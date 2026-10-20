import '../data/recipe_db.dart';
import '../models/recipe.dart';

/// Dietary preferences. These are a convenience for planning, NOT an allergen
/// control — users must always check ingredients themselves.
enum Diet { vegetarian, noBeef, noPork, noPoultry, noSeafood, dairyFree }

extension DietInfo on Diet {
  String get label {
    switch (this) {
      case Diet.vegetarian:
        return 'Vegetarian';
      case Diet.noBeef:
        return 'No beef';
      case Diet.noPork:
        return 'No pork';
      case Diet.noPoultry:
        return 'No poultry';
      case Diet.noSeafood:
        return 'No seafood';
      case Diet.dairyFree:
        return 'Dairy-free';
    }
  }
}

const _beef = {'ground_beef', 'beef_chuck', 'beef_steak_sirloin', 'broth_beef', 'au_jus_mix'};
const _pork = {
  'ground_pork', 'pork_chop', 'pork_chop_bone_in', 'pork_shoulder', 'bacon',
  'sausage_italian', 'sausage_chorizo', 'prosciutto', 'pancetta', 'pepperoni',
};
const _poultry = {
  'chicken_thigh_boneless', 'chicken_thigh_bone_in', 'chicken_breast', 'chicken_whole',
  'chicken_drumstick', 'ground_turkey', 'broth_chicken', 'cream_of_chicken_canned',
};
const _seafood = {'salmon_fillet', 'shrimp_frozen', 'tilapia_fillet', 'tuna_canned', 'fish_sauce'};
const _otherMeat = {'lamb_ground', 'worcestershire'}; // worcestershire contains anchovy
const _dairy = {
  'ricotta', 'goat_cheese', 'butter_unsalted', 'milk_whole', 'cream_heavy', 'sour_cream',
  'yogurt_greek', 'cheddar', 'parmesan', 'mozzarella_low_moisture', 'cream_cheese', 'feta',
  'alfredo_sauce', 'cream_of_chicken_canned', 'cream_of_mushroom_canned', 'pesto', 'tortellini',
  'ranch_seasoning', 'gnocchi',
};

bool _violates(String id, Diet d) {
  switch (d) {
    case Diet.vegetarian:
      return _beef.contains(id) ||
          _pork.contains(id) ||
          _poultry.contains(id) ||
          _seafood.contains(id) ||
          _otherMeat.contains(id);
    case Diet.noBeef:
      return _beef.contains(id);
    case Diet.noPork:
      return _pork.contains(id);
    case Diet.noPoultry:
      return _poultry.contains(id);
    case Diet.noSeafood:
      return _seafood.contains(id);
    case Diet.dairyFree:
      return _dairy.contains(id);
  }
}

/// True if [recipe] fits all selected diets and uses none of the excluded
/// ("won't eat") ingredients.
bool recipeAllowed(
  Recipe recipe, {
  required Set<Diet> diets,
  required Set<String> excluded,
}) {
  for (final ri in recipe.ingredients) {
    if (excluded.contains(ri.ingredientId)) return false;
    for (final d in diets) {
      if (_violates(ri.ingredientId, d)) return false;
    }
  }
  return true;
}

bool isVegetarian(Recipe r) => recipeAllowed(r, diets: {Diet.vegetarian}, excluded: const {});

/// Ingredients that can be listed under "won't eat" (everything in the database).
List<String> get excludableIngredientIds =>
    (kIngredients.keys.toList()..sort((a, b) => kIngredients[a]!.name.compareTo(kIngredients[b]!.name)));
