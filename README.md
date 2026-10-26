# Baby-tracker ("Mission Control")

A companion app for expectant fathers. Funny and cheeky during the pregnancy, deliberately sober during labour. Native iOS plus watchOS, UK/NHS guidance first.

Author: Liam Daly

## Where to start

- `docs/plan.md`: the approved research and build plan. Read this first. It holds every product decision (platform, region, theme, sharing model), the content schema, the go/no-go contraction engine thresholds, the watch sync design and the phased delivery order.
- `docs/research/01-pre-birth-preparation.md`: everything the dad and couple need to do before the birth, by week, with GOV.UK/NHS sources.
- `docs/research/02-labour-partner-support.md`: how a birth partner supports labour, stages and durations, when to call, pain relief, interventions, a 54-term midwife jargon glossary, rights and self-care.
- `docs/research/03-competitive-landscape.md`: existing dad apps, contraction timers, birth plan and glossary tools, tone evidence, gaps, regulatory risks and Apple Watch technical constraints.

## Status

Phase 0 (research and plan) complete. Next: scaffold the Swift package and Xcode project per `docs/plan.md` section B3, then build the engine (B5) with its test matrix. The app targets need a Mac with Xcode; the `MissionCore` package is designed to build and test on Linux as well.
