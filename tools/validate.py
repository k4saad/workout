#!/usr/bin/env python3
"""Validation gates V1-V13 from docs/02-data-model.md, section 1.6.

These are the same assertions Phase 1 ports to `flutter test`. Run this after any
edit to data/*.json, and after any change to tools/gen.py.

    python tools/validate.py

Exit code 0 = every gate passed. Non-zero = the build is broken.
"""
import json, os, sys, itertools, collections, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as fh:
        return json.load(fh)


prog = load("keller-twelve.json")
exdoc = load("exercises.json")
inv = load("inventory.json")
schema = load("schema.json")

LIB = {e["id"]: e for e in exdoc["exercises"]}
BLOCKS = {b["id"]: b for b in prog["blocks"]}

failures, warnings = [], []


def fail(gate, msg):
    failures.append(f"{gate}: {msg}")


def warn(msg):
    warnings.append(msg)


# ---------------------------------------------------------------- lattice ----
BARS = {b["id"]: b["weightKg"] for b in inv["bars"]}
PLATES = [(p["weightKg"], p["count"]) for p in inv["plates"]]
DIV = {"barbell": 2, "ezBar": 2, "dumbbellPair": 4, "dumbbellSingle": 2}
BASE = {"barbell": BARS["barbell"], "ezBar": BARS["ezBar"],
        "dumbbellPair": BARS["dbHandle"], "dumbbellSingle": BARS["dbHandle"]}


def lattice(mode, max_kg=250.0):
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


def lattice_valid(kg, mode):
    if mode not in LAT:
        return True
    return any(abs(a - kg) < 1e-6 for a in LAT[mode])


# ------------------------------------------------------------- walk helpers --
def source_days(block):
    if block.get("inheritsDaysFrom"):
        return BLOCKS[block["inheritsDaysFrom"]].get("days", [])
    return block.get("days", [])


def all_prescriptions(days):
    for d in days:
        for s in d.get("sections", []):
            for p in s.get("prescriptions", []):
                yield d, s, p


OWN = [b for b in prog["blocks"] if not b.get("inheritsDaysFrom")]
OWN_DAYS = [d for b in OWN for d in b.get("days", [])]

# ============================================================== V1 schema ====
try:
    import jsonschema
    try:
        jsonschema.validate(prog, schema)
    except jsonschema.ValidationError as e:
        fail("V1", f"schema violation at {'/'.join(str(x) for x in e.path)}: {e.message}")
except ImportError:
    warn("V1 skipped — `pip install jsonschema` to enable full schema validation "
         "(structural gates V2-V11 still ran)")

# ======================================================== V2 references ======
for b in prog["blocks"]:
    for d, s, p in all_prescriptions(b.get("days", [])):
        if p["exerciseId"] not in LIB:
            fail("V2", f"{p['id']} -> unknown exerciseId {p['exerciseId']}")
        for sub in p.get("substitutes", []):
            if sub not in LIB:
                fail("V2", f"{p['id']} -> unknown substitute {sub}")
        for sec in b.get("days", []):
            pass
for b in prog["blocks"]:
    for d in b.get("days", []):
        for s in d.get("sections", []):
            for dr in s.get("drills", []):
                if dr["exerciseId"] not in LIB:
                    fail("V2", f"{d['id']}/{s['title']} drill -> unknown {dr['exerciseId']}")
for t in prog.get("strengthTargets", []):
    if t["exerciseId"] not in LIB:
        fail("V2", f"strengthTarget -> unknown exerciseId {t['exerciseId']}")

# ============================================================ V3 weeks =======
cover = collections.Counter()
for b in prog["blocks"]:
    for w in b["weeks"]:
        cover[w] += 1
for w in range(1, prog["totalWeeks"] + 1):
    if cover[w] != 1:
        fail("V3", f"week {w} covered {cover[w]} times, expected exactly 1")
for w in cover:
    if w > prog["totalWeeks"]:
        fail("V3", f"week {w} is beyond totalWeeks {prog['totalWeeks']}")

# ========================================================= V4 overrides ======
for b in prog["blocks"]:
    src = {d["id"]: d for d in source_days(b)}
    for did, ov in (b.get("dayOverrides") or {}).items():
        if did not in src:
            fail("V4", f"{b['id']}: override targets unknown day {did}")
            continue
        known = {p["id"] for s in src[did]["sections"] for p in s.get("prescriptions", [])}
        for pid in (ov.get("prescriptionOverrides") or {}):
            if pid not in known:
                fail("V4", f"{b['id']}/{did}: override targets unknown prescription {pid}")
        for wk, wov in (ov.get("weekSpecific") or {}).items():
            if int(wk) not in b["weeks"]:
                fail("V4", f"{b['id']}/{did}: weekSpecific {wk} not in this block's weeks")
            for pid in (wov.get("prescriptionOverrides") or {}):
                if pid not in known:
                    fail("V4", f"{b['id']}/{did}/wk{wk}: unknown prescription {pid}")

# ====================================================== V5 days xor inherit ==
for b in prog["blocks"]:
    has_days = bool(b.get("days"))
    has_inherit = bool(b.get("inheritsDaysFrom"))
    if has_days == has_inherit:
        fail("V5", f"{b['id']}: must have EITHER days OR inheritsDaysFrom "
                   f"(days={has_days}, inherits={has_inherit})")
    if has_inherit and b["inheritsDaysFrom"] not in BLOCKS:
        fail("V5", f"{b['id']}: inheritsDaysFrom '{b['inheritsDaysFrom']}' is not a block")

# ========================================================= V6 LATTICE ========
# The gate that would have caught v1's 19 unloadable starting weights.
checked = 0
for b in OWN:
    for d, s, p in all_prescriptions(b.get("days", [])):
        kg, mode = p.get("startLoadKg"), p["loadMode"]
        if kg is None or mode not in LAT:
            continue
        checked += 1
        if not lattice_valid(kg, mode):
            below = max([a for a in LAT[mode] if a <= kg], default=None)
            above = min([a for a in LAT[mode] if a >= kg], default=None)
            fail("V6", f"{p['id']} {p['exerciseId']}: {kg} kg is NOT loadable as {mode} "
                       f"(nearest {below} / {above})")

# ============================== V12 resolved loads in inherited blocks =======
# V6 only sees blocks that own their days. Deload multiplies every load by 0.70,
# which lands off-lattice — the engine snaps it, but assert the snap is sane and
# never collapses a light lift below the bare implement.
for b in prog["blocks"]:
    if not b.get("inheritsDaysFrom"):
        continue
    mult = b.get("loadMultiplier", 1.0)
    if abs(mult - 1.0) < 1e-9:
        continue
    for d, s, p in all_prescriptions(source_days(b)):
        kg, mode = p.get("startLoadKg"), p["loadMode"]
        if kg is None or mode not in LAT:
            continue
        target = kg * mult
        snapped = max([a for a in LAT[mode] if a <= target + 1e-9], default=None)
        if snapped is None:
            # Already at or near the bare implement — you cannot deload an empty bar.
            # Correct behaviour is to clamp to base and say so (docs/02 test B-3),
            # not to fail the build.
            warn(f"V12 {b['id']}: {p['id']} {p['exerciseId']} deloads to {target:.2f} kg, "
                 f"below the bare {mode} at {BASE[mode]:g} kg. The solver must clamp to "
                 f"{BASE[mode]:g} kg and show 'already at the bare implement'.")
        elif not lattice_valid(snapped, mode):
            fail("V12", f"{b['id']}/{p['id']}: resolved {target:.2f} kg snapped to {snapped}, "
                        f"which is not lattice-valid")

# ============================== V13 defaultRir is actually load-bearing ======
# Audit C2: v1 declared defaultRir on every block and never consumed it. If no
# prescription leaves targetRir null, the field is decorative again.
for b in OWN:
    if b.get("defaultRir") is None:
        continue
    nulls = sum(1 for _, _, p in all_prescriptions(b.get("days", []))
                if p.get("targetRir") is None and p["loadMode"] != "timed")
    if nulls == 0:
        fail("V13", f"{b['id']}: declares defaultRir={b['defaultRir']} but every prescription "
                    f"overrides it — the field is dead, and the deload will not soften anything")

# ====================================================== V7 rep ranges ========
for b in OWN:
    for d, s, p in all_prescriptions(b.get("days", [])):
        if p["repsMin"] > p["repsMax"]:
            fail("V7", f"{p['id']}: repsMin {p['repsMin']} > repsMax {p['repsMax']}")
        creep = p.get("repsCreepMax")
        if creep is not None and creep < p["repsMax"]:
            fail("V7", f"{p['id']}: repsCreepMax {creep} < repsMax {p['repsMax']}")

# ======================================================== V8 supersets =======
for b in OWN:
    for d in b.get("days", []):
        for s in d.get("sections", []):
            groups = collections.Counter(
                p["groupId"] for p in s.get("prescriptions", []) if p.get("groupId"))
            for g, n in groups.items():
                if n < 2:
                    fail("V8", f"{d['id']}/{s['title']}: groupId '{g}' has only {n} member")
            # a superset whose members need different loads on the SAME implement
            # forces a re-plate every round -- the thing that broke v1's time budget
            for g in groups:
                members = [p for p in s["prescriptions"] if p.get("groupId") == g]
                impl = collections.defaultdict(set)
                for p in members:
                    if p["loadMode"] in ("barbell", "ezBar", "dumbbellPair", "dumbbellSingle"):
                        fam = "db" if "dumbbell" in p["loadMode"] else p["loadMode"]
                        impl[fam].add(p.get("startLoadKg"))
                for fam, loads in impl.items():
                    if len(loads) > 1:
                        warn(f"V8 time: {d['id']} superset '{g}' needs {fam} at "
                             f"{sorted(loads)} — a re-plate every round")

# ============================================================ V9 units =======
OK_UNIT_MODES = {"sec": {"timed", "bodyweight", "dumbbellSingle", "dumbbellPair", "banded"},
                 "m": {"distance", "timed", "bodyweight"}}
for b in OWN:
    for d, s, p in all_prescriptions(b.get("days", [])):
        u = p.get("unit", "reps")
        if u in OK_UNIT_MODES and p["loadMode"] not in OK_UNIT_MODES[u]:
            fail("V9", f"{p['id']}: unit '{u}' with loadMode '{p['loadMode']}'")

# ==================================================== V10 reachability =======
used = set()
for b in prog["blocks"]:
    for d in b.get("days", []):
        for s in d.get("sections", []):
            for dr in s.get("drills", []):
                used.add(dr["exerciseId"])
            for p in s.get("prescriptions", []):
                used.add(p["exerciseId"])
                used.update(p.get("substitutes", []))
for t in prog.get("strengthTargets", []):
    used.add(t["exerciseId"])
orphans = sorted(set(LIB) - used)
if orphans:
    fail("V10", f"{len(orphans)} library exercises are unreachable: {', '.join(orphans)}")

# =========================================== V11 sixty-minute ceiling ========
CEIL = 60
for b in OWN:
    for d in b.get("days", []):
        if d["kind"] == "lift" and d["estMinutes"] > CEIL:
            fail("V11", f"{d['id']} '{d['title']}': {d['estMinutes']} min exceeds the "
                        f"{CEIL} min ceiling")
# the deload and push blocks inherit, so check the resolved set counts too
for b in prog["blocks"]:
    if not b.get("inheritsDaysFrom"):
        continue
    mult = b.get("setMultiplier", 1.0)
    for d in source_days(b):
        if d["kind"] != "lift":
            continue
        # push adds sets via overrides; approximate by scaling the source estimate
        extra = 0
        ov = (b.get("dayOverrides") or {}).get(d["id"], {})
        for pid, po in (ov.get("prescriptionOverrides") or {}).items():
            if "sets" in po:
                base = next((p["sets"] for s in d["sections"]
                             for p in s.get("prescriptions", []) if p["id"] == pid), 0)
                extra += max(0, po["sets"] - base) * 3.2   # ~190 s per heavy set
            if po.get("optional") is False:
                extra += 4.5
        est = d["estMinutes"] * mult + extra
        if est > CEIL:
            fail("V11", f"{b['id']}/{d['id']} resolves to ~{est:.0f} min, over the {CEIL} ceiling")

# ---------------------------------------------------- informational report ---
print("=" * 74)
print("DATA REPORT")
print("=" * 74)
print(f"programme      {prog['name']}  schema v{prog['schemaVersion']} rev {prog['revision']}")
print(f"start          {prog['startDate']}   {prog['totalWeeks']} weeks   "
      f"{len(prog['blocks'])} blocks")
print(f"exercises      {len(LIB)} in library, {len(used)} referenced")
print(f"loads checked  {checked} startLoadKg values against the lattice")
print(f"lattice step   barbell {LAT['barbell'][1]-LAT['barbell'][0]:.2f} kg  |  "
      f"dumbbell {LAT['dumbbellPair'][1]-LAT['dumbbellPair'][0]:.2f} kg per DB")

print("\nSESSION LENGTHS")
for b in OWN:
    for d in b.get("days", []):
        if d["kind"] == "rest":
            continue
        n = sum(p["sets"] for _, _, p in all_prescriptions([d]))
        flag = "  <-- OVER" if (d["kind"] == "lift" and d["estMinutes"] > CEIL) else ""
        opt = " (optional)" if d.get("optional") else ""
        print(f"  {b['id']:11s} {d['weekday']}  {d['title'][:26]:28s} "
              f"{d['estMinutes']:3d} min  {n:2d} sets{opt}{flag}")

print("\nWEEKLY SETS PER PRIMARY MUSCLE")
for bid in ("foundation", "build"):
    vol = collections.Counter()
    for d in BLOCKS[bid]["days"]:
        for s in d.get("sections", []):
            # cardio-day core circuits are real training volume — count them
            if s["type"] not in ("main", "finisher", "cardio"):
                continue
            for p in s["prescriptions"]:
                if p.get("optional"):
                    continue
                for m in LIB[p["exerciseId"]].get("primaryMuscles", []):
                    vol[m] += p["sets"]
    lo = [m for m, n in vol.items() if n < 6]
    hi = [m for m, n in vol.items() if n > 18]
    print(f"  {bid}: " + "  ".join(f"{m} {n}" for m, n in vol.most_common()))
    if lo:
        print(f"    low (<6):  {', '.join(lo)}")
    if hi:
        print(f"    high (>18): {', '.join(hi)}")

print("\nPUSH / PULL BALANCE PER LIFT DAY")
PUSH = {"horizontalPush", "verticalPush", "extension"}
PULL = {"horizontalPull", "verticalPull", "curl"}
for bid in ("foundation", "build"):
    for d in BLOCKS[bid]["days"]:
        if d["kind"] != "lift":
            continue
        push = pull = 0
        for _, s, p in all_prescriptions([d]):
            if s["type"] not in ("main", "finisher") or p.get("optional"):
                continue
            pat = LIB[p["exerciseId"]].get("pattern")
            if pat in PUSH:
                push += p["sets"]
            if pat in PULL:
                pull += p["sets"]
        # only meaningful on upper-focused days; a lower day carrying 3 sets of
        # pull-up negatives is deliberate, not an imbalance
        mark = ""
        if push + pull >= 8 and (push == 0 or pull == 0):
            mark = "  <-- UNBALANCED"
        elif push + pull >= 8 and max(push, pull) > 2 * min(push, pull):
            mark = "  <-- SKEWED"
        print(f"  {bid:11s} {d['weekday']}  {d['title'][:26]:28s} "
              f"push {push:2d}  pull {pull:2d}{mark}")

print("\nPATTERN FREQUENCY PER WEEK (build)")
freq = collections.Counter()
for d in BLOCKS["build"]["days"]:
    seen = set()
    for _, s, p in all_prescriptions([d]):
        if s["type"] in ("main", "finisher") and not p.get("optional"):
            seen.add(LIB[p["exerciseId"]].get("pattern"))
    for pat in seen:
        freq[pat] += 1
print("  " + "  ".join(f"{k} {v}x" for k, v in freq.most_common()))

print("\nMACRO ARITHMETIC")
for ph in prog["nutritionPhases"]:
    s = ph["proteinG"] * 4 + ph["carbsG"] * 4 + ph["fatG"] * 9
    d = ph["kcal"] - s
    ok = "ok" if abs(d) <= 25 else f"OFF BY {d:+d}"
    print(f"  weeks {ph['weeks'][0]}-{ph['weeks'][-1]}: stated {ph['kcal']}  "
          f"macros {s}  {ok}")

# --------------------------------------------------------------- verdict ----
print()
print("=" * 74)
if warnings:
    print(f"{len(warnings)} WARNING(S)")
    for w in warnings:
        print(f"  ! {w}")
    print()
if failures:
    print(f"FAILED — {len(failures)} gate violation(s)")
    for f in failures:
        print(f"  X {f}")
    sys.exit(1)
print("ALL GATES PASSED (V1-V13)")
sys.exit(0)
