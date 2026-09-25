# QA pass — v0.13.0+13, as a tester and as Saad

Goal: use the app the way Saad does (in the basement, between sets, over
twelve weeks) and the way a tester does (edges, interruptions, bad input),
find what is broken, fix what is clearly a bug, and write down the rest.

## How the app is driven

There is no emulator or phone on this machine, and Chrome cannot run the
app's native SQLite. So the "user" is a **robot driving the real app**: the
real router, shell, tabs and screens, the real seeded programme and generated
data, an in-memory Drift database, and a pinned "today". It taps what a
thumb taps (buttons, steppers, chips, sheets, back) and never calls
internals a user cannot reach. Every step:

- fails on any framework error: overflow, assertion, exception, a
  `setState` after dispose, a leaked timer;
- renders key states to `app/build/screens/qa_*.png` with real fonts, which
  are **looked at**, not just written.

Plugins with hardware behind them (GPS, camera, notifications) are replaced
by the same fakes the tests already use, at the plugin boundary only.

Alongside the robot: a **code review** of the risky paths, with targeted
greps for known bug shapes, and a **data review** of the generated JSON.

## 1. Static sweep (fast, high yield)

| # | Look for | Why it bites |
|---|---|---|
| S1 | `.add(Duration(days: …))` / `subtract` on local dates | 25 Oct 2026 and 28 Mar 2027 are 23/25-hour days: a date "plus one day" lands on 23:00 the same day |
| S2 | `DateTime.now()` outside the clock providers | the app would not agree with itself about "today" after midnight |
| S3 | date equality on values that may carry a time | a session logged at 19:40 not matching "today" |
| S4 | `firstWhere` without `orElse`, `.single`, `.first` on possibly-empty lists, `!` on async data | a crash on an edited programme or an empty history |
| S5 | `context` / `setState` after `await` without `mounted` | crash when the user backs out mid-await |
| S6 | controllers, timers, streams, listeners not disposed | leaks, ticks after dispose |
| S7 | division by a count or a target that can be 0 | NaN on a ring, `Infinity` in a pace |
| S8 | the privacy and permission rules in CLAUDE.md | photos never near network code, location only in the runs paths |
| S9 | stale copy: text that describes the old behaviour | e.g. "swipe for the next week" |

## 2. Journeys (the robot)

Timeline anchors from the real programme: **pre-start** (the day before
week 1), **week 1 day 1**, **mid-programme** (week 3–5, with history
seeded), **a deload / test week**, **the last day**, **after the end**.

| # | Journey | Checks |
|---|---|---|
| J1 | First install, pre-start: launch quote → Today → every tab → Settings | empty states make sense, nothing claims history that does not exist |
| J2 | Day 1: Today → start the session → log every set with the steppers → rest timer → finish → finish moment → Today, History, Week, Calendar all agree | the core loop, end to end |
| J3 | Interrupted session: back out (confirm), resume from Today, leave with sets logged, reopen | nothing lost, no duplicate session |
| J4 | In a session: swap an exercise, skip a set, edit and undo a logged set, add a note / niggle | history keeps its own exercise ids |
| J5 | Calendar: move a session to a rest day, skip one, look at a missed one | Week, Today and the progress numbers agree |
| J6 | A run day: open the run, live tracker with fake GPS, pause, finish, summary, runs list, run detail, replay | the v3.1 run work in the full app |
| J7 | Fuel: eat / half / skip, swap, water, supplements; Plan: this week / next week, swap next Tuesday, tick the list; Today's next-meal card | swaps land on the right date, totals move |
| J8 | Body: weigh-in and tape on steppers, apply +250, revert, checkpoint ticks | no keyboard; adjustments stay applied |
| J9 | Photos: capture with the fake camera, viewer, compare, delete a photo then the shoot | files deleted, not just rows |
| J10 | Lifts and stats with seeded history: lift detail charts, PRs | numbers match the logs |
| J11 | More: library search and filter → exercise → demo; cardio; settings toggles, athlete name, calibration, programme editor (edit a prescription, a day), programme files, next cycle | editor changes reach Today and Week |
| J12 | Deload and test weeks; the last day; the day after the programme ends | Today, Week, Fuel, Plan still sensible |
| J13 | Clock edges: midnight rollover with the app open, the DST weekend, a month end, Friday → the Plan's "next week" | no day counted twice or skipped |
| J14 | Stress layout: 360 × 640 phone, text scale 1.3 and 2.0, on every tab root and the session runner | no overflow, 48 dp targets intact |
| J15 | Navigation: back from every drill-down, swipe on every tab root, swipe on drill-downs (must not move), tab tap to pop to root | never quits by accident, never loses a tab's place |

## 3. Data review

- Every exercise in the programme has a library entry, a demo and a licence;
  no invented YouTube links (V-gates cover most; spot-check the rest).
- Fuel: meal ids, names and notes still agree after v3.1 (an id that says
  one food and a name that says another); notes that promise something the
  meal does not contain.
- Quotes: attribution formats, no duplicates (V20), spot-read.

## 4. Triage and fixing

Each finding gets an ID (`Q1`, `Q2`, …), a severity, steps, expected,
actual, and a status.

- **Crash / data loss / wrong training data**: fixed now, with a
  regression test that fails first.
- **Wrong or misleading UI**: fixed now if the fix is local and safe.
- **Programme meaning, a new dependency, a new permission**: written down
  and left for Saad (CLAUDE.md, "What to ask me about").

Every fix goes through the gate: analyze clean, full suite green, V1–V21,
screenshots looked at, `dart format`. Commits carry no co-author line.

## Findings

Severity: **H** breaks a feature or loses data · **M** wrong numbers or a
misleading screen · **L** rough edge.

| ID | Sev | Where | What was wrong | Status |
|---|---|---|---|---|
| Q1 | M | Body trend | Across the clock change the 7-day weigh-in window held 6 weigh-ins (25 Oct), and the weekly rate read 0.375 for 0.35 kg (28 Mar): `subtract(Duration(days:))` on local dates. The eat-more rule reads both. | Fixed, tests |
| Q2 | L | Fuel adherence, programme anchor | Same shape: the 14-day adherence window became 15 days across the spring change; the Monday anchor was only safe by luck. | Fixed |
| Q3 | H | Body → Fuel | The +250 rule ("the app enforces this") could not be acted on: the Body page said "Add 250 kcal" with no button, Fuel said to take it off "in Body → adjustments", a page that did not exist, and nothing called apply or revert. The v3 spec's adherence gate (≥ 85 % eaten, else "eat the plan") and the reset after a change were never wired, so applying would have stacked +250 every visit; a −200 waist cut was dropped from the day's total. | Fixed: apply button, changes-in-force list with Take it off, Fuel banner shows the booster as food and links to Body; advice gains *Eat the plan* and *Settling in*. Tests |
| Q4 | L | Fuel adherence | A swap is stored as `planned`; it counted as a missed meal, so swapping next week on the Plan would lower adherence. | Fixed, test |
| Q5 | H | Cardio | Stop cleared the screen but not the scheduled round alarms; the phone kept calling "Round 4 — go" to "Done". Backing out mid-interval did the same, with no warning. | Fixed: Stop, back (asks) and leaving cancel the cues. Tests |
| Q6 | M | Cardio | The run section said **"No GPS — your phone already has a running app"** — stale since the tracker, and the source of the "phone already has running app" report. "Log a run" was a keyboard dialog that silently saved nothing for "30.5" or an empty field, and leaked its controllers. | Fixed: *Record a run* opens the tracker; *Log one by hand* is steppers. Tests |
| Q7 | L | Body, Cardio | Rows with no give: the "50.0 kg 7-day average" row and the week-target lines ran off the right at a large text size. | Fixed |
| Q8 | L | Editors, photos | `setState` after a dialog/sheet `await` with no `mounted` check. Modal, so theoretical. | Guarded |
| Q9 | M | Today, next meal | "Next to eat" went by the clock alone: at 10:35 the 10:30 meal had vanished, eaten or not; a meal just eaten stayed "next"; and its clock was frozen when Today was built — Today stays alive behind the other tabs, so it could be hours stale. | Fixed: the first meal not yet logged, kept for two hours past its time; the card ticks each minute. Tests |
| Q10 | M | Fuel meal cards | Tapping Eaten / Half / Skip saved, but the buttons never showed it — the status provider was never refreshed — inviting a second tap. Selected was shown by fill alone. | Fixed: refreshed with the day; selected carries a tick. Test |
| Q11 | H | Session runner | At 1.3× text on a small phone the safety warnings pushed "Read it — start the session" off the screen: the session could not be started. (Layout robot.) | Fixed: warnings scroll within 40 % of the screen, the button is pinned under them. Robot re-run clean |
| Q12 | H | Today, resume | "Session in progress" opened the runner without the session's date. Left open past midnight (or moved), resuming it **started a second session** for the same day and orphaned the first, splitting its sets. | Fixed: one `sessionRunPath` for the banner and the day sheet. Test |
| Q13 | M | Session runner | A session resumed hours later counted the whole night: the header read "1480 / 45 min" and the runner opened on "Running long — you are 1480 minutes in, cut the last superset". The header row also had no give. | Fixed: over three hours open is an interruption; the budget stops, the header says "picked up again" and wraps. Test |
| Q14 | L | Today week strip | "2 of 5 done · 3 in a row" ran off the card at a large text size. (Layout robot.) | Fixed |

| Q15 | M | Fuel after the programme | The day after week 12, Fuel fell back to week one: 2,596 kcal instead of ~2,900 — 300 a day gone the week the programme ends, for someone whose problem is eating enough. The code's own comment said "week twelve". (Timeline robot screenshot.) | Fixed, test |
| Q16 | H | Backup restore | A restore that failed part way (a row the schema cannot hold) left an **empty database**: the wipe was committed before the import's transaction. Files could be written before the data had imported; and a zip entry like `../x` was written outside the app's folder. The "newer schema refuses" test never called restore. | Fixed: data first, wipe and inserts in one transaction, then only a backup's own entries, each checked to stay inside. Tests |
| Q17 | M | After a restore | Only the programme was reloaded. Preferences held in memory would be written back over the restored ones at the next toggle; the equipment, Fuel, stats and run lists showed pre-restore data until a cold start. | Fixed: the app restarts in place (`RestartScope`: new provider container, database reopened). Test |

Checked and sound: a 0 kg set does not break the next suggestion (tests
kept), pace with no distance, calendar moves (live streams), the plate and
chart divisions.

**Timeline robot (J1, J12):** 13 screens at six moments — the day before,
day 1, deload, test week, the last day, after the end — with seeded history:
0 framework errors; screenshots read for sense (found Q15).

**Back robot (J15):** back from 15 drill-downs lands on the parent, in the
same tab, never on "Close the app?": 15/15.

| Q18 | L | Session runner | After logging a niggle: "stop the set and use the substitute" — with no substitute in sight. They are on the exercise page ("If this one is not working today"), one tap from the runner. | Copy now says where |
| Q19 | L | Fuel data | The rest-day "Lentils and couscous" promised "no cooking beyond a kettle" — with 60 g of dry red lentils in it. | Note fixed in `gen_fuel.py`, regenerated |

**Data review:** fuel notes scanned for promises their food contradicts
(Q19; the rest agree); gates V1–V21 pass; the stale "phone already has a
running app" copy was the one piece of text describing a feature that no
longer exists (Q6).

**Left for Saad** (CLAUDE.md, "what to ask me about"):

1. **Logging a substitute mid-session.** Sixty-five exercises carry
   authored substitutes, and they are shown, but a session can only log the
   prescribed exercise. Swapping in the runner would record sets under the
   substitute's own id (history already supports it); it touches exercise
   selection, so it waits for your word.
2. **What this pass cannot reach.** No emulator or phone here: GPS, the
   camera, notifications with the screen off, the midnight roll-over on a
   real clock — `docs/07-on-device-checklist.md` has those, including the
   new Body → "Add 250 kcal a day" loop and the restore reload.

**How to run it again:**

```bash
flutter test --dart-define=QA=true test/qa/
```

**Layout robot (J14):** 22 screens × {360×640, 360×640 at 1.3×, 412×915 at
2.0×}, real fonts, every list swept to the end. First run: 4 overflows in 2
places (Q11, Q14). After the fixes: **0 issues in 66 renders**.
