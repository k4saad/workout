# The Keller Twelve — v2

A 12-week hypertrophy programme and the single-user Android app that runs it.

**Athlete:** male, under 25 · 167 cm · 50 kg · complete beginner · trains alone
**Gym:** basement — spinlock barbell, EZ bar, 2 dumbbell handles, plate set with
microplates, bench, squat stands with catch pins, wall pull-up bar, rings, bands, wall
cable, heavy bag, jump rope, ab wheel, kettlebell, step platform, mats
**Constraint that shapes everything:** 5 evenings a week, **60 minutes hard ceiling**

---

## Getting around

Five tabs along the bottom, where your thumb is:

| Tab | What is in it |
|---|---|
| **Today** | What you are doing now, the resume banner, week progress, bodyweight trend. History sits behind the top-right icon. |
| **Week** | The seven day cards, and the month calendar behind the top-right icon. |
| **Numbers** | Sets per muscle, session length, plate gaps, niggles, every lift. |
| **Body** | Weigh-ins, the trend, measurements. Progress photos behind the top-right icon. |
| **More** | Exercise library, cardio timer, and Settings (bars and plates, the programme editor, backups, next cycle). |

Back walks up the tab you are in, then to Today, then asks before closing.
Tapping the tab you are already on jumps back to the top of it.

## Toolchain recorded

| | |
|---|---|
| Flutter | 3.47.5 · stable · Dart 3.13.4 |
| JDK running Gradle | Temurin 17.0.20.1, via `flutter config --jdk-dir` (system default java is 25) |
| minSdk / target | 24 / Flutter default |
| App version | 0.11.0+11 |

Known deviations from the build plan are listed at the end of
[docs/03-build-plan.md](docs/03-build-plan.md).

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
- [x] Phase 6 — cardio, bodyweight, food — tag `v0.6-phase6`
- [x] Phase 7 — exercise demos + form clips — tag `v0.7-phase7`
- [x] Phase 8 — programme editor + next-cycle seeding — tag `v0.8-phase8`
- [x] Phase 9 — stats + dashboard — tag `v0.9-phase9`
- [x] Phase 10 — hardening + release — tag `v0.10-phase10`
- [ ] `v1.0` — after the on-device checks in the release checklist below

**The signed release APK builds and is signed with your key.** What remains is
installing it and running the on-device checks.

### Toolchain setup — done

The Android SDK licences are accepted and the packages are installed
(`platform-tools`, `platforms;android-36`, `build-tools;36.0.0`). Flutter is
pointed at `C:\Users\Saad\Android\Sdk` and at Temurin JDK 17 via
`flutter config --jdk-dir`. `flutter doctor` reports the Android toolchain
green.

`tools/finish-android-setup.ps1` is kept only as a record of what was run; you
do not need it again unless the SDK is reinstalled.

### Still owed: week-1 calibration

([docs/04-calibration.md](docs/04-calibration.md)).
The app runs on placeholder bar weights and says so on every screen until you
weigh them. Edit `INVENTORY` at the top of `tools/gen.py`, re-run the two
commands below, and every load moves onto your real lattice.

### Where the keystore is

`C:\Users\Saad\keys\keller-twelve.jks`, password in
`app/android/key.properties` (gitignored). **Back both up to two places that
are not this PC.** Lose that file and you cannot update the app without
uninstalling — and uninstalling deletes the training database and every
progress photo.


---

## Building and installing

Everything below works as-is; the toolchain is set up
(see *Toolchain setup*, above).

### Check it first

```bash
cd app && flutter analyze && flutter test
```

```bash
python tools/gen.py && python tools/validate.py
```

`flutter analyze` must be clean and all gates must pass before a build.
Warnings are errors here.

### Build the APK

```bash
cd app && flutter build apk --release --split-per-abi
```

`--split-per-abi` builds one APK per architecture. The one for your phone is
`app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` — **27.6 MB**
(11.8 MB Flutter engine, 10.0 MB your compiled Dart, 1.5 MB sqlite3, 2.9 MB
dex after R8, 1.7 MB assets). A single fat APK would be ~85 MB.

### Confirm it is signed with YOUR key

```bash
apksigner verify --print-certs app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

It must print your certificate. It currently prints:

```
CN=Saad, OU=Keller Twelve, O=Personal, L=Muenster, C=DE
```

If it ever prints `CN=Android Debug`, **stop** —
installing that build and later switching keys forces an uninstall, and an
uninstall deletes the training database and every progress photo.

### Install

```bash
adb install -r app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`-r` reinstalls over the top and keeps your data. Without a matching signing
key, `-r` fails — which is the safety net working, not a bug to route around.

---

## Updating an installed app

Do these in order, every time. Skipping the version bump means Android may
refuse the install or keep the old code.

1. Bump **both** numbers in `app/pubspec.yaml`:
   `version: 0.9.0+9` → `version: 0.10.0+10`
   (the part before `+` is what you read, the part after is what Android
   compares).
2. `cd app && flutter analyze && flutter test`
3. `flutter build apk --release --split-per-abi`
4. `adb install -r <the apk>`
5. Open it once with the cable unplugged before you train off it.

**Take a backup before installing over a version that changed the database.**
The app copies the database automatically before any migration, but a copy you
made yourself is the one you can find.

---

## Release checklist — the parts that need the phone

These cannot be verified from a desktop, and each one has a real failure mode
behind it.

- [ ] **A full session on the RELEASE build**, not a debug build. Log every
      set, let a rest timer run with the screen off, finish. A debug build is
      not minified and proves nothing about R8.
- [ ] **A full photo shoot on the release build.** The `camera` plugin resolves
      implementations by name; if R8 stripped one, this is where it shows.
- [ ] **Open the phone's gallery app and Google Photos. The progress photos
      must not be there.** If they are, stop and read
      `docs/03-build-plan.md` §5.5 before shooting anything else.
- [ ] Exempt the app from battery optimisation: *Settings → Apps → Keller
      Twelve → Battery → Unrestricted*. On Xiaomi, Realme and Samsung the
      OEM task killer will otherwise stop the rest timer mid-session. There is
      no way to do this from inside the app on modern Android.
- [ ] Export a full backup and open the zip on the PC. A backup you have never
      opened is a backup you do not have.
- [ ] Only once all of the above pass: `git tag v1.0`.

---

## Your data, and where it lives

**Everything is on the phone.** There is no account, no server and no sync.
The app has no `INTERNET` permission at all — `test/privacy_audit_test.dart`
fails the build if one appears.

| What | Where | Leaves the device when |
|---|---|---|
| Sessions, sets, weigh-ins, measurements | app-private SQLite | you export a backup |
| Progress photos and form clips | app-private files, excluded from Android's cloud backup | you export a backup and choose where it goes |
| The programme | `programme.json` in app-private storage | you export it |

### Backup and restore

In the app: **Settings → Backup and files**.

- **Export full backup** writes one zip — database rows, programme, photos,
  clips — and hands it to the Android share sheet so you choose the
  destination. It contains your progress photos; whatever you send it to can
  read them, so pick deliberately.
- **Restore from backup** replaces everything currently on the phone. It shows
  you what is inside and asks first. There is no undo.
- **Export programme** is the small one: the JSON only, no photos. That is the
  one to keep in git.

**Do this every fortnight.** The app reminds you if it has been longer.

### If you lose the phone

Your training history is whatever your last backup holds. Progress photos exist
in exactly two places: that phone, and backups you made deliberately. That is
the trade for them never touching a cloud.

---

## Running the checks

```bash
cd app && flutter test
```

```bash
cd app && flutter analyze
```

```bash
python tools/gen.py && python tools/validate.py
```
