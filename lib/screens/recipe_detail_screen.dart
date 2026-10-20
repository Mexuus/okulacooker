import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../models/recipe.dart';
import '../services/format.dart';
import '../services/recipe_export.dart';
import '../state/app_state.dart';
import '../widgets/recipe_image.dart';

/// Full recipe view with live serving-size scaling and print/share.
class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final int initialServings;
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.initialServings,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _servings = widget.initialServings;

  double get _scale => _servings / widget.recipe.baseServings;

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => printRecipe(r, _servings),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share),
            onPressed: () => shareRecipe(r, _servings),
          ),
        ],
      ),
      body: ListView(
        children: [
          RecipeImage(recipe: r, height: 200, emojiSize: 90),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 4),
                    Text('${r.totalMinutes} min'),
                    const SizedBox(width: 16),
                    const Icon(Icons.local_fire_department_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text('${r.prepMinutes} prep / ${r.cookMinutes} cook'),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: r.tags
                      .map((t) => Chip(
                            label: Text(t),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),

                // Serving scaler
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_outlined),
                        const SizedBox(width: 10),
                        Text('Servings',
                            style: theme.textTheme.titleMedium),
                        const Spacer(),
                        IconButton.filledTonal(
                          onPressed: _servings > 1
                              ? () => setState(() => _servings--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$_servings',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        IconButton.filledTonal(
                          onPressed: _servings < 20
                              ? () => setState(() => _servings++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text('Ingredients',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...r.ingredients.map((ri) {
                  final ing = kIngredients[ri.ingredientId];
                  if (ing == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(
                          child: Text(formatAmount(ing, ri.qty * _scale),
                              style: theme.textTheme.bodyLarge),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),

                Text('Steps',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...r.steps.asMap().entries.map((e) {
                  final text = applyStepTokens(e.value, r, _scale);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text('${e.key + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer,
                              )),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(text, style: theme.textTheme.bodyLarge),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AppState>().freezeExtra(r.id, _servings);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Froze $_servings servings of ${r.title} for a later week'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.ac_unit),
                  label: const Text('Freeze extra servings'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Always review ingredients, measurements, cooking instructions, '
                  'food-safety guidance, and allergy information before cooking.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
