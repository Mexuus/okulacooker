import 'dart:math';

import '../models/plan.dart';
import '../models/recipe.dart';
import '../models/settings.dart';
import '../data/recipes_seed.dart';
import 'diet.dart';
import 'grocery_builder.dart';
import 'pricing.dart';

/// Returns the Monday (as yyyy-MM-dd) of the week containing [d].
String mondayOfWeek(DateTime d) {
  final monday = d.subtract(Duration(days: d.weekday - DateTime.monday));
  final m = monday.month.toString().padLeft(2, '0');
  final day = monday.day.toString().padLeft(2, '0');
  return '${monday.year}-$m-$day';
}

/// Recipes that satisfy the user's diet and "won't eat" settings.
List<Recipe> allowedRecipes(UserSettings s) => kRecipes
    .where((r) => recipeAllowed(r,
        diets: s.diets, excluded: s.excludedIngredients))
    .toList();

/// Generates a budget-aware week of dinners from the allowed recipe pool.
class PlanGenerator {
  final PricingEngine pricing;
  final Set<String> ownedStaples;
  final List<Recipe> pool;
  final Random _rng;

  PlanGenerator({
    required this.pricing,
    required this.ownedStaples,
    List<Recipe>? pool,
    int? seed,
  })  : pool = pool ?? kRecipes,
        _rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  double _planTotal(List<PlannedMeal> meals) {
    final list = GroceryBuilder(pricing: pricing, ownedStaples: ownedStaples)
        .build(WeekPlan(weekStart: 'tmp', meals: meals));
    return list.total;
  }

  /// Picks [count] meals, avoiding [exclude] where possible. If the pool is
  /// smaller than [count], recipes repeat rather than leaving nights empty.
  List<PlannedMeal> _pick(int count, int servings, Set<String> exclude) {
    if (pool.isEmpty) return [];
    var candidates = pool.where((r) => !exclude.contains(r.id)).toList();
    if (candidates.isEmpty) candidates = [...pool];
    candidates.shuffle(_rng);
    return [
      for (var i = 0; i < count; i++)
        PlannedMeal(
          slot: i,
          recipeId: candidates[i % candidates.length].id,
          servings: servings,
        ),
    ];
  }

  /// Greedily swaps the most expensive meals for cheaper unused recipes until
  /// the plan fits the weekly budget or no improvement is possible.
  void _fitBudget(List<PlannedMeal> meals, double budget, int servings) {
    if (budget <= 0 || meals.isEmpty) return;
    for (var pass = 0; pass < 20; pass++) {
      if (_planTotal(meals) <= budget) return;
      final byCost = [...meals]..sort((a, b) =>
          estimateMealCost(b, pricing).compareTo(estimateMealCost(a, pricing)));
      final used = meals.map((m) => m.recipeId).toSet();
      final target = byCost.first;
      final targetCost = estimateMealCost(target, pricing);
      final cheaper = pool.where((r) => !used.contains(r.id)).map((r) {
        final pm = PlannedMeal(slot: 0, recipeId: r.id, servings: servings);
        return MapEntry(r.id, estimateMealCost(pm, pricing));
      }).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      if (cheaper.isEmpty || cheaper.first.value >= targetCost) return;
      target.recipeId = cheaper.first.key;
    }
  }

  WeekPlan generate(UserSettings s, {DateTime? forDate}) {
    final servings = s.householdSize;
    final nights = max(1, s.cookNightCount);

    final week1 = _pick(nights, servings, {});
    _fitBudget(week1, s.weeklyBudget, servings);

    var week2 = <PlannedMeal>[];
    if (s.twoWeekMode) {
      week2 = _pick(nights, servings, week1.map((m) => m.recipeId).toSet());
      _fitBudget(week2, s.weeklyBudget, servings);
    }

    return WeekPlan(
      weekStart: mondayOfWeek(forDate ?? DateTime.now()),
      meals: week1,
      weekTwoMeals: week2,
    );
  }

  /// Returns an allowed recipe id to replace [currentId], avoiding [used].
  String swapRecipe(String currentId, Set<String> used) {
    var options = pool
        .where((r) => r.id != currentId && !used.contains(r.id))
        .toList();
    if (options.isEmpty) {
      options = pool.where((r) => r.id != currentId).toList();
    }
    if (options.isEmpty) return currentId;
    options.shuffle(_rng);
    return options.first.id;
  }
}
