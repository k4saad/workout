# 02 — Data model v2 and the algorithms

Schema changes from v1, then the five algorithms that must be pure, in `lib/domain/`,
and written **test-first**.

Everything else in this app is forms and lists. These five are the brain, and each one
is a place where a silent bug costs real training weeks.

---

## Part 1 — Schema changes

v1's schema is kept. These are additions and clarifications, all of which close a hole
identified in doc 00.

### 1.1 `prescription` — new fields

```jsonc
{
  "id": "b-tue-3a",
  "exerciseId": "incline-dumbbell-press",
  "order": 3,

  // NEW — superset grouping.  Prescriptions sharing a groupId are performed
  // alternating, and only the LAST member of the group carries the rest.
  // Closes audit C7.  This is how the 60-minute cap is met.
  "groupId": "b-tue-ss1",

  // NEW — explicit unit.  Replaces smuggling seconds through repsMin/repsMax.
  // Closes audit C6.  "reps" is the default when absent.
  "unit": "reps",              // reps | sec | m

  "sets": 3,
  "repsMin": 10,
  "repsMax": 10,

  // NEW — the ceiling rep creep may extend to before a load jump is forced.
  // Null means rep creep is disabled for this movement.  Closes audit A1.
  "repsCreepMax": 14,

  "restSec": 60,
  "targetRir": null,           // null => inherit block.defaultRir.  Closes audit C2.
  "loadMode": "dumbbellPair",

  // RENAMED in meaning, not in name: this is now the COLD-START value only,
  // used when no history exists within `progression.historyWindowDays`.
  // It MUST be lattice-valid for the configured inventory.  Closes audit A2/B4.
  "startLoadKg": 7.0,

  // NEW — does `sets: 3` mean 3 total or 3 per side?  Closes audit C5.
  "perSide": false,

  // NEW — generate lattice-aware ramp sets before the first work set (algorithm D).
  // Ramp sets log is_warmup = 1 and never feed progression or volume.
  "warmupRamp": false,

  // NEW — droppable when short on time, and the first thing the runner offers to
  // cut at the 45-minute mark.  Also lets a movement ship disabled and be switched
  // on later by a block override (the Nordic curl, week 9).
  "optional": false,

  "progression": { "...": "see 1.3" },
  "substitutes": ["dumbbell-bench-press"],
  "coachNote": "Bench at ~30 degrees.",
  "tempo": null,
  "unilateral": false
}
```

**`unilateral` vs `perSide`.** `unilateral` describes the *movement* (one limb at a
time). `perSide` describes the *prescription* (whether the set count is per side). They
are usually both true together, but a suitcase carry is `unilateral: true,
perSide: true` while an alternating dumbbell curl is `unilateral: true,
perSide: false`. The UI logs two entries per set when `perSide` is true.

### 1.2 `block` — new and clarified fields

```jsonc
{
  "id": "deload",
  "weeks": [8],

  // NEW — lets the UI render a test week and a deload week differently, and lets
  // the calendar know when the programme is over.  Closes audit C8.
  "blockKind": "deload",       // accumulation | deload | test | intro

  "defaultRir": 4,             // NOW CONSUMED — see resolution step 2c
  "loadMultiplier": 0.70,
  "setMultiplier": 0.60,

  // NEW — removes the 1.5-sets ambiguity.  Closes audit C3.
  "setRounding": "up",         // up | down | nearest.  Result is clamped to >= 1.

  // NEW — deload unwinds supersets so nothing is rushed.
  "includeSupersets": false,
  "includeFinishers": false,

  "inheritsDaysFrom": "build",
  "dayOverrides": {},
  "days": []
}
```

### 1.3 `progression` — new fields

```jsonc
{
  "type": "doubleProgression",
  "incrementKg": 2.5,          // the DESIRED jump; the engine may use a smaller
                               // lattice step or refuse and rep-creep instead
  "deloadPct": 0.10,
  "stallLimit": 2,

  // NEW — history older than this is ignored and startLoadKg is used instead.
  // Closes audit B4 by making the precedence explicit rather than implied.
  "historyWindowDays": 21,

  // NEW — the fraction of current load above which a single jump is "too big"
  // and rep creep engages instead.  Closes audit A1.
  "maxJumpPct": 0.10
}
```

### 1.3a `section.drills` — warm-ups become real references

v1 held warm-ups as `freeItems` strings, which is why ten library exercises
(`cat-cow`, `couch-stretch`, `leg-swing`, `bodyweight-squat` and six more) were
unreachable — they had cues and a detail page that nothing could ever link to
(audit C16).

```jsonc
"drills": [
  { "exerciseId": "rope-skipping", "order": 1, "text": "3 min",
    "note": "On the interlocking mats, never bare concrete." },
  { "exerciseId": "band-pull-apart", "order": 2, "text": "2 x 20", "note": null }
]
```

Drills are **ticked, not logged** — they produce no `set_logs` rows and never feed the
progression engine. But each one is tappable through to the exercise detail screen with
its cues and demo, which is what you want when you have forgotten what a wall slide is.
Gate V10 enforces that every library exercise is reachable this way.

### 1.4 `programme` — new top-level fields

```jsonc
{
  "nutritionPhases": [                       // replaces the single nutritionTargets
    { "weeks": [1,2,3,4],      "kcal": 2600, "proteinG": 110, "carbsG": 382, "fatG": 70 },
    { "weeks": [5,6,7,8],      "kcal": 2750, "proteinG": 115, "carbsG": 410, "fatG": 72 },
    { "weeks": [9,10,11,12],   "kcal": 2900, "proteinG": 120, "carbsG": 440, "fatG": 75 }
  ],
  "nutritionRules": {
    "gainKgPerWeek": 0.3,
    "flatWeeksBeforeBump": 2,
    "kcalBumpWhenFlat": 250,
    "useRollingAverage": true,
    "rollingAverageDays": 7,                  // closes audit C11 + the noise problem
    "waistGrowthLimitCm": 3.0,
    "kcalCutWhenWaistGrows": 200
  },

  // NEW — what the app does at week 13.  Closes audit C8.
  "onComplete": {
    "action": "seedNextCycle",
    "skipBlocks": ["foundation"],
    "seedFrom": "test",
    "bodyweightTargetKg": 60.0
  }
}
```

### 1.5 `cardioProgression` becomes authoritative

Audit C4: cardio duration was specified in two places. **Resolution rule:** when
`progression.type == "cardioTable"`, the week's row in `cardioProgression` wins and the
prescription's `repsMin`/`repsMax` are ignored entirely. The loader must strip them so
no UI can accidentally render them.

### 1.6 Validation gates — Phase 1 tests that must fail the build

| Gate | Assertion |
|---|---|
| **V1** | Programme validates against `schema.json`. |
| **V2** | Every `exerciseId` and every `substitutes` entry resolves in the library. |
| **V3** | Weeks 1..`totalWeeks` are each covered by exactly one block. |
| **V4** | Every `dayOverrides` key resolves to a real day, every `prescriptionOverrides` key to a real prescription in that day. |
| **V5** | A block has **either** `days` **or** `inheritsDaysFrom`, never both, never neither. |
| **V6** | **Every `startLoadKg` is lattice-valid** for the default inventory, for its `loadMode`. This is the test that would have caught audit A2. |
| **V7** | No prescription has `repsMin > repsMax`, or `repsCreepMax < repsMax`. |
| **V8** | Every `groupId` appears on at least two prescriptions within the same section. |
| **V9** | Every prescription with `unit: "sec"` or `"m"` has `loadMode` in `{timed, distance, bodyweight}`. |
| **V10** | Every exercise in the library is reachable — referenced by at least one prescription, substitute, or warm-up drill. Closes audit C16 by forcing warm-up items to become real references. |
| **V11** | Summed `estMinutes` for each `lift` day is <= 60, **including** the resolved set counts of inheriting blocks. This is the 60-minute ceiling, enforced by CI rather than by hope. |
| **V12** | For every inheriting block, each load after `loadMultiplier` snaps to a lattice-valid value. Where it would fall below the bare implement, that is a *warning* and the solver must clamp to base and say "already at the bare implement" — you cannot deload an empty bar. |
| **V13** | Any block declaring `defaultRir` has at least one prescription leaving `targetRir` null. Otherwise the field is decorative again (audit C2) and the deload softens nothing. |

Gates V12 and V13 were added after generating the v2 data — V12 caught the EZ-bar curl
and lateral raise deloading below their own bare implements, and V13 caught `defaultRir`
being dead on arrival because every prescription restated it. `tools/validate.py`
implements all thirteen; Phase 1 ports them to `flutter test`.

### 1.7 A superset must not force a re-plate

A soft gate in `tools/validate.py`, but a real one for the 60-minute ceiling: if two
members of the same `groupId` need **the same implement family at different loads**, you
re-plate between every round and the superset saves nothing.

Pair a loaded movement with a bodyweight, cable or banded one, or give both members the
same load. The v2 data follows this everywhere — it is why Monday's calf raise is
single-leg bodyweight rather than loaded, and why Tuesday's face pull and Friday's
pushdown use the wall cable.

---

## Part 2 — The algorithms

All five live in `lib/domain/`. **Zero Flutter imports. Zero I/O.** Pure functions over
plain Dart objects. Tests before implementation, every time.

---

### Algorithm A — Progression engine

`lib/domain/progression/progression_engine.dart`

**Input:** the resolved `ExercisePrescription`, set logs for that `exerciseId`, the
block's `loadMultiplier`, the stall counter, the plate inventory, today's date.

**Output:**

```dart
class LoadSuggestion {
  final double? suggestedKg;
  final int repTargetMin, repTargetMax;   // may be rep-crept above prescription.repsMax
  final String reason;                    // shown verbatim in the UI
  final PlateSolution? plates;
  final bool isStalled;
  final bool isRepCreep;
  final double? smallestStepKg;
  final String? warning;                  // e.g. "no loadable jump at this weight"
}
```

**Rules, in order:**

```
0.  Non-kilogram progression types short-circuit:
      repsOnly        -> same setup, target +1 rep
      timeOnly        -> target + incrementSec
      bandProgression -> surface last logged band note; suggest a thinner band
                         once repsMax is hit on all sets
      cardioTable     -> read programme.cardioProgression for the current week
      none            -> no suggestion at all

1.  No set logs for this exerciseId within progression.historyWindowDays
      -> suggest prescription.startLoadKg, reason "programme start"
      (This is the ONLY place startLoadKg is read.  Closes audit B4.)

2.  Compute step = plateSolver.smallestStep(lastLoad, loadMode, inventory)

3.  Last session: every working set hit repTargetMax AND every logged rir >= targetRir
      3a. if step <= progression.maxJumpPct * lastLoad
            -> suggest lastLoad + min(incrementKg, step-rounded)
               reset rep target to repsMin..repsMax
               reason "earned the jump"
      3b. else  (one step is too big a jump — REP CREEP.  Closes audit A1.)
            if repTargetMax < repsCreepMax
              -> suggest lastLoad, rep target = repsMin..(repTargetMax + 2)
                 isRepCreep = true
                 reason "plates are too coarse here — add reps instead"
            else
              -> suggest lastLoad + step, rep target back to repsMin..repsMax
                 reason "rep ceiling reached — taking the big jump"

4.  Last session: all sets inside the range but not all at the top
      -> suggest lastLoad, reason "add reps at this weight"

5.  Any working set below repTargetMin
      -> stall counter += 1
      5a. stallCount < progression.stallLimit
            -> suggest lastLoad, reason "repeat — stall 1 of 2"
      5b. stallCount >= stallLimit
            -> suggest lastLoad * (1 - deloadPct), reset counter
               reason "back off 10% and build up"

6.  Apply block.loadMultiplier  (deload weeks)

7.  Snap DOWN to the lattice via algorithm B.  Never up.

8.  Final guard: if the snapped result == lastLoad but rule 3 fired, fall through
    to rep creep rather than returning "no change".  A jump that was earned must
    always produce SOMETHING — weight or reps.
```

> **Rule 8 is the whole point.** v1 could earn a jump, clamp it, round it to zero and
> return the same weight with the reason "earned the jump" — forever, on every lift
> under 25 kg. See audit A1.

**Substitution rule:** when an exercise is swapped for a substitute, history for the
**substitute's own** `exerciseId` is used. If it has none, rule 1 fires with the
substitute's own `startLoadKg`. Never inherit the original's load — a 26 kg back squat
is not a 26 kg front squat.

### History lookup precedence — do not key on `exerciseId` alone

Found while generating the v2 data, and it only bites because v2 deliberately trains
patterns twice a week.

`single-leg-calf-raise` appears on Monday at 3 × 15 and on Thursday at 3 × 20.
`easy-run` appears on Wednesday at 20 min and on Sunday at 26 min. If history is keyed
on `exerciseId` alone, Monday's 15-rep performance drives Thursday's 20-rep suggestion,
and the engine concludes you stalled every single Thursday.

**Lookup order:**

```
1. set_logs for the SAME prescriptionId          <- the normal path
2. set_logs for the same exerciseId within historyWindowDays
     (only when 1 is empty — i.e. a new prescription, or after a swap)
3. prescription.startLoadKg                       <- cold start
```

Step 2 is what makes a substitute inherit sensible history. Step 1 is what stops two
prescriptions of the same lift from fighting each other.

`set_logs` already stores both `prescription_id` and a denormalised `exercise_id`, so
this needs no schema change — only that the query is written correctly.

**Extra tests:**

| # | Case | Expect |
|---|---|---|
| A-15 | Same exerciseId at 3 × 15 and 3 × 20 in one week | each prescription progresses off its own history |
| A-16 | Brand-new prescription id, existing exerciseId history | falls back to exerciseId history, not `startLoadKg` |
| A-17 | Brand-new prescription id, no exerciseId history | `startLoadKg` |

**Required tests** (write these first, show the failing run):

| # | Case | Expect |
|---|---|---|
| A-1 | No history at all | `startLoadKg` |
| A-2 | History 30 days old, `historyWindowDays: 21` | `startLoadKg`, not the stale load |
| A-3 | 4×8 at 8,8,8,8 RIR 2 on a 6–8 range, 1 kg lattice, 30 kg load | 31 kg, "earned the jump" |
| A-4 | **Same, but 17 kg load and a 2.5 kg lattice** | **17 kg, reps 6–10, `isRepCreep` true** |
| A-5 | A-4 repeated until `repsCreepMax` is hit | 19.5 kg, reps back to 6–8 |
| A-6 | 4×8 at 8,8,7,6 | same weight, "add reps" |
| A-7 | 4×8 at 8,6,5,5 | same weight, stall 1 |
| A-8 | Two consecutive stalls | −10%, snapped down, counter reset |
| A-9 | Deload block `loadMultiplier 0.7` | 70%, still lattice-valid |
| A-10 | Suggestion unloadable with inventory | rounds **down**, never up |
| A-11 | Swapped to a substitute with no history | substitute's `startLoadKg` |
| A-12 | Swapped to a substitute *with* history | substitute's own last load |
| A-13 | Each of `repsOnly`/`timeOnly`/`bandProgression`/`cardioTable`/`none` | right shape, no kg suggestion |
| A-14 | **Earned jump that snaps to zero change** | must return rep creep, never "same weight, earned the jump" |

---

### Algorithm B — Plate solver and the lattice

`lib/domain/plates/plate_solver.dart`

The feature no commercial app has for your gym, and the thing every load in the app
passes through.

```dart
PlateSolution solve(double targetKg, LoadMode mode, Inventory inv);
double  smallestStep(double atLoadKg, LoadMode mode, Inventory inv);
List<double> lattice(LoadMode mode, Inventory inv, {double maxKg});
bool    isLatticeValid(double kg, LoadMode mode, Inventory inv);
```

**Per-mode plate budgets** — this is the part that is easy to get wrong:

| `loadMode` | Base | Plates consumed per size | Budget |
|---|---|---|---|
| `barbell` | bar weight | 2 (one per side) | `count ~/ 2` |
| `ezBar` | EZ bar weight | 2 | `count ~/ 2` |
| `dumbbellPair` | handle weight (per DB) | **4** (2 sides × 2 handles) | `count ~/ 4` |
| `dumbbellSingle` | handle weight | 2 | `count ~/ 2` |
| `kettlebell` | — | fixed list, no solve | — |
| `bodyweightLoaded` | — | solves the added weight only | — |
| `bodyweight` / `banded` / `timed` / `distance` | — | no solve | — |

For `dumbbellPair`, **`targetKg` is per dumbbell**, not the total.

**Outputs:**

```dart
class PlateSolution {
  final double achievableKg;          // closest at or BELOW target
  final double? nextUpKg;             // closest above, so the UI can offer both
  final List<PlateCount> perSide;
  final double deltaFromTarget;
  final String breakdown;             // "27 kg = bar 9 + (5 + 2.5 + 1.25 + 0.5) per side"
  final bool contended;               // another prescription today needs these plates
  final double smallestStepKg;
  final String? microplateHint;       // fires when smallestStep > 5% of load
}
```

**Contention detection.** You own one plate set. Given all of today's prescriptions and
their suggested loads, report any pair that cannot be loaded simultaneously — typically
a barbell lift and a dumbbell pair competing for the same 5 kg plates. **Warn, do not
block**; you will just re-plate between movements, but you should know before you start.

**Microplate hint.** When `smallestStep > 0.05 × currentLoad`, surface it:
*"Smallest jump on overhead press is 2.5 kg = 19% of your current load. A pair of 0.5 kg
microplates would make this 4%."* This is how the app tells you what to buy.

**Required tests:**

| # | Case | Expect |
|---|---|---|
| B-1 | Exact hit on the lattice | zero delta |
| B-2 | Target between lattice points | rounds down, `nextUpKg` populated |
| B-3 | Target below bar weight | returns bar weight, delta negative, flagged |
| B-4 | Inventory exhausted mid-solve | best achievable, no crash |
| B-5 | `dumbbellPair` budget | consumes 4 per size, not 2 |
| B-6 | `dumbbellSingle` vs `dumbbellPair` at the same target | different solutions |
| B-7 | Empty bar | `perSide` empty, breakdown "bar only" |
| B-8 | Contention: barbell 40 kg + DB pair 12 kg with 8×5 kg plates | `contended: true` |
| B-9 | `smallestStep` with 1.25 kg smallest plate | 2.5 kg |
| B-10 | `smallestStep` with 0.5 kg microplates | 1.0 kg |
| B-11 | `isLatticeValid(20.0, barbell, 9 kg bar, 1.25 smallest)` | **false** — the v1 bug |
| B-12 | `isLatticeValid(19.0, ...)` | true |

---

### Algorithm C — Calendar projection

`lib/domain/calendar/programme_calendar.dart`

```
anchor  = Monday of the ISO week containing programme.startDate
weekNo  = ((date - anchor).inDays ~/ 7) + 1

if weekNo < 1                       -> BeforeProgramme
if weekNo > programme.totalWeeks    -> Complete(onComplete)   // closes audit C8
if date < programme.startDate       -> null  (week 1, pre-start days)

block = the unique block whose weeks contains weekNo
days  = block.days, or resolve(block.inheritsDaysFrom) + overrides
day   = days.firstWhere(weekday == date.weekday)  ?? null
```

**Block inheritance resolution — the exact order:**

```
1.  deep-copy the source block's days
2a. sets      := round(sets * setMultiplier, block.setRounding), clamped to >= 1
2b. load      := load * loadMultiplier            (applied later, by algorithm A)
2c. targetRir := prescription.targetRir ?? block.defaultRir      <- audit C2
2d. if !includeFinishers -> drop sections of type "finisher"
2e. if !includeSupersets -> clear every groupId (supersets become straight sets)
3.  apply dayOverrides[dayId].prescriptionOverrides[presId]      (shallow merge)
4.  apply dayOverrides[dayId].weekSpecific[weekNo].prescriptionOverrides[presId]
```

Steps 2c and 2e are new; 2a's rounding rule is new. All three close audit findings.

**Scheduling mode:** `fixed` by default. Dates are dates; week 6 is week 6 whether or
not you trained in week 5, and a missed session shows as missed. The alternative
(`rolling`) never marks anything missed but drifts the week number away from the cardio
table. Keep `fixed`, plus an explicit **"shift programme by N weeks"** action for when
you genuinely lose a week to illness or travel.

**Also required:** `sessionsForRange(from, to)` merging projected days with real
`sessions` rows in one query per month; `adherence(from, to)` excluding `optional` days;
current streak.

**Required tests:**

| # | Case | Expect |
|---|---|---|
| C-1 | `startDate` on a Monday | week 1 = that week |
| C-2 | `startDate` on a Thursday | Mon–Wed of week 1 return null, Thu onward resolve |
| C-3 | Date before `startDate` | `BeforeProgramme` |
| C-4 | Week 4 → week 5 boundary | block changes Foundation → Build |
| C-5 | Week 8 | deload multipliers applied; 3 sets → 2 with `setRounding: "up"` |
| C-6 | Week 8 | supersets unwound, every `groupId` null |
| C-7 | Week 8 | `targetRir` = 4 everywhere it was null |
| C-8 | Week 12 Sunday | resolves to `five-k-time-trial` |
| C-9 | Week 13 | `Complete`, not null |
| C-10 | A weekday with no day defined | null, no throw |
| C-11 | Rescheduled session | drawn on `scheduled_date`, counted in `planned_date`'s week |
| C-12 | `setMultiplier 0.6` on 3 sets, rounding up | 2 |
| C-13 | `setMultiplier 0.6` on 1 set, rounding up | 1, never 0 |

---

### Algorithm D — Warm-up ramp generator (new)

`lib/domain/progression/ramp_generator.dart`

v1 prescribed "50% × 5, 70% × 3, 85% × 1" in free text. At a 20 kg bench with a 9 kg
bar, 50% is 10 kg — **0.5 kg per side, unloadable** (audit C1). Percentages break
whenever the bar is a large fraction of the load, which is every lift you own for the
next two months.

**Rule: ramps are absolute and lattice-aware.**

```
gap = workingLoad - barWeight

gap < 4 kg     -> [bar x 8]                      // one set, nothing to ramp
gap < 15 kg    -> [bar x 8, snap(bar + 0.5*gap) x 5]
otherwise      -> [bar x 8, snap(bar + 0.45*gap) x 5, snap(bar + 0.75*gap) x 3]

never more than 3 ramp sets  (the 60-minute ceiling)
rest between ramp sets: 60 s, or 75 s on the deadlift
```

Worked examples on a 9 kg bar with the shipped 0.5 kg lattice:

| Working set | Ramp |
|---|---|
| 11.5 kg | bar × 8 — under a 4 kg gap there is nothing worth ramping |
| 17 kg bench | bar × 8, 13 × 5 |
| 39 kg deadlift | bar × 8, 22.5 × 5, 31.5 × 3 |
| 69 kg deadlift | bar × 8, 36 × 5, 54 × 3 |

Rest between ramp sets is 60 s, or 75 s on a deadlift — it is the heaviest
thing in the room and the setup takes longer.

Ramp sets are logged with `is_warmup = 1` and are **excluded from every progression
decision and every volume statistic.**

**Required tests:** each branch of the rule; every output is lattice-valid; never
exceeds 3 sets; never exceeds the working load; `is_warmup` set.

---

### Algorithm E — Next-cycle seeder (new)

`lib/domain/progression/cycle_seeder.dart`

What happens at week 13. Closes audit C8 and is the reason the Test block exists.

```
input:  week-12 test results  { exerciseId -> (weightKg, reps) }
        programme.onComplete

1. e1RM   = weight * (1 + reps/30)            // Epley, LABELLED AS AN ESTIMATE
2. newStart:
     4x5 lead lifts   -> snap(0.75 * e1RM)
     3x8 secondaries  -> snap(0.65 * e1RM)
     accessories      -> snap(last logged load * 1.0)   // carry straight over
3. emit a new programme JSON: same block structure,
   blocks in onComplete.skipBlocks removed,
   weeks renumbered from 1,
   startDate = the Monday after the test week,
   revision  = old revision + 1,
   startLoadKg for every prescription = newStart, snapped to the lattice
4. present as a DIFF against the current programme before it is applied
```

**Required tests:** e1RM arithmetic; every emitted `startLoadKg` is lattice-valid;
Foundation is removed and weeks renumbered contiguously from 1; the diff lists every
changed load; an exercise with no test result carries its last logged load rather than
being dropped.

---

## Part 3 — Database

v1's schema, kept, plus these.

```sql
-- NEW: audit C15.  Twelve weeks alone with no way to record that something hurt.
niggles(
  id INTEGER PK, logged_on DATE, exercise_id TEXT NULL, session_id INTEGER NULL,
  site TEXT,                    -- knee | lowBack | shoulder | elbow | wrist | hip | other
  severity INTEGER,             -- 1..5
  note TEXT NULL,
  resolved_on DATE NULL
)

-- NEW: the calibration wizard's output.  Everything the plate solver depends on.
inventory_bars(id TEXT PK, name TEXT, weight_kg REAL, measured BOOLEAN DEFAULT 0)
inventory_plates(weight_kg REAL PK, count INTEGER, bore TEXT)
inventory_misc(id TEXT PK, name TEXT, weight_kg REAL NULL, note TEXT NULL)

-- NEW: rolling-average bodyweight is a query, but cache the 7-day value so the
-- "flat for 2 weeks" card is cheap to evaluate on every launch.
bodyweight_rolling(measured_on DATE PK, avg7_kg REAL)
```

**Kept from v1, and worth restating because both are load-bearing:**

- `set_logs.exercise_id` is **denormalised on purpose**. You will swap exercises in the
  editor. Logs must survive that. Never join history through the live programme JSON.
- `sessions.planned_date` and `sessions.scheduled_date` are **separate**. Adherence is
  measured against `planned_date`; the calendar draws on `scheduled_date`.

**Added to `set_logs`:** `is_warmup` already exists in v1 — the ramp generator depends
on it being honoured by every query that feeds algorithm A or the stats screens.

---

## Part 4 — Android specifics v1 missed

| Concern | Requirement |
|---|---|
| **Exact rest timer on Android 12+** | `SCHEDULE_EXACT_ALARM` (or `USE_EXACT_ALARM`) in the manifest, plus `AndroidScheduleMode.exactAllowWhileIdle`. Without it the timer fires late or not at all. Closes audit C9. |
| Notifications on Android 13+ | Runtime `POST_NOTIFICATIONS` request, with a graceful path if denied. |
| Battery optimisation | Prompt once to exempt the app; document it in the README. OEM-aggressive killers (Xiaomi, Realme, Samsung) will kill the timer otherwise. |
| Timer correctness | **Wall-clock based** — compare against an end timestamp. A tick counter drifts and stops when Android suspends the isolate. The notification survives the screen going off; the in-app countdown is cosmetic. |
| Photo privacy | `android:allowBackup="false"` **and** `backup_rules.xml` excluding the photo directory. Belt and braces. |
| Release signing | Real keystore from **Phase 0**. See audit A4. |
| APK size | `--split-per-abi`, arm64 only. ~8 MB instead of ~20 MB. |
| minSdk | 24. `camera`, `local_auth` and Drift are all fine there. |
| JDK | **17.** Not 21. Pin it in `android/gradle.properties` if the system default differs. |
