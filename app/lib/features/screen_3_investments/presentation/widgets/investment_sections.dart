part of '../investments_page.dart';

final class _AreaSelector extends StatelessWidget {
  const _AreaSelector({required this.viewModel});
  final InvestmentsViewModel viewModel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 6.0;
      final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
      const areas = {
        InvestmentArea.fixedIncome: 'Renda Fixa',
        InvestmentArea.realEstate: 'Imobiliários',
        InvestmentArea.equitiesEtfs: 'Ações e ETFs',
        InvestmentArea.crypto: 'Criptoativos',
      };
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final entry in areas.entries) ...[
            SizedBox(
              width: itemWidth,
              child: ChoiceChip(
                showCheckmark: false,
                label: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(entry.value),
                  ),
                ),
                selected: viewModel.state.area == entry.key,
                onSelected: (_) => viewModel.selectArea(entry.key),
              ),
            ),
          ],
        ],
      );
    },
  );
}

final class _PositionsList extends StatelessWidget {
  const _PositionsList({
    required this.positions,
    required this.formatter,
    required this.valuesHidden,
    required this.onOpen,
    required this.onAdd,
  });
  final List<InvestmentHolding> positions;
  final MoneyFormatter formatter;
  final bool valuesHidden;
  final ValueChanged<InvestmentHolding> onOpen;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (positions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('Nenhuma posição nesta área e mês.'),
            ),
          ...positions.map(
            (position) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: material.Text(
                '${position.identity.symbol} · ${position.identity.officialName}',
              ),
              subtitle: Text(
                '${position.identity.currency.isoCode} · ${uiText(context, position.identity.family.label)}',
                translate: false,
              ),
              trailing: Text(
                valuesHidden
                    ? '••••'
                    : formatter.formatMinor(position.currentValueMinor),
              ),
              onTap: () => onOpen(position),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar manualmente'),
          ),
        ],
      ),
    ),
  );
}

final class _InflationCard extends StatelessWidget {
  const _InflationCard({
    required this.nominal,
    required this.effect,
    required this.real,
    required this.formatter,
    required this.valuesHidden,
  });
  final int nominal;
  final int effect;
  final int real;
  final MoneyFormatter formatter;
  final bool valuesHidden;
  String value(int minor) =>
      valuesHidden ? '••••' : formatter.formatMinor(minor);
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crescimento acima da inflação',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('Rendeu no mês: ${value(nominal)}'),
          Text('Efeito estimado da inflação: −${value(effect.abs())}'),
          Text(
            'Crescimento real estimado: ${real >= 0 ? '+' : '−'}${value(real.abs())}',
            style: TextStyle(
              color: real > 0
                  ? AppColors.emerald
                  : real < 0
                  ? const Color(0xFFB74747)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Estimativa baseada em uma cesta média; não representa sua inflação pessoal.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

final class _CurrencyFooter extends StatelessWidget {
  const _CurrencyFooter({
    required this.viewModel,
    required this.baseCurrency,
    required this.valuesHidden,
  });
  final InvestmentsViewModel viewModel;
  final CurrencyCode baseCurrency;
  final bool valuesHidden;
  @override
  Widget build(BuildContext context) {
    final fx = viewModel.state.fx;
    final ordered = [
      baseCurrency,
      ...CurrencyCode.values.where((item) => item != baseCurrency),
    ];
    return SafeArea(
      top: false,
      child: Material(
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final currency in ordered)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${currency.isoCode} · ${currency.symbol}',
                        translate: false,
                        style: TextStyle(
                          fontWeight: currency == baseCurrency
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      _formatConverted(
                        context,
                        fx,
                        viewModel.totalValueMinor,
                        currency,
                        valuesHidden,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                fx == null
                    ? 'Cotações indisponíveis'
                    : fx.status == QuoteStatus.current
                    ? 'Cotações atualizadas · fonte de mercado'
                    : 'Últimas cotações salvas · atualização automática',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(leading: Icon(icon), title: Text(text)),
  );
}

String _formatConverted(
  BuildContext context,
  FxQuoteSet? fx,
  int amountMinor,
  CurrencyCode currency,
  bool hidden,
) {
  if (hidden) return '••••';
  final converted = fx?.convertMinor(amountMinor, currency);
  if (converted == null) return 'Indisponível';
  return MoneyFormatter(
    locale: Localizations.localeOf(context).toLanguageTag(),
    currency: currency,
  ).formatMinor(converted);
}
