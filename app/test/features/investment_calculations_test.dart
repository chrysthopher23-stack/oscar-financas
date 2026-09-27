import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_3_investments/data/initial_asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_catalog.dart';
import 'package:oscar_financas/features/screen_7_calculator/domain/compound_projection.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_health.dart';

void main() {
  group('catálogo internacional', () {
    const repository = LocalAssetCatalogRepository(initialAssetCatalog);

    test('prioriza ticker exato e preserva identidade de mercado', () async {
      final results = await repository.search('MXRF11');
      expect(results.first.symbol, 'MXRF11');
      expect(results.first.exchangeMic, 'BVMF');
      expect(results.first.countryCode, 'BR');
      expect(results.first.currency, CurrencyCode.brl);
      expect(results.first.providerAssetId, 'br-mxrf11');
    });

    test('busca aliases dos mercados sem regra de país no widget', () async {
      expect((await repository.search('Schatz')).first.symbol, 'BUND');
      expect((await repository.search('SCPI')).first.symbol, 'VNQ');
      expect((await repository.search('LCI')).first.symbol, 'CDB');
    });

    test('encontra ações das Casas Bahia por símbolo parcial', () async {
      final results = await repository.search('bhi');
      expect(results.first.symbol, 'BHIA3');
      expect(results.first.exchangeMic, 'BVMF');
      expect(results.first.providerAssetId, 'br-bhia3');
    });
  });

  group('simulação exata por inteiro escalado', () {
    test('taxa e aporte zero mantêm o principal', () {
      final points = CompoundProjection.calculate(
        initialMinor: 100000,
        monthlyContributionMinor: 0,
        rateScaled: 0,
        periodicity: RatePeriodicity.monthly,
        months: 12,
      );
      expect(points.last.totalMinor, 100000);
      expect(points.last.earningsMinor, 0);
    });

    test('prazo zero gera somente o ponto inicial', () {
      final points = CompoundProjection.calculate(
        initialMinor: 250000,
        monthlyContributionMinor: 10000,
        rateScaled: 10000000,
        periodicity: RatePeriodicity.monthly,
        months: 0,
      );
      expect(points, hasLength(1));
      expect(points.single.totalMinor, 250000);
    });

    test('taxa anual equivalente não é dividida silenciosamente por 12', () {
      final monthly = CompoundProjection.annualToMonthlyEquivalent(120000000);
      expect(monthly, isNot(10000000));
      final projection = CompoundProjection.calculate(
        initialMinor: 100000,
        monthlyContributionMinor: 0,
        rateScaled: 120000000,
        periodicity: RatePeriodicity.annual,
        months: 12,
      );
      expect(projection.last.totalMinor, closeTo(112000, 5));
    });
  });

  test('FxQuoteSet exige as quatro moedas', () {
    expect(
      () => FxQuoteSet(
        base: CurrencyCode.brl,
        unitsPerBaseScaled: const {
          CurrencyCode.brl: FxQuoteSet.scale,
          CurrencyCode.usd: 190000000,
        },
        observedAt: DateTime(2026),
        status: QuoteStatus.current,
      ),
      throwsArgumentError,
    );
  });

  test('crescimento real subtrai o efeito estimado da inflação', () {
    final result = calculateInvestmentHealth(
      month: const YearMonth(2026, 8),
      openingPrincipalMinor: 1000000,
      nominalReturnMinor: 12000,
      monthlyInflationScaled: 3800000,
      referenceMonth: const YearMonth(2026, 7),
    );
    expect(result.inflationEffectMinor, 3800);
    expect(result.realGrowthMinor, 8200);
  });
}
