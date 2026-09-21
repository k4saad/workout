#!/usr/bin/env python3
"""Generate the Keller Twelve v2 data files.

Everything numeric is computed, never typed:
  - every startLoadKg is snapped onto the plate lattice for its loadMode
  - every estMinutes is computed from the prescriptions, ramps and implement changes
This is the file that stops v1's 19-unloadable-weights bug from recurring.
"""
import json, math, itertools, os, io

OUT = r"C:\Users\Saad\OneDrive\Desktop\workout\data"
V1 = os.path.join(OUT, "v1-reference")

# ----------------------------------------------------------------------------
# Inventory — PLACEHOLDER. Weigh yours (docs/04-calibration.md) and regenerate.
# "Ideal" microplates: 0.5 kg and 0.25 kg pairs -> a 0.5 kg barbell lattice step.
# ----------------------------------------------------------------------------
INVENTORY = {
    "_comment": "PLACEHOLDER VALUES. Replace from docs/04-calibration.md, then re-run tools/gen.py.",
    "bars": [
        {"id": "barbell",  "name": "Standard spinlock barbell", "weightKg": 9.0, "measured": False},
        {"id": "ezBar",    "name": "EZ curl bar",               "weightKg": 6.0, "measured": False},
        {"id": "dbHandle", "name": "Dumbbell handle",           "weightKg": 2.0, "measured": False},
    ],
    "plates": [
        {"weightKg": 20.0, "count": 2, "bore": "standard"},
        {"weightKg": 10.0, "count": 4, "bore": "standard"},
        {"weightKg": 5.0,  "count": 8, "bore": "standard"},
        {"weightKg": 2.5,  "count": 8, "bore": "standard"},
        {"weightKg": 1.25, "count": 8, "bore": "standard"},
        {"weightKg": 0.5,  "count": 8, "bore": "standard"},
        {"weightKg": 0.25, "count": 8, "bore": "standard"},
    ],
    "fixedDumbbells": [{"weightKg": 2.0, "count": 2}, {"weightKg": 3.0, "count": 2}],
    "kettlebells": [{"weightKg": 8.0}],
    "collarWeightKg": 0.0,
    "cable": {"present": True, "maxKg": None, "incrementKg": None,
              "note": "Wall-mounted single pulley. Measure the stack and increment."},
    "room": {"ceilingLiftingCm": None, "ceilingSkippingCm": None,
             "pullUpClearanceCm": None, "carryLengthM": None},
}

BAR = {b["id"]: b["weightKg"] for b in INVENTORY["bars"]}
PLATES = [(p["weightKg"], p["count"]) for p in INVENTORY["plates"]]
DIV = {"barbell": 2, "ezBar": 2, "dumbbellPair": 4, "dumbbellSingle": 2}
BASE = {"barbell": BAR["barbell"], "ezBar": BAR["ezBar"],
        "dumbbellPair": BAR["dbHandle"], "dumbbellSingle": BAR["dbHandle"]}


def lattice(mode, max_kg=200.0):
    """Every total load this mode can actually make."""
    if mode not in DIV:
        return None
    base, div = BASE[mode], DIV[mode]
    budget = [(kg, c // div) for kg, c in PLATES]
    out = set()
    for combo in itertools.product(*[range(n + 1) for _, n in budget]):
        per = sum(kg * n for (kg, _), n in zip(budget, combo))
        t = round(base + 2 * per, 3)
        if t <= max_kg:
            out.add(t)
    return sorted(out)


LAT = {m: lattice(m) for m in DIV}


def snap(target, mode):
    """Closest loadable weight at or BELOW target. Never up."""
    if mode not in LAT:
        return target
    below = [a for a in LAT[mode] if a <= target + 1e-9]
    return below[-1] if below else LAT[mode][0]


def valid(kg, mode):
    return mode not in LAT or any(abs(a - kg) < 1e-6 for a in LAT[mode])


def step_at(kg, mode):
    """Smallest loadable increment above kg."""
    if mode not in LAT:
        return None
    above = [a for a in LAT[mode] if a > kg + 1e-9]
    return round(above[0] - kg, 3) if above else None


def breakdown(kg, mode):
    if mode not in DIV:
        return None
    base, div = BASE[mode], DIV[mode]
    per, parts = (kg - base) / 2, []
    for w, c in PLATES:
        n = min(int(per / w + 1e-9), c // div)
        if n:
            parts.append(f"{w:g}x{n}")
            per -= w * n
    return " + ".join(parts) if parts else "bare"


# ----------------------------------------------------------------------------
# Builders
# ----------------------------------------------------------------------------
def P(pid, ex, order, sets, rmin, rmax, rest, mode, load=None, *,
      rir=None, prog=None, subs=None, note=None, tempo=None, uni=False,
      per_side=False, group=None, unit="reps", creep=None, ramp=False,
      optional=False):
    if load is not None:
        load = snap(load, mode)
    p = {
        "id": pid, "exerciseId": ex, "order": order,
        "groupId": group, "unit": unit,
        "sets": sets, "repsMin": rmin, "repsMax": rmax, "repsCreepMax": creep,
        "restSec": rest, "targetRir": rir,
        "loadMode": mode, "startLoadKg": load,
        "perSide": per_side, "unilateral": uni,
        "warmupRamp": ramp, "optional": optional,
        "progression": prog or {"type": "none"},
        "substitutes": subs or [],
        "coachNote": note, "tempo": tempo,
    }
    return p


def DP(inc, *, deload=0.10, stall=2, window=21, maxjump=0.10):
    return {"type": "doubleProgression", "incrementKg": inc, "deloadPct": deload,
            "stallLimit": stall, "historyWindowDays": window, "maxJumpPct": maxjump}


REPS = {"type": "repsOnly", "stallLimit": 3, "historyWindowDays": 21}
TIME = lambda s=5: {"type": "timeOnly", "incrementSec": s, "stallLimit": 3, "historyWindowDays": 21}
BAND = {"type": "bandProgression", "stallLimit": 3, "historyWindowDays": 21}
CARD = {"type": "cardioTable", "stallLimit": 99, "historyWindowDays": 21}
NONE = {"type": "none"}


def drill(ex, order, text, note=None):
    return {"exerciseId": ex, "order": order, "text": text, "note": note}


def S(stype, title, *, drills=None, prescriptions=None):
    return {"type": stype, "title": title, "estMinutes": 0,
            "drills": drills or [], "prescriptions": prescriptions or []}


def D(did, weekday, title, kind, sections, *, note=None, warnings=None, optional=False):
    return {"id": did, "weekday": weekday, "title": title, "kind": kind,
            "optional": optional, "estMinutes": 0, "note": note,
            "warnings": warnings or [], "sections": sections}


# ----------------------------------------------------------------------------
# Time model — honest, and the reason estMinutes is computed not guessed
# ----------------------------------------------------------------------------
IMPLEMENT = {"barbell": "bar", "ezBar": "ez", "dumbbellPair": "db",
             "dumbbellSingle": "db", "kettlebell": "kb", "cable": "cable",
             "banded": "band", "bodyweight": "bw", "bodyweightLoaded": "bw",
             "timed": "bw", "distance": "bw"}
DRILL_SEC = 45          # per warm-up/cool-down drill
CHANGE_SEC = 60         # one spinlock re-plate or dumbbell reassembly


def work_sec(p):
    if p["unit"] == "sec":
        w = p["repsMax"]
    elif p["unit"] == "m":
        w = p["repsMax"] * 0.3
    else:
        w = max(25, p["repsMax"] * 3.5)
    return w * (2 if p["perSide"] else 1)


def day_minutes(day):
    total, last_impl, last_load = 0, None, None
    for sec in day["sections"]:
        sec_sec = len(sec["drills"]) * DRILL_SEC
        pres = sorted(sec["prescriptions"], key=lambda x: x["order"])
        # group supersets so only the last member's rest counts per round
        groups, seen = [], set()
        for p in pres:
            g = p["groupId"]
            if g is None:
                groups.append([p])
            elif g not in seen:
                seen.add(g)
                groups.append([q for q in pres if q["groupId"] == g])
        for grp in groups:
            rounds = max(p["sets"] for p in grp)
            if grp[0]["warmupRamp"]:
                sec_sec += 2 * (30 + 75)
            per_round = sum(work_sec(p) for p in grp) + \
                sum(p["restSec"] for p in grp if p["restSec"] > 0)
            sec_sec += rounds * per_round
            for p in grp:
                impl = IMPLEMENT.get(p["loadMode"], "bw")
                if impl in ("bar", "ez", "db", "kb"):
                    key = (impl, p["startLoadKg"])
                    if last_impl is not None and key != (last_impl, last_load):
                        sec_sec += CHANGE_SEC
                    last_impl, last_load = impl, p["startLoadKg"]
        sec["estMinutes"] = int(round(sec_sec / 60))
        total += sec_sec
    day["estMinutes"] = int(round(total / 60))
    return day["estMinutes"]


# ============================================================================
# FOUNDATION — weeks 1-4
# ============================================================================
WARN_PINS_SQ = {"title": "Set the catch pins",
                "body": "Before your first work set, set the stand's catch pins just below your "
                        "bottom position. Miss a rep and you sit down; the bar lands on steel."}
WARN_PINS_BN = {"title": "Bench pins at chest height",
                "body": "Set the pins so a failed rep lands on them and not on you. Never take "
                        "the bench press to failure alone."}
WARN_BAR_HT = {"title": "Bar height — read before your first pull",
               "body": "Your plates are small-diameter, so a lightly loaded bar sits too low and "
                       "forces your back to round at the start. Stack the two 20 kg tri-grips flat "
                       "and rest each end of the bar on them until your working weight has enough "
                       "plates to raise it naturally — around 50 kg with the 20s on."}
WARN_CEIL = {"title": "Check the ceiling",
             "body": "Measure your overhead clearance before pressing. The basement beams and "
                     "pipes are not at a uniform height."}
WARN_COLLAR = {"title": "Collars on, checked mid-set",
               "body": "Spinlock collars work loose under load. A plate sliding off one end is "
                       "the single most likely injury in your room."}
WARN_PAD = {"title": "Pad the hip thrust bar",
            "body": "Fold the green mat over the bar. A bare bar on the hip bones ends the set early."}

f_mon = D("f-mon", "mon", "Full Body A", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "6 x 30 s on / 30 s off", "On the interlocking mats, never bare concrete."),
        drill("broomstick-pass-through", 2, "x 10", "Wide grip, over the head and behind."),
        drill("bodyweight-squat", 3, "x 15"),
        drill("glute-bridge", 4, "x 15"),
        drill("band-pull-apart", 5, "x 20", "Green band."),
        drill("leg-swing", 6, "x 10 / side"),
    ]),
    S("main", "Main work", prescriptions=[
        P("f-mon-1", "barbell-back-squat", 1, 3, 8, 8, 120, "barbell", 9.0, rir=None,
          prog=DP(2.5), subs=["goblet-squat", "dumbbell-squat"],
          note="EMPTY BAR in week 1. No exceptions. Brace as if someone is about to punch your "
               "stomach, then sit down and stand up."),
        P("f-mon-2", "barbell-romanian-deadlift", 2, 3, 10, 10, 90, "barbell", 15.0, rir=None,
          prog=DP(2.5), subs=["dumbbell-romanian-deadlift", "barbell-good-morning"],
          note="Same bar, add plates. The bar stays in contact with your legs the whole way down. "
               "If it drifts forward, your lower back takes it."),
        P("f-mon-3a", "push-up-handles", 3, 3, 8, 12, 0, "bodyweight", None, rir=3,
          prog=REPS, subs=["incline-push-up", "dumbbell-floor-press", "dumbbell-bench-press"],
          group="f-mon-ss1", creep=20,
          note="Bodyweight on purpose, so the one dumbbell stays loaded through the whole "
               "superset. If you can't get 8, put your hands on the bench and do them at an incline."),
        P("f-mon-3b", "one-arm-dumbbell-row", 4, 3, 10, 10, 75, "dumbbellSingle", 7.0, rir=None,
          prog=DP(1.0), subs=["chest-supported-dumbbell-row", "ring-row"], group="f-mon-ss1",
          uni=True, per_side=True,
          note="Pull to the hip pocket, not the armpit. One full second at the top."),
        P("f-mon-4", "plank", 5, 3, 30, 30, 45, "timed", None, unit="sec",
          prog=TIME(5), subs=["dead-bug", "hollow-hold"],
          note="The second your lower back sags, the set is over. Reset rather than holding a bad shape."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("couch-stretch", 1, "45 s / side"),
        drill("standing-hamstring-stretch", 2, "45 s / side"),
        drill("doorway-chest-stretch", 3, "45 s / side"),
    ]),
], note="Squat-led. Every load is deliberately light — you are rehearsing patterns, not testing "
        "yourself. The four weeks you spend here are the four you don't lose to a tweaked back in week six.",
   warnings=[WARN_PINS_SQ, WARN_COLLAR])

f_tue = D("f-tue", "tue", "Skip, Run & Core", "cardio", [
    S("cardio", "Session", prescriptions=[
        P("f-tue-1", "rope-skipping", 1, 6, 60, 60, 60, "timed", None, unit="sec", prog=TIME(15),
          note="Skipping wrecks untrained calves and Achilles tendons, so we ramp it over four weeks."),
        P("f-tue-2", "easy-run", 2, 1, 900, 1080, 0, "timed", None, unit="sec", prog=CARD,
          subs=["run-intervals"],
          note="Conversational pace. If you cannot speak a full sentence, you are going too fast."),
        P("f-tue-3a", "dead-bug", 3, 3, 10, 10, 0, "bodyweight", None, prog=REPS,
          group="f-tue-core", uni=True, per_side=True,
          note="Three-round circuit with the side plank and hollow hold."),
        P("f-tue-3b", "side-plank", 4, 3, 20, 20, 0, "timed", None, unit="sec", prog=TIME(5),
          group="f-tue-core", uni=True, per_side=True),
        P("f-tue-3c", "hollow-hold", 5, 3, 20, 20, 45, "timed", None, unit="sec", prog=TIME(5),
          group="f-tue-core"),
    ]),
], note="Easy means easy. This session exists for your heart and your calves, not to burn "
        "calories — you need those.")

f_wed = D("f-wed", "wed", "Full Body B", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "2 min"),
        drill("cat-cow", 2, "x 10"),
        drill("glute-bridge", 3, "x 15"),
        drill("bodyweight-good-morning", 4, "x 15"),
        drill("band-pull-apart", 5, "x 20"),
    ]),
    S("main", "Main work", prescriptions=[
        P("f-wed-1", "barbell-deadlift", 1, 3, 5, 5, 150, "barbell", 9.0, rir=None,
          prog=DP(5.0), subs=["dumbbell-deadlift", "barbell-romanian-deadlift"],
          note="EMPTY BAR from the blocks in week 1. Take the slack out of the bar before you "
               "pull — you should hear it click. Set it down and reset every rep."),
        P("f-wed-2", "barbell-overhead-press", 2, 3, 8, 8, 105, "barbell", 9.0, rir=None,
          prog=DP(1.0), subs=["dumbbell-overhead-press", "seated-dumbbell-press"],
          note="Empty bar in week 1. Ribs down, glutes and abs locked. Leaning back to move the "
               "weight means it is too heavy."),
        P("f-wed-3a", "ring-row", 3, 3, 8, 12, 0, "bodyweight", None, rir=3, prog=REPS,
          subs=["one-arm-dumbbell-row", "chest-supported-dumbbell-row"], group="f-wed-ss1",
          creep=15,
          note="The more horizontal your body, the harder it gets. Log your foot position so you "
               "can repeat it."),
        P("f-wed-3b", "goblet-squat", 4, 3, 10, 10, 75, "kettlebell", 8.0, prog=NONE,
          subs=["dumbbell-squat", "barbell-back-squat"], group="f-wed-ss1",
          note="Depth is whatever you can hold without the lower back rounding. That point is "
               "your depth for now."),
        P("f-wed-4", "dead-bug", 5, 3, 10, 10, 30, "bodyweight", None, prog=REPS,
          subs=["plank"], uni=True, per_side=True,
          note="Lower back pressed flat into the mat the entire time."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("ninety-ninety-hip-switch", 1, "10 / side"),
        drill("thoracic-rotation", 2, "10 / side"),
        drill("standing-hamstring-stretch", 3, "45 s / side"),
    ]),
], note="Hinge-led, and the day that teaches you the deadlift and the overhead press — the two "
        "lifts a beginner is most often thrown into cold.",
   warnings=[WARN_BAR_HT, WARN_CEIL, WARN_COLLAR])

f_thu = D("f-thu", "thu", "Rest", "rest", [],
          note="A real rest day. Eat your full target, get eight hours, walk if you feel like "
               "moving. Muscle is built on the days you don't train — the session only sends the signal.")

f_fri = D("f-fri", "fri", "Full Body C", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "2 min"),
        drill("band-pull-apart", 2, "x 20"),
        drill("wall-slide", 3, "x 10"),
        drill("push-up-handles", 4, "x 10"),
        drill("dead-hang", 5, "2 x 20 s"),
    ]),
    S("main", "Main work", prescriptions=[
        P("f-fri-1", "barbell-bench-press", 1, 3, 8, 8, 120, "barbell", 9.0, rir=None,
          prog=DP(1.0), subs=["dumbbell-floor-press", "dumbbell-bench-press"],
          note="Empty bar in week 1. Feet flat, shoulder blades pinched back and down, bar to the "
               "lower chest, elbows at 45-60 degrees."),
        P("f-fri-2", "barbell-bent-over-row", 2, 3, 8, 8, 105, "barbell", 9.0, rir=None,
          prog=DP(2.5), subs=["one-arm-dumbbell-row", "chest-supported-dumbbell-row"],
          note="Same bar as the bench. Pull to the navel. If your torso rises with every rep, the "
               "weight is winning."),
        P("f-fri-3a", "pull-up-negative", 3, 3, 4, 4, 0, "bodyweight", None, prog=REPS,
          subs=["pull-up-assisted", "ring-row"], group="f-fri-ss1", tempo="5s eccentric",
          note="Step or jump to the top, then fight the way down for a full five seconds. This is "
               "the fastest route to your first strict pull-up."),
        P("f-fri-3b", "bulgarian-split-squat", 4, 3, 8, 8, 75, "bodyweight", None, rir=3,
          prog=REPS, subs=["split-squat", "reverse-lunge"], group="f-fri-ss1",
          uni=True, per_side=True, creep=12,
          note="Bodyweight only for four weeks. Brutal for a bodyweight movement — that is "
               "normal, don't add load."),
        P("f-fri-4", "ab-wheel-knees", 5, 2, 6, 6, 60, "bodyweight", None, prog=REPS,
          subs=["plank", "hollow-hold"], creep=10,
          note="Partial range. If your back arches at all, swap for a 3 x 40 s plank until week 3."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("doorway-chest-stretch", 1, "45 s / side"),
        drill("couch-stretch", 2, "45 s / side"),
    ]),
], note="Press-led, plus the first work towards a pull-up. You will not get a pull-up by trying "
        "pull-ups — you get it by lowering yourself slowly, over and over.",
   warnings=[WARN_PINS_BN, WARN_COLLAR])

f_sat = D("f-sat", "sat", "Rest", "rest", [],
          note="Off. Cook something big — Saturday is the easiest day of the week to bank a "
               "3,000 kcal day, and a good week of eating covers a mediocre week of training.")

f_sun = D("f-sun", "sun", "Easy Run & Mobility", "cardio", [
    S("cardio", "Session", prescriptions=[
        P("f-sun-1", "easy-run", 1, 1, 1200, 1320, 0, "timed", None, unit="sec", prog=CARD,
          subs=["run-intervals"], note="The longer of your two runs. Same conversational pace."),
        P("f-sun-2", "rope-skipping", 2, 3, 60, 60, 60, "timed", None, unit="sec", prog=TIME(15)),
        P("f-sun-3", "dead-hang", 3, 3, 20, 20, 45, "timed", None, unit="sec", prog=TIME(5),
          note="From the rings or the wall bar. Relax into it — this decompresses everything the "
               "squats and rows compressed all week."),
    ]),
    S("cooldown", "Mobility", drills=[
        drill("ninety-ninety-hip-switch", 1, "10 / side"),
        drill("couch-stretch", 2, "45 s / side"),
        drill("thoracic-rotation", 3, "10 / side"),
        drill("standing-hamstring-stretch", 4, "45 s / side"),
        drill("cat-cow", 5, "x 10"),
    ]),
])

FOUNDATION_DAYS = [f_mon, f_tue, f_wed, f_thu, f_fri, f_sat, f_sun]

# ============================================================================
# BUILD — weeks 5-7  (Deload and Push inherit these)
# ============================================================================
b_mon = D("b-mon", "mon", "Lower A · Squat", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "3 min"),
        drill("leg-swing", 2, "x 10 / side"),
        drill("bodyweight-squat", 3, "x 15"),
        drill("glute-bridge", 4, "x 15"),
    ]),
    S("main", "Main work", prescriptions=[
        P("b-mon-1", "barbell-back-squat", 1, 4, 5, 5, 150, "barbell", 21.0, ramp=True,
          prog=DP(2.5), subs=["barbell-front-squat", "goblet-squat"], creep=7,
          note="The most important set of your week. Drive the whole foot through the floor coming "
               "up — don't let the hips shoot up first."),
        P("b-mon-2", "barbell-romanian-deadlift", 2, 3, 8, 8, 120, "barbell", 27.0, rir=None,
          prog=DP(2.5), subs=["dumbbell-romanian-deadlift", "barbell-good-morning",
                              "single-leg-rdl"], creep=12,
          note="Same bar, strip to the RDL weight once. Squeeze the glutes to stand up rather "
               "than pulling with the lower back."),
        P("b-mon-3a", "bulgarian-split-squat", 3, 3, 8, 8, 0, "dumbbellPair", 6.0, rir=None,
          prog=DP(1.0), subs=["reverse-lunge", "split-squat", "step-up", "walking-lunge"],
          group="b-mon-ss1", uni=True, per_side=True, creep=12,
          note="Torso slightly forward loads the glute, upright loads the quad. Pick one and stay "
               "consistent."),
        P("b-mon-3b", "single-leg-calf-raise", 4, 3, 15, 15, 75, "bodyweight", None, rir=1,
          prog=REPS, subs=["standing-calf-raise"], group="b-mon-ss1",
          uni=True, per_side=True, creep=25,
          note="On the edge of the step platform. Bodyweight on purpose — no plate change inside "
               "the superset. Full stretch at the bottom, 2-second squeeze at the top."),
        P("b-mon-4a", "hanging-knee-raise", 5, 3, 8, 12, 0, "bodyweight", None, rir=1,
          prog=REPS, subs=["dead-bug", "hollow-hold"], group="b-mon-ss2", creep=18,
          note="No swinging. Curl the pelvis up towards the ribs, don't just lift the thighs."),
        P("b-mon-4b", "pull-up-negative", 6, 3, 3, 3, 60, "bodyweight", None,
          prog=REPS, subs=["pull-up-assisted", "ring-row"], group="b-mon-ss2",
          tempo="5s eccentric", creep=6,
          note="You are already hanging on the bar, so this costs you almost nothing. A second "
               "vertical-pull exposure in the week is what buys you your first strict pull-up."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("couch-stretch", 1, "45 s / side"),
        drill("ninety-ninety-hip-switch", 2, "10 / side"),
    ]),
], note="Quads, glutes and the whole brace. If you only ever do one thing properly, make it this squat.",
   warnings=[WARN_PINS_SQ, WARN_COLLAR])

b_tue = D("b-tue", "tue", "Upper A · Bench-led", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "3 min"),
        drill("band-pull-apart", 2, "2 x 20"),
        drill("wall-slide", 3, "x 10"),
        drill("push-up-handles", 4, "x 10"),
    ]),
    S("main", "Main work", prescriptions=[
        P("b-tue-1", "barbell-bench-press", 1, 4, 6, 6, 150, "barbell", 17.0, ramp=True,
          prog=DP(1.0), subs=["dumbbell-bench-press", "dumbbell-floor-press"], creep=10,
          note="Bar to the lower chest, elbows at 45-60 degrees, drive up and slightly towards "
               "your face. Pins at chest height."),
        P("b-tue-2", "barbell-bent-over-row", 2, 4, 8, 8, 120, "barbell", 19.0, rir=None,
          prog=DP(2.5), subs=["one-arm-dumbbell-row", "chest-supported-dumbbell-row"], creep=12,
          note="Same bar as the bench. This is the row v1 left out of push day — your shoulders "
               "need it on the same day you press."),
        P("b-tue-3a", "incline-dumbbell-press", 3, 3, 10, 10, 0, "dumbbellPair", 7.0, rir=None,
          prog=DP(1.0), subs=["dumbbell-bench-press"], group="b-tue-ss1", creep=14,
          note="Bench at its lower incline notch, roughly 30 degrees."),
        P("b-tue-3b", "cable-face-pull", 4, 3, 15, 15, 60, "cable", None, rir=None,
          prog=BAND, subs=["band-face-pull", "band-pull-apart"], group="b-tue-ss1",
          note="Use the wall cable — no plate change inside the superset. Elbows high and wide, "
               "rotating the hands back. The insurance policy on every press you do."),
        P("b-tue-4a", "ez-bar-curl", 5, 3, 10, 10, 0, "ezBar", 8.0, rir=1,
          prog=DP(1.0), subs=["dumbbell-curl", "hammer-curl"], group="b-tue-ss2",
          tempo="3s eccentric", creep=14,
          note="Elbows pinned to the ribs. Lower over 3 seconds — the negative is where the arm grows."),
        P("b-tue-4b", "lateral-raise", 6, 3, 12, 15, 45, "dumbbellPair", 2.0, rir=1,
          prog=DP(0.5), subs=["band-lateral-raise"], group="b-tue-ss2", tempo="3s eccentric",
          creep=20,
          note="Bare handles, or the fixed vinyl dumbbells. Lead with the elbows. There is no such "
               "thing as a heavy lateral raise."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("doorway-chest-stretch", 1, "45 s / side"),
        drill("thoracic-rotation", 2, "10 / side"),
    ]),
], note="10 pressing sets and 10 pulling sets. Every upper day in this programme is balanced — "
        "that is the whole point of the rewrite.",
   warnings=[WARN_PINS_BN, WARN_COLLAR])

b_wed = D("b-wed", "wed", "Easy Run or Nothing", "cardio", [
    S("cardio", "Session", prescriptions=[
        P("b-wed-1", "easy-run", 1, 1, 1200, 1500, 0, "timed", None, unit="sec", prog=CARD,
          note="Zone 2. If you cannot breathe through your nose, you are going too fast."),
    ]),
    S("cooldown", "Mobility", drills=[
        drill("ninety-ninety-hip-switch", 1, "10 / side"),
        drill("thoracic-rotation", 2, "10 / side"),
        drill("couch-stretch", 3, "45 s / side"),
    ]),
], optional=True,
   note="Genuinely optional. Take it if you slept well and ate enough; skip it without guilt if "
        "you are sore, behind on food, or the week is heavy. At your bodyweight, extra cardio is "
        "a cost, not a bonus.")

b_thu = D("b-thu", "thu", "Lower B · Deadlift", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "3 min"),
        drill("cat-cow", 2, "x 10"),
        drill("glute-bridge", 3, "x 20"),
        drill("bodyweight-good-morning", 4, "x 15"),
    ]),
    S("main", "Main work", prescriptions=[
        P("b-thu-1", "barbell-deadlift", 1, 3, 5, 5, 180, "barbell", 39.0, ramp=True,
          prog=DP(2.5), subs=["barbell-romanian-deadlift", "dumbbell-deadlift"], creep=6,
          note="Three sets, not four — this is the highest-fatigue lift you own. Set it down and "
               "reset every rep. Never to failure."),
        P("b-thu-2", "barbell-front-squat", 2, 3, 8, 8, 120, "barbell", 16.0, rir=None,
          prog=DP(1.0), subs=["goblet-squat", "barbell-back-squat"], creep=12,
          note="Your second squat exposure of the week, and the one v1 was missing. Elbows high, "
               "torso vertical. Swap to a goblet squat if the wrists complain."),
        P("b-thu-3a", "barbell-hip-thrust", 3, 3, 10, 10, 0, "barbell", 24.0, rir=None,
          prog=DP(2.5), subs=["dumbbell-hip-thrust", "glute-bridge"], group="b-thu-ss1",
          tempo="1s pause top", creep=15,
          note="Squeeze hard at the top for a full second. Ribs stay down — don't arch the lower "
               "back to get higher."),
        P("b-thu-3b", "single-leg-calf-raise", 4, 3, 20, 20, 60, "bodyweight", None, rir=1,
          prog=REPS, subs=["standing-calf-raise"], group="b-thu-ss1",
          uni=True, per_side=True, creep=30,
          note="Higher reps than Monday, same quality. No bouncing."),
        P("b-thu-4", "suitcase-carry", 5, 3, 30, 30, 60, "dumbbellSingle", 14.0, unit="sec",
          prog=DP(2.5), subs=["farmers-walk"], uni=True, per_side=True,
          note="Walk the length of the basement without leaning away from it. Check the collars "
               "before you pick it up."),
        P("b-thu-5", "nordic-curl-negative", 6, 3, 5, 5, 90, "bodyweight", None, prog=REPS,
          subs=["slider-hamstring-curl", "dumbbell-romanian-deadlift"], tempo="max eccentric",
          optional=True, creep=8,
          note="FROM WEEK 9 ONLY — skip this in weeks 5-8. Hook your feet under the squat stand. "
               "Lower as slowly as you can control; expect to fall fast at first."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("standing-hamstring-stretch", 1, "45 s / side"),
        drill("cat-cow", 2, "x 10"),
    ]),
], note="Deadlift day. The heaviest thing you lift all week and the lift with the least margin "
        "for sloppy technique. Five reps, never more, never to failure.",
   warnings=[WARN_BAR_HT, WARN_PAD, WARN_COLLAR])

b_fri = D("b-fri", "fri", "Upper B · Press-led", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "3 min"),
        drill("band-pull-apart", 2, "2 x 20"),
        drill("wall-slide", 3, "x 10"),
        drill("dead-hang", 4, "2 x 20 s"),
    ]),
    S("main", "Main work", prescriptions=[
        P("b-fri-1", "barbell-overhead-press", 1, 4, 6, 6, 150, "barbell", 13.0, ramp=True,
          prog=DP(1.0), subs=["dumbbell-overhead-press", "seated-dumbbell-press"], creep=10,
          note="Glutes and abs locked. Head moves back, then through, as the bar passes. Leaning "
               "back to move it means it is too heavy."),
        P("b-fri-2", "pull-up-assisted", 2, 4, 3, 8, 120, "banded", None, rir=1,
          prog=BAND, subs=["pull-up", "pull-up-negative", "ring-row"],
          note="Always stop one rep before failure. When you get 8 assisted, move to a thinner "
               "band. Log the band colour in the set note."),
        P("b-fri-3a", "dumbbell-bench-press", 3, 3, 10, 10, 0, "dumbbellPair", 8.0, rir=None,
          prog=DP(1.0), subs=["dumbbell-floor-press", "incline-dumbbell-press"],
          group="b-fri-ss1", creep=14),
        P("b-fri-3b", "ring-row", 4, 3, 10, 12, 60, "bodyweight", None, prog=REPS,
          subs=["chest-supported-dumbbell-row", "one-arm-dumbbell-row"], group="b-fri-ss1",
          creep=16,
          note="Bodyweight, so the dumbbells stay loaded through the whole superset. Walk your "
               "feet forward to make it harder."),
        P("b-fri-4a", "hammer-curl", 5, 3, 12, 12, 0, "dumbbellPair", 5.0, rir=1,
          prog=DP(1.0), subs=["dumbbell-curl", "ez-bar-curl"], group="b-fri-ss2", creep=16,
          note="Neutral grip, thumbs up. Hits the brachialis, which pushes the arm wider."),
        P("b-fri-4b", "cable-triceps-pushdown", 6, 3, 12, 15, 45, "cable", None, rir=1,
          prog=BAND, subs=["ez-bar-skullcrusher", "overhead-dumbbell-extension", "bench-dip", "ring-dip"],
          group="b-fri-ss2",
          note="Wall cable — no plate change inside the superset. Elbows pinned to the ribs."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("dead-hang", 1, "30 s"),
        drill("doorway-chest-stretch", 2, "45 s / side"),
    ]),
], note="10 pressing sets and 10 pulling sets again. Back and biceps are what make a physique "
        "read as trained, and they are what beginners skimp on.",
   warnings=[WARN_CEIL, WARN_COLLAR])

b_sat = D("b-sat", "sat", "Rest", "rest", [],
          note="Complete rest after four lifting days. Cook, sleep in, meal-prep for the week. "
               "If you are twitchy, a 30-minute walk is all you get.")

b_sun = D("b-sun", "sun", "Run, Skip & Core", "cardio", [
    S("cardio", "Session", prescriptions=[
        P("b-sun-1", "easy-run", 1, 1, 1440, 1560, 0, "timed", None, unit="sec", prog=CARD,
          subs=["run-intervals"],
          note="Your one dedicated cardio session, 48 hours clear of Thursday's deadlifts and a "
               "full day before Monday's squat. Follow the cardio table."),
        P("b-sun-2", "rope-skipping", 2, 8, 30, 30, 30, "timed", None, unit="sec", prog=TIME(0),
          note="Fast intervals. Balls of the feet, elbows in, wrists doing the work."),
        P("b-sun-3", "heavy-bag-rounds", 3, 3, 120, 120, 60, "timed", None, unit="sec", prog=NONE,
          subs=["rope-skipping"],
          note="Wraps or gloves on, always. Straight punches, move your feet, breathe out on every "
               "shot. This lives on Sunday, not on lifting days — that is where v1's 77-minute "
               "sessions came from."),
        P("b-sun-4a", "ab-wheel-knees", 4, 3, 8, 8, 0, "bodyweight", None, rir=1, prog=REPS,
          subs=["plank"], group="b-sun-core", creep=14),
        P("b-sun-4b", "hollow-hold", 5, 3, 30, 30, 0, "timed", None, unit="sec", prog=TIME(5),
          subs=["dead-bug"], group="b-sun-core"),
        P("b-sun-4c", "side-plank", 6, 3, 30, 30, 45, "timed", None, unit="sec", prog=TIME(5),
          subs=["plank"], group="b-sun-core", uni=True, per_side=True),
    ]),
    S("cooldown", "Stretch", drills=[
        drill("couch-stretch", 1, "45 s / side"),
        drill("ninety-ninety-hip-switch", 2, "10 / side"),
        drill("standing-hamstring-stretch", 3, "45 s / side"),
        drill("thoracic-rotation", 4, "10 / side"),
    ]),
])

BUILD_DAYS = [b_mon, b_tue, b_wed, b_thu, b_fri, b_sat, b_sun]

# ============================================================================
# TEST — week 12
# ============================================================================
TEST_NOTE = ("Work up in singles and doubles to one hard set of 5. HARD means the last rep grinds "
             "but the bar still moves and the shape holds. NOT a failed rep, NOT a maximal single "
             "— you train alone. The number below is the target; beat it if it is there.")

t_mon = D("t-mon", "mon", "Test · Squat", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "3 min"),
        drill("leg-swing", 2, "x 10 / side"),
        drill("bodyweight-squat", 3, "x 15"),
        drill("glute-bridge", 4, "x 15"),
    ]),
    S("main", "Test", prescriptions=[
        P("t-mon-1", "barbell-back-squat", 1, 1, 5, 5, 300, "barbell", 36.0, rir=0, ramp=True,
          prog=NONE, note=TEST_NOTE),
        P("t-mon-2a", "bulgarian-split-squat", 2, 2, 10, 10, 0, "dumbbellPair", 6.0, rir=3,
          prog=NONE, subs=["step-up", "reverse-lunge"], group="t-mon-ss1", uni=True, per_side=True, note="Light. Just moving."),
        P("t-mon-2b", "single-leg-calf-raise", 3, 2, 15, 15, 60, "bodyweight", None, rir=3,
          prog=NONE, group="t-mon-ss1", uni=True, per_side=True),
    ]),
], note="Test week. Nothing to prove except what twelve weeks bought you.",
   warnings=[WARN_PINS_SQ, WARN_COLLAR])

t_tue = D("t-tue", "tue", "Test · Bench & Row", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "3 min"),
        drill("band-pull-apart", 2, "2 x 20"),
        drill("wall-slide", 3, "x 10"),
        drill("push-up-handles", 4, "x 10"),
    ]),
    S("main", "Test", prescriptions=[
        P("t-tue-1", "barbell-bench-press", 1, 1, 5, 5, 300, "barbell", 26.0, rir=0, ramp=True,
          prog=NONE, note=TEST_NOTE),
        P("t-tue-2", "barbell-bent-over-row", 2, 1, 5, 5, 240, "barbell", 31.0, rir=0,
          prog=NONE, note=TEST_NOTE),
        P("t-tue-3a", "incline-dumbbell-press", 3, 2, 12, 12, 0, "dumbbellPair", 7.0, rir=3,
          prog=NONE, group="t-tue-ss1"),
        P("t-tue-3b", "cable-face-pull", 4, 2, 15, 15, 60, "cable", None, rir=3,
          prog=NONE, group="t-tue-ss1"),
    ]),
], warnings=[WARN_PINS_BN, WARN_COLLAR])

t_wed = D("t-wed", "wed", "Rest", "rest", [], note="Rest. Thursday is the heavy one.")

t_thu = D("t-thu", "thu", "Test · Deadlift", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "3 min"),
        drill("cat-cow", 2, "x 10"),
        drill("glute-bridge", 3, "x 20"),
        drill("bodyweight-good-morning", 4, "x 15"),
    ]),
    S("main", "Test", prescriptions=[
        P("t-thu-1", "barbell-deadlift", 1, 1, 5, 5, 300, "barbell", 69.0, rir=0, ramp=True,
          prog=NONE, note=TEST_NOTE + " Then stop. Nothing else today."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("standing-hamstring-stretch", 1, "45 s / side"),
        drill("cat-cow", 2, "x 10"),
    ]),
], note="One lift, then go home and eat.", warnings=[WARN_BAR_HT, WARN_COLLAR])

t_fri = D("t-fri", "fri", "Test · Press & Pull-ups", "lift", [
    S("warmup", "Warm-up", drills=[
        drill("rope-skipping", 1, "3 min"),
        drill("band-pull-apart", 2, "2 x 20"),
        drill("wall-slide", 3, "x 10"),
        drill("dead-hang", 4, "2 x 20 s"),
    ]),
    S("main", "Test", prescriptions=[
        P("t-fri-1", "barbell-overhead-press", 1, 1, 5, 5, 300, "barbell", 19.0, rir=0, ramp=True,
          prog=NONE, note=TEST_NOTE),
        P("t-fri-2", "pull-up", 2, 1, 1, 12, 240, "bodyweight", None, rir=0, prog=NONE,
          subs=["pull-up-assisted"],
          note="MAX STRICT REPS. No kipping, no half reps — chin over the bar, full hang at the "
               "bottom. This is the number you will remember."),
        P("t-fri-3a", "hammer-curl", 3, 2, 12, 12, 0, "dumbbellPair", 5.0, rir=3, prog=NONE,
          group="t-fri-ss1"),
        P("t-fri-3b", "cable-triceps-pushdown", 4, 2, 15, 15, 60, "cable", None, rir=3,
          prog=NONE, group="t-fri-ss1"),
    ]),
], note="Last lifting session of the cycle. Take the week-12 photos afterwards, while you are "
        "still pumped — same four poses, same spot, same light.",
   warnings=[WARN_CEIL, WARN_COLLAR])

t_sat = D("t-sat", "sat", "Rest", "rest", [], note="Rest before the time trial.")

t_sun = D("t-sun", "sun", "Test · 5K Time Trial", "cardio", [
    S("cardio", "Test", prescriptions=[
        P("t-sun-1", "five-k-time-trial", 1, 1, 5000, 5000, 0, "distance", None, unit="m",
          prog=NONE, subs=["easy-run"],
          note="Flat measured route. Even pacing beats a fast first kilometre. Target 28-32 min. "
               "Then you are done — twelve weeks, logged."),
    ]),
    S("cooldown", "Cool-down", drills=[
        drill("standing-hamstring-stretch", 1, "45 s / side"),
        drill("couch-stretch", 2, "45 s / side"),
    ]),
])

TEST_DAYS = [t_mon, t_tue, t_wed, t_thu, t_fri, t_sat, t_sun]

# ============================================================================
# Assemble
# ============================================================================
for d in FOUNDATION_DAYS + BUILD_DAYS + TEST_DAYS:
    day_minutes(d)

PROGRAMME = {
    "id": "keller-twelve",
    "name": "The Keller Twelve",
    "schemaVersion": 2,
    "revision": 1,
    "startDate": "2026-09-28",
    "totalWeeks": 12,
    "notes": ("Beginner hypertrophy block for a 167 cm / 50 kg lifter training alone five evenings "
              "a week in a basement gym, on a 60-minute session ceiling. Every load in this file "
              "is snapped to the plate lattice described in inventory.json -- change the inventory "
              "and regenerate with tools/gen.py rather than editing loads by hand. Cardio is "
              "deliberately capped so it does not eat the caloric surplus."),
    "athlete": {"startWeightKg": 50.0, "heightCm": 167, "targetWeightKg": 55.0,
                "ageYears": 22, "sex": "male", "experience": "beginner", "trainsAlone": True},
    "nutritionPhases": [
        {"weeks": [1, 2, 3, 4], "kcal": 2600, "proteinG": 110, "carbsG": 382, "fatG": 70,
         "note": "Start here. ~52 kcal/kg -- two liquid meals a day make this easy."},
        {"weeks": [5, 6, 7, 8], "kcal": 2750, "proteinG": 115, "carbsG": 410, "fatG": 72,
         "note": "TDEE has risen with your bodyweight. So does the target."},
        {"weeks": [9, 10, 11, 12], "kcal": 2900, "proteinG": 120, "carbsG": 440, "fatG": 75,
         "note": "Final push. If the waist is growing faster than the lifts, cut 200."},
    ],
    "nutritionRules": {
        "gainKgPerWeek": 0.3, "flatWeeksBeforeBump": 2, "kcalBumpWhenFlat": 250,
        "useRollingAverage": True, "rollingAverageDays": 7,
        "waistGrowthLimitCm": 3.0, "kcalCutWhenWaistGrows": 200,
    },
    "onComplete": {"action": "seedNextCycle", "skipBlocks": ["foundation"],
                   "seedFrom": "test", "bodyweightTargetKg": 60.0},
    "rules": [
        "Eat in surplus every single day. A missed meal is a missed session.",
        "Leave 2 reps in the tank -- 3 to 4 during weeks 1 to 4.",
        "Collars on. Check them mid-set. Spinlock collars work loose under load.",
        "Never fail alone under a bar. Set the catch pins, or press dumbbells.",
        "Add weight only when you earn it: top of the rep range on every set.",
        "Log every set. A session you didn't log is a session you can't beat next week.",
        "Sixty minutes means sixty minutes. If you are over, cut the last superset -- not the "
        "main lift, not the warm-up.",
        "If something hurts -- not burns, HURTS -- stop the set, log the niggle, use the substitute.",
    ],
    "cardioProgression": [
        {"weeks": [1, 2], "longRunMin": [15, 18], "secondRunMin": [12, 15],
         "skipping": "Warm-up 6 x 45 s", "bag": None,
         "note": "Calves and Achilles need four weeks to adapt. Don't rush this."},
        {"weeks": [3, 4], "longRunMin": [20, 22], "secondRunMin": [15, 18],
         "skipping": "Warm-up 6 x 60 s", "bag": "Sun 2 x 2 min",
         "note": "The bag appears. Wraps or gloves, always."},
        {"weeks": [5, 6], "longRunMin": [24, 26], "secondRunMin": [20, 20],
         "skipping": "Warm-up 3 min - Sun 8 x 30 s fast", "bag": "Sun 3 x 2 min",
         "note": "Second run becomes the optional Wednesday. Skip it if you are behind on food."},
        {"weeks": [7], "longRunMin": [28, 28], "secondRunMin": [20, 20],
         "skipping": "Warm-up 3 min - Sun 8 x 30 s fast", "bag": "Sun 3 x 2 min",
         "note": "Highest cardio week before the deload."},
        {"weeks": [8], "longRunMin": [15, 15], "secondRunMin": None,
         "skipping": "5 x 60 s", "bag": None,
         "note": "Deload. Everything comes down, including this."},
        {"weeks": [9, 10], "longRunMin": [30, 33], "secondRunMin": [20, 25],
         "skipping": "Warm-up 3 min - Sun 10 x 30 s fast", "bag": "Sun 3 x 2 min",
         "note": "Runs get longer, never faster."},
        {"weeks": [11], "longRunMin": [35, 35], "secondRunMin": [25, 25],
         "skipping": "Warm-up 3 min - Sun 10 x 30 s fast", "bag": "Sun 3 x 3 min",
         "note": "Last easy long run."},
        {"weeks": [12], "longRunMin": None, "secondRunMin": None,
         "skipping": "5 x 60 s", "bag": None,
         "note": "5K time trial replaces the Sunday run. Target 28-32 min."},
    ],
    "checkpoints": [
        {"week": 1, "expectedWeightKg": [50.0, 50.5], "items": [
            "Baseline photos -- all four poses, normal camera app",
            "All five measurements: waist, chest, upper arm, thigh, neck",
            "WEIGH both bars and both dumbbell handles, then update inventory.json",
            "Count every plate and weigh one of each size",
            "Measure ceiling clearance for overhead press and for skipping",
            "First bodyweight entry"]},
        {"week": 4, "expectedWeightKg": [51.0, 52.0], "items": [
            "Photos", "Measurements",
            "Squat and bench moving with real plates on",
            "Every session logged -- check for holes before Build starts"]},
        {"week": 8, "expectedWeightKg": [53.0, 54.0], "items": [
            "Photos", "Measurements",
            "DELOAD WEEK -- do it properly, you will want to skip it",
            "Waist vs the 3 cm rule -- if it is growing faster than the lifts, cut 200 kcal",
            "Clothes should fit differently across the shoulders"]},
        {"week": 12, "expectedWeightKg": [55.0, 56.5], "items": [
            "Photos", "Measurements",
            "5-rep tests: squat, bench, row, deadlift, overhead press",
            "Max strict pull-ups", "5K time trial",
            "Seed cycle 2 from the test numbers"]},
    ],
    "strengthTargets": [
        {"exerciseId": "barbell-back-squat", "week4Kg": [18, 18], "week12Kg": [36, 36], "reps": 5,
         "isFloor": True, "note": "e1RM ~42 kg, 0.76x bodyweight. A FLOOR, not a goal."},
        {"exerciseId": "barbell-deadlift", "week4Kg": [39, 39], "week12Kg": [69, 69], "reps": 5,
         "isFloor": True, "note": "e1RM ~80 kg, 1.46x bodyweight."},
        {"exerciseId": "barbell-bench-press", "week4Kg": [15, 15], "week12Kg": [26, 26], "reps": 5,
         "isFloor": True, "note": "e1RM ~31 kg."},
        {"exerciseId": "barbell-overhead-press", "week4Kg": [13, 13], "week12Kg": [19, 19], "reps": 5,
         "isFloor": True, "note": "e1RM ~23 kg. The slowest-moving lift you own -- that is normal."},
        {"exerciseId": "barbell-bent-over-row", "week4Kg": [18, 18], "week12Kg": [31, 31], "reps": 5,
         "isFloor": True, "note": "e1RM ~39 kg."},
        {"exerciseId": "barbell-romanian-deadlift", "week4Kg": [27, 27], "week12Kg": [42, 42], "reps": 8,
         "isFloor": True, "note": None},
        {"exerciseId": "pull-up", "week4Kg": None, "week12Kg": None, "reps": 3,
         "isFloor": True, "note": "3 to 6 strict reps by week 12. The most satisfying number here."},
    ],
    "blocks": [
        {"id": "foundation", "name": "Foundation", "weeks": [1, 2, 3, 4], "blockKind": "intro",
         "defaultRir": 4, "loadMultiplier": 1.0, "setMultiplier": 1.0, "setRounding": "up",
         "includeSupersets": True, "includeFinishers": True,
         "summary": "Full body three times a week. Light loads, perfect reps, every barbell lift "
                    "introduced with the empty bar. Build the eating habit here.",
         "inheritsDaysFrom": None, "dayOverrides": {}, "days": FOUNDATION_DAYS},

        {"id": "build", "name": "Build", "weeks": [5, 6, 7], "blockKind": "accumulation",
         "defaultRir": 2, "loadMultiplier": 1.0, "setMultiplier": 1.0, "setRounding": "up",
         "includeSupersets": True, "includeFinishers": True,
         "summary": "Upper/Lower across four days. Every movement pattern gets two exposures a "
                    "week, every upper day presses and pulls, and the accessories are supersetted "
                    "so it all fits in 60 minutes.",
         "inheritsDaysFrom": None, "dayOverrides": {}, "days": BUILD_DAYS},

        {"id": "deload", "name": "Deload", "weeks": [8], "blockKind": "deload",
         "defaultRir": 4, "loadMultiplier": 0.70, "setMultiplier": 0.60, "setRounding": "up",
         "includeSupersets": False, "includeFinishers": False,
         "summary": "Same four days, 70% of the load, 60% of the sets, supersets unwound so "
                    "nothing is rushed. Bar speed stays fast. You will want to skip this week -- "
                    "it is the week the previous three turn into muscle.",
         "inheritsDaysFrom": "build", "dayOverrides": {}, "days": []},

        {"id": "push", "name": "Push", "weeks": [9, 10, 11], "blockKind": "accumulation",
         "defaultRir": 2, "loadMultiplier": 1.0, "setMultiplier": 1.0, "setRounding": "up",
         "includeSupersets": True, "includeFinishers": True,
         "summary": "Same split, one set added to the lead lift of each day, 1 rep in reserve on "
                    "those sets. Nordic curl negatives become non-optional on Thursday.",
         "inheritsDaysFrom": "build",
         "dayOverrides": {
             "b-mon": {"prescriptionOverrides": {"b-mon-1": {"sets": 5, "targetRir": 1}}},
             "b-tue": {"prescriptionOverrides": {"b-tue-1": {"sets": 5, "targetRir": 1}}},
             "b-thu": {"prescriptionOverrides": {"b-thu-1": {"sets": 4, "targetRir": 1},
                                                 "b-thu-5": {"optional": False}}},
             "b-fri": {"prescriptionOverrides": {"b-fri-1": {"sets": 5, "targetRir": 1}}},
         },
         "days": []},

        {"id": "test", "name": "Test", "weeks": [12], "blockKind": "test",
         "defaultRir": 0, "loadMultiplier": 1.0, "setMultiplier": 1.0, "setRounding": "up",
         "includeSupersets": True, "includeFinishers": False,
         "summary": "Five-rep tests on the four barbell lifts, max strict pull-ups, and the 5K. "
                    "These five numbers seed cycle 2.",
         "inheritsDaysFrom": None, "dayOverrides": {}, "days": TEST_DAYS},
    ],
}

# ============================================================================
# Exercises — v1's 72, plus the ones v2 needs
# ============================================================================
with io.open(os.path.join(V1, "exercises.json"), encoding="utf-8") as fh:
    exdoc = json.load(fh)

NEW = [
    {"id": "cable-face-pull", "name": "Cable face pull", "aliases": ["face pull"],
     "pattern": "horizontalPull", "primaryMuscles": ["rearDelts", "upperBack"],
     "secondaryMuscles": ["biceps"], "equipment": ["cable"], "defaultLoadMode": "cable",
     "cues": ["Rope or handle at roughly forehead height.",
              "Pull towards your face with the elbows high and wide.",
              "Rotate the hands back at the end so the knuckles finish pointing behind you.",
              "Light weight, high reps. This is a health movement, not a strength one."],
     "commonErrors": ["Dropping the elbows, which turns it into a row.",
                      "Going heavy and leaning back to move it."],
     "soloSafety": "As safe as it gets. Nothing can fall on you.",
     "media": {"still": None, "stillLicence": None, "stillSearchTerm": "cable face pull",
               "youtubeUrl": None, "youtubeStartSec": 0},
     "substitutes": ["band-face-pull", "band-pull-apart"],
     "tags": ["accessory", "shoulderHealth"],
     "equipmentNote": "Uses the wall-mounted cable. No plate change, which is why it is a superset partner.",
     "progressionNote": "Progress by adding reps, then load. Never sacrifice the elbow position for weight."},

    {"id": "cable-triceps-pushdown", "name": "Cable triceps pushdown", "aliases": ["pushdown"],
     "pattern": "extension", "primaryMuscles": ["triceps"], "secondaryMuscles": [],
     "equipment": ["cable"], "defaultLoadMode": "cable",
     "cues": ["Elbows pinned to the ribs and they stay there.",
              "Extend fully, squeeze for a beat at the bottom.",
              "Control the way up -- do not let the stack pull your arms back."],
     "commonErrors": ["Elbows drifting forward, turning it into a press.",
                      "Leaning over the handle to use bodyweight."],
     "soloSafety": "Safe. Nothing overhead, nothing to fail under.",
     "media": {"still": None, "stillLicence": None, "stillSearchTerm": "cable triceps pushdown",
               "youtubeUrl": None, "youtubeStartSec": 0},
     "substitutes": ["ez-bar-skullcrusher", "overhead-dumbbell-extension", "bench-dip"],
     "tags": ["accessory", "isolation"],
     "equipmentNote": "Uses the wall-mounted cable -- no plate change inside a superset.",
     "progressionNote": None},

    {"id": "wall-slide", "name": "Wall slide", "aliases": ["wall angel"],
     "pattern": "mobility", "primaryMuscles": ["shoulders"], "secondaryMuscles": ["upperBack"],
     "equipment": [], "defaultLoadMode": "bodyweight",
     "cues": ["Back against the wall, forearms flat against it.",
              "Slide the arms up while keeping the forearms and wrists in contact.",
              "Ribs stay down -- do not arch the lower back to get higher."],
     "commonErrors": ["Arching the lower back off the wall to fake the range."],
     "soloSafety": "A warm-up drill. No risk.",
     "media": {"still": None, "stillLicence": None, "stillSearchTerm": "wall slide shoulder",
               "youtubeUrl": None, "youtubeStartSec": 0},
     "substitutes": ["band-pull-apart", "broomstick-pass-through"],
     "tags": ["warmup", "mobility"],
     "equipmentNote": "A clear stretch of wall. Harder than it looks.",
     "progressionNote": "If the forearms leave the wall, that is your current range. Work there."},

    {"id": "step-up", "name": "Step-up", "aliases": [],
     "pattern": "lunge", "primaryMuscles": ["quads", "glutes"], "secondaryMuscles": ["hamstrings"],
     "equipment": ["stepPlatform", "dumbbell"], "defaultLoadMode": "dumbbellPair",
     "cues": ["Drive through the heel of the top foot.",
              "Do not push off the trailing foot -- that is cheating the rep.",
              "Lower under control; do not drop."],
     "commonErrors": ["Bouncing off the bottom leg.", "A step so high the hip has to hike."],
     "soloSafety": "Check the platform does not slide on the mats before you load it.",
     "media": {"still": None, "stillLicence": None, "stillSearchTerm": "dumbbell step up",
               "youtubeUrl": None, "youtubeStartSec": 0},
     "substitutes": ["bulgarian-split-squat", "reverse-lunge", "split-squat"],
     "tags": ["accessory", "unilateral"],
     "equipmentNote": "Uses the black step platform.",
     "progressionNote": "Raise the step before you raise the weight."},
]

byid = {e["id"]: e for e in exdoc["exercises"]}
for e in NEW:
    byid[e["id"]] = e
# normalise: make sure every exercise carries the optional v2 fields
for e in byid.values():
    e.setdefault("equipmentNote", None)
    e.setdefault("progressionNote", None)
    e["media"].setdefault("stillLicence", None)

EXERCISES = {
    "schemaVersion": 2, "revision": 2,
    "notes": ("Exercise library for The Keller Twelve. 72 definitions carried from v1 plus four "
              "added for v2 (the wall cable and the step platform). media.still and "
              "media.youtubeUrl ship as null on purpose -- Phase 7 fills them. stillSearchTerm is "
              "a matching hint for free-exercise-db, NOT a verified slug."),
    "exercises": sorted(byid.values(), key=lambda e: e["id"]),
}

# ============================================================================
# Write
# ============================================================================
def dump(obj, name):
    path = os.path.join(OUT, name)
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(obj, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    return path, os.path.getsize(path)


for obj, name in [(PROGRAMME, "keller-twelve.json"),
                  (EXERCISES, "exercises.json"),
                  (INVENTORY, "inventory.json")]:
    p, n = dump(obj, name)
    print(f"wrote {name:24s} {n:>8,} bytes")

print("\nlattice steps:")
for m in DIV:
    print(f"  {m:16s} base {BASE[m]:>5.2f}  step {LAT[m][1]-LAT[m][0]:.2f}  "
          f"first: {[f'{x:g}' for x in LAT[m][:6]]}")
