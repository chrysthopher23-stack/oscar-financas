import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../core/money/money.dart';
import '../../../shared/formatting/currency_amount_input_formatter.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../domain/compound_projection.dart';

final class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    super.key,
    required this.onDestinationSelected,
    required this.currency,
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final CurrencyCode currency;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

final class _CalculatorPageState extends State<CalculatorPage> {
  final _initial = TextEditingController(text: '10000');
  final _contribution = TextEditingController(text: '500');
  final _rate = TextEditingController(text: '10');
  final _months = TextEditingController(text: '24');
  RatePeriodicity _periodicity = RatePeriodicity.annual;
  List<ProjectionPoint> _projection = const [];

  @override
  void dispose() {
    _initial.dispose();
    _contribution.dispose();
    _rate.dispose();
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = MoneyFormatter(locale: locale, currency: widget.currency);
    return OscarFeatureScaffold(
      destination: AppDestination.calculator,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.menuOnly,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Calculadora de juros compostos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Estimativa educacional. Não é promessa de rentabilidade nem recomendação.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _initial,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [CurrencyAmountInputFormatter(locale)],
                    decoration: InputDecoration(
                      labelText: uiText(
                        context,
                        'Valor inicial (${widget.currency.isoCode})',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contribution,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [CurrencyAmountInputFormatter(locale)],
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Aporte mensal'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Taxa (%)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<RatePeriodicity>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: RatePeriodicity.monthly,
                        label: Text('Mensal'),
                      ),
                      ButtonSegment(
                        value: RatePeriodicity.annual,
                        label: Text('Anual'),
                      ),
                    ],
                    selected: {_periodicity},
                    onSelectionChanged: (value) =>
                        setState(() => _periodicity = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _months,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Prazo em meses'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _calculate(locale),
                    child: const Text('Calcular cenário'),
                  ),
                  if (_projection.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Patrimônio estimado: ${formatter.formatMinor(_projection.last.totalMinor)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _calculate(String locale) {
    setState(() {
      _projection = CompoundProjection.calculate(
        initialMinor: parseCurrencyMinor(_initial.text, locale),
        monthlyContributionMinor: parseCurrencyMinor(
          _contribution.text,
          locale,
        ),
        rateScaled: _parseRate(_rate.text),
        periodicity: _periodicity,
        months: int.tryParse(_months.text) ?? 0,
      );
    });
  }
}

int _parseRate(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  final negative = normalized.startsWith('-');
  final clean = negative ? normalized.substring(1) : normalized;
  final parts = clean.split('.');
  final whole = int.tryParse(parts.first) ?? 0;
  final fraction = parts.length > 1
      ? parts[1].padRight(7, '0').substring(0, 7)
      : '0000000';
  final scaled = whole * 10000000 + (int.tryParse(fraction) ?? 0);
  return negative ? -scaled : scaled;
}
