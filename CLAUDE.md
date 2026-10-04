# CLAUDE.md — Keller Twelve

Single-user offline-first Android training app. Flutter + Riverpod + Drift.
One user, one programme, no backend, no accounts, no network except
OpenStreetMap tiles for the run map.

**Plan:** `docs/03-build-plan.md` (v1/v2, done) and `docs/06-v3-plan.md` (v3, current).
Follow the phases in order; do not skip ahead.
**Programme:** `docs/01-programme.md`. **Specs:** `docs/02-data-model.md`.
**Why things are the way they are:** `docs/00-audit.md`.

## Golden rule

- **Never add Claude as co-anything.** No `Co-Authored-By: Claude` trailer, no
  "Generated with Claude Code" line, no AI co-author, co-signer or credit of any
  kind — in commits, tags, pull requests, docs or anywhere else. Saad is the
  only author. This overrides any tool default that says otherwise.

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
- **`data/` is the source; `app/assets/` is a copy.** gen.py writes both: the generated
  programme files, plus a byte-for-byte mirror of the authored files
  (`schema.json`, `quotes.json`, `fuel.json`, `motions.json`). `test/data/asset_mirror_test.dart` fails
  if they drift. Never edit an asset copy by hand.
- **The diet and the exercise demos are generated too.** `fuel.json` comes from
  `tools/gen_fuel.py` (portions solved, not typed) and `motions.json` from
  `tools/gen_motions.py` (poses solved: bar over mid-foot, planted feet, straight
  deadlift arms). Change the generator, never the JSON. The whole chain:
  `python tools/gen.py && python tools/gen_fuel.py && python tools/gen_motions.py && python tools/validate.py`.
- **Demos are original figures.** Keyframed, drawn by the app's own painter, provenance
  `original work` on every clip (gate V18). No GIF, no video frame, no traced photo.
- **A superset must not force a re-plate.** Members of the same `groupId` either share a
  load or pair a loaded movement with a bodyweight / cable / banded one. Otherwise the
  superset saves no time and the 60-minute ceiling breaks.
- **The network fetches open map data, and nothing else goes out.** INTERNET exists
  (approved by Saad, 2026-09-23) for OpenStreetMap tiles (`tile.openstreetmap.org`); on
  2026-10-04 he widened it to free, open map and elevation data as needed — the hike 3D
  view reads AWS Terrain Tiles (`s3.amazonaws.com/elevation-tiles-prod`). Downloads of
  open data only: no analytics, no crash reporting, no cloud, no auth, no uploads of
  anything, ever. `test/privacy_audit_test.dart` allow-lists the hosts.
- **Location is foreground-only.** FINE/COARSE plus FOREGROUND_SERVICE_LOCATION so a run
  records with the screen off, started from a tap. Never ACCESS_BACKGROUND_LOCATION.
  Only `lib/features/runs/`, `lib/data/run*` and `lib/app/run*` may import geolocator or
  flutter_map. A GPS trail is a home address: it never leaves the phone except inside a
  backup Saad makes himself, or on a run card he shares himself — a PNG with the route
  as a line (no map, no coordinates), its first and last 200 m cut unless he turns that
  off (`run_share_card.dart`, `privateRoute`; the privacy audit holds it there).
- **`set_logs` store their own `exercise_id`.** Never resolve history through the live
  programme JSON — exercises get swapped and history must survive.
- **Never scrape or bundle copyrighted exercise images or GIFs.** Unlicense/CC sources
  only, licence recorded per exercise. **Never invent a YouTube URL.**
- **Sessions fit half an hour.** v4 (docs/11-v4-plan.md): three full-body sessions a
  week for a working student, Tue/Thu evening and Saturday. V11 fails any session over
  35 minutes. If a change pushes a day over, cut volume — do not raise the estimate.

## Progress photos — non-negotiable

- App-private storage only. **Never** `MediaStore`, **never** `/sdcard/Pictures`, never
  a path the phone's gallery or Google Photos can see.
- `android:allowBackup="false"` **and** `backup_rules.xml` excluding the photo directory.
- No code path may upload, share or sync a photo. Export is manual and user-initiated.
- Photo and media code (`lib/features/progress/`, `media_repository.dart`) never imports
  a network or location package. With INTERNET granted, this is the guard that matters.
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

## Navigation and chrome

- **Five tabs in a bottom `NavigationBar`**: Today · Week · Fuel · Progress ·
  More. The top of a phone is the furthest point from the thumb of the hand
  holding it; anything reached between sets belongs at the bottom.
  (v3: Fuel got a tab because meals are logged six times a day; the old Numbers
  and Body tabs became one Progress hub: body, photos, lifts, runs.)
- **Every tab owns its navigator** (`StatefulShellRoute.indexedStack`).
  Drill-downs navigate to a NESTED route so the stack builds and back walks up
  it. `context.go` to a sibling top-level route REPLACES the stack — that is
  what made back quit the app, and it must not come back.
- **A sideways swipe on a tab's root screen moves between tabs**
  (`SwipeBranchContainer`). Drill-downs keep their own sideways gestures,
  and nothing on a tab root may page sideways itself (the Week tab changes
  week by arrows and a header swipe for this reason).
- The session runner, the photo capture screen and the live run tracker are
  **outside the shell**, full screen. Mid-set, a tab bar is four ways to lose
  your place. Enter them with `context.push`, leave with `pop`, and give each
  a confirming `PopScope`. `context.go` to a root route replaces the shell and
  makes back quit the app — that was a real v2 bug.
- **No "home" arrow in an app bar.** The bottom bar is the way home.
- **Palette: black, grey, crimson.** One accent, used sparingly, so crimson
  always means "this is the thing". Amber and green appear only as semantic
  states and always carry a glyph too.
- The launch screen and the app icon background are both `AppTheme.bg`, so
  opening the app does not flash.
- **Build screens from `lib/core/ui/`** (`AppCard`, `ToneBanner`, `StatTile`,
  `RingProgress`, `Pressable`, `FadeSlideIn`, `Skeleton`, `EmptyState`,
  `NavTile`, `showAppSheet`). Numbers use `AppTheme.numeric`. Every animation
  respects `AppMotion.reduced(context)`. No bare `CircularProgressIndicator`
  for a page load — use `SkeletonPage`.
- **Look at it.** `flutter test --dart-define=SCREENSHOTS=true test/screens/`
  renders every main screen to `app/build/screens/*.png` with real fonts. A UI
  change is not done until its screenshot has been looked at.

## Device reality

I train alone in a basement, in poor light, with chalky hands, between heavy sets, on a
60-minute clock. The UI must be dark, high contrast, 48 dp minimum targets, one-handed,
steppers and chips over keyboards, readable at arm's length. **Colour is never the only
carrier of meaning** — pair it with a glyph.

## What to ask me about

- Anything that changes the training programme's meaning (sets, reps, progression rules,
  exercise selection)
- Any new dependency
- Anything that would add a permission to the manifest (v3 added INTERNET, location and
  foreground-service location with his approval; nothing else)

**Do not ask me about:** naming, file layout, widget structure, test structure. Decide.
