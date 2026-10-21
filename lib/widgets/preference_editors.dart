import 'package:flutter/material.dart';

import '../data/recipe_db.dart';
import '../models/ingredient.dart';
import '../services/diet.dart';
import '../services/plan_generator.dart';
import 'ingredient_icon.dart';

/// Multi-select chips for dietary preferences.
class DietChips extends StatelessWidget {
  final Set<Diet> selected;
  final ValueChanged<Set<Diet>> onChanged;
  const DietChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
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
        ),
        if (selected.any((d) => d.allergenLike))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'For allergies, always check product labels — brands differ.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Picture tiles for common dislikes. Tapping a tile adds (or removes) all of
/// its ingredients from the won't-eat list.
class DislikeGrid extends StatelessWidget {
  final Set<String> excluded;
  final ValueChanged<Set<String>> onChanged;
  const DislikeGrid({super.key, required this.excluded, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = kCommonDislikes.where((d) => d.presentIds.isNotEmpty).toList();
    return LayoutBuilder(builder: (context, box) {
      final perRow = (box.maxWidth / 104).floor().clamp(3, 8);
      final width = (box.maxWidth - (perRow - 1) * 8) / perRow;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final d in tiles)
            SizedBox(
              width: width,
              child: _DislikeTile(
                dislike: d,
                selected: d.isSelected(excluded),
                theme: theme,
                onTap: () {
                  final next = Set<String>.from(excluded);
                  d.isSelected(excluded) ? next.removeAll(d.presentIds) : next.addAll(d.presentIds);
                  onChanged(next);
                },
              ),
            ),
        ],
      );
    });
  }
}

class _DislikeTile extends StatelessWidget {
  final Dislike dislike;
  final bool selected;
  final ThemeData theme;
  final VoidCallback onTap;
  const _DislikeTile(
      {required this.dislike, required this.selected, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? 'Skipping ${dislike.label}' : dislike.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: selected ? 0.55 : 1,
                      child: IngredientIcon(dislike.iconIngredient, size: 40),
                    ),
                    if (selected)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: scheme.error,
                          child: Icon(Icons.close, size: 14, color: scheme.onError),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dislike.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? scheme.onErrorContainer : scheme.onSurface,
                    decoration: selected ? TextDecoration.lineThrough : null,
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

/// Chips for every ingredient the household won't eat, plus a searchable
/// picker with icons grouped by aisle.
class WontEatEditor extends StatelessWidget {
  final Set<String> excluded;
  final ValueChanged<Set<String>> onChanged;
  const WontEatEditor({super.key, required this.excluded, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = excluded.map((id) => kIngredients[id]).whereType<Ingredient>().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final ing in items)
          InputChip(
            avatar: IngredientIcon(ing.id, size: 20),
            label: Text(ing.name),
            onDeleted: () => onChanged(Set.from(excluded)..remove(ing.id)),
          ),
        ActionChip(
          avatar: const Icon(Icons.search, size: 18),
          label: const Text('Find an ingredient'),
          onPressed: () => _pick(context),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IngredientPicker(initial: excluded),
    );
    if (result != null) onChanged(result);
  }
}

class _IngredientPicker extends StatefulWidget {
  final Set<String> initial;
  const _IngredientPicker({required this.initial});

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  late final Set<String> _selection = Set.of(widget.initial);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final byAisle = <Aisle, List<Ingredient>>{};
    for (final ing in kIngredients.values) {
      if (q.isNotEmpty && !ing.name.toLowerCase().contains(q)) continue;
      byAisle.putIfAbsent(ing.aisle, () => []).add(ing);
    }
    final aisles = Aisle.values.where(byAisle.containsKey).toList();
    for (final list in byAisle.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
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
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: aisles.isEmpty
                ? Center(child: Text('No ingredient matches “$_query”'))
                : CustomScrollView(
                    slivers: [
                      for (final aisle in aisles) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(children: [
                              Icon(aisle.icon, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(aisle.label,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(color: theme.colorScheme.primary)),
                            ]),
                          ),
                        ),
                        SliverList.builder(
                          itemCount: byAisle[aisle]!.length,
                          itemBuilder: (_, i) {
                            final ing = byAisle[aisle]![i];
                            return CheckboxListTile(
                              dense: true,
                              value: _selection.contains(ing.id),
                              title: Text(ing.name),
                              secondary: IngredientIcon(ing.id, size: 30),
                              onChanged: (on) => setState(() =>
                                  on == true ? _selection.add(ing.id) : _selection.remove(ing.id)),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selection),
                  child: Text(_selection.isEmpty
                      ? 'Done'
                      : 'Skip ${_selection.length} ingredient${_selection.length == 1 ? '' : 's'}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _gearIcons = <String, IconData>{
  'oven': Icons.microwave_outlined,
  'slow_cooker': Icons.soup_kitchen_outlined,
  'air_fryer': Icons.air,
  'pressure_cooker': Icons.speed,
  'grill': Icons.outdoor_grill_outlined,
};

/// Kitchen gear tiles plus how many nights a week to use the special gear.
class GearPicker extends StatelessWidget {
  final Set<String> owned;
  final int gearNights;
  final ValueChanged<Set<String>> onOwnedChanged;
  final ValueChanged<int> onGearNightsChanged;

  const GearPicker({
    super.key,
    required this.owned,
    required this.gearNights,
    required this.onOwnedChanged,
    required this.onGearNightsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ownsSpecial = owned.any(kSpecialGear.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in kGear.entries)
              FilterChip(
                avatar: Icon(_gearIcons[e.key], size: 18),
                label: Text(e.value),
                selected: owned.contains(e.key),
                onSelected: (on) {
                  final next = Set<String>.from(owned);
                  on ? next.add(e.key) : next.remove(e.key);
                  onOwnedChanged(next);
                },
              ),
          ],
        ),
        if (!owned.contains('oven'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No oven: baked and broiled recipes are left out.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        if (ownsSpecial) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Use my gear', style: theme.textTheme.bodyLarge),
              ),
              Text(
                gearNights == 0
                    ? 'Never'
                    : '$gearNights night${gearNights == 1 ? '' : 's'} a week',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: gearNights.toDouble(),
            min: 0,
            max: 7,
            divisions: 7,
            label: '$gearNights',
            semanticFormatterCallback: (v) => '${v.round()} nights a week',
            onChanged: (v) => onGearNightsChanged(v.round()),
          ),
        ],
      ],
    );
  }
}

/// Weeknight time limit, difficulty and heat preferences.
class CookingPrefs extends StatelessWidget {
  final int? maxMinutes;
  final bool easyOnly;
  final bool mildOnly;
  final ValueChanged<int?> onMaxMinutesChanged;
  final ValueChanged<bool> onEasyOnlyChanged;
  final ValueChanged<bool> onMildOnlyChanged;

  const CookingPrefs({
    super.key,
    required this.maxMinutes,
    required this.easyOnly,
    required this.mildOnly,
    required this.onMaxMinutesChanged,
    required this.onEasyOnlyChanged,
    required this.onMildOnlyChanged,
  });

  static const limits = <int?>[30, 45, 60, null];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time to cook', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int?>(
            showSelectedIcon: false,
            segments: [
              for (final m in limits)
                ButtonSegment(value: m, label: Text(m == null ? 'Any' : '≤ $m min')),
            ],
            selected: {maxMinutes},
            onSelectionChanged: (s) => onMaxMinutesChanged(s.first),
          ),
        ),
        if (maxMinutes != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Slow-cooker meals still count — they cook while you’re out.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Easy recipes only'),
          value: easyOnly,
          onChanged: onEasyOnlyChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Keep it mild'),
          subtitle: const Text('Skip dishes with chiles, hot sauce or other heat.'),
          value: mildOnly,
          onChanged: onMildOnlyChanged,
        ),
      ],
    );
  }
}
