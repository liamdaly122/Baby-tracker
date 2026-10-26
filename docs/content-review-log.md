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

## Engine behaviour (GoNoGoEngine)

How the engine turns NHS wording into rules. The code is in `Sources/MissionCore/Engine/`; every rule below has a test, and the scripted labours in `Tests/MissionCoreTests/Fixtures/` show each one end to end.

| # | Rule | Notes | Status |
|---|---|---|---|
| E1 | Frequency is start to start; duration is start to end. | Matches how NHS and ACOG describe timing. | Open |
| E2 | Statistics use the contractions in the last hour (`patternWindowSec`), and need at least 4. | Fewer than 4 shows "not enough recent contractions". | Open |
| E3 | A gap over 3× the recent median interval starts a new run, and the hour restarts. If no contraction starts within 3× the median, the pattern counts as stale. | Stops an old pattern counting after a long pause. | Open |
| E4 | "Regular" means the interquartile range of intervals divided by the median is 0.35 or less (see T5). | | Open |
| E5 | "Sustained" runs from the first contraction of the current run to the earlier of now and one median interval after the last start. | Silence doesn't count. A slower but unbroken lead-in can count towards the hour if the last hour is regular, which leans towards calling earlier. | Open |
| E6 | "6 or more in 10 minutes" counts starts in any half-open 10-minute window, so contractions every 2 minutes (5 per 10 minutes) don't trigger it, and every 100 seconds does. | Inclusive counting would flag every-2-minute contractions. | Open |
| E7 | A contraction over 2 minutes in the last hour means call now. | | Open |
| E8 | A contraction still being timed past 2 minutes also means call now, worded "If it's still going, call now. If you forgot to stop the timer, fix it." Past 5 minutes it's left out of duration statistics and flagged for editing. | Amendment B13.3. | Open |
| E9 | Under 37+0 weeks, any labour session means call now. | Gestational age is worked out at the moment of evaluation. | Open |
| E10 | Red flags hold until the partner turns them off; turning one off takes effect at once. | Undo is the fix for a mis-tap. | Open |
| E11 | Contraction-driven advice rises immediately but only drops after 15 minutes of lower readings, showing "Contractions have eased. This advice stays up for 15 minutes in case they pick up again." It drops to the highest level seen in those 15 minutes. | **Question for Phase 3:** corrections (editing, deleting or undoing a contraction) are also held for 15 minutes, so fixing a mis-tap that triggered "call now" keeps it up with the easing note. Safe, but possibly annoying. | Open |
| E12 | Second or later babies, a previous fast labour, or a journey over 30 minutes need the pattern for 30 minutes, not an hour (see T6). | | Open |
| E13 | "Keep timing" (establishing) also covers a regular pattern up to 1.5× the advice interval (7.5 minutes by default). | | Open |
| E14 | Engine copy is instructional ("Time to call your maternity unit"), never diagnostic. A test checks every line against "established labour", "active labour", "you are in labour" and "diagnos". | Sources shown under each line: NHS signs of labour; RCOG for the cord prolapse wording ("Don't touch it. Help her onto her knees with her bottom up, or onto her left side with her hips raised."). | Open |
| E15 | The US profile says "your provider or labor and delivery unit" and 911. | | Open |
| E16 | If the phone and watch both press start within 20 seconds with no stop between, it's one contraction. | | Open |
