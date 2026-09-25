# On-device checklist — v0.12.0+12

What the tests cannot prove, because it needs the phone, the camera, the GPS
or a night passing. Everything else is covered by `flutter test` (1,491
tests) and the data gates V1–V20.

Tick these in order. The first two protect everything else.

## Before installing

- [ ] **Export a backup on v0.11**, and copy the zip off the phone (More →
      Settings → Backup and files → Export full backup). The update migrates the database; a copy is taken
      automatically first (`keller_twelve.premigration.v2.sqlite`), but a
      backup you hold yourself is the one that cannot be lost with the phone.
- [ ] Install **`apk/keller-twelve-0.12.0+12-arm64.apk`** over the old app —
      do **not** uninstall first. (`-arm32` is only for a phone older than
      about 2017.) It is signed with the same key as v0.11
      (`389b93bc…b7b5`), so Android installs it as an update and keeps the data.

## The update itself

- [ ] Every logged session is still there: History, Week and Calendar show
      the same sessions as before, with the same sets.
- [ ] The progress photos are still there and open.
- [ ] Bodyweight history and measurements are unchanged.
- [ ] If a session was left open in v0.11, Today offers to resume it.
- [ ] Android asks for no new permission until you first start a GPS run.

## GPS runs (Phase 4)

- [ ] Starting a run asks for location **"While using the app"** — there is
      no "Allow all the time" option, and none is needed.
- [ ] A **"Run in progress"** notification shows while recording.
- [ ] **Screen off:** start a run, lock the phone, walk 10 minutes, unlock.
      The trail is continuous, with no straight-line gap.
- [ ] The map draws **real OpenStreetMap tiles**, dark, and the attribution
      at the bottom opens the OSM copyright page.
- [ ] Force-close the app mid-run; reopening offers **"Run still open"**.
- [ ] A finished programme run appears as the set on that day's session.

## Photos (Phase 6)

- [ ] The camera opens on the **front** lens.
- [ ] **The ghost lines up the right way round.** Shoot one pose, then shoot it
      again with the ghost on and raise your right hand: the ghost's raised
      hand must be on the same side as the live one. (The app assumes the
      saved front-camera photo is mirrored like the preview, which is
      CameraX's default. If it is the other way round, tell me.)
- [ ] The timer's **pips are audible** from where you stand to pose, and the
      phone buzzes at each second.
- [ ] Saved photos are **upright** in the timeline and the viewer.
- [ ] **Not in the gallery:** after a shoot, open the phone's Gallery and
      Google Photos. No progress photo may appear in either.
- [ ] Deleting a photo, then a shoot, lowers the storage figure on Photos.
- [ ] Backing out of the camera before keeping anything leaves no empty shoot.

## Calendar, Week, Body (Phases 5–6)

- [ ] Months and weeks swipe smoothly.
- [ ] A weigh-in and a measurement on the steppers: no keyboard appears.
- [ ] The week-4 checkpoint ticks Photos and Measurements by itself after the
      shoot and the tape.

## The day (Phase 7)

- [ ] **First open of the day:** the quote screen greets you by name, in a
      serif face, and moves on with a tap or by itself.
- [ ] **Second open the same day** goes straight in.
- [ ] With a session in progress, the quote is skipped.
- [ ] Settings → "A quote to open the day" off stops it.
- [ ] **Overnight:** leave the app open in the background at night; in the
      morning, without closing it, Today shows the new date, the new session
      and the new quote. (The launch screen itself is for a fresh start; on a
      warm return the new quote is on Today.)
- [ ] Finishing a session shows the ring and the numbers, and Done returns
      to where the session was started.
- [ ] Tapping an exercise in the library, the figure grows into its page;
      tapping a photo thumbnail, the photo grows into the viewer.

## Cannot be tested with one phone

- A **phone-to-phone transfer** to a new phone should carry the training log
  but no photo, thumbnail or clip (`data_extraction_rules.xml`). Check when
  you next change phone, before wiping the old one.

When this list is ticked, tag the build so it can always be returned to:

```bash
git tag v0.12-v3
```
