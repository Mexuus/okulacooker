import 'package:flutter/material.dart';

import '../services/format.dart';
import '../services/price_book.dart';
import '../services/pricing.dart';
import 'money_text.dart';

String _unitName(String unit) => unit == 'each' ? 'item' : unit;

String _pct(double factor) {
  final p = ((factor - 1) * 100).round();
  return p == 0 ? 'no change' : '${p > 0 ? '+' : '−'}${p.abs()}%';
}

/// Bottom sheet explaining how one item's local price was calculated.
Future<void> showPriceBreakdown(BuildContext context, PriceQuote q) {
  final theme = Theme.of(context);
  final unit = _unitName(q.ingredient.unit);
  final book = PriceBook.instance;
  final national = q.item.isBls
      ? 'National average (BLS, ${book.asOfLabel})'
      : 'National estimate (TapCook)';

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
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.ingredient.name,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text('${formatAmount(q.ingredient, q.qty)} at ${q.store.name}',
                style: theme.textTheme.bodyMedium),
            const Divider(height: 24),
            row(national, '${formatMoney(q.nationalUnit)} / $unit', hint: q.item.note),
            row(
              '${q.region.name} region',
              '${formatMoney(q.regionalUnit)} / $unit',
              hint: q.item.isBls
                  ? 'BLS regional average price'
                  : 'Adjusted with USDA regional food prices',
            ),
            if (q.metro != null)
              row('${q.metro!.name} metro', _pct(q.metroFactor),
                  hint: 'USDA ERS metro-area food prices'),
            row('${q.store.name} pricing', _pct(q.chainFactor),
                hint: 'TapCook estimate of the chain’s price level'),
            const Divider(height: 24),
            row('Local price', '${formatMoney(q.unitPrice)} / $unit'),
            row('You need ${formatAmount(q.ingredient, q.qty)}', '', bold: false),
            row('Estimated cost', formatMoney(q.total), bold: true),
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
