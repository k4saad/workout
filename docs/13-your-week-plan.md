# v4.2 — your week, on the phone

Saad, 2026-11-09: the timetable changed again, and he does not want to edit
source code every time it does.

- Dropped **Geoinformation in Society** (Mon and Tue).
- **Spatial Justice** on Wednesday only; not on Friday.
- No **study project**.
- **German**, at least an hour, every day.
- **The library** in the evening: proper study time for his subjects.
- The plan starts again on **Monday 9 November**.

## Decided

- **The week is his to change in the app.** Week → Planner → "Your week"
  (also More → Settings → Your week): every block (lecture, work, study,
  prayer) added, changed or deleted, with undo; the semester's name, lecture
  period, breaks, travel time and places. Saved as `programmes/timetable.json`
  in app-private storage, included in every backup. `data/timetable.json` is
  only what a fresh install starts from, and "Back to the shipped week" goes
  back to it.
- **A block can be on several days** (`days`, schema 2; v1's `weekday` still
  reads), **somewhere or anywhere** (`place` optional: no travel), and **off
  in the breaks** (`offInBreaks`).
- **German: every day, 20:00–21:00, anywhere.** After dinner, before an early
  night (Tuesday's shift starts at 07:00).
- **The library: Tuesday and Friday, 15:00–18:00, off in the breaks.**
  Straight after the last class on the two weekday evenings with no session,
  so it is one trip and he is home by 18:30. Monday and Wednesday evenings are
  training; Thursday is already 09:00–17:45.
- **Training stays Mon 18:00 · Wed 16:45 · Sat 10:00.** Sets, reps and loads
  unchanged; programme revision 5 only moves the start to 9 November
  (`startsFresh`) and takes the timetable out of the rest-day notes.

## The planner

- Study is a commitment: on the day, skippable for a date ("Not today"),
  reminded (German 15 minutes before; the library when it is time to leave),
  switchable in Settings.
- German does not push the session later: the session goes in the first free
  time at home after classes, work and his own entries.
- A gap long enough for two rides and an hour at home is spent at home.
- The meals are chosen together, not one at a time: a late Thursday lunch used
  to push the snack, and the snack pushed dinner past German. A meal can be
  eaten on a break in the library ("take it with you").

## As built

- `lib/domain/planner/timetable.dart` (model, edits, JSON), `timetable_validator.dart`
  (V22 on the phone: errors only for what the planner cannot use, warnings for
  clashes), `day_planner.dart` (study, home in between, meals jointly).
- `lib/features/planner/timetable_screen.dart`, `lib/app/timetable_providers.dart`.
- `tools/validate.py` V22 reads `days`, `study`, optional places.
- 0.17.0+19.
