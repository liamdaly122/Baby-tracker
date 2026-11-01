# Where Mission Control is up to

Plain-English progress, kept up to date with each pull request. Last updated 31 October 2026.

## In short

The heart of the app works. He presses LAUNCH, taps START and STOP for each contraction, and the app tells him when to call the maternity unit, following NHS guidance. It has a call script, red flags, a practice run and a watch app. More than 350 automatic tests check it on every change.

Two things haven't happened yet:

- **It hasn't been on a real iPhone.** Everything so far has run on the Mac's pretend iPhone (the simulator). See "Trying it on your iPhone" below.
- **It still looks like a plain iPhone app.** The design from the prototype comes later, in "the redesign" (the plan calls it the reskin).

Right now we're working through the safety fixes from the October review, because they need to be in place before the redesign.

## What works today

- **Labour mode:** LAUNCH, timing contractions, the advice on when to call, undo and fixing mistakes (a forgotten STOP, a double tap).
- **Red flags** such as her waters breaking or bleeding, each with what to do.
- **The Call tab:** tap-to-call, a script to read out, "Can't get through?" (labour ward, 111, 999), getting there with directions, a backup hospital, and the people on his call list (call or text), always below the unit.
- **Alerts** that break through Sleep and other Focus modes.
- **999 is one tap away** on every labour screen, and the "call now" panels are easy to read in the dark.
- **The practice run:** a pretend labour to rehearse with, which never gets in the way of a real one.
- **The watch app:** its own timer that stays in step with the phone. It has not been tried on a real watch.
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
| 9 | Readable in the dark, big buttons, large text, VoiceOver | Foundations done. The rest happens screen by screen in the redesign |
| 10 | Hard moments: loss, admission, neonatal care, false alarms | Done. Later: discreet mode in early pregnancy, support for her recovery |
| 11 | A storage problem never stops labour mode or loses the hospital's number | Done |
| 12 | Legal and privacy groundwork (medical device rules, privacy policy, "delete everything") | Can start any time, alongside the rest |
| 13 | Automatic checks on every change, and tests for the app itself | Done (GitHub settings still to change) |
| 14 | One labour engine shared by the phone and watch | Done |
| 15 | Phone and watch always agree | Done (the core) |
| 16 | Saved hospital, and a call list of people | Main part done. Later: home births, finding the hospital on a map, messaging family after the birth |
| 17 | A birth plan built up over the weeks | How it's stored: waiting to be merged ([PR #10](https://github.com/liamdaly122/Baby-tracker/pull/10)). Phase 6: the guided builder, the PDF and reminders |
| 18 | The watch as the main timer | Phases 4 and 5 |
| 19 | Fair week-by-week stages on the home screen | The rules are built and tested, on `feature/fair-stages`. The screens that show them come in Phase 6 |
| 20 | Weekly briefings and the home screen | Phase 6 |

## What's next, in order

1. Merge the fair stages (19).
2. **The redesign**, screen by screen, following `docs/redesign-rules.md`: the timer first, then Call, Plan, Coach and Decoder, launch and the practice run, set-up, the watch, and the home screen.
3. A first test build for real phones (TestFlight).
4. The watch as the main timer (18), the lock screen and the Live Activity.
5. Phase 6: the home screen's rocket and checklists, weekly briefings and the birth plan builder (20).
6. Final checks, the midwife's sign-off, then a wider test.

The legal and privacy groundwork (12) can happen alongside any of these.

The full plan, with the reasons, is in `docs/plan.md` (section B14).

## Trying it on your iPhone

This can happen any time; nothing in the app is blocking it. It needs:

1. The iPhone plugged into the Mac, with Developer Mode on (Settings, Privacy & Security).
2. Your Apple ID signed in to Xcode. You'll need to type the password yourself.
3. Your team ID put into `Configs/Signing.local.xcconfig`, then a build to the phone.

A free Apple ID works, but the app stops opening after 7 days until it's rebuilt from the Mac. Some features may need the paid Apple Developer Program (£79 a year), which TestFlight needs anyway.

There are test switches for the simulator and the phone. They're listed at the top of `Apps/MissionControl/App/LaunchOptions.swift`. For example, `-demoLabour` opens labour mode with an hour of contractions, and `-failLabourStore` shows what happens if the phone can't save.

## Waiting on you

- **Merging** the fair stages pull request once it's open and its checks pass.
- **GitHub settings:** make `main` the default branch, and protect it so the checks must pass before merging. I can do this with your go-ahead.
- **The midwife review** of the advice rules in `docs/content-review-log.md`. It's best done before the redesign. It now includes two questions about the hospital numbers (H1, H2) and one about the birth plan in labour (P2). There's also a question on which checklist items count as must-dos (S1). The new rules for loss and neonatal care (L1 to L6) need a bereavement midwife in particular.
- **Deciding on the Apple Developer Program**, before TestFlight.
