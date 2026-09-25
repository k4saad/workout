# On-device checklist — v0.13.0+13

What the tests cannot prove, because it needs the phone, the camera, the GPS
or a night passing. Everything else is covered by `flutter test` (1,538
tests) and the data gates V1–V21.

v0.13 is the fix-up after the first week on the phone (docs/08-v3.1-plan.md):
GPS that locks, runs that look like a running app, Fuel planned by the week
on a student's money, and swiping between tabs. The database schema is
unchanged, so this update runs no migration.

Tick these in order. The first two protect everything else.

## Before installing

- [ ] **Export a backup on v0.12**, and copy the zip off the phone (More →
      Settings → Backup and files → Export full backup). Nothing in this
      update touches the database, but a backup you hold yourself is the one
      that cannot be lost with the phone.
- [ ] Install **`apk/keller-twelve-0.13.0+13-arm64.apk`** over the old app —
      do **not** uninstall first. (`-arm32` is only for a phone older than
      about 2017.) It is signed with the same key as v0.11 and v0.12
      (`389b93bc…b7b5`), so Android installs it as an update and keeps the data.

## The update itself

- [ ] Every logged session is still there: History, Week and Calendar show
      the same sessions as before, with the same sets.
- [ ] The progress photos are still there and open.
- [ ] Bodyweight history and measurements are unchanged.
- [ ] Android asks for no new permission: v0.13 has exactly the
      permissions v0.12 had.

## GPS runs (v3.1 Phase A)

- [ ] **Precise location off** (the phone's "Use precise location" switch for
      this app): the run screen says so and offers the settings, instead of
      "finding GPS" forever. Turn it back on; the screen notices on return.
- [ ] Outside, the chip goes from **Waiting for GPS** to **GPS fair** or
      **GPS good ±N m** within a minute or so, and the map shows where you
      are straight away (your last known position) while it warms up.
- [ ] **Start works at once**, even before the chip says good. The trail
      begins at the first usable fix.
- [ ] **No notification before Start.** Opening the run screen and looking
      for GPS shows nothing in the status bar; **"Recording your run"**
      appears on Start and goes on Finish or Discard.
- [ ] Leave the run screen without starting: Today shows **no "Run still
      open"** card.
- [ ] **Screen off:** start a run, lock the phone, walk 10 minutes, unlock.
      The trail is continuous, with no straight-line gap.
- [ ] Force-close the app mid-run; reopening offers **"Run still open"**.
- [ ] A finished programme run appears as the set on that day's session.

## Runs look (v3.1 Phase B)

- [ ] The map is **quiet**: grey roads on near-black, no colourful satellite
      look, and the crimson trail is the brightest thing on it. The
      attribution at the bottom opens the OSM copyright page.
- [ ] While running: a pulsing dot with an accuracy halo, big time, distance
      and pace, the round Start button.
- [ ] A finished run opens with the **route drawing itself in**; the speed
      button colours it by pace (with a slower → quicker key); **Replay** runs
      a dot along it with the km and time ticking.
- [ ] Runs list: activity cards ("Evening run"), three numbers and a large
      trail.

## Fuel (v3.1 Phase C)

- [ ] **Today** shows the weekday's meals: Monday lunch and dinner are both
      chicken thighs; no day defaults to salmon.
- [ ] **Plan** opens on next week from Friday, this week before. The week's
      cost is there (about €40), each day card shows its cost, and a day opens
      to every meal with a swap button. A swap on a day next week is still
      there when you come back to it.
- [ ] **Cook ahead** shows Sunday evening for Mon–Tue and Wednesday for
      Thu–Fri, with grams, and says tonight on the night.
- [ ] **Shopping list**: whole packets by aisle, this week's shop priced, and
      the cupboard food (rice, oats, oil, whey) below it with how long a
      packet lasts. Ticks stay ticked after closing the app, and next week's
      list starts clean.
- [ ] Compare the week's total with a real receipt once. The prices are
      estimates; tell me if they are far out and the generator gets fixed.

## Swipe between tabs (v3.1 Phase D)

- [ ] On each of the five tab screens, a sideways swipe moves to the next
      tab and back, the bottom bar follows, and each tab is where you left it.
- [ ] Drilled into a tab (a lift, a run, the photo compare), a sideways swipe
      does **not** change tab, and the compare slider still wipes.
- [ ] Week: the arrows and a swipe along the "Week N of 12" header change the
      week; a swipe on the days changes tab.
- [ ] Back still walks up a tab's own pages, then to Today, then asks
      before closing.

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

- [ ] Months swipe smoothly in the calendar.
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
git tag v0.13-v3.1
```
