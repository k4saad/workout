# 00 — Audit of v1

Every finding below was verified against the shipped `keller-twelve.json`,
`exercises.json` and `schema.json` by running the arithmetic, not by reading.
Ordered by what it would have cost you.

The v1 data was **structurally** clean — 72 exercises, no broken `exerciseId` or
`substitutes` references, no duplicate prescription ids, weeks 1–12 covered exactly
once, every `dayOverrides` target resolving. The problems are all one layer up:
the numbers are not loadable, the engine that consumes them deadlocks, and the
split does not match the athlete.

---

## Critical — would have cost training weeks or data

### A1. The progression engine deadlocks on every light barbell lift

v1 §5.1 rule 2 says *"suggest lastLoad + `progression.incrementKg`"* (2.5 kg).
v1 §5.1 rule 7 says *"never suggest a jump larger than 10% of lastLoad — clamp and flag"*.
v1 §5.1 rule 6 says *"round to nearest achievable load, rounding DOWN"*.

On a 20 kg bench press, 2.5 kg **is 12.5%**. Rule 7 clamps to 2.0 kg. Rule 6 rounds
2.0 kg down to the nearest achievable increment, which is 0 kg. **The suggestion is
the same weight, forever.** The same happens on overhead press (2.5 kg on 12.5 kg is
20%), bent-over row, and every barbell lift below 25 kg — which is all of them for
the first six weeks.

This is the exact failure mode the v1 plan warns about in its own risk table:
*"the progression engine silently suggesting wrong loads for weeks."*

**Fix:** doc 02, algorithm A. The clamp becomes `max(smallestLatticeStep, 0.10 × load)`,
so it can never clamp below one loadable step. And when one step exceeds 10% of the
current load, the lift automatically switches to **rep creep** — extend the rep range
upward before adding weight — which is what a coach actually does with coarse plates.

### A2. 19 of 25 `startLoadKg` values are physically unloadable

With a 9 kg bar and 1.25 kg as the smallest plate, the barbell lattice is
`9, 11.5, 14, 16.5, 19, 21.5, 24, 26.5, 29, 31.5, 34 …` — 2.5 kg apart, offset by 9.
Every round number in v1 misses it.

| Prescription | Exercise | v1 target | Nearest loadable |
|---|---|---|---|
| `p2-mon-1` | Bench press | 20.0 | 19.0 / 21.5 |
| `p2-tue-1` | Back squat | 27.5 | 26.5 / 29.0 |
| `p2-fri-1` | Deadlift | 45.0 | 44.0 / 46.5 |
| `p2-mon-2` | Overhead press | 12.5 | 11.5 / 14.0 |
| `p2-thu-2` | Bent-over row | 22.5 | 21.5 / 24.0 |
| `p1-wed-4` | DB overhead press | 4.0 | 2.0 / 4.5 |
| …14 more | | | |

The plate solver would have silently shifted every one of them down, so nothing
*breaks* — but the load tables, the strength targets and the week-by-week narrative
are all built on numbers that never appear on the bar.

**Fix:** doc 02, section B. All v2 loads are generated **on the lattice**, and Phase 1
ships a test that fails the build if any `startLoadKg` is not lattice-valid for the
configured inventory.

### A3. Deadlift, overhead press and bent-over row are never trained in weeks 1–4

Then week 5 opens with **deadlift 4 × 5 at 45 kg**, overhead press at 12.5 kg and
bent-over row at 22.5 kg — for someone who has, per v1's own intake, never lifted.

v1's Foundation block contains no conventional deadlift at all. The first time the
bar leaves the floor, it is at 90% of bodyweight for five reps, alone, in a basement,
on a bar whose height v1 separately flags as a technique hazard.

**Fix:** doc 01. Every barbell lift that appears in Build is introduced in Foundation
with the empty bar, and the week 4 to week 5 handoff is continuous.

### A4. The release keystore is in Phase 9 — that is a guaranteed data wipe

Flutter's generated `android/app/build.gradle` signs release builds with the **debug**
key by default. Phases 0–8 therefore ship debug-signed APKs. Introducing a real
keystore in Phase 9 changes the signing certificate, `adb install -r` fails with
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and the only way forward is to uninstall.

Uninstalling deletes app-private storage: **the whole training database and every
progress photo.** Those photos are the one thing in this project that cannot be
recreated.

**Fix:** doc 03, Phase 0. Generate the keystore and wire the signing config before the
first feature is written. Cost: fifteen minutes.

### A5. No backup path until Phase 7 — week 10

Nine weeks of logs and seven weeks of photos with no export. A dropped phone, a
failed Drift migration or a bad `flutter clean` ends the project.

**Fix:** doc 03, Phase 2. Backup and export ship in the same phase as the database.

---

## High — would have cost results

### B1. "Upper A · Push" has 16 pressing sets and zero pulling sets

Its own `note` reads: *"Chest, shoulders and triceps, with one rowing movement in
the middle so your shoulders don't end the block rounded forward."*

There is no rowing movement. The six prescriptions are bench, overhead press, ring
dip, incline DB press, skullcrusher, lateral raise. Upper B is the mirror image —
14 pull sets, zero push.

That is a push/pull split wearing an upper/lower label, and it is the precise
shoulder problem the note claims to prevent.

### B2. Every main lift is trained once a week — a downgrade from weeks 1–4

Measured pattern frequency in v1's Build block:

```
horizontalPush 1x   verticalPush 1x   squat 1x
horizontalPull 1x   verticalPull 1x   hinge 2x
```

Foundation gives a novice three full-body sessions a week. Build drops every main
lift to one exposure. For a beginner — whose limiting factor is motor learning, not
recovery — that is backwards. Frequency is the single highest-yield variable
available at this training age.

**Fix:** doc 01. v2's Build block gives every pattern **two exposures a week**, and
every upper day contains both a press and a pull.

### B3. Sessions are ~75 minutes, not the 55 in the data

Computed from the actual prescriptions — work time, prescribed rests, and the
warm-up and cool-down `estMinutes`:

| Day | `estMinutes` | Computed | + ramp sets | + spinlock plate changes | Real |
|---|---|---|---|---|---|
| Upper A · Push | 55 | 62 | +5 | +10 | **~77 min** |
| Upper B · Pull | 55 | 59 | +4 | +9 | **~72 min** |
| Lower B · Hinge | 55 | 55 | +4 | +11 | **~70 min** |
| Sun · Run, Skip & Core | 40 | 65 | — | — | **~65 min** |

Spinlock loading is the hidden cost no commercial app models: every change means
unscrewing two collars, sliding plates, and screwing them back. Assembling a pair of
dumbbells from scratch is two to three minutes. v1 has six exercises across four
implements on Upper A.

**Fix:** doc 01. Five movements per day, accessories supersetted, bag work moved off
lifting days, and implement changes minimised within a session.

### B4. The Build load table is dead data

v1 §5.1 rule 1: *"No history for this `exerciseId` → suggest `startLoadKg`."*

By week 5 there **is** history for `barbell-back-squat` (Foundation trains it every
Wednesday, ending around 16.5 kg). So rule 1 never fires, rules 2–3 do, and the
engine carries 16.5 kg into Build — not the 27.5 kg the data says. The entire Build
column is fiction the app will never read.

**Fix:** doc 01 designs the handoff so no jump is needed, and doc 02 section A makes
the history-versus-cold-start precedence explicit and tested.

### B5. Squat jumps 67% between week 4 and week 5

16.5 kg → 27.5 kg. Even if B4 were fixed, that is not a week-to-week progression.

### B6. Strength targets are not reachable by the programme's own arithmetic

v1 targets a **35–42 kg bench for 5 reps** at week 12. Working the double-progression
forward from an empty bar through v1's own increments and session count lands near
26 kg. A beginner who hits every session and still misses every stated target
concludes the programme failed.

**Fix:** doc 01 publishes projections computed from the actual increments, labelled as
a **floor** rather than a target.

---

## Medium — correctness and spec gaps

| # | Finding |
|---|---|
| C1 | **Percentage ramps are unloadable near the bar.** "50% × 5" of a 20 kg bench is 10 kg — 0.5 kg per side. Ramps must be absolute and lattice-aware (doc 02, algorithm D). |
| C2 | **`defaultRir` is never consumed.** v1 §4.2's resolution algorithm applies `loadMultiplier`, `setMultiplier` and `includeFinishers` — but nothing reads `defaultRir`. Dead field on every block. |
| C3 | **`setMultiplier: 0.5` on 3 sets is undefined.** 1.5 sets. Round up, down, or nearest? Unspecified means a coin flip in the implementation. |
| C4 | **Two sources of truth for cardio.** `p2-sun-1` carries `repsMin`/`repsMax` in seconds *and* `cardioProgression` carries per-week minutes. Which wins is not stated. |
| C5 | **`unilateral: true` does not say whether `sets: 3` means 3 or 3-per-side.** Suitcase carry says "per side" in a free-text `coachNote` the app cannot parse. |
| C6 | **Timed work is smuggled through `repsMin`/`repsMax`.** A 2-minute bag round is `repsMin: 120`. Works, but every consumer has to remember the unit, and one that forgets shows "120 reps". |
| C7 | **No superset support** despite a `coachNote` describing "a 3-round circuit with the side plank and hollow hold". v2 needs supersets structurally — they are how the 60-minute cap is met. |
| C8 | **Nothing happens at week 13.** `ProgrammeCalendar.forDate` returns null past `totalWeeks`. No completion state, no next-cycle seeding. |
| C9 | **Rest timer will be inexact on Android 12+.** `flutter_local_notifications` scheduled notifications need `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` and a battery-optimisation exemption. v1 mentions `POST_NOTIFICATIONS` only. |
| C10 | **Macros do not sum.** 110 g protein + 375 g carbs + 75 g fat = 2,615 kcal, against a stated 2,700. |
| C11 | **Nutrition target is fixed for 12 weeks.** TDEE rises with bodyweight; a flat 2,700 becomes maintenance by week 10. Needs to escalate. |
| C12 | **BMR inputs were never collected.** Age and sex change the target by 400–700 kcal. Now known: male, under 25 — corrected numbers in doc 01. |
| C13 | **Ring dips in week 5** for someone who cannot yet do a pull-up. One of the hardest bodyweight pushes there is, on an unstable implement, trained alone. Demoted to a progression endpoint. |
| C14 | **Nordic curl negatives on deadlift day**, stacked with hip thrust and reverse lunge — four posterior-chain movements in one novice session, one of them maximal-eccentric. Moved to week 9+ and made optional. |
| C15 | **No pain or niggle capture.** Twelve weeks of training alone with no structured way to record that something hurt, and no link from that to substitution. |
| C16 | **Ten library exercises are unreachable** — `cat-cow`, `couch-stretch`, `leg-swing`, `bodyweight-squat` and six others exist but are referenced only in free-text warm-up strings, so they get no cues, no demo, no detail page. |

---

## Equipment the programme ignores

Confirmed present, unused by v1:

| Item | Where it belongs in v2 |
|---|---|
| **Wall cable and handle** (photos 2 and 3) | Face pulls, triceps pushdowns, straight-arm pulldowns — all things that need no plate changes, which is exactly what the 60-minute cap wants. Optional accessory slot on both upper days. |
| **Step platform** (photo 1) | Step-ups, elevated split squats, a calf-raise block that does not require standing on a plate edge. |
| **Medicine balls** (photo 1) | Optional: throws as a power warm-up. Low priority. |
| **Kettlebell** | Used in v1 for goblet squats only. Also good for suitcase carries and swings. |

---

## What v1 got right and v2 keeps

- **Programme-as-data.** The single best decision in the document. Kept verbatim.
- **Capping cardio to protect the surplus.** Correct call for a 50 kg lifter.
- **The plate solver as a first-class feature.** No commercial app models a finite
  plate collection. It is the thing that makes this app worth building.
- **Deload expressed as block multipliers**, not special-case code.
- **The photo privacy requirements.** All six are kept and made testable.
- **Denormalised `exercise_id` in `set_logs`**, so history survives programme edits.
- **The `inheritsDaysFrom` and `dayOverrides` inheritance model.** Kept, with the
  rounding and `defaultRir` holes closed.
- **Refusing to scrape exercise GIF sites, and refusing to invent YouTube URLs.**
- **"You will build the app instead of training" as the headline risk.** Correct, and
  v2 keeps Phase 1 small enough to ship in one evening for exactly that reason.
