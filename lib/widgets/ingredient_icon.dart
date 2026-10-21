import 'package:flutter/material.dart';

import '../data/recipe_db.dart';
import '../models/ingredient.dart';

/// The ingredient's 3D food icon, falling back to its aisle icon.
class IngredientIcon extends StatelessWidget {
  final String ingredientId;
  final double size;
  const IngredientIcon(this.ingredientId, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final ing = kIngredients[ingredientId];
    final fallback = Icon(ing?.aisle.icon ?? Icons.restaurant,
        size: size * 0.8, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final asset = ing?.iconAsset;
    if (asset == null) return SizedBox.square(dimension: size, child: Center(child: fallback));
    return Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size, child: Center(child: fallback)),
    );
  }
}
