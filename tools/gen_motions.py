#!/usr/bin/env python3
"""tools/gen_motions.py -- the exercise demos, as data.

Writes data/motions.json and mirrors it to app/assets/exercises/motions.json.

Every demo is ORIGINAL WORK: a figure with Saad's proportions (167 cm), posed
from keyframes this file computes. No GIF, no video frame, no traced photo.

The poses are solved, not typed, the same way the loads are:

  * a planted foot is one world point for the whole clip, so it cannot skate;
  * a squat keeps the bar over mid-foot (the trunk angle is SOLVED for it);
  * a deadlift keeps the bar on a vertical line, touching the shins, with
    straight arms (the hips are solved from shoulder and knee);
  * a limb that swings out of the picture is drawn shorter, both bones
    alike, instead of being stretched or bent to fake it.

The app's rig (app/lib/domain/motion/) does the inverse kinematics between
keyframes; app/test/domain/motion_library_test.dart checks every frame of
every clip against it (no stretched bone, no hand missing its bar, nothing
through the floor).

    python tools/gen_motions.py && python tools/validate.py
"""

import io
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "motions.json")
MIRROR = os.path.join(ROOT, "app", "assets", "exercises", "motions.json")
EXERCISES = os.path.join(ROOT, "data", "exercises.json")

PROVENANCE = "original work"

# ============================================================================
# The body: Saad, 167 cm, slim. Centimetres, y up, floor at y = 0.
# ============================================================================
STATURE = 167.0
TRUNK = 50.0      # hip joint to shoulder joint
NECK = 8.0        # shoulder line to the bottom of the head
HEAD_R = 10.5
UA, FA = 30.0, 31.0   # upper arm; elbow to the middle of the grip
TH, SH = 40.0, 41.0   # thigh; knee to ankle joint
ARM, LEG = UA + FA, TH + SH
SHOULDER_HALF, HIP_HALF = 15.0, 9.0
DEPTH = (-3.0, 1.5)   # the far side of a side view, drawn behind
ANKLE_Y = 6.5         # ankle joint above the sole
STAND_Y = 87.4        # pelvis height standing, knees soft
MIDFOOT = 6.5         # ankle at x = 0, heel -6, toe +19

assert abs(ANKLE_Y + LEG + TRUNK + NECK + 2 * HEAD_R - STATURE) < 0.6

SKELETON = {
    "statureCm": STATURE,
    "trunk": TRUNK, "neck": NECK, "headR": HEAD_R,
    "upperArm": UA, "forearm": FA, "thigh": TH, "shin": SH,
    "shoulderHalf": SHOULDER_HALF, "hipHalf": HIP_HALF,
    "depth": list(DEPTH),
    "foot": {"heel": [-6.0, -ANKLE_Y], "toe": [19.0, -ANKLE_Y]},
    "footFront": {"heel": [-2.5, -ANKLE_Y], "toe": [5.5, -ANKLE_Y]},
    # Half-widths along each segment, root to end. A 50 kg frame: slim.
    "girth": {
        "upperArm": [5.0, 4.2, 3.5],
        "forearm": [3.7, 3.3, 2.5],
        "hand": [3.1],
        "thigh": [7.8, 6.6, 5.2],
        "shin": [4.9, 5.2, 4.2, 3.0],
        "foot": [3.1, 2.2],
        "neck": [4.7],
        # side view: pelvis, low back, waist, chest, shoulder line
        "trunkSide": [10.8, 9.4, 9.0, 11.2, 9.2],
        # front view: hips, waist, chest, shoulders (half-widths)
        "trunkFront": [14.5, 12.5, 16.0, 18.0],
    },
}

# Where each muscle named in exercises.json is drawn. Checked both ways:
# validate.py refuses an unknown region, the app test refuses a muscle that
# maps to nothing.
MUSCLES = {
    "abs": ["abs"],
    "adductors": ["adductors"],
    "ankleStabilisers": ["calves"],
    "back": ["upperBack", "lats", "lowerBack"],
    "biceps": ["biceps"],
    "brachialis": ["biceps"],
    "calves": ["calves"],
    "chest": ["chest"],
    "upperChest": ["chest"],
    "forearms": ["forearms"],
    "grip": ["forearms"],
    "frontDelts": ["frontDelt"],
    "sideDelts": ["sideDelt"],
    "rearDelts": ["rearDelt"],
    "shoulders": ["frontDelt", "sideDelt", "rearDelt"],
    "rotatorCuff": ["rearDelt"],
    "glutes": ["glutes"],
    "hamstrings": ["hamstrings"],
    "heart": ["heart"],
    "hipFlexors": ["hipFlexors"],
    "hips": ["glutes", "hipFlexors", "adductors"],
    "lats": ["lats"],
    "legs": ["quads", "hamstrings", "calves", "glutes"],
    "obliques": ["obliques"],
    "quads": ["quads"],
    "spinalErectors": ["lowerBack"],
    "spine": ["lowerBack", "upperBack"],
    "thoracicSpine": ["upperBack"],
    "traps": ["traps"],
    "triceps": ["triceps"],
    "upperBack": ["upperBack"],
}
REGIONS = {
    "chest", "frontDelt", "sideDelt", "rearDelt", "traps", "upperBack",
    "lats", "lowerBack", "abs", "obliques", "glutes", "hipFlexors",
    "adductors", "quads", "hamstrings", "calves", "biceps", "triceps",
    "forearms", "heart",
}

# ============================================================================
# Vector helpers, and a mirror of the app's rig for the side view.
# ============================================================================


def pol(deg, r=1.0):
    a = math.radians(deg)
    return (math.cos(a) * r, math.sin(a) * r)


def add(*vs):
    return (sum(v[0] for v in vs), sum(v[1] for v in vs))


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def mul(a, k):
    return (a[0] * k, a[1] * k)


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def lerp(a, b, t):
    return a + (b - a) * t


def vlerp(a, b, t):
    return (lerp(a[0], b[0], t), lerp(a[1], b[1], t))


def cw(v):
    """A quarter turn clockwise: out of the chest, for a spine direction."""
    return (v[1], -v[0])


def ang(v):
    return math.degrees(math.atan2(v[1], v[0]))


def inout(u):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, u)))


def smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def neck_of(pelvis, trunk, spine=0.0):
    lower = pol(trunk + spine / 2)
    upper = pol(trunk - spine / 2)
    mid = add(pelvis, mul(lower, TRUNK / 2))
    return add(mid, mul(upper, TRUNK / 2))


def body_pt(pelvis, trunk, u, v):
    """A point riding on the trunk, as the app's BodyTarget places it."""
    d = pol(trunk)
    return add(pelvis, mul(d, u), mul(cw(d), v))


def bisect(f, lo, hi, iters=80):
    flo = f(lo)
    if flo * f(hi) > 0:
        raise ValueError(f"no root in [{lo}, {hi}]: {flo} / {f(hi)}")
    for _ in range(iters):
        mid = (lo + hi) / 2
        fm = f(mid)
        if flo * fm <= 0:
            hi = mid
        else:
            lo, flo = mid, fm
    return (lo + hi) / 2


def circle_meet(c1, r1, c2, r2, prefer):
    """Where a circle round c1 meets one round c2; [prefer] picks one."""
    d = dist(c1, c2)
    if d >= r1 + r2:
        return add(c1, mul(sub(c2, c1), r1 / d))
    a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, r1 * r1 - a * a))
    u = mul(sub(c2, c1), 1 / d)
    p = add(c1, mul(u, a))
    n = (-u[1], u[0])
    return prefer([add(p, mul(n, h)), add(p, mul(n, -h))])


def solve_trunk(pelvis, u, v, x, lo=5.0, hi=100.0):
    """The trunk angle that puts body point (u, v) at world x."""
    return bisect(lambda a: body_pt(pelvis, a, u, v)[0] - x, lo, hi)


def knee_hip(ankle, shin_deg, thigh_deg):
    """Up the leg from a planted ankle: shin direction, then thigh."""
    knee = add(ankle, pol(shin_deg, SH))
    return knee, add(knee, pol(thigh_deg, TH))


def sole_clear(ankle, angle, shape=((-6.0, -ANKLE_Y), (19.0, -ANKLE_Y))):
    """The ankle, lifted just enough that heel and toe stay on or above the
    floor at this foot angle."""
    a = math.radians(angle)
    low = min(px * math.sin(a) + py * math.cos(a) for px, py in shape)
    need = -low
    return (ankle[0], max(ankle[1], need))


def foot_on_toe(toe, angle):
    """The ankle for a foot at [angle] whose toe rests at [toe]."""
    a = math.radians(angle)
    x, y = 19.0, -ANKLE_Y
    rt = (x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a))
    return sub(toe, rt)


# ============================================================================
# Keyframe vocabulary (mirrors app/lib/domain/motion/clip.dart)
# ============================================================================


def r2(x):
    return round(float(x), 2)


def _s(s):
    if isinstance(s, (tuple, list)):
        return [r2(s[0]), r2(s[1])]
    return r2(s)


def at(p, foot=None, s=None):
    d = {"at": [r2(p[0]), r2(p[1])]}
    if foot is not None:
        d["foot"] = r2(foot)
    if s is not None:
        d["s"] = _s(s)
    return d


def body(u, v, s=None):
    d = {"body": [r2(u), r2(v)]}
    if s is not None:
        d["s"] = _s(s)
    return d


def fk(a, b, s=None):
    d = {"fk": [r2(a), r2(b)]}
    if s is not None:
        d["s"] = _s(s)
    return d


def fkb(a, b, s=None):
    d = {"fkb": [r2(a), r2(b)]}
    if s is not None:
        d["s"] = _s(s)
    return d


def P(pelvis, trunk, arm, leg, armR=None, legR=None, spine=0.0, head=0.0):
    """One pose. The R limbs default to the L ones: side-on, the far side
    is then drawn one depth step behind, which is what symmetry looks like."""
    return {
        "pelvis": [r2(pelvis[0]), r2(pelvis[1])],
        "trunk": r2(trunk),
        "spine": r2(spine),
        "head": r2(head),
        "armL": arm,
        "armR": armR if armR is not None else arm,
        "legL": leg,
        "legR": legR if legR is not None else leg,
    }


def prop(kind, pts, layer=None, **params):
    d = {"type": kind, "pts": [p if isinstance(p, (str, dict)) else
                               [r2(p[0]), r2(p[1])] for p in pts]}
    if layer:
        d["layer"] = layer
    for k, v in params.items():
        d[k] = r2(v)
    return d


def trunk_ref(u, v):
    return {"body": [r2(u), r2(v)]}


SIDE_BEND = {"armL": -1, "armR": -1, "legL": 1, "legR": 1}

CLIPS = []


class Clip:
    def __init__(self, cid, name, view="side", period=3000, travel=0.0,
                 still=0.5, bend=None, props=(), scale=None, behind=None):
        self.id = cid
        self.name = name
        self.view = view
        self.period = period
        self.travel = travel
        self.still = still
        self.bend = dict(bend or SIDE_BEND)
        self.props = list(props)
        self.scale = scale
        self.behind = list(behind or [])
        self.frames = []
        CLIPS.append(self)

    def key(self, t, pose, ease=None):
        t = round(t, 4)
        if self.frames and t <= self.frames[-1]["t"]:
            raise ValueError(f"{self.id}: keyframe at {t} after "
                             f"{self.frames[-1]['t']}")
        f = {"t": t}
        if ease:
            f["ease"] = ease
        f.update(pose)
        shape = (((-6.0, -ANKLE_Y), (19.0, -ANKLE_Y)) if self.view == "side"
                 else ((-2.5, -ANKLE_Y), (5.5, -ANKLE_Y)))
        for leg in ("legL", "legR"):
            tgt = f[leg]
            if "at" in tgt:
                lifted = sole_clear(tgt["at"], tgt.get("foot", 0.0), shape)
                tgt = dict(tgt)
                tgt["at"] = [r2(lifted[0]), r2(lifted[1] + 0.05 if lifted[1] > tgt["at"][1] else lifted[1])]
                f[leg] = tgt
        self.frames.append(f)

    def rep(self, fn, down=(0.10, 0.45), up=(0.55, 0.90), steps=5):
        """One rep: hold, lower, hold, rise, hold. fn(0) is the start, fn(1)
        the far end. In-between keyframes follow an eased depth at even
        times, joined linearly, so the rep moves like a body and not like a
        slideshow."""
        self.key(0.0, fn(0.0), "linear")
        t0, t1 = down
        for i in range(steps + 1):
            t = t0 + (t1 - t0) * i / steps
            if t <= 0:
                continue
            self.key(t, fn(inout(i / steps)), "linear")
        t2, t3 = up
        for i in range(steps + 1):
            t = t2 + (t3 - t2) * i / steps
            if i == 0 and t <= t1:
                continue
            self.key(t, fn(1 - inout(i / steps)), "linear")

    def loop(self, fn, n=12):
        """A cycle sampled evenly: fn(phase) for phase in [0, 1)."""
        for i in range(n):
            self.key(i / n, fn(i / n), "linear")

    def json(self):
        d = {
            "id": self.id,
            "name": self.name,
            "view": self.view,
            "periodMs": int(self.period),
            "travel": r2(self.travel),
            "still": r2(self.still),
            "provenance": PROVENANCE,
            "bend": self.bend,
        }
        if self.scale:
            d["scale"] = {k: r2(v) for k, v in self.scale.items()}
        if self.behind:
            d["behind"] = self.behind
        d["props"] = self.props
        d["keyframes"] = self.frames
        return d


FOOT = at((0, ANKLE_Y))
HANG = fk(-91, -88)
FLOOR_MAT = prop("mat", [(-95, 0), (95, 0)])

# ============================================================================
# SQUATS -- the bar (or the load) stays over mid-foot
# ============================================================================


def squat_hip(d, shin=(86.0, 55.0), thigh=(93.0, 186.0)):
    return knee_hip((0, ANKLE_Y), lerp(*shin, d), lerp(*thigh, d))[1]


BACK_BAR = (46.0, -8.5)      # on the upper traps, behind the spine line


def squat_back(d):
    hip = squat_hip(d)
    a = solve_trunk(hip, *BACK_BAR, MIDFOOT)
    return P(hip, a, body(*BACK_BAR), FOOT, head=lerp(0, 12, d))


bar_top = body_pt(squat_hip(0), solve_trunk(squat_hip(0), *BACK_BAR, MIDFOOT),
                  *BACK_BAR)
bar_low = body_pt(squat_hip(1), solve_trunk(squat_hip(1), *BACK_BAR, MIDFOOT),
                  *BACK_BAR)

c = Clip("squat_back", "Barbell back squat", period=3600,
         bend={"armL": 1, "armR": 1, "legL": 1, "legR": 1},
         scale={"armL": 0.72, "armR": 0.72},
         props=[
             prop("rack", [(MIDFOOT, 0), (MIDFOOT, 175)],
                  hook=bar_top[1] - 3, safety=bar_low[1] - 8),
             prop("barbell", [trunk_ref(*BACK_BAR)], "near", r=17),
         ])
c.rep(squat_back)

FRONT_BAR = (48.0, 9.5)


def squat_front(d):
    hip = squat_hip(d, shin=(86.0, 50.0), thigh=(93.0, 188.0))
    a = solve_trunk(hip, *FRONT_BAR, MIDFOOT)
    return P(hip, a, body(*FRONT_BAR, s=(0.75, 0.45)), FOOT,
             head=lerp(0, 6, d))


fbar_top = body_pt(squat_hip(0), solve_trunk(squat_hip(0), *FRONT_BAR, MIDFOOT),
                   *FRONT_BAR)
c = Clip("squat_front", "Barbell front squat", period=3600,
         bend={"armL": 1, "armR": 1, "legL": 1, "legR": 1},
         props=[
             prop("rack", [(MIDFOOT, 0), (MIDFOOT, 175)],
                  hook=fbar_top[1] - 3),
             prop("barbell", [trunk_ref(*FRONT_BAR)], "near", r=17),
         ])
c.rep(squat_front)

GOBLET = (52.0, 15.0)


def squat_goblet(d):
    hip = squat_hip(d, shin=(86.0, 52.0), thigh=(93.0, 186.0))
    a = solve_trunk(hip, GOBLET[0], GOBLET[1] - 4, MIDFOOT + 4)
    return P(hip, a, body(*GOBLET), FOOT)


c = Clip("squat_goblet", "Goblet squat", period=3400,
         scale={"armL": 0.84, "armR": 0.84},
         props=[prop("kettlebell", ["hands"], "near", r=8)])
c.rep(squat_goblet)


def squat_db(d):
    hip = squat_hip(d, shin=(86.0, 58.0), thigh=(93.0, 178.0))
    a = solve_trunk(hip, 50, 0, MIDFOOT + 1)
    return P(hip, a, fk(-90, -89), FOOT)


c = Clip("squat_db", "Dumbbell squat", period=3400,
         props=[prop("dumbbell", ["handR"], "far", r=7.5),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(squat_db)


def squat_bw(d):
    hip = squat_hip(d)
    a = solve_trunk(hip, 40, 0, MIDFOOT - 2)
    return P(hip, a, fk(lerp(-82, 2, d), lerp(-80, 4, d)), FOOT)


c = Clip("squat_bw", "Bodyweight squat", period=2800)
c.rep(squat_bw, down=(0.08, 0.44), up=(0.50, 0.86))

# ============================================================================
# HINGES
# ============================================================================


def pick_back(cands):
    return min(cands, key=lambda p: p[0])


DL_R = 19.0          # 20 kg plates: the bar starts 19 cm off the floor
DL_X = 5.5           # the bar path, over mid-foot


def deadlift(p, bar_x=DL_X, r=DL_R):
    """p = 0 on the floor, 1 locked out."""
    top_y = STAND_Y + TRUNK - (ARM - 1.0)
    bar = (bar_x, lerp(r, top_y, smooth(p)))
    # Shins touch the bar at the start and come vertical as it passes the
    # knee; shoulders a little in front of the bar until lockout.
    shin = lerp(75.0, 90.0, smooth(min(1.0, p * 1.7)))
    knee = add((0, ANKLE_Y), pol(shin, SH))
    ahead = lerp(6.0, 0.0, p)
    shoulder = (bar_x + ahead, bar[1] + math.sqrt((ARM - 1.0) ** 2 - ahead ** 2))
    hip = circle_meet(shoulder, TRUNK, knee, TH, pick_back)
    trunk = ang(sub(shoulder, hip))
    return P(hip, trunk, at(bar), FOOT, head=lerp(18, 0, p)), bar


c = Clip("deadlift_bar", "Barbell deadlift", period=4000, still=0.0,
         props=[prop("barbell", ["hands"], "near", r=DL_R)])
c.rep(lambda d: deadlift(d)[0], down=(0.12, 0.44), up=(0.56, 0.90))


def deadlift_db(p):
    # Dumbbells beside the feet: the handles sit ~16 cm off the floor.
    top_y = STAND_Y + TRUNK - (ARM - 0.4)
    hand = (2.0, lerp(16.0, top_y, smooth(p)))
    shin = lerp(72.0, 89.0, smooth(min(1.0, p * 1.6)))
    knee = add((0, ANKLE_Y), pol(shin, SH))
    shoulder = (hand[0] + lerp(2.0, 0.0, p), hand[1] + math.sqrt((ARM - 0.4) ** 2 - lerp(2, 0, p) ** 2))
    hip = circle_meet(shoulder, TRUNK, knee, TH, pick_back)
    trunk = ang(sub(shoulder, hip))
    return P(hip, trunk, at(hand), FOOT, head=lerp(14, 0, p))


c = Clip("deadlift_db", "Dumbbell deadlift", period=3800, still=0.0,
         props=[prop("dumbbell", ["handR"], "far", r=7.5),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(deadlift_db, down=(0.12, 0.44), up=(0.56, 0.90))


def rdl(d, bar_x=5.0, knee_soft=(86.0, 80.0), hip_back=(94.0, 146.0)):
    """d = 0 standing tall, 1 at the bottom of the hinge. Soft knees, hips
    back, shoulders just ahead of the bar, straight arms."""
    knee = add((0, ANKLE_Y), pol(lerp(*knee_soft, d), SH))
    hip = add(knee, pol(lerp(*hip_back, d), TH))
    sx = bar_x + 2.0
    trunk = math.degrees(math.acos(max(-1, min(1, (sx - hip[0]) / TRUNK))))
    shoulder = add(hip, pol(trunk, TRUNK))
    bar = (bar_x, shoulder[1] - math.sqrt((ARM - 0.4) ** 2 - 4))
    return P(hip, trunk, at(bar), FOOT, head=lerp(0, 22, d)), bar


c = Clip("rdl_bar", "Barbell Romanian deadlift", period=4200,
         props=[prop("barbell", ["hands"], "near", r=17)])
c.rep(lambda d: rdl(d)[0], down=(0.10, 0.48), up=(0.56, 0.90))

c = Clip("rdl_db", "Dumbbell Romanian deadlift", period=4200,
         props=[prop("dumbbell", ["handR"], "far", r=7.5),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(lambda d: rdl(d, bar_x=3.0)[0], down=(0.10, 0.48), up=(0.56, 0.90))

# ============================================================================
# PRESSES
# ============================================================================

BENCH_TOP = 43.0


def bench_press(d, db=False):
    """Supine, head to the left (face up). d = 0 locked out, 1 on the chest."""
    pelvis = (0.0, BENCH_TOP + 10.0)
    trunk = 179.0
    spine = -8.0   # a small arch
    neck = neck_of(pelvis, trunk, spine)
    top = add(neck, (2.0, ARM * 0.88 - 1.0))
    chest = add(neck, (13.0 if not db else 10.0, 13.0 if not db else 12.0))
    hand = vlerp(top, chest, d)
    # Locked out, the arm is nearly in the picture; at the chest the upper
    # arm points out to the side (short on screen) and the forearm is
    # vertical under the bar.
    s = (lerp(0.9, 0.48, d), lerp(0.9, 0.86, d))
    return P(pelvis, trunk, at(hand, s=s), at((38, ANKLE_Y)), spine=spine,
             head=lerp(0, 4, d))


BENCH = prop("bench", [(-85, BENCH_TOP), (18, BENCH_TOP)])
neck_b = neck_of((0.0, BENCH_TOP + 10.0), 179.0, -8.0)

c = Clip("bench_press_bar", "Barbell bench press", period=3600,
         props=[
             prop("rack", [(neck_b[0] - 6, 0), (neck_b[0] - 6, 125)],
                  hook=neck_b[1] + ARM * 0.88 + 2, safety=neck_b[1] + 5),
             BENCH,
             prop("barbell", ["hands"], "near", r=17),
         ])
c.rep(bench_press, down=(0.10, 0.46), up=(0.52, 0.86))

c = Clip("bench_press_db", "Dumbbell bench press", period=3600,
         props=[BENCH,
                prop("dumbbell", ["handR"], "far", r=7.5),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(lambda d: bench_press(d, db=True), down=(0.10, 0.46), up=(0.52, 0.86))

# Standing overhead press, from the front: the bar path is vertical from the
# side, but the ARMS only make sense seen square-on.
FRONT_LEGS = {"armL": -1, "armR": 1, "legL": 1, "legR": -1}
FEET_FRONT = (at((11.0, ANKLE_Y)), at((-11.0, ANKLE_Y)))


def ohp_front(d, grip=22.0, rack_y=None):
    """d = 0 at the shoulders, 1 locked out overhead."""
    pelvis = (0.0, STAND_Y)
    shoulder_y = STAND_Y + TRUNK
    y = lerp(shoulder_y - 1.0 if rack_y is None else rack_y,
             shoulder_y + ARM - 1.5, d)
    s = lerp(0.8, 1.0, smooth(d))
    return P(pelvis, 90, at((grip, y), s=s), FEET_FRONT[0],
             armR=at((-grip, y), s=s), legR=FEET_FRONT[1])


c = Clip("ohp_bar", "Standing barbell overhead press", view="front",
         period=3400, bend=FRONT_LEGS,
         props=[prop("barbell", ["handL", "handR"], "near", r=17, len=24)])
c.rep(ohp_front, down=(0.10, 0.42), up=(0.54, 0.88))

c = Clip("ohp_db", "Standing dumbbell overhead press", view="front",
         period=3400, bend=FRONT_LEGS,
         props=[prop("dumbbell", ["handL"], "near", r=7.5),
                prop("dumbbell", ["handR"], "near", r=7.5)])
c.rep(lambda d: ohp_front(d, grip=24.0), down=(0.10, 0.42), up=(0.54, 0.88))

# ============================================================================
# PULLS
# ============================================================================

PULLUP_Y = 226.0
BACK_ARMS = {"armL": 1, "armR": -1, "legL": -1, "legR": 1}


def pull_up(d, grip=24.0):
    """From behind. d = 0 dead hang, 1 chin over the bar."""
    hands = PULLUP_Y - 3.0
    hang = hands - (ARM - 1.0) * 0.99
    top = PULLUP_Y - NECK - HEAD_R - 6.0
    shoulder_y = lerp(hang, top, d)
    pelvis = (0.0, shoulder_y - TRUNK)
    legs = fk(-92 + 6 * d, -96 + 20 * d)
    legsR = fk(-88 - 6 * d, -84 - 20 * d)
    return P(pelvis, 90, at((-grip, hands)), legs, armR=at((grip, hands)),
             legR=legsR)


PULLUP_BAR = prop("pullupBar", [(-60, PULLUP_Y), (60, PULLUP_Y)])
c = Clip("pull_up", "Pull-up", view="back", period=3200, bend=BACK_ARMS,
         props=[PULLUP_BAR])
c.rep(pull_up, down=(0.08, 0.40), up=(0.50, 0.90))

c = Clip("pull_up_negative", "Pull-up negative", view="back", period=5200,
         bend=BACK_ARMS, still=0.3, props=[PULLUP_BAR])
# Up is the easy part (a jump, or a step); the lowering is the exercise.
c.rep(pull_up, down=(0.04, 0.18), up=(0.26, 0.88))


def row_bar(d):
    """Hinged to ~40 degrees, bar from straight arms to the belly."""
    knee = add((0, ANKLE_Y), pol(84.0, SH))
    hip = add(knee, pol(125.0, TH))
    trunk = 40.0
    shoulder = add(hip, pol(trunk, TRUNK))
    hang = (shoulder[0] + 1.0, shoulder[1] - (ARM - 0.8))
    belly = body_pt(hip, trunk, 22.0, 13.0)
    return P(hip, trunk, at(vlerp(hang, belly, d)), FOOT, head=18)


c = Clip("row_barbell", "Barbell bent-over row", period=2800,
         props=[prop("barbell", ["hands"], "near", r=17)])
c.rep(row_bar, down=(0.10, 0.40), up=(0.50, 0.86))

# ============================================================================
# ARMS
# ============================================================================


def curl(d):
    fore = lerp(-88.0, 58.0, d)
    return P((0.5, STAND_Y), 90, fk(-93.0 + 6 * d, fore), FOOT)


c = Clip("curl_db", "Dumbbell curl", period=3000,
         props=[prop("dumbbell", ["handR"], "far", r=7),
                prop("dumbbell", ["handL"], "near", r=7)])
c.rep(curl, down=(0.08, 0.40), up=(0.48, 0.88))

# ============================================================================
# SHOULDERS, from the front
# ============================================================================


def lateral_raise(d):
    return P((0.0, STAND_Y), 90,
             fk(lerp(-84, -4, d), lerp(-80, 2, d)), FEET_FRONT[0],
             armR=fk(lerp(-96, -176, d), lerp(-100, -182, d)),
             legR=FEET_FRONT[1])


c = Clip("lateral_raise", "Lateral raise", view="front", period=3000,
         bend=FRONT_LEGS,
         props=[prop("dumbbell", ["handL"], "near", r=6.5),
                prop("dumbbell", ["handR"], "near", r=6.5)])
c.rep(lateral_raise, down=(0.10, 0.40), up=(0.50, 0.90))

# ============================================================================
# FLOOR
# ============================================================================

PRONE_FOOT_Y, PRONE_FOOT = 19.7, -60.0   # toes tucked, heel up


def plank(d):
    ankle = (0.0, PRONE_FOOT_Y)
    shoulder_y = 4.0 + UA
    theta = math.degrees(math.asin((shoulder_y - ankle[1] + 0.3 * d)
                                   / (LEG - 0.6 + TRUNK)))
    hip = add(ankle, pol(theta, LEG - 0.6))
    shoulder = add(hip, pol(theta, TRUNK))
    hand = (shoulder[0] + FA - 2, 4.0)
    return P(hip, theta, at(hand), at(ankle, foot=PRONE_FOOT))


c = Clip("plank", "Plank", period=4000, still=0.0,
         props=[prop("mat", [(-20, 0), (175, 0)])])
c.rep(plank, down=(0.0, 0.45), up=(0.5, 0.95), steps=3)


def push_up(d, grip_y=12.0, grip_x=None, low_off=5.0):
    ankle = (0.0, PRONE_FOOT_Y)
    full = LEG - 0.6 + TRUNK
    top_y = grip_y + ARM - 1.5
    low_y = grip_y + low_off
    y = lerp(top_y, low_y, d)
    theta = math.degrees(math.asin((y - ankle[1]) / full))
    hip = add(ankle, pol(theta, LEG - 0.6))
    top_theta = math.degrees(math.asin((top_y - ankle[1]) / full))
    hx = grip_x if grip_x is not None else full * math.cos(math.radians(top_theta)) - 3
    return P(hip, theta, at((hx, grip_y)), at(ankle, foot=PRONE_FOOT),
             head=lerp(0, -4, d)), hx


_, hx = push_up(0)
c = Clip("push_up_handles", "Push-up on handles", period=3000,
         props=[prop("handles", [(hx, 12.0)])])
c.rep(lambda d: push_up(d)[0], down=(0.08, 0.42), up=(0.50, 0.84))

# ============================================================================
# RUNNING -- a travelling cycle; the camera follows
# ============================================================================


def run_cycle(stride=180.0, stance=0.32, lift=34.0, knee=26.0, lean=84.0,
              bounce=2.2, arm=40.0):
    def foot_at(phase, land_x):
        """World ankle and foot angle for one leg, phase 0 = touchdown."""
        if phase < stance:
            roll = max(0.0, (phase - stance * 0.55) / (stance * 0.45))
            angle = lerp(0.0, -32.0, smooth(roll))
            toe = (land_x + 19.0, 0.0)
            if roll <= 0:
                return (land_x, ANKLE_Y), angle
            return foot_on_toe(toe, angle), angle
        # Swing: kick up behind, come through at knee height, reach, land.
        u = (phase - stance) / (1 - stance)
        start = foot_on_toe((land_x + 19.0, 0.0), -32.0)
        end = (land_x + stride, ANKLE_Y)
        x = lerp(start[0], end[0], smooth(u) ** 1.15)
        y = (ANKLE_Y + lift * math.sin(math.pi * min(1.0, u / 0.62)) if u < 0.62
             else ANKLE_Y + knee * math.sin(math.pi * 0.5 * (1 - (u - 0.62) / 0.38)))
        angle = lerp(-32.0, -70.0, smooth(u / 0.35)) if u < 0.35 else \
            lerp(-70.0, 0.0, smooth((u - 0.35) / 0.65))
        return (x, y), angle

    def pose(t):
        px = stride * t
        pa = t % 1.0
        pb = (t + 0.5) % 1.0
        # landings: leg A lands at t = 0 at x = 22 ahead of the pelvis
        la = 22.0 + stride * math.floor(t)
        lb = 22.0 + stride * (math.floor(t + 0.5) - 0.5)
        fa, aa = foot_at(pa, la)
        fb, ab = foot_at(pb, lb)
        py = STAND_Y - 3.0 + bounce * math.cos(4 * math.pi * (t - 0.16))
        swing = math.sin(2 * math.pi * t)
        armA = fk(-90 - arm * swing, -90 - arm * swing + 95)
        armB = fk(-90 + arm * swing, -90 + arm * swing + 95)
        # arms swing against the legs: the near arm goes back as the near
        # leg goes forward.
        return P((px, py), lean, armB, at(fa, foot=aa), armR=armA,
                 legR=at(fb, foot=ab), head=90 - lean)

    return pose


c = Clip("run_easy", "Easy run", period=820, travel=180.0, still=0.25)
c.loop(run_cycle(), n=16)

c = Clip("run_fast", "Running fast", period=660, travel=240.0, still=0.25)
c.loop(run_cycle(stride=240.0, stance=0.26, lift=48.0, knee=36.0, lean=80.0,
                 bounce=3.0, arm=52.0), n=16)

# ============================================================================
# Which exercise shows which clip
# ============================================================================

MAPPING = {
    "barbell-back-squat": "squat_back",
    "barbell-front-squat": "squat_front",
    "goblet-squat": "squat_goblet",
    "dumbbell-squat": "squat_db",
    "bodyweight-squat": "squat_bw",
    "barbell-deadlift": "deadlift_bar",
    "dumbbell-deadlift": "deadlift_db",
    "barbell-romanian-deadlift": "rdl_bar",
    "dumbbell-romanian-deadlift": "rdl_db",
    "barbell-bench-press": "bench_press_bar",
    "dumbbell-bench-press": "bench_press_db",
    "barbell-overhead-press": "ohp_bar",
    "dumbbell-overhead-press": "ohp_db",
    "pull-up": "pull_up",
    "pull-up-negative": "pull_up_negative",
    "barbell-bent-over-row": "row_barbell",
    "dumbbell-curl": "curl_db",
    "hammer-curl": "curl_db",
    "lateral-raise": "lateral_raise",
    "plank": "plank",
    "push-up-handles": "push_up_handles",
    "easy-run": "run_easy",
    "five-k-time-trial": "run_fast",
    "running-strides": "run_fast",
    "run-intervals": "run_fast",
}

# ============================================================================
# More vocabulary
# ============================================================================


def to_body(pelvis, trunk, pt):
    """World point -> (u, v) on the trunk, the inverse of body_pt."""
    d = pol(trunk)
    rel = sub(pt, pelvis)
    n = cw(d)
    return (rel[0] * d[0] + rel[1] * d[1], rel[0] * n[0] + rel[1] * n[1])


KNEEL_ANKLE = (-40.9, 5.5)     # shin flat on the mat behind a knee at (0, 5)
KNEEL_FOOT = 195.0             # top of the foot on the mat, sole up


def kneel_pelvis(thigh_deg, knee=(0.0, 5.0)):
    return add(knee, pol(thigh_deg, TH))


SIDE_BAR_TOP = 226.0
SIDE_BAR = prop("pullupBar", [(0, SIDE_BAR_TOP), (-40, SIDE_BAR_TOP + 14)])
WALL_AT = 58.0

# ============================================================================
# CORE, FLOOR
# ============================================================================


def ab_wheel(d):
    thigh = lerp(76.0, 28.0, d)
    pelvis = kneel_pelvis(thigh)
    trunk = lerp(31.0, 11.0, d)
    shoulder = add(pelvis, pol(trunk, TRUNK))
    reach = ARM - 1.0
    dy = shoulder[1] - 9.0
    hand = (shoulder[0] + math.sqrt(max(0.0, reach ** 2 - dy ** 2))
            * lerp(0.1, 1.0, d), 9.0)
    return P(pelvis, trunk, at(hand), at(KNEEL_ANKLE, foot=KNEEL_FOOT),
             spine=lerp(8, 4, d), head=lerp(-10, 0, d))


c = Clip("ab_wheel", "Ab wheel from knees", period=4200,
         props=[FLOOR_MAT, prop("abWheel", ["hands"], "near", r=9)])
c.rep(ab_wheel, down=(0.10, 0.50), up=(0.58, 0.88))


def dead_bug(t):
    """Opposite arm and leg reach long, one side then the other."""
    pelvis = (0.0, 10.0)
    up_arm, over = 90.0, 172.0
    table = (90.0, 0.0)
    long_leg = (8.0, 4.0)
    if t < 0.5:
        k = math.sin(math.pi * min(1.0, t / 0.5))
        ak, bk = k, 0.0
    else:
        k = math.sin(math.pi * min(1.0, (t - 0.5) / 0.5))
        ak, bk = 0.0, k
    armL = fk(lerp(up_arm, over, ak), lerp(up_arm, over, ak))
    armR = fk(lerp(up_arm, over, bk), lerp(up_arm, over, bk))
    legR = fk(lerp(table[0], long_leg[0], ak), lerp(table[1], long_leg[1], ak))
    legL = fk(lerp(table[0], long_leg[0], bk), lerp(table[1], long_leg[1], bk))
    return P(pelvis, 180.0, armL, legL, armR=armR, legR=legR)


c = Clip("dead_bug", "Dead bug", period=5200, still=0.25,
         bend={"armL": -1, "armR": -1, "legL": 1, "legR": 1},
         props=[FLOOR_MAT])
for i in range(16):
    c.key(i / 16, dead_bug(i / 16), "linear")


def hollow(d):
    pelvis = (0.0, 9.5)
    return P(pelvis, lerp(166.0, 163.0, d), fk(158.0, 160.0),
             fk(lerp(17.0, 19.0, d), lerp(15.0, 17.0, d)),
             spine=lerp(14.0, 16.0, d), head=-8.0)


c = Clip("hollow_hold", "Hollow hold", period=4000, still=0.5,
         props=[FLOOR_MAT])
c.rep(hollow, down=(0.0, 0.45), up=(0.5, 0.95), steps=3)


def side_plank(d):
    """Seen from the front, lying on the left side: the figure's left is
    down. Elbow under the shoulder, body in one line, hips lifting."""
    ankle = (0.0, 7.0)
    neck_y = 4.0 + UA + SHOULDER_HALF - 1.0
    line = math.degrees(math.asin((neck_y - 11.5) / (LEG - 4.5 + TRUNK)))
    neck = add((0.0, 11.5), pol(line, LEG - 4.5 + TRUNK))
    theta = line + lerp(8.0, 0.0, d)
    pelvis = sub(neck, pol(theta, TRUNK))
    left = cw(pol(theta))
    shoulderL = add(neck, mul(left, SHOULDER_HALF))
    elbow_x = shoulderL[0] + 1
    handL = (elbow_x + 3, 4.0)
    return P(pelvis, theta, at(handL, s=(1.0, 0.35)), at(ankle, foot=theta),
             armR=body(18.0, -14.0, s=(0.8, 0.8)),
             legR=at(add(ankle, (0.0, 9.0)), foot=theta))


c = Clip("side_plank", "Side plank", view="front", period=4200, still=0.5,
         bend={"armL": -1, "armR": -1, "legL": 1, "legR": -1},
         props=[prop("mat", [(-20, 0), (160, 0)])])
c.rep(side_plank, down=(0.05, 0.40), up=(0.62, 0.95), steps=4)


def cat_cow(t):
    """Quadruped: knees under hips, hands under shoulders. Round, then
    arch, one segment at a time."""
    pelvis = kneel_pelvis(90.0)
    trunk = 16.0
    w = math.sin(2 * math.pi * t)          # +1 cat, -1 cow
    spine = 34.0 * w if w > 0 else 26.0 * w
    neck = neck_of(pelvis, trunk, spine)
    hand = (neck_of(pelvis, trunk)[0] + 1.0, 1.5)
    return P(pelvis, trunk, at(hand, s=(1.0, 0.93)),
             at(KNEEL_ANKLE, foot=KNEEL_FOOT), spine=spine,
             head=-30.0 * w if w > 0 else -24.0 * w)


c = Clip("cat_cow", "Cat-cow", period=5600, still=0.25,
         props=[FLOOR_MAT])
c.loop(cat_cow, n=16)


def t_spine(d):
    """Quadruped, hand behind the head: the elbow sweeps down under the
    chest, then up to the ceiling, eyes following."""
    pelvis = kneel_pelvis(90.0)
    trunk = 16.0
    neck = neck_of(pelvis, trunk)
    hand = (neck[0] + 1.0, 1.5)
    upper = lerp(-100.0, 96.0, d)
    # Down under the chest the upper arm is half out of the picture; side-on
    # to the ceiling it is nearly all in it; in between it points at you.
    su = 0.2 + 0.35 * (1 - 2 * d) if d < 0.5 else 0.2 + 0.75 * (2 * d - 1)
    su = max(0.2, su)
    spine = lerp(6.0, -4.0, d)
    head_tilt = lerp(-40.0, 45.0, d)
    neck2 = neck_of(pelvis, trunk, spine)
    elbow = add(neck2, pol(upper, UA * su))
    head_c = add(neck2, pol(trunk - spine / 2 + head_tilt, NECK + HEAD_R))
    to_head = sub(head_c, elbow)
    sl = max(0.2, min(1.0, (math.hypot(*to_head) - 4.0) / FA))
    return P(pelvis, trunk, fk(upper, ang(to_head), s=(su, sl)),
             at(KNEEL_ANKLE, foot=KNEEL_FOOT),
             armR=at(hand, s=(1.0, 0.93)), head=head_tilt, spine=spine)


c = Clip("t_spine_rotation", "Thoracic rotation", period=4600,
         props=[FLOOR_MAT])
c.rep(t_spine, down=(0.10, 0.45), up=(0.55, 0.90))

# ============================================================================
# BRIDGES AND HIP THRUSTS (supine, head to the left)
# ============================================================================

HT_BENCH_TOP = 42.0
HT_EDGE = (-40.0, HT_BENCH_TOP + 1.0)
UPPER_BACK = (42.0, -10.0)


def pelvis_from_contact(contact, trunk, u, v):
    d = pol(trunk)
    return sub(contact, add(mul(d, u), mul(cw(d), v)))


def hip_thrust(d, bar=True):
    trunk = lerp(152.0, 181.0, d)
    pelvis = pelvis_from_contact(HT_EDGE, trunk, *UPPER_BACK)
    return P(pelvis, trunk, body(3.0, 12.5), at((44.0, ANKLE_Y)),
             head=lerp(-28.0, -32.0, d))


c = Clip("hip_thrust_bar", "Barbell hip thrust", period=3400,
         props=[prop("bench", [(-95, HT_BENCH_TOP), (HT_EDGE[0], HT_BENCH_TOP)]),
                prop("barbell", [trunk_ref(3.0, 12.5)], "near", r=17)])
c.rep(hip_thrust, down=(0.10, 0.42), up=(0.58, 0.88))

c = Clip("hip_thrust_db", "Dumbbell hip thrust", period=3400,
         props=[prop("bench", [(-95, HT_BENCH_TOP), (HT_EDGE[0], HT_BENCH_TOP)]),
                prop("dumbbell", [trunk_ref(3.0, 12.0)], "near", r=8)])
c.rep(lambda d: hip_thrust(d, bar=False), down=(0.10, 0.42), up=(0.58, 0.88))

FLOOR_BACK = (-42.0, 1.0)
SUPINE_ARMS = {"armL": 1, "armR": 1, "legL": 1, "legR": 1}


def bridge(d, ankle_x=32.0):
    trunk = lerp(178.0, 204.0, d)
    pelvis = pelvis_from_contact(FLOOR_BACK, trunk, *UPPER_BACK)
    return P(pelvis, trunk, at((1.0, 3.4)), at((ankle_x, ANKLE_Y)),
             head=lerp(-4.0, -12.0, d))


c = Clip("glute_bridge", "Glute bridge", period=3200, bend=SUPINE_ARMS,
         props=[FLOOR_MAT])
c.rep(bridge, down=(0.10, 0.42), up=(0.58, 0.88))

HEEL_FLOOR_Y = 7.8        # ankle height with the heel down and toes up (70 deg)


def slider_curl(d):
    """Heels on a towel, hips up, drag the feet in with the hamstrings."""
    ankle = (lerp(74.0, 34.0, d), HEEL_FLOOR_Y)
    trunk = lerp(190.0, 206.0, d)
    pelvis = pelvis_from_contact(FLOOR_BACK, trunk, *UPPER_BACK)
    return P(pelvis, trunk, at((1.0, 3.4)), at(ankle, foot=70.0),
             head=-8.0)


c = Clip("slider_curl", "Slider hamstring curl", period=3600,
         bend=SUPINE_ARMS, props=[FLOOR_MAT, prop("towel", ["heelL"], "back")])
c.rep(slider_curl, down=(0.10, 0.42), up=(0.52, 0.90))

RING_LOW_Y = 22.0


def ring_curl(d):
    ankle = (lerp(76.0, 36.0, d), RING_LOW_Y)
    trunk = lerp(192.0, 208.0, d)
    pelvis = pelvis_from_contact(FLOOR_BACK, trunk, *UPPER_BACK)
    return P(pelvis, trunk, at((1.0, 3.4)), at(ankle, foot=80.0), head=-8.0)


c = Clip("ring_curl", "Ring hamstring curl", period=3800,
         bend=SUPINE_ARMS, props=[FLOOR_MAT,
                prop("rings", [(58, 150), "ankleR", "ankleL"], "far")])
c.rep(ring_curl, down=(0.10, 0.42), up=(0.52, 0.92))

# ============================================================================
# MORE PRESSES AND PUSHES
# ============================================================================


def floor_press(d):
    pelvis = (0.0, 10.0)
    trunk = 180.0
    neck = neck_of(pelvis, trunk)
    top = add(neck, (2.0, ARM * 0.9 - 1.0))
    low = add(neck, (9.0, 13.0))
    hand = vlerp(top, low, d)
    s = (lerp(0.92, 0.36, d), lerp(0.92, 0.66, d))
    return P(pelvis, trunk, at(hand, s=s), at((36.0, ANKLE_Y)),
             head=lerp(0.0, 3.0, d))


c = Clip("floor_press_db", "Dumbbell floor press", period=3400,
         props=[FLOOR_MAT,
                prop("dumbbell", ["handR"], "far", r=7.5),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(floor_press, down=(0.10, 0.44), up=(0.54, 0.86))

INCLINE = 35.0
INC_JOINT = (-8.0, 46.0)
INC_TOP = add(INC_JOINT, pol(180 - INCLINE, 64.0))


def incline_press(d):
    backrest = pol(180 - INCLINE)          # up the pad, towards the head
    normal = (math.sin(math.radians(INCLINE)),
              math.cos(math.radians(INCLINE)))   # off the pad, body side
    base = add(INC_JOINT, mul(normal, 11.0))
    pelvis = add(base, mul(backrest, 3.0))
    trunk = 180 - INCLINE
    neck = neck_of(pelvis, trunk)
    top = add(neck, (5.0, ARM * 0.9 - 1.0))
    low = add(neck, (11.0, 10.0))
    s = (lerp(0.92, 0.46, d), lerp(0.92, 0.84, d))
    return P(pelvis, trunk, at(vlerp(top, low, d), s=s), at((40.0, ANKLE_Y)),
             head=lerp(-6.0, -2.0, d))


c = Clip("incline_press_db", "Incline dumbbell press", period=3600,
         props=[prop("bench", [(22, 46), INC_JOINT, INC_TOP]),
                prop("dumbbell", ["handR"], "far", r=7.5),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(incline_press, down=(0.10, 0.46), up=(0.52, 0.86))

_, hx_inc = push_up(0, grip_y=46.0)
c = Clip("push_up_incline", "Incline push-up", period=3000,
         props=[prop("bench", [(hx_inc - 12, 43.0), (hx_inc + 60, 43.0)])])
c.rep(lambda d: push_up(d, grip_y=46.0, low_off=13.0)[0], down=(0.08, 0.42),
      up=(0.50, 0.84))


def seated_press(d):
    pelvis = (0.0, 56.0)
    shoulder_y = pelvis[1] + TRUNK
    y = lerp(shoulder_y - 1.0, shoulder_y + ARM - 1.5, d)
    s = lerp(0.8, 1.0, smooth(d))
    feet = (at((24.0, ANKLE_Y), s=(0.35, 1.0)), at((-24.0, ANKLE_Y), s=(0.35, 1.0)))
    return P(pelvis, 90, at((24.0, y), s=s), feet[0],
             armR=at((-24.0, y), s=s), legR=feet[1])


c = Clip("seated_press_db", "Seated dumbbell press", view="front",
         period=3400, bend=FRONT_LEGS,
         props=[prop("box", [(-15, 46), (15, 46)]),
                prop("dumbbell", ["handL"], "near", r=7.5),
                prop("dumbbell", ["handR"], "near", r=7.5)])
c.rep(seated_press, down=(0.10, 0.42), up=(0.54, 0.88))


def bench_dip(d):
    hand = (-17.0, 46.0)
    shoulder = (lerp(-13.0, -10.0, d), lerp(hand[1] + ARM - 2.0, hand[1] + 30.0, d))
    trunk = lerp(88.0, 84.0, d)
    pelvis = sub(shoulder, pol(trunk, TRUNK))
    return P(pelvis, trunk, at(hand), at((44.0, ANKLE_Y)),
             head=lerp(0.0, -6.0, d))


c = Clip("bench_dip", "Bench dip", period=3000,
         props=[prop("bench", [(-95, 43), (-15, 43)])])
c.rep(bench_dip, down=(0.10, 0.44), up=(0.52, 0.86))

RING_ANCHOR_Y = 232.0


def ring_dip(d):
    hand = (3.0, 118.0)
    top = (0.0, hand[1] + ARM - 2.0)
    low = (4.0, hand[1] + 29.0)
    shoulder = vlerp(top, low, d)
    trunk = lerp(84.0, 72.0, d)
    pelvis = sub(shoulder, pol(trunk, TRUNK))
    return P(pelvis, trunk, at(hand), fk(-100.0, -155.0),
             head=lerp(0.0, -8.0, d))


c = Clip("ring_dip", "Ring dip", period=3200,
         props=[prop("rings", [(3, RING_ANCHOR_Y), "handR", "handL"], "far")])
c.rep(ring_dip, down=(0.10, 0.44), up=(0.52, 0.86))

# ============================================================================
# MORE PULLS
# ============================================================================


def ring_row(d):
    ankle = (0.0, HEEL_FLOOR_Y)     # heels down, toes up
    ang0, ang1 = 146.0, 126.0
    a0 = ang0
    pel0 = add(ankle, pol(a0, LEG - 0.6))
    sh0 = add(pel0, pol(a0, TRUNK))
    hand = add(sh0, pol(a0 - 80.0, ARM - 1.5))
    a = lerp(ang0, ang1, d)
    pelvis = add(ankle, pol(a, LEG - 0.6))
    return P(pelvis, a, at(hand), at(ankle, foot=70.0),
             head=lerp(-6, -12, d)), hand


_, rr_hand = ring_row(0)
c = Clip("ring_row", "Ring row", period=3000,
         bend={"armL": 1, "armR": 1, "legL": 1, "legR": 1},
         props=[prop("rings", [(rr_hand[0], RING_ANCHOR_Y), "handR"], "far"),
                prop("rings", [(rr_hand[0], RING_ANCHOR_Y), "handL"], "near")])
c.rep(lambda d: ring_row(d)[0], down=(0.10, 0.40), up=(0.50, 0.88))


def one_arm_row(d):
    knee_bench = (-10.0, 47.0)
    pelvis = add(knee_bench, pol(92.0, TH - 0.05))
    trunk = 15.0
    shoulder = add(pelvis, pol(trunk, TRUNK))
    far_hand = (shoulder[0] + 2.0, 46.0)
    hang = (shoulder[0] + 1.0, shoulder[1] - (ARM - 2.0))
    pocket = body_pt(pelvis, trunk, 14.0, -3.0)
    return P(pelvis, trunk, at(vlerp(hang, pocket, d)),
             at((-4.0, ANKLE_Y)),
             armR=at(far_hand),
             legR=at((-51.0, 48.5), foot=KNEEL_FOOT),
             head=12.0)


c = Clip("row_one_arm", "One-arm dumbbell row", period=3000,
         props=[prop("bench", [(-70, 43), (58, 43)]),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(one_arm_row, down=(0.10, 0.38), up=(0.52, 0.86))

CS_JOINT = (-5.0, 45.0)
CS_ANGLE = 32.0


def chest_supported_row(d):
    back = pol(CS_ANGLE)
    normal = (-back[1], back[0])
    base = add(CS_JOINT, mul(normal, 11.5))
    pelvis = add(base, mul(back, 4.0))
    trunk = CS_ANGLE
    shoulder = add(pelvis, pol(trunk, TRUNK))
    hang = (shoulder[0] + 1.0, shoulder[1] - (ARM - 2.0))
    ribs = body_pt(pelvis, trunk, 26.0, -18.0)
    return P(pelvis, trunk, at(vlerp(hang, ribs, d)), at((-66.0, ANKLE_Y)),
             head=14.0)


c = Clip("row_chest_supported", "Chest-supported dumbbell row", period=3000,
         props=[prop("bench", [(-38, 45), CS_JOINT,
                               add(CS_JOINT, pol(CS_ANGLE, 62.0))]),
                prop("dumbbell", ["handR"], "far", r=7.5),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(chest_supported_row, down=(0.10, 0.38), up=(0.52, 0.86))


def face_pull(d, anchor_y=150.0):
    shoulder = (0.5, STAND_Y + TRUNK)
    start = add(shoulder, (ARM - 2.0, anchor_y - shoulder[1] - 2.0))
    end = add(shoulder, (8.0, 17.0))
    s = (lerp(1.0, 0.36, d), lerp(1.0, 0.86, d))
    return P((0.5, STAND_Y), 90, at(vlerp(start, end, d), s=s),
             at((0.0, ANKLE_Y)), head=lerp(0.0, 4.0, d))


FACE_BEND = {"armL": 1, "armR": 1, "legL": 1, "legR": 1}
c = Clip("face_pull_band", "Band face pull", period=3000, bend=FACE_BEND,
         props=[prop("rack", [(95, 0), (95, 175)]),
                prop("band", [(95, 150), "hands"], "near")])
c.rep(face_pull, down=(0.10, 0.40), up=(0.52, 0.86))

c = Clip("face_pull_cable", "Cable face pull", period=3000, bend=FACE_BEND,
         props=[prop("cable", [(92, 158), "hands"], "back")])
c.rep(lambda d: face_pull(d, anchor_y=156.0), down=(0.10, 0.40),
      up=(0.52, 0.86))


def pull_apart(d):
    """From behind: the hands start together in front of the chest (hidden
    by the body) and sweep out to a T, shoulder blades squeezing."""
    y = STAND_Y + TRUNK - 1.0
    xs = [(-7.0, 0.28), (-24.0, 0.5), (-72.0, 0.97)]
    if d < 0.35:
        u = d / 0.35
        x = lerp(xs[0][0], xs[1][0], u)
        sc = lerp(xs[0][1], xs[1][1], u)
    else:
        u = (d - 0.35) / 0.65
        x = lerp(xs[1][0], xs[2][0], u)
        sc = lerp(xs[1][1], xs[2][1], u)
    return P((0.0, STAND_Y), 90, at((x, y - 1.5), s=sc), FEET_FRONT[1],
             armR=at((-x, y - 1.5), s=sc), legR=FEET_FRONT[0])


c = Clip("pull_apart", "Band pull-apart", view="back", period=3000,
         bend={"armL": 1, "armR": -1, "legL": -1, "legR": 1},
         behind=["armL", "armR"],
         props=[prop("band", ["handL", "handR"], "back")])
c.rep(pull_apart, down=(0.10, 0.40), up=(0.52, 0.86))


def pull_up_band(d):
    pose = pull_up(d)
    pose["legL"] = fk(-86.0 + 4 * d, -94.0 + 4 * d, s=(0.82, 0.38))
    return pose


c = Clip("pull_up_band", "Band-assisted pull-up", view="back", period=3200,
         bend=BACK_ARMS,
         props=[PULLUP_BAR,
                prop("band", [(-7, PULLUP_Y), "kneeL", (7, PULLUP_Y)],
                     "back", w=1.8)])
c.rep(pull_up_band, down=(0.08, 0.40), up=(0.50, 0.90))


def dead_hang(d):
    pose = pull_up(0)
    # shoulders sink into the stretch and draw back down: breathing, not a
    # pull.
    pose["pelvis"][1] = r2(pose["pelvis"][1] + lerp(0.0, 1.4, d))
    return pose


c = Clip("dead_hang", "Dead hang", view="back", period=4400, still=0.5,
         bend=BACK_ARMS, props=[PULLUP_BAR])
c.rep(dead_hang, down=(0.05, 0.45), up=(0.55, 0.95), steps=3)


def knee_raise(d):
    hands = (0.0, SIDE_BAR_TOP - 3.0)
    shoulder = (lerp(-1.0, -4.0, d), hands[1] - (ARM - 1.2))
    trunk = lerp(90.0, 97.0, d)
    pelvis = sub(shoulder, pol(trunk, TRUNK))
    thigh = lerp(-92.0, 28.0, d)
    shin = lerp(-94.0, -64.0, d)
    return P(pelvis, trunk, at(hands), fk(thigh, shin),
             spine=lerp(0.0, 22.0, d), head=lerp(0.0, -8.0, d))


c = Clip("hanging_knee_raise", "Hanging knee raise", period=3200,
         props=[SIDE_BAR])
c.rep(knee_raise, down=(0.10, 0.40), up=(0.52, 0.88))

# ============================================================================
# MORE ARMS
# ============================================================================


def curl_bar(d):
    return P((0.5, STAND_Y), 90, fk(-94.0 + 6 * d, lerp(-86.0, 60.0, d)), FOOT)


c = Clip("curl_ez", "EZ-bar curl", period=3000,
         props=[prop("barbell", ["hands"], "near", r=11)])
c.rep(curl_bar, down=(0.08, 0.40), up=(0.48, 0.88))


def pushdown(d):
    return P((0.0, STAND_Y - 0.5), 84.0,
             fk(-96.0, lerp(28.0, -88.0, d), s=(1.0, 1.0)), FOOT,
             head=4.0)


c = Clip("pushdown_cable", "Cable triceps pushdown", period=2800,
         props=[prop("cable", [(24, 192), "hands"], "back")])
c.rep(pushdown, down=(0.10, 0.40), up=(0.52, 0.86))


def overhead_ext(d):
    return P((0.0, STAND_Y), 90,
             fk(97.0, lerp(96.0, 252.0, d)), FOOT, head=lerp(0.0, -4.0, d))


c = Clip("overhead_extension", "Overhead dumbbell extension", period=3000,
         props=[prop("dumbbell", ["hands"], "near", r=8.5)])
c.rep(overhead_ext, down=(0.10, 0.44), up=(0.52, 0.86))


def skullcrusher(d):
    pelvis = (0.0, BENCH_TOP + 10.0)
    trunk = 179.0
    return P(pelvis, trunk, fk(100.0, lerp(96.0, 206.0, d), s=(0.95, 0.95)),
             at((38.0, ANKLE_Y)), spine=-6.0)


c = Clip("skullcrusher", "EZ-bar skull crusher", period=3000,
         props=[BENCH, prop("barbell", ["hands"], "near", r=11)])
c.rep(skullcrusher, down=(0.10, 0.44), up=(0.52, 0.86))

# ============================================================================
# SHOULDERS, MOBILITY
# ============================================================================


def band_lateral(d):
    pose = lateral_raise(d)
    return pose


c = Clip("lateral_raise_band", "Band lateral raise", view="front",
         period=3000, bend=FRONT_LEGS,
         props=[prop("band", ["handL", (0, 1.5), "handR"], "near")])
c.rep(band_lateral, down=(0.10, 0.40), up=(0.50, 0.90))


def wall_slide(d):
    upper = lerp(-8.0, 62.0, d)
    fore = lerp(90.0, 70.0, d)
    return P((0.0, STAND_Y), 90, fk(upper, fore, s=(0.94, 0.96)), FEET_FRONT[0],
             armR=fk(180 - upper, 180 - fore, s=(0.94, 0.96)),
             legR=FEET_FRONT[1])


c = Clip("wall_slide", "Wall slide", view="front", period=3600,
         bend=FRONT_LEGS)
c.rep(wall_slide, down=(0.10, 0.44), up=(0.52, 0.88))


def pass_through(t):
    """Straight arms over the head and behind, and back: one loop."""
    path = [(-70.0, 0.86), (0.0, 0.8), (90.0, 0.84), (180.0, 0.8),
            (238.0, 0.74)]
    u = 0.5 - 0.5 * math.cos(2 * math.pi * t)       # 0 -> 1 -> 0
    x = u * (len(path) - 1)
    i = min(len(path) - 2, int(x))
    f = x - i
    a = lerp(path[i][0], path[i + 1][0], f)
    sc = lerp(path[i][1], path[i + 1][1], f)
    return P((0.5, STAND_Y), 90, fk(a, a, s=sc), FOOT, head=0)


c = Clip("pass_through", "Broomstick pass-through", period=4800, still=0.5,
         props=[prop("dowel", ["hands"], "near")])
c.loop(pass_through, n=20)


def doorway(d):
    """Forearm on the frame at shoulder height; step through."""
    hand = (-5.0, STAND_Y + TRUNK + 26.0)
    lean = lerp(90.0, 81.0, d)
    pelvis = (lerp(0.0, 11.0, d), lerp(84.5, 82.5, d))
    return P(pelvis, lean, at(hand, s=(0.42, 0.96)), at((15.0, ANKLE_Y)),
             legR=at((-12.0, ANKLE_Y)), head=0)


c = Clip("doorway_stretch", "Doorway chest stretch", period=5000,
         bend={"armL": 1, "armR": -1, "legL": 1, "legR": 1},
         props=[prop("wall", [(-7, 0), (-7, 205)], "far")])
c.rep(doorway, down=(0.10, 0.45), up=(0.70, 0.95), steps=4)


def couch(d):
    """Rear knee down against the wall, shin up the wall, front foot
    forward. Squeeze the back glute: the hips glide forward."""
    knee = (6.0, 5.0)
    hip = add(knee, pol(lerp(72.0, 64.0, d), TH - 0.05))
    trunk = lerp(88.0, 92.0, d)
    return P(hip, trunk, fk(-92, -86),
             at((knee[0] - 4.0, knee[1] + SH - 0.5), foot=96.0),
             legR=at((72.0, ANKLE_Y)), head=0)


c = Clip("couch_stretch", "Couch stretch", period=5000,
         bend={"armL": -1, "armR": -1, "legL": 1, "legR": 1},
         props=[FLOOR_MAT, prop("wall", [(0, 0), (0, 130)])])
c.rep(couch, down=(0.10, 0.45), up=(0.65, 0.95), steps=4)


def hamstring_stretch(d):
    heel = (70.0, 32.0)
    a = math.radians(80.0)
    lh = (-6.0, -ANKLE_Y)
    rh = (lh[0] * math.cos(a) - lh[1] * math.sin(a),
          lh[0] * math.sin(a) + lh[1] * math.cos(a))
    ankle = sub(heel, rh)
    pelvis = (0.5, lerp(86.0, 85.5, d))
    trunk = lerp(86.0, 44.0, d)
    return P(pelvis, trunk, fk(lerp(-88, -70, d), lerp(-86, -64, d)),
             at(ankle, foot=80.0), legR=at((0.0, ANKLE_Y)), head=0)


c = Clip("hamstring_stretch", "Standing hamstring stretch", period=5000,
         props=[prop("box", [(56, 32), (90, 32)])])
c.rep(hamstring_stretch, down=(0.10, 0.45), up=(0.70, 0.95), steps=4)


def leg_swing(t):
    swing = math.sin(2 * math.pi * t)
    thigh = -90.0 + 48.0 * swing
    shin = thigh - 22.0 + 10.0 * max(0.0, -swing)
    return P((0.5, STAND_Y), 90, at((WALL_AT - 3.0, 125.0)), fk(thigh, shin),
             armR=fk(-92, -88), legR=at((0.0, ANKLE_Y)), head=0)


c = Clip("leg_swing", "Leg swing", period=1800, still=0.25,
         bend={"armL": -1, "armR": -1, "legL": 1, "legR": 1},
         props=[prop("wall", [(WALL_AT, 0), (WALL_AT, 190)])])
c.loop(leg_swing, n=16)


def hip_9090(t):
    """Seated, from the front: both knees tip from one side, up through the
    middle, to the other, hands off the floor. Each pose is a pair of 90s:
    the front shin lies across the body, the side thigh points away."""
    keys = [  # (L thigh, L shin, L s), (R thigh, R shin, R s)
        ((190.0, 0.0, (0.6, 0.85)), (188.0, 0.0, (0.95, 0.3))),
        ((70.0, -66.0, (0.6, 0.75)), (110.0, -114.0, (0.6, 0.75))),
        ((-8.0, -180.0, (0.95, 0.3)), (-10.0, -180.0, (0.6, 0.85))),
    ]
    p = 0.5 - 0.5 * math.cos(2 * math.pi * t)       # 0 -> 1 -> 0
    x = p * 2
    i = min(1, int(x))
    f = smooth(x - i)

    def leg(n):
        a, b = keys[i][n], keys[i + 1][n]
        return fk(lerp(a[0], b[0], f), lerp(a[1], b[1], f),
                  s=(lerp(a[2][0], b[2][0], f), lerp(a[2][1], b[2][1], f)))

    lean = lerp(-5.0, 5.0, p)
    return P((0.0, 12.0), 90 + lean, fk(-62, -72, s=0.55), leg(0),
             armR=fk(-118, -108, s=0.55), legR=leg(1), head=-lean)


c = Clip("hip_9090", "90/90 hip switch", view="front", period=4400,
         still=0.25, bend={"armL": -1, "armR": 1, "legL": 1, "legR": -1},
         props=[FLOOR_MAT])
c.loop(hip_9090, n=16)

# ============================================================================
# LEGS: LUNGES, SPLIT SQUATS, STEPS, HINGES ON ONE LEG, CALVES
# ============================================================================

HOLD_DBS = [prop("dumbbell", ["handR"], "far", r=7.5),
            prop("dumbbell", ["handL"], "near", r=7.5)]


def split_squat(d, front=(24.0, ANKLE_Y), rear=None, rear_foot=-45.0,
                top=(-6.0, 80.0), low=(-10.0, 46.0)):
    pelvis = vlerp(top, low, d)
    rear = rear or foot_on_toe((-46.0, 0.0), rear_foot)
    return P(pelvis, lerp(88.0, 84.0, d), fk(-90, -89), at(front),
             legR=at(rear, foot=rear_foot), head=0)


c = Clip("split_squat", "Split squat", period=3200, props=HOLD_DBS)
c.rep(split_squat, down=(0.10, 0.44), up=(0.54, 0.88))

BSS_REAR = (-60.0, HT_BENCH_TOP + 6.0)
c = Clip("split_squat_bulgarian", "Bulgarian split squat", period=3400,
         props=[prop("bench", [(-110, HT_BENCH_TOP), (-52, HT_BENCH_TOP)])]
         + HOLD_DBS)
c.rep(lambda d: split_squat(d, front=(20.0, ANKLE_Y), rear=BSS_REAR,
                            rear_foot=200.0, top=(-6.0, 80.5),
                            low=(-12.0, 45.0)),
      down=(0.10, 0.44), up=(0.54, 0.88))


def reverse_lunge(t):
    """The far leg steps back into a lunge and returns; the near leg does
    the work."""
    front = (0.0, ANKLE_Y)
    land = foot_on_toe((-62.0, 0.0), -45.0)
    stand = (0.5, STAND_Y)
    step = (-24.0, 76.0)
    low = (-28.0, 46.0)
    keys = [
        (0.00, stand, front, 0.0),
        (0.08, stand, front, 0.0),
        (0.20, (-10.0, 84.0), (-34.0, 18.0), -25.0),
        (0.30, step, land, -45.0),
        (0.44, low, land, -45.0),
        (0.54, low, land, -45.0),
        (0.68, step, land, -45.0),
        (0.78, (-10.0, 84.0), (-34.0, 18.0), -25.0),
        (0.90, stand, front, 0.0),
    ]
    for (t0, p0, f0, a0), (t1, p1, f1, a1) in zip(keys, keys[1:]):
        if t0 <= t < t1:
            u = inout((t - t0) / (t1 - t0))
            pel, rear, ang = vlerp(p0, p1, u), vlerp(f0, f1, u), lerp(a0, a1, u)
            break
    else:
        pel, rear, ang = stand, front, 0.0
    return P(pel, 88.0, fk(-90, -89), at(front),
             legR=at(rear, foot=ang), head=0)


c = Clip("lunge_reverse", "Reverse lunge", period=3600, still=0.48,
         props=HOLD_DBS)
c.loop(reverse_lunge, n=24)


def walking_lunge(t, step=72.0):
    """Two steps a loop, the camera following: step, sink, drive up, bring
    the back foot through."""
    def half(u, lead_from, trail_from):
        # u in [0, 1): one step forward by the lead leg
        stand_x = lead_from
        land = lead_from + step
        pel_top = (stand_x + 0.5, STAND_Y)
        keys = [
            (0.00, pel_top, (lead_from, ANKLE_Y), 0.0, (trail_from, ANKLE_Y), 0.0),
            (0.16, (stand_x + 18.0, 84.0), (lead_from + 36.0, 20.0), 0.0,
             (trail_from, ANKLE_Y), 0.0),
            (0.30, (stand_x + 30.0, 74.0), (land, ANKLE_Y), 0.0,
             foot_on_toe((trail_from + 19.0, 0.0), -40.0), -40.0),
            (0.52, (stand_x + 34.0, 47.0), (land, ANKLE_Y), 0.0,
             foot_on_toe((trail_from + 19.0, 0.0), -48.0), -48.0),
            (0.74, (stand_x + 56.0, 80.0), (land, ANKLE_Y), 0.0,
             (trail_from + 36.0, 22.0), -30.0),
            (1.00, (land + 0.5, STAND_Y), (land, ANKLE_Y), 0.0,
             (land, ANKLE_Y), 0.0),
        ]
        for a, b in zip(keys, keys[1:]):
            if a[0] <= u < b[0] or (b is keys[-1] and u >= a[0]):
                v = inout((u - a[0]) / (b[0] - a[0]))
                return (vlerp(a[1], b[1], v), vlerp(a[2], b[2], v),
                        lerp(a[3], b[3], v), vlerp(a[4], b[4], v),
                        lerp(a[5], b[5], v))
        raise ValueError(u)

    if t < 0.5:
        pel, lead, la, trail, ta = half(t / 0.5, 0.0, 0.0)
        near, na, far, fa = lead, la, trail, ta
    else:
        pel, lead, la, trail, ta = half((t - 0.5) / 0.5, step, step)
        near, na, far, fa = trail, ta, lead, la
    return P(pel, 87.0, fk(-90, -89), at(near, foot=na),
             legR=at(far, foot=fa), head=0)


c = Clip("lunge_walking", "Walking lunge", period=4400, travel=144.0,
         still=0.26, props=HOLD_DBS)
c.loop(walking_lunge, n=40)


STEP_TOP = 25.0


def step_up(t):
    box_foot = (34.0, STEP_TOP + ANKLE_Y)
    floor = (0.0, ANKLE_Y)
    keys = [
        (0.00, (0.5, STAND_Y), floor, floor),
        (0.08, (0.5, STAND_Y), floor, floor),
        (0.18, (3.0, 85.5), (18.0, STEP_TOP + 22.0), floor),
        (0.26, (8.0, 84.0), box_foot, floor),
        (0.46, (33.0, STEP_TOP + STAND_Y), box_foot, (20.0, STEP_TOP + 20.0)),
        (0.54, (34.5, STEP_TOP + STAND_Y), box_foot, box_foot),
        (0.62, (34.5, STEP_TOP + STAND_Y), box_foot, box_foot),
        (0.74, (12.0, 85.0), box_foot, floor),
        (0.84, (5.0, 85.5), (16.0, STEP_TOP + 22.0), floor),
        (0.92, (0.5, STAND_Y), floor, floor),
    ]
    for a, b in zip(keys, keys[1:]):
        if a[0] <= t < b[0]:
            u = inout((t - a[0]) / (b[0] - a[0]))
            pel, near, far = vlerp(a[1], b[1], u), vlerp(a[2], b[2], u), vlerp(a[3], b[3], u)
            break
    else:
        pel, near, far = keys[-1][1], keys[-1][2], keys[-1][3]
    return P(pel, 88.0, fk(-90, -89), at(near), legR=at(far),
             head=0)


c = Clip("step_up", "Step-up", period=4400, still=0.5,
         props=[prop("box", [(16, STEP_TOP), (58, STEP_TOP)])] + HOLD_DBS)
c.loop(step_up, n=32)


def single_leg_rdl(d):
    knee = add((0, ANKLE_Y), pol(lerp(88.0, 82.0, d), SH))
    trunk = lerp(88.0, 8.0, d)
    hip = add(knee, pol(lerp(92.0, 118.0, d), TH))
    return P(hip, trunk, fk(-90, -89), at((0.0, ANKLE_Y)),
             legR=fk(trunk - 182.0, trunk - 186.0),
             head=lerp(0.0, 30.0, d))


c = Clip("rdl_single_leg", "Single-leg Romanian deadlift", period=4000,
         props=[prop("dumbbell", ["handR"], "far", r=7.5)])
c.rep(single_leg_rdl, down=(0.10, 0.46), up=(0.56, 0.90))

PLATFORM = 4.0
CALF_WALL = 52.0


def calf_raise(d, both=True):
    ball = (13.0, PLATFORM)
    angle = lerp(8.0, -34.0, d)
    ankle = foot_on_toe(ball, angle)
    pelvis = add(ankle, (0.8, LEG - 0.4))
    far = at(sub(ankle, (0.0, 0.0)), foot=angle) if both else fk(-100.0, -150.0)
    return P(pelvis, 90, fk(-90, -89), at(ankle, foot=angle),
             armR=at((CALF_WALL - 4.0, 130.0)) if not both else fk(-90, -89),
             legR=far, head=0)


c = Clip("calf_raise", "Standing calf raise", period=3000,
         props=[prop("platform", [(9, PLATFORM), (46, PLATFORM)]),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(calf_raise, down=(0.10, 0.40), up=(0.56, 0.88))

c = Clip("calf_raise_single", "Single-leg calf raise", period=3000,
         props=[prop("wall", [(CALF_WALL, 0), (CALF_WALL, 190)]),
                prop("platform", [(9, PLATFORM), (46, PLATFORM)]),
                prop("dumbbell", ["handL"], "near", r=7.5)])
c.rep(lambda d: calf_raise(d, both=False), down=(0.10, 0.40),
      up=(0.56, 0.88))


def good_morning(d, bar=True):
    trunk = lerp(90.0, 44.0, d)
    knee = add((0, ANKLE_Y), pol(lerp(86.0, 83.0, d), SH))
    # The bar starts behind the spine line; as the hips go back it ends a
    # little ahead of mid-foot.
    if bar:
        target_x = lerp(-4.0, 8.0, d)
        u, v = BACK_BAR
    else:
        target_x = lerp(3.0, 5.0, d)
        u, v = 30.0, 0.0

    def gap(theta):
        hip = add(knee, pol(theta, TH))
        return body_pt(hip, trunk, u, v)[0] - target_x

    theta = bisect(gap, 80.0, 179.0)
    hip = add(knee, pol(theta, TH))
    arm = body(*BACK_BAR) if bar else body(62.0, -8.0, s=(0.42, 0.6))
    return P(hip, trunk, arm, FOOT, head=lerp(0.0, 16.0, d))


c = Clip("good_morning_bar", "Barbell good morning", period=3600,
         bend={"armL": 1, "armR": 1, "legL": 1, "legR": 1},
         scale={"armL": 0.72, "armR": 0.72},
         props=[prop("rack", [(MIDFOOT, 0), (MIDFOOT, 175)],
                     hook=bar_top[1] - 3),
                prop("barbell", [trunk_ref(*BACK_BAR)], "near", r=17)])
c.rep(good_morning, down=(0.10, 0.44), up=(0.54, 0.88))

c = Clip("good_morning_bw", "Bodyweight good morning", period=3200,
         bend={"armL": 1, "armR": 1, "legL": 1, "legR": 1})
c.rep(lambda d: good_morning(d, bar=False), down=(0.10, 0.44),
      up=(0.54, 0.88))


def nordic(t):
    """Lower as slowly as you can, catch, push back up. Only the lowering
    counts, so it takes most of the loop."""
    knee = (0.0, 5.0)
    if t < 0.62:
        u = t / 0.62
        theta = lerp(90.0, 24.0, u ** 1.3)
        hands = lerp(0.0, 1.0, max(0.0, (u - 0.7) / 0.3))
    elif t < 0.72:
        theta, hands = 24.0, 1.0
    else:
        u = inout((t - 0.72) / 0.28)
        theta = lerp(24.0, 90.0, u)
        hands = 1.0 - u
    pelvis = add(knee, pol(theta, TH))
    chest = (38.0, 16.0)
    shoulder = add(pelvis, pol(theta, TRUNK))
    floor_hand = (shoulder[0] + 12.0, 3.0)
    catch = to_body(pelvis, theta, floor_hand)
    hand = vlerp(chest, catch, smooth(hands))
    return P(pelvis, theta, body(*hand), at(KNEEL_ANKLE, foot=KNEEL_FOOT),
             head=lerp(0.0, 10.0, hands))


c = Clip("nordic", "Nordic curl negative", period=6000, still=0.4,
         props=[FLOOR_MAT, prop("bar", [(-47, 17)], "near", r=17)])
c.loop(nordic, n=30)

# ============================================================================
# CONDITIONING
# ============================================================================


def skipping(t):
    hop = 4.0 * max(0.0, math.sin(2 * math.pi * t))
    pelvis = (0.0, STAND_Y - 1.2 + hop)
    turn = 2 * math.pi * t
    hx, hy = 26.0 + 2.5 * math.cos(turn), 98.0 + hop + 2.5 * math.sin(turn)
    ankle_y = ANKLE_Y + hop
    toe = -12.0 * min(1.0, hop / 3.0)
    return P(pelvis, 90, at((hx, hy), s=(0.95, 0.55)),
             at((6.0, ankle_y), foot=toe),
             armR=at((-hx, hy), s=(0.95, 0.55)),
             legR=at((-6.0, ankle_y), foot=toe), head=0)


c = Clip("skipping", "Rope skipping", view="front", period=600, still=0.75,
         bend={"armL": -1, "armR": 1, "legL": 1, "legR": -1},
         props=[prop("jumpRope", ["handL", "handR"], "near", reach=92)])
c.loop(skipping, n=12)


def bag(t):
    """Orthodox stance, a jab and a cross, back to the guard."""
    guardL, guardR = (46.0, 17.0), (44.0, 11.0)
    punch, cross = (50.0, 62.0), (48.0, 58.5)
    keys = [(0.00, guardL, guardR), (0.12, guardL, guardR),
            (0.24, punch, guardR), (0.36, guardL, guardR),
            (0.50, guardL, guardR), (0.64, guardL, cross),
            (0.78, guardL, guardR)]
    for a, b in zip(keys, keys[1:]):
        if a[0] <= t < b[0]:
            u = inout((t - a[0]) / (b[0] - a[0]))
            l, r = vlerp(a[1], b[1], u), vlerp(a[2], b[2], u)
            break
    else:
        l, r = guardL, guardR
    bob = 1.2 * math.sin(4 * math.pi * t)
    pelvis = (0.0, STAND_Y - 4.0 + bob)
    return P(pelvis, 86.0 - 3.0 * (r[1] - guardR[1]) / (cross[1] - guardR[1]),
             body(*l), at((22.0, ANKLE_Y)),
             armR=body(*r), legR=at(foot_on_toe((-8.0, 0.0), -22.0), foot=-22.0),
             head=-6.0)


c = Clip("bag_rounds", "Heavy bag rounds", period=1800, still=0.24,
         props=[prop("bag", [(80, 235), (80, 72)], "back", w=30, len=92)])
c.loop(bag, n=28)


def gait(stride, stance, lift, clear, pelvis_y, bounce, arms, lean=88.0,
         land_ahead=26.0, roll_to=-42.0):
    """A walking cycle: the heel lands, rolls over the ball, lifts, swings
    through low. Both feet share the floor for part of each step."""
    def foot_at(phase, land_x):
        if phase < stance:
            roll = max(0.0, (phase - stance * 0.5) / (stance * 0.5))
            angle = lerp(0.0, roll_to, smooth(roll))
            if roll <= 0:
                return (land_x, ANKLE_Y), 0.0
            return foot_on_toe((land_x + 19.0, 0.0), angle), angle
        u = (phase - stance) / (1 - stance)
        start = foot_on_toe((land_x + 19.0, 0.0), roll_to)
        end = (land_x + stride, ANKLE_Y)
        x = lerp(start[0], end[0], smooth(u))
        base_y = lerp(start[1], ANKLE_Y, smooth(u))
        y = base_y + (lift if u < 0.4 else clear) * math.sin(math.pi * u)
        angle = lerp(roll_to, 0.0, smooth(u * 1.4))
        return (x, y), angle

    def pose(t):
        px = stride * t
        la = land_ahead + stride * math.floor(t)
        lb = land_ahead + stride * (math.floor(t + 0.5) - 0.5)
        fa, aa = foot_at(t % 1.0, la)
        fb, ab = foot_at((t + 0.5) % 1.0, lb)
        py = pelvis_y + bounce * math.cos(4 * math.pi * (t - stance / 2))
        armL, armR = arms(t)
        return P((px, py), lean, armL, at(fa, foot=aa), armR=armR,
                 legR=at(fb, foot=ab), head=0)

    return pose


def carry_arms(both):
    def arms(t):
        sw = 3.0 * math.sin(2 * math.pi * t)
        near = fk(-90 + sw, -89 + sw)
        far = fk(-90 - sw, -89 - sw) if both else fk(-90 - 16 * math.sin(2 * math.pi * t), -80 - 16 * math.sin(2 * math.pi * t))
        return near, far
    return arms


WALK = dict(stride=116.0, stance=0.6, lift=9.0, clear=4.0,
            pelvis_y=STAND_Y - 2.8, bounce=1.2, land_ahead=20.0)

c = Clip("carry_farmer", "Farmer's walk", period=1100, travel=116.0,
         still=0.0, props=HOLD_DBS)
c.loop(gait(arms=carry_arms(True), **WALK), n=20)

c = Clip("carry_suitcase", "Suitcase carry", period=1100, travel=116.0,
         still=0.0, props=[prop("dumbbell", ["handL"], "near", r=8.5)])
c.loop(gait(arms=carry_arms(False), **WALK), n=20)

MAPPING.update({
    "ab-wheel-knees": "ab_wheel",
    "dead-bug": "dead_bug",
    "hollow-hold": "hollow_hold",
    "side-plank": "side_plank",
    "cat-cow": "cat_cow",
    "thoracic-rotation": "t_spine_rotation",
    "barbell-hip-thrust": "hip_thrust_bar",
    "dumbbell-hip-thrust": "hip_thrust_db",
    "glute-bridge": "glute_bridge",
    "slider-hamstring-curl": "slider_curl",
    "ring-hamstring-curl": "ring_curl",
    "dumbbell-floor-press": "floor_press_db",
    "incline-dumbbell-press": "incline_press_db",
    "incline-push-up": "push_up_incline",
    "seated-dumbbell-press": "seated_press_db",
    "bench-dip": "bench_dip",
    "ring-dip": "ring_dip",
    "ring-row": "ring_row",
    "one-arm-dumbbell-row": "row_one_arm",
    "chest-supported-dumbbell-row": "row_chest_supported",
    "band-face-pull": "face_pull_band",
    "cable-face-pull": "face_pull_cable",
    "band-pull-apart": "pull_apart",
    "pull-up-assisted": "pull_up_band",
    "dead-hang": "dead_hang",
    "hanging-knee-raise": "hanging_knee_raise",
    "ez-bar-curl": "curl_ez",
    "cable-triceps-pushdown": "pushdown_cable",
    "overhead-dumbbell-extension": "overhead_extension",
    "ez-bar-skullcrusher": "skullcrusher",
    "band-lateral-raise": "lateral_raise_band",
    "wall-slide": "wall_slide",
    "broomstick-pass-through": "pass_through",
    "doorway-chest-stretch": "doorway_stretch",
    "couch-stretch": "couch_stretch",
    "standing-hamstring-stretch": "hamstring_stretch",
    "leg-swing": "leg_swing",
    "ninety-ninety-hip-switch": "hip_9090",
    "split-squat": "split_squat",
    "bulgarian-split-squat": "split_squat_bulgarian",
    "reverse-lunge": "lunge_reverse",
    "walking-lunge": "lunge_walking",
    "step-up": "step_up",
    "single-leg-rdl": "rdl_single_leg",
    "standing-calf-raise": "calf_raise",
    "single-leg-calf-raise": "calf_raise_single",
    "barbell-good-morning": "good_morning_bar",
    "bodyweight-good-morning": "good_morning_bw",
    "nordic-curl-negative": "nordic",
    "rope-skipping": "skipping",
    "heavy-bag-rounds": "bag_rounds",
    "farmers-walk": "carry_farmer",
    "suitcase-carry": "carry_suitcase",
})

# ============================================================================
# Checks, then write
# ============================================================================

errors = []


def fail(msg):
    errors.append(msg)


def limb_roots(frame, view):
    """The rig's limb roots for one keyframe (mirrors pose.dart)."""
    pel = tuple(frame["pelvis"])
    tr, sp = frame["trunk"], frame.get("spine", 0.0)
    lower, upper = pol(tr + sp / 2), pol(tr - sp / 2)
    neck = add(pel, mul(lower, TRUNK / 2), mul(upper, TRUNK / 2))
    chord = pol(tr)
    if view == "side":
        return pel, chord, cw(chord), {
            "armL": neck, "armR": add(neck, DEPTH),
            "legL": pel, "legR": add(pel, DEPTH)}

    def left(v):
        return cw(v) if view == "front" else (-v[1], v[0])
    return pel, chord, left(chord), {
        "armL": add(neck, mul(left(upper), SHOULDER_HALF)),
        "armR": add(neck, mul(left(upper), -SHOULDER_HALF)),
        "legL": add(pel, mul(left(lower), HIP_HALF)),
        "legR": add(pel, mul(left(lower), -HIP_HALF))}


def reach_warnings(clip):
    """Keyframes asking a limb to reach further (or nearer) than it can.
    Between keyframes the app's test checks every frame; this is the quick
    look while authoring."""
    out = []
    for f in clip.frames:
        pel, chord, normal, roots = limb_roots(f, clip.view)
        for limb in ("armL", "armR", "legL", "legR"):
            tgt = f[limb]
            sv = tgt.get("s", 1.0)
            su, sl = (sv if isinstance(sv, list) else (sv, sv))
            cs = (clip.scale or {}).get(limb, 1.0)
            arm = limb.startswith("arm")
            a = (UA if arm else TH) * su * cs
            b = (FA if arm else SH) * sl * cs
            if "at" in tgt:
                pt = tuple(tgt["at"])
            elif "body" in tgt:
                u, v = tgt["body"]
                pt = add(pel, mul(chord, u), mul(normal, v))
            else:
                continue
            if clip.view == "side" and limb.endswith("R"):
                pt = add(pt, DEPTH)
            dd = dist(roots[limb], pt)
            if dd > a + b + 0.3 or dd < abs(a - b) - 0.3:
                out.append(f"{clip.id} t={f['t']}: {limb} needs {dd:.1f}, "
                           f"reaches {abs(a - b):.1f}..{a + b:.1f}")
    return out


with io.open(EXERCISES, encoding="utf-8") as fh:
    EX = json.load(fh)["exercises"]
ex_ids = [e["id"] for e in EX]
clip_ids = {c.id for c in CLIPS}

if len(clip_ids) != len(CLIPS):
    fail("duplicate clip ids")
for ex_id, clip_id in MAPPING.items():
    if ex_id not in ex_ids:
        fail(f"mapping names unknown exercise {ex_id}")
    if clip_id not in clip_ids:
        fail(f"{ex_id} -> missing clip {clip_id}")
missing = [e for e in ex_ids if e not in MAPPING]
used = set(MAPPING.values())
for cl in CLIPS:
    if cl.id not in used:
        fail(f"clip {cl.id} is not used by any exercise")
for e in EX:
    for m in e["primaryMuscles"] + e["secondaryMuscles"]:
        if m not in MUSCLES:
            fail(f"{e['id']}: muscle {m} has no region")
for m, regions in MUSCLES.items():
    for r in regions:
        if r not in REGIONS:
            fail(f"muscle {m} -> unknown region {r}")

doc = {
    "schemaVersion": 1,
    "provenance": PROVENANCE,
    "notes": ("Exercise demos. Original figures posed from keyframes by "
              "tools/gen_motions.py -- never edit by hand. Units: cm, y up, "
              "floor at 0. Side views face +x."),
    "skeleton": SKELETON,
    "muscles": MUSCLES,
    "clips": [c.json() for c in CLIPS],
    "exercises": [
        {"exerciseId": e, "clip": MAPPING[e], "provenance": PROVENANCE}
        for e in ex_ids if e in MAPPING
    ],
}


def dump(obj):
    """Compact where it is bulky (one keyframe per line), readable where a
    person would look (the header, the mapping)."""
    out = ["{"]
    keys = list(obj.keys())
    for i, k in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        v = obj[k]
        if k == "clips":
            out.append('  "clips": [')
            for j, clip in enumerate(v):
                cc = "," if j < len(v) - 1 else ""
                head = {kk: vv for kk, vv in clip.items() if kk != "keyframes"}
                out.append("    {")
                for hk, hv in head.items():
                    out.append(f'      {json.dumps(hk)}: '
                               f'{json.dumps(hv, ensure_ascii=False)},')
                out.append('      "keyframes": [')
                frames = clip["keyframes"]
                for n, f in enumerate(frames):
                    fc = "," if n < len(frames) - 1 else ""
                    out.append("        " + json.dumps(f, ensure_ascii=False,
                                                       separators=(",", ":"))
                               + fc)
                out.append("      ]")
                out.append("    }" + cc)
            out.append("  ]" + comma)
        elif k == "exercises":
            out.append('  "exercises": [')
            for j, e in enumerate(v):
                ec = "," if j < len(v) - 1 else ""
                out.append("    " + json.dumps(e, ensure_ascii=False) + ec)
            out.append("  ]" + comma)
        else:
            text = json.dumps(v, ensure_ascii=False, indent=2)
            text = text.replace("\n", "\n  ")
            out.append(f"  {json.dumps(k)}: {text}{comma}")
    out.append("}")
    return "\n".join(out) + "\n"


text = dump(doc)
json.loads(text)
for path in (OUT, MIRROR):
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)

print(f"wrote motions.json  {len(text.encode('utf-8')):>8,} bytes  "
      f"{len(CLIPS)} clips, {len(doc['exercises'])} of {len(ex_ids)} "
      f"exercises mapped")
if missing:
    print(f"  NOT YET MAPPED ({len(missing)}): {', '.join(missing)}")
warn = [w for cl in CLIPS for w in reach_warnings(cl)]
if warn:
    print(f"\nREACH ({len(warn)} keyframes):")
    for w in warn[:60]:
        print("  " + w)
if errors:
    print("\nFAILED:")
    for e in errors:
        print("  " + e)
    sys.exit(1)
