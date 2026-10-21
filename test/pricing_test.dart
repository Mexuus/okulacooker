import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:okulacooker/data/recipe_db.dart';
import 'package:okulacooker/data/stores.dart';
import 'package:okulacooker/models/settings.dart';
import 'package:okulacooker/models/store_location.dart';
import 'package:okulacooker/services/location_service.dart';
import 'package:okulacooker/services/persistence.dart';
import 'package:okulacooker/services/price_book.dart';
import 'package:okulacooker/services/pricing.dart';
import 'package:okulacooker/services/store_directory.dart';
import 'package:okulacooker/services/store_locator.dart';
import 'package:okulacooker/services/zip_locator.dart';
import 'package:okulacooker/state/app_state.dart';

import 'test_helpers.dart';

PriceBook get book => PriceBook.instance;

PricingEngine at(String storeId, double lat, double lng, String state) => PricingEngine(
      store: storeById(storeId),
      location: PriceLocation(lat: lat, lng: lng, state: state, label: 'test'),
    );

void main() {
  setUpAll(loadTestData);

  group('price book data', () {
    test('covers every database ingredient in every region', () {
      for (final id in kIngredients.keys) {
        final item = book.items[id];
        expect(item, isNotNull, reason: id);
        for (final r in ['NE', 'MW', 'S', 'W']) {
          expect(item!.ratioFor(r), inInclusiveRange(0.8, 1.25), reason: '$id/$r');
        }
      }
    });

    test('uses current BLS regional prices for staple items', () {
      expect(book.asOf, matches(RegExp(r'^\d{4}-\d{2}$')));
      expect(book.blsItemCount, greaterThanOrEqualTo(20));
      final beef = book.items['ground_beef']!;
      expect(beef.isBls, isTrue);
      expect(beef.blsCode, '703112');
    });
  });

  group('metro detection', () {
    test('finds the metro a store is in', () {
      expect(book.metroFor(34.0700, -118.4000)?.name, 'Los Angeles');
      expect(book.metroFor(40.7357, -74.1724)?.name, 'New York');
      expect(book.metroFor(39.9259, -75.1196)?.name, 'Philadelphia');
      expect(book.metroFor(29.7589, -95.3677)?.name, 'Houston');
    });

    test('no metro outside the covered areas', () {
      expect(book.metroFor(36.7378, -119.7871), isNull); // Fresno
      expect(book.metroFor(39.7392, -104.9903), isNull); // Denver
      expect(book.metroFor(null, null), isNull);
    });
  });

  group('location-specific pricing', () {
    test('local price = national pack price × region × metro × chain', () {
      final beef = kIngredients['ground_beef']!;
      final q = at('ralphs', 34.07, -118.40, 'CA').quote(beef, 453.592);
      expect(q.region.id, 'W');
      expect(q.metro?.name, 'Los Angeles');
      expect(q.regionRatio, book.items['ground_beef']!.ratioFor('W'));
      expect(q.chainFactor, storeById('ralphs').priceMultiplier);
      expect(q.localPackPrice, closeTo(beef.packPrice * q.factor, 1e-9));
      expect(q.proportionalCost, closeTo(453.592 * beef.pricePerGram * q.factor, 1e-9));
    });

    test('the same chain costs different amounts in different places', () {
      final tomato = kIngredients['tomato_fresh']!;
      final houston = at('kroger', 29.76, -95.37, 'TX').quote(tomato).localPackPrice;
      final detroit = at('kroger', 42.33, -83.05, 'MI').quote(tomato).localPackPrice;
      expect(houston, isNot(closeTo(detroit, 0.001)));
    });

    test('a store inside a metro is priced differently from one outside it', () {
      final la = at('ralphs', 34.07, -118.40, 'CA');
      final fresno = at('ralphs', 36.74, -119.79, 'CA');
      expect(la.metro, isNotNull);
      expect(fresno.metro, isNull);
      final laTotal = kIngredients.values.fold(0.0, (s, i) => s + la.quote(i).localPackPrice);
      final fresnoTotal = kIngredients.values.fold(0.0, (s, i) => s + fresno.quote(i).localPackPrice);
      expect(laTotal, isNot(closeTo(fresnoTotal, 0.5)));
    });

    test('discount chains beat premium chains at the same location', () {
      final beef = kIngredients['ground_beef']!;
      expect(at('aldi', 41.88, -87.63, 'IL').quote(beef).localPackPrice,
          lessThan(at('whole_foods', 41.88, -87.63, 'IL').quote(beef).localPackPrice));
    });

    test('settings price at the picked store location, not just the ZIP', () {
      final zipOnly = UserSettings(zip: '93721', storeId: 'ralphs'); // Fresno ZIP
      final withStore = zipOnly.copyWith(
        storeLocation: const StoreLocationRef(
            storeId: 'ralphs', label: 'Ralphs', lat: 34.07, lng: -118.40, state: 'CA',
            address: '9040 W Sunset Blvd, West Hollywood'),
      );
      expect(PricingEngine.forSettings(zipOnly).metro, isNull);
      final engine = PricingEngine.forSettings(withStore);
      expect(engine.metro?.name, 'Los Angeles');
      expect(engine.location.label, '9040 W Sunset Blvd, West Hollywood');
      expect(engine.areaName, 'Los Angeles metro');
    });
  });

  group('settings', () {
    test('switching chain drops a store location from the old chain', () {
      final s = UserSettings(
        storeId: 'ralphs',
        storeLocation: const StoreLocationRef(storeId: 'ralphs', label: 'Ralphs', lat: 1, lng: 2),
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

  group('AppState store comparison', () {
    Future<AppState> makeState() async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        await Persistence.create(),
        location: LocationService(zipLoader: () async => ZipLocator.fromCsv('60601,41.8858,-87.6181\n')),
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
          zip: '60601', storeId: 'jewel_osco', householdSize: 4, weeklyBudget: 0));
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
      expect(rows.map((r) => r.$1.store.id), containsAll(['aldi', 'whole_foods', 'jewel_osco']));
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
