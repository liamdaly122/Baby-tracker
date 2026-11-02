# Is Mission Control a medical device? (MHRA qualification note)

Draft, 2 November 2026, for a regulatory adviser to check. It isn't legal advice, and we shouldn't rely on it until someone qualified has reviewed it. It walks through the MHRA's guidance for apps, [Medical device stand-alone software including apps (including IVDMDs), v1.10g](https://assets.publishing.service.gov.uk/media/6abf6c8c943e890cb55e5e52/Medical_device_stand-alone_software_including_apps__including_IVDMDs.pdf) (last revised October 2026; page numbers below are from that PDF), against the app as it is today and the [intended purpose](intended-purpose.md). It answers review item PRT-03 (`docs/reviews/2026-10-26-full-review.md`).

## In short

It's a borderline case.

- **As designed, there's a fair case that it isn't a device.** Every piece of advice it gives is "phone your maternity unit" or "call 999", taken from NHS pages, and the midwife on the phone makes the decision. The guidance says software that only signposts like this is unlikely to be a device.
- **The case against:** the advice comes from rules the app applies to her contraction times, and to red flags, to decide when to say "call". The guidance says decision support that applies an algorithm is usually a device. Some of the rules are the app's own, not the NHS's.
- **If it is a device, it's most likely Class I** in Great Britain. That means a self-declared UKCA mark, technical documentation, clinical evaluation, post-market surveillance and registration with the MHRA before release. It doesn't need an approved body.

**Recommendation:** get a regulatory adviser's view (or ask the MHRA) before TestFlight testers outside the family, and well before the App Store. Until then, keep every output as signposting, and keep every claim inside the intended purpose.

## The flowchart, step by step

**1. Is it software, not part of another device? Yes.** It's a stand-alone app on iPhone and Apple Watch. It doesn't drive or take data from any medical device.

**2. Does it have a medical purpose? This is the question.** The guidance's medical purposes (p. 10) are: diagnosis, prevention, monitoring, treatment or alleviation of disease, an injury or handicap; compensation for an injury or handicap; investigation, replacement or modification of the anatomy or of a physiological process; and control of conception. Wellbeing, administration and stores that keep data without changing it are not medical purposes (p. 10).

- Pregnancy and labour aren't a disease, injury or handicap. The guidance says monitoring needs "a link to a specific disease, injury or handicap" (p. 21).
- Labour is a physiological process. The guidance's only example under "investigation ... of a physiological process" is an educational one, which it says is unlikely to be a device (p. 23). Timing contractions to know when to call is closer to keeping a diary than to investigating the process. But this head is the one an adviser might use.
- The app doesn't diagnose (no "you are in labour", no stage), prevent, treat, compensate, or control conception.

**3. Does the decision-support guidance pull it in?** (p. 12)

- Software is **unlikely** to be a device if "it offers only lifestyle treatment choices or referral advice (e.g. see your GP)". Every output here is referral advice: phone the unit, or call 999.
- Decision support is **usually** a device "when it applies automated reasoning such as a simple calculation, an algorithm". The app does apply rules to her data: how often contractions come over the last hour, whether they're regular, how long that has lasted, her weeks, and any red flags.

**4. The symptom-checker appendix, the nearest example** (p. 39)

- **Unlikely to be devices:** software that "only signposts the user to suitable care e.g. see your GP, go to A&E".
- **May be devices:** software that "offers filters by red flag/severity". Here, he switches a red flag on and the app shows the NHS instruction for it.

**5. Diary or tracker** (p. 21): apps that "simply replace a written diary/log of symptoms" are unlikely to be devices, but "features that enhance the data presented may bring it into the remit". The contraction log and its summary ("every 4 min, lasting 60 s") are on that line.

## The case that it isn't a device

1. **Every output is signposting:** call the unit, call them back, or call 999. There's never a diagnosis, a stage of labour, a prognosis or a treatment.
2. **The advice is the NHS's**, quoted with its source. The thresholds are the NHS's, and a midwife can change them.
3. **The midwife decides.** The app helps him phone. She decides whether to stay at home or come in, and the app then shows what she said.
4. **It never discourages a call.** Every state says he can call any time he's worried. There's no "safe to wait" or "don't call", and red flags only ever raise the advice.
5. **Nothing is measured.** It has no sensors and no Apple Health. It only records the times he taps, like a pen-and-paper log.

## The case that it is

1. **The "time to call" moment comes from rules applied to her data,** not just a copy of the NHS page. The guidance treats an algorithm in decision support as usually a device (p. 12).
2. **Some parameters are the app's own, not the NHS's.** These are how irregular "regular" can be (T5), and how much sooner early callers are told to call when a hold is set (T6). The urgent rules (T3 and T4) are the NHS's. See `docs/content-review-log.md`.
3. **Red flags raise the advice to "call now" or "999".** That looks like the severity filtering the appendix says may make software a device (p. 39).
4. **The output can change when she gets care.** An earlier or later call is a real clinical consequence, even though the unit makes the decision.

## If it is a device

- **Classification** (p. 27). Stand-alone software counts as an active device. Rule 12 puts "all other active devices" in Class I. Rule 10 (Class IIa) applies to devices "intended to allow direct diagnosis or monitoring of vital physiological processes". The app doesn't diagnose and doesn't measure anything vital, so Class I looks right. The appendix also says symptom checkers are Class I unless they "allow direct diagnosis" (p. 39).
- **What Class I would mean in Great Britain:**
  - a self-declared UKCA mark;
  - technical documentation and a clinical evaluation;
  - a quality and risk management process (the hazard log in `docs/safety/hazard-log.md` is the start of that);
  - post-market surveillance and incident reporting;
  - registration with the MHRA before release (p. 27: "All devices placed on the Great Britain market must be registered with MHRA").
- **Northern Ireland is different** (p. 1). The EU rules apply there, and under the EU's software rule (MDR Rule 11) decision-support software is often Class IIa, which needs a notified body. The App Store's "United Kingdom" includes Northern Ireland, so this needs an answer before release.
- **Disclaimers don't change the answer** (p. 11). A line like "this is not a medical device" doesn't help if medical claims are made or implied elsewhere. What decides it is the intended purpose and how we describe the app everywhere.

## What keeps it on the right side today

- **Engine wording.** Every headline is an instruction to phone, never a statement about her body. `StateCopyTests.forbidden` fails the build on "established labour", "you are in labour", "diagnos" and similar.
- **Content.** The content lint checks the bundled content for the same phrases, and requires a source on every clinical item.
- **Store and promotional copy.** `Scripts/claims-lint.py` checks everything in `docs/store/` against the banned claims in the intended purpose.
- **Disclaimer.** The disclaimer shows when the LAUNCH cover is lifted: "Based on NHS advice, not a diagnosis. Her midwife's advice comes first. Emergency: 999."
- **Never a reason to wait.** "You can call any time you're worried" is on every state, and no output ever lowers the advice.
- **Thresholds.** They're the NHS's by default, a midwife can change them, and the safety ceilings can't be relaxed (content lint).

## To do

1. **A regulatory adviser's opinion** on this note, or a question to the MHRA. Either way, keep the answer in this folder.
2. **Decide Northern Ireland and the EU**: release in Great Britain only at first, or meet the EU rules.
3. **Apple's question.** The App Store asks Health & Fitness and Medical apps whether they're a regulated medical device (review item PRT-07). Answer it from this note, once reviewed.
4. **Re-check this note:**
   - before every release;
   - whenever an output changes or a new kind of output is added;
   - when the MHRA guidance changes (the GB rules are being reformed).
