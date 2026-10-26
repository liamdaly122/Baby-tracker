# Supporting a woman in labour: an evidence-based brief for the "companion during birth" mode

Author: Liam Daly
Research date: 26 October 2026.

**Scope.** UK-first (NHS / NICE NG235 2023 / NICE NG229 fetal monitoring / NICE NG207 induction / NICE NG192 caesarean / RCOG patient leaflets / Birthrights), with US contrast (ACOG, ACOG/SMFM 2014 consensus, Cleveland Clinic, Lamaze). Numeric thresholds are stated explicitly for encoding in app logic. Where a figure came from a secondary source (NHS trust guideline reproducing NICE, or a consumer site), that is flagged.

**Access notes for the developer.** nice.org.uk, acog.org, tommys.org, mayoclinic.org, evidencebasedbirth.com and dona.org all block automated fetches; NICE and ACOG content was obtained via a text-proxy of the canonical pages and is cited to the canonical URLs. The Norfolk and Norwich (NNUH) intrapartum guideline v13 (Oct 2024) and the NHS Greater Glasgow and Clyde "Delay in labour pathway" (Aug 2024) are local guidelines explicitly adapted from NG235 and were used to corroborate NICE numbers.

---

## 1. Signs that labour is starting

### 1.1 Braxton Hicks vs real contractions
- NHS: practice (Braxton Hicks) contractions "are usually painless", "don't last long, don't happen often, and don't build up". Real contractions "become longer, stronger and more frequent as labour progresses"; the womb "feels harder during a contraction and softer as it relaxes." [NHS signs of labour]
- ACOG true-vs-false table: true labour contractions come at regular intervals that get closer together, each lasting "about 60 or 90 seconds", continue despite rest/movement, steadily strengthen, and often start in the back and move to the front. False labour is irregular, may stop with walking/rest/position change, and is usually felt only at the front. ACOG's practical test: rest and drink water; if contractions stop, it is probably not true labour. [ACOG]
- App implication: a "does it stop if she lies down / drinks a pint of water / has a bath?" check is a legitimate first-line discriminator before any timing threshold is applied.

### 1.2 The "show"
- "Sticky, jelly-like, pink mucus"; may come as one blob or several pieces; labour "may follow quickly or take a few days"; sometimes there is no show. **If she is losing more blood than a small pink-tinged show, phone the hospital straight away.** [NHS signs of labour]

### 1.3 Waters breaking (SROM / PROM)
- Can be a slow trickle or a gush. Fluid should be clear/pale, may be slightly blood-stained at first. Use a pad (not a tampon) so the midwife can check colour. [NHS]
- **Call the maternity unit whenever waters break** (NHS lists this as an "urgent advice" trigger). Tell them *immediately* if fluid is smelly or coloured (green/brown = meconium) or if there is bleeding. [NHS]
- NICE NG235 on term PROM (37+0 weeks or more): about **60% of women labour within 24 hours**; the serious neonatal infection risk is **1% vs 0.5%** with intact membranes; phone triage first, in-person review within 12h if no risk factors; **offer induction if labour has not started after about 24 hours**; while waiting, record temperature **every 4 hours** while awake and report reduced movements or a change in fluid colour/smell; if labour has not started 24h after rupture, birth should be where neonatal services are available and mother and baby stay in hospital at least 12h after birth. [NICE NG235 1.7.x; NHS says a raised temperature is "usually above 37.5C"]
- **Group B strep (GBS):** carried by 20 to 40% of UK women; early-onset GBS infection affects about 1 in 1,750 newborns; IV antibiotics in labour reduce risk from about 1 in 400 to about 1 in 4,000; antibiotics should start as soon as labour begins or waters break (repeated about 4-hourly); a term baby whose mother had antibiotics **4 hours or more before birth** needs no special monitoring, otherwise observations for at least 12h. **If GBS-positive and waters break at term, induction is offered straight away** (NICE NG207 says offer immediate induction or caesarean). IV antibiotics "may not always be possible to arrange at home or in some midwifery-led units." [RCOG GBS leaflet; NICE NG207; NHS GBS]

### 1.4 Other prodromal signs
- NHS: backache or a heavy aching feeling; urge to go to the toilet (head pressing on the bowel). Cleveland Clinic adds backache, bloody show, **diarrhoea and nesting** as pre-labour signs; ACOG adds "lightening" (baby dropping) hours to weeks before. [NHS; Cleveland Clinic; ACOG]

### 1.5 Reduced fetal movements: a red flag at any time
- NHS: "Call your midwife or maternity unit immediately if" the baby is moving less than usual, you cannot feel movement, or the pattern changes. **Do not wait until the next day; call even in the middle of the night.** Do not use a home doppler (a heartbeat does not mean the baby is well). There is no set kick count; learn the baby's usual pattern. Movements should continue right up to and during labour. [NHS your baby's movements]
- NICE NG229 lists "reduced fetal movements in the 24 hours before regular contractions" as an indication for continuous CTG in labour; NNUH triage asks about movements over the last 24 hours. [NICE NG229; NNUH]

---

## 2. Stages of labour, with expected durations

| Stage | Definition (NICE NG235) | Expected duration |
|---|---|---|
| **Latent first stage** | Painful contractions with *some* cervical change (position, consistency, effacement, dilatation) **up to 4 cm**; need not be continuous | "Can take hours or sometimes days"; usually the longest stage (NHS). US: "prolonged latent" = over 20h nulliparous, over 14h multiparous (ACOG/SMFM via EBB) |
| **Established first stage** | Regular painful contractions **and progressive dilatation from 4 cm** | First labour: **average 8h, unlikely to last over 18h**. Subsequent: **average 5h, unlikely over 12h** (NICE 1.8.36; NHS). Expected progress about **2 cm per 4 hours** (GGC pathway, citing NICE) |
| **Transition** | Not a formal NICE stage; the end of first stage approaching full dilatation | NNUH: "restlessness, vocalisation with increasing distress, women may feel very alone... often a time when she will ask for pain relief"; abdomen may bear down before fully dilated. Consumer sources: about 30 min to 2h |
| **Second stage, passive** | Full dilatation without involuntary expulsive contractions | With epidural: up to **2h** passive (nulliparous) / **1h** (multiparous) allowed (NICE 1.9.27 to 28). RCOG recommends delayed pushing 1 to 2h with epidural |
| **Second stage, active** | Baby visible, or expulsive contractions with full dilatation, or active pushing after full dilatation confirmed | **Nulliparous: birth expected within 3h** of active stage; reassess at 1h; refer for senior review if not imminent at **2h**. **Multiparous: within 2h**; reassess at 30 min; refer at **1h**. With epidural, NNUH plans for birth within 4h of full dilatation regardless of parity (NICE 1.9.25 to 30; NNUH; NHS: pushing "should last no longer than 3 hours" first baby, "no more than 2 hours" later babies) |
| **Third stage** | Birth of baby to expulsion of placenta and membranes | **Active management: placenta usually within 30 min**; prolonged if **over 30 min**. **Physiological: prolonged if over 60 min**; NICE says change to active if not delivered within 1h (NICE 1.10.17, 1.10.20; NHS) |

**First-stage delay (NICE 1.8.42 to 49):** suspect delay if dilatation **under 2 cm in 4 hours** (first labour) or under 2 cm in 4h *or slowing* (subsequent); repeat VE 2h later and diagnose delay if under 1 cm; amniotomy (ARM) shortens labour by "approximately an hour" but makes contractions stronger/more painful; if no progress 2h after ARM, transfer to obstetric-led care and consider oxytocin (which "will bring forward the time of birth, but not influence the mode of birth"); if under 2 cm after 4h of oxytocin, obstetric review for caesarean. [NICE NG235; NNUH]

**Third-stage trade-off numbers** (GGC pathway, citing NICE): physiological vs active management: PPH over 500 ml **188 vs 68 per 1,000**; PPH over 1,000 ml **29 vs 13 per 1,000**; transfusion 35 vs 13 per 1,000; side effects (nausea, headache, hypertension) 90 vs 186 per 1,000. Active management = oxytocin injection into the thigh at/just after birth, cord clamped **between 1 and 5 minutes** (NICE: not before 1 min; before 5 min for controlled cord traction, earlier only if baby's heart rate under 60 and not rising), controlled cord traction. Physiological = no drug, cord cut after it stops pulsing (about 2 to 4 min), placenta pushed out by maternal effort. [NICE 1.10.11 to 20; NHS stages; GGC]

**US contrast:** ACOG/SMFM 2014 define *active* labour from **6 cm** (not 4); first-stage arrest = 6 cm or more with ruptured membranes and no change for 4h with adequate contractions or 6h with inadequate; second-stage arrest = 3h pushing nulliparous / 2h multiparous, **+1h with epidural**. Cleveland Clinic: first stage 12 to 19h total (early 6 to 12h to about 6 cm, active 4 to 8h), pushing 30 min to several hours, placenta usually under 30 min; first births average 12 to 24h, later 8 to 10h. [EBB summary of ACOG/SMFM; Cleveland Clinic]

---

## 3. When to call / go in: the decision logic

### 3.1 UK (NHS) thresholds
**Call for advice** if she thinks she's in labour, is "having regular contractions coming every 5 minutes or more often", or is unsure/worried. Call 111 if the unit cannot be reached. [NHS signs of labour; NHS stages]

**Call urgently (do not wait until morning)** if:
- waters break;
- vaginal bleeding;
- baby moving less than usual;
- under 37 weeks and may be in labour;
- **any contraction lasts longer than 2 minutes**;
- **6 or more contractions in 10 minutes**. [NHS]

**Call 999** if she "thinks the baby is coming now" and has a strong urge to push. [NHS]

NHS trust triage pages add detail: East Sussex says call when "contractions are five minutes apart lasting 40 seconds or more and painful"; a Worcestershire page says "around three times in every 10 minute period lasting 40 to 60 seconds and... consistently strong". If she arrives before labour is established she may be advised to go home. [ESHT; Worcs via search; NHS]

### 3.2 US rules
- **5-1-1**: contractions **every 5 minutes, lasting 1 minute, for at least 1 hour**; the most widely used; Cleveland Clinic phrases it "every five minutes for at least one hour". [Healthline; Cleveland Clinic]
- **4-1-1 / 3-1-1** appear only in consumer/doula sources (Baby Chick) as "stay home longer" variants for first-time mothers close to hospital; no clinical body publishes them. **ACOG itself gives no numeric timing rule**, only "call if you think you're in labour or are unsure" and the go-now list. Flag as informal. [Baby Chick via search; ACOG]
- Subsequent babies: call sooner; labour "progresses doubly quick" after a previous birth (Healthline citing a 2019 cohort). [Healthline]

### 3.3 Go in / call immediately regardless of timing
Waters with meconium (green/brown), any bleeding beyond a show, reduced movements, under 37 weeks, urge to push/bear down, previous fast labour or multiparous (call earlier), GBS-positive with waters gone (immediate induction offered), labour before a planned caesarean date, constant severe pain with no relief between contractions, cord felt/seen at the vagina (call 999, knees-chest or left side with hip raised, do not touch the cord). [NHS; ACOG; RCOG GBS; RCOG cord prolapse; Healthline]

### 3.4 How to measure (for the timer)
- **Frequency = start of one contraction to start of the next** (the 5-minute figure is start-to-start; NHS frequency language "every 5 minutes"; ACOG/Healthline time "when they happen and how long they last").
- **Duration = start to end of one contraction.**
- **Consistency = the pattern must hold for 1 hour or more** (5-1-1; NHS "regular").
- **Intensity proxy**: cannot talk/walk through them; "feeling consistently strong" (Worcs); ACOG: continue despite rest/water. The "can't talk through it" test is ubiquitous in antenatal teaching but is not stated on the NHS or ACOG pages fetched; label it as a heuristic.
- Suggested encoding (UK default): PROMPT TO CALL when median start-to-start interval 5 min or less AND median duration 45 to 60 s or more over a rolling 60-min window with 8 to 10 or more contractions; CALL NOW (override) if any duration over 120 s, or 6 or more contractions in any 10-min window, or any red-flag toggle (waters, bleeding, movements, under 37 wk, pushing urge). Multiparous or over 30 min from hospital: trigger at the first regular pattern "every 5 minutes" without waiting the full hour (NHS wording) and tell the user to phone early. US profile: 5-1-1 default, same overrides.
- NICE NG229/NG207 define **tachysystole/hyperstimulation as 5 or more contractions in 10 minutes** (for 20 min or more) or a contraction of 2 minutes or more; this is why NHS tells women to call at 6-in-10 or over 2 min. [NICE NG229; NG207]

### 3.5 Distance, home birth, and the triage call
- NHS: ask the midwife in advance how long a transfer would take and to which hospital; ACOG: measure the trip including traffic and rehearse it. [NHS where to give birth; ACOG]
- Home birth call-out: ESHT: call the triage line to send the midwife when contractions are 5 min apart, 40 s or more and painful, or when waters break; Sussex: call early if labour starts in the day so planning can happen. [ESHT; UHSussex via search]
- NHS home-birth safety: first baby, serious problems for baby about 9 in 1,000 at home vs 5 in 1,000 in hospital; for subsequent babies planned home birth is as safe as hospital/MLU; epidural not available at home. [NHS where to give birth]
- What triage will ask (NNUH SOP): length, strength and frequency of contractions; pain; **baby's movements over the last 24 hours**; any vaginal loss (SROM / bleeding / meconium) and its colour (look at the pad); handheld notes/alerts. Have the timer summary, time waters went and colour, and last-felt movement ready. [NNUH]

---

## 4. The partner's practical toolkit, by stage

### 4.1 Why it matters: the evidence
Cochrane (Bohren 2017; 26 trials, 15,858 women): continuous support vs usual care: spontaneous vaginal birth **RR 1.08** (1.04 to 1.12); **caesarean RR 0.75** (0.64 to 0.88, i.e. about 25% fewer); instrumental birth **RR 0.90** (0.85 to 0.96); any analgesia RR 0.90; regional analgesia RR 0.93; labour **0.69 h shorter**; low 5-min Apgar RR 0.62; **negative feelings about the birth RR 0.69** (0.59 to 0.79). No harms identified; evidence quality mostly low. Support = comfort measures + emotional support + information + advocacy, from someone whose *sole* job is supporting her, starting in early labour. Subgroups (exploratory): caesarean reduction strongest when the supporter was a doula; support from a chosen companion (partner/family) chiefly increases satisfaction. [Cochrane; PMC full text] In the US, partners provide labour support in 77% of births (Listening to Mothers III, via Lamaze). NICE: encourage support from birth companions of the woman's choice; one-to-one midwifery care; "do not leave a woman in established labour on her own except for short periods or at the woman's request." [NICE 1.4.5 to 1.4.13; NNUH]

### 4.2 Early/latent labour at home
- NHS: walk/move, drink (isotonic drinks), snack, breathing/relaxation with partner, partner rubs back, **paracetamol is safe in labour**, warm bath; rest at night, be gently upright/active by day. [NHS]
- TENS: NHS says probably most useful in early labour and for back pain; not shown effective in active labour; no known side effects; put it on early, before pain is strong. [NHS pain relief]
- NCT: provide distraction between contractions, set up equipment, bring snacks/water, help with TENS/breathing/hypnobirthing, help change position. [NCT]
- Timing: time a handful of contractions to establish a pattern, then stop; re-time when things change. (Obsessive timing is a frequent complaint in partner-advice sources; NHS language is "regular", not "logged".)
- Latent phase can last days: eat, sleep in shifts, do not go to hospital too early (you may be sent home). [NHS]

### 4.3 Established labour
- **Positions**: NICE/NNUH: for women without epidural, walking and upright positions reduce labour duration, caesarean risk and epidural use; for second stage, upright positions give slightly shorter labours, fewer episiotomies/assisted births; **with an epidural, lying on her side (lateral) gives more unassisted births than upright**; discourage lying flat/semi-recumbent. Options: standing/leaning, kneeling, all-fours (good for back pain), squatting, side-lying, birth ball. [NNUH citing Lawrence 2013, Gupta 2017, Walker 2018, RCOG 2020; NHS]
- **Back labour / OP ("back to back")**: longer labour, more caesarean/assisted birth; forward-leaning and all-fours positions ease backache (no good evidence they turn the baby). Lamaze: leaning while standing/kneeling, hands-and-knees, water, backward chair-sitting, slow dancing, asymmetric lunge, and the partner-performed **abdominal lift and tuck**; these positions give the partner access to the back for **massage, counter-pressure, ice and heat**. [NCT baby positions; Lamaze back pain; NHS Forth Valley via search]
- **Hands-on**: counter-pressure on the sacrum, double hip squeeze, firm low-back massage, cool flannel to face/neck, water spray/fan, sips of water (bottle with straw), lip balm, hair tie, emptying her bladder every 2 to 3 hours (NICE/NNUH: encourage passing urine 2 to 3 hourly; a full bladder can slow things). She may suddenly not want to be touched; don't take it personally. [NNUH; NHS hospital bag list; NHS pain relief]
- **Breathing coaching**: breathe *with* her; slow in through the nose, longer out through the mouth ("up-breathing", Tommy's); for gas and air, start breathing it as the contraction begins because it takes 15 to 20 s to work. [Tommy's via search; NHS]
- **Eating/drinking**: low-risk women may eat a light diet in established labour unless they've had opioids; isotonic drinks beneficial. [NNUH citing NICE]
- **Environment**: dim lights, her music, minimal chatter, protect her from interruptions, handle phones/family. [NNUH; NCT]
- **Words that work**: "You're doing it", "That one's gone", "Every contraction brings the baby closer", "I'm so proud of you"; agree in advance what she wants to hear. Avoid: "I know how you feel", complaining about your own tiredness/hunger, constant questions ("do you want a straw?"; a midwife's rule: *don't ask, do*), visible panic, chit-chat, inviting visitors she doesn't want. [Pediatrix OB; The Bump midwife; Baby Chick; NCT]

### 4.4 Transition
Signs: restlessness, vocalising, shaking, nausea/vomiting, hot/cold, "I can't do this", irritability, asking for an epidural after hours of refusing, bearing down before fully dilated. NNUH: "an extremely intense experience but... a normal part of labour... continuous support and reassurance is very important." Respond: stay, don't be offended, remind her it is nearly over and this intensity means she's close, short firm phrases, eye contact through contractions, sips of water, cool cloth, call the midwife if she feels pushy. [NNUH; HealthLinkBC; Sutter Health]

### 4.5 Pushing
- The midwife will say: push with the urge (feels like opening the bowels); with an epidural she may not feel it and will be coached; at crowning "stop pushing and pant/short breaths" so the head comes slowly (reduces tears); "the head's out, body with the next contraction". [NHS stages]
- Partner: stand by her head/shoulder (where she can see you), support a leg or her back in the position she's chosen, mirror the midwife's instructions, don't count loudly unless asked, don't photograph without prior agreement.
- **Cord**: ask beforehand; NHS Wales notes partners may be able to cut the cord, after at least 1 minute (NICE). [111 Wales; NICE]
- **Perineal protection**: OASI care bundle: warm compress between contractions, manual perineal protection, episiotomy only when indicated (mediolateral, 60°). [NNUH]

### 4.6 Third stage and the golden hour
- Baby goes straight onto her bare chest before the cord is cut; dried; **skin-to-skin for at least an hour or until after the first feed**, Apgar at 1, 5 (and 10) minutes done on her chest; weighing, measuring and ID bands can wait; avoid separating mother and baby in the first hour for routine procedures; first feed ideally **within 1 hour**. Not while she's on Entonox or drowsy from opioids (then **dad does skin-to-skin**). Keep her semi-reclined, baby's face visible, airway clear; watch colour/breathing; "always listen to parents and respond immediately to any concerns raised." [UNICEF BFI; NICE 1.11.1 to 1.11.11; NHS what happens straight after]

---

## 5. Pain relief and the partner's role

| Option | Facts | Side effects | Partner's job |
|---|---|---|---|
| **TENS** | Pads on back; self-controlled; best early/for back pain; hire or hospital | None known | Fit it early; boost button at contraction start |
| **Water** | Pool/bath, water 37.5°C or less (35 to 37°C first stage, about 37 at birth); enter once established (about 4 to 5 cm; too early may slow labour); must leave for meconium, FH concerns, opioids (no pool within 2h of pethidine/diamorphine), epidural | Rare neonatal infection reports; Cochrane (Cluett 2018) no difference in mode of birth, women calmer | Keep her hydrated, top up warmth, swimwear packed, not in the pool unless agreed |
| **Entonox (gas and air)** | 50:50 N2O/O2, self-administered, works in **15 to 20 s**, start at contraction onset | Light-headed, nausea, drowsiness, dry mouth; B12 issues if over 24h | Hand her the mouthpiece as contraction starts; don't use it yourself; she can't do skin-to-skin while on it |
| **Pethidine / diamorphine (IM)** | Onset **about 20 min**, lasts **2 to 4 h**; not if near second stage; given with antiemetic | Woozy, sick, forgetful; baby's breathing/drowsiness (reversal drug available), can interfere with first feed | Watch for nausea; she can't enter water for 2h |
| **Remifentanil PCA** | IV button, fast on/off, usable to birth; needs finger oxygen clip | Sleepiness, sickness, itch, breathlessness; baby's breathing briefly | Prompt her to press at contraction start; tell staff if she's very drowsy/sats alarm |
| **Epidural** | Anaesthetist only (not at home/freestanding MLU); drip first; **about 10 min to site, 10 to 15 min to work**; continuous CTG; catheter likely; top-ups by midwife or PCEA; may prolong second stage; delayed pushing 1 to 2h; lateral positions | Not working well **1 in 8**; BP drop **1 in 50**; severe headache **1 in 100**; temporary nerve damage 1 in 1,000, permanent 1 in 13,000; itch, shivering, fever; abscess/meningitis about 1 in 50,000 | Help her stay still curled on her side during siting (you may be asked to step out; look away if squeamish); watch BP alarms; remind her to change side every hour; she can't walk |
| **Hypnobirthing** | Breathing (long exhale), visualisation, relaxation, scripts; NICE says staff must respect chosen coping strategies | Evidence of benefit on pain/intervention is limited and mixed (Cochrane Madden 2016; trials show no clear difference) | Read scripts, play tracks, keep the room calm, use her anchors/cues |

Sources: NHS pain relief; OAA epidural card (NHS trust reproductions); NNUH; NHS Borders/Scottish water guidance via search; Tommy's/NCT hypnobirthing; The Conversation.

---

## 6. Interventions and what they mean

**Induction (IOL).** Offered from **41+0 weeks** (stillbirth/NICU/caesarean risks rise past 41 weeks), for term PROM after about 24h, and for conditions (diabetes, hypertension/pre-eclampsia, cholestasis, poor growth). About 1 in 3 UK labours are induced (FHFT leaflet). Steps: **membrane sweep** (from 39 weeks; may cause cramping/bleeding), then **prostaglandin** (dinoprostone pessary/gel/tablet, or oral misoprostol) or **balloon catheter/osmotic dilator** when Bishop score 6 or less, then **ARM** + **oxytocin (Syntocinon) drip** when Bishop over 6, then continuous CTG once contracting on oxytocin. Can take many hours; "up to 48 hours" (Walsall) or longer with multiple cycles; induced labour is usually more painful, more likely to need assisted birth. Hyperstimulation = 5 or more in 10 min for 20 min or more or a contraction of 2 min or more: stop drug, remove pessary, consider terbutaline. **"Failed induction"** = labour not established after one treatment cycle: options are rest and retry, expectant management, further attempts, or caesarean. Outpatient induction possible for low-risk women. It's her choice to accept or decline. [NHS inducing labour; NICE NG207; Walsall and FHFT via search]

**Augmentation** = ARM and/or oxytocin for slow established labour (see section 2 delay rules). [NICE; NNUH]

**Monitoring.** *Intermittent auscultation* (Pinard/handheld doppler): 1 minute or more immediately after a contraction, **every 15 min in first stage, every 5 min in second stage**, with maternal pulse checked to distinguish the two heartbeats. *Continuous CTG* ("the trace", two belts) is offered for risk factors: previous caesarean, hypertension on medication, prolonged ruptured membranes, bleeding, suspected infection, diabetes on medication, breech, growth restriction, over 42 weeks, reduced movements, meconium, maternal temp 38°C or more (or 37.5°C or more twice), pulse over 120 twice, delay, epidural, oxytocin. Trace features are graded white/amber/red: baseline normal **110 to 160 bpm**; variability normal 5 to 25 bpm; accelerations (15 bpm or more for 15 s or more) reassuring; **decels** (drop over 15 bpm for 15 s or more): early = normal, variable with concerning features for over 30 min = red, late = red, a single prolonged decel of 3 min or more = urgent review and expedite birth if persisting 9 min. Overall: normal (all white), suspicious (one amber), pathological (one red or two amber). A CTG started for concern can be stopped after 20 min if normal. [NICE NG229; NHS stages]
- **Fetal scalp electrode (FSE)**: clip on the baby's scalp for a clearer trace when belts are unreliable; removed at birth. **Fetal blood sampling (FBS)**: a tiny scalp blood sample to measure pH/lactate when the trace is abnormal, to decide whether the baby is coping or needs delivery (cut-offs about pH under 7.21 / lactate over 4.8 mmol/L in trials; local protocols vary). [NHS; Cochrane CD006174 via search]

**Episiotomy and tears.** Up to **9 in 10 first-time mothers** tear, graze or have an episiotomy. 1st degree = skin, often unstitched; 2nd = perineal muscle, stitched in the room under local/epidural top-up, usually within an hour of birth; **3rd = into the anal sphincter (3a/3b/3c), 4th = into the rectal lining**; OASI (3rd/4th) in **about 3 in 100** vaginal births (6 in 100 first births, 2 in 100 subsequent; up to 4% after ventouse, 8 to 12% after forceps), repaired **in theatre under spinal/epidural**, with catheter, antibiotics, laxatives, physio and a 6 to 12-week follow-up; 6 to 8 in 10 have no lasting problems. Episiotomy reasons: fetal distress, instrumental birth, risk of anal tear, breech. [NHS episiotomy and tears; RCOG OASI; RCOG assisted birth]

**Assisted (instrumental) birth.** About 1 in 8 UK births (10 to 15%); **about 1 in 3 first babies**. Reasons: concern for baby, no progress, unable/advised not to push. Ventouse (cup; may pop off) vs forceps (curved blades; preferred under 36 weeks and for rotation); episiotomy more likely; done in the room if expected to be straightforward, **in theatre ("trial of instrumental") if it might fail so a caesarean can follow immediately**; antibiotics afterwards; a paediatrician may attend. Risk factors for failure: OP position, high head, baby over 4 kg. Less likely with continuous support, upright/lateral positions, delayed pushing with epidural. [RCOG assisted birth]

**Caesarean.** NHS says around 45% of babies in England are now born by caesarean (NHS page figure; quote cautiously). *Planned* (from 39 weeks: breech, praevia, pre-eclampsia, maternal request after discussion). *Emergency* categories (NICE NG192): **Cat 1: immediate threat to life, birth usually within 30 min of decision** (e.g. cord prolapse, abruption, severe fetal distress); **Cat 2: compromise not immediately life-threatening, usually within 75 min**; Cat 3: no compromise but early birth needed; Cat 4: timed to suit. Regional anaesthesia (spinal/epidural top-up) preferred; **birth partner can be present**, sits at her head, screen across the tummy, baby out in **5 to 10 min**, whole operation **40 to 50 min**, oxytocin given to reduce bleeding, catheter out at 12 to 18h, home **1 to 2 days** (NICE: can be discharged after 24h if well). Under **general anaesthetic the partner is normally not allowed in theatre**; he waits nearby and usually gets the baby for skin-to-skin in recovery. Cat 1 under GA is the scenario that most frightens partners: it is fast, loud and he is excluded; tell him in advance. [NHS caesarean; NICE NG192; RCOG classification via search]

**VBAC.** About 3 in 4 succeed (8 to 9 in 10 with a previous vaginal birth); scar rupture up to **1 in 200** (2 to 3 times higher if induced); continuous CTG, cannula and hospital birth advised; not advised after 3 or more caesareans, previous rupture or classical scar. [RCOG VBAC]

**Breech / transverse.** 3 to 4 in 100 at term; ECV works for about 1 in 2 (1 in 200 need emergency caesarean right after); planned caesarean is safer for the baby than planned vaginal breech (about 1 vs 4 deaths per 2,000); transverse lie means caesarean, small cord-prolapse risk. [RCOG breech; NHS breech]

**Emergencies the partner may witness (why the room fills up).**
- **Shoulder dystocia** (about 1 in 150): head born, shoulder stuck; buzzer, 3 to 4 extra staff, "stop pushing", legs pulled back (McRoberts), pressure above pubic bone, possible episiotomy or all-fours; about 1 in 10 affected babies have a (usually temporary) brachial plexus injury. [RCOG]
- **Cord prolapse** (1 in 200 to 1,000): hand kept inside to lift the head off the cord, bladder filled, immediate caesarean often under GA. [RCOG]
- **PPH**: 500 ml or more = minor, over 1,000 ml = major; uterine massage, second uterotonic, catheter, IV fluids/tranexamic acid, checking placenta/tears, theatre if continuing (balloon, surgery). Most women have no risk factors; staff should keep the partner informed and the baby cared for. [RCOG PPH; NICE 1.10.29 to 35]
- **Retained placenta**: over 30 min active / over 60 min physiological: empty bladder, feed/skin-to-skin, position change, then manual removal in theatre under regional anaesthetic. [NICE; GGC]
- **Pre-eclampsia/eclampsia**: severe headache not eased by paracetamol, visual disturbance, pain under ribs, sudden swelling, vomiting: report immediately, including in the weeks *after* birth; BP 160/110 or more is a transfer trigger; magnesium for seizure prevention; early delivery. [NHS pre-eclampsia; NNUH]
- **Meconium**: significant meconium means obstetric unit, continuous CTG, advanced neonatal resuscitation staff at birth, baby observed at 1, 2, then 2-hourly to 12h. [NICE 1.8.33, 1.11.27]
- **"The baby doctors are coming" / resus table (Resuscitaire)**: paediatric/neonatal staff are routinely called for meconium, instrumental birth, caesarean under GA, prematurity or any concern. Up to about 85% of babies breathe spontaneously, about 10% more after drying/stimulation, few need inflation breaths and **under 0.3% need chest compressions** (ERC/RCUK figures via secondary sources). NHS: "some babies need help starting to breathe and may be given oxygen briefly in another part of the room, then returned to you." [NHS what happens after; RCUK/ERC via search]

---

## 7. Glossary: what they actually mean, and should I worry?

| Term | Plain English | Worry? |
|---|---|---|
| **Tightenings** | Midwife-speak for contractions, especially early/irregular ones | No |
| **Latent phase / early labour** | Contractions with cervix opening up to 4 cm; can last days | No, but tiring |
| **Established / active labour** | Regular contractions + progressive dilatation from 4 cm (US: 6 cm) | No. This is "go" |
| **Dilated / "she's 6"** | Cervix opening, 0 to 10 cm | Progress marker only |
| **Fully / fully dilated / FD** | 10 cm; second stage can begin | Good news |
| **Effaced** | Cervix thinned/shortened (often %) | Good sign |
| **Station / -2 / 0 / +1** | How low the head is relative to the ischial spines (bony landmarks); 0 = at the spines, + = lower | Lower is better |
| **Engaged / "3/5 palpable"** | How much of the head the midwife can still feel above the pelvis in fifths; 2/5 or less palpable = engaged | Normal |
| **Vertex / cephalic (ceph)** | Head down, crown first | Ideal |
| **LOA / ROA / OP** | Left/right occiput anterior = baby's back to mum's front (ideal); OP = "back-to-back" (longer, backache) | OP: longer, not dangerous |
| **Membranes / SROM / ARM / PROM / PPROM** | Waters; spontaneous rupture; artificial rupture (midwife breaks them with a hook); pre-labour rupture at term; pre-term pre-labour rupture (under 37 wk) | PPROM: hospital now |
| **Show** | Mucus plug, pink-tinged | No unless frank bleeding |
| **VE** | Vaginal examination (usually 4-hourly; she can decline) | No |
| **Primip / multip; G2P1** | First birth / had a baby before; Gravida 2 = second pregnancy, Para 1 = one previous birth | No |
| **Fundal height / SFH** | Bump measurement in cm, roughly equal to weeks | No |
| **Obs / MEOWS** | Temperature, pulse, BP, breathing, sats; an early-warning score | Only if they escalate |
| **BP** | Blood pressure; 140/90 or more twice or 160/110 or more once triggers doctors | Yes if high |
| **CTG / the trace** | Continuous heart-rate and contraction printout | Normal / suspicious / pathological |
| **Variability / accelerations** | Beat-to-beat wobble (5 to 25 bpm) and brief rises; both reassuring | Low variability over 50 min is red |
| **Decels** | Dips in baby's heart rate; early = normal squeeze on head; variable = cord compression; late = concerning | Late/prolonged: action |
| **FSE / FBS** | Clip on baby's scalp for a better trace / scalp blood test to check oxygen | Means they want certainty |
| **Ketones / urinalysis** | Urine dipstick showing she's running on empty; eat/drink | Mild |
| **Syntocinon / oxytocin / "the drip"** | Synthetic hormone to start or strengthen contractions; needs CTG | Contractions get stronger |
| **Prostin / Propess / pessary / gel** | Prostaglandin induction drugs (gel/tablet or 24-h pessary) | No |
| **Sweep** | Finger sweep around the cervix to trigger labour | Cramps/spotting normal |
| **Balloon (Cook/Foley)** | Mechanical induction | No |
| **Partogram / "action line"** | Progress chart; crossing the line prompts review | Review, not crisis |
| **"We'll see how things go in 4 hours"** | Standard 4-hourly VE interval; expecting about 2 cm progress | Normal pacing |
| **Delay / "failure to progress"** | Under 2 cm in 4 h: ARM, then oxytocin, then review | Common; a cascade point to use BRAIN |
| **Transition** | The last cm before pushing; intense, "I can't" | Normal and brief |
| **Crowning / "ring of fire"** | Widest part of head stretching the perineum; midwife says pant | Seconds to minutes |
| **Episiotomy** | Cut to enlarge the opening | Stitched after |
| **1st/2nd/3rd/4th degree tear; OASI** | Skin / muscle / anal sphincter / rectal lining | 3rd/4th: theatre repair, follow-up |
| **Ventouse / Kiwi / forceps / "trial in theatre"** | Suction cup / blades; theatre = may convert to caesarean | Partner can usually attend |
| **Theatre / spinal / GA / Cat 1 section** | Operating room; one-shot regional anaesthetic; general anaesthetic (partner excluded); the fastest caesarean (30 min or less) | Cat 1 is urgent; most babies are fine |
| **Cannula / catheter / TED stockings** | Drip line in hand; bladder tube (epidural/caesarean); anti-clot stockings | Routine |
| **Active / physiological third stage** | Injection + cord traction vs. waiting | Her choice |
| **Retained placenta** | Not out in 30/60 min: theatre | Common-ish, manageable |
| **PPH / "the bell"** | Bleeding 500 ml or more; emergency buzzer brings the team | Scary but rehearsed |
| **Apgar** | 0 to 10 score at 1 and 5 (and 10) min; 7 or more is fine; 1-min scores are often lower | Only 5-min score matters much |
| **Cord gases** | Blood test from the cord after an eventful birth | Routine check |
| **Vitamin K** | Injection (or oral doses) to prevent rare bleeding disorder | Routine |
| **NIPE / newborn check** | Full examination within 72 h (eyes, heart, hips, testes) | Routine |
| **Jaundice / bili / phototherapy** | Yellowing peaking about day 3, clears about 2 weeks; light treatment about 48 h if high; jaundice under 24 h old = 999/A&E | Common; early onset is not |
| **Colostrum / hand expressing / EBM** | First concentrated milk (teaspoon per feed); squeezing it out by hand | Feeds 8 to 12 times per 24 h |
| **Transitional care / SCBU / LNU / NICU** | Baby with mum with extra support / special care (Level 1) / local neonatal unit (Level 2) / intensive care (Level 3) | Depends on level |
| **MLU / birth centre / CLU / "consultant-led" / "high risk" / obstetric unit** | Midwife-run unit (no epidural if freestanding) vs. doctor-available ward; "high risk" = needs doctors available, not = danger | No |
| **Triage / MAU / DAU / MAC** | Maternity assessment/day unit; the phone number to call | No |
| **Doctors' review / "the reg" / "the consultant"** | Obstetric registrar/consultant asked to look at the picture | Ask what they're reviewing and why |
| **Handover** | Shift change (about 08:00/20:00); new midwife; recap the plan with her | Re-state birth preferences |
| **BRAIN** | Benefits, Risks, Alternatives, Intuition, Nothing (what if we wait?) | The tool for every decision |

Sources: NICE NG235/NG229/NG192; NHS; NNUH glossary; CTMUHB abbreviations; RCOG leaflets; Bliss; UNICEF; Lamaze BRAIN.

---

## 8. Rights and advocacy

- **Only she consents.** "Only you can give informed consent... Your birth partner cannot give consent for you," but he can speak up for her, say she can't take in information right now, and ask for time or clearer explanation. After birth, consent for the baby's treatment needs someone with parental responsibility (married fathers / those on the birth certificate have it). [Birthrights birth partners]
- **Absolute right to decline** any treatment, even if that risks her or the baby; consent can be withdrawn mid-procedure; staff "cannot perform procedures, such as assisted birth (forceps or ventouse), without your agreement"; threats or time pressure (e.g. social services) are "undue influence"; staff must not restrain. Montgomery: information must cover material risks, alternatives and doing nothing; leaflets alone are not enough. [Birthrights consent]
- **Right to choose birth partner(s)** (Article 8 ECHR); hospital policy on numbers must be applied flexibly, with reasonable adjustments; partner excluded only with proportionate justification (e.g. previous violence; theatre under GA for clinical reasons); hospitals should allow partners to stay postnatally where possible (e.g. after caesarean). [Birthrights birth partners]
- AIMS' stance: "Maternity services are usually the ones who need to ask for your permission"; don't ask "am I allowed?". [AIMS via search]
- **How a partner asks without being adversarial**: use BRAIN out loud ("What are the benefits for her and the baby? Risks? Alternatives? What happens if we wait an hour?"); ask "Is this an emergency or a recommendation?"; "Can we have five minutes alone to decide?"; "Can we speak to the consultant/senior midwife?"; RCOG's three questions: *What are my options? What are the pros and cons of each? How do I get support to make a decision that is right for me?* [Lamaze BRAIN; RCOG shoulder dystocia; Birthrights]
- **If something feels wrong**: say it to the midwife first; use the call bell; ask for the coordinator/senior midwife; ask for an obstetric review. **Martha's Rule** (England): a 24/7 line to request an urgent independent review by the critical-care/outreach team when a patient is deteriorating and concerns aren't being addressed; covers maternity wards, MLUs and home care in trusts like OUH; say "Martha's Rule call"; rolled out to all acute sites in England during 2025 (full implementation expected through 2026/27 per NHS England). Not a complaints route (PALS is). [OUH; NHS England via search; Healthwatch Kingston via search]

---

## 9. Partner self-care

- Eat and drink (NCT: manage your own food, drink, rest and toilet breaks; pack your own snacks, change of clothes, charger/power bank, coins for parking and vending). Sleep in shifts in a long latent phase; someone has to be functional for pushing. [NCT; NHS hospital bag]
- **Fainting** is common enough that L&D nurses have a script: low blood sugar, standing still with locked knees, heat and anxiety trigger it; sit before you fall; tell staff early ("responsible, not dramatic"); look away during epidural siting or the caesarean incision if squeamish; if a midwife tells you to step back or sit, do it. [Upworthy/nurse; midwife via search]
- Blood: a second-degree tear repair, a PPH or theatre can look like a lot; the team's calm is informative; watch the midwife's face, not the floor.
- Fear: ask to be told what's happening ("the midwife should explain to the woman and partner what is happening and why", RCOG PPH); you are allowed to say "I'm scared, tell me what you need me to do."
- **Birth trauma in partners**: pooled meta-analysis (154 studies, n=54,711): fathers **1.2% PTSD, 1.3% clinically significant symptoms** vs 4.7%/12.3% in mothers; individual studies range about 1 to 7% symptom-level, higher after emergency caesarean/instrumental birth and when the partner felt sidelined ("merely a passenger"); UK qualitative study: fathers wanted explanations, **debriefs**, and dad peer groups; stigma ("be quiet and man up") delayed help-seeking. Post-birth: ask the unit for a birth reflections/debrief appointment, see the GP, Birth Trauma Association peer support, Dads in Mind/local perinatal mental health teams; symptoms can surface months later. [Heyne 2022 Clin Psychol Rev; Daniels 2020 BMC Preg Childbirth; KMPT/EKHUFT via search]

---

## 10. Immediately after

- **Golden hour**: skin-to-skin 1 h or more/until first feed; Apgar at 1 and 5 min on mum; cord cut after 1 min or more (dad can); placenta; stitches with her still cuddling baby (epidural top-up or local); baby dried, weighed, measured, ID bands; **vitamin K** injection (or oral course); newborn exam within 72 h. Dad's skin-to-skin if mum is on Entonox, in theatre under GA, or being stitched in theatre. [NICE 1.11; UNICEF; NHS what happens straight after; NHS NIPE]
- **First feed**: within the hour ideally; colostrum about a teaspoon per feed; then 8 to 12 feeds per 24 h; hand expressing taught by the midwife. [NHS first few days]
- **Going home**: straightforward vaginal birth **from about 6 h** (many trusts 4 to 6 h+; average stay one day); instrumental 1 to 2 days; caesarean 1 to 2 days (NICE: discharge possible after 24 h); GBS/meconium/PROM babies observed 12 h; 47% of women in England spent one day in postnatal care in 2022/23. [DBTH, Hampshire, UCLH, North Mid via search; NICE NG192; NICE NG235]
- **Bring/do**: NHS bag list: car seat (fitted *before* labour), going-home outfit, snacks, long charging cable, straw bottle, change for parking; partner: clothes, toiletries, swimwear for the pool, meds, glasses. [NHS hospital bag]
- **Comms plan** (agree beforehand): who gets the first call, a single "we're in, all fine, no news is good news" text, phone on silent in the room, no posting before both parents agree, no photos/video of her without explicit consent (and staff consent in theatre). NCT: the partner "handles questions from other family members". [NCT]
- Visiting/partner staying overnight: hospital policies vary; Birthrights says they should be applied flexibly. [Birthrights]

---

## 11. Things partners commonly get wrong (true, and funny later)

- **Falling asleep during contractions** (it is 3 a.m.; it will be remembered). Nap in shifts in the latent phase, not in the delivery room. [NCT self-care; Pediatrix]
- **Eating a kebab/crisps in the room** or complaining you're hungry/tired: "pointing out that you're hungry, tired, stressed or uncomfortable will not help anyone." [Pediatrix OB]
- **Filming or photographing without asking**: agree boundaries in advance; many units restrict filming in theatre.
- **"We're pregnant" / "we're in labour"** and **"it can't hurt that much"** / "I know how you feel": "YOU DON'T." [Baby Chick]
- **Asking instead of doing** ("Do you want a straw? Ice? Music?"): a midwife's rule: don't ask, do. [The Bump]
- **Going home to shower/feed the dog at 8 cm**: second babies and transition move fast; ask the midwife "how long do I realistically have?" before leaving.
- **Forgetting the car seat**: on the NHS packing list; you will not be allowed to improvise. [NHS]
- **Parking fines and dead phones**: bring coins/app set-up and a power bank; hospital Wi-Fi is unreliable. [NHS bag list]
- **Hungover**: Entonox is for her; hospitals are hot and bright.
- **Fainting**: eat, sit, don't lock your knees, look away from the needle. [nurse guidance]
- **Taking it personally** when she swears at you in transition: it's a sign the baby is close. [Sutter Health]

---

## Key numbers cheat-sheet (for app logic)

| Item | Value | Source |
|---|---|---|
| Established labour | from 4 cm (UK) / 6 cm (US) | NICE NG235 / ACOG-SMFM |
| First stage, first baby | mean 8 h, unlikely over 18 h | NICE 1.8.36 |
| First stage, subsequent | mean 5 h, unlikely over 12 h | NICE 1.8.36 |
| Expected progress | 2 cm or more / 4 h | NICE 1.8.42; GGC |
| Active second stage expected | 3 h or less (nullip), 2 h or less (multip) | NICE 1.9.25 to 26; NHS |
| Refer for delay in second stage | 2 h (nullip), 1 h (multip) of active pushing | NICE |
| Passive second stage w/ epidural | up to 2 h (nullip), 1 h (multip) | NICE 1.9.27 to 28 |
| Third stage prolonged | over 30 min active, over 60 min physiological | NICE 1.10.20 |
| Cord clamping | 1 min or more, under 5 min (active) | NICE 1.10.14 |
| UK call trigger | regular contractions every 5 min or more often | NHS |
| UK urgent triggers | contraction over 2 min; 6 or more in 10 min; waters; bleeding; reduced movements; under 37 wk | NHS |
| UK 999 | strong urge to push | NHS |
| US rule | 5-1-1 (every 5 min, 1 min long, for 1 h) | Healthline/Cleveland |
| Tachysystole | 5 or more contractions / 10 min | NICE NG229/NG207 |
| Term PROM | 60% labour in 24 h; induce after about 24 h; temp q4h | NICE 1.7 |
| IA frequency | q15 min (1st stage), q5 min (2nd) | NICE NG229 |
| Entonox onset | 15 to 20 s | NHS |
| Pethidine | onset 20 min, lasts 2 to 4 h | NHS |
| Epidural | 10 min to site + 10 to 15 min to work; 1 in 8 inadequate; 1 in 100 headache | NHS; OAA |
| Cat 1 / Cat 2 CS | 30 min or less / 75 min or less decision-to-birth | NICE NG192 |
| Caesarean duration | 5 to 10 min to baby, 40 to 50 min total | NHS |
| Assisted birth | 1 in 8 overall; 1 in 3 first babies | RCOG |
| OASI | 3 in 100 (6 first birth, 2 subsequent) | RCOG |
| Shoulder dystocia | 1 in 150 | RCOG |
| Cord prolapse | 1 in 200 to 1,000 | RCOG |
| PPH | 500 ml or more minor, over 1,000 ml major | RCOG |
| VBAC success / rupture | 3 in 4 / 1 in 200 | RCOG |
| GBS EOGBS | 1 in 1,750; antibiotics 1/400 to 1/4,000; 4 h or more before birth | RCOG |
| Home vs hospital (first baby) | 9 vs 5 per 1,000 serious baby problems | NHS |
| Discharge | about 6 h+ vaginal; 1 to 2 days CS/instrumental | NHS trusts; NICE |
| Father PTSD | 1.2% (meta-analysis) | Heyne 2022 |
| Continuous support | CS RR 0.75; instrumental RR 0.90; negative experience RR 0.69 | Cochrane 2017 |

---

## Sources (URLs actually used)

NHS
- https://www.nhs.uk/pregnancy/labour-and-birth/signs-of-labour/signs-that-labour-has-begun/
- https://www.nhs.uk/pregnancy/labour-and-birth/what-happens/the-stages-of-labour-and-birth/
- https://www.nhs.uk/pregnancy/labour-and-birth/what-happens/pain-relief-in-labour/
- https://www.nhs.uk/pregnancy/labour-and-birth/signs-of-labour/inducing-labour/
- https://www.nhs.uk/conditions/caesarean-section/
- https://www.nhs.uk/conditions/caesarean-section/what-happens/
- https://www.nhs.uk/pregnancy/labour-and-birth/what-happens/episiotomy-and-perineal-tears/
- https://www.nhs.uk/pregnancy/labour-and-birth/after-the-birth/what-happens-straight-after/
- https://www.nhs.uk/pregnancy/keeping-well/your-babys-movements/
- https://www.nhs.uk/pregnancy/labour-and-birth/preparing-for-the-birth/where-to-give-birth-the-options/
- https://www.nhs.uk/pregnancy/labour-and-birth/preparing-for-the-birth/pack-your-bag-for-labour/
- https://www.nhs.uk/pregnancy/labour-and-birth/what-happens/if-your-baby-is-breech/
- https://www.nhs.uk/conditions/pre-eclampsia/
- https://www.nhs.uk/conditions/group-b-strep/
- https://www.nhs.uk/conditions/jaundice-newborn/
- https://www.nhs.uk/conditions/baby/breastfeeding-and-bottle-feeding/breastfeeding/the-first-few-days/
- https://www.nhs.uk/conditions/baby/newborn-screening/physical-examination/
- https://111.wales.nhs.uk/livewell/pregnancy/BirthingPartner
- https://ctmuhb.nhs.wales/services/maternity/tips-for-birth-partner/common-abbreviations-used-in-pregnancy/

NICE
- https://www.nice.org.uk/guidance/ng235/chapter/Recommendations (Intrapartum care, 2023)
- https://www.nice.org.uk/guidance/ng229/chapter/Recommendations (Fetal monitoring in labour)
- https://www.nice.org.uk/guidance/ng207/chapter/Recommendations (Inducing labour)
- https://www.nice.org.uk/guidance/ng192/chapter/Recommendations (Caesarean birth)

NHS trust guidelines adapted from NICE
- https://www.nnuh.nhs.uk/publication/download/intrapartum-care-v13 (Norfolk and Norwich, Oct 2024)
- https://rightdecisions.scot.nhs.uk/media/2b2aculj/delay-in-labour-pathway-v1-1165.pdf (NHS GGC, Aug 2024)
- https://gpnotebook.com/en-GB/pages/obstetrics/2nd-stage-of-labour
- https://gpnotebook.com/en-GB/pages/obstetrics/3rd-stage-of-labour
- https://www.esht.nhs.uk/service/maternity/labour-and-birth/when-to-call-the-midwife-homebirth-or-go-into-hospital/
- https://www.uhsussex.nhs.uk/wp-content/uploads/2025/07/2570-Homebirth-Advice-2025.pdf
- https://www.worcsacute.nhs.uk/maternity-services/labour-and-birth/when-to-call-triage/
- https://www.liverpoolwomens.nhs.uk/media/1944/epidural-information-card-epidurals-in-labour.pdf (OAA card)
- https://www.royaldevon.nhs.uk/media/uvek3e1i/epidural-information-card-epidurals-in-labour-what-you-need-to-know.pdf
- https://www.walsallhealthcare.nhs.uk/wp-content/uploads/2022/11/Induction-of-Labour-Information-Leaflet.pdf
- https://www.fhft.nhs.uk/patients-and-visitors/patient-information-library/information-induction-labour
- https://www.rightdecisions.scot.nhs.uk/nhs-borders-clinical-guidelines/obstetrics-gynaecology/maternity/intrapartum-care-and-complications/pool-use-in-labour-and-birth/
- https://www.dbth.nhs.uk/services/maternity/general-information/our-postnatal-wards/
- https://www.hampshirehospitals.nhs.uk/our-services/az-departments-and-specialties/maternity-hampshire-hospitals/after-birth-your-baby
- https://uclh.nhs.uk/our-services/find-service/womens-health-1/maternity-services/postnatal-care/after-your-baby-born
- https://www.northmid.nhs.uk/after-your-birth-postnatal-care
- https://www.ouh.nhs.uk/patient-guide/marthas-rule/
- https://nhsforthvalley.com/?p=3805126

RCOG patient information
- https://www.rcog.org.uk/for-the-public/browse-our-patient-information/assisted-vaginal-birth-ventouse-or-forceps/
- https://www.rcog.org.uk/for-the-public/browse-our-patient-information/care-of-a-third-or-fourth-degree-tear-that-occurred-during-childbirth-also-known-as-obstetric-anal-sphincter-injury-oasi/
- https://www.rcog.org.uk/for-the-public/browse-our-patient-information/shoulder-dystocia/
- https://www.rcog.org.uk/for-the-public/browse-our-patient-information/umbilical-cord-prolapse-in-late-pregnancy/
- https://www.rcog.org.uk/for-the-public/browse-our-patient-information/heavy-bleeding-after-birth-postpartum-haemorrhage/
- https://www.rcog.org.uk/for-the-public/browse-our-patient-information/birth-after-previous-caesarean/
- https://www.rcog.org.uk/for-the-public/browse-our-patient-information/group-b-streptococcus-gbs-in-pregnancy-and-newborn-babies/
- https://www.rcog.org.uk/for-the-public/browse-our-patient-information/breech-baby-at-the-end-of-pregnancy/

Cochrane / research
- https://www.cochrane.org/CD003766/PREG_continuous-support-women-during-childbirth
- https://pmc.ncbi.nlm.nih.gov/articles/PMC6483123/ (Bohren 2017 full text)
- https://pure.eur.nl/en/publications/prevalence-and-risk-factors-of-birth-related-posttraumatic-stress/ (Heyne et al. 2022, Clin Psychol Rev 94:102157)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC7179006/ (Daniels et al. 2020, BMC Pregnancy Childbirth 20:236)
- https://cochranelibrary.com/cdsr/doi/10.1002/14651858.CD006174.pub2/full (fetal scalp lactate vs pH)
- https://theconversation.com/hypnobirthing-scant-evidence-self-hypnosis-reduces-pain-during-childbirth-128024

Rights and advocacy
- https://www.birthrights.org.uk/factsheets/consenting-to-treatment/
- https://birthrights.org.uk/wp-content/uploads/2025/03/Birth-partners-factsheet-March-2025.docx.pdf
- https://www.aims.org.uk/campaigning/item/nhse-letter
- https://shop.aims.org.uk/products/aims-guide-to-your-rights-in-pregnancy-birth
- https://www.england.nhs.uk/patient-safety/marthas-rule/
- https://www.healthwatchkingston.org.uk/news/2025-09-12/marthas-rule-rolled-out-all-acute-hospitals-england
- https://lamaze.org/Giving-Birth-with-Confidence/GBWC-Post/use-your-brain-when-communicating-with-your-care-provider-about-birth-1

Partner support / education
- https://www.nct.org.uk/labour-birth/dads-and-partners/ten-tips-for-birth-partners
- https://www.nct.org.uk/labour-birth/getting-ready-for-birth/baby-positions-womb-birth
- https://nct.org.uk/labour-birth/getting-ready-for-birth/hypnobirthing-where-start
- https://tommys.org/pregnancy-information/giving-birth/pain-relief/hypnobirthing
- https://lamaze.org/Connecting-the-Dots/Post/lamaze-healthy-birth-practice-3-bring-a-loved-one-friend-or-doula-for-continuous-support
- https://lamaze.org/Giving-Birth-with-Confidence/GBWC-Post/best-labor-positions-for-back-pain
- https://www.unicef.org.uk/babyfriendly/baby-friendly-resources/implementing-standards-resources/skin-to-skin-contact/
- https://www.bliss.org.uk/different-levels-of-care
- https://www.healthlinkbc.ca/living-well/family-planning-pregnancy-and-childbirth/labour-and-birth/stages-labour/first-stage-1
- https://www.sutterhealth.org/health/labor-stages-suggestions
- https://www.pediatrix.com/about/for-media/news/how-to-support-your-partner-in-labor
- https://www.thebump.com/new-mom-new-dad/your-life/articles/he-said-what-in-the-delivery-room.aspx
- https://www.baby-chick.com/what-not-to-do-or-say-to-a-woman-in-labor/
- https://www.upworthy.com/the-internet-slams-a-man-drinking-water-while-his-partner-gives-birth-but-a-nurse-sets-them-straight

US contrast
- https://www.acog.org/womens-health/faqs/how-to-tell-when-labor-begins
- https://my.clevelandclinic.org/health/articles/9676-labor-delivery
- https://www.healthline.com/health/pregnancy/when-to-go-to-the-hospital-for-labor
- https://www.baby-chick.com/when-to-go-to-the-hospital-in-labor/ (4-1-1/3-1-1, informal)
- https://evidencebasedbirth.com/friedmans-curve-and-failure-to-progress-a-leading-cause-of-unplanned-c-sections/ (ACOG/SMFM 2014 definitions; summary only, page blocks fetch)
- https://resus.org.uk/node/11335 and https://cpd.nwas.nhs.uk/?p=1239 (newborn resuscitation proportions; accessed via search summaries only)

**Not obtained (blocked or 404) and therefore not cited for content:** Tommy's birth-partner page, DONA, RCM position statement, Birth Trauma Association partners page, NHS England Martha's Rule page text (rollout facts taken from OUH and Healthwatch), Lamaze "when to go to hospital" article.
