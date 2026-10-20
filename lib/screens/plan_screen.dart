import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipe_db.dart';
import '../models/plan.dart';
import '../services/grocery_builder.dart';
import '../state/app_state.dart';
import '../widgets/budget_bar.dart';
import '../widgets/money_text.dart';
import '../widgets/recipe_image.dart';
import '../widgets/slot_picker.dart';
import 'browse_screen.dart';
import 'recipe_detail_screen.dart';

const _weekdayShort = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final plan = state.plan;
        final grocery = state.groceryList;
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('This week'),
            actions: [
              IconButton(
                tooltip: 'Browse recipes',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const BrowseScreen())),
                icon: const Icon(Icons.menu_book_outlined),
              ),
              IconButton(
                tooltip: 'New week of meals',
                onPressed: () => state.generatePlan(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: plan == null
              ? const Center(child: Text('No plan yet.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (grocery != null)
                              BudgetBar(
                                total: grocery.total,
                                budget: state.settings.weeklyBudget,
                              ),
                            const SizedBox(height: 12),
                            _ShoppingDayRow(state: state),
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome_outlined, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${state.newRecipeCount} recipes you haven’t had yet',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Dinners',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (plan.meals.isEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.no_meals_outlined),
                          title: const Text('No recipes match your diet settings'),
                          subtitle: const Text(
                              'Loosen your diet or won’t-eat list in Settings, then regenerate.'),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => state.generatePlan(archive: false),
                          ),
                        ),
                      ),
                    ...plan.meals.map((m) => _MealCard(meal: m, state: state)),
                    if (plan.isTwoWeek) ...[
                      const SizedBox(height: 16),
                      Text('Next week',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Fresh items for these are on your list as “buy later”.',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      ...plan.weekTwoMeals.map((m) => _MealCard(
                            meal: m,
                            state: state,
                            readOnly: true,
                          )),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _ShoppingDayRow extends StatelessWidget {
  final AppState state;
  const _ShoppingDayRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.event_outlined, size: 20),
        const SizedBox(width: 8),
        const Text('Shopping day'),
        const Spacer(),
        DropdownButton<int>(
          value: state.settings.shoppingDay,
          underline: const SizedBox.shrink(),
          items: _weekdayShort.entries
              .map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              state.updateSettings(state.settings.copyWith(shoppingDay: v));
            }
          },
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final PlannedMeal meal;
  final AppState state;
  final bool readOnly;
  const _MealCard({
    required this.meal,
    required this.state,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = recipeById(meal.recipeId);
    final theme = Theme.of(context);
    final cost = estimateMealCost(meal, state.pricing);
    final dimmed = meal.skipped || meal.fromFreezer;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Column(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(
                    recipe: recipe,
                    initialServings: meal.servings,
                  ),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 96,
                    child: RecipeImage(
                        recipe: recipe, height: 96, emojiSize: 40),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${readOnly ? 'Next ' : ''}${slotLabel(state, meal.slot)} · ${recipe.cuisine}'
                                .toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 2),
                          Text(recipe.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: meal.skipped
                                    ? TextDecoration.lineThrough
                                    : null,
                              )),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${recipe.totalMinutes} min',
                                  style: theme.textTheme.bodySmall),
                              const SizedBox(width: 12),
                              Icon(Icons.people_alt_outlined,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${meal.servings}',
                                  style: theme.textTheme.bodySmall),
                              const Spacer(),
                              if (meal.fromFreezer)
                                const Icon(Icons.ac_unit, size: 16)
                              else
                                MoneyText(cost,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  _MealAction(
                    icon: Icons.autorenew,
                    label: 'Swap',
                    onTap: () => state.swapMeal(meal.slot, weekTwo: readOnly),
                  ),
                  _MealAction(
                    icon: Icons.menu_book_outlined,
                    label: 'Choose',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BrowseScreen(slot: meal.slot, weekTwo: readOnly),
                    )),
                  ),
                  if (!readOnly) ...[
                    _MealAction(
                      icon: meal.skipped ? Icons.undo : Icons.event_busy_outlined,
                      label: meal.skipped ? 'Restore' : 'Skip',
                      onTap: () => state.toggleSkip(meal.slot),
                    ),
                    _MealAction(
                      icon: Icons.ac_unit,
                      label: 'Freezer',
                      active: meal.fromFreezer,
                      onTap: () => state.toggleFromFreezer(meal.slot),
                    ),
                    _ServingsMenu(meal: meal, state: state),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _MealAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          foregroundColor: color,
        ),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ServingsMenu extends StatelessWidget {
  final PlannedMeal meal;
  final AppState state;
  const _ServingsMenu({required this.meal, required this.state});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PopupMenuButton<int>(
        tooltip: 'Servings',
        onSelected: (v) => state.setServings(meal.slot, v),
        itemBuilder: (_) => [
          for (var i = 1; i <= 12; i++)
            PopupMenuItem(value: i, child: Text('$i servings')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(Icons.tune,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 2),
              const Text('Servings', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
