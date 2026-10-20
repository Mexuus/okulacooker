import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tapcook/services/location_service.dart';
import 'package:tapcook/services/persistence.dart';
import 'package:tapcook/services/zip_locator.dart';
import 'package:tapcook/state/app_state.dart';
import 'package:tapcook/models/settings.dart';
import 'package:tapcook/screens/plan_screen.dart';

void main() {
  testWidgets('PlanScreen renders a generated week without throwing',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final persistence = await Persistence.create();
    final state = AppState(
      persistence,
      location: LocationService(
          zipLoader: () async => ZipLocator.fromCsv('90210,34.1030,-118.4105\n')),
    );
    await state.completeOnboarding(UserSettings(
      zip: '90210',
      storeId: 'kroger',
      householdSize: 4,
      cookNights: const [1, 2, 3, 4, 5],
      weeklyBudget: 100,
    ));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Dinners'), findsOneWidget);
  });
}
