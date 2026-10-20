"""Builds TapCook's local price book: assets/data/prices.json

Sources (public domain, no account needed):
  * BLS CPI Average Price Data (series APU<area><item>) - current average
    retail prices nationally and for the 4 Census regions.
    https://www.bls.gov/cpi/factsheets/average-prices.htm
  * USDA ERS Food-at-Home Monthly Area Prices (F-MAP) - spatial price indexes
    for 90 food groups in 4 regions and 10 metro areas. Used for metro-level
    adjustments and to regionalise items BLS doesn't price.
    https://www.ers.usda.gov/data-products/food-at-home-monthly-area-prices

Items without a BLS series keep the hand-entered national estimate from
lib/data/catalog.dart (marked "est" in the output) and are regionalised with
F-MAP food-group ratios.

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
CATALOG = os.path.join(ROOT, "lib", "data", "catalog.dart")
CACHE = os.path.join(ROOT, "build", "price_sources")
BLS_CACHE = os.path.join(CACHE, "bls_series.json")
FMAP_URL = "https://www.ers.usda.gov/media/5400/food-at-home-monthly-area-prices-2012-to-2018.zip?v=40678"
UA = "TapCook-build/1.0 (grocery price data refresh)"

REGIONS = {"US": "0000", "NE": "0100", "MW": "0200", "S": "0300", "W": "0400"}
FMAP_REGION = {"NE": "1", "MW": "2", "S": "3", "W": "4"}

# ingredient id -> (BLS item code or None, BLS units per recipe unit, F-MAP EFPG code, note)
# "BLS units per recipe unit" converts e.g. $/lb into $/cup using typical weights.
ITEMS = {
    # Produce
    "onion": ("712404", 0.50, "29000", "medium onion ≈ 0.5 lb"),
    "garlic": (None, 0, "29000", ""),
    "bell_pepper": ("712406", 0.37, "24500", "pepper ≈ 6 oz"),
    "tomato": ("712311", 0.33, "23000", "tomato ≈ 5 oz"),
    "roma_tomato": ("712311", 0.15, "23000", "roma ≈ 2.4 oz"),
    "romaine": ("FL2101", 1.2, "26000", "head ≈ 1.2 lb"),
    "lemon": ("711412", 0.22, "30000", "lemon ≈ 3.5 oz"),
    "lime": (None, 0, "30000", ""),
    "potato": ("712112", 1.0, "20000", ""),
    "sweet_potato": (None, 0, "24500", ""),
    "broccoli": ("712412", 1.0, "26000", ""),
    "carrot": ("712403", 1.0, "24500", ""),
    "zucchini": (None, 0, "29000", ""),
    "mushroom": ("712411", 1 / 16, "29000", "per oz"),
    "spinach": (None, 0, "26000", ""),
    "cilantro": (None, 0, "29000", ""),
    "green_onion": ("712405", 0.22, "29000", "bunch ≈ 3.5 oz"),
    "avocado": (None, 0, "30000", ""),
    "ginger": (None, 0, "29000", ""),
    "jalapeno": (None, 0, "29000", ""),
    "snap_peas": (None, 0, "29000", ""),
    "cucumber": ("712409", 0.66, "29000", "cucumber ≈ 10.5 oz"),
    "celery": ("712402", 0.09, "29000", "stalk ≈ 1.4 oz"),
    "coleslaw_mix": (None, 0, "29025", ""),
    "tofu": (None, 0, "59000", ""),
    # Meat & seafood
    "ground_beef": ("703112", 1.0, "50000", ""),
    "ground_turkey": (None, 0, "51500", ""),
    "chicken_breast": ("FF1101", 1.0, "51500", "boneless"),
    "chicken_thigh": ("706212", 1.0, "51500", "priced as bone-in chicken legs"),
    "pork_chop": ("FD3101", 1.0, "50000", "all pork chops"),
    "pork_shoulder": ("704411", 1.0, "50000", "blade Boston roast"),
    "bacon": ("704111", 1 / 16, "56000", "per oz"),
    "italian_sausage": ("704421", 1.0, "56000", "fresh sausage"),
    "flank_steak": ("FC3101", 1.0, "50000", "priced as all uncooked beef steaks"),
    "salmon": (None, 0, "53000", ""),
    "shrimp": (None, 0, "53050", ""),
    "tilapia": (None, 0, "53050", ""),
    "tuna_can": ("707111", 5 / 16, "53075", "5 oz can"),
    # Dairy & eggs
    "milk": ("709112", 1 / 16, "40000", "cup of a gallon"),
    "butter": ("FS1101", 1 / 32, "70000", "tbsp"),
    "egg": ("708111", 1 / 12, "57500", "one egg of a dozen"),
    "cheddar": ("710212", 1 / 16, "46000", "per oz"),
    "mozzarella": (None, 0, "46000", ""),
    "parmesan": (None, 0, "46000", ""),
    "sour_cream": (None, 0, "40030", ""),
    "greek_yogurt": ("FJ4101", 1 / 8, "40060", "priced as yogurt, per oz"),
    "heavy_cream": (None, 0, "40030", ""),
    "feta": (None, 0, "46000", ""),
    # Bakery / frozen
    "tortilla": (None, 0, "15000", ""),
    "burger_bun": (None, 0, "15000", ""),
    "sandwich_roll": (None, 0, "15000", ""),
    "flatbread": (None, 0, "15000", ""),
    "wrap_large": (None, 0, "15000", ""),
    "pita": (None, 0, "15000", ""),
    "frozen_peas": (None, 0, "21550", ""),
    # Grains
    "spaghetti": ("701322", 1 / 16, "15025", "per oz"),
    "penne": ("701322", 1 / 16, "15025", "per oz"),
    "fettuccine": ("701322", 1 / 16, "15025", "per oz"),
    "egg_noodles": ("701322", 1 / 16, "15025", "priced as pasta, per oz"),
    "rice_white": ("701312", 0.41, "15025", "cup dry ≈ 0.41 lb"),
    "rice_jasmine": ("701312", 0.41, "15025", "priced as long-grain rice"),
    "breadcrumbs": (None, 0, "15075", ""),
    "lentils": ("714233", 0.42, "27500", "priced as dried beans, cup ≈ 0.42 lb"),
    "flour": ("701111", 0.276, "15075", "cup ≈ 0.28 lb"),
    # Canned
    "black_beans": (None, 0, "27575", ""),
    "kidney_beans": (None, 0, "27575", ""),
    "chickpeas": (None, 0, "27575", ""),
    "diced_tomatoes": (None, 0, "23075", ""),
    "tomato_sauce": (None, 0, "23075", ""),
    "pasta_sauce": (None, 0, "71000", ""),
    "coconut_milk": (None, 0, "71000", ""),
    "corn_can": ("714221", 0.94, "21575", "15 oz can"),
    "chicken_broth": (None, 0, "65000", ""),
    "veg_broth": (None, 0, "65000", ""),
    # Condiments, spices, pantry
    "pesto": (None, 0, "71000", ""),
    "olive_oil": (None, 0, "70000", ""),
    "veg_oil": (None, 0, "70000", ""),
    "soy_sauce": (None, 0, "71000", ""),
    "teriyaki": (None, 0, "71000", ""),
    "bbq_sauce": (None, 0, "71000", ""),
    "honey": (None, 0, "73000", ""),
    "ketchup": (None, 0, "71000", ""),
    "mayo": (None, 0, "70050", ""),
    "caesar_dressing": (None, 0, "70050", ""),
    "cornstarch": (None, 0, "15075", ""),
    "sesame_oil": (None, 0, "70000", ""),
    "salt": (None, 0, "71050", ""),
    "pepper": (None, 0, "71050", ""),
    "cumin": (None, 0, "71050", ""),
    "chili_powder": (None, 0, "71050", ""),
    "paprika": (None, 0, "71050", ""),
    "garlic_powder": (None, 0, "71050", ""),
    "italian_seasoning": (None, 0, "71050", ""),
    "curry_powder": (None, 0, "71050", ""),
    "taco_seasoning": (None, 0, "71050", ""),
    "sugar": ("715211", 0.00926, "73000", "tsp ≈ 4.2 g"),
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


def catalog_estimates():
    src = open(CATALOG, encoding="utf-8").read()
    est = {m.group(1): float(m.group(2)) for m in re.finditer(
        r"'(\w+)':\s*Ingredient\(.*?refPricePerUnit:\s*([\d.]+)", src)}
    missing = set(est) ^ set(ITEMS)
    if missing:
        sys.exit(f"ITEMS and catalog.dart disagree on: {sorted(missing)}")
    return est


def bls_fetch(series_ids, refresh):
    cache = json.load(open(BLS_CACHE)) if os.path.exists(BLS_CACHE) and not refresh else {}
    todo = [s for s in series_ids if s not in cache]
    key = os.environ.get("BLS_API_KEY")
    url = f"https://api.bls.gov/publicAPI/{'v2' if key else 'v1'}/timeseries/data/"
    year = dt.date.today().year
    for i in range(0, len(todo), 50 if key else 25):
        batch = todo[i:i + (50 if key else 25)]
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
    os.makedirs(CACHE, exist_ok=True)
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
    """2018 mean GEKS index per (EFPG, area)."""
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
    est = catalog_estimates()
    codes = sorted({c for c, *_ in ITEMS.values() if c})
    series = [f"APU{area}{code}" for code in codes for area in REGIONS.values()]
    bls = bls_fetch(series, refresh)
    newest = max((d for obs in bls.values() for d, _ in obs), default="2000-01")
    fmap = fmap_indexes()

    def fmap_ratio(efpg, area, base):
        a, b = fmap.get((efpg, area)), fmap.get((efpg, base))
        return clamp(a / b) if a and b else 1.0

    items, stale = {}, []
    for iid, (code, per_unit, efpg, note) in ITEMS.items():
        entry = {"efpg": efpg}
        us = None
        if code:
            us_val, latest = recent_value(bls.get(f"APU0000{code}"), newest)
            if us_val is None:
                stale.append(f"{iid} ({code}, last {latest})")
            else:
                us = us_val * per_unit
                entry.update(src="bls", code=code, asOf=latest, note=note)
        if us is None:
            us = est[iid]
            entry["src"] = "est"
        entry["US"] = round(us, 4)
        for reg, area in REGIONS.items():
            if reg == "US":
                continue
            val = None
            if entry["src"] == "bls":
                v, _ = recent_value(bls.get(f"APU{area}{code}"), newest)
                if v is not None:
                    val = v * per_unit
            if val is None:
                val = us * fmap_ratio(efpg, FMAP_REGION[reg], "0")
            entry[reg] = round(val, 4)
        items[iid] = entry

    efpgs = sorted({e for *_, e, _ in ITEMS.values()})
    metros = []
    for mcode, (name, reg, lat, lng, radius) in METROS.items():
        f = {e: round(fmap_ratio(e, mcode, FMAP_REGION[reg]), 3) for e in efpgs}
        metros.append({"code": mcode, "name": name, "region": reg, "lat": lat, "lng": lng,
                       "radiusMi": radius, "factors": f})

    out = {
        "asOf": newest,
        "sources": {
            "bls": "U.S. Bureau of Labor Statistics, CPI Average Price Data",
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
    print(f"Wrote {OUT}: {len(items)} items ({n_bls} from BLS, {len(items) - n_bls} estimates), "
          f"{len(metros)} metros, prices as of {newest}")
    if stale:
        print("BLS series skipped as stale/missing:", ", ".join(stale))


if __name__ == "__main__":
    main()
