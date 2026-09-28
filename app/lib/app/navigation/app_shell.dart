import 'package:flutter/material.dart' hide Text;

import '../../core/time/year_month.dart';
import '../../features/screen_1_financial/screen_1_financial.dart';
import '../../features/screen_2_extra_income/screen_2_extra_income.dart';
import '../../features/screen_3_investments/data/alpha_vantage_market_repository.dart';
import '../../features/screen_3_investments/data/coinmarketcap_repository.dart';
import '../../features/screen_3_investments/data/awesome_api_fx_repository.dart';
import '../../features/screen_3_investments/data/hg_brasil_market_repository.dart';
import '../../features/screen_3_investments/data/persistent_asset_market_repository.dart';
import '../../features/screen_3_investments/data/initial_asset_catalog.dart';
import '../../features/screen_3_investments/data/routed_asset_market_repository.dart';
import '../../features/screen_3_investments/domain/asset_catalog.dart';
import '../../features/screen_3_investments/domain/asset_market_series.dart';
import '../../features/screen_3_investments/domain/fx_quote_set.dart';
import '../../features/screen_3_investments/screen_3_investments.dart';
import '../../features/screen_5_general_reports/screen_5_general_reports.dart';
import '../../features/screen_6_agenda/screen_6_agenda.dart';
import '../../features/screen_7_calculator/screen_7_calculator.dart';
import '../../features/screen_8_plans/screen_8_plans.dart';
import '../../features/screen_9_oscar_club/data/partner_catalog_repository.dart';
import '../../features/screen_9_oscar_club/screen_9_oscar_club.dart';
import '../../features/screen_11_settings/screen_11_settings.dart';
import '../../features/screen_0_home/presentation/home_page.dart';
import '../../features/screen_10_account/screen_10_account.dart';
import '../../features/screen_4_objectives/screen_4_objectives.dart';
import '../../shared/controllers/financial_visibility_controller.dart';
import '../../shared/widgets/localized_text.dart';
import '../services/app_services.dart';
import '../history_experience_copy.dart';
import '../services/create_app_services.dart';
import '../settings/app_preferences_controller.dart';
import 'app_destination.dart';
import 'navigation_controller.dart';

final class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigation,
    required this.financialVisibility,
    required this.preferences,
    this.servicesFactory,
  });

  final NavigationController navigation;
  final FinancialVisibilityController financialVisibility;
  final AppPreferencesController preferences;
  final AppServices Function()? servicesFactory;

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  late final AppServices _services;
  late final Future<void> _initialDemoData;
  late final AssetCatalogRepository _assetCatalog;
  late final FxRepository _fxRepository;
  late final AssetMarketRepository _marketRepository;
  final EntitlementController _entitlements = EntitlementController();
  final LocalPartnerCatalogRepository _partnerCatalog =
      const LocalPartnerCatalogRepository();
  YearMonth? _earliestMonth;

  @override
  void initState() {
    super.initState();
    _services = widget.servicesFactory?.call() ?? createAppServices();
    _initialDemoData = _services.ensureInitialDemoData(
      month: YearMonth.now(),
      currency: widget.preferences.currency,
    );
    _initialDemoData.then((_) => _refreshHistoryBoundary());
    widget.navigation.addListener(_refreshHistoryBoundary);
    final crypto = CoinMarketCapRepository();
    _assetCatalog = CombinedAssetCatalog(
      const LocalAssetCatalogRepository(initialAssetCatalog),
      crypto,
    );
    _fxRepository = AwesomeApiFxRepository(
      apiKey: const String.fromEnvironment('AWESOME_API_KEY'),
    );
    _marketRepository = PersistentAssetMarketRepository(
      delegate: RoutedAssetMarketRepository(
        cryptoRepository: crypto,
        brazilianRepository: HgBrasilMarketRepository(
          apiKey: const String.fromEnvironment('HG_BRASIL_API_KEY'),
        ),
        globalRepository: AlphaVantageMarketRepository(
          apiKey: const String.fromEnvironment('ALPHA_VANTAGE_API_KEY'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.navigation.removeListener(_refreshHistoryBoundary);
    _entitlements.dispose();
    super.dispose();
  }

  Future<void> _refreshHistoryBoundary() async {
    await _initialDemoData;
    final earliest = await _services.earliestRecordedMonth();
    if (mounted && earliest != _earliestMonth) {
      setState(() => _earliestMonth = earliest);
    }
  }

  Future<void> _resetHistory() async {
    await _initialDemoData;
    await _services.resetPersonalHistory();
    await _refreshHistoryBoundary();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.navigation, _entitlements]),
      builder: (context, _) {
        final destination = widget.navigation.current;
        final extraIncomeAllowed = _entitlements
            .evaluate(CapabilityId.extraIncome)
            .allowed;
        final investmentsAllowed = _entitlements
            .evaluate(CapabilityId.investments)
            .allowed;
        final objectivesAllowed = _entitlements
            .evaluate(CapabilityId.objectives)
            .allowed;
        return KeyedSubtree(
          key: ValueKey((
            destination,
            widget.preferences.locale,
            widget.preferences.currency,
            widget.preferences.region,
            switch (destination) {
              AppDestination.financial ||
              AppDestination.extraIncome ||
              AppDestination.investments ||
              AppDestination.agenda => _earliestMonth,
              _ => null,
            },
          )),
          child: switch (destination) {
            AppDestination.home => HomePage(
              onDestinationSelected: widget.navigation.select,
              visibilityController: widget.financialVisibility,
              preferences: widget.preferences,
              financialRepository: _services.financialRepository,
              extraIncomeRepository: _services.extraIncomeRepository,
              investmentRepository: _services.investmentRepository,
              objectiveRepository: _services.objectiveRepository,
              assetMarketRepository: _marketRepository,
              fxRepository: _fxRepository,
              initialData: _initialDemoData,
              welcomeCopy: HistoryExperienceCopy(widget.preferences.locale),
            ),
            AppDestination.financial => FinancialPage(
              onDestinationSelected: widget.navigation.select,
              visibilityController: widget.financialVisibility,
              repository: _services.financialRepository,
              extraIncomePort: _services.extraIncomeContributionPort,
              currency: widget.preferences.currency,
              fxRepository: _fxRepository,
              minimumMonth: _earliestMonth,
            ),
            AppDestination.extraIncome => ExtraIncomePage(
              onDestinationSelected: widget.navigation.select,
              visibilityController: widget.financialVisibility,
              repository: _services.extraIncomeRepository,
              currency: widget.preferences.currency,
              fxRepository: _fxRepository,
              actionsEnabled: extraIncomeAllowed,
              onBlocked: () => _showPlanNotice(PlanTier.plus),
              minimumMonth: _earliestMonth,
            ),
            AppDestination.investments => InvestmentsPage(
              onDestinationSelected: widget.navigation.select,
              visibilityController: widget.financialVisibility,
              repository: _services.investmentRepository,
              catalog: _assetCatalog,
              fxRepository: _fxRepository,
              marketRepository: _marketRepository,
              currency: widget.preferences.currency,
              actionsEnabled: investmentsAllowed,
              onBlocked: () => _showPlanNotice(PlanTier.pro),
              minimumMonth: _earliestMonth,
            ),
            AppDestination.objectives => ObjectivesPage(
              onDestinationSelected: widget.navigation.select,
              repository: _services.objectiveRepository,
              financialRepository: _services.financialRepository,
              fxRepository: _fxRepository,
              currency: widget.preferences.currency,
              visibilityController: widget.financialVisibility,
              initialData: _initialDemoData,
              actionsEnabled: objectivesAllowed,
              onBlocked: () => _showPlanNotice(PlanTier.pro),
            ),
            AppDestination.reports => GeneralReportsPage(
              onDestinationSelected: widget.navigation.select,
              service: GeneralReportService(
                financial: MonthlyFinancialReportAdapter(
                  _services.financialRepository,
                  widget.preferences.currency,
                  fxRepository: _fxRepository,
                ),
                extraIncome: _services.extraIncomeContributionPort,
                investments: _services.investmentRepository,
                objectives: _services.objectiveRepository,
                fxRepository: _fxRepository,
              ),
              currency: widget.preferences.currency,
              accessTier: switch (_entitlements.tier) {
                PlanTier.basic => ReportAccessTier.basic,
                PlanTier.plus => ReportAccessTier.plus,
                PlanTier.pro => ReportAccessTier.pro,
              },
            ),
            AppDestination.agenda => AgendaPage(
              onDestinationSelected: widget.navigation.select,
              repository: _services.agendaRepository,
              scheduler: widget.preferences.agendaRemindersEnabled
                  ? _services.notificationScheduler
                  : const DisabledNotificationScheduler(),
              defaultReminder: switch (widget.preferences.agendaReminder) {
                AgendaReminderPreference.atTime => ReminderPreset.atTime,
                AgendaReminderPreference.oneDayAndAtTime =>
                  ReminderPreset.oneDayAndAtTime,
                AgendaReminderPreference.threeDaysOneDayAndAtTime =>
                  ReminderPreset.threeDaysOneDayAndAtTime,
              },
              minimumMonth: _earliestMonth,
            ),
            AppDestination.calculator => CalculatorPage(
              onDestinationSelected: widget.navigation.select,
              currency: widget.preferences.currency,
              actionsEnabled: investmentsAllowed,
              onBlocked: () => _showPlanNotice(PlanTier.pro),
            ),
            AppDestination.plans => PlansPage(
              onDestinationSelected: widget.navigation.select,
              entitlements: _entitlements,
            ),
            AppDestination.club => OscarClubPage(
              onDestinationSelected: widget.navigation.select,
              catalog: _partnerCatalog,
            ),
            AppDestination.account => AccountPage(
              onDestinationSelected: widget.navigation.select,
              repository: const LocalAccountProfileRepository(),
              currentPlan: _entitlements.tier,
            ),
            AppDestination.settings => SettingsPage(
              onDestinationSelected: widget.navigation.select,
              preferences: widget.preferences,
              fxRepository: _fxRepository,
              onResetHistory: _resetHistory,
            ),
          },
        );
      },
    );
  }

  void _showPlanNotice(PlanTier requiredTier) {
    final label = requiredTier == PlanTier.plus ? 'Plus' : 'Pro';
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          uiText(
            context,
            'Disponível no Plano {plan}.',
          ).replaceAll('{plan}', label),
          translate: false,
        ),
      ),
    );
  }
}
