import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tapcook/data/recipe_db.dart';
import 'package:tapcook/models/ingredient.dart';
import 'package:tapcook/models/plan.dart';
import 'package:tapcook/models/recipe.dart';
import 'package:tapcook/models/settings.dart';
import 'package:tapcook/services/format.dart';
import 'package:tapcook/services/grocery_builder.dart';
import 'package:tapcook/services/location_service.dart';
import 'package:tapcook/services/persistence.dart';
import 'package:tapcook/services/plan_generator.dart';
import 'package:tapcook/services/price_book.dart';
import 'package:tapcook/services/pricing.dart';
import 'package:tapcook/services/zip_locator.dart';
import 'package:tapcook/state/app_state.dart';

import 'test_helpers.dart';

PricingEngine national() => PricingEngine.from(storeId: 'trader_joes', zip: '', book: PriceBook.empty);

Recipe byTitle(String t) => kRecipes.firstWhere((r) => r.title == t);

void main() {
  setUpAll(loadTestData);

  group('recipe database', () {
    test('contains the original library', () {
      expect(kRecipes.length, 494);
      expect(kIngredients.length, 202);
      expect(kRecipes.map((r) => r.id).toSet().length, kRecipes.length);
    });

    test('every recipe ingredient exists and converts to grams', () {
      for (final r in kRecipes) {
        for (final ri in r.ingredients) {
          final ing = kIngredients[ri.ingredientId];
          expect(ing, isNotNull, reason: '${r.title}: ${ri.ingredientId}');
          expect(ing!.gramsFor(ri.amount, ri.unit), greaterThan(0),
              reason: '${r.title}: ${ri.amount} ${ri.unit} ${ri.ingredientId}');
        }
      }
    });

    test('every step placeholder has an amount and renders at any size', () {
      for (final r in kRecipes) {
        expect(r.phases, isNotEmpty, reason: r.title);
        for (final p in r.phases) {
          for (final a in p.actions) {
            for (final scale in [0.5, 1.0, 1.5, 2.0]) {
              final text = renderActionBody(a, scale);
              expect(text.contains(RegExp(r'\{\d+\}')), isFalse,
                  reason: '${r.title} @x$scale: $text');
            }
          }
        }
      }
    });

    test('pack-price cost model reproduces the original cost per serving', () {
      final engine = national();
      final ratios = [
        for (final r in kRecipes)
          estimateMealCost(PlannedMeal(slot: 0, recipeId: r.id, servings: r.baseServings), engine) /
              r.baseServings /
              r.costPerServing,
      ]..sort();
      final median = ratios[ratios.length ~/ 2];
      expect(median, inInclusiveRange(0.95, 1.05));
    });
  });

  group('formatting and scaling', () {
    test('recipe amounts read naturally', () {
      final tacos = byTitle('Crispy Chicken Thigh Tacos');
      final lines = tacos.ingredients.map((ri) => formatRecipeAmount(ri, 1)).toList();
      expect(lines, contains('1½ lb boneless chicken thighs'));
      expect(lines, contains('12 corn tortillas'));
      final crushed = kRecipes.expand((r) => r.ingredients).firstWhere(
          (i) => i.ingredientId == 'tomato_canned_crushed' && i.unit == 'count' && i.amount == 1);
      expect(formatRecipeAmount(crushed, 1), startsWith('1 can '));
      expect(formatRecipeAmount(crushed, 2), startsWith('2 cans '));
      expect(lines.where((l) => l.contains('cloves garlic')).length,
          tacos.ingredients.where((i) => i.unit == 'clove').length);
    });

    test('original wording at base servings, scaled amounts otherwise', () {
      final tacos = byTitle('Crispy Chicken Thigh Tacos');
      final toss = tacos.phases.first.actions.firstWhere((a) => a.verb == 'Toss');
      expect(renderActionBody(toss, 1), contains('1 tsp of the kosher salt'));
      expect(renderActionBody(toss, 2), contains('2 tsp of the kosher salt'));
      final slice = tacos.phases.first.actions.firstWhere((a) => a.verb == 'Slice');
      // A plain reference ("the red onion") doesn't change with servings.
      expect(renderActionBody(slice, 2), renderActionBody(slice, 1));
    });

    test('formatQty renders common fractions', () {
      expect(formatQty(0.5), '½');
      expect(formatQty(1.5), '1½');
      expect(formatQty(2), '2');
      expect(formatQty(0.3333), '⅓');
    });

    test('dish emoji match whole words', () {
      Recipe? find(String t) => kRecipes.where((r) => r.title.startsWith(t)).firstOrNull;
      expect(find('Bacon-Wrapped Pork')?.emoji, isNot('🌯'));
      expect(find('Baingan Bharta')?.emoji, '🍆');
      expect(find('Baja Fish Lettuce Wraps')?.emoji, '🌯');
      expect(find('Crispy Chicken Thigh Tacos')?.emoji, '🌮');
    });
  });

  group('pack buying', () {
    Ingredient thighs() => kIngredients['chicken_thigh_boneless']!;
    double lb(double x) => x * 453.592;

    test('picks the cheapest combination of pack sizes', () {
      // small 1.75 lb $5.01, family 3.75 lb $7.46
      final small = planPurchase(thighs().packs, lb(1.6));
      expect(small.single.pack.label, 'small');
      final three = planPurchase(thighs().packs, lb(3));
      expect(three.single.pack.label, 'family');
      final five = planPurchase(thighs().packs, lb(5));
      expect(five.map((p) => p.pack.label).toSet(), {'family', 'small'});
    });

    test('grocery list buys whole packs and leaves owned staples off the bill', () {
      final tacos = byTitle('Crispy Chicken Thigh Tacos');
      final plan = WeekPlan(weekStart: 'w', meals: [PlannedMeal(slot: 0, recipeId: tacos.id, servings: 4)]);
      final none = GroceryBuilder(pricing: national(), ownedStaples: {}).build(plan);
      final salted = GroceryBuilder(pricing: national(), ownedStaples: {'salt_kosher'}).build(plan);
      final tortillas = none.lines.firstWhere((l) => l.ingredient.id == 'tortilla_corn');
      expect(tortillas.packCount, 1); // 12 of a 30-count pack
      expect(tortillas.estCost, closeTo(2.99, 0.01));
      expect(salted.total, lessThan(none.total));
      expect(salted.lines.firstWhere((l) => l.ingredient.id == 'salt_kosher').ownedStaple, isTrue);
    });

    test('two-week plans buy week-two fresh items later', () {
      final salmon = kRecipes.firstWhere((r) => r.anchor == 'salmon_fillet');
      final tacos = byTitle('Crispy Chicken Thigh Tacos');
      final plan = WeekPlan(
        weekStart: 'w',
        meals: [PlannedMeal(slot: 0, recipeId: tacos.id, servings: 4)],
        weekTwoMeals: [PlannedMeal(slot: 0, recipeId: salmon.id, servings: 4)],
      );
      final list = GroceryBuilder(pricing: national(), ownedStaples: {}).build(plan);
      expect(list.laterLines.any((l) => l.ingredient.id == 'salmon_fillet'), isTrue);
      expect(list.lines.any((l) => l.ingredient.id == 'salmon_fillet'), isFalse);
    });

    test('skipped meals add nothing', () {
      final r = kRecipes.first;
      final list = GroceryBuilder(pricing: national(), ownedStaples: {}).build(WeekPlan(
          weekStart: 'w', meals: [PlannedMeal(slot: 0, recipeId: r.id, servings: 4, skipped: true)]));
      expect(list.lines, isEmpty);
    });
  });

  group('never-repeat planner', () {
    final settings = UserSettings(zip: '10001', weeklyBudget: 0, cookNights: [1, 2, 3, 4, 5]);

    test('a year of weekly plans never repeats a recipe', () {
      final history = <String, String>{};
      final seen = <String>{};
      for (var week = 0; week < 52; week++) {
        final plan = PlanGenerator(
          pricing: national(),
          ownedStaples: {},
          pool: allowedRecipes(settings),
          history: history,
          seed: week,
        ).generate(settings, forDate: DateTime(2026, 1, 5).add(Duration(days: 7 * week)));
        for (final m in plan.meals) {
          expect(seen.add(m.recipeId), isTrue, reason: 'week $week repeated ${m.recipeId}');
          history[m.recipeId] = plan.weekStart;
        }
      }
      expect(seen.length, 52 * 5);
    });

    test('each week varies the main ingredient and cuisine', () {
      for (var seed = 0; seed < 20; seed++) {
        final plan = PlanGenerator(
                pricing: national(), ownedStaples: {}, pool: allowedRecipes(settings), seed: seed)
            .generate(settings);
        final recipes = plan.meals.map((m) => recipeById(m.recipeId)).toList();
        expect(recipes.map((r) => r.anchor).toSet().length, recipes.length);
        for (final c in recipes.map((r) => r.cuisine).toSet()) {
          expect(recipes.where((r) => r.cuisine == c).length, lessThanOrEqualTo(2));
        }
      }
    });

    test('slow-cooker and air-fryer recipes need the equipment', () {
      final none = allowedRecipes(settings);
      expect(none.any((r) => r.equipment == 'slow_cooker' || r.equipment == 'air_fryer'), isFalse);
      final withGear = allowedRecipes(settings.copyWith(equipment: {'slow_cooker', 'air_fryer'}));
      expect(withGear.length, kRecipes.length);
    });

    test('once everything has been had, the longest-ago recipes come back first', () {
      final pool = kRecipes.take(10).toList();
      final history = {
        for (final (i, r) in pool.indexed) r.id: '2026-01-${(10 + i).toString().padLeft(2, '0')}',
      };
      final order = PlanGenerator(
              pricing: national(), ownedStaples: {}, pool: pool, history: history, seed: 1)
          .freshOrder();
      expect(order.first.id, pool.first.id);
      expect(order.last.id, pool.last.id);
    });

    test('budget fitting swaps in cheaper new recipes', () {
      final tight = settings.copyWith(weeklyBudget: 40);
      final loose = PlanGenerator(pricing: national(), ownedStaples: {}, pool: allowedRecipes(settings), seed: 3)
          .generate(settings);
      final fitted = PlanGenerator(pricing: national(), ownedStaples: {}, pool: allowedRecipes(tight), seed: 3)
          .generate(tight);
      double total(WeekPlan p) =>
          GroceryBuilder(pricing: national(), ownedStaples: {}).build(p).total;
      expect(total(fitted), lessThan(total(loose)));
    });
  });

  group('AppState meals', () {
    Future<AppState> makeState([Map<String, Object> prefs = const {}]) async {
      SharedPreferences.setMockInitialValues(prefs);
      final state = AppState(
        await Persistence.create(),
        location: LocationService(
            zipLoader: () async => ZipLocator.fromCsv('10001,40.7506,-73.9972\n')),
      );
      return state;
    }

    test('swaps always bring a recipe never planned before', () async {
      final state = await makeState();
      await state.completeOnboarding(UserSettings(zip: '10001', weeklyBudget: 0));
      for (var i = 0; i < 10; i++) {
        final before = state.plan!.meals.first.recipeId;
        final seenBefore = {for (final r in kRecipes) if (state.lastPlanned(r.id) != null) r.id};
        await state.swapMeal(0);
        final after = state.plan!.meals.first.recipeId;
        expect(after, isNot(before));
        expect(seenBefore.contains(after), isFalse);
      }
    });

    test('a meal you choose can repeat one you had before', () async {
      final state = await makeState();
      await state.completeOnboarding(UserSettings(zip: '10001', weeklyBudget: 0));
      final hadBefore = state.plan!.meals.first.recipeId;
      await state.generatePlan();
      expect(state.plan!.meals.map((m) => m.recipeId), isNot(contains(hadBefore)));
      await state.chooseMeal(2, hadBefore);
      expect(state.plan!.meals[2].recipeId, hadBefore);
    });

    test('favorites persist', () async {
      final state = await makeState();
      await state.toggleFavorite(kRecipes[7].id);
      expect(state.isFavorite(kRecipes[7].id), isTrue);
      await state.toggleFavorite(kRecipes[7].id);
      expect(state.favorites, isEmpty);
    });

    test('plans saved by older versions are replaced', () async {
      final state = await makeState({
        'settings': '{"zip":"10001","onboarded":true,"weeklyBudget":0}',
        'currentPlan':
            '{"weekStart":"2026-10-12","meals":[{"slot":0,"recipeId":"beef_tacos","servings":4}]}',
      });
      expect(state.plan, isNull);
      await state.init();
      expect(state.plan, isNotNull);
      expect(state.plan!.meals.every((m) => isKnownRecipe(m.recipeId)), isTrue);
    });
  });
}
