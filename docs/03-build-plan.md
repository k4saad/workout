# 03 — Build plan v2

Eleven phases. **Each one ends with an APK installed on your phone.** No phase is done
because the code compiled.

## Phase order and why it changed from v1

| Phase | v1 position | v2 position | Why moved |
|---|---|---|---|
| Release keystore | Phase 9 | **Phase 0** | Switching signing keys later forces an uninstall, which deletes the database and every progress photo. Audit A4. |
| Backup / export | Phase 7 | **Phase 2** | Nine weeks of data with no export is the other way to lose everything. Audit A5. |
| Calendar | Phase 5 | **Phase 4** | Retroactive logging protects the data quality the progression engine reads. It has to exist before the data gets holes in it. |
| Exercise demos | Phase 4 | **Phase 7** | Genuinely nice, but YouTube on your phone already does this. Lowest-value thing in the list. |
| Cycle 2 seeding | absent | **Phase 8** | Audit C8 — the app currently has nothing to say at week 13. |

## Deadlines that are real

| Must ship by | Why |
|---|---|
| **Phase 0 + 1 before training week 1** | Phase 1 replaces the HTML page. Train off it while the rest gets built. |
| **Phase 3 before training week 5** | Build block is where loads get real and the lattice starts mattering. |
| **Phase 5 before training week 8** | The week-8 checkpoint is the first shoot that can use a ghost overlay. |
| **Phase 8 before training week 12** | Cycle 2 seeding runs off the week-12 tests. |

## Pace

| Phase | Effort | Training week |
|---|---|---|
| 0 — Toolchain + keystore | 1 evening | before week 1 |
| 1 — Data + viewer | 1 evening | week 1 |
| 2 — Runner + DB + backup | 3 evenings | weeks 2–3 |
| 3 — Plates + progression | 2 evenings | week 4 |
| 4 — Calendar | 3 evenings | weeks 5–6 |
| 5 — Progress photos | 3 evenings | week 7 |
| 6 — Cardio / body / food | 2 evenings | week 9 |
| 7 — Demos + form clips | 2 evenings | week 10 |
| 8 — Editor + cycle 2 | 2 evenings | week 11 |
| 9 — Stats | 1 evening | week 12 |
| 10 — Hardening | 1 evening | week 12 |

**~20 evenings across the twelve weeks of the programme itself.** That is the right
pacing: each phase gets tested in the room it is for.

> **The headline risk is that you build the app instead of training.** Phase 1 ships in
> one evening and already replaces the web page. Never let a half-finished phase block a
> session — doc 01 is always the fallback, printed if necessary.

---

# Phase 0 — Toolchain, project, and the keystore

**Goal:** an unmodified Flutter counter app, **signed with your real release keystore**,
installed on your phone.

### 0.1 Toolchain
- [ ] Flutter SDK on the stable channel; `flutter --version` recorded in the README
- [ ] `flutter doctor -v` with no red on Android
- [ ] **JDK 17** confirmed (`java -version`). If the system default is 21, set
      `org.gradle.java.home` in `android/gradle.properties`
- [ ] `flutter doctor --android-licenses` accepted — release builds fail late otherwise
- [ ] `adb devices` lists the phone as `device`, not `unauthorized`

### 0.2 Project
- [x] `flutter create --org de.saad --platforms=android keller_twelve`
- [x] `minSdk 24`, `applicationId de.saad.kellertwelve`, `versionName 0.1.0`,
      `versionCode 1`
- [x] `git init`, Flutter `.gitignore`, first commit
- [x] `CLAUDE.md` copied to the repo root
- [x] `docs/` copied in

### 0.3 Release signing — **do not skip, do not defer**
- [x] `keytool -genkey -v -keystore <path>/keller-twelve.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kellertwelve`
- [x] `android/key.properties` created and **added to `.gitignore`**
- [x] `signingConfigs.release` wired into `android/app/build.gradle`, and
      `buildTypes.release.signingConfig` pointed at it — **not** at `signingConfigs.debug`
- [ ] `flutter build apk --release --split-per-abi`
- [ ] `apksigner verify --print-certs` shows **your** certificate, not `CN=Android Debug`
- [ ] **Keystore backed up to two locations that are not this PC.** Do this tonight.

### 0.4 Install
- [ ] `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- [ ] Counter app launches from the drawer with the cable unplugged

**Definition of done:** `apksigner verify --print-certs` prints your own certificate,
and the APK is running on the phone.

### Gotchas
- JDK 21 + older Gradle gives cryptic Kotlin failures. Pin 17.
- Xiaomi / Redmi / Realme: also enable "Install via USB" in Developer options and
  disable MIUI optimisation. This wastes hours if you do not know it.
- `--split-per-abi` gives ~8 MB arm64 instead of ~20 MB fat.
- Wireless: `adb pair <ip>:<port>` then `adb connect <ip>:<port>`.

### Prompt

```
Phase 0 of docs/03-build-plan.md. No app features.

1. Run `flutter doctor -v` and fix every Android issue, explaining each fix first.
   My JDK must be 17 — check and tell me if it is not.
2. `flutter create --org de.saad --platforms=android keller_twelve`, then set
   minSdk 24, applicationId de.saad.kellertwelve, versionName 0.1.0, versionCode 1.
3. git init with a Flutter .gitignore, copy CLAUDE.md and docs/ in, first commit.
4. CRITICAL — release signing NOW, not in a later phase. Walk me through generating
   the keystore, create android/key.properties (gitignored), and wire a release
   signingConfig into android/app/build.gradle. The release buildType must NOT use
   signingConfigs.debug. Read docs/00-audit.md A4 for why this cannot wait.
5. Build --release --split-per-abi, run `apksigner verify --print-certs` and show me
   the output. It must show my certificate, not CN=Android Debug.
6. Give me the adb install command, and remind me to back the keystore up to two
   places that are not this machine.

Stop after that.
```

---

# Phase 1 — Programme as data, read-only viewer

**Goal:** the programme JSON loads, resolves, and renders as a browsable week. This
alone replaces doc 01 on your phone.

**Blocked by:** doc 04 calibration. The lattice test (V6) cannot pass against guessed
bar weights.

### 1.1 Author the v2 data files
- [x] `data/keller-twelve.json` written from doc 01 — 5 blocks, day templates, supersets
- [x] `data/exercises.json` — start from v1's 72, add the wall-cable and step-platform
      movements, make the 10 orphaned warm-up exercises real references (audit C16)
- [x] `data/schema.json` updated with every field in doc 02 part 1
- [x] **Every `startLoadKg` generated on the lattice**, not typed by hand

### 1.2 Domain models
- [x] `lib/domain/models/` — immutable, `fromJson`/`toJson`, **zero Flutter imports**
- [x] `Programme`, `Block`, `Day`, `Section`, `ExercisePrescription`, `Exercise`,
      `Progression`, `NutritionPhase`, `CardioWeek`, `Checkpoint`, `Inventory`

### 1.3 Resolution
- [x] `inheritsDaysFrom` + `dayOverrides` + `weekSpecific` per doc 02 algorithm C
- [x] All four new resolution steps: `setRounding`, `defaultRir` inheritance,
      `includeSupersets`, `includeFinishers`

### 1.4 Validation tests — **these gate the build**
- [x] V1–V11 from doc 02 §1.6, every one of them
- [x] V6 (lattice validity) and V11 (60-minute ceiling) are the two that catch the
      v1 class of bug. Do not let them be skipped.

### 1.5 Repository
- [x] Load from asset → copy to app documents dir on first launch → prefer the copy
- [x] The asset is **never** mutated, so "reset to original" is one delete away

### 1.6 UI
- [ ] Riverpod (`@riverpod` code-gen) + `go_router` — **deviation: plain
      providers were used throughout, not code-gen.** `go_router` is as planned.
      `riverpod_generator` is still a dev dependency, so converting later is
      mechanical. See "Known deviations" below.
- [x] **Today** — which day is it, what am I doing
- [x] **Week** — 7 day cards
- [x] **Day detail** — sections, prescriptions, cues, `warnings` as a top banner,
      supersets visually grouped
- [x] Theme: dark-first, high contrast, 48 dp minimum targets, readable at arm's length

**Definition of done:** you open it in the basement, see "Monday · Lower A · Squat",
scroll five movements with sets, reps, rest and cues, and never open doc 01 again.

### Prompt

```
Phase 1 of docs/03-build-plan.md.

Read docs/01-programme.md and docs/02-data-model.md in full first.

1. Author data/keller-twelve.json from docs/01 section 6 — all five blocks, with the
   superset groupIds, unit fields, perSide, repsCreepMax, nutritionPhases, onComplete.
   Generate every startLoadKg ON THE LATTICE using the inventory in docs/04 — do not
   type round numbers. Update data/schema.json for every new field in docs/02 part 1.
2. Extend data/exercises.json: keep the 72 from v1, add the wall-cable and step-platform
   movements docs/01 uses, and make the 10 orphaned warm-up exercises real references.
3. Models in lib/domain/models/ — immutable, fromJson/toJson, no Flutter imports.
4. Block inheritance per docs/02 algorithm C, INCLUDING setRounding, defaultRir
   inheritance, includeSupersets and includeFinishers. These four are new in v2.
5. Write validation tests V1 through V11 from docs/02 section 1.6. V6 (every
   startLoadKg is lattice-valid) and V11 (every lift day <= 60 min) must fail the
   build. Show me them passing.
6. ProgrammeRepository: asset -> documents dir on first launch -> prefer the copy.
   Never mutate the asset.
7. Riverpod + go_router. Screens: Today, Week, DayDetail. Render day.warnings as a
   banner. Group supersets visually — they are not separate exercises.
8. Theme in lib/core/theme/: dark-first, large type, 48dp targets.

Then build the release APK and give me the install command.
```

---

# Phase 2 — Session runner, database, and backup

**Goal:** press Start, walk through the session, log every set, rest between them,
finish. **This is the app.**

### 2.1 Database
- [x] Drift: `sessions`, `set_logs`, `stall_counters`, `bodyweight`, `cardio_logs`,
      `food_logs`, `niggles`, `inventory_*`
- [x] Migration strategy from schema v1, with a **pre-migration automatic DB copy**

### 2.2 Interval engine
- [x] `lib/domain/intervals/` — **wall-clock based**, never a tick counter
- [x] Unit tested: drift under suspension, pause/resume, ±15 s, skip

### 2.3 Session lifecycle
- [x] `startSession(dayId, date)` → `inProgress`
- [x] `logSet(...)` **persisted immediately** — phones die mid-session
- [x] `finishSession()`, and resume an `inProgress` session on launch

### 2.4 The runner screen — the most important UI in the app
- [x] One exercise in focus; swipe or tap between them
- [x] **Supersets render as one card** with alternating members, one rest at the end
- [x] Per-set row: target reps · actual-reps stepper · load field · RIR chip
- [x] Large "log set" button; rest timer starts **automatically**
- [x] Last session's numbers inline: *"last time: 8, 8, 7 @ 25 kg"*
- [x] `day.warnings` as a dismissible banner before the first set
- [x] Notes per exercise and per session
- [x] **Niggle button** — one tap records site + severity against this exercise (audit C15)

### 2.5 Rest timer
- [x] Prefilled from `restSec`; runs with the screen off
- [x] `flutter_local_notifications` + `SCHEDULE_EXACT_ALARM` +
      `exactAllowWhileIdle` (audit C9)
- [x] Runtime `POST_NOTIFICATIONS` on Android 13+
- [x] Haptic + optional sound; ±15 s; skip
- [x] `wakelock_plus` for the duration of a session

### 2.6 The 60-minute features — these are programme requirements, not polish
- [x] **Elapsed vs `estMinutes`** shown in the session header
- [x] At 45 minutes elapsed with more than one movement left, offer
      *"running long — drop the last superset?"*
- [x] **"I only have 40 minutes"** mode at session start: keeps movement 1 and the
      first superset, drops the rest

### 2.7 Backup — ships here, not in Phase 8
- [x] Export: SQLite + programme JSON → one zip, written where you choose
- [x] Import with a confirmation step
- [x] **Reminder card if no backup in 14 days**

### 2.8 History
- [x] Flat list of completed sessions, tappable to a read-only set list

**Definition of done:** you complete a full Monday session using only the phone, and the
next morning every set is there and correct — including the one you logged after the
screen went black during a 2:30 rest. Then you export a backup and open the zip on the PC.

### Prompt

```
Phase 2 of docs/03-build-plan.md.

1. Drift: every table in docs/02 part 3, with DAOs and a migration strategy that takes
   an automatic copy of the DB before any migration runs.
2. lib/domain/intervals/ — wall-clock based, not a tick counter. Unit tested.
3. Session lifecycle: startSession / logSet persisted IMMEDIATELY / finishSession.
   Must survive app kill — resume an inProgress session on launch.
4. The runner screen per section 2.4. Supersets render as ONE card with alternating
   members and a single rest at the end — this is new in v2 and it is how the session
   fits in 60 minutes. Include the one-tap niggle button.
5. Rest timer: auto-start on log, screen-off via flutter_local_notifications with
   SCHEDULE_EXACT_ALARM and exactAllowWhileIdle, POST_NOTIFICATIONS on Android 13+,
   haptic, +/-15s, skip. Read docs/02 part 4 — v1 missed the exact-alarm permission
   and the timer would have fired late on Android 12+.
6. wakelock_plus while a session is in progress.
7. Section 2.6 — the three time-budget features. These are programme requirements.
8. Backup/export to a zip, and import with confirmation. This ships NOW, not later.
   Read docs/00-audit.md A5.
9. Flat history screen.

Optimise for one-handed use with chalky hands: steppers and chips, not keyboards.
Then build the release APK.
```

---

# Phase 3 — Plate solver and progression engine

**Goal:** the app tells you what to put on the bar, which plates, and why.

**Test-first. Show me the failing run before any implementation.**

### 3.1 Plate solver
- [x] `lib/domain/plates/plate_solver.dart` per doc 02 algorithm B
- [x] All load modes, correct per-mode plate budgets (the `dumbbellPair` quad budget is
      the one that gets written wrong)
- [x] `lattice()`, `smallestStep()`, `isLatticeValid()`
- [x] Contention detection, breakdown string, microplate hint
- [x] **Tests B-1 to B-12, written first**

### 3.2 Progression engine
- [x] `lib/domain/progression/progression_engine.dart` per doc 02 algorithm A
- [x] All 8 ordered rules, including **rule 3b rep creep and rule 8's final guard**
- [x] `historyWindowDays` precedence over `startLoadKg`
- [x] **Tests A-1 to A-14, written first.** A-4 and A-14 are the ones that catch the
      v1 deadlock — do not let them be dropped.

### 3.3 Ramp generator
- [x] `lib/domain/progression/ramp_generator.dart` per doc 02 algorithm D
- [x] Absolute and lattice-aware, never percentage-based
- [x] Ramp sets logged `is_warmup = 1` and excluded from progression and volume

### 3.4 Integration
- [x] Each exercise opens with suggested load + reason + plate breakdown
- [x] Always overridable; the override is what gets logged
- [x] Rep-creep state shown explicitly: *"6–10 reps this week — plates too coarse to jump"*
- [x] Contention warning at session start
- [x] Stall counters persisted per `exerciseId`

### 3.5 Calibration wizard
- [x] First-run flow capturing everything in doc 04
- [x] Editable afterwards in Settings
- [x] **Blocks nothing, but warns loudly while bars are unmeasured** — the solver is
      garbage-in until this is done

**Definition of done:** the app says
`Back squat — 21 kg · bar 9 + (5 + 1) per side · earned the jump`, and it matches the
plates actually on the floor.

### Prompt

```
Phase 3 of docs/03-build-plan.md. TEST-FIRST — write the tests from docs/02 algorithms
A, B and D before any implementation and show me the failing run.

1. plate_solver.dart per docs/02 algorithm B. Note the dumbbellPair budget consumes
   FOUR plates per size, not two. Implement lattice(), smallestStep(), isLatticeValid(),
   contention detection, the breakdown string and the microplate hint.
   Tests B-1 to B-12 first.
2. progression_engine.dart per docs/02 algorithm A — all 8 rules. Rule 3b (rep creep)
   and rule 8 (a jump that was earned must always produce weight OR reps) are the two
   that fix v1's deadlock. Read docs/00-audit.md A1 first.
   Tests A-1 to A-14 first. A-4 and A-14 are non-negotiable.
3. ramp_generator.dart per docs/02 algorithm D — absolute, lattice-aware, never
   percentages. Ramp sets are is_warmup=1 and excluded from progression and volume.
4. Wire into the runner: suggested load, reason, plate breakdown, rep-creep state,
   contention warning. Always overridable; the override is logged.
5. First-run calibration wizard per docs/04, editable in Settings, with a loud warning
   while bar weights are still estimates.

Then build the release APK.
```

---

# Phase 4 — Calendar and retroactive logging

**Goal:** the app becomes the record of what you planned and what you actually did.

### 4.1 Projection
- [x] `lib/domain/calendar/programme_calendar.dart` per doc 02 algorithm C
- [x] **Tests C-1 to C-13, written first** — including C-9, week 13 returns `Complete`
- [x] `sessionsForRange` in one query per month; `adherence()` excluding `optional`;
      streak

### 4.2 Month grid
- [x] `table_calendar` for paging only; cells hand-built via `calendarBuilders`
- [x] Monday-first, programme week numbers (1–12) in the left gutter, not ISO weeks
- [x] Header: month · `Week 6 of 12 · Build` · block adherence · streak

### 4.3 The cell
```
┌─────────────┐
│ 23      ●●  │  day number, dot cluster
│ ▔▔▔▔▔▔▔▔    │  3px rail, coloured by day.kind
│ Lower A     │  short label, ellipsised
│ ✓           │  state glyph
└─────────────┘
```
- [x] Rail colour by `kind`; **dashed** for `optional: true`
- [x] Glyph: `✓` completed · `◐` partial · `✕` skipped · `▶` in progress · `↷` moved
- [x] Today gets a ring; past-planned-but-unlogged gets a faint warning tint
- [x] Dots: bodyweight · food target hit · photo shoot · cardio logged
- [x] **Colour never carries state alone — the glyph does.** You are reading this in bad
      basement light.

### 4.4 Interaction
- [x] Tap behaviour by day state (today/past-done/past-missed/future/rest/outside)
- [x] Long-press: log retroactively · move to another date · mark skipped · add note ·
      add photo shoot
- [x] **Retroactive logging is first-class** — the Phase 2 runner with the date pre-set
      and `logged_retroactively = 1`. You will forget to open the app mid-session a
      dozen times; if live logging is the only path, the engine reads stale history.
- [x] Move a session: `scheduled_date ≠ planned_date`, drawn on the new date, counted in
      the old week

### 4.5 Supporting views
- [x] Agenda list for the current week
- [x] Week-strip mode for one-handed in-gym use
- [x] Checkpoint markers on weeks 1/4/8/12 opening that week's checklist
- [x] Week-8 deload banner across the week
- [x] Settings: scheduling mode (`fixed` default) + "shift programme by N weeks"

**Definition of done:** in week 7 you spot a missed Thursday from week 5, log it
retroactively from memory, and the next deadlift day's suggested load accounts for it.

---

# Phase 5 — Progress photos and measurements

**Goal:** proof that twelve weeks happened.

**The only phase with a hard privacy constraint. Read doc 00's privacy section and this
section in full before starting.**

### 5.1 Tables
- [x] `photo_shoots`, `progress_photos`, `photo_poses`, `measurements`
- [x] Seed four poses: front relaxed · front flexed · side right · back

### 5.2 Capture with the ghost overlay — the feature
- [x] `camera` plugin live preview (**not** `image_picker` — it hands off to the system
      camera and cannot draw over the viewfinder)
- [x] **Previous photo of the same pose as a semi-transparent overlay**, default 30%,
      with a toggle and an opacity slider
- [x] Rule-of-thirds grid, 3-2-1 self-timer, pose guidance line
- [x] Shoot flow: all enabled poses in one pass, review, retake

### 5.3 Comparison
- [x] Side-by-side two shoots, same pose
- [x] **Wipe slider** — two images stacked with a draggable divider. This is the one
      that actually reveals change.
- [x] Flipbook: scrub or auto-play one pose chronologically
- [x] Captions auto-resolve date, programme week and bodyweight (nearest entry ±2 days)

### 5.4 Measurements
- [x] Waist, chest, upper arm, thigh, neck — entered at checkpoints
- [x] Charted on the same date axis as bodyweight
- [x] **Waist rule from doc 01 §3**: flag when waist grows more than 3 cm over the block

### 5.5 Privacy — six hard requirements, verified on device
1. [ ] **App-private storage only.** `getApplicationDocumentsDirectory()`. Never
       `MediaStore`, never `/sdcard/Pictures`, never `image_picker`'s default save.
2. [ ] **`android:allowBackup="false"`** and `backup_rules.xml` excluding the photo dir
3. [ ] Optional `local_auth` biometric gate on the section, off by default
4. [ ] **No network code path touches these files.** No upload, no share-to-cloud.
5. [ ] **Delete means delete** — files and directories, not just rows
6. [ ] Thumbnails cached app-private too

### 5.6 Storage
- [x] Resize to 1920 px long edge, JPEG q85 (~400–600 KB each)
- [x] Configurable budget, default 500 MB across photos and clips, with a readout and a
      warning before it is exceeded

**Definition of done:** two things, both on the phone.
1. At the week-8 checkpoint you shoot four poses in ~90 seconds, each aligned against
   the week-4 ghost, and the wipe slider shows you something the mirror hasn't.
2. You open the phone's gallery app and Google Photos and **the photos are not there.**

> Claude Code must state explicitly how it verified requirement 5.5 before calling this
> phase done.

---

# Phase 6 — Cardio, bodyweight, food

### 6.1 Cardio
- [x] Cardio day runner on the Phase 2 interval engine — skipping intervals and bag
      rounds, audible + haptic transitions, works with the screen off
- [x] Manual run logging: duration, optional distance, perceived effort. **No GPS.**
- [x] `cardioProgression` surfaced per week — Sunday's target comes from the table, and
      **the table wins over the prescription** (audit C4)

### 6.2 Bodyweight
- [x] Quick entry, **7-day rolling average**, `fl_chart` trend
- [x] **The flat rule**: rolling average has not risen for `flatWeeksBeforeBump` weeks →
      card saying *"flat for 2 weeks — add 250 kcal"*, both numbers read from the JSON
- [x] Projected vs actual against doc 01 §7's bodyweight table

### 6.3 Food
- [x] Deliberately minimal: date, kcal, protein, hit-target yes/no, streak
- [x] **Reads the current week's `nutritionPhase`**, so the target escalates (audit C11)
- [x] No food database, no barcode scanning. Those apps exist.

### 6.4 Checkpoints
- [x] Prompts from `programme.checkpoints` on the dashboard and calendar

**Definition of done:** the app notices your weight has been flat for two weeks and says
so, unprompted, before you do.

---

# Phase 7 — Exercise demos and form clips

**Read doc 00's licensing note first. This is the phase with a trap in it.**

### 7.1 Detail screen
- [x] Still, cues, common errors, `soloSafety`, `equipmentNote`, muscles, equipment
- [x] "Watch demo" via `url_launcher`
- [x] **One-tap from inside the runner, returning to the exact set you were on.** A demo
      you have to leave the session to find does not get watched.

### 7.2 Stills — licence-clean only
- [x] Source: `yuhonas/free-exercise-db` (Unlicense, public domain). `wger` (CC-BY-SA)
      is also fine with attribution.
- [x] **Never scrape MuscleWiki, GymVisual, Everkinetic-derived sets or the RapidAPI
      ExerciseDB GIF bundles.** "It's only for me" does not change the copying.
- [x] `stillSearchTerm` in `exercises.json` is a **hint, not a verified slug**. Expect
      misses. Report the list of exercises with no match.
- [x] Record the licence per exercise in `exercises.json`

### 7.3 Video — link, don't bundle
- [x] **Do not invent YouTube URLs.** Generate an empty checklist markdown file for you
      to fill in over a week, and read `media.youtubeUrl` when populated.
- [x] Prefer coaches demoing the *solo home-gym* version — bailing from a squat, floor
      pressing, setting catch pins.
- [x] `youtubeStartSec` skips the intro.

### 7.4 Your own clips — the actually valuable media
- [x] `image_picker` video mode (no overlay needed here — save `camera` for Phase 5)
- [x] App-private `files/clips/<exerciseId>/<timestamp>.mp4`
- [x] `video_player` + `chewie` playback, dated series, delete
- [x] 720p, most-recent-N per exercise, shared 500 MB budget
- [x] Compare week 1 against week 8 — for a solo lifter this is worth more than any
      stock demo

### 7.5 Library
- [x] Search; filter by pattern, muscle, equipment

---

# Phase 8 — Programme editor and cycle 2

### 8.1 Editor
- [x] Edit any prescription: sets, rep range, rest, RIR, increment, start load
- [x] Swap an exercise (offering `substitutes` first), **history preserved** — `set_logs`
      keep their own `exercise_id`, and the engine looks up by `exercise_id`, never by
      prescription id. **Test this.**
- [x] Reorder within a section; add/remove exercises; edit superset grouping
- [x] Add/remove/rename days; change a day's weekday or kind
- [x] Edit `day.warnings` and `coachNote`
- [x] **Detach and duplicate** an inheriting block — materialise the resolved days and
      clear the inheritance
- [x] Writes to the user override JSON, never the bundled asset. Bumps `revision`.

### 8.2 Cycle 2 seeding — the week-13 answer
- [x] `lib/domain/progression/cycle_seeder.dart` per doc 02 algorithm E, **tested first**
- [x] Test-week results → e1RM → new `startLoadKg`, all lattice-valid
- [x] Foundation removed, weeks renumbered from 1, `startDate` set to the Monday after
- [x] **Shown as a diff before it applies**

### 8.3 Import / export
- [x] Programme JSON via `file_picker` + `share_plus`, validated against `schema.json`,
      diff summary before applying
- [x] Revision conflict warning when importing over newer local edits
- [x] "Reset to shipped programme" — delete the override, re-copy the asset
- [x] Full backup/restore extended to include photos and clips (Phase 2 shipped the
      DB + JSON half)

**Definition of done:** you decide mid-block that Bulgarian split squats are wrecking
your knee, swap them for reverse lunges on the phone in the basement, and your squat
history is intact.

---

### What shipped

All of 8.1–8.3, plus three things the phase exposed:

- **`lastSetsForPrescription` now matches the exercise as well as the slot.** It did
  not, so swapping Bulgarian split squats for reverse lunges would have suggested the
  split squat's load for a movement never performed. `test/data/exercise_swap_test.dart`
  is the regression test; the failing run came first.
- **`ProgrammeValidator`** (`lib/domain/programme/programme_validator.dart`) runs gates
  V1–V9 at runtime against *edited* programmes, not just authored ones. `tools/validate.py`
  guards what we write; this guards what gets edited in the basement and what arrives
  through import. Same gate names on both sides.
- Phase 2 shipped `BackupService` with no UI. `/programme/file` is that UI: programme
  export/import with a diff, reset to shipped, and the full zip including photos and
  clips.

A save is never refused on a validation error — it is saved and flagged in place. A
half-finished edit the app will not store is worse than one it stores and shows you.

# Phase 9 — Stats and dashboard

- [x] `lib/domain/metrics/` — pure, tested: Epley e1RM (**labelled as an estimate**),
      best set, tonnage, weekly sets per muscle group from `exercise.primaryMuscles`
- [x] Dashboard: current week and block · streak · week progress · bodyweight sparkline ·
      next session · checkpoint card when due
- [x] Per-lift detail: e1RM trend, best set, volume, full log history
- [x] **Weekly sets per muscle group** — the number that actually drives hypertrophy.
      Flag when any muscle drops below 8 or above 20 sets.
- [x] `strengthTargets` rendered as progress against doc 01 §7's projections, **labelled
      as floors** so missing one is not read as failure
- [x] **Plate-gap report**: *"smallest jump on overhead press is 19% — buy 0.5 kg
      microplates"*
- [x] **Niggle timeline** — which joints complained, when, against which exercise
- [x] Session duration stats — is 60 minutes real, or is it 80?
- [x] Optional evening reminder on planned session days, off by default

---

### What shipped

`lib/domain/metrics/` gained four pure, tested modules — `strength_metrics`
(Epley e1RM, best set, per-day trend, tonnage), `volume_metrics` (weekly sets
per muscle, flagged below 8 and above 20), `plate_gap` and `session_stats` —
plus `lib/domain/calendar/session_reminders.dart` for the evening nudge.
`StatsService` is the only place they meet the database.

Charts are hand-drawn `CustomPainter`s, matching the Phase 6 bodyweight chart.
No charting package was added: two line charts are less code to draw than a
library is to configure, and a new dependency needs asking about.

Three things worth knowing:

- **Every e1RM is labelled an estimate, everywhere it appears**, and a lift
  with no load never gets one invented. An empty chart is honest; a fabricated
  maximum is not.
- **A retroactively logged session contributes no duration.** It has no honest
  start time, and a zero would drag the median down and make the hour look
  safer than it is.
- The **plate-gap report** exists because "you are stalling" and "the smallest
  plate you own is 19% of the bar" look identical in a log and need opposite
  responses.

Fixed in passing: `InfoChip` could overflow its own pill with a long label at
400 px (a Wrap hands its child the full row width), the Today header hardcoded
`of 12` — a programme value in a widget, which the hard rules forbid, and cycle
two is eight weeks — and the strength-target rows fell back to a raw exercise id
for any lift with no logged history.

The evening reminder is **off by default** and stored in `preferences.json`
rather than the database: it is a convenience, and a schema migration to hold
one boolean would put twelve weeks of logs at risk for nothing.

# Phase 10 — Hardening and release

- [x] R8/ProGuard rules written, with a keep rule for every class reached by
      name rather than by reference — **the device run is yours** (see below)
- [x] Version ritual documented in the README, and enforced by
      `test/version_test.dart`
- [x] Drift migration rehearsed against a **populated** database, not an empty
      one — `test/data/migration_test.dart`
- [x] Battery-optimisation exemption documented (it cannot be requested from
      inside the app on modern Android)
- [x] `README.md`: build, install, update, keystore warning, backup/restore,
      and where the photos actually live
- [ ] Tag `v1.0` — **after** the on-device checks below

### What shipped

- **`proguard-rules.pro` rewritten.** The previous file kept four things. R8
  strips anything it cannot see referenced, and three of this app's plugins are
  reached by name: the two notification receivers named as strings in the
  manifest, Gson inside `flutter_local_notifications`, and CameraX. Each rule
  carries the failure it prevents.
- **Migration rehearsal.** `migration_test.dart` builds a v1 database with
  sessions, sets, weigh-ins and a stall counter, winds `user_version` back,
  reopens it and asserts nothing was lost and the cascades still fire. An empty
  database migrates cleanly by definition; the one on the phone in week nine
  is the one that matters.
- **The pre-migration copy now only runs when a migration is actually due.**
  It was copying the whole database on every launch. `schemaVersionOf()` reads
  `user_version` straight out of the SQLite header without opening the file.
- **`privacy_audit_test.dart`** — fifteen checks that fail the build if
  `allowBackup` flips, an `INTERNET` permission appears, any Dart file
  mentions `MediaStore` or `/sdcard/`, an analytics package lands in the
  pubspec, or the release build points at the debug key.
- **The 14-day backup reminder finally exists.** Phase 2 specified it and it
  was never built. `lastBackupAt` lives in `preferences.json` and the card on
  Today appears once there are finished sessions and no recent copy of them.
- **`appVersion` and `pubspec.yaml` had drifted** — 0.2.0+2 against 0.1.0+1 —
  so every backup manifest named a build that never existed. Both are now
  0.10.0+10 and a test keeps them together.

### What is still owed, and only you can do it

These need the phone and a signed build. None of them can be faked from a
desktop, and each has a real failure behind it:

1. A **full session on the release APK**, rest timer running with the screen
   off. Debug builds are not minified and prove nothing about R8.
2. A **full photo shoot on the release APK** — CameraX resolves by name.
3. **Open the gallery and Google Photos and confirm the progress photos are
   not there.** This is the Phase 5.5 requirement and the single most likely
   privacy mistake in the app.
4. Exempt the app from battery optimisation on the device.
5. Export a backup and open the zip on the PC.
6. Then, and only then, `git tag v1.0`.

---

# Risks

| Risk | Mitigation |
|---|---|
| **You build the app instead of training.** The real failure mode. | Phase 1 ships in one evening and replaces doc 01. Train off Phase 1. Never let a half-finished phase block a session. |
| **Losing the keystore** → cannot update without wiping data *and photos* | Generated in Phase 0, backed up to two non-PC locations that same evening. |
| **Progression engine silently wrong for weeks** | Tests A-1..A-14 are not optional. A-4 and A-14 specifically catch the v1 deadlock. |
| **Loads that do not exist on your plates** | Test V6 fails the build. The lattice is the source of truth, not the JSON. |
| **Sessions quietly growing past 60 minutes** | Test V11 fails the build; the runner shows elapsed vs estimate and offers to cut. |
| **Progress photos leaking to Google Photos** | Six requirements in Phase 5.5, verified on device. This is the single most likely privacy mistake here, and it happens **by default** with `image_picker`'s standard save. |
| Drift migrations breaking on a device with real data | Automatic pre-migration copy from Phase 2; rehearse against a real DB copy in Phase 10. |
| Android battery optimisation killing the rest timer | Notification-backed wall-clock timers, exact-alarm permission, exemption prompt. |
| Gradle / JDK / AGP version hell | Phase 0 exists for this. Pin JDK 17. Do not upgrade Flutter mid-phase. |
| Calendar week numbers drifting from reality | `fixed` scheduling by default, plus an explicit "shift programme" action. Tests C-1..C-13. |
| Missing sessions poisoning the engine | Retroactive logging is a first-class Phase 4 flow. |
| Scope creep into a food diary or GPS running app | Those apps exist. This one logs sets. |

# Backlog — after Phase 10, only if you still want them

- CSV export for spreadsheet analysis
- Superset *circuits* (3+ members) — the model supports it, the UI does not
- Auto-regulation from a morning readiness score
- Side-by-side video compare for form clips with the same wipe slider
- Auto-generated progress video: the flipbook rendered to an MP4
- Home-screen widget with today's session
- Wear OS companion for the rest timer
- A second programme slot, so cycle 2 can be planned while cycle 1 runs

---

# Known deviations from the plan

| Planned | Built | Why it stands |
|---|---|---|
| `@riverpod` code-gen providers (also in CLAUDE.md) | Plain `Provider` / `FutureProvider` / `AsyncNotifierProvider` | Every provider was written by hand from Phase 1 onward. It works, it is tested, and it reads fine — but it is not what the conventions say. Converting is mechanical (`riverpod_generator` is already a dev dependency) and touches eight files in `lib/app/`. **Worth doing if you want the conventions honoured; not worth doing mid-cycle if the app is on your phone and training has started.** |
| `chewie` for clip playback (Phase 7.4) | `video_player` with a hand-built control bar | Play, scrub and delete is the whole feature. Fewer dependencies in an app holding a year of logs and a gallery of private photos. |
| `fl_chart` for trends (Phase 6.2, 9) | Hand-drawn `CustomPainter`s | Two line charts are less code to draw than a charting package is to configure, and a new dependency needs asking about. |
| Programme JSON validated against `schema.json` on import (8.3) | Validated against gates V1–V9 by `ProgrammeValidator` | A JSON-schema check would confirm the shape. The gates confirm the thing that actually matters: that the loads exist on your plates and the days resolve. Both run on import; only one of them would have caught v1's 19 unloadable weights. |
