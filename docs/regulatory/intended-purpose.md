# Intended purpose

Draft, 2 November 2026. Not yet reviewed by a regulatory adviser, the clinical safety officer or a midwife. This is the statement everything we say about the app has to match: the App Store listing, the website, social posts and the app's own words. The MHRA judges whether software is a medical device by what its maker says it's for, including the App Store description ([MHRA guidance v1.10g](https://assets.publishing.service.gov.uk/media/6abf6c8c943e890cb55e5e52/Medical_device_stand-alone_software_including_apps__including_IVDMDs.pdf), p. 11), so a careless sentence in a listing can change what the app is. Whether it's a device is worked through in [mhra-qualification-note.md](mhra-qualification-note.md).

The layout follows the MHRA's [Crafting an intended purpose in the context of software as a medical device](https://www.gov.uk/government/publications/crafting-an-intended-purpose-in-the-context-of-software-as-a-medical-device-samd/crafting-an-intended-purpose-in-the-context-of-software-as-a-medical-device-samd).

## The statement

Mission Control is an iPhone and Apple Watch app for the birth partner of a pregnant woman in the UK. Before the birth, it helps him prepare: the due date, the maternity unit's numbers, the people to call and her birth plan. Once labour seems to have started, it times contractions and shows the NHS's published advice on when to phone her maternity unit. It also keeps the unit's numbers, a call script and her birth plan to hand.

It doesn't diagnose labour or anything else. It doesn't say what stage of labour she's in, and it doesn't measure anything about her or the baby. It never tells him not to call, or that it's safe to wait. The midwife he speaks to decides what happens next.

## What it does

- **Times contractions** from the start and stop times he taps on the phone or watch.
- **Compares them with the NHS advice.** The NHS says to call when contractions are regular and every 5 minutes or more often. A midwife can set her own rule instead.
- **Shows one of five headlines:** "No regular pattern yet", "Keep timing", "Time to call [the unit]", "Call [the unit] now" or "Call 999 now". Each comes with the reason, the numbers behind it and the NHS source. Every screen says he can call any time he's worried.
- **Red flags he switches on**, such as bleeding, waters that are coloured or the baby moving less, bring up "Call now" or "Call 999 now", as the NHS pages say. They stay on until he turns them off.
- **Always calls before 37 weeks.** Before 37 weeks, or if the weeks aren't known and he hasn't said she's 37 weeks or more, any labour means "Call now".
- **Helps him make the call:**
  - the unit's numbers, each showing what it will dial;
  - "Can't get through?" (the labour ward, NHS 111, 999);
  - a script to read out, and a note of what the unit said.
- **Sends alerts** when the advice changes, and offers a practice run that never dials anyone.

## Who it's for

- **The patient population** is pregnant women in the UK cared for by NHS maternity services, at any stage of pregnancy and in any pregnancy, first or later. The app treats labour before 37 weeks as "call now".
- **The user** is her partner or another birth supporter: an adult with no medical training. He may be tired, frightened, in the dark and using one hand. The app isn't for healthcare professionals, and it isn't for the pregnant woman to use on her own as a substitute for calling.
- **Where it's used:** at home, in the car and at the hospital, often at night, and with no signal. The app works offline.

## What it is not for

- Deciding whether she's in labour, or how far along.
- Deciding whether it's safe to stay at home.
- Replacing the call to the maternity unit, or her midwife's advice.
- Monitoring her or the baby. It has no sensors, and it doesn't use Apple Health.
- Use outside the UK. A US option exists for development only and is to be hidden in release builds.

## Words we use, and words we don't

Use: "times contractions", "helps you follow NHS advice on when to call your maternity unit", "based on NHS guidance", "her midwife's advice comes first", "not affiliated with or endorsed by the NHS".

Never use, about the app, in any listing, post or screen:

- "monitors" labour, her or the baby; "detects", "predicts" or "measures" labour;
- "tells you when you're in labour", "know when to go", "safe to wait", "no need to call";
- "triage" as something the app does (the unit's "triage line" is just its name);
- "symptom checker", "self-assessment", "screening" or "diagnosis";
- "accurate", "clinically proven", "medically approved";
- "NHS-approved", "NHS-endorsed", "NHS app" or the NHS logo.

The engine's wording is already checked by tests (`StateCopyTests.forbidden`) and the content lint. The store listing and other promotional copy in `docs/store/` are checked by `Scripts/claims-lint.py`.

## When to look at this again

- Before every release.
- Whenever the app gains a new kind of output, especially anything that uses her data to say something new.
- Whenever the listing, website or ads change.
- When the MHRA guidance changes.
