import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../core/money/money.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../application/entitlement_controller.dart';
import '../domain/access_policy.dart';
import '../domain/plan_pricing.dart';

final class PlansPage extends StatefulWidget {
  const PlansPage({
    super.key,
    required this.onDestinationSelected,
    required this.entitlements,
  });
  final ValueChanged<AppDestination> onDestinationSelected;
  final EntitlementController entitlements;
  @override
  State<PlansPage> createState() => _PlansPageState();
}

final class _PlansPageState extends State<PlansPage> {
  BillingCycle cycle = BillingCycle.monthly;
  @override
  Widget build(BuildContext context) {
    final formatter = MoneyFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: CurrencyCode.usd,
    );
    return OscarFeatureScaffold(
      destination: AppDestination.plans,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.menuOnly,
      body: ListenableBuilder(
        listenable: widget.entitlements,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<BillingCycle>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: BillingCycle.monthly,
                  label: Text('Mensal'),
                ),
                ButtonSegment(value: BillingCycle.annual, label: Text('Anual')),
              ],
              selected: {cycle},
              onSelectionChanged: (value) =>
                  setState(() => cycle = value.first),
            ),
            const SizedBox(height: 12),
            _PlanCard(
              title: 'Plano Básico',
              tagline: 'Organização financeira essencial, sem custo.',
              benefits: const [
                'Painel Financeiro completo, Reserva de Emergência e Oscar Score',
                'Relatório mensal com impressão e compartilhamento',
                'Agenda completa com recorrência e lembretes locais',
                'Oscar Clube e Configurações',
              ],
              current: widget.entitlements.tier == PlanTier.basic,
              priceText: uiText(context, 'Grátis'),
              onPressed: () => widget.entitlements.selectPlan(PlanTier.basic),
            ),
            _PlanCard(
              title: 'Plano Plus',
              tagline: 'Mais controle para quem transforma trabalho em renda.',
              benefits: const [
                'Tudo do Plano Básico',
                'Ganho Extra completo: Serviços, Vendas e recorrências',
                'Integração Agenda → Ganho Extra',
                'Relatórios do mês e dos últimos 3 meses',
                'Sem anúncios',
              ],
              current: widget.entitlements.tier == PlanTier.plus,
              priceText: _price(context, UsdPlanCatalog.plus, formatter),
              onPressed: () => widget.entitlements.selectPlan(PlanTier.plus),
            ),
            _PlanCard(
              title: 'Plano Pro',
              tagline: 'Visão patrimonial completa, simples e internacional.',
              benefits: const [
                'Tudo do Plano Plus',
                'Investimentos, busca internacional, ações, ETFs e calculadora',
                'Carteira de criptoativos',
                'Objetivos financeiros com evolução mês a mês',
                'Crescimento real e resumo em BRL, USD, EUR e INR',
                'Relatórios de 1, 3, 6 e 12 meses',
                'Sem anúncios',
              ],
              current: widget.entitlements.tier == PlanTier.pro,
              priceText: _price(context, UsdPlanCatalog.pro, formatter),
              onPressed: () => widget.entitlements.selectPlan(PlanTier.pro),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Convide um Amigo',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Receba 30% de desconto quando um amigo indicado se cadastrar e contratar um plano anual. Assinaturas mensais não participam. Descontos não se acumulam: vale o maior desconto elegível.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'O convite de amigos está indisponível nesta versão.',
                              ),
                            ),
                          ),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Convidar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _price(
    BuildContext context,
    PlanPrice price,
    MoneyFormatter formatter,
  ) {
    if (cycle == BillingCycle.monthly) {
      return 'USD ${formatter.formatMinor(price.monthlyMinor)} ${uiText(context, 'por mês')}';
    }
    return 'USD ${formatter.formatMinor(price.annualFinalMinor)} ${uiText(context, 'por ano')} · ${uiText(context, 'equivalente a')} ${formatter.formatMinor(price.annualEquivalentMonthlyMinor)}/${uiText(context, 'mês')} · ${uiText(context, 'economize')} ${price.annualDiscountBasisPoints ~/ 100}%';
  }
}

final class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.tagline,
    required this.benefits,
    required this.current,
    required this.priceText,
    required this.onPressed,
  });
  final String title;
  final String tagline;
  final List<String> benefits;
  final bool current;
  final String priceText;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: current ? const Color(0xFFD4AF37) : Colors.transparent,
        width: 1.5,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
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
              if (current)
                const Flexible(child: Chip(label: Text('Plano atual'))),
            ],
          ),
          Text(tagline),
          const SizedBox(height: 12),
          ...benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 19),
                  const SizedBox(width: 8),
                  Expanded(child: Text(benefit)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            priceText,
            translate: false,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: current ? null : onPressed,
            child: Text(
              current
                  ? uiText(context, 'Plano atual')
                  : uiText(context, 'Escolher ${uiText(context, title)}'),
              translate: false,
            ),
          ),
        ],
      ),
    ),
  );
}
