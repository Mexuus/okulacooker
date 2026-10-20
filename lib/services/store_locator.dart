import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/stores.dart';
import '../models/store.dart';
import 'store_directory.dart';
import 'zip_locator.dart';

enum StoreSource { directory, openStreetMap }

/// One physical store location near the user that matches a known chain.
class NearbyStore {
  final Store store;
  final String label;
  final double distanceMi;
  final String? address;
  final StoreSource source;

  const NearbyStore({
    required this.store,
    required this.label,
    required this.distanceMi,
    this.address,
    this.source = StoreSource.openStreetMap,
  });

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// True when the location trades under a different name than its pricing
  /// chain (e.g. "Nob Hill Foods" priced as Raley's).
  bool get isOtherBanner => !_norm(label).contains(_norm(store.name));

  /// The location's own name, normalised to the chain name when they only
  /// differ by punctuation ("Marianos" -> "Mariano's").
  String get displayName => _norm(label) == _norm(store.name) ? store.name : label;
}

class StoreLookupException implements Exception {
  final String message;
  const StoreLookupException(this.message);
  @override
  String toString() => message;
}

/// Finds grocery stores near a coordinate.
///
/// Offline-first: searches the bundled [StoreDirectory] (instant, no network).
/// Only if nothing is found nearby does it fall back to a live OpenStreetMap
/// query via the public Overpass API (free, no key; data © OpenStreetMap
/// contributors, ODbL). Results are matched to TapCook's known chains.
class StoreLocator {
  static const attribution = '© OpenStreetMap contributors';
  static const endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  final http.Client _client;
  final Duration timeout;
  final bool allowOnline;
  final Future<StoreDirectory> Function() _directory;
  final Map<String, List<NearbyStore>> _cache = {};

  StoreLocator({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    this.allowOnline = true,
    Future<StoreDirectory> Function()? directoryLoader,
  })  : _client = client ?? http.Client(),
        _directory = directoryLoader ?? StoreDirectory.load;

  static String buildQuery(double lat, double lng, int radiusMeters) => '''
[out:json][timeout:20];
nwr["shop"~"^(supermarket|wholesale|department_store|grocery)\$"](around:$radiusMeters,${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)});
out center tags 300;
''';

  static String? _joinAddress(DirectoryEntry e) {
    final s = [
      if (e.street.isNotEmpty) e.street,
      if (e.city.isNotEmpty) e.city,
    ].join(', ');
    return s.isEmpty ? null : s;
  }

  static List<NearbyStore> _fromDirectory(List<(DirectoryEntry, double)> hits) => [
        for (final (e, mi) in hits)
          NearbyStore(
            store: e.store,
            label: e.label ?? e.store.name,
            distanceMi: mi,
            address: _joinAddress(e),
            source: StoreSource.directory,
          ),
      ];

  /// Matching store locations near the point, nearest first. Searches the
  /// bundled directory within [radiusMiles], then 3x that radius for rural
  /// areas, then (if allowed) live OpenStreetMap data.
  Future<List<NearbyStore>> nearby(double lat, double lng,
      {double radiusMiles = 10}) async {
    final key =
        '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)},$radiusMiles';
    final cached = _cache[key];
    if (cached != null) return cached;

    StoreDirectory? dir;
    try {
      dir = await _directory();
    } catch (_) {
      dir = null;
    }
    if (dir != null) {
      for (final r in [radiusMiles, radiusMiles * 3]) {
        final hits = dir.nearby(lat, lng, r);
        if (hits.isNotEmpty) return _cache[key] = _fromDirectory(hits);
      }
    }

    if (!allowOnline) {
      if (dir == null) {
        throw const StoreLookupException(
            'The store directory couldn’t be loaded. Showing stores common in your state instead.');
      }
      return _cache[key] = const [];
    }

    try {
      return _cache[key] = await _online(lat, lng, radiusMiles);
    } on StoreLookupException {
      // Directory worked but found nothing; an empty answer is honest.
      if (dir != null) return _cache[key] = const [];
      rethrow;
    }
  }

  Future<List<NearbyStore>> _online(
      double lat, double lng, double radiusMiles) async {
    final query = buildQuery(lat, lng, (radiusMiles * 1609.34).round());
    Object? lastError;
    for (final url in endpoints) {
      try {
        final res = await _client
            .post(Uri.parse(url), body: {'data': query})
            .timeout(timeout);
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        // Overpass serves UTF-8 JSON; don't rely on the charset header.
        return parse(utf8.decode(res.bodyBytes), lat, lng);
      } on TimeoutException {
        lastError = 'timed out';
      } catch (e) {
        lastError = e;
      }
    }
    throw StoreLookupException(
        'Couldn’t reach the store map ($lastError). Showing stores common in your state instead.');
  }

  /// Parses an Overpass JSON response into matched stores sorted by distance.
  static List<NearbyStore> parse(String body, double lat, double lng) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final elements = (json['elements'] as List?) ?? const [];
    final out = <NearbyStore>[];
    for (final e in elements.cast<Map<String, dynamic>>()) {
      final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final brand = tags['brand'] as String?;
      final name = tags['name'] as String?;
      final store = matchStore(brand) ?? matchStore(name);
      if (store == null) continue;

      final center = (e['center'] as Map?)?.cast<String, dynamic>();
      final eLat = ((e['lat'] ?? center?['lat']) as num?)?.toDouble();
      final eLng = ((e['lon'] ?? center?['lon']) as num?)?.toDouble();
      if (eLat == null || eLng == null) continue;

      final street = [tags['addr:housenumber'], tags['addr:street']]
          .whereType<String>()
          .join(' ');
      final city = tags['addr:city'] as String?;
      final address = [if (street.isNotEmpty) street, ?city].join(', ');

      out.add(NearbyStore(
        store: store,
        label: name ?? store.name,
        distanceMi: haversineKm(lat, lng, eLat, eLng) * 0.621371,
        address: address.isEmpty ? null : address,
      ));
    }
    out.sort((a, b) => a.distanceMi.compareTo(b.distanceMi));
    return out;
  }

  /// Closest location for each distinct chain, nearest first.
  static List<NearbyStore> closestPerChain(List<NearbyStore> all) {
    final seen = <String>{};
    return [
      for (final s in all)
        if (seen.add(s.store.id)) s,
    ];
  }
}
