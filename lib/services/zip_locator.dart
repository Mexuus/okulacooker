import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// A ZIP code centroid.
class ZipPoint {
  final String zip;
  final double lat;
  final double lng;
  const ZipPoint(this.zip, this.lat, this.lng);
}

/// Great-circle distance in kilometres.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * r * asin(min(1.0, sqrt(a)));
}

/// Offline ZIP <-> coordinate lookup backed by the bundled U.S. Census Bureau
/// ZCTA gazetteer (public domain). No network or API key required.
class ZipLocator {
  static const assetPath = 'assets/data/zcta.csv';

  final List<String> _zips;
  final Float64List _lat;
  final Float64List _lng;
  final Map<String, int> _index;

  ZipLocator._(this._zips, this._lat, this._lng)
      : _index = {for (var i = 0; i < _zips.length; i++) _zips[i]: i};

  /// Parses `zip,lat,lng` lines.
  factory ZipLocator.fromCsv(String csv) {
    final zips = <String>[];
    final lats = <double>[];
    final lngs = <double>[];
    for (final line in csv.split('\n')) {
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 3) continue;
      final la = double.tryParse(parts[1]);
      final lo = double.tryParse(parts[2]);
      if (la == null || lo == null) continue;
      zips.add(parts[0].trim());
      lats.add(la);
      lngs.add(lo);
    }
    return ZipLocator._(
        zips, Float64List.fromList(lats), Float64List.fromList(lngs));
  }

  static Future<ZipLocator>? _shared;

  /// Lazily loads and caches the bundled dataset.
  static Future<ZipLocator> load() =>
      _shared ??= rootBundle.loadString(assetPath).then(ZipLocator.fromCsv);

  int get length => _zips.length;

  ZipPoint? lookup(String zip) {
    final i = _index[zip.trim()];
    if (i == null) return null;
    return ZipPoint(_zips[i], _lat[i], _lng[i]);
  }

  /// Nearest ZIP centroid to the given coordinates (reverse geocoding).
  ZipPoint? nearest(double lat, double lng) {
    if (_zips.isEmpty) return null;
    // Cheap equirectangular distance for the scan; exact enough for ranking.
    final cosLat = cos(lat * pi / 180);
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < _zips.length; i++) {
      final dy = _lat[i] - lat;
      final dx = (_lng[i] - lng) * cosLat;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return ZipPoint(_zips[best], _lat[best], _lng[best]);
  }
}
