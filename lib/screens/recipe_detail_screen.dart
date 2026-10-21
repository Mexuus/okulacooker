import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plan.dart';
import '../models/recipe.dart';
import '../services/format.dart';
import '../services/grocery_builder.dart';
import '../services/recipe_export.dart';
import '../state/app_state.dart';
import '../widgets/ingredient_icon.dart';
import '../widgets/money_text.dart';
import '../widgets/recipe_image.dart';
import '../widgets/slot_picker.dart';
import 'cook_mode_screen.dart';

/// "Week of Oct 6" style label for a yyyy-MM-dd date.
String weekLabel(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}';
}

/// Full recipe view: phase-by-phase directions that scale with servings,
/// local cost, nutrition, favorites, and adding the recipe to a night.
class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final int initialServings;

  /// When set (e.g. opened from "Choose a meal"), the main button calls this
  /// instead of asking which night.
  final VoidCallback? onChoose;
  final String? chooseLabel;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.initialServings,
    this.onChoose,
    this.chooseLabel,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _servings = widget.initialServings;

  /// Ingredient lines ticked off while gathering them.
  final Set<int> _gathered = {};

  double get _scale => _servings / widget.recipe.baseServings;

  Future<void> _thumbsDown(AppState state) async {
    final r = widget.recipe;
    final slots = await state.toggleDislike(r.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (!state.isDisliked(r.id)) {
      messenger.showSnackBar(const SnackBar(content: Text('Thumbs down removed')));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(slots.isEmpty
          ? 'Got it — TapCook won’t suggest this again, or dishes too much like it as often.'
          : 'Got it — it won’t be suggested again. Swap it out of this week?'),
      action: slots.isEmpty
          ? null
          : SnackBarAction(
              label: 'Swap',
              onPressed: () async {
                for (final (slot, weekTwo) in slots) {
                  await state.swapMeal(slot, weekTwo: weekTwo);
                }
              },
            ),
    ));
  }

  Future<void> _addToWeek(AppState state) async {
    if (widget.onChoose != null) {
      widget.onChoose!();
      return;
    }
    final pick = await showSlotPicker(context, state, title: 'Cook ${widget.recipe.title} on…');
    if (pick == null || !mounted) return;
    await state.chooseMeal(pick.$1, widget.recipe.id, weekTwo: pick.$2);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added to ${slotLabel(state, pick.$1)}${pick.$2 ? ' next week' : ''}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final fav = state.isFavorite(r.id);
    final disliked = state.isDisliked(r.id);
    final last = state.lastPlanned(r.id);
    final plan = state.plan;
    final onPlan = plan != null &&
        [...plan.meals, ...plan.weekTwoMeals].any((m) => m.recipeId == r.id);
    final cost = estimateMealCost(
        PlannedMeal(slot: 0, recipeId: r.id, servings: _servings), state.pricing);
    final nutrition = nutritionPerServing(r);

    Widget meta(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(r.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: fav ? 'Remove thumbs up' : 'Thumbs up — love it',
            isSelected: fav,
            icon: const Icon(Icons.thumb_up_outlined),
            selectedIcon: Icon(Icons.thumb_up, color: theme.colorScheme.primary),
            onPressed: () => state.toggleFavorite(r.id),
          ),
          IconButton(
            tooltip: disliked ? 'Remove thumbs down' : 'Thumbs down — don’t suggest it',
            isSelected: disliked,
            icon: const Icon(Icons.thumb_down_outlined),
            selectedIcon: Icon(Icons.thumb_down, color: theme.colorScheme.error),
            onPressed: () => _thumbsDown(state),
          ),
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
      bottomNavigationBar: state.plan == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: () => _addToWeek(state),
                  icon: const Icon(Icons.event_available),
                  label: Text(widget.chooseLabel ?? 'Add to this week'),
                ),
              ),
            ),
      body: ListView(
        children: [
          RecipeImage(recipe: r, height: 240),
          if (r.photo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(r.photo!.attribution,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  onPlan
                      ? 'On this week’s plan'
                      : last == null
                          ? '✨ New to you'
                          : 'You last had this the week of ${weekLabel(last)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: last == null ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      fontWeight: last == null ? FontWeight.w700 : null),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    meta(Icons.schedule, r.handsOff ? '${r.totalMinutes} min · hands-off' : '${r.totalMinutes} min'),
                    meta(Icons.public, r.cuisine),
                    meta(Icons.signal_cellular_alt, r.difficulty),
                    meta(Icons.soup_kitchen_outlined, r.formatLabel),
                    meta(Icons.local_fire_department_outlined, '${nutrition.kcal.round()} kcal'),
                    if (r.spicy) meta(Icons.whatshot, 'Spicy'),
                    meta(Icons.cleaning_services_outlined, 'Cleanup ${r.cleanupScore}/8'),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Servings', style: theme.textTheme.titleMedium),
                              Text('${formatMoney(cost / _servings)} / serving · ${formatMoney(cost)} total',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$_servings',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        IconButton.filledTonal(
                          onPressed: _servings < 20 ? () => setState(() => _servings++) : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text('Ingredients',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (_gathered.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(_gathered.clear),
                        child: Text('${_gathered.length}/${r.ingredients.length} · Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final (i, ri) in r.ingredients.indexed)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.trailing,
                    value: _gathered.contains(i),
                    onChanged: (on) =>
                        setState(() => on == true ? _gathered.add(i) : _gathered.remove(i)),
                    secondary: IngredientIcon(ri.ingredientId, size: 32),
                    title: Text(
                      formatRecipeAmount(ri, _scale),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: _gathered.contains(i) ? TextDecoration.lineThrough : null,
                        color: _gathered.contains(i) ? theme.colorScheme.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CookModeScreen(recipe: r, servings: _servings))),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Start cooking — step by step with timers'),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Directions',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                for (final (i, phase) in r.phases.indexed) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text('${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimary,
                              )),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(phase.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        if (phase.minutes > 0) ...[
                          const SizedBox(width: 8),
                          Text('${phase.minutes} min', style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  for (final a in phase.actions)
                    Padding(
                      padding: const EdgeInsets.only(left: 36, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: '${a.verb} ',
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              TextSpan(text: renderActionBody(a, _scale)),
                            ]),
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (a.duration != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.timer_outlined,
                                      size: 14, color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(a.duration!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: theme.colorScheme.primary)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        for (final (label, value) in [
                          ('Calories', nutrition.kcal.round().toString()),
                          ('Protein', '${nutrition.protein.round()} g'),
                          ('Carbs', '${nutrition.carbs.round()} g'),
                          ('Fat', '${nutrition.fat.round()} g'),
                        ])
                          Expanded(
                            child: Column(
                              children: [
                                Text(value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800)),
                                Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text('Per serving, estimated from ingredients.',
                      style: theme.textTheme.bodySmall),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    state.freezeExtra(r.id, _servings);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Froze $_servings servings of ${r.title} for a later week'),
                    ));
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
