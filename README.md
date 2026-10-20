# TapCook

Plan the week's dinners and know what the groceries will cost before you leave
the house. Flutter app for **iOS and web**. No account, no server, no
subscription: everything runs on the device.

## Run

```powershell
flutter pub get
flutter run -d chrome        # web (works on Windows)
flutter test                 # unit + widget tests
flutter build web --release  # static site in build/web
```

iOS builds need macOS: use the CI workflows below, or a Mac with Xcode
(`flutter run -d ios`).

## How it works

| Area | Where | Notes |
|---|---|---|
| Recipes | `assets/data/recipe_db.json`, `lib/data/recipe_db.dart` | The original app's database: 494 dinners and 202 ingredients with pack sizes, prices, shelf life, nutrition, and phase-by-phase directions whose amounts scale with servings. |
| Meal planning | `lib/services/plan_generator.dart` | Suggested meals **never repeat**: every planned recipe is logged, and only after the whole library has been used do the longest-ago recipes return. Each week varies the main ingredient and cuisine and respects diet, won't-eat, and kitchen-gear settings (`lib/services/diet.dart`). Users can still pick any recipe (Browse, favorites, history) — chosen meals may repeat. |
| Grocery list | `lib/services/grocery_builder.dart` | Totals grams across the week, buys the cheapest combination of whole packs, leaves owned pantry staples off the bill, and separates fresh items when shopping two weeks at once. |
| Price estimates | `lib/services/pricing.dart`, `price_book.dart` | Per item: the database's national pack price × regional ratio (BLS average prices, or USDA food-group ratios) × USDA metro-area adjustment (10 large metros) × chain price level. Priced at the **specific store location** you pick. Estimates, not live shelf prices; tap any grocery item to see the breakdown. |
| Location | `lib/services/location_service.dart` | Device GPS via `geolocator`, reverse-geocoded **offline** to a ZIP using bundled U.S. Census ZCTA data (`assets/data/zcta.csv`). |
| Nearby stores | `lib/services/store_locator.dart`, `store_directory.dart` | Offline directory of ~24k US store locations (`assets/data/stores.csv`). Falls back to a live OpenStreetMap (Overpass) query only when nothing is found nearby. |

Privacy: GPS is used once to find the ZIP and is never stored. The optional
online store lookup sends only the ZIP's center point.

## Data refresh

| File | Source | License | Refresh |
|---|---|---|---|
| `assets/data/zcta.csv` | U.S. Census Bureau ZCTA Gazetteer | Public domain | Yearly; download `*_Gaz_zcta_national.zip` and keep `GEOID,INTPTLAT,INTPTLONG` |
| `assets/data/stores.csv` | [All The Places](https://alltheplaces.xyz) + OpenStreetMap | CC0 / ODbL (attribution shown in-app) | `python tool/build_store_directory.py` |
| `assets/data/recipe_db.json` | Original app's `mealplan.json` | Your own data | `python tool/import_recipe_db.py <path to .ipa or mealplan.json>` |
| `assets/data/prices.json` | BLS CPI Average Price Data + USDA ERS F-MAP | Public domain | Monthly via the **Refresh prices** workflow, or `python tool/build_price_data.py --refresh` |

The price script classifies each database ingredient with the regex `RULES`
table (BLS item code + USDA food group); anything unmatched falls back to its
category's food group. The importer validates that every recipe ingredient
converts to grams and packs.

When adding a chain, add it to `lib/data/stores.dart` **and** to the `BRANDS`
map in `tool/build_store_directory.py`. A test fails if the directory contains
a chain the app doesn't know.

## Host with Docker (Linux)

The image is a static web build served by unprivileged nginx on port 8080
(~60 MB, amd64 + arm64). Everything runs in the browser — no database or API
server; each visitor's plans live in their own browser storage.

**Option A — build on the server** (needs ~3 GB free disk for the build):

```sh
git clone https://github.com/Mexuus/tapcook.git && cd tapcook
docker compose up -d --build          # → http://SERVER_IP:8080
```

**Option B — pull the prebuilt image** CI publishes on every push to `main`.
The repo is private, so log in once with a personal access token that has
`read:packages`:

```sh
echo "$GHCR_TOKEN" | docker login ghcr.io -u Mexuus --password-stdin
TAPCOOK_IMAGE=ghcr.io/mexuus/tapcook:latest docker compose pull
TAPCOOK_IMAGE=ghcr.io/mexuus/tapcook:latest docker compose up -d
```

(Or without compose: `docker run -d --name tapcook --restart unless-stopped -p 8080:8080 ghcr.io/mexuus/tapcook:latest`.)

**HTTPS (required for the Locate/GPS button).** Browsers only allow location
access on HTTPS or `localhost`; over plain `http://SERVER_IP:8080` ZIP entry
still works but Locate is blocked. Point a domain at the server, open ports
80/443, and start the bundled Caddy proxy (automatic Let's Encrypt):

```sh
DOMAIN=tapcook.example.com docker compose --profile https up -d
```

LAN-only alternatives: Tailscale (`tailscale serve 8080`) or your existing
reverse proxy (Nginx Proxy Manager, Traefik) in front of port 8080.

**Other settings:** `TAPCOOK_PORT=9000` changes the host port. To serve under
a sub-path, build with `docker compose build --build-arg BASE_HREF=/tapcook/`
(the trailing slash matters). **Update:** `git pull && docker compose up -d --build`
(Option A) or `docker compose pull && docker compose up -d` (Option B).

## CI / releases

- **GitHub Actions** (`.github/workflows/ci.yml`): analyze + test + web build on
  every push, an **unsigned iOS build** on a macOS runner (downloadable `.ipa`
  artifact), a **Docker image** smoke-tested and published to
  `ghcr.io/mexuus/tapcook` (`latest` + `sha-…`) from `main`, and deployment of
  the web app to GitHub Pages from `main` (public repos only).
- **Codemagic** (`codemagic.yaml`): signed iOS build uploaded to TestFlight on
  tags `v*`. Requires an Apple Developer account and an App Store Connect API
  key added in Codemagic as `TapCook ASC`.

## Attribution

Store locations: All The Places (CC0) and © OpenStreetMap contributors (ODbL).
Prices: U.S. Bureau of Labor Statistics and USDA Economic Research Service.
ZIP centroids: U.S. Census Bureau. Typeface: Schibsted Grotesk (SIL OFL).
