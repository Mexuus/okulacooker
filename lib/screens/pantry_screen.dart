import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipe_db.dart';
import '../models/ingredient.dart';
import '../state/app_state.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final theme = Theme.of(context);
        final q = _query.trim().toLowerCase();
        final owned = state.pantry.ownedStapleIds;
        final byAisle = <Aisle, List<Ingredient>>{};
        for (final ing in kIngredients.values.where((i) => i.staple)) {
          if (q.isNotEmpty && !ing.name.toLowerCase().contains(q)) continue;
          byAisle.putIfAbsent(ing.aisle, () => []).add(ing);
        }
        final aisles = byAisle.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
        final freezer = state.freezer;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pantry'),
            actions: [
              if (owned.isNotEmpty)
                TextButton(onPressed: state.clearPantry, child: const Text('Clear')),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Tick the staples you already keep in the cupboard. They come off '
                'your bill this week and every week after.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search staples',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    for (final aisle in aisles)
                      ExpansionTile(
                        key: PageStorageKey('aisle-${aisle.name}-$q'),
                        initiallyExpanded: q.isNotEmpty,
                        leading: Icon(aisle.icon),
                        title: Text(aisle.label),
                        subtitle: Text(
                            '${byAisle[aisle]!.where((i) => owned.contains(i.id)).length} of '
                            '${byAisle[aisle]!.length} in your pantry'),
                        children: [
                          for (final ing in byAisle[aisle]!..sort((a, b) => a.name.compareTo(b.name)))
                            CheckboxListTile(
                              dense: true,
                              value: owned.contains(ing.id),
                              onChanged: (_) => state.togglePantryStaple(ing.id),
                              title: Text(ing.name),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.ac_unit),
                  const SizedBox(width: 8),
                  Text('Freezer',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Extras you froze. Mark a dinner as “from freezer” on the Plan '
                'tab to use these instead of re-buying.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (freezer.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.kitchen_outlined),
                    title: Text('Nothing frozen yet'),
                    subtitle: Text('Open a recipe and tap “Freeze extra servings”.'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final f in freezer)
                        ListTile(
                          leading: Text(recipeById(f.recipeId).emoji,
                              style: const TextStyle(fontSize: 24)),
                          title: Text(recipeById(f.recipeId).title),
                          subtitle: Text('${f.servings} servings • frozen ${f.frozenOn}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => state.removeFreezerItem(f.id),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
