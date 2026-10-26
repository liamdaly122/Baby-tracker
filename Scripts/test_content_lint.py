"""Self-tests for content-lint.py. Run: python3 -I -m unittest discover -s Scripts -p 'test_*.py'"""

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "content-lint.py"
CONTENT = Path(__file__).resolve().parent.parent / "Sources" / "MissionContent" / "Content"

spec = importlib.util.spec_from_file_location("content_lint", SCRIPT)
content_lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(content_lint)


def provenance(reviewed=False):
    return {
        "sourceURL": "https://www.nhs.uk/",
        "sourceTitle": "NHS",
        "accessed": "2026-10-26",
        "reviewer": "A Midwife RM" if reviewed else None,
        "reviewedOn": "2026-11-01" if reviewed else None,
        "clinical": True,
    }


def envelope(region, items):
    return {"schemaVersion": 1, "contentVersion": "test", "region": region, "items": items}


class ContentLintTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "uk").mkdir()
        self.uk_thresholds = json.loads((CONTENT / "uk" / "thresholds.json").read_text())

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, kind, doc, region="uk"):
        (self.root / region / f"{kind}.json").write_text(json.dumps(doc))

    def lint(self, release=False):
        lint = content_lint.Lint(release=release)
        lint.run(self.root)
        return lint.errors

    def threshold(self, field):
        return next(item for item in self.uk_thresholds["items"] if item["id"] == field)

    def test_bundled_content_is_clean(self):
        lint = content_lint.Lint(release=False)
        lint.run(CONTENT)
        self.assertEqual(lint.errors, [])

    def test_uk_duration_zero_is_allowed_as_disabled(self):
        self.write("thresholds", self.uk_thresholds)
        self.assertEqual(self.lint(), [])

    def test_default_outside_bounds_fails(self):
        self.threshold("adviceIntervalSec")["default"] = 600
        self.write("thresholds", self.uk_thresholds)
        self.assertTrue(any("outside its safe bounds" in e for e in self.lint()))

    def test_zero_without_allows_disabled_fails(self):
        self.threshold("adviceDurationSec")["allowsDisabled"] = False
        self.write("thresholds", self.uk_thresholds)
        self.assertTrue(any("outside its safe bounds" in e for e in self.lint()))

    def test_relaxed_safety_ceiling_fails(self):
        self.threshold("urgentSingleDurationSec")["max"] = 180
        self.write("thresholds", self.uk_thresholds)
        self.assertTrue(any("relaxes a safety ceiling" in e for e in self.lint()))

    def test_lengthened_pattern_window_fails(self):
        self.threshold("patternWindowSec")["max"] = 5400
        self.write("thresholds", self.uk_thresholds)
        self.assertTrue(any("relaxes a safety ceiling" in e for e in self.lint()))

    def test_missing_threshold_field_fails(self):
        self.uk_thresholds["items"] = [i for i in self.uk_thresholds["items"] if i["id"] != "regularityCV"]
        self.write("thresholds", self.uk_thresholds)
        self.assertTrue(any("missing threshold field regularityCV" in e for e in self.lint()))

    def test_region_must_match_folder(self):
        doc = copy.deepcopy(self.uk_thresholds)
        doc["region"] = "us"
        self.write("thresholds", doc)
        self.assertTrue(any("to match its folder" in e for e in self.lint()))

    def test_forbidden_phrase_in_coaching_fails(self):
        card = {
            "id": "c1",
            "stage": "established",
            "title": "You are in labour now",
            "doThis": ["Breathe with her"],
            "avoidThis": [],
            "provenance": provenance(),
        }
        self.write("coaching", envelope("uk", [card]))
        self.assertTrue(any("forbidden phrase 'you are in labour'" in e for e in self.lint()))

    def test_glossary_may_name_established_labour(self):
        entry = {
            "id": "g1",
            "term": "Established labour",
            "aliases": ["active labour"],
            "plainEnglish": "Regular contractions and the cervix opening from 4 cm.",
            "worryLevel": 0,
            "questionToAsk": "How far along is she?",
            "stages": ["established"],
            "provenance": provenance(),
        }
        self.write("glossary", envelope("uk", [entry]))
        self.assertEqual(self.lint(), [])

    def test_glossary_still_rejects_diagnos(self):
        entry = {
            "id": "g1",
            "term": "Delay",
            "aliases": [],
            "plainEnglish": "Doctors diagnose delay when progress slows.",
            "worryLevel": 1,
            "questionToAsk": "What happens next?",
            "stages": ["established"],
            "provenance": provenance(),
        }
        self.write("glossary", envelope("uk", [entry]))
        self.assertTrue(any("forbidden phrase 'diagnos'" in e for e in self.lint()))

    def test_clinical_item_without_provenance_fails(self):
        item = {
            "id": "k1",
            "module": "skillsTraining",
            "title": {"off": "Learn the 70°C rule"},
            "why": {"off": "Kills bacteria in formula powder."},
            "clinicalText": "Use water boiled and left for no more than 30 minutes.",
            "unlockWeek": 30,
            "deadline": None,
            "reminderDaysBefore": [],
            "quizID": None,
            "xp": 10,
        }
        self.write("checklist", envelope("uk", [item]))
        self.assertTrue(any("clinical item has no provenance" in e for e in self.lint()))

    def test_copy_needs_off_variant(self):
        item = {
            "id": "k1",
            "module": "money",
            "title": {"mild": "Open a baby budget"},
            "why": {"off": "The first year costs about £8,000 to £10,000."},
            "unlockWeek": 4,
            "deadline": None,
            "reminderDaysBefore": [],
            "quizID": None,
            "xp": 5,
        }
        self.write("checklist", envelope("uk", [item]))
        self.assertTrue(any("title.off is missing" in e for e in self.lint()))

    def test_duplicate_ids_fail_across_files(self):
        self.write("thresholds", self.uk_thresholds)
        card = {"id": "adviceIntervalSec", "stage": "latent", "title": "t", "doThis": [], "avoidThis": [],
                "provenance": provenance()}
        self.write("coaching", envelope("uk", [card]))
        self.assertTrue(any("duplicate id" in e for e in self.lint()))

    def test_release_requires_reviewer(self):
        self.write("thresholds", self.uk_thresholds)
        self.assertEqual(self.lint(release=False), [])
        self.assertTrue(any("no reviewer sign-off" in e for e in self.lint(release=True)))

    def test_release_passes_once_reviewed(self):
        for item in self.uk_thresholds["items"]:
            item["provenance"] = provenance(reviewed=True)
        self.write("thresholds", self.uk_thresholds)
        self.assertEqual(self.lint(release=True), [])

    def test_unknown_file_fails(self):
        (self.root / "uk" / "notes.json").write_text("{}")
        self.assertTrue(any("unexpected file" in e for e in self.lint()))


if __name__ == "__main__":
    unittest.main()
