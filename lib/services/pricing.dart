import '../models/ingredient.dart';
import '../models/store.dart';
import '../data/regions.dart';
import '../data/stores.dart';

/// Turns national reference prices into store- and region-adjusted estimates.
///
/// IMPORTANT: these are estimates only. They start from a national reference
/// price per ingredient and are adjusted by the chosen chain and ZIP region.
/// Real prices change often and vary by branch, so checkout totals will differ.
class PricingEngine {
  final Store store;
  final Region region;

  PricingEngine({required this.store, required this.region});

  factory PricingEngine.from({required String storeId, required String zip}) {
    return PricingEngine(
      store: storeById(storeId),
      region: regionForZip(zip),
    );
  }

  double get multiplier => store.priceMultiplier * region.costMultiplier;

  /// Estimated cost for [qty] units of [ing] at this store/region.
  double estimate(Ingredient ing, double qty) {
    final raw = ing.refPricePerUnit * qty * multiplier;
    // Round to the nearest cent.
    return (raw * 100).round() / 100;
  }
}
