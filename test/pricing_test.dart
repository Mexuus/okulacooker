import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tapcook/data/catalog.dart';
import 'package:tapcook/data/stores.dart';
import 'package:tapcook/models/settings.dart';
import 'package:tapcook/models/store_location.dart';
import 'package:tapcook/services/location_service.dart';
import 'package:tapcook/services/persistence.dart';
import 'package:tapcook/services/price_book.dart';
import 'package:tapcook/services/pricing.dart';
import 'package:tapcook/services/store_directory.dart';
import 'package:tapcook/services/store_locator.dart';
import 'package:tapcook/services/zip_locator.dart';
import 'package:tapcook/state/app_state.dart';

final book =
    PriceBook.fromJsonString(File('assets/data/prices.json').readAsStringSync());

PricingEngine at(String storeId, double lat, double lng, String state) => PricingEngine(
      store: storeById(storeId),
      location: PriceLocation(lat: lat, lng: lng, state: state, label: 'test'),
      book: book,
    );

void main() {
  setUpAll(() => PriceBook.instance = book);

  group('price book data', () {
    test('covers every catalog ingredient in every region', () {
      for (final id in kIngredients.keys) {
        final item = book.items[id];
        expect(item, isNotNull, reason: id);
        for (final r in ['US', 'NE', 'MW', 'S', 'W']) {
          expect(item!.byRegion[r], greaterThan(0), reason: '$id/$r');
        }
      }
    });

    test('uses current BLS average prices for staple items', () {
      expect(book.asOf, matches(RegExp(r'^\d{4}-\d{2}$')));
      expect(book.blsItemCount, greaterThanOrEqualTo(20));
      final beef = book.items['ground_beef']!;
      expect(beef.isBls, isTrue);
      expect(beef.blsCode, '703112');
      // Ground beef is several dollars a pound everywhere.
      for (final r in ['US', 'NE', 'MW', 'S', 'W']) {
        expect(beef.inRegion(r), inInclusiveRange(3.0, 15.0));
      }
      // Eggs are priced per egg (a dozen / 12).
      expect(book.items['egg']!.national, inInclusiveRange(0.08, 0.80));
    });

    test('falls back to estimates when data is missing', () {
      final fallback = PriceBook.estimatesOnly();
      expect(fallback.hasLiveData, isFalse);
      expect(fallback.items['salmon']!.national, kIngredients['salmon']!.refPricePerUnit);
    });
  });

  group('metro detection', () {
    test('finds the metro a store is in', () {
      expect(book.metroFor(34.0700, -118.4000)?.name, 'Los Angeles'); // West Hollywood
      expect(book.metroFor(40.7357, -74.1724)?.name, 'New York'); // Newark NJ
      expect(book.metroFor(39.9259, -75.1196)?.name, 'Philadelphia'); // Camden NJ
      expect(book.metroFor(29.7589, -95.3677)?.name, 'Houston');
    });

    test('no metro outside the covered areas', () {
      expect(book.metroFor(36.7378, -119.7871), isNull); // Fresno
      expect(book.metroFor(39.7392, -104.9903), isNull); // Denver
      expect(book.metroFor(null, null), isNull);
    });
  });

  group('location-specific pricing', () {
    final beef = kIngredients['ground_beef']!;
    final tomato = kIngredients['tomato']!;

    test('quote = regional price × metro × chain', () {
      final q = at('ralphs', 34.07, -118.40, 'CA').quote(beef, 2);
      expect(q.region.id, 'W');
      expect(q.metro?.name, 'Los Angeles');
      expect(q.regionalUnit, book.items['ground_beef']!.inRegion('W'));
      expect(q.chainFactor, storeById('ralphs').priceMultiplier);
      expect(q.unitPrice, closeTo(q.regionalUnit * q.metroFactor * q.chainFactor, 1e-9));
      expect(q.total, closeTo(q.unitPrice * 2, 0.006));
    });

    test('the same chain costs different amounts in different places', () {
      final houston = at('kroger', 29.76, -95.37, 'TX').estimate(tomato, 10);
      final detroit = at('kroger', 42.33, -83.05, 'MI').estimate(tomato, 10);
      expect(houston, isNot(closeTo(detroit, 0.01)));
    });

    test('a store inside a metro is priced differently from one outside it', () {
      final la = at('ralphs', 34.07, -118.40, 'CA');
      final fresno = at('ralphs', 36.74, -119.79, 'CA');
      expect(la.region.id, fresno.region.id);
      expect(la.metro, isNotNull);
      expect(fresno.metro, isNull);
      var laTotal = 0.0, fresnoTotal = 0.0;
      for (final ing in kIngredients.values) {
        laTotal += la.estimate(ing, 1);
        fresnoTotal += fresno.estimate(ing, 1);
      }
      expect(laTotal, isNot(closeTo(fresnoTotal, 0.5)));
    });

    test('discount chains beat premium chains at the same location', () {
      final aldi = at('aldi', 41.88, -87.63, 'IL').estimate(beef, 1);
      final wholeFoods = at('whole_foods', 41.88, -87.63, 'IL').estimate(beef, 1);
      expect(aldi, lessThan(wholeFoods));
    });

    test('settings price at the picked store location, not just the ZIP', () {
      final zipOnly = UserSettings(zip: '93721', storeId: 'ralphs'); // Fresno ZIP
      final withStore = zipOnly.copyWith(
        storeLocation: const StoreLocationRef(
            storeId: 'ralphs', label: 'Ralphs', lat: 34.07, lng: -118.40, state: 'CA',
            address: '9040 W Sunset Blvd, West Hollywood'),
      );
      expect(PricingEngine.forSettings(zipOnly, book: book).metro, isNull);
      final engine = PricingEngine.forSettings(withStore, book: book);
      expect(engine.metro?.name, 'Los Angeles');
      expect(engine.location.label, '9040 W Sunset Blvd, West Hollywood');
      expect(engine.areaName, 'Los Angeles metro');
    });
  });

  group('settings', () {
    test('switching chain drops a store location from the old chain', () {
      final s = UserSettings(
        storeId: 'ralphs',
        storeLocation: const StoreLocationRef(
            storeId: 'ralphs', label: 'Ralphs', lat: 1, lng: 2),
      );
      expect(s.copyWith(storeId: 'vons').storeLocation, isNull);
      expect(s.copyWith(weeklyBudget: 90).storeLocation, isNotNull);
    });

    test('changing ZIP drops the old ZIP coordinates', () {
      final s = UserSettings(zip: '90210', zipLat: 34.1, zipLng: -118.4);
      expect(s.copyWith(zip: '10001').zipLat, isNull);
      expect(s.copyWith(householdSize: 3).zipLat, 34.1);
    });
  });

  group('AppState', () {
    Future<AppState> makeState() async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        await Persistence.create(),
        location: LocationService(
          zipLoader: () async =>
              ZipLocator.fromCsv('60601,41.8858,-87.6181\n'),
        ),
        storeLocator: StoreLocator(
          allowOnline: false,
          directoryLoader: () async => StoreDirectory.fromCsv(
            'aldi|41.8950|-87.6300|Chicago|IL|30 W Huron St|\n'
            'whole_foods|41.8920|-87.6200|Chicago|IL|255 E Grand Ave|\n'
            'jewel_osco|41.8930|-87.6280|Chicago|IL|550 N State St|\n',
          ),
        ),
      );
      await state.completeOnboarding(UserSettings(
          zip: '60601', storeId: 'jewel_osco', householdSize: 4, weeklyBudget: 150));
      return state;
    }

    test('ZIP coordinates are filled in for metro pricing', () async {
      final state = await makeState();
      expect(state.settings.zipLat, closeTo(41.8858, 1e-6));
      expect(state.pricing.metro?.name, 'Chicago');
    });

    test('compares nearby stores cheapest first and switches store location', () async {
      final state = await makeState();
      final rows = await state.compareNearbyStores();
      expect(rows.map((r) => r.$1.store.id),
          containsAll(['aldi', 'whole_foods', 'jewel_osco']));
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].$2, greaterThanOrEqualTo(rows[i - 1].$2));
      }
      expect(rows.first.$1.store.id, 'aldi');
      expect(rows.last.$1.store.id, 'whole_foods');

      final aldi = rows.first;
      await state.selectStore(aldi.$1.store.id, location: aldi.$1.toRef());
      expect(state.settings.storeLocation?.address, '30 W Huron St, Chicago');
      final list = state.groceryList!;
      expect(list.total + list.laterTotal, closeTo(aldi.$2, 0.01));
    });
  });
}
