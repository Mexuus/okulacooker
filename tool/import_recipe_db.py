"""Builds assets/data/recipe_db.json, the recipe database the app bundles.

Inputs (all under tool/sources/):
  mealplan.json          the original ReelChef/OkulaCooker database (recipes + ingredients)
  curation.json          editorial decisions: recipes to drop, titles/servings to fix
  extra_ingredients.json ingredients added after the original app
  recipes/*.json         new recipes in the authoring format (see recipes/README.md)
  recipe_ids.json        stable numeric ids for new recipes (append-only)

Each ingredient is augmented with its grocery aisle, purchasable packs, gram
conversions and diet flags. Each recipe gets the gear it needs, whether it's
spicy, and per-serving nutrition.

Usage:
  python tool/import_recipe_db.py [path/to/app.ipa | path/to/mealplan.json]
  python tool/import_recipe_db.py --check tool/sources/recipes/grill.json ...
--check validates authoring files and prints a summary without writing anything.
"""
import glob
import json
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "data", "recipe_db.json")
SOURCES = os.path.join(ROOT, "tool", "sources")
DEFAULT_SOURCE = os.path.join(SOURCES, "mealplan.json")
CURATION = os.path.join(SOURCES, "curation.json")
EXTRA_INGREDIENTS = os.path.join(SOURCES, "extra_ingredients.json")
NEW_RECIPES = os.path.join(SOURCES, "recipes")
RECIPE_IDS = os.path.join(SOURCES, "recipe_ids.json")
INGREDIENT_ICONS = os.path.join(SOURCES, "ingredient_icons.json")
ICON_DIR = os.path.join(ROOT, "assets", "icons", "food")
PHOTO_DIR = os.path.join(ROOT, "assets", "photos")
FIRST_NEW_ID = 1000

G_PER_LB = 453.592
G_PER_OZ = 28.3495
ML_PER_CUP = 236.588
ML_PER_GAL = 3785.41

# Typical weight of one bunch (the source data sells these by the bunch).
BUNCH_GRAMS = {"cilantro": 60, "parsley_fresh": 60, "kale": 280, "scallion": 100, "celery": 450}

# "count" means a whole head for garlic (g_per_count in the source is per clove).
COUNT_GRAMS = {"garlic_head": 30}

# This app has no seafood in it. Fish and shellfish dinners are dropped in
# curation.json, the ingredients below are deleted from the database once
# nothing is left using them, and the three fish-derived condiments are swapped
# for the fish-free bottles sold beside them so the meat and poultry dinners
# that only needed a splash of one survive.
SEAFOOD = {"salmon_fillet", "shrimp_frozen", "tilapia_fillet", "cod_fillet", "tuna_canned",
           "fish_sauce", "oyster_sauce", "worcestershire"}
# old id -> (replacement id, wording in the steps to rewrite)
SUBSTITUTE = {
    "fish_sauce": ("soy_sauce", "fish sauce", "soy sauce"),
    "worcestershire": ("worcestershire_vegan", None, None),
}
AISLE_BY_CATEGORY = {
    "produce": "produce", "herb": "produce", "canned": "canned", "pantry": "pantry",
    "spice": "spices", "grain": "grains", "dairy": "dairy", "bakery": "bakery",
    "frozen": "frozen", "protein": "meat",
}

TIER_RE = re.compile(r"(\w+)\s+([\d.]+)\s*(lb|oz|count)\s+\$([\d.]+)")

# Diet flags per ingredient. These drive the app's diet filters, which are a
# planning convenience, not allergen control: brands differ, so they lean
# conservative (e.g. soy sauce and miso count as containing gluten).
FLAGS = {
    "beef": {"ground_beef", "beef_chuck", "beef_steak_sirloin", "broth_beef", "au_jus_mix"},
    "pork": {"ground_pork", "pork_chop", "pork_chop_bone_in", "pork_shoulder", "bacon",
             "sausage_italian", "sausage_chorizo", "prosciutto", "pancetta", "pepperoni",
             "pork_tenderloin", "pork_ribs"},
    "poultry": {"chicken_thigh_boneless", "chicken_thigh_bone_in", "chicken_breast",
                "chicken_whole", "chicken_drumstick", "chicken_wings", "ground_turkey",
                "broth_chicken", "cream_of_chicken_canned"},
    "lamb": {"lamb_ground"},
    "dairy": {"butter_unsalted", "cheddar", "cream_cheese", "cream_heavy", "feta", "goat_cheese",
              "milk_whole", "mozzarella_low_moisture", "parmesan", "ricotta", "sour_cream",
              "yogurt_greek", "alfredo_sauce", "cream_of_chicken_canned",
              "cream_of_mushroom_canned", "pesto", "tortellini", "ranch_seasoning", "gnocchi"},
    "egg": {"egg_large", "noodle_egg", "mayo", "tortellini", "gnocchi"},
    "gluten": {"pasta_long", "pasta_short", "pasta_lasagna", "pasta_orzo", "noodle_egg",
               "tortellini", "gnocchi", "couscous", "flour_ap", "breadcrumb_panko",
               "bread_crusty", "bread_sandwich", "bun_burger", "pie_crust", "pita_bread",
               "tortilla_flour", "soy_sauce", "hoisin_sauce", "stirfry_sauce_veg",
               "cream_of_chicken_canned", "cream_of_mushroom_canned", "gochujang",
               "miso_white", "au_jus_mix", "onion_soup_mix"},
    "nuts": {"peanut_butter", "peanut_raw", "cashew_raw", "pesto"},
    "honey": {"honey"},
}

# Ingredients that make a dish spicy at any amount, and those that do above a
# threshold (amount per 4 servings, in the recipe's unit).
HOT = {"jalapeno", "chipotle_adobo", "hot_sauce", "buffalo_sauce", "gochujang",
       "curry_paste_red", "harissa"}
HOT_ABOVE = {"cayenne": ("tsp", 0.25), "chili_flake": ("tsp", 0.5)}
HOT_TITLE = re.compile(r"spicy|hot honey|nashville|diavolo|arrabbiata|kung pao|buffalo|"
                       r"chili crisp|piri|jerk|sriracha|firecracker|fra diavolo", re.I)

GEAR_BY_EQUIPMENT = {"oven": "oven", "slow_cooker": "slow_cooker", "air_fryer": "air_fryer",
                     "pressure_cooker": "pressure_cooker", "grill": "grill"}
EQUIPMENT = {"stove", *GEAR_BY_EQUIPMENT}
FORMATS = {"skillet", "oven", "pot", "slow", "air", "pressure", "grill"}
OVEN_TEXT = re.compile(r"(?<!dutch )\boven\b|\bbroil", re.I)

STARCHES = {"rice_long_grain", "rice_basmati", "arborio_rice", "pasta_long", "pasta_short",
            "pasta_lasagna", "pasta_orzo", "noodle_egg", "rice_noodle", "gnocchi", "tortellini",
            "couscous", "quinoa", "polenta", "bread_crusty", "bread_sandwich", "bun_burger",
            "pita_bread", "tortilla_flour", "tortilla_corn", "pie_crust", "potato_yukon",
            "potato_russet", "sweet_potato", "flour_ap"}
# Light dinners (below LIGHT_KCAL per serving, no starch) get a side so they
# make a full meal: crusty bread with soups, stews and European dishes, rice
# with everything else.
LIGHT_KCAL = 450
BREAD_CUISINES = {"Italian", "French", "British", "German", "Irish", "Scandinavian",
                  "Russian", "Portuguese", "Mediterranean"}

DIFFICULTIES = {"Easy", "Medium", "Hard"}
FRACTIONS = [(0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"), (0.375, "⅜"), (0.5, "½"),
             (0.625, "⅝"), (0.666, "⅔"), (0.75, "¾"), (0.875, "⅞")]
PLACEHOLDER = re.compile(r"\{amt:([a-z0-9_]+)(?::([0-9.]+))?(?:\|([^|}]+)\|([^|}]+))?\}")


# ---------------------------------------------------------------- ingredients

def load_source(path):
    if path.lower().endswith(".ipa"):
        with zipfile.ZipFile(path) as z:
            name = next(n for n in z.namelist() if n.endswith(".app/mealplan.json"))
            return json.loads(z.read(name).decode("utf-8"))
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def read_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def grams(size, unit, ing):
    if unit == "lb":
        return size * G_PER_LB
    if unit == "oz":
        return size * G_PER_OZ
    if unit == "count":
        return size * COUNT_GRAMS.get(ing["canonical_id"], ing.get("g_per_count") or 0)
    if unit == "gal":
        return size * ML_PER_GAL / ML_PER_CUP * (ing.get("g_per_cup") or ML_PER_CUP)
    if unit == "ml":
        return size / ML_PER_CUP * (ing.get("g_per_cup") or ML_PER_CUP)
    if unit == "bunch":
        return size * BUNCH_GRAMS.get(ing["canonical_id"], 100)
    raise ValueError(f"unknown pack unit {unit} for {ing['canonical_id']}")


def unit_grams(ing):
    """Grams per recipe unit for this ingredient."""
    out = {"lb": G_PER_LB, "oz": G_PER_OZ}
    if ing.get("g_per_cup"):
        out.update(cup=ing["g_per_cup"], tbsp=ing["g_per_cup"] / 16, tsp=ing["g_per_cup"] / 48)
    if ing.get("g_per_count"):
        g = ing["g_per_count"]
        out.update(count=COUNT_GRAMS.get(ing["canonical_id"], g), clove=g, stalk=g, packet=g)
    return {k: round(v, 3) for k, v in out.items()}


def aisle(ing):
    cid, cat = ing["canonical_id"], ing["category"]
    if cat == "protein":
        if cid == "egg_large":
            return "dairy"
        if cid in ("tofu_firm", "tempeh"):
            return "produce"
    return AISLE_BY_CATEGORY[cat]


def augment_ingredients(ingredients):
    for ing in ingredients:
        ing["aisle"] = aisle(ing)
        ing["g_per_pack"] = round(grams(ing["pack_size"], ing["pack_unit"], ing), 2)
        packs = [
            {"label": label, "size": float(size), "unit": unit, "price": float(price),
             "grams": round(grams(float(size), unit, ing), 2)}
            for label, size, unit, price in TIER_RE.findall(ing.get("tiers") or "")
        ]
        if not packs:
            packs = [{"label": "", "size": ing["pack_size"], "unit": ing["pack_unit"],
                      "price": ing["pack_price_usd"], "grams": ing["g_per_pack"]}]
        ing["packs"] = packs
        ing["unit_grams"] = unit_grams(ing)
        ing["flags"] = sorted(f for f, ids in FLAGS.items() if ing["canonical_id"] in ids)
        if ing["g_per_pack"] <= 0:
            sys.exit(f"{ing['canonical_id']}: could not compute grams per pack")
    known = {i["canonical_id"] for i in ingredients}
    stale = sorted(set().union(*FLAGS.values(), HOT, HOT_ABOVE) - known)
    if stale:
        sys.exit(f"diet/spice tables name unknown ingredients: {stale}")


# --------------------------------------------------------------- amounts/text

def qty_text(q):
    whole, frac = int(q), q - int(q)
    best, sym = 0.04, None
    for v, s in FRACTIONS:
        if abs(frac - v) < best:
            best, sym = abs(frac - v), s
    if sym:
        return f"{whole}{sym}" if whole else sym
    if frac < 0.04:
        return str(whole)
    if frac > 0.96:
        return str(whole + 1)
    r = round(q, 1)
    return str(int(r)) if r == int(r) else str(r)


def amount_text(v, unit, nouns):
    q = qty_text(v)
    if nouns:
        return f"{q} {nouns[1] if v > 1.0001 else nouns[0]}"
    if unit == "cup":
        return f"{q} {'cups' if v > 1.0001 else 'cup'}"
    return f"{q} {unit}"


def auto_nouns(unit, ing):
    if unit == "count" and ing["category"] == "canned":
        return ["can", "cans"]
    if unit in ("clove", "stalk", "packet"):
        return [unit, unit + "s"]
    return None


def convert_body(body, lines, by_id, ctx, used):
    """Replaces {amt:...} placeholders with {0}, {1}… and builds StepAmounts."""
    amounts = []

    def sub(m):
        cid, frac, one, many = m.group(1), m.group(2), m.group(3), m.group(4)
        if cid not in lines:
            raise ValueError(f"{ctx}: placeholder for {cid}, which isn't in the ingredient list")
        amount, unit = lines[cid]
        f = float(frac) if frac else 1.0
        if not 0 < f <= 1:
            raise ValueError(f"{ctx}: fraction {f} for {cid} must be in (0, 1]")
        used[cid] = used.get(cid, 0) + f
        nouns = [one.strip(), many.strip()] if one else auto_nouns(unit, by_id[cid])
        if unit == "count" and not nouns:
            raise ValueError(f"{ctx}: {cid} is counted; write {{amt:{cid}|singular|plural}}")
        v = round(amount * f, 4)
        a = {"cid": cid, "v": v, "u": unit, "b": amount_text(v, unit, nouns),
             "id": f"n{ctx.split('#')[-1]}_{len(amounts)}"}
        if nouns:
            a["n"] = nouns
        else:
            a["w"] = "short"
        amounts.append(a)
        return "{" + str(len(amounts) - 1) + "}"

    text = PLACEHOLDER.sub(sub, body)
    if "{amt:" in text:
        raise ValueError(f"{ctx}: malformed placeholder in: {body}")
    return text, amounts


def convert_actions(actions, lines, by_id, ctx, used):
    out = []
    for i, a in enumerate(actions):
        for key in ("verb", "body"):
            if not isinstance(a.get(key), str) or not a[key].strip():
                raise ValueError(f"{ctx}: action {i + 1} needs a '{key}'")
        body, amounts = convert_body(a["body"], lines, by_id, f"{ctx}#{i}", used)
        act = {"verb": a["verb"].strip(), "body": body, "amounts": amounts}
        if a.get("duration"):
            if not re.fullmatch(r"\d+(-\d+)? (min|hr)", a["duration"]):
                raise ValueError(f"{ctx}: duration must look like '8 min' or '2-3 hr'")
            act["duration"] = a["duration"]
        out.append(act)
    return out


# -------------------------------------------------------------------- recipes

def nutrition(recipe, by_id):
    tot = {"kcal": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0}
    for ri in recipe["ingredients"]:
        ing = by_id[ri["canonical_id"]]
        g = ri["amount"] * ing["unit_grams"][ri["unit"]]
        for k in tot:
            tot[k] += g * (ing.get(f"{k}_100g") or 0) / 100
    return {k: round(v / recipe["serves"]) for k, v in tot.items()}


def cost_per_serving(recipe, by_id):
    total = 0.0
    for ri in recipe["ingredients"]:
        ing = by_id[ri["canonical_id"]]
        total += ri["amount"] * ing["unit_grams"][ri["unit"]] * ing["pack_price_usd"] / ing["g_per_pack"]
    return round(total / recipe["serves"], 2)


def recipe_text(recipe):
    return " ".join(f"{a['verb']} {a['body']}" for p in recipe["directions"] for a in p["actions"])


def derive(recipe, by_id):
    """Gear the recipe needs, spiciness and per-serving nutrition."""
    needs = set()
    if recipe["equipment"] in GEAR_BY_EQUIPMENT:
        needs.add(GEAR_BY_EQUIPMENT[recipe["equipment"]])
    if OVEN_TEXT.search(recipe_text(recipe)):
        needs.add("oven")
    recipe["needs"] = sorted(needs)

    per4 = 4 / recipe["serves"]
    spicy = bool(HOT_TITLE.search(recipe["title"]))
    for ri in recipe["ingredients"]:
        cid = ri["canonical_id"]
        if cid in HOT:
            spicy = True
        elif cid in HOT_ABOVE:
            unit, limit = HOT_ABOVE[cid]
            tsp = ri["amount"] * {"tsp": 1, "tbsp": 3, "cup": 48}.get(ri["unit"], 0)
            if unit == "tsp" and tsp * per4 >= limit:
                spicy = True
    recipe["spicy"] = spicy
    recipe["nutrition"] = nutrition(recipe, by_id)


def add_light_side(recipe, by_id):
    """Turns a too-light, starch-free dinner into a full meal."""
    if recipe["nutrition"]["kcal"] >= LIGHT_KCAL:
        return None
    if any(ri["canonical_id"] in STARCHES for ri in recipe["ingredients"]):
        return None
    per = recipe["serves"] / 4
    soupy = re.search(r"soup|stew|chowder|chili|minestrone|shakshuka|egg", recipe["title"], re.I)
    if not soupy and recipe["cuisine"] not in BREAD_CUISINES:
        cid = "rice_basmati" if recipe["cuisine"] in ("Indian", "Middle Eastern") else "rice_long_grain"
        amount = round(1.5 * per, 2)
        lead = "Rinse" if cid == "rice_basmati" else "Measure"
        body = (f"the rice: {lead.lower()} {{amt:{cid}}} and simmer it, covered, in 1½ times "
                "its volume of salted water for 15 minutes, then let it steam off the heat "
                "for 5 minutes.")
        action, phase, pos, side = ({"verb": "Start", "body": body}, 0, 0, "rice")
        recipe["minutes"] = max(recipe["minutes"], 25)
    else:
        cid, amount = "bread_crusty", round(12 * per, 1)
        action = {"verb": "Serve", "body": f"with {{amt:{cid}}} of warm crusty bread."}
        phase, pos, side = len(recipe["directions"]) - 1, None, "bread"
    unit = "cup" if side == "rice" else "oz"
    recipe["ingredients"].append({"canonical_id": cid, "amount": amount, "unit": unit})
    lines = {cid: (amount, unit)}
    [act] = convert_actions([action], lines, by_id, f"side {recipe['id']}", {})
    actions = recipe["directions"][phase]["actions"]
    actions.insert(len(actions) if pos is None else pos, act)
    return side


def swap_condiments(recipes, by_id):
    """Replaces the fish-derived condiments in the source data with their
    fish-free equivalents, in the ingredient lines and in the wording of the
    steps. Returns how many lines were swapped."""
    swapped = 0
    for r in recipes:
        listed = {ri["canonical_id"] for ri in r["ingredients"]}
        for ri in r["ingredients"]:
            sub = SUBSTITUTE.get(ri["canonical_id"])
            if not sub:
                continue
            new, old_text, new_text = sub
            if new not in by_id:
                sys.exit(f"substitute ingredient '{new}' is not in the database")
            if new in listed:
                sys.exit(f"recipe {r['id']} lists both {ri['canonical_id']} and {new}; "
                         f"the amounts would need merging by hand")
            ri["canonical_id"] = new
            swapped += 1
            if not old_text:
                continue
            pattern = re.compile(old_text, re.I)
            for ph in r["directions"]:
                for a in ph["actions"]:
                    a["body"] = pattern.sub(new_text, a["body"])
                    for am in a.get("amounts", []):
                        am["b"] = pattern.sub(new_text, am["b"])
    return swapped


def apply_curation(recipes, curation, by_id):
    drop = {int(k): v for k, v in curation.get("drop", {}).items()}
    patch = {int(k): v for k, v in curation.get("patch", {}).items()}
    ids = {r["id"] for r in recipes}
    missing = sorted((set(drop) | set(patch)) - ids)
    if missing:
        sys.exit(f"curation names recipes that don't exist: {missing}")
    both = sorted(set(drop) & set(patch))
    if both:
        sys.exit(f"curation both drops and patches: {both}")
    kept = []
    for r in recipes:
        if r["id"] in drop:
            continue
        p = patch.get(r["id"], {})
        unknown = set(p) - {"title", "serves", "minutes"}
        if unknown:
            sys.exit(f"recipe {r['id']}: unsupported patch keys {sorted(unknown)}")
        r.update(p)
        kept.append(r)
    return kept, len(drop)


def convert_new(src, rid, by_id, ctx):
    required = {"key", "title", "cuisine", "anchor", "serves", "minutes", "difficulty",
                "equipment", "format", "ingredients", "steps"}
    missing = required - set(src)
    if missing:
        raise ValueError(f"{ctx}: missing fields {sorted(missing)}")
    if src["equipment"] not in EQUIPMENT:
        raise ValueError(f"{ctx}: equipment must be one of {sorted(EQUIPMENT)}")
    if src["format"] not in FORMATS:
        raise ValueError(f"{ctx}: format must be one of {sorted(FORMATS)}")
    if src["difficulty"] not in DIFFICULTIES:
        raise ValueError(f"{ctx}: difficulty must be one of {sorted(DIFFICULTIES)}")
    if src["anchor"] not in by_id:
        raise ValueError(f"{ctx}: anchor {src['anchor']} isn't a known ingredient")

    lines, ingredients = {}, []
    for entry in src["ingredients"]:
        cid, amount, unit = entry
        if cid in SEAFOOD:
            raise ValueError(f"{ctx}: this app has no seafood in it — {cid} can't be used")
        if cid not in by_id:
            raise ValueError(f"{ctx}: unknown ingredient {cid}")
        if unit not in by_id[cid]["unit_grams"]:
            raise ValueError(f"{ctx}: {cid} can't be measured in '{unit}' "
                             f"(use one of {sorted(by_id[cid]['unit_grams'])})")
        if cid in lines:
            raise ValueError(f"{ctx}: {cid} listed twice")
        if not amount > 0:
            raise ValueError(f"{ctx}: {cid} needs a positive amount")
        lines[cid] = (float(amount), unit)
        ingredients.append({"canonical_id": cid, "amount": float(amount), "unit": unit})
    if src["anchor"] not in lines:
        raise ValueError(f"{ctx}: anchor {src['anchor']} must be in the ingredient list")

    used, directions = {}, []
    for pi, ph in enumerate(src["steps"]):
        if not ph.get("phase") or not ph.get("actions"):
            raise ValueError(f"{ctx}: step group {pi + 1} needs 'phase' and 'actions'")
        directions.append({
            "phase": ph["phase"], "minutes": int(ph.get("minutes", 0)),
            "actions": convert_actions(ph["actions"], lines, by_id, f"{ctx}/{ph['phase']}", used),
        })
    over = {c: round(f, 2) for c, f in used.items() if f > 1.05}
    if over:
        raise ValueError(f"{ctx}: step amounts use more than the listed quantity: {over}")

    return {
        "id": rid, "title": src["title"].strip(), "cuisine": src["cuisine"],
        "anchor": src["anchor"], "serves": int(src["serves"]), "minutes": int(src["minutes"]),
        "format": src["format"], "equipment": src["equipment"], "ingredients": ingredients,
        "directions": directions, "difficulty": src["difficulty"],
        "cleanup_score": int(src.get("cleanup", 3)), "added": "3.0", "key": src["key"],
    }


def load_new_recipes(paths, by_id, ids, assign):
    out, errors = [], []
    for path in paths:
        try:
            items = read_json(path, [])
        except json.JSONDecodeError as e:
            errors.append(f"{os.path.basename(path)}: invalid JSON: {e}")
            continue
        for n, src in enumerate(items):
            ctx = f"{os.path.basename(path)}[{n}] {src.get('title', '?')}"
            key = src.get("key")
            if not key or not re.fullmatch(r"[a-z0-9-]+", key):
                errors.append(f"{ctx}: 'key' must be lowercase-with-dashes")
                continue
            if key not in ids:
                ids[key] = assign()
            try:
                out.append(convert_new(src, ids[key], by_id, ctx))
            except (ValueError, TypeError) as e:
                errors.append(str(e))
    return out, errors


def norm_title(t):
    return re.sub(r"[^a-z0-9]+", " ", t.lower()).strip()


def check(recipes, by_id, new_only):
    """Sanity checks; returns (errors, warnings)."""
    errors, warnings, seen = [], [], {}
    for r in recipes:
        t = norm_title(r["title"])
        if t in seen:
            errors.append(f"duplicate title: '{r['title']}' (#{seen[t]} and #{r['id']})")
        seen[t] = r["id"]
    for r in new_only:
        k, p = r["nutrition"]["kcal"], r["nutrition"]["protein"]
        tag = f"#{r['id']} {r['title']}"
        if not 380 <= k <= 1100:
            errors.append(f"{tag}: {k} kcal per serving is outside 380–1100; fix the portions")
        elif not 450 <= k <= 950:
            warnings.append(f"{tag}: {k} kcal per serving (typical dinner is 450–950)")
        meatless = not ({"beef", "pork", "poultry", "lamb", "fish", "shellfish"} &
                        {f for ri in r["ingredients"] for f in by_id[ri["canonical_id"]]["flags"]})
        if p < (12 if meatless else 22):
            warnings.append(f"{tag}: only {p} g protein per serving")
        phases = sum(ph["minutes"] for ph in r["directions"])
        if r["equipment"] != "slow_cooker" and abs(phases - r["minutes"]) > max(10, r["minutes"] * 0.25):
            warnings.append(f"{tag}: total {r['minutes']} min but steps add up to {phases} min")
        mentioned = recipe_text(r).lower()
        for ri in r["ingredients"]:
            ing = by_id[ri["canonical_id"]]
            word = ing["display"].split(",")[0].split("(")[0].strip().lower().split()[-1]
            if f"{ri['canonical_id']}" not in json.dumps(r["directions"]) and word not in mentioned:
                warnings.append(f"{tag}: '{ing['display']}' is never mentioned in the steps")
    return errors, warnings


def attach_photos(recipes):
    """Links recipes to credited photos listed in tool/sources/recipe_photos_*.json:
    {"photos": {key: {file, credit, license, source}}, "recipes": {title: key}}."""
    photos, by_title = {}, {}
    for path in sorted(glob.glob(os.path.join(SOURCES, "recipe_photos_*.json"))):
        data = read_json(path, {})
        for key, p in data.get("photos", {}).items():
            if key in photos and photos[key]["file"] != p["file"]:
                sys.exit(f"{os.path.basename(path)}: photo key '{key}' defined twice")
            photos[key] = p
        by_title.update(data.get("recipes", {}))
    titles = {r["title"] for r in recipes}
    stale = sorted(set(by_title) - titles)
    if stale:
        print(f"WARNING photo mappings for unknown titles: {stale[:5]}", file=sys.stderr)
    linked = 0
    for r in recipes:
        key = by_title.get(r["title"])
        p = photos.get(key) if key else None
        if p and os.path.exists(os.path.join(PHOTO_DIR, p["file"])):
            r["photo"] = {k: p[k] for k in ("file", "credit", "license", "source") if k in p}
            linked += 1
    return linked


def tidy_amount_text(recipes):
    """The original database writes some step amounts as decimals ("0.5 cup");
    show them as kitchen fractions ("½ cup") like everything else."""
    decimal = re.compile(r"\d+\.\d+")
    fixed = 0
    for r in recipes:
        for p in r["directions"]:
            for a in p["actions"]:
                body = decimal.sub(lambda m: qty_text(float(m.group())), a["body"])
                if body != a["body"]:
                    a["body"] = body
                    fixed += 1
                for am in a.get("amounts", []):
                    new = decimal.sub(lambda m: qty_text(float(m.group())), am["b"])
                    if new != am["b"]:
                        am["b"] = new
                        fixed += 1
    return fixed


def build(src_path, check_paths=None):
    db = load_source(src_path)
    extra = read_json(EXTRA_INGREDIENTS, [])
    dup = {i["canonical_id"] for i in extra} & {i["canonical_id"] for i in db["ingredients"]}
    if dup:
        sys.exit(f"extra ingredients already exist: {sorted(dup)}")
    db["ingredients"].extend(extra)
    augment_ingredients(db["ingredients"])
    icons = read_json(INGREDIENT_ICONS, {})
    for ing in db["ingredients"]:
        slug = icons.get(ing["canonical_id"])
        if slug and os.path.exists(os.path.join(ICON_DIR, slug + ".webp")):
            ing["icon"] = slug
    by_id = {i["canonical_id"]: i for i in db["ingredients"]}

    for r in db["recipes"]:
        bad = [ri["canonical_id"] for ri in r["ingredients"] if ri["canonical_id"] not in by_id]
        if bad:
            sys.exit(f"recipe {r['id']} references unknown ingredients: {bad}")
        bad = [f"{ri['canonical_id']}:{ri['unit']}" for ri in r["ingredients"]
               if ri["unit"] not in by_id[ri["canonical_id"]]["unit_grams"]]
        if bad:
            sys.exit(f"recipe {r['id']}: no gram conversion for {bad}")

    original = len(db["recipes"])
    recipes, dropped = apply_curation(db["recipes"], read_json(CURATION, {}), by_id)
    swap_condiments(recipes, by_id)
    tidy_amount_text(recipes)
    sides = {"rice": 0, "bread": 0}
    for r in recipes:
        derive(r, by_id)
        side = add_light_side(r, by_id)
        if side:
            sides[side] += 1
            derive(r, by_id)

    ids = read_json(RECIPE_IDS, {})
    next_id = [max([FIRST_NEW_ID - 1, *ids.values()]) + 1]

    def assign():
        next_id[0] += 1
        return next_id[0] - 1

    paths = check_paths or sorted(glob.glob(os.path.join(NEW_RECIPES, "*.json")))
    new, errors = load_new_recipes(paths, by_id, ids, assign)
    for r in new:
        r["cost_per_serving"] = cost_per_serving(r, by_id)
        derive(r, by_id)
    all_recipes = recipes + new
    errs, warns = check(all_recipes, by_id, new)
    errors += errs
    left = sorted({ri["canonical_id"] for r in all_recipes for ri in r["ingredients"]} & SEAFOOD)
    if left:
        sys.exit(f"recipes still use seafood ingredients: {left}")
    db["ingredients"] = [i for i in db["ingredients"] if i["canonical_id"] not in SEAFOOD]
    photos = attach_photos(all_recipes) if not check_paths else 0
    return db, all_recipes, new, ids, errors, warns, dict(
        original=original, dropped=dropped, sides=sides, photos=photos)


def main():
    args = sys.argv[1:]
    if args and args[0] == "--check":
        paths = [os.path.abspath(p) for p in args[1:]]
        if not paths:
            sys.exit("usage: --check FILE [FILE...]")
        _, _, new, _, errors, warns, _ = build(DEFAULT_SOURCE, paths)
        for r in new:
            n = r["nutrition"]
            print(f"  #{r['id']} {r['title']}: {n['kcal']} kcal, {n['protein']} g protein, "
                  f"{r['minutes']} min, needs {r['needs'] or ['stove']}"
                  f"{', spicy' if r['spicy'] else ''}")
        for w in warns:
            print(f"WARNING {w}")
        for e in errors:
            print(f"ERROR {e}")
        print(f"{len(new)} recipes checked, {len(errors)} errors, {len(warns)} warnings")
        sys.exit(1 if errors else 0)

    src = args[0] if args else DEFAULT_SOURCE
    db, recipes, new, ids, errors, warns, stats = build(src)
    for w in warns:
        print(f"WARNING {w}", file=sys.stderr)
    if errors:
        for e in errors:
            print(f"ERROR {e}", file=sys.stderr)
        sys.exit(f"{len(errors)} errors; nothing written")

    for r in new:
        r.pop("key", None)
    db["recipes"] = recipes
    db["version"] = 7
    # Provenance: repo-relative path for the committed copy, otherwise the
    # file name of whatever .ipa or export it was built from.
    rel = os.path.relpath(os.path.abspath(src), ROOT).replace("\\", "/")
    db["source"] = rel if not rel.startswith("..") else os.path.basename(src)
    with open(RECIPE_IDS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(ids.items(), key=lambda kv: kv[1])), f, indent=1)
        f.write("\n")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(db, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Wrote {OUT}: {len(recipes)} recipes ({stats['original']} original, "
          f"{stats['dropped']} dropped, {len(new)} new; light dinners given a side: "
          f"{stats['sides']['rice']} rice, {stats['sides']['bread']} bread; "
          f"{stats['photos']} with photos), "
          f"{len(db['ingredients'])} ingredients ({os.path.getsize(OUT) // 1024} KB)")


if __name__ == "__main__":
    main()
