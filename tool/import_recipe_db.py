"""Imports the original ReelChef/TapCook recipe database into this app.

Reads `Payload/*.app/mealplan.json` from the original .ipa (or an extracted
mealplan.json), keeps every recipe verbatim, and augments each ingredient with:
  * aisle      - grocery-list section
  * g_per_pack - grams in one pack, so recipe amounts convert to packs to buy
  * packs      - purchasable pack options (small/family tiers where known)

Usage:
  python tool/import_recipe_db.py [path/to/app.ipa | path/to/mealplan.json]
Writes assets/data/recipe_db.json.
"""
import json
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "data", "recipe_db.json")
DEFAULT_IPA = os.path.expanduser(
    r"~\OneDrive\Documents\com.testmaxx.reelchef_6769601354_2.1.6.ipa")

G_PER_LB = 453.592
G_PER_OZ = 28.3495
ML_PER_CUP = 236.588
ML_PER_GAL = 3785.41

# Typical weight of one bunch (the source data sells these by the bunch).
BUNCH_GRAMS = {"cilantro": 60, "parsley_fresh": 60, "kale": 280, "scallion": 100, "celery": 450}

# "count" means a whole head for garlic (g_per_count in the source is per clove).
COUNT_GRAMS = {"garlic_head": 30}

SEAFOOD = {"salmon_fillet", "shrimp_frozen", "tilapia_fillet"}
AISLE_BY_CATEGORY = {
    "produce": "produce", "herb": "produce", "canned": "canned", "pantry": "pantry",
    "spice": "spices", "grain": "grains", "dairy": "dairy", "bakery": "bakery",
    "frozen": "frozen", "protein": "meat",
}

TIER_RE = re.compile(r"(\w+)\s+([\d.]+)\s*(lb|oz|count)\s+\$([\d.]+)")


def load_source(path):
    if path.lower().endswith(".ipa"):
        with zipfile.ZipFile(path) as z:
            name = next(n for n in z.namelist() if n.endswith(".app/mealplan.json"))
            return json.loads(z.read(name).decode("utf-8"))
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
        if cid in SEAFOOD:
            return "seafood"
        if cid == "egg_large":
            return "dairy"
        if cid in ("tofu_firm", "tempeh"):
            return "produce"
    return AISLE_BY_CATEGORY[cat]


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_IPA
    db = load_source(src)
    for ing in db["ingredients"]:
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
        if ing["g_per_pack"] <= 0:
            sys.exit(f"{ing['canonical_id']}: could not compute grams per pack")

    by_id = {i["canonical_id"]: i for i in db["ingredients"]}
    bad = {ri["canonical_id"] for r in db["recipes"] for ri in r["ingredients"]} - set(by_id)
    if bad:
        sys.exit(f"recipes reference unknown ingredients: {sorted(bad)}")
    unconvertible = sorted({f"{ri['canonical_id']}:{ri['unit']}" for r in db["recipes"]
                            for ri in r["ingredients"]
                            if ri["unit"] not in by_id[ri["canonical_id"]]["unit_grams"]})
    if unconvertible:
        sys.exit(f"no gram conversion for: {unconvertible}")

    db["source"] = os.path.basename(src)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(db, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Wrote {OUT}: {len(db['recipes'])} recipes, {len(db['ingredients'])} ingredients "
          f"({os.path.getsize(OUT) // 1024} KB) from {db['source']} (v{db['version']})")


if __name__ == "__main__":
    main()
