import '../models/grocery.dart';
import '../models/ingredient.dart';
import '../models/plan.dart';
import '../data/catalog.dart';
import '../data/recipes_seed.dart';
import 'pricing.dart';

/// Builds a consolidated, estimated grocery list from a week plan.
class GroceryBuilder {
  final PricingEngine pricing;

  /// Ids of staples the user already owns (removed from the bill).
  final Set<String> ownedStaples;

  GroceryBuilder({required this.pricing, required this.ownedStaples});

  /// Accumulates ingredient quantities for the given meals.
  void _accumulate(
    List<PlannedMeal> meals,
    Map<String, double> into, {
    bool onlyShelfStable = false,
    bool onlyPerishable = false,
  }) {
    for (final meal in meals) {
      if (meal.skipped || meal.fromFreezer) continue;
      final recipe = recipeById(meal.recipeId);
      final scale = meal.servings / recipe.baseServings;
      for (final ri in recipe.ingredients) {
        final ing = kIngredients[ri.ingredientId];
        if (ing == null) continue;
        if (onlyShelfStable && ing.aisle.isPerishable) continue;
        if (onlyPerishable && !ing.aisle.isPerishable) continue;
        into.update(ri.ingredientId, (v) => v + ri.qty * scale,
            ifAbsent: () => ri.qty * scale);
      }
    }
  }

  GroceryLine _line(String id, double qty) {
    final ing = kIngredients[id]!;
    final owned = ing.staple && ownedStaples.contains(id);
    return GroceryLine(
      ingredient: ing,
      qty: qty,
      estCost: pricing.estimate(ing, qty),
      ownedStaple: owned,
    );
  }

  List<GroceryLine> _linesFrom(Map<String, double> qty) {
    final lines = qty.entries.map((e) => _line(e.key, e.value)).toList();
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
      // Week-two shelf-stable items can be bought now; perishables buy later.
      _accumulate(plan.weekTwoMeals, main, onlyShelfStable: true);
      _accumulate(plan.weekTwoMeals, later, onlyPerishable: true);
    }

    return GroceryList(
      lines: _linesFrom(main),
      laterLines: _linesFrom(later),
    );
  }
}

/// Stand-alone cost estimate for a single meal (used by the planner and cards).
double estimateMealCost(PlannedMeal meal, PricingEngine pricing) {
  if (meal.skipped || meal.fromFreezer) return 0;
  final recipe = recipeById(meal.recipeId);
  final scale = meal.servings / recipe.baseServings;
  double total = 0;
  for (final ri in recipe.ingredients) {
    final ing = kIngredients[ri.ingredientId];
    if (ing == null) continue;
    total += pricing.estimate(ing, ri.qty * scale);
  }
  return total;
}
