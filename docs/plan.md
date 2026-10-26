# Baby-tracker: "Mission Control" companion app for dads. Research and plan

Author: Liam Daly
Date: 26 October 2026
Branch: claude/sleepy-goldberg-ra4cso

## Context

The repo `liamdaly122/Baby-tracker` is empty (branch `claude/sleepy-goldberg-ra4cso`, no commits). The goal is a companion app for expectant fathers that is funny and cheeky in tone but gives genuinely good guidance, with to-do trackers for everything that must be ready before the birth, and a "labour mode" companion for the birth itself (contraction timer with go-to-hospital advice, Apple Watch sync, one-screen birth plan, plain-English glossary of midwife jargon).

Decisions already made with the user:
- **Platform:** native iOS (SwiftUI) + watchOS companion.
- **Region:** UK / NHS first, with a region switch architected in so US (ACOG, 5-1-1) content can follow.
- **Theme:** Mission Control. Dad is Flight Director, baby is the Payload, mum is the Commander, midwife is Ground Control, contractions are telemetry, due date is T-0.
- **Sharing:** single-user (dad's device), no accounts in v1; export/share-outs for the birth plan, contraction log and "baby's here" broadcast.

This document is in two halves: (A) the research findings that become the app's content, and (B) the build plan.

Research method: three parallel research passes (pre-birth preparation, labour partner support, competitive landscape) across roughly 380 tool calls over NHS, NICE, GOV.UK, RCOG, Cochrane, Birthrights, Lullaby Trust, App Store and Play listings, Apple developer docs and parenting press, plus an architecture review. Full reports are preserved for commit under `docs/research/`.

---

# PART A: RESEARCH

## A1. Pre-birth preparation: everything the dad/couple needs to do (research complete; full report to `docs/research/01-pre-birth-preparation.md`)

All UK figures are 2026/27 values, sourced from GOV.UK / NHS / NICE / Lullaby Trust / RoSPA unless flagged. Leeds-specific details (MAC numbers, Register Office) were current on 26 Oct 2026 and should be user-editable, not hard-coded.

### Master timeline (becomes the week-gated checklist)

| When | Must-dos |
|---|---|
| Confirmed (wk 4–8) | Book booking appointment (8–12 wk). Ask midwife for maternity exemption certificate. Check Healthy Start eligibility (from 10 wk). Open baby budget. Read employer paternity policy quietly. Agree who to tell and when. |
| 12 wk | Dating scan (11–14 wk, combined screening). Partner's legal right to unpaid time off for 2 antenatal appointments (6.5h each) starts. Names shortlist. |
| 16 wk | Midwife appt. Whooping cough jab from 16 wk (ideally by 32). Flu jab in season. |
| 20 wk | Anomaly scan (18–21 wk, 11 conditions, not "the gender scan"). Research birth place. Start birth plan draft. Book NHS classes (Leeds "Preparation for Birth and Beyond" from ~24 wk); NCT fills 3–4 months ahead so book now. |
| 24–25 wk | **Paternity leave notice deadline: 15th week before EWC (~wk 25).** Most-missed dad deadline. Mum tells employer by same week. SPL maths. GTT 24–28 wk if risk factors. |
| 28 wk | Bloods, anti-D if Rh-neg, RSV vaccine (from 28 wk). Nursery/pram/car seat decisions, order lead-time items. Will and life insurance (appoint guardians). Sure Start Maternity Grant window opens (~wk 29). |
| 32 wk | Classes running. Start hospital bags. Fit car seat and get it checked. Birth plan draft 2. Plan route + alternative, parking, childcare/pet backups. Batch cook. Deep clean now, not at 39. Pet prep. |
| 34 wk | 28-day notice of paternity start date if fixing a date (most pick "day of birth"). Agree visitors policy. Finalise names. |
| 36 wk | Baby's position checked. Three bags packed and staged. Car seat fitted. Fuel above quarter tank. Numbers saved. Cot built, clothes washed, steriliser set up. Skills learned. Mum rehearses "labour starts when I'm alone". |
| 37+ wk | Term. Stay within ~1h. Phone on loud. Tell work you may leave mid-shift. Know MAC triggers. Sweep offered ~39–40 wk, induction discussed at 41. |
| Birth + 2 wk | Skin-to-skin, delayed cord clamping, vitamin K. NIPE within 72h. Midwife within 36h of home, day 3 check, **day 5 heel prick**, day 10–14 handover to health visitor. **Register birth within 42 days, both attend if unmarried.** Child Benefit 48h after registering. GP registration. Maternal and baby red flags. Baby blues vs PND. |

### Key facts and gotchas by module

**Admin and leave (UK).** Paternity leave: 2 weeks, as one block or two separate weeks, within 52 weeks of birth; day-one right since 6 April 2026 (Employment Rights Act 2025). Statutory Paternity Pay £194.32/wk or 90% of earnings if lower, but pay still needs 26 weeks' service and £129/wk earnings. Notice: 15th week before EWC, then 28 days for dates. Shared Parental Leave: up to 50 weeks / 37 paid, 3 blocks each, 8 weeks' notice per block, 20 SPLIT days. Unpaid parental leave 18 weeks per child, day-one right. Registering birth: 42 days (21 in Scotland); Leeds is appointment-only at Merrion House. Unmarried fathers only get parental responsibility if they jointly register. Child Benefit £27.05/wk first child, claim even if opting out of payments for High Income charge (NI credits and child's NI number), backdates 3 months max. US: FMLA 12 weeks unpaid, 50+ employee employers, 30 days' notice; paid leave only in some states.

**Money.** First-year cost roughly £8,000–£10,000 excluding childcare; the real hit is the maternity-leave income drop (SMP 90% for 6 weeks then flat rate). Buy new: car seat, cot mattress. Borrow/second-hand fine: pram frame, Moses basket (new mattress), bouncer, clothes (newborn size lasts ~3–4 weeks). Grants: Sure Start £500 (qualifying benefits), Healthy Start, Maternity Allowance (form MA1 from 26 wk). 30 hours funded childcare from 9 months; apply from 23 weeks old.

**Appointments.** 10+ appointments first pregnancy, 7+ subsequent, plus 2 scans. Reduced movements: call immediately, any hour, no home dopplers, no set kick count. Maternity exemption certificate backdates one month.

**Classes.** NHS free, 8–10 weeks before birth. NCT £200–£300 for both. Hypnobirthing £140–£250. Dad-specific: DaddyNatal, Dad Matters (Leeds 0113 244 2419), DadPad app, Baby Buddy app, Leeds Dads. Fatherhood Institute: 81% of dads were excluded from appointments during Covid.

**Birth plan.** Preference list, not a contract. Sections: place (home / alongside MLU / freestanding MLU / labour ward, with NHS safety numbers for first vs subsequent babies), partners and who attends theatre, pain relief ladder, positions and monitoring, third stage (active vs physiological; cord clamping not before 1 min per NICE), skin-to-skin, vitamin K route, feeding, cord cutting, photos, cultural needs. Gotcha: a 3-page plan nobody reads; produce a one-page top-5.

**Hospital bag.** Pack by 36 wk. Mum labour bag, mum postnatal bag, baby bag, and the dad bag: snacks and drinks, change/card for parking and vending, battery pack and long cable, toothbrush, change of clothes, swim shorts for the pool, pillow and blanket for the chair, downloaded entertainment, printed phone list, copy of birth plan. Leeds lets one partner stay overnight in the chair. Gotcha: car seat still in its box in the boot.

**Car seat.** UK law: seat until 12 or 135 cm; R129 (i-Size) rear-facing until over 15 months; R44 seats no longer sold since Sept 2024; front airbag off for rear-facing in front; driver fined up to £500. Taxi exemption: under-3s rear seat only. Never second-hand of unknown history. Transport only, not sleep; take baby out on arrival. Remove bulky coats.

**Home.** Lullaby Trust safer sleep: back, clear flat firm waterproof mattress, own cot in your room 6 months, 16–20°C, no pillows/bumpers/nests/pods, smoke-free, never sofa or armchair. Pram must lie flat from birth. Formula: boiled water left ≤30 min so still ≥70°C, one feed at a time, sterilise to 12 months. Nappies ~10–12/day. Clothes: 6–8 vests and sleepsuits in newborn and 0–3. Baby-proofing not needed until ~6 months, don't spend yet. Pets: gates up early, baby-cry recordings, scent blanket.

**Day-of logistics.** Leeds MAC: LGI 0113 392 6731, St James's 0113 206 5781, 24h, phone before coming in. Drive the route at rush hour and at 3am. Alternative route. Parking payment method. If she's alone and you're 45+ min away, name a nearby backup driver. Two backups each for other kids and pets.

**Relationship and mental health.** Sex is safe in uncomplicated pregnancy. Dads: roughly 1 in 10 experience perinatal mental health difficulties; presents as irritability, withdrawal, overwork, drinking. 70% say support for them is poor. Helplines: PANDAS 0808 1961 776 (dads' call last Monday monthly), Dad Matters Leeds, CALM 0800 58 58 58, Samaritans 116 123, Tommy's midwives 0800 0147 800, Shout text BABYBUDDY to 85258, Andy's Man Club. Mum: baby blues resolve within ~2 weeks; PND beyond that; postpartum psychosis is an emergency. Agree visitor rules before birth; dad is in charge of the door. Brief grandparents on modern safe-sleep and car-seat rules.

**Skills to learn before birth.** Nappy, top-and-tail (plain water first month, 2–3 baths/week), cord care, swaddling (hips loose, stop at rolling), TICKS for slings, winding, soothing, never shake, feeding cues (crying is the late cue), supporting breastfeeding (water and snacks every feed, take all nappies, protect sleep; National Breastfeeding Helpline 0300 100 0212), formula 70°C rule, jaundice (under 24h old = 999/A&E; dark urine or pale poo = urgent), baby red flags (≥38°C or <36°C, no wet nappy 8h, non-fading rash, floppy, blue/grey).

**Post-birth.** Discharge from ~6h vaginal, 1–2 days caesarean/instrumental. Maternal red flags: soaking >1 pad/hour or large clots, severe headache with visual changes or upper abdominal pain (pre-eclampsia can start after birth), sepsis signs (fever, confusion, breathlessness, no urine 12–18h, mottled skin), calf or chest pain. Mum's 6–8 week GP check; baby's 6–8 week check and 8-week jabs.

**Gamifiable achievements with a real payoff.** Scan Squad, Deadline Dodger (paternity notice in time), Pit Crew (car seat fitted and checked), Dry Run (route at rush hour and at night), Flat-Pack Hero, Fold Master (pram one-handed), Freezer Full (14 meals), Bag Boss, Nappy Ninja / Swaddle Sensei / Burp Baron, 70-Degree Club, Name Game, Birth DJ (offline playlist), Dog Diplomat, Gatekeeper (visitor policy texted), Dad Bod to Dad Mode (sleep bank, no alcohol near due date since you're the driver), Day-One Done, Form Filler Supreme (registration, Child Benefit, GP, will within 2 weeks).

**Verification notes from the researcher.** Birth certificate fees, MATB1 timing and the 21-day unpaid-parental-leave notice were not confirmed on GOV.UK in this pass. The "2-hour car seat rule" and "swaddle below shoulders" are general guidance, not Lullaby Trust wording. Re-verify Leeds numbers annually.

## A2. Partner support during labour and birth (research complete; full report to `docs/research/02-labour-partner-support.md`)

Sourced from NHS, NICE NG235 (intrapartum 2023), NG229 (fetal monitoring), NG207 (induction), NG192 (caesarean), RCOG patient leaflets, Cochrane, Birthrights, with ACOG for US contrast.

### Signs labour is starting
- Braxton Hicks: painless, short, infrequent, don't build. Real contractions: longer, stronger, closer together; continue despite rest, water and position change. ACOG test: rest and drink water; if they stop it's probably not labour. This is a legitimate first-line check before any timer threshold.
- Show: pink jelly-like mucus; labour may follow in hours or days. More blood than a pink tinge = phone now.
- Waters: trickle or gush; use a pad not a tampon so colour can be checked. Always call when waters break. Green/brown (meconium) or smelly = tell them immediately. Term PROM: 60% labour within 24h; induction offered after ~24h; temperature every 4h while waiting. GBS-positive with waters gone = immediate induction offered.
- Reduced fetal movements is a red flag at any time, overrides every rule, call even at 3am.

### Stages and expected durations (NICE)
| Stage | Definition | Duration |
|---|---|---|
| Latent | Painful contractions, cervix to 4 cm | Hours to days; the longest stage |
| Established first | Regular contractions, progressive dilatation from 4 cm (US: 6 cm) | First baby mean 8h, unlikely >18h; subsequent mean 5h, unlikely >12h; expect ~2 cm per 4h |
| Transition | Approaching full dilatation | ~30 min to 2h; "I can't do this", shaking, nausea, shouting at you |
| Second (active pushing) | Full dilatation with expulsive urge | First baby within 3h (review at 2h); subsequent within 2h (review at 1h); with epidural up to 2h passive first |
| Third | Placenta | Active management usually <30 min (prolonged >30); physiological prolonged >60 min |

Delay: <2 cm in 4h → ARM (shortens by ~1h, makes contractions stronger) → oxytocin → review for caesarean if <2 cm after 4h on drip.

### When to call: the decision logic (this is the engine spec)
**UK (NHS).** Call for advice: regular contractions every 5 minutes or more often, or unsure/worried. Call urgently, don't wait for morning: waters broken; bleeding; reduced movements; under 37 weeks; **any contraction longer than 2 minutes**; **6 or more contractions in 10 minutes** (these two mirror NICE's tachysystole definition of ≥5 in 10). Call 999: strong urge to push, cord felt or seen (knees-chest position, don't touch cord), heavy bleeding, seizure or collapse. Trust pages add "lasting 40–60s and consistently strong". Subsequent babies and long travel times: call earlier, don't wait the full hour.
**US.** 5-1-1 (every 5 min, lasting 1 min, for 1 hour). 4-1-1 and 3-1-1 are informal doula variants, no clinical body publishes them. ACOG gives no numeric rule.
**Measurement.** Frequency is start-to-start. Duration is start-to-end. Consistency means the pattern holds for ~1 hour. "Can't talk through them" is a widely taught heuristic, not NHS wording; label it as such.
**What triage asks.** Length, strength, frequency of contractions; pain; baby's movements in the last 24h; any loss (waters, blood, meconium) and its colour; notes/alerts. The app should have these on one screen before dialling.
**Home birth.** Call-out when contractions are 5 min apart, ≥40s and painful, or when waters break. First baby at home: serious outcome 9 vs 5 per 1,000 in hospital; subsequent babies as safe as hospital.

### Why the partner matters (Cochrane 2017, 26 trials, 15,858 women)
Continuous support: caesarean RR 0.75, instrumental RR 0.90, labour 0.69h shorter, negative feelings about the birth RR 0.69, no harms. NICE: don't leave a woman in established labour alone except briefly. The partner's job in one sentence: comfort, information, advocacy, and his whole attention.

### Partner toolkit by stage
- **Latent at home:** walk, drink, snack, paracetamol is fine, warm bath, TENS on early. Time a handful of contractions to see a pattern, then stop; re-time when things change. Sleep in shifts. Don't go in too early (you'll be sent home).
- **Established:** upright and forward positions shorten labour and reduce intervention; with an epidural, side-lying beats upright. Back-to-back (OP): all-fours, forward leaning, counter-pressure, hip squeeze, heat/ice. Hands-on: sacral pressure, cool flannel, water spray, straw bottle, lip balm, hair tie, prompt the loo every 2–3h (full bladder slows labour). Breathe with her: long exhale. Gas and air takes 15–20s so start at contraction onset. Dim lights, her music, handle the phone. Words: "You're doing it", "That one's gone", "Every one brings the baby closer". Midwife's rule: don't ask, do.
- **Transition:** stay; don't be offended; short firm phrases; eye contact; "this intensity means you're close"; call the midwife if she feels pushy.
- **Pushing:** stand where she can see you; mirror the midwife; at crowning she'll be told to pant; cord cutting after ≥1 min if agreed; no photos without prior agreement.
- **Third stage and golden hour:** baby on her bare chest before cord cut; skin-to-skin ≥1h or until first feed; Apgar done on her chest; weighing waits. If she's on Entonox, drowsy, or in theatre under GA, **dad does skin-to-skin**.

### Pain relief: facts and the partner's job
TENS (early, back pain, none in water). Water (≤37.5°C, once established, out for meconium/opioids). Entonox (15–20s onset, she can't do skin-to-skin on it, don't use it yourself). Pethidine/diamorphine (20 min onset, 2–4h, baby drowsy, no pool for 2h). Remifentanil PCA (press at onset). Epidural (labour ward only, ~10 min to site + 10–15 to work, 1 in 8 inadequate, 1 in 50 BP drop, 1 in 100 severe headache, catheter, continuous CTG, side-lying, change side hourly; you may be asked to step out during siting). Hypnobirthing (evidence on pain is limited; staff must respect it).

### Interventions in plain English
- **Induction** (~1 in 3 UK labours): sweep → prostaglandin pessary/gel or balloon → ARM + oxytocin drip + CTG. Can take 24–48h+. More painful, more assisted births. "Failed induction" = retry, wait, or caesarean. Her choice throughout.
- **Monitoring:** intermittent auscultation every 15 min (first stage) / 5 min (second) for low risk; continuous CTG for risk factors (epidural, oxytocin, meconium, previous caesarean, reduced movements etc.). Baseline 110–160, variability 5–25 reassuring, early decels normal, late/prolonged decels prompt action. FSE = scalp clip for a clearer trace. FBS = scalp blood test for certainty.
- **Tears:** up to 9 in 10 first-time mothers tear or have an episiotomy. 1st/2nd stitched in the room; 3rd/4th (OASI, ~3 in 100) repaired in theatre.
- **Assisted birth** (1 in 8; 1 in 3 first babies): ventouse or forceps; "trial in theatre" means caesarean is on standby; partner can usually attend.
- **Caesarean:** Cat 1 (immediate threat, birth within ~30 min of decision), Cat 2 (~75 min), Cat 3/4 planned. Spinal: partner present at her head, baby out in 5–10 min, 40–50 min total. **General anaesthetic: partner excluded**, waits nearby, gets skin-to-skin in recovery. Cat 1 under GA is the scenario that most frightens partners; the app must tell him in advance.
- **Emergencies and why the room fills up:** shoulder dystocia (1 in 150; buzzer, legs back, "stop pushing"), cord prolapse (1 in 200–1,000), PPH (≥500 ml minor, >1,000 major), retained placenta, pre-eclampsia (also after birth), meconium (neonatal team present), "the baby doctors are coming" (routine for meconium, instrumental, GA, prematurity; <0.3% of babies need chest compressions).

### Glossary (54 terms researched with plain English, worry level, question to ask)
Tightenings, latent/established, dilated/"she's 6", fully, effaced, station, engaged/"3/5 palpable", vertex/cephalic, LOA/ROA/OP, SROM/ARM/PROM/PPROM, show, VE, primip/multip, G2P1, fundal height, obs/MEOWS, BP, CTG/trace, variability, decels, FSE/FBS, ketones, syntocinon/"the drip", prostin/propess/pessary, sweep, balloon, partogram/action line, "we'll see how things go in 4 hours", delay/failure to progress, transition, crowning/ring of fire, episiotomy, tears 1–4/OASI, ventouse/kiwi/forceps/"trial in theatre", theatre/spinal/GA/Cat 1, cannula/catheter/TEDs, active/physiological third stage, retained placenta, PPH/"the bell", Apgar, cord gases, vitamin K, NIPE, jaundice/bili, colostrum/hand expressing/EBM, transitional care/SCBU/LNU/NICU, MLU/CLU/"high risk" (means doctors available, not danger), triage/MAU/DAU/MAC, doctors' review/"the reg", handover, BRAIN.

### Rights and advocacy
Only she consents; the partner cannot consent for her but can say "she can't take this in right now, give us a minute". Absolute right to decline; consent can be withdrawn mid-procedure; time pressure or threats are undue influence (Birthrights). Right to chosen birth partner (Article 8). Use BRAIN out loud: Benefits, Risks, Alternatives, Intuition, Nothing (what if we wait an hour?). Ask "is this an emergency or a recommendation?" and "can we speak to the senior midwife/consultant?". If it feels wrong: call bell, coordinator, obstetric review, and Martha's Rule (England, 24/7 independent critical-care review, covers maternity; rolling out through 2026/27).

### Partner self-care
Eat, drink, sleep in shifts, don't lock your knees (fainting is common enough that staff have a script), look away during epidural siting and the incision, watch the midwife's face not the floor, say "I'm scared, tell me what to do". Birth trauma in fathers: 1.2% PTSD in a 154-study meta-analysis, higher after emergency caesarean or when sidelined; ask for a birth debrief; Birth Trauma Association; symptoms can surface months later.

### Things partners get wrong (true, and funny later)
Falling asleep during contractions. Eating a kebab in the room. Filming without asking. "We're pregnant" / "it can't hurt that much" / "I know how you feel". Asking instead of doing. Going home to shower at 8 cm. Forgetting the car seat. Parking fines and dead phones. Hungover. Fainting. Taking transition swearing personally.

### Key numbers for the engine and copy
Established from 4 cm (UK) / 6 cm (US). First stage first baby mean 8h, ≤18h. Pushing ≤3h first baby. Third stage prolonged >30 min active. Cord ≥1 min. UK call: every 5 min. UK urgent: >2 min or ≥6 in 10. US: 5-1-1. Entonox 15–20s. Epidural 10 + 10–15 min. Cat 1 ≤30 min. Assisted 1 in 8. OASI 3 in 100. Shoulder dystocia 1 in 150. VBAC 3 in 4 succeed, rupture 1 in 200. Continuous support: caesarean RR 0.75.

## A3. Competitive landscape and gaps (research complete; full report to be committed as `docs/research/03-competitive-landscape.md`)

**Dad-focused apps.** The category is small, dated and thin on labour.
- *Daddy Up* is the only one with scale (4.9★, ~3K iOS ratings, ~250K Android installs). Lumberjack theme, free + $5.99 unlock, weekly updates, checklists, basic contraction timer. No watch, no birth plan, no jargon, no go-to-hospital logic. Praise: "comprehensive and funny". Complaints: ads, dated UI, theme polarises, shallow medical depth.
- *Who's Your Daddy* (2014) is dead and was criticised as laddish ("that hot girl over there… don't even think of looking"). *Pregnant Dad* abandoned 2022 (3.4★). *DadPad* is NHS-commissioned but clinical and postnatal, 3.0★. *Dad's Guide* (UK, June 2026, NHS-sourced, has birth plan notes) and *DADit* (2026, AI toolkit, birth plan builder, $9.99/mo) are new and unproven. *HiDaddy* (4.8★, 1.8K) has a polite/humorous notification toggle but one review called its daily nudges "anxiety inducing… made me feel worthless". *Big Daddy* (4.7★, 479) is doctor-built with a casual tone. *Baby Buddy* (RCM/RCOG-endorsed, free) has dad content but no tools.
- A 2018 Journal of Gender Studies analysis found dad apps "condescend" to fathers and assume men "need amusement and encouragement to get involved".

**General pregnancy apps** (Pregnancy+, BabyCentre, What to Expect, Ovia, The Bump, Bounty, Emma's Diary) treat the partner as a role toggle or read-only mirror. Flo for Partners is the only real partner curriculum and it is cycle-focused. What to Expect had an unfixed account-takeover flaw reported in 2024.

**Contraction timers.** Commoditised and mum-facing. Leaders: *Contraction Timer & Counter 9m* (4.8★, 69K), *Full Term* (4.7★, 7.2K, last updated 2019), *Freya* (£5.99, hypnobirthing, Apple Watch, hides its threshold). 2025 wave (*Labora*, *Bump Pulse*, *Bornly*, *contractiontimer.io*) adds Apple Watch, Live Activities and partner live-links. Every single one uses US 5-1-1 / 4-1-1 / 3-1-1 rules; none quotes NHS wording. Accuracy complaints cluster on the advice layer ("often inaccurate alerts", phase predictions "very inaccurate"), not the stopwatch. Users forget to press stop and punish apps that cannot edit entries. Praised: true dark mode, big button, lock-screen widget in the flashlight slot, log survives restart. Hated: bright screens, weekly subscriptions, paywalls mid-labour ("the last thing you want in labor"), phone must be unlocked.

**Birth plan tools.** NHS has a Word template and checklist page; NCT frames the plan as where the partner writes down their role. Only BumpTrackr and DADit have in-app builders. Nothing produces a one-screen midwife-facing summary or a "plan has changed" mode.

**Glossary.** NHS trusts publish staff abbreviation lists and Glasgow publishes "recommended language for maternity services", so the NHS itself recognises the jargon problem. No app offers a searchable labour-ward lookup. The "what midwives say vs what they mean" angle is unoccupied.

**Tone evidence (books, reviews).** Rob Kemp's *Expectant Dad's Survival Guide*: "cheeky wit" vs "patronising, far too laddish". *Man vs Baby*: very funny but leans on the bumbling-dad trope men are tired of. *Commando Dad*: military theme works as structure, wears thin when content is common sense. *We're Pregnant!* (3.98★, 2.9K) valued for practicality and "helped me destress". Rules that emerge: punch at yourself, never at her; dad as competent learner not idiot; jokes sit on top of real information; give a tone dial; no guilt mechanics; theme skinnable.

**Unoccupied space this app should own.**
1. "Dad is the device holder" timer (one thumb, watch haptics, her phone optional).
2. Timer + decision advice in NHS wording with red flags and 999 rules, "time to call" not "go now", parity-aware.
3. Pre-filled triage call script with last hour's timings on screen.
4. One-screen birth plan for the midwife plus "what to ask when the plan changes".
5. Offline jargon lookup with "what to ask next" and "is this normal".
6. Stage-based "say/do this now" partner coaching cards; "breathe with her" haptic on his watch.
7. Live hospital bag checklist and one-tap post-birth broadcast to a pre-approved list.
8. Hospital-specific info (triage number, parking, after-hours entrance) on the labour screen.
9. Funny prep that switches to a sober labour mode. The market is bifurcated funny-but-shallow vs clinical-and-dull.

**Risks to design around.**
- App Store 1.4.1 (medical apps reviewed with greater scrutiny; must disclose methodology; reviewers ask for source links). "Entertainment purposes" disclaimers do not cure (1.1.6).
- MHRA: software is a medical device by intended purpose. A timer that displays NHS rules is wellbeing; one that decides "you are in established labour" edges toward decision support. Keep claims to "helps you follow NHS advice on when to call".
- 5.1.3: health data may not be stored in iCloud; design CloudKit sync carefully or keep contraction logs out of it.
- Watch runtime: watch apps suspend on wrist-down. Background haptics only inside an HKWorkoutSession; extended runtime sessions are type-limited (self care 10 min, mindfulness 1h, smart alarm 30 min). Shipping timers avoid this by storing tap timestamps and using scheduled local notifications for threshold alerts. Live Activities mirror to the watch Smart Stack but cannot be started from the watch (ActivityKit is iPhone-only); Live Activities have a lifetime cap (commonly cited 8h) so long labours need restart. WatchConnectivity `transferUserInfo`/`updateApplicationContext` is the right path for tap timestamps so either device can own the timer.
- React Native/Expo/Flutter cannot run on watchOS; native Swift is required for the watch regardless. Confirms the native iOS decision.
- Wear OS has almost no competition (one maintained timer) and supports timers via the Ongoing Activity API; secondary lane for later.

## A4. Things you may have missed (confirmed against the research)

1. **The triage phone call is the real decision point in the UK, not the drive.** NHS says phone first; many couples are told to stay home. A pre-filled call script (timings, waters time and colour, last movement, risk factors) is more useful than "go now" and is a gap no competitor fills.
2. **Reduced fetal movements overrides every contraction rule and every joke.** It needs its own always-visible button in labour mode and in the last trimester.
3. **A large share of births never follow the "contractions at home" script.** Roughly 1 in 3 UK labours are induced and a large share end in caesarean. Labour mode needs induction, planned caesarean and "plan has changed" branches, including the "Cat 1 under general anaesthetic, you'll be asked to wait outside" scenario that frightens partners most.
4. **Paternity leave notice is due around week 25**, not at the birth. Day-one leave rights since April 2026 don't extend to pay. This is the single most-missed dad deadline and the app should nag with a date.
5. **Unmarried dads must attend the birth registration** or they're not on the certificate and have no parental responsibility. Nobody tells them this.
6. **Child Benefit should be claimed even by high earners** (opt out of payments, keep NI credits and the child's NI number). Backdating is capped at 3 months.
7. **Dad's own mental health.** About 1 in 10 fathers experience perinatal mental health difficulties, presenting as irritability and withdrawal rather than sadness; 1.2% develop PTSD after the birth. The app needs a fortnightly check-in, signposting (PANDAS, Dad Matters, CALM), and a "humour off" exit.
8. **Post-birth is where dads are most lost** and most competitor apps stop at the birth: day 5 heel prick, 42-day registration, maternal red flags (bleeding, post-birth pre-eclampsia, sepsis), jaundice under 24h, the 70°C formula rule, visitor gatekeeping.
9. **Second-time dads** need a different engine (call earlier), plus childcare and pet backup plans.
10. **Hospital-specific logistics** (MAC number, parking payment, after-hours entrance, whether partner can stay overnight) should be user-entered and surfaced on the labour screen.
11. **Partner self-care in labour**: fainting, sleeping in shifts, eating, and not taking transition personally. Reviewed books and midwife blogs are full of this; apps have none of it.
12. **Tone risk is real.** Laddish humour and bumbling-dad tropes get punished in reviews; guilt-based daily nudges got one competitor called "anxiety inducing". Humour must punch at the dad or the app, never at mum, sit on top of real information, and have a dial.
13. **Regulatory exposure.** App Store 1.4.1 and MHRA treat "you are in established labour" as decision support. Output "time to call your maternity unit", quote NHS/NICE verbatim with source links, make thresholds midwife-editable, never predict dilation or phase, and get a midwife to review content before release.
14. **Health data and iCloud.** App Store 5.1.3 forbids storing personal health information in iCloud, so contraction logs stay local or are non-identifying.
15. **Dark delivery room ergonomics**: true black, one thumb, 44pt+ targets, undo for mis-taps (users forget to press stop), lock-screen widget in the flashlight slot, timer must survive app kill and work for 24h+.
16. **Monetisation**: weekly subscriptions and mid-labour paywalls are the most hated thing in the category. Labour mode must be free; a one-time unlock before 37 weeks is the safe model.

---

# PART B: BUILD PLAN

## B1. Product shape

Two modes, one app:

1. **Pre-launch (T-minus mode)**: the pregnancy. Countdown to T-0, mission briefings per week, go/no-go checklists, skills training, story beats.
2. **Launch Day (Labour mode)**: a stripped-back, dark, high-contrast UI reached from a persistent "LAUNCH" button. Contraction telemetry, go/no-go advice, triage call script, birth plan one-screen summary, jargon decoder, "what to do right now" cards, post-birth broadcast.

## B2. Theme, characters and story (Mission Control)

Characters (voiced in copy and illustrated as simple flat avatars):
- **CAPCOM**: the main narrator/voice of the app. Dry, deadpan NASA comms voice. Delivers briefings and reads out checklists. Occasionally admits it has never actually held a baby.
- **The Commander**: mum. Never a joke at her expense; she's the one actually flying the ship. The app constantly re-centres dad on supporting the Commander.
- **The Payload**: baby. Represented as a growing capsule/astronaut with weekly size comparisons that are deliberately non-fruit (a Mars bar, a Game Boy, a rugby ball) with the real cm/g alongside.
- **Ground Control**: the midwife/clinical team. Always portrayed as competent; the glossary is "learning Ground Control's language".
- **Flight Surgeon**: the serious voice. Appears whenever content is medical and the jokes stop. Visually distinct (plain card, no theme chrome). Every red-flag item is delivered by the Flight Surgeon.
- **The Veteran**: a retired Flight Director (a dad who's done it) who gives "things I got wrong" asides.

Story arc (one beat per week, unlocked by gestational week, skippable):
- Act 1 "Recruitment" (weeks 4–13): you've been drafted; learn the ship; first scan is "first contact".
- Act 2 "Systems Check" (weeks 14–27): anomaly scan, antenatal classes, building the module (nursery), money, leave paperwork.
- Act 3 "Countdown" (weeks 28–36): hospital bag, car seat certification, birth plan, dress rehearsal drive, classes complete.
- Act 4 "Hold at T-minus" (37+): daily check-ins, "any day now" mode, pre-flight checklist locked.
- Act 5 "Launch" (labour): story pauses; CAPCOM goes quiet; Flight Surgeon and checklists take over.
- Epilogue "Splashdown" (first 2 weeks): post-birth to-dos, registration, dad mental health check-in, mission patch awarded.

Gamification: ranks (Cadet → Flight Director), mission patches for completed modules, streaks for daily check-ins, "certifications" (Car Seat Certified, Nappy Qualified) earned by completing skill lessons with a short quiz. Keep it light; no paywalls on safety content.

## B3. Architecture

**Principle: the Swift package is the source of truth; the Xcode project is thin and generated.** Everything that can be Foundation-only lives in `MissionCore` so it builds and tests on Linux (this session's environment) with `swift test`. The app shells need a Mac and are compiled on macOS CI.

- iOS 17+, watchOS 10+, Swift 5.10+, SwiftUI. XcodeGen (`project.yml` checked in, `.xcodeproj` gitignored).
- SwiftData, **two separate ModelContainers**: `PlanningStore` (pregnancy, checklist state, birth plan, progress; CloudKit off in v1 but possible later) and `LabourStore` (sessions, tap events, contractions, red flags, engine snapshots; `cloudKitDatabase: .none`, never synced, file-protected). This is how App Store 5.1.3 is satisfied.
- Content as versioned JSON bundled in a resource target, one file per kind per region: `briefings`, `checklist`, `glossary`, `coaching`, `quiz`, `thresholds`, `badges`. Works offline in a hospital basement. A midwife can review JSON.
- No backend. Share-outs via `ShareLink` (birth plan PDF, contraction log, "Payload has landed" message).
- No analytics in v1. Local notifications only.
- App Group `group.uk.leeds.missioncontrol` for shared UserDefaults between app, widget extension and watch complication.

```
Baby-tracker/
├── Package.swift                 # MissionCore (Foundation-only), MissionContent (JSON), MissionUI (SwiftUI, Apple-only)
├── project.yml                   # XcodeGen
├── Sources/MissionCore/
│   ├── Engine/      GoNoGoEngine, ContractionMetrics, LabourState, Thresholds, Hysteresis
│   ├── Events/      TapEvent, EventLog (reduce events → contractions), EventMerger
│   ├── Pregnancy/   PregnancyCalendar (EDD → week, EWC, deadlines), DeadlineRule
│   ├── Content/     ContentSchema (Codable DTOs), ContentLoader, HumourResolver, ContentIndex (glossary search)
│   └── Gamification/ RankLadder, BadgeRules
├── Sources/MissionContent/Content/{uk,us}/*.json
├── Sources/MissionUI/            # shared SwiftUI: BigButton, StateBanner, ContractionList, LabourTheme
├── Apps/MissionControl/          # iOS: SwiftData models, PhoneSyncCoordinator, TimerActivityController,
│                                 #      ThresholdNotifier, Features/{PreLaunch,Labour,BirthPlan}, ThresholdEditorView
├── Apps/MissionControlWatch/     # watchOS: LabourTimerView, WatchSyncCoordinator, WatchTimerWidget (complication)
├── Apps/MissionControlWidgets/   # TimerLiveActivity, TimerAttributes, CountdownWidget
├── Tests/MissionCoreTests/       # Swift Testing, runs on Linux, JSON fixtures of scripted labours
├── Tests/MissionUISnapshotTests/ # Mac only
├── Scripts/content-lint.py, gen-project.sh
├── docs/research/                # the three research reports verbatim, plus content-review log and disclaimers
└── .github/workflows/ci.yml      # linux job (build, test, lint) on every PR; mac job gated to main / label
```

### Data model (SwiftData, app targets; `MissionCore` has plain struct mirrors)
- `Pregnancy`: dueDate, region, parity, previousFastLabour, multiples, travelMinutesToUnit, maternityUnitName, triagePhone, parkingNotes, afterHoursEntrance, humourLevel, thresholdOverrides (Codable), contentVersion.
- `ChecklistItemState`: contentID (stable key into JSON), status (todo/done/skipped), completedAt, snoozedUntil, notes. Content is never persisted, only state, so content updates don't orphan progress.
- `BirthPlan`: answers[] (questionID, choiceIDs, freeText), updatedAt, pdfCacheURL.
- `LabourSession`: startedAt, endedAt?, ownerDeviceID, thresholdSnapshot (frozen at start), liveActivityID?.
- `TapEventRecord` (append-only): id UUID, sessionID, kind (start/stop/editStart/editStop/delete/merge/undo/redFlag), timestamp, deviceID, lamport, target?, payload?.
- `Contraction`: materialised projection rebuilt from events on launch.
- `RedFlagEvent`: watersBroken, watersColoured, bleeding, heavyBleeding, reducedMovements, urgeToPush, cordVisible, seizureCollapse; isOn, timestamp.
- `EngineStateSnapshot`: state, enteredAt, reasonCodes (for hysteresis and a post-hoc "how we got here" view).
- `Progress` (rankID, xp, streakDays), `BadgeAward`, `ReminderSchedule` (notification identifiers so EDD changes can cancel precisely).

### Content schema
Envelope `{ schemaVersion, contentVersion, region, items[] }`. Every clinical item carries `provenance { sourceURL, sourceTitle, accessed, reviewer, reviewedOn, clinical: true }`; the lint enforces it. Copy fields use `LocalizedCopy { off, mild, full }` with `off` mandatory and fallback full → mild → off; `clinicalText` is a plain string and never varies. Checklist items carry `module`, `unlockWeek`, `deadline { anchor: ewc|edd|birth, offsetDays }` (paternity notice = EWC minus 105 days), `reminderDaysBefore[]`, `quizID?`, `xp`. Glossary entries carry `term`, `aliases[]`, `plainEnglish`, `worryLevel 0–3`, `questionToAsk`, `stage[]`. Coaching cards carry `stage`, `doThis[]`, `avoidThis[]`, no humour variants. `thresholds.json` holds region defaults with min/max safe bounds per field.

## B4. Features

1. **Onboarding**: due date (or scan date), first baby or not, previous fast labour, planned birth place, planned mode (spontaneous / induction booked / planned caesarean), hospital details (name, MAC/triage number, parking payment, after-hours entrance, travel minutes), region, humour level. Disclaimer screen.
2. **T-minus dashboard**: countdown, this week's briefing and story beat, this week's to-dos, Payload size card (non-fruit comparisons with real cm/g), rank and streak.
3. **Mission checklists**: twelve modules (Admin & Leave, Money, Appointments, Classes, Birth Plan, Hospital Bag, Vehicle, Home Module, Day-Of Logistics, Skills Training, Commander Support, Splashdown), each item with title, why it matters, when, source link, done state, snooze, optional reminder. Dated deadlines (paternity notice, registration) get real notifications.
4. **Skills Training**: short lesson plus 3-question quiz per skill, awarding certifications (Nappy Qualified, Car Seat Certified, 70-Degree Club).
5. **Flight Plan builder**: form mirroring NHS birth plan sections, outputs a one-screen large-type summary for the midwife and a printable PDF (`ImageRenderer`), plus "what changed" prompts for induction, epidural and theatre.
6. **Launch Day (labour mode)**: see B7.
7. **Jargon Decoder**: offline search over the 54+ glossary terms with plain English, worry level and the question to ask. Available everywhere, pinned in labour mode.
8. **Splashdown**: 14-day post-birth checklist, maternal and baby red flags (Flight Surgeon voice), dad mental health check-in with helplines, broadcast composer.
9. **Settings**: region, humour level, threshold editor (within safe bounds, with "your midwife may give you different advice, use theirs" note), haptics, export data, delete labour data.

## B5. Go/no-go engine

Pure, deterministic Swift function with no clocks or I/O: `GoNoGoEngine.evaluate(EngineInput) -> EngineOutput`. Input: reduced contractions, red-flag set, profile (parity, previousFastLabour, gestationalWeeks, travelMinutes, region), `ThresholdProfile`, previous snapshot, `now`. Output: `LabourState` (early < establishing < callTriage < callNow < call999), reason codes, metrics, enteredAt.

**ThresholdProfile UK defaults [safe bounds]**: adviceIntervalSec 300 [180–420]; adviceDurationSec 0 UK / 60 US [30–90]; patternWindowSec 3600 [1800–3600, cannot be lengthened]; urgentSingleDurationSec 120 [90–120, cannot be relaxed]; urgentCountIn10Min 6 [5–6]; regularityCV 0.35 [0.25–0.5]; earlyCallerWindowSec 1800; travelEarlyCallMinutes 30.

**Metrics**: sort, drop deleted; open contraction counts as ending `now`; an open contraction older than 300s is treated as "forgot to stop" (excluded from duration stats, surfaced as `needsEdit`). Rolling window of the last `patternWindowSec`, minimum 4 contractions. Intervals are start-to-start; any interval over 3× the median splits the window and only the latest segment counts. Median interval, median duration, regularity as IQR/median, max count in any 10 minutes, longest recent duration, `patternSustainedSec`.

**Precedence (first match wins)**:
1. `call999`: urgeToPush, cordVisible, seizureCollapse, heavyBleeding. No auto-exit.
2. `callNow`: watersBroken or watersColoured, bleeding, reducedMovements, gestation < 37 weeks, any contraction > urgentSingleDurationSec, ≥ urgentCountIn10Min in 10 minutes.
3. `callTriage`: median interval ≤ adviceIntervalSec, regularity ≤ regularityCV, median duration ≥ adviceDurationSec, sustained ≥ required window. Required window drops from 3600 to 1800 for parity ≥ 1, previous fast labour, or travel > 30 min (adjustments don't stack below 1800).
4. `establishing`: pattern met but not yet sustained, or median interval ≤ 1.5× advice interval with regularity met.
5. `early`: otherwise.

**Hysteresis**: states rise immediately; a drop requires the lower state's conditions to hold for 15 minutes; the UI shows "pattern easing" meanwhile. Red-flag states never auto-demote.

**Copy rule**: state copy is instructional ("Time to call your maternity unit"), never diagnostic. A unit test asserts no copy contains "established labour" or "you are in labour".

**Test matrix** (JSON fixtures): empty and 3-contraction logs → early; textbook UK 4-min/50s regular at 65 min → callTriage, at 45 min → establishing; US 5-min/45s → establishing (duration fails), 65s → callTriage; irregular 3/9/4/12 → early; 50-minute gap resets segment; one 130s contraction → callNow; 6 in 10 min → callNow; forgot-to-stop excluded with needsEdit; parity 1 at 35 min → callTriage while parity 0 → establishing; travel 45 min same; 36+6 → callNow, 37+0 normal; each red flag individually; heavyBleeding beats everything; hysteresis rise immediate / fall after 15 min; edited entry recomputes identically to a fresh log; threshold clamping; determinism property test over 500 random logs.

## B6. Watch and sync

**Event-sourced tap log.** Both devices append `TapEvent { id, sessionID, kind, at, deviceID, lamport, target?, payload? }` locally and publish. The contraction list is always derived, so there are no contraction edit conflicts, only event ordering. Merge: dedupe by id, order by (lamport, at, deviceID), lamport bumped on receipt. Two starts within 20s from different devices with no stop are coalesced. Edits and deletes are last-writer-wins by lamport. Undo tombstones an event so it works cross-device. `EventLog.reduce` is idempotent and tested with shuffled inputs.

**Transport**: `updateApplicationContext` carries a `SessionSummary` (state, last 5 contractions, lamport high-water mark) for complication and banner catch-up; `transferUserInfo` carries batches of un-acked events (queued, survives background); `sendMessage` mirrors a tap instantly when reachable (same event also queued, dedupe makes it safe). Ownership is advisory (who owns the Live Activity); either device can tap.

**Standalone watch**: own `LabourStore`, runs the engine locally with the threshold snapshot received at session start. On reconnect, sends events above the peer's high-water mark; both converge because reduction is deterministic.

**Runtime strategy**: no workout or extended runtime sessions in v1. All timing is timestamp arithmetic, so wrist-down suspension is harmless. Threshold alerts are **scheduled local notifications**: after every engine run, compute the earliest moment the state could change without further taps (pattern reaches 60 min at T, demotion dwell completes at T) and schedule one pending notification at T, replacing the previous. Immediate notification on any rise, with phone/watch suppression via `notifiedState` in the summary. "Still going?" nudge 5 minutes into an open contraction catches forgotten stops.

**Live Activity**: `TimerAttributes` + `ContentState` (state, lastStart, lastDuration, medianInterval, isOpen); `Text(timerInterval:)` so nothing ticks in-process; Start/Stop/Undo via `AppIntent` writing to the App Group store, so the lock screen works without unlocking. 8-hour cap handled by a `BGAppRefreshTask` plus local notification at 7h30 that ends and restarts the activity under the same session. Watch Smart Stack mirrors automatically.

**Watch complication** (WidgetKit): corner/circular shows minutes since last contraction; rectangular shows state and last interval/duration; reload after each tap. Pre-launch iPhone widget shows days to T-0, next deadline, rank.

**Watch UI**: single `LabourTimerView` with one button, state, elapsed; crown scrolls history; long-press for red flags; prompt to enable Water Lock.

## B7. Labour-mode UI and humour suppression

Entered via a persistent LAUNCH button (confirm once, sticky until "End labour"). `LabourTheme`: true black, high-contrast amber/white, 56pt minimum controls, forced dark, Dynamic Type capped at accessibility3 so layout never breaks. No modals; everything is a push or inline expand.

Five-icon bottom bar:
1. **Timer**: giant Start/Stop toggle filling the bottom half; state banner with reason line ("every 4 min for 50 min"); 10-second Undo chip after any tap; inline red-flag toggles; swipe-up history with ±1 min steppers, Delete, Merge-with-previous.
2. **Call**: one-tap `tel:` to the triage number; auto-filled script card (name, weeks, parity, pattern summary, red flags, waters time and colour, last movement, travel time). 999 button shown in `call999` and always reachable via long-press on the banner.
3. **Plan**: one-screen birth plan, large type, read-only, with "plan has changed" prompts.
4. **Coach**: coaching cards for the current stage, swipeable, plus partner self-care prompts (eat, sit, shifts).
5. **Decoder**: glossary with search pinned at top.
"End labour" opens the Broadcast composer and unlocks Splashdown.

Humour: `humourLevel` is a SwiftUI environment value; the labour root forces `.off`, engine copy and coaching cards have no variants at all, and gamification observers are paused while a session is active. No badge toasts in a delivery room. The Flight Surgeon template (plain card, no theme chrome) is used for every red-flag and maternal/baby warning item in both modes.

## B8. Content and clinical governance

- Every clinical item has provenance (source URL, title, access date, reviewer, review date). `Scripts/content-lint.py` fails CI on missing provenance, missing `off` copy, duplicate IDs, out-of-bounds threshold defaults, or forbidden phrases ("established labour", "you are in labour", "diagnos").
- The three research reports are committed verbatim under `docs/research/` as the content source, with their verification notes carried into a `docs/content-review-log.md` of items still to confirm (birth certificate fees, MATB1 timing, 21-day unpaid leave notice, the "2-hour car seat rule" wording).
- Recruit a registered midwife reviewer before TestFlight. Disclaimers at onboarding and at labour-mode entry: NHS/NICE guidance, not diagnosis; your midwife's instructions override the app.
- Monetisation: labour mode and all safety content free forever; optional one-time unlock for story, badges and extra briefings, offered before 37 weeks, never during labour.

## B9. Tooling and CI

- XcodeGen; swift-format (works on Linux); SwiftLint on Mac CI only; Swift Testing for `MissionCoreTests`; pointfreeco swift-snapshot-testing for `MissionUI` (timer in each state × 3 type sizes); 2–3 XCUITest smoke flows.
- CI: `linux` job on every PR (`swift build`, `swift test --filter MissionCoreTests`, content lint, format lint). `mac` job on `macos-15` gated to pushes to `main` or a `needs-mac` label because of the 10× minute multiplier: xcodegen, `xcodebuild test` on iPhone 16 simulator, watch build-only, snapshot tests.
- `MissionCore` stays strictly Foundation (no Combine, no os.log; a `Logger` protocol). `Package.swift` guards `MissionUI` with `#if canImport(SwiftUI)`, so `swift test` on Linux builds only the core and content.

## B10. Phased delivery

| Phase | Scope | Testable here (Linux)? | Effort |
|---|---|---|---|
| 0 Scaffold | Package.swift, project.yml, CI, lint script, schema DTOs, UK/US `thresholds.json`, research reports into `docs/research/`, README with theme and characters | Yes | 2 days |
| 1 Core engine | ContractionMetrics, GoNoGoEngine, Hysteresis, full test matrix, EventLog/EventMerger with shuffle tests | Yes, fully | 1 week |
| 2 Calendar + content | PregnancyCalendar (EDD, EWC, deadlines), ContentLoader, HumourResolver, ContentIndex; UK content v1: ~120 checklist items across 12 modules from A1, 54 glossary terms and coaching cards from A2, 10 story beats, 20 quiz questions, badge rules | Yes | 1–2 weeks |
| 3 iOS labour mode | LabourStore, Timer, edit/undo, red flags, Call screen with script, Plan view, Coach, Decoder, notifications | Mac: unit + snapshot; manual on device | 2 weeks |
| 4 Live Activity + widgets | ActivityKit UI, AppIntents, 8h restart, countdown widget | Mac + physical device | 1 week |
| 5 watchOS | Standalone timer, complication, WatchConnectivity sync and reconciliation | Mac + paired device | 2 weeks |
| 6 Pre-launch | Dashboard, briefings and story, checklists, reminders, quizzes, gamification, birth plan builder + PDF, onboarding, settings | Mac | 3 weeks |
| 7 Hardening | VoiceOver pass, true-black audit, midwife sign-off, TestFlight with expectant dads, App Store medical-wording review | Mixed | 1–2 weeks |

Roughly 11–13 weeks for one developer. Phases 0–2 are fully achievable in this Linux session and de-risk the clinically sensitive part first; the Mac-dependent app shells follow.

## B11. Verification

- `swift test` on Linux: engine matrix above, merger shuffle/idempotence tests, calendar tests (EWC Monday calculation, paternity deadline = EWC minus 105 days, week boundaries), content decode tests for every bundled JSON file, forbidden-phrase test.
- `python3 -I Scripts/content-lint.py` clean on every PR.
- Snapshot tests of labour screens in every state at three Dynamic Type sizes, dark mode.
- Manual device test: run a 90-minute scripted labour with phone locked, watch on wrist, phone in a bag out of Bluetooth range for 20 minutes, then reconnect and confirm both devices show an identical contraction list and state. Confirm lock-screen Start/Stop works without unlocking, Live Activity restarts past 7h30, and the "still going?" nudge fires at 5 minutes.
- Content review: midwife sign-off recorded in the review log before TestFlight.

## B12. Immediate next steps on approval

1. Commit this plan's research as `docs/research/01-03*.md` plus `docs/plan.md` on `claude/sleepy-goldberg-ra4cso`.
2. Phase 0 scaffold: `Package.swift`, `project.yml`, CI, lint script, schema DTOs, `thresholds.json` for UK and US.
3. Phase 1: engine and merger with the full test matrix, green under `swift test` on Linux.
4. Phase 2: content v1 authored from A1/A2 with provenance, CAPCOM/Flight Surgeon copy variants, story beats.
5. Push after each phase.
