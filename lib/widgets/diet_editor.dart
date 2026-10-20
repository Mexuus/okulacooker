import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../models/ingredient.dart';
import '../services/diet.dart';

/// Multi-select chips for dietary preferences.
class DietChips extends StatelessWidget {
  final Set<Diet> selected;
  final ValueChanged<Set<Diet>> onChanged;
  const DietChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: Diet.values.map((d) {
        return FilterChip(
          label: Text(d.label),
          selected: selected.contains(d),
          onSelected: (on) {
            final next = Set<Diet>.from(selected);
            on ? next.add(d) : next.remove(d);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

/// Chips for ingredients the household won't eat, with a searchable picker.
class WontEatEditor extends StatelessWidget {
  final Set<String> excluded;
  final ValueChanged<Set<String>> onChanged;
  const WontEatEditor(
      {super.key, required this.excluded, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = excluded
        .map((id) => kIngredients[id])
        .whereType<Ingredient>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final ing in items)
          InputChip(
            label: Text(ing.name),
            onDeleted: () => onChanged(Set.from(excluded)..remove(ing.id)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Add ingredient'),
          onPressed: () => _pick(context),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final selection = Set<String>.from(excluded);
    final all = kIngredients.values.where((i) => !i.staple).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    var query = '';

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = all
              .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search ingredients',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setSheet(() => query = v),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final ing in filtered)
                        CheckboxListTile(
                          dense: true,
                          value: selection.contains(ing.id),
                          title: Text(ing.name),
                          secondary: Icon(ing.aisle.icon, size: 20),
                          onChanged: (on) => setSheet(() {
                            on == true
                                ? selection.add(ing.id)
                                : selection.remove(ing.id);
                          }),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selection),
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result != null) onChanged(result);
  }
}
