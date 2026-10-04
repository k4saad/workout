# v4 — fit, not bodybuilding: a working student's week, and hikes

Saad, 2026-10-04: a working student (19¼ h a week across two jobs, plus a
full winter semester); no time for a bodybuilding block; eats four times a
day — breakfast, lunch, a small evening snack, dinner. Wants to be fit.
And: a hike section like runs, with the trail shown as a 3D mountain.

Decided with him:

- **3 × 30 min** full body: **Tue and Thu evening** (after 17:45), **Saturday
  morning**. Monday (07:00–19:45) and the other days are rest. Sunday is an
  optional run or hike.
- **~2,300 kcal** in his four meals — a little above maintenance, because
  at 50 kg / 167 cm he is underweight; no shakes, no six-meal day.
- **Real terrain** for hikes, from free open data over the internet.
- The new plan starts **Monday 12 October 2026**, with the semester.

## Phase G — the programme: three 30-minute sessions

`tools/gen.py`, regenerated, every gate green (the session ceiling becomes
**35 minutes**, V11).

- Every block: Mon rest · **Tue A** · Wed rest · **Thu B** · Fri rest ·
  **Sat C** · Sun *Run or hike* (optional, easy, the run table).
- Foundation (1–4): A squat · push-up/row superset · plank. B deadlift ·
  overhead press · ring-row/goblet superset. C bench · bent-over row ·
  pull-up-negative/split-squat superset. Short warm-ups, short cool-downs, no
  arm and delt finishers.
- Build (5–7), Deload (8), Push (9–11) on the same three days, loads handed
  on from week 4 as before; Test (12) keeps the 5-rep tests on the three
  days and makes the Sunday 5K optional.
- No second run, no skipping sessions; nutrition phases flat at 2,300;
  the flat rule bumps by 150, not 250; target weight 53 kg.
- `revision` 3, so the installed programme upgrades; logs are untouched
  (they carry their own exercise ids).

## Phase H — food: four meals at about 2,300 kcal

`tools/gen_fuel.py`, regenerated, V21 green.

- Slots: **Breakfast 06:45 · Lunch 13:30 · Snack 17:15 · Dinner 20:00**, the
  same on every day (the snack is the pre-session fuel on training evenings).
- The same cheap rotation (one main protein a day), prep nights, budget,
  shopping list — re-solved for the four slots. Protein floor 90 g.
- One phase, no step-ups; the stalled-scale booster becomes +150.

## Phase I — hikes, and the 3D mountain

- **Recording**: the tracker records a hike as well as a run (`runs.kind`,
  schema v4, migration with the automatic copy first). A hike shows climb
  and altitude instead of pace.
- **Progress → Hikes**: a list like runs; a hike's page with the map, an
  elevation profile, distance, time, ascent, descent and the highest point.
- **3D**: real terrain from **AWS Terrain Tiles** (open elevation data,
  terrarium PNGs, no key), only for the hike's own area, cached on the
  phone. Drawn by the app's own painter: a lit, shaded mesh with the trail
  draped on it, glowing; drag to orbit, pinch to zoom, a slow fly-around
  until touched, and the trail drawing itself in. Offline, it falls back to
  the track's own GPS heights.
- **Network rule** (CLAUDE.md, privacy audit): open map and elevation data
  may be fetched — approved by Saad 2026-10-04. Still no analytics, no
  accounts, no uploads.

## Release

0.15.0+17, same key, permissions unchanged, migration rehearsed, every
gate, screens looked at.
