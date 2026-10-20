"""Builds TapCook's offline store directory: assets/data/stores.csv

Sources (fetched at build time, never by the app at runtime):
  * All The Places (https://alltheplaces.xyz) - store-locator scrapes, CC0.
    Spiders whose latest scrape was incomplete are pinned to a good run.
  * OpenStreetMap via Overpass - only for chains All The Places lacks.
    (c) OpenStreetMap contributors, ODbL. Pass --skip-osm to omit.

Output rows:  store_id|lat|lng|city|state|street|label
`label` is only written when the location's own name differs from the chain
name (e.g. "Nob Hill Foods" priced as Raley's).

Usage:  python tool/build_store_directory.py [--skip-osm]
"""
import concurrent.futures
import csv
import json
import os
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "data", "stores.csv")
CACHE = os.path.join(ROOT, "build", "store_sources")
ATP = "https://alltheplaces-data.openaddresses.io/runs/{run}/output/{spider}.geojson"
UA = "TapCook-build/1.0 (offline store directory)"

PINNED = {
    "walmart_us": "2026-01-31-13-32-31",
    "stop_and_shop_us": "2026-07-11-13-32-25",
    "bjs_wholesale": "2026-08-22-13-32-16",
    "stater_bros_us": "2026-05-09-13-32-52",
}
SPIDERS = [
    "albertsons", "aldi_sud_us", "costco_ca_gb_us", "food_lion_us", "giant_eagle_us",
    "giant_food_stores", "giant_food_us", "h_e_b_us", "hannaford", "hy_vee_us", "ingles",
    "kroger_us", "lidl", "market_basket_us", "meijer_us", "piggly_wiggly_us", "publix_us",
    "raleys_us", "safeway", "sams_club", "save_mart_us", "shoprite_us", "smart_and_final_us",
    "sprouts_farmers_market", "target_us", "tops_us", "trader_joes_us", "wegmans_us",
    "whole_foods", "winn_dixie_us", *PINNED,
]
SHOP_TYPES = {"supermarket", "wholesale", "department_store", "grocery"}

# Brand (as published) -> TapCook store id. Unlisted brands are dropped.
BRANDS = {
    "Aldi": "aldi", "Albertsons": "albertsons", "Jewel-Osco": "jewel_osco", "Vons": "vons",
    "ACME Markets": "acme", "Acme": "acme", "Shaw's": "shaws", "Star Market": "star_market",
    "Tom Thumb": "tom_thumb", "Randalls": "randalls", "Pavilions": "pavilions",
    "Safeway": "safeway", "Costco": "costco", "Food Lion": "food_lion",
    "Giant Eagle": "giant_eagle", "Market District": "giant_eagle", "Giant": "giant",
    "H-E-B": "heb", "H-E-B plus!": "heb", "Hannaford": "hannaford", "Hy-Vee": "hy_vee",
    "Ingles": "ingles", "Kroger": "kroger", "Smith's": "smiths", "Fry's Food Stores": "frys",
    "Fred Meyer": "fred_meyer", "King Soopers": "king_soopers", "City Market": "king_soopers",
    "Ralphs": "ralphs", "Dillons": "dillons", "Food 4 Less": "food_4_less",
    "Foods Co": "food_4_less", "QFC": "qfc", "Mariano's Fresh Market": "marianos",
    "Pick 'n Save": "pick_n_save", "Metro Market": "pick_n_save", "Lidl": "lidl",
    "Market Basket": "market_basket", "Meijer": "meijer", "Piggly Wiggly": "piggly_wiggly",
    "Publix": "publix", "Raley's": "raleys", "Bel Air": "raleys", "Nob Hill Foods": "raleys",
    "Sam's Club": "sams_club", "Save Mart": "save_mart", "Lucky": "lucky",
    "FoodMaxx": "foodmaxx", "ShopRite": "shoprite", "Smart & Final": "smart_final",
    "Sprouts Farmers Market": "sprouts", "Target": "target", "Tops": "tops",
    "Trader Joe's": "trader_joes", "Walmart": "walmart", "Walmart Supercenter": "walmart",
    "Walmart Neighborhood Market": "walmart", "Wegmans": "wegmans",
    "Whole Foods Market": "whole_foods", "Winn-Dixie": "winn_dixie",
    "BJ's Wholesale Club": "bjs", "BJ's": "bjs", "Stop & Shop": "stop_shop",
    "Stater Bros.": "stater_bros", "Stater Bros": "stater_bros", "WinCo Foods": "winco",
    "Harris Teeter": "harris_teeter", "Weis": "weis", "Weis Markets": "weis",
    "Price Chopper": "price_chopper", "Market 32": "price_chopper",
}

OSM_QUERIES = {
    "osm_west": "WinCo Foods|Pavilions",
    "osm_east": "Harris Teeter|Weis|Weis Markets|Price Chopper|Market 32",
}
OVERPASS = [
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass-api.de/api/interpreter",
]


def fetch(url, path, data=None, timeout=300):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read()
    with open(path, "wb") as f:
        f.write(body)
    return path


def latest_run():
    req = urllib.request.Request("https://data.alltheplaces.xyz/runs/latest.json",
                                 headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["run_id"]


def atp_rows(run):
    def get(spider):
        r = PINNED.get(spider, run)
        return fetch(ATP.format(run=r, spider=spider),
                     os.path.join(CACHE, f"{spider}@{r}.geojson"))

    with concurrent.futures.ThreadPoolExecutor(8) as ex:
        paths = list(ex.map(get, SPIDERS))
    for path in paths:
        for feat in json.load(open(path, encoding="utf-8"))["features"]:
            p = feat.get("properties") or {}
            g = feat.get("geometry") or {}
            if g.get("type") != "Point" or (p.get("addr:country") or "US") != "US":
                continue
            if p.get("shop") not in SHOP_TYPES:
                continue
            lng, lat = g["coordinates"][:2]
            street = p.get("addr:street_address") or " ".join(
                x for x in (p.get("addr:housenumber"), p.get("addr:street")) if x)
            yield (p.get("brand") or p.get("name"), p.get("name"), lat, lng,
                   p.get("addr:city"), p.get("addr:state"), street)


def osm_rows():
    for key, brands in OSM_QUERIES.items():
        q = ('[out:csv(::lat,::lon,brand,name,"addr:city","addr:state","addr:housenumber",'
             '"addr:street";true;"|")][timeout:240];area["ISO3166-1"="US"][admin_level=2]->.us;'
             f'nwr["shop"="supermarket"]["brand"~"^({brands})$"](area.us);out center;')
        path = os.path.join(CACHE, f"{key}.csv")
        ok = os.path.exists(path) and sum(1 for _ in open(path, encoding="utf-8")) > 20
        for attempt in range(8):
            if ok:
                break
            ep = OVERPASS[attempt % len(OVERPASS)]
            try:
                if os.path.exists(path):
                    os.remove(path)
                fetch(ep, path, urllib.parse.urlencode({"data": q}).encode(), timeout=260)
                ok = sum(1 for _ in open(path, encoding="utf-8")) > 20
            except Exception as e:  # noqa: BLE001 - public mirrors fail often
                print(f"  {key}: {ep} failed ({e})", file=sys.stderr)
            if not ok:
                time.sleep(5)
        if not ok:
            print(f"  {key}: all Overpass mirrors failed; skipping", file=sys.stderr)
            continue
        for r in csv.DictReader(open(path, encoding="utf-8"), delimiter="|"):
            street = " ".join(x for x in (r.get("addr:housenumber"), r.get("addr:street")) if x)
            yield (r["brand"], r["name"], float(r["@lat"]), float(r["@lon"]),
                   r.get("addr:city"), r.get("addr:state"), street)


def clean(s):
    return (s or "").replace("|", " ").strip()


def main():
    os.makedirs(CACHE, exist_ok=True)
    run = latest_run()
    print(f"All The Places run {run}")
    sources = list(atp_rows(run))
    if "--skip-osm" not in sys.argv:
        sources += list(osm_rows())

    seen, out, unmapped, chain_name = set(), [], {}, {}
    for brand, name, lat, lng, city, state, street in sources:
        sid = BRANDS.get(brand)
        if not sid:
            unmapped[brand] = unmapped.get(brand, 0) + 1
            continue
        if sid == "price_chopper" and lng < -82:  # Kansas City's unrelated chain
            continue
        if not (17 < lat < 72 and -180 < lng < -64):
            continue
        key = (sid, round(lat, 3), round(lng, 3))
        if key in seen:
            continue
        seen.add(key)
        chain_name.setdefault(sid, brand)
        label = name if name and name not in (brand, chain_name[sid]) else ""
        out.append("|".join([sid, f"{lat:.4f}", f"{lng:.4f}", clean(city), clean(state),
                             clean(street), clean(label)]))

    out.sort()
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")

    counts = {}
    for line in out:
        sid = line.split("|", 1)[0]
        counts[sid] = counts.get(sid, 0) + 1
    print(f"Wrote {len(out)} stores ({os.path.getsize(OUT) // 1024} KB) -> {OUT}")
    print("  " + ", ".join(f"{sid} {n}" for sid, n in sorted(counts.items(), key=lambda kv: -kv[1])))
    if unmapped:
        top = sorted(unmapped.items(), key=lambda kv: -kv[1])[:20]
        print("Dropped (unmapped brands):", ", ".join(f"{b} ({n})" for b, n in top))


if __name__ == "__main__":
    main()
