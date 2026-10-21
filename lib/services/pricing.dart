import '../data/regions.dart';
import '../data/stores.dart';
import '../data/zip_states.dart';
import '../models/ingredient.dart';
import '../models/settings.dart';
import '../models/store.dart';
import 'price_book.dart';

/// Where prices are being estimated: a specific store location or the user's
/// ZIP area.
class PriceLocation {
  final double? lat;
  final double? lng;
  final String? state;

  /// Human description, e.g. "9040 W Sunset Blvd, West Hollywood" or "ZIP 90210".
  final String label;

  const PriceLocation({this.lat, this.lng, this.state, required this.label});

  factory PriceLocation.forSettings(UserSettings s) {
    final loc = s.storeLocation;
    if (loc != null && loc.storeId == s.storeId) {
      return PriceLocation(
        lat: loc.lat,
        lng: loc.lng,
        state: loc.state ?? stateForZip(s.zip),
        label: loc.address ?? loc.label,
      );
    }
    return PriceLocation(
      lat: s.zipLat,
      lng: s.zipLng,
      state: stateForZip(s.zip),
      label: s.zip.isEmpty ? 'National average' : 'ZIP ${s.zip}',
    );
  }
}

/// How one ingredient's local price was built — shown in the price breakdown.
class PriceQuote {
  final Ingredient ingredient;
  final double grams;
  final ItemPrice item;
  final Region region;
  final Metro? metro;
  final Store store;
  final double regionRatio;
  final double metroFactor;
  final double chainFactor;

  const PriceQuote({
    required this.ingredient,
    required this.grams,
    required this.item,
    required this.region,
    required this.metro,
    required this.store,
    required this.regionRatio,
    required this.metroFactor,
    required this.chainFactor,
  });

  /// Combined local multiplier on the national reference price.
  double get factor => regionRatio * metroFactor * chainFactor;

  /// Local price of the ingredient's default pack.
  double get localPackPrice => ingredient.packPrice * factor;

  double localPrice(PackOption p) => p.price * factor;

  /// Cost of exactly [grams] (the share of packs a recipe uses).
  double get proportionalCost => grams * ingredient.pricePerGram * factor;
}

/// Estimates local grocery prices for a store location.
///
/// price = national reference price (recipe database, per pack)
///       × regional ratio (BLS Average Price Data, or USDA food-group ratios)
///       × metro-area adjustment (USDA ERS F-MAP, 10 large metros)
///       × chain price positioning (OkulaCooker estimate)
///
/// These are estimates, not live shelf prices from any retailer.
class PricingEngine {
  final Store store;
  final Region region;
  final Metro? metro;
  final PriceLocation location;
  final PriceBook book;

  PricingEngine({
    required this.store,
    required this.location,
    PriceBook? book,
  })  : book = book ?? PriceBook.instance,
        region = regionForState(location.state),
        metro = (book ?? PriceBook.instance)
            .metroFor(location.lat, location.lng, region: regionForState(location.state));

  factory PricingEngine.forSettings(UserSettings s, {PriceBook? book}) =>
      PricingEngine(store: storeById(s.storeId), location: PriceLocation.forSettings(s), book: book);

  /// Convenience for a chain + ZIP (optionally with coordinates for metro pricing).
  factory PricingEngine.from({
    required String storeId,
    required String zip,
    double? lat,
    double? lng,
    PriceBook? book,
  }) =>
      PricingEngine(
        store: storeById(storeId),
        location: PriceLocation(lat: lat, lng: lng, state: stateForZip(zip), label: 'ZIP $zip'),
        book: book,
      );

  /// Human description of the price area, e.g. "Los Angeles metro".
  String get areaName => metro != null ? '${metro!.name} metro' : '${region.name} region';

  PriceQuote quote(Ingredient ing, [double grams = 0]) {
    final item = book.itemFor(ing.id);
    return PriceQuote(
      ingredient: ing,
      grams: grams,
      item: item,
      region: region,
      metro: metro,
      store: store,
      regionRatio: item.ratioFor(region.id),
      metroFactor: metro?.factorFor(item.foodGroup) ?? 1.0,
      chainFactor: store.priceMultiplier,
    );
  }

  /// Local multiplier for [ing] at this store.
  double factorFor(Ingredient ing) => quote(ing).factor;

  /// Estimated cost of [grams] of [ing] (proportional share of a pack).
  double costOf(Ingredient ing, double grams) => quote(ing, grams).proportionalCost;
}
