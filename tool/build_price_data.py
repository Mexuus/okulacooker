"""Builds OkulaCooker's local price book: assets/data/prices.json

National prices come from the recipe database's per-pack reference prices
(the original app's model). This script adds how those prices vary by place:
  * BLS CPI Average Price Data (series APU<area><item>) - regional ratio
    (region price ÷ national price) for items BLS still prices.
    https://www.bls.gov/cpi/factsheets/average-prices.htm
  * USDA ERS Food-at-Home Monthly Area Prices (F-MAP) - food-group spatial
    indexes for 4 regions and 10 metro areas: regional ratios for everything
    else, and metro-vs-region adjustments.
    https://www.ers.usda.gov/data-products/food-at-home-monthly-area-prices

Usage:
  python tool/build_price_data.py            # uses cached BLS responses if present
  python tool/build_price_data.py --refresh  # re-query BLS
Set BLS_API_KEY to use the BLS v2 API (500 queries/day instead of 25).
"""
import csv
import datetime as dt
import io
import json
import os
import re
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "data", "prices.json")
RECIPE_DB = os.path.join(ROOT, "assets", "data", "recipe_db.json")
CACHE = os.path.join(ROOT, "build", "price_sources")
# Committed so a fresh clone can rebuild prices without spending BLS queries
# (the free API allows 25 per day); --refresh rewrites it.
BLS_CACHE = os.path.join(ROOT, "tool", "sources", "bls_series.json")
FMAP_URL = "https://www.ers.usda.gov/media/5400/food-at-home-monthly-area-prices-2012-to-2018.zip?v=40678"
UA = "OkulaCooker-build/1.0 (grocery price data refresh)"

REGIONS = {"US": "0000", "NE": "0100", "MW": "0200", "S": "0300", "W": "0400"}
FMAP_REGION = {"NE": "1", "MW": "2", "S": "3", "W": "4"}

# First matching rule wins: (regex on ingredient id, BLS item code or None, F-MAP food group).
RULES = [
    # Protein
    (r"^chicken_breast", "FF1101", "51500"),
    (r"^chicken_whole", "706111", "51500"),
    (r"^chicken_", "706212", "51500"),
    (r"^ground_turkey", None, "51500"),
    (r"^ground_beef", "703112", "50000"),
    (r"^beef_steak", "FC3101", "50000"),
    (r"^beef_chuck", "703211", "50000"),
    (r"^pork_chop", "FD3101", "50000"),
    (r"^(ground_pork|pork_shoulder|lamb_ground)", None, "50000"),
    (r"^bacon", "704111", "56000"),
    (r"^(sausage_|pancetta|prosciutto|pepperoni)", "704421", "56000"),
    (r"^egg_large", "708111", "57500"),
    (r"^(tofu|tempeh)", None, "59000"),
    # Dairy
    (r"^milk_whole", "709112", "40000"),
    (r"^plant_milk", None, "43000"),
    (r"^butter", "FS1101", "70000"),
    (r"^cheddar", "710212", "46000"),
    (r"^(cream_heavy|sour_cream)", None, "40030"),
    (r"^yogurt", "FJ4101", "40060"),
    (r"^(ricotta|goat_cheese|parmesan|mozzarella|cream_cheese|feta)", None, "46000"),
    # Produce
    (r"^potato_", "712112", "20000"),
    (r"^tomato_(fresh|cherry)", "712311", "23000"),
    (r"^lettuce_romaine", "FL2101", "26000"),
    (r"^(broccoli|spinach|kale|arugula|bok_choy)", None, "26000"),
    (r"^(bell_pepper|carrot|sweet_potato|butternut)", None, "24500"),
    (r"^lemon", "711412", "30000"),
    (r"^orange$", "711311", "30000"),
    (r"^(lime|avocado)", None, "30000"),
    (r"^cabbage", "712401", "29000"),
    (r"^celery", "712402", "29000"),
    (r"^onion_(yellow|red)", "712404", "29000"),
    (r"^cucumber", "712409", "29000"),
    (r"^mushroom", "712411", "29000"),
    # Grains & bakery
    (r"^(pasta_|noodle_egg|tortellini|gnocchi)", "701322", "15025"),
    (r"^rice_(long_grain|basmati)|^arborio_rice", "701312", "15025"),
    (r"^(rice_noodle|quinoa|couscous|polenta)", None, "15025"),
    (r"^flour_ap", "701111", "15075"),
    (r"^(breadcrumb|cornstarch|baking_)", None, "15075"),
    (r"^bread_sandwich", "702111", "15000"),
    (r"^(bread_|bun_|pita|tortilla_|pie_crust)", None, "15000"),
    # Canned
    (r"^bean_.*_canned", None, "27575"),
    (r"^(bean_dried|lentil_dried)", "714233", "27500"),
    (r"^tomato_(canned|paste|sauce)|^marinara", None, "23075"),
    (r"^corn_canned", "714221", "21575"),
    (r"^(broth_|cream_of_|coconut_milk)", None, "65000"),
    # Frozen
    (r"^(peas|corn)_frozen", None, "21550"),
    (r"^edamame", None, "27550"),
    # Pantry
    (r"^(olive_oil|oil_|sesame_oil)", None, "70000"),
    (r"^(mayo)", None, "70050"),
    (r"^(honey|maple_syrup)", None, "73000"),
    (r"^sugar_white", "715211", "73000"),
    (r"^sugar_", None, "73000"),
    (r"^peanut_butter", "716141", "54550"),
    (r"^(tahini)", None, "54550"),
    (r"^(peanut_raw|cashew|pepita|sesame_seed)", None, "54500"),
    (r"^wine_", None, "72050"),
]
CATEGORY_GROUP = {
    "produce": "29000", "herb": "29000", "canned": "71000", "pantry": "71000",
    "spice": "71050", "grain": "15025", "dairy": "46000", "bakery": "15000",
    "frozen": "21550", "protein": "50000",
}

# F-MAP metro areas: code -> (name, Census region, lat, lng, radius in miles)
METROS = {
    "12060": ("Atlanta", "S", 33.749, -84.388, 45),
    "14460": ("Boston", "NE", 42.360, -71.059, 40),
    "16980": ("Chicago", "MW", 41.878, -87.630, 45),
    "19100": ("Dallas–Fort Worth", "S", 32.840, -97.050, 50),
    "19820": ("Detroit", "MW", 42.400, -83.150, 40),
    "26420": ("Houston", "S", 29.760, -95.370, 50),
    "31080": ("Los Angeles", "W", 33.950, -118.150, 55),
    "33100": ("Miami", "S", 26.150, -80.200, 60),
    "35620": ("New York", "NE", 40.713, -74.006, 40),
    "37980": ("Philadelphia", "NE", 39.953, -75.165, 30),
}

MAX_STALE_MONTHS = 12
CLAMP = (0.8, 1.25)


def ingredients():
    db = json.load(open(RECIPE_DB, encoding="utf-8"))
    return [(i["canonical_id"], i["category"]) for i in db["ingredients"]]


def classify(iid, category):
    for pattern, code, group in RULES:
        if re.search(pattern, iid):
            return code, group
    return None, CATEGORY_GROUP[category]


def bls_fetch(series_ids, refresh):
    cache = json.load(open(BLS_CACHE)) if os.path.exists(BLS_CACHE) and not refresh else {}
    todo = [s for s in series_ids if s not in cache]
    key = os.environ.get("BLS_API_KEY")
    url = f"https://api.bls.gov/publicAPI/{'v2' if key else 'v1'}/timeseries/data/"
    year = dt.date.today().year
    step = 50 if key else 25
    for i in range(0, len(todo), step):
        batch = todo[i:i + step]
        body = {"seriesid": batch, "startyear": str(year - 2), "endyear": str(year)}
        if key:
            body["registrationkey"] = key
        req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": UA})
        resp = json.load(urllib.request.urlopen(req, timeout=60))
        if resp.get("status") != "REQUEST_SUCCEEDED":
            sys.exit(f"BLS API error: {resp.get('message')}")
        for s in resp["Results"]["series"]:
            cache[s["seriesID"]] = [
                (f"{d['year']}-{d['period'][1:]}", float(d["value"]))
                for d in s.get("data", []) if d["period"].startswith("M") and d["value"] not in ("-", "")
            ]
        print(f"  BLS: fetched {len(batch)} series", file=sys.stderr)
    os.makedirs(os.path.dirname(BLS_CACHE), exist_ok=True)
    json.dump(cache, open(BLS_CACHE, "w"))
    return cache


def recent_value(obs, newest):
    """Mean of up to the 3 latest monthly values, if not stale."""
    if not obs:
        return None, None
    obs = sorted(obs, reverse=True)
    latest = obs[0][0]
    ny, nm = map(int, newest.split("-"))
    ly, lm = map(int, latest.split("-"))
    if (ny - ly) * 12 + (nm - lm) > MAX_STALE_MONTHS:
        return None, latest
    vals = [v for _, v in obs[:3]]
    return sum(vals) / len(vals), latest


def fmap_indexes():
    """2018 mean GEKS index per (food group, area)."""
    path = os.path.join(CACHE, "fmap", "FMAP-Data.csv")
    if not os.path.exists(path):
        print("  downloading USDA F-MAP…", file=sys.stderr)
        data = urllib.request.urlopen(urllib.request.Request(
            FMAP_URL, headers={"User-Agent": "Mozilla/5.0 " + UA}), timeout=300).read()
        zipfile.ZipFile(io.BytesIO(data)).extractall(os.path.join(CACHE, "fmap"))
    acc = {}
    for r in csv.DictReader(open(path)):
        if r["Year"] == "2018" and r["Attribute"] == "Price_index_GEKS":
            k = (r["EFPG_code"], r["Metroregion_code"])
            s, n = acc.get(k, (0.0, 0))
            acc[k] = (s + float(r["Value"]), n + 1)
    return {k: s / n for k, (s, n) in acc.items()}


def clamp(x):
    return max(CLAMP[0], min(CLAMP[1], x))


def main():
    refresh = "--refresh" in sys.argv
    ings = [(iid, *classify(iid, cat)) for iid, cat in ingredients()]
    codes = sorted({code for _, code, _ in ings if code})
    bls = bls_fetch([f"APU{a}{c}" for c in codes for a in REGIONS.values()], refresh)
    newest = max((d for obs in bls.values() for d, _ in obs), default="2000-01")
    fmap = fmap_indexes()

    def fmap_ratio(group, area, base):
        a, b = fmap.get((group, area)), fmap.get((group, base))
        return clamp(a / b) if a and b else 1.0

    items, stale = {}, set()
    for iid, code, group in ings:
        entry = {"efpg": group, "src": "fmap"}
        us = None
        if code:
            us, latest = recent_value(bls.get(f"APU0000{code}"), newest)
            if us is None:
                stale.add(f"{code} (last {latest})")
            else:
                entry.update(src="bls", code=code, asOf=latest)
        for reg, area in REGIONS.items():
            if reg == "US":
                continue
            ratio = None
            if us:
                v, _ = recent_value(bls.get(f"APU{area}{code}"), newest)
                if v is not None:
                    ratio = clamp(v / us)
            if ratio is None:
                ratio = fmap_ratio(group, FMAP_REGION[reg], "0")
            entry[reg] = round(ratio, 4)
        items[iid] = entry

    groups = sorted({g for _, _, g in ings})
    metros = [
        {"code": m, "name": name, "region": reg, "lat": lat, "lng": lng, "radiusMi": radius,
         "factors": {g: round(fmap_ratio(g, m, FMAP_REGION[reg]), 3) for g in groups}}
        for m, (name, reg, lat, lng, radius) in METROS.items()
    ]

    out = {
        "asOf": newest,
        "sources": {
            "bls": "U.S. Bureau of Labor Statistics, CPI Average Price Data (regional ratios)",
            "fmap": "USDA ERS Food-at-Home Monthly Area Prices (2018 spatial indexes)",
        },
        "items": items,
        "metros": metros,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    n_bls = sum(1 for v in items.values() if v["src"] == "bls")
    print(f"Wrote {OUT}: {len(items)} ingredients ({n_bls} with BLS regional prices, "
          f"{len(items) - n_bls} with USDA food-group ratios), {len(metros)} metros, as of {newest}")
    if stale:
        print("BLS series without current data (USDA ratios used):", ", ".join(sorted(stale)))


if __name__ == "__main__":
    main()
