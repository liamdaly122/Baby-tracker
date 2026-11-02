"""Self-tests for claims-lint.py. Run: python3 -I -m unittest discover -s Scripts -p 'test_*.py'"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "claims-lint.py"
ROOT = Path(__file__).resolve().parent.parent

spec = importlib.util.spec_from_file_location("claims_lint", SCRIPT)
claims_lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(claims_lint)


class ClaimsLintTests(unittest.TestCase):
    def words(self, text):
        return [words.lower() for _, words, _ in claims_lint.problems_in(text)]

    def test_the_real_listing_passes(self):
        self.assertEqual(claims_lint.lint(ROOT), [])

    def test_device_claims_are_caught(self):
        text = "Monitors labour, detects contractions and predicts when to go in. Accurate and clinically proven."
        self.assertEqual(
            self.words(text),
            ["monitors", "detects", "predicts", "when to go in", "accurate", "clinically proven", "proven"],
        )

    def test_a_claim_is_caught_in_any_case_and_on_any_line(self):
        found = claims_lint.problems_in("Fine.\nTRIAGE at home.\n")
        self.assertEqual([(number, words) for number, words, _ in found], [(2, "TRIAGE")])

    def test_waiting_and_stage_claims_are_caught(self):
        text = "It tells you when it's safe to wait, with no need to call, and when she's in active labour."
        self.assertEqual(self.words(text), ["safe to wait", "no need to call", "active labour"])

    def test_nhs_endorsement_is_caught_but_the_disclaimer_is_not(self):
        self.assertEqual(
            self.words("An NHS-approved app, recommended by the NHS."), ["nhs-approved", "recommended by the nhs"]
        )
        self.assertEqual(self.words("Based on NHS guidance. It isn't affiliated with or endorsed by the NHS."), [])

    def test_saying_what_it_doesnt_do_is_allowed(self):
        self.assertEqual(self.words("It doesn't diagnose anything. Based on NHS advice, not a diagnosis."), [])
        self.assertEqual(self.words("It diagnoses labour."), ["diagnoses"])

    def test_the_units_triage_line_is_allowed(self):
        self.assertEqual(self.words("Save the triage line and the triage number."), [])
        self.assertEqual(self.words("The app triages her."), ["triages"])

    def test_words_inside_other_words_are_not_caught(self):
        self.assertEqual(self.words("Unmonitored? Undetectable? An improvement."), [])
        self.assertEqual(self.words("A measurement of nothing, an unpredictable day."), [])

    def test_a_missing_folder_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(len(claims_lint.lint(Path(folder))), 1)

    def test_only_text_files_are_read(self):
        with tempfile.TemporaryDirectory() as folder:
            store = Path(folder) / "docs" / "store"
            store.mkdir(parents=True)
            (store / "listing.md").write_text("Monitors labour.\n", encoding="utf-8")
            (store / "notes.txt").write_text("Detects labour.\n", encoding="utf-8")
            (store / "image.svg").write_text("Predicts labour.\n", encoding="utf-8")
            messages = claims_lint.lint(Path(folder))
        self.assertEqual(
            messages,
            [
                'docs/store/listing.md:1: "Monitors": the app doesn\'t monitor her, the baby or labour',
                'docs/store/notes.txt:1: "Detects": the app doesn\'t detect labour',
            ],
        )


if __name__ == "__main__":
    unittest.main()
