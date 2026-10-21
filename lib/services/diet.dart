import '../data/recipe_db.dart';
import '../models/recipe.dart';

/// Dietary preferences. These are a convenience for planning, NOT an allergen
/// control — users must always check ingredients themselves.
///
/// There is no fish or shellfish option because there is no seafood anywhere
/// in the recipe database.
enum Diet {
  vegetarian,
  vegan,
  noBeef,
  noPork,
  noPoultry,
  noLamb,
  dairyFree,
  glutenFree,
  eggFree,
  nutFree,
}

const _meat = {'beef', 'pork', 'poultry', 'lamb'};

extension DietInfo on Diet {
  String get label => const {
        Diet.vegetarian: 'Vegetarian',
        Diet.vegan: 'Vegan',
        Diet.noBeef: 'No beef',
        Diet.noPork: 'No pork',
        Diet.noPoultry: 'No poultry',
        Diet.noLamb: 'No lamb',
        Diet.dairyFree: 'Dairy-free',
        Diet.glutenFree: 'Gluten-free',
        Diet.eggFree: 'Egg-free',
        Diet.nutFree: 'Nut-free',
      }[this]!;

  /// Ingredient flags (from the database) this diet rules out.
  Set<String> get excludedFlags => switch (this) {
        Diet.vegetarian => _meat,
        Diet.vegan => {..._meat, 'dairy', 'egg', 'honey'},
        Diet.noBeef => {'beef'},
        Diet.noPork => {'pork'},
        Diet.noPoultry => {'poultry'},
        Diet.noLamb => {'lamb'},
        Diet.dairyFree => {'dairy'},
        Diet.glutenFree => {'gluten'},
        Diet.eggFree => {'egg'},
        Diet.nutFree => {'nuts'},
      };

  /// Diets with allergy implications get a "check labels" reminder in the UI.
  bool get allergenLike =>
      this == Diet.glutenFree || this == Diet.nutFree || this == Diet.eggFree ||
      this == Diet.dairyFree;
}

/// Reads saved diet names, dropping retired ones. The seafood diets
/// ("noSeafood", "noFish", "noShellfish", "pescatarian") went away when the
/// last fish and shellfish recipes were removed from the database.
const _retiredDiets = {'noSeafood', 'noFish', 'noShellfish', 'pescatarian'};

Set<Diet> dietsFromNames(Iterable<Object?> names) {
  final out = <Diet>{};
  for (final n in names) {
    if (_retiredDiets.contains(n)) continue;
    for (final d in Diet.values) {
      if (d.name == n) out.add(d);
    }
  }
  return out;
}

Set<String> _flagsOf(String ingredientId) => kIngredients[ingredientId]?.flags ?? const {};

/// True if [recipe] fits all selected diets and uses none of the excluded
/// ("won't eat") ingredients.
bool recipeAllowed(
  Recipe recipe, {
  required Set<Diet> diets,
  required Set<String> excluded,
}) {
  final banned = {for (final d in diets) ...d.excludedFlags};
  for (final ri in recipe.ingredients) {
    if (excluded.contains(ri.ingredientId)) return false;
    if (banned.isNotEmpty && _flagsOf(ri.ingredientId).any(banned.contains)) return false;
  }
  return true;
}

bool isVegetarian(Recipe r) => recipeAllowed(r, diets: {Diet.vegetarian}, excluded: const {});

/// Ingredients that can be listed under "won't eat" (everything in the database).
List<String> get excludableIngredientIds =>
    (kIngredients.keys.toList()..sort((a, b) => kIngredients[a]!.name.compareTo(kIngredients[b]!.name)));

/// A common dislike shown as a picture tile: one tap excludes every listed
/// ingredient that exists in the database.
class Dislike {
  final String label;
  final List<String> ingredientIds;
  const Dislike(this.label, this.ingredientIds);

  List<String> get presentIds => ingredientIds.where(kIngredients.containsKey).toList();

  /// Ingredient whose icon represents the tile.
  String get iconIngredient => presentIds.isEmpty ? ingredientIds.first : presentIds.first;

  bool isSelected(Set<String> excluded) =>
      presentIds.isNotEmpty && presentIds.every(excluded.contains);
}

const kCommonDislikes = <Dislike>[
  Dislike('Mushrooms', ['mushroom_cremini']),
  Dislike('Olives', ['olive_kalamata']),
  Dislike('Cilantro', ['cilantro']),
  Dislike('Tofu & tempeh', ['tofu_firm', 'tempeh']),
  Dislike('Beans', ['bean_black_canned', 'bean_pinto_canned', 'bean_cannellini_canned',
      'bean_dried']),
  Dislike('Chickpeas', ['bean_chickpea_canned']),
  Dislike('Lentils', ['lentil_dried']),
  Dislike('Eggplant', ['eggplant']),
  Dislike('Coconut', ['coconut_milk']),
  Dislike('Cauliflower', ['cauliflower']),
  Dislike('Brussels sprouts', ['brussels_sprout']),
  Dislike('Kale', ['kale']),
  Dislike('Spinach', ['spinach_fresh']),
  Dislike('Cabbage', ['cabbage_green']),
  Dislike('Zucchini', ['zucchini']),
  Dislike('Bell peppers', ['bell_pepper', 'pepper_roasted_jar']),
  Dislike('Sweet potato', ['sweet_potato']),
  Dislike('Asparagus', ['asparagus']),
  Dislike('Avocado', ['avocado']),
  Dislike('Feta & goat cheese', ['feta', 'goat_cheese']),
  Dislike('Capers & pickles', ['caper', 'pickle_dill', 'pepperoncini']),
  Dislike('Kimchi', ['kimchi']),
];
