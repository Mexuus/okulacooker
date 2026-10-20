import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

final _currency = NumberFormat.simpleCurrency(locale: 'en_US');

String formatMoney(double value) => _currency.format(value);

/// Displays a USD amount with consistent formatting.
class MoneyText extends StatelessWidget {
  final double value;
  final TextStyle? style;

  const MoneyText(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) =>
      Text(formatMoney(value), style: style);
}
