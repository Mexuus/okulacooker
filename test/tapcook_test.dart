import 'package:flutter_test/flutter_test.dart';

import 'package:tapcook/data/catalog.dart';
import 'package:tapcook/data/recipes_seed.dart';
import 'package:tapcook/models/plan.dart';
import 'package:tapcook/services/format.dart';
import 'package:tapcook/services/grocery_builder.dart';
import 'package:tapcook/services/pricing.dart';

void main() {
  group('catalog integrity', () {
    test('every recipe ingredient id exists in the catalog', () {
      for (final r in kRecipes) {
        for (final ri in r.ingredients) {
          expect(kIngredients.containsKey(ri.ingredientId), isTrue,
              reason: '${r.id} references missing ingredient ${ri.ingredientId}');
        }
      }
    });

    test('every step token maps to one of the recipe ingredients', () {
      final tokenRe = RegExp(r'\{([^}]+)\}');
      for (final r in kRecipes) {
        final tokens = r.ingredients
            .where((i) => i.token != null)
            .map((i) => i.token)
            .toSet();
        for (final step in r.steps) {
          for (final m in tokenRe.allMatches(step)) {
            expect(tokens.contains(m.group(1)), isTrue,
                reason: '${r.id} step references unknown token {${m.group(1)}}');
          }
        }
      }
    });
  });

  group('pricing engine', () {
    test('store and region multipliers compound', () {
      final cheap = PricingEngine.from(storeId: 'aldi', zip: '75001'); // S. Central
      final pricey = PricingEngine.from(storeId: 'whole_foods', zip: '94105'); // West
      final ing = kIngredients['chicken_breast']!;
      expect(cheap.estimate(ing, 1), lessThan(pricey.estimate(ing, 1)));
    });

    test('estimate scales linearly with quantity', () {
      final p = PricingEngine.from(storeId: 'kroger', zip: '10001');
      final ing = kIngredients['rice_white']!;
      final one = p.estimate(ing, 1);
      final four = p.estimate(ing, 4);
      expect((four - one * 4).abs(), lessThan(0.05));
    });
  });

  group('grocery builder', () {
    PlannedMeal meal(String id, {int servings = 4, bool skipped = false}) =>
        PlannedMeal(slot: 0, recipeId: id, servings: servings, skipped: skipped);

    test('skipped meals contribute nothing', () {
      final pricing = PricingEngine.from(storeId: 'kroger', zip: '10001');
      final builder = GroceryBuilder(pricing: pricing, ownedStaples: {});
      final withMeal = builder.build(WeekPlan(
        weekStart: 'w',
        meals: [meal('beef_tacos')],
      ));
      final skipped = builder.build(WeekPlan(
        weekStart: 'w',
        meals: [meal('beef_tacos', skipped: true)],
      ));
      expect(withMeal.total, greaterThan(0));
      expect(skipped.total, 0);
    });

    test('owned staples are removed from the bill', () {
      final pricing = PricingEngine.from(storeId: 'kroger', zip: '10001');
      final plan = WeekPlan(weekStart: 'w', meals: [meal('beef_tacos')]);
      final none = GroceryBuilder(pricing: pricing, ownedStaples: {}).build(plan);
      final withSalt =
          GroceryBuilder(pricing: pricing, ownedStaples: {'salt'}).build(plan);
      // Tacos use taco_seasoning (not staple) but no salt; use a recipe with salt.
      final chiliPlan = WeekPlan(weekStart: 'w', meals: [meal('chili_con_carne')]);
      final chiliNone =
          GroceryBuilder(pricing: pricing, ownedStaples: {}).build(chiliPlan);
      final chiliSalt = GroceryBuilder(
              pricing: pricing, ownedStaples: {'salt', 'cumin', 'chili_powder'})
          .build(chiliPlan);
      expect(chiliSalt.total, lessThan(chiliNone.total));
      expect(chiliSalt.savedByPantry, greaterThan(0));
      // sanity: taco salt case unaffected since recipe has no salt
      expect(withSalt.total, none.total);
    });

    test('two-week plan separates fresh items to buy later', () {
      final pricing = PricingEngine.from(storeId: 'kroger', zip: '10001');
      final plan = WeekPlan(
        weekStart: 'w',
        meals: [meal('beef_tacos')],
        weekTwoMeals: [meal('baked_salmon_rice')],
      );
      final list =
          GroceryBuilder(pricing: pricing, ownedStaples: {}).build(plan);
      // Salmon (perishable) should be in laterLines, not the main list.
      expect(list.laterLines.any((l) => l.ingredient.id == 'salmon'), isTrue);
      expect(list.lines.any((l) => l.ingredient.id == 'salmon'), isFalse);
    });
  });

  group('serving scaling', () {
    test('step tokens render scaled amounts', () {
      final r = recipeById('spaghetti_meatballs');
      final single = applyStepTokens(r.steps[2], r, 1.0); // "Cook {spaghetti}..."
      final doubleBatch = applyStepTokens(r.steps[2], r, 2.0);
      expect(single.contains('{'), isFalse);
      expect(single, isNot(equals(doubleBatch)));
    });
  });

  test('formatQty renders common fractions', () {
    expect(formatQty(0.5), '½');
    expect(formatQty(1.5), '1½');
    expect(formatQty(2), '2');
  });
}
