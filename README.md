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
| Price estimates | `lib/services/pricing.dart` | National reference price × chain multiplier × ZIP-region multiplier. Estimates, not live prices. |
| Meal planning | `lib/services/plan_generator.dart` | Budget-aware; respects diet and won't-eat settings (`lib/services/diet.dart`). |
| Grocery list | `lib/services/grocery_builder.dart` | Consolidates meals, removes owned pantry staples, splits two-week fresh items. |
| Location | `lib/services/location_service.dart` | Device GPS via `geolocator`, reverse-geocoded **offline** to a ZIP using bundled U.S. Census ZCTA data (`assets/data/zcta.csv`). |
| Nearby stores | `lib/services/store_locator.dart`, `store_directory.dart` | Offline directory of ~24k US store locations (`assets/data/stores.csv`). Falls back to a live OpenStreetMap (Overpass) query only when nothing is found nearby. |

Privacy: GPS is used once to find the ZIP and is never stored. The optional
online store lookup sends only the ZIP's center point.

## Data refresh

| File | Source | License | Refresh |
|---|---|---|---|
| `assets/data/zcta.csv` | U.S. Census Bureau ZCTA Gazetteer | Public domain | Yearly; download `*_Gaz_zcta_national.zip` and keep `GEOID,INTPTLAT,INTPTLONG` |
| `assets/data/stores.csv` | [All The Places](https://alltheplaces.xyz) + OpenStreetMap | CC0 / ODbL (attribution shown in-app) | `python tool/build_store_directory.py` |

When adding a chain, add it to `lib/data/stores.dart` **and** to the `BRANDS`
map in `tool/build_store_directory.py`. A test fails if the directory contains
a chain the app doesn't know.

## CI / releases

- **GitHub Actions** (`.github/workflows/ci.yml`): analyze + test + web build on
  every push, an **unsigned iOS build** on a macOS runner (downloadable `.ipa`
  artifact), and deployment of the web app to GitHub Pages from `main`
  (enable Pages → Source: GitHub Actions in the repo settings).
- **Codemagic** (`codemagic.yaml`): signed iOS build uploaded to TestFlight on
  tags `v*`. Requires an Apple Developer account and an App Store Connect API
  key added in Codemagic as `TapCook ASC`.

## Attribution

Store locations: All The Places (CC0) and © OpenStreetMap contributors (ODbL).
ZIP centroids: U.S. Census Bureau. Typeface: Schibsted Grotesk (SIL OFL).
