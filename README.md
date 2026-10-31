# Baby-tracker ("Mission Control")

A companion app for expectant fathers. Funny and cheeky during the pregnancy, deliberately sober during labour. Native iOS plus watchOS, UK/NHS guidance first.

Author: Liam Daly

## The theme

Mission Control. Dad is the **Flight Director**, the due date is **T-0**, contractions are **telemetry**.

| Character | Who | Voice |
|---|---|---|
| CAPCOM | The narrator | Dry, deadpan NASA comms. Reads out briefings and checklists. Has never actually held a baby. |
| The Commander | Mum | Never the butt of a joke. She's flying the ship; the app keeps steering dad back to supporting her. |
| The Payload | Baby | A growing capsule, with weekly size comparisons that aren't fruit (a Mars bar, a Game Boy, a rugby ball) next to the real cm and g. |
| Ground Control | The midwife and clinical team | Always competent. The glossary is "learning Ground Control's language". |
| Flight Surgeon | The serious voice | Takes over whenever content is medical and the jokes stop. Plain card, no theme chrome. Delivers every red flag. |
| The Veteran | A dad who's done it | "Things I got wrong" asides. |

Two modes: **T-minus** (the pregnancy: briefings, checklists, skills training, ranks and mission patches) and **Launch Day** (labour: contraction timer, when-to-call advice in NHS wording, triage call script, one-screen birth plan, jargon decoder). Labour mode forces humour off and is free forever.

## Where to start

- `docs/plan.md`: the approved research and build plan, including the amendments made after approval (section B13). Read this first.
- `docs/content-review-log.md`: everything a midwife or the content team still needs to confirm, including how the go/no-go engine interprets NHS wording.
- `docs/research/01-pre-birth-preparation.md`: everything the dad and couple need to do before the birth, by week, with GOV.UK/NHS sources.
- `docs/research/02-labour-partner-support.md`: how a birth partner supports labour, when to call, pain relief, interventions, a midwife jargon glossary, rights and self-care.
- `docs/research/03-competitive-landscape.md`: existing dad apps, contraction timers, tone evidence, gaps, regulatory risks and Apple Watch constraints.

## Layout

| Path | What |
|---|---|
| `Package.swift` | `MissionCore` (Foundation only: engine, events, content schema), `MissionContent` (bundled JSON), `MissionUI` (SwiftUI, Apple only) |
| `Sources/MissionContent/Content/{uk,us}/` | Versioned content JSON, one file per kind per region |
| `Apps/` | Thin iOS, watchOS and widget shells. The Xcode project is generated from `project.yml` |
| `Scripts/content-lint.py` | Content checks: provenance, `off` copy, duplicate IDs, forbidden diagnostic phrases, threshold bounds |
| `.github/workflows/ci.yml` | On every PR: Linux build, test and format lint, content lint, and on macOS SwiftLint, the app tests and the iOS and watch builds (Xcode 27.2) |

## Building

The package builds and tests anywhere Swift 6 runs, including Linux:

```bash
swift test
```

```bash
python3 -I Scripts/content-lint.py
```

The apps need a Mac with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`):

```bash
Scripts/gen-project.sh
```

Then open `MissionControl.xcodeproj`. The app tests (`Tests/MissionControlTests`) run in the `MissionControl` scheme on any iPhone simulator:

```bash
xcodebuild test -project MissionControl.xcodeproj -scheme MissionControl -destination 'platform=iOS Simulator,name=iPhone 17'
```

Simulator builds need no signing. For a device, put your team in `Configs/Signing.local.xcconfig` (gitignored) as `DEVELOPMENT_TEAM = ABCDE12345`.

## Status

- Phase 0 (research, plan, scaffold) complete.
- Phase 1 (go/no-go engine and event-sourced tap log) complete: `GoNoGoEngine`, `ContractionMetrics`, hysteresis, NHS-worded state copy, `EventLog` and `EventMerger`, with 26 scripted labours and property tests.
- Phase 2 (calendar and UK content v1) complete: `PregnancyCalendar` (gestational age, expected week of childbirth, qualifying week, deadlines and reminders), `ContentLoader`, `HumourResolver` and `GlossaryIndex` search; 134 checklist items in 12 modules, 94 glossary terms, 17 coaching cards, 12 story beats, 22 quiz questions and 35 badges.
- Phase 3 (iOS labour mode) and the watch's own timer are built. The first full review's safety fixes are being worked through before the redesign.

Where things are, in plain English (what works, the review's fixes, what's next, and what's waiting on the owner): [`docs/progress.md`](docs/progress.md), updated with each pull request.
