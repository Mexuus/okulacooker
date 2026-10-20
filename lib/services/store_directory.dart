import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../data/stores.dart';
import '../models/store.dart';
import 'zip_locator.dart';

/// One store location from the bundled directory.
class DirectoryEntry {
  final Store store;
  final double lat;
  final double lng;
  final String city;
  final String state;
  final String street;

  /// The location's own name when it differs from the chain (e.g. a banner).
  final String? label;

  const DirectoryEntry({
    required this.store,
    required this.lat,
    required this.lng,
    required this.city,
    required this.state,
    required this.street,
    this.label,
  });
}

/// Offline directory of ~24k US grocery store locations, bundled with the app
/// (built by `tool/build_store_directory.py` from All The Places [CC0] and
/// OpenStreetMap [ODbL] data). Lookups are instant and need no network.
class StoreDirectory {
  static const assetPath = 'assets/data/stores.csv';
  static const double _cellDeg = 0.25;

  final List<DirectoryEntry> entries;
  final Map<int, List<int>> _grid = {};

  StoreDirectory(this.entries) {
    for (var i = 0; i < entries.length; i++) {
      _grid.putIfAbsent(_cell(entries[i].lat, entries[i].lng), () => []).add(i);
    }
  }

  static int _row(double lat) => ((lat + 90) / _cellDeg).floor();
  static int _col(double lng) => ((lng + 180) / _cellDeg).floor();
  static int _key(int row, int col) => row * 10000 + col;
  static int _cell(double lat, double lng) => _key(_row(lat), _col(lng));

  /// Parses `store_id|lat|lng|city|state|street|label` rows; unknown store ids
  /// are skipped so an older app never shows a chain it can't price.
  factory StoreDirectory.fromCsv(String csv) {
    final byId = {for (final s in kStores) s.id: s};
    final out = <DirectoryEntry>[];
    for (final line in csv.split('\n')) {
      if (line.isEmpty) continue;
      final p = line.split('|');
      if (p.length < 7) continue;
      final store = byId[p[0]];
      final lat = double.tryParse(p[1]);
      final lng = double.tryParse(p[2]);
      if (store == null || lat == null || lng == null) continue;
      out.add(DirectoryEntry(
        store: store,
        lat: lat,
        lng: lng,
        city: p[3],
        state: p[4],
        street: p[5],
        label: p[6].isEmpty ? null : p[6],
      ));
    }
    return StoreDirectory(out);
  }

  static Future<StoreDirectory>? _shared;

  static Future<StoreDirectory> load() =>
      _shared ??= rootBundle.loadString(assetPath).then(StoreDirectory.fromCsv);

  int get length => entries.length;

  /// Locations within [radiusMiles], nearest first, with distances in miles.
  List<(DirectoryEntry, double)> nearby(double lat, double lng, double radiusMiles) {
    final radiusKm = radiusMiles * 1.609344;
    final dLat = radiusKm / 111.0;
    final dLng = radiusKm / (111.0 * max(0.1, cos(lat * pi / 180)));
    final results = <(DirectoryEntry, double)>[];
    for (var r = _row(lat - dLat); r <= _row(lat + dLat); r++) {
      for (var c = _col(lng - dLng); c <= _col(lng + dLng); c++) {
        final ids = _grid[_key(r, c)];
        if (ids == null) continue;
        for (final i in ids) {
          final e = entries[i];
          final km = haversineKm(lat, lng, e.lat, e.lng);
          if (km <= radiusKm) results.add((e, km / 1.609344));
        }
      }
    }
    results.sort((a, b) => a.$2.compareTo(b.$2));
    return results;
  }

  /// Number of locations per chain (for diagnostics / data-sources screen).
  Map<String, int> countsByStore() {
    final m = <String, int>{};
    for (final e in entries) {
      m[e.store.id] = (m[e.store.id] ?? 0) + 1;
    }
    return m;
  }
}
