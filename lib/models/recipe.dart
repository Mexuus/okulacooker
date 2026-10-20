/// One ingredient line within a recipe, referencing a catalog [Ingredient] by id.
class RecipeIngredient {
  final String ingredientId;

  /// Quantity in the ingredient's catalog unit, for the recipe's base servings.
  final double qty;

  /// Short token usable in step text as `{token}` so quantities scale with
  /// serving size (e.g. a step "Add {rice} and simmer" renders "Add 2 cups rice").
  final String? token;

  const RecipeIngredient(this.ingredientId, this.qty, {this.token});
}

/// A dinner recipe. Photos are generated locally (gradient + emoji) so the app
/// works fully offline with no image downloads.
class Recipe {
  final String id;
  final String title;
  final String emoji;
  final int baseServings;
  final int prepMinutes;
  final int cookMinutes;
  final List<String> tags; // e.g. vegetarian, quick, kid-friendly
  final List<RecipeIngredient> ingredients;

  /// Step text. May contain `{token}` placeholders replaced with the scaled
  /// amount + name of the matching ingredient.
  final List<String> steps;

  const Recipe({
    required this.id,
    required this.title,
    required this.emoji,
    required this.baseServings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.tags,
    required this.ingredients,
    required this.steps,
  });

  int get totalMinutes => prepMinutes + cookMinutes;

  bool get isVegetarian => tags.contains('vegetarian');
}
