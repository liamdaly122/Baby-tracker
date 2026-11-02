# Where Mission Control is up to

Plain-English progress, kept up to date with each pull request. Last updated 2 November 2026.

## In short

The heart of the app works. He presses LAUNCH, taps START and STOP for each contraction, and the app tells him when to call the maternity unit, following NHS guidance. It has a call script, red flags, a practice run and a watch app. More than 350 automatic tests check it on every change.

One thing hasn't happened yet:

- **It hasn't been on a real iPhone.** Everything so far has run on the Mac's pretend iPhone (the simulator). See "Trying it on your iPhone" below.

The redesign is finished: every screen now looks like the agreed prototype (v3), from labour mode to the watch and the home screen with its lift-off ([PR #14](https://github.com/liamdaly122/Baby-tracker/pull/14) to [PR #20](https://github.com/liamdaly122/Baby-tracker/pull/20)). Next is the legal and privacy groundwork.

## What works today

- **Labour mode:** LAUNCH, timing contractions, the advice on when to call, undo and fixing mistakes (a forgotten STOP, a double tap).
- **Red flags** such as her waters breaking or bleeding, each with what to do.
- **The Call tab:** tap-to-call, a script to read out, "Can't get through?" (labour ward, 111, 999), getting there with directions, a backup hospital, and the people on his call list (call or text), always below the unit.
- **Alerts** that break through Sleep and other Focus modes.
- **999 is one tap away** on every labour screen, and the "call now" panels are easy to read in the dark.
- **The practice run:** a pretend labour to rehearse with, which never gets in the way of a real one.
- **The watch app:** its own timer that stays in step with the phone, now in the prototype's look. It has not been tried on a real watch.
- **The home screen:** the launch site with the countdown to the due date, the set-up list, "When to call", and LAUNCH, with the lift-off from 37 weeks.
- **Set-up screens:** the profile (due date, her details), the hospital or birth centre and a backup (with a reminder to check the numbers against her notes, and again from 34 weeks), the people to call (from Contacts or typed in), and when-to-call settings for a midwife's advice.
- **The birth plan:** her top five, each section with whose decision it is, and what she'd want if plans change. You edit a copy and Save or Discard; "Read it through with her" records when she agreed it, and the app says what's changed since. In labour it's read-only and marks anything she hasn't seen. It never goes to iCloud.
- **When things go differently:** ending labour mode asks how everyone is. If the baby needs extra care, or after a loss, the app goes quiet (no humour, countdown or LAUNCH) and shows support lines (Sands, Miscarriage UK, Tommy's, Bliss, Samaritans) and practical help with leave and registration. This also works from the home screen at any week.
- **If the phone has a storage problem**, labour mode still works, using a backup copy of the hospital's numbers, and says clearly if it isn't saving.
- **Written but mostly not on screen yet:** the pregnancy calendar, checklists, glossary, coaching cards and quizzes. Their screens come in Phase 6.

## The review's 20 fixes

| # | What it's about | Where it is |
|---|---|---|
| 1 | Never sound reassuring when it's time to call | Done |
| 2 | Missed taps and forgotten stops | Done |
| 3 | Fix her weeks when labour starts; ask "37 weeks or more?" if unknown | Done |
| 4 | Alerts that get through | Done |
| 5 | Phone numbers that dial correctly | Done |
| 6 | Red flags and the call script | Done |
| 7 | The practice run | Done |
| 8 | Rules for the redesign (every Call button dials, 999 always one tap away) | Done: the rules are in `docs/redesign-rules.md` |
| 9 | Readable in the dark, big buttons, large text, VoiceOver | Done for every screen in the redesign ([PR #14](https://github.com/liamdaly122/Baby-tracker/pull/14) to [PR #20](https://github.com/liamdaly122/Baby-tracker/pull/20)) |
| 10 | Hard moments: loss, admission, neonatal care, false alarms | Done. Later: discreet mode in early pregnancy, support for her recovery |
| 11 | A storage problem never stops labour mode or loses the hospital's number | Done |
| 12 | Legal and privacy groundwork (medical device rules, privacy policy, "delete everything") | Started: the drafts are written, waiting to be merged. Next: "Delete everything" and the other app changes |
| 13 | Automatic checks on every change, and tests for the app itself | Done (GitHub settings still to change) |
| 14 | One labour engine shared by the phone and watch | Done |
| 15 | Phone and watch always agree | Done (the core) |
| 16 | Saved hospital, and a call list of people | Main part done. Later: home births, finding the hospital on a map, messaging family after the birth |
| 17 | A birth plan built up over the weeks | How it's stored: done ([PR #10](https://github.com/liamdaly122/Baby-tracker/pull/10)). Phase 6: the guided builder, the PDF and reminders |
| 18 | The watch as the main timer | Phases 4 and 5 |
| 19 | Fair week-by-week stages on the home screen | Done: the rules are built and tested ([PR #13](https://github.com/liamdaly122/Baby-tracker/pull/13)). The screens that show them come in Phase 6 |
| 20 | Weekly briefings and the home screen | Phase 6 |

## What's next, in order

1. The legal and privacy groundwork (12). The documents are drafted; next come the app changes: "Delete everything", the privacy manifests, and hiding the US option.
2. A first test build for real phones (TestFlight).
3. The watch as the main timer (18), the lock screen and the Live Activity.
4. Phase 6: the home screen's rocket and checklists, weekly briefings and the birth plan builder (20).
5. Final checks, the midwife's sign-off, then a wider test.

The redesign, done screen by screen following `docs/redesign-rules.md`, is finished.

The full plan, with the reasons, is in `docs/plan.md` (section B14).

## The redesigned timer

The labour timer now matches the agreed prototype (v3): the night sky and the Earth behind it, the five-level strip, the big headline, the call button inside the advice, the last hour as a line, three big numbers, the two flag switches, the round START button, and the prototype's own tab bar, in its three fonts (League Gothic, Instrument Sans and Martian Mono, free to use under their licence).

A few things differ from the prototype on purpose, each because a safety rule needs it:

- **Red panels are a darker red.** The prototype's bright red with cream words is hard to read (3.3 to 1). The "Call now" panel, its level chip, a lit flag and "Real labour? Launch" use the prototype's own darker red instead (5.7 to 1).
- **999 is always in the top row**, next to "Baby's here?". The prototype only showed 999 in an emergency.
- **The big button never leaves the screen.** It sits just above the tab bar. When there's a lot to show, it shrinks to its smallest size, the numbers row steps aside, and the rest scrolls above it.
- **The undo bar sits above the big button, not over it.** Over a small button it hid the running clock.
- **Nothing moves except the breathing rings while a contraction runs.** The prototype's twinkling stars, passing satellite, glowing line and blinking dot are still.
- **No text is smaller than 11 points.** The prototype's smallest labels were 8.5, so they're a little bigger, and everything grows with the phone's text size.
- **Buttons are bigger:** flags and controls are at least 56 points tall, small chips at least 44.
- **"They've stopped" is cream, not lilac,** so it's readable over the Earth.
- **Kept from the app:** the list of contractions for fixing a mis-tap, with "Baby moved", is below the flags (scroll down). "Labour settings" moved to the bottom of the Plan tab, as the top row has no room for it next to 999. "End practice" is in the practice run's guide card.

## The redesigned Call tab

The Call tab now matches the prototype's dark red "comms" panel: the unit on its own plate with a big "Call triage" button, the number to copy and "then press 2", the numbered "If nobody answers" list, the script on a ruled notepad, getting there, the backup unit, the people to ring with their own "Call" buttons, and a red 999 plate. The headers on the Plan, Coach and Decoder tabs now use the prototype's style too.

Where it differs from the prototype, and why:

- **The order follows the safety rules.** "After the call" (what they said) comes straight after the unit, and 999 comes last as well as first in an emergency. The prototype had 999 in the middle and no "After the call".
- **The 999 plate is the darker red,** so the cream words are readable, and it says when to ring 999 in the app's own words.
- **Small call buttons use the display font a little bigger** (22 points, not 17), because the rules keep that font for big text.
- **Kept from the app:** the backup unit, a text button beside each person, and "Labour settings" on the Plan tab. The prototype's "Copy 'We're heading in'" message isn't added: the app doesn't have that message yet.
- **Added, not in the prototype:** the one-line advice strip above the other tabs, so a change in the advice is never missed.

## The redesigned Plan, Coach and Decoder tabs

- **Plan:** her plan on one printed sheet on a dark desk, with a rubber stamp saying whether she's checked it, her top choices numbered in red, each section in a ruled box, "If plans change" boxed in red, and a yellow sticky note for him.
- **Coach:** the stages as stops on a line (Early to First hour), and that stage's cards one under another, each with mint bullet points and a red-edged "Avoid" box.
- **Decoder:** the search box, then each term in big type with how much to worry, what it means, and a question to ask.

Where they differ from the prototype, and why:

- **The app's own words throughout:** "Birth plan" rather than "Flight plan", the stage name "Established" rather than "Active", the app's search hint, and the sticky note built from her plan and the coaching cards.
- **Four worry levels, not three,** with the plain labels the rules set ("Routine" up to "Serious: the team acts fast"). A long label moves under the term when it doesn't fit beside it.
- **A warning above the plan** when she hasn't checked it, or it has changed since she did, and a red "Not checked with her" on any section that's his draft. The prototype only had the stamp.
- **The stamp sits above the heading,** not beside it: at the 11-point minimum it's too wide to fit next to it.
- **No drop shadows** under the sheet or the sticky note: the rules allow no blur in labour mode.
- **At the largest text sizes** the coach's stages become a list.
- **Kept from the app:** "Labour settings" at the bottom of the plan, each coaching card's source, and tapping a term for its other names and source.

## LAUNCH, the practice run and the end of labour

- **LAUNCH** now sits in the prototype's yellow-and-navy hazard-striped well, under a safety cover that says "Lift cover to launch". Tap the cover (or drag it up) and it tips back to show the big red LAUNCH key. Tap that and labour mode starts. The cover is the "are you sure?", so nothing launches from a pocket, and it closes itself again after a few seconds. While it's up, the app says what it does and doesn't do, and from 30 weeks the "Run the drill" key sits under LAUNCH.
- **The practice run** uses the prototype's deep teal cards with a cyan edge: the "Is she having tightenings…?" question before the drill (the "yes, it's real" answer is red), the training hangar, and "End the practice run?".
- **The end of labour** uses the dark choices of labour mode. When everyone is well, it opens on the prototype's dawn, with the capsule under its parachutes on the sea, and a paper card for the time, the details and the message. When the baby or she needs extra care, it's the same paper card with no dawn. After a loss, it's plain words only.

Where it differs from the prototype, and why:

- **The lift-off came later**, with the home screen (see "The redesigned home screen").
- **The disclaimer shows while the cover is up**: what the app does and doesn't do, and that her midwife's advice comes first. The prototype didn't have it at launch.
- **The heading is plain** ("The baby's here.") rather than "Splashdown.", and there's no mission patch: there's no humour in labour mode.
- **Nothing moves:** the hazard stripes, the falling capsule and the ripples are still.
- **Fixed:** the "Tap again to end labour mode" button was white on bright orange (hard to read); it's now cream on the darker red.

## The redesigned set-up screens

Mission profile, the hospital, the people to call, the birth plan and when to call now use the prototype's "Ground control" and "Flight plan" look: cream paper, big League Gothic headings, small capital labels over pale boxes, tick boxes, chips to pick from, dark buttons, and the hospital on a teal card. As he types a number, a green line says what it will dial, or a red one says what's wrong.

Where they differ from the prototype, and why:

- **Dark inside labour mode.** The same screens open from Labour settings during labour, so there they use the prototype's night colours instead of bright paper (the "dark at 3am" rule).
- **They're pages, not sheets.** They open the way they always have, with a back button, rather than sliding up over the home screen. The redesigned home screen keeps it that way.
- **The app's own wording and fields**, which are more than the prototype's: her details for the call, the backup unit, "whose decision" on each part of the plan, and the call thresholds.
- **People can be moved up the list** with an arrow button, as the old list could be dragged.
- **Not added from the prototype:** "Use example numbers" and the ready-made "We're heading in" messages, which the app doesn't have.

## The redesigned watch

The watch now looks like the prototype's: a small pill for the advice ("No pattern", "Time to call", "Call now"), a call button from "time to call" (yellow, then red), the round Start button with its yellow ring and the time in the display font, and "4 min apart · 15 in hour" in small type underneath. The Call page uses the phone's dark red comms look, the questions use its cream cards, and LAUNCH is the phone's red key, round, with a cream ring that fills as you hold it.

Where it differs from the prototype, and why:

- **The darker red** behind cream text, as on the phone, so it's readable.
- **No clock of our own:** the watch already shows the time at the top.
- **The hospital's full name** on the call button, cut short if it's long, rather than just its first word (a first word like "St" could be anyone). VoiceOver reads it in full.
- **No glow** round the running button (no blur in labour mode).
- **Kept from the app:** the questions, undo, the Call page with "If nobody answers", and the red flags page.

Checked on the Apple Watch Ultra 2 simulator, and it now has its own picture tests (39 pictures: the advice pill at every level, the main screen at each stage, a question, a call row and LAUNCH, at three text sizes), run on every change like the phone's.

## The redesigned home screen

The home screen now opens on the prototype's launch site: the rocket on its pad by the tower, the commander and flight director beside it, and a sky that changes with the weeks (dawn before 20 weeks, then day, overcast, dusk, and night from 37 weeks). Over the sky are the big countdown ("T–10"), "Days to launch", the due date and the week. Underneath, on cream paper, "Ground control" lists the set-up, with a line in small capitals saying how each one stands (amber when something needs doing). At the bottom is the prototype's dock: "When to call", and LAUNCH in its hazard-striped well under the cover.

From 37 weeks, tapping LAUNCH plays the lift-off: 3, 2, 1, ignition, the rocket climbing as the sky turns to space, then "Labour mode".

Where it differs from the prototype, and why:

- **A shorter lift-off that never holds him up.** It takes about 4 seconds, not the prototype's 7.7. Labour mode starts the moment LAUNCH is tapped and the lift-off plays over the top, so a contraction can't be missed; tapping anywhere skips it. It doesn't play before 37 weeks (the prototype skips it then too), with Reduce Motion on, or in Low Power Mode.
- **The rocket is drawn whole.** Building it stage by stage over the weeks comes in Phase 6, with the weekly briefing, the baby's size, CAPCOM, appointments and the checklists.
- **A still picture.** No drifting clouds, twinkling stars or blinking lights, and the lift-off's smoke isn't blurred.
- **At the largest text sizes** the countdown's small print moves below the picture so it doesn't cover the rocket, and "When to call" sits above LAUNCH. The home screen's text isn't capped.
- **Kept from the app:** the full set-up list (including alerts, "Something's happened" and, from 37 weeks, the practice run), and the disclaimer under the lifted cover.
- After the birth or a loss there's still no launch site, countdown or LAUNCH.

Checked on the iPhone simulator, with 20 new picture tests: the launch site in all five skies, the countdown, Ground control, the dock with the cover down and up, and three moments of the lift-off.

- **Fixed:** GitHub's check on `main` failed once after the watch was merged, because the first few picture tests timed out on a slow machine. The picture tests now try a drawing again before failing.

## Legal and privacy groundwork

These are first drafts, written for the right people to check. None of them is legal advice or a safety sign-off yet.

- **What the app is for** (`docs/regulatory/intended-purpose.md`). One statement that the App Store listing, the website and the app all have to match. It covers who it's for, what it does and doesn't do, and the words we never use about it, like "monitors labour", "accurate" or "NHS-approved".
- **Is it a medical device?** (`docs/regulatory/mhra-qualification-note.md`). It's a borderline case.
  - For: its advice is only ever "phone the unit" or "call 999", which the MHRA's guidance says is unlikely to make an app a device.
  - Against: that advice comes from rules the app applies to her contraction times, which the guidance says usually does.
  - If it is a device, it's the lowest class (Class I): a self-declared UKCA mark, paperwork, and registering with the MHRA.
  - Northern Ireland follows EU rules, which are stricter.
  - The note recommends getting a regulatory adviser's view before testers outside the family.
- **The hazard log** (`docs/safety/hazard-log.md`). The 17 ways the app could contribute to harm, such as a delayed call, a wrong number or a missed alert. Each one lists what already guards against it in the app and what's still to do. The ratings need a clinical safety officer.
- **The privacy policy** (`docs/privacy-policy.md`). In plain English: everything stays on the phone and watch, there are no accounts, servers, analytics or adverts, and the app itself never goes online. It also says exactly what leaves the phone, and only when he taps: calls, texts, directions in Maps, shared plans and web links. It needs a name and contact email before it can go online.
- **The App Store listing** (`docs/store/app-store-listing.md`). A first go at the name, subtitle, description and keywords, plus the answers App Store Connect will ask for.
- **A new automatic check** (`Scripts/claims-lint.py`). It fails GitHub's checks if the listing ever makes a claim the intended purpose rules out.

Next: "Delete everything" inside the app (planning, labour, the watch, alerts and the backup card), the privacy manifests Apple requires before TestFlight, hiding the US option, and a privacy page in the app.

## Trying it on your iPhone

This can happen any time; nothing in the app is blocking it. It needs:

1. The iPhone plugged into the Mac, with Developer Mode on (Settings, Privacy & Security).
2. Your Apple ID signed in to Xcode. You'll need to type the password yourself.
3. Your team ID put into `Configs/Signing.local.xcconfig`, then a build to the phone.

A free Apple ID works, but the app stops opening after 7 days until it's rebuilt from the Mac. Some features may need the paid Apple Developer Program (£79 a year), which TestFlight needs anyway.

There are test switches for the simulator and the phone. They're listed at the top of `Apps/MissionControl/App/LaunchOptions.swift`. For example, `-demoLabour` opens labour mode with an hour of contractions, and `-failLabourStore` shows what happens if the phone can't save.

## Waiting on you

- **A regulatory adviser's opinion** on whether the app counts as a medical device (`docs/regulatory/mhra-qualification-note.md`). Best before testers outside the family.
- **A clinical safety officer:** a registered clinician trained in clinical risk who can own the hazard log and sign off releases. Your midwife reviewer may know someone, or may be able to do it.
- **For the privacy policy:** whose name the app is published under (you, or a limited company, which the review recommends for insurance), and a contact email.

- **GitHub settings:** make `main` the default branch, and protect it so the checks must pass before merging. I can do this with your go-ahead.
- **The midwife review** of the advice rules in `docs/content-review-log.md`. It's needed before the wider test. It now includes two questions about the hospital numbers (H1, H2) and one about the birth plan in labour (P2). There's also a question on which checklist items count as must-dos (S1). The new rules for loss and neonatal care (L1 to L6) need a bereavement midwife in particular.
- **Deciding on the Apple Developer Program**, before TestFlight.
