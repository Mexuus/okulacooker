# Working on OkulaCooker

OkulaCooker is a Flutter app (iOS + web) that plans a week of dinners and prices the
grocery list at a real nearby store. Everything runs on-device: no backend, no
accounts, no subscriptions. `main` is the source of truth — this repo is the
canonical copy of the project.

## Workflow

- **Every change is committed and pushed to `main` in the same sitting.** Nothing
  stays only on a local machine; a local checkout is disposable scratch space.
- Before pushing, run `flutter analyze` and `flutter test` locally.
  CI re-runs them, builds the web app, builds an unsigned iOS app and publishes
  the Docker image, so a push must leave CI green.
- After pushing, confirm the local commit matches `origin/main`.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Layout

| Path | What it is |
|---|---|
| `lib/models/` | Recipes, ingredients, plans, stores |
| `lib/services/` | Plan generator, grocery builder, pricing, location, formatting |
| `lib/state/app_state.dart` | Central state: plan, pantry, favourites, recipe log, prices |
| `lib/screens/` | UI |
| `assets/data/` | Bundled data: `recipe_db.json`, `prices.json`, `stores.csv`, `zcta.csv` |
| `tool/` | Python scripts that regenerate everything in `assets/data/` |
| `docker/`, `Dockerfile`, `docker-compose.yml`, `zimaos-compose.yml` | Self-hosting |

## Regenerating bundled data

The scripts write into `assets/data/`; their large downloads land in `build/`
(gitignored). Re-running them needs network access and, for prices, respect for
the BLS limit of 25 queries per day.

```sh
python tool/import_recipe_db.py                   # recipe_db.json (from tool/sources/)
python tool/import_recipe_db.py --check FILE      # validate new recipes only
python tool/build_price_data.py                   # prices.json  (BLS + USDA)
python tool/build_store_directory.py              # stores.csv   (All The Places + OSM)
python tool/build_icons.py                        # assets/icons/food (Fluent Emoji)
python tool/build_photos.py                       # assets/photos (Wikimedia Commons)
```

New recipes go in `tool/sources/recipes/*.json`; the format and quality bar
are in `tool/sources/recipes/README.md`. Editorial drops and fixes to the
original recipes go in `tool/sources/curation.json`, never in the generated
`assets/data/recipe_db.json`.

`import_recipe_db.py` reads the original app's database from
`tool/sources/mealplan.json` (committed; it originally came from the app's `.ipa`).

## Tests

`test/test_helpers.dart` loads the real bundled data, so tests exercise the
actual recipe database and price book. Widget tests must inject a `zipLoader`;
loading that asset for real hangs under fake async.
