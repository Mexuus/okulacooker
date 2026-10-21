import 'package:flutter/material.dart';

/// Grocery aisle / department used to group the shopping list.
enum Aisle {
  produce,
  meat,
  seafood,
  dairy,
  bakery,
  frozen,
  pantry,
  spices,
  condiments,
  grains,
  canned,
  other,
}

extension AisleInfo on Aisle {
  String get label {
    switch (this) {
      case Aisle.produce:
        return 'Produce';
      case Aisle.meat:
        return 'Meat';
      case Aisle.seafood:
        return 'Seafood';
      case Aisle.dairy:
        return 'Dairy & Eggs';
      case Aisle.bakery:
        return 'Bakery';
      case Aisle.frozen:
        return 'Frozen';
      case Aisle.pantry:
        return 'Pantry';
      case Aisle.spices:
        return 'Spices';
      case Aisle.condiments:
        return 'Condiments';
      case Aisle.grains:
        return 'Grains & Pasta';
      case Aisle.canned:
        return 'Canned & Jarred';
      case Aisle.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case Aisle.produce:
        return Icons.eco_outlined;
      case Aisle.meat:
        return Icons.kebab_dining_outlined;
      case Aisle.seafood:
        return Icons.set_meal_outlined;
      case Aisle.dairy:
        return Icons.egg_outlined;
      case Aisle.bakery:
        return Icons.bakery_dining_outlined;
      case Aisle.frozen:
        return Icons.ac_unit_outlined;
      case Aisle.pantry:
        return Icons.kitchen_outlined;
      case Aisle.spices:
        return Icons.grass_outlined;
      case Aisle.condiments:
        return Icons.water_drop_outlined;
      case Aisle.grains:
        return Icons.rice_bowl_outlined;
      case Aisle.canned:
        return Icons.inventory_2_outlined;
      case Aisle.other:
        return Icons.shopping_basket_outlined;
    }
  }
}

/// One purchasable pack size of an ingredient (national reference price).
class PackOption {
  final String label; // e.g. "small", "family", or ""
  final double size;
  final String unit; // lb, oz, count, bunch, gal, ml
  final double price;
  final double grams;

  const PackOption({
    required this.label,
    required this.size,
    required this.unit,
    required this.price,
    required this.grams,
  });

  factory PackOption.fromJson(Map<String, dynamic> j) => PackOption(
        label: j['label'] as String? ?? '',
        size: (j['size'] as num).toDouble(),
        unit: j['unit'] as String,
        price: (j['price'] as num).toDouble(),
        grams: (j['grams'] as num).toDouble(),
      );
}

/// An ingredient from the recipe database, with pack sizes and a national
/// reference price per pack.
class Ingredient {
  final String id;

  /// Display name as stored, e.g. "Chicken thighs, boneless".
  final String name;
  final String category;
  final Aisle aisle;

  /// Pantry staple most kitchens keep (can be ticked off the bill for good).
  final bool staple;
  final int perishDays;

  /// Grams per recipe unit (lb, oz, cup, tbsp, tsp, count, clove, stalk, packet).
  final Map<String, double> unitGrams;

  /// Default pack and its national reference price.
  final double packPrice;
  final double gramsPerPack;
  final String packUnit;
  final double packSize;

  /// All purchasable pack sizes (small/family tiers when known).
  final List<PackOption> packs;

  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  /// Diet flags from the database: beef, pork, poultry, lamb, fish, shellfish,
  /// dairy, egg, gluten, nuts, honey.
  final Set<String> flags;

  /// File name (without extension) of the 3D food icon in assets/icons/food.
  final String? icon;

  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.aisle,
    required this.staple,
    required this.perishDays,
    required this.unitGrams,
    required this.packPrice,
    required this.gramsPerPack,
    required this.packUnit,
    required this.packSize,
    required this.packs,
    this.kcalPer100g = 0,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatPer100g = 0,
    this.flags = const {},
    this.icon,
  });

  factory Ingredient.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return Ingredient(
      id: j['canonical_id'] as String,
      name: j['display'] as String,
      category: j['category'] as String,
      aisle: Aisle.values.firstWhere((a) => a.name == j['aisle'], orElse: () => Aisle.other),
      staple: (j['is_pantry'] as num? ?? 0) == 1,
      perishDays: (j['perish_days'] as num?)?.toInt() ?? 7,
      unitGrams: (j['unit_grams'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      packPrice: n('pack_price_usd'),
      gramsPerPack: n('g_per_pack'),
      packUnit: j['pack_unit'] as String,
      packSize: n('pack_size'),
      packs: (j['packs'] as List)
          .map((p) => PackOption.fromJson(p as Map<String, dynamic>))
          .toList(),
      kcalPer100g: n('kcal_100g'),
      proteinPer100g: n('protein_100g'),
      carbsPer100g: n('carbs_100g'),
      fatPer100g: n('fat_100g'),
      flags: ((j['flags'] as List?) ?? const []).map((e) => e as String).toSet(),
      icon: j['icon'] as String?,
    );
  }

  /// Asset path of the ingredient's 3D icon, or null when it has none.
  String? get iconAsset => icon == null ? null : 'assets/icons/food/$icon.webp';

  /// National reference price per gram (default pack).
  double get pricePerGram => gramsPerPack > 0 ? packPrice / gramsPerPack : 0;

  /// Converts a recipe amount to grams (0 if the unit isn't known).
  double gramsFor(double amount, String unit) => amount * (unitGrams[unit] ?? 0);

  /// Spoils within two weeks — bought "later" when shopping two weeks at once.
  bool get perishable => perishDays < 14 && aisle != Aisle.frozen;

  /// Natural-language name: "Chicken thighs, boneless" -> "boneless chicken thighs".
  String get naturalName {
    final parts = name.split(', ');
    final s = parts.length == 2 ? '${parts[1]} ${parts[0]}' : name;
    return s.toLowerCase();
  }
}
