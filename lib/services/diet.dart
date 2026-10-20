import '../data/catalog.dart';
import '../models/ingredient.dart';
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

const _beef = {'ground_beef', 'flank_steak'};
const _pork = {'pork_chop', 'pork_shoulder', 'bacon', 'italian_sausage'};
const _poultry = {'chicken_breast', 'chicken_thigh', 'ground_turkey'};

bool _isSeafood(Ingredient i) => i.aisle == Aisle.seafood || i.id == 'tuna_can';
bool _isMeat(Ingredient i) => i.aisle == Aisle.meat;

/// Dairy aisle items that are actually dairy (eggs are not dairy).
bool _isDairy(Ingredient i) => i.aisle == Aisle.dairy && i.id != 'egg';

bool _violates(Ingredient ing, Diet d) {
  switch (d) {
    case Diet.vegetarian:
      return _isMeat(ing) || _isSeafood(ing);
    case Diet.noBeef:
      return _beef.contains(ing.id);
    case Diet.noPork:
      return _pork.contains(ing.id);
    case Diet.noPoultry:
      return _poultry.contains(ing.id);
    case Diet.noSeafood:
      return _isSeafood(ing);
    case Diet.dairyFree:
      return _isDairy(ing);
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
    final ing = kIngredients[ri.ingredientId];
    if (ing == null) continue;
    for (final d in diets) {
      if (_violates(ing, d)) return false;
    }
  }
  return true;
}
