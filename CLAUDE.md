# CLAUDE.md — Keller Twelve

Single-user offline Android training app. Flutter + Riverpod + Drift.
One user, one programme, no backend, no accounts, no network.

**Plan:** `docs/03-build-plan.md`. Follow its phases; do not skip ahead.
**Programme:** `docs/01-programme.md`. **Specs:** `docs/02-data-model.md`.
**Why things are the way they are:** `docs/00-audit.md`.

## Hard rules

- **The programme is DATA.** Never hardcode sets, reps, loads, exercise names, rest
  intervals or day structure in Dart. If a value belongs to the training programme, it
  lives in JSON. Hardcoding `4 × 6–8 bench press` in a widget is a bug even if it
  renders correctly.
- **`lib/domain/` is pure Dart.** No Flutter imports, no I/O, no plugins. It is unit
  tested without a device.
- **Test-first, always**, for: the progression engine, the plate solver, the calendar
  projection, the ramp generator, the cycle seeder. Write the tests from
  `docs/02-data-model.md`, show me the failing run, then implement.
- **Kilograms only.** No unit conversion, no imperial.
- **Loads live on the lattice.** A weight the plates cannot make is not a valid weight.
  `isLatticeValid()` gates it, and test V6 fails the build.
- **Never hand-edit a load or an `estMinutes` in `data/*.json`.** They are generated.
  Change `tools/gen.py`, then run `python tools/gen.py && python tools/validate.py` and
  confirm all gates pass. Typing loads by hand is how v1 ended up with 19 unloadable
  starting weights.
- **A superset must not force a re-plate.** Members of the same `groupId` either share a
  load or pair a loaded movement with a bodyweight / cable / banded one. Otherwise the
  superset saves no time and the 60-minute ceiling breaks.
- **No network calls** except `url_launcher` opening a YouTube link. No analytics, no
  crash reporting, no cloud, no auth, ever.
- **`set_logs` store their own `exercise_id`.** Never resolve history through the live
  programme JSON — exercises get swapped and history must survive.
- **Never scrape or bundle copyrighted exercise images or GIFs.** Unlicense/CC sources
  only, licence recorded per exercise. **Never invent a YouTube URL.**
- **Sessions must fit 60 minutes.** Test V11 enforces it. If a change pushes a lift day
  over, cut volume — do not raise the estimate.

## Progress photos — non-negotiable

- App-private storage only. **Never** `MediaStore`, **never** `/sdcard/Pictures`, never
  a path the phone's gallery or Google Photos can see.
- `android:allowBackup="false"` **and** `backup_rules.xml` excluding the photo directory.
- No code path may upload, share or sync a photo. Export is manual and user-initiated.
- Deleting a photo or shoot deletes the **files**, not just the DB rows.
- Never commit anything under `photos/` or `clips/`.

## Signing and data safety

- The release keystore exists from Phase 0. **Never** point `buildTypes.release` at
  `signingConfigs.debug` — changing the signing key later forces an uninstall, which
  deletes the database and every progress photo.
- Never commit `key.properties` or `*.jks`.
- Take an automatic copy of the database before any Drift migration runs.

## Conventions

- `flutter analyze` clean before any commit. Warnings are errors.
- `dart format .` before any commit.
- Conventional commits: `feat`/`fix`/`refactor`/`test`/`chore`, scoped by feature.
- One phase per branch: `phase-4-calendar`. Merge when the APK is on my phone.
- Tag each merge: `v0.1-phase1`, `v0.2-phase2`, … so I can always return to a build that
  worked in the basement.
- Riverpod code-gen providers (`@riverpod`). No global mutable state.
- Every new domain function gets a unit test in the same change.

## Device reality

I train alone in a basement, in poor light, with chalky hands, between heavy sets, on a
60-minute clock. The UI must be dark, high contrast, 48 dp minimum targets, one-handed,
steppers and chips over keyboards, readable at arm's length. **Colour is never the only
carrier of meaning** — pair it with a glyph.

## What to ask me about

- Anything that changes the training programme's meaning (sets, reps, progression rules,
  exercise selection)
- Any new dependency
- Anything that would add a permission to the manifest

**Do not ask me about:** naming, file layout, widget structure, test structure. Decide.
