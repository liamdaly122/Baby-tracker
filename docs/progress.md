# Where Mission Control is up to

Plain-English progress, kept up to date with each pull request. Last updated 31 October 2026.

## In short

The heart of the app works. He presses LAUNCH, taps START and STOP for each contraction, and the app tells him when to call the maternity unit, following NHS guidance. It has a call script, red flags, a practice run and a watch app. More than 320 automatic tests check it on every change.

Two things haven't happened yet:

- **It hasn't been on a real iPhone.** Everything so far has run on the Mac's pretend iPhone (the simulator). See "Trying it on your iPhone" below.
- **It still looks like a plain iPhone app.** The design from the prototype comes later, in "the redesign" (the plan calls it the reskin).

Right now we're working through the safety fixes from the October review, because they need to be in place before the redesign.

## What works today

- **Labour mode:** LAUNCH, timing contractions, the advice on when to call, undo and fixing mistakes (a forgotten STOP, a double tap).
- **Red flags** such as her waters breaking or bleeding, each with what to do.
- **The Call tab:** tap-to-call, a script to read out, "Can't get through?" (labour ward, 111, 999), getting there with directions, a backup hospital, and the people on his call list (call or text), always below the unit.
- **Alerts** that break through Sleep and other Focus modes.
- **The practice run:** a pretend labour to rehearse with, which never gets in the way of a real one.
- **The watch app:** its own timer that stays in step with the phone. It has not been tried on a real watch.
- **Set-up screens:** the profile (due date, her details), the hospital or birth centre and a backup (with a reminder to check the numbers against her notes, and again from 34 weeks), the people to call (from Contacts or typed in), the five-point birth plan, and when-to-call settings for a midwife's advice.
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
| 8 | Rules for the redesign (every Call button dials, 999 always one tap away) | Before the redesign |
| 9 | Readable in the dark, big buttons, large text, VoiceOver | Before the redesign |
| 10 | Hard moments: loss, admission, neonatal care, false alarms | Before the redesign |
| 11 | A storage problem never stops labour mode or loses the hospital's number | Done |
| 12 | Legal and privacy groundwork (medical device rules, privacy policy, "delete everything") | Can start any time, alongside the rest |
| 13 | Automatic checks on every change, and tests for the app itself | Done (GitHub settings still to change) |
| 14 | One labour engine shared by the phone and watch | Done |
| 15 | Phone and watch always agree | Done (the core) |
| 16 | Saved hospital, and a call list of people | Main part waiting to be merged ([PR #9](https://github.com/liamdaly122/Baby-tracker/pull/9)). Later: home births, finding the hospital on a map, messaging family after the birth |
| 17 | A birth plan built up over the weeks | Before the redesign (how it's stored); Phase 6 (the screens) |
| 18 | The watch as the main timer | Phases 4 and 5 |
| 19 | Fair week-by-week stages on the home screen | Before the redesign |
| 20 | Weekly briefings and the home screen | Phase 6 |

## What's next, in order

1. Merge the hospital and call list (16, PR #9).
2. How the birth plan is stored, so it can be built up over the weeks (17).
3. The hard moments (10).
4. The redesign rules and accessibility (8 and 9), and the home screen stages (19).
5. **The redesign**, then a first test build for real phones (TestFlight).
6. The watch as the main timer (18), the lock screen and the Live Activity.
7. Phase 6: the home screen, weekly briefings and the birth plan builder (20).
8. Final checks, the midwife's sign-off, then a wider test.

The full plan, with the reasons, is in `docs/plan.md` (section B14).

## Trying it on your iPhone

This can happen any time; nothing in the app is blocking it. It needs:

1. The iPhone plugged into the Mac, with Developer Mode on (Settings, Privacy & Security).
2. Your Apple ID signed in to Xcode. You'll need to type the password yourself.
3. Your team ID put into `Configs/Signing.local.xcconfig`, then a build to the phone.

A free Apple ID works, but the app stops opening after 7 days until it's rebuilt from the Mac. Some features may need the paid Apple Developer Program (£79 a year), which TestFlight needs anyway.

There are test switches for the simulator and the phone. They're listed at the top of `Apps/MissionControl/App/LaunchOptions.swift`. For example, `-demoLabour` opens labour mode with an hour of contractions, and `-failLabourStore` shows what happens if the phone can't save.

## Waiting on you

- **Merging** PR #9 (the hospital and call list) once its checks pass.
- **GitHub settings:** make `main` the default branch, and protect it so the checks must pass before merging. I can do this with your go-ahead.
- **The midwife review** of the advice rules in `docs/content-review-log.md`. It's best done before the redesign. It now includes two questions about the hospital numbers (H1, H2).
- **Deciding on the Apple Developer Program**, before TestFlight.
