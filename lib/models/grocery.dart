import 'ingredient.dart';

/// A number of one pack size to buy.
class PackCount {
  final PackOption pack;
  final int count;
  const PackCount(this.pack, this.count);
}

/// One consolidated line on the grocery list: an ingredient, how much the
/// week's recipes need, which packs to buy, and their estimated local cost.
class GroceryLine {
  final Ingredient ingredient;
  final double grams;
  final List<PackCount> buy;
  final double estCost;

  /// Already in the pantry: shown ticked and left off the bill.
  final bool ownedStaple;

  GroceryLine({
    required this.ingredient,
    required this.grams,
    required this.buy,
    required this.estCost,
    this.ownedStaple = false,
  });

  int get packCount => buy.fold(0, (s, p) => s + p.count);
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
