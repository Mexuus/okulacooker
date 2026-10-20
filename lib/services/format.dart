import '../data/recipe_db.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';

/// Formats a quantity using common cooking fractions (½, ⅓, ¼, ¾ …).
String formatQty(double qty) {
  if (qty <= 0) return '0';
  final whole = qty.floor();
  final frac = qty - whole;

  const fractionValues = <double>[0.125, 0.25, 0.333, 0.375, 0.5, 0.625, 0.666, 0.75, 0.875];
  const fractionSymbols = <String>['⅛', '¼', '⅓', '⅜', '½', '⅝', '⅔', '¾', '⅞'];

  String? fracStr;
  double best = 0.04;
  for (var i = 0; i < fractionValues.length; i++) {
    final d = (frac - fractionValues[i]).abs();
    if (d < best) {
      best = d;
      fracStr = fractionSymbols[i];
    }
  }
  if (fracStr != null) return whole > 0 ? '$whole$fracStr' : fracStr;
  if (frac < 0.04) return '$whole';
  if (frac > 0.96) return '${whole + 1}';
  final rounded = (qty * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toString();
}

const _shortUnit = {'tsp': 'tsp', 'tbsp': 'tbsp', 'cup': 'cup', 'lb': 'lb', 'oz': 'oz'};
const _longUnit = {
  'tsp': ('teaspoon', 'teaspoons'),
  'tbsp': ('tablespoon', 'tablespoons'),
  'cup': ('cup', 'cups'),
  'lb': ('pound', 'pounds'),
  'oz': ('ounce', 'ounces'),
};

bool _many(double q) => q > 1.0001;

String _plural(String word, double qty) {
  if (!_many(qty) || word.endsWith('s')) return word;
  if (word.endsWith('y') && !RegExp(r'[aeiou]y$').hasMatch(word)) {
    return '${word.substring(0, word.length - 1)}ies';
  }
  if (RegExp(r'(sh|ch|x|o)$').hasMatch(word)) return '${word}es';
  return '${word}s';
}

/// "1½ lb boneless chicken thighs", "12 corn tortillas", "3 cloves garlic".
String formatRecipeAmount(RecipeIngredient ri, double scale) {
  final ing = kIngredients[ri.ingredientId];
  final name = ing?.naturalName ?? ri.ingredientId.replaceAll('_', ' ');
  final q = ri.amount * scale;
  final qs = formatQty(q);
  switch (ri.unit) {
    case 'count':
      if (ing?.category == 'canned') return '$qs ${_many(q) ? 'cans' : 'can'} $name';
      return '$qs ${_plural(name, q)}';
    case 'clove':
    case 'stalk':
    case 'packet':
      final base = name.replaceAll(RegExp(r'\s*head$'), '');
      return '$qs ${_plural(ri.unit, q)} $base';
    case 'cup':
      return '$qs ${_many(q) ? 'cups' : 'cup'} $name';
    default:
      return '$qs ${ri.unit} $name';
  }
}

String _numberText(double v, double? v2, String? unit, String? width) {
  final a = formatQty(v);
  final range = v2 == null ? a : '$a${width == 'long' ? ' to ' : '–'}${formatQty(v2)}';
  final top = v2 ?? v;
  if (unit == null || unit == 'count') return range;
  if (width == 'long' && _longUnit.containsKey(unit)) {
    final (one, many) = _longUnit[unit]!;
    return '$range ${_many(top) ? many : one}';
  }
  final short = _shortUnit[unit] ?? unit;
  return '$range ${short == 'cup' && _many(top) ? 'cups' : short}';
}

/// Renders one `{n}` amount at [scale] (servings ÷ recipe servings).
/// At the recipe's own servings the original wording is used verbatim.
String renderStepAmount(StepAmount a, double scale) {
  if ((scale - 1).abs() < 1e-9) return a.base;
  switch (a.kind) {
    case 'ref':
    case 'of':
    case 'per':
      return a.base;
    case 'all':
      if (a.nouns != null) return 'all the ${a.nouns![1]}';
      if (a.unit != null && a.unit != 'count') {
        return _numberText(a.value * scale, null, a.unit, a.width);
      }
      return a.base;
  }
  // Linear (null kind or "lin"): scales with servings.
  if (a.kind == null && a.unit == null) return a.base; // "the other lime"
  final v = a.value * scale;
  final v2 = a.value2 == null ? null : a.value2! * scale;
  final forms = a.forms;
  if (forms != null && forms.length == 2) {
    final one = (v - 1).abs() < 0.26;
    return one ? forms[0] : forms[1].replaceAll('{n}', formatQty(v.roundToDouble()));
  }
  if (a.nouns != null && (a.unit == null || a.unit == 'count' || a.unit == 'clove')) {
    final top = v2 ?? v;
    final noun = _many(top) ? a.nouns![1] : a.nouns![0];
    final range = v2 == null ? formatQty(v) : '${formatQty(v)} to ${formatQty(v2)}';
    return '$range $noun';
  }
  return _numberText(v, v2, a.unit, a.width);
}

final _placeholder = RegExp(r'\{(\d+)\}');

/// A direction step's body with amounts filled in for [scale].
String renderActionBody(RecipeAction action, double scale) =>
    action.body.replaceAllMapped(_placeholder, (m) {
      final i = int.parse(m.group(1)!);
      return i < action.amounts.length ? renderStepAmount(action.amounts[i], scale) : m.group(0)!;
    });

/// Full step sentence: "Pat the chicken thighs completely dry…".
String renderAction(RecipeAction action, double scale) =>
    '${action.verb} ${renderActionBody(action, scale)}';

/// Human amount for [grams] of [ing] in its shopping unit
/// ("1.6 lb", "3", "½ bunch", "2 tsp").
String describeGrams(Ingredient ing, double grams) {
  switch (ing.packUnit) {
    case 'lb':
      return '${formatQty(grams / 453.592)} lb';
    case 'count':
      final per = ing.unitGrams['count'] ?? (ing.gramsPerPack / ing.packSize);
      return per > 0 ? formatQty(((grams / per) * 4).ceil() / 4) : '';
    case 'bunch':
      final b = grams / (ing.gramsPerPack / ing.packSize);
      return '${formatQty((b * 4).ceil() / 4)} ${_many(b) ? 'bunches' : 'bunch'}';
    case 'gal':
    case 'ml':
      final cup = ing.unitGrams['cup'];
      return cup == null ? '' : '${formatQty(grams / cup)} ${_many(grams / cup) ? 'cups' : 'cup'}';
    default: // oz packs: small amounts read better as spoons
      final tsp = ing.unitGrams['tsp'];
      if (tsp != null && grams < 15 * tsp) {
        final t = grams / tsp;
        return t >= 3 ? '${formatQty(t / 3)} tbsp' : '${formatQty(t)} tsp';
      }
      final cup = ing.unitGrams['cup'];
      if (cup != null && grams >= cup / 4 && ing.category != 'protein') {
        return '${formatQty(grams / cup)} ${_many(grams / cup) ? 'cups' : 'cup'}';
      }
      return '${formatQty(grams / 28.3495)} oz';
  }
}

/// "3.75 lb", "12-count", "750 ml", "1 bunch".
String describePack(PackOption p) {
  switch (p.unit) {
    case 'count':
      return p.size == 1 ? 'each' : '${formatQty(p.size)}-count';
    case 'bunch':
      return p.size == 1 ? 'bunch' : '${formatQty(p.size)} bunches';
    default:
      return '${formatQty(p.size)} ${p.unit}';
  }
}
