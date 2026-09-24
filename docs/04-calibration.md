# 04 — Week-1 calibration

> **Replaced in v3. There is nothing to weigh.** The programme now ships a definitive
> kit — barbell 10 kg, EZ bar 7 kg, dumbbell handles 2 kg (all including collars),
> plates 20 ×2, 10 ×4, 5 ×8, 2.5 ×8, 1.25 ×8, 1.0 ×4, 0.5 ×8 — and you arrange your
> equipment to match it. The app shows it under **Settings → Your equipment**, and
> [doc 01 §4](01-programme.md#4-equipment-and-the-loading-lattice) explains the lattice
> it makes (every whole kilogram on every implement). Week 1's checkpoint is "confirm
> the kit", not "weigh the bars".
>
> What follows is kept as **optional reference**: how to check a bar or a plate if one
> ever looks wrong, and the room, body, movement and running baselines, which still
> matter. The room measurements (§3) are safety checks — ceiling clearance for the
> press and the rope — not load calibration. Two things below are superseded outright:
> the microplate advice in §2 (the kit already has 1.0 kg and 0.5 kg plates; 0.25 kg
> plates are not needed), and the "normal camera" in §5 (use the app's capture screen).

**Originally:** do this before Phase 1. It takes about forty minutes.

The plate solver, the progression engine, the ramp generator and every load in the
programme are computed from these numbers. Guessed inputs produce a plausible-looking
app that tells you to put a weight on the bar that your plates cannot make — which is
exactly what happened to v1, in 19 of 25 cases.

---

## 1. Weigh the bars

Bathroom scale. Stand on it, note the number. Pick up the bar, note the number.
Subtract. **Do it twice and average** — bathroom scales are noisy at these weights.

| Item | Measured (kg) |
|---|---|
| Standard barbell | ______ |
| EZ curl bar | ______ |
| Dumbbell handle A (with collars) | ______ |
| Dumbbell handle B (with collars) | ______ |
| Kettlebell | ______ |
| Spinlock collar, single | ______ |

> If the two dumbbell handles differ by more than 0.2 kg, note which is which and
> always load them the same way round.

## 2. Count and weigh the plates

Count every plate. Weigh one of each size — vinyl and cement plates are frequently
10–15% off their stamped value, and that error compounds across four plates.

| Stamped | Count | Actual weight of one | Bore (30 mm standard / 50 mm Olympic) |
|---|---|---|---|
| 20 kg (tri-grip) | ______ | ______ | ______ |
| 10 kg | ______ | ______ | ______ |
| 5 kg | ______ | ______ | ______ |
| 2.5 kg | ______ | ______ | ______ |
| 1.25 kg | ______ | ______ | ______ |
| **microplates** | ______ | ______ | ______ |
| other | ______ | ______ | ______ |

### The two things to check here

**Bore compatibility.** Your barbell is a spinlock standard bar, so its sleeve is
~25–30 mm. The big tri-grip plates in your photos *look* like they could be Olympic
bore. **If any plate does not fit the bar, it is not in the inventory** — record it
separately. A 20 kg plate you cannot load is a 20 kg plate the solver must not count.

**Microplate size.** This is the single most consequential number in the whole project.

| Your smallest plate | Lattice step | Jump on a 17 kg bench | Verdict |
|---|---|---|---|
| 1.25 kg | 2.5 kg | 15% | Rep creep fires constantly |
| 1.0 kg | 2.0 kg | 12% | Still coarse |
| **0.5 kg** | **1.0 kg** | **6%** | **Good** |
| 0.25 kg | 0.5 kg | 3% | Ideal |

> If yours are 1 kg or larger, buy a pair of 0.5 kg and a pair of 0.25 kg standard-bore
> microplates. About €20. Worth more to this programme than anything else you could
> spend money on.

## 3. Measure the room

| | Measured | Why it matters |
|---|---|---|
| Ceiling height, lifting area | ______ cm | Standing overhead press needs your height + ~55 cm with arms locked out. Under that, the programme switches to seated or landmine pressing. |
| Ceiling height, skipping area | ______ cm | Skipping needs roughly 2.4 m clear. Pipes count. |
| Clearance above the pull-up bar | ______ cm | Your chin has to clear the bar without your head hitting the ceiling. |
| Usable floor length for carries | ______ m | Only matters if you swap a suitcase carry in for the Sunday side plank; if the run is short you will be turning a lot. |
| Squat stand catch-pin lowest setting | ______ cm | Must be below your squat bottom position. |

## 4. Baseline body

| | Measured |
|---|---|
| Bodyweight, morning, after the toilet, before food | ______ kg |
| Waist at navel, relaxed, exhaled | ______ cm |
| Chest at nipple line, arms down | ______ cm |
| Upper arm, mid-biceps, relaxed (note which arm) | ______ cm |
| Thigh, mid-thigh, relaxed | ______ cm |
| Neck | ______ cm |

## 5. Baseline photos — do this week, in the app

Use the app's capture screen, **not the phone's camera app**: the capture screen keeps
photos in app-private storage, while the camera app puts them in the gallery and from
there into every cloud backup the phone runs.

Four poses: **front relaxed · front flexed · side right · back**.

- Same spot, same light, phone at the same height (prop it on the bench)
- Same distance — mark the floor with tape
- Shorts only, no shirt, feet in the same place
- Do not suck in, do not flex on the relaxed shots

**You cannot shoot week 1 retroactively.** The ghost overlay also needs a first frame
to align every later shoot against.

## 6. Movement screen — do this before your first loaded set

Not a test, a check. Film each one from the side on your phone.

| Movement | Looking for | If it fails |
|---|---|---|
| Bodyweight squat × 10 | Heels stay down, back does not round at the bottom | That depth is your depth for now. Raise the heels on 1.25 kg plates if the ankles are the limit. |
| Broomstick hip hinge × 10 | Stick stays in contact with head, mid-back and tailbone | Drill it with the stick for two weeks before loading the RDL. |
| Broomstick overhead × 10, arms locked | Ribs stay down, no lower-back arch | Seated pressing until it cleans up. |
| Dead hang 20 s | Shoulders tolerate it, grip lasts | Build to 30 s before pull-up negatives. |
| Wall slide × 10 | Forearms stay on the wall | Shoulder mobility work in every warm-up. |

## 7. Running baseline

| | |
|---|---|
| Longest continuous run, comfortable pace | ______ min |
| Route you will actually use | ______ |
| Can you hold a conversation at that pace? | yes / no |

If the answer to the last one is no, you are running too fast. Every run in this
programme is conversational except the week-12 time trial.

---

## Hand this to Claude Code

Once filled in, the Phase 3 prompt seeds the calibration wizard from it, and the Phase 1
lattice test (V6) validates every `startLoadKg` against these real numbers rather than
the placeholders in doc 01.

```json
{
  "bars": [
    { "id": "barbell",  "name": "Standard barbell", "weightKg": 0.0, "measured": true },
    { "id": "ezBar",    "name": "EZ curl bar",      "weightKg": 0.0, "measured": true },
    { "id": "dbHandle", "name": "Dumbbell handle",  "weightKg": 0.0, "measured": true }
  ],
  "plates": [
    { "weightKg": 0.0, "count": 0, "bore": "standard" }
  ],
  "fixedDumbbells": [
    { "weightKg": 0.0, "count": 2 }
  ],
  "kettlebells": [ { "weightKg": 0.0 } ],
  "collarWeightKg": 0.0,
  "room": {
    "ceilingLiftingCm": 0,
    "ceilingSkippingCm": 0,
    "pullUpClearanceCm": 0,
    "carryLengthM": 0.0
  }
}
```
