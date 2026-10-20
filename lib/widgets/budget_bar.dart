import 'package:flutter/material.dart';

import 'money_text.dart';

/// Shows the estimated grocery total against the weekly budget, with a progress
/// bar that turns amber/red as it approaches or exceeds the budget.
class BudgetBar extends StatelessWidget {
  final double total;
  final double budget;
  final String label;

  const BudgetBar({
    super.key,
    required this.total,
    required this.budget,
    this.label = 'Estimated total',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = budget > 0 ? (total / budget) : 0.0;
    final over = total > budget && budget > 0;
    final color = over
        ? scheme.error
        : ratio > 0.85
            ? Colors.amber.shade700
            : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            MoneyText(
              total,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            minHeight: 10,
            backgroundColor: scheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          budget <= 0
              ? 'No budget set'
              : over
                  ? 'Over budget by ${formatMoney(total - budget)}'
                  : '${formatMoney(budget - total)} under your ${formatMoney(budget)} budget',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
