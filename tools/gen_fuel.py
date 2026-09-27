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
  - **German supermarket.** Aldi, Lidl and Rewe own-brand staples, named in
    English (v0.14.1: the app is in English; the German shelf names read as
    noise to him). Only the halal guide keeps a German label word, in
    brackets, where the point is to find that word on the packet.
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
# Per 100 g as the LABEL states it, because that is what he can check
# against the packet in his hand. `pack` is the shelf size, which
# is what the grocery list has to round up to.
#
# kcal, protein, carbohydrate, fat.
F = lambda kcal, p, c, f, name, cat, pack, note=None: {
    "kcal": kcal, "proteinG": p, "carbsG": c, "fatG": f,
    "name": name, "category": cat, "packG": pack, "note": note,
}

FOODS = {
    # --- dairy and eggs: the cheapest protein in a German supermarket -------
    "magerquark": F(67, 12.0, 4.0, 0.3, "Low-fat quark", "dairy", 500,
                    "The backbone of this plan. 500 g is 60 g of protein for about a euro."),
    "skyr": F(63, 11.0, 4.0, 0.2, "Skyr, plain", "dairy", 450),
    "huettenkaese": F(98, 12.5, 3.0, 4.2, "Cottage cheese", "dairy", 200),
    "vollmilch": F(64, 3.4, 4.8, 3.5, "Whole milk 3.5 %", "dairy", 1000,
                   "Whole milk, not skimmed. You are trying to gain weight."),
    "griech_joghurt": F(133, 4.0, 4.0, 10.0, "Greek yoghurt 10 %", "dairy", 500),
    "gouda": F(356, 25.0, 0.0, 28.0, "Young Gouda, in a block", "dairy", 400,
               "Check the rennet is microbial (the label says mikrobielles Lab) — "
               "animal rennet is not halal."),
    "eier": F(137, 12.6, 0.6, 9.5, "Eggs, size M", "dairy", 580,
              "One egg is about 58 g. A 10-pack is 580 g."),
    "whey": F(380, 78.0, 6.0, 5.0, "Whey protein, unflavoured", "supplement", 1000,
              "Neutral, not flavoured: flavoured tubs often carry undeclared alcohol carriers."),

    # --- meat and fish, halal ----------------------------------------------
    "haehnchenbrust": F(106, 23.0, 0.0, 1.5, "Chicken breast fillet (halal)", "meat", 500),
    "haehnchenschenkel": F(172, 18.0, 0.0, 11.0, "Chicken legs (halal)", "meat", 600,
                           "Cheaper and far more forgiving in a pan than breast."),
    "haehnchen_ok": F(125, 19.5, 0.0, 5.0, "Boneless chicken thighs (halal)",
                      "meat", 600,
                      "Boneless thigh: cheaper than breast, and it stays juicy "
                      "when it is cooked on Sunday and eaten on Tuesday."),
    "rinderhack": F(212, 19.0, 0.0, 15.0, "Beef mince 15 % (halal)", "meat", 500),
    "thunfisch": F(108, 24.0, 0.0, 1.0, "Tuna in its own juice", "fish", 150,
                   "Drained weight. A tin is about 150 g in, 110 g out."),
    "lachs": F(208, 20.0, 0.0, 14.0, "Salmon fillet, frozen", "fish", 400),

    # --- legumes and plant protein -----------------------------------------
    "linsen_rot": F(347, 24.0, 52.0, 1.5, "Red lentils, dry", "legume", 500),
    "kichererbsen": F(122, 6.5, 16.0, 2.6, "Chickpeas (tin, drained)", "legume", 265),
    "kidneybohnen": F(116, 7.0, 15.0, 0.6, "Kidney beans (tin, drained)", "legume", 265),
    "tofu": F(144, 15.0, 1.0, 8.5, "Tofu, plain", "legume", 400),

    # --- starches -----------------------------------------------------------
    "haferflocken": F(372, 13.0, 59.0, 7.0, "Rolled oats", "grain", 500,
                      "Weigh them dry. Cooked oats are mostly water."),
    "reis": F(350, 7.5, 77.0, 0.9, "Basmati rice, dry", "grain", 1000,
              "Dry weight. 100 g dry is roughly 260 g cooked."),
    "nudeln": F(340, 13.0, 62.0, 2.5, "Wholemeal pasta, dry", "grain", 500),
    "couscous": F(358, 12.0, 72.0, 1.0, "Couscous, dry", "grain", 500),
    "bulgur": F(342, 12.0, 69.0, 1.3, "Bulgur, dry", "grain", 500),
    "kartoffeln": F(70, 2.0, 15.0, 0.1, "Potatoes", "veg", 2500),
    "suesskartoffel": F(86, 1.6, 20.0, 0.1, "Sweet potato", "veg", 1000),
    "vollkornbrot": F(210, 7.0, 36.0, 1.5, "Wholemeal bread", "grain", 500,
                      "A slice is about 45 g."),

    # --- fruit and fast sugar ----------------------------------------------
    "banane": F(89, 1.1, 21.0, 0.3, "Banana", "fruit", 120,
                "A medium banana is about 120 g peeled."),
    "datteln": F(282, 2.5, 65.0, 0.4, "Dates, dried", "fruit", 200,
                 "Sunnah, and the densest carbohydrate on the shelf."),
    "rosinen": F(299, 3.1, 71.0, 0.5, "Raisins", "fruit", 200),
    "honig": F(304, 0.3, 75.0, 0.0, "Honey", "fruit", 500),
    "apfel": F(52, 0.3, 12.0, 0.2, "Apple", "fruit", 180),
    "orange": F(47, 0.9, 9.4, 0.1, "Orange", "fruit", 200),

    # --- fats ---------------------------------------------------------------
    "erdnussmus": F(588, 25.0, 12.0, 50.0, "Peanut butter (100 % peanuts)", "fat", 350,
                    "Ingredients should read: peanuts. Maybe salt."),
    "mandeln": F(579, 21.0, 9.0, 50.0, "Almonds", "fat", 200),
    "walnuesse": F(654, 15.0, 7.0, 65.0, "Walnuts", "fat", 200),
    "olivenoel": F(884, 0.0, 0.0, 100.0, "Olive oil", "fat", 500),
    "rapsoel": F(884, 0.0, 0.0, 100.0, "Rapeseed oil", "fat", 1000),
    "tahin": F(595, 17.0, 10.0, 54.0, "Tahini (sesame paste)", "fat", 300),
    "avocado": F(160, 2.0, 2.0, 15.0, "Avocado", "fat", 200),

    # --- vegetables ---------------------------------------------------------
    "spinat_tk": F(24, 2.9, 1.0, 0.4, "Leaf spinach, frozen", "veg", 450),
    "brokkoli": F(34, 2.8, 4.0, 0.4, "Broccoli", "veg", 500),
    "tomaten": F(18, 0.9, 3.0, 0.2, "Tomatoes", "veg", 500),
    "gurke": F(15, 0.7, 2.0, 0.1, "Cucumber", "veg", 400),
    "paprika": F(31, 1.0, 6.0, 0.3, "Bell pepper", "veg", 400),
    "zwiebel": F(40, 1.1, 7.0, 0.1, "Onion", "veg", 1000),
    "karotten": F(41, 0.9, 8.0, 0.2, "Carrots", "veg", 1000),
    "passata": F(35, 1.5, 6.0, 0.2, "Passata", "veg", 500),
    "gemuese_tk": F(45, 2.5, 6.0, 0.5, "Mixed vegetables, frozen", "veg", 750,
                    "Frozen mixed vegetables: cheaper than fresh, already cut, "
                    "and nothing goes off in the drawer."),
}

# ---------------------------------------------------------------- prices ---
# Euro per kilo, as a German discounter (Aldi, Lidl, Netto) shelf price in
# 2026 — ESTIMATES, to plan a week by, not a receipt. For tins and anything
# sold drained, per kilo of what is eaten. The app says so where it shows a
# number. He is a student: the default week averages about six euros a
# day, and no day of it costs more than seven.
PRICES = {
    "magerquark": 2.40, "skyr": 3.10, "huettenkaese": 5.00, "vollmilch": 1.05,
    "griech_joghurt": 3.50, "gouda": 8.50, "eier": 4.00, "whey": 24.00,
    "haehnchenbrust": 11.00, "haehnchenschenkel": 5.50, "haehnchen_ok": 8.00,
    "rinderhack": 10.00, "thunfisch": 11.50, "lachs": 18.00,
    "linsen_rot": 3.20, "kichererbsen": 3.00, "kidneybohnen": 3.00,
    "tofu": 4.50, "haferflocken": 1.30, "reis": 2.00, "nudeln": 2.20,
    "couscous": 2.60, "bulgur": 3.00, "kartoffeln": 1.00,
    "suesskartoffel": 2.50, "vollkornbrot": 2.40, "banane": 1.50,
    "datteln": 7.50, "rosinen": 6.00, "honig": 8.00, "apfel": 2.50,
    "orange": 2.20, "erdnussmus": 7.50, "mandeln": 12.00, "walnuesse": 15.00,
    "olivenoel": 11.00, "rapsoel": 2.30, "tahin": 10.00, "avocado": 5.00,
    "spinat_tk": 2.20, "brokkoli": 3.00, "tomaten": 3.00, "gurke": 1.80,
    "paprika": 4.50, "zwiebel": 1.30, "karotten": 1.10, "passata": 1.60,
    "gemuese_tk": 2.40,
}
for fid in FOODS:
    if fid not in PRICES:
        raise SystemExit(f"no price for {fid}: every food needs one")
    FOODS[fid]["priceEurPerKg"] = PRICES[fid]

# What keeps in a cupboard or a freezer for weeks: dry goods, tins, oil, nut
# butter, frozen vegetables and fish. A week's plan uses part of a packet, so
# the shopping list asks for these only when they run out -- a list that
# prices a whole kilo tub of whey every week tells a student the week costs
# twice what it does.
KEEPS = {"whey", "linsen_rot", "kichererbsen", "kidneybohnen", "haferflocken",
         "reis", "nudeln", "couscous", "bulgur", "datteln", "rosinen", "honig",
         "erdnussmus", "mandeln", "walnuesse", "olivenoel", "rapsoel", "tahin",
         "thunfisch", "passata", "spinat_tk", "gemuese_tk", "lachs"}
for fid in KEEPS:
    if fid not in FOODS:
        raise SystemExit(f"KEEPS names {fid}, which is not a food")
    FOODS[fid]["keeps"] = True

# Nothing on this list may contain these. The gate checks the names too, so a
# future edit that adds "Schinken" fails rather than quietly shipping.
HARAM = ["schwein", "schinken", "speck", "bacon", "pork", "ham ", "lard",
         "gammon", "salami", "chorizo",
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

# Every template: the portions that ARE the meal, written as they are eaten
# (three eggs, 70 g of oats, a tin of tuna), plus ONE flex food whose grams the
# generator solves so the meal lands on its slot calories. Rounded to 5 g.
#
# It used to solve TWO flex foods against calories AND protein. That is a
# tighter fit on paper and it produced "porridge" of 15 g of oats and 400 g of
# milk, because oats and milk sit close enough together in protein density that
# the solver could trade one away entirely. Calories are the target that has to
# be hit exactly; protein is a floor checked across the whole day, so the meal
# does not need to carry a precise amount of it -- which is what lets every
# portion here be a portion.
#
# (slot, id, name, note, fixed[(food, g)], flex_food)
TEMPLATES = [
    # ---- breakfast: 540 kcal ----------------------------------------------
    ("breakfast", "porridge_pb", "Porridge with peanut butter",
     "Cook the oats in the milk, not water. Stir the peanut butter in at the end.",
     [("haferflocken", 55), ("erdnussmus", 15), ("banane", 100),
      ("magerquark", 100)], "vollmilch"),
    ("breakfast", "eggs_bread", "Eggs on wholemeal bread",
     "Three eggs, scrambled in the oil, with a sliced tomato.",
     [("eier", 116), ("rapsoel", 5), ("tomaten", 80)], "vollkornbrot"),
    ("breakfast", "quark_oats", "Overnight oats with quark",
     "Made the night before. The one breakfast that survives oversleeping.",
     [("magerquark", 110), ("rosinen", 25), ("honig", 15)], "haferflocken"),

    # ---- mid-morning: 330 kcal --------------------------------------------
    ("mid_morning", "dates_nuts", "Dates, almonds and a glass of milk",
     "Pocket food. The milk is what makes it a meal rather than a snack.",
     [("datteln", 50), ("mandeln", 15)], "vollmilch"),
    ("mid_morning", "bread_cheese", "Bread, cheese and an apple",
     "Two slices, sliced Gouda, an apple on the walk.",
     [("vollkornbrot", 70), ("apfel", 150)], "gouda"),
    ("mid_morning", "banana_shake", "Banana milk",
     "Blended, or just shaken in a bottle on the way out.",
     [("banane", 110), ("honig", 10), ("magerquark", 100)], "vollmilch"),

    # ---- lunch: 560 kcal --------------------------------------------------
    ("lunch", "chicken_rice", "Chicken thighs, rice and vegetables",
     "Cooked on prep night with the dinner's chicken. Reheat until steaming.",
     [("haehnchen_ok", 130), ("gemuese_tk", 150), ("rapsoel", 8)], "reis"),
    ("lunch", "chickpea_rice", "Chickpea curry with rice",
     "Half a tin of chickpeas, passata, spinach, onion, with a spoon of skyr "
     "on top. Cook the whole tin: the other half is tonight's dinner.",
     [("kichererbsen", 130), ("passata", 100), ("zwiebel", 50),
      ("spinat_tk", 100), ("rapsoel", 10), ("skyr", 100)], "reis"),
    ("lunch", "egg_rice", "Egg fried rice",
     "Yesterday's rice is better than fresh for this. Three eggs, frozen veg.",
     [("eier", 174), ("gemuese_tk", 150), ("rapsoel", 5)], "reis"),
    ("lunch", "lentil_bulgur", "Red lentils with bulgur",
     "Mercimek. Cheap, filling, and it reheats better than it cooks.",
     [("linsen_rot", 65), ("zwiebel", 60), ("olivenoel", 12),
      ("passata", 100)], "bulgur"),
    ("lunch", "tuna_pasta", "Tuna pasta",
     "A whole tin, wholemeal pasta, passata. Fifteen minutes.",
     [("thunfisch", 110), ("passata", 150), ("olivenoel", 10),
      ("paprika", 80)], "nudeln"),
    ("lunch", "mince_potato", "Mince and potatoes",
     "Halal beef mince, potatoes, whatever vegetable is in the drawer.",
     [("rinderhack", 130), ("karotten", 100), ("zwiebel", 50)], "kartoffeln"),

    # ---- before training: 250 kcal ----------------------------------------
    ("pre_training", "banana_dates", "Banana and dates",
     "Ninety minutes before you go down. Nothing heavy, nothing fatty.",
     [("banane", 120)], "datteln"),
    ("pre_training", "rice_honey", "Rice with honey",
     "If the dates are gone. Fast, boring, works.",
     [("honig", 20)], "reis"),
    ("pre_training", "oat_shake", "Oats and dates, blended",
     "When the day got away from you and it has to be liquid. No milk this "
     "close to training -- fat and protein sit in the stomach.",
     [("datteln", 30)], "haferflocken"),

    # ---- straight after: 280 kcal -----------------------------------------
    ("post_training", "whey_banana", "Whey and banana",
     "Drink it in the basement, before you shower. This is the easy 30 g.",
     [("whey", 25), ("banane", 120)], "vollmilch"),
    ("post_training", "quark_honey", "Quark with honey",
     "If the whey has run out. Slower, just as good.",
     [("magerquark", 140), ("honig", 20)], "rosinen"),
    ("post_training", "milk_oats", "Oats, milk and quark",
     "The cheapest recovery meal in this plan.",
     [("magerquark", 100), ("haferflocken", 40)], "vollmilch"),

    # ---- rest-day afternoon: 530 kcal -------------------------------------
    ("afternoon", "chickpea_couscous", "Lentils and couscous",
     "Rest-day second lunch. The red lentils simmer in fifteen minutes "
     "while the couscous soaks in kettle water.",
     [("linsen_rot", 60), ("olivenoel", 6), ("paprika", 80),
      ("zwiebel", 40)], "couscous"),
    ("afternoon", "eggs_bread_big", "Eggs, bread and avocado",
     "Four eggs. A rest day still has to hit the number.",
     [("eier", 145), ("avocado", 40), ("tomaten", 80)], "vollkornbrot"),
    ("afternoon", "quark_bowl", "Quark bowl",
     "Quark, oats, fruit, nut butter. Two minutes.",
     [("magerquark", 130), ("erdnussmus", 12), ("banane", 120)],
     "haferflocken"),

    # ---- dinner: 520 kcal -------------------------------------------------
    ("dinner", "chicken_potato", "Chicken thighs and potatoes",
     "The other half of prep night's chicken. Potatoes boiled in the same go.",
     [("haehnchen_ok", 130), ("gemuese_tk", 150), ("rapsoel", 6)], "kartoffeln"),
    ("dinner", "lentil_dal", "Red lentil dal with rice",
     "Lentils, passata, onion, spinach, cumin, skyr stirred through at the "
     "end. The cheapest good dinner there is.",
     [("reis", 50), ("passata", 100), ("zwiebel", 30), ("spinat_tk", 80),
      ("rapsoel", 8), ("skyr", 100)], "linsen_rot"),
    ("dinner", "shakshuka", "Shakshuka with bread",
     "Eggs poached in tomato, pepper and onion. One pan, fifteen minutes.",
     [("eier", 174), ("passata", 150), ("zwiebel", 40), ("paprika", 80),
      ("olivenoel", 5)], "vollkornbrot"),
    ("dinner", "chickpea_bowl", "Chickpeas, couscous and a quark dip",
     "Couscous needs only a kettle. The other half of the tin, pepper, "
     "cucumber, and quark with garlic and lemon.",
     [("kichererbsen", 130), ("paprika", 80), ("gurke", 80),
      ("olivenoel", 8), ("magerquark", 100)], "couscous"),
    ("dinner", "tuna_potato", "Tuna and potato salad",
     "Boiled potatoes, a tin of tuna, cucumber, onion, oil. Cold is fine.",
     [("thunfisch", 110), ("gurke", 80), ("zwiebel", 30),
      ("olivenoel", 12)], "kartoffeln"),
    ("dinner", "mince_pasta", "Pasta with mince sauce",
     "Sunday: mince, passata, onion, carrot. Once a week — mince is the dear one.",
     [("rinderhack", 100), ("passata", 150), ("zwiebel", 50),
      ("karotten", 60)], "nudeln"),
    ("dinner", "salmon_potato", "Salmon and potatoes",
     "Frozen fillet, oven, done. The dearest dinner here — a treat, not a habit.",
     [("lachs", 120), ("brokkoli", 120), ("olivenoel", 6)], "kartoffeln"),
    ("dinner", "tofu_stirfry", "Tofu and vegetables",
     "Whatever is in the drawer, hot pan, soy sauce.",
     [("tofu", 150), ("paprika", 100), ("zwiebel", 50),
      ("rapsoel", 8)], "reis"),
    ("dinner", "chicken_salad", "Chicken, bread and salad",
     "The one to cook when you got home late and still have to eat properly.",
     [("haehnchenbrust", 110), ("gurke", 100), ("tomaten", 100),
      ("olivenoel", 10)], "vollkornbrot"),

    # ---- before bed: 120 kcal ---------------------------------------------
    ("before_bed", "quark_small", "Quark",
     "Slow protein overnight. Non-negotiable on training days.",
     [], "magerquark"),
    ("before_bed", "skyr_small", "Skyr",
     "Same job, different tub.",
     [], "skyr"),
    ("before_bed", "milk_glass", "Warm milk with honey",
     "When you cannot face another spoonful of quark.",
     [("honig", 10)], "vollmilch"),
]

# What each meal is built around, and whether it is cooked ahead.
#
# `protein` is the MAIN protein, the one that costs money and needs cooking:
# a day's default lunch and dinner share one, so it is bought and cooked
# once. Dairy, oats and eggs at breakfast are the cheap backbone, not a main.
# `batch` meals are cooked on prep night and keep three days in the fridge.
MEAL_META = {
    "chicken_rice": ("chicken", True), "chicken_potato": ("chicken", True),
    "chicken_salad": ("chicken", False),
    "lentil_bulgur": ("legumes", True), "lentil_dal": ("legumes", True),
    "chickpea_rice": ("legumes", True), "chickpea_bowl": ("legumes", True),
    "chickpea_couscous": ("legumes", False),
    "egg_rice": ("eggs", False), "shakshuka": ("eggs", False),
    "tuna_pasta": ("fish", False), "tuna_potato": ("fish", False),
    "salmon_potato": ("fish", False),
    "mince_potato": ("mince", False), "mince_pasta": ("mince", False),
    "tofu_stirfry": ("legumes", False),
}
MEAT_OR_FISH = {"chicken", "fish", "mince"}

# The week, a day at a time: one main protein per day for lunch and dinner,
# the cheap backbone around it, and the dear things rarely. Chicken twice
# (cooked Sunday for Monday, Wednesday for Thursday), mince once, on Sunday
# when there is time to cook it. No salmon — it is still a swap.
#
# (weekday 1-7, theme, {slot: meal})
ROTATION = [
    (1, "Chicken", {"breakfast": "porridge_pb", "mid_morning": "banana_shake",
                    "lunch": "chicken_rice", "pre_training": "oat_shake",
                    "post_training": "milk_oats", "afternoon": "quark_bowl",
                    "dinner": "chicken_potato", "before_bed": "quark_small"}),
    (2, "Lentils", {"breakfast": "quark_oats", "mid_morning": "bread_cheese",
                    "lunch": "lentil_bulgur", "pre_training": "banana_dates",
                    "post_training": "quark_honey", "afternoon": "eggs_bread_big",
                    "dinner": "lentil_dal", "before_bed": "quark_small"}),
    (3, "Eggs", {"breakfast": "porridge_pb", "mid_morning": "banana_shake",
                 "lunch": "egg_rice", "pre_training": "rice_honey",
                 "post_training": "milk_oats", "afternoon": "quark_bowl",
                 "dinner": "shakshuka", "before_bed": "milk_glass"}),
    (4, "Chicken", {"breakfast": "eggs_bread", "mid_morning": "dates_nuts",
                    "lunch": "chicken_rice", "pre_training": "oat_shake",
                    "post_training": "whey_banana", "afternoon": "quark_bowl",
                    "dinner": "chicken_potato", "before_bed": "quark_small"}),
    (5, "Chickpeas", {"breakfast": "quark_oats", "mid_morning": "bread_cheese",
                      "lunch": "chickpea_rice", "pre_training": "banana_dates",
                      "post_training": "milk_oats", "afternoon": "eggs_bread_big",
                      "dinner": "chickpea_bowl", "before_bed": "quark_small"}),
    (6, "Tuna", {"breakfast": "porridge_pb", "mid_morning": "banana_shake",
                 "lunch": "tuna_pasta", "pre_training": "rice_honey",
                 "post_training": "milk_oats", "afternoon": "quark_bowl",
                 "dinner": "tuna_potato", "before_bed": "quark_small"}),
    (7, "Mince", {"breakfast": "eggs_bread", "mid_morning": "dates_nuts",
                  "lunch": "mince_potato", "pre_training": "oat_shake",
                  "post_training": "milk_oats", "afternoon": "quark_bowl",
                  "dinner": "mince_pasta", "before_bed": "quark_small"}),
]

# Prep nights: what is cooked when, for which days. Cooked chicken, rice and
# pulses keep three days in the fridge.
PREP = {
    "keepsDays": 3,
    "sessions": [
        {"cookOn": 7, "label": "Sunday evening", "covers": [1, 2]},
        {"cookOn": 3, "label": "Wednesday evening", "covers": [4, 5]},
    ],
    "foods": ["haehnchen_ok", "haehnchenbrust", "linsen_rot", "kichererbsen",
              "reis", "bulgur", "couscous", "kartoffeln", "nudeln"],
}

# Budget, per day: the ceiling the default week must stay under.
BUDGET_EUR_PER_DAY = 7.00
BUDGET_EUR_PER_WEEK = 45.00

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
    ("Cheese", "Look for microbial or vegetarian rennet — on a German label, "
               "mikrobielles Lab or vegetarisches Lab. Animal rennet is the "
               "default in a lot of German cheese and it is usually calf."),
    ("Gelatine", "In yoghurts, gummy sweets, some protein bars and a lot of "
                 "desserts. If the label says gelatine without saying beef "
                 "(Rind), assume pork."),
    ("Flavourings", "Vanilla extract and some flavoured whey carry alcohol as "
                    "a carrier. Neutral whey avoids the question entirely."),
    ("Reading a label", "The nutrition per 100 g (Nährwerte je 100 g) is what "
                        "this plan is built on. Compare per 100 g, never per "
                        "portion — the portion on the packet is whatever "
                        "flatters the number."),
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


def solve(fixed, flex, kcal_target):
    """Grams of the flex food that land the meal on its calorie target."""
    base = macros(fixed)
    need = kcal_target - base["kcal"]
    per_g = FOODS[flex]["kcal"] / 100.0
    if per_g <= 0:
        return None
    return round((need / per_g) / 5) * 5


# The smallest amount of a food that is still a PORTION. Below these the
# arithmetic is fine and the meal is a joke: 15 g of oats is a garnish, and a
# solver with no lower bound will happily write it.
MIN_G = {
    "haferflocken": 40, "reis": 50, "nudeln": 60, "couscous": 50, "bulgur": 50,
    "kartoffeln": 150, "vollkornbrot": 60, "vollmilch": 100, "magerquark": 100,
    "skyr": 100, "datteln": 20, "banane": 60, "mandeln": 15, "gouda": 20,
    "erdnussmus": 10, "honig": 10, "rosinen": 15, "whey": 20,
}

SLOT_BY_ID = {s[0]: s for s in SLOTS}
built = []

for slot_id, tid, name, note, fixed, flex in TEMPLATES:
    slot = SLOT_BY_ID[slot_id]
    kcal_t = slot[4]
    g = solve(fixed, flex, kcal_t)

    if g is None:
        fail(f"{tid}: {flex} has no calories to solve with")
        continue

    floor = MIN_G.get(flex, 5)
    if g < floor:
        fail(f"{tid}: solved to {flex} {g} g, under the {floor} g that food "
             f"needs to be a portion. The fixed items already use "
             f"{macros(fixed)['kcal']:.0f} of the {kcal_t} kcal slot.")
        continue

    items = list(fixed) + [(flex, g)]
    merged, order = {}, []
    for fid, grams in items:
        if fid not in merged:
            order.append(fid)
            merged[fid] = 0
        merged[fid] += grams
    items = [(fid, merged[fid]) for fid in order]

    for fid, grams in items:
        floor = MIN_G.get(fid)
        if floor and grams < floor:
            fail(f"{tid}: {fid} at {grams} g is under its {floor} g minimum")

    m = macros(items)
    cost = sum(FOODS[fid]["priceEurPerKg"] * g / 1000 for fid, g in items)
    main, batch = MEAL_META.get(tid, (None, False))
    built.append({
        "id": tid, "slotId": slot_id, "name": name, "note": note,
        "items": [{"foodId": fid, "grams": grams} for fid, grams in items],
        "kcal": round(m["kcal"]),
        "proteinG": round(m["proteinG"], 1),
        "carbsG": round(m["carbsG"], 1),
        "fatG": round(m["fatG"], 1),
        "costEur": round(cost, 2),
        **({"protein": main} if main else {}),
        **({"batch": True} if batch else {}),
    })

    dk = m["kcal"] - kcal_t
    if abs(dk) > max(12, kcal_t * 0.04):
        fail(f"{tid}: {m['kcal']:.0f} kcal against a {kcal_t} target ({dk:+.0f})")

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

        lo = {
            "kcal": add["kcal"],
            "proteinG": add["proteinG"],
            "fatG": add["fatG"],
            "carbsG": add["carbsG"],
        }
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
            # No protein CEILING. The first draft had one, and it was the
            # wrong gate: it failed days of entirely sensible food and the
            # only way to satisfy it was to shrink the meat back to the
            # portions that made this plan absurd in the first place.
            #
            # Protein is only a problem insofar as it displaces the
            # carbohydrate that fuels five sessions a week, so THAT is what
            # is checked. 250 g is 5 g per kilo at 50 kg, which is enough to
            # train on; below it the day is worth re-authoring.
            if tot["carbsG"] < 250:
                fail(f"{day_kind} {label}, {bound} day: {tot['carbsG']:.0f} g "
                     f"of carbohydrate, under the 250 g floor -- the protein "
                     f"is crowding out the fuel")
            if tot["fatG"] < 40:
                fail(f"{day_kind} {label}, {bound} day: {tot['fatG']:.0f} g fat "
                     f"— below the 40 g floor hormones need")

# ---------------------------------------------------- the default week ----
# Every rotation day, training and rest, must hit its calories, clear the
# protein, carbohydrate and fat floors, stay under the budget, and have at
# most ONE meat-or-fish main. (Swaps are his choice; the default is ours.)
BUILT = {t["id"]: t for t in built}
week_cost = {"training": 0.0, "rest": 0.0}
for wd, theme, meals in ROTATION:
    for day_kind, slot_ids in [
        ("training", ["breakfast", "mid_morning", "lunch", "pre_training",
                      "post_training", "dinner", "before_bed"]),
        ("rest", ["breakfast", "mid_morning", "lunch", "afternoon", "dinner",
                  "before_bed"]),
    ]:
        chosen = []
        for sid in slot_ids:
            mid = meals.get(sid)
            t = BUILT.get(mid)
            if t is None or t["slotId"] != sid:
                fail(f"rotation day {wd} ({theme}): {sid} -> {mid} is not a {sid} meal")
                continue
            chosen.append(t)
        tot = {k: sum(t[k] for t in chosen) for k in ("kcal", "proteinG", "carbsG", "fatG")}
        cost = sum(t["costEur"] for t in chosen)
        week_cost[day_kind] += cost
        target = 2600
        if abs(tot["kcal"] - target) > target * 0.03:
            fail(f"rotation day {wd} {day_kind}: {tot['kcal']} kcal against {target}")
        if tot["proteinG"] < 110:
            fail(f"rotation day {wd} {day_kind}: {tot['proteinG']:.0f} g protein, under 110")
        if tot["carbsG"] < 250:
            fail(f"rotation day {wd} {day_kind}: {tot['carbsG']:.0f} g carbohydrate, under 250")
        if tot["fatG"] < 40:
            fail(f"rotation day {wd} {day_kind}: {tot['fatG']:.0f} g fat, under 40")
        if cost > BUDGET_EUR_PER_DAY:
            fail(f"rotation day {wd} {day_kind}: EUR {cost:.2f}, over the "
                 f"EUR {BUDGET_EUR_PER_DAY:.2f} a day a student can spend")
        mains = {t.get("protein") for t in chosen if t.get("protein") in MEAT_OR_FISH}
        if len(mains) > 1:
            fail(f"rotation day {wd} ({theme}): two meat/fish mains {sorted(mains)} "
                 f"— one protein a day, bought and cooked once")
        if any(t["id"] == "salmon_potato" for t in chosen):
            fail(f"rotation day {wd}: salmon is a treat swap, not a default")
for kind, c in week_cost.items():
    if c > BUDGET_EUR_PER_WEEK:
        fail(f"the default week, all {kind} days: EUR {c:.2f}, over "
             f"EUR {BUDGET_EUR_PER_WEEK:.2f}")

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
    "rotation": [
        {"weekday": wd, "theme": theme, "meals": meals}
        for wd, theme, meals in ROTATION
    ],
    "prep": PREP,
    "budget": {"eurPerDay": BUDGET_EUR_PER_DAY, "eurPerWeek": BUDGET_EUR_PER_WEEK,
               "note": "Estimated discounter prices, 2026. Check your receipt."},
}

os.makedirs(MIRROR, exist_ok=True)
raw = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
for path in (os.path.join(OUT, "fuel.json"), os.path.join(MIRROR, "fuel.json")):
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(raw)

print(f"fuel.json          {len(raw.encode('utf-8')):>8,} bytes   "
      f"{len(FOODS)} foods, {len(built)} meals across {len(SLOTS)} slots")
print(f"the default week: EUR {week_cost['training']:.2f} if every day trained, "
      f"EUR {week_cost['rest']:.2f} if every day rested")
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
