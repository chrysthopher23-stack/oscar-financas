part of '../financial_page.dart';

final class _TransactionSection extends StatelessWidget {
  const _TransactionSection({
    required this.title,
    required this.emptyText,
    required this.actionLabel,
    required this.transactions,
    required this.formatter,
    required this.valuesHidden,
    required this.onAdd,
    required this.onOpen,
    this.extraServicesMinor = 0,
    this.extraSalesMinor = 0,
  });

  final String title;
  final String emptyText;
  final String actionLabel;
  final List<FinancialTransaction> transactions;
  final int extraServicesMinor;
  final int extraSalesMinor;
  final MoneyFormatter formatter;
  final bool valuesHidden;
  final VoidCallback onAdd;
  final ValueChanged<FinancialTransaction> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(actionLabel),
                    ),
                  ),
                ],
              ),
              if (transactions.isEmpty &&
                  extraServicesMinor == 0 &&
                  extraSalesMinor == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(emptyText),
                )
              else
                for (final transaction in transactions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => onOpen(transaction),
                    title: Text(
                      demoFinancialTitle(
                        context,
                        transaction.id,
                        transaction.title,
                      ),
                      translate: false,
                    ),
                    subtitle: Text(
                      [
                        if (transaction.recurring)
                          uiText(context, 'Recorrente'),
                        if (transaction.installmentLabel != null)
                          installmentProgressText(
                            transaction.installmentLabel!,
                            Localizations.localeOf(context).toLanguageTag(),
                          ),
                      ].join(' · '),
                      translate: false,
                    ),
                    trailing: Text(
                      valuesHidden
                          ? '••••'
                          : formatter.formatMinor(transaction.netAmountMinor),
                    ),
                  ),
              if (extraServicesMinor > 0)
                _ExtraIncomeTotalLine(
                  label: 'Serviços',
                  amountMinor: extraServicesMinor,
                  formatter: formatter,
                  valuesHidden: valuesHidden,
                ),
              if (extraSalesMinor > 0)
                _ExtraIncomeTotalLine(
                  label: 'Vendas',
                  amountMinor: extraSalesMinor,
                  formatter: formatter,
                  valuesHidden: valuesHidden,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ExtraIncomeTotalLine extends StatelessWidget {
  const _ExtraIncomeTotalLine({
    required this.label,
    required this.amountMinor,
    required this.formatter,
    required this.valuesHidden,
  });

  final String label;
  final int amountMinor;
  final MoneyFormatter formatter;
  final bool valuesHidden;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(uiText(context, label)),
    subtitle: Text(uiText(context, 'Ganhos extras')),
    trailing: Text(valuesHidden ? '••••' : formatter.formatMinor(amountMinor)),
  );
}

final class _FinancialFooter extends StatelessWidget {
  const _FinancialFooter({
    required this.state,
    required this.formatter,
    required this.valuesHidden,
  });

  final FinancialScreenState? state;
  final MoneyFormatter formatter;
  final bool valuesHidden;

  @override
  Widget build(BuildContext context) {
    final summary = state?.summary;
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              _FooterValue(
                label: uiText(context, 'Entradas'),
                value: _value(summary?.grossIncomeMinor ?? 0),
              ),
              _FooterValue(
                label: uiText(context, 'Gastos'),
                value: _value(summary?.expenseMinor ?? 0),
              ),
              _FooterValue(
                label: summary != null && summary.deficitMinor > 0
                    ? 'Déficit'
                    : 'Sobra',
                value: _value(
                  summary == null
                      ? 0
                      : (summary.deficitMinor > 0
                            ? summary.deficitMinor
                            : summary.netMinor),
                ),
                accent: summary != null && summary.deficitMinor > 0
                    ? AppColors.ruby
                    : AppColors.emerald,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _value(int value) =>
      valuesHidden ? '••••' : formatter.formatMinor(value);
}

final class _FooterValue extends StatelessWidget {
  const _FooterValue({required this.label, required this.value, this.accent});
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

final class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Não foi possível carregar seus dados.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
