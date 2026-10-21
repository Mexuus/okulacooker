import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:okulacooker/data/recipe_db.dart';
import 'package:okulacooker/models/settings.dart';
import 'package:okulacooker/screens/browse_screen.dart';
import 'package:okulacooker/screens/grocery_screen.dart';
import 'package:okulacooker/screens/pantry_screen.dart';
import 'package:okulacooker/screens/plan_screen.dart';
import 'package:okulacooker/screens/recipe_detail_screen.dart';
import 'package:okulacooker/screens/settings_screen.dart';
import 'package:okulacooker/services/location_service.dart';
import 'package:okulacooker/services/persistence.dart';
import 'package:okulacooker/services/store_directory.dart';
import 'package:okulacooker/services/store_locator.dart';
import 'package:okulacooker/services/zip_locator.dart';
import 'package:okulacooker/state/app_state.dart';

import 'test_helpers.dart';

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(
    await Persistence.create(),
    location: LocationService(zipLoader: () async => ZipLocator.fromCsv('90210,34.1030,-118.4105\n')),
    storeLocator: StoreLocator(
      allowOnline: false,
      directoryLoader: () async =>
          StoreDirectory.fromCsv('ralphs|34.0700|-118.4000|West Hollywood|CA|9040 W Sunset Blvd|\n'),
    ),
  );
  await state.completeOnboarding(UserSettings(
    zip: '90210',
    storeId: 'ralphs',
    householdSize: 4,
    cookNights: const [1, 2, 3, 4, 5],
    weeklyBudget: 120,
    twoWeekMode: true,
  ));
  return state;
}

Future<void> _pump(WidgetTester tester, AppState state, Widget screen) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
  final error = tester.takeException();
  if (error is FlutterError) debugPrint(error.toStringDeep());
  expect(error, isNull);
}

void main() {
  setUpAll(loadTestData);

  testWidgets('Plan screen shows a week of database recipes', (tester) async {
    final state = await _state();
    await _pump(tester, state, const PlanScreen());
    expect(find.text('Dinners'), findsOneWidget);
    expect(find.text(recipeById(state.plan!.meals.first.recipeId).title), findsOneWidget);
    expect(find.text('Choose'), findsWidgets);
    expect(find.textContaining('recipes you haven’t had yet'), findsOneWidget);
  });

  testWidgets('Browse screen lists and filters the library', (tester) async {
    final state = await _state();
    await _pump(tester, state, const BrowseScreen());
    expect(find.textContaining(' recipes'), findsWidgets);
    expect(find.text('New'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'tacos');
    await tester.pumpAndSettle();
    expect(find.text('Crispy Chicken Thigh Tacos'), findsOneWidget);
  });

  testWidgets('Choosing a meal from Browse puts it on that night', (tester) async {
    final state = await _state();
    await _pump(tester, state, const BrowseScreen(slot: 1));
    await tester.enterText(find.byType(TextField), 'Crispy Chicken Thigh Tacos');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Crispy Chicken Thigh Tacos'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Cook this on'));
    await tester.pumpAndSettle();
    expect(recipeById(state.plan!.meals[1].recipeId).title, 'Crispy Chicken Thigh Tacos');
  });

  testWidgets('Recipe detail renders directions for many recipes', (tester) async {
    final state = await _state();
    for (final r in kRecipes.take(25)) {
      await _pump(tester, state, RecipeDetailScreen(recipe: r, initialServings: 6));
      expect(find.text('Directions'), findsOneWidget);
      expect(find.textContaining('{'), findsNothing);
    }
  });

  testWidgets('Grocery, pantry and settings screens render', (tester) async {
    final state = await _state();
    await _pump(tester, state, const GroceryScreen());
    expect(find.textContaining('Total at'), findsOneWidget);
    expect(find.text('Already have the basics?'), findsOneWidget);
    await tester.tap(find.text('I have them'));
    await tester.pumpAndSettle();
    expect(find.text('Already have the basics?'), findsNothing);
    expect(state.pantry.ownedStapleIds, contains('salt_kosher'));
    await tester.scrollUntilVisible(find.textContaining('· buy ').first, 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('· buy '), findsWidgets);
    await _pump(tester, state, const PantryScreen());
    expect(find.text('Spices'), findsOneWidget);
    await _pump(tester, state, const SettingsScreen());
    await tester.scrollUntilVisible(find.text('Recipe library'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Recipe library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
