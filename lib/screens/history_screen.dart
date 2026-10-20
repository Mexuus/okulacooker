import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipes_seed.dart';
import '../models/plan.dart';
import '../state/app_state.dart';
import '../widgets/recipe_image.dart';
import 'recipe_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final theme = Theme.of(context);
        final history = state.history;

        return Scaffold(
          appBar: AppBar(title: const Text('Recent weeks')),
          body: history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Your last three weeks of dinners will show up here after '
                      'you generate a new week.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final WeekPlan plan in history)
                      _WeekSection(plan: plan),
                  ],
                ),
        );
      },
    );
  }
}

class _WeekSection extends StatelessWidget {
  final WeekPlan plan;
  const _WeekSection({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text('Week of ${plan.weekStart}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Card(
          child: Column(
            children: [
              for (final meal in plan.meals)
                Builder(builder: (context) {
                  final r = recipeById(meal.recipeId);
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: RecipeImage(
                            recipe: r, height: 44, emojiSize: 22),
                      ),
                    ),
                    title: Text(r.title),
                    subtitle: Text('${meal.servings} servings'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(
                          recipe: r,
                          initialServings: meal.servings,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
