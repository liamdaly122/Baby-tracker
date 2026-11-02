#!/usr/bin/env python3
"""Claims lint for Mission Control's store listing and other promotional copy. Standard library only.

The MHRA judges whether an app is a medical device by what its maker says it's for, including the
App Store description (docs/regulatory/intended-purpose.md). This checks every Markdown and text
file under docs/store/ for claims the intended purpose rules out: that the app monitors, detects,
predicts or diagnoses; that it triages; that it's accurate or proven; that it says when it's safe to
wait; or that the NHS approves it. The app's own wording is checked by StateCopyTests and the
content lint.

Usage: python3 -I Scripts/claims-lint.py [--root PATH]
Exits 1 if anything fails.
"""

import argparse
import re
import sys
from pathlib import Path

# Phrases that are fine although they contain a banned word. They're blanked out before checking.
ALLOWED = [
    r"(?:not|isn't|is not) affiliated with or endorsed by the NHS",
    r"(?:doesn't|does not|never) diagnose\w*",
    r"not a diagnosis",
    r"triage (?:line|number)s?",
]

# A pattern, and why it's banned. Matched without regard to case, on whole words.
BANNED = [
    (r"monitor(?:s|ed|ing)?", "the app doesn't monitor her, the baby or labour"),
    (r"detect(?:s|ed|ing|ion)?", "the app doesn't detect labour"),
    (r"predict(?:s|ed|ing|ion|ions)?", "the app doesn't predict anything"),
    (r"measur(?:e|es|ed|ing)", "the app doesn't measure anything about her"),
    (r"diagnos\w*", "the app doesn't diagnose"),
    (r"triag(?:e|es|ed|ing)", "triage is what the unit does, not the app"),
    (r"symptom checker", "the app isn't a symptom checker"),
    (r"self[- ]assess\w*", "the app isn't a self-assessment"),
    (r"screening", "the app doesn't screen"),
    (r"accura(?:te|tely|cy)", "no accuracy claims"),
    (r"(?:clinically|medically) (?:proven|validated|tested|approved)", "no clinical claims"),
    (r"proven", "no clinical claims"),
    (r"know when to go", "the app helps follow advice on when to call; it doesn't decide when to go"),
    (r"when to go (?:in|to hospital)", "the app helps follow advice on when to call; it doesn't decide when to go"),
    (r"safe to wait", "the app never says it's safe to wait"),
    (r"no need to (?:call|ring|phone)", "the app never discourages a call"),
    (r"(?:you're|you are|she's|she is) in labour", "the app doesn't say whether she's in labour"),
    (r"(?:established|active|early) labour", "the app doesn't say what stage of labour she's in"),
    (r"NHS[- ](?:approved|endorsed|recommended|app)", "the app isn't approved or endorsed by the NHS"),
    (r"(?:approved|endorsed|recommended) by the NHS", "the app isn't approved or endorsed by the NHS"),
]


def problems_in(text):
    """Every banned claim in the text, as (line number, the words found, why)."""
    found = []
    for number, line in enumerate(text.splitlines(), start=1):
        for allowed in ALLOWED:
            # Blank it out to the same length, so positions still match the line.
            line = re.sub(allowed, lambda match: " " * len(match.group(0)), line, flags=re.IGNORECASE)
        on_line = []
        for pattern, reason in BANNED:
            for match in re.finditer(rf"\b{pattern}\b", line, flags=re.IGNORECASE):
                on_line.append((match.start(), match.group(0), reason))
        found += [(number, words, reason) for _, words, reason in sorted(on_line, key=lambda item: item[0])]
    return found


def lint(root):
    """Problems in every file under docs/store/, as printable lines."""
    folder = root / "docs" / "store"
    if not folder.is_dir():
        return [f"{folder}: missing"]
    messages = []
    for path in sorted(folder.rglob("*")):
        if path.suffix not in {".md", ".txt"}:
            continue
        for number, words, reason in problems_in(path.read_text(encoding="utf-8")):
            messages.append(f"{path.relative_to(root)}:{number}: \"{words}\": {reason}")
    return messages


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args(argv)
    messages = lint(args.root)
    for message in messages:
        print(message)
    if messages:
        print(f"claims-lint: {len(messages)} problem(s)")
        return 1
    print("claims-lint: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
