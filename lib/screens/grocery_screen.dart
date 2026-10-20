import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery.dart';
import '../models/ingredient.dart';
import '../services/format.dart';
import '../services/price_book.dart';
import '../state/app_state.dart';
import '../widgets/budget_bar.dart';
import '../widgets/money_text.dart';
import '../widgets/price_breakdown.dart';
import '../widgets/store_compare_sheet.dart';

class GroceryScreen extends StatelessWidget {
  const GroceryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final grocery = state.groceryList;
        final theme = Theme.of(context);
        final pricing = state.pricing;
        final store = pricing.store;
        final loc = state.settings.storeLocation;
        final storeName = loc != null && loc.storeId == store.id ? loc.label : store.name;

        return Scaffold(
          appBar: AppBar(title: const Text('Grocery list')),
          body: grocery == null
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
                            BudgetBar(
                              total: grocery.total,
                              budget: state.settings.weeklyBudget,
                              label: 'Total at $storeName',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${pricing.location.label} · ${pricing.areaName} prices',
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (grocery.savedByPantry > 0) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.savings_outlined, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pantry savings: ${formatMoney(grocery.savedByPantry)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => showStoreComparison(context, state),
                                icon: const Icon(Icons.compare_arrows),
                                label: const Text('Compare nearby stores'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        PriceBook.instance.hasLiveData
                            ? 'Local estimates from BLS average prices (${PriceBook.instance.asOfLabel}), '
                                'adjusted for your store’s area and chain. Tap an item to see how. '
                                'Checkout totals will differ.'
                            : 'Estimates, not live prices. Checkout totals will differ.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildAisleSections(context, state, grocery.lines),
                    if (grocery.laterLines.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Buy next week (fresh)',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          MoneyText(grocery.laterTotal,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._buildAisleSections(
                          context, state, grocery.laterLines),
                    ],
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _buildAisleSections(
      BuildContext context, AppState state, List<GroceryLine> lines) {
    final theme = Theme.of(context);
    final grouped = <Aisle, List<GroceryLine>>{};
    for (final l in lines) {
      grouped.putIfAbsent(l.ingredient.aisle, () => []).add(l);
    }
    final widgets = <Widget>[];
    final aisles = grouped.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final aisle in aisles) {
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Row(
          children: [
            Icon(aisle.icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(aisle.label,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ));
      widgets.add(Card(
        child: Column(
          children: [
            for (final line in grouped[aisle]!)
              _GroceryTile(line: line, state: state),
          ],
        ),
      ));
    }
    return widgets;
  }
}

class _GroceryTile extends StatelessWidget {
  final GroceryLine line;
  final AppState state;
  const _GroceryTile({required this.line, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ing = line.ingredient;
    final owned = line.ownedStaple;
    final struck = owned
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    return ListTile(
      dense: true,
      leading: ing.staple
          ? Checkbox(
              value: owned,
              onChanged: (_) => state.togglePantryStaple(ing.id),
            )
          : const SizedBox(width: 24),
      title: Text(ing.name, style: struck),
      subtitle: Text(formatAmount(ing, line.qty), style: struck),
      onTap: () => showPriceBreakdown(context, state.pricing.quote(ing, line.qty)),
      trailing: owned
          ? Text('have it',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary))
          : MoneyText(line.estCost,
              style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
