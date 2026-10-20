import 'package:flutter/material.dart';

import '../models/recipe.dart';

/// Deterministic gradient for a recipe, derived from its id so the same dish
/// always looks the same. Fully offline — no image downloads.
List<Color> gradientForRecipe(String id) {
  const palettes = <List<Color>>[
    [Color(0xFFFF9A6C), Color(0xFFFF6B6B)],
    [Color(0xFF6DD5B3), Color(0xFF2E7D4F)],
    [Color(0xFF8E7CFF), Color(0xFF5B6BF0)],
    [Color(0xFFFFC56B), Color(0xFFF08C3A)],
    [Color(0xFF6CC6FF), Color(0xFF3A7BF0)],
    [Color(0xFFFF8FB1), Color(0xFFE05297)],
    [Color(0xFF9CD67A), Color(0xFF4F9E3A)],
    [Color(0xFFFFB36C), Color(0xFFBF5B04)],
  ];
  final hash = id.codeUnits.fold<int>(0, (a, b) => a + b);
  return palettes[hash % palettes.length];
}

/// A recipe "photo": a gradient banner with the dish emoji centered. Looks good
/// on cards, detail screens, and prints, with zero network dependency.
class RecipeImage extends StatelessWidget {
  final Recipe recipe;
  final double height;
  final double emojiSize;
  final BorderRadius? borderRadius;

  const RecipeImage({
    super.key,
    required this.recipe,
    this.height = 140,
    this.emojiSize = 56,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientForRecipe(recipe.id);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(recipe.emoji, style: TextStyle(fontSize: emojiSize)),
      ),
    );
  }
}
