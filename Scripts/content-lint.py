#!/usr/bin/env python3
"""Content lint for Mission Control. Standard library only.

Checks every file in Sources/MissionContent/Content/<region>/<kind>.json for:
  - a valid envelope (schemaVersion, contentVersion, region matching its folder, items)
  - duplicate item IDs within a region
  - provenance on every clinical item (reviewer sign-off required with --release)
  - an "off" variant on every humour copy field
  - forbidden diagnostic phrases ("established labour", "you are in labour", "diagnos", ...)
  - threshold defaults inside their safe bounds, and the safety ceilings that can never be relaxed

Usage: python3 -I Scripts/content-lint.py [--release] [--root PATH]
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
DEFAULT_ROOT = Path(__file__).resolve().parent.parent / "Sources" / "MissionContent" / "Content"


class Lint:
    def __init__(self, release):
        self.release = release
        self.errors = []

    def error(self, where, message):
        self.errors.append(f"{where}: {message}")

    # Envelope and items

    def check_file(self, path, region, kind, seen_ids):
        where = str(path)
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            self.error(where, f"cannot parse JSON ({exc})")
            return
        if not isinstance(doc, dict):
            self.error(where, "top level must be an object")
            return
        if doc.get("schemaVersion") != SCHEMA_VERSION:
            self.error(where, f"schemaVersion must be {SCHEMA_VERSION}")
        if not isinstance(doc.get("contentVersion"), str) or not doc.get("contentVersion"):
            self.error(where, "contentVersion must be a non-empty string")
        if doc.get("region") != region:
            self.error(where, f"region must be {region!r} to match its folder")
        items = doc.get("items")
        if not isinstance(items, list):
            self.error(where, "items must be a list")
            return

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
            if kind == "glossary":
                self.check_glossary(item_where, item)

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

    def check_glossary(self, where, item):
        worry = item.get("worryLevel")
        if not isinstance(worry, int) or isinstance(worry, bool) or not 0 <= worry <= 3:
            self.error(where, "worryLevel must be an integer from 0 to 3")
        for key in ("term", "plainEnglish", "questionToAsk"):
            if not isinstance(item.get(key), str) or not item.get(key):
                self.error(where, f"{key} must be a non-empty string")
        if not isinstance(item.get("aliases"), list):
            self.error(where, "aliases must be a list")

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
            for path in sorted(region_dir.iterdir()):
                if path.name.startswith("."):
                    continue
                if path.suffix != ".json" or path.stem not in KINDS:
                    self.error(str(path), f"unexpected file (expected <kind>.json, kinds: {sorted(KINDS)})")
                    continue
                self.check_file(path, region, path.stem, seen_ids)


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


def main(argv=None):
    parser = argparse.ArgumentParser(description="Lint Mission Control content JSON.")
    parser.add_argument("--release", action="store_true", help="require midwife sign-off on clinical items")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="content folder to lint")
    args = parser.parse_args(argv)

    lint = Lint(release=args.release)
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
