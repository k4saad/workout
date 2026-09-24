#!/usr/bin/env python3
"""Generate data/fuel.json — the Keller Twelve eating plan.

Same house rule as the loads: **nothing numeric is typed.** A meal is authored
as foods and a target, and the generator SOLVES the portions that hit it. Typing
"120 g rice, 150 g chicken, 480 kcal" is how a plan ends up 300 kcal short of
its own headline, which is exactly what happened to v1's macros.

Who this is for: Saad — 22, male, 167 cm, 50 kg, BMI 17.9, training five
evenings a week and trying to reach 55-60 kg. The hard part of his diet is not
protein, it is TOTAL CALORIES: 2,600 kcal at 50 kg is 52 kcal/kg, and that is a
lot of chewing. So the plan leans on calorie-dense food and two liquid meals a
day, which is the only way a small appetite hits that number five days a week.

Rules the food list obeys:
  - **Halal.** No pork, no gelatine of unstated origin, no alcohol, no vanilla
    extract. Meat is the halal butcher's or the supermarket's halal line.
  - **German supermarket.** Aldi, Lidl and Rewe own-brand staples, with the
    German shelf name, because that is what is on the shelf he stands in front of.
  - **Cheap per gram of protein.** Magerquark and eggs do the heavy lifting.
"""
import json, os, io, itertools

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data")
MIRROR = os.path.join(ROOT, "app", "assets", "nutrition")

failures = []
warnings = []


def fail(msg):
    failures.append(msg)


def warn(msg):
    warnings.append(msg)


# ---------------------------------------------------------------- the food ---
# Per 100 g as the LABEL states it (Nährwerte je 100 g), because that is what
# he can check against the packet in his hand. `pack` is the shelf size, which
# is what the grocery list has to round up to.
#
# kcal, protein, carbohydrate, fat.
F = lambda kcal, p, c, f, name, cat, pack, note=None: {
    "kcal": kcal, "proteinG": p, "carbsG": c, "fatG": f,
    "name": name, "category": cat, "packG": pack, "note": note,
}

FOODS = {
    # --- dairy and eggs: the cheapest protein in a German supermarket -------
    "magerquark": F(67, 12.0, 4.0, 0.3, "Magerquark", "dairy", 500,
                    "The backbone of this plan. 500 g is 60 g of protein for about a euro."),
    "skyr": F(63, 11.0, 4.0, 0.2, "Skyr natur", "dairy", 450),
    "huettenkaese": F(98, 12.5, 3.0, 4.2, "Hüttenkäse", "dairy", 200),
    "vollmilch": F(64, 3.4, 4.8, 3.5, "Vollmilch 3,5 %", "dairy", 1000,
                   "Whole milk, not skimmed. You are trying to gain weight."),
    "griech_joghurt": F(133, 4.0, 4.0, 10.0, "Griechischer Joghurt 10 %", "dairy", 500),
    "gouda": F(356, 25.0, 0.0, 28.0, "Gouda jung, am Stück", "dairy", 400,
               "Check the label says mikrobielles Lab — animal rennet is not halal."),
    "eier": F(137, 12.6, 0.6, 9.5, "Eier Größe M", "dairy", 580,
              "One egg is about 58 g. A 10-pack is 580 g."),
    "whey": F(380, 78.0, 6.0, 5.0, "Whey Protein neutral", "supplement", 1000,
              "Neutral, not flavoured: flavoured tubs often carry undeclared alcohol carriers."),

    # --- meat and fish, halal ----------------------------------------------
    "haehnchenbrust": F(106, 23.0, 0.0, 1.5, "Hähnchenbrustfilet (halal)", "meat", 500),
    "haehnchenschenkel": F(172, 18.0, 0.0, 11.0, "Hähnchenschenkel (halal)", "meat", 600,
                           "Cheaper and far more forgiving in a pan than breast."),
    "rinderhack": F(212, 19.0, 0.0, 15.0, "Rinderhackfleisch 15 % (halal)", "meat", 500),
    "thunfisch": F(108, 24.0, 0.0, 1.0, "Thunfisch im eigenen Saft", "fish", 150,
                   "Drained weight. A tin is about 150 g in, 110 g out."),
    "lachs": F(208, 20.0, 0.0, 14.0, "Lachsfilet TK", "fish", 400),

    # --- legumes and plant protein -----------------------------------------
    "linsen_rot": F(347, 24.0, 52.0, 1.5, "Rote Linsen, trocken", "legume", 500),
    "kichererbsen": F(122, 6.5, 16.0, 2.6, "Kichererbsen (Dose, abgetropft)", "legume", 265),
    "kidneybohnen": F(116, 7.0, 15.0, 0.6, "Kidneybohnen (Dose, abgetropft)", "legume", 265),
    "tofu": F(144, 15.0, 1.0, 8.5, "Tofu natur", "legume", 400),

    # --- starches -----------------------------------------------------------
    "haferflocken": F(372, 13.0, 59.0, 7.0, "Haferflocken zart", "grain", 500,
                      "Weigh them dry. Cooked oats are mostly water."),
    "reis": F(350, 7.5, 77.0, 0.9, "Basmatireis, roh", "grain", 1000,
              "Dry weight. 100 g dry is roughly 260 g cooked."),
    "nudeln": F(340, 13.0, 62.0, 2.5, "Vollkornnudeln, roh", "grain", 500),
    "couscous": F(358, 12.0, 72.0, 1.0, "Couscous, roh", "grain", 500),
    "bulgur": F(342, 12.0, 69.0, 1.3, "Bulgur, roh", "grain", 500),
    "kartoffeln": F(70, 2.0, 15.0, 0.1, "Kartoffeln", "veg", 2500),
    "suesskartoffel": F(86, 1.6, 20.0, 0.1, "Süßkartoffel", "veg", 1000),
    "vollkornbrot": F(210, 7.0, 36.0, 1.5, "Vollkornbrot", "grain", 500,
                      "A slice is about 45 g."),

    # --- fruit and fast sugar ----------------------------------------------
    "banane": F(89, 1.1, 21.0, 0.3, "Banane", "fruit", 120,
                "A medium banana is about 120 g peeled."),
    "datteln": F(282, 2.5, 65.0, 0.4, "Datteln, getrocknet", "fruit", 200,
                 "Sunnah, and the densest carbohydrate on the shelf."),
    "rosinen": F(299, 3.1, 71.0, 0.5, "Rosinen", "fruit", 200),
    "honig": F(304, 0.3, 75.0, 0.0, "Honig", "fruit", 500),
    "apfel": F(52, 0.3, 12.0, 0.2, "Apfel", "fruit", 180),
    "orange": F(47, 0.9, 9.4, 0.1, "Orange", "fruit", 200),

    # --- fats ---------------------------------------------------------------
    "erdnussmus": F(588, 25.0, 12.0, 50.0, "Erdnussmus (100 % Erdnüsse)", "fat", 350,
                    "Ingredients should read: peanuts. Maybe salt."),
    "mandeln": F(579, 21.0, 9.0, 50.0, "Mandeln", "fat", 200),
    "walnuesse": F(654, 15.0, 7.0, 65.0, "Walnüsse", "fat", 200),
    "olivenoel": F(884, 0.0, 0.0, 100.0, "Olivenöl", "fat", 500),
    "rapsoel": F(884, 0.0, 0.0, 100.0, "Rapsöl", "fat", 1000),
    "tahin": F(595, 17.0, 10.0, 54.0, "Sesammus (Tahin)", "fat", 300),
    "avocado": F(160, 2.0, 2.0, 15.0, "Avocado", "fat", 200),

    # --- vegetables ---------------------------------------------------------
    "spinat_tk": F(24, 2.9, 1.0, 0.4, "Blattspinat TK", "veg", 450),
    "brokkoli": F(34, 2.8, 4.0, 0.4, "Brokkoli", "veg", 500),
    "tomaten": F(18, 0.9, 3.0, 0.2, "Tomaten", "veg", 500),
    "gurke": F(15, 0.7, 2.0, 0.1, "Gurke", "veg", 400),
    "paprika": F(31, 1.0, 6.0, 0.3, "Paprika", "veg", 400),
    "zwiebel": F(40, 1.1, 7.0, 0.1, "Zwiebel", "veg", 1000),
    "karotten": F(41, 0.9, 8.0, 0.2, "Karotten", "veg", 1000),
    "passata": F(35, 1.5, 6.0, 0.2, "Passierte Tomaten", "veg", 500),
}

# Nothing on this list may contain these. The gate checks the names too, so a
# future edit that adds "Schinken" fails rather than quietly shipping.
HARAM = ["schwein", "schinken", "speck", "bacon", "pork", "ham ", "lard",
         "wein", "wine", "bier", "beer", "rum", "likör", "alkohol",
         "gelatine", "gelatin"]


# ------------------------------------------------------------- the schedule --
# Slots are placed around an 18:30-19:30 session. `days` says which kind of day
# the slot belongs to: the two training-day slots collapse into one afternoon
# meal on a rest day, carrying the same calories and protein.
# A slot's protein target also sets its protein DENSITY, and a density has to
# be reachable with real food AND produce a portion worth putting on a plate.
#
# The first cut of this file targeted the programme's 110 g of protein spread
# evenly, and solved "chicken, rice and broccoli" to SIXTY GRAMS of chicken --
# a third of a breast -- because the rice was carrying the protein instead.
# Meals built around a real portion (a tin of tuna, a breast, 150 g of mince)
# carry 25-35 g each, so the protein-bearing slots are targeted there and the
# day lands near 130 g.
#
# That is deliberate, and it is why the day gate treats protein as a FLOOR
# rather than a band: for someone at 50 kg trying to reach 60, CALORIES are
# what must be precise. Protein above the target is harmless; protein below it
# wastes the training. The only ceiling is a sanity one, because protein
# crowding out carbohydrate is a real way to stall a hardgainer.
SLOTS = [
    ("breakfast",     "Breakfast",          "07:30", "both",     540, 22),
    ("mid_morning",   "Mid-morning",        "10:30", "both",     330, 10),
    ("lunch",         "Lunch",              "13:00", "both",     560, 30),
    ("pre_training",  "Before training",    "17:00", "training", 250, 3),
    ("post_training", "Straight after",     "19:45", "training", 280, 24),
    ("afternoon",     "Afternoon",          "17:00", "rest",     530, 27),
    ("dinner",        "Dinner",             "20:45", "both",     520, 32),
    ("before_bed",    "Before bed",         "22:30", "both",     120, 10),
]

# Every template: fixed grams where the amount is the point (one banana, two
# slices of bread), and two FLEX foods whose grams the generator solves so the
# meal lands on its slot targets. Rounded to 5 g, because nobody weighs 37 g
# of oats.
#
# (slot, id, name, note, fixed[(food, g)], flex(lighter_food, protein_food))
TEMPLATES = [
    # ---- breakfast: 540 kcal, 22 P ----------------------------------------
    ("breakfast", "porridge_pb", "Porridge with peanut butter",
     "Cook the oats in the milk, not water. Stir the peanut butter in at the end.",
     [("erdnussmus", 20), ("banane", 120)], ("haferflocken", "vollmilch")),
    ("breakfast", "eggs_bread", "Eggs on wholemeal bread",
     "Scrambled in the oil, with a sliced tomato.",
     [("rapsoel", 8), ("tomaten", 80)], ("vollkornbrot", "eier")),
    ("breakfast", "quark_oats", "Overnight oats with quark",
     "Made the night before. The one breakfast that survives oversleeping.",
     [("rosinen", 25), ("honig", 15)], ("haferflocken", "magerquark")),

    # ---- mid-morning: 330 kcal, 10 P --------------------------------------
    ("mid_morning", "dates_nuts", "Dates, almonds and a glass of milk",
     "Pocket food. The milk is what makes it a meal rather than a snack.",
     [("vollmilch", 150)], ("datteln", "mandeln")),
    ("mid_morning", "bread_cheese", "Bread, cheese and an apple",
     "Two slices, sliced Gouda, an apple on the walk.",
     [("tomaten", 80), ("apfel", 180)], ("vollkornbrot", "gouda")),
    ("mid_morning", "banana_shake", "Banana milk",
     "Blended, or just shaken in a bottle on the way out. No whey in this "
     "one: a 10 g slot has no room for it, and pretending otherwise would "
     "have solved to a 3 g scoop.",
     [("honig", 10)], ("banane", "vollmilch")),

    # ---- lunch: 560 kcal, 30 P --------------------------------------------
    ("lunch", "chicken_rice", "Chicken, rice and broccoli",
     "Cook the rice for two days at once.",
     [("brokkoli", 150), ("rapsoel", 10)], ("reis", "haehnchenbrust")),
    ("lunch", "lentil_bulgur", "Red lentils with bulgur",
     "Mercimek. Cheap, filling, and it reheats better than it cooks.",
     [("zwiebel", 60), ("olivenoel", 8), ("passata", 100)], ("bulgur", "linsen_rot")),
    ("lunch", "tuna_pasta", "Tuna pasta",
     "Tuna, wholemeal pasta, passata. Fifteen minutes.",
     [("passata", 150), ("olivenoel", 10), ("paprika", 80)], ("nudeln", "thunfisch")),
    ("lunch", "mince_potato", "Mince and potatoes",
     "Halal beef mince, potatoes, whatever vegetable is in the drawer.",
     [("karotten", 100), ("zwiebel", 50)], ("kartoffeln", "rinderhack")),

    # ---- before training: 250 kcal, 3 P -----------------------------------
    ("pre_training", "banana_dates", "Banana and dates",
     "Ninety minutes before you go down. Nothing heavy, nothing fatty.",
     [], ("datteln", "banane")),
    ("pre_training", "rice_honey", "Rice with honey",
     "If the dates are gone. Fast, boring, works.",
     [("banane", 120)], ("honig", "reis")),
    ("pre_training", "oat_shake", "Oats and dates, blended",
     "When the day got away from you and it has to be liquid. No milk this "
     "close to training -- fat and protein sit in the stomach.",
     [("honig", 10)], ("datteln", "haferflocken")),

    # ---- straight after: 280 kcal, 24 P -----------------------------------
    ("post_training", "whey_banana", "Whey and banana",
     "Drink it in the basement, before you shower. This is the easy 24 g.",
     [("banane", 120)], ("vollmilch", "whey")),
    ("post_training", "quark_honey", "Quark with honey",
     "If the whey has run out. Slower, just as good.",
     [("honig", 20), ("rosinen", 20)], ("vollmilch", "magerquark")),
    ("post_training", "milk_oats", "Oats, milk and quark",
     "The cheapest 24 g of protein in this plan.",
     [("vollmilch", 200), ("honig", 15)], ("haferflocken", "magerquark")),

    # ---- rest-day afternoon: 530 kcal, 27 P -------------------------------
    ("afternoon", "chickpea_couscous", "Lentils and couscous",
     "Rest-day second lunch. No cooking beyond a kettle.",
     [("olivenoel", 12), ("paprika", 80), ("zwiebel", 40)],
     ("couscous", "linsen_rot")),
    ("afternoon", "eggs_bread_big", "Eggs, bread and avocado",
     "A rest day still has to hit the number.",
     [("avocado", 70), ("tomaten", 80)], ("vollkornbrot", "eier")),
    ("afternoon", "quark_bowl", "Quark bowl",
     "Quark, oats, fruit, nut butter. Two minutes.",
     [("erdnussmus", 20), ("banane", 120)], ("haferflocken", "magerquark")),

    # ---- dinner: 520 kcal, 32 P -------------------------------------------
    ("dinner", "salmon_potato", "Salmon and potatoes",
     "Frozen fillet, oven, done.",
     [("brokkoli", 120), ("olivenoel", 6)], ("kartoffeln", "lachs")),
    ("dinner", "tofu_stirfry", "Tofu and vegetables",
     "Whatever is in the drawer, hot pan, soy sauce.",
     [("paprika", 100), ("zwiebel", 50), ("rapsoel", 8)], ("reis", "tofu")),
    ("dinner", "chicken_salad", "Chicken, bread and salad",
     "The one to cook when you got home late and still have to eat properly.",
     [("gurke", 100), ("tomaten", 100), ("olivenoel", 8)],
     ("vollkornbrot", "haehnchenbrust")),

    # ---- before bed: 120 kcal, 10 P ---------------------------------------
    ("before_bed", "quark_small", "Quark",
     "Slow protein overnight. Non-negotiable on training days.",
     [], ("vollmilch", "magerquark")),
    ("before_bed", "skyr_small", "Skyr",
     "Same job, different tub.",
     [], ("vollmilch", "skyr")),
    ("before_bed", "milk_glass", "Warm milk and cottage cheese",
     "When you cannot face another spoonful of quark.",
     [("honig", 10)], ("vollmilch", "huettenkaese")),
]

# Phase modules. The base day is 2,600 kcal; the later phases ADD to it rather
# than being authored again, because three separate plans is three things to
# keep in step.
MODULES = [
    ("phase2", "Weeks 5-8: +150", 150, 5,
     "TDEE rose with your bodyweight. Add this to any meal.",
     [("erdnussmus", 25)]),
    ("phase3", "Weeks 9-12: +300", 300, 10,
     "Final push. Split it: half in the morning, half after training.",
     [("erdnussmus", 25), ("haferflocken", 40)]),
    ("boost250", "Stalled: +250", 250, 8,
     "The scale has not moved for two weeks. This is the fix, and it stays "
     "applied until the scale moves again.",
     [("erdnussmus", 20), ("datteln", 40)]),
]

SUPPLEMENTS = [
    ("creatine", "Creatine monohydrate", "5 g", "any time, daily",
     "The only supplement here with strong evidence behind it. Unflavoured "
     "monohydrate; nothing else is worth the money."),
    ("vitamin_d", "Vitamin D3", "1000-2000 IU", "with a meal containing fat",
     "Münster, indoors, training in a basement. Between October and March "
     "almost everyone at this latitude is short of it."),
    ("whey_supp", "Whey protein", "1 scoop", "straight after training",
     "Convenience, not magic. It is there so the post-training 25 g happens "
     "on a night you cannot face cooking."),
]

HYDRATION = {
    "dailyMl": 3000,
    "trainingExtraMl": 700,
    "note": "Three litres, plus about 700 ml across a session. Dark urine in "
            "the morning means yesterday was short.",
}

GUIDE = [
    ("Meat", "The halal butcher, or the supermarket's halal line. Lidl and "
             "Rewe both stock halal chicken in most Münster branches; the "
             "Turkish grocers on Wolbecker Straße are cheaper and better."),
    ("Cheese", "Look for mikrobielles Lab or vegetarisches Lab on the label. "
               "Animal rennet is the default in a lot of German cheese and it "
               "is usually calf."),
    ("Gelatine", "In yoghurts, gummy sweets, some protein bars and a lot of "
                 "desserts. If the label says Gelatine without saying Rind, "
                 "assume pork."),
    ("Flavourings", "Vanilla extract and some flavoured whey carry alcohol as "
                    "a carrier. Neutral whey avoids the question entirely."),
    ("Reading a label", "Nährwerte je 100 g is what this plan is built on. "
                        "Compare per 100 g, never per portion — the portion on "
                        "the packet is whatever flatters the number."),
]


# ------------------------------------------------------------------ solving --
def macros(items):
    """Sum a list of (food_id, grams)."""
    t = {"kcal": 0.0, "proteinG": 0.0, "carbsG": 0.0, "fatG": 0.0}
    for fid, g in items:
        f = FOODS[fid]
        for k in t:
            t[k] += f[k] * g / 100.0
    return t


def solve(fixed, flex_a, flex_b, kcal_target, protein_target):
    """Grams of the two flex foods that land the meal on its targets.

    Two equations, two unknowns:
        kcal_a/100 * ga + kcal_b/100 * gb = kcal still needed
        prot_a/100 * ga + prot_b/100 * gb = protein still needed

    Rounded to 5 g afterwards — the rounding error is what the tolerance gate
    then has to accept, and it is worth it for a number he can actually weigh.
    """
    base = macros(fixed)
    need_k = kcal_target - base["kcal"]
    need_p = protein_target - base["proteinG"]

    a, b = FOODS[flex_a], FOODS[flex_b]
    a1, b1 = a["kcal"] / 100.0, b["kcal"] / 100.0
    a2, b2 = a["proteinG"] / 100.0, b["proteinG"] / 100.0

    det = a1 * b2 - a2 * b1
    if abs(det) < 1e-9:
        return None, None  # the two foods are macro-parallel: unsolvable
    ga = (need_k * b2 - need_p * b1) / det
    gb = (a1 * need_p - a2 * need_k) / det
    return round(ga / 5) * 5, round(gb / 5) * 5


SLOT_BY_ID = {s[0]: s for s in SLOTS}
built = []

for slot_id, tid, name, note, fixed, (flex_a, flex_b) in TEMPLATES:
    slot = SLOT_BY_ID[slot_id]
    kcal_t, prot_t = slot[4], slot[5]
    ga, gb = solve(fixed, flex_a, flex_b, kcal_t, prot_t)

    if ga is None:
        fail(f"{tid}: {flex_a} and {flex_b} cannot solve — same macro ratio")
        continue
    if ga < 5 or gb < 5:
        fail(f"{tid}: solved to {flex_a} {ga} g, {flex_b} {gb} g. A negative or "
             f"zero portion means the fixed items already overshoot the slot.")
        continue

    items = list(fixed) + [(flex_a, ga), (flex_b, gb)]
    # Merge a flex food that is also fixed, so nothing is listed twice.
    merged = {}
    order = []
    for fid, g in items:
        if fid not in merged:
            order.append(fid)
            merged[fid] = 0
        merged[fid] += g
    items = [(fid, merged[fid]) for fid in order]

    m = macros(items)
    built.append({
        "id": tid, "slotId": slot_id, "name": name, "note": note,
        "items": [{"foodId": fid, "grams": g} for fid, g in items],
        "kcal": round(m["kcal"]),
        "proteinG": round(m["proteinG"], 1),
        "carbsG": round(m["carbsG"], 1),
        "fatG": round(m["fatG"], 1),
    })

    dk = m["kcal"] - kcal_t
    if abs(dk) > kcal_t * 0.06:
        fail(f"{tid}: {m['kcal']:.0f} kcal against a {kcal_t} target ({dk:+.0f})")
    dp = m["proteinG"] - prot_t
    if abs(dp) > max(3.0, prot_t * 0.12):
        fail(f"{tid}: {m['proteinG']:.0f} g protein against a {prot_t} target ({dp:+.0f})")

# ------------------------------------------------------- the whole-day gate --
# Every combination he could pick has to land on the phase. Rather than walking
# 3^7 of them, take the lightest and heaviest template in each slot: if both
# extremes are inside the tolerance, everything between them is too.
PHASES = [
    ("weeks 1-4", 2600, 110, None),
    ("weeks 5-8", 2750, 115, "phase2"),
    ("weeks 9-12", 2900, 120, "phase3"),
]
MODULE_BY_ID = {m[0]: m for m in MODULES}

for day_kind, slot_ids in [
    ("training", ["breakfast", "mid_morning", "lunch", "pre_training",
                  "post_training", "dinner", "before_bed"]),
    ("rest", ["breakfast", "mid_morning", "lunch", "afternoon", "dinner",
              "before_bed"]),
]:
    for label, kcal_t, prot_t, module_id in PHASES:
        add = macros(MODULE_BY_ID[module_id][5]) if module_id else {
            "kcal": 0, "proteinG": 0, "carbsG": 0, "fatG": 0}

        lo = {"kcal": add["kcal"], "proteinG": add["proteinG"], "fatG": add["fatG"]}
        hi = dict(lo)
        for sid in slot_ids:
            opts = [t for t in built if t["slotId"] == sid]
            if not opts:
                fail(f"slot {sid} has no meals")
                continue
            for key in lo:
                lo[key] += min(t[key] for t in opts)
                hi[key] += max(t[key] for t in opts)

        for bound, tot in (("lightest", lo), ("heaviest", hi)):
            d = tot["kcal"] - kcal_t
            if abs(d) > kcal_t * 0.03:
                fail(f"{day_kind} {label}, {bound} day: {tot['kcal']:.0f} kcal "
                     f"against {kcal_t} ({d:+.0f}, over the 3 % band)")
            # A FLOOR, not a band. Calories drive the weight gain and are
            # held to 3 %; protein below the target wastes the training, and
            # protein above it is harmless until it starts crowding out the
            # carbohydrate a hardgainer needs. Hence the sanity ceiling.
            p = tot["proteinG"]
            if p < prot_t:
                fail(f"{day_kind} {label}, {bound} day: {p:.0f} g protein, "
                     f"under the {prot_t} g floor")
            if p > prot_t * 1.45:
                fail(f"{day_kind} {label}, {bound} day: {p:.0f} g protein is "
                     f"more than 145 % of {prot_t} -- it displaces carbs")
            if tot["fatG"] < 40:
                fail(f"{day_kind} {label}, {bound} day: {tot['fatG']:.0f} g fat "
                     f"— below the 40 g floor hormones need")

# ------------------------------------------------------------- halal check ---
for fid, f in FOODS.items():
    hay = (f["name"] + " " + (f["note"] or "")).lower()
    for bad in HARAM:
        # The buying guide TALKS about gelatine and pork to warn him off them;
        # what matters is that no food IS one.
        if bad in f["name"].lower():
            fail(f"{fid}: {f['name']} contains '{bad}'")

for t in built:
    for it in t["items"]:
        if it["foodId"] not in FOODS:
            fail(f"{t['id']}: unknown food '{it['foodId']}'")

# ------------------------------------------------------------------ write ----
if failures:
    print("FAILED — nothing written")
    for f in failures:
        print(f"  X {f}")
    raise SystemExit(1)

doc = {
    "schemaVersion": 1,
    "generatedBy": "tools/gen_fuel.py",
    "note": "Generated. Every gram is solved to hit a slot target; do not hand-edit.",
    "athlete": {"heightCm": 167, "startWeightKg": 50.0, "targetWeightKg": 60.0},
    "foods": [
        {"id": fid, **{k: v for k, v in f.items() if v is not None}}
        for fid, f in FOODS.items()
    ],
    "slots": [
        {"id": i, "name": n, "time": t, "days": d, "kcal": k, "proteinG": p}
        for i, n, t, d, k, p in SLOTS
    ],
    "meals": built,
    "modules": [
        {"id": i, "name": n, "kcal": k, "proteinG": p, "note": note,
         "items": [{"foodId": f, "grams": g} for f, g in items]}
        for i, n, k, p, note, items in MODULES
    ],
    "phases": [
        {"weeks": w, "kcal": k, "proteinG": p, "moduleId": m}
        for w, k, p, m in [
            ([1, 2, 3, 4], 2600, 110, None),
            ([5, 6, 7, 8], 2750, 115, "phase2"),
            ([9, 10, 11, 12], 2900, 120, "phase3"),
        ]
    ],
    "supplements": [
        {"id": i, "name": n, "dose": d, "timing": t, "note": note}
        for i, n, d, t, note in SUPPLEMENTS
    ],
    "hydration": HYDRATION,
    "buyingGuide": [{"title": t, "body": b} for t, b in GUIDE],
}

os.makedirs(MIRROR, exist_ok=True)
raw = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
for path in (os.path.join(OUT, "fuel.json"), os.path.join(MIRROR, "fuel.json")):
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(raw)

print(f"fuel.json          {len(raw.encode('utf-8')):>8,} bytes   "
      f"{len(FOODS)} foods, {len(built)} meals across {len(SLOTS)} slots")
if warnings:
    print(f"\n{len(warnings)} warning(s)")
    for w in warnings:
        print(f"  ! {w}")

print("\nthe day, as solved:")
for sid, name, time, days, kcal_t, prot_t in SLOTS:
    opts = [t for t in built if t["slotId"] == sid]
    ks = "-".join(str(t["kcal"]) for t in (min(opts, key=lambda t: t["kcal"]),
                                           max(opts, key=lambda t: t["kcal"])))
    print(f"  {time}  {name:18s} {days:8s} target {kcal_t:4d} kcal / {prot_t:2d} P"
          f"   built {ks} kcal, {len(opts)} choices")
