# The Keller Twelve — v2

A 12-week hypertrophy programme and the single-user Android app that runs it.

**Athlete:** male, under 25 · 167 cm · 50 kg · complete beginner · trains alone
**Gym:** basement — spinlock barbell, EZ bar, 2 dumbbell handles, plate set with
microplates, bench, squat stands with catch pins, wall pull-up bar, rings, bands, wall
cable, heavy bag, jump rope, ab wheel, kettlebell, step platform, mats
**Constraint that shapes everything:** 5 evenings a week, **60 minutes hard ceiling**

---

## Read these in order

| # | Document | What it is |
|---|---|---|
| 0 | [docs/00-audit.md](docs/00-audit.md) | What was wrong with v1 and why each change was made. Read once, then never again. |
| 1 | [docs/01-programme.md](docs/01-programme.md) | The training programme. Blocks, session tables, load projections, cardio, nutrition. **The coaching document.** |
| 2 | [docs/02-data-model.md](docs/02-data-model.md) | Schema v2, the five algorithms, and the specs that must be test-first. |
| 3 | [docs/03-build-plan.md](docs/03-build-plan.md) | 11 phases, sub-phases, tasks, acceptance criteria, paste-ready prompts. |
| 4 | [docs/04-calibration.md](docs/04-calibration.md) | The week-1 measurements the whole app depends on. **Do this before Phase 1.** |
| — | [CLAUDE.md](CLAUDE.md) | Standing rules for Claude Code. Loaded automatically. |

## The data

`data/` holds the validated programme. Phase 1 copies these into the Flutter project's
`assets/` — it does not author them.

| File | What it is |
|---|---|
| [data/keller-twelve.json](data/keller-twelve.json) | The programme. 5 blocks, 16 day definitions, 76 prescriptions, cardio table, checkpoints, nutrition phases. |
| [data/exercises.json](data/exercises.json) | 76 exercises with cues, common errors and a solo-safety note each. |
| [data/schema.json](data/schema.json) | JSON Schema (draft-07) for the programme. |
| [data/inventory.json](data/inventory.json) | **Placeholder bar and plate weights.** Replace from doc 04. |
| `data/v1-reference/` | The superseded v1 files. Kept only as a source for exercise definitions. |

### Regenerating

Loads and session lengths are **computed, never typed** — that is what stops v1's
19-unloadable-weights bug from recurring.

```bash
python tools/gen.py && python tools/validate.py
```

`tools/gen.py` snaps every `startLoadKg` onto the plate lattice and computes every
`estMinutes` from the prescriptions, ramp sets and implement changes.
`tools/validate.py` runs gates V1–V13 and prints a report: session lengths, weekly sets
per muscle, push/pull balance, pattern frequency and macro arithmetic. Exit code 0 means
the data is sound.

**After you fill in doc 04, edit `INVENTORY` at the top of `tools/gen.py` and re-run
both.** Every load in the programme moves onto your real lattice.

Current state — all gates passing:

```
exercises      76 in library, 76 referenced
loads checked  30 startLoadKg values against the lattice
lattice step   barbell 0.50 kg  |  dumbbell 0.50 kg per DB
sessions       Foundation 30–39 min · Build 45–54 min · ceiling 60
frequency      squat 2x  hinge 2x  h-push 2x  v-push 2x  h-pull 2x  v-pull 2x
balance        both upper days 10 push / 10 pull
```

## The three rules that survive everything else

1. **The programme is data.** Sets, reps, loads, day structure and cues live in JSON.
   Hardcoding `4 × 6–8 bench press` in a widget is a bug even if it renders correctly.
2. **Nothing leaves the device.** No accounts, no sync, no analytics. One outbound call:
   `url_launcher` opening a YouTube demo, and even that is optional.
3. **A phase is done when the APK is on the phone**, not when the code compiles.

## Status

- [x] Programme v2 authored and validated (gates V1–V13)
- [x] Phase 0 — toolchain + release keystore
- [x] Phase 1 — programme data + read-only viewer — tag `v0.1-phase1`
- [x] Phase 2 — session runner + database + backup — tag `v0.2-phase2`
- [x] Phase 3 — plate solver + progression engine — tag `v0.3-phase3`
- [x] Phase 4 — calendar + retroactive logging — tag `v0.4-phase4`
- [x] Phase 5 — progress photos + measurements — tag `v0.5-phase5`
- [ ] Phase 6 — cardio, bodyweight, food
- [ ] Phase 7 — exercise demos + form clips
- [ ] Phase 8 — programme editor + next-cycle seeding
- [ ] Phase 9 — stats + dashboard
- [ ] Phase 10 — hardening + release

### Two things only you can do

**1. Accept the Android SDK licences.** Flutter 3.47.5, JDK 17 and the Android
command-line tools are installed, but installing SDK packages means accepting
Google's licence agreements, which is yours to accept, not the assistant's.
One script does the rest:

```bash
powershell -ExecutionPolicy Bypass -File tools\finish-android-setup.ps1
```

Until that runs there is no APK, so no phase can meet its "installed on the
phone" definition of done. Everything else — the tests, `flutter analyze`,
the data gates — passes without it.

**2. Week-1 calibration** ([docs/04-calibration.md](docs/04-calibration.md)).
The app runs on placeholder bar weights and says so on every screen until you
weigh them. Edit `INVENTORY` at the top of `tools/gen.py`, re-run the two
commands below, and every load moves onto your real lattice.

### Where the keystore is

`C:\Users\Saad\keys\keller-twelve.jks`, password in
`app/android/key.properties` (gitignored). **Back both up to two places that
are not this PC.** Lose that file and you cannot update the app without
uninstalling — and uninstalling deletes the training database and every
progress photo.

## Running it

```bash
cd app && flutter test
```

```bash
cd app && flutter analyze
```

```bash
python tools/gen.py && python tools/validate.py
```
