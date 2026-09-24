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
3. `python tools/gen.py && python tools/validate.py` — all gates pass, no diff in the
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

## Where this stands (2026-09-24)

| Phase | State |
|---|---|
| 0 — Foundation | **Done** — `a1888e7` |
| 1 — The programme a coach would sign off | **Done** — `8282b8d`, finished in `e6cd785` |
| 2 — Fuel: the diet plan | next |
| 3 — Animated exercise demos | |
| 4 — GPS runs on OpenStreetMap | |
| 5 — Calendar and Week | |
| 6 — Progress photos and Body | |
| 7 — Launch quote and premium polish | |
| 8 — Hardening and release | |

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
3. `python tools/gen.py && python tools/validate.py` — all gates.
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

## Phase 5 — Calendar and Week

- Month view that swipes, block bands, legend, today, markers (session state, run,
  weigh-in, meals hit, photo shoot, checkpoint), readable labels, month summary.
- A day sheet that shows everything that happened that day and can act on it.
- Week tab shows done/missed state and progress; swipes; "this week".
- **Bugs:** stale after a live session, "adherence" that was really "programme done",
  streak reset every morning, moved sessions leaving a false ✕, a second session on one
  date disappearing, skipped and missed looking identical.

## Phase 6 — Progress photos and Body

- Timeline of shoots by week with weight; before/after slider between any two shoots;
  time-lapse with crossfade; checkpoints that tick themselves.
- Capture: ghost geometrically aligned with the preview, review/retake, sound + haptic
  countdown, no empty shoots, no duplicate rows on retake, images processed off the UI
  thread, correct resolution and orientation, thumbnails.
- Measurements with steppers (no keyboard), per-site history. Weigh-in with a stepper.

## Phase 7 — Launch quote and premium polish

- `data/quotes.json`: Islamic (Qur'an with surah:ayah, sahih hadith with collection and
  number), Greek and Roman (public-domain translations), every attribution verified.
  Addressed to Saad. Never repeats until the pool is used.
- An animated launch screen over the router (deep links and resume untouched), tap or
  wait to continue, skipped when resuming a session. Quote of the day on Today.
- Today rebuilt around the day; the runner gets a finish moment; every remaining screen
  moved onto the kit; hero transitions where they carry meaning.

## Phase 8 — Hardening and release

- Full adversarial review across the release; privacy audit; migration rehearsal from a
  real v0.11 database; release APK built and signed with Saad's key; docs updated.
- What cannot be checked without the phone goes on the on-device checklist.
