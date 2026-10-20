import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tapcook/data/recipes_seed.dart';
import 'package:tapcook/data/stores.dart';
import 'package:tapcook/data/zip_states.dart';
import 'package:tapcook/models/settings.dart';
import 'package:tapcook/services/diet.dart';
import 'package:tapcook/services/location_service.dart';
import 'package:tapcook/services/persistence.dart';
import 'package:tapcook/services/plan_generator.dart';
import 'package:tapcook/services/pricing.dart';
import 'package:tapcook/services/store_directory.dart';
import 'package:tapcook/services/store_locator.dart';
import 'package:tapcook/services/zip_locator.dart';
import 'package:tapcook/state/app_state.dart';
import 'package:tapcook/widgets/location_store_picker.dart';

class FakeGeo implements GeoProvider {
  final GeoFix? fix;
  final LocationException? error;
  FakeGeo({this.fix, this.error});
  @override
  Future<GeoFix> currentFix() async {
    if (error != null) throw error!;
    return fix!;
  }
}

const _sampleCsv = '90210,34.1030,-118.4105\n10001,40.7506,-73.9972\n60601,41.8858,-87.6181\n';

String _overpass(List<Map<String, dynamic>> elements) =>
    jsonEncode({'elements': elements});

/// Mimics Overpass: UTF-8 bytes with a charset-less JSON content type.
http.Response _jsonResponse(String body, [int status = 200]) => http.Response.bytes(
    utf8.encode(body), status, headers: {'content-type': 'application/json'});

Future<StoreDirectory> _emptyDir() async => StoreDirectory.fromCsv('');

void main() {
  final realZips = ZipLocator.fromCsv(File('assets/data/zcta.csv').readAsStringSync());
  final directory =
      StoreDirectory.fromCsv(File('assets/data/stores.csv').readAsStringSync());

  group('ZIP → state', () {
    test('maps common ZIPs', () {
      expect(stateForZip('90210'), 'CA');
      expect(stateForZip('10001'), 'NY');
      expect(stateForZip('60601'), 'IL');
      expect(stateForZip('75001'), 'TX');
      expect(stateForZip('73301'), 'TX');
      expect(stateForZip('99501'), 'AK');
      expect(stateForZip('20500'), 'DC');
      expect(stateForZip('00601'), 'PR');
      expect(stateForZip('abc'), isNull);
    });

    test('every bundled ZIP maps to a state or territory', () {
      final csv = File('assets/data/zcta.csv').readAsLinesSync();
      final unmapped = csv
          .where((l) => l.isNotEmpty)
          .map((l) => l.split(',').first)
          .where((z) => stateForZip(z) == null)
          .toList();
      expect(unmapped, isEmpty, reason: 'unmapped: ${unmapped.take(10)}');
    });
  });

  group('offline ZIP locator (Census data)', () {
    test('bundled dataset is complete', () {
      expect(realZips.length, greaterThan(30000));
      expect(realZips.lookup('90210'), isNotNull);
      expect(realZips.lookup('00000'), isNull);
    });

    test('reverse geocodes coordinates to the nearest ZIP', () {
      // Empire State Building
      final p = realZips.nearest(40.7484, -73.9857)!;
      expect(stateForZip(p.zip), 'NY');
      expect(haversineKm(40.7484, -73.9857, p.lat, p.lng), lessThan(2));
      // A ZIP's own centroid resolves to itself.
      final bh = realZips.lookup('90210')!;
      expect(realZips.nearest(bh.lat, bh.lng)!.zip, '90210');
    });
  });

  group('LocationService', () {
    LocationService svc(GeoProvider geo) => LocationService(
        geo: geo, zipLoader: () async => realZips);

    test('detects ZIP, state, and pricing region from GPS', () async {
      final place =
          await svc(FakeGeo(fix: const GeoFix(41.8827, -87.6233))).detect();
      expect(place.state, 'IL');
      expect(place.zip.startsWith('606'), isTrue);
      expect(place.region.name, 'Central');
    });

    test('rejects locations outside the US', () async {
      expect(
        () => svc(FakeGeo(fix: const GeoFix(51.5072, -0.1276))).detect(),
        throwsA(isA<LocationException>().having(
            (e) => e.reason, 'reason', LocationFailure.outsideUs)),
      );
    });

    test('surfaces permission errors', () async {
      expect(
        () => svc(FakeGeo(error: const LocationException(LocationFailure.denied)))
            .detect(),
        throwsA(isA<LocationException>()
            .having((e) => e.reason, 'reason', LocationFailure.denied)),
      );
    });

    test('resolves typed ZIPs and rejects unknown ones', () async {
      final s = svc(FakeGeo());
      expect((await s.resolveZip('10001'))!.state, 'NY');
      expect(await s.resolveZip('00000'), isNull);
      expect(await s.resolveZip('12'), isNull);
    });
  });

  group('store matching', () {
    test('recognises chains from map tags', () {
      expect(matchStore('Kroger')!.id, 'kroger');
      expect(matchStore('Walmart Supercenter')!.id, 'walmart');
      expect(matchStore('Trader Joe’s')!.id, 'trader_joes');
      expect(matchStore('Giant Eagle Market District')!.id, 'giant_eagle');
      expect(matchStore('Giant Food')!.id, 'giant');
      expect(matchStore('H-E-B plus!')!.id, 'heb');
      expect(matchStore("Rinaldi's Market"), isNull);
      expect(matchStore('Joe’s Corner Deli'), isNull);
    });

    test('store ids are unique', () {
      final ids = kStores.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('banner names are shown sensibly', () {
      NearbyStore n(String id, String label) =>
          NearbyStore(store: storeById(id), label: label, distanceMi: 1);
      expect(n('marianos', 'Marianos').displayName, "Mariano's");
      expect(n('marianos', 'Marianos').isOtherBanner, isFalse);
      expect(n('heb', '7th Street H-E-B').isOtherBanner, isFalse);
      expect(n('raleys', 'Nob Hill Foods').isOtherBanner, isTrue);
    });

    test('state ordering puts local chains first', () {
      final tx = storesForState('TX');
      final hebIndex = tx.indexWhere((s) => s.id == 'heb');
      final publixIndex = tx.indexWhere((s) => s.id == 'publix');
      expect(hebIndex, lessThan(publixIndex));
    });
  });

  group('StoreLocator (OpenStreetMap)', () {
    final body = _overpass([
      {'type': 'node', 'lat': 34.0700, 'lon': -118.4000,
        'tags': {'shop': 'supermarket', 'brand': 'Ralphs', 'name': 'Ralphs',
          'addr:housenumber': '9040', 'addr:street': 'W Sunset Blvd'}},
      {'type': 'way', 'center': {'lat': 34.1000, 'lon': -118.4100},
        'tags': {'shop': 'supermarket', 'name': 'Trader Joe’s'}},
      {'type': 'node', 'lat': 34.0500, 'lon': -118.3500,
        'tags': {'shop': 'supermarket', 'name': 'Ralphs Fresh Fare'}},
      {'type': 'node', 'lat': 34.1, 'lon': -118.4,
        'tags': {'shop': 'supermarket', 'name': 'Local Corner Market'}},
    ]);

    test('parses, matches, and sorts by distance', () {
      final res = StoreLocator.parse(body, 34.1030, -118.4105);
      expect(res.map((r) => r.store.id), ['trader_joes', 'ralphs', 'ralphs']);
      expect(res[1].address, '9040 W Sunset Blvd');
      final perChain = StoreLocator.closestPerChain(res);
      expect(perChain.map((r) => r.store.id), ['trader_joes', 'ralphs']);
    });

    test('falls back to the mirror endpoint when the first fails', () async {
      final hits = <String>[];
      final client = MockClient((req) async {
        hits.add(req.url.host);
        if (req.url.host == 'overpass-api.de') return http.Response('busy', 504);
        expect(req.bodyFields['data'], contains('around:'));
        return _jsonResponse(body);
      });
      final res = await StoreLocator(client: client, directoryLoader: _emptyDir)
          .nearby(34.1030, -118.4105);
      expect(hits, ['overpass-api.de', 'overpass.kumi.systems']);
      expect(res.first.store.id, 'trader_joes',
          reason: 'UTF-8 names like “Trader Joe’s” must decode correctly');
    });

    test('offline with no directory gives a friendly error', () async {
      final client = MockClient((_) async => throw const SocketException('offline'));
      expect(
          () => StoreLocator(
                  client: client,
                  directoryLoader: () async => throw StateError('missing'))
              .nearby(34.1, -118.4),
          throwsA(isA<StoreLookupException>()));
    });

    test('offline with an empty area returns no stores instead of failing', () async {
      final client = MockClient((_) async => throw const SocketException('offline'));
      final res = await StoreLocator(client: client, directoryLoader: _emptyDir)
          .nearby(34.1, -118.4);
      expect(res, isEmpty);
    });

    test('directory hits never touch the network', () async {
      final client = MockClient((_) async => fail('network should not be used'));
      final res = await StoreLocator(client: client, directoryLoader: () async => directory)
          .nearby(34.1030, -118.4105);
      expect(res, isNotEmpty);
      expect(res.every((r) => r.source == StoreSource.directory), isTrue);
    });
  });

  group('bundled store directory', () {
    test('loads ~24k locations and every chain id is known', () {
      final raw = File('assets/data/stores.csv')
          .readAsLinesSync()
          .where((l) => l.isNotEmpty)
          .toList();
      expect(directory.length, raw.length,
          reason: 'rows with unknown store ids were dropped');
      expect(directory.length, greaterThan(20000));
      final counts = directory.countsByStore();
      expect(counts['walmart'], greaterThan(4000));
      expect(counts['aldi'], greaterThan(2000));
    });

    test('finds real stores near Beverly Hills, nearest first', () {
      final hits = directory.nearby(34.1030, -118.4105, 5);
      final chains = hits.map((h) => h.$1.store.id).toSet();
      expect(chains, containsAll(['ralphs', 'trader_joes', 'whole_foods']));
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i].$2, greaterThanOrEqualTo(hits[i - 1].$2));
      }
      expect(hits.every((h) => h.$2 <= 5), isTrue);
    });

    test('regional chains show up in their home markets', () {
      Set<String> near(double lat, double lng) =>
          directory.nearby(lat, lng, 10).map((h) => h.$1.store.id).toSet();
      expect(near(30.2672, -97.7431), contains('heb')); // Austin
      expect(near(28.5383, -81.3792), contains('publix')); // Orlando
      expect(near(43.1566, -77.6088), contains('wegmans')); // Rochester NY
      expect(near(35.2271, -80.8431), contains('harris_teeter')); // Charlotte
      expect(near(39.7392, -104.9903), contains('king_soopers')); // Denver
    });

    test('rural areas widen the search radius', () async {
      const lat = 39.2474, lng = -114.8886; // Ely, Nevada
      final within10 = directory.nearby(lat, lng, 10);
      final within30 = directory.nearby(lat, lng, 30);
      final res = await StoreLocator(
              directoryLoader: () async => directory, allowOnline: false)
          .nearby(lat, lng);
      expect(res.length, within10.isNotEmpty ? within10.length : within30.length);
    });
  });

  group('diet filtering', () {
    test('vegetarian, dairy-free, and won’t-eat rules', () {
      bool ok(String id, {Set<Diet> d = const {}, Set<String> x = const {}}) =>
          recipeAllowed(recipeById(id), diets: d, excluded: x);
      expect(ok('beef_tacos', d: {Diet.vegetarian}), isFalse);
      expect(ok('veggie_stir_fry', d: {Diet.vegetarian}), isTrue);
      expect(ok('tuna_pasta_bake', d: {Diet.noSeafood}), isFalse);
      expect(ok('shrimp_alfredo', d: {Diet.dairyFree}), isFalse);
      expect(ok('egg_fried_rice', d: {Diet.dairyFree, Diet.vegetarian}), isTrue);
      expect(ok('sausage_peppers', d: {Diet.noPork}), isFalse);
      expect(ok('beef_tacos', x: {'tortilla'}), isFalse);
    });

    test('generator only uses allowed recipes and fills every night', () {
      final s = UserSettings(
          zip: '10001', diets: {Diet.vegetarian}, cookNights: [1, 2, 3, 4, 5, 6, 7]);
      final pool = allowedRecipes(s);
      expect(pool.length, greaterThanOrEqualTo(7));
      final plan = PlanGenerator(
        pricing: PricingEngine.from(storeId: 'kroger', zip: '10001'),
        ownedStaples: {},
        pool: pool,
        seed: 1,
      ).generate(s);
      expect(plan.meals.length, 7);
      for (final m in plan.meals) {
        expect(recipeById(m.recipeId).isVegetarian, isTrue, reason: m.recipeId);
      }
    });

    test('tiny pools repeat recipes; empty pools give an empty plan', () {
      final s = UserSettings(zip: '10001', cookNights: [1, 2, 3]);
      final pricing = PricingEngine.from(storeId: 'kroger', zip: '10001');
      final one = PlanGenerator(
              pricing: pricing, ownedStaples: {}, pool: [recipeById('beef_tacos')])
          .generate(s);
      expect(one.meals.map((m) => m.recipeId).toSet(), {'beef_tacos'});
      expect(one.meals.length, 3);
      final none =
          PlanGenerator(pricing: pricing, ownedStaples: {}, pool: []).generate(s);
      expect(none.meals, isEmpty);
    });

    test('diet settings survive a save/load round trip', () {
      final s = UserSettings(
          diets: {Diet.dairyFree, Diet.noPork}, excludedIngredients: {'mushroom'});
      final back = UserSettings.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.diets, {Diet.dairyFree, Diet.noPork});
      expect(back.excludedIngredients, {'mushroom'});
    });
  });

  testWidgets('“Locate” fills the ZIP and lists nearby stores', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final persistence = await Persistence.create();
    final state = AppState(
      persistence,
      location: LocationService(
        geo: FakeGeo(fix: const GeoFix(34.1030, -118.4105)),
        zipLoader: () async => ZipLocator.fromCsv(_sampleCsv),
      ),
      storeLocator: StoreLocator(
        allowOnline: false,
        directoryLoader: () async => StoreDirectory.fromCsv(
            'ralphs|34.0700|-118.4000|West Hollywood|CA|9040 W Sunset Blvd|\n'
            'raleys|34.0800|-118.4000|Los Angeles|CA|1 Main St|Nob Hill Foods\n'),
      ),
    );

    var zip = '';
    var storeId = 'kroger';
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: LocationStorePicker(
                zip: zip,
                storeId: storeId,
                autoSelectNearest: true,
                onZipChanged: (v) => setState(() => zip = v),
                onStoreChanged: (v) => setState(() => storeId = v),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Locate'));
    await tester.pumpAndSettle();

    expect(zip, '90210');
    expect(find.text('California · West Coast pricing'), findsOneWidget);
    expect(find.text('Stores near 90210'), findsOneWidget);
    expect(find.text('Ralphs'), findsWidgets);
    expect(find.textContaining('priced as Raley'), findsOneWidget);
    // Nearest store (Nob Hill Foods, priced as Raley's) is pre-selected.
    expect(storeId, 'raleys');

    await tester.tap(find.widgetWithText(ListTile, 'Ralphs'));
    await tester.pumpAndSettle();
    expect(storeId, 'ralphs');

    // Searching again must not override the user's explicit choice.
    await tester.tap(find.byTooltip('Search again'));
    await tester.pumpAndSettle();
    expect(storeId, 'ralphs');
    expect(tester.takeException(), isNull);
  });
}
