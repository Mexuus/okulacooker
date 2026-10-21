import 'package:flutter/material.dart';

import '../data/recipe_db.dart';
import '../models/recipe.dart';
import 'ingredient_icon.dart';

/// Backdrop colours per cuisine family, so dishes from the same part of the
/// world feel related.
List<Color> gradientForRecipe(Recipe r) {
  const warm = [Color(0xFFFFB36C), Color(0xFFE0663A)];
  const tomato = [Color(0xFFFF8F7A), Color(0xFFD9483B)];
  const herb = [Color(0xFF9CD67A), Color(0xFF3F8F4A)];
  const spice = [Color(0xFFFFC56B), Color(0xFFC9782E)];
  const sea = [Color(0xFF7CC8F0), Color(0xFF2F78C4)];
  const umami = [Color(0xFFB59CFF), Color(0xFF6150D8)];
  const earth = [Color(0xFFD8B48C), Color(0xFF8A5A34)];
  switch (r.cuisine) {
    case 'Mexican' || 'Tex-Mex' || 'Southwest' || 'Caribbean' || 'Cajun':
      return warm;
    case 'Italian' || 'Spanish' || 'Portuguese':
      return tomato;
    case 'Greek' || 'Mediterranean' || 'Middle Eastern' || 'Turkish':
      return herb;
    case 'Indian' || 'Moroccan' || 'Thai' || 'Malaysian' || 'Indonesian' || 'West African':
      return spice;
    case 'Japanese' || 'Korean' || 'Chinese' || 'Vietnamese' || 'Filipino' || 'Asian':
      return umami;
    case 'Scandinavian':
      return sea;
  }
  return earth;
}

const _genericIcons = {'salt', 'jar', 'sake', 'amphora', 'canned_food', 'candy', 'butter'};

/// Up to [n] ingredients worth picturing besides the main one: the heaviest
/// non-seasoning ingredients with distinct, specific icons.
List<String> companionIngredients(Recipe r, {int n = 2}) {
  final anchorIcon = kIngredients[r.anchor]?.icon;
  final seen = <String?>{anchorIcon};
  final scored = <(String, double)>[];
  for (final ri in r.ingredients) {
    final ing = kIngredients[ri.ingredientId];
    if (ing == null || ing.id == r.anchor) continue;
    if (ing.category == 'spice' || ing.category == 'pantry') continue;
    if (ing.icon == null || _genericIcons.contains(ing.icon)) continue;
    scored.add((ing.id, ing.gramsFor(ri.amount, ri.unit)));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final out = <String>[];
  for (final (id, _) in scored) {
    if (seen.add(kIngredients[id]!.icon)) out.add(id);
    if (out.length == n) break;
  }
  return out;
}

/// A recipe's picture: its credited photo when it has one, otherwise an
/// illustrated plate of its main ingredients. Works offline either way.
class RecipeImage extends StatelessWidget {
  final Recipe recipe;
  final double height;
  final BorderRadius? borderRadius;

  /// Thumbnail mode: the main ingredient only, no companions.
  final bool compact;

  const RecipeImage({
    super.key,
    required this.recipe,
    this.height = 140,
    this.borderRadius,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final photo = recipe.photo;
    final illustrated = _Illustration(recipe: recipe, height: height, compact: compact);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: photo == null
            ? illustrated
            : Image.asset(
                photo.asset,
                fit: BoxFit.cover,
                cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
                semanticLabel: 'Photo of ${recipe.title}',
                errorBuilder: (_, _, _) => illustrated,
              ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  final Recipe recipe;
  final double height;
  final bool compact;
  const _Illustration({required this.recipe, required this.height, required this.compact});

  @override
  Widget build(BuildContext context) {
    final colors = gradientForRecipe(recipe);
    final plate = height * (compact ? 0.82 : 0.62);
    final companions = compact ? const <String>[] : companionIngredients(recipe);
    return Semantics(
      label: 'Illustration of ${recipe.title}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: plate * (companions.isEmpty ? 1 : 1.9),
            height: plate,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: plate,
                  height: plate,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.92),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: plate * 0.12,
                        offset: Offset(0, plate * 0.05),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: IngredientIcon(recipe.anchor, size: plate * 0.62),
                ),
                for (final (i, id) in companions.indexed)
                  Align(
                    alignment: Alignment(i == 0 ? -1 : 1, 0.55),
                    child: Container(
                      width: plate * 0.5,
                      height: plate * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      alignment: Alignment.center,
                      child: IngredientIcon(id, size: plate * 0.34),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
