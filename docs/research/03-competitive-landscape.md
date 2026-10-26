# Competitive Landscape and Gap Analysis: Apps and Content for Expectant Fathers / Birth Partners, Contraction Timers and Labour Companions

Author: Liam Daly
Research date: 26 October 2026.

*Method: about 45 web searches and about 60 direct page fetches of App Store / Google Play listings, developer sites, NHS pages, Apple/Google developer docs, Goodreads, Product Hunt and academic repositories. Note: reddit.com (r/daddit, r/predaddit, r/BabyBumps) is blocked to the crawler at the domain level, so community-tone evidence below comes from App Store reviews, Product Hunt comments, Goodreads reviews and a peer-reviewed discourse analysis rather than Reddit directly. Ratings are App Store (US or UK) unless stated; counts are approximate snapshots.*

---

## 1. Executive summary

- **The dad-app category is small, dated and thin on labour.** The only app with real scale is **Daddy Up** (4.9 stars, about 3K iOS ratings, about 250K Android installs), which is themed (lumberjack / "Lady Lumberjill" / "cub"), free with a $5.99 unlock, and includes a basic contraction timer but no Apple Watch, no birth plan, no jargon help and no "when to go in" logic. Most other dad apps are either abandoned (Pregnant Dad last updated 2022, 3.4 stars; Who's Your Daddy launched 2014 and no longer resolves in the US/UK App Store), NHS-commissioned-but-clinical (DadPad, 3.0 stars from 18 reviews), or brand-new with no ratings (Dad's Guide UK, DADit, BumpTrackr).
- **Humour is the most divisive design decision in the category, and the evidence says it fails when it's laddish.** Who's Your Daddy's screenshot joke ("That hot girl over there... Don't even think of looking at her") drew "offensive" comments on Product Hunt; Rob Kemp's *Expectant Dad's Survival Guide* (3.61 stars Goodreads) gets "Patronising. Far too laddish"; a 2018 *Journal of Gender Studies* paper found pregnancy apps "condescend" to fathers and assume men "need amusement and encouragement to get involved". Humour that works (Matt Coyne's *Man vs Baby*, Daddy Up's defenders) is self-deprecating, competence-building and never at the partner's expense.
- **Contraction timers are commoditised and almost all mum-facing.** Leaders: Contraction Timer and Counter 9m (4.8 stars, 69K), Full Term (4.7 stars, 7.2K, last updated 2019), Freya (£/$5.99, 4.5 stars, hypnobirthing, Apple Watch). Nearly all give a US-style 5-1-1 alert; none implement the NHS wording ("every 5 minutes or more often"; call urgently if 6+ in 10 min or any contraction over 2 min). A new 2025 wave (Labora, Bump Pulse, Bornly, contractiontimer.io) adds Apple Watch, Lock Screen widgets, Live Activities and partner live-links, but still positions the mother as the device owner.
- **Nobody combines the things a birth partner actually needs in the room.** No product found pairs timer + decision advice + one-screen birth plan + jargon lookup + "what to say now" prompts + triage call script + hospital bag/live checklist + post-birth broadcast. No app models "dad is the device holder". Apple Watch haptic coaching for the partner is unexploited.
- **Technical reality:** a watchOS companion that times contractions is feasible (HKWorkoutSession or extended runtime session for background runtime/haptics; Live Activities mirror to the watch Smart Stack but cannot be started from the watch), but **it must be written in Swift/SwiftUI**. React Native/Expo and Flutter cannot run on watchOS, only ship a native target alongside.
- **Risk posture:** a "go to hospital now" instruction is where App Store 1.4.1 and MHRA "intended purpose" become live. Mitigation is to present NHS/NICE rules verbatim, frame outputs as "it's time to *call* your maternity unit", require the midwife's instruction to override, and never claim diagnostic accuracy.

---

## 2. Dad-focused apps

### 2.1 Comparison table

| App | Platform / status | Price | Core features | Tone | Rating (count) | Characters / gamification | Labour-mode depth |
|---|---|---|---|---|---|---|---|
| **Daddy Up** (Sycamore Spur) | iOS, Android; active (v2.28, Aug 2026) | Free + Daddy Up+ $5.99 (ads off, partner sync, journal share) | Weekly updates, baby-size comparisons, journal, trimester checklists, "field guide" articles (finances, loss), contraction timer w/ intensity, twins, monthly "Lady Clues" | Humorous, outdoorsy lumberjack theme; "dad humor and wisdom" | 4.9 (about 3K iOS); 4.9 about 247K installs Android (3rd-party) | Theme + persona, no XP/quests | Timer only; no go-advice, no Watch, no birth plan |
| **Who's Your Daddy** | iOS; launched 2014 (Product Hunt, 76 upvotes); US/UK store pages now 404 | about $2.99 (historic) | 290 daily tips, 42 weekly updates, contraction counter, hospital bag checklist, to-do, names, due-date widget | Laddish jokes ("Day 28: Mood Swings") | n/a (not available) | None | Counter only |
| **DadPad** (Inspire Cornwall CIC; NHS-commissioned, postcode-localised) | iOS, Android; original listing last updated Sep 2022; new "TheDadPad" + "DadPad Neonatal" (2025) listings | Free (NHS-funded) | Feeding, safer sleep, nappies, bathing, crying, mental health (self and partner), home safety, first aid, local signposting | Clinical, structured, "babies don't come with instructions" | 3.0 (18 reviews, old listing); new listings unrated | None | None (post-birth focused) |
| **Dad Matters** (Home-Start) | Service, not an app | n/a | Perinatal peer support | n/a | n/a | n/a | n/a |
| **Pregnant Dad** (SB Apps) | iOS; last updated Mar 2022 | $1.99 | Due-date calc, weekly slider, daily notifications, contraction counter, zodiac | Upbeat, "little bugger", typos | 3.4 (35) | None | Counter |
| **Dad's Guide** (Strive Developers, UK) | iPhone; v1.0 Jun 2026 | Free + $2.99 / $9.99 lifetime | Week-by-week, labour guide (signs, stages, pain relief), contraction timer, hospital bag lists (mum/baby/dad), **birth plan notes**; "built on NHS guidance" | Calm, "No clutter. No overwhelm" | Unrated | None | Timer + plan notes; no Watch, no go-advice |
| **Big Daddy** (doctor-built) | iOS, Mac | Free + $2.99 full / $12.99 lifetime / $0.99 mo | Weekly updates, 40+ doctor-reviewed articles, contraction timer (premium), hospital bag and birth prep checklists (premium), "Bumpies" photos, widget | Casual "pre-Dadding" humour, no jargon, disclaimer | 4.7 (479) | None | Timer (paid) |
| **HiDaddy** (Idea Accelerator, pairs with HiMommy) | iOS, Android; very active | Sub $7.99/3mo or $11.99/yr (listing also shows $14.99/$39.99) | Daily messages "from the baby", partner mood explainers, birth prep, shared checklists with HiMommy | Two notification voices: polite or "humorous for dads who don't take themselves seriously" | 4.8 (1.8K) | Baby-as-narrator | Minimal |
| **Super Dad** | iOS | $2.99 | Daily tip, countdown, dad jokes, contraction timer, checklists | Light humour | 3.0 (2) | None | Timer |
| **DADit** (DADit Inc, 2026) | iOS | Free w/ ads; Pro $9.99/mo, $79.99/yr, Lifetime $179 | "Expectant Father Toolkit": contraction timer, kick counter, hospital bag, **birth plan builder**, appointment tracker; AI "Ask DADit"; Dad Prep Course including "advocating in the delivery room"; shared logging | Tactical ("command center"), no humour | 4.0 (4) | None | Broadest dad labour toolkit, but unproven and expensive |
| **Dad Natal** (Dad AF) | iOS/Android | £4.99/mo or £39.99/yr | Community, courses (sleep, mental health), access to therapists | Peer, serious | Not found | None | Course content |
| **Father's Playbook** (UT Austin) | Android first, free | Checklists (finances, infant CPR, signs of labour), research-led, "earth tones and terminology men relate to" | Practical | n/a | None | Checklist |
| **ProDaddy** | iPhone | n/a | 3-minute reads, gear, finance | Modern | n/a | None | None |
| **Dad Basics** | iOS (listing now 404) | One-time unlock | Course with **XP and levels** | Gamified | few | XP/levels | None |
| **Expecting.app** | iOS | n/a | Partner sync, dads-only section from week 9 | Neutral | n/a | None | None |
| **Baby Buddy** (Best Beginnings; RCM/RCOG-endorsed) | iOS/Android, free | Daily content for "dads and non-birthing co-parents", 300+ videos, birth planning, maternity unit finder, child health record | NHS-style plain English ("no jargon") | 4.5 (22, 2021 listing) | None | Planning content, no timer |
| DaddyNatal (Dean Beaumont), Fatherly, The Dad Lab, Dad Jokes | No apps found | n/a | Classes / media / books | n/a | n/a | n/a | n/a |

### 2.2 What reviews praise and complain about

- **Daddy Up**: praise: "comprehensive and funny", "weekly updates accurate and fun to read", male-focused relief from "tedious and female-focused" mum apps. Complaints: ads "can get annoying if you don't pay", "interface looks dated", theme "will not appeal to every father", "medical depth is limited"; a 2019 review explicitly defends the app against people "offended" by it, implying a tone backlash.
- **Who's Your Daddy**: Product Hunt comment: the joke "felt offensive to me as a man and soon-to-be father." Another hoped it would be "a babycenter for dads", unmet demand.
- **Pregnant Dad**: "the lite version and the paid version are hardly different", "articles so poorly written they can be hard to read", "information will stay the same for days on end".
- **Big Daddy**: asks for hyperemesis gravidarum coverage and partner sharing (both absent).
- **HiDaddy**: one 2024 reviewer called it "extremely anxiety inducing... made me feel worthless", a warning that daily "what you should be doing" nudges aimed at dads can tip into guilt.
- **DadPad**: low rating (3.0) despite NHS backing; content is postnatal basics and regional signposting; no interactivity.
- **Research signal**: the 2018 discourse analysis of app-store descriptions (Thomas, Lupton and Pedersen) found dad apps "talk down to expectant fathers and downplay their role", assuming men "need amusement and encouragement". A registered trial (NCT06168656) is now testing whether a mobile app reduces expectant fathers' fear of childbirth, i.e. there is clinical interest in exactly the labour-anxiety space.

### 2.3 Newer entrants 2024 to 2026
Dad's Guide (UK, NHS-sourced, iPhone-only), DADit (AI + toolkit, premium-priced), BumpTrackr (couple-sync with birth plan builder), DadPad Neonatal, HiDaddy's continuous updates. None has traction yet; none has Apple Watch; none is funny.

---

## 3. General pregnancy apps and their partner experience

| App | Scale | Partner experience | Labour tools | Verdict for dads |
|---|---|---|---|---|
| **Pregnancy+** (Philips Avent) | 80M+ lifetime downloads; premium tier | "Can be personalised for dads, grandparents and other family members", a role picker over the same content; no partner-specific tools found | Listing doesn't surface timer/birth plan/bag | Weak: cosmetic |
| **BabyCentre UK** (Everyday Health) | 4.9 (19K) | None listed; forums are "mums"; US version has a contraction timer and birth-plan checklist | Contraction timer (US), birth plan checklist | Weak |
| **What to Expect** | 4.9 (381K); Apple Watch listed but no watch features | Reviewer asks for "I am the father / non-carrying partner" option; "very skewed towards the mother". 2024 security reporting (404 Media) of an unfixed account-takeover flaw | Not in listing | Weak, plus privacy concerns |
| **Ovia** | Employer-benefit distribution | Partner can connect an account and log too | n/a | Moderate (account link only) |
| **Flo** | Huge | "Flo for Partners": pairing code, partner tab, educational stories/quizzes; cycle-focused, 18+ | n/a | Best-designed partner mode but fertility/cycle oriented |
| **Glow Nurture** | n/a | Partner tools mostly fertility-side | Contraction timer, Apple Health sync | Weak |
| **The Bump** | 4.8 (37 to 39K) | None found | Contraction counter "to determine when it's time to enact your birth plan" | Weak |
| **Bounty** (UK) | 4.7 (9) | "Dads can use it" but no partner features; local hospital leaflets | Checklists | Weak |
| **Emma's Diary** (UK) | Freebies-led | Baby-name swipe to share with partner | n/a | Weak |
| **NHS Start for Life** | Website only (no app); 2023 refresh added "Labour and Birth" section | Addressed to parents generally | n/a | Reference, not a tool |
| **Peanut** | "5M mums" | Women-only by design (selfie verification) | n/a | Excluded |

Takeaway: partner "modes" are role toggles or read-only mirrors. Flo is the only mainstream app that built a distinct partner curriculum, and it's for cycles, not labour.

---

## 4. Contraction timers and labour companions

### 4.1 Feature matrix

| App | Price | Rating | Watch | "Go now" advice and rule | Offline | Partner times on own device | Live share to family | Stores birth plan | Notes |
|---|---|---|---|---|---|---|---|---|---|
| **Freya** (Positive Birth Co.) | $5.99/£ paid | iOS 4.5 (173); Play 4.7 (470), about 50 to 67K installs | **Yes**, companion (surge button, log, audio controls) | Notification "labour is established... call your midwife"; threshold undisclosed | Not stated | No | Share log (export) | No | Breathing counts 4-8/3-6, 4 coach voices; complaints: "bare-bones", editing surges, sound "all-or-nothing"; last update Jul 2025 |
| **Full Term** | Free; $0.99 ads off | 4.7 (7.2K) | Yes (watchOS 4) | 5-1-1 alert, customisable | Yes (local, survives restarts) | No | Email history | No | Last updated **2019**; praised dark mode; "edit button... not obvious mid-labor" |
| **Contraction Timer and Counter 9m** | Free; $2.99 to 5.99 | 4.8 (69K) | No | "Notifies when it's time to go to the hospital"; shows labour stage | Not stated | No | PDF report (premium) | No | Lock-screen widget premium; 3rd-party review: "often inaccurate alerts", "bright screen"; user "forgot to press stop a FEW times" |
| **Storky** (TappyTaps) | Free, no ads | n/a | No | Alerts when "indications suggest baby might be on its way" | n/a | No | Email overview | No | Simple |
| **Contraction Timer and Tracker** (contractiontimer.io) | Free; $5.99 one-time or $1.99/wk; ($9.99 lifetime on web) | 4.8 (89) | Yes (Pro) | 5-1-1 alert (free); notes some providers use 4-1-1/3-1-1 | Yes, no account | **Yes, partner can start/stop remotely (Pro)** | **Yes, private live link** | No | Phases; relaxation audio; hospital-bag reminder; Lock Screen widget; web timer |
| **Contraction Timer: Time labor** (Going Merry) | $1.99/wk or $19.99/yr | 4.6 to 4.9 (small) | Yes companion | n/a | n/a | No | n/a | No | Complaint: "only with the phone unlocked" |
| **Labora** (Aug 2025) | Free + tips | 5.0 (101) | Yes (watchOS 11) | "Smart notifications when contractions are regular"; phase predictions "very inaccurate" | Yes, no account | No | No | No | Lock Screen widget in flashlight slot praised; Siri |
| **Bump Pulse** (Developer On Wheels) | Free; $5.99 birth cert | 4.7 (79) | Yes (watchOS 11) | 3-1-1 pattern option | Yes | Partner joins by code, but **records are per-device and don't merge** | Partial (while app open) | No | Live Activity, Siri, widgets, PDF export, hospital bag checklist |
| **Bornly Contraction Timer** | Free | 5.0 (5) | No | 5-1-1 (1 min / 5 min default, 15-min snooze); **one-tap call and navigate to saved hospital** | n/a | No | **Partner gets push when criteria met + live stats** | No | Guided breathing with haptics; Live Activities; strong accessibility |
| **BumpTrackr** (2026) | Free | Unrated | No | 5-1-1 guidance, Braxton Hicks explainer | iCloud | Partner invite (sync) | n/a | **Yes, builder, shareable** | Couple-oriented tracker |
| **Contraction Timer Watch** (E. Korkmaz) | $3.99 | Unrated | **Standalone watchOS 11.6**, haptic confirm | None | Local | No | No | No | Watch-only |
| **Bloom** (Pigeon Labs) | $2.99 | Unrated | Watch-first + iPhone companion (v2.1) | 5-1-1 guide (per aggregator) | Local | No | No | No | Always-on display |
| **GentleBirth** | Free + $0.99 | 4.7 (91) | No | "GentleBirth Indicator" tells you when to go/contact provider | n/a | No | Email | No | Hypnobirthing audio; "does not provide medical advice" |
| **Easy Contraction Timer** (Android) | Free, ads off | n/a | **Wear OS** timing | 5-minute alert | n/a | No | Real-time shared link | No | Only maintained Wear OS option found |
| Ian Lake Contraction Timer (Android Wear) | Free | n/a | Android Wear | n/a | n/a | n/a | n/a | n/a | Last updated 2019 |
| **Garmin Pregnancy Tracking** | Free with watch | n/a | Garmin watch Contraction Timer app | None | Yes | No | No | No | Since Nov 2020; logs symptoms, movement |
| **WHOOP Pregnancy Insights** | Membership | n/a | WHOOP band | None, HRV/RHR trends only | n/a | n/a | n/a | n/a | Criticised in 2022 for "screening for premature birth" framing |
| Fitbit | n/a | n/a | None found | n/a | n/a | n/a | n/a | n/a | n/a |

### 4.2 Observations
1. **Every "go to hospital" rule is US-flavoured (5-1-1/4-1-1/3-1-1).** None quotes NHS guidance: call when contractions are "coming every 5 minutes or more often"; call **urgently** if waters break, bleeding, reduced movements, under 37 weeks, any contraction lasting over 2 minutes, or 6+ contractions in 10 minutes; 999 if urge to push. Freya is the only UK-origin product and it hides its threshold.
2. **Accuracy complaints cluster on the advice layer**, not the stopwatch: "often inaccurate alerts" (9m), phase predictions "very inaccurate" (Labora). Users forget to press stop; apps that can't edit entries get punished.
3. **Partner features exist but are bolt-ons**: live links (contractiontimer.io, Bornly, Easy Contraction Timer), partner remote start/stop (contractiontimer.io Pro only), partner push alert on 5-1-1 (Bornly). Bump Pulse's "each phone has its own record" shows the engineering gap of true shared-state timing.
4. **Apple Watch is table stakes in the 2025 wave** (Freya, Full Term, Labora, Bump Pulse, contractiontimer.io, Bloom, Contraction Timer Watch) but is always "mum taps her wrist". Nobody designs the watch for the *partner's* wrist (haptic cue to start breathing with her, haptic when the interval threshold is hit, discreet glance without lighting the room).
5. **Room ergonomics are a recurring praise/complaint axis**: dark mode (Full Term praised), bright screen (9m complaint), big button (Bump Pulse praised), lock-screen widget in the flashlight slot (Labora praised), "edit not obvious mid-labor" (Full Term).
6. **Paywall-in-labour is a trust killer**: a 2026 side-by-side review called the "paywall first" feeling "the last thing you want in labor"; weekly subscriptions ($1.99 to 4.99/wk) are common and resented.
7. **Hypnobirthing is the only differentiated content layer** (Freya, GentleBirth): breathing counts, coach voices. There is no "partner coaching" layer anywhere.

---

## 5. Birth plan tools

- **NHS**: "How to make a birth plan" page with a checklist (place of birth, companions including during forceps/ventouse/caesarean, pool, positions, skin-to-skin, trainees, pain relief, feeding, vitamin K) and a **65 KB Word template**. Guidance: talk it through with your midwife; plans may change at the last minute. The birth partner's *responsibilities* are not described.
- **NCT**: "Dad's view: birth plan and pain relief" frames the plan as the place where partners "write down what they want their role in labour to be" so the midwife "can help them fill that role". No NCT app or digital template found.
- **NHS trust tools**: NHS Lothian "Personal Care Plan" (midwife-issued); Coventry and Warwickshire birth-partner page lists practical, emotional and advocacy duties ("speak up or ask questions with professionals", manage visitors).
- **Digital**: *My Birth Plan UK* (free, tip-funded, NHS-focused web builder); printable templates (Twinkl two-pager, DocHub, Pabau); US forms (Niagara Health names the birth partner and their role).
- **In apps**: Dad's Guide (free-text "birth plan notes"), BumpTrackr (structured builder shareable with partner/doula/care team), DADit (builder), BabyCenter US (checklist), Baby Buddy ("plan the sort of birth you want").
- **Gap**: nothing produces a **one-screen, midwife-facing summary** the partner can hold up (e.g., "Pain relief: wants to try gas and air first, no pethidine; delayed cord clamping; skin-to-skin; partner to announce sex"), nor a **"what's changed" mode** when the plan is overtaken by events (induction, theatre). No tool prepares the partner to *present* the plan or to translate it into the triage call.

---

## 6. Glossary / jargon products

- **NHS**: Mid Kent (Maidstone and Tunbridge Wells) publishes a maternity glossary (MW/RM, CTG, PET...); Hywel Dda (NHS Wales) has a *staff* abbreviation guideline (ARM, APH...); NHS Greater Glasgow and Clyde publishes "Recommended language for use in maternity services", evidence that the NHS itself recognises the jargon problem.
- **Media**: Mother and Baby's "What does that mean? Your antenatal note jargon explained" decodes FHH/FHNH, FMF/FMNF, LOA/ROA, "32+6"; notes-focused, not labour-ward-focused.
- **Charities**: Tommy's hosts a pregnancy glossary (page blocked to the crawler, so content unverified); Nutricia (AU) has a general glossary (engagement, APGAR).
- **Books**: *A-Z Midwifery* (Elsevier), *Bailliere's Midwives' Dictionary*: professional, not parent-facing.
- **Apps**: **none** of the 30+ apps reviewed offers a searchable "what the midwife just said" lookup. Big Daddy and Baby Buddy advertise "no jargon" as a *content* virtue, not a *tool*.
- **Gap**: a fast, offline, labour-ward-specific glossary (VE, "4 cm", SROM/ARM, syntocinon, CTG, "decels", meconium, OP/"back-to-back", transition, "fully", instrumental, theatre, cat-1 section, Apgar, "obs"), ideally with *"what to ask next"* and *"is this normal?"* framing for the partner. The "what midwives say vs what they mean" angle is unoccupied.

---

## 7. Humour, character and story-driven products: what tone works

### 7.1 Books (reception)
| Title | Reception | Lesson |
|---|---|---|
| *The Expectant Dad's Survival Guide* (Rob Kemp) | Goodreads 3.61 (792). "Technical knowledge delivered with a cheeky wit" **vs** "Patronising. Far too laddish", "very laddish, off-putting way" | Cheeky is fine; laddish is punished |
| *Pregnancy for Men* (Mark Woods) | Marketed as "factual and funny... utterly honest"; a go-to UK guide | Honesty + facts carries the humour |
| *Man vs Baby* (Matt Coyne) | Viral origin; NYT-reviewed; "very funny" but "makes fun of the classic bumbling, confused father stereotype" | Strongest humour brand, but the bumbling-dad trope is a known irritant |
| *Commando Dad* (Neil Sinclair) | "Unexpected charm and humor to the military theme"; "nothing revelatory", sequel "too heavy on fun terminology" | Metaphor/theme works as structure; wears thin if content is common sense |
| *We're Pregnant!* (Adrian Kulp) | 3.98 (2,868); valued for practicality, "helped me destress" | Reassurance beats jokes |
| *Dude, You're Gonna Be a Dad* | Could not retrieve verified reviews (Goodreads fetch returned a different title) | n/a |
| *The Unmumsy Mum*, Father of Daughters | Not researched in depth (mum-facing / influencer content) | n/a |

### 7.2 Apps with characters or game mechanics
- **Daddy Up**: the only themed dad app (expedition/lumberjack persona, "cubs"); theme is both its hook and its most-cited turn-off.
- **HiDaddy**: baby-as-narrator daily messages; optional humorous voice; risk of guilt-tripping (see "anxiety inducing" review).
- **Dad Basics**: XP and levels on a course (now delisted). **Mr. Dad on Pregnancy**: trivia vs partner (delisted). **Milk Man** (Telethon Kids, 2019 JMIR): gamified breastfeeding support for fathers; academic evidence that gamification for dads has been tried and studied.
- **Models outside parenting**: **Finch** (4.9, 1M+ Play): pet-nurture mechanic, Editors' Choice; critics note it "leverages our nurturing instincts" and question intrinsic motivation. **Habitica**: quest/party structure. Neither has a parenting analogue in the market.
- **Dad-content comedy** (Dad Jokes apps, Fatherly, The Dad Lab): media brands, no companion apps for the pregnancy/labour journey.

### 7.3 Synthesis: tone rules for men in this space (from reviews and research)
1. **Punch up or at yourself, never at her.** Every backlash example (Who's Your Daddy "hot girl", Kemp "laddish") involved jokes at the partner's or women's expense.
2. **Dad as competent learner, not bumbling idiot.** Coyne works despite the trope; the 2018 study and Product Hunt comments show men are tired of being assumed incapable.
3. **Jokes must sit on top of real information.** "Comprehensive *and* funny" is the Daddy Up compliment; "fun terminology... plain common sense" is the Commando Dad complaint.
4. **Give the user a tone dial.** HiDaddy's "polite vs humorous" switch is the right instinct; mandatory humour in a 3 a.m. labour moment is wrong. The labour mode should be serious, big-button, calm, with humour only in debriefs/rewards.
5. **Avoid guilt mechanics.** Daily "you should..." nudges produced "made me feel worthless". Streaks should be celebratory, never punitive.
6. **Theme is a differentiator but should be optional/skinnable**; UK dads may not want US lumberjack.

---

## 8. Gaps and opportunities

### 8.1 Unoccupied product space (specifically for the male partner during labour)
1. **"Dad is the device holder" model.** Every timer assumes the labouring woman taps. A partner-first timer (big thumb target, one-handed, watch haptic start/stop, voice "contraction" via Siri/Shortcuts) with her phone as optional mirror is unbuilt. Bump Pulse's per-device records problem shows the need for proper shared state.
2. **Timer + decision advice in NHS language.** Implement the NHS wording and red flags verbatim (5-min frequency, over 2-min contractions, 6-in-10, waters, bleeding, reduced movements, under 37w, urge to push means 999), with "it's time to call" rather than "go now", configurable to the unit's own advice and to parity (second babies go earlier). No competitor does this.
3. **Triage call script.** Trusts ask for hospital/unit number, intended hospital, reason, risk factors, blood group (if Rh-neg), medications; outcomes are come-in / stay-home plan. A pre-filled, read-aloud card (with the last hour's timings on screen) is a clear, cheap win. Nothing exists.
4. **One-screen birth plan for the midwife** + "what to ask when the plan changes" prompts (induction, epidural, theatre). Only BumpTrackr/DADit have builders; none have the presentation layer.
5. **Jargon lookup in the room**: search-first, offline, labour-ward terms with "what to ask next". Unoccupied.
6. **"What to say / do right now" partner coaching cards** by stage (latent, established, transition, pushing, theatre, golden hour). Hypnobirthing apps coach *her*; nobody coaches *him*. Freya/GentleBirth prove breathing audio sells; a partner-sync "breathe with her" haptic on his watch is novel.
7. **Hospital bag as a *live* checklist** (what's where, what's still in the car, charger, snacks, coins/parking app) and **post-birth comms broadcast** (one-tap "She's here, both well, no visitors till Thursday" to a pre-approved list). Only fragments exist (birth announcement cards in Freya/9m).
8. **Hospital-specific info** (triage number, parking, entrance after hours, unit visiting rules). Bounty links hospital leaflets; DadPad localises content by postcode; nobody puts it on the labour screen.
9. **Serious + funny in one product.** The market is bifurcated: funny-but-shallow (Daddy Up, Who's Your Daddy) vs clinical-and-dull (DadPad, Dad's Guide, DADit). A character-led, quest-structured journey that *switches to a sober labour mode* has no direct competitor.
10. **Apple Watch for the partner**: complication showing time since last contraction and count in last hour; haptic at threshold; Smart Stack Live Activity mirrored from iPhone. Existing watch apps are mum-wrist stopwatches.

### 8.2 Risks
- **Medical-advice liability / App Store 1.4.1**: "Medical apps that could provide inaccurate data... may be reviewed with greater scrutiny... apps must clearly disclose data and methodology... Apps should remind users to check with a doctor... before making medical decisions." 1.1.6: "for entertainment purposes" disclaimers do not cure. Reviewers are reported to ask for **source links** for medical content; wellness disclaimers alone did not stop one app being classed as medical. Mitigation: quote NHS/NICE sources in-app, label outputs as "guidance from the NHS, not a diagnosis", never compute dilation/phase "predictions" (Labora's inaccuracy complaints), keep thresholds user/midwife-editable.
- **MHRA (UK)**: software is a medical device based on *intended purpose*; symptom checkers start at Class I and rise to IIa when enabling diagnosis; lifestyle/wellbeing apps without medical claims sit outside. A timer that *displays NHS rules* is wellbeing; one that *decides* "you are in established labour" edges toward decision support. Keep claims to "helps you follow NHS advice on when to call".
- **5.1.3 / HealthKit**: no advertising/data-mining on health data; must disclose data collected; "may not store personal health information in iCloud", relevant if syncing contraction logs via CloudKit (BumpTrackr uses iCloud; design sync carefully or keep logs non-identifying). Privacy is a live reputational issue (What to Expect account-takeover flaw; Glow exposure; Pregnancy+ cloud transfer).
- **UK vs US guidance**: 5-1-1 vs NHS wording; NZ "60 s every 5 min"; US advice often "go sooner". Ship region packs; default to the user's country; let the midwife's instruction override.
- **Accessibility in a dark delivery room**: true-black dark mode, haptic confirmation, 44pt or larger thumb targets, one-handed reach, no modal paywalls, undo for mis-taps (top complaint), lock-screen/watch start without unlocking (Going Merry complaint), VoiceOver (Bornly sets the bar).
- **Battery and runtime**: labours run 8 to 24 h+; keep timing timestamp-based, persist on every tap, survive app kill (Full Term's "saves even if device restarts" is praised); watch sessions have hard limits (below).
- **Tone risk**: humour that lands wrong in a crisis; fix with a hard "labour mode" that mutes jokes and a user tone dial.
- **Monetisation risk**: weekly subs and mid-labour paywalls are explicitly hated; one-time unlock before 37 weeks or free labour mode is safer.

---

## 9. Technical notes: Apple Watch (and Wear OS)

**Independent vs companion.** watchOS apps can be standalone (Contraction Timer Watch runs with no iPhone) or companions. A standalone watch app *can* provide complications (Apple forum confirms, via WidgetKit). Expo Apple Targets only generates *companion* watch targets.

**Background runtime (the core constraint for a multi-hour timer).**
- Normal watch apps suspend when the wrist drops. Options: **HKWorkoutSession** (runs until ended; the *only* case allowing background haptics per `WKInterfaceDevice.play` docs; also unlocks live heart-rate via HKLiveWorkoutBuilder) or **WKExtendedRuntimeSession**. Apple's table: Self care: frontmost, 10 min; Mindfulness: frontmost, 1 hour; Physical therapy: background, 1 hour; Smart alarm: background, 30 min, schedulable. Apple requires choosing by *intended use*, one type per app, started while active, and may cancel on sustained CPU. A contraction timer doesn't map cleanly to any type; most shipping timers avoid the problem by storing tap timestamps and using **local notifications** (which deliver haptics without runtime) rather than a running session.
- Background App Refresh gives only seconds; `WKWatchConnectivityRefreshBackgroundTask` wakes the watch for incoming data.

**Haptics.** `WKInterfaceDevice.play(_:)` is foreground-only except during an active workout session; `notifyUser(hapticType:)` is for smart-alarm sessions. Threshold alerts ("5-1-1 reached") should therefore be **scheduled local notifications** (system haptic + wake) rather than in-app haptics.

**Complications and Smart Stack.** WidgetKit complications (watchOS 9+) can show "last contraction 4 min ago / 6 in last hour" with timeline refresh budgets. **Live Activities (ActivityKit, iOS 16.1+) appear automatically in the watch Smart Stack** (watchOS 10/11+) and on the iPhone Lock Screen/Dynamic Island, but **"Live Activities cannot be initiated from the watch"; ActivityKit is not available to watchOS apps.** Updates come from the iPhone app or ActivityKit push. (Apple also caps a Live Activity's active lifetime, commonly cited as 8 hours, so a long labour needs re-starting; verify against current docs.)

**HealthKit heart rate.** Available on the wearer's watch (live only inside a workout session); useful only if *she* wears the watch; irrelevant for a partner-held device, and a 1.4.1/MHRA risk if presented as monitoring.

**WatchConnectivity sync.** `sendMessage` needs `isReachable` (both apps live); `transferUserInfo`/`updateApplicationContext` queue in the background and deliver in order; the right path for tap timestamps so either device can own the timer. Expo's guide notes RN-side `sendMessage` only works when the RN app is running; App Groups + `UserDefaults(suiteName:)` share persistent state.

**Cross-platform reality.** React Native/Expo: "React Native doesn't support watchOS... watch code can't be written in JS/TS"; Expo Apple Targets scaffolds a **SwiftUI** watch target (`npx create-target watch`, `watch-widget` for complications) that is companion-only. Flutter: engine cannot run on watchOS; community workarounds send a UI schema to a SwiftUI renderer. Capacitor has a similar SwiftUI-only watch plugin. **Conclusion: a watch app means native Swift/SwiftUI regardless of the phone stack; a Swift-native iOS app avoids the bridge entirely.**

**Android / Wear OS.** Timers are an explicitly supported use of the **Ongoing Activity API** (ongoing notification + foreground service; `CATEGORY_STOPWATCH`/`ALARM`; watch-face icon and Recents status with `Status.StopwatchPart`; required by Wear quality guideline WO-V4). Heart rate via **Health Services** (`MeasureClient`/`PassiveMonitoringClient`, `BODY_SENSORS(_BACKGROUND)` to `READ_HEART_RATE` on API 36). Flutter *can* target Wear OS (it's Android) but with layout caveats. Competitor coverage is near-zero (Easy Contraction Timer is the only maintained Wear OS timer), so Wear OS is a secondary but open lane. Garmin ships its own Contraction Timer inside Pregnancy Tracking (Connect IQ integration not necessary to compete).

---

## 10. Recommended positioning (one paragraph)
Own the unoccupied square: **the birth partner's device**. Funny, character-led, quest-structured prep for 30 weeks (where every rival is either laddish or clinical), then a deliberately sober **Labour Mode**: giant one-thumb timer with watch haptics and Smart Stack mirror, NHS-worded "time to call" logic with red flags and 999 rules, pre-filled triage script, one-screen birth plan, searchable jargon, stage-based "say/do this now" cards, live hospital bag, and a one-tap post-birth broadcast; free during labour, one-time unlock before, Swift-native with a SwiftUI watch target, and every medical line sourced to NHS/NICE with a midwife-override.

---

## Sources

**Dad apps**
- https://apps.apple.com/us/app/dad-pregnancy-guide-daddy-up/id1097347717
- https://appshunter.io/ios/app/1097347717
- https://grand-screen.com/apps/dad-pregnancy-guide-daddy-up/
- https://androidworld.nl/apps/app-van-de-week-daddy-up-helpt-vaders-op-weg/
- https://www.producthunt.com/products/who-s-your-daddy
- https://laughingsquid.com/whos-your-daddy-an-app-for-first-time-fathers-that-offers-advice-and-tips-during-their-partners-pregnancy/
- https://apps.appfollow.io/ios/dadpad/1299225900?country=gb
- https://apps.apple.com/gb/app/the-dadpad-neonatal-app/id6505065718
- https://news.croydon.gov.uk/croydon-dads-get-free-nhs-backed-app-and-new-video-series-on-world-sleep-day/
- https://www.hey.nhs.uk/news/2022/06/06/dadpad-app-launched-to-support-new-and-dads-to-be/
- https://www.gloshospitals.nhs.uk/about-us/news-media/press-releases-statements/dads-gloucestershire-can-now-prepare-parenthood-new-free-app-called-dadpad/
- https://www.mindwell-leeds.org.uk/services-directory/dad-matters/
- https://apps.apple.com/us/app/pregnant-dad/id381272043
- https://apps.apple.com/app/id6780309872 (Dad's Guide)
- https://apps.apple.com/app/id1447942380 (Big Daddy)
- https://apps.apple.com/us/app/-/id1328264789 (HiDaddy)
- https://apps.apple.com/us/app/superdad/id1483933253
- https://apps.apple.com/us/app/dadit/id6759115776
- https://apps.apple.com/app/id6758869835 (BumpTrackr)
- https://apps.appfollow.io/ios/expecting/1462394627?country=us
- https://healthcomm.utexas.edu/our-work/fathers-playbook
- https://www.fatherhood.org/fatherhood/freakin-awesome-free-app-for-expectant-dads
- https://alternativeto.net/software/prodaddy
- https://alternativeto.net/software/dad-basics-quick-baby-tips/about
- https://ie.silvercrossbaby.com/the-edit/parenting/giving-dads-a-voice (Dad Natal)
- https://marieclaire.co.uk/news/peterborough-offers-men-only-antenatal-classes-211661 (DaddyNatal)
- https://apps.appfollow.io/ios/baby-buddy-2-0/1548271681?country=gb
- https://healthforunder5s.co.uk/nottinghamshire/?p=1796 (Baby Buddy)
- https://adamosoft.com/blog/healthcare-software-development/pregnancy-app-for-dads/
- https://www.motherandbaby.com/pregnancy/health-and-wellness/pregnancy-app-for-dads (paywalled; search snippets only)
- https://orca.cardiff.ac.uk/id/eprint/98626 (Thomas, Lupton and Pedersen 2018, *J. Gender Studies*)
- https://clinicaltrials.gov/study/NCT06168656

**General pregnancy apps**
- https://apps.apple.com/gb/app/babycentre-pregnancy-tracker/id386022579
- https://apps.apple.com/us/app/pregnancy-baby-tracker-wte/id289560144
- https://www.404media.co/pregnancy-tracking-app-what-to-expect-refuses-to-fix-issue-that-allows-full-account-takeover-2/
- https://www.philips.com.ph/a-w/about/news/archive/standard/news/press/2019/20190516-pregnancy-plus-app-designed-to-support-a-healthy-full-term-pregnancy.cs
- https://nurserytoday.co.uk/2025/02/25/philips-pregnancy-app-teams-up-with-nuna-to-support-parents-everywhere/
- https://flo.health/product-tour/flo-for-partners
- https://help.flo.health/hc/en-us/articles/19871976024596-How-do-I-set-up-Flo-for-Partners
- https://theeverymom.com/ovia-fertility-pregnancy-app-review/
- https://apps.apple.com/jp/app/id882398397 (Glow Nurture)
- https://apps.apple.com/app/id568940747 (The Bump)
- https://apps.apple.com/us/app/-/id560102929 (Bounty)
- https://babygo.uk/blogs/news/best-free-pregnancy-apps-uk (Bounty/Emma's Diary)
- https://apps.apple.com/app/peanut-find-friends-support/id1178656034
- https://campaignresources.dhsc.gov.uk/campaigns/better-health-start-for-life/start-for-life-website-video-new-features

**Contraction timers / labour apps / wearables**
- https://apps.apple.com/app/id1447509164 (Freya)
- https://grand-screen.com/apps/freya-surge-timer-for-labour/reviews/
- https://www.appbrain.com/dev/The+Positive+Birth+Company/
- https://apps.apple.com/us/app/full-term-contraction-timer/id382013176
- https://apps.apple.com/us/app/877303791 (Contraction Timer and Counter 9m)
- https://apps.appfollow.io/ios/storky-contraction-timer/1367356707?country=br
- https://apps.apple.com/app/id1633196366 (Contraction Timer and Tracker)
- https://contractiontimer.io/
- https://apps.apple.com/us/app/contraction-timer-time-labor-contractions/id933501579
- https://apps.apple.com/us/app/-/id6749383000 (Labora)
- https://apps.apple.com/app/id6745621181 (Bump Pulse)
- https://apps.apple.com/app/id1626847362 (Bornly)
- https://apps.apple.com/us/app/contraction-timer-watch/id6759578917
- https://apps.apple.com/us/app/bloom-contraction-timer/id6782416595
- https://apps.apple.com/us/app/gentlebirth-contraction-timer/id1543780051
- https://apps.apple.com/us/app/labour-timer-contraction-app/id6449134360
- https://play.google.com/store/apps/details?id=com.cuberob.contractiontimer (Easy Contraction Timer)
- https://www.appbrain.com/app/contraction-timer/com.ianhanniballake.contractiontimer
- https://www.fatherly.com/gear/best-contraction-timers-and-how-to-use-them
- https://www.fatherly.com/gear/the-top-rated-contraction-timer-apps-for-ios-and-android
- https://conqueringmotherhood.com/best-contraction-timer-apps/
- https://medium.com/@social.devonwheels/the-5-best-contraction-timer-apps-for-labor-f0103cbbe09c (403; snippet only)
- https://connect.garmin.com/features/pregnancy-tracking/
- https://www.garmin.com/en-US/newsroom/?p=766
- https://www.whoop.com/thelocker/understanding-every-stage-of-pregnancy-with-new-pregnancy-coaching/
- https://www.bostonglobe.com/2022/12/09/business/whoop-draws-criticism-claiming-its-fitness-tracker-may-predict-premature-births

**NHS guidance, birth plans, triage, glossaries**
- https://www.nhs.uk/pregnancy/labour-and-birth/signs-of-labour/signs-that-labour-has-begun/
- https://www.nhs.uk/pregnancy/labour-and-birth/preparing-for-the-birth/how-to-make-a-birth-plan/
- https://nct.org.uk/pregnancy/dad's-view-birth-plan-and-pain-relief
- https://coch.nhs.uk/all-services/maternity-services/your-labour-birth/birth-partners.aspx
- https://services.nhslothian.scot/maternity/ (Personal Care Plan)
- https://ko-fi.com/N5D321IO1K (My Birth Plan UK)
- https://www.rightdecisions.scot.nhs.uk/maternity-gynaecology-guidelines/maternity/common-obstetric-problems-maternity-assessment/telephone-triage-maternity-sop
- https://www.uhcw.nhs.uk/download/clientfiles/files/Patient%20Information%20Leaflets/Women%20and%20Children_s/Maternity/Maternity%20triage%20services.pdf
- https://barnsleyhospital.nhs.uk/sites/default/files/2024-10/Admission%20to%20Maternity%20Triage.pdf
- https://www.motherandbaby.com/pregnancy/scans-tests/what-does-that-mean-your-antenatal-note-jargon-explained/
- https://www.mkuh.nhs.uk/?p=28368 (NHS glossary of terms)
- https://wisdom.nhs.wales/health-board-guidelines/hywel-dda-file/976-maternity-abbrevations-guideline/
- https://rightdecisions.scot.nhs.uk/maternity-gynaecology-guidelines/maternity/orientation-and-support-you-will-need/recommended-language-for-use-in-ggc-maternity-services
- https://www.tommys.org/pregnancy-information/im-pregnant/pregnancy-glossary (403 to crawler; existence only)

**Books, humour, gamification**
- https://www.goodreads.com/book/show/230045303 (Expectant Dad's Survival Guide)
- https://www.penguin.co.uk/books/406985/the-expectant-dads-survival-guide-by-rob-kemp/9781407030906
- https://uk.bookshop.org/a/10403/9781399720830 (Pregnancy for Men)
- https://www.dona.org/book-review-fathers-day-man-vs-baby-matt-coyne
- https://www.simonandschuster.com/books/Man-vs-Baby/Matt-Coyne/9781501187438
- https://www.chroniclebooks.com/commando-dad.html
- https://www.yorkshirepost.co.uk/news/commando-dad-knows-drill-under-threes-1898435
- https://u.osu.edu/infantsandme/book-reviews (We're Pregnant!)
- https://yourstory.com/2022/06/app-review-self-care-pet-finch-gamifies-mental-wellbeing
- https://foxdata.com/en/blogs/finch-as-app-store-editors-choice-a-self-care-companion/
- https://donate.telethonkids.org.au/our-research/reports-and-findings/2019/june-2019/gamifying-breastfeeding-for-fathers-process/ (Milk Man)

**Platform / regulatory / technical**
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/forums/thread/807508 (1.4.1 wellness flagged as medical)
- https://developer.apple.com/forums/thread/134169
- https://www.gov.uk/government/publications/medical-devices-software-applications-apps
- https://www.digitalhealth.net/2020/08/health-apps-developers-take-note-new-mhra-rules-are-here/
- https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions
- https://developer.apple.com/documentation/watchkit/background-execution
- https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)
- https://developer.apple.com/documentation/activitykit
- https://developer.apple.com/forums/thread/766130 (Live Activities cannot start from watch)
- https://developer.apple.com/forums/thread/774436 (complications from independent watch app)
- https://developer.apple.com/documentation/watchconnectivity/wcsession
- https://developer.apple.com/forums/thread/766559 (WatchConnectivity background)
- https://www.igeeksblog.com/how-to-use-live-activities-on-apple-watch/
- https://mintlify.wiki/EvanBacon/expo-apple-targets/guides/watch-apps
- https://github.com/ixacik/expo-watch-connectivity
- https://cdn.jsdelivr.net/npm/react-native-watch-connectivity@2.0.0/README.md
- https://pub.dev/packages/voo_watch_ui ; https://pub.dev/packages/flutter_watch_connectivity (Flutter cannot run on watchOS)
- https://capgo.app/docs/plugins/watch/getting-started/
- https://developer.android.com/training/wearables/ongoing-activity
- https://developer.android.com/health-and-fitness/health-services/permissions
- https://gurubase.io/g/flutter/can-flutter-be-used-for-wear-os-development
