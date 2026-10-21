import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipe_db.dart';
import '../models/plan.dart';
import '../models/recipe.dart';
import '../services/grocery_builder.dart';
import '../state/app_state.dart';
import '../widgets/money_text.dart';
import '../widgets/recipe_image.dart';
import '../widgets/slot_picker.dart';
import 'recipe_detail_screen.dart';

enum _Show { all, fresh, favorites, had, disliked }

/// Searchable recipe library. With [slot] set, picking a recipe puts it on
/// that night of the plan ("Choose a meal"). [dislikedOnly] opens it on the
/// recipes the user thumbed down.
class BrowseScreen extends StatefulWidget {
  final int? slot;
  final bool weekTwo;
  final bool dislikedOnly;
  const BrowseScreen({super.key, this.slot, this.weekTwo = false, this.dislikedOnly = false});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  String _query = '';
  late _Show _show = widget.dislikedOnly ? _Show.disliked : _Show.all;
  String? _cuisine;
  int? _maxMinutes;
  late bool _fitsSettings = !widget.dislikedOnly;

  List<Recipe> _filter(AppState state) {
    final base = _fitsSettings && _show != _Show.disliked
        ? state.allowedRecipeList
        : kRecipes;
    final q = _query.trim().toLowerCase();
    final out = base.where((r) {
      if (_cuisine != null && r.cuisine != _cuisine) return false;
      if (_maxMinutes != null && r.totalMinutes > _maxMinutes!) return false;
      switch (_show) {
        case _Show.fresh:
          if (state.lastPlanned(r.id) != null) return false;
        case _Show.favorites:
          if (!state.isFavorite(r.id)) return false;
        case _Show.had:
          if (state.lastPlanned(r.id) == null) return false;
        case _Show.disliked:
          if (!state.isDisliked(r.id)) return false;
        case _Show.all:
          break;
      }
      if (q.isEmpty) return true;
      final anchorName = kIngredients[r.anchor]?.naturalName ?? r.anchor;
      return r.title.toLowerCase().contains(q) ||
          r.cuisine.toLowerCase().contains(q) ||
          anchorName.contains(q);
    }).toList();
    if (_show == _Show.had) {
      out.sort((a, b) => state.lastPlanned(b.id)!.compareTo(state.lastPlanned(a.id)!));
    } else {
      out.sort((a, b) => a.title.compareTo(b.title));
    }
    return out;
  }

  Future<void> _open(AppState state, Recipe r) async {
    final slot = widget.slot;
    final servings = state.settings.householdSize;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => RecipeDetailScreen(
        recipe: r,
        initialServings: servings,
        chooseLabel: slot == null ? null : 'Cook this on ${slotLabel(state, slot)}',
        onChoose: slot == null
            ? null
            : () async {
                await state.chooseMeal(slot, r.id, weekTwo: widget.weekTwo);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) Navigator.of(context).pop();
              },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final results = _filter(state);
    final cuisines = kRecipes.map((r) => r.cuisine).toSet().toList()..sort();
    final pricing = state.pricing;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.slot == null
            ? 'Recipes'
            : 'Choose ${slotLabel(state, widget.slot!)}’s dinner'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search recipes, cuisines, ingredients',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (s, label) in [
                  (_Show.all, 'All'),
                  (_Show.fresh, 'New to you'),
                  (_Show.favorites, 'Loved'),
                  (_Show.had, 'Had before'),
                  if (state.disliked.isNotEmpty || _show == _Show.disliked)
                    (_Show.disliked, 'Thumbs down'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _show == s,
                      onSelected: (_) => setState(() => _show = s),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text('Fits my settings'),
                    selected: _fitsSettings,
                    onSelected: (v) => setState(() => _fitsSettings = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _cuisine,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Cuisine', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any')),
                      for (final c in cuisines) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _cuisine = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _maxMinutes,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Time', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Any')),
                      DropdownMenuItem(value: 30, child: Text('≤ 30 min')),
                      DropdownMenuItem(value: 45, child: Text('≤ 45 min')),
                      DropdownMenuItem(value: 60, child: Text('≤ 1 hour')),
                    ],
                    onChanged: (v) => setState(() => _maxMinutes = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                Text('${results.length} recipes', style: theme.textTheme.bodySmall),
                const Spacer(),
                Text('${state.newRecipeCount} new to you', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('No recipes match.'))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final r = results[i];
                      final last = state.lastPlanned(r.id);
                      final perServing = estimateMealCost(
                              PlannedMeal(slot: 0, recipeId: r.id, servings: r.baseServings),
                              pricing) /
                          r.baseServings;
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: RecipeImage(recipe: r, height: 56, compact: true),
                          ),
                        ),
                        title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${r.cuisine} · ${r.totalMinutes} min · ${r.difficulty} · '
                          '${formatMoney(perServing)}/serving',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (state.isFavorite(r.id))
                              Icon(Icons.thumb_up, size: 16, color: theme.colorScheme.primary),
                            if (state.isDisliked(r.id))
                              Icon(Icons.thumb_down, size: 16, color: theme.colorScheme.error),
                            _Badge(last: last),
                          ],
                        ),
                        onTap: () => _open(state, r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String? last;
  const _Badge({required this.last});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (last == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('New',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer)),
      );
    }
    return Text('Had ${weekLabel(last!)}', style: theme.textTheme.bodySmall);
  }
}
