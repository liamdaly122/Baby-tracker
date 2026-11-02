# Hazard log

Started 2 November 2026 (review item PRT-04). It lists the ways the app could contribute to harm to her or the baby, what already guards against each, and what's still to do. It follows the shape of the NHS clinical risk standard [DCB0129](https://digital.nhs.uk/data-and-information/information-standards/governance/latest-activity/standards-and-collections/dcb0129-clinical-risk-management-its-application-in-the-manufacture-of-health-it-systems). That standard is for health IT used by NHS organisations, so a consumer app doesn't strictly need it. It's still the standard any NHS reviewer, the MHRA or an insurer would expect us to work to.

**Status: a first draft by the developer, not yet clinically reviewed.** The severity and likelihood ratings are provisional. They need setting by a named clinical safety officer (a registered clinician trained in clinical risk management), who also signs off each release. Until there is one, nothing here counts as a safety case.

## How to use it

- **Add a row** whenever a change brings a new way the app could mislead, delay or distract. Also add one for every safety concern reported by a user or a tester.
- **Look at the whole log before every release.** Check each control is still in place, and that its test still passes.
- **Never delete a row.** Mark it closed, with the reason and the date.

Severity: minor, significant, considerable, major, catastrophic. Likelihood: very low, low, medium, high, very high. These are the DCB0129 scales.

## The hazards

### HZ-01 The advice delays a call that should have been made

- **Causes:** a hold before "Time to call"; the "Keep timing" headline read as "don't call yet"; the app's own regularity rule (T5) not counting a pattern the NHS would; a wrong due date making preterm labour look like term.
- **Possible harm:** a late call, a birth before arrival, or a complication found late. Provisional: major / low.
- **Controls in place:**
  - The UK has no hold by default, so the app says "call" as soon as the NHS rate is met (T2).
  - Every state says "or sooner if you're worried" or "you can call any time".
  - Before 37 weeks, or with the weeks unknown, any labour means "Call now" (E9).
  - The numbers never round across the call point (`EngineSafetyTests`).
  - 500 random patterns with every gap 5 minutes or less all say to call, never "Keep timing" (`CallRuleTests`).
- **Still to do:** the midwife's decision on T2 and T5.

### HZ-02 The wrong number is dialled, or the number is out of date

- **Causes:** a typo; the unit changed its number; the wrong unit saved; a menu option left out.
- **Possible harm:** delay in reaching the unit. Provisional: major / low.
- **Controls in place:**
  - Each number shows exactly what it will dial as it's typed (`NumberCheck`).
  - A tick for "checked against her notes", and a reminder to check again from 34 weeks.
  - "Can't get through?": try again, the labour ward, NHS 111, then 999 (`CallFallback`).
  - The phone's own call confirmation.
- **Still to do:** the midwife's view on H1 and H2.

### HZ-03 999 isn't reachable quickly

- **Causes:** hidden behind a menu, a long press or a scroll.
- **Possible harm:** delay in an emergency. Provisional: catastrophic / very low.
- **Controls in place:**
  - 999 is in the top row of every labour screen, one tap away. The header sits above whichever tab is showing, and every layout of its top row has the key (`LabourRootView`, redesign rules).
  - A test checks it dials 999, and pictures of the header at every text size, live and in practice, guard it (`LabourHeaderTests`).
  - On the watch, the Call page.
- **Still to do:** nothing known.

### HZ-04 Forgotten stops, double taps or missed contractions give a false pattern

- **Causes:** tired hands, a phone in a pocket, the app killed.
- **Possible harm:** the advice comes too late or too soon. Provisional: significant / medium.
- **Controls in place:**
  - After 5 minutes the app asks "did it just end, or is this a new one?" rather than guess.
  - A forgotten stop can be fixed afterwards, and there's undo.
  - Gaps are only filled in a regular run.
  - All of this is tested (`TapPolicy`, `EngineSafetyTests`).
- **Still to do:** nothing known.

### HZ-05 An alert isn't seen

- **Causes:** alerts not allowed, Focus or Sleep mode, the phone on silent, the phone off.
- **Possible harm:** the change to "call" is missed. Provisional: major / low.
- **Controls in place:**
  - Time Sensitive alerts, which break through Focus.
  - "Labour alerts" on the home screen asks before labour.
  - The watch has its own alerts.
  - Alerts are asked for after labour mode has started, so the prompt never holds it up.
- **Still to do:** say plainly in labour mode when alerts are off.

### HZ-06 A practice run is mistaken for real labour, or real labour for practice

- **Causes:** starting the drill when labour has really begun; a drill left running.
- **Possible harm:** no real alerts, and calls not made. Provisional: major / low.
- **Controls in place:**
  - The drill asks "Is she having tightenings…?" first, and "yes, it's real" goes to LAUNCH.
  - The drill is kept in memory, never dials and never sends alerts.
  - It has its own look, and a real session always ends a drill (`PracticeRunTests`).
- **Still to do:** nothing known.

### HZ-07 The phone and watch disagree

- **Causes:** taps on both devices, sync delays, out of range.
- **Possible harm:** confusion about whether to call. Provisional: significant / low.
- **Controls in place:** one shared engine, and one event log merged the same way on both.
- **Still to do:**
  - Watch alert hazards (wrist down, out of range) as the watch becomes the main timer (PRT-14).
  - Testing on real devices.

### HZ-08 A storage problem loses the hospital's numbers or the log

- **Causes:** a damaged store, a full phone, a failed update.
- **Possible harm:** no number to call, or a lost pattern. Provisional: major / very low.
- **Controls in place:**
  - The two stores open separately, and labour mode always works.
  - A backup copy of the numbers (the emergency card).
  - A clear message when it isn't saving (`StorageTests`).
- **Still to do:** nothing known.

### HZ-09 The wrong rules for her

- **Causes:** the US option chosen by a UK user; a wrong due date; the weeks unknown.
- **Possible harm:** advice that doesn't match the NHS's. Provisional: major / low.
- **Controls in place:**
  - The weeks are fixed when labour starts.
  - "Is she 37 weeks or more?" is asked when they're unknown, and the answer is "Call now" until he says yes.
  - The US option only appears in development builds, never in release (PRT-07).
- **Still to do:** nothing known.

### HZ-10 A red flag is missed, or turned off by mistake

- **Causes:** he doesn't know the signs; a brush of the screen turns a flag off.
- **Possible harm:** the advice to call now or call 999 is lost. Provisional: catastrophic / low.
- **Controls in place:**
  - Flags stay on until he turns them off, and turning one off asks first, on the phone and the watch.
  - "Baby moving less" and "Waters broke" are on the timer screen, and the rest are one tap away under More.
- **Still to do:** the midwife's review of the red-flag list and wording.

### HZ-11 The NHS advice the app is built on changes

- **Causes:** NHS pages are updated, and the app's copy and rules aren't.
- **Possible harm:** advice that no longer matches the NHS. Provisional: significant / medium.
- **Controls in place:** every clinical content item has its source and the date it was read, and a release build needs a midwife's sign-off on each (content lint).
- **Still to do:**
  - Re-check every source before each release.
  - The NHS "signs that labour has begun" page is due for review on 9 November 2026 (review PRT-04).

### HZ-12 He relies on the app instead of calling, or the app and the unit disagree

- **Causes:** trusting the screen over his worry, or over what the unit said.
- **Possible harm:** delay. Provisional: major / low.
- **Controls in place:**
  - "Her midwife's advice comes first" at LAUNCH.
  - "Call any time you're worried" on every state.
  - After a logged call, the app follows what the unit said, and asks him to call back if anything changes.
- **Still to do:** the midwife's review of the wording.

### HZ-13 The phone dies or the app is closed mid-labour

- **Causes:** a flat battery, an update, the app killed.
- **Possible harm:** the log and advice are lost at a key moment. Provisional: significant / medium.
- **Controls in place:**
  - The log is saved after every tap, and labour mode picks up again on reopening.
  - The watch keeps its own timer.
- **Still to do:** a low-battery reminder, and real-device testing.

### HZ-14 Getting into labour mode is slow or distracting

- **Causes:** the safety cover, the lift-off animation.
- **Possible harm:** a missed contraction or a delay. Provisional: minor / low.
- **Controls in place:**
  - The cover is one tap.
  - Labour mode starts at once, and the lift-off plays over it, can be skipped, and doesn't play before 37 weeks, with Reduce Motion or in Low Power Mode.
- **Still to do:** nothing known.

### HZ-15 The wrong tone at a hard moment

- **Causes:** humour or space-mission language during an emergency, a loss or neonatal care.
- **Possible harm:** distress, and lost trust. Provisional: significant / low.
- **Controls in place:**
  - No humour in labour mode or in any advice.
  - After a loss, the app goes quiet, with plain words and support lines (`OutcomeTests`).
- **Still to do:** the bereavement midwife's review (L1 to L6).

### HZ-16 Hard to read or use in the dark, under stress

- **Causes:** small text, low contrast, small buttons, one hand.
- **Possible harm:** misreading the advice, or mis-taps. Provisional: significant / low.
- **Controls in place:**
  - Text is tested for contrast (`LabourPalette.textPairs`).
  - Text is 11 points or more, and grows with the phone's text size.
  - Controls are 56 points, and labour mode is dark.
  - All of this is covered by picture tests.
- **Still to do:** testing with real users at night.

### HZ-17 Her private details are seen by someone else

- **Causes:** alerts on the lock screen; a shared birth plan; a lost phone.
- **Possible harm:** distress, or risk where there's domestic abuse. Provisional: considerable / low.
- **Controls in place:**
  - Everything stays on the phone and watch, with no accounts and no servers.
  - Sharing only happens when he taps Share.
  - "Delete everything" on the home screen's Your data page, on the phone and watch (`DeleteEverythingTests`).
  - Alerts say only what to do, for example "Time to call your maternity unit", and the numbers behind it. The alert planner is never given her name, her hospital number or the unit's name, so no alert can show them.
- **Still to do:**
  - Alerts still show that labour is under way ("Call your maternity unit now", "24 hours since her waters went"). Discreet mode should cover them (PRT-09).
  - The domestic abuse findings in the review.

## Reporting a safety concern

During TestFlight, testers report concerns through TestFlight's feedback, or by email with "Safety" in the subject, as the tester notice says (`docs/store/testflight.md`). An in-app "Report a safety concern" route comes before the App Store (`docs/release-checklist.md`). Each concern gets a row here within a working day, and a decision on whether to pull or fix the build.
