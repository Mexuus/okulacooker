# New recipes — authoring format

Recipes added after the original app live here as JSON arrays, one file per
theme (`instant_pot.json`, `grill.json`, …). `tool/import_recipe_db.py` turns
them into the app's database format and checks them:

```sh
python tool/import_recipe_db.py --check tool/sources/recipes/grill.json   # validate only
python tool/import_recipe_db.py                                           # rebuild assets/data/recipe_db.json
```

## Standard

Every recipe should be a dish people actually search for and cook at home — the
kind that tops the popular food sites — made with standard, well-tested
proportions, times and temperatures. Write the steps in your own words.

- **Portions:** a full dinner, 450–950 kcal and 22 g+ protein per serving
  (12 g+ if meatless). The checker reports both from the database's nutrition
  data; outside 380–1100 kcal is an error.
- **Ingredients:** use existing ids (see `assets/data/recipe_db.json` →
  `ingredients`, or `extra_ingredients.json`). Each needs a unit it can be
  measured in; the checker lists valid units if you pick a wrong one.
- **Safe cooking:** state doneness by internal temperature where it matters
  (chicken 165°F, pork 145°F, ground meat 160°F, fish 145°F).
- **Times:** `minutes` is the total, start to plate. Phase minutes should add up
  to roughly the same. Add `"duration"` to any action with a timer-worthy wait.

## Fields

```json
{
  "key": "ip-butter-chicken",            // stable id: lowercase-with-dashes, never reuse
  "title": "Instant Pot Butter Chicken",
  "cuisine": "Indian",                    // one of the cuisines already in the database
  "anchor": "chicken_thigh_boneless",     // main ingredient (drives variety)
  "serves": 4,
  "minutes": 40,
  "difficulty": "Easy",                   // Easy | Medium | Hard
  "equipment": "pressure_cooker",         // stove | oven | slow_cooker | air_fryer | pressure_cooker | grill
  "format": "pressure",                   // skillet | oven | pot | slow | air | pressure | grill
  "cleanup": 2,                           // 1 (one pan) … 8 (every dish in the house)
  "ingredients": [["chicken_thigh_boneless", 2, "lb"], ["onion_yellow", 1, "count"]],
  "steps": [
    {"phase": "Prep", "minutes": 10, "actions": [
      {"verb": "Dice", "body": "{amt:onion_yellow|onion|onions}."}
    ]}
  ]
}
```

### Amounts in steps

Write quantities as placeholders so they scale with the household size:

| Placeholder | Renders (serves 4) |
|---|---|
| `{amt:butter_unsalted}` | `3 tbsp` — the full listed amount |
| `{amt:butter_unsalted:0.5}` | `1½ tbsp` — a fraction of it (0–1) |
| `{amt:onion_yellow\|onion\|onions}` | `1 onion` — counted items need singular\|plural |

Cans, cloves, stalks and packets get their nouns automatically
(`{amt:tomato_canned_crushed}` → `1 can`). Placeholders for one ingredient may
not add up to more than its listed amount.

## Example

```json
[
  {
    "key": "ip-butter-chicken",
    "title": "Instant Pot Butter Chicken",
    "cuisine": "Indian",
    "anchor": "chicken_thigh_boneless",
    "serves": 4,
    "minutes": 45,
    "difficulty": "Easy",
    "equipment": "pressure_cooker",
    "format": "pressure",
    "cleanup": 2,
    "ingredients": [
      ["chicken_thigh_boneless", 2, "lb"],
      ["butter_unsalted", 3, "tbsp"],
      ["onion_yellow", 1, "count"],
      ["garlic_head", 5, "clove"],
      ["ginger_fresh", 1, "tbsp"],
      ["garam_masala", 2, "tsp"],
      ["curry_powder", 1, "tsp"],
      ["paprika_smoked", 1, "tsp"],
      ["salt_kosher", 1.5, "tsp"],
      ["tomato_sauce", 1, "count"],
      ["cream_heavy", 0.5, "cup"],
      ["rice_basmati", 1.25, "cup"],
      ["cilantro", 0.25, "cup"]
    ],
    "steps": [
      {"phase": "Prep", "minutes": 10, "actions": [
        {"verb": "Cut", "body": "{amt:chicken_thigh_boneless} of chicken thighs into 1½-inch pieces and toss with {amt:salt_kosher:0.5} of salt."},
        {"verb": "Dice", "body": "{amt:onion_yellow|onion|onions}, mince {amt:garlic_head} of garlic and grate {amt:ginger_fresh} of ginger."}
      ]},
      {"phase": "Sauté", "minutes": 8, "actions": [
        {"verb": "Melt", "body": "{amt:butter_unsalted:0.5} of butter on Sauté and cook the onion until soft, about 5 minutes.", "duration": "5 min"},
        {"verb": "Stir in", "body": "the garlic, ginger, {amt:garam_masala:0.5} of garam masala, {amt:curry_powder} of curry powder and {amt:paprika_smoked} of smoked paprika for 1 minute."},
        {"verb": "Pour in", "body": "{amt:tomato_sauce} of tomato sauce and scrape up anything stuck to the bottom so the pot doesn't show a burn warning."}
      ]},
      {"phase": "Pressure cook", "minutes": 20, "actions": [
        {"verb": "Add", "body": "the chicken and the rest of the salt and stir once. Lock the lid, set the valve to Sealing and cook on High Pressure for 8 minutes.", "duration": "8 min"},
        {"verb": "Cook", "body": "the rice meanwhile: rinse {amt:rice_basmati} of basmati and simmer it, covered, in 1½ times its volume of water for 15 minutes.", "duration": "15 min"},
        {"verb": "Release", "body": "the pressure naturally for 5 minutes, then quick-release the rest.", "duration": "5 min"}
      ]},
      {"phase": "Finish", "minutes": 5, "actions": [
        {"verb": "Stir in", "body": "{amt:cream_heavy} of heavy cream, the remaining {amt:butter_unsalted:0.5} of butter and the rest of the garam masala. Check the chicken reads 165°F."},
        {"verb": "Serve", "body": "over the rice, topped with {amt:cilantro} of chopped cilantro."}
      ]}
    ]
  }
]
```
