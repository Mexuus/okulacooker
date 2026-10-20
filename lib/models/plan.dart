/// A single planned dinner slot within a week.
class PlannedMeal {
  /// 0 = first cook night of the week, 1 = second, etc. (index into cook nights).
  final int slot;

  /// Catalog recipe id for this slot.
  String recipeId;

  /// Servings to cook for this meal (defaults to household size).
  int servings;

  /// If true, the night is skipped and its groceries are removed from the list.
  bool skipped;

  /// If true, this dinner is covered by something in the freezer and should not
  /// add its ingredients to the shopping list (smarter leftovers).
  bool fromFreezer;

  PlannedMeal({
    required this.slot,
    required this.recipeId,
    required this.servings,
    this.skipped = false,
    this.fromFreezer = false,
  });

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'recipeId': recipeId,
        'servings': servings,
        'skipped': skipped,
        'fromFreezer': fromFreezer,
      };

  factory PlannedMeal.fromJson(Map<String, dynamic> j) => PlannedMeal(
        slot: j['slot'] as int,
        recipeId: j['recipeId'] as String,
        servings: j['servings'] as int,
        skipped: (j['skipped'] as bool?) ?? false,
        fromFreezer: (j['fromFreezer'] as bool?) ?? false,
      );
}

/// A week of planned dinners.
class WeekPlan {
  /// ISO date (yyyy-MM-dd) of the Monday the week starts on.
  final String weekStart;
  final List<PlannedMeal> meals;

  /// Second-week meals when shopping two weeks at once; empty otherwise.
  final List<PlannedMeal> weekTwoMeals;

  WeekPlan({
    required this.weekStart,
    required this.meals,
    this.weekTwoMeals = const [],
  });

  bool get isTwoWeek => weekTwoMeals.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'weekStart': weekStart,
        'meals': meals.map((m) => m.toJson()).toList(),
        'weekTwoMeals': weekTwoMeals.map((m) => m.toJson()).toList(),
      };

  factory WeekPlan.fromJson(Map<String, dynamic> j) => WeekPlan(
        weekStart: j['weekStart'] as String,
        meals: (j['meals'] as List)
            .map((e) => PlannedMeal.fromJson(e as Map<String, dynamic>))
            .toList(),
        weekTwoMeals: ((j['weekTwoMeals'] as List?) ?? [])
            .map((e) => PlannedMeal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
