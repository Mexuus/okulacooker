import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/store.dart';
import 'zip_locator.dart';

/// How one ingredient's price varies by region.
class ItemPrice {
  /// `bls` = BLS regional average prices; `fmap` = USDA food-group ratios.
  final String source;
  final String? blsCode;

  /// Month of the latest BLS observation used (yyyy-MM).
  final String? asOf;

  /// USDA ERS food-group code used for metro adjustments.
  final String foodGroup;

  /// Regional price ÷ national price, keyed by region id (NE, MW, S, W).
  final Map<String, double> regionRatio;

  const ItemPrice({
    required this.source,
    required this.foodGroup,
    required this.regionRatio,
    this.blsCode,
    this.asOf,
  });

  static const neutral = ItemPrice(source: 'none', foodGroup: '', regionRatio: {});

  bool get isBls => source == 'bls';
  double ratioFor(String regionId) => regionRatio[regionId] ?? 1.0;
}

/// A metro area with food-group price adjustments relative to its region.
class Metro {
  final String code;
  final String name;
  final String regionId;
  final double lat;
  final double lng;
  final double radiusMi;
  final Map<String, double> factors;

  const Metro({
    required this.code,
    required this.name,
    required this.regionId,
    required this.lat,
    required this.lng,
    required this.radiusMi,
    required this.factors,
  });

  double factorFor(String foodGroup) => factors[foodGroup] ?? 1.0;
}

/// Bundled local price data (`assets/data/prices.json`), built by
/// `tool/build_price_data.py` from BLS Average Price Data and USDA ERS F-MAP.
class PriceBook {
  static const assetPath = 'assets/data/prices.json';

  /// Month the BLS data describes (yyyy-MM).
  final String asOf;
  final Map<String, ItemPrice> items;
  final List<Metro> metros;

  const PriceBook({required this.asOf, required this.items, required this.metros});

  factory PriceBook.fromJson(Map<String, dynamic> j) {
    final items = <String, ItemPrice>{};
    (j['items'] as Map<String, dynamic>).forEach((id, raw) {
      final m = raw as Map<String, dynamic>;
      items[id] = ItemPrice(
        source: m['src'] as String,
        blsCode: m['code'] as String?,
        asOf: m['asOf'] as String?,
        foodGroup: m['efpg'] as String,
        regionRatio: {
          for (final r in const ['NE', 'MW', 'S', 'W'])
            if (m[r] != null) r: (m[r] as num).toDouble(),
        },
      );
    });
    final metros = [
      for (final raw in (j['metros'] as List).cast<Map<String, dynamic>>())
        Metro(
          code: raw['code'] as String,
          name: raw['name'] as String,
          regionId: raw['region'] as String,
          lat: (raw['lat'] as num).toDouble(),
          lng: (raw['lng'] as num).toDouble(),
          radiusMi: (raw['radiusMi'] as num).toDouble(),
          factors: (raw['factors'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toDouble())),
        ),
    ];
    return PriceBook(asOf: j['asOf'] as String, items: items, metros: metros);
  }

  factory PriceBook.fromJsonString(String s) =>
      PriceBook.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// No local data: national reference prices everywhere.
  static const empty = PriceBook(asOf: 'none', items: {}, metros: []);

  /// The price book in use. Set once at startup by [load].
  static PriceBook instance = empty;

  static Future<PriceBook> load() async {
    try {
      instance = PriceBook.fromJsonString(await rootBundle.loadString(assetPath));
    } catch (_) {
      instance = empty;
    }
    return instance;
  }

  bool get hasLiveData => items.isNotEmpty;

  int get blsItemCount => items.values.where((i) => i.isBls).length;

  ItemPrice itemFor(String ingredientId) => items[ingredientId] ?? ItemPrice.neutral;

  /// The metro area containing the point (nearest centre within its radius),
  /// restricted to [region] when given.
  Metro? metroFor(double? lat, double? lng, {Region? region}) {
    if (lat == null || lng == null) return null;
    Metro? best;
    var bestMi = double.infinity;
    for (final m in metros) {
      if (region != null && region.id != 'US' && region.id != m.regionId) continue;
      final mi = haversineKm(lat, lng, m.lat, m.lng) * 0.621371;
      if (mi <= m.radiusMi && mi < bestMi) {
        best = m;
        bestMi = mi;
      }
    }
    return best;
  }

  /// "September 2026" style label for [asOf].
  String get asOfLabel {
    final parts = asOf.split('-');
    if (parts.length != 2) return asOf;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final m = int.tryParse(parts[1]);
    return m == null || m < 1 || m > 12 ? asOf : '${months[m - 1]} ${parts[0]}';
  }
}
