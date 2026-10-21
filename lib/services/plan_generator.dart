import 'dart:math';

import '../data/recipe_db.dart';
import '../models/plan.dart';
import '../models/recipe.dart';
import '../models/settings.dart';
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

/// Kitchen gear the user can say they own. The stove is assumed.
const kGear = <String, String>{
  'oven': 'Oven',
  'slow_cooker': 'Slow cooker',
  'air_fryer': 'Air fryer',
  'pressure_cooker': 'Instant Pot',
  'grill': 'Grill',
};

/// Gear the planner schedules a set number of nights for ([UserSettings.gearNights]).
const kSpecialGear = {'slow_cooker', 'air_fryer', 'pressure_cooker', 'grill'};

bool usesSpecialGear(Recipe r) => r.needs.any(kSpecialGear.contains);

/// Whether [r] suits the user's gear, diet, won't-eat list, time limit,
/// difficulty and spice preferences, and hasn't been thumbed down.
bool recipeFits(Recipe r, UserSettings s, {Set<String> disliked = const {}}) =>
    !disliked.contains(r.id) &&
    s.equipment.containsAll(r.needs) &&
    (s.maxMinutes == null || r.handsOff || r.totalMinutes <= s.maxMinutes!) &&
    (!s.easyOnly || r.difficulty == 'Easy') &&
    (!s.mildOnly || !r.spicy) &&
    recipeAllowed(r, diets: s.diets, excluded: s.excludedIngredients);

/// Recipes the planner may suggest for [s].
List<Recipe> allowedRecipes(UserSettings s, {Set<String> disliked = const {}}) =>
    kRecipes.where((r) => recipeFits(r, s, disliked: disliked)).toList();

/// Builds weekly plans from the recipe database without repeating meals.
///
/// Recipes never shown before come first; only when those run out are
/// previously shown recipes reused, oldest first. Among new recipes, ones like
/// those the user liked (same cuisine or main ingredient) tend to come sooner
/// and ones like those they disliked later. Each week avoids repeating a main
/// ingredient, keeps any one cuisine to two nights, and plans [gearNights]
/// meals for special gear. Meals the user picks themselves can repeat — that
/// happens outside the generator.
class PlanGenerator {
  final PricingEngine pricing;
  final Set<String> ownedStaples;
  final List<Recipe> pool;

  /// recipe id -> date (yyyy-MM-dd) it was last put in a plan.
  final Map<String, String> history;

  /// Meals per week for slow cooker / air fryer / Instant Pot / grill recipes.
  final int gearNights;

  final Map<String, int> _likedCuisine = {}, _likedAnchor = {};
  final Map<String, int> _dislikedCuisine = {}, _dislikedAnchor = {};
  final Random _rng;

  PlanGenerator({
    required this.pricing,
    required this.ownedStaples,
    List<Recipe>? pool,
    Map<String, String>? history,
    this.gearNights = 2,
    Set<String> liked = const {},
    Set<String> disliked = const {},
    int? seed,
  })  : pool = pool ?? kRecipes,
        history = history ?? const {},
        _rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch) {
    void tally(Set<String> ids, Map<String, int> cuisine, Map<String, int> anchor) {
      for (final id in ids) {
        if (!isKnownRecipe(id)) continue;
        final r = recipeById(id);
        cuisine[r.cuisine] = (cuisine[r.cuisine] ?? 0) + 1;
        anchor[r.anchor] = (anchor[r.anchor] ?? 0) + 1;
      }
    }

    tally(liked, _likedCuisine, _likedAnchor);
    tally(disliked, _dislikedCuisine, _dislikedAnchor);
  }

  /// How much the user's ratings favour [r] (0 with no ratings).
  double preference(Recipe r) =>
      min(_likedCuisine[r.cuisine] ?? 0, 3) * 0.6 +
      min(_likedAnchor[r.anchor] ?? 0, 2) * 0.8 -
      min(_dislikedCuisine[r.cuisine] ?? 0, 3) * 0.6 -
      min(_dislikedAnchor[r.anchor] ?? 0, 2) * 0.8;

  /// Never-shown recipes (shuffled, nudged by ratings), then shown ones from
  /// oldest to newest.
  List<Recipe> freshOrder({Set<String> exclude = const {}}) {
    final unseen = <(Recipe, double)>[], seen = <Recipe>[];
    for (final r in pool) {
      if (exclude.contains(r.id)) continue;
      if (history.containsKey(r.id)) {
        seen.add(r);
      } else {
        unseen.add((r, preference(r) + _rng.nextDouble() * 2));
      }
    }
    unseen.sort((a, b) => b.$2.compareTo(a.$2));
    seen.shuffle(_rng);
    seen.sort((a, b) => history[a.id]!.compareTo(history[b.id]!));
    return [...unseen.map((e) => e.$1), ...seen];
  }

  /// Number of allowed recipes that have never been planned.
  int get unseenCount => pool.where((r) => !history.containsKey(r.id)).length;

  bool _fits(Recipe r, List<Recipe> chosen,
      {required bool strictCuisine, required bool strictAnchor, int? gearCap}) {
    if (strictAnchor && chosen.any((c) => c.anchor == r.anchor)) return false;
    if (strictCuisine && chosen.where((c) => c.cuisine == r.cuisine).length >= 2) return false;
    if (usesSpecialGear(r) && chosen.where(usesSpecialGear).length >= (gearCap ?? gearNights)) {
      return false;
    }
    return true;
  }

  List<Recipe> _pickRecipes(int count, Set<String> exclude) {
    final ordered = freshOrder(exclude: exclude);
    final chosen = <Recipe>[];
    final gearTarget = min(gearNights, count);
    const passes = [(true, true), (false, true), (false, false)];
    // Gear nights first so they aren't crowded out, then everything else.
    for (final gearOnly in [true, false]) {
      for (final (cuisine, anchor) in passes) {
        for (final r in ordered) {
          final full = gearOnly
              ? chosen.where(usesSpecialGear).length >= gearTarget
              : chosen.length >= count;
          if (full) break;
          if (chosen.contains(r) || (gearOnly && !usesSpecialGear(r))) continue;
          if (_fits(r, chosen, strictCuisine: cuisine, strictAnchor: anchor)) chosen.add(r);
        }
      }
    }
    // A tiny pool (strict diets) may still be short: allow repeats within the week.
    var i = 0;
    while (chosen.length < count && pool.isNotEmpty) {
      chosen.add(ordered.isEmpty ? pool[i % pool.length] : ordered[i % ordered.length]);
      i++;
    }
    return chosen;
  }

  double _planTotal(List<PlannedMeal> meals) =>
      GroceryBuilder(pricing: pricing, ownedStaples: ownedStaples)
          .build(WeekPlan(weekStart: 'tmp', meals: meals))
          .total;

  /// Swaps the priciest meals for cheaper fresh recipes until under budget.
  void _fitBudget(List<PlannedMeal> meals, double budget, Set<String> exclude) {
    if (budget <= 0 || meals.isEmpty) return;
    final candidates = freshOrder(exclude: exclude).take(200).toList();
    for (var pass = 0; pass < 15; pass++) {
      if (_planTotal(meals) <= budget) return;
      final byCost = [...meals]
        ..sort((a, b) => estimateMealCost(b, pricing).compareTo(estimateMealCost(a, pricing)));
      final target = byCost.first;
      final targetCost = estimateMealCost(target, pricing);
      final inPlan = meals.map((m) => m.recipeId).toSet();
      final others = meals.where((m) => m != target).map((m) => recipeById(m.recipeId)).toList();
      Recipe? best;
      var bestCost = targetCost;
      for (final r in candidates) {
        if (inPlan.contains(r.id)) continue;
        if (!_fits(r, others, strictCuisine: false, strictAnchor: true)) continue;
        final c = estimateMealCost(
            PlannedMeal(slot: 0, recipeId: r.id, servings: target.servings), pricing);
        if (c < bestCost) {
          best = r;
          bestCost = c;
        }
      }
      if (best == null) return;
      target.recipeId = best.id;
    }
  }

  List<PlannedMeal> _week(int nights, int servings, Set<String> exclude, double budget) {
    final meals = [
      for (final (i, r) in _pickRecipes(nights, exclude).indexed)
        PlannedMeal(slot: i, recipeId: r.id, servings: servings),
    ];
    _fitBudget(meals, budget, exclude);
    return meals;
  }

  WeekPlan generate(UserSettings s, {DateTime? forDate}) {
    final nights = max(1, s.cookNightCount);
    final week1 = _week(nights, s.householdSize, const {}, s.weeklyBudget);
    var week2 = <PlannedMeal>[];
    if (s.twoWeekMode) {
      week2 = _week(nights, s.householdSize, week1.map((m) => m.recipeId).toSet(), s.weeklyBudget);
    }
    return WeekPlan(
      weekStart: mondayOfWeek(forDate ?? DateTime.now()),
      meals: week1,
      weekTwoMeals: week2,
    );
  }

  /// A fresh replacement for [currentId] that isn't already in the plan and,
  /// where possible, doesn't share a main ingredient with the other meals.
  String swapRecipe(String currentId, Set<String> used, {List<Recipe> others = const []}) {
    final ordered = freshOrder(exclude: {...used, currentId});
    for (final r in ordered) {
      if (_fits(r, others, strictCuisine: false, strictAnchor: true)) return r.id;
    }
    return ordered.isNotEmpty ? ordered.first.id : currentId;
  }
}
