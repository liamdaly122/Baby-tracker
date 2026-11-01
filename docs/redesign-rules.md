# Redesign rules

Binding rules for "the redesign" (the plan calls it the reskin): putting the prototype's look onto the working app. They come from the first full review, actions 8 and 9 (`docs/reviews/2026-10-26-full-review.md`: ux-01, NRC-09, CS-13, SWUI-01, SWUI-02, SWUI-05, SWUI-08 to SWUI-15, content-04, content-07, content-08, content-14, ux-10, TCI-07). Where the prototype and these rules disagree, these rules win. A screen isn't finished until it meets every rule that applies to it, and the tests that check them pass.

## 1. The prototype is the look, not the rules

- Take layout, shapes, colours and type from the prototype. Take nothing else: no words, numbers, thresholds or decisions from its JavaScript.
- Every piece of advice, every number and every line of copy comes from the app's tested core:
  - the advice: `EngineOutput` and `StateCopy`;
  - the call script: `TriageScript`;
  - "Can't get through?": `CallFallback`;
  - the practice run: `Drill`;
  - the launch card: `LaunchWindow`;
  - support after a loss or neonatal care: `SupportDirectory`.
- The prototype's own engine teaches the wrong 999 set and has no easing, stale or needs-fixing states. It's ignored.
- The hospital, its numbers and the people to call come from what he saved, never from sample data.

## 2. Calls

- **Every control that says "Call X" dials X**, through `PhoneNumber.telURL`. Nothing copies a number to the clipboard instead of dialling.
- **999 is one tap from every labour screen**, and always visible: the red 999 button in the labour top bar. When the advice is "Call 999", the biggest control on the timer dials 999.
- **The Call tab keeps its order:**
  1. 999, first when it's a 999 situation;
  2. the unit, with its name, number and "press 2";
  3. after the call;
  4. "Can't get through?" (try again, labour ward, 111, 999);
  5. the script;
  6. getting there;
  7. the backup unit;
  8. the people;
  9. 999 again.
- **In a practice run nothing dials.** Every call control shows the number and "In a real labour this rings…".

## 3. Red flags

- **The flag controls are built from every red flag** (`RedFlagLayout`): "Baby moving less" and "Waters broke" pinned, the rest one tap away. No hard-coded subset.
- **A flag turns on with one tap.** It turns off only after "Turn it off", so one stray tap can't lower the advice.

## 4. Every state is designed

The redesign must cover each of these, live and in a practice run:

- **START/STOP is on screen in every state**, without scrolling, on the smallest supported iPhone. When cards stack up (a question, the drill's guide, a 999 button), the stats and history give way first, never the big button. Today it can end up under the tab bar on a standard iPhone, in the practice run or while "When did her waters go?" is showing.
- **The five advice levels:**
  - no regular pattern yet;
  - keep timing;
  - time to call;
  - call now;
  - call 999.
- **The timer:** no taps yet; a contraction running; one running for over 2 minutes; a contraction that needs fixing; "Are they still coming?"; "They've stopped".
- **Questions:** "Is she 37 weeks or more?"; "When did her waters go?"; the forgotten-stop question; "How strong?".
- **Calls:** after a call, while the call covers things, and "Call them back".
- **Other screens:** not saving; no hospital number; the drill's guide and debrief; the end of labour mode and each outcome.

## 5. Readable at 3am

- **Labour screens are true black.** Big bright surfaces are only for things held up for someone else to read: the birth plan sheet for the midwife. The call script's paper card is a design decision for the redesign: keep it, or make it ink on black. The timer's orbit scene from the agreed prototype counts as dark: a near-black sky (#05060F to #101737) and an Earth no brighter than #1D4B7A.
- **Text passes WCAG 2.2 contrast:** 4.5:1, or 3:1 for large text, 18pt (or 14pt bold) and over. Every colour pair the app uses is checked by a test (`LabourPaletteTests`).
  - Hot colours behind text use the fill tokens: `LabourTheme.fill(for:)` and `textOnFill(for:)`.
  - Bright orange (`urgent`) is for strokes, icons and text on black only. Never put white text on it.
- **Controls are big enough:**
  - every labour control is at least 56pt (`LabourTheme.minimumControlSize`);
  - small choice chips (strength, nudge a minute) have at least a 44pt tap area (`LabourTheme.chipSize`).
- **Text is never smaller than caption 2** (11pt).
- **Text grows with the phone's text size (Dynamic Type)** everywhere. Labour mode is capped at the third accessibility size, so the big button stays on screen; the home screen isn't capped.
- **Fonts:** the prototype's fonts are OFL-licensed. Ship the licence text with them. Use the display face only at 22pt and over, and plain sans-serif for safety copy. They're in `Sources/MissionUI/Fonts` with their licences: League Gothic (display), Instrument Sans (body, the plain sans-serif) and Martian Mono (labels). Use them through `MissionType`, which keeps text at 11pt or more and the display face at 22pt or more.

## 6. VoiceOver

- Every control has a label, and toggles say whether they're on.
- **When the advice changes level, VoiceOver says the new headline once.** Nothing that updates every second is announced.
- Illustrations are one element with a short description, never a group of hidden buttons. A typewriter effect is visual only: VoiceOver gets the whole line at once.
- The practice run says "Practice" before every headline.

## 7. Motion, battery and haptics

- **One clock ticks once a second in labour mode.** Views are given the time; they don't each run their own timer.
- Animations run only while they mean something, such as a contraction running, and stop under Reduce Motion and Low Power Mode. No blur or grain effects in labour.
- **Haptics:**
  - start is heavy;
  - stop is lighter;
  - a red flag is a warning;
  - steppers are a selection tick.
- The phone doesn't pulse a breathing rhythm; breathing is a visual ring.

## 8. The decoder

- **The worry scale has four levels:**
  - "Routine";
  - "Worth asking about";
  - "Staff will watch closely";
  - "Serious: the team acts fast".
- Every level has a label. Nothing says "Act now" about something he can't act on.

## 9. How the redesign is done

- **Order:**
  1. foundations: colours, fonts, button styles, cards, the contrast test, picture tests;
  2. the timer;
  3. the Call tab;
  4. Plan, Coach and Decoder;
  5. launch, practice run, end of labour;
  6. set-up screens;
  7. the watch;
  8. the home screen.
- **Each redesigned screen gets picture tests** (`SnapshotTests`): live and practice, at small, normal and the largest labour text size. The old screen stays until its replacement passes, then it's deleted.
- **Copy stays plain English.** No humour in labour mode, and no forbidden phrases ("you are in labour", "established labour", "diagnose").
