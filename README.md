# OkulaCooker

Plan the week's dinners and know what the groceries will cost before you leave
the house. Flutter app for **iOS and web**. No account, no server, no
subscription: everything runs on the device.

**Try it:** <https://mexuus.github.io/okulacooker/> ·
**Self-host:** `docker run -d -p 8080:8080 ghcr.io/mexuus/okulacooker:latest`
(see [Install on ZimaOS](#install-on-zimaos) / [Host with Docker](#host-with-docker-linux))

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
| Recipes | `assets/data/recipe_db.json`, `lib/data/recipe_db.dart` | Built by `tool/import_recipe_db.py` from the original app's database, curated (`tool/sources/curation.json` drops side dishes, odd combinations and near-duplicates and fixes portions), plus new popular recipes for the Instant Pot, grill, air fryer and slow cooker (`tool/sources/recipes/`). Every recipe is a full dinner (about 450–950 kcal per serving) with directions whose amounts scale with servings and round to kitchen measures. |
| Meal planning | `lib/services/plan_generator.dart` | Suggested meals **never repeat**: every planned recipe is logged, and only after the whole library has been used do the longest-ago recipes return. Each week varies the main ingredient and cuisine and respects diet, won't-eat, gear, time-limit, easy-only and mild settings (`lib/services/diet.dart`), and plans the chosen number of nights for special gear. Thumbs up/down nudge which new recipes come first; thumbed-down recipes are never suggested. Users can still pick any recipe — chosen meals may repeat. |
| Pictures | `assets/photos/`, `assets/icons/food/` | Free-licensed dish photos from Wikimedia Commons (credited in-app, rebuilt by `tool/build_photos.py`); recipes without one show an illustrated plate of their main ingredients using Microsoft Fluent Emoji 3D icons (MIT, `tool/build_icons.py`). |
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
| `assets/data/recipe_db.json` | `tool/sources/` (original database, curation, new recipes, extra ingredients) | Your own data | `python tool/import_recipe_db.py` — see `tool/sources/recipes/README.md` to add recipes |
| `assets/data/prices.json` | BLS CPI Average Price Data + USDA ERS F-MAP | Public domain | Monthly via the **Refresh prices** workflow, or `python tool/build_price_data.py --refresh` |
| `assets/photos/` | Wikimedia Commons | CC0 / PD / CC BY / CC BY-SA (credited in-app) | `python tool/build_photos.py` from `tool/sources/recipe_photos_*.json` |
| `assets/icons/food/` | Microsoft Fluent Emoji (3D) | MIT (`assets/icons/LICENSE.txt`) | `python tool/build_icons.py` from `tool/sources/ingredient_icons.json` |

The price script classifies each database ingredient with the regex `RULES`
table (BLS item code + USDA food group); anything unmatched falls back to its
category's food group. The importer validates that every recipe ingredient
converts to grams and packs, tags ingredients with diet flags (`FLAGS`) and
recipes with the gear they need, spiciness and per-serving nutrition, and
rejects new recipes whose portions fall outside 380–1100 kcal.

When adding a chain, add it to `lib/data/stores.dart` **and** to the `BRANDS`
map in `tool/build_store_directory.py`. A test fails if the directory contains
a chain the app doesn't know.

## Install on ZimaOS

The image is public, so ZimaOS can pull it without a GitHub login.

1. ZimaOS → **App Store** → **+** → *Install a customized app* → **Import**.
2. Paste [`zimaos-compose.yml`](zimaos-compose.yml) (or its
   [raw URL](https://raw.githubusercontent.com/Mexuus/okulacooker/main/zimaos-compose.yml)).
   Change the published port first if 8080 is already in use.
3. Install, then open OkulaCooker from the ZimaOS dashboard.

No volumes are needed: plans, favourites and history are stored in each
visitor's browser, so every device keeps its own plan. For the **Locate**
(GPS) button see the HTTPS note below — ZIP entry works either way.

**Without any GitHub login**, build the image on the ZimaOS box over SSH
first, then import the compose file with `image: okulacooker:latest`:

```sh
git clone https://github.com/Mexuus/okulacooker.git && cd okulacooker
docker build -t okulacooker:latest .      # ~10 min, needs ~3 GB free disk
```

### Enabling the Locate button on ZimaOS

Browsers only grant GPS to HTTPS origins, so over `http://<server-ip>:<port>`
the button stays disabled. If the box is on a Tailscale tailnet, `tailscale
serve` provides HTTPS with no domain, certificate or port forwarding:

```sh
tailscale serve --bg 8181     # the port OkulaCooker is published on
tailscale serve status        # -> https://<machine>.<tailnet>.ts.net/
```

ZimaOS runs Tailscale as a container with `network_mode: host`, so run those
inside it — `docker exec tailscale tailscale serve --bg 8181`, or over
Tailscale SSH if that is enabled. `127.0.0.1:<port>` resolves to the host's
published port because of host networking. The config is written to the
tailscale state directory (bind-mounted to `/DATA/AppData/tailscale`), so it
survives container restarts and reboots.

The result is reachable only from your tailnet; exposing it to the public
internet would need `tailscale funnel` instead. Undo with
`tailscale serve --https=443 off`.

## Host with Docker (Linux)

The image is a static web build served by unprivileged nginx on port 8080
(~60 MB, amd64 + arm64). Everything runs in the browser — no database or API
server; each visitor's plans live in their own browser storage.

**Option A — pull the prebuilt image** CI publishes on every push to `main`:

```sh
docker run -d --name okulacooker --restart unless-stopped -p 8080:8080 \
  ghcr.io/mexuus/okulacooker:latest                    # → http://SERVER_IP:8080
```

With compose (gets the hardened settings: read-only rootfs, no capabilities):

```sh
curl -O https://raw.githubusercontent.com/Mexuus/okulacooker/main/docker-compose.yml
OKULACOOKER_IMAGE=ghcr.io/mexuus/okulacooker:latest docker compose up -d
```

**Option B — build on the server** (needs ~3 GB free disk for the build):

```sh
git clone https://github.com/Mexuus/okulacooker.git && cd okulacooker
docker compose up -d --build
```

**HTTPS (required for the Locate/GPS button).** Browsers only allow location
access on HTTPS or `localhost`; over plain `http://SERVER_IP:8080` ZIP entry
still works but Locate is blocked. Point a domain at the server, open ports
80/443, and start the bundled Caddy proxy (automatic Let's Encrypt):

```sh
DOMAIN=okulacooker.example.com docker compose --profile https up -d
```

LAN-only alternatives: Tailscale (`tailscale serve 8080`) or your existing
reverse proxy (Nginx Proxy Manager, Traefik, the ZimaOS remote-access link) in
front of port 8080.

**Other settings:** `OKULACOOKER_PORT=9000` changes the host port. To serve under
a sub-path, build with `docker compose build --build-arg BASE_HREF=/okulacooker/`
(the trailing slash matters). **Update:** `docker compose pull && docker compose up -d`
(Option A) or `git pull && docker compose up -d --build` (Option B).

## CI / releases

- **GitHub Actions** (`.github/workflows/ci.yml`): analyze + test + web build on
  every push, an **unsigned iOS build** on a macOS runner (downloadable `.ipa`
  artifact), a **Docker image** smoke-tested and published to
  `ghcr.io/mexuus/okulacooker` (`latest` + `sha-…`) from `main`, and deployment of
  the web app to GitHub Pages from `main` (public repos only).
- **Codemagic** (`codemagic.yaml`): signed iOS build uploaded to TestFlight on
  tags `v*`. Requires an Apple Developer account and an App Store Connect API
  key added in Codemagic as `OkulaCooker ASC`.

## Attribution

Store locations: All The Places (CC0) and © OpenStreetMap contributors (ODbL).
Prices: U.S. Bureau of Labor Statistics and USDA Economic Research Service.
ZIP centroids: U.S. Census Bureau. Typeface: Schibsted Grotesk (SIL OFL).
