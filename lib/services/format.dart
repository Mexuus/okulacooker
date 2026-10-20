import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../data/catalog.dart';

/// Formats a quantity using common cooking fractions (½, ⅓, ¼, ¾ …) and drops
/// trailing zeros so amounts read naturally.
String formatQty(double qty) {
  if (qty <= 0) return '0';
  final whole = qty.floor();
  final frac = qty - whole;

  const fractionValues = <double>[
    0.125, 0.25, 0.333, 0.375, 0.5, 0.625, 0.666, 0.75, 0.875,
  ];
  const fractionSymbols = <String>[
    '⅛', '¼', '⅓', '⅜', '½', '⅝', '⅔', '¾', '⅞',
  ];

  String? fracStr;
  double best = 0.04;
  for (var i = 0; i < fractionValues.length; i++) {
    final d = (frac - fractionValues[i]).abs();
    if (d < best) {
      best = d;
      fracStr = fractionSymbols[i];
    }
  }

  if (fracStr != null) {
    return whole > 0 ? '$whole$fracStr' : fracStr;
  }
  if (frac < 0.04) return '$whole';
  // Fall back to one decimal.
  final rounded = (qty * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

/// Pluralizes a unit for display when appropriate.
String _unitLabel(String unit, double qty) {
  const invariable = {'oz', 'lb', 'tsp', 'tbsp', 'cup'};
  if (invariable.contains(unit)) return unit;
  if (qty <= 1.0001) return unit;
  switch (unit) {
    case 'each':
      return '';
    case 'clove':
      return 'cloves';
    case 'can':
      return 'cans';
    case 'jar':
      return 'jars';
    case 'head':
      return 'heads';
    case 'bunch':
      return 'bunches';
    case 'packet':
      return 'packets';
    case 'stalk':
      return 'stalks';
    case 'block':
      return 'blocks';
    default:
      return unit;
  }
}

/// Renders a human amount like "1½ lb chicken breast" or "8 tortillas".
String formatAmount(Ingredient ing, double qty) {
  final unit = _unitLabel(ing.unit, qty);
  final q = formatQty(qty);
  if (unit.isEmpty) {
    return '$q ${ing.name.toLowerCase()}';
  }
  return '$q $unit ${ing.name.toLowerCase()}';
}

/// Replaces `{token}` placeholders in a recipe step with the scaled amount of
/// the matching ingredient, so quantities update with serving size.
String applyStepTokens(String step, Recipe recipe, double scale) {
  return step.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) {
    final token = m.group(1);
    final ri = recipe.ingredients.firstWhere(
      (e) => e.token == token,
      orElse: () => const RecipeIngredient('', -1),
    );
    if (ri.qty < 0) return m.group(0)!; // unknown token: leave as written
    final ing = kIngredients[ri.ingredientId];
    if (ing == null) return m.group(0)!;
    return formatAmount(ing, ri.qty * scale);
  });
}
