import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../services/format.dart';
import '../services/price_book.dart';
import '../services/pricing.dart';
import 'money_text.dart';

String _pct(double factor) {
  final p = ((factor - 1) * 100).round();
  return p == 0 ? 'no change' : '${p > 0 ? '+' : '−'}${p.abs()}%';
}

/// Bottom sheet explaining how one item's local price was calculated, and
/// (with [line]) which packs this week's list buys.
Future<void> showPriceBreakdown(BuildContext context, PriceQuote q, {GroceryLine? line}) {
  final theme = Theme.of(context);
  final ing = q.ingredient;
  final pack = ing.packs.firstWhere((p) => p.price == ing.packPrice, orElse: () => ing.packs.first);
  final packName = describePack(pack);

  Widget row(String label, String value, {String? hint, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: bold
                          ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)
                          : theme.textTheme.bodyMedium),
                  if (hint != null) Text(hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(value,
                style: (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                    ?.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ing.name,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text('at ${q.store.name}', style: theme.textTheme.bodyMedium),
            const Divider(height: 24),
            row('National price', '${formatMoney(pack.price)} / $packName',
                hint: 'TapCook reference price'),
            row(
              '${q.region.name} region',
              _pct(q.regionRatio),
              hint: q.item.isBls
                  ? 'BLS regional average prices (${PriceBook.instance.asOfLabel})'
                  : 'USDA regional food prices',
            ),
            if (q.metro != null)
              row('${q.metro!.name} metro', _pct(q.metroFactor),
                  hint: 'USDA ERS metro-area food prices'),
            row('${q.store.name} pricing', _pct(q.chainFactor),
                hint: 'TapCook estimate of the chain’s price level'),
            const Divider(height: 24),
            row('Local price', '${formatMoney(q.localPrice(pack))} / $packName', bold: true),
            if (line != null) ...[
              const SizedBox(height: 8),
              row('This week’s recipes need', describeGrams(ing, line.grams)),
              for (final p in line.buy)
                row(
                  'Buy ${p.count} × ${describePack(p.pack)}'
                      '${p.pack.label.isEmpty ? '' : ' (${p.pack.label})'}',
                  formatMoney(p.count * q.localPrice(p.pack)),
                ),
              if (line.ownedStaple)
                row('Already in your pantry', '−${formatMoney(line.estCost)}'),
              row('On your bill', formatMoney(line.ownedStaple ? 0 : line.estCost), bold: true),
            ],
            const SizedBox(height: 8),
            Text(
              'An estimate, not a live shelf price. Actual prices vary by branch and week.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
