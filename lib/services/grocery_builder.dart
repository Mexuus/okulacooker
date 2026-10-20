import '../data/recipe_db.dart';
import '../models/grocery.dart';
import '../models/ingredient.dart';
import '../models/plan.dart';
import '../models/recipe.dart';
import 'pricing.dart';

/// Buying up to this much less than a recipe calls for is fine (avoids an
/// extra pack for a sliver).
const double kPackTolerance = 0.95;

/// Cheapest combination of [packs] covering [grams] (national prices; the
/// local multiplier is the same for every pack of an ingredient).
List<PackCount> planPurchase(List<PackOption> packs, double grams) {
  if (grams <= 0 || packs.isEmpty) return const [];
  final need = grams * kPackTolerance;
  final sorted = [...packs]..sort((a, b) => b.grams.compareTo(a.grams));
  List<PackCount>? best;
  var bestCost = double.infinity;

  void search(int i, double remaining, double cost, List<PackCount> chosen) {
    if (cost >= bestCost) return;
    if (remaining <= 0) {
      best = List.of(chosen);
      bestCost = cost;
      return;
    }
    if (i >= sorted.length) return;
    final p = sorted[i];
    final maxCount = (remaining / p.grams).ceil();
    for (var c = maxCount; c >= 0; c--) {
      if (c > 0) chosen.add(PackCount(p, c));
      search(i + 1, remaining - c * p.grams, cost + c * p.price, chosen);
      if (c > 0) chosen.removeLast();
    }
  }

  search(0, need, 0, []);
  return best ?? [PackCount(sorted.last, (need / sorted.last.grams).ceil())];
}

/// Builds a consolidated, pack-based grocery list from a week plan.
class GroceryBuilder {
  final PricingEngine pricing;

  /// Ids of staples the user already owns (left off the bill).
  final Set<String> ownedStaples;

  GroceryBuilder({required this.pricing, required this.ownedStaples});

  void _accumulate(
    List<PlannedMeal> meals,
    Map<String, double> into, {
    bool onlyShelfStable = false,
    bool onlyPerishable = false,
  }) {
    for (final meal in meals) {
      if (meal.skipped || meal.fromFreezer || !isKnownRecipe(meal.recipeId)) continue;
      final recipe = recipeById(meal.recipeId);
      final scale = meal.servings / recipe.baseServings;
      for (final ri in recipe.ingredients) {
        final ing = kIngredients[ri.ingredientId];
        if (ing == null) continue;
        if (onlyShelfStable && ing.perishable) continue;
        if (onlyPerishable && !ing.perishable) continue;
        final g = ing.gramsFor(ri.amount, ri.unit) * scale;
        into.update(ri.ingredientId, (v) => v + g, ifAbsent: () => g);
      }
    }
  }

  GroceryLine _line(String id, double grams) {
    final ing = kIngredients[id]!;
    final buy = planPurchase(ing.packs, grams);
    final factor = pricing.factorFor(ing);
    final cost = buy.fold(0.0, (s, p) => s + p.count * p.pack.price * factor);
    return GroceryLine(
      ingredient: ing,
      grams: grams,
      buy: buy,
      estCost: (cost * 100).round() / 100,
      ownedStaple: ing.staple && ownedStaples.contains(id),
    );
  }

  List<GroceryLine> _linesFrom(Map<String, double> grams) {
    final lines = grams.entries.map((e) => _line(e.key, e.value)).toList();
    lines.sort((a, b) {
      final c = a.ingredient.aisle.index.compareTo(b.ingredient.aisle.index);
      return c != 0 ? c : a.ingredient.name.compareTo(b.ingredient.name);
    });
    return lines;
  }

  GroceryList build(WeekPlan plan) {
    final main = <String, double>{};
    _accumulate(plan.meals, main);
    final later = <String, double>{};
    if (plan.isTwoWeek) {
      // Week-two shelf-stable items are bought now; perishables next week.
      _accumulate(plan.weekTwoMeals, main, onlyShelfStable: true);
      _accumulate(plan.weekTwoMeals, later, onlyPerishable: true);
    }
    return GroceryList(lines: _linesFrom(main), laterLines: _linesFrom(later));
  }
}

/// Estimated cost of the ingredients one meal actually uses (its share of
/// each pack), at [pricing]'s store.
double estimateMealCost(PlannedMeal meal, PricingEngine pricing) {
  if (meal.skipped || meal.fromFreezer || !isKnownRecipe(meal.recipeId)) return 0;
  final recipe = recipeById(meal.recipeId);
  final scale = meal.servings / recipe.baseServings;
  var total = 0.0;
  for (final ri in recipe.ingredients) {
    final ing = kIngredients[ri.ingredientId];
    if (ing == null) continue;
    total += pricing.costOf(ing, ing.gramsFor(ri.amount, ri.unit) * scale);
  }
  return total;
}

/// Nutrition per serving (kcal, protein g, carbs g, fat g) for [recipe].
({double kcal, double protein, double carbs, double fat}) nutritionPerServing(Recipe recipe) {
  var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0;
  for (final ri in recipe.ingredients) {
    final ing = kIngredients[ri.ingredientId];
    if (ing == null) continue;
    final g = ing.gramsFor(ri.amount, ri.unit) / 100;
    kcal += g * ing.kcalPer100g;
    protein += g * ing.proteinPer100g;
    carbs += g * ing.carbsPer100g;
    fat += g * ing.fatPer100g;
  }
  final s = recipe.baseServings;
  return (kcal: kcal / s, protein: protein / s, carbs: carbs / s, fat: fat / s);
}
