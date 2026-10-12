# On-device checklist — v0.16.0+18

What the tests cannot prove, because it needs the phone, the camera, the GPS
or a night passing. Everything else is covered by `flutter test` (1,700-odd
tests), the QA robots and the data gates V1–V22.

v0.16 is v4.1, the semester (docs/12-semester-plan.md), on top of v4
(docs/11-v4-plan.md):

- the final WS 26/27 timetable built in;
- training moved to **Mon · Wed · Sat**;
- every meal timed around the day;
- a **planner** under Week;
- notifications before classes, work and sessions.

v4 itself brought four meals at about 2,300 kcal and hikes in 3D.

**This update migrates the database**, from schema 3 or 4 to 5: runs learn
whether they were a hike, and the planner gets its table. The app copies the
database before it migrates. A backup you hold yourself is still the first
step.

Tick these in order. The first two protect everything else.

## Before installing

- [ ] **Export a backup first**, and copy the zip off the phone (More →
      Settings → Backup and files → Export full backup). This update
      migrates the database; a backup you hold yourself is the one that
      cannot be lost with the phone.
- [ ] Install **`apk/keller-twelve-0.16.0+18-arm64.apk`** over the old app —
      do **not** uninstall first. (`-arm32` is only for a phone older than
      about 2017.) It is signed with the same key as v0.11 and v0.12
      (`389b93bc…b7b5`), so Android installs it as an update and keeps the data.

## The update itself

- [ ] Every logged session is still there: History, Week and Calendar show
      the same sessions as before, with the same sets.
- [ ] The progress photos are still there and open.
- [ ] Bodyweight history and measurements are unchanged.
- [ ] Android asks for no new permission: v0.16 has exactly the
      permissions v0.14 and v0.15 had (the elevation tiles use the internet
      permission the map already has; reminders use the notification and
      exact-alarm permissions the rest timer already has).
- [ ] Every run is still in Progress → Runs, with its trail.
- [ ] Today shows **"Programme updated to revision 4 — a new plan, starting
      Monday 12 October"** once; dismissed, it stays gone. The sessions you
      logged on the old plan are in History as **"Earlier plan"**, sets
      intact.

## The new week (v4.1 Phase K)

- [ ] Week shows **Mon Full Body A** · Tue rest · **Wed Full Body B** · Thu
      rest · Fri rest · **Sat Full Body C** · Sun *Run or hike* (optional).
      Each session says under half an hour.
- [ ] A rest day on Today names the next session ("Next: Full Body B,
      tomorrow").
- [ ] Time one real session start to finish: under 30 minutes, warm-up
      included. If it runs over, tell me which part; the cure is less
      volume, never a longer estimate.
- [ ] Past the estimate plus ten minutes, the runner offers to cut the last
      superset.

## Four meals, around the day (v4 Phase H, v4.1 Phase L)

- [ ] Fuel's times follow the day, about 2,300 kcal and 90 g protein or more:
  - Monday: breakfast 07:30, lunch 13:00 **packed, at work**, snack 17:30
    (fuel for the session), dinner 19:30;
  - Tuesday: breakfast **06:10** before Job 2, lunch 13:45.
- [ ] On Saturday, breakfast is the fuel for the 10:00 session.
- [ ] The portions are food you would actually eat at those times; tell me
      any that are not, and the generator changes.

## The planner (v4.1 Phase M)

- [ ] **Week → the planner button** (or Today's **Your day** card) opens
      the planner: seven days at a glance, each with its day drawn in, then
      the chosen day as a timeline, with the free time in it.
  - Monday has Geoinformation (Room 242), the ride to Job 2, the shift, the
    ride home, the session at **18:00**.
  - Tuesday has its free afternoon.
- [ ] Tap a class: room and lecturer; **Skip this one** takes it off that
      day only, and **Bring back** returns it.
- [ ] On a Friday, **Job 2 this Friday** switches the 07:00 shift on, and
      breakfast moves earlier.
- [ ] Tap the session: **Start session** today; − / + and **Move to …**
      move it, and its reminder moves with it.
- [ ] **Add to this day**: an exam or a meeting, with chips and steppers,
      reminded 15 minutes before.
- [ ] The winter break (23 Dec – 3 Jan) shows work but no lectures.

## Reminders (v4.1 Phase N)

- [ ] Android asks to allow notifications if it never has. Allow them.
- [ ] A class rings **15 minutes before**, with its room: "Spatial Justice ·
      14:15", "Room 147 · Feitosa · in 15 minutes".
- [ ] Work rings **when to leave**. Monday's Job 2 rings as Geoinformation
      ends, not in the middle of it.
- [ ] A session rings **half an hour before**, and not at all once you have
      trained, or on the optional Sunday.
- [ ] Skip a class in the planner: its reminder goes. Settings → Reminders
      switches each kind off.
- [ ] With the phone locked and the app closed, they still ring (exact
      alarms). They are laid two weeks ahead each time you open the app.

## Hikes, in 3D (v4 Phase I)

- [ ] Progress → **Hikes** → **Start a hike**: the tracker says HIKE and
      shows **▲ Climb** and **Height** instead of pace. Walk up something.
- [ ] A slow, steep climb keeps counting time (no "Auto-paused" while you
      are still moving).
- [ ] **Hike saved**: the 3D card says **Fetching the terrain**, then shows
      the land with the trail on it, drawing itself in, turning slowly.
      A sideways drag turns it; the page still scrolls up and down.
- [ ] **Full screen 3D**: one finger turns and tilts, two zoom, a double
      tap starts it again. Contour lines sit on the hills; the trail behind
      a hill goes faint.
- [ ] Ascent, descent and the highest point look right for the walk
      ("from the terrain under the trail").
- [ ] **Offline** (flight mode), open a hike you have not opened before: it
      says **GPS heights · offline** and stands the trail on the phone's
      own heights. Open one you have: its terrain is kept on the phone.
- [ ] From Sunday's session, **Hike it with GPS** records a hike and logs
      its time as Sunday's set.
- [ ] Share a hike: the card says "Morning hike" and shows the climb.

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

## A run to look at, a run to send (v0.14, docs/10-v3.2-plan.md)

- [ ] On a run's page, tap the route (or ⤢): it opens **full screen**
      over the tab bar, draws itself in, pans and pinches; **Draw it
      again**, pace colours and replay work; ✕ and back both close it.
- [ ] **Share** (the share icon in the run's bar, or in full screen):
      the card preview shows the route with a gap at the start and finish.
      Share it to yourself (e.g. WhatsApp "Message yourself"): the picture
      is sharp, 1080 × 1350, with no map on it.
- [ ] Turn **Hide the start and finish** off: the line closes. Turn **Show
      the route** off: the card becomes the numbers.

## After the QA pass (docs/09-qa-pass.md)

- [ ] Body, with the scale flat for three weeks: **Add 150 kcal a day** adds
      it; Fuel's target rises and shows it as food; **Take it off** on Body
      removes it.
- [ ] Cardio: start a skipping timer, press **Stop**, lock the phone and
      wait a minute: no round alarms go off.
- [ ] Leave a session open, come back after midnight, tap **Session in
      progress**: the same session opens (History shows one, not two).
- [ ] On Fuel, tap **Eaten**: the button fills and shows a tick at once.
- [ ] Restore a backup: the app reloads onto Today, showing the backup's
      data, and a setting toggled afterwards stays as restored.

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
git tag v0.16-v4.1
```
