# Keller Twelve — Android App Build Plan

**A single-user, offline-first Android training app for Saad's basement gym.**

Status: specification, with programme data ready to drop in.
Target: an installable release APK on your own phone, no Play Store, no accounts, no backend.
Execution: Claude Code on your PC, phase by phase.

Revision 2 — adds the clickable calendar and the progress-photo gallery as Phase 5,
and ships the validated programme data files.

---

## 0. How to use this document

This is a build spec, not a tutorial. It is written to be handed to Claude Code in
slices. Each phase in §7 has:

- a **Goal** (one sentence)
- **Deliverables** (files that must exist)
- **Definition of done** (how you verify it, on the phone, not in an emulator)
- a **Claude Code prompt** — paste it verbatim at the start of that phase

**Do not skip Phase 0.** Most hobby app projects die in the toolchain, not the code.
Phase 0 exists to prove you can get *any* APK onto your phone before a single feature
is written. If Phase 0 takes an evening, that evening was well spent.

**Rule for every phase: it ends with an APK installed on your phone.** No phase is
"done" because the code compiles. The app is the artefact.

### Files shipped alongside this plan

| File | What it is | Where it goes |
|---|---|---|
| `keller-twelve.json` | The full 12-week programme — 4 blocks, 14 day definitions, 54 prescriptions, cardio table, checkpoints, strength targets | `assets/programmes/` |
| `exercises.json` | 72 exercises with cues, common errors and solo-safety notes | `assets/exercises/` |
| `schema.json` | JSON Schema (draft-07) for the programme file | `assets/programmes/` |

All three are already cross-validated: schema-valid, every `exerciseId` and every
`substitutes` entry resolves, weeks 1–12 covered exactly once with no overlap, and every
`dayOverrides` entry points at a real day and prescription. Phase 1 is therefore pure
wiring, not data entry.

---

## 1. Scope

### 1.1 What this app is

A training companion for exactly one user, running exactly one programme at a time,
with the programme itself stored as editable data. It replaces:

- the HTML plan (read the day's session)
- a notes app (log every set)
- a stopwatch (rest timer, interval timer)
- mental arithmetic (what weight next session, what plates on the bar)
- a bathroom-scale spreadsheet (bodyweight trend, protein tick)
- YouTube searches mid-set (exercise demo + cues)
- a calendar (what am I doing today, what did I actually do in week 6)
- a folder of awkward mirror photos (a proper aligned progress gallery)

### 1.2 What this app is not — explicit non-goals

| Not doing | Why |
|---|---|
| User accounts, login, multi-user | One user. Every account system is pure cost here. |
| Cloud sync / server / API | Offline-first. Backup is a file export you control. |
| Social features, sharing, leaderboards | No. |
| iOS / web builds | Android only. Flutter keeps the door open; don't spend time on it. |
| Play Store publishing | Sideload the APK. No review, no policy, no signing key escrow. |
| Analytics, crash reporting, telemetry | Zero network calls except opening a YouTube link. |
| AI coaching / chat inside the app | The programme is the coaching. Keep the app dumb and fast. |
| Nutrition database / barcode scanning | Out of scope. A daily kcal + protein number you type is enough. |
| GPS run tracking | Your phone already has a running app. This records that the run happened. |
| Photos leaving the device, ever | See §6.3. This is a hard constraint, not a preference. |

### 1.3 The one design principle

> **The programme is data, not code.**

Every set, rep, rest interval, cue, day name and exercise lives in JSON. The app is a
renderer, a logger and a calculator over that JSON. This is what makes it "super
customisable": to change the programme you edit data — in-app, or by dropping a file —
and you never touch Dart to do it.

Corollary: hardcoding "4 × 6–8 bench press" anywhere in a widget is a bug, even if it
renders correctly.

---

## 2. Tech decision

### 2.1 Recommendation: **Flutter (Dart)**

| Option | Verdict |
|---|---|
| **Flutter** | **Chosen.** One `flutter build apk` to a sideloadable artefact. Best-in-class local DB options, strong animation/timer/camera/video story, enormous package ecosystem for exactly the pieces needed here. Claude Code is very strong in Dart. Door stays open to desktop/iOS at zero cost today. |
| Kotlin + Jetpack Compose | Smallest and fastest APK, best platform integration. But more Android-specific boilerplate per feature, and Gradle/Compose churn eats time. Pick this only if you *want* to learn Android natively as a side goal. |
| .NET MAUI / Blazor Hybrid | Tempting — reuses your Blazor experience from the SmarTracks work. But Android MAUI tooling is the heaviest of the three, APKs are large, and the hot-reload loop is the worst. Skip. |
| React Native / Expo | Fine, but you gain nothing over Flutter here and inherit the JS dependency surface. |
| Capacitor wrapper around the existing HTML | Fastest path to "an APK exists" — about an hour. But a WebView can't do a proper background rest timer, local DB, or camera capture with a live overlay. Dead end for Phases 2+. |

**Decision: Flutter, stable channel.** If Phase 0 reveals a broken Android toolchain on
your machine and you want an APK on the phone tonight, the Capacitor wrapper is a
legitimate 1-hour stopgap — but treat it as a throwaway, not as Phase 1.

### 2.2 Stack

| Concern | Choice | Why |
|---|---|---|
| Language / framework | Flutter 3.x stable, Dart 3 | — |
| State management | **Riverpod** (`flutter_riverpod`, `riverpod_annotation`) | Compile-safe, testable, no BuildContext gymnastics. |
| Local database | **Drift** (SQLite, type-safe) | You will want real queries: "best set for back squat", "last 8 weeks bodyweight", "sets per muscle group per week". Do not use a key-value store for logs. |
| Settings / small state | `shared_preferences` | Bar weights, theme, active programme id, scheduling mode. |
| Programme files | JSON in `assets/programmes/` + user overrides in app documents dir | Asset is the shipped default; the file is the editable copy. |
| Routing | `go_router` | Deep-linkable, testable. |
| Charts | `fl_chart` | Bodyweight trend, e1RM trend, weekly volume. |
| Calendar grid | `table_calendar` for paging/scaffolding, **cells hand-built via `calendarBuilders`** | Don't fight a package's cell API — you need fully custom cells (§6.2). The package is worth it only for month paging and date maths. |
| Camera — progress photos | **`camera`** (live preview, needed for the ghost overlay) | `image_picker` cannot render an overlay over the viewfinder. The overlay is the whole point (§6.3). |
| Camera — form clips | `image_picker` in video mode | Much simpler, and form clips don't need alignment. |
| Video playback | `video_player` + `chewie` | Form clips. |
| Image processing | `image` (Dart) | Resize/compress photos to 1920px long edge, q85. |
| Section lock | `local_auth` | Optional biometric gate on the progress gallery. |
| Keep screen awake | `wakelock_plus` | Non-negotiable. A phone that sleeps mid-session is useless. |
| Timers + notifications | `flutter_local_notifications` + `audioplayers` | Rest and interval timers must fire with the screen off. Needs `POST_NOTIFICATIONS` on Android 13+. |
| Haptics | `flutter/services` `HapticFeedback` | Timer end buzz. Better than sound in a basement. |
| File import/export | `file_picker` + `path_provider` + `share_plus` + `archive` | Backup/restore zip, programme import. |
| Open YouTube demos | `url_launcher` | Launches the YouTube app. |
| IDs, dates | `uuid`, `intl` | — |

### 2.3 Deliberately avoided

- No Firebase, no Supabase, no auth SDK, no ad SDK, no analytics SDK.
- No `MediaStore` / gallery writes for progress photos. Ever. See §6.3.
- No code generation beyond Drift + Riverpod (both worth it; anything more is drag).

---

## 3. Architecture

### 3.1 Layers

```
lib/
├── main.dart
├── app.dart                      # MaterialApp.router, theme, providers scope
├── core/
│   ├── theme/                    # tokens: colors, type scale, spacing
│   ├── extensions/
│   └── util/
├── domain/                       # PURE DART. No Flutter imports. No I/O.
│   ├── models/                   # Programme, Block, Day, ExercisePrescription, Exercise,
│   │                             #   SetLog, Session, BodyweightEntry, PlateInventory,
│   │                             #   ProgressPhoto, PhotoPose, Measurement
│   ├── progression/              # progression engine       ← unit tested, §5.1
│   ├── plates/                   # plate solver             ← unit tested, §5.2
│   ├── calendar/                 # programme date projection ← unit tested, §5.3
│   ├── intervals/                # interval timer engine     ← unit tested
│   └── metrics/                  # e1RM, volume, trend       ← unit tested
├── data/
│   ├── db/                       # Drift database, tables, DAOs
│   ├── programme_repository.dart  # asset JSON + user override file + inheritance resolution
│   ├── exercise_repository.dart
│   ├── media_repository.dart      # photos + clips on disk, app-private only
│   └── settings_repository.dart
├── features/
│   ├── today/                    # the home screen
│   ├── session/                  # the session runner (the core loop)
│   ├── calendar/                 # month grid, day sheet, retroactive logging
│   ├── progress/                 # photo capture, gallery, compare, measurements
│   ├── programme/                # programme browser + editor
│   ├── exercises/                # exercise library, demos, form clips
│   ├── cardio/
│   ├── body/                     # bodyweight, food tick
│   ├── stats/
│   └── settings/
└── assets/
    ├── programmes/keller-twelve.json
    ├── programmes/schema.json
    ├── exercises/exercises.json
    ├── exercises/img/            # bundled form stills (licence-clean, §8)
    └── sounds/
```

**The hard rule:** `domain/` has zero Flutter imports and zero I/O. The progression
engine, plate solver and calendar projection are pure functions over plain Dart objects.
This is what makes them unit-testable without a device, and they are the three places
where a bug silently ruins months of training data.

### 3.2 Data flow

```
assets/programmes/keller-twelve.json  ──┐
                                        ├─→ ProgrammeRepository ─→ Riverpod ─→ UI
app documents/programmes/active.json  ──┘   (override wins; resolves
                                             inheritsDaysFrom + dayOverrides)

SQLite (Drift): sessions, set_logs, bodyweight, cardio_logs, food_logs,
                progress_photos, measurements, form_clips, stall_counters
        ↑                          ↓                        ↓
  SessionRunner            ProgressionEngine        CalendarProjection
    writes                  reads history            reads programme

app-private files/: photos/<shootId>/<poseId>.jpg   ← never in MediaStore
                    clips/<exerciseId>/<ts>.mp4
```

### 3.3 Why the override file matters

Shipped asset = the pristine Keller Twelve. User file = your edited version. On first
launch the asset is copied to the documents dir. All edits write the file. The asset is
never mutated, so "reset to original" is always one delete away, and a bad edit in the
in-app editor can never brick the app.

---

## 4. Data model

Concrete enough for Claude Code to generate from, and matching the shipped JSON exactly.
Kilograms only — no unit switching. You're in Germany; this is a feature, not a limitation.

### 4.1 `Programme`

```json
{
  "id": "keller-twelve",
  "name": "The Keller Twelve",
  "schemaVersion": 1,
  "revision": 1,
  "startDate": "2026-09-21",
  "totalWeeks": 12,
  "notes": "…",
  "athlete":          { "startWeightKg": 50.0, "heightCm": 167, "targetWeightKg": 55.0, "experience": "beginner", "trainsAlone": true },
  "nutritionTargets": { "kcal": 2700, "proteinG": 110, "carbsG": 375, "fatG": 75, "gainKgPerWeek": 0.3, "flatWeeksBeforeBump": 2, "kcalBumpWhenFlat": 300 },
  "rules":            ["Eat in surplus every single day…"],
  "cardioProgression":[ /* per-week run/skip targets */ ],
  "checkpoints":      [ /* weeks 1, 4, 8, 12 — photos, waist, tests */ ],
  "strengthTargets":  [ /* per-lift week-4 and week-12 targets */ ],
  "blocks":           [ /* Block[] */ ]
}
```

### 4.2 `Block`

```json
{
  "id": "build",
  "name": "Build",
  "weeks": [5, 6, 7],
  "defaultRir": 2,
  "loadMultiplier": 1.0,
  "setMultiplier": 1.0,
  "includeFinishers": true,
  "summary": "…",
  "inheritsDaysFrom": null,
  "dayOverrides": {},
  "days": [ /* Day[] */ ]
}
```

Two mechanisms do a lot of work here and must be implemented exactly:

**`loadMultiplier` / `setMultiplier` / `includeFinishers`** express the week-8 deload as
*data*: `{ weeks: [8], loadMultiplier: 0.6, setMultiplier: 0.5, includeFinishers: false }`.
No special-case deload code anywhere.

**`inheritsDaysFrom` + `dayOverrides`** let the Deload and Push blocks reuse the Build
block's days without duplicating them. Resolution order:

```
1. deep-copy the source block's days
2. apply block-level loadMultiplier / setMultiplier / includeFinishers
3. apply dayOverrides[dayId].prescriptionOverrides[prescriptionId]   (shallow merge)
4. apply dayOverrides[dayId].weekSpecific[weekNo].prescriptionOverrides[…]  (shallow merge)
```

Step 4 is how week 12's Sunday run becomes the 5K time trial. A block must have either
`days` or `inheritsDaysFrom`, never both — the validator enforces this, and so should
the loader.

The in-app editor (Phase 8) offers **"detach and duplicate"** on an inheriting block,
which materialises the resolved days into real `days` and clears the inheritance. That
keeps the shipped file compact while letting you diverge later.

### 4.3 `Day`

```json
{
  "id": "p2-mon",
  "weekday": "mon",
  "title": "Upper A · Push",
  "kind": "lift",
  "optional": false,
  "estMinutes": 55,
  "note": "Chest, shoulders and triceps, with one rowing movement in the middle…",
  "warnings": [
    { "title": "Catch pins, every session", "body": "Bench press pins at chest height…" }
  ],
  "sections": [ /* Section[] */ ]
}
```

`kind`: `lift` | `cardio` | `rest` | `mobility` — drives the calendar cell colour.
`optional: true` (the Wednesday run) means the calendar shows it dashed and skipping it
doesn't break the adherence streak.
`warnings` render as a dismissible banner at the top of the session runner. The deadlift
bar-height note and the ceiling-clearance note live here — they're the ones that matter
before your first rep, not buried in a cue list.

### 4.4 `Section`

```json
{
  "type": "warmup",
  "title": "Warm-up",
  "estMinutes": 8,
  "freeItems": [
    "Skipping 3 min · band pull-apart 2 × 20 · push-up × 10 · empty-bar bench × 15",
    "Ramp-up on the bench: 50% × 5, 70% × 3, 85% × 1. Every session, no skipping it."
  ],
  "prescriptions": []
}
```

`type`: `warmup` | `main` | `finisher` | `cooldown` | `cardio`
Warm-ups and cool-downs are free text — you tick them, you don't log them. Main work,
finishers and cardio carry `prescriptions`.

### 4.5 `ExercisePrescription`

```json
{
  "id": "p2-mon-1",
  "exerciseId": "barbell-bench-press",
  "order": 1,
  "sets": 4,
  "repsMin": 6,
  "repsMax": 8,
  "restSec": 150,
  "targetRir": 2,
  "loadMode": "barbell",
  "startLoadKg": 20.0,
  "progression": { "type": "doubleProgression", "incrementKg": 2.5, "deloadPct": 0.10, "stallLimit": 2 },
  "substitutes": ["dumbbell-bench-press", "dumbbell-floor-press"],
  "coachNote": "Bar to the lower chest, elbows at 45–60°…",
  "tempo": null,
  "unilateral": false
}
```

`loadMode`: `barbell` | `ezBar` | `dumbbellPair` | `dumbbellSingle` | `kettlebell` |
`bodyweight` | `bodyweightLoaded` | `banded` | `timed` | `distance`

It drives three things: which plate-solver path runs, what the log input widget looks
like, and whether bodyweight is folded into the e1RM estimate.

`progression.type`: `doubleProgression` | `repsOnly` | `timeOnly` | `bandProgression` |
`cardioTable` | `none`. Band and bodyweight movements progress by band colour or leverage,
not kilograms — those log the setup in the set note and the engine suggests "thinner
band" rather than a number.

For `timed` and `distance` modes, `repsMin`/`repsMax` carry **seconds** or **metres**.
A 3 × 2 min bag round is `sets: 3, repsMin: 120, repsMax: 120, loadMode: "timed"`.

### 4.6 `Exercise` (library, separate from programme)

```json
{
  "id": "barbell-bench-press",
  "name": "Barbell bench press",
  "aliases": ["bench", "flat bench"],
  "pattern": "horizontalPush",
  "primaryMuscles": ["chest", "triceps"],
  "secondaryMuscles": ["frontDelts"],
  "equipment": ["barbell", "bench", "squatStand"],
  "defaultLoadMode": "barbell",
  "cues": ["Feet planted, shoulder blades pinched back and down…"],
  "commonErrors": ["Elbows flared to 90° — the fastest route to shoulder pain…"],
  "soloSafety": "The most dangerous lift in the room for a solo lifter. Set the catch pins…",
  "media": { "still": null, "stillLicence": null, "stillSearchTerm": "barbell bench press", "youtubeUrl": null, "youtubeStartSec": 0 },
  "substitutes": ["dumbbell-bench-press", "dumbbell-floor-press", "push-up-handles"],
  "tags": ["mainLift", "soloRisk"],
  "equipmentNote": null,
  "progressionNote": null
}
```

`media.still` and `media.youtubeUrl` ship as `null` on purpose — Phase 6 fills them.
`stillSearchTerm` is a matching hint for `free-exercise-db`, **not** a verified slug.
`primaryMuscles` is what drives the weekly sets-per-muscle-group chart, so keep it honest.

### 4.7 Drift tables

```
sessions(
  id INTEGER PK, programme_id TEXT, block_id TEXT, day_id TEXT, week_no INTEGER,
  planned_date DATE,            -- where the programme says it belongs
  scheduled_date DATE,          -- where you moved it to (usually == planned_date)
  started_at DATETIME NULL, finished_at DATETIME NULL,
  status TEXT,                  -- planned | inProgress | completed | partial | skipped
  bodyweight_kg REAL NULL, rpe_overall INTEGER NULL, note TEXT NULL,
  logged_retroactively BOOLEAN DEFAULT 0
)

set_logs(
  id INTEGER PK, session_id INTEGER FK, prescription_id TEXT,
  exercise_id TEXT,             -- DENORMALISED on purpose: survives programme edits
  set_index INTEGER,
  target_reps_min INTEGER, target_reps_max INTEGER, target_load_kg REAL NULL,
  reps INTEGER, load_kg REAL NULL, duration_sec INTEGER NULL, rir INTEGER NULL,
  is_warmup BOOLEAN DEFAULT 0, completed_at DATETIME, note TEXT NULL
)

stall_counters(exercise_id TEXT PK, count INTEGER, updated_at DATETIME)

bodyweight(id INTEGER PK, measured_on DATE UNIQUE, kg REAL, note TEXT NULL)

cardio_logs(
  id INTEGER PK, session_id INTEGER NULL, kind TEXT,   -- run | skip | bag
  measured_on DATE, duration_sec INTEGER NULL, distance_m INTEGER NULL,
  rounds INTEGER NULL, effort INTEGER NULL, note TEXT NULL
)

food_logs(id INTEGER PK, logged_on DATE UNIQUE, kcal INTEGER NULL,
          protein_g INTEGER NULL, hit_target BOOLEAN, note TEXT NULL)

-- Phase 5 ----------------------------------------------------------------
photo_shoots(
  id TEXT PK,                   -- uuid; one shoot = one session in front of the phone
  shot_on DATE, week_no INTEGER NULL,
  bodyweight_kg REAL NULL,      -- resolved from bodyweight within ±2 days
  note TEXT NULL
)

progress_photos(
  id TEXT PK, shoot_id TEXT FK, pose_id TEXT,
  file_path TEXT,               -- app-private; NEVER a MediaStore uri
  width INTEGER, height INTEGER, bytes INTEGER,
  taken_at DATETIME
)

photo_poses(id TEXT PK, name TEXT, order_index INTEGER,
            guidance TEXT NULL, enabled BOOLEAN DEFAULT 1)

measurements(id INTEGER PK, measured_on DATE, site TEXT, cm REAL,
             UNIQUE(measured_on, site))

form_clips(id TEXT PK, exercise_id TEXT, file_path TEXT,
           recorded_at DATETIME, duration_sec INTEGER, bytes INTEGER, note TEXT NULL)
```

**Why `exercise_id` is denormalised into `set_logs`:** you will swap exercises in the
programme editor. Logs must survive that. Never join history through the live programme
JSON.

**Why `planned_date` and `scheduled_date` are separate:** life moves sessions. Adherence
is measured against `planned_date`; the calendar draws the session on `scheduled_date`.

---

## 5. The algorithms that matter

Everything else in this app is forms and lists. These are the brain. They must be pure
functions in `domain/`, and they must have unit tests **written before** the UI that
calls them.

### 5.1 Progression engine

**Input:** an `ExercisePrescription`, the set logs from the most recent completed session
containing that `exerciseId`, the current block's `loadMultiplier`, the stall counter,
and the plate inventory.

**Output:** `LoadSuggestion { suggestedKg, reason, achievableKg, plateBreakdown, isStalled }`.

Rules, in order:

```
1. No history for this exerciseId
   → suggest prescription.startLoadKg, reason = "programme start"

2. Last session: every working set hit repsMax AND every logged rir >= targetRir
   → suggest lastLoad + progression.incrementKg, reason = "earned the jump"

3. Last session: all sets landed within [repsMin, repsMax] but not all at repsMax
   → suggest lastLoad (same weight, add reps), reason = "add reps at this weight"

4. Last session: any working set fell below repsMin
   → increment the stall counter for this exerciseId
     4a. stallCount < progression.stallLimit
         → suggest lastLoad, reason = "repeat — stall 1 of 2"
     4b. stallCount >= progression.stallLimit
         → suggest lastLoad * (1 - deloadPct), rounded DOWN to achievable,
           reset stall counter, reason = "back off 10% and build up"

5. Apply block.loadMultiplier (deload weeks)
6. Round to nearest ACHIEVABLE load via the plate solver (§5.2), rounding DOWN
7. Never suggest a jump larger than 10% of lastLoad in one step — clamp and flag
```

Non-kilogram progression types short-circuit at step 1:
`repsOnly` → suggest the same setup, target +1 rep. `timeOnly` → target +`incrementSec`.
`bandProgression` → surface the last logged band note plus "move to a thinner band when
you hit `repsMax` on all sets". `cardioTable` → read the target straight off
`programme.cardioProgression` for the current week. `none` → nothing.

**Test cases that must exist:**

- First-ever session → returns `startLoadKg`.
- 4×8 at 8,8,8,8 reps with RIR 2 on `4 × 6–8` → +2.5 kg.
- 4×8 at 8,8,7,6 → same weight.
- 4×8 at 8,6,5,5 → stall 1, same weight.
- Two consecutive stalls → −10%, rounded down to achievable, counter reset.
- Deload block (`loadMultiplier: 0.6`) → 60% of suggestion, still achievable.
- A suggestion that isn't loadable with the inventory → rounds down, never up.
- Exercise swapped for a substitute → history for the *substitute* is used if present,
  otherwise its own `startLoadKg` (do not inherit the original's load).
- `repsOnly`, `timeOnly`, `bandProgression`, `cardioTable`, `none` each return the right
  shape and never a kilogram suggestion.

### 5.2 Plate solver — the feature nobody else's app has for your gym

You have spinlock standard bars and a fixed, finite plate collection. Generic apps assume
infinite 20 kg Olympic plates and round to 2.5 kg. Yours should know exactly what you own.

**Configured inventory** (Settings, editable — these are estimates from the photos;
correct them once you've put the bars on a bathroom scale):

```json
{
  "bars": [
    { "id": "barbell",  "name": "Standard barbell", "weightKg": 9.0 },
    { "id": "ezBar",    "name": "EZ curl bar",      "weightKg": 6.0 },
    { "id": "dbHandle", "name": "Dumbbell handle",  "weightKg": 2.0 }
  ],
  "plates": [
    { "weightKg": 20.0, "count": 2 },
    { "weightKg": 10.0, "count": 4 },
    { "weightKg": 5.0,  "count": 8 },
    { "weightKg": 2.5,  "count": 8 },
    { "weightKg": 1.25, "count": 8 }
  ],
  "collarWeightKg": 0.0
}
```

**Function:** `solve(targetKg, loadMode, inventory) → PlateSolution`

```
barbell / ezBar:
  perSide = (target - barWeight) / 2
  greedy from heaviest plate, limited to floor(count / 2) pairs of each size
  → { achievableKg, perSide: [{kg, n}], deltaFromTarget }

dumbbellPair:
  perHandleSide = (target - handleWeight) / 2      // target is PER dumbbell
  each plate size consumes 4 plates (2 sides × 2 handles) → floor(count / 4)

dumbbellSingle:
  as above, consumes 2 plates per size → floor(count / 2)

kettlebell:
  fixed increments from the inventory's kettlebell list; no solve

bodyweight / banded / timed / distance:
  no solve. bodyweightLoaded solves the added weight only.
```

**Requirements:**

- Return the **closest achievable at or below** the target, plus the closest above, so
  the UI can offer both.
- Plate breakdown as text you can read while loading the bar:
  `27.5 kg = bar 9 + (5 + 2.5 + 1.25) per side`.
- Flag when a plate is **contended**: if a session has you loading dumbbells and the
  barbell with the same 5 kg plates, the solver can't satisfy both at once. Warn, don't
  block. This is a genuinely annoying real-world problem with one plate set, and the app
  earning its keep.
- **Microplate gap hint:** if the smallest achievable jump on a lift exceeds 5% of the
  current load, say so. It will fire on the overhead press almost immediately, which is
  how you discover you need a second pair of 1.25 kg plates.

**Test cases:** exact hits, unachievable targets, inventory exhausted mid-solve, dumbbell
pair halving the budget, empty-bar case, target below bar weight, contention detection.

### 5.3 Calendar projection

The function that makes the calendar work. Pure, tested, no I/O.

**`ProgrammeCalendar.forDate(DateTime date) → PlannedDay?`**

```
anchor   = Monday of the ISO week containing programme.startDate
weekNo   = ((date - anchor).inDays ~/ 7) + 1
if weekNo < 1 or weekNo > programme.totalWeeks  → null (outside the programme)

block    = the block whose weeks contains weekNo        (validator guarantees exactly one)
days     = block.days, or resolve(block.inheritsDaysFrom) + overrides  (§4.2)
day      = days.firstWhere(weekday == date.weekday)     → null if none defined
return PlannedDay(date, weekNo, block, day, multipliersApplied)
```

Week 1 is Monday-anchored even if `startDate` falls mid-week, because the programme's
days are keyed by weekday. Days before `startDate` in week 1 return `null`.

**Two scheduling modes**, a setting, default `fixed`:

| Mode | Behaviour | Trade-off |
|---|---|---|
| **`fixed`** (default) | Dates are dates. Week 6 is week 6 whether or not you trained in week 5. Missed sessions are simply missed. | Honest adherence data. You see the truth. |
| `rolling` | Week advances only once you've completed *n* sessions of the current week. | Nothing is ever "missed", but week numbers drift from the calendar and the cardio table desynchronises. |

Recommendation: `fixed`, plus a **"shift programme"** action that moves `startDate`
forward by whole weeks when you genuinely lose a week to illness or travel. That keeps
the data honest without punishing you for a real interruption.

**Also needed:**

- `sessionsForRange(from, to)` → merges projected planned days with actual `sessions`
  rows, so a month renders in one query rather than 31.
- `adherence(from, to)` → completed ÷ (planned, excluding `optional` days), as a
  percentage, plus the current streak.
- Moving a session: write `scheduled_date` ≠ `planned_date`. The calendar draws it on
  `scheduled_date`; adherence still counts it against its `planned_date` week.

**Test cases:** `startDate` on a Monday and on a Thursday; dates before `startDate`;
week 1 / 8 / 12 boundaries; a date past week 12; a weekday with no day defined; deload
week returns multipliers applied; week 12 Sunday resolves to the 5K time trial via
`weekSpecific`; a rescheduled session appears on its new date but counts in its old week.

### 5.4 Interval timer engine

Drives the rest timer, the skipping intervals and the bag rounds from one tested source.

```
IntervalSpec { rounds, workSec, restSec, prepareSec, label }
→ emits a stream of IntervalTick { round, phase (prepare|work|rest|done), secondsLeft }
```

Must be wall-clock based (compare against an end timestamp), never a tick counter — a
counter drifts and stops when Android suspends the isolate. The notification is what
survives the screen going off; the in-app countdown is cosmetic.

---

## 6. The two new surfaces, specified

### 6.1 Why they're one phase

The calendar and the progress gallery are both time-indexed views of history over the
same date axis: a shoot hangs off a date, a session hangs off a date, a weigh-in hangs
off a date. Build the date-indexed data layer once and both fall out of it.

### 6.2 The calendar

**Layout — month grid**

- 7 columns, **Monday-first** (German convention, and the programme is weekday-keyed).
- Swipe between months, a "jump to today" button, and a week-strip mode for one-handed
  in-gym use.
- Header shows: month and year · programme week (`Week 6 of 12 · Build`) · adherence for
  the block so far · current streak.
- Week numbers down the left gutter, showing **programme** week (1–12), not ISO week.
  Weeks outside the programme are greyed.

**The cell** — this is where the design work is. Each cell carries, at a glance:

```
┌─────────────┐
│ 23      ●   │  ← day number; dot cluster top-right
│ ▔▔▔▔▔▔▔▔    │  ← 3px rail, coloured by day.kind
│ Upper A     │  ← short label, one line, ellipsised
│ ✓           │  ← state glyph
└─────────────┘
```

| Element | Encodes |
|---|---|
| Rail colour | `day.kind` — lift (oxblood), cardio (moss), rest (grey), mobility (muted) |
| Rail style | solid for required, dashed for `optional: true` |
| State glyph | `✓` completed · `◐` partial · `✕` skipped · `▶` in progress · none for planned · `↷` rescheduled |
| Fill | today gets a ring; past planned-but-unlogged gets a faint warning tint |
| Dots | one small dot each for: bodyweight logged · food target hit · photo shoot · cardio logged |

Colour alone must never carry the state — the glyph does. Assume you're looking at this
in bad basement light.

**Tap behaviour, by what the day is:**

| Day | Tap |
|---|---|
| Today, planned, not started | Day sheet with **Start session** as the primary action |
| Today, in progress | Jump straight back into the session runner |
| Past, completed | Read-only log: every set, load, RIR, session note, duration |
| Past, planned but unlogged | Day sheet offering **Log retroactively** and **Mark skipped** |
| Future | Planned session preview — exercises, targets, suggested loads |
| Rest day | The rest-day note, plus the bodyweight and food entry for that date |
| Outside programme | Nothing, or bodyweight/food entry only |

**Long-press menu:** log retroactively · move this session to another date · mark skipped
· add a note · add a photo shoot for this date.

**Retroactive logging is not optional.** You will forget to open the app mid-session at
least a dozen times over twelve weeks. If the only way to record a session is live, the
data set will have holes and the progression engine will suggest wrong loads off stale
history. The retroactive flow is the same runner UI with the date pre-set and
`logged_retroactively = 1`.

**Also in this surface:**

- An **agenda list** view for the current week — easier to scan than a grid when you just
  want to know what's tomorrow.
- **Checkpoint markers** on weeks 1, 4, 8 and 12, read from `programme.checkpoints`,
  which open the checklist (photos, waist, tests) for that week.
- A **week-8 deload banner** across that week, because it's the week you'll be most
  tempted to ignore.

**Definition of done for the calendar:** you open it in week 7, see at a glance that you
missed one Thursday in week 5 and skipped two optional Wednesdays, tap the missed
Thursday, log it retroactively from memory, and the progression engine picks that history
up on your next pull day.

### 6.3 Progress photos

Four features make a progress gallery actually useful rather than a folder of unusable
photos. Most apps ship one of them.

**1. Aligned capture — the ghost overlay**

The reason progress photos usually prove nothing is that the distance, angle, lighting
and pose all drift. So the capture screen shows the **previous photo of the same pose as
a semi-transparent overlay on the live viewfinder**, at ~30% opacity, with a toggle and
an opacity slider. You line yourself up against your past self and press the shutter.

This requires the `camera` plugin's live preview with a `Stack` overlay — `image_picker`
hands off to the system camera app and cannot do it. That's the reason for the extra
dependency, and it's worth it.

Alongside the ghost: rule-of-thirds grid lines, a **3-2-1 self-timer** (you're propping
the phone on the bench, not holding it), and a one-line reminder of the pose's guidance.

**2. A fixed pose set**

Default poses, seeded into `photo_poses`, editable:

| id | name | guidance |
|---|---|---|
| `front-relaxed` | Front relaxed | Arms at your sides, shoulders down, completely relaxed. No flexing. |
| `front-flexed`  | Front flexed  | Same stance, everything braced. |
| `side-right`    | Side (right)  | Right shoulder to the camera, arms hanging naturally. |
| `back`          | Back          | Arms at your sides, lats relaxed. |

One **shoot** = one pass through all enabled poses on one date. Shoots are the unit you
compare, not individual photos.

**3. Comparison that shows something**

- **Side by side:** pick two shoots, see the same pose next to each other, with each
  photo's date, programme week and bodyweight captioned underneath.
- **Wipe slider:** the two images stacked with a draggable divider. This is the one that
  actually reveals change.
- **Flipbook:** scrub or auto-play through every photo of one pose chronologically. Four
  months of weekly shoots played as ~16 frames is the single most motivating thing the
  app will do.
- Bodyweight is resolved automatically from the `bodyweight` table (nearest entry within
  ±2 days) so captions are never empty.

**4. Measurements on the same axis**

Waist, chest, upper arm, thigh and neck, entered at checkpoint weeks, charted alongside
the photos. The waist number is the one that tells you whether the surplus is too big —
if the waist is growing faster than the lifts, trim 200 kcal.

**Privacy — hard requirements, not preferences**

These are shirtless photos of you. Treat the storage design as part of the feature:

1. **App-private storage only.** Write to the app's internal files directory
   (`getApplicationDocumentsDirectory()`), never to `MediaStore`, never to
   `/sdcard/Pictures`, never via `image_picker`'s default save. Photos must not appear in
   the phone's gallery app, and must not be picked up by Google Photos sync.
2. **Excluded from Android auto-backup.** Set `android:allowBackup="false"` on
   `<application>`, or ship `@xml/backup_rules` excluding the photo directory. Otherwise
   Android may upload them to the user's Google Drive backup silently.
3. **Optional lock.** A biometric/PIN gate on the progress section via `local_auth`, off
   by default, one toggle in Settings.
4. **No network, ever.** No upload path, no share-to-cloud, no "sync". Export exists, and
   it is an explicit, manual, one-photo-or-one-zip action you initiate.
5. **Delete means delete.** Removing a photo removes the file, not just the row. Removing
   a shoot removes its directory.
6. Thumbnails cached in app-private storage too. No `.thumbnails` in shared space.

**Storage budget**

JPEG, quality 85, resized to a 1920px long edge — roughly 400–600 KB per photo.
4 poses × weekly × 52 weeks ≈ 200 photos ≈ 100 MB. Fine, but bound it: a configurable
budget (default 500 MB across photos and form clips), a usage readout in Settings, and a
warning before it's exceeded. Form clips are the real consumer — 720p video is ~60 MB a
minute.

**Reminders**

At checkpoint weeks (1, 4, 8, 12, read from `programme.checkpoints`) the calendar shows a
marker and the dashboard shows a card: *"Week 8 checkpoint — photos, waist, and the
deload starts Monday."* No nagging outside those weeks.

**Definition of done for the gallery:** at week 8 you take four photos in about ninety
seconds, each lined up against the week-4 ghost, and the wipe slider shows you something
the mirror hasn't.

---

## 7. Phases

Ten phases. Each ends with an APK on your phone.

---

### Phase 0 — Toolchain to phone

**Goal:** an unmodified Flutter counter app, built as a release APK, installed on your
phone, launched.

**Why first:** if Gradle, the JDK, the Android SDK licences, or USB debugging are going
to fight you, find out now on code you don't care about.

**Deliverables**
- Flutter SDK on stable, `flutter doctor -v` with no red for Android
- Android SDK + platform-tools (via Android Studio is the least painful route)
- JDK 17 (Flutter's current Gradle expects 17, not 21 — pin it)
- `keller_twelve/` project created, git initialised, first commit
- `app-arm64-v8a-release.apk` installed on the phone

**Steps**

```bash
flutter --version                       # stable channel
flutter doctor -v                       # resolve every Android-related issue
flutter create --org de.saad --platforms=android keller_twelve
cd keller_twelve
git init && git add -A && git commit -m "chore: flutter create"

# phone: Settings → About → tap Build number 7× → Developer options
#        → enable USB debugging (and Wireless debugging if you prefer)
adb devices                             # must list your phone, not "unauthorized"

flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Wireless alternative (nicer, no cable):
```bash
adb pair <phone-ip>:<pair-port>         # code from the Wireless debugging screen
adb connect <phone-ip>:<debug-port>
```

**Definition of done:** the counter app launches from your app drawer, from an APK you
built, with the cable unplugged.

**Gotchas**
- JDK 21 + older Gradle = cryptic Kotlin/Gradle failures. Install JDK 17 and set
  `org.gradle.java.home` in `android/gradle.properties` if needed.
- `flutter doctor --android-licenses` must be accepted or release builds fail late.
- Xiaomi/Redmi/Realme: also enable "Install via USB" in Developer options and disable
  MIUI optimisation. This one wastes hours if you don't know it.
- `--split-per-abi` gives you a ~8 MB arm64 APK instead of a ~20 MB fat one. Always use it.

**Claude Code prompt**

```
Phase 0 of keller-twelve-app-plan.md. Do not write any app features.

1. Run `flutter doctor -v` and fix every Android-related issue, explaining each fix
   before you make it. My JDK must be 17 — check and tell me if it isn't.
2. Create the project: `flutter create --org de.saad --platforms=android keller_twelve`
3. Set up git with a Flutter .gitignore and make the first commit.
4. Configure android/app/build.gradle: minSdk 24, targetSdk to the current default,
   applicationId de.saad.kellertwelve, versionName 0.1.0.
5. Build `flutter build apk --release --split-per-abi` and give me the exact adb
   command to install the arm64 APK.

Stop after that. Do not start Phase 1.
```

---

### Phase 1 — Programme as data, read-only viewer

**Goal:** the shipped programme JSON loads, resolves, and renders as a browsable week.
This alone already replaces the HTML page.

**Deliverables**
- `domain/models/*` — the full model set from §4, immutable, with `fromJson`/`toJson`
- The three shipped files placed in `assets/` and wired into `pubspec.yaml`
- `ProgrammeRepository`: load asset → copy to documents dir on first run → read override
- **Inheritance resolution** per §4.2 — `inheritsDaysFrom`, `dayOverrides`,
  `weekSpecific`, and the block multipliers. Unit tested.
- A test that validates the programme JSON against `schema.json` and asserts every
  `exerciseId` and `substitutes` entry resolves in the library
- Screens: **Today** (which day is it), **Week** (7 day cards), **Day detail** (sections,
  prescriptions, cues, warnings)
- Theme: dark-first, high contrast, large tap targets, readable at arm's length in bad
  basement light

**Definition of done:** you open the app in the basement, see "Monday · Upper A · Push",
scroll the six exercises with their sets, reps, rest and cues, and never need the web
page again.

**Claude Code prompt**

```
Phase 1 of keller-twelve-app-plan.md.

The programme data already exists and is validated — I'm giving you keller-twelve.json,
exercises.json and schema.json. Do NOT regenerate or "improve" them; treat them as the
source of truth and make the models match the data, not the other way round.

1. Place the three files under assets/ and wire them into pubspec.yaml.
2. Implement every model in §4 as immutable Dart classes in lib/domain/models/ with
   fromJson/toJson. No Flutter imports anywhere in domain/.
3. Implement block inheritance resolution exactly as §4.2 specifies: deep-copy source
   days, apply loadMultiplier/setMultiplier/includeFinishers, then dayOverrides, then
   weekSpecific. Unit test it — including that week 12's p2-sun-1 resolves to
   five-k-time-trial and that the deload block halves sets and scales load to 60%.
4. Write a test that validates the programme JSON against schema.json and asserts every
   exerciseId and every substitutes entry resolves in the exercise library.
5. ProgrammeRepository: load from asset, copy to app documents dir on first launch,
   prefer the documents copy thereafter, never mutate the asset.
6. Riverpod providers + go_router. Screens: Today, Week, DayDetail. Render day.warnings
   as a banner at the top of DayDetail.
7. Theme in lib/core/theme/: dark-first, large type, 48dp minimum tap targets.

Then build the release APK and give me the install command.
```

---

### Phase 2 — The session runner (the core loop)

**Goal:** press Start on a day, walk through the exercises, log every set, rest timer
between them, finish the session. This is the app.

**Deliverables**
- Drift database + all Phase 1–2 tables from §4.7 + DAOs + migration strategy
- `domain/intervals/` — the interval timer engine per §5.4, wall-clock based, tested
- **Session runner screen** — the single most important UI in the app:
  - one exercise in focus at a time, swipe or tap between them
  - per-set row: target reps, an actual-reps stepper, a load field, an RIR chip
  - big "log set" button, then the rest timer starts *automatically*
  - previous session's numbers inline ("last time: 8, 8, 7 @ 25 kg")
  - `day.warnings` as a dismissible banner before the first set
  - notes per exercise and per session
- **Rest timer**: prefilled from `restSec`, runs with the screen off, notification +
  haptic + optional sound, ±15 s mid-rest, skippable
- `wakelock_plus` on while a session is in progress
- Session resume: kill the app mid-session, reopen, continue exactly where you were
- A flat history list (the proper calendar comes in Phase 5)

**Definition of done:** you complete a full Monday session using only the phone, and the
next morning every logged set is there and correct — including the one you logged after
the screen went black during the 2:30 rest.

**Notes**
- Persist on **every** set log, not on finish. Phones die.
- Input ergonomics matter more than they sound: chalky hands, between heavy sets. Steppers
  and chips over keyboards; number keyboard only when unavoidable.

**Claude Code prompt**

```
Phase 2 of keller-twelve-app-plan.md.

1. Drift: implement sessions, set_logs, stall_counters, bodyweight, cardio_logs and
   food_logs from §4.7, with DAOs and a migration strategy from schema v1.
2. domain/intervals/ — the interval timer engine per §5.4. Wall-clock based, not a tick
   counter. Unit tested.
3. Session lifecycle: startSession(dayId, date) → inProgress, logSet(...) persisted
   immediately, finishSession(). Must survive app kill — resume an inProgress session
   on launch.
4. Session runner screen per §Phase 2: one exercise in focus, per-set rows with a reps
   stepper, load field and RIR chip, a large log-set button, and last session's reps and
   load shown inline. day.warnings as a dismissible banner before the first set.
5. Rest timer: auto-starts on set log, prefilled from restSec, runs with the screen off
   via flutter_local_notifications, ends with a notification + haptic. ±15s and skip.
   Request POST_NOTIFICATIONS on Android 13+.
6. wakelock_plus for the duration of a session.
7. A flat history screen listing completed sessions, tappable to a read-only set list.

Optimise the runner for one-handed use with chalky hands: steppers and chips, not
keyboards. Then build the release APK.
```

---

### Phase 3 — Progression engine and plate solver

**Goal:** the app tells you what to put on the bar, which plates, and why.

**Deliverables**
- `domain/plates/plate_solver.dart` — pure, per §5.2
- `domain/progression/progression_engine.dart` — pure, per §5.1
- Unit tests for every case listed in §5.1 and §5.2, **written first**
- Stall tracking persisted in `stall_counters`
- Session runner integration: each exercise opens with a suggested load, the reason, and
  the plate breakdown; always overridable, and the override is what gets logged
- Settings: editable bar weights and plate inventory
- Deload handled purely by the block multipliers — no special-case code

**Definition of done:** you walk into the basement, the app says
`Back squat — 27.5 kg · bar 9 + 5 + 2.5 + 1.25 per side · earned the jump`, and it's
correct against the plates actually on the floor.

**Claude Code prompt**

```
Phase 3 of keller-twelve-app-plan.md.

Test-first. Write the unit tests from §5.1 and §5.2 BEFORE the implementations, and show
me the failing test run.

1. domain/plates/plate_solver.dart per §5.2 — all loadModes, pair/quad plate budgets,
   closest-below and closest-above, plate breakdown string, contention warning,
   microplate-gap hint. Pure Dart, no I/O.
2. domain/progression/progression_engine.dart per §5.1 — the 7 ordered rules, stall
   counting, block loadMultiplier, rounding DOWN to achievable, 10% jump clamp, and
   correct short-circuits for repsOnly / timeOnly / bandProgression / cardioTable / none.
3. Persist stall counters per exerciseId in Drift.
4. Wire into the session runner: suggested load + reason + plate breakdown at the top of
   each exercise, always overridable, override is what gets logged.
5. Settings screen for bar weights and plate inventory, seeded with §5.2's values.

Then build the release APK.
```

---

### Phase 4 — Exercise demos

**Goal:** for any exercise, see how it's done, in the basement, without leaving the app.

This is the phase with a licensing trap in it. Read §8 before starting.

**Deliverables**
- Exercise detail screen: name, bundled still, cues, common errors, `soloSafety`,
  `equipmentNote`, muscles, equipment, "Watch demo" (YouTube handoff), your form clips
- Bundled stills from a licence-clean source (§8.1), licence recorded per exercise
- A checklist file for you to fill in one curated YouTube URL per exercise
- **Record your own** (§8.3): film a set, store locally, play it back, dated series per
  exercise
- Exercise library: search, filter by pattern / muscle / equipment
- Demo reachable **from inside the session runner in one tap**, returning to the exact
  set you were on. A demo you have to leave the session to find doesn't get watched.

**Definition of done:** mid-session, unsure about the Nordic curl, one tap gets you the
cues and a demo, one more tap gets you back to logging.

**Claude Code prompt**

```
Phase 4 of keller-twelve-app-plan.md. Read §8 first — licensing matters here, and you
must not scrape any exercise GIF site.

1. Exercise detail screen: still, cues, commonErrors, soloSafety, equipmentNote,
   progressionNote, muscles, equipment, "Watch demo" via url_launcher, and my form clips.
2. Bring in stills from yuhonas/free-exercise-db (Unlicense) for every exercise with a
   match — exercises.json already carries a stillSearchTerm hint per exercise, which is a
   hint and NOT a verified slug. Bundle matches under assets/exercises/img/ and record
   the licence in exercises.json. Give me a list of the exercises with no match.
3. Do NOT invent YouTube URLs. Generate a checklist markdown file of every exercise with
   an empty URL slot for me to fill in, and read media.youtubeUrl when it's populated.
4. Form clips: record via image_picker in video mode, store under app-private
   files/clips/<exerciseId>/, row in form_clips, playback with video_player + chewie,
   delete, and a dated list so I can compare form over months.
5. One-tap demo access from the session runner, returning to the exact set I was on.
6. Exercise library with search and filters.

Then build the release APK.
```

---

### Phase 5 — Calendar and progress gallery

**Goal:** the app becomes the record of twelve weeks — what you planned, what you
actually did, and what changed in the mirror.

Read §6 in full before starting. This is the phase with the most design in it and the
only one with a hard privacy constraint.

**Deliverables**

*Calendar*
- `domain/calendar/programme_calendar.dart` — projection per §5.3, pure, **tested first**
- `sessionsForRange`, `adherence`, streak calculation
- Month grid, Monday-first, custom cells per §6.2 (rail colour by `day.kind`, dashed for
  optional, state glyph, dot cluster, today ring, unlogged-past tint)
- Tap behaviour per the §6.2 table; long-press menu
- **Retroactive logging** — the runner UI with the date pre-set and
  `logged_retroactively = 1`
- Move a session: `scheduled_date` ≠ `planned_date`, drawn on the new date, counted in
  the old week
- Agenda view for the current week; week-strip mode for in-gym use
- Checkpoint markers on weeks 1/4/8/12 from `programme.checkpoints`; week-8 deload banner
- Scheduling mode setting (`fixed` default) and a "shift programme by N weeks" action

*Progress gallery*
- `photo_shoots`, `progress_photos`, `photo_poses`, `measurements` tables
- Default pose set seeded per §6.3
- **Capture screen with the ghost overlay** — `camera` live preview, previous photo of
  the same pose at adjustable opacity, grid lines, 3-2-1 self-timer, pose guidance line
- Shoot flow: walk through all enabled poses in one pass, review, save or retake
- Gallery: browse by shoot (a date) or by pose (a timeline)
- **Compare:** side-by-side two shoots, and a wipe slider
- **Flipbook:** scrub/auto-play one pose chronologically
- Captions auto-resolve date, programme week and bodyweight (±2 days from `bodyweight`)
- Measurements entry and chart on the same date axis
- **Privacy, all six requirements from §6.3 implemented and verified on device:**
  app-private storage only, `allowBackup` disabled or photo dir excluded, optional
  `local_auth` gate, no network path, delete removes files, thumbnails app-private
- Storage budget readout and warning (default 500 MB across photos and clips)

**Definition of done:** two things, both on the phone.
1. In week 7 you spot a missed Thursday from week 5 on the calendar, log it retroactively
   from memory, and the next pull day's suggested loads account for it.
2. At the week-8 checkpoint you shoot four poses in about ninety seconds, each aligned
   against the week-4 ghost, and the wipe slider shows you something the mirror hasn't.
   Then you check the phone's gallery app and Google Photos and **the photos are not
   there**.

**Claude Code prompt**

```
Phase 5 of keller-twelve-app-plan.md — the calendar and the progress gallery.
Read §5.3 and §6 of the plan in full first.

PART A — Calendar
1. domain/calendar/programme_calendar.dart per §5.3. Pure, no I/O. Write the tests from
   §5.3's test list FIRST and show me them failing: startDate on Monday and on Thursday,
   dates before startDate, week 1/8/12 boundaries, a weekday with no day defined, deload
   multipliers applied, week 12 Sunday resolving to five-k-time-trial via weekSpecific,
   and a rescheduled session drawn on its new date but counted in its old week.
2. sessionsForRange(from,to) merging projected planned days with actual sessions rows in
   ONE query per month. adherence() excluding optional days, plus current streak.
3. Month grid with table_calendar for paging only — build the cells yourself via
   calendarBuilders, exactly as §6.2 specifies. Colour must never be the only carrier of
   state; the glyph is.
4. Tap behaviour per the §6.2 table, and the long-press menu.
5. Retroactive logging: the Phase 2 runner with the date pre-set and
   logged_retroactively = 1. This is a first-class flow, not a hidden one.
6. Move-session support via scheduled_date. Agenda view. Week-strip mode.
7. Checkpoint markers from programme.checkpoints, week-8 deload banner.
8. Settings: scheduling mode (fixed default) and "shift programme by N weeks".

PART B — Progress gallery
9. Tables photo_shoots, progress_photos, photo_poses, measurements. Seed the four default
   poses from §6.3.
10. Capture screen using the `camera` plugin with a live preview and the GHOST OVERLAY of
    the previous photo of the same pose — adjustable opacity, default ~30%, plus grid
    lines, a 3-2-1 self-timer and the pose guidance line. This overlay is the point of
    the feature; image_picker cannot do it, so use `camera`.
11. Shoot flow through all enabled poses in one pass, with review and retake.
12. Gallery by shoot and by pose. Side-by-side compare, a wipe slider, and a flipbook
    scrub/auto-play for one pose.
13. Captions resolve date, programme week and bodyweight (nearest entry within ±2 days).
14. Measurements entry + chart (waist, chest, arm, thigh, neck).
15. PRIVACY — implement all six requirements in §6.3 and then verify on my device that
    the photos do NOT appear in the phone's gallery app or Google Photos:
    - app-private storage only, never MediaStore, never /sdcard/Pictures
    - android:allowBackup="false" or backup_rules excluding the photo directory
    - optional local_auth gate on the section, off by default
    - no network code path touches these files
    - delete removes files and directories, not just rows
    - thumbnails cached app-private too
16. Resize to 1920px long edge at JPEG q85. Storage budget readout and warning, default
    500 MB across photos and clips.

Tell me explicitly how you verified #15 before you call this phase done.
Then build the release APK.
```

---

### Phase 6 — Cardio, bodyweight, food

**Goal:** the non-lifting half of the programme stops living in your head.

**Deliverables**
- Cardio day runner driven by the Phase 2 interval engine: skipping (`8 × 30 s / 30 s`)
  and bag rounds (`3 × 2 min / 1 min`), audible and haptic round transitions
- Run logging: duration, optional distance, perceived effort. No GPS.
- `programme.cardioProgression` surfaced per week, so Sunday's target run length comes
  from the table rather than memory
- Bodyweight: quick entry, 7-day rolling average, trend chart, and the rule enforced —
  **rolling average flat for `flatWeeksBeforeBump` weeks → surface "add 300 kcal"**
  (both values already in the programme JSON)
- Food: a deliberately minimal daily tick — kcal, protein, hit-target yes/no, and a
  streak. Not a food diary.
- Checkpoint prompts firing from `programme.checkpoints`

**Definition of done:** the app notices your weight has been flat for two weeks and says
so, unprompted, before you do.

**Claude Code prompt**

```
Phase 6 of keller-twelve-app-plan.md.

1. Cardio day runner using the Phase 2 interval engine, driven by the prescriptions in
   the JSON — for timed loadModes, repsMin/repsMax carry SECONDS. Audible + haptic
   transitions, works with the screen off.
2. Manual run logging: duration, optional distance, effort.
3. Surface programme.cardioProgression for the current week in the cardio day and on the
   dashboard.
4. Bodyweight: entry, 7-day rolling average, fl_chart trend, and a card that appears when
   the rolling average hasn't risen in nutritionTargets.flatWeeksBeforeBump weeks:
   "flat for 2 weeks — add 300 kcal". Read both numbers from the programme JSON.
5. Minimal food tick: date, kcal, protein_g, hitTarget bool, streak counter. No food
   database, no barcode scanning.
6. Checkpoint prompts from programme.checkpoints, surfaced on the dashboard and the
   calendar.

Then build the release APK.
```

---

### Phase 7 — Customisation layer

**Goal:** you can reshape the entire programme from the phone, without Claude Code and
without a PC. This is the phase that makes it *yours*.

**Deliverables**
- **In-app programme editor**
  - edit any prescription: sets, reps range, rest, RIR, increment, start load
  - swap an exercise (offering `substitutes` first), history preserved
  - reorder within a section; add/remove exercises
  - add/remove/rename days; change a day's weekday or kind
  - edit `day.warnings` and `coachNote`
  - **detach and duplicate** an inheriting block (§4.2), so Push can diverge from Build
  - duplicate a block to extend past week 12
- **Import/export** of programme JSON, validated against `schema.json` on import, with a
  diff summary before it applies. This is how you and Claude Code collaborate later: it
  writes a new JSON, you import it.
- **Full backup/restore**: SQLite + programme JSONs + photos + clips → one zip. Restore
  from the same, with a confirmation step.
- Reset-to-shipped-programme (the asset is untouched, so this is trivial)
- Revision guard: bump `revision` on every edit; warn before an import overwrites newer
  local edits

**Definition of done:** you decide mid-block that Bulgarian split squats are wrecking
your knee, swap them for reverse lunges on the phone in the basement, and your squat
history is still intact.

**Claude Code prompt**

```
Phase 7 of keller-twelve-app-plan.md.

1. In-app programme editor covering everything in §Phase 7. Writes to the user override
   JSON in the documents dir, never the bundled asset. Bumps `revision` on every edit.
2. Exercise swap must preserve history: set_logs keep their own exercise_id, and the
   progression engine looks up history by exercise_id, not by prescription id. Test this.
3. "Detach and duplicate" on a block with inheritsDaysFrom: materialise the resolved days
   into real `days` and clear the inheritance.
4. Import/export of programme JSON via file_picker and share_plus, validated against
   schema.json on import, with a diff summary shown before it applies.
5. Full backup/restore: a zip of the SQLite file, programme JSONs, photos and clips,
   written to Downloads. Restore with a confirmation step. Photos are private — the zip
   must not be auto-shared anywhere, only written where I chose.
6. "Reset to shipped programme": delete the override, re-copy the asset.
7. Revision conflict warning when importing over newer local edits.

Then build the release APK.
```

---

### Phase 8 — Stats and quality of life

**Goal:** the app shows you that twelve weeks happened.

**Deliverables**
- Dashboard: current week and block, streak, week progress, bodyweight sparkline, next
  session, checkpoint card when due
- Per-lift progress: e1RM over time (Epley, **labelled as an estimate**), best set, volume
- Weekly **sets per muscle group** from `exercise.primaryMuscles` — the number that
  actually drives hypertrophy
- Session duration stats — sanity-check that 55 min is real and not 90
- `strengthTargets` from the programme rendered as progress against week-4 and week-12
  targets
- Plate-gap report: "your smallest jump on overhead press is 11% — buy a second pair of
  1.25 kg plates"
- Optional evening reminder on planned session days, off by default

**Claude Code prompt**

```
Phase 8 of keller-twelve-app-plan.md.

1. domain/metrics/: pure, tested functions for Epley e1RM, best set, per-exercise
   tonnage, and weekly sets-per-muscle-group derived from exercise.primaryMuscles.
2. Dashboard: current week and block, streak, week progress, bodyweight sparkline, next
   session, and a checkpoint card when one is due.
3. Per-lift detail: e1RM trend chart labelled as an estimate, best set, volume, full log
   history for that lift.
4. Weekly sets-per-muscle-group chart.
5. Render programme.strengthTargets as progress against the week-4 and week-12 targets.
6. Plate-gap report per lift using the plate solver's microplate-gap hint.
7. Optional local notification on planned session days, time configurable, off by default.

Then build the release APK.
```

---

### Phase 9 — Release, signing, and not losing your data

**Goal:** a properly signed APK you can keep updating in place for years, and a backup
you'd actually survive a lost phone with.

**Deliverables**
- Release keystore, generated once, **backed up off the machine**
- `android/key.properties` (gitignored) + signing config in `build.gradle`
- Version scheme: `versionName` semver, `versionCode` monotonic
- `flutter build apk --release --split-per-abi` producing a signed arm64 APK
- R8/ProGuard sanity check — confirm Drift and camera survive minification
- A documented update ritual: bump version → build → `adb install -r`
- `README.md`: how to build, install, update, where the keystore is, how to restore a
  backup, and the reminder that photos live only on the device

**Steps**

```bash
keytool -genkey -v -keystore ~/keys/keller-twelve.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias kellertwelve
```

```properties
# android/key.properties   (ADD TO .gitignore)
storePassword=…
keyPassword=…
keyAlias=kellertwelve
storeFile=/home/saad/keys/keller-twelve.jks
```

**Critical:** if you lose that `.jks`, you cannot install an update over the existing app
— you have to uninstall, which wipes the database *and every progress photo*. Back the
keystore up to two places that aren't the PC, today, before you build Phase 9.

**Claude Code prompt**

```
Phase 9 of keller-twelve-app-plan.md.

1. Walk me through generating a release keystore, then wire android/key.properties
   (gitignored) into the signing config in android/app/build.gradle.
2. Set up versionName/versionCode and tell me the ritual for bumping them.
3. Build a signed release APK with --split-per-abi. Verify with apksigner and show me
   the output.
4. Check R8/ProGuard hasn't broken Drift or the camera plugin — run the signed APK
   through a full session AND a photo shoot on the device, and confirm the DB and the
   photo files both still work.
5. Write README.md: build, install, update, keystore location warning, backup/restore,
   and a note that progress photos exist only on this device and in my own backups.
6. Remind me in your output to back up the keystore to two places off this machine.
```

---

## 8. Exercise demo media — the licensing part

Read this before Phase 4. It is the one place in this project where the obvious approach
is the wrong one.

### 8.1 Bundled stills — use a licence-clean source

**Use:** [`yuhonas/free-exercise-db`](https://github.com/yuhonas/free-exercise-db) —
~870 exercises with images, released under the Unlicense (public domain). Clone it, pick
the matches for the exercises in the library, bundle those.

Also fine: **wger** (`wger-project/wger`) — AGPL app whose exercise database is
contributed under CC-BY-SA. Usable with attribution; check each image's licence field.

**Do not:** scrape MuscleWiki, GymVisual, Everkinetic-derived commercial sets, or the
RapidAPI "ExerciseDB" GIF bundles. Those are copyrighted or licence-restricted, and the
fact that the app is only for you doesn't change the copying. Claude Code should refuse
this, and so should you.

`exercises.json` carries a `stillSearchTerm` per exercise as a matching hint. It is a
hint, not a verified slug — expect misses, and expect to leave some exercises without a
still. A cue list with no picture is fine; a stolen picture is not.

### 8.2 Video — link, don't bundle

Store one curated YouTube URL per exercise and hand off with `url_launcher`. Zero app
weight, zero licensing exposure, and the demos are better than anything you'd bundle.

Curate them yourself, once, over a week. Prefer coaches who demo the *solo home-gym*
version where it differs — bailing out of a squat, floor pressing, setting catch pins.
**Do not let Claude Code invent URLs**; it cannot verify them, and a wrong link is worse
than none. Phase 4 generates an empty checklist for you to fill in.

`youtubeStartSec` exists so a link can jump past ninety seconds of intro.

### 8.3 Your own clips — the actually valuable feature

For a solo lifter with no coach, the highest-value media in the app is **you**.

- Prop the phone on the bench, film one working set from the side (squat, deadlift, bench)
- Store under app-private `files/clips/<exerciseId>/<timestamp>.mp4`
- Compare week 1 against week 8

Free, legal, fully customisable, and genuinely how you'll catch your squat depth drifting
or your bench elbows flaring. Note that form clips do **not** need the ghost overlay — use
`image_picker`'s video mode here and save `camera` for the progress photos in Phase 5.

Cap the storage: 720p default, most-recent-N per exercise, and the shared budget from
§6.3.

### 8.4 The fully-offline variant

If you want the app to hold **zero** network permission: drop `url_launcher`, rely on
bundled stills, cues and your own clips. Everything else here already works offline.
Worth considering for an app that holds a year of your training data and a gallery of
shirtless photos.

---

## 9. Repo conventions and the CLAUDE.md to drop in

Create this at the repo root before Phase 1. It keeps Claude Code consistent across
sessions and stops it re-litigating decisions.

```markdown
# CLAUDE.md — Keller Twelve

Single-user offline Android training app. Flutter + Riverpod + Drift.
Build plan: keller-twelve-app-plan.md — follow its phases, do not skip ahead.

## Hard rules
- The programme is DATA. Never hardcode sets, reps, loads, exercise names or day
  structure in Dart. If a value belongs to the training programme, it lives in JSON.
- keller-twelve.json, exercises.json and schema.json are the validated source of truth.
  Make the models match the data. Do not regenerate or "tidy" those files.
- lib/domain/ is pure Dart: no Flutter imports, no I/O, no plugins. It is unit tested.
- The progression engine, plate solver and calendar projection are test-first. Tests
  before implementation, always, and show me the failing run.
- Kilograms only. No unit conversion, no imperial. Timed prescriptions carry SECONDS in
  repsMin/repsMax.
- No network calls except url_launcher opening a YouTube link. No analytics, no crash
  reporting, no cloud, no auth, ever.
- set_logs store their own exercise_id. Never resolve history through the live programme.
- Never scrape or bundle copyrighted exercise images or GIFs. Unlicense/CC sources only,
  with the licence recorded in exercises.json. Never invent a YouTube URL.

## Progress photos — non-negotiable
- App-private storage only. NEVER MediaStore, NEVER /sdcard/Pictures, never a path the
  phone's gallery or Google Photos can see.
- android:allowBackup="false" or backup_rules excluding the photo directory.
- No code path may upload, share or sync a photo. Export is manual and user-initiated.
- Deleting a photo or shoot deletes the files, not just the DB rows.
- Never commit anything under photos/ or clips/.

## Conventions
- `flutter analyze` clean before any commit. Treat warnings as errors.
- `dart format .` before any commit.
- Conventional commits: feat/fix/refactor/test/chore, scoped by feature.
- One phase per branch: `phase-5-calendar-progress`. Merge when the APK is on my phone.
- Tag each merge: v0.1-phase1, v0.2-phase2, … so I can always return to a build that
  worked in the basement.
- Riverpod: code-gen providers (@riverpod). No global mutable state.
- Every new domain function gets a unit test in the same PR.
- Never commit key.properties or *.jks.

## Device reality
I train alone in a basement, in poor light, with chalky hands, between heavy sets.
UI must be: dark, high contrast, 48dp minimum targets, one-handed, steppers and chips
over keyboards, readable at arm's length. Colour is never the only carrier of meaning.

## What to ask me about
- Anything that changes the training programme's meaning (sets, reps, progression rules)
- Any new dependency
- Anything that would add a permission to the manifest
Don't ask me about: naming, file layout, widget structure, test structure. Just decide.
```

---

## 10. Risks and the things that will actually bite

| Risk | Mitigation |
|---|---|
| **You build the app instead of training.** The real failure mode. | Phase 1 ships in one evening and already replaces the web page. Train off Phase 1 while Phases 2+ get built. Never let a half-finished phase block a session — the HTML plan is always the fallback. |
| Gradle/JDK/AGP version hell | Phase 0 exists for this. Pin JDK 17. Don't upgrade Flutter mid-phase. |
| Android battery optimisation killing the rest timer | Notification-backed, wall-clock timers, never in-process tick counters. Exempt the app from battery optimisation and note it in the README. |
| Losing the keystore → can't update without wiping data **and photos** | Back it up to two non-PC locations in Phase 9, before building. |
| Drift migrations breaking on a device with real data | Write the migration and test it against a copy of the device DB *before* installing. Always export a backup before a schema-bumping version. |
| **Progress photos leaking to Google Photos** | The six requirements in §6.3, verified on device as part of Phase 5's definition of done. This is the single most likely privacy mistake in the whole project, and it happens by default if you use `image_picker`'s standard save. |
| Phone storage filling with photos and clips | 1920px q85 stills, 720p clips, per-exercise caps, shared 500 MB budget with a warning. |
| Calendar week numbers drifting from reality | `fixed` scheduling by default, plus an explicit "shift programme" action. Test the boundaries. |
| Missing session data poisoning the progression engine | Retroactive logging is a first-class Phase 5 flow, not an afterthought. |
| Scope creep into a food diary / GPS running app | §1.2. Those apps exist. This one logs sets. |
| The progression engine silently suggesting wrong loads for weeks | The test list in §5.1 is not optional. This is the one bug class that costs real training time. |
| Editing the programme mid-block and losing history | Denormalised `exercise_id` in `set_logs` (§4.7), tested in Phase 7. |

---

## 11. Backlog — after Phase 9, only if you still want them

- CSV export for spreadsheet analysis
- A second programme slot, so you can plan block 2 while running block 1
- Superset / circuit support in the data model (`groupId` on prescriptions)
- Auto-regulation: adjust the day's targets from a morning readiness score
- Side-by-side video compare for form clips, with the same wipe slider as the photos
- Auto-generated progress video: the flipbook rendered to an MP4 you keep
- Wear OS companion for the rest timer
- Home-screen widget with today's session
- Import your SmarTracks sprint data for the running side — you already work on that
  platform, and the sensor data is more interesting than a stopwatch
- A "basement inventory" scanner: photograph the plate pile, count plates, update the
  inventory. Ridiculous. Slightly tempting.

---

## 12. Suggested pace

| Phase | Realistic effort | Ship by |
|---|---|---|
| 0 — Toolchain | 1 evening | before training week 1 |
| 1 — Data + viewer | 1 evening (data is done) | end of training week 1 |
| 2 — Session runner | 2–3 evenings | end of training week 3 |
| 3 — Progression + plates | 2 evenings | end of training week 4, before block 2 |
| 4 — Demos | 1–2 evenings + a week of curating URLs | training week 6 |
| 5 — Calendar + progress gallery | 3–4 evenings | training week 8, in time for the checkpoint |
| 6 — Cardio / body / food | 2 evenings | training week 9 |
| 7 — Customisation | 2–3 evenings | training week 10 |
| 8 — Stats | 1–2 evenings | training week 11 |
| 9 — Release + signing | 1 evening | training week 12 |

Total: roughly 16–21 evenings, spread across the twelve weeks of the programme itself.
That's the right pacing — the app gets built by the person using it, and each phase gets
tested in the room it's for.

**Two ordering notes.** Take the baseline photos in week 1 with your phone's normal
camera, before Phase 5 exists — you cannot go back and shoot week 1 later, and the ghost
overlay needs a first frame to align against. Import them into the gallery when Phase 5
lands. And Phases 3 and 9 are the two that must not be rushed; everything else can be
sloppy and fixed later.
