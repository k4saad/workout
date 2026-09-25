# 06 — v3 plan: phase by phase

v3 answers one message from Saad (2026-09-23): the calendar and progress photos are
lacking, exercises have no animated demo, the diet plan is not really implemented, the
programme must be right for a 167 cm / 50 kg beginner, the whole app should feel premium,
a motivational quote (Islamic, Greek, Roman) should greet him by name on launch, weights
should be definitive rather than "weigh your bar", and runs should be GPS-tracked on
OpenStreetMap with the trail on the calendar.

**How it is built: one phase at a time.** Each phase ends with the same gate, and the next
phase does not start until it passes:

1. `cd app && flutter analyze` — no issues.
2. `cd app && flutter test` — everything green.
3. `python tools/gen.py && python tools/gen_fuel.py && python tools/gen_motions.py &&
   python tools/validate.py` — all gates pass, no diff in the
   generated files beyond what the phase intended.
4. `flutter test --dart-define=SCREENSHOTS=true test/screens/` — every screen the phase
   touched has been LOOKED at.
5. An independent review of the phase's diff (correctness, the CLAUDE.md rules, and
   whether it actually does what this document says), with every confirmed finding fixed.
6. `dart format .`, then one conventional commit for the phase.

Decisions Saad made up front: GPS tracking with the screen off (INTERNET for tiles,
fine + foreground-service location, never background); meals halal, built from German
supermarket staples.

---

## Where this stands (2026-09-25)

| Phase | State |
|---|---|
| 0 — Foundation | **Done** — `a1888e7` |
| 1 — The programme a coach would sign off | **Done** — `8282b8d`, finished in `e6cd785` |
| 2 — Fuel: the diet plan | **Done** — `d955501` |
| 3 — Animated exercise demos | **Done** — see below |
| 4 — GPS runs on OpenStreetMap | **Done** — see below |
| 5 — Calendar and Week | **Done** — see below |
| 6 — Progress photos and Body | **Done** — see below |
| 7 — Launch quote and premium polish | **Done** — see below |
| 8 — Hardening and release | **Done** — APK built; on-device checks in `docs/07-on-device-checklist.md` |

Phase 1's review found 24 issues and its fixer was interrupted partway,
leaving eight failing engine tests — written for confirmed findings, none
implemented. Those are done (`e6cd785`) and the branch is merged to `master`:
**681 tests, analyze clean, gates V1–V17.** The worktree is gone; everything
is in the main checkout.

### How the remaining phases get built

The plan was never the problem. The last run spent its budget on 31-agent
review-and-fix swarms that re-derived context they already had, and stopped
mid-surgery. So:

- **No agent swarms.** The work is done directly, in this session, in order.
- **One phase per commit**, each ending on the gate below.
- **Test-first for anything with arithmetic in it** — the meal solver, the
  run maths, the motion rig — as CLAUDE.md already requires.
- When something is cut, it is **said out loud** rather than left looking done.

The gate, unchanged and non-negotiable:

1. `flutter analyze` clean.
2. `flutter test` green.
3. `python tools/gen.py && python tools/gen_fuel.py && python tools/gen_motions.py &&
   python tools/validate.py` — all gates (V1–V20).
4. Screens the phase touched have been **looked at**, not just asserted on.
5. `dart format .`, one conventional commit.

## Phase 0 — Foundation

Everything the later phases stand on, so none of them has to invent it.

- Dependencies: `geolocator`, `flutter_map`, `latlong2`. Bundled display font
  (Roboto Condensed, Apache-2.0, copied from the Flutter SDK's own cache).
- Manifest: INTERNET, FINE/COARSE, FOREGROUND_SERVICE(_LOCATION); predictive back on.
  R8 keeps geolocator. A status-bar glyph for the run notification.
- `privacy_audit_test.dart` rewritten as allow-lists: tile host only, no background
  location, photo code cannot import a network/location package, only the run feature
  may import geolocator/flutter_map.
- DB schema v3: `runs`, `run_points`, `meal_logs`, `water_logs`, `supplement_logs`,
  `nutrition_adjustments`. New tables only. Migration and backup round-trip tests.
  Later phases extend the same `from < 3` branch — one migration per release.
- Theme rebuilt: the text styles are derived, not replaced (v2 dropped the font family
  on every heading); radius and motion tokens; every component themed.
- `lib/core/ui/`: the house kit (cards, banners, stats, rings, press feedback, entrance
  motion, skeletons, empty states, nav tiles, sheets).
- IA: Today · Week · **Fuel** · **Progress** · More. Fuel placeholder, Progress hub.
  Tabs fade through without losing their stacks.
- **Bug fixed:** the runner and the capture screen were entered with `context.go`, which
  replaced the shell — back mid-session closed the app. Now pushed, with a confirm.
- Preferences: `athleteName` (default Saad), `launchQuote`, `recentQuoteIds`.
- `tools/gen.py`: paths relative to the repo (it wrote into the main checkout from a
  worktree); writes `app/assets/` too; **stopped wiping the 26 licensed exercise stills**
  on every run; mirrors authored content. `asset_mirror_test.dart` guards the copies.
- Screenshot harness: real fonts in widget tests, full-app tour to PNG.

## Phase 1 — The programme, as a coach would sign it off

The coach's review found the engine cannot deliver the programme's own projections.

- **Definitive equipment** (no more "weigh your bar"): barbell 10 kg, EZ bar 7 kg,
  handles 2 kg (all including collars); plates 20×2, 10×4, 5×8, 2.5×8, 1.25×8 plus
  **1 kg ×4 and 0.5 kg ×8** to buy. Every whole kg is loadable on every implement.
  The in-app gym screen becomes "your equipment": what to own, what each week-12 target
  needs per side. Every placeholder / bathroom-scale nag goes.
- **Engine fixes, test-first:**
  1. The 10% jump cap froze every barbell lift near 17 kg by week 11 — `maxJumpPct` is
     set per prescription so empty-bar starts can actually climb.
  2. The week-8 deload became the history week 9 progressed from (0.7× the load).
     Deload sessions are excluded from progression history.
  3. Rep creep deadlocked on light dumbbell work: the log stored the prescription's
     rep range, not the suggested one. Log the suggestion's targets.
  4. The runner pre-filled `startLoadKg` every week instead of the suggestion.
  5. Foundation `defaultRir` 4 blocked jumps when RIR 3 was logged; now 3.
  6. The cardio table was never applied — runs showed the static block value.
- **Programme changes** (coach's MUST list): side-delt and triceps work in Build,
  hamstring curl replaces the suitcase carry on Lower B, Push-block nordics re-pointed,
  targets re-derived from the fixed engine. Foundation gains a low-skill arms/delts
  superset and ramps on the main lifts (within ~45 minutes). V11 still passes.
- **Installed phones pick it up:** the programme and inventory are copied once and never
  refreshed. A shipped-revision upgrade replaces an older copy (backing it up, keeping
  the start date).

## Phase 2 — Fuel: the diet plan

A dietitian's plan, halal, from Aldi/Lidl/Rewe staples, as data.

- `data/fuel.json`: ~50 foods (per-100 g label values, German names, pack sizes, halal
  notes), 7 slots timed around an evening session, 3–4 templates per slot, phase
  modules (2,600 → 2,750 → 2,900 kcal), +250 boosters, supplements, hydration, the halal
  buying guide. **Meal macros are computed from grams, never typed** (same lesson as the
  loads). Gates: every combination within ±3 % kcal and −3/+5 % protein of the phase, fat
  ≥ 40 g, every food id resolves, nothing pork or alcohol.
- Domain (test-first): resolve a day's plan for a date (phase, training/rest, session
  time, applied adjustments), totals, portions, weekly grocery list, adherence.
- **Fix the +250 rule:** it was recomputed on every read, so it vanished the moment it
  worked. Applied adjustments persist; the flat-weeks count resets after one; adherence
  gates it (≥ 85 % of days hit, or the advice is "eat the plan"); the day-4 false alarm and
  the unbounded waist check are fixed.
- UI: the Fuel tab — rings (kcal, protein), the day as a timeline around the session,
  meal cards with grams, eaten / half / skip, swap sheet, water, supplements, grocery
  list, guide. A "next meal" card on Today. Food content leaves Dart.

## Phase 3 — Animated exercise demos

Original figures, drawn from keyframes. No GIFs, no scraping, nothing copyrighted.

- `lib/domain/motion/`: a 2-D skeleton, two-bone IK for planted feet and gripping hands,
  eased keyframe interpolation. Pure Dart, tested (bone lengths hold, targets reached).
- `data/motions.json`: motion archetypes with keyframes and props (bar, dumbbells,
  bench, pull-up bar, rings, band, cable, rope, bag), and a mapping for **all 76**
  exercises, each with provenance `original work`. Gate: every exercise has a motion.
- A painter in the house style — crimson on the working muscles — shown as the hero of
  the exercise screen, in the runner card, and as thumbnails in the library.
  Every archetype is rendered to PNG and looked at.

### What Phase 3 shipped

- **The rig** (`app/lib/domain/motion/`, pure Dart, 52 tests written first): two-bone IK
  that never stretches a bone, eased keyframes, targets that are world points (a planted
  foot), trunk points (a bar on the back) or joint angles, and a per-bone projection
  factor. That last one is the honest answer to "a wide grip seen side-on": an arm that
  swings out of the picture is drawn shorter, instead of being bent to fake it.
- **75 clips for all 78 exercises**, generated by `tools/gen_motions.py` with Saad's
  proportions (167 cm). Poses are solved: the squat keeps the bar over mid-foot, the
  deadlift bar travels a vertical line with straight arms, feet never skate. Side views
  by default; overhead presses, lateral raises, skipping and the side plank from the
  front; pull-ups and the pull-apart from behind, so the muscle doing the work faces you.
- **Checked frame by frame** against the real rig (120 frames a clip): no stretched bone,
  no hand more than 5 mm off its bar, nothing through the floor, every demo shows at
  least one primary muscle from its viewpoint. Gate V18 in `validate.py` checks mapping,
  provenance, regions and props.
- **On screen:** the hero of the exercise page (tap to hold a frame), an 88 px moving
  demo beside the name in the runner (tap for the full page), still thumbnails in the
  library. Crimson on the primary muscles, a darker red on secondary ones, and the
  muscles are still named in the chips. Reduced motion shows the still frame.
- **Looked at:** every clip on contact sheets
  (`flutter test --dart-define=SCREENSHOTS=true test/screens/motion_sheet_test.dart`),
  twice; nine clips were redrawn after the first look.
- **Cut, said out loud:** the figure is a clean mannequin, not a muscled anatomy chart,
  and depth is suggested, not modelled; the 90/90 hip switch and the doorway stretch
  are the least readable clips and will be the first to improve. The "no demo link"
  developer note is gone from the exercise page; video links stay filled in by hand.

## Phase 4 — GPS runs on OpenStreetMap

- `lib/domain/run/` (test-first): haversine, jitter/accuracy filtering, moving time,
  pace, splits, auto-pause, pace band guidance.
- Tracker: geolocator stream with the foreground-service notification; points persisted
  as they arrive; a killed app resumes the run as a new segment.
- Live screen (full-screen, outside the shell): map with the trail, start marker, big
  distance / time / pace / speed, pause, hold-to-finish. Summary: trail with start and end
  markers, splits, pace chart. Runs list, per-run detail, runs on the calendar.
- A run started from a programme cardio day logs its time and distance into that
  session, which also fixes the runner storing seconds as reps.
- OSM tile policy: user agent, attribution, no bulk prefetch, bounded cache, dark tiles.

### What Phase 4 shipped

- **The run maths** (`app/lib/domain/run/`, pure Dart, test-first): haversine, a fix
  filter (accuracy, stale, impossible jumps), distance counted in steps so GPS drift
  standing at a crossing adds nothing, auto-pause with hysteresis on displacement
  speed, moving time, current and average pace, kilometre splits, a 100 m pace
  profile, climb with a smoothed altimeter, and a pace guide centred on his OWN recent
  easy runs (median ± 6 %), not on a number typed into the programme.
- **The tracker** persists every accepted point as it arrives. Pause breaks the trail
  and counts nothing across it; a run open when the app was killed is picked up as a
  new segment (Today and the Runs page both offer it).
- **Screens:** a full-screen live run (outside the tab bar) with the trail on dark
  OpenStreetMap tiles, distance big enough to read at pace, pause, and a finish that
  has to be held for 1.2 s; the end of it is the summary (fitted trail with start and
  finish markers, splits with the quickest marked, pace chart, effort 1–10). Progress
  gets a Runs page (totals, free run, every run with its trail shape) and a page per
  run; the calendar marks run days and the day sheet lists them.
- **Programme runs:** the runs the library tags `gps` (easy run, intervals, the 5K)
  show "Run it with GPS" in the session runner. The finished run logs itself as the
  set: seconds in the seconds column, metres in the metres column. The runner now
  reads a run as `24–26 min` and a 5K as `5 km`, and shows no RIR for timed or
  distance work (the "seconds as reps" labels are gone).
- **Tile policy:** app-id User-Agent, visible attribution linking to the OSM copyright
  page, only on-screen tiles, an 80 MB cache in app-private storage.
- **Cut, said out loud:** screen-off recording, the foreground notification and the
  real tiles can only be proved on the phone; they go on the on-device checklist in
  Phase 8. The 5K time trial gets no pace guide (a test is not run to a band).

## Phase 5 — Calendar and Week

- Month view that swipes, block bands, legend, today, markers (session state, run,
  weigh-in, meals hit, photo shoot, checkpoint), readable labels, month summary.
- A day sheet that shows everything that happened that day and can act on it.
- Week tab shows done/missed state and progress; swipes; "this week".
- **Bugs:** stale after a live session, "adherence" that was really "programme done",
  streak reset every morning, moved sessions leaving a false ✕, a second session on one
  date disappearing, skipped and missed looking identical.

### What Phase 5 shipped

- **The six bugs, each with a test that failed first:**
  - *Stale calendar:* sessions are now a live stream. Finish a session and
    the calendar, the week and the streak already know.
  - *"Adherence" that was really "programme done":* adherence is done over
    what was **due** (a perfect first fortnight is 100 %, not 17 %). Progress
    through the programme is its own number beside it. Optional days count
    for neither.
  - *Streak reset every morning:* today does not break the streak until
    today is over.
  - *Moved sessions leaving a false ✕:* the date a session moved away from
    shows **→** and is not missed. The date it moved to shows **↷**.
  - *A second session on one date disappearing:* a date keeps every session
    drawn on it. The cell counts them (`✓+1`) and the day sheet lists both.
  - *Skipped and missed looking identical:* a deliberate skip is **⊘**, a
    no-show is **✕**. History uses the same glyphs.
- **Found and fixed on the way:**
  - Every day-range query in the new providers used an inclusive `between`
    up to the next midnight. That pulled the 1st of next month's weigh-in
    into this month, and tomorrow's weigh-in onto today's sheet. The ranges
    are half-open now, with DST-safe day arithmetic.
  - "Correct it" on a session moved onto a date opened that date's own
    session. It now opens the moved session, by its own day and planned
    date.
  - The Week tab's deload and test banners had the programme's numbers
    typed into Dart. They now read each block's `summary` from the data.
  - "1 sets" is now "1 set".
- **Calendar:**
  - Months swipe (the provider is the single source of truth; the pages
    follow it). "Today" appears when you have wandered off.
  - A band opens each block, and the week column carries its block colour.
  - A crimson flag marks a checkpoint week; tap it for the list.
  - Each cell has a glyph and up to three markers: photo shoot, run,
    weigh-in, meals hit (85 % of planned portions, halves counting as
    halves).
  - Under the grid: the month in numbers (sessions against what was due,
    missed and skipped, km run, weigh-ins with the change, fed days,
    shoots) and a key to every mark.
- **Day sheet:** one place to see and act on a date, from the calendar or
  the week.
  - What became of its own session (done, moved and where, missed with the
    reason to log it).
  - Every session logged there, with its sets, "Correct it", and "Move to
    another date".
  - Start, log from memory, or mark skipped, depending on what the day is.
  - The weigh-in, meals and kcal against plan, photos, and runs.
- **Week tab:**
  - Weeks swipe, with a "This week" button to come back.
  - A progress card: done of required, one bar segment per session, missed,
    skipped and still to come.
  - Every day card says what happened (✓ done, ✕ missed, ⊘ skipped,
    → moved to Thu 22, ↷ Wed's session done here) and shows any run.
  - The checkpoint's list on checkpoint weeks, with "Take the photos" in
    the current week.
  - Tapping a day opens its sheet.
- **Cut, said out loud:**
  - Checkpoint items do not tick themselves yet. That needs the capture
    screen to record what it took, which is Phase 6.
  - The small "from memory" mark moved out of the calendar cell (no room
    beside four other signs). It is on the sheet and the week card.
  - A session that has not been started cannot be moved ahead of time; only
    logged sessions move, as before.

## Phase 6 — Progress photos and Body

- Timeline of shoots by week with weight; before/after slider between any two shoots;
  time-lapse with crossfade; checkpoints that tick themselves.
- Capture: ghost geometrically aligned with the preview, review/retake, sound + haptic
  countdown, no empty shoots, no duplicate rows on retake, images processed off the UI
  thread, correct resolution and orientation, thumbnails.
- Measurements with steppers (no keyboard), per-site history. Weigh-in with a stepper.

### What Phase 6 shipped

- **Checkpoints that tick themselves.** Each checkpoint in the data now says
  which of its lines the app can check (`autoTick`, written by `gen.py`,
  guarded by new gate **V19**):
  - a shoot with every pose;
  - every site in the programme's new `measurementSites`;
  - a weigh-in;
  - no session missing.

  The evidence counts from the checkpoint week and the week before, so a
  shoot on the Sunday before counts. The other lines are ticked by hand.
  The same checklist shows on Today, the Week tab and the calendar.
  (`lib/domain/progress/checkpoint_review.dart`, test-first.)
- **Capture, rebuilt:**
  - The preview, the ghost and the review share one frame of the camera's
    shape, so what lines up on screen lines up in the photos (v2 scaled the
    ghost to the whole screen).
  - The front camera by default: he shoots alone, and only the screen side
    shows the ghost. The lens is remembered.
  - A 3 / 5 / 10-second timer with pips and a buzz each second. The pips
    are made in code, so there is no sound file.
  - Review with Keep or Retake, and Skip for a pose.
  - No shoot is written until the first photo is kept, so backing out
    leaves nothing. Empty shoots from v2 are tidied on open.
  - A retake replaces its row instead of adding one.
  - Processing runs in an isolate: turned upright once, every EXIF tag
    stripped (a location tag has no business in these files), 1920 px long
    edge, and a 480 px thumbnail, all app-private.
  - Also fixed: two callers seeding the poses at once collided on the
    primary key.
- **Photos screen:**
  - A timeline by programme week, with each checkpoint flagged, the weight
    and the change since the first shoot.
  - Compare any two shoots of a pose, as a wipe or side by side.
  - A time-lapse that crossfades frame to frame.
  - A viewer per shoot. Deleting deletes the files.
  - Photos, measurements and weigh-ins are live streams now; nothing needs
    invalidating.
- **Body:**
  - Weigh-in on a stepper (±0.1, ±1, hold to repeat), starting from the
    last reading.
  - The tape moved here from Photos: the programme's five sites first, hips
    and calf as optional, each on a stepper with its history and change.
  - The waist rule is read from the programme's numbers. It was typed into
    Dart.
- **Cut, said out loud:**
  - Whether a front-camera photo is saved mirrored like its preview (the
    ghost assumes it is, which is CameraX's default) can only be seen on
    the phone. So can the pips' volume. Both go on the Phase 8 checklist.
  - The lens is remembered but not stored per photo, so nothing warns when
    two compared shoots used different lenses.
  - The v2 one-tap "Did you hit it?" food card is gone from Body. The Fuel
    tab is the food log, and the card showed a phase-level kcal target that
    disagreed with Fuel's per-day plan. Today's "Eat today" card still
    shows the phase number; Phase 7's Today rebuild replaces it.
  - Hand ticks live in `preferences.json`, like the other conveniences,
    not in the training database.

## Phase 7 — Launch quote and premium polish

- `data/quotes.json`: Islamic (Qur'an with surah:ayah, sahih hadith with collection and
  number), Greek and Roman (public-domain translations), every attribution verified.
  Addressed to Saad. Never repeats until the pool is used.
- An animated launch screen over the router (deep links and resume untouched), tap or
  wait to continue, skipped when resuming a session. Quote of the day on Today.
- Today rebuilt around the day; the runner gets a finish moment; every remaining screen
  moved onto the kit; hero transitions where they carry meaning.

### What Phase 7 shipped

- **55 quotes, every one checked against its source** (`data/quotes.json`,
  gate **V20**; `python tools/verify_quotes.py` re-checks them, network
  needed):
  - **18 from the Qur'an** in Pickthall (1930), by surah:ayah. Each excerpt
    was matched word for word against Tanzil's text of Pickthall.
  - **11 hadith** from Sahih al-Bukhari and Sahih Muslim, by their standard
    numbers. Each number was checked in an open hadith dataset. For Muslim
    that meant the Abdul-Baqi numbering, since the dataset's own index
    differs. The English is the meaning in plain words, so no modern
    copyrighted translation is copied.
  - **12 Greek and 14 Roman**, only in public-domain translations: George
    Long's Marcus Aurelius and Epictetus, Evelyn-White's Hesiod, Dakyns's
    Xenophon, Chase's Aristotle, Jowett's Plato, Stewart's Seneca,
    Shuckburgh's Cicero and Smart's Horace. Each was matched against the
    Project Gutenberg text, and the Meditations book numbers were read from
    the translation's own markers.
  - Left out rather than risked: Surah 103. Every digital Pickthall reads
    "man is a state of loss", which looks like a transcription slip, and
    there was no printed copy to settle it.
- **A quote a day, never the same one twice until all 55 have had their
  day** (`lib/domain/content/quotes.dart`, test-first). A new round never
  opens with the quote that closed the last.
- **The launch screen** sits over the router, not in it, so deep links and
  resumes land where they would have. It greets him by name ("Good
  morning, Saad."), sets the day's quote with its source and translator,
  and leaves on a tap or after enough time to read it. It shows on the
  first open of the day only, never when a session or run is waiting, and
  it can be switched off in Settings.
- **Today, rebuilt around the day:**
  - The session still to do is the one crimson card. Once done, skipped or
    moved, it says so quietly and is not offered again.
  - Below it: the quote of the day, what to eat next, a one-tap weigh-in
    with the trend, the week as seven marks, the checkpoint, and cardio.
  - The phase-level "Eat today" card that disagreed with Fuel's per-day plan
    is gone.
- **The end of a session:** the ring fills, then sets, movements, kilos on
  the bar and minutes count up (`SessionSummary`, test-first; no time for a
  session logged from memory or left open overnight).
- **Hero transitions where they mean something:** a photo grows from its
  thumbnail into the viewer, which now opens on the pose that was tapped,
  and an exercise's figure flies from the library into its page.
- **The rest onto the kit:** 15 plain Cards became AppCards; every page
  load is a skeleton instead of a bare spinner.
- **Cut, said out loud:**
  - The serif for quotes is Android's system serif (Noto Serif), which the
    test renderer does not have, so the screenshots show it in the sans. It
    goes on the on-device checklist.
  - Hero flights into the session runner were not added: the runner is on
    the root navigator, and a hero cannot cross navigators.
  - The video player keeps its buffering spinner; it is media loading, not
    a page.

## Phase 8 — Hardening and release

- Full adversarial review across the release; privacy audit; migration rehearsal from a
  real v0.11 database; release APK built and signed with Saad's key; docs updated.
- What cannot be checked without the phone goes on the on-device checklist.

### What Phase 8 shipped

- **The migration, rehearsed on a real v0.11 database.** The v0.11.0+11
  code itself, checked out at `8af0b7c`, logged two weeks through its own
  services: 110 sets, a partial, a skip, a moved session, one left open when
  the app died, weigh-ins, the tape, cardio, food ticks, a niggle, a stall
  counter and a photo shoot. That file is `app/test/fixtures/v0.11.0+11.sqlite`.
  `v011_rehearsal_test.dart` opens it with v0.12 and checks:
  - the pre-migration copy is byte-identical;
  - every row survives, and the file is v3;
  - the new tables take rows;
  - the open session still resumes;
  - the photo rows are kept;
  - a second launch takes no second copy;
  - the upgraded database backs up and restores whole.

  `prepareDatabaseFile` was split out of `openConnection` so the copy could
  be rehearsed at all.
- **A privacy bug, found and fixed.** Every backup exclusion named the
  `file` and `database` domains, but the app keeps everything in
  path_provider's documents directory, `app_flutter/`. So the rules excluded
  folders the app never uses. On Android 12+, `allowBackup="false"` does not
  stop a phone-to-phone transfer, so a new phone would have received the
  progress photos. The rules now name `root:app_flutter/…`: cloud backup
  excludes all of it, and a device transfer excludes photos, thumbnails and
  clips. The audit test checks the domain and the path, not a substring.
- **A stale "today", fixed.** The date was read once, and Android keeps the
  app in memory for days. The next morning it could still show yesterday's
  session and quote. It now rolls over on every resume and at midnight
  (calendar midnight, DST-safe), and a hand-pinned date stays pinned.
- **The release:**
  - `apk/keller-twelve-0.12.0+12-arm64.apk` and `-arm32.apk`, signed with
    Saad's key.
  - Certificate `389b93bc…b7b5`, the same as v0.11's, so it installs as an
    update and keeps the data.
  - Version code 2011 → 2012.
  - The merged-manifest permissions differ from v0.11 by exactly the five
    approved for v3: INTERNET, fine and coarse location, FOREGROUND_SERVICE,
    FOREGROUND_SERVICE_LOCATION. There is no background location.
- **Said out loud:**
  - The merged manifest still carries permissions v0.11 already had, added
    by plugins, not by app code: RECORD_AUDIO (camera),
    READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE up to Android 9 (file
    and image pickers), and USE_BIOMETRIC. None is new. Stripping them would
    be a manifest change to discuss, not to slip in.
  - The build warns that the CupertinoIcons font is absent. No app code uses
    it; the framework's adaptive widgets reference it and this Material-only
    app never draws them.
  - The rest is on the phone: `docs/07-on-device-checklist.md`.

