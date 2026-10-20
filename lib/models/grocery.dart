import 'ingredient.dart';

/// One consolidated line on the grocery list: a single ingredient with the
/// total quantity needed across all planned meals, plus its estimated cost.
class GroceryLine {
  final Ingredient ingredient;
  final double qty;
  final double estCost;

  /// True when this item was removed from the bill because the user already has
  /// it in the pantry (kept for display, shown struck-through / $0).
  final bool ownedStaple;

  GroceryLine({
    required this.ingredient,
    required this.qty,
    required this.estCost,
    this.ownedStaple = false,
  });
}

/// A full estimated grocery list grouped by aisle, with totals. When planning
/// two weeks, [laterLines] holds perishable items to buy the following week.
class GroceryList {
  final List<GroceryLine> lines;
  final List<GroceryLine> laterLines;

  GroceryList({required this.lines, this.laterLines = const []});

  double get total =>
      lines.where((l) => !l.ownedStaple).fold(0.0, (s, l) => s + l.estCost);

  double get laterTotal =>
      laterLines.where((l) => !l.ownedStaple).fold(0.0, (s, l) => s + l.estCost);

  double get savedByPantry =>
      lines.where((l) => l.ownedStaple).fold(0.0, (s, l) => s + l.estCost);

  Map<Aisle, List<GroceryLine>> groupByAisle() {
    final map = <Aisle, List<GroceryLine>>{};
    for (final line in lines) {
      map.putIfAbsent(line.ingredient.aisle, () => []).add(line);
    }
    return map;
  }
}
