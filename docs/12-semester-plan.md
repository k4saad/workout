# v4.1 — the semester: a planner, and reminders

Saad, 2026-10-12, with the final timetable (WS 26/27, v7):

| | |
|---|---|
| Mon | Geoinformation in Society 10:15–11:45 · Job 2 12:15–17:00 |
| Tue | Job 2 07:00–11:45 · Geoinformatics Forum 12:15–13:45 · Geoinformation in Society 16:15–17:45 |
| Wed | Job 1 09:00–13:45 · Spatial Justice 14:15–15:45 |
| Thu | Job 1 09:00–13:45 · SII lecture 14:15–15:45 · SII exercise 16:15–17:45 (optional, going) |
| Fri | (Job 2 07:00–09:30, every 5th week) · Spatio-Temporal Data 10:15–13:45 · Jumu'ah 14:00–14:25 · Spatial Justice 14:30–15:15 · Study Project 15:15–16:45 |

Lectures 12 Oct 2026 – 5 Feb 2027, winter break 23 Dec – 3 Jan, 30 minutes
to get between campus and work. Wayfinding moved to next year; no German, no
Maths.

He asked for: the app fitted to this week, a planner to look at it and plan
with, and a notification when something is about to start.

Decided with him:

- **Training moves to Mon · Wed · Sat.** Tuesday and Thursday are now the long
  days (07:00–17:45, 09:00–17:45); Monday ends at 17:00 and Wednesday at
  15:45. Sunday stays an optional run or hike.
- **Friday's Job 2** is off unless he marks the Friday in the planner.
- **SII** (Thursday): he goes to both, so they count as part of the day.
- **Reminders** for classes, work and training sessions. Not meals.

v4 got the meals wrong against this week — breakfast at 06:45 on 07:00 work
mornings, lunch at 13:30 in the middle of a lecture or a shift — because it
gave every day the same four times. Fixing that is part of this release.

## Phase J — the timetable as data

- `data/timetable.json`, authored, mirrored into the app like `fuel.json`:
  the lecture period, the break, the travel time, and every weekly block
  (lecture, job, prayer) with its room. Optional classes say so; Friday's
  job only happens on a Friday he marks.
- A gate (V22): times valid, nothing overlapping, 30 minutes between campus
  and work.

## Phase K — training on Monday, Wednesday and Saturday

`tools/gen.py`, revision 4, the same three sessions on new days:
A Monday, B Wednesday, C Saturday, Sunday optional; Tuesday, Thursday and
Friday rest, with notes that fit them. Sets, reps and loads unchanged.

## Phase L — the day, planned

A pure-Dart day planner (`lib/domain/planner/`), tested first:

- **What is on**: the week's blocks for the date — no lectures in the break or
  after 5 February — plus his own entries, minus what he skips.
- **When to train**: after the last commitment, travel home and a snack (Mon
  ≈ 18:00, Wed ≈ 16:45), 10:00 on a free day; he can move it.
- **When to eat**: each meal at the free time nearest its target, never
  inside a lecture; inside a shift only when nothing else fits, and then
  it says "packed, at work". The last meal before the session is its fuel.
- Fuel, Today and the reminders all read the same plan.

## Phase M — the planner

- **Week → Planner**: the week at a glance (a strip of seven days, each with
  its load drawn in), then the chosen day as a timeline: classes, work,
  travel, the session in crimson, the meals. Every kind has its own glyph.
- Tap a block: room, lecturer, time; skip an optional class or a shift that
  is off; mark Friday's job; move the session.
- **Add to a day**: an exam, a meeting, an appointment, study — chips, a
  title, time and length on steppers, remind or not.
- **Today** gets "Your day": what is on now and next, linking to the planner.
- Stored in the app's database (`planner_entries`, schema 5, created after the
  automatic copy).

## Phase N — "bruh, this is starting"

- Notifications, the next seven days, re-laid on every launch and change:
  a class 15 minutes before (with the room), work when it is time to leave
  (30 minutes' travel), a session 30 minutes before, his own entries when
  he asked. Nothing for a skipped class, a logged session or a rest day.
- Settings: a switch each for classes, work, sessions. On by default — he
  asked for them. The old fixed-time evening reminder goes.
- No new permission: exact alarms and notifications are already granted.

## Release

0.16.0+18, same key, permissions unchanged, schema 5 rehearsed, every gate,
screens looked at.
