# Where Mission Control is up to

Plain-English progress, kept up to date with each pull request. Last updated 1 November 2026.

## In short

The heart of the app works. He presses LAUNCH, taps START and STOP for each contraction, and the app tells him when to call the maternity unit, following NHS guidance. It has a call script, red flags, a practice run and a watch app. More than 350 automatic tests check it on every change.

Two things haven't happened yet:

- **It hasn't been on a real iPhone.** Everything so far has run on the Mac's pretend iPhone (the simulator). See "Trying it on your iPhone" below.
- **Most of it still looks like a plain iPhone app.** The redesign has started: all five labour tabs now look like the agreed prototype (v3): the timer, Call, Plan, Coach and Decoder. The other screens follow one at a time.

Right now we're doing the redesign. The labour timer ([PR #14](https://github.com/liamdaly122/Baby-tracker/pull/14)) and the Call tab ([PR #15](https://github.com/liamdaly122/Baby-tracker/pull/15)) are done. Plan, Coach and Decoder are built and tested, waiting to be merged ([PR #16](https://github.com/liamdaly122/Baby-tracker/pull/16)).

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
| 9 | Readable in the dark, big buttons, large text, VoiceOver | Foundations done. Done for the five labour tabs: the timer ([PR #14](https://github.com/liamdaly122/Baby-tracker/pull/14)), Call ([PR #15](https://github.com/liamdaly122/Baby-tracker/pull/15)), and Plan, Coach and Decoder (waiting to be merged, [PR #16](https://github.com/liamdaly122/Baby-tracker/pull/16)). The other screens follow |
| 10 | Hard moments: loss, admission, neonatal care, false alarms | Done. Later: discreet mode in early pregnancy, support for her recovery |
| 11 | A storage problem never stops labour mode or loses the hospital's number | Done |
| 12 | Legal and privacy groundwork (medical device rules, privacy policy, "delete everything") | Can start any time, alongside the rest |
| 13 | Automatic checks on every change, and tests for the app itself | Done (GitHub settings still to change) |
| 14 | One labour engine shared by the phone and watch | Done |
| 15 | Phone and watch always agree | Done (the core) |
| 16 | Saved hospital, and a call list of people | Main part done. Later: home births, finding the hospital on a map, messaging family after the birth |
| 17 | A birth plan built up over the weeks | How it's stored: waiting to be merged ([PR #10](https://github.com/liamdaly122/Baby-tracker/pull/10)). Phase 6: the guided builder, the PDF and reminders |
| 18 | The watch as the main timer | Phases 4 and 5 |
| 19 | Fair week-by-week stages on the home screen | Done: the rules are built and tested ([PR #13](https://github.com/liamdaly122/Baby-tracker/pull/13)). The screens that show them come in Phase 6 |
| 20 | Weekly briefings and the home screen | Phase 6 |

## What's next, in order

1. **The redesign**, screen by screen, following `docs/redesign-rules.md`. The timer ([PR #14](https://github.com/liamdaly122/Baby-tracker/pull/14)) and Call tab ([PR #15](https://github.com/liamdaly122/Baby-tracker/pull/15)) are done; Plan, Coach and Decoder are waiting to be merged ([PR #16](https://github.com/liamdaly122/Baby-tracker/pull/16)). Next: launch and the practice run, set-up, the watch, and the home screen.
2. The legal and privacy groundwork (12).
3. A first test build for real phones (TestFlight).
4. The watch as the main timer (18), the lock screen and the Live Activity.
5. Phase 6: the home screen's rocket and checklists, weekly briefings and the birth plan builder (20).
6. Final checks, the midwife's sign-off, then a wider test.

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

## Trying it on your iPhone

This can happen any time; nothing in the app is blocking it. It needs:

1. The iPhone plugged into the Mac, with Developer Mode on (Settings, Privacy & Security).
2. Your Apple ID signed in to Xcode. You'll need to type the password yourself.
3. Your team ID put into `Configs/Signing.local.xcconfig`, then a build to the phone.

A free Apple ID works, but the app stops opening after 7 days until it's rebuilt from the Mac. Some features may need the paid Apple Developer Program (£79 a year), which TestFlight needs anyway.

There are test switches for the simulator and the phone. They're listed at the top of `Apps/MissionControl/App/LaunchOptions.swift`. For example, `-demoLabour` opens labour mode with an hour of contractions, and `-failLabourStore` shows what happens if the phone can't save.

## Waiting on you

- **Merging** PR #13 (the fair stages) once its checks pass.
- **GitHub settings:** make `main` the default branch, and protect it so the checks must pass before merging. I can do this with your go-ahead.
- **The midwife review** of the advice rules in `docs/content-review-log.md`. It's best done before the redesign. It now includes two questions about the hospital numbers (H1, H2) and one about the birth plan in labour (P2). There's also a question on which checklist items count as must-dos (S1). The new rules for loss and neonatal care (L1 to L6) need a bereavement midwife in particular.
- **Deciding on the Apple Developer Program**, before TestFlight.
