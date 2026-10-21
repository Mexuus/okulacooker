import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tapcook/data/recipe_db.dart';
import 'package:tapcook/models/ingredient.dart';
import 'package:tapcook/models/plan.dart';
import 'package:tapcook/models/recipe.dart';
import 'package:tapcook/models/settings.dart';
import 'package:tapcook/screens/cook_mode_screen.dart';
import 'package:tapcook/services/diet.dart';
import 'package:tapcook/services/format.dart';
import 'package:tapcook/services/grocery_builder.dart';
import 'package:tapcook/services/location_service.dart';
import 'package:tapcook/services/persistence.dart';
import 'package:tapcook/services/plan_generator.dart';
import 'package:tapcook/services/price_book.dart';
import 'package:tapcook/services/pricing.dart';
import 'package:tapcook/services/zip_locator.dart';
import 'package:tapcook/state/app_state.dart';
import 'package:tapcook/widgets/recipe_image.dart';

import 'test_helpers.dart';

PricingEngine national() => PricingEngine.from(storeId: 'trader_joes', zip: '', book: PriceBook.empty);

Recipe byTitle(String t) => kRecipes.firstWhere((r) => r.title == t);

void main() {
  setUpAll(loadTestData);

  group('recipe database', () {
    test('is the curated original library plus the new recipes', () {
      expect(kRecipes.length, greaterThanOrEqualTo(420));
      expect(kIngredients.length, 211);
      expect(kRecipes.map((r) => r.id).toSet().length, kRecipes.length);
      final titles = kRecipes.map((r) => r.title).toSet();
      // Dropped side dishes, odd combinations and near-duplicates stay out.
      for (final gone in ['Miso Butter Mushrooms with Bok Choy', 'Fettuccine Pesto Bolognese',
          'Halloumi-Style Feta with Charred Peppers', 'Shakshuka Verde with Feta']) {
        expect(titles, isNot(contains(gone)));
      }
      for (final added in ['Instant Pot Butter Chicken', 'Classic Grilled Cheeseburgers with Potato Wedges',
          'Air Fryer Fish and Chips', 'Slow Cooker Chicken Tikka Masala', 'Classic Stuffed Bell Peppers']) {
        expect(titles, contains(added));
      }
      expect(titles, contains('Miso Butter Tilapia with Blistered Broccoli')); // renamed: it was never cod
    });

    test('every recipe is a full dinner portion', () {
      final kcal = [for (final r in kRecipes) r.nutrition.kcal]..sort();
      expect(kcal.first, greaterThanOrEqualTo(400), reason: 'lightest dinner');
      expect(kcal.last, lessThanOrEqualTo(1250), reason: 'heaviest dinner');
      expect(kcal[kcal.length ~/ 2], inInclusiveRange(600, 800));
      for (final r in kRecipes) {
        expect(r.nutrition.protein, greaterThanOrEqualTo(10), reason: r.title);
      }
    });

    test('gear needs, spice and diet flags come from the database', () {
      expect(byTitle('Instant Pot Butter Chicken').needs, {'pressure_cooker'});
      expect(byTitle('Classic Stuffed Bell Peppers').needs, contains('oven'));
      expect(byTitle('Nashville Hot Chicken Sandwiches').spicy, isTrue);
      expect(kIngredients['soy_sauce']!.flags, contains('gluten'));
      expect(kIngredients['honey']!.flags, contains('honey'));
      expect(kIngredients['shrimp_frozen']!.flags, contains('shellfish'));
      expect(kIngredients['worcestershire']!.flags, contains('fish'));
      expect(kIngredients.values.where((i) => i.icon != null).length, kIngredients.length);
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
    test('settings from older versions keep their oven and split "no seafood"', () {
      final old = UserSettings.fromJson({
        'zip': '10001',
        'diets': ['noSeafood', 'vegetarian'],
        'equipment': ['slow_cooker'],
      });
      expect(old.equipment, {'slow_cooker', 'oven'});
      expect(old.diets, {Diet.noFish, Diet.noShellfish, Diet.vegetarian});
      expect(old.gearNights, 2);
      expect(old.maxMinutes, 60, reason: 'weeknight default for older settings');
      final saved = UserSettings.fromJson(
          old.copyWith(equipment: {'grill'}, maxMinutes: 45, mildOnly: true).toJson());
      expect(saved.equipment, {'grill'}, reason: 'a saved "no oven" choice sticks');
      expect(saved.maxMinutes, 45);
      expect(saved.mildOnly, isTrue);
      expect(UserSettings.fromJson(saved.copyWith(clearMaxMinutes: true).toJson()).maxMinutes, isNull);
    });

    test('diets rule out the right ingredients', () {
      bool ok(Recipe r, Diet d) => recipeAllowed(r, diets: {d}, excluded: const {});
      bool uses(Recipe r, String id) => r.ingredients.any((i) => i.ingredientId == id);
      final vegan = kRecipes.where((r) => ok(r, Diet.vegan)).toList();
      expect(vegan, isNotEmpty);
      for (final r in vegan) {
        for (final id in ['honey', 'butter_unsalted', 'egg_large', 'cheddar', 'chicken_breast']) {
          expect(uses(r, id), isFalse, reason: '${r.title} uses $id');
        }
      }
      final gf = kRecipes.where((r) => ok(r, Diet.glutenFree));
      expect(gf.any((r) => uses(r, 'pasta_long') || uses(r, 'soy_sauce')), isFalse);
      final chicken = kRecipes.firstWhere((r) => uses(r, 'chicken_breast'));
      expect(kRecipes.where((r) => uses(r, 'salmon_fillet') && ok(r, Diet.pescatarian)), isNotEmpty);
      expect(ok(chicken, Diet.pescatarian), isFalse);
      expect(kRecipes.where((r) => ok(r, Diet.nutFree)).any((r) => uses(r, 'peanut_butter')), isFalse);
    });

    test('cook-mode timers come from step durations or text', () {
      const explicit = RecipeAction(verb: 'Cook', body: 'until done.', duration: '7-8 hr');
      expect(stepTimer(explicit, 'until done.'), const Duration(hours: 7));
      const inText = RecipeAction(verb: 'Simmer', body: 'x');
      expect(stepTimer(inText, 'covered for 10–12 minutes, stirring once.'), const Duration(minutes: 10));
      expect(stepTimer(inText, 'until golden.'), isNull);
      expect(stepTimer(inText, 'for 20 seconds.'), isNull);
    });

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

    test('scaled amounts are rounded the way a cook measures', () {
      ({double qty, String unit}) k(double q, String u, [String? c]) =>
          kitchenAmount(q, u, category: c);
      expect(k(0.2, 'tsp'), (qty: 0.25, unit: 'tsp'));
      expect(k(2.9, 'tsp'), (qty: 1.0, unit: 'tbsp'));
      expect(k(0.99, 'tbsp'), (qty: 1.0, unit: 'tbsp')); // used to loop forever
      expect(k(0.6, 'tbsp'), (qty: 1.75, unit: 'tsp'));
      expect(k(4, 'tbsp'), (qty: 0.25, unit: 'cup'));
      expect(k(5, 'tbsp').qty, closeTo(1 / 3, 1e-9)); // 0.3125 cup is closest to ⅓
      expect(k(0.62, 'cup').qty, closeTo(2 / 3, 1e-9));
      expect(k(0.15, 'cup'), (qty: 2.5, unit: 'tbsp'));
      expect(k(0.3, 'lb'), (qty: 5.0, unit: 'oz'));
      expect(k(0.9, 'lb'), (qty: 1.0, unit: 'lb'));
      expect(k(0.8, 'count', 'produce'), (qty: 1.0, unit: 'count'));
      expect(k(0.3, 'count', 'canned'), (qty: 0.5, unit: 'count'));
      expect(k(1.5, 'count', 'protein'), (qty: 2.0, unit: 'count'));
      expect(k(0.4, 'clove'), (qty: 1.0, unit: 'clove'));
    });

    test('scaled ingredient lines never show decimals', () {
      final decimal = RegExp(r'\d\.\d');
      for (final r in kRecipes) {
        for (final people in [1, 2, 3, 5, 6, 8]) {
          final scale = people / r.baseServings;
          for (final ri in r.ingredients) {
            final line = formatRecipeAmount(ri, scale);
            expect(decimal.hasMatch(line), isFalse, reason: '${r.title} for $people: $line');
          }
          for (final p in r.phases) {
            for (final a in p.actions) {
              final text = renderActionBody(a, scale);
              final amounts = a.amounts.map((x) => renderStepAmount(x, scale));
              for (final s in amounts) {
                expect(decimal.hasMatch(s), isFalse, reason: '${r.title} for $people: $text');
              }
            }
          }
        }
      }
    });

    test('illustrations picture the main ingredient plus distinct companions', () {
      for (final r in kRecipes) {
        final companions = companionIngredients(r);
        expect(companions, isNot(contains(r.anchor)), reason: r.title);
        final icons = [kIngredients[r.anchor]!.icon, ...companions.map((c) => kIngredients[c]!.icon)];
        expect(icons.toSet().length, icons.length, reason: '${r.title}: $icons');
      }
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

    test('gear decides which recipes can be planned', () {
      final ovenOnly = allowedRecipes(settings);
      expect(ovenOnly.any(usesSpecialGear), isFalse);
      final everything = allowedRecipes(
          settings.copyWith(equipment: kGear.keys.toSet(), clearMaxMinutes: true));
      expect(everything.length, kRecipes.length);
      final noOven = allowedRecipes(settings.copyWith(equipment: {}));
      expect(noOven, isNotEmpty);
      expect(noOven.any((r) => r.needs.contains('oven')), isFalse);
      expect(noOven.length, lessThan(ovenOnly.length));
    });

    test('plans use owned gear the chosen number of nights', () {
      final gear = settings.copyWith(equipment: kGear.keys.toSet());
      for (final nights in [0, 1, 3]) {
        for (var seed = 0; seed < 10; seed++) {
          final plan = PlanGenerator(
            pricing: national(),
            ownedStaples: {},
            pool: allowedRecipes(gear),
            gearNights: nights,
            seed: seed,
          ).generate(gear);
          final special = plan.meals.where((m) => usesSpecialGear(recipeById(m.recipeId))).length;
          expect(special, nights, reason: 'gearNights $nights, seed $seed');
        }
      }
    });

    test('time, difficulty and spice filters', () {
      final quick = allowedRecipes(settings.copyWith(
          maxMinutes: 30, equipment: {'oven', 'slow_cooker'}));
      for (final r in quick) {
        expect(r.handsOff || r.totalMinutes <= 30, isTrue, reason: r.title);
      }
      expect(quick.any((r) => r.handsOff), isTrue, reason: 'slow cooker is exempt');
      expect(allowedRecipes(settings.copyWith(easyOnly: true)).every((r) => r.difficulty == 'Easy'),
          isTrue);
      final mild = allowedRecipes(settings.copyWith(mildOnly: true));
      expect(mild.any((r) => r.spicy), isFalse);
      expect(mild.length, lessThan(allowedRecipes(settings).length));
    });

    test('thumbs down removes a recipe; ratings steer new suggestions', () {
      final r = allowedRecipes(settings).first;
      expect(allowedRecipes(settings, disliked: {r.id}).map((x) => x.id), isNot(contains(r.id)));
      final liked = kRecipes.where((x) => x.cuisine == 'Thai').take(3).map((x) => x.id).toSet();
      final gen = PlanGenerator(
          pricing: national(), ownedStaples: {}, pool: allowedRecipes(settings), liked: liked, seed: 4);
      final thai = kRecipes.firstWhere((x) => x.cuisine == 'Thai' && !liked.contains(x.id));
      final other = kRecipes.firstWhere((x) => x.cuisine == 'British');
      expect(gen.preference(thai), greaterThan(gen.preference(other)));
      final hated = PlanGenerator(
          pricing: national(), ownedStaples: {}, disliked: liked, seed: 4);
      expect(hated.preference(thai), lessThan(0));
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

    test('thumbs down reports plan slots and keeps the recipe out of new plans', () async {
      final state = await makeState();
      await state.completeOnboarding(UserSettings(zip: '10001', weeklyBudget: 0));
      final victim = state.plan!.meals[1].recipeId;
      await state.toggleFavorite(victim);
      final slots = await state.toggleDislike(victim);
      expect(slots, [(1, false)]);
      expect(state.isDisliked(victim), isTrue);
      expect(state.isFavorite(victim), isFalse, reason: 'thumbs down replaces thumbs up');
      expect(state.allowedRecipeList.map((r) => r.id), isNot(contains(victim)));
      await state.resetRecipeHistory();
      for (var i = 0; i < 5; i++) {
        await state.generatePlan();
        expect(state.plan!.meals.map((m) => m.recipeId), isNot(contains(victim)));
      }
      expect(await state.toggleDislike(victim), isEmpty);
      expect(state.isDisliked(victim), isFalse);
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
