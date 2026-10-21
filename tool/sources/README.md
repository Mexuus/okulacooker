# Source data

Inputs the scripts in `tool/` turn into the files the app bundles in
`assets/data/`. They live here so a fresh clone can rebuild that data without
hunting down the originals.

| File | Used by | Origin |
|---|---|---|
| `mealplan.json` | `import_recipe_db.py` → `assets/data/recipe_db.json` | The original ReelChef/OkulaCooker iOS app's recipe database (`Payload/*.app/mealplan.json` inside the `.ipa`) |
| `bls_series.json` | `build_price_data.py` → `assets/data/prices.json` | Cached responses from the U.S. Bureau of Labor Statistics average-price API (public domain) |

`bls_series.json` is a cache, not a hand-written file: `build_price_data.py
--refresh` re-queries the API and rewrites it, which the monthly
`refresh-prices` workflow commits. Keeping it here means an ordinary build
spends none of the 25 queries per day the key-less API allows.

Large public downloads — the USDA ERS Food-at-Home area price file and the
store-location extracts — are **not** stored here. The scripts fetch them into
`build/` (gitignored) when needed.
