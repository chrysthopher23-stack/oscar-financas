import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../shared/formatting/money_formatter.dart';
import '../../application/home_investment_totals.dart';

final class InvestmentBreakdown extends StatelessWidget {
  const InvestmentBreakdown({
    super.key,
    required this.totals,
    required this.formatter,
    required this.locale,
    required this.valuesHidden,
  });

  final HomeInvestmentTotals totals;
  final MoneyFormatter formatter;
  final String locale;
  final bool valuesHidden;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final percent = NumberFormat.percentPattern(locale)
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _CategoryDetails(
            title: strings.text('Ativos'),
            count: totals.assetsCount,
            singularCountKey: '{count} ativo',
            pluralCountKey: '{count} ativos',
            valueMinor: totals.assetsValueMinor,
            changeBasisPoints: totals.assetsMonthlyChangeBasisPoints,
            period: strings.text('investment.period.month'),
            formatter: formatter,
            percentFormatter: percent,
            valuesHidden: valuesHidden,
          ),
        ),
        Container(
          width: 1,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 9),
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(
          child: _CategoryDetails(
            title: strings.text('Criptoativos'),
            count: totals.cryptoCount,
            singularCountKey: '{count} criptoativo',
            pluralCountKey: '{count} criptoativos',
            valueMinor: totals.cryptoValueMinor,
            changeBasisPoints: totals.cryptoDailyChangeBasisPoints,
            period: strings.text('24h'),
            formatter: formatter,
            percentFormatter: percent,
            valuesHidden: valuesHidden,
          ),
        ),
      ],
    );
  }
}

final class _CategoryDetails extends StatelessWidget {
  const _CategoryDetails({
    required this.title,
    required this.count,
    required this.singularCountKey,
    required this.pluralCountKey,
    required this.valueMinor,
    required this.changeBasisPoints,
    required this.period,
    required this.formatter,
    required this.percentFormatter,
    required this.valuesHidden,
  });

  final String title;
  final int count;
  final String singularCountKey;
  final String pluralCountKey;
  final int valueMinor;
  final int? changeBasisPoints;
  final String period;
  final MoneyFormatter formatter;
  final NumberFormat percentFormatter;
  final bool valuesHidden;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final countLabel = strings.text(
      count == 1 ? singularCountKey : pluralCountKey,
      {'count': '$count'},
    );
    final change = changeBasisPoints;
    final changeColor = change == null || change == 0
        ? theme.colorScheme.onSurfaceVariant
        : change > 0
        ? AppColors.emerald
        : AppColors.ruby;
    final changeIcon = change == null
        ? null
        : change > 0
        ? Icons.trending_up_rounded
        : change < 0
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final changeLabel = valuesHidden
        ? '••••'
        : change == null
        ? strings.text('Variação indisponível')
        : '${percentFormatter.format(change.abs() / 10000)} · $period';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          valuesHidden ? '••••' : formatter.formatMinor(valueMinor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          countLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          children: [
            if (changeIcon != null && !valuesHidden) ...[
              Icon(changeIcon, size: 14, color: changeColor),
              const SizedBox(width: 2),
            ],
            Expanded(
              child: Text(
                changeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: valuesHidden
                      ? theme.colorScheme.onSurfaceVariant
                      : changeColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
