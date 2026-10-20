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
  final double qty;
  final ItemPrice item;
  final Region region;
  final Metro? metro;
  final Store store;

  /// Price per recipe unit nationally, in the region, and the multipliers.
  final double nationalUnit;
  final double regionalUnit;
  final double metroFactor;
  final double chainFactor;

  const PriceQuote({
    required this.ingredient,
    required this.qty,
    required this.item,
    required this.region,
    required this.metro,
    required this.store,
    required this.nationalUnit,
    required this.regionalUnit,
    required this.metroFactor,
    required this.chainFactor,
  });

  double get unitPrice => regionalUnit * metroFactor * chainFactor;

  double get total => (unitPrice * qty * 100).round() / 100;
}

/// Estimates local grocery prices for a store location.
///
/// price = regional average price (BLS Average Price Data, or a TapCook
///         estimate regionalised with USDA food-group ratios)
///       × metro-area adjustment (USDA ERS F-MAP, 10 large metros)
///       × chain price positioning (TapCook estimate)
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
      PricingEngine(
        store: storeById(s.storeId),
        location: PriceLocation.forSettings(s),
        book: book,
      );

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
        location: PriceLocation(
            lat: lat, lng: lng, state: stateForZip(zip), label: 'ZIP $zip'),
        book: book,
      );

  /// Human description of the price area, e.g. "Los Angeles metro".
  String get areaName => metro != null ? '${metro!.name} metro' : '${region.name} region';

  PriceQuote quote(Ingredient ing, double qty) {
    final item = book.items[ing.id] ??
        ItemPrice(source: 'est', foodGroup: '', byRegion: {'US': ing.refPricePerUnit});
    return PriceQuote(
      ingredient: ing,
      qty: qty,
      item: item,
      region: region,
      metro: metro,
      store: store,
      nationalUnit: item.national,
      regionalUnit: item.inRegion(region.id),
      metroFactor: metro?.factorFor(item.foodGroup) ?? 1.0,
      chainFactor: store.priceMultiplier,
    );
  }

  /// Estimated cost for [qty] units of [ing] at this store location.
  double estimate(Ingredient ing, double qty) => quote(ing, qty).total;
}
