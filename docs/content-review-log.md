# Content review log

Author: Liam Daly
Started: 26 October 2026

Everything here must be confirmed, or signed off by a registered midwife, before TestFlight. Clinical items in the content JSON carry `reviewer` and `reviewedOn` fields; `python3 -I Scripts/content-lint.py --release` fails until every clinical item has both.

## Status key

- **Open**: not yet checked.
- **Confirmed**: checked against the primary source; note the date and who.
- **Signed off**: reviewed by the midwife reviewer.

## Facts the research could not confirm

Carried over from the verification notes in `docs/research/01-pre-birth-preparation.md`.

| # | Item | Why it's open | Status |
|---|---|---|---|
| 1 | Birth certificate fees | Not confirmed on GOV.UK in the research pass | Open |
| 2 | MATB1 timing (when the midwife issues it) | Not confirmed on GOV.UK | Open |
| 3 | 21-day notice for unpaid parental leave | Not confirmed on GOV.UK | Open |
| 4 | The "2-hour car seat rule" | Industry and parenting guidance, not Lullaby Trust wording. Phrase as "general guidance" in the app | Open |
| 5 | "Swaddle below the shoulders" | General guidance, not Lullaby Trust wording | Open |
| 6 | Leeds numbers: LGI MAC 0113 392 6731, St James's MAC 0113 206 5781, Register Office 0113 222 4408, Dad Matters 0113 244 2419 | Correct on 26 Oct 2026; re-check every year. Hospital details are user-entered, never hard-coded | Open |
| 7 | Martha's Rule rollout dates | Taken from OUH and Healthwatch pages; the NHS England page could not be fetched | Open |

## Threshold decisions (thresholds.json)

The defaults and safe bounds for the go/no-go engine live in `Sources/MissionContent/Content/{uk,us}/thresholds.json`, with a compiled-in copy in `ThresholdTable.builtIn(for:)` that a test keeps identical.

| # | Decision | Reason | Status |
|---|---|---|---|
| T1 | UK `adviceDurationSec` defaults to 0, meaning "no duration requirement". The 30 to 90 second bounds only apply when it's switched on. 0 is also allowed in the US profile. | The NHS call-for-advice wording has no duration. Switching the duration rule off only makes the app suggest calling sooner, never later. | Open |
| T2 | `patternWindowSec` is 1 hour and can be shortened to 30 minutes but never lengthened. | NHS says "regular" without a time; 1 hour matches the 5-1-1 convention. | Open |
| T3 | `urgentSingleDurationSec` is 2 minutes and can be tightened to 90 seconds but never relaxed. | NHS: call urgently if any contraction lasts longer than 2 minutes. | Open |
| T4 | `urgentCountIn10Min` is 6 and can be tightened to 5. | NHS: call urgently at 6 or more in 10 minutes. NICE defines tachysystole as more than 5 in 10. | Open |
| T5 | `regularityCV` 0.35 (bounds 0.25 to 0.5) is app-defined. | Turns "regular" into a number: interquartile range of start-to-start intervals divided by the median interval. Needs a midwife's view. | Open |
| T6 | Early callers (second or later baby, previous fast labour, journey over 30 minutes) need the pattern for 30 minutes instead of an hour. Not editable in v1. | NHS: call earlier for subsequent babies and long journeys, without a number. | Open |
| T7 | The US profile reuses the NHS urgent rules (over 2 minutes, 6 in 10). | ACOG publishes no numeric rule. | Open |
