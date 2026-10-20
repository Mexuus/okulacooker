import 'package:flutter/material.dart';

import '../services/store_locator.dart';
import '../state/app_state.dart';
import 'money_text.dart';

/// Bottom sheet comparing this week's grocery total at nearby stores.
Future<void> showStoreComparison(BuildContext context, AppState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.7,
      child: _StoreComparison(state: state),
    ),
  );
}

class _StoreComparison extends StatefulWidget {
  final AppState state;
  const _StoreComparison({required this.state});

  @override
  State<_StoreComparison> createState() => _StoreComparisonState();
}

class _StoreComparisonState extends State<_StoreComparison> {
  late final Future<List<(NearbyStore, double)>> _future =
      widget.state.compareNearbyStores();

  bool _isCurrent(NearbyStore n) {
    final s = widget.state.settings;
    if (n.store.id != s.storeId) return false;
    final loc = s.storeLocation;
    return loc == null || (loc.lat == n.lat && loc.lng == n.lng);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.state.groceryList;
    final currentTotal = current == null ? null : current.total + current.laterTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text('Compare nearby stores',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('This week’s list priced at each store’s location.',
              style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: FutureBuilder<List<(NearbyStore, double)>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return const Center(child: Text('No supported stores found nearby.'));
              }
              final cheapest = rows.first.$2;
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final (n, total) = rows[i];
                  final current = _isCurrent(n);
                  final diff = currentTotal == null ? null : total - currentTotal;
                  return ListTile(
                    leading: Icon(
                      current ? Icons.check_circle : Icons.storefront_outlined,
                      color: current ? theme.colorScheme.primary : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(n.displayName, overflow: TextOverflow.ellipsis)),
                        if (total == cheapest) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Cheapest',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade900)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      [
                        '${n.distanceMi.toStringAsFixed(1)} mi',
                        if (n.address != null) n.address!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(total,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        if (diff != null && !current && diff.abs() >= 0.01)
                          Text(
                            '${diff < 0 ? '−' : '+'}${formatMoney(diff.abs())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: diff < 0 ? Colors.green.shade700 : Colors.deepOrange.shade700,
                            ),
                          ),
                      ],
                    ),
                    onTap: current
                        ? null
                        : () {
                            widget.state.selectStore(n.store.id, location: n.toRef());
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Now pricing at ${n.displayName}'),
                            ));
                          },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
