import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/regions.dart';
import '../models/settings.dart';
import '../models/store_location.dart';
import '../services/diet.dart';
import '../state/app_state.dart';
import '../widgets/location_store_picker.dart';
import '../widgets/money_text.dart';
import '../widgets/preference_editors.dart';

const _weekdayNames = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

/// First-run setup: ZIP + store, household, cook nights, and budget.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _zip = '';
  String _storeId = 'kroger';
  StoreLocationRef? _storeLocation;
  int _household = 4;
  final Set<int> _nights = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };
  double _budget = 100;
  Set<Diet> _diets = {};
  Set<String> _excluded = {};
  Set<String> _equipment = {'oven'};
  int _gearNights = 2;
  int? _maxMinutes = 60;
  bool _easyOnly = false;
  bool _mildOnly = false;
  bool _stockBasics = true;
  bool _zipTouched = false;

  bool get _zipOk => isValidZip(_zip);

  void _finish() {
    setState(() => _zipTouched = true);
    if (!_zipOk || _nights.isEmpty) return;
    final settings = UserSettings(
      zip: _zip.trim(),
      storeId: _storeId,
      storeLocation: _storeLocation?.storeId == _storeId ? _storeLocation : null,
      householdSize: _household,
      cookNights: _nights.toList()..sort(),
      weeklyBudget: _budget,
      diets: _diets,
      excludedIngredients: _excluded,
      equipment: _equipment,
      gearNights: _gearNights,
      maxMinutes: _maxMinutes,
      easyOnly: _easyOnly,
      mildOnly: _mildOnly,
    );
    context.read<AppState>().completeOnboarding(settings, stockBasics: _stockBasics);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Text('TapCook',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Plan the week’s dinners and know the grocery total before you leave the house.',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Step 1 — ZIP + store
            _StepCard(
              step: 1,
              title: 'Where do you shop?',
              child: LocationStorePicker(
                zip: _zip,
                storeId: _storeId,
                storeLocation: _storeLocation,
                showZipError: _zipTouched,
                autoSelectNearest: true,
                onZipChanged: (v) => setState(() => _zip = v),
                onStoreChanged: (id, loc) => setState(() {
                  _storeId = id;
                  _storeLocation = loc;
                }),
              ),
            ),

            // Step 2 — household + nights
            _StepCard(
              step: 2,
              title: 'Who and when?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Feeding', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      _Stepper(
                        value: _household,
                        min: 1,
                        max: 12,
                        onChanged: (v) => setState(() => _household = v),
                        suffix: 'people',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Nights you cook', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _weekdayNames.entries.map((e) {
                      final sel = _nights.contains(e.key);
                      return FilterChip(
                        label: Text(e.value),
                        selected: sel,
                        onSelected: (s) => setState(() {
                          if (s) {
                            _nights.add(e.key);
                          } else {
                            _nights.remove(e.key);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  if (_nights.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Pick at least one night',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                ],
              ),
            ),

            // Step 3 — what you eat
            _StepCard(
              step: 3,
              title: 'What do you eat?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Diet (optional)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DietChips(
                    selected: _diets,
                    onChanged: (d) => setState(() => _diets = d),
                  ),
                  const SizedBox(height: 16),
                  Text('Tap anything you won’t eat', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DislikeGrid(
                    excluded: _excluded,
                    onChanged: (e) => setState(() => _excluded = e),
                  ),
                  const SizedBox(height: 12),
                  WontEatEditor(
                    excluded: _excluded,
                    onChanged: (e) => setState(() => _excluded = e),
                  ),
                ],
              ),
            ),

            // Step 4 — kitchen
            _StepCard(
              step: 4,
              title: 'Your kitchen',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gear you have', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  GearPicker(
                    owned: _equipment,
                    gearNights: _gearNights,
                    onOwnedChanged: (g) => setState(() => _equipment = g),
                    onGearNightsChanged: (n) => setState(() => _gearNights = n),
                  ),
                  const SizedBox(height: 12),
                  CookingPrefs(
                    maxMinutes: _maxMinutes,
                    easyOnly: _easyOnly,
                    mildOnly: _mildOnly,
                    onMaxMinutesChanged: (m) => setState(() => _maxMinutes = m),
                    onEasyOnlyChanged: (v) => setState(() => _easyOnly = v),
                    onMildOnlyChanged: (v) => setState(() => _mildOnly = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I have the basics'),
                    subtitle: const Text(
                        'Salt, pepper, oils, sugar, flour, common spices — left off your bill.'),
                    value: _stockBasics,
                    onChanged: (v) => setState(() => _stockBasics = v),
                  ),
                ],
              ),
            ),

            // Step 5 — budget
            _StepCard(
              step: 5,
              title: 'Weekly budget',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Target for groceries',
                          style: theme.textTheme.titleMedium),
                      MoneyText(
                        _budget,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Slider(
                    value: _budget,
                    min: 40,
                    max: 400,
                    divisions: 36,
                    label: _budget.round().toString(),
                    onChanged: (v) => setState(() => _budget = v),
                  ),
                  Text('TapCook keeps the plan under this when it can.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),

            const SizedBox(height: 8),
            FilledButton(
              onPressed: _finish,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Build my week'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final Widget child;
  const _StepCard(
      {required this.step, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text('$step',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      )),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? suffix;
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            suffix == null ? '$value' : '$value $suffix',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.filledTonal(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
