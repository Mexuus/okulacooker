/// A US grocery chain with a chain-level price multiplier applied to national
/// reference prices. Multipliers are rough positioning estimates, not real
/// retail pricing, and TapCook is not affiliated with any retailer.
class Store {
  final String id;
  final String name;

  /// Relative price factor vs. the national reference (1.0 = reference).
  final double priceMultiplier;

  /// States where the chain commonly operates (approximate). Null = nationwide.
  final Set<String>? states;

  /// Lower-case keywords used to recognise this chain in map data
  /// (OpenStreetMap `brand` / `name` tags).
  final List<String> keywords;

  const Store({
    required this.id,
    required this.name,
    required this.priceMultiplier,
    this.states,
    this.keywords = const [],
  });

  bool get isNational => states == null;

  bool operatesIn(String? state) =>
      state == null || states == null || states!.contains(state);
}

/// A US pricing region derived from a ZIP code, with a cost-of-living factor.
class Region {
  final String id;
  final String name;
  final double costMultiplier;

  const Region({
    required this.id,
    required this.name,
    required this.costMultiplier,
  });
}
