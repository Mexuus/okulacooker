import 'package:flutter/material.dart';

/// Grocery aisle / department used to group the shopping list and to decide
/// which items are perishable ("fresh") for two-week shopping.
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
        return 'Dairy';
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
        return 'Canned';
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

  /// Perishable aisles are separated as "buy later" in two-week planning.
  bool get isPerishable =>
      this == Aisle.produce ||
      this == Aisle.meat ||
      this == Aisle.seafood ||
      this == Aisle.dairy ||
      this == Aisle.bakery;
}

/// A purchasable ingredient with a *national reference price* per unit.
///
/// The reference price is a flat national estimate; the pricing engine adjusts
/// it for the chosen store chain and ZIP-based region. These are estimates, not
/// live retail prices.
class Ingredient {
  final String id;
  final String name;
  final Aisle aisle;

  /// The unit recipes measure this in (e.g. 'lb', 'oz', 'cup', 'clove', 'each').
  final String unit;

  /// National reference price in USD for one [unit] of this ingredient.
  final double refPricePerUnit;

  /// Whether this is a common pantry staple most people already own
  /// (so it can be ticked off and removed from the bill, permanently).
  final bool staple;

  const Ingredient({
    required this.id,
    required this.name,
    required this.aisle,
    required this.unit,
    required this.refPricePerUnit,
    this.staple = false,
  });
}
