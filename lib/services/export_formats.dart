/// Turns a grocery list, a week of dinners or a single recipe into the plain
/// text, CSV, JSON and printable HTML an export needs.
///
/// Nothing here touches the browser, the file system or Flutter widgets, so it
/// can be unit tested directly and reused by every export destination.
library;

import 'package:intl/intl.dart';

import '../models/grocery.dart';
import '../models/ingredient.dart';
import '../models/plan.dart';
import '../models/recipe.dart';
import 'format.dart';

final _money = NumberFormat.simpleCurrency(locale: 'en_US');
final _isoDate = DateFormat('yyyy-MM-dd');
final _longDate = DateFormat('EEEE d MMMM y');

/// What to put in an export. The user picks these per export, so a list bound
/// for Reminders or Alexa can be plain item names while a printout keeps the
/// aisles and prices.
class ExportOptions {
  /// Group items under their supermarket aisle instead of one flat list.
  final bool groupByAisle;

  /// Append the estimated local price to every line, plus a total.
  final bool includePrices;

  /// Include staples already ticked off in the pantry.
  final bool includeOwned;

  const ExportOptions({
    this.groupByAisle = true,
    this.includePrices = true,
    this.includeOwned = false,
  });

  ExportOptions copyWith({
    bool? groupByAisle,
    bool? includePrices,
    bool? includeOwned,
  }) =>
      ExportOptions(
        groupByAisle: groupByAisle ?? this.groupByAisle,
        includePrices: includePrices ?? this.includePrices,
        includeOwned: includeOwned ?? this.includeOwned,
      );
}

/// Where the list is being shopped, for the export's header.
class ExportContext {
  final String storeName;
  final String areaName;
  final String? weekStart;
  final DateTime generatedAt;

  ExportContext({
    required this.storeName,
    this.areaName = '',
    this.weekStart,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  String get subtitle => areaName.isEmpty ? storeName : '$storeName · $areaName';
}

String formatExportMoney(double v) => _money.format(v);

/// Everything needed to export one thing, in every format. The renderers are
/// lazy so only the format the user picks is built.
class ExportDoc {
  /// Shown at the top of the sheet, e.g. "Grocery list".
  final String title;

  /// File name without an extension.
  final String fileStem;

  final String Function(ExportOptions) text;
  final String Function(ExportOptions) html;

  /// Null when a spreadsheet makes no sense (a single recipe).
  final String Function(ExportOptions)? csv;

  /// Null when there is nothing useful to post to an automation.
  final Map<String, dynamic> Function(ExportOptions)? json;

  /// Recipes have nothing to group or price, so their sheet hides the
  /// layout switches.
  final bool showOptions;

  const ExportDoc({
    required this.title,
    required this.fileStem,
    required this.text,
    required this.html,
    this.csv,
    this.json,
    this.showOptions = true,
  });
}

// ---------------------------------------------------------------- grocery

List<GroceryLine> _visible(List<GroceryLine> lines, ExportOptions o) =>
    o.includeOwned ? lines : lines.where((l) => !l.ownedStaple).toList();

Map<Aisle, List<GroceryLine>> _byAisle(List<GroceryLine> lines) {
  final map = <Aisle, List<GroceryLine>>{};
  for (final l in lines) {
    map.putIfAbsent(l.ingredient.aisle, () => []).add(l);
  }
  return Map.fromEntries(
    map.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index)),
  );
}

/// "Broccoli — 1 × 2 lb" plus the price when asked for.
String groceryLineText(GroceryLine line, ExportOptions o) {
  final parts = StringBuffer(line.ingredient.name);
  final buy = buyText(line);
  if (buy.isNotEmpty) parts.write(' — $buy');
  if (line.ownedStaple) {
    parts.write(' (have it)');
  } else if (o.includePrices) {
    parts.write(' · ${formatExportMoney(line.estCost)}');
  }
  return parts.toString();
}

void _writeSection(
  StringBuffer out,
  String heading,
  List<GroceryLine> lines,
  ExportOptions o,
) {
  if (lines.isEmpty) return;
  out.writeln();
  out.writeln(heading.toUpperCase());
  if (o.groupByAisle) {
    for (final entry in _byAisle(lines).entries) {
      out.writeln();
      out.writeln('${entry.key.label}:');
      for (final line in entry.value) {
        out.writeln('  ${groceryLineText(line, o)}');
      }
    }
  } else {
    for (final line in lines) {
      out.writeln(groceryLineText(line, o));
    }
  }
}

/// The list as plain text — what gets copied, shared to Reminders, emailed or
/// handed to a Shortcut.
String groceryListText(GroceryList list, ExportOptions o, ExportContext ctx) {
  final out = StringBuffer();
  final now = _visible(list.lines, o);
  final later = _visible(list.laterLines, o);

  out.writeln('OkulaCooker grocery list — ${ctx.subtitle}');
  out.writeln(_longDate.format(ctx.generatedAt));

  _writeSection(out, later.isEmpty ? 'Shopping list' : 'Buy now', now, o);
  _writeSection(out, 'Buy next week (fresh)', later, o);

  if (o.includePrices) {
    out.writeln();
    out.writeln('Estimated total: ${formatExportMoney(list.total)}');
    if (later.isNotEmpty) {
      out.writeln('Next week: ${formatExportMoney(list.laterTotal)}');
    }
    out.writeln('Estimates only — the till will differ.');
  }
  return out.toString().trimRight();
}

String _csvCell(Object? value) {
  final s = '$value';
  return RegExp('[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _csvRow(List<Object?> cells) => cells.map(_csvCell).join(',');

/// Spreadsheet-friendly CSV, also the easiest thing for a local list app to
/// import.
String groceryListCsv(GroceryList list, ExportOptions o, ExportContext ctx) {
  final rows = <String>[
    _csvRow(['Week', 'Aisle', 'Item', 'Need', 'Buy', 'Packs', 'Est price', 'In pantry']),
  ];

  void add(String week, List<GroceryLine> lines) {
    for (final line in lines) {
      rows.add(_csvRow([
        week,
        line.ingredient.aisle.label,
        line.ingredient.name,
        describeGrams(line.ingredient, line.grams),
        buyText(line),
        line.packCount,
        line.ownedStaple ? '' : line.estCost.toStringAsFixed(2),
        line.ownedStaple ? 'yes' : 'no',
      ]));
    }
  }

  add('This week', _visible(list.lines, o));
  add('Next week', _visible(list.laterLines, o));
  rows.add(_csvRow(['Total', '', '', '', '', '', list.total.toStringAsFixed(2), '']));
  return rows.join('\r\n');
}

/// The payload posted to the user's webhook, e.g. an n8n or Home Assistant
/// flow that pushes the items onto an Alexa shopping list.
Map<String, dynamic> groceryListJson(
  GroceryList list,
  ExportOptions o,
  ExportContext ctx, {
  List<PlannedMeal> meals = const [],
  String Function(PlannedMeal)? mealLabel,
  Recipe? Function(String id)? lookupRecipe,
}) {
  Map<String, dynamic> item(GroceryLine line) => {
        'id': line.ingredient.id,
        'name': line.ingredient.name,
        'aisle': line.ingredient.aisle.label,
        'need': describeGrams(line.ingredient, line.grams),
        'needGrams': double.parse(line.grams.toStringAsFixed(1)),
        'buy': buyText(line),
        'packs': line.packCount,
        'estCost': double.parse(line.estCost.toStringAsFixed(2)),
        'inPantry': line.ownedStaple,
      };

  return {
    'app': 'OkulaCooker',
    'schema': 1,
    'generatedAt': ctx.generatedAt.toUtc().toIso8601String(),
    'weekStart': ctx.weekStart,
    'store': {'name': ctx.storeName, 'area': ctx.areaName},
    'currency': 'USD',
    'total': double.parse(list.total.toStringAsFixed(2)),
    'laterTotal': double.parse(list.laterTotal.toStringAsFixed(2)),
    'options': {
      'groupByAisle': o.groupByAisle,
      'includePrices': o.includePrices,
      'includeOwned': o.includeOwned,
    },
    // A bare list of names, so a flow can drop it straight onto a voice
    // assistant's shopping list without reshaping anything.
    'itemNames': [
      for (final l in _visible(list.lines, o)) l.ingredient.name,
    ],
    'items': [for (final l in _visible(list.lines, o)) item(l)],
    'laterItems': [for (final l in _visible(list.laterLines, o)) item(l)],
    'meals': [
      for (final m in meals)
        {
          'night': mealLabel?.call(m) ?? 'Night ${m.slot + 1}',
          'recipeId': m.recipeId,
          'title': lookupRecipe?.call(m.recipeId)?.title,
          'servings': m.servings,
          'skipped': m.skipped,
          'fromFreezer': m.fromFreezer,
        },
    ],
    'text': groceryListText(list, o, ctx),
  };
}

// ------------------------------------------------------------------- plan

/// The week's dinners as plain text.
String weekPlanText(
  List<PlannedMeal> meals,
  Recipe? Function(String id) lookup,
  String Function(PlannedMeal) label,
  ExportContext ctx, {
  List<PlannedMeal> weekTwo = const [],
}) {
  final out = StringBuffer();
  out.writeln('OkulaCooker dinners');
  out.writeln(_longDate.format(ctx.generatedAt));

  void week(String heading, List<PlannedMeal> list) {
    if (list.isEmpty) return;
    out.writeln();
    out.writeln(heading.toUpperCase());
    for (final m in list) {
      final r = lookup(m.recipeId);
      final title = r?.title ?? m.recipeId;
      final note = m.skipped
          ? ' (skipped)'
          : m.fromFreezer
              ? ' (from the freezer)'
              : '';
      final mins = r == null ? '' : ' · ${r.totalMinutes} min';
      out.writeln('${label(m)}: $title — serves ${m.servings}$mins$note');
    }
  }

  week(weekTwo.isEmpty ? 'This week' : 'Week one', meals);
  week('Week two', weekTwo);
  return out.toString().trimRight();
}

// ----------------------------------------------------------------- recipe

/// One recipe as plain text, scaled to [servings].
String recipeText(Recipe r, int servings) {
  final scale = servings / r.baseServings;
  final out = StringBuffer();
  out.writeln(r.title);
  out.writeln('Serves $servings · ${r.totalMinutes} min · ${r.cuisine}');
  out.writeln();
  out.writeln('INGREDIENTS');
  for (final ri in r.ingredients) {
    out.writeln('  ${formatRecipeAmount(ri, scale)}');
  }
  out.writeln();
  out.writeln('DIRECTIONS');
  for (final (i, phase) in r.phases.indexed) {
    final mins = phase.minutes > 0 ? ' (${phase.minutes} min)' : '';
    out.writeln();
    out.writeln('${i + 1}. ${phase.name}$mins');
    for (final a in phase.actions) {
      out.writeln('   ${renderAction(a, scale)}');
    }
  }
  out.writeln();
  out.writeln('From OkulaCooker. Check ingredients and allergens before cooking.');
  return out.toString().trimRight();
}

// ------------------------------------------------------------------- HTML

String escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const _printCss = '''
*, *::before, *::after { box-sizing: border-box; }
body {
  font: 15px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  color: #15231a;
  margin: 28px;
}
h1 { font-size: 24px; margin: 0 0 2px; }
h2 {
  font-size: 13px;
  letter-spacing: .08em;
  text-transform: uppercase;
  color: #2E7D4F;
  margin: 22px 0 6px;
  border-bottom: 1px solid #cfe3d6;
  padding-bottom: 3px;
}
.sub { color: #5d6b62; margin: 0 0 4px; }
ul { list-style: none; margin: 0; padding: 0; }
li {
  display: flex;
  align-items: baseline;
  gap: 8px;
  padding: 3px 0;
  border-bottom: 1px dotted #dde6e0;
  break-inside: avoid;
}
li .box {
  flex: none;
  width: 11px;
  height: 11px;
  border: 1.5px solid #8aa294;
  border-radius: 3px;
}
li .name { flex: 1 1 auto; }
li .qty { color: #5d6b62; }
li .price { flex: none; font-variant-numeric: tabular-nums; }
li.owned { color: #8c9a92; text-decoration: line-through; }
.total {
  margin-top: 18px;
  padding-top: 8px;
  border-top: 2px solid #2E7D4F;
  font-size: 18px;
  font-weight: 700;
  display: flex;
  justify-content: space-between;
}
.foot { margin-top: 22px; font-size: 11px; color: #7a8880; }
ol { padding-left: 18px; }
ol li { display: list-item; border: 0; padding: 2px 0; }
.step { margin: 10px 0; break-inside: avoid; }
.step h3 { font-size: 14px; margin: 0 0 3px; }
.verb { font-weight: 700; }
@page { margin: 14mm; }
@media print { body { margin: 0; } .noprint { display: none; } }
''';

String _htmlDocument(String title, String body) => '''<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<style>$_printCss</style>
</head><body>$body</body></html>''';

String _groceryItemsHtml(List<GroceryLine> lines, ExportOptions o) {
  final out = StringBuffer('<ul>');
  for (final line in lines) {
    final price = line.ownedStaple
        ? 'have it'
        : o.includePrices
            ? formatExportMoney(line.estCost)
            : '';
    out
      ..write('<li class="${line.ownedStaple ? 'owned' : ''}">')
      ..write('<span class="box"></span>')
      ..write('<span class="name">${escapeHtml(line.ingredient.name)}</span>')
      ..write('<span class="qty">${escapeHtml(buyText(line))}</span>')
      ..write('<span class="price">${escapeHtml(price)}</span>')
      ..write('</li>');
  }
  out.write('</ul>');
  return out.toString();
}

String _grocerySectionHtml(
    String heading, List<GroceryLine> lines, ExportOptions o) {
  if (lines.isEmpty) return '';
  final out = StringBuffer();
  if (o.groupByAisle) {
    for (final entry in _byAisle(lines).entries) {
      out
        ..write('<h2>${escapeHtml(entry.key.label)}</h2>')
        ..write(_groceryItemsHtml(entry.value, o));
    }
    return '<h2>${escapeHtml(heading)}</h2>$out';
  }
  return '<h2>${escapeHtml(heading)}</h2>${_groceryItemsHtml(lines, o)}';
}

/// A printable grocery list: tick boxes, aisles, prices and a total.
String groceryListHtml(GroceryList list, ExportOptions o, ExportContext ctx) {
  final now = _visible(list.lines, o);
  final later = _visible(list.laterLines, o);
  final body = StringBuffer()
    ..write('<h1>Grocery list</h1>')
    ..write('<p class="sub">${escapeHtml(ctx.subtitle)}</p>')
    ..write('<p class="sub">${escapeHtml(_longDate.format(ctx.generatedAt))}</p>')
    ..write(_grocerySectionHtml(
        later.isEmpty ? 'Shopping list' : 'Buy now', now, o))
    ..write(_grocerySectionHtml('Buy next week (fresh)', later, o));

  if (o.includePrices) {
    body.write('<div class="total"><span>Estimated total</span>'
        '<span>${escapeHtml(formatExportMoney(list.total))}</span></div>');
    if (later.isNotEmpty) {
      body.write('<div class="total"><span>Next week</span>'
          '<span>${escapeHtml(formatExportMoney(list.laterTotal))}</span></div>');
    }
  }
  body.write('<p class="foot">Made with OkulaCooker. Prices are local '
      'estimates, not live shelf prices — the till will differ.</p>');
  return _htmlDocument('OkulaCooker grocery list', body.toString());
}

/// A printable week of dinners.
String weekPlanHtml(
  List<PlannedMeal> meals,
  Recipe? Function(String id) lookup,
  String Function(PlannedMeal) label,
  ExportContext ctx, {
  List<PlannedMeal> weekTwo = const [],
}) {
  String week(String heading, List<PlannedMeal> list) {
    if (list.isEmpty) return '';
    final out = StringBuffer('<h2>${escapeHtml(heading)}</h2><ul>');
    for (final m in list) {
      final r = lookup(m.recipeId);
      final note = m.skipped
          ? ' · skipped'
          : m.fromFreezer
              ? ' · from the freezer'
              : '';
      final mins = r == null ? '' : ' · ${r.totalMinutes} min';
      out
        ..write('<li><span class="box"></span>')
        ..write('<span class="name"><strong>${escapeHtml(label(m))}</strong> — '
            '${escapeHtml(r?.title ?? m.recipeId)}</span>')
        ..write('<span class="qty">serves ${m.servings}'
            '${escapeHtml('$mins$note')}</span></li>');
    }
    out.write('</ul>');
    return out.toString();
  }

  final body = StringBuffer()
    ..write('<h1>Dinners</h1>')
    ..write('<p class="sub">${escapeHtml(_longDate.format(ctx.generatedAt))}</p>')
    ..write(week(weekTwo.isEmpty ? 'This week' : 'Week one', meals))
    ..write(week('Week two', weekTwo))
    ..write('<p class="foot">Made with OkulaCooker.</p>');
  return _htmlDocument('OkulaCooker dinners', body.toString());
}

/// A printable recipe card, scaled to [servings].
String recipeHtml(Recipe r, int servings) {
  final scale = servings / r.baseServings;
  final body = StringBuffer()
    ..write('<h1>${escapeHtml(r.title)}</h1>')
    ..write('<p class="sub">Serves $servings · ${r.totalMinutes} min · '
        '${escapeHtml(r.cuisine)} · ${escapeHtml(r.difficulty)}</p>')
    ..write('<h2>Ingredients</h2><ul>');
  for (final ri in r.ingredients) {
    body
      ..write('<li><span class="box"></span>')
      ..write('<span class="name">'
          '${escapeHtml(formatRecipeAmount(ri, scale))}</span></li>');
  }
  body.write('</ul><h2>Directions</h2>');
  for (final (i, phase) in r.phases.indexed) {
    final mins = phase.minutes > 0 ? ' (${phase.minutes} min)' : '';
    body.write('<div class="step"><h3>${i + 1}. '
        '${escapeHtml(phase.name)}${escapeHtml(mins)}</h3><ol>');
    for (final a in phase.actions) {
      body.write('<li><span class="verb">${escapeHtml(a.verb)}</span> '
          '${escapeHtml(renderActionBody(a, scale))}</li>');
    }
    body.write('</ol></div>');
  }
  body.write('<p class="foot">Made with OkulaCooker. Check ingredients, '
      'measurements and allergens before cooking.</p>');
  return _htmlDocument(r.title, body.toString());
}

/// A file name stem like `okulacooker-grocery-2026-10-21`.
String exportFileStem(String what, DateTime when) =>
    'okulacooker-$what-${_isoDate.format(when)}';
