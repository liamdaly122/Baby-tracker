# Mission Control: synthesis of the ten-reviewer audit

> Review run on 26 October 2026: 10 independent reviewers, each finding checked by an adversarial verifier (critical ones by a second skeptic), then synthesised. 148 findings were raised; none were refuted outright, and corrections from verifiers marked "partly" have been applied. Engine simulations referred to as the "harness" lived in a temporary scratch folder and are not part of the repo.


Branch `feature/labour-mode`, repo `/Users/liamdaly/Baby tracker`. All findings below survived adversarial verification. Where a verifier marked a finding "partly", its correction has been applied and is noted. "Harness" refers to the scratch engine simulations in `/private/tmp/claude-501/-Users-liamdaly-Baby-tracker/3376e532-1f69-434a-bc7e-c03480e84e19/scratchpad/enginesim/`. Their sources are byte-identical to `Sources/MissionCore`, and the repo was not changed.

## Summary

The foundations are strong. The event-sourced tap log and pure go/no-go engine match the NHS triggers, the UK facts are accurate (SPP, EWC−99 days, SPL, Child Benefit, registration, R129, Lullaby Trust), the privacy design has no backend, analytics or account, and 107 to 121 core tests pass.

Labour mode is not yet safe to ship:

- The engine can say "No regular pattern yet" or "Keep timing" when the NHS call point is already met.
- Three missed taps restart the hour.
- A red flag hides every later change.
- Labour alerts can be silenced by Focus.
- Several call controls build wrong numbers or don't dial.

All four new requirements fit the concept, but each needs data and safety work first. The watch needs sync that agrees on the advice, not just the events. The birth plan needs a structured, versioned, co-authored model. The unit and crew need proper models and tested tap-to-call. The practice run must be isolated from real labour and must never stand between him and LAUNCH before 37 weeks.

The v2 prototype is a good layout reference, but its labour engine, flag set, call buttons and colours are unsafe to copy. Contrast-tested tokens, true black, 56pt controls, accessibility and a snapshot harness must come before the reskin.

Beyond safety, the app needs a path for loss, admission, neonatal care and false alarms, HOLD rules that don't blame him for her choices, and 38 weeks of reviewed briefings.

On delivery, the mac CI job never runs on PRs, the WIP branch fails lint, the app layer has no tests and the stores have no schema versioning. There is also no hazard log or intended-purpose statement, and the B10 schedule no longer fits.

## The four new requirements

### 1. Apple Watch times contractions in labour mode

**Confirmed.** The watch was already in scope (Phase 5, B6), and the owner's requirement makes it the primary timer.

**What exists.** B6 plans a standalone watch with its own LabourStore that runs the engine locally. Taps go by sendMessage plus transferUserInfo, starts within 20 s from two devices are coalesced, and the plan includes a long-press for red flags, a Water Lock prompt, a complication reload after each tap, an iPhone Live Activity mirrored to the Smart Stack, and no runtime sessions. Built so far: the MissionCore event log, Lamport clock and EventMerger. The watch target is a 25-line shell on watchOS 10.0. The session logic, models and profile live only in the iOS target. The prototype has no watch screens.

**Recommended design.**

1. Fix MissionCore first:
   - make advice a pure replay of the merged log (SYNC-01);
   - coalesce by clock time (SYNC-03);
   - record tap intent and the sender's seenSeq (SYNC-04);
   - add a contiguous per-device seq (SYNC-05);
   - add a shared LabourSessionCore (arch-04);
   - push a MissionBrief on every planning change, so the watch can launch, apply the preterm rule and call (SYNC-06, WPR-06, NRC-12).
2. Run a hardware spike, with "no more than 2 taps from wrist raise to start" as the acceptance test (TCI-09).
3. Raise the target to watchOS 11. Add Double Tap, an interactive Smart Stack widget, a complication deep link, an Action-button Shortcut, and a pre-flight step that sets Return to Clock to 1 hour.
4. Drop Water Lock. Use pages for the timer, Call and Flags. Watch launch is press-and-hold.
5. Use distinct haptics, time-sensitive alerts with deterministic shared identifiers, and a battery plan.
6. Design the watch frames in the bespoke tokens before the phone reskin. The phone shows a "Timing on your watch" state and a comms-link chip.
7. Keep breathing haptics visual-only in v1.

**Risks.**

- Divergent advice between devices, and a false callNow held for 15 minutes.
- Double counting, lost taps and phantom open contractions.
- Gaps that high-water marks can't detect, and watch-first sessions that never merge.
- An unbriefed watch with no preterm rule and no numbers.
- The clock face returning between contractions.
- Battery, the complication budget and the Live Activity's 8-hour cap.
- Focus silencing alerts.
- Clock skew is normally only seconds, so false over-2-minute contractions from skew are an edge case.

### 2. Birth plan built in advance, revised, and opened in labour

**What exists.** BirthPlanRecord is five free-text headlines, a sectionsJSON blob and one updatedAt, which is bumped on every close. The stock editor writes straight into the live record. The labour Plan tab links to the full editor and shows generic coaching. B3 planned answers[], and B4.5 plans a Phase 6 builder, PDF and "what changed" prompts. The checklist has 11 plan.* items from weeks 20 to 34. The prototype's sample plan is read-only, and its lock rule blocks the theatre, cord, feeding, photos and plan-changes items until weeks 30 to 32.

**Recommended design.** Fix the model before the reskin, under a VersionedSchema:

- answers with sectionID, choiceIDs, freeText, who decided, and changedAt;
- an ordered top five;
- "if plans change" branches;
- reviewedAt and herConfirmedAt, kept separate from changedAt;
- BirthPlanSnapshot revisions, so "what changed" is a diff;
- birthplan.json content with provenance, adding students present, induction views, environment, his role, access needs, past trauma, interpreter and preferred name;
- draft editing with Save and Discard.

The Flight Plan becomes a top-level destination, open from about week 12 with no locks. A "Read it with her" mode records her confirmation, and "Ask her tonight" answers can be saved into the plan.

Review cadence: draft at 20 to 27 weeks, revise at 32, one-pager by 36, a post-36-week-appointment step, and an induction review at 39 to 41. Events (induction booked, breech or planned caesarean, unit change) re-open it.

In labour the plan is read-only and large type, shows "last confirmed with her", and offers Plan-changed chips. The empty state asks him to get her one or two wishes, with no editor. Share-outs are PDF and plain text. The plan never goes into CloudKit.

**Risks.** His unagreed draft gets carried into labour. A migration loses months of data, and a planning-store failure currently takes labour mode down too. A spurious updatedAt. Typing mid-labour. Guideline 5.1.3(ii) for health data in iCloud.

### 3. Saved birth centre or hospital and people to call, with tap-to-call

**What exists.** One unitName and triagePhone. A digit filter that builds wrong tel: URLs. One Call button plus 999, and no 111. No contacts model. No birth setting in the engine. The prototype hard-codes LGI, and its Call tab copies the number instead of dialling. The review log says details are user-entered and never hard-coded.

**Recommended design.**

- **Now:** a tested PhoneNumber type in MissionCore, and a "Can't get through?" row (try again, labour ward, 111, 999).
- **Before the reskin:** a MaternityUnit or BirthPlace model (kind, triage, ward and switchboard numbers, address, coordinates, entrances, parking, peak and night travel, verification) and a CrewContact model (roles, CNContactPicker, copied values). Add plannedPlace, plannedMode and birthSetting so the home-birth rules and copy apply.
- **Selecting a unit:** MapKit fills name, address and journey only; its number is offered as the switchboard, never as triage. Triage numbers are confirmed against her notes, stamped "checked [date]", and re-checked at 34 to 36 weeks. A bundled directory is allowed only for research-verified entries with provenance.
- **Call tab order:** 999 (always visible, first in call999), unit card, "Can't get through?", script, Getting there, then Crew as secondary. Every Call control dials.
- **Elsewhere:** an emergency card in the App Group for StoreFailureView, the watch and the Live Activity. Data auto-ticks the checklist. A comms plan and broadcast list (Messages pre-filled, never auto-sent). A "Send her Ground Control" .vcf.

**Risks.** Wrong, switchboard or stale numbers. Bundled clinical data going out of date. Calling family before the unit. Home-birth copy errors. A live ETA making the engine vary with traffic. Third-party data and 5.1.1(iii)/5.1.2(v). Regressions copied from the prototype.

### 4. Practice run under the launch cover until the birth window

**What exists.** Nothing is planned, and "Dry Run" means the drive. The cover is the only route into labour mode. LabourSessionModel allows one session, resumes any unended session, writes the real store and always notifies. Under 37+0 every session is callNow. The injected `now`, the in-memory container and the prototype's seeded hour make a drill feasible.

**Recommended design: one cover, two keys.** This reconciles labourreq, ux, design, content and privacy.

- LAUNCH is the same full-size red key at every gestation, one tap after lifting the cover, never week-gated.
- From week 30 to 36+6 a smaller blueprint "Run the drill" key sits on the raised lid.
- At 37+0 (the engine's term rule) the drill moves to the Training hangar behind an "Is she having contractions now? Then launch instead" gate.
- Rejected options: swapping LAUNCH for practice before 37 weeks, a "real or practice?" question on the real path, and giving practice the primary key before 37 weeks. The rehearsed gesture must open real labour mode in a preterm labour.
- Before 37 weeks the cover reads "Labour started? Any week. Lift to launch". Window wording only ever describes when births are most likely.

**Real path.** The session starts on the tap. Skip the liftoff under 37 weeks, with unknown gestation, with a red flag on, or under Reduce Motion, VoiceOver or Low Power Mode, and open on the call card. Otherwise cap the liftoff at about 3 s with tap-to-skip. Ask for permission earlier. Show the disclaimer the first time the cover is lifted, then as a non-blocking line.

**Drill.**

- A separate DrillModel: in memory, simulated clock, scripted 39+0 profile.
- No notifications, no Live Activity, and no real sync (tagged; live sendMessage only).
- No dialling: "In a real labour this rings [unit]".
- Never restored after the app is killed.
- Its own "static fire" visual world: a SIMULATION tape, "SIM:" headlines, cyan or blueprint tints, and a VoiceOver "Practice" prefix.
- A one-tap "Real labour? Launch now" bar. Any real LAUNCH ends a drill.
- Accepts scripted cues only. The start card asks about real symptoms.

**Drill content.** About 8 minutes in seven chapters: pre-flight, wrist drill, fast-forward, curveball, the call, getting there, debrief. The script is JSON with provenance and midwife sign-off. Pre-flight checks permissions, Time Sensitive, the watch brief, complication, battery and Return to Clock, verifies the number, reads the plan to her and flags empty crew seats. Passed checks tick the matching checklist items and earn a "Simulator certified" patch. Suggest doing it at 35 to 36 weeks with her, offer a refresher if done before 33, and add an "if she's alone" variant.

**Risks.** A preterm labour reaching a game. A forgotten drill swallowing the real LAUNCH. Practice taps in the real log. Real-looking drill alerts and real dialling. Practising on real Braxton Hicks ("practice contractions"). Wall-clock views blocking an accelerated clock. A celebratory liftoff delaying the call card.

## Prioritised actions

Ordered by user safety, then release-blocking, then the owner's goals, then effort.

| # | Action | Severity | Effort | When | Sources |
|---|---|---|---|---|---|
| 1 | Stop the engine sounding reassuring when the NHS call point is met (one-sided frequency test, recent window, monotonic guard, NHS headline once met, no rounding across the threshold, clamp thresholds, timeline fixtures) | high | M | now | CS-01, PRT-02, content-10, CS-12, CS-11, CS-15, TCI-13 |
| 2 | Handle missed taps and forgotten stops (latch callTriage, "still coming?", missed-tap gaps, forgotten stop → new start with quick fix) | high | M | now | CS-02, arch-01 |
| 3 | Freeze gestation at session start; unknown due date asks "37 weeks or more?" | high | S | now | CS-10, WPR-01 |
| 4 | Make alerts reach him: Time Sensitive, permission before LAUNCH, settings check, prefix-scoped namespaced IDs, didReceive routing | high | S | now | CS-04, SYNC-02, arch-03, TCI-05, arch-12 |
| 5 | Correct tap-to-call (PhoneNumber type) and add "Can't get through? Call 111" | high | S | now | NRC-01, arch-10, TCI-14, NRC-02, PRT-08 |
| 6 | Rework red flags ("I've called them", alert on new reasons, sticky flags, bleeding definition, missing flags) and triage-script accuracy (waters time, sustained time, strength) | high | M | before reskin | CS-03, CS-09, CS-06, CS-07 |
| 7 | One cover, two keys: isolated drill, fast unchanged real LAUNCH | high | M | before reskin | CS-05, SYNC-09, arch-06, WPR-02/03/04/05/07/08/11/12/13/15, PRT-01, PRT-11, content-02, TCI-04, SWUI-03, SWUI-04, ux-05, NRC-13 |
| 8 | Binding reskin rules: prototype is layout only; every Call dials; 999 one tap and always visible; flags from RedFlag.allCases; all states designed | high | S | before reskin | ux-01, NRC-09, CS-13, SWUI-02, TCI-07, ux-10, content-14 |
| 9 | Contrast-tested, true-black, 56pt, Dynamic Type, VoiceOver, redraw budget and snapshot foundations | high | M | before reskin | SWUI-01, content-04, SWUI-05, content-08, content-07, SWUI-08–12, SWUI-14, SWUI-15 |
| 10 | Loss, admission, neonatal and false-alarm routes; store the birth outcome; discreet early mode | high | M | before reskin | ux-02, content-01, PRT-09, arch-07, content-15 |
| 11 | Independent stores, VersionedSchema, emergency card, surfaced save failures | high | M | before reskin | arch-02, TCI-01, arch-13, SYNC-13, arch-14 |
| 12 | Intended purpose, MHRA note, hazard log, CSO, earlier midwife review, privacy policy, manifest, delete-everything, UK-only, insurance | high | M | now | PRT-03/04/05/06/07/10/12/14/15, TCI-10, TCI-15 |
| 13 | CI on every PR, branch protection, pinned Xcode, split the WIP commit, app test target, B14 re-sequence | high | S | now | TCI-02, TCI-11, TCI-12, TCI-06, arch-15, TCI-03 |
| 14 | Shared LabourSession in MissionCore with frozen LabourSetup and LabourScreenState | high | L | before reskin | arch-04, arch-05, SYNC-06, arch-09 |
| 15 | Sync that converges on advice: deterministic replay, completeness gating, clock-time coalescing, tap intent, contiguous seq, MissionBrief | high | L | now (core) | SYNC-01/03/04/05, CS-08, TCI-08, arch-09, WPR-06, WPR-11, NRC-12 |
| 16 | BirthPlace and CrewContact models, verified numbers, Call tab order, comms plan, share-outs | high | M | before reskin | arch-08, NRC-03/04/08/10/11, ux-03, CS-14, content-03, PRT-08, SWUI-07, ux-09 |
| 17 | Structured, versioned, co-authored birth plan; read-only in labour | medium | M | before reskin (model), Phase 6 (builder) | arch-11, NRC-05/06/07, ux-04, content-09, PRT-13, PRT-06, NRC-14 |
| 18 | Watch as primary timer: hardware spike, watchOS 11, Double Tap, Smart Stack, pages, haptics, battery, Live Activity intents | high | M | Phase 4-5 (design frames before reskin) | SYNC-07/08/10/11/12/14, WPR-09, WPR-10, TCI-09, ux-06, SWUI-06, WPR-14 |
| 19 | Fair stage gates and HOLD, ported to tested MissionCore | high | M | Phase 6 (port before reskin) | ux-07, ux-08, content-06, TCI-07, SWUI-13, ux-15 |
| 20 | 38 weeks of reviewed briefings and the holistic strands; home layout, countdown, weekly ritual | medium | L | start content now; Phase 6 | ux-11, content-05, ux-12, content-11/12/13/15, ux-13, ux-14, ux-15, TCI-15, PRT-15 |

### How conflicts between reviewers were resolved

- **Cover layout before 37 weeks.** The proposals ranged from LAUNCH primary with a small drill key (WPR-03), to two equal buttons (content-02, CS-05), to practice primary (SWUI-04, ux-05). I chose LAUNCH unchanged and primary at every gestation, with the drill secondary. The threshold is 37+0, not 39.
- **Liftoff length.** Proposals were 2 s (ux-05) and about 3 s (WPR-04, SWUI-03). I chose about 3 s, skippable, and skipped entirely under 37 weeks, with unknown gestation, with a red flag, or under accessibility and Low Power settings.
- **Disclaimer.** WPR-04 wanted to move it wholly to onboarding, but B8 requires one at labour-mode entry. Resolution: show it the first time the cover is lifted, then as a non-blocking line in orbit (PRT-11).
- **999 placement.** Always visible on the Call tab, and first in call999 (reconciles ux-01 and NRC-09).
- **Watch red flags.** A visible page instead of B6's long-press (SYNC-12, WPR-09).
- **Unit numbers.** User-entered or user-confirmed. An optional bundled directory only with provenance and a confirmation step (reconciles NRC-08, content-03 and ux-03).
- **Privacy label.** With no backend and no sync, nothing is "collected", so no Health or Contacts declaration is needed (NRC-14 correction, PRT-05).
- **Breathing haptics.** Visual only in v1; prototype later (SWUI-06, WPR-14).

## Findings by dimension

### Clinical safety and the go/no-go engine

The rule set matches the NHS triggers. Urgent bounds can only be tightened, and hysteresis never shows less than the raw contraction or flag level. The risks are in what follows.

**CS-01 Frequent but uneven contractions never count as "regular"** (high, M, now; confirmed, second opinion high rather than critical)
- Evidence: GoNoGoEngine.swift:139-150 gates both callTriage and establishing on `regularity <= regularityCV` (0.35). ContractionMetrics.swift:64-66 computes a symmetric IQR/median.
  - Alternating 3/5 min gives CV 0.50 and early. Alternating 2/4 gives CV 0.67 and early. A 2-3-4-5 cycle gives CV 0.43 and early.
  - Alternating 2.5/5 stays early for 2 h. A 2,2,5 pattern (median 120 s, CV 1.5) stays early.
  - Every 7 min then every 4 min drops to early/noRegularPattern at 90 min and reaches callTriage only at 99 min.
  - Random 2 to 5 min gaps reach callTriage at 60 min, then fall back at 107 and 112 min.
  - The early copy is "No regular pattern yet. Rest, eat and drink". The NHS trigger is "every 5 minutes or more often" (research 02:59). T5 and E4 are Open, and plan B5 specifies the same rule.
- Problem: being more frequent can read as less urgent, and a labour that is speeding up is penalised by its own slower start. 6-in-10 does not catch these patterns.
- Second opinion: the strictly alternating fixtures are synthetic, and realistic random logs mostly hold callTriage. The early copy says to call any time she's worried. "Regular" is itself undefined (T5), and the app is pre-release. The finding still blocks labour-mode release.
- Fix: a one-sided percentile test (P75 to P80 of intervals at or under adviceIntervalSec counts as meeting the call rule); keep the spread test only for the building band; compute statistics over the last 20 to 30 min; add a guard that a log which has only become more frequent can't move lower; add fixtures for these patterns and send them to the midwife with T5.

**CS-02 Three missed taps reset the hour** (high, M, now; confirmed)
- Evidence: ContractionMetrics.swift:50-55 (stale after 3x median) and 137-148 (the segment splits at any gap over 3x median). LabourState.swift:135 (gapSplitFactor 3.0). Fixture 22. Harness scenario A: callTriage at 60 min, establishing/patternNotYetSustained at 148 min, and no callTriage again before 196 min. Scenario A2: a 25-min gap gives early/notEnoughContractions at 92 min. E3 is Open, and the plan only tests a 50-min gap.
- Problem: "nothing logged" is treated as "no contractions", and the copy "Rest, eat and drink" describes the log, not her.
- Fix: latch the callTriage time and keep it in the script; ask "Nothing logged for 14 min. Still coming?"; treat gaps near 2x, 3x or 4x the median as missed taps and offer "Add the ones I missed"; drop only after a positive "they've eased" or a long quiet period; add fixtures for 2, 3 and 4 missed taps and a 25-min gap.

**CS-03 After a red flag or the preterm rule, later contraction changes are hidden and raise no alert** (high, M, before reskin; confirmed)
- Evidence: GoNoGoEngine.swift:71-83 shows only reasons at the winning level. LabourAlertPlanner.swift:40 and :57 alert only when the state rises. Harness scenario C: after waters break, the state stays callNow [watersBroken] for 100 min while the contraction advice alone reaches callTriage at 80 min, with no alert. Scenario M: 6-in-10 is appended with alert: none. Research 02:24 (term PROM: about 60% labour within 24 h).
- Problem: the banner is pinned for up to a day and stops meaning anything, and it can't represent "stay home and call back". Every preterm session is pinned the same way.
- Fix: an "I've called them" TapEventKind with what they said; always show the contraction line under a flag; alert on any new reason code at callNow or above; a 24 h-since-waters reminder; three tests (flag then pattern, flag then 6-in-10, flag then a contraction over 2 min).

**CS-04 Labour alerts are ordinary notifications** (high, S, now; confirmed)
- Evidence: ThresholdNotifier.swift:52-60 sets no interruptionLevel. There is no Time Sensitive or critical entitlement. requestAuthorization discards its result. plan.md:107 and research 02:107 advise sleeping in shifts. B6 makes scheduled notifications the only background path.
- Problem: a Sleep Focus at 3am holds back "Time to call" and the 2-minute nudge, and nothing tells him alerts are off.
- Fix: .timeSensitive for callTriage and above, plus the entitlement; consider applying for Critical Alerts for 999; check authorisation at LAUNCH and show "Alerts are off"; send a test alert in the practice run; the same for the watch.

**CS-05 The practice run must never stand in for real preterm labour or leak into real advice** (high, M, before reskin; confirmed)
- Evidence: the cover is the only route (launch.js:44-47, labour.js:353-356). Preterm is callNow (GoNoGoEngine.swift:158-160). About 8 in 100 babies are born early (research 04:28). LabourSessionModel.swift:89-90 has `guard session == nil`. LabourSessionRecord has no practice marker. ThresholdNotifier posts for any session.
- Problem: a game instead of "Call now" in preterm labour; a forgotten practice blocks a real launch; practice writes real snapshots; drill alerts look real.
- Fix: two separate controls after lifting; the real path applies preterm at once and skips the wait; practice on a simulated clock in its own in-memory store with a PRACTICE banner, no real notifications and no snapshot; a real launch ends practice; script the drill with the real engine; test a real launch with a practice open. (Layout resolved above as one cover, two keys.)

**CS-06 Red-flag gaps, and "Heavy bleeding" (999) is undefined** (medium, M, before reskin; partly)
- Evidence: LabourState.swift:58-73 has 8 flags. Research 02:79 lists constant severe pain, GBS-positive with waters gone, and labour before a planned caesarean. There is no head-visible trigger. LabourRootView.swift:141-142 and StateCopy.swift:87-88 just say "Heavy bleeding". Research 04:22 gives the NHS 999 definition (soaks a pad soon after, or bleeding with severe pain, faintness or dizziness). Research 04:26 covers pre-eclampsia signs.
- Fix: toggles for constant severe pain (callNow), head visible (999 with emergency-birth steps) and severe headache, vision changes or feeling very unwell (callNow); the NHS definition on the Heavy bleeding toggle; GBS and planned caesarean as structured fields that change the copy; sourced through research per B13.10; extend the tests.
- Correction applied: the flags fully cover the NHS signs-of-labour list, and GBS plus waters already gives callNow. Medium. The clearest fix is the bleeding definition.

**CS-07 The triage script overstates how long the pattern has held and uses the tap time as waters time** (medium, M, before reskin; partly)
- Evidence: ContractionMetrics.swift:70-74 measures from segment.first. Harness run3: after 2 h every 10 min and then 31 min every 4 min, it prints "Every 4 min … for 151 min". TriageScript.swift:132 uses the toggle time for waters. Line 85 adds the Frequency line only if the reason is shown (a 999 flag hides it). Line 83 hard-codes "in the last hour". Strength and pain are never captured (research 02:93).
- Fix: track time at or under the interval separately ("every 4 min for the last 31 min, about every 10 min for 2 h before"); an editable "waters went at"; the Frequency line from metrics; the real window length; a strength tap; tests.
- Correction applied: the overstatement pushes towards earlier assessment, and triage talks to her directly. The waters time, which drives the 24 h PROM induction, matters most. Medium.

**CS-08 Watch timing: phone and watch can show different advice, and mixed-device timestamps corrupt durations** (medium, L, Phase 4-5; partly)
- Evidence: B6 runs the engine on each device. Hysteresis depends on a per-device `previous` (GoNoGoEngine.swift:9, :68), and a nil previous returns raw advice (Hysteresis.swift:32-34). A stop takes the stopping device's clock (EventLog.swift:74-78). An end before its start is excluded (ContractionMetrics.swift:115-120). Harness L: 90 s skew gives needsEdit and early.
- Fix: share the snapshot or, better, replay hysteresis from the log; estimate clock offset at each sync or keep a contraction's start and stop on one device; flags and 999 one gesture away on the watch; test skew and evaluation cadence.
- Correction applied: the divergence of held state is the real issue. Apple-device skew is normally a few seconds, so 90 s is an edge case. Medium.

**CS-09 One tap on a lit red flag clears it and drops "Call 999 now" instantly** (medium, S, before reskin; confirmed)
- Evidence: TimerTab.swift:85-88 and 121-124 toggle with `!active.contains(flag)`. Flags hold only while on (GoNoGoEngine.swift:153). The undo chip lasts 10 s (LabourSessionModel.swift:26).
- Fix: make flags sticky with a "Tapped by mistake? Clear it" confirm; keep cleared flags in the history and script; keep 999 on screen for a minute after clearing a 999 flag; test that one tap never lowers the state.

**CS-10 Preterm "Call now" vanishes at midnight at 37+0, and a missing due date switches the rule off** (medium, S, now; confirmed)
- Evidence: PlanningModels.swift:70-77 recomputes gestation at each evaluation. There is no hold (GoNoGoEngine.swift:158-160). PregnancyCalendar.swift:58-60 uses Calendar.current. Harness E: callNow at 36+6 23:59 becomes early at 00:00. GoNoGoEngineTests:54-58 asserts that unknown gestation never triggers.
- Fix: store gestation at session start; ask at LAUNCH if it's unknown; add midnight-crossing and missing-date tests.

**CS-11 Thresholds aren't clamped where they're used, and the editor's footer overstates its guarantee** (low, S, now; partly)
- Evidence: Thresholds.swift:23-59 has public mutable fields. Session thresholds are decoded raw (LabourModels.swift:34-36). applyThresholds accepts any profile. The urgent look-back uses patternWindowSec (ContractionMetrics.swift:44-45). ThresholdEditor.swift:32-34 and :41-44.
- Fix: `public private(set)` with a clamping initialiser; re-clamp in evaluate; a fixed 60-min urgent look-back; mark delaying edits "only if your midwife told you" and show "Using your midwife's numbers"; tests with hostile profiles.
- Correction applied: every created profile is clamped today, the minimum window is 30 min, the footer is literally true of the urgent rules, and the bounds are as B5 planned. Low.

**CS-12 State and alert copy contradicts itself in "Keep timing", lacks 111, and the nudge is wrong in 999 states and the US** (medium, S, before reskin; confirmed)
- Evidence: StateCopy.swift:27-32 uses one establishing detail line for both reasons, shown with :57-58 ("Regular, every 4 min … so far"). The hour is app-defined (thresholds.json:47). Research 02:59 says call 111 if the unit can't be reached, but CallTab has no 111. LabourAlertPlanner.swift:73-78 hard-codes "call your maternity unit now". Harness K: a US call999 state still gets the maternity-unit nudge. StateCopy.swift:91-93 says "Contractions have eased" after a mis-tap is fixed (E11).
- Fix: a detail line for each reason with a countdown from nextReviewAt; "Can't get through? Call 111" plus a button; build the nudge from StateCopy by region and state and skip it in call999; separate copy for drops caused by edits; include planner copy in the forbidden-phrase test.

**CS-13 Prototype evaluate() would teach the wrong 999 set** (medium, S, before reskin; confirmed)
- Evidence: body.html:139-147 has 6 flags (no cordVisible or seizureCollapse). labour.js:85-87 gives 999 only for urge to push or heavy bleeding. :96 checks only an open contraction over 2 min. There are no easing, stale or needs-edit states. :135-138 shows call only when hot. renderCall :302-320 has no 999. :29 hard-codes the unit.
- Fix: layout only; flags from RedFlag.allCases; banner from EngineOutput; design all levels plus easing, needs-edit and stale; 999 reachable everywhere; unit from the profile; a UI test that every RedFlag has a control.

**CS-14 Saved unit and contacts need validated clinical numbers, and the engine has no birth setting** (medium, M, Phase 6; confirmed)
- Evidence: PlanningModels.swift:98-101 (isNumber accepts "½"; no length check). CallTab.swift:50-66 shows a form mid-labour when no number is saved. LabourProfile (LabourState.swift:103-126) has no birth setting. StateCopy.swift:35 says "Phone before you set off". plan.md:101 gives the home-birth call-out.
- Fix: the picker stores triage, labour ward and regional fallback; ASCII validation and a "ring it once" task at 36 weeks; personal contacts visibly secondary, with the state-driven primary button always 999 or the unit; birthSetting with home-birth copy and rules; travel stored as worst case, not a live ETA.

**CS-15 Tests are single-moment snapshots** (medium, M, now; partly)
- Evidence: LabourFixtureTests.swift:7-43 and 107-113 evaluate once per fixture. The property test (GoNoGoEngineTests.swift:218-226) checks only state ≥ flag. Only the latest-starting contraction can be open (ContractionMetrics.swift:48, 121-131; LabourSessionModel.swift:71-74), so a back-dated start becomes needsEdit and can't be stopped.
- Fix: timeline fixtures (taps, toggles, evaluateAt list, expected state, reasons and alerts) for every case above; property tests that state ≥ max(raw, flag) with random previous snapshots and that the planner never schedules a lower state; reject a tap earlier than the same device's previous tap.
- Correction applied: basic hysteresis is unit-tested (rise, dwell, cancel, highest target, replay). What's missing is timelines, these edge cases and the invariants.

### Event log, sync and Apple Watch timing

**SYNC-01 Advice depends on delivery order** (high, L, now; partly, downgraded from critical)
- Evidence: LabourSessionModel.swift:188-204 feeds back and saves the snapshot on every refresh. Hysteresis.swift:35-48 raises at once and drops after 900 s. ContractionMetrics.swift:93 has no forgot-stop cap on hasOpenOverUrgent. recordBackdated is DEBUG-only (:262-268). EventMerger.swift:6-8 has no concept of a batch. ThresholdNotifier.swift:25-35 posts when the app isn't active. plan.md:312 claims convergence. Simulation: events taken in one at a time give callNow [openContractionOverUrgentDuration], still held 10 min later; the same log as one batch gives establishing.
- Fix: advice as a pure function (replay hysteresis over the merged log, snapshot only as a cache keyed by the version vector, checkpointed); completeness gating (latest seq per sender; an open contraction "awaiting sync"; hold immediate alerts about 30 s); a single core ingest(batch); property tests over random splits.
- Correction applied: no sync path exists yet (the watch is a Phase 0 shell). This is a MissionCore design defect to fix before Phase 5. The rise half fails safe (B13.3), though an alert held for 15 minutes is still a problem. The other half is divergence, not a missed rise.

**SYNC-02 Labour alerts may not reach him** (high, M, now; partly)
- Evidence: ThresholdNotifier.swift:19-21 requests [.alert, .sound]; :52-59 sets no interruptionLevel. The entitlements hold only the App Group. :34 builds IDs from a UUID. :31-33 gives only a phone haptic for an in-app rise. :49 calls removeAll on end. Apple docs on Time Sensitive and forwarding; DTS thread 765669 (use the same identifier on both devices; the watch waits about 13 s for the phone's alert). plan.md:314.
- Fix: deterministic IDs generated in MissionCore (`labour.<sessionID>.<kind>.<state>.<minute>`) scheduled by both devices; cancel by session prefix; the Time Sensitive capability on iOS and watch; .timeSensitive for callTriage and above and the nudge; read timeSensitiveSetting in pre-flight; no plan for Critical Alerts; willPresent and distinct haptics on the watch; stale-alert wording ("If you've already stopped the timer, ignore this").
- Correction applied: double buzzes and stale forwarded alerts are Phase 5 risks, and wiping admin reminders is a Phase 6 risk. The Time Sensitive gap applies today.

**SYNC-03 Coalescing follows Lamport order, so double-timed contractions are counted twice once the clocks drift by 2** (high, M, now; confirmed)
- Evidence: EventLog.swift:62-73 coalesces only with latestOpenIndex at processing time. Processing order is TapEvent.swift:71-76. EventLogTests.swift:73-84 covers only equal clocks. Simulation: 16 contractions with Lamport offset 2 or 3 give 32 contractions and callNow (tooManyInTenMinutes); 8 contractions at 5 min with offset 3 give 16 and early.
- Fix: a pre-pass grouping starts by `at` within 20 s, or overlapping, across devices, with the canonical ID and an alias map; a property test with random offsets, interleaving and ±5 s jitter.

**SYNC-04 A tap made on a stale screen is silently dropped, and the next tap opens a phantom contraction** (high, M, now; confirmed)
- Evidence: LabourSessionModel.swift:122-128 decides stop or start from the device's own view. EventLog.swift:74-78 ignores a stop on a closed contraction. Simulation result: [0-50, 355-open], so the real 300-355 contraction is lost and callNow plus the nudge follow. The reverse race gives a 1-second contraction.
- Fix: every tap carries intent and seenSeq; reducer rules (a stop on an already-closed, unseen target becomes a start; a stop less than 10 s after an unseen start counts as a duplicate start); stale-view tests; "synced 4 s ago" on the watch.

**SYNC-05 High-water marks can't spot gaps, and the convergence test hides it** (medium, S, now; partly)
- Evidence: EventMerger.swift:16-27 ("tells a peer exactly which events it's missing"). observe() jumps the clock (TapEvent.swift:92-94). EventLogTests.swift:258-267 merges `rest`. plan.md:310 (transferUserInfo is FIFO).
- Fix: a contiguous `seq: UInt64` per device, saved and defaulted when decoding; a version vector of the highest contiguous seq; `missing(from:)`; prefix acknowledgement; a saved outbox; the latest seq in every message; rewrite the test without `rest`.
- Correction applied: B6 queues every event, so permanent loss needs an unbuilt ack design or a lost system queue. Medium.

**SYNC-06 Session identity, thresholds, profile and session end sit outside the log, and the session logic is out of the watch's reach** (high, L, now; confirmed)
- Evidence: LabourSessionModel.swift:89-98 creates a session UUID per device; :276-279 filter by sessionID; :114-118 change thresholds locally; :100-111 end locally. LabourModels.swift:7-27 has no mission field. project.yml:59-68 (the watch gets only MissionCore and MissionUI). plan.md:312. GoNoGoEngine.swift:158 needs gestation. The unit and phone exist only on the phone.
- Fix: a Codable MissionBrief (missionID, a real session ID created in advance plus practice IDs, due date, parity, fast labour, travel, region, thresholds, unit, contacts, plan headlines, version) pushed by updateApplicationContext; lifecycle events (launch, thresholdsChanged, splashdown) and session-alias rules; LabourSessionCore in MissionCore with an EventStore protocol and a shared SwiftData adapter; "Not briefed: open Mission Control on iPhone".

**SYNC-07 One-tap wrist timing isn't designed** (high, M, Phase 4-5; confirmed)
- Evidence: plan.md:314. Apple frontmost-app state (2 minutes by default, user-adjustable per app). Double Tap needs watchOS 11 and a Series 9 or Ultra 2. Interactive widgets need watchOS 11. Third-party Action-button support is for workout and dive apps only, but the button can run a Shortcut. project.yml:9 targets watchOS 10.0.
- Fix: watchOS 11 (consider 26 for a ControlWidgetButton); `.handGestureShortcut(.primaryAction)`; a relevant interactive Smart Stack widget with a ToggleContractionIntent; a complication to the button; an App Shortcut with openAppWhenRun false; a Return to Clock pre-flight; never a faked workout.

**SYNC-08 The 8-hour Live Activity restart from BGAppRefreshTask won't work, and intents from another process leave the engine stale** (high, M, Phase 4-5; confirmed)
- Evidence: plan.md:316 and :369. Apple: a Live Activity can be started from the background only through a LiveActivityIntent; 8 h and 4 KB limits. LabourSessionModel.swift:78-98 and 270-284 hold events in memory. After 8 h an ended activity can stay stale on the Lock Screen for up to 4 h.
- Fix: Start, Stop and Undo as LiveActivityIntents calling the core's ingest; restart inside a tap's intent after about 7 h, with the 7h30 notification action as a fallback; ContentState under 4 KB with staleDate = nextReviewAt; Double Tap on the activity; the watch's own widget as the phone-independent path.

**SYNC-09 The practice run needs its own session mode, must never hide the real LAUNCH before 37 weeks, and is the natural watch pre-flight** (high, M, before reskin; confirmed)
- Evidence: LabourModels.swift:7-27 has no mode. LabourSessionModel.swift:78-86 resumes any session; :90 allows one. ThresholdNotifier.swift:49. termDays 259. `now` is injected (:35, :52). remainingComplicationUserInfoTransfers is 0 if the complication isn't on the active face.
- Fix: `mode: .real | .practice(scriptID)` with separate IDs and notification namespace, never merged; before 37+0 practice is offered with an always-visible "This is real"; a 10x time-compressed clock; a watch drill measuring delay and checking link, permissions, complication, battery and Return to Clock.

**SYNC-10 No battery plan for a 24-hour-plus labour** (medium, M, Phase 4-5; confirmed)
- Evidence: Apple battery figures (Series 12 up to 24 h or 38 h in Low Power; SE 3 up to 18 h; Ultra 4 up to 50 h). plan.md:85-92. TimerTab.swift:41 redraws every second.
- Fix: no HealthKit; Text(timerInterval:); once a minute under isLuminanceReduced; widget reloads only on starts and state changes; battery level in the sync summary; a 20% warning; suggest Low Power Mode; a watch charger in the bag; Live Activity ownership handed to the phone when the watch is critical.

**SYNC-11 Per-tap complication reloads would use up the 50-a-day budget** (medium, S, Phase 4-5; partly)
- Evidence: plan.md:318. Apple: 50 transfers a day, then fallback to transferUserInfo.
- Fix: a self-updating timeline with `Text(lastStart, style: .timer)`; transfers only on starts and rises after checking the remaining budget; local reloads when the watch is tapping; "as of hh:mm" when stale.
- Correction applied: the plan doesn't name the API. Only phone-originated taps use the budget, and WidgetKit's own reload budget is a further reason for a self-updating timeline.

**SYNC-12 Watch screen spec** (medium, M, Phase 4-5; confirmed)
- Evidence: plan.md:320 (long-press, Water Lock). Water Lock disables touch until the Crown is held. Frontmost apps can play haptics. openSystemURL supports tel: and sms:.
- Fix: Page 1 a full-screen toggle, Text(timerInterval:), a state ribbon and a 10 s Undo, with the Crown scrolling history; Page 2 Call from the brief, brought forward at callTriage and above, with a large number; Page 3 Flags plus 999; distinct haptics; drop Water Lock; test pool use on hardware; a mindfulness-session breathing pacer later.

**SYNC-13 Save failures are swallowed, and a rebuilt clock can reuse sequence values** (low, S, Phase 4-5; partly)
- Evidence: LabourSessionModel.swift:245-251 and 286-288 (`try?`, event still appended); :280-282 rebuild the clock from stored events; LabourModels.swift:25 and LabourSessionModel.swift:64-66 fall back to default thresholds.
- Fix: a throwing save, an outbox and retry, a "not saved yet" marker, a separately stored seq counter, a loud failure on threshold encoding, and kill-and-relaunch tests.
- Correction applied: encoding practically can't fail and save failures are rare. Low.

**SYNC-14 The bespoke design has no concept of devices** (low, S, before reskin; confirmed)
- Evidence: labour.js:27 (one contractions array). body.html:129 telemetry block. B7 has no link indicator.
- Fix: a CAPCOM link chip ("WATCH LINKED · synced 4 s ago" / "OUT OF RANGE · 6 taps will sync" / "WATCH 18%"), a source mark on each row, and "syncing" while version vectors differ.

### iOS app architecture and code quality

The core builds cleanly under Swift 6. The problems are in the app layer.

**arch-01 STOP on a forgotten contraction records a real 10-minute one** (high, S, now; partly)
- Evidence: LabourSessionModel.swift:122-128 always stops at now. ContractionMetrics.swift:115-127 excludes only open contractions over forgotStopSec, and :92 counts any closed one over the urgent duration. TimerTab.swift:261-272 offers the quick fix only when `!isLast`.
- Fix: if the open contraction is in needsEdit, record a new start instead and show "Forgot to stop #12? 30s / 60s / 90s / Delete"; close(afterSeconds:) for the last row; a stop within 1.5 s of its start counts as a double-tap; put the rule in the shared core; tests.
- Correction applied: callNow already shows from the open-over-2-minutes rule (B13.3). The press turns a fixable state into a closed 10-minute contraction that holds callNow for the window and skews the stats.

**arch-02 Either store failing takes labour mode and the triage number down; no schema versioning** (high, M, before reskin; confirmed)
- Evidence: AppModel.swift:19-21. MissionControlApp.swift:7, 17-18 and :48 ("phone your maternity unit" with no number). No VersionedSchema or SchemaMigrationPlan anywhere.
- Fix: SchemaV1 and a migration plan; open the containers independently; mirror an emergency card plist and show tap-to-call in StoreFailureView; a V1 fixture test.

**arch-03 Permission is asked at LAUNCH, and Focus silences alerts** (high, S, before reskin; confirmed)
- Evidence: AppModel.swift:55-58 awaits authorisation before start (only caller HomeView.swift:18). ThresholdNotifier.swift:19-21 and 52-59. The entitlements hold only the App Group.
- Fix: ask in setup or the first practice; never await UI before start(); .timeSensitive plus the entitlement; getNotificationSettings on launch and foreground with a persistent Settings strip; the same on the watch.

**arch-04 The session logic is locked in the iPhone target with unfrozen inputs** (high, L, before reskin; confirmed)
- Evidence: LabourSessionModel.swift:22-60. project.yml:59-68. AppModel.swift:32-34 reads the live profile. LabourModels.swift:13-15 freezes only thresholds. The profile is editable mid-labour (EndLabourView.swift:113-115, MissionProfileForm.swift:17-20). ThresholdNotifier.swift:28 uses the live region while banners use the session region. TimerTab.swift:168-180 computes stats in the view.
- Fix: a Foundation-only LabourSession in MissionCore (injected clock, EventStore protocol; toggle, undo, edit, redFlag, ingest); a frozen LabourSetup; a pure LabourScreenState shared by iOS, watch and Live Activity; testable on Linux.

**arch-05 Labour mode runs only while the labour screen shows** (medium, M, before reskin; partly)
- Evidence: LabourRootView.swift:44-56. AppModel exists only as @State. refresh() re-reads memory, and reloadEvents runs only at init and start (:180-209, 270-284). The iOS 17 target has no SwiftData history API. The B6 widget writer and BGAppRefreshTask. ActivityKit and BGTaskRequest documentation.
- Fix: create AppModel once and register it with AppDependencyManager; the review timer inside the session; reloadFromStore on foreground and after sync; LiveActivityIntents for Start, Stop and Undo (a single writer); restart inside the intents and on foreground.
- Correction applied: no current defect. Sheets don't stop .task, and the loop runs whenever labour is active and the app is in the foreground. The risk is in the reskin and Phase 4.

**arch-06 The current model can't host a practice run safely** (high, M, before reskin; confirmed)
- Evidence: MissionControlApp.swift:30-34. LabourSessionModel.swift:78-87 and :208. ThresholdNotifier.swift:47-50. The wall clock is used in LabourRootView.swift:48, TimerTab.swift:41-44 and 168-175, and ThresholdNotifier.swift:43 (real-seconds triggers).
- Fix: LabourSessionRecord.kind, never silently resuming a practice; a separate in-memory session with PracticeAlerting (in-app banners, "practice." prefix) and the watch joining in; every view and the scheduler read the session's now; real LAUNCH always reachable.

**arch-07 "Baby's here" records nothing** (high, M, before reskin; confirmed)
- Evidence: EndLabourView.swift:15-20 (the time is Date() on each render), :60-63 and :77 (false alarm on the same screen). end() sets only endedAt. No outcome field anywhere. Prototype splashdown deadlines use landedAt (labour.js:411-430). The labour store is excluded from backup (Stores.swift:33). :17 reads profile.humour.
- Fix: a pregnancy-level outcome (editable birthAt, babyName, outcome enum) linked by endReason (born, standDown, practice); two explicit exits; reminders from birthAt; humour from the environment.

**arch-08 Hospital and call list are flat strings** (high, M, before reskin; confirmed)
- Evidence: PlanningModels.swift:7-25, and hospitalNumber and notes in the planning store (:14-15). CallTab.swift:37-49. The plan has no contact entity. A1 lists two Leeds units and backups. CloudKit is pencilled in for later.
- Fix: a BirthPlace model (kind, catalogue ID and version, numbers, address, postcode, coordinates, travel, parking, entrance, overnight, isPrimary) and a CrewContact model (relationship, normalised phone, roles OptionSet, contactIdentifier) with CNContactPicker; a bundled units file with provenance copied into an editable record ("this number has changed"); travel on the place and in LabourSetup; hospital number and notes local-only; App Group snapshot.

**arch-09 With the watch as main timer, session identity, hysteresis and alert ownership diverge** (high, L, Phase 4-5; confirmed)
- Evidence: LabourSessionModel.swift:89-98 and 276-278. Hysteresis.swift:42 (since = the device's own now). :201-204 save per device. iPhone alerts forward to the watch when the phone is locked.
- Fix: a handshake (either device starts; ID and setup in the first batch; the phone adopts the earliest open session); deterministic dwell replay or one authoritative device; one notification owner per session (the last tapper), with the other cancelling labour.* on ingest; a two-device simulation test.

**arch-10 Tap-to-call builds invalid numbers** (medium, S, now; confirmed)
- Evidence: PlanningModels.swift:98-101. "+44 (0)113 392 6731" becomes +4401133926731; an extension is appended; "½" passes.
- Fix: a PhoneNumber type in MissionCore storing E.164 plus display, rejecting invalid input, a "Test this number" button, and Linux tests.

**arch-11 The birth plan model can't evolve** (medium, M, before reskin; confirmed)
- Evidence: PlanningModels.swift:153-162. B3 planned answers[]. BirthPlanEditor.swift:29-32 bumps updatedAt on every close, and :35-61 bind to the live record.
- Fix: answers with sectionID, choiceIDs, freeText, updatedAt and agreedWithHer; a topFive; reviewedAt; BirthPlanRevision written on "Mark reviewed" and at the 20, 32 and 36-week nudges; draft with Save and Discard; IDs from bundled content; read-only in labour, with any edit logged.

**arch-12 Ending labour deletes every pending notification, and tapping an alert goes nowhere** (medium, S, Phase 6; confirmed)
- Evidence: ThresholdNotifier.swift:47-50; it is the only delegate (:16); willPresent only (:63-71).
- Fix: a NotificationRouter with namespaces (labour.<id>.*, practice.*, reminder.<id>.*); remove by prefix and clear delivered alerts; didReceive opens the call card; an "Open call card" category action.

**arch-13 Save and decode failures are swallowed** (medium, S, Phase 7; confirmed)
- Evidence: LabourSessionModel.swift:286-288 and 245-251; AppModel.swift:60-62 and :74; compactMap at :279; LabourModels.swift:25 with :64-66.
- Fix: a throwing save, a pending queue, a "Not saving: write the times down" strip, os.Logger, non-optional frozen setup (refuse to start otherwise), and a count of dropped rows.

**arch-14 Store location depends on the App Group entitlement, and device IDs differ per process** (medium, S, Phase 4-5; confirmed)
- Evidence: Stores.swift:39-49 falls back silently; CI builds unsigned. AppModel.swift:85-96 uses UserDefaults.standard.
- Fix: fallback only in DEBUG simulator builds; a release build treats nil as the failure path; a one-time move from Application Support; DeviceIdentity in the group, re-minted after a restore (compare identifierForVendor).

**arch-15 No app-layer tests; the mac CI job will fail at its first step; demo flags can overwrite real data** (medium, M, now; partly)
- Evidence: Tests/MissionControlTests and Tests/MissionUISnapshotTests are empty, and project.yml has no test target. ci.yml:35, 41-42 run lint first. `swiftlint --strict` gives 9 errors, including TriageScript.swift:48 and LabourAlertPlanner.swift:77. LaunchOptions.swift:21-23 and 38-47 write demo data whenever motherName is empty.
- Fix: a MissionControlTests target (in-memory stores, fake clock, fake alerting) covering relaunch, undo, forgotten stops, end and practice isolation, and notification IDs; one -demoLabour XCUITest; fix the two MissionCore lint errors and run the mac job on this PR; demo flags imply in-memory stores.
- Correction applied: the lint errors come from the WIP commit, so main isn't broken today but would be on merge. The demo overwrite is DEBUG-only and low. A clean Swift 6 build with Xcode 27.1 was not independently verified.

### Product and UX of the bespoke design

The staged rocket, the Her-first briefing, "Ask her tonight", the radar and the sober orbit are the right foundations.

**ux-01 Every "Call" control must dial, and 999 must be one tap** (high, S, before reskin; partly)
- Evidence: labour.js:132 (setTab), :137 (labelled "Call 999"), :302-321 (no 999; :314 "Copy"). sheets.js:96 placeholder. home.js:673 (pill opens a sheet). The WIP does it right (CallTab.swift:14-16, 24-26, :39).
- Fix: a reskin rule that "Call X" is a tel: link to X; at level 4 the largest control dials 999; Call tab order 999, triage, crew; "Call [unit]" on the When-to-call sheet and pill from 24 weeks; a test that call999 renders tel:999.
- Correction applied: a regression risk for the reskin, not a defect in the app. High, not critical.

**ux-02 No path for loss, admission, premature birth or false alarm** (high, M, before reskin; partly)
- Evidence: labour.js:362, :409, :393-405. EndLabourView.swift:11. home.js:357-366. plan.md:324 and :332. No loss content. plan.md:107. Research 04:28, 04:632, 02:409.
- Fix: a "Mission status" switch: (1) loss (cancel everything, hide the countdown, rocket and payload, humour off, support, archive or delete, never resumes); (2) in hospital (admission card); (3) early or neonatal care (no patch, neonatal decoder, Bliss, Neonatal Care Leave and Pay, after research); (4) "Not yet: back to the pad". The broadcast makes no wellbeing claim, and every surface checks the status.
- Correction applied: the WIP has an "End labour mode" exit with a false-alarm footnote (EndLabourView.swift:60-78), but it sits under a birth-centred screen. Only the prototype makes birth the sole exit. Sensitivity rather than clinical safety, so high.

**ux-03 Birth place and crew list need their own model and screen** (high, M, before reskin; confirmed)
- Evidence: PlanningModels.swift:13-20 (plan.md:275 promises place and mode). labour.js:29 and 311-315 are hard-coded. sheets.js:96 and labour.js:101 "set off". Research 01:243-244, 03:94. Review log row 6.
- Fix: a "Crew and pad" set-up and manual: birth setting and planned mode; MKLocalSearch for the unit but the triage number typed from her notes; transfer unit, parking, entrance and overnight rule; contacts by role through CNContactPicker with Call and Text; shown on the Call tab, the "while you're out" card and splashdown; copy follows the setting; must-dos auto-tick.

**ux-04 The birth plan is a static, partly locked sample** (high, M, before reskin; confirmed)
- Evidence: content.js:181-187 and labour.js:325-327 (sample). sheets.js:141-153 (advice only). home.js:81-86 locks plan.theatre, third-stage and feeding to week 30, and photos and plan-changes to 32. PlanningModels.swift:153-162. The plan is tile 4 of 9 (body.html:74-77). The 34- and 36-week appointments discuss it. Research 03:116-123.
- Fix: a top-level Flight plan from week 12 with no locks; choice chips, "in her words" and a status per section; reviews after 28, 34 and 36 weeks showing differences; revisions; sub-plans; read-only large type in labour with "last checked with her"; PDF; fix the data shape before the reskin.

**ux-05 Turn the cover into a launch console with a practice run, and keep the real launch fast** (high, L, before reskin; partly)
- Evidence: body.html:88-94. home.js:592-593. launch.js:93 (7.7 s). labour.js:353-356 seeds 16 fake contractions. Research 04:28, 01:72, 02:150. plan.md:71 and :275.
- Fix: a "What's happening?" question on the real path (contractions, waters, induction, planned caesarean, something's wrong); preterm or red flag skips the animation; real liftoff at most 2 s or behind a working timer; a scripted, sped-up practice with watch taps, a red flag, the script, the plan and the decoder, then a debrief and patch; stored apart, never dialling, everything labelled PRACTICE; suggest doing it at 35 to 36 weeks. (Layout reconciled to keep LAUNCH primary; liftoff about 3 s.)
- Correction applied: liftoff has a Skip button (body.html:200-201, launch.js:82 and :361). The prototype already opens preterm on "Call now", though after the animation. "Dry Run" is the drive, so the drill needs a new patch.

**ux-06 The watch is missing from the bespoke design** (high, M, before reskin; confirmed)
- Evidence: body.html:115-175 is phone-only. labour.js:158-159 breathing. plan.md:320 and :314. Research 03:199-202 and :171.
- Fix: watch frames before the phone reskin (amber-ring button, level strip, time since start, Crown history, flags, a wrist-dial Call or 999 via openSystemURL, to be confirmed in Phase 5); a phone "Timing on your watch" banner that promotes Call, Plan and Coach; breathing cue only while the watch screen is on; the watch in the practice run.

**ux-07 The stage gate puts on-track dads on HOLD and ties his rocket to her decisions** (high, S, Phase 6; confirmed)
- Evidence: home.js:46-59. content.js:23-25. items.json: week-28 appointment, dating scan, whooping cough (deadline 32 weeks, blocks from 28), RSV, mum-tells-employer. checklist.json has no `must` field. Items per stage are 16, 25, 69 and 8. Research 03:163.
- Fix: a must-do gates only if its window closes before the next stage opens (two weeks' grace), enforced by a content test; her-choice must-dos reworded as his actions and cleared by "Not for us"; must flags with reasons, reviewed by the midwife; paint weighted by must-dos or parts.

**ux-08 Late starters, items that don't apply and second babies get a broken, guilt-heavy rocket** (high, M, Phase 6; partly)
- Evidence: home.js:81-86, 68-70, 72-75 (a held stage paints 0%). 5 and 8 must-dos in stages 0 and 1. Items that often don't apply (Maternity Allowance, unmarried registration, pets, backups, car). content.js:41 and body.html:216 ("Behind", overcast). content.js:89 "Hold, hold, hold". plan.md:261 (skipped state). A4.9.
- Fix: profile questions that hide inapplicable items; a catch-up screen with Done / Missed it / Not for us ("missed it" never blocks and suggests a next step); never lock ticking; paint visible under a HOLD stencil; a second-baby set; no weather tied to progress; "Joining at 30 weeks? Here's what matters now".
- Correction applied: home.cot and vehicle.fit-seat have deadlines and are tickable at any time. Only deadline-free items such as vehicle.choose-seat (26) and home.sleep-space (30) are locked early.

**ux-09 Involve her through share-outs and saved answers** (medium, M, Phase 6; partly)
- Evidence: body.html:53-58 and home.js:488-492 (Ask-her saves nothing). content.js:118. dayof.alone-plan (week 35). Research 01:243. plan.md:15. Research 03:50 and :34.
- Fix: private notes on Ask-her prompts with "Add to the birth plan" or "visitors plan"; a launch card for her phone; the plan sent for her approval ("checked with her"); an optional weekly "what I've sorted" message; notes local and never synced.
- Correction applied: an engagement improvement (medium). The launch card overlaps ux-03.

**ux-10 Decoder worry labels break for the most serious terms** (medium, S, before reskin; confirmed)
- Evidence: sheets.js:230 has 3 labels for levels 0 to 3, so 6 level-3 terms show "undefined", and there is no .w3 style (style.css:460-463). Level 2 "Act now" sits on SCBU, NICU, blood pressure, GA and Martha's Rule. The WIP DecoderTab.swift:124-127 maps level 3 to "Act now". Review log C2.
- Fix: separate seriousness from action (Routine / Worth asking / The team will keep a close eye / Serious: the team moves fast) plus a "your job" line; map all four levels; add to the C2 review.

**ux-11 The weekly briefing needs a schema and 38 weeks of reviewed content** (high, L, Phase 6; confirmed)
- Evidence: content.js:51-146 covers 5 demo weeks. briefings.json has 12 single-body items. Review log line 67. Research 04 covers weeks 4 to 41. home.js:423-443 (tabs hide lenses) and :428 ("Watch for" inside the themed card, against plan.md:212 and :334). The Veteran character (plan.md:213) is unused.
- Fix: a weeklyBriefing schema with typed lenses and sources on clinical fields; start writing now from research 04; swipeable lens cards starting with Her; "Watch for" as a Flight Surgeon card; a "how you might be feeling" line and a Veteran aside in the You lens.

**ux-12 Fill the gaps in the holistic picture** (medium, M, Phase 6; confirmed)
- Evidence: every Watch-for line is physical (content.js:64, 81, 98, 115, 132). Research 04:55 and :223 (1 in 5 anxious) and alert 11. commander.sex is a checkbox. Research 04:182. The check-in is the ninth tile. Money is figures only. Research 01:244. The scene has two figures.
- Fix: a mental-health line each trimester; an "Us" strand (intimacy, arguments, mental load); the check-in as a home card when due; a "money's tight" path (Healthy Start, Sure Start grant, Maternity Allowance, MoneyHelper) and a money Ask-her; a sibling strand and the child in the scene.

**ux-13 The home screen is long and shows the build four times** (medium, M, Phase 6; confirmed)
- Evidence: body.html:8-79. style.css:89 (470px scene) and :159. Progress appears in four places (home.js:330-340, 371-385, 546-558, 440-442). No navigation besides tiles.
- Fix: a scene of about 380pt with a tap opening the build sheet; one CAPCOM line, briefing cards, Ask her, and a merged "Next up" (3 plus See all); a four-item bar (Home, Flight plan, Crew, Manuals) plus the dock; check at SE size and the largest Dynamic Type.

**ux-14 The T-minus countdown has no state after the due date** (medium, S, Phase 6; partly)
- Evidence: home.js:357-359. content.js:128 and :124. Research 04:559 and 02:150. plan.md:318 widget.
- Fix: a 37 to 42-week "launch window" gauge; "T+3: going past the due date is common" with the 41-week options; the number can be hidden and never appears after a status change.
- Correction applied: the prototype can't actually show "T–-7" (its demo weeks stop at 38, and the real app uses the EDD). The gap is the undesigned state after 40+0.

**ux-15 Make rocket parts mean something; a weekly ritual, not a daily nag** (medium, M, Phase 6; confirmed)
- Evidence: home.js:112 (named parts) and :155-160 (one fill). content.js:23-27. Patches only at GO (home.js:642). plan.md:71, :219 and :223 (daily streaks). Research 03:51 and :163. commander.who-to-tell (week 4).
- Fix: map modules to parts (car seat = fins, bags = cargo bay, skills = training deck, plan = flight computer, crew = comms ring, when to call = heat shield); a weekly delivery scene; one Sunday notification built around Ask-her; real-world patches; a never-resetting weekly count instead of streaks; a nameable mission; discreet notifications and widget until "who to tell" is ticked.

### New requirements: watch timing and the practice run (labourreq)

**WPR-01 A missing due date silently switches off the under-37 rule** (high, M, now; partly)
- Evidence: GoNoGoEngine.swift:158. LabourState.swift:108. PlanningModels.swift:76. TriageScript.swift:168 treats unknown as term. HomeView shows "Set T-0" but still offers LAUNCH. Research 04:28 and 02:65. Review log E9 is Open.
- Fix: unknown gestation becomes the question "Is she 37 weeks or more?" (Yes / No / Not sure) as a syncable event, with No and Not sure driving callNow; it stays above the timer until answered; the script says "weeks: not known"; engine tests; a due date required before the drill.
- Correction applied: high, not critical. The branch is pre-release and Phase 6 onboarding asks for the date.

**WPR-02 The practice run must not reuse the real session, store or notifier** (high, M, before reskin; confirmed, downgraded from critical)
- Evidence: MissionControlApp.swift:30-31. LabourSessionModel.swift:90. ThresholdNotifier.swift:23-44 with titles from StateCopy (LabourAlertPlanner.swift:100). The preterm rule. `now` is injectable (:52).
- Fix: a separate DrillModel (engine and EventLog, simulated clock, scripted 39+0 profile with real parity, memory only, alerting nil, no UNUserNotificationCenter, ActivityKit or WatchConnectivity); "a real labour always wins"; never restored; a UI test.
- Note: watch sync is a future concern, since sync doesn't exist yet.

**WPR-03 One cover, two keys** (medium, M, before reskin; confirmed)
- Evidence: body.html:88-94. launch.js:44-47. home.js:591-593. Research 04:28 and :531, 01:67-76. termDays 259 (LabourState.swift:143).
- Options considered: A swap (rejected); B two keys (recommended); C hangar only (fallback); D ask real or practice (rejected).
- Fix: weeks 30 to 36+6 "Labour started? Any week. Lift to launch" plus a drill key labelled "T-minus practice" whose start card's biggest button is real LAUNCH; from 37+0 the drill moves to the hangar behind a gate, and the well shows hazard styling and "Launch window open"; switch at 37+0.
- Note: the prototype's blueprint colour is pale blue (#8DB8E8 / #C9DAF2), not cyan.

**WPR-04 The real launch path has too many steps and blocks on a permission alert** (medium, S, before reskin; partly)
- Evidence: AppModel.swift:55-57. HomeView.swift:17, 59, 143 (LaunchGate). launch.js:93 (7.7 s) and :343 "WE HAVE LIFT-OFF". plan.md:324 "confirm once".
- Fix: start the session at the tap; ask for permission in the drill or setup, or later on the timer screen; under 37 weeks or unknown gestation skip the liftoff; otherwise about 3 s with tap-to-skip, and never lose the start; acceptance test of 2 taps and 1 s under 37 weeks.
- Correction applied: Skip and tap-to-skip already exist (launch.js:82, :361-362). B8 needs a disclaimer at labour-mode entry, so keep a short non-blocking one on the timer. Medium.

**WPR-05 Pre-37 cover copy and styling suggest launching isn't allowed yet** (medium, S, before reskin; partly)
- Evidence: body.html:92 "Only when labour starts". home.js:592-593. style.css:335 (hazard only from 37). Research 02:65. sheets.js:102.
- Fix: "Labour started? Any week. Lift to launch" (and the same VoiceOver label); window language only for likelihood; equal prominence in every week; a drill card using labour.js:95's preterm copy.
- Correction applied: the pre-37 copy itself is neutral. The misleading signal is the change at 37 weeks. Medium.

**WPR-06 The watch must launch and call on its own, with the profile synced before labour** (high, L, Phase 4-5; confirmed)
- Evidence: plan.md:312 and :310 (SessionSummary carries no profile). The watch shell. GoNoGoEngine.swift:158. Requirements 1 and 3.
- Fix: a readiness context via updateApplicationContext on every profile change (due date, parity, fast labour, travel, region, overrides, unit, triage, call list) with a "Ready" state checked in pre-flight; watch LAUNCH by press-and-hold (about 1.5 s, ring, haptic) with a local session ID the phone adopts; "Call [unit]" from callTriage and 999 at call999; under 37 weeks or unknown, the first screen is Call now.

**WPR-07 What the drill simulates: an 8-minute, seven-chapter "static fire"** (medium, L, Phase 6; confirmed)
- Evidence: B5 pure engine and injected now. labour.js:30-41 and :175-226. Research 02:93 (NNUH triage questions). The 2-minute nudge (B13.3). The checklist items. briefing.w32-dress-rehearsal.
- Chapters: pre-flight (1 min; real data, permissions, watch Ready, Return to Clock); wrist drill (2 min real time, scored on reaction and start-to-start); fast-forward (12x through the real engine, including the second-baby and travel windows); curveball (forgotten stop, waters, reduced movements); the call (CAPCOM plays triage, the number is shown but not dialled); go (bag, seat, address, travel, parking; the real drive as homework); debrief (score, patch, "Before 37 weeks, skip all this: launch and call").
- Fix: a versioned JSON script with provenance and midwife sign-off, driven by DrillModel and the real TriageScript; 8 minutes or less, resumable and repeatable; humour only in the framing.

**WPR-08 Labelling so the drill can never be mistaken for labour** (high, M, before reskin; confirmed)
- Evidence: launch.js:344-348. content.js:43-47 (blueprint palette). home.js:146. CallTab.swift:39 and LabourRootView.swift:169 (tel: links). plan.md:316.
- Fix: a "static fire" world (blueprint rocket on a test stand, never orbit); a "SIMULATION · NOT REAL LABOUR" tape on every phone and watch screen; "SIM:" headlines; tints instead of state colours; an outline call button that can't dial; no notifications or Live Activity; "SIM" on the complication; a full-width "Real labour? Launch now" bar; a VoiceOver "Practice" prefix; auto-end after 15 min idle; snapshot tests. (The palette is pale blue rather than cyan.)

**WPR-09 Water Lock would stop him tapping; use Double Tap** (medium, S, Phase 4-5; confirmed)
- Evidence: plan.md:320. Apple HT210931. handGestureShortcut needs watchOS 11. project.yml:9.
- Fix: drop Water Lock; `.handGestureShortcut(.primaryAction)` (Series 9 / Ultra 2 or later, in addition to the full-screen target); distinct start and stop haptics; an Action-button intent; target watchOS 11 or availability checks; teach it in the drill; a visible flags page instead of the long-press.

**WPR-10 Getting back to the wrist button between contractions** (medium, M, Phase 4-5; partly)
- Evidence: plan.md:314 and :316. Return to Clock options. Live Activities in the Smart Stack from watchOS 11. project.yml:9.
- Fix: a Return to Clock pre-flight (Custom, After 1 hour); the complication as a one-tap way in; a supplemental Live Activity view with Start/Stop; the 2-minute nudge as a watch notification with Stop and Still going actions; raise the target (for Double Tap).
- Correction applied: Smart Stack mirroring depends on the user's watchOS (11+), not the app's deployment target.

**WPR-11 Run the drill on the wrist, but keep drill events out of sync** (low, M, Phase 4-5; partly)
- Evidence: EventMerger.swift:6-14 (no sessionID check). TapEvent.swift:38-40. plan.md:310.
- Fix: a session kind in the session and envelope; drill events by live sendMessage only, dropped when unreachable; merges filtered by session ID with drill envelopes rejected; a shuffled-mix test; a watch drill face (ring, "SIM" corner, cue haptic).
- Correction applied: loads already filter by sessionID (LabourSessionModel.swift:278), so the check belongs on the unwritten receive path. Low.

**WPR-12 The drill must never time real tightenings** (medium, S, Phase 6; confirmed)
- Evidence: research 04:426 (painful or regular Braxton Hicks may be early labour) and 04:28. glossary.json:35 ("Practice contractions").
- Fix: the drill accepts scripted cues only; the start card asks about tightenings, pain, a show or fluid, and Yes sends him to "Then this isn't a drill" and the real LAUNCH; drill copy says "To time real tightenings, always use LAUNCH. If they're painful or regular before 37 weeks, call."

**WPR-13 Link the drill to the build and checklist, plus a "she's alone" variant** (low, S, Phase 6; confirmed)
- Evidence: checklist dayof.save-number and hospital-details (week 30), when-to-call (34), alone-plan and bag.staged (35). badges.json:50 Dry Run = drive. plan.md:71. Research 01:72.
- Fix: unlock at week 30 (partway through stage 2, which starts at 28); completion ticks dayof.when-to-call and earns "Simulator certified" (Dry Run stays for the drive); a 2-minute "If she's alone" variant; a 36-week refresher if done before 33.

**WPR-14 Haptic breathing pacer during an open contraction** (low, M, later; confirmed)
- Evidence: research 03:109. labour.js:158-159. plan.md:314. WKExtendedRuntimeSession types.
- Fix: prototype after first release; off by default, only while a contraction is open, tried in the drill first; check the session type with App Review (one type per app, short limits).

**WPR-15 The prototype starts labour mode with 16 fake contractions** (low, S, before reskin; confirmed)
- Evidence: labour.js:30-41 and 353-355; hard-coded names and details at 311-315. The SwiftUI port already starts empty, and -demoLabour is DEBUG-only (LaunchOptions.swift).
- Fix: real labour always starts empty with the real profile; the seeded hour and sample names move into the drill JSON.

### New requirements: evolving birth plan, saved hospital and call list (planreq)

**NRC-01 Tap-to-call can dial the wrong number** (high, S, now; partly)
- Evidence: PlanningModels.swift:98-101. CallTab.swift:38-44 shows the raw text. MissionProfileForm.swift:38-40 is a free TextField. Scratch run: "0113 392 6731 option 2" becomes 011339267312; "+44 (0)…" becomes +4401133926731; two numbers concatenate. Apple Phone Links ignore * and #.
- Fix: a PhoneNumber type in MissionCore (E.164, short codes 999, 111 and 116 123, reject a second number or letters); raw and dialable stored separately; "Then press 2" note; inline read-back; normalised number in labour; tests for the five inputs.
- Correction applied: the current filter strips * and #, so "*2#" makes a wrong number rather than a link that does nothing. The * and # rule is why menu codes belong in the "after connecting" note.

**NRC-02 The labour Call tab has no route when triage doesn't answer** (high, S, now; confirmed)
- Evidence: CallTab.swift:13-31. Research 01:241 ("111 if you can't reach the unit"). The prototype has it only in the pre-labour manual (sheets.js:106). Two Leeds units (01:240) but one triagePhone.
- Fix: an always-visible "Can't get through?" row (retry; labour ward or switchboard "ask for the labour ward"; NHS 111; 999 if it's an emergency); US wording for the US profile; copy in JSON with provenance.

**NRC-03 There is no call list** (high, M, before reskin; confirmed)
- Evidence: PlanningModels.swift:7-25. Stores.swift:12. Checklist dayof.backup-driver, backups and comms-plan. Research 01:240 and :244.
- Fix: a CrewContact model (name, role from the CrewRole cases, phone raw and dialable, note, order, alertOnLaunch, firstCall, inBroadcast, updatedAt); clinical numbers stay on the unit; CNContactPicker with copied values; tap to call, long-press to text; an MC-09 Crew roster manual and the comms part of stage 3; seats that tick and untick checklist items; a Crew section on the Call tab ordered by what matters now.

**NRC-04 Hospital details are flat strings** (high, M, before reskin; confirmed)
- Evidence: PlanningModels.swift:12-20. plan.md:275 promises place and mode, but neither the fields nor the data model (line 260) have them. TriageScript.swift:4-13. Research 01:240, 01:242, 02:91.
- Fix: a MaternityUnit model (site, kind, isBooked, triage and hours, ward, switchboard, address, coordinates, day and night entrances, drop-off, parking and payment, overnight, peak and night travel, source, verifiedAt and how); plannedPlace, plannedMode, plannedDate and bookedUnitID with a migration; an extended TriageDetails opening line; the longer travel time into the engine; a Ground Control hotspot and unit card; the Call tab top card; Getting there with Directions and the night entrance first after dark.

**NRC-05 The birth plan model has drifted from the planned structured answers** (medium, M, before reskin; partly)
- Evidence: PlanningModels.swift:153-162. plan.md:262. BirthPlanEditor.swift:29-32.
- Fix: a BirthPlan model (revision, changedAt for real edits only, reviewedAt, herConfirmedAt, place, PlanAnswer with who and changedAt, topFive linked to answers, branches) plus BirthPlanSnapshot (reason draft1, draft2, onePage, midwife36, inductionBooked or manual); birthplan.json with provenance; "what changed" as a diff; a one-time migration.
- Correction applied: the builder is explicitly Phase 6. updatedAt isn't read anywhere, and nothing has shipped. Medium.

**NRC-06 "If plans change" is generic, and labour opens the full editor** (medium, M, before reskin; partly)
- Evidence: PlanTab.swift:67-101 (generic coaching cards), :49 (editor link, against plan.md:329 "read-only") and :61 ("You can do it now"). labour.js:327. Research 02:150 and 02:161.
- Fix: a PlanBranch model (scenario, preferences, his job) prompted by plan.plan-changes at 32 weeks; in labour, "Plan changed?" chips that promote the branch, show BRAIN and switch Coach, with the active branch saved as a labour event; a new empty state with one quick note; a "baby needs extra care" branch after research.
- Correction applied: plan.md has no "no typing" rule, and the editor is a push, not a modal, so it breaks only the read-only line. The "what changed" prompts are already planned. Branch storage is the gap. Medium.

**NRC-07 The builder doesn't record her input, has no review cadence, and misses NHS sections** (medium, L, Phase 6; partly)
- Evidence: BirthPlanEditor.swift:5-33 has a single author. Ask-her prompts (content.js:118, :135) are never saved. Research 01:68 and :77. BirthPlanSection (PlanningModels.swift:105-117) lacks students, induction views, environment and his role (research 03:118, 01:200, 01:203, 02:115, 03:119).
- Fix: a "Flight Plan" builder, one decision per card in NHS order, each offering "Her answer" / "Decide together" / "Decide on the day"; his drafts marked "check with her"; a "Read it with her" mode that sets herConfirmedAt and takes a snapshot; save Ask-her answers to the plan; cadence of 20 to 27, 32, one-pager by 36, a post-36-week step and an induction review at 39 to 41; event re-opens with a CAPCOM line.
- Correction applied: the checklist has 11 plan.* items from weeks 20 to 34, including a week-32 plan-changes item and an advocate item, and plan.draft says to write it together. Her confirmation and the 36-week and induction reviews are what's missing.

**NRC-08 Choosing the unit: MapKit for the address, manual numbers, verify both** (medium, M, Phase 6; confirmed)
- Evidence: review log item 6 and C9. B13.10. MKMapItem.phoneNumber is the business number. MKDirections departureDate. Research 01:242. MissionProfileForm.swift:41-43 (5-min stepper). plan.md:296.
- Fix: three tiers (numbers by hand as the source of truth; MKLocalSearch for name, address and coordinates, with the MapKit number offered as the switchboard only; a small bundled directory of research-verified entries with sourceURL and verifiedOn, a 12-month lint, and "check it matches her notes"); verifiedAt with 34 and 36-week nudges and an amber "Not checked"; Dry Run journey times for 8am and 3am, the longer fed into travelMinutes.

**NRC-09 The prototype Call tab copies the number and urgent calls take two taps** (high, S, before reskin; confirmed, severity raised)
- Evidence: labour.js:314 Copy; :132 setTab; :29 and :311-312 hard-coded; sheets.js:96 placeholder; no 999 at labour.js:314-320 (the WIP CallTab.swift:14-27 has one); Plan tab :324-328 has no plan-changed controls.
- Fix: a written spec: the hot card dials directly with the name and number; Call tab order (999 first in call999, unit card with stamp and "press 2", "Can't get through?", script, Getting there, Crew); the manual reads the saved unit or offers "Add Ground Control's number"; the Plan tab shows the top five, his job, the chips and "Confirmed with her".

**NRC-10 The post-birth broadcast has no saved list or first calls** (medium, M, Phase 6; confirmed)
- Evidence: EndLabourView.swift:53-59 (ShareLink with no recipients). plan.md:163 (pre-approved list). Research 02:265. dayof.comms-plan (week 36). body.html:192-195. MFMessageComposeViewController.recipients.
- Fix: a comms plan at 36 weeks with her (first calls, broadcast list, an approved message with gaps, her rules); a "Tell the crew" card after LAUNCH; at splashdown, first-call rows plus "Send to 9 people" opening Messages pre-filled; ShareLink fallback; never auto-send.

**NRC-11 She has none of it on her phone** (low, M, Phase 6; partly)
- Evidence: plan.md:15, :41, :279. dayof.alone-plan (checklist.json:2171). Research 01:165, 01:209, 01:205. BirthPlanEditor.swift:3-4.
- Fix: an A4 PDF with a "Preferences, not a contract" footer; a plain-text version for her notes app; a "Send her Ground Control" .vcf with the alone-plan; record what was sent and prompt resends; buttons on MC-03, the unit card and the drill.
- Correction applied: the PDF is already planned. Only the text and .vcf are new, and she usually has the number in her notes. Low.

**NRC-12 The watch says "time to call" but can't call** (medium, S, Phase 4-5; confirmed)
- Evidence: plan.md:310 and :320. The 25-line watch shell. openSystemURL initiates calls.
- Fix: unit name, dialable number, checked stamp and region emergency number in the application context; a large "Call [unit]" at callTriage and above and 999 in call999; design this now while SessionSummary is unbuilt.

**NRC-13 Use the practice run to check the numbers, plan and crew** (medium, M, Phase 6; confirmed)
- Evidence: requirement 4. Cover copy body.html:92 (switched at home.js:593, not :670). dayof.route. Manual ticks while fields are empty (PlanningModels.swift:16-17).
- Fix: the drill shows the exact number and asks "Does this match her notes?" (sets verifiedAt, never dials); "Read it to her" (snapshot plus herConfirmedAt); empty crew seats flagged; Dry Run times; passed checks tick dayof.save-number, hospital-details, backup-driver, backups and plan.one-page, and clearing the data unticks them; rehearsal kept out of the real store and notifications.

**NRC-14 Her plan, notes and the crew list are sensitive and backed up, with CloudKit pencilled in** (low, S, Phase 6; partly)
- Evidence: Stores.swift:19 (excludeFromBackup false) and :33. plan.md:230. MissionProfileForm.swift:31 ("GBS positive"). PlanningModels.swift:14. Guideline 5.1.3(ii).
- Fix: plan, unit and crew never in CloudKit (split out a non-health store if sync is ever wanted); exports as the visible backup with "last exported" nudges; a "Delete her plan and contacts" control; the backup decision recorded in the review log.
- Correction applied: 5.1.3(ii) concerns iCloud storage, and ordinary encrypted device backup isn't generally a breach. No privacy-label declaration is needed, because nothing leaves the device.

### Content, copy, inclusivity and accessibility

UK facts are accurate. The dating-scan window is consistently 11 to 14 weeks, and no joke lands at her expense.

**content-01 No path for miscarriage, stillbirth, neonatal death or neonatal care** (high, L, before reskin; confirmed)
- Evidence: labour.js:362 and :409. EndLabourView.swift:11, and :17 picks the humour opener despite B7. No stillbirth, bereavement, Sands or Miscarriage Association content; NICU only in the glossary. Splashdown reminders and badges would still fire. Research 04 note 12 and 04:154. NHS miscarriage page; Bliss (about 1 in 7 babies in neonatal care).
- Fix: a neutral "Something's happened" route at any week; "How is everyone?" (all well / baby needs extra care / she needs extra care / we lost our baby); non-well branches turn off humour, countdown, story, badges, streaks and scheduled reminders; support (Miscarriage Association, Tommy's, Sands, Bliss, Birth Trauma Association, Samaritans) and the right admin (stillbirth registration differs); a blank broadcast; research pass first; bereavement midwife review.

**content-02 A practice run must never stand between a dad and real labour mode before 37 weeks** (high, M, before reskin; confirmed)
- Evidence: home.js:593. Research 04 alert 7. Review log E9. B6 notifications, watch and Live Activity.
- Fix: before 37+0, practice and "It's real" both available after lifting, with the real path skipping the animation to preterm "Call now"; practice has a permanent banner on phone, watch and Live Activity, an in-memory store, no notifications and disabled tap-to-call; scenario teaching ending in a debrief; practice in the hangar after 37 weeks. (Layout reconciled: LAUNCH primary.)

**content-03 A saved hospital and contacts are safety content** (medium, M, before reskin; partly)
- Evidence: review log item 6 and C9. Research 01:240. labour.js:29. LaunchOptions.swift:43 ("0113 000 0000", DEBUG only).
- Fix: unit names, sites and types from a maintained source with provenance; no default triage numbers, or a confirm-against-her-notes step with a date stamp; re-check at 34 to 36 weeks; contacts split into clinical (triage, community midwife, a fixed 999) and people, with only clinical shown first in callNow and call999; the transfer question for a freestanding MLU; the saved unit's name in engine copy.
- Correction applied: the demo number is DEBUG-only seed data, and numbers are already user-entered. This is a guard for the new picker.

**content-04 The "call now" panel fails WCAG contrast, and labour tabs use bright cream cards** (high, S, before reskin; confirmed)
- Evidence: style.css:516 and :514 (3.26:1 at 16.5px), :519 (2.63:1 at 8.5px), :537 (flags 3.26:1), :449 (.big-call 3.73:1), :575 (.card --paper in labour). B7 true black. Research 03 on bright screens.
- Fix: urgent surface #B3301C (5.15:1) or a black panel with a red border; the source line at 4.5:1 or better; near-black labour tabs; a LabourTheme token-pair contrast test.

**content-05 Weekly content covers 12 of 38 weeks, and the research's warning signs are missing** (high, L, Phase 6; confirmed)
- Evidence: briefings.json has 12 items. Briefing has title and body only (ContentSchema.swift:203). ContentLoader.swift:57 shows the latest beat, so weeks 13 to 15 show the dating scan. Research 04 covers weeks 4 to 41 plus 11 alerts. Zero matches for ectopic, severe sickness, ICP itching, folic acid or vitamin D, side-sleeping from 28 weeks, and movements by 24 weeks. The prototype WEEKS shape has no schema. home.js:428 routes early bleeding to labour advice.
- Fix: a WeeklyBriefing kind (Her: headline, body, appointment; Baby: length and how it's measured, explaining the week-20 switch, weight, comparison, fact; help list; a Flight Surgeon warning line with provenance and guide ID; Ask-her; CAPCOM variants); write weeks 4 to 41; a lint for missing weeks and warnings; route warnings correctly (early bleeding to the early pregnancy unit, 111 or 999).

**content-06 The HOLD rule blocks progress on her choices and on things that don't apply, and leans on guilt** (high, M, Phase 6; confirmed)
- Evidence: 33 must-dos in prototype/items.json, including whooping cough and RSV ("Remind her…", checklist.json:639 and :765), appointments, and admin for employees and her employer. home.js:46 statuses() has no not-applicable state. ChecklistItem has no must field. Research 01:113 (self-employed). A3 bans guilt mechanics (HiDaddy). content.js:89. Red "N days late" pills.
- Fix: must and appliesTo (his employment, her employment, nation) in checklist.json; must-dos only in his control, with her clinical decisions as information; "Doesn't apply to us" and "She's decided" clear a must-do; "Late is fine: speak to your employer today" instead of "N days late"; test the HOLD copy with dads.

**content-07 VoiceOver can't use the illustration, and the typewriter floods it** (medium, M, before reskin; confirmed)
- Evidence: body.html:10 (role=img with focusable buttons inside, home.js:193). body.html:21 payload label. body.html:32-34 and home.js:389-398 (aria-live rewritten every 26 ms). Canvas label body.html:131. B10 puts VoiceOver in Phase 7.
- Fix: the scene as one element with a generated summary and custom actions or rotor entries per stage; typewriter visual only, with the full line given once; announce advice-level changes only; an Audio Graph or text summary for the trace; VoiceOver pass during the reskin.

**content-08 Text of 6.5 to 9px and controls under 44pt (56pt in labour)** (medium, M, before reskin; confirmed)
- Evidence: style.css text sizes at :415, :225, :313, :379, :460, :353, :452, :509, :532; tap targets at :126, :96, :507, :568, :584, :497. B7 56pt and A4.15 44pt. The Swift app already uses 56pt and caps at AX3.
- Fix: every text role mapped to Dynamic Type with nothing under caption2; home grows to accessibility sizes, labour capped at AX3; all labour controls 56pt or more, including Undo and "Baby's here?"; 44pt hit areas for chips; snapshots at XS and AX3.

**content-09 The birth plan has no content behind it** (high, L, Phase 6; partly)
- Evidence: B4.5. ContentKind has no birth plan. Prompts are hard-coded at PlanningModels.swift:136-150. A free-text editor. No agreement or history. The "other" prompt is too narrow. A1 place-of-birth safety figures unused. appts.week-36 prompts no revision.
- Fix: a birthPlan.json kind (sections, questions, choices, explanation, ask-her, provenance from NHS, NICE NG235 and Birthrights) written in her voice; a "Checked with her on [date]" stamp per section; nudges at 28, 32, 36 and after the 36-week appointment; history; the top five, agreed date and branches in labour; access needs, past trauma, language, preferred name and who may be in the room.
- Correction applied: choices and "what changed" prompts are planned (B3, B4.5). The gaps are a provenance-backed content kind, approval stamps, nudges and history, and access-needs fields.

**content-10 Rounding gives "every 5 min, not at the call point yet"** (medium, S, now; confirmed)
- Evidence: StateCopy.swift:140 rounds to whole minutes. GoNoGoEngine.swift:147-148 (building up to 1.5x 300 s). StateCopy.swift:60 against :28-32. A 320 s median prints "About every 5 min … Not at the call point yet". The prototype does the same (labour.js:53).
- Fix: never round across the threshold (m:ss, or "just over 5 minutes apart"); a test that no reason line for an interval above adviceIntervalSec prints a number at or below the threshold.

**content-11 Safety copy outside the reviewed JSON; prep copy omits two NHS urgent rules; no watch-length copy; stale links** (medium, M, before reskin; confirmed)
- Evidence: B3 (a midwife reviews JSON), but engine copy is in StateCopy.swift, plan prompts in PlanningModels.swift and end defaults in EndLabourView.swift, and content-lint.py:1-17 scans only MissionContent. briefing.w36-preflight, sheets.js:95-107 and dayof.when-to-call omit "over 2 minutes" and "6 in 10" (research 04 alert 8), and the quiz doesn't test them. No short variants. 33 old NHS paths (signs-that-labour-has-begun ×18, antenatal appointments ×10, inducing labour ×5), and StateCopy.swift:147-150 hard-codes one. Review log item 2 (MATB1) is Open though research 04 note 18 confirms "from 20 weeks".
- Fix: labourCopy.json with long, short (about 40 characters) and spoken versions plus provenance; render one "when to call" item everywhere; add the two rules and a quiz question; lint the lengths; update URLs via the research and add a scheduled link check; close item 2.

**content-12 "UK" content is partly England-only or Leeds-only** (medium, M, Phase 6; confirmed)
- Evidence: research 01 (NI devolved) against checklist.json:32 and :197 with no NI caveat; :513 England's funded hours; :367 Healthy Start (Scotland has Best Start Foods); :269 and :3073 Merrion House; :2742 Dad Matters Leeds. C9 is Open. Martha's Rule shows the right pattern.
- Fix: nation applicability plus a locality pack, asked at onboarding or derived from the unit; a research pass on NI leave, Scotland's Best Start grants and foods, and the Welsh childcare offer.

**content-13 The content assumes one family shape** (medium, L, Phase 6; confirmed)
- Evidence: zero matches for same-sex, civil partner, twin, multiples, IVF, fertility and disabled. B3 multiples aren't in PlanningModels. admin.unmarried-registration and splashdown.register frame parental responsibility around the father and marriage. content.js:148-162 (first-baby rows). Research 04:503 (twins). Research 01:113.
- Fix: a research pass (GOV.UK same-sex registration and parental responsibility, HFEA consent, Twins Trust, Fertility Network UK, Disability Rights UK); onboarding questions (relationship and legal status, previous births, multiples, IVF dating, both employments); appliesTo tags and variants; "partner" wherever the law uses it.

**content-14 Decoder: level 3 renders "undefined", and "Act now" sits on terms he can't act on** (low, S, before reskin; partly)
- Evidence: sheets.js:230 (3 labels). Glossary levels 0 to 3. Six level-3 terms. No .worry.w3 (style.css:461-463). Level 2 "Act now" on SROM, meconium, decelerations, FBS, SCBU, NICU, GA and Martha's Rule. C2 Open.
- Fix: the scale named for him (Routine / Worth asking about / Staff will watch closely / Serious: the team acts fast); a partnerAction field for the few actionable terms (cord prolapse at home, PPROM, pre-eclampsia signs, waters); render all four levels; C2 sign-off.
- Correction applied: the Swift app already maps 2 to "Pay attention" and 3 to "Act now". The issue is the wording of level 3 and porting the prototype's labels.

**content-15 Humour "mild" is effectively "off"; humour leaks into labour; copy slips** (low, S, Phase 6; confirmed)
- Evidence: ContentSchema.swift:97-103 (mild ?? off; one mild field in total). EndLabourView.swift:17. badges.json:25 "Most don't. You did." (unsourced) and :412 "Home Module module". sheets.js:200 PANDAS described as for dads, against research 01:253 (general helpline plus a monthly dads' call). sheets.js:207 has no 999 or A&E line.
- Fix: two settings (Plain and Mission), or a mild version wherever a full one exists with a lint warning; plain copy in every labour view including the end screen; fix the three copy errors; add the urgent route to the check-in.

### Turning the prototype into SwiftUI

Canvas with TimelineView, Shapes, tinted vectors and SwiftUI modifiers cover everything, with no SpriteKit or web view.

**SWUI-01 Hot-state fills fail contrast in the WIP and the prototype** (high, S, now; confirmed)
- Evidence: LabourTheme.swift:13 (#FF6B36) and :30-32. StateBanner.swift:31, :37, :61 and TimerTab.swift:146, :151 put white on it (2.83:1). Prototype .advice.hot 3.26:1, .flag.on, .big-call 3.73:1, .pill.hot 8.5px, LAUNCH small 8px, cream on teal 4.00:1 at 15px. call999 #E32926 with white is 4.55:1 (passes narrowly). WCAG 2.2 SC 1.4.3.
- Fix: #B3301C for text-bearing hot fills (5.15:1) or near-black on orange (7.41:1); #E5482F only for strokes, icons and display text of 24pt or more; cream on teal only at large sizes; a MissionUI contrast unit test over all token pairs.

**SWUI-02 Use labour.js as layout only** (high, S, before reskin; confirmed)
- Evidence: labour.js:85 (999 set), body.html:139-148 (6 flags against 8 in RedFlag), :28 (own level names), :86-105 (hard-coded copy), body.html:126 (one source line), :132 (tab switch), :314 (Copy). B5 hysteresis and B8 lint.
- Fix: inputs only from EngineOutput, StateCopy, TriageScript and the log; flags from RedFlag.allCases (two pinned); levels from LabourState with StateCopy labels; the hot call control a Link(tel:) to the unit or 999; the source from StateCopy.source(for:) (which takes a ReasonCode); a coverage test.

**SWUI-03 Liftoff: start the session on tap, keep it short, render with Canvas** (medium, M, before reskin; partly)
- Evidence: AppModel.swift:55-58. MissionControlApp.swift:29-35. launch.js:93, 351-357, 361-362, :67. Non-determinism at :113, 227-243, :101, :223. Drawing at :54-58, 69-71, 274, 275-297, 308-309.
- Fix: a synchronous labour.start() on LAUNCH; liftoff as an overlay above the mounted LabourRootView; real launch about 3 s, the full 7.7 s for practice and replay; tap anywhere plus a 44pt Skip; skipped under Reduce Motion, VoiceOver or Low Power with an announcement; permission asked earlier; TimelineView plus Canvas as a pure function of t and a seed (home.js:231 seeded()), with a fixed 1/60 s step, resolveSymbol, about 300 particles; profile on an XR or SE 2.
- Correction applied: the fade sits inside the 7.7 s. The long delay is prototype-only, while permission-before-session is a real WIP issue. Medium.

**SWUI-04 Practice run under the cover: one step from the real launch and unmistakable** (high, M, before reskin; confirmed)
- Evidence: requirement 4. home.js:592-593. launch.js:44-47. B5 preterm. Research 04:28. labour.js:30-41.
- Fix: two controls in the well after lifting, never week-gating the real one; an in-memory model with no notifier, no Live Activity and tagged or excluded watch taps; a time-compressed walk through every state with a debrief ("you'd have called at 21:40") and gap prompts; a `missionMode` environment value (.live / .practice) driving a SIMULATION band, blueprint accent and VoiceOver prefix. (Layout reconciled: LAUNCH remains primary.)

**SWUI-05 The orbit scene, cream cards and small chips break B7's true-black theme** (high, M, before reskin; confirmed)
- Evidence: plan.md:324. style.css:502 (#05060F), :575, :520, :566. labour.js:2-23 (sky, earth, 80 stars, 46 static city lights, moving capsule). Sizes at :497 (liftoff), :507, :534, :568, :584. LabourTheme.swift:7 and :15 are already true black and 56pt.
- Fix: a static dimmed orbit (about 10% luminance at most) on #000; ink cards with cream text; amber for START/STOP and the selected tab only; filled red only for callNow and above; a LabourControlStyle with a 56pt minimum via @ScaledMetric; cream paper for pre-launch only.

**SWUI-06 No watch design, and haptic breathing conflicts with B6** (medium, L, Phase 4-5; partly)
- Evidence: init.js:31. The watch shell (MissionControlWatchApp.swift:14-24). plan.md:314, :320, and A3 item 6 (:162). Research 03:109, :199, :202. No Core Haptics on watchOS. handGestureShortcut needs watchOS 11 (project.yml:9 targets 10).
- Fix: a watch timer in the shared tokens (full-screen target, large numerals, state ring, last interval and duration, Crown history, flags, true black); Double Tap behind an availability check or a raised target; either amend B6 for a mindfulness session or keep breathing visual in v1; a watch practice mode.
- Correction applied: the timer is planned (B6, Phase 5). What's missing is the visual design and resolving the A3 versus B6 haptic conflict.

**SWUI-07 No editing surfaces for the birth plan, hospital or contacts** (high, M, before reskin; confirmed)
- Evidence: sheets.js:141-154 and :96. body.html:84-87 and home.js:673. labour.js:325-327. Stock BirthPlanEditor.swift:10-27 and MissionProfileForm.swift:10-63. CallTab.swift:38-49 (a working Link). B4.5. B3 single triagePhone.
- Fix: MissionUI components (PaperField, PaperTextArea, PhoneField with a test call, ChoiceChips, ContactRow, a single CallButton always Link(tel:) with an empty state, HospitalCard); CNContactPicker; one BirthPlanSummary themed paper, night or print (with a "last reviewed" stamp); the dock pill dials the unit and the guide moves to a secondary control.

**SWUI-08 Fonts: licences fine; packaging, Dynamic Type and minimum sizes need work** (medium, M, before reskin; partly)
- Evidence: build.py:10 (League Gothic, Instrument Sans, Martian Mono, all OFL 1.1 with no Reserved Font Name). Package.swift:32 (no resources). project.yml:86-89 (widgets). 48 sizes under 10px (style.css:117, :225, :415). Apple HIG minimums 11pt iOS and 12pt watchOS. tabular-nums at style.css:531 and :561.
- Fix: bundle OFL.txt; fonts in Sources/MissionUI/Resources/Fonts registered with CTFontManagerRegisterFontURLs on iOS and watch; static weights cut with fontTools; widgets and Live Activity get the fonts too; an MCFont type with relativeTo:, @ScaledMetric and a legibilityWeight step-up; nothing under 11pt; hero numerals capped; League Gothic only at 22pt or more; Instrument Sans for safety copy; check League Gothic's tabular figures, or use Martian Mono for clocks.
- Correction applied: shipping the licence text satisfies OFL condition 2, so an Acknowledgements screen is optional. Medium.

**SWUI-09 One semantic token set and explicit appearance handling** (medium, M, before reskin; confirmed)
- Evidence: style.css:1-25 and :24 (dark only). home.js:111 (second ink #232850) and 562-570 (raw hex). content.js:42-48. LabourTheme.swift:7-16 (a different amber and urgent). plan.md:212. About 12 radii.
- Fix: three layers (raw palette; semantic roles; context variants prelaunch, labour, practice and print) as asset colour sets with Increase Contrast variants; a 4pt grid and four radii; colour scheme scoped per surface; .accessibilityIgnoresInvertColors on illustrations; LabourTheme as a wrapper during migration.

**SWUI-10 A redraw budget** (medium, S, before reskin; confirmed)
- Evidence: labour.js:227-238 (rAF loop, renderLabour every 250 ms) and 196-205 (shadowBlur, sine wobble). style.css:558 and about a dozen infinite home animations. TimerTab.swift:41, :168, :190 (three 1 s TimelineViews). Research 03:188.
- Fix: one 1 Hz clock in labour; the trace redraws on change or every 10 s; an under-stroke instead of blur; ring animation only while a contraction is open and not under Reduce Motion or Low Power; one ambient TimelineView at 30 fps on home, paused when inactive, off screen or in Low Power; check with the energy gauge and Instruments.

**SWUI-11 A snapshot harness with injected time before the first reskinned screen** (medium, M, before reskin; partly)
- Evidence: Tests/MissionUISnapshotTests is empty. Package.swift:8-27. B9 (plan.md:345) and B11. The CI runner and Xcode mismatch. TimerTab.swift:41-44 reads context.date.
- Fix: swift-snapshot-testing with a hosted target; every time-dependent component takes now or t; fonts registered in setup; a matrix of states × idle, open and over 2 min × live and practice × three type sizes × Increase Contrast, plus stage combinations × palettes, liftoff frames and watch sizes; a pinned simulator; record and verify on the same Xcode; perceptualPrecision about 0.98.
- Correction applied: the mac job also runs SwiftLint and `swift test`. What's missing is an `xcodebuild test` step on a matching runner.

**SWUI-12 Prototype techniques that won't translate cheaply** (medium, M, before reskin; confirmed)
- Evidence: a fixed 390×844 layout (style.css:44-55, :389, :495, :526, :607). Full-screen feTurbulence grain overlay (style.css:58-66, body.html:203). textPath patch (labour.js:396-400). Typewriter in aria-live (home.js:389-409). 3D cover drag (style.css:355-373, launch.js:17-38). Custom nav (:569-571). Hover (:81).
- Fix: adaptive stacks tested at SE and Pro Max, with START/STOP layoutPriority and ViewThatFits dropping the trace first; grain baked into assets and none in labour; an ArcText view or cached render for the patch; AttributedString reveal with a full accessibility label (TextRenderer if on iOS 18); rotation3DEffect plus DragGesture with the dock in safeAreaInset, tap-to-toggle and a "Launch labour mode" accessibility action; a styled system TabView; pressed states instead of hover.

**SWUI-13 Rocket as code Shapes, scenery as tinted vectors, driven by a tested build model** (medium, L, Phase 6; confirmed)
- Evidence: home.js:113-130 (SVG path strings), :146-153 (regex blueprint), :155-169 (clip), :208-228 (rAF paint), :46-86 (rules in JS only). content.js:41 (PALETTE_FOR covers only demo weeks; home.js:310 has no fallback). :336-344 (absolute chips). :177-179 (7.5px stencils). :190-195 (hit targets).
- Fix: a pure BuildProgress.evaluate in MissionCore (status, paint, must-dos left, focus stage, palette derived from progress); a RocketPart enum of Paths with a bottom mask, and the blueprint as a dashed stroke with animated dashPhase; paint animated only on change, with the last-shown value stored; template SVG scenery; a single scale transform with unscaled chip text; invisible per-stage buttons for accessibility.

**SWUI-14 Haptics: .sensoryFeedback for taps, Core Haptics for ignition, no phone breathing pulse** (low, S, before reskin; confirmed)
- Evidence: TimerTab.swift:46 and :140 (a new, unprepared, identical generator each time). sensoryFeedback on iOS 17 and watchOS 10. labour.js:158-159. B4.9 haptics setting.
- Fix: heavy for start, lighter or success for stop, warning for a flag, selection for steppers; one AHAP for ignition from a liftoff-only engine; check supportsHaptics and the setting; breathing as a visual ring, with an optional watch tick.

**SWUI-15 Migrate in risk order** (low, S, before reskin; confirmed)
- Evidence: eight Labour/*.swift files with stock UI. HomeView.swift:5-6 (Phase 6). B10. LaunchOptions.swift.
- Order: (1) foundations (tokens, fonts, ButtonStyles, cards, contrast test, snapshot harness); (2) labour Timer; (3) Call with CallButton, ContactRow and 999; (4) Plan (night summary), Coach, Decoder; (5) launch control, practice, liftoff, End labour, splashdown; (6) setup sheets; (7) watch on the same tokens; (8) home scene and briefings once BuildProgress exists. A LaunchOptions switch between stock and reskin for each screen, deleting the stock version once replaced.

### Privacy, regulation and trust

The foundations are good: no backend, analytics or accounts, a never-synced labour store kept out of backups, and engine copy that signposts rather than diagnosing.

**PRT-01 The practice run must never hide real labour mode and must be isolated** (high, M, before reskin; partly)
- Evidence: requirement 4. Review log E9. About 1 in 13 UK babies are born preterm (Bliss, Tommy's). ThresholdNotifier.swift:52-60 has no session marker. CallTab.swift:38-41 and LabourRootView.swift:162-178 dial real numbers. Stores.swift:25-29 supports an in-memory store.
- Fix: real LAUNCH reachable at every gestation, with the drill separate and visibly different, never in place of it; Stores.labourContainer(inMemory: true) with isDrill on the session and every TapEvent; no system notifications (or PRACTICE-prefixed ones cleared on exit); "In a real labour this rings <unit>" with the script kept; a persistent DRILL watermark and a one-tap "This is real" exit; all four hazards in the hazard log.
- Correction applied: high rather than critical, because nothing yet hides LAUNCH or shares a pipeline.

**PRT-02 "Keep timing" appears when the NHS call point is met** (high, S, before reskin; confirmed)
- Evidence: GoNoGoEngine.swift:143-145 (establishing/patternNotYetSustained up to 3600 s, thresholds.json:41-44). StateCopy.swift:15, :28-32, :57-58. Review log T2 ("5-1-1", a US rule; research 02:74). NHS page: regular every 5 min or more often, with no duration. Research 02:86. The prototype does the same (labour.js:100-102).
- Problem: a tired partner reads the headline as "don't call yet". This is the one output that can delay care, and it pushes the app towards an algorithm deciding when to seek care.
- Fix: the midwife decides T2 before the reskin; in the UK, once the criterion is met, the headline repeats the NHS instruction and the hour becomes information, or callTriage fires on the NHS criterion; a test that "Keep timing" never appears while any NHS criterion is met; update fixtures and E5/E13.

**PRT-03 An intended-purpose statement and an MHRA qualification note** (high, S, now; partly)
- Evidence: plan.md:169 and :189 frame the risk mainly around one phrase. MHRA stand-alone software guidance v1.10: p.12 (algorithms are usually devices; referral advice is unlikely to be), p.20, p.39 (signposting unlikely; first-aid and red-flag filtering may be), p.11 (purpose set by store copy; disclaimers don't cure claims; indicative words). If it were a device, likely Class I (p.27; GB registration). A planned 2027 consultation (not independently verified). StateCopy.swift:84-86.
- Fix: docs/regulatory/intended-purpose.md and a one-page note walking the flowchart and mapping outputs to signposting; cord-prolapse positioning as quoted RCOG reference text; no output that says don't call; store copy and social posts kept in the repo with a lint banning monitor, detect, predict, triage as a claim, accurate, clinically proven and "know when to go"; re-check whenever outputs change.
- Correction applied: the cord-prolapse text is already sourced to RCOG (StateCopy.swift:97-100, 159-165). The fix is presentation, not attribution.

**PRT-04 Clinical safety management now** (high, M, now; confirmed)
- Evidence: plan.md:340 and :360. 40+ Open review items. No hazard log, safety case or incident route. DTAC C1.1.1 and DCB0129, with NHS England reviewing DCB0129 and DCB0160. Hazards in code: ignored permission result (ThresholdNotifier.swift:19-21), no Time Sensitive (:52-59), US rules selectable by a UK user (MissionProfileForm.swift:18-19), and 999 behind a long-press in plan.md:328 (the WIP Call tab shows it always; only the Timer tab hides it). The NHS signs-of-labour page is due for review on 9 Nov 2026.
- Fix: docs/safety/hazard-log.md (hazard, cause, effect, harm, severity and likelihood, controls, test, residual risk) seeded with these plus stale numbers, forgot-to-stop, drill confusion, device disagreement, battery and stale sources; a named CSO; midwife review of rules and copy before the reskin and of all content before TestFlight (with NMC check, scope, version and date); a "Report a safety concern" route, response target, expedited-fix plan and source re-check every release.

**PRT-05 No privacy policy, label plan or manifest, and no plan for data reaching the developer** (medium, M, Phase 6; partly)
- Evidence: none in the plan; no *.xcprivacy. UserDefaults is a required-reason API (AppModel.swift:89, plus App Group defaults). Guideline 5.1.1(i). Apple: data processed only on device isn't "collected". ICO fee £52. TriageScript.swift:97-101 puts her name, hospital number and notes on the card.
- Fix: a plain-English policy (on-device data, backups, nothing sent unless shared, third-party contacts, deletion) linked in App Store Connect and Settings; PrivacyInfo.xcprivacy for app, widget and watch (CA92.1, 1C8F.1); write "no analytics or crash SDKs" as a rule; before TestFlight, a tester notice with explicit consent, dummy names, a DPIA, a feedback retention period and the ICO fee.
- Correction applied: plan.md:233 says only "No analytics in v1", so the crash-SDK rule must be written down. Medium.

**PRT-06 Rule out CloudKit for health data** (medium, S, before reskin; partly)
- Evidence: plan.md:230 and Stores.swift:4-7 claim the two stores satisfy 5.1.3. Stores.swift:19 (in backups). Health data in PlanningModels.swift:10-15 and 155-161. Guideline 5.1.3(ii).
- Fix: amend B3 (no CloudKit, iCloud Drive or NSUbiquitousKeyValueStore for any pregnancy, plan or labour data); share with her by PDF or text; record and disclose the backup decision; correct the Stores.swift comment; a CI check on cloudKitDatabase and iCloud entitlements.
- Correction applied: both stores are .none today and there are no iCloud entitlements. Medium.

**PRT-07 Prepare the App Store health submission** (high, S, Phase 7; confirmed)
- Evidence: Apple's regulated medical device declaration for Health & Fitness and Medical apps in the UK, EU/EEA and US, shown on the product page (the "early 2027" date for existing apps is unverified and irrelevant for a new app). Guideline 1.4.1. The US region (MissionProfileForm.swift:18-19), Cleveland Clinic copy (StateCopy.swift:153-157) and T7 with no US review. EU MDR Rule 11 class IIa.
- Fix: declare "No" for the UK backed by the PRT-03 note; Health & Fitness category; an in-app "How the advice works" page listing every rule with its source and the app's own numbers (T5), telling him to check with her midwife; App Review notes; UK-only availability; US region hidden in release.

**PRT-08 Saved hospital and contacts: system picker, user-confirmed triage numbers, 111 fallback** (high, M, Phase 6; confirmed)
- Evidence: PlanningModels.swift:16-17 and 98-101. Review log line 25. Guidelines 5.1.1(iii) and 5.1.2(v). NHS: call 111 if the unit can't be reached. NHS content licence terms.
- Fix: places and people with roles; CNContactPicker copying only name and number; any unit list used for name and address only, under licence with attribution; the triage number typed or confirmed from her notes or the tour, with a last-checked date and a 36-week re-check; keep the system call confirmation; "Can't get through? Call 111" next to the unit; 999 always visible in labour mode; contacts in the privacy policy.

**PRT-09 No pregnancy-loss pathway and no discreet mode** (high, S, Phase 6; confirmed)
- Evidence: no loss content. plan.md:277, :318, :33. Research 04:154. Tommy's (1 in 4 pregnancies end in loss). NHS miscarriage page.
- Fix: "Pause or end the mission" in Settings and the overflow menu (cancel notifications, stop widget and story, humour off, NHS, Tommy's, Miscarriage UK and Sands support, delete option) written with the midwife, with no CAPCOM voice; discreet mode by default until 14 weeks (neutral notification text and widget).

**PRT-10 Deletion, export and retention miss places data lives** (medium, M, Phase 6; partly)
- Evidence: plan.md:283. ThresholdNotifier.swift:47-50 leaves delivered notifications. pdfCacheURL and App Group defaults (B3). The watch store (B6). Stores.swift:33. Guideline 5.1.1(i).
- Fix: "Delete everything" across planning, labour and watch stores (via a wipe event), App Group defaults, widget and Live Activity, pending and delivered notifications, PDF caches and share files, tested end to end; at End labour, keep, export (PDF or CSV) or delete the log; warn that the labour log isn't backed up.
- Correction applied: export isn't labour-only (Settings export and ShareLink are planned). The gaps are complete deletion and the retention choice.

**PRT-11 The bespoke launch skips the disclaimer, and "NHS-led" implies endorsement** (medium, S, before reskin; confirmed)
- Evidence: launch.js:64-67 and 350-357 go straight to enterLabour, while the WIP LaunchGate has the right words (HomeView.swift:127-150) and plan.md:340 requires a disclaimer at entry. body.html:75 "UK · NHS-led". HomeView.swift:138 "follows NHS advice" (but T2 and T5 are app-defined). NHS identity rules. ICO poll on fertility apps.
- Fix: the LaunchGate text the first time the cover is lifted in each pregnancy, then one line in orbit ("Based on NHS advice, not a diagnosis. Her midwife's advice comes first. Emergency: 999."); liftoff skippable and skipped with reduced motion or a red flag; "Built on NHS guidance" and "Not affiliated with or endorsed by the NHS"; "is based on" instead of "follows"; reviewer badge and per-manual dates only after real sign-off; a visible privacy promise (research 03:185).

**PRT-12 Disclaimers won't limit liability for injury** (medium, M, Phase 7; confirmed)
- Evidence: Consumer Rights Act 2015 s65(1). MHRA p.11. The Law Commission product liability review (consultation date not independently verified). No liability item in the plan.
- Fix: publish through a limited company; product liability and tech E&O cover that includes consumer health software, with the labour features described to the insurer; terms of use restating the purpose; a written reviewer agreement, checking whether her own cover extends to product review.

**PRT-13 Most of the data is hers: co-author the plan and ask before broadcasting** (medium, S, Phase 6; confirmed)
- Evidence: PlanningModels.swift:13-15 and 155-161. B2. Requirement 2. EndLabourView.swift:11. Research 02:265.
- Fix: "Agreed with her on <date>" per section and a "What changed since <week>" history; "Send her the plan to check"; agreement status in labour; a blank wellbeing line and "Has she OK'd this message?" in the broadcast; no features that monitor her (location, Health data).

**PRT-14 Watch timing needs the phone's privacy and wording controls** (medium, S, Phase 4-5; confirmed)
- Evidence: B6 and plan.md:314. Store hardening only in Apps/MissionControl/Persistence/Stores.swift. Research 03:206. Guidelines 5.1.2(vi) and 5.1.3(i).
- Fix: a shared store factory; StateCopy headlines unchanged on the watch, with sources and disclaimers on the phone; drill flag and wipe event over WatchConnectivity; no HealthKit or HKWorkoutSession in v1 (record HealthKit explicitly); watch-alert hazards in the log (missed haptic, wrist down, out of range).

**PRT-15 Present the dad check-in as signposting, store little, and add urgent routes** (low, S, Phase 6; partly)
- Evidence: sheets.js:189-208 (scored outcomes, Samaritans only). MHRA p.39 ("Self assessment"). NHS urgent mental health help (111 mental health option; 999 if life is at risk).
- Fix: call it a check-in, never a screening (no EPDS or PHQ-9 thresholds); keep only the latest answers and include them in Delete everything; add 111 (mental health option) and 999; cite the 1-in-10 figure on screen; have the helpline numbers checked in the review log.
- Correction applied: the figure is sourced in research 01:252 and plan.md:65. Only the prototype's source line omits it.

### Tests, CI and the delivery plan

The core is well tested: the B5 matrix, the EWC Acas example, decoding of every bundled file and lint self-tests (107 on main, 121 on the branch). Everything outside MissionCore has little or no signal.

**TCI-01 No schema versioning or migration test, and either store failing blocks labour mode** (high, M, before reskin; partly)
- Evidence: PlanningModels.swift:6-25 and 154-162. Stores.swift:11-37 (no migrationPlan). AppModel.swift:19-21. MissionControlApp.swift:7 and 17-18. try? saves (LabourSessionModel.swift:286-288; AppModel.swift:60-62). plan.md:262.
- Fix: SchemaV1 and a migration plan; an on-disk v1 store test; open labour separately with defaults and 999 if planning fails; a save-failure banner; a device install-over-install check.
- Correction applied: nothing has shipped, additive changes migrate automatically, and V1 can be declared later to match what shipped. The real deadline is the first TestFlight build. Decoupling labour mode and surfacing save failures matter now.

**TCI-02 The mac job never runs on PRs** (high, S, now; confirmed)
- Evidence: ci.yml:32-36 (gated on main or a needs-mac label; on a pull_request event github.ref is refs/pull/N/merge). SwiftLint only in the mac job (:42). B13.4 contradicts this. The repo is public, the default branch is claude/sleepy-goldberg-ra4cso, main is unprotected, and there is no run for feature/labour-mode. GitHub-hosted runners are free for public repos. Branch: `swift format --strict` passes, `swiftlint --strict` exits 2 with 9 errors.
- Fix: the mac job on every pull_request (optionally path-filtered), concurrency cancel-in-progress, main protected with Linux, content and mac jobs required, main as default, B9 and B13.4 corrected.

**TCI-03 B10 no longer fits** (medium, M, now; partly)
- Evidence: plan.md:349-362 (Phase 6 in 3 weeks, watch in 2, total 11 to 13). The prototype's size (home.js 673 lines, nine manuals, launch.js). Labour tabs read BirthPlanRecord and triagePhone. plan.md:314.
- Proposed sequence: (1) week 1: split the WIP, fix CI, SchemaV1, app tests; (2) weeks 2 to 3: port prototype rules to MissionCore, plan, unit and contact models, phone handling; (3) weeks 3 to 6: reskin labour, cover and practice with real data, snapshots, internal TestFlight; (4) weeks 6 to 9: watch spike, sync with lossy-transport tests, watch UI, then the Live Activity; (5) weeks 9 to 14: home, briefings, manuals, builder and PDF, external group A; (6) weeks 14 to 16: hardening, midwife sign-off, `--release` lint, group B. Record this as B14.
- Correction applied: the Plan and Call screens aren't blocked (the data and editors exist and requirements extend them), the watch was already in scope, and the 14 to 18 week estimate is unsupported. Medium.

**TCI-04 The practice run will collide with real sessions unless isolated by design** (high, M, before reskin; confirmed)
- Evidence: LabourSessionModel.swift:78-87 and :89-90. AppModel.swift:36 and 55-58. home.js:592-593. launch.js:14 (the cover auto-closes after 7 s). Review log E9.
- Fix: a separate model on Stores.labourContainer(inMemory: true) with a virtual clock, an in-app alert sink and a PRACTICE banner; practice scripts in the LabourFixture JSON format so they double as tests; tests that a real launch after an abandoned practice starts clean, practice adds no UNNotificationRequest and doesn't write the on-disk store, the real LAUNCH takes the same taps at every week from 4+0 to 42+0, and before 37+0 practice and real are separate explicit choices; the window rule in MissionCore with boundary tests at 36+6 and 37+0.

**TCI-05 Ending labour wipes every pending reminder, and Focus silences alerts** (high, S, now; confirmed)
- Evidence: ThresholdNotifier.swift:47-50 and 52-60. Entitlements (App Group only). UKContentTests.swift:51-55 (registration due 42 days after birth). plan.md:268. Apple Time Sensitive documentation. The class already uses a `labour.scheduled.` prefix (line 11).
- Fix: remove only `labour.` identifiers; a protocol seam for the notification centre with a fake; .timeSensitive plus the entitlement, tested on a device under Sleep and Do Not Disturb; warn in labour mode if permission or Time Sensitive is off.

**TCI-06 The app layer has no tests, though the model was built to be testable** (high, M, before reskin; confirmed)
- Evidence: project.yml:29-110 has no test targets. Package.swift has no MissionUI tests. ci.yml:47-54 builds only. plan.md:345 and :368. Seams at LabourSessionModel.swift:49-60, Stores.swift:25-30 and LaunchOptions.swift:5-7. Untested: survival of kill (:20-21), undo expiry (:131), mid-labour thresholds (:114-118), Lamport restore (:280-282), and openContraction (:71-74), which differs from ReducedLog's. E11.
- Fix: an app-hosted MissionControlTests (Swift Testing) covering on-disk rebuild, undo at 9 s and 11 s, applyThresholds, end and relaunch, a flag surviving relaunch; after the reskin, snapshots for each state at three sizes and two XCUITests (start, stop, terminate, relaunch; practice never touches the real session); `xcodebuild test` in CI.

**TCI-07 Stage gating and other rules exist only in untested JavaScript, next to a different engine** (medium, M, before reskin; partly)
- Evidence: home.js:44-56, 81-86 and 494-497. labour.js:26, 58-95 and 86-95 (its 999 branch also omits cord and seizure). PregnancyCalendarTests.swift:87-95 (the paternity deadline at 25+0 to 25+6, inside stage 1).
- Fix: MissionCore types for stage rules, locks, the radar and the launch window; a property over weeks 4 to 42 and random done-sets that no deadline or safety item is ever locked; tests that HOLD releases on completion and stage 4 opens only after birth; must and safety marks in checklist.json, linted; labour copy only from StateCopy and TriageScript; the JS engine removed from the spec.
- Correction applied: labour.js has a crude gap split. HOLD only marks the stage, and items stay tickable, while weeks and stage 4 lock. isLocked exempts deadline items but not safety items. Medium.

**TCI-08 The sync convergence test proves nothing, and high-water marks can miss events** (medium, M, Phase 4-5; partly)
- Evidence: EventLogTests.swift:253-271 (the `rest` patch). EventMerger.swift:16-27. TapEvent.swift:87-94. plan.md:310. Undecodable events dropped silently (LabourModels.swift:64-66, LabourSessionModel.swift:277-279). `.movement` added on this branch (TapEvent.swift:20-21).
- Fix: a contiguous per-device seq with prefix acknowledgement and resend from the first gap; a seeded transport simulator (drop, duplicate, reorder, delay, 20-min partition, reinstall) asserting convergence without `rest`; an `.unknown` event kind preserved and relayed; golden JSON for every event version.
- Correction applied: normal reordering doesn't lose events because the transferUserInfo queue still delivers. Loss needs a lost queue plus a mark-based resend. The transport is unbuilt and failures mostly over-alert. Medium.

**TCI-09 Prove on hardware that the watch works as main timer** (high, S, Phase 4-5; confirmed)
- Evidence: plan.md:314 and :320. The watch shell. Return to Clock defaults to 2 minutes.
- Fix: a 2 to 3 day spike measuring taps from wrist raise to start for the app at the default setting, a complication, the Smart Stack or Live Activity, and an extended runtime session; check Water Lock, rise haptics and forwarded phone notifications; record a B13 amendment; acceptance test of no more than 2 taps.

**TCI-10 The TestFlight plan lacks groups, recruitment timing and consented data handling** (medium, M, Phase 7; confirmed)
- Evidence: plan.md:360 and :369. Review log line 6. A public repo. External TestFlight needs App Review.
- Fix: group A (6 to 10 dads at 12 to 30 weeks, from the first home-plus-builder build, for 8+ weeks); group B (6 to 10 dads at 33 to 37 weeks, expecting 3 to 5 real labours); 2 or 3 experienced dads replaying their labours as practice runs; the midwife at two practice runs; partner consent; a private feedback form; a device matrix (oldest and newest OS, small phone at AX3, out of range 20+ min, Sleep Focus and Low Power, force-quit and reboot, airplane mode, tel: locked and unlocked, data kept across builds, and the 25 Oct 2026 clock change, when times like 01:30 occur twice).

**TCI-11 CI builds with Xcode 16.4 while the app ships from 27.1; tools float** (medium, S, now; confirmed)
- Evidence: CI job 121505687517 used Xcode_16.4 on macos-15-arm64 (Swift 6.1). Local Xcode 27.1 and Swift 6.4. Linux on swift:6.2-noble. Unpinned brew installs (XcodeGen 2.46.0, SwiftLint 0.65.1). Node 20 deprecation on checkout v4. App Store uploads need Xcode 26+ since 28 April 2026.
- Fix: runs-on macos-26 with xcode-select of the local version printed at the start; Linux on swift:6.4 when available; XcodeGen and SwiftLint pinned via Mint or versioned downloads, cached; actions/checkout v5.

**TCI-12 Split the WIP commit** (medium, S, now; confirmed)
- Evidence: commit 1fa98d8's message. 9 strict lint errors, including LabourAlertPlanner.swift:77 (121 characters) and TriageScript.swift:48 (6 parameters), the rest in HomeView.swift:138 and :143, BirthPlanEditor.swift:19, ThresholdEditor.swift:11 and :33, and TimerTab.swift:258 and :262. `git diff main --stat`: 31 files, 3,249 insertions, including EventLog and TapEvent.
- Fix: PR 1 with the MissionCore pieces (TriageScript, LabourAlertPlanner, the movement event), persistence, LabourSessionModel and ThresholdNotifier, lint fixed (TriageScript.build takes one input struct) and the app test target, run through the mac job and merged; stock views parked as a reference branch.

**TCI-13 Property tests prove only determinism** (medium, S, before reskin; confirmed)
- Evidence: GoNoGoEngineTests.swift:206-228 and 252-281 (uniform 30 to 900 s, default thresholds). Review log T1 and content-lint.py:82 claims. A simulated generator finds only about 0.2 to 0.3% of logs regular at 5 min or less.
- Fix: a pattern-biased generator (base 120 to 480 s with jitter, gaps, an open last contraction); monotonicity properties (a tighter profile is never lower, duration 0 is at least as high as any duration, adding a flag never lowers the raw state, a flag state never drops while the flag is on); 2,000+ cases with a fixed seed.

**TCI-14 Tap-to-call and contacts need tested number handling in the core** (medium, S, before reskin; confirmed)
- Evidence: PlanningModels.swift:98-101 (+44 (0) becomes +4401…; "½" accepted) and 16-17. Review log line 25.
- Fix: a PhoneNumber type with table tests ((0) after +44, 0044, spaces, dashes, ext, letters rejected, 999, 111 and 112 fixed); a Contact model in planning schema v2 with a migration test; a number check at set-up; any bundled unit list in content JSON with provenance, lint and yearly review.

**TCI-15 Clinical copy outside the content JSON escapes the lint, and the release check never runs** (medium, S, before reskin; confirmed)
- Evidence: content-lint.py:206-211 (`--release`) isn't run (ci.yml:28), and there is no release workflow. App-layer copy at CallTab.swift:28 and LabourRootView.swift:135-147. StateCopyTests.swift:14-43 and UKContentTests.swift:112-122 scan only engine copy and JSON. content-lint.py:97-103 accepts only URLs in docs/research, and docs/research/04-week-by-week.md is untracked.
- Fix: port the prototype copy into JSON with an extended Briefing schema (her, baby and you lenses, CAPCOM, askHer); scan string literals in Apps/** and MissionUI for forbidden phrases; move the red-flag labels into MissionCore beside StateCopy; commit research 04; a release workflow (tag, archive, `content-lint.py --release`) blocking external builds until sign-off is recorded.

## What the review missed (completeness check)

A final critic looked for angles the ten reviewers under-weighted. Each gap was checked against the repo.

### 1. Twins, booked inductions, planned caesareans and previous caesareans are not covered. The review treats every pregnancy as a single baby with spontaneous onset at term. plan.md B3 lists a `multiples` field and onboarding asks for planned mode, but Apps/MissionControl/Persistence/PlanningModels.swift has neither, and nothing in Sources or Apps mentions multiples. The review adds plannedMode for the Call tab only. It does not cover what plannedMode does to the stage gates, the 37-week LAUNCH and drill boundary, or how labour mode is entered.

**Why it matters.** Twins are usually delivered from about 36 to 37 weeks, so stage 3 and the 37+0 drill handover come too late for them, and the preterm rule fires on a normal twin labour. About 1 in 3 UK labours are induced (plan.md line 117). For those, the first labour 'event' happens on a ward and can run 24 to 48 hours, often with him sent home overnight. Contraction timing at home is the wrong tool for that. With a planned caesarean there is no LAUNCH moment at all. Planned caesarean is also the shape a VBAC or previous-caesarean labour starts from, and that needs earlier advice to call the unit.

**How to close it.** Add multiples, plannedMode (spontaneous / induction booked with date / planned caesarean with date) and previousCaesarean to the profile and to the frozen LabourSetup. Have the midwife set the rules for each shape: drill window and launch-window gauge dates for twins, the preterm threshold, VBAC call advice, and an induction 'ward mode' that has no timer-first screen and handles 'sent home overnight'. Add fixtures for twins at 36+2, induction day 2 and a planned caesarean date. Each fixture checks that gates, briefings and LAUNCH copy follow the profile, not a single 40-week template.

### 2. She is the data subject, but she has no say, and domestic abuse is missing. The app stores her health details (hospital number, notes, red flags, the birth plan, her vaccine and mental-health status) on his device. She has no consent step, no view of what is stored about her, and no way to remove it. A grep for domestic, abuse and coercion finds nothing in the docs, the research or the content.

**Why it matters.** Domestic abuse often starts or gets worse in pregnancy. The NHS asks every woman about it at booking, alone. A partner-held record of her medical details, her hospital number and her movements could be used for control, and a 'dad's app' raises that risk more than most. The privacy review covered GDPR mechanics and tester consent, not this threat model. Leaving out an NHS-standard safety topic also weakens the 'built on NHS guidance' position.

**How to close it.** Add a threat-model section for coercive use to the hazard log. Add an onboarding step: 'Show her what this app stores and agree it together', with a share-out of the summary for her and a note that she can ask for it to be deleted. Never collect her location, and keep the hospital number out of share-outs by default. Add National Domestic Abuse Helpline (0808 2000 247) and Refuge signposting, with provenance, to the Her lens and the dad check-in. Word it for him both as a possible bystander and as someone who may need help himself. Have the midwife and a DA charity review the wording.

### 3. No one plans to test the advice or the bespoke design with real users. Midwife review checks the rules on paper, and plan.md puts 'TestFlight with expectant dads' in Phase 7, after the reskin. No step tests the v2 prototype with dads, or replays the engine on real contraction logs. Because the app has no backend, nothing after launch would show false reassurance in real use either.

**Why it matters.** A labour happens rarely, and each tester can only test once. The owner has already rejected one UI, and the bespoke concept (illustration home, safety cover, orbit metaphor) has not been tested on its target users under stress. The engine fixtures the review proposes are synthetic. Without real-world logs and the decision the midwife actually made, nobody can show that 'Time to call' arrives when a triage midwife would want it. The MHRA position and the hazard log both need this evidence.

**How to close it.** Before the SwiftUI port, run moderated sessions with 5 to 8 expectant or recent dads on the v2 prototype. Use the drill script, one hand, at night brightness, with a 'call the unit' task. Record time-to-call and errors. Add an opt-in, on-device 'debrief' after splashdown that exports an anonymised event log plus what the unit said and when, shared by the user. Build a replay harness that runs the engine over these logs (and any published contraction datasets) and has the midwife judge the outputs. Record the results as clinical evaluation evidence in the hazard log.

### 4. Time handling: clock changes, revised due dates and device clock skew. Gestation uses Calendar.current with no fixed time zone. The due date is stored as a string (dueDateText). The review's sync fix ('coalesce by clock time') relies on the watch and phone clocks agreeing. No test covers the UK clock-change night. UK clocks went back yesterday, 25 Oct 2026.

**Why it matters.** A labour that runs through 01:00 to 02:00 on a clock-change night shows ambiguous or repeated times in the read-aloud script. Notifications built from date components can fire twice or not at all. The dating scan often moves the due date, and the review's rank 3 freezes gestation at session start. Before labour, though, a revised due date has to reschedule every deadline reminder (the qualifying week, the paternity notice) and recompute HOLD states without losing ticks. Watch-to-phone clock offsets of a few seconds can merge or split contractions under clock-time coalescing.

**How to close it.** Add tests for labours crossing 2026-10-25 01:00 BST to GMT and 2027-03-28 01:00 GMT to BST. Print zone-qualified times in the script. Use interval triggers, not calendar triggers, for labour alerts. Add a 'due date changed after scan' flow that reschedules the reminders (through the NotificationRouter prefix cancel) and re-runs the gates, with a test. Have each device report its clock offset in the sync handshake. Add simulator cases with offsets of ±2 s and ±30 s.

### 5. Launch risks with the App Store and the name. The app is called 'Mission Control', which is the name of an Apple macOS feature, and nothing in docs/plan.md mentions a trademark or name check. The review's regulatory item covers MHRA claims but not App Review. App Review applies Guideline 1.4.1 (medical apps get extra scrutiny and must disclose their methodology) and 5.2.5 (no Apple product or feature names). A reviewer also cannot reach labour mode or the 37-week paths without a real pregnancy.

**Why it matters.** A name rejection or a forced rebrand late in delivery means new assets, new copy and possibly a new bundle display name. Rejection loops over medical advice are common for contraction timers. If the reviewer cannot exercise the safety paths, approval stalls or a later update gets pulled.

**How to close it.** Now, search UKIPO and the App Store for the name and check it against Apple's trademark list, then choose a store name that keeps 'Mission Control' as an in-app theme only. Write App Review notes: the intended purpose, a 'How the advice works' link, and a reviewer path through the drill and a demo profile at 38 weeks, using the in-memory demo flags. Do a pre-submission check of the store copy against Guidelines 1.4.1 and 5.2.5 as part of the content-lint --release step.

### 6. The phone has to last a long labour and work without signal, and there is no paper backup. The review plans the watch battery but not the phone's. The phone carries the Live Activity, the call card and the script for up to 24 to 48 hours (inductions, a long first labour). Hospital labour wards often have poor mobile signal, and a tel: link does nothing without a cellular or Wi-Fi Calling connection.

**Why it matters.** If the phone dies or has no signal when he needs to call 999 or the ward, every safety feature is gone at once. NHS and charity advice already tells partners to keep key numbers written down. The app should support that, not replace it.

**How to close it.** Add a phone battery strip in labour mode at 20% that suggests Low Power Mode, and check that the app's redraw budget holds under it. Add 'charger and long cable' as a must-do in the hospital bag. Add a pre-flight check that Wi-Fi Calling is on. Generate a printable or saveable 'launch card' from the saved unit, the call list and the NHS call rules, with a must-do to print it and put it in the bag. Do a device test of a full overnight session at real brightness and record how much battery it uses.

