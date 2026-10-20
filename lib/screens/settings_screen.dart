import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/regions.dart';
import '../models/settings.dart';
import '../services/price_book.dart';
import '../services/store_locator.dart';
import '../state/app_state.dart';
import '../widgets/diet_editor.dart';
import '../widgets/location_store_picker.dart';
import '../widgets/money_text.dart';

const _weekdayNames = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final s = state.settings;
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _section(context, 'Store & region'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LocationStorePicker(
                    zip: s.zip,
                    storeId: s.storeId,
                    storeLocation: s.storeLocation,
                    onZipChanged: (v) {
                      if (isValidZip(v)) {
                        state.updateSettings(state.settings.copyWith(zip: v));
                      }
                    },
                    onStoreChanged: (id, loc) => state.selectStore(id, location: loc),
                  ),
                ),
              ),
              _section(context, 'Household'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Feeding'),
                      trailing: _MiniStepper(
                        value: s.householdSize,
                        min: 1,
                        max: 12,
                        onChanged: (v) =>
                            state.updateSettings(s.copyWith(householdSize: v)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Nights you cook'),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _weekdayNames.entries.map((e) {
                              final sel = s.cookNights.contains(e.key);
                              return FilterChip(
                                label: Text(e.value),
                                selected: sel,
                                onSelected: (on) {
                                  final nights =
                                      List<int>.from(s.cookNights);
                                  if (on) {
                                    nights.add(e.key);
                                  } else {
                                    nights.remove(e.key);
                                  }
                                  if (nights.isEmpty) return;
                                  nights.sort();
                                  state.updateSettings(
                                      s.copyWith(cookNights: nights));
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: const Text('Shopping day'),
                      trailing: DropdownButton<int>(
                        value: s.shoppingDay,
                        underline: const SizedBox.shrink(),
                        items: _weekdayNames.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            state.updateSettings(s.copyWith(shoppingDay: v));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _section(context, 'Budget & planning'),
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          const Text('Weekly budget'),
                          const Spacer(),
                          MoneyText(s.weeklyBudget,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Slider(
                      value: s.weeklyBudget.clamp(40, 400),
                      min: 40,
                      max: 400,
                      divisions: 36,
                      label: s.weeklyBudget.round().toString(),
                      onChanged: (v) =>
                          state.updateSettings(s.copyWith(weeklyBudget: v)),
                    ),
                    SwitchListTile(
                      title: const Text('Shop two weeks at once'),
                      subtitle: const Text(
                          'Fresh items for week two are separated as “buy later”.'),
                      value: s.twoWeekMode,
                      onChanged: (v) =>
                          state.updateSettings(s.copyWith(twoWeekMode: v)),
                    ),
                  ],
                ),
              ),
              _section(context, 'Diet & won’t eat'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DietChips(
                        selected: s.diets,
                        onChanged: (d) =>
                            state.updateSettings(s.copyWith(diets: d)),
                      ),
                      const SizedBox(height: 16),
                      Text('Won’t eat', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      WontEatEditor(
                        excluded: s.excludedIngredients,
                        onChanged: (e) => state.updateSettings(
                            s.copyWith(excludedIngredients: e)),
                      ),
                      const SizedBox(height: 12),
                      Builder(builder: (context) {
                        final n = state.allowedRecipeList.length;
                        return Text(
                          n == 0
                              ? 'No recipes match these settings — loosen them to get a plan.'
                              : '$n recipes match your settings.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: n == 0 ? theme.colorScheme.error : null),
                        );
                      }),
                      const SizedBox(height: 4),
                      Text(
                        'A planning convenience, not an allergen control. Always check ingredients.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              _section(context, 'Appearance'),
              Card(
                child: Column(
                  children: AppTheme.values
                      .map((t) => RadioListTile<AppTheme>(
                            value: t,
                            // ignore: deprecated_member_use
                            groupValue: s.theme,
                            title: Text(t.label),
                            // ignore: deprecated_member_use
                            onChanged: (v) {
                              if (v != null) state.setTheme(v);
                            },
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => state.generatePlan(),
                icon: const Icon(Icons.refresh),
                label: const Text('Generate a fresh week'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _confirmReset(context, state),
                icon: Icon(Icons.restart_alt,
                    color: theme.colorScheme.error),
                label: Text('Reset app',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
              const SizedBox(height: 16),
              _section(context, 'Location & data'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '• “Locate” uses your device’s location once to find your ZIP. '
                    'The lookup runs on-device against bundled U.S. Census ZIP data; '
                    'your coordinates are never stored.\n'
                    '• Nearby stores come from a store directory built into the app '
                    '(~24,000 US locations), so it works offline. Only if none are '
                    'found does it ask OpenStreetMap (free, no account), sending just '
                    'your ZIP’s center point — never your exact location.\n'
                    '• Prices: BLS Average Price Data (${PriceBook.instance.asOfLabel}) for '
                    '${PriceBook.instance.blsItemCount} staple items by region, USDA ERS '
                    'metro-area food prices for 10 large metros, and TapCook estimates for '
                    'everything else and for each chain’s price level. Picking a specific '
                    'store prices your list for that store’s area. Estimates, not live '
                    'shelf prices.\n'
                    '• Your plan, pantry, and settings stay on this device. No account '
                    'or subscription.\n\n'
                    'Store locations: All The Places (CC0) and '
                    '${StoreLocator.attribution} (ODbL).',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TapCook is not affiliated with, endorsed by, or connected to any '
                'grocery store. Prices are estimates from a national reference, '
                'adjusted for the chain and region — not live retail prices. '
                'Dietary settings are a convenience, not allergen control.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      );

  void _confirmReset(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset app?'),
        content: const Text(
            'This clears your plan, pantry, freezer, history, and settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              state.resetAll();
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _MiniStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
