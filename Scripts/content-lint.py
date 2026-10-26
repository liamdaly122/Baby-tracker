#!/usr/bin/env python3
"""Content lint for Mission Control. Standard library only.

Checks every file in Sources/MissionContent/Content/<region>/<kind>.json for:
  - a valid envelope (schemaVersion, contentVersion, region matching its folder, items)
  - duplicate item IDs within a region
  - provenance on every clinical item (reviewer sign-off required with --release), with a source
    URL that appears in the research reports under docs/research/
  - an "off" variant on every humour copy field, and no humour at all from the Flight Surgeon
  - forbidden diagnostic phrases ("established labour", "you are in labour", "diagnos", ...)
  - the fields of each kind (modules, stages, weeks, deadlines, quiz answers, badge rules)
  - references between files (checklist quizzes, badge targets, at least 3 questions per quiz)
  - threshold defaults inside their safe bounds, and the safety ceilings that can never be relaxed

Usage: python3 -I Scripts/content-lint.py [--release] [--root PATH] [--research PATH]
Exits 1 if anything fails.
"""

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA_VERSION = 1
REGIONS = {"uk", "us"}
KINDS = {"briefings", "checklist", "glossary", "coaching", "quiz", "thresholds", "badges"}

# Enum raw values, mirroring Sources/MissionCore/Content/ContentSchema.swift.
MODULES = {
    "adminAndLeave", "money", "appointments", "classes", "birthPlan", "hospitalBag", "vehicle",
    "homeModule", "dayOfLogistics", "skillsTraining", "commanderSupport", "splashdown",
}
STAGES = {"latent", "established", "transition", "pushing", "thirdStage", "theatre", "goldenHour", "postnatal"}
ACTS = {"recruitment", "systemsCheck", "countdown", "holdAtTMinus", "launch", "splashdown"}
SPEAKERS = {"capcom", "flightSurgeon", "veteran"}
ANCHORS = {"ewc", "edd", "birth"}
BADGE_RULES = {"checklistItemsDone", "moduleComplete", "quizPassed", "streakDays"}
MAX_WEEK = 42
MIN_QUIZ_QUESTIONS = 3

# Kinds whose items are always clinical and so always need provenance.
ALWAYS_CLINICAL = {"glossary", "coaching", "thresholds"}

# Humour copy fields per kind. Each must be an object with a non-empty "off".
COPY_FIELDS = {
    "checklist": ["title", "why"],
    "briefings": ["title", "body"],
    "badges": ["description"],
}

# Copy must tell the user what to do, never what is happening to her body.
FORBIDDEN_PHRASES = [
    "established labour",
    "established labor",
    "active labour",
    "active labor",
    "you are in labour",
    "you are in labor",
    "you're in labour",
    "you're in labor",
    "diagnos",
]

# The glossary explains what midwives mean by these terms, so it may name them.
ALLOWED_PHRASES = {
    "glossary": {"established labour", "established labor", "active labour", "active labor"},
}

THRESHOLD_FIELDS = {
    "adviceIntervalSec",
    "adviceDurationSec",
    "patternWindowSec",
    "urgentSingleDurationSec",
    "urgentCountIn10Min",
    "regularityCV",
    "earlyCallerWindowSec",
    "travelEarlyCallMinutes",
}
THRESHOLD_UNITS = {"seconds", "minutes", "count", "ratio"}

# Ceilings and floors from the approved plan. These rules can be tightened but never relaxed.
THRESHOLD_LIMITS = {
    "patternWindowSec": ("max", 3600),
    "urgentSingleDurationSec": ("max", 120),
    "urgentCountIn10Min": ("max", 6),
    "earlyCallerWindowSec": ("min", 1800),
}

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
URL_RE = re.compile(r"https://[^\s)>;,`\"]+")
REPO = Path(__file__).resolve().parent.parent
DEFAULT_ROOT = REPO / "Sources" / "MissionContent" / "Content"
DEFAULT_RESEARCH = REPO / "docs" / "research"


def research_urls(folder):
    """Every https URL quoted in the research reports, so content can't cite an invented source."""
    urls = set()
    for path in sorted(folder.glob("*.md")):
        for match in URL_RE.findall(path.read_text(encoding="utf-8")):
            urls.add(match.rstrip("."))
    return urls


class Lint:
    def __init__(self, release, sources=None):
        self.release = release
        self.sources = research_urls(DEFAULT_RESEARCH) if sources is None else sources
        self.errors = []

    def error(self, where, message):
        self.errors.append(f"{where}: {message}")

    # Envelope and items

    def load_file(self, path, region):
        """Returns the items list, or None if the envelope is unusable."""
        where = str(path)
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            self.error(where, f"cannot parse JSON ({exc})")
            return None
        if not isinstance(doc, dict):
            self.error(where, "top level must be an object")
            return None
        if doc.get("schemaVersion") != SCHEMA_VERSION:
            self.error(where, f"schemaVersion must be {SCHEMA_VERSION}")
        if not isinstance(doc.get("contentVersion"), str) or not doc.get("contentVersion"):
            self.error(where, "contentVersion must be a non-empty string")
        if doc.get("region") != region:
            self.error(where, f"region must be {region!r} to match its folder")
        items = doc.get("items")
        if not isinstance(items, list):
            self.error(where, "items must be a list")
            return None
        return items

    def check_items(self, path, kind, items, seen_ids):
        where = str(path)
        for index, item in enumerate(items):
            item_where = f"{where} item {index}"
            if not isinstance(item, dict):
                self.error(item_where, "item must be an object")
                continue
            item_id = item.get("id")
            if not isinstance(item_id, str) or not item_id:
                self.error(item_where, "id must be a non-empty string")
            else:
                item_where = f"{where} [{item_id}]"
                if item_id in seen_ids:
                    self.error(item_where, f"duplicate id (also in {seen_ids[item_id]})")
                else:
                    seen_ids[item_id] = path.name
            self.check_provenance(item_where, kind, item)
            self.check_copy(item_where, kind, item)
            self.check_phrases(item_where, kind, item)
            checker = {
                "checklist": self.check_checklist,
                "glossary": self.check_glossary,
                "coaching": self.check_coaching,
                "briefings": self.check_briefings,
                "quiz": self.check_quiz,
                "badges": self.check_badges,
            }.get(kind)
            if checker:
                checker(item_where, item)
        if kind == "thresholds":
            self.check_thresholds(where, items)

    def is_clinical(self, kind, item):
        if kind in ALWAYS_CLINICAL:
            return True
        if item.get("clinicalText"):
            return True
        if item.get("speaker") == "flightSurgeon":
            return True
        provenance = item.get("provenance")
        return isinstance(provenance, dict) and provenance.get("clinical") is True

    def check_provenance(self, where, kind, item):
        provenance = item.get("provenance")
        if provenance is None:
            if self.is_clinical(kind, item):
                self.error(where, "clinical item has no provenance")
            return
        if not isinstance(provenance, dict):
            self.error(where, "provenance must be an object")
            return
        url = provenance.get("sourceURL")
        if not isinstance(url, str) or not url.startswith("https://"):
            self.error(where, "provenance.sourceURL must be an https URL")
        elif url not in self.sources:
            self.error(where, f"provenance.sourceURL is not in the research reports: {url}")
        if not isinstance(provenance.get("sourceTitle"), str) or not provenance.get("sourceTitle"):
            self.error(where, "provenance.sourceTitle is missing")
        accessed = provenance.get("accessed")
        if not isinstance(accessed, str) or not DATE_RE.match(accessed):
            self.error(where, "provenance.accessed must be a YYYY-MM-DD date")
        if not isinstance(provenance.get("clinical"), bool):
            self.error(where, "provenance.clinical must be true or false")
        for key in ("reviewer", "reviewedOn"):
            if key not in provenance:
                self.error(where, f"provenance.{key} must be present (null until review)")
        if provenance.get("clinical") is True and self.release:
            if not provenance.get("reviewer"):
                self.error(where, "release build: clinical item has no reviewer sign-off")
            reviewed_on = provenance.get("reviewedOn")
            if not isinstance(reviewed_on, str) or not DATE_RE.match(reviewed_on):
                self.error(where, "release build: clinical item has no reviewedOn date")

    def check_copy(self, where, kind, item):
        for field in COPY_FIELDS.get(kind, []):
            copy = item.get(field)
            if not isinstance(copy, dict):
                self.error(where, f"{field} must be a copy object with an 'off' variant")
                continue
            if not isinstance(copy.get("off"), str) or not copy["off"].strip():
                self.error(where, f"{field}.off is missing or empty")
            for variant in ("mild", "full"):
                if variant in copy and copy[variant] is not None and not isinstance(copy[variant], str):
                    self.error(where, f"{field}.{variant} must be a string or null")

    def check_phrases(self, where, kind, item):
        allowed = ALLOWED_PHRASES.get(kind, set())
        for path, text in iter_strings(item):
            if path and path[0] == "provenance":
                continue
            lowered = text.lower()
            for phrase in FORBIDDEN_PHRASES:
                if phrase in allowed:
                    continue
                if phrase in lowered:
                    self.error(where, f"forbidden phrase {phrase!r} in {'.'.join(map(str, path))}")

    # Per-kind fields

    def check_checklist(self, where, item):
        if item.get("module") not in MODULES:
            self.error(where, f"module must be one of {sorted(MODULES)}")
        week = item.get("unlockWeek")
        if not is_int(week) or not 0 <= week <= MAX_WEEK:
            self.error(where, f"unlockWeek must be an integer from 0 to {MAX_WEEK}")
        deadline = item.get("deadline")
        if deadline is not None:
            if not isinstance(deadline, dict) or deadline.get("anchor") not in ANCHORS:
                self.error(where, f"deadline.anchor must be one of {sorted(ANCHORS)}")
            elif not is_int(deadline.get("offsetDays")):
                self.error(where, "deadline.offsetDays must be an integer")
        reminders = item.get("reminderDaysBefore")
        if not isinstance(reminders, list) or not all(is_int(d) and d >= 0 for d in reminders):
            self.error(where, "reminderDaysBefore must be a list of whole days, 0 or more")
        elif reminders and deadline is None:
            self.error(where, "reminderDaysBefore needs a deadline")
        if not is_int(item.get("xp")) or item["xp"] < 0:
            self.error(where, "xp must be a whole number, 0 or more")
        if item.get("quizID") is not None and not isinstance(item.get("quizID"), str):
            self.error(where, "quizID must be a string or null")

    def check_glossary(self, where, item):
        worry = item.get("worryLevel")
        if not is_int(worry) or not 0 <= worry <= 3:
            self.error(where, "worryLevel must be an integer from 0 to 3")
        for key in ("term", "plainEnglish", "questionToAsk"):
            if not isinstance(item.get(key), str) or not item.get(key):
                self.error(where, f"{key} must be a non-empty string")
        if not isinstance(item.get("aliases"), list):
            self.error(where, "aliases must be a list")
        stages = item.get("stages")
        if not isinstance(stages, list) or not all(stage in STAGES for stage in stages):
            self.error(where, f"stages must be a list of {sorted(STAGES)}")

    def check_coaching(self, where, item):
        if item.get("stage") not in STAGES:
            self.error(where, f"stage must be one of {sorted(STAGES)}")
        if not isinstance(item.get("title"), str) or not item.get("title"):
            self.error(where, "title must be a non-empty string")
        do_this = item.get("doThis")
        if not isinstance(do_this, list) or not do_this or not all(isinstance(line, str) for line in do_this):
            self.error(where, "doThis must be a non-empty list of strings")
        avoid = item.get("avoidThis")
        if not isinstance(avoid, list) or not all(isinstance(line, str) for line in avoid):
            self.error(where, "avoidThis must be a list of strings")

    def check_briefings(self, where, item):
        week = item.get("week")
        if not is_int(week) or not 0 <= week <= MAX_WEEK:
            self.error(where, f"week must be an integer from 0 to {MAX_WEEK}")
        if item.get("act") not in ACTS:
            self.error(where, f"act must be one of {sorted(ACTS)}")
        if item.get("speaker") not in SPEAKERS:
            self.error(where, f"speaker must be one of {sorted(SPEAKERS)}")
        if item.get("speaker") == "flightSurgeon":
            for field in ("title", "body"):
                copy = item.get(field)
                if isinstance(copy, dict) and (copy.get("mild") or copy.get("full")):
                    self.error(where, f"the Flight Surgeon never jokes: {field} must only have 'off'")

    def check_quiz(self, where, item):
        for key in ("quizID", "prompt", "explanation"):
            if not isinstance(item.get(key), str) or not item.get(key):
                self.error(where, f"{key} must be a non-empty string")
        choices = item.get("choices")
        if not isinstance(choices, list) or len(choices) < 2 or not all(isinstance(c, str) and c for c in choices):
            self.error(where, "choices must be a list of at least 2 non-empty strings")
            return
        answer = item.get("correctIndex")
        if not is_int(answer) or not 0 <= answer < len(choices):
            self.error(where, "correctIndex must point at one of the choices")

    def check_badges(self, where, item):
        if not isinstance(item.get("name"), str) or not item.get("name"):
            self.error(where, "name must be a non-empty string")
        rule = item.get("rule")
        if not isinstance(rule, dict) or rule.get("kind") not in BADGE_RULES:
            self.error(where, f"rule.kind must be one of {sorted(BADGE_RULES)}")
            return
        targets = rule.get("targetIDs")
        if not isinstance(targets, list) or not all(isinstance(t, str) for t in targets):
            self.error(where, "rule.targetIDs must be a list of strings")
        if rule.get("count") is not None and (not is_int(rule["count"]) or rule["count"] < 1):
            self.error(where, "rule.count must be a whole number, 1 or more")

    # Thresholds

    def check_thresholds(self, where, items):
        seen = set()
        for item in items:
            if not isinstance(item, dict):
                continue
            field = item.get("id")
            item_where = f"{where} [{field}]"
            if field not in THRESHOLD_FIELDS:
                self.error(item_where, "unknown threshold field")
                continue
            seen.add(field)
            values = {key: item.get(key) for key in ("default", "min", "max")}
            if not all(is_number(value) for value in values.values()):
                self.error(item_where, "default, min and max must be numbers")
                continue
            default, low, high = values["default"], values["min"], values["max"]
            allows_disabled = item.get("allowsDisabled")
            if not isinstance(allows_disabled, bool):
                self.error(item_where, "allowsDisabled must be true or false")
                allows_disabled = False
            if item.get("unit") not in THRESHOLD_UNITS:
                self.error(item_where, f"unit must be one of {sorted(THRESHOLD_UNITS)}")
            if low > high:
                self.error(item_where, f"min {low} is above max {high}")
            disabled = allows_disabled and default == 0
            if not disabled and not low <= default <= high:
                self.error(item_where, f"default {default} is outside its safe bounds [{low}, {high}]")
            limit = THRESHOLD_LIMITS.get(field)
            if limit:
                side, bound = limit
                if side == "max" and high > bound:
                    self.error(item_where, f"max {high} relaxes a safety ceiling of {bound}")
                if side == "min" and low < bound:
                    self.error(item_where, f"min {low} is below the safety floor of {bound}")
        for field in sorted(THRESHOLD_FIELDS - seen):
            self.error(where, f"missing threshold field {field}")

    # References between files

    def check_references(self, region_dir, files):
        def items_of(kind):
            return [item for item in files.get(kind, []) if isinstance(item, dict)]

        quiz_counts = {}
        for question in items_of("quiz"):
            if isinstance(question.get("quizID"), str):
                quiz_counts[question["quizID"]] = quiz_counts.get(question["quizID"], 0) + 1
        for quiz_id, count in sorted(quiz_counts.items()):
            if count < MIN_QUIZ_QUESTIONS:
                self.error(f"{region_dir}/quiz.json", f"quiz {quiz_id!r} has {count} question(s), needs {MIN_QUIZ_QUESTIONS}")

        checklist_ids = {item.get("id") for item in items_of("checklist")}
        for item in items_of("checklist"):
            quiz_id = item.get("quizID")
            if isinstance(quiz_id, str) and quiz_id not in quiz_counts:
                self.error(f"{region_dir}/checklist.json [{item.get('id')}]", f"quiz {quiz_id!r} not found in quiz.json")

        valid_targets = {
            "checklistItemsDone": checklist_ids,
            "moduleComplete": MODULES,
            "quizPassed": set(quiz_counts),
            "streakDays": set(),
        }
        for badge in items_of("badges"):
            rule = badge.get("rule")
            if not isinstance(rule, dict) or rule.get("kind") not in valid_targets:
                continue
            for target in rule.get("targetIDs") or []:
                if target not in valid_targets[rule["kind"]]:
                    self.error(f"{region_dir}/badges.json [{badge.get('id')}]", f"target {target!r} not found")

    # Entry point

    def run(self, root):
        if not root.is_dir():
            self.error(str(root), "content folder not found")
            return
        for region_dir in sorted(p for p in root.iterdir() if p.is_dir()):
            region = region_dir.name
            if region not in REGIONS:
                self.error(str(region_dir), f"unknown region folder (expected one of {sorted(REGIONS)})")
                continue
            seen_ids = {}
            files = {}
            for path in sorted(region_dir.iterdir()):
                if path.name.startswith("."):
                    continue
                if path.suffix != ".json" or path.stem not in KINDS:
                    self.error(str(path), f"unexpected file (expected <kind>.json, kinds: {sorted(KINDS)})")
                    continue
                items = self.load_file(path, region)
                if items is None:
                    continue
                files[path.stem] = items
                self.check_items(path, path.stem, items, seen_ids)
            self.check_references(region_dir, files)


def iter_strings(value, path=()):
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from iter_strings(child, path + (key,))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_strings(child, path + (index,))


def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Lint Mission Control content JSON.")
    parser.add_argument("--release", action="store_true", help="require midwife sign-off on clinical items")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="content folder to lint")
    parser.add_argument("--research", type=Path, default=DEFAULT_RESEARCH, help="research reports folder")
    args = parser.parse_args(argv)

    lint = Lint(release=args.release, sources=research_urls(args.research))
    lint.run(args.root)
    if lint.errors:
        for line in lint.errors:
            print(line, file=sys.stderr)
        print(f"content-lint: {len(lint.errors)} problem(s)", file=sys.stderr)
        return 1
    print("content-lint: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
