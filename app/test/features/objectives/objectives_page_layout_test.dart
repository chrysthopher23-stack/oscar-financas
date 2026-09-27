import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_4_objectives/domain/financial_objective.dart';
import 'package:oscar_financas/features/screen_4_objectives/domain/objective_repository.dart';
import 'package:oscar_financas/features/screen_4_objectives/presentation/objectives_page.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('objectives screen remains scrollable with multiple goals', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final shared = await SharedPreferences.getInstance();
    final visibility = FinancialVisibilityController(shared);
    addTearDown(visibility.dispose);

    await tester.pumpWidget(
      _app(
        visibility: visibility,
        objectives: [
          _goal('objective:reserve', 'Emergency fund', 'treasury_selic'),
          _goal('objective:home', 'Own a Home', 'savings'),
          _goal('objective:travel', 'Travel around the world', 'other'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Goal'), findsOneWidget);
    expect(find.text('Emergency fund'), findsOneWidget);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.maxScrollExtent.isFinite, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Own a Home'), findsOneWidget);
    expect(find.textContaining('Savings account'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Travel around the world'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('objectives screen remains usable with no goals', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final shared = await SharedPreferences.getInstance();
    final visibility = FinancialVisibilityController(shared);
    addTearDown(visibility.dispose);

    await tester.pumpWidget(_app(visibility: visibility, objectives: []));
    await tester.pumpAndSettle();

    expect(find.text('New Goal'), findsOneWidget);
    expect(find.text('Your goals start here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in SupportedAppLocale.values) {
    testWidgets(
      '${locale.tag}: goal form shows five timeframes without overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final shared = await SharedPreferences.getInstance();
        final visibility = FinancialVisibilityController(shared);
        addTearDown(visibility.dispose);

        await tester.pumpWidget(
          _app(
            visibility: visibility,
            objectives: [_goal('legacy-home', 'Own a Home', 'savings')],
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final strings = AppStrings(locale);
        final rateDescription = tester.getRect(
          find.text(strings.text('objectives.annualRateShort')),
        );
        final decreaseRate = tester.getRect(
          find.byTooltip(strings.text('objectives.lowerRate')),
        );
        expect(rateDescription.height, lessThan(22));
        expect(
          tester
              .getRect(find.text(strings.text('objectives.viewEvolution')))
              .height,
          lessThan(25),
        );
        expect(
          (rateDescription.center.dy - decreaseRate.center.dy).abs(),
          lessThan(25),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining(
            strings.text('objectives.monthCount', {'count': '8'}),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(strings.text('objectives.new')));
        await tester.pumpAndSettle();

        for (final key in [
          'objectives.threeMonths',
          'objectives.sixMonths',
          'objectives.oneYear',
          'objectives.fiveYears',
          'objectives.tenYears',
        ]) {
          expect(find.text(strings.text(key)), findsOneWidget);
        }
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        final timeframes = find.byType(SegmentedButton<int>);
        final firstRow = tester.getRect(timeframes.at(0));
        final secondRow = tester.getRect(timeframes.at(1));
        expect(secondRow.width, lessThan(firstRow.width));
        expect((secondRow.center.dx - firstRow.center.dx).abs(), lessThan(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('creating a ten-year goal saves the selected timeframe', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final shared = await SharedPreferences.getInstance();
    final visibility = FinancialVisibilityController(shared);
    addTearDown(visibility.dispose);
    final repository = _ObjectivesRepository([]);

    await tester.pumpWidget(
      _app(
        visibility: visibility,
        objectives: repository.objectives,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Goal'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New home');
    await tester.enterText(find.byType(TextFormField).at(1), '400000');
    await tester.ensureVisible(find.text('10 years'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 years'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create goal'));
    await tester.pumpAndSettle();

    final created = repository.objectives.single;
    expect(created.name, 'New home');
    expect(created.targetMonths, 120);
    expect(created.instrument, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required FinancialVisibilityController visibility,
  required List<FinancialObjective> objectives,
  ObjectiveRepository? repository,
  SupportedAppLocale locale = SupportedAppLocale.enUs,
}) => MaterialApp(
  locale: locale.locale,
  supportedLocales: SupportedAppLocale.values.map((item) => item.locale),
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.light(),
  home: ObjectivesPage(
    onDestinationSelected: (_) {},
    repository: repository ?? _ObjectivesRepository(objectives),
    financialRepository: _FinancialRepository(),
    fxRepository: _FxRepository(),
    currency: CurrencyCode.usd,
    visibilityController: visibility,
    initialData: Future<void>.value(),
    actionsEnabled: true,
    onBlocked: () {},
  ),
);

FinancialObjective _goal(String id, String name, String instrument) =>
    FinancialObjective(
      id: id,
      name: name,
      instrument: instrument,
      targetMonths: 8,
      initialBalanceMinor: 0,
      targetAmountMinor: 40000000,
      annualRateBasisPoints: 0,
      monthlyContributionMinor: 50000,
      frequency: ObjectiveContributionFrequency.monthly,
      startMonth: const YearMonth(2026, 2),
      currency: CurrencyCode.usd,
    );

final class _ObjectivesRepository extends Fake implements ObjectiveRepository {
  _ObjectivesRepository(this.objectives);
  final List<FinancialObjective> objectives;

  @override
  Future<List<FinancialObjective>> loadAll() async => objectives;

  @override
  Future<void> save(FinancialObjective objective) async {
    objectives.removeWhere((item) => item.id == objective.id);
    objectives.add(objective);
  }
}

final class _FinancialRepository extends Fake implements FinancialRepository {}

final class _FxRepository extends Fake implements FxRepository {
  @override
  Future<FxQuoteSet?> latest(
    CurrencyCode base, {
    bool forceRefresh = false,
  }) async => null;
}
