import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/screen_1_financial.dart';
import 'package:oscar_financas/features/screen_5_general_reports/data/pdf_report_renderer.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/general_report_document.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/report_period.dart';
import 'package:oscar_financas/features/screen_8_plans/domain/access_policy.dart';
import 'package:oscar_financas/features/screen_8_plans/domain/plan_pricing.dart';
import 'package:oscar_financas/features/screen_9_oscar_club/domain/partner_category.dart';
import 'package:oscar_financas/features/screen_9_oscar_club/domain/partner_offer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Planos', () {
    test('preços e descontos anuais usam centavos inteiros exatos', () {
      expect(UsdPlanCatalog.plus.monthlyMinor, 1190);
      expect(UsdPlanCatalog.plus.annualFinalMinor, 12138);
      expect(UsdPlanCatalog.plus.annualDiscountBasisPoints, 1500);
      expect(UsdPlanCatalog.pro.monthlyMinor, 2390);
      expect(UsdPlanCatalog.pro.annualFinalMinor, 22944);
      expect(UsdPlanCatalog.pro.annualDiscountBasisPoints, 2000);
    });

    test('indicação de 30% não acumula e não vale para mensal', () {
      expect(
        UsdPlanCatalog.appliedDiscountBasisPoints(
          annualDiscountBasisPoints: 2000,
          validReferral: true,
        ),
        3000,
      );
      expect(
        UsdPlanCatalog.appliedDiscountBasisPoints(
          annualDiscountBasisPoints: 2000,
          validReferral: false,
        ),
        2000,
      );
      expect(
        UsdPlanCatalog.appliedDiscountBasisPoints(
          annualDiscountBasisPoints: 2000,
          validReferral: true,
          cycle: BillingCycle.monthly,
        ),
        0,
      );
    });

    test('política preserva navegação e bloqueia somente a ação', () {
      const policy = AccessPolicy();
      expect(
        policy.evaluate(PlanTier.basic, CapabilityId.investments).allowed,
        isFalse,
      );
      expect(
        policy.evaluate(PlanTier.plus, CapabilityId.objectives).allowed,
        isFalse,
      );
      expect(
        policy.evaluate(PlanTier.pro, CapabilityId.objectives).allowed,
        isTrue,
      );
      expect(
        policy.evaluate(PlanTier.basic, CapabilityId.extraIncome).allowed,
        isFalse,
      );
      expect(
        policy.evaluate(PlanTier.plus, CapabilityId.extraIncome).allowed,
        isTrue,
      );
      expect(
        policy.evaluate(PlanTier.pro, CapabilityId.annualReport).allowed,
        isTrue,
      );
    });
  });

  test('oferta do Oscar Clube exige HTTPS e validade vigente', () {
    PartnerOffer offer(Uri uri, DateTime until) => PartnerOffer(
      id: 'partner-1',
      category: PartnerCategory.educationCareer,
      partnerName: 'Parceiro',
      benefit: 'Benefício',
      condition: 'Condição',
      destinationUrl: uri,
      validFrom: DateTime(2026),
      validUntil: until,
      paidPartnership: true,
      countryCodes: const {'BR'},
    );
    final clock = DateTime(2026, 8, 31);
    expect(
      offer(Uri.https('example.com'), DateTime(2027)).isValidAt(clock),
      isTrue,
    );
    expect(
      offer(Uri.http('example.com'), DateTime(2027)).isValidAt(clock),
      isFalse,
    );
    expect(
      offer(Uri.https('example.com'), DateTime(2025)).isValidAt(clock),
      isFalse,
    );
  });

  test('PDF é renderizado offline nos cinco idiomas e quatro moedas', () async {
    final renderer = PdfReportRenderer();
    const cases = <(String, CurrencyCode)>[
      ('pt-BR', CurrencyCode.brl),
      ('en-US', CurrencyCode.usd),
      ('de-DE', CurrencyCode.eur),
      ('fr-FR', CurrencyCode.eur),
      ('hi-IN', CurrencyCode.inr),
    ];
    for (final item in cases) {
      final document = GeneralReportDocument(
        period: ReportPeriod.currentMonth,
        pages: [
          MonthlyReportPage(
            financial: MonthlyFinancialSnapshot(
              month: const YearMonth(2026, 8),
              currency: item.$2,
              mainIncomeMinor: 100000,
              expenseMinor: 40000,
              installmentMinor: 5000,
              netMinor: 55000,
              score: 55,
              scoreLabel: 'Saudável',
              reserveBalanceMinor: 300000,
              reserveCoverageMilliMonths: 3000,
              expenses: const [
                ReportExpenseItem(title: 'Aluguel', amountMinor: 40000),
              ],
            ),
            extraIncomeMinor: 10000,
            extraIncomeItems: const [
              ReportExtraIncomeItem(
                title: 'Consultoria',
                description: 'Projeto concluído',
                amountMinor: 10000,
              ),
            ],
          ),
        ],
        localeTag: item.$1,
        currency: item.$2,
        generatedAt: DateTime(2026, 8, 31),
      );
      final bytes = await renderer.render(document);
      expect(bytes.length, greaterThan(10000), reason: item.$1);
    }
  });
}
