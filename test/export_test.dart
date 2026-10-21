import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:okulacooker/data/recipe_db.dart';
import 'package:okulacooker/models/grocery.dart';
import 'package:okulacooker/models/plan.dart';
import 'package:okulacooker/models/settings.dart';
import 'package:okulacooker/services/export_formats.dart';
import 'package:okulacooker/services/grocery_builder.dart';
import 'package:okulacooker/services/price_book.dart';
import 'package:okulacooker/services/pricing.dart';

import 'test_helpers.dart';

PricingEngine national() =>
    PricingEngine.from(storeId: 'trader_joes', zip: '', book: PriceBook.empty);

/// Minimal RFC-4180 reader, so the tests check the CSV the way a spreadsheet
/// would rather than the way it was written.
List<String> _parseCsvRow(String row) {
  final fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < row.length; i++) {
    final c = row[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < row.length && row[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      fields.add(field.toString());
      field.clear();
    } else {
      field.write(c);
    }
  }
  fields.add(field.toString());
  return fields;
}

void main() {
  setUpAll(loadTestData);

  final ctx = ExportContext(
    storeName: 'Trader Joe’s',
    areaName: 'National average',
    weekStart: '2026-10-19',
    generatedAt: DateTime(2026, 10, 21, 9),
  );

  late GroceryList list;
  late WeekPlan plan;

  setUp(() {
    final tacos = kRecipes.firstWhere(
        (r) => r.title == 'Crispy Chicken Thigh Tacos');
    plan = WeekPlan(
      weekStart: '2026-10-19',
      meals: [PlannedMeal(slot: 0, recipeId: tacos.id, servings: 4)],
    );
    list = GroceryBuilder(pricing: national(), ownedStaples: {'salt_kosher'})
        .build(plan);
  });

  group('grocery list text', () {
    test('groups by aisle and totals when asked', () {
      final text = groceryListText(list, const ExportOptions(), ctx);
      expect(text, startsWith('OkulaCooker grocery list — Trader Joe’s'));
      expect(text, contains('Produce:'));
      expect(text, contains('Estimated total:'));
      // Pantry items the user owns are left out by default.
      expect(text, isNot(contains('Kosher salt')));
    });

    test('is a plain list of names when aisles and prices are off', () {
      final text = groceryListText(
        list,
        const ExportOptions(groupByAisle: false, includePrices: false),
        ctx,
      );
      expect(text, isNot(contains('Produce:')));
      expect(text, isNot(contains('Estimated total')));
      expect(text, isNot(contains(r'$')));
      final items = const LineSplitter().convert(text).skip(3);
      expect(items, isNotEmpty);
      for (final line in items.where((l) => l.trim().isNotEmpty)) {
        expect(line, isNot(startsWith(' ')),
            reason: 'ungrouped lines should not be indented');
      }
    });

    test('can include pantry items the user already has', () {
      final text = groceryListText(
        list,
        const ExportOptions(includeOwned: true),
        ctx,
      );
      expect(text, contains('Kosher salt'));
      expect(text, contains('(have it)'));
    });
  });

  group('grocery list CSV', () {
    test('has a header, one row per item and a total row', () {
      final csv = groceryListCsv(list, const ExportOptions(), ctx);
      final rows = const LineSplitter().convert(csv);
      expect(rows.first,
          'Week,Aisle,Item,Need,Buy,Packs,Est price,In pantry');
      expect(rows.last, startsWith('Total,'));
      expect(rows.length, list.lines.where((l) => !l.ownedStaple).length + 2);
    });

    test('quotes fields so every row parses back to the same columns', () {
      final csv = groceryListCsv(list, const ExportOptions(includeOwned: true), ctx);
      final rows = const LineSplitter().convert(csv);
      for (final row in rows) {
        expect(_parseCsvRow(row).length, 8, reason: row);
      }
      // An item name with a comma in it must survive the round trip.
      final names = rows.skip(1).map((r) => _parseCsvRow(r)[2]).toList();
      for (final line in list.lines) {
        expect(names, contains(line.ingredient.name));
      }
    });
  });

  group('webhook payload', () {
    test('is JSON-encodable and carries a bare list of item names', () {
      final payload = groceryListJson(
        list,
        const ExportOptions(),
        ctx,
        meals: plan.meals,
        mealLabel: (m) => 'Mon',
        lookupRecipe: recipeById,
      );
      final round = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;

      expect(round['app'], 'OkulaCooker');
      expect(round['schema'], 1);
      expect(round['weekStart'], '2026-10-19');
      expect(round['total'], closeTo(list.total, 0.01));

      final names = (round['itemNames'] as List).cast<String>();
      expect(names, isNotEmpty);
      expect(names.length, (round['items'] as List).length);

      final meals = (round['meals'] as List).cast<Map<String, dynamic>>();
      expect(meals.single['night'], 'Mon');
      expect(meals.single['title'], 'Crispy Chicken Thigh Tacos');
    });
  });

  group('printable HTML', () {
    test('is a complete document with the list in it', () {
      final html = groceryListHtml(list, const ExportOptions(), ctx);
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<title>OkulaCooker grocery list</title>'));
      expect(html, contains('Estimated total'));
      expect(html, contains('@media print'));
      expect('<'.allMatches(html).length, greaterThan(20));
    });

    test('escapes names so a stray character cannot break the markup', () {
      expect(escapeHtml('Trader Joe\'s "<b>&"'),
          'Trader Joe\'s &quot;&lt;b&gt;&amp;&quot;');
    });

    test('renders a recipe card with every step', () {
      final recipe = kRecipes.firstWhere(
          (r) => r.title == 'Crispy Chicken Thigh Tacos');
      final html = recipeHtml(recipe, 6);
      expect(html, contains('Serves 6'));
      for (final phase in recipe.phases) {
        expect(html, contains(escapeHtml(phase.name)));
      }
    });
  });

  group('plan export', () {
    test('lists every night with its recipe', () {
      final text = weekPlanText(
        plan.meals,
        recipeById,
        (m) => 'Mon',
        ctx,
      );
      expect(text, contains('Mon: Crispy Chicken Thigh Tacos — serves 4'));
    });
  });

  group('export settings', () {
    test('survive a save and load round trip', () {
      final saved = UserSettings(
        exportWebhookUrl: 'https://home.local/api/webhook/okulacooker',
        appleShortcutName: 'Groceries to Reminders',
        exportGroupByAisle: false,
        exportIncludePrices: false,
        exportIncludeOwned: true,
      );
      final back = UserSettings.fromJson(
          jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>);

      expect(back.exportWebhookUrl, saved.exportWebhookUrl);
      expect(back.appleShortcutName, 'Groceries to Reminders');
      expect(back.exportGroupByAisle, isFalse);
      expect(back.exportIncludePrices, isFalse);
      expect(back.exportIncludeOwned, isTrue);
    });

    test('older saves without export settings get sensible defaults', () {
      final back = UserSettings.fromJson({'zip': '45011'});
      expect(back.exportWebhookUrl, '');
      expect(back.appleShortcutName, 'Add to Reminders');
      expect(back.exportGroupByAisle, isTrue);
      expect(back.exportIncludePrices, isTrue);
      expect(back.exportIncludeOwned, isFalse);
    });
  });
}
