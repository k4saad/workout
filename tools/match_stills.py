#!/usr/bin/env python3
"""Match our exercises against yuhonas/free-exercise-db and report.

Source licence: The Unlicense (public domain). Verified two ways —
LICENSE.md in the repo carries the Unlicense text, and GitHub's own licence
detection reports `unlicense` for the repository.

This script MATCHES and REPORTS. It downloads nothing on its own: run it,
read the report, then pass --download once the matches look right. A wrong
picture is worse than no picture, because a cue list with no image is fine
and a mislabelled demo teaches the wrong movement.

    python tools/match_stills.py
    python tools/match_stills.py --download
"""
import json, os, re, sys, urllib.request, difflib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
OUT_IMG = os.path.join(ROOT, "app", "assets", "exercises", "img")
FEDB_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
IMG_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

# Below this, a match is a guess rather than a match. A mislabelled demo is
# worse than none at all.
THRESHOLD = 0.82

STOP = {"with", "the", "a", "and", "of"}

# The implement is the DISTINGUISHING information, never a stop word.
#
# A first pass stripped these as noise, and matched barbell-bench-press to
# "Dumbbell Bench Press" at 0.95 confidence — the main lift of the programme,
# illustrated with the wrong implement. Equipment now has to agree.
EQUIPMENT = {
    "barbell": {"barbell", "ez", "olympic"},
    "dumbbell": {"dumbbell", "dumbbells", "db"},
    "cable": {"cable", "pulley"},
    "band": {"band", "bands", "banded", "resistance"},
    "machine": {"machine", "smith", "sled", "lever"},
    "bodyweight": {"bodyweight", "body"},
    "kettlebell": {"kettlebell", "kb"},
}


def implement(name):
    """Which implement a name implies, or None when it does not say."""
    ts = set(norm(name).split())
    for kind, words in EQUIPMENT.items():
        if ts & words:
            return kind
    return None


def norm(s):
    s = s.lower().replace("-", " ").replace("_", " ")
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    return " ".join(s.split())


def tokens(s):
    return {t for t in norm(s).split() if t not in STOP}


def score(a, b):
    """Blend token overlap with sequence similarity, then veto on equipment."""
    ta, tb = tokens(a), tokens(b)
    if not ta or not tb:
        return 0.0
    jac = len(ta & tb) / len(ta | tb)
    seq = difflib.SequenceMatcher(None, norm(a), norm(b)).ratio()
    base = 0.6 * jac + 0.4 * seq

    # Hard veto: a bench press illustrated with dumbbells is not a bench
    # press. If both sides name an implement and they disagree, it is not a
    # match at any similarity.
    ia, ib = implement(a), implement(b)
    if ia is not None and ib is not None and ia != ib:
        return 0.0
    return base


def load_fedb():
    cache = os.path.join(ROOT, "tools", ".fedb-cache.json")
    if os.path.exists(cache):
        with open(cache, encoding="utf-8-sig") as fh:
            return json.load(fh)
    print(f"fetching {FEDB_URL} ...")
    with urllib.request.urlopen(FEDB_URL, timeout=60) as r:
        data = json.loads(r.read().decode("utf-8"))
    with open(cache, "w", encoding="utf-8") as fh:
        json.dump(data, fh)
    return data


def main():
    download = "--download" in sys.argv

    with open(os.path.join(DATA, "exercises.json"), encoding="utf-8") as fh:
        ours = json.load(fh)
    fedb = load_fedb()

    # Only exercises that would benefit from a picture. A stretch or a run
    # does not need one, and matching them produces noise.
    SKIP_PATTERNS = ("run", "skipping", "hang", "stretch", "carry",
                     "time-trial", "bag", "cat-cow", "wall-slide")

    matched, missed, skipped = [], [], []

    for ex in ours["exercises"]:
        if any(p in ex["id"] for p in SKIP_PATTERNS):
            skipped.append(ex)
            continue

        hint = (ex.get("media") or {}).get("stillSearchTerm") or ex["name"]
        candidates = []
        for f in fedb:
            s = max(score(hint, f["name"]), score(ex["name"], f["name"]))
            for alias in ex.get("aliases", []):
                s = max(s, score(alias, f["name"]))
            candidates.append((s, f))
        candidates.sort(key=lambda x: -x[0])
        best, runner = candidates[0], candidates[1]

        if best[0] >= THRESHOLD and best[1].get("images"):
            matched.append((ex, best[1], best[0], runner[0]))
        else:
            missed.append((ex, best[1], best[0]))

    print("=" * 78)
    print(f"MATCHED {len(matched)}   MISSED {len(missed)}   "
          f"SKIPPED {len(skipped)} (no picture needed)")
    print("=" * 78)

    print("\n--- MATCHED ---")
    for ex, f, s, second in sorted(matched, key=lambda x: x[2]):
        gap = s - second
        flag = "  <-- CHECK: close runner-up" if gap < 0.05 else ""
        print(f"  {s:.2f}  {ex['id']:32s} -> {f['name']}{flag}")

    print("\n--- NO MATCH (cue list only; that is fine) ---")
    for ex, f, s in sorted(missed, key=lambda x: -x[2]):
        print(f"  {s:.2f}  {ex['id']:32s} (closest: {f['name']})")

    print("\n--- SKIPPED (a picture would not help) ---")
    print("  " + ", ".join(e["id"] for e in skipped))

    if not download:
        print("\nNothing downloaded. Re-run with --download once the matches "
              "above look right.")
        return

    os.makedirs(OUT_IMG, exist_ok=True)
    written = 0
    for ex, f, s, _ in matched:
        img = f["images"][0]
        dest = os.path.join(OUT_IMG, f"{ex['id']}.jpg")
        if os.path.exists(dest):
            continue
        try:
            with urllib.request.urlopen(IMG_BASE + img, timeout=60) as r:
                blob = r.read()
            with open(dest, "wb") as fh:
                fh.write(blob)
            written += 1
        except Exception as e:  # noqa: BLE001
            print(f"  failed {ex['id']}: {e}")

    # Record the provenance IN the data, per CLAUDE.md: never bundle an image
    # without its licence recorded.
    by_id = {e["id"]: e for e in ours["exercises"]}
    for ex, f, s, _ in matched:
        if not os.path.exists(os.path.join(OUT_IMG, f"{ex['id']}.jpg")):
            continue
        media = by_id[ex["id"]].setdefault("media", {})
        media["still"] = f"assets/exercises/img/{ex['id']}.jpg"
        media["stillLicence"] = (
            "Unlicense (public domain) - yuhonas/free-exercise-db, "
            f"source id {f['id']}"
        )
    with open(os.path.join(DATA, "exercises.json"), "w", encoding="utf-8",
              newline="\n") as fh:
        json.dump(ours, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    print(f"\ndownloaded {written} images to {OUT_IMG}")
    print("licences recorded in data/exercises.json")


if __name__ == "__main__":
    main()
