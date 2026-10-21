import 'dart:math' as math;

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

double _nearest(double v, double step) => (v / step).round() * step;

/// A scaled quantity rounded to something a cook can measure, switching unit
/// where that reads better (3 tsp → 1 tbsp, 0.2 cup → 3 tbsp, 0.3 lb → 5 oz).
/// [category] is the ingredient's database category; it decides whether a
/// counted item can be halved (an onion, a can) or must stay whole (eggs, buns).
({double qty, String unit}) kitchenAmount(double q, String unit, {String? category}) {
  switch (unit) {
    case 'tsp':
      final t = q < 0.25 ? math.max(0.125, _nearest(q, 0.125)) : _nearest(q, 0.25);
      // Resolve directly: recursing into 'tbsp' could bounce back here forever.
      if (t >= 3) return (qty: math.max(1, _nearest(t / 3, 0.5)), unit: 'tbsp');
      return (qty: t, unit: 'tsp');
    case 'tbsp':
      if (q < 1) return kitchenAmount(q * 3, 'tsp', category: category);
      if (q >= 4) return kitchenAmount(q / 16, 'cup', category: category);
      return (qty: _nearest(q, 0.5), unit: 'tbsp');
    case 'cup':
      if (q < 0.25) return kitchenAmount(q * 16, 'tbsp', category: category);
      final quarter = _nearest(q, 0.25), third = _nearest(q, 1 / 3);
      return (qty: (q - third).abs() < (q - quarter).abs() ? third : quarter, unit: 'cup');
    case 'lb':
      if (q < 0.5) return (qty: math.max(1, (q * 16).roundToDouble()), unit: 'oz');
      return (qty: _nearest(q, 0.25), unit: 'lb');
    case 'oz':
      return (qty: q < 4 ? math.max(0.5, _nearest(q, 0.5)) : q.roundToDouble(), unit: 'oz');
    case 'count':
      const whole = {'protein', 'bakery', 'dairy', 'grain', 'frozen'};
      if (whole.contains(category)) return (qty: math.max(1, q.roundToDouble()), unit: unit);
      return (qty: math.max(0.5, _nearest(q, 0.5)), unit: unit);
    case 'clove':
    case 'stalk':
      return (qty: math.max(1, q.roundToDouble()), unit: unit);
    case 'packet':
      return (qty: math.max(0.5, _nearest(q, 0.5)), unit: unit);
  }
  return (qty: q, unit: unit);
}

String _plural(String word, double qty) {
  if (!_many(qty) || word.endsWith('s')) return word;
  if (word.endsWith('y') && !RegExp(r'[aeiou]y$').hasMatch(word)) {
    return '${word.substring(0, word.length - 1)}ies';
  }
  if (RegExp(r'(sh|ch|x|o)$').hasMatch(word)) return '${word}es';
  return '${word}s';
}

/// "1½ lb boneless chicken thighs", "12 corn tortillas", "3 cloves garlic".
/// Scaled amounts are rounded with [kitchenAmount]; at the recipe's own
/// servings ([scale] 1) the database amount is shown as written.
String formatRecipeAmount(RecipeIngredient ri, double scale) {
  final ing = kIngredients[ri.ingredientId];
  final name = ing?.naturalName ?? ri.ingredientId.replaceAll('_', ' ');
  var q = ri.amount * scale;
  var unit = ri.unit;
  if ((scale - 1).abs() > 1e-9) {
    final k = kitchenAmount(q, unit, category: ing?.category);
    q = k.qty;
    unit = k.unit;
  }
  final qs = formatQty(q);
  switch (unit) {
    case 'count':
      if (ing?.category == 'canned') return '$qs ${_many(q) ? 'cans' : 'can'} $name';
      return '$qs ${_plural(name, q)}';
    case 'clove':
    case 'stalk':
    case 'packet':
      final base = name.replaceAll(RegExp(r'\s*head$'), '');
      return '$qs ${_plural(unit, q)} $base';
    case 'cup':
      return '$qs ${_many(q) ? 'cups' : 'cup'} $name';
    default:
      return '$qs $unit $name';
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
/// At the recipe's own servings the original wording is used verbatim;
/// otherwise quantities are rounded with [kitchenAmount].
String renderStepAmount(StepAmount a, double scale) {
  if ((scale - 1).abs() < 1e-9) return a.base;
  final category = kIngredients[a.cid]?.category;
  String measured(double v, double? v2) {
    final k = kitchenAmount(v, a.unit!, category: category);
    final k2 = v2 == null ? null : kitchenAmount(v2, a.unit!, category: category);
    final hi = (k2 != null && k2.unit == k.unit && k2.qty > k.qty) ? k2.qty : null;
    return _numberText(k.qty, hi, k.unit, a.width);
  }

  switch (a.kind) {
    case 'ref':
    case 'of':
    case 'per':
      return a.base;
    case 'all':
      if (a.nouns != null) return 'all the ${a.nouns![1]}';
      if (a.unit != null && a.unit != 'count') return measured(a.value * scale, null);
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
  const counted = {null, 'count', 'clove', 'stalk', 'packet'};
  if (a.nouns != null && counted.contains(a.unit)) {
    double round(double x) => kitchenAmount(x, a.unit ?? 'count', category: category).qty;
    final lo = round(v);
    final hi = v2 == null ? null : round(v2);
    final top = hi ?? lo;
    final noun = _many(top) ? a.nouns![1] : a.nouns![0];
    final range = hi == null || hi <= lo ? formatQty(lo) : '${formatQty(lo)} to ${formatQty(hi)}';
    return '$range $noun';
  }
  if (a.unit == null || a.unit == 'count') return _numberText(v, v2, a.unit, a.width);
  return measured(v, v2);
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
