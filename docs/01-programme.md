# 01 — The Keller Twelve v2: the training programme

The coaching document. Everything here becomes `data/keller-twelve.json` in Phase 1.
If you only ever read one file in this repo, read this one.

---

## 1. Athlete and constraints

| | |
|---|---|
| Age / sex | Under 25, male |
| Height / weight | 167 cm / 50 kg — BMI 17.9 |
| Experience | Complete beginner |
| Training partner | None. Trains alone, in a basement. |
| Days available | 5 evenings |
| **Session ceiling** | **60 minutes, door to door. Hard.** |
| Current running | 10–20 min continuous |
| Cooking | Cooks most days |
| Injuries | None reported |
| Goal | Gain muscle |

### The one sentence that drives every decision

**You are not limited by your training. You are limited by your bodyweight.**

At 167 cm and 50 kg you have more room to grow than almost anyone who will ever read a
programme, and the programme is the easy half. If the scale does not move, nothing else
here matters — not the split, not the progression rule, not the app. Two weeks of a flat
scale is a nutrition problem 100% of the time at your bodyweight, never a training one.

### The second sentence

**Sixty minutes is a real constraint and it changes the programme, not just the pacing.**

Loading a spinlock bar is slow. Every weight change means unscrewing two collars,
sliding plates on, and screwing them back — 45 to 90 seconds, every time. Assembling a
pair of dumbbells from scratch is two to three minutes. A six-exercise session across
four implements spends ten to twelve minutes on a spanner.

So v2 runs **five movements per lifting day**, with the last four arranged as two
supersets, and it minimises implement changes inside a session. That is not a
compromise — at your training age it is also the better programme. The volume you need
is lower than the volume v1 prescribed.

---

## 2. Design principles

1. **Frequency over volume.** A beginner gets more from squatting twice a week at 10
   total sets than once a week at 16. Every movement pattern gets two exposures.
2. **Every upper day presses and pulls.** No day is all push. Shoulder health is not an
   accessory.
3. **Nothing appears in week 5 that did not appear in week 1.** Every barbell lift is
   introduced with the empty bar in Foundation. There are no cold starts under load.
4. **Loads live on the lattice.** Every prescribed weight is one your plates can
   actually make. See §4.
5. **Progression is earned at the top of the rep range**, and when the plates are too
   coarse to add weight, the rep range grows instead. See §8.
6. **Cardio serves the heart, not the calorie burn.** Runs stay conversational. At 50 kg
   trying to gain, extra cardio is a cost, not a bonus.
7. **The targets published here are floors, not goals.** They are computed from the
   programme's own increments. The engine will beat them whenever you earn it.
8. **Everything is substitutable.** Every prescription carries substitutes, because at
   some point your knee will complain, the bench will be in use as a table, or you will
   have 35 minutes instead of 60.

---

## 3. Nutrition — corrected

v1's 2,700 kcal was computed without age or sex. With those known:

```
Mifflin-St Jeor, male, 22 y, 167 cm, 50 kg
BMR   = 10(50) + 6.25(167) − 5(22) + 5         = 1,440 kcal
TDEE  = BMR × 1.5  (4 lifting + 1 cardio day, otherwise desk/uni)
                                                ≈ 2,160 kcal
```

A lean novice can run a larger surplus than an experienced lifter and still partition
most of it into muscle. But appetite is the binding constraint at 50 kg, not appetite's
theoretical ceiling. So: start achievable, and **escalate** — because TDEE rises as you
gain, and a fixed target quietly becomes maintenance by week 10.

### Escalating targets

| Weeks | kcal | Protein | Fat | Carbs | Expected gain |
|---|---|---|---|---|---|
| 1–4 | **2,600** | 110 g | 70 g | 382 g | +0.3 kg/wk |
| 5–8 | **2,750** | 115 g | 72 g | 410 g | +0.3 kg/wk |
| 9–12 | **2,900** | 120 g | 75 g | 440 g | +0.3 kg/wk |

Arithmetic check, weeks 1–4: (110 × 4) + (382 × 4) + (70 × 9) = 440 + 1,528 + 630 =
**2,598 kcal**. It closes. v1's did not — it was 85 kcal short of its own headline.

**Protein:** 110 g is 2.2 g/kg at 50 kg and 2.0 g/kg at your 55 kg target. That is at
the top of what is useful; 100 g is the floor, anything above 120 g is wasted money.

**The adjustment rule** (the app enforces this): if your **7-day rolling average**
bodyweight has not risen for **two consecutive weeks**, add 250 kcal. Not the daily
number — the rolling average. Daily bodyweight swings 1 kg on water and gut content and
will make you chase noise.

**The waist rule** (the counterweight): if waist circumference is growing faster than
the lifts are, the surplus is too big. Measured at checkpoints. Expect the waist to grow
a little — you are gaining weight. More than 3 cm across twelve weeks means cut 200 kcal.

### Eating 2,600 kcal at 50 kg is the actual hard part

It is roughly 52 kcal per kg of bodyweight. That is a lot of chewing. Practical:

- **Two liquid meals a day solves the whole problem.** Milk, oats, peanut butter,
  banana, whey — 700 to 800 kcal in three minutes, and it does not fill you up the way
  the same calories as chicken and rice would.
- **Eat before training as well as after.** The pre-session meal is a free 500 kcal most
  beginners skip.
- **Do not open a meal with salad or soup.** Volume is the enemy right now.
- **Cook in batches on the two rest days.** Saturday is the easiest 3,000 kcal day of
  your week — no session, no time pressure.
- Add fat to things you already eat. Olive oil on rice is 120 kcal you will not notice.

> Targets and the two rules live in the JSON, so the app reads them rather than
> hardcoding. See doc 02, `nutritionPhases`.

---

## 4. Equipment and the loading lattice

### Inventory (placeholders — **replace with measured values in week 1**, doc 04)

| Item | Assumed | How to correct |
|---|---|---|
| Standard barbell | 9.0 kg | Bathroom scale, twice, average |
| EZ curl bar | 6.0 kg | Same |
| Dumbbell handle (×2) | 2.0 kg each | Same, with collars on |
| Kettlebell | 8.0 kg | Should be stamped |
| Fixed vinyl dumbbells | unknown pairs | Weigh each pair |
| Plates | 20×2, 10×4, 5×8, 2.5×8, 1.25×8 | Count them |
| **Microplates** | **you have some — size unknown** | **Weigh. This number matters more than any other.** |
| Wall cable | unknown stack/ratio | Note the max and the increment |

### The lattice — why this concept runs the whole app

A barbell can only be loaded in **pairs**. So the achievable weights are:

```
achievable = barWeight + 2 × (any sum of plates you can put on one side)
```

With a 9 kg bar and 1.25 kg as the smallest plate, the step is 2.5 kg and the set is:

```
9.0   11.5   14.0   16.5   19.0   21.5   24.0   26.5   29.0   31.5   34.0 …
```

**No round number is on it.** 20 kg, 25 kg, 27.5 kg, 45 kg — none of them exist in your
gym. This is why 19 of v1's 25 starting loads were unloadable, and it is why the app
must treat the lattice as the source of truth rather than the JSON.

It is also why one step is **12.5% of a 20 kg bench press**, which is far too big a jump
for a beginner and is what deadlocks v1's progression engine.

### Your microplates change everything

| Smallest plate | Lattice step | Jump on a 20 kg bench |
|---|---|---|
| 1.25 kg | 2.5 kg | 12.5% — unusable |
| **0.5 kg** | **1.0 kg** | **5.0% — good** |
| 0.25 kg | 0.5 kg | 2.5% — ideal |

`data/inventory.json` currently ships the **ideal** placeholder: pairs of 0.5 kg *and*
0.25 kg microplates, giving a **0.5 kg lattice step** on every implement. Every load in
`data/keller-twelve.json` is generated against it, so all 30 of them are loadable —
verified by gate V6 on every run of `tools/validate.py`.

The §7 projections move in 1.0 kg steps, which sit on that lattice with room to spare.
If your real microplates are a different size, regenerate and the loads shift; nothing
else changes.

> **If your microplates turn out to be 1 kg or larger, buy a pair of 0.5 kg and a pair
> of 0.25 kg standard-bore plates.** They cost about €20 and they are worth more to this
> programme than any other purchase you could make. A second pair of 1.25 kg is the
> next-best €10, so loading a barbell and a pair of dumbbells in the same session stops
> competing for the same plates.

### The plate-contention problem

You own one plate set. A session that loads the barbell *and* a pair of dumbbells needs
the same 5 kg plates in two places. Assembling a dumbbell pair consumes **four** plates
of each size (two sides, two handles).

v2 minimises this by ordering each day so the barbell work finishes before the dumbbell
work begins. The app warns when a day's prescriptions cannot all be loaded at once
(doc 02, algorithm B).

### Solo-lifter non-negotiables

1. **Catch pins before every squat and bench work set.** Set just below your bottom
   position. If you miss, you sit down and the bar lands on steel.
2. **Never take bench or squat to failure.** Two reps in reserve, always. There is no
   spotter and there will not be one.
3. **Check the spinlock collars mid-set.** They work loose under load and a plate
   sliding off one end is how people get hurt in home gyms. This is the single most
   likely injury in your room.
4. **Bar height on the deadlift.** Your plates are small-diameter, so a lightly loaded
   bar sits too low and forces your back to round at the start. Stack the two 20 kg
   tri-grips flat and rest the bar ends on them until your working weight is heavy
   enough to raise it naturally — around 50 kg with 20s on.
5. **Measure your ceiling clearance** before the first overhead press and before the
   first skipping session. The basement pipes are not at a uniform height.

---

## 5. Block structure

| Block | Weeks | Shape | Days | Session length | Goal |
|---|---|---|---|---|---|
| **Foundation** | 1–4 | Full body ×3 | 3 lift + 2 cardio | 30–39 min | Learn every pattern. Build the eating habit. Introduce every barbell lift with an empty bar. |
| **Build** | 5–7 | Upper/Lower ×4 | 4 lift + 1 cardio | 45–52 min | Two exposures per pattern. Loads climb weekly. RIR 2. |
| **Deload** | 8 | Same days | 4 lift + 1 cardio | 30–35 min | 70% load, 60% sets, supersets unwound. Checkpoint week. |
| **Push** | 9–11 | Same days | 4 lift + 1 cardio | 50–58 min | +1 set on the lead lift. RIR 1 on those sets. Nordics switch on. |
| **Test** | 12 | Own days | 4 test + 1 cardio | 13–26 min | 5-rep tests, max pull-ups, 5K time trial. Seeds cycle 2. |

Every one of those numbers is **computed** from the prescriptions, ramp sets and
implement changes — not estimated. Gate V11 fails the build if a lift day exceeds 60
minutes, including after the Push block adds its sets. The real sessions land well
under the ceiling, which is deliberate: the model cannot know the evening you cannot
find the 2.5 kg plates.

### Why Foundation is full-body and Build is not

Three full-body sessions gives a beginner **three exposures per pattern per week** —
the fastest possible motor learning, and the loads are light enough that recovery is
never the limit. That is correct for weeks 1–4.

By week 5 the loads are heavy enough that three squat sessions a week stops being free,
and the session would not fit in 60 minutes anyway. Upper/Lower at four days keeps
**two exposures** per pattern, which is the right dose for the next eight weeks.

v1 went from three exposures to one. That is the change that mattered most.

### Weekly rhythm

```
Foundation (weeks 1–4)              Build / Deload / Push / Test (weeks 5–12)
────────────────────────            ──────────────────────────────────────────
Mon   Full Body A   (squat-led)     Mon   Lower A · Squat
Tue   Cardio: skip + run + core     Tue   Upper A · Bench-led
Wed   Full Body B   (hinge-led)     Wed   Rest, or an optional easy run
Thu   Rest                          Thu   Lower B · Deadlift
Fri   Full Body C   (press-led)     Fri   Upper B · Press-led
Sat   Rest                          Sat   Rest
Sun   Cardio: long run + mobility   Sun   Cardio: run + skip intervals + core
```

Both give you 72 hours between same-pattern sessions and two genuine rest days.
Wednesday is deliberately optional from week 5 — take it if you slept well and ate
enough, skip it without guilt if you are sore or behind on food.

---

## 6. Session templates

> **`data/keller-twelve.json` is authoritative.** These tables are rendered from it.
> Loads are snapped to the plate lattice, and `estMinutes` is computed from the
> prescriptions, ramp sets and implement changes — never typed by hand.
> Regenerate with `python tools/gen.py && python tools/validate.py`.

`SS1` / `SS2` mark supersets: alternate the members and rest only after the pair.
Loads shown are **week-1 / week-5 starting values** with placeholder bar weights; the
app recomputes them from your measured inventory and your own logged history.

### Foundation · weeks 1–4

**Monday — Full Body A · 36 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Barbell back squat | 3 × 8 | 120 s | 9 kg |
| Barbell Romanian deadlift | 3 × 10 | 90 s | 15 kg |
| `SS1` Push-up on handles | 3 × 8–12 | — | bodyweight |
| `SS1` One-arm dumbbell row | 3 × 10 / side | 75 s | 7 kg |
| Plank | 3 × 30 s | 45 s | — |

Empty bar on the squat in week 1. The press is bodyweight so the one dumbbell stays
loaded through the whole superset — no spanner work between rounds.

**Tuesday — Skip, Run & Core · 39 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Rope skipping | 6 × 60 s | 60 s | — |
| Easy run | 1 × 15–18 min | — | — |
| `SS1` Dead bug | 3 × 10 / side | — | bodyweight |
| `SS1` Side plank | 3 × 20 s / side | — | — |
| `SS1` Hollow hold | 3 × 20 s | 45 s | — |

**Wednesday — Full Body B · 35 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Barbell deadlift | 3 × 5 | 150 s | 9 kg |
| Barbell overhead press | 3 × 8 | 105 s | 9 kg |
| `SS1` Ring row | 3 × 8–12 | — | bodyweight |
| `SS1` Goblet squat | 3 × 10 | 75 s | 8 kg |
| Dead bug | 3 × 10 / side | 30 s | bodyweight |

**This is the day v1 didn't have.** Deadlift and overhead press, both from the empty bar,
eight weeks before you would otherwise meet them under load. Read the bar-height warning
before your first pull.

**Friday — Full Body C · 30 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Barbell bench press | 3 × 8 | 120 s | 9 kg |
| Barbell bent-over row | 3 × 8 | 105 s | 9 kg |
| `SS1` Pull-up negative | 3 × 4 | — | bodyweight |
| `SS1` Bulgarian split squat | 3 × 8 / side | 75 s | bodyweight |
| Ab wheel from knees | 2 × 6 | 60 s | bodyweight |

**Sunday — Easy Run & Mobility · 35 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Easy run | 1 × 20–22 min | — | — |
| Rope skipping | 3 × 60 s | 60 s | — |
| Dead hang | 3 × 20 s | 45 s | — |

Plus ten minutes of mobility. Hanging decompresses everything the squats and rows
compressed all week.

**Foundation pattern coverage:** squat 2 · hinge 2 · horizontal push 2 ·
vertical push 1 · horizontal pull 3 · vertical pull 1 · core 3.
Every barbell lift that appears in Build is introduced here.

---

### Build · weeks 5–7 (Push, weeks 9–11, adds a set to movement 1 and drops to RIR 1)

**Monday — Lower A · Squat · 47 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Barbell back squat | 4 × 5 | 150 s | 21 kg · ramp |
| Barbell Romanian deadlift | 3 × 8 | 120 s | 27 kg |
| `SS1` Bulgarian split squat | 3 × 8 / side | — | 6 kg |
| `SS1` Single-leg calf raise | 3 × 15 / side | 75 s | bodyweight |
| `SS2` Hanging knee raise | 3 × 8–12 | — | bodyweight |
| `SS2` Pull-up negative | 3 × 3 | 60 s | bodyweight |

Both supersets pair a loaded movement with a bodyweight one, so nothing is re-plated
mid-round. The pull-up negatives cost almost nothing — you are already hanging on the
bar — and they are your second vertical-pull exposure of the week.

**Tuesday — Upper A · Bench-led · 48 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Barbell bench press | 4 × 6 | 150 s | 17 kg · ramp |
| Barbell bent-over row | 4 × 8 | 120 s | 19 kg |
| `SS1` Incline dumbbell press | 3 × 10 | — | 7 kg |
| `SS1` Cable face pull | 3 × 15 | 60 s | wall cable |
| `SS2` EZ-bar curl | 3 × 10 | — | 8 kg |
| `SS2` Lateral raise | 3 × 12–15 | 45 s | 2 kg |

**10 pressing sets, 10 pulling sets.** The row is a main lift here, not an afterthought —
v1's push day had sixteen pressing sets and no row at all. The cable work is what makes
the supersets free: no plates to move.

**Wednesday — Easy Run or Nothing · 27 min · optional**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Easy run | 1 × 20–25 min | — | — |

Genuinely optional. Skip it without guilt if you are sore or behind on food.

**Thursday — Lower B · Deadlift · 52 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Barbell deadlift | 3 × 5 | 180 s | 39 kg · ramp |
| Barbell front squat | 3 × 8 | 120 s | 16 kg |
| `SS1` Barbell hip thrust | 3 × 10 | — | 24 kg |
| `SS1` Single-leg calf raise | 3 × 20 / side | 60 s | bodyweight |
| Suitcase carry | 3 × 30 s / side | 60 s | 14 kg |
| Nordic curl negative *(week 9+)* | 3 × 5 | 90 s | bodyweight |

Three deadlift sets, not four — it is the highest-fatigue lift you own. The front squat
is the second squat exposure v1 lacked; swap it for a goblet squat if your wrists
complain. Nordics stay switched off until week 9, when the Push block turns them on.

**Friday — Upper B · Press-led · 45 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Barbell overhead press | 4 × 6 | 150 s | 13 kg · ramp |
| Band-assisted pull-up | 4 × 3–8 | 120 s | band |
| `SS1` Dumbbell bench press | 3 × 10 | — | 8 kg |
| `SS1` Ring row | 3 × 10–12 | 60 s | bodyweight |
| `SS2` Hammer curl | 3 × 12 | — | 5 kg |
| `SS2` Cable triceps pushdown | 3 × 12–15 | 45 s | wall cable |

**10 pressing sets, 10 pulling sets** again.

**Sunday — Run, Skip & Core · 54 min**

| Movement | Sets × reps | Rest | Load |
|---|---|---|---|
| Easy run | 1 × 24–26 min | — | — |
| Rope skipping | 8 × 30 s | 30 s | — |
| Heavy bag rounds | 3 × 2 min | 60 s | — |
| `SS1` Ab wheel from knees | 3 × 8 | — | bodyweight |
| `SS1` Hollow hold | 3 × 30 s | — | — |
| `SS1` Side plank | 3 × 30 s / side | 45 s | — |

The bag lives here, not on lifting days. v1 put nine-minute bag finishers on two lifting
days, which is a large part of where its 77-minute sessions came from.

**Build weekly pattern frequency:** squat 2 · hinge 2 · horizontal push 2 ·
vertical push 2 · horizontal pull 2 · vertical pull 2 · calves 2 · curl 2.
**Every pattern, twice.** That is the headline change from v1.

**Build weekly sets per primary muscle:** glutes 16 · lats 14 · triceps 14 · biceps 13 ·
abs 12 · quads 10 · chest 10 · upper back 10 · front delts 7 · hamstrings 6 · calves 14.
All inside the range a beginner responds to, at roughly two-thirds of v1's session time.

---

### Deload · week 8 · ~30–35 min

Resolved from Build by data, not special-case code:

```json
{ "loadMultiplier": 0.70, "setMultiplier": 0.60, "setRounding": "up",
  "includeSupersets": false, "includeFinishers": false, "defaultRir": 4 }
```

4 sets becomes 3, 3 becomes 2, loads drop to 70%, and supersets unwind into straight
sets so nothing is rushed. Bar speed stays fast — this is a *feel good* week, not a
do-nothing week.

Two lifts are already so light that 70% falls below the bare implement (the EZ-bar curl
and the lateral raise). The app clamps those to the empty bar and says so, rather than
pretending. Deload week also halves the cardio and is a checkpoint week: photos,
measurements, and an honest look at whether the surplus is working.

> **You will want to skip this week. Don't.** A beginner does not detrain in seven days,
> and this is the week the previous three turn into muscle.

---

### Test · week 12 · 13–26 min per session

| Day | Session | Target |
|---|---|---|
| Mon | Back squat, work up to a hard 5, then two light accessory sets | 36 kg |
| Tue | Bench press 5RM, then bent-over row 5RM, then one accessory superset | 26 / 31 kg |
| Thu | Deadlift, work up to a hard 5. **Then stop.** | 69 kg |
| Fri | Overhead press 5RM, then **max strict pull-ups**, then week-12 photos | 19 kg |
| Sun | **5K time trial** | 28–32 min |

"A hard 5" means the last rep grinds but the bar still moves and the technique holds.
**Not a failed rep. Not a maximal single.** You train alone; a missed 5RM is just a miss,
a missed single is an injury.

These five numbers seed cycle 2 (doc 02, algorithm E).

## 7. Load projections

**These are floors, not targets.** They are what the programme's own increments produce
if you earn every jump. The engine goes faster whenever you hit the top of the rep range
on every set — which, at these loads, will be most weeks.

Assumes a 9 kg bar and a 1.0 kg lattice (0.5 kg microplates). The app recomputes from
your measured inventory.

### Foundation — weeks 1–4, from the empty bar

| Lift | Scheme | w1 | w2 | w3 | w4 | → Build w5 |
|---|---|---|---|---|---|---|
| Back squat | 3 × 8 | 9 | 12 | 15 | 18 | 21 |
| Deadlift | 3 × 5 | 9 | 19 | 29 | 39 | 39 |
| Overhead press | 3 × 8 | 9 | 10 | 12 | 13 | 13 |
| Bench press | 3 × 8 | 9 | 11 | 13 | 15 | 17 |
| Bent-over row | 3 × 8 | 9 | 12 | 15 | 18 | 19 |
| Barbell RDL | 3 × 10 | 15 | 19 | 23 | 27 | 27 |

Note the handoff: week 5 is the same weight or one small step up, at **fewer reps**.
Nothing jumps. Compare v1's squat, which went 16.5 → 27.5 (+67%).

Deadlift climbs fastest because it always does for novices — the pattern is simple and
the muscles involved are large. If 10 kg a week starts to feel heavy before week 4,
drop to 5 kg a week; the app's stall rule handles it automatically.

### Build → Test — weeks 5–12

| Lift | Scheme | w5 | w6 | w7 | w8\* | w9 | w10 | w11 | w12 | w12 e1RM | ×BW at 55 kg |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Back squat | 4 × 5 | 21 | 23 | 26 | 19 | 28 | 31 | 33 | 36 | ~42 kg | 0.76× |
| Deadlift | 3 × 5 | 39 | 44 | 49 | 37 | 54 | 59 | 64 | 69 | ~80 kg | 1.46× |
| Bench press | 4 × 6 | 17 | 18 | 20 | 15 | 21 | 23 | 24 | 26 | ~31 kg | 0.57× |
| Overhead press | 4 × 6 | 13 | 14 | 15 | 11 | 16 | 17 | 18 | 19 | ~23 kg | 0.41× |
| Bent-over row | 4 × 8 | 19 | 21 | 23 | 17 | 25 | 27 | 29 | 31 | ~39 kg | 0.71× |
| Barbell RDL | 3 × 8 | 27 | 29 | 32 | 24 | 34 | 37 | 39 | 42 | ~53 kg | 0.97× |
| Goblet/front squat | 3 × 8 | 16 | 17 | 19 | 14 | 20 | 22 | 23 | 25 | ~32 kg | 0.58× |
| Hip thrust | 3 × 10 | 24 | 26 | 29 | 22 | 31 | 34 | 36 | 39 | ~52 kg | 0.95× |

\* week 8 deload at 70%

**Pull-up:** negatives weeks 1–4 → band-assisted weeks 5–11 → **3 to 6 strict reps at
week 12.** At 55 kg bodyweight this is very achievable and it is the most satisfying
number on this page.

### Bodyweight

| Week | Expected | Notes |
|---|---|---|
| 1 | 50.0–50.5 | Baseline. Photos and all five measurements. |
| 4 | 51.0–52.0 | If flat, it is food. Always. |
| 8 | 53.0–54.0 | Checkpoint. Clothes should sit differently across the shoulders. |
| 12 | 55.0–56.5 | +5 to +6.5 kg. BMI moves from 17.9 to ~19.8. |

---

## 8. Progression rules

### Double progression — the default

Every loaded exercise has a rep range, e.g. 4 × 6–8.

1. Start at the bottom of the range on every set.
2. Each session, try to add a rep to each set.
3. When **every set hits the top of the range** with the target RIR, add one lattice
   step next session and drop back to the bottom of the range.

### Rep creep — what happens when the plates are too coarse

If one lattice step is more than **10% of the current load**, adding weight is too big a
jump. So instead the rep range extends upward:

```
6–8  →  6–10  →  6–12  → then add one step and reset to 6–8
```

This is the rule that fixes v1's deadlock (audit A1) and it is what a coach actually
does with a light bar and coarse plates. With 0.5 kg microplates it will rarely fire;
with 1.25 kg as your smallest plate it will fire constantly on the overhead press.

The app tells you which rule is active and why.

### Stalling

- **Any working set below the bottom of the rep range** → stall counter +1, repeat the
  same weight next session.
- **Two consecutive stalls** → drop 10%, snap down to the lattice, reset the counter,
  and build back up. You will come back through it stronger within three weeks.
- **Two or more lifts stalling in the same week** → the app suggests an early deload
  regardless of the calendar. That is almost always a food or sleep problem, not a
  programming one.

### RIR by block

| Block | Target RIR | What it feels like |
|---|---|---|
| Foundation | 3–4 | Comfortably could have done 3 or 4 more. Deliberately easy. |
| Build | 2 | Two more were there. |
| Deload | 4 | Easy on purpose. |
| Push | 1 on the last set of movement 1, 2 elsewhere | One more was there. |
| Test | 0 on the 5RM | The last rep grinds, but it moves and the shape holds. |

**Never 0 RIR on bench or squat outside of a test, and never on a day you feel off.**
You train alone.

---

## 9. Cardio

Two jobs: a heart that works, and calves and Achilles that tolerate skipping. Neither
job is "burn calories" — you need those.

| Weeks | Sunday run | 2nd session | Skipping | Heavy bag |
|---|---|---|---|---|
| 1–2 | 15–18 min easy | Tue 12–15 min easy | Warm-up 6 × 45 s | — |
| 3–4 | 20–22 min | Tue 15–18 min | Warm-up 6 × 60 s | Sun 2 × 2 min |
| 5–6 | 24–26 min | Wed optional 20 min | Warm-up 3 min · Sun 8 × 30 s fast | Sun 3 × 2 min |
| 7 | 28 min | Wed optional 20 min | same | Sun 3 × 2 min |
| **8** | **15 min** | — | 5 × 60 s | — |
| 9–10 | 30–33 min | Wed optional 20–25 min | Sun 10 × 30 s fast | Sun 3 × 2 min |
| 11 | 35 min | Wed optional 25 min | same | Sun 3 × 3 min |
| **12** | **5K time trial** | — | 5 × 60 s | — |

**Runs stay conversational.** If you cannot speak a full sentence, you are going too
fast. The only hard cardio in this programme is the Sunday skipping intervals and the
bag rounds. That keeps the interference with lifting near zero.

**Skipping ramps slowly on purpose.** It is the single most common way untrained calves
and Achilles tendons get injured, and four weeks of patience costs you nothing.
Always on the interlocking mats — **never bare concrete**.

**The bag is off lifting days.** v1 put 9-minute bag finishers on Monday and Thursday,
which is where a large part of its 77-minute sessions came from. It lives on Sunday now,
and as an optional Wednesday session if you have energy to burn.

---

## 10. Checkpoints

| Week | Do |
|---|---|
| **1** | Baseline photos, all four poses · all five measurements · **weigh both bars and both dumbbell handles** · count every plate · weigh the microplates · measure ceiling clearance for overhead press and skipping · first bodyweight entry |
| **4** | Photos · measurements · confirm squat and bench are moving with real plates on · review: has every session been logged? |
| **8** | Photos · measurements · **deload week — do it properly** · check the waist against §3's rule · review bodyweight trend against the table in §7 |
| **12** | Photos · measurements · 5-rep tests on all four barbell lifts · max strict pull-ups · 5K time trial · **then seed cycle 2 from the test numbers** |

### Measurement sites

Waist (at the navel, relaxed, exhaled), chest (at the nipple line, arms down), upper arm
(mid-biceps, relaxed, same arm every time), thigh (mid-thigh, relaxed), neck.

Same time of day, same tape tension, same person measuring — which is you, so use a
mirror for the chest.

### Take the week-1 photos before the app exists

You cannot shoot week 1 retroactively, and the ghost-overlay feature in Phase 5 needs a
first frame to align against. Use your normal camera app this week, then import them
when Phase 5 lands.

---

## 11. Rules

1. Eat in surplus every single day. A missed meal is a missed session.
2. Leave 2 reps in the tank — 3 to 4 during weeks 1–4.
3. Collars on. Check them mid-set.
4. Never fail alone under a bar. Set the pins, or press dumbbells.
5. Add weight only when you earn it: top of the rep range on every set.
6. Log every set. A session you did not log is a session you cannot beat next week.
7. **Sixty minutes means sixty minutes.** If you are over, cut the last superset — not
   the main lift, not the warm-up. The app will offer this.
8. If something hurts — not burns, *hurts* — stop the set, log the niggle, and use the
   substitute. Twelve weeks is long enough that training through pain will cost you more
   than the swap does.

---

## 12. What happens after week 12

Run it again. Specifically:

1. Week 12's test results become cycle 2's starting loads (doc 02, algorithm E).
2. Foundation is skipped — you are no longer a beginner at these patterns. Cycle 2 is
   Build → Deload → Push → Test across 9 weeks.
3. Bodyweight target moves to 60 kg, calories re-derived from the new bodyweight.
4. If the pull-up came, band assistance is dropped and weighted pull-ups enter.

That is the cycle the app has to support, and it is why Phase 8 exists.
