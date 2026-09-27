import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_portfolio_history.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_position.dart';

void main() {
  final now = DateTime.utc(2026, 9);
  InvestmentPosition position({
    required String id,
    required int principal,
    required int returns,
    required YearMonth month,
    DateTime? deletedAt,
  }) => InvestmentPosition(
    id: id,
    identity: const InstrumentIdentity(
      providerAssetId: 'us-aapl',
      family: AssetFamily.equity,
      symbol: 'AAPL',
      officialName: 'Apple Inc.',
      exchangeMic: 'XNAS',
      countryCode: 'US',
      currency: CurrencyCode.usd,
    ),
    principalMinor: principal,
    monthlyReturnMinor: returns,
    month: month,
    createdAt: now,
    updatedAt: now,
    deletedAt: deletedAt,
  );

  test('builds a cumulative six-month history through the selected month', () {
    final history = buildPortfolioHistory([
      position(
        id: 'apr',
        principal: 1000,
        returns: 50,
        month: const YearMonth(2026, 4),
      ),
      position(
        id: 'jun',
        principal: 2000,
        returns: 0,
        month: const YearMonth(2026, 6),
      ),
      position(
        id: 'sep',
        principal: 500,
        returns: 100,
        month: const YearMonth(2026, 9),
      ),
      position(
        id: 'oct',
        principal: 10000,
        returns: 0,
        month: const YearMonth(2026, 10),
      ),
      position(
        id: 'deleted',
        principal: 10000,
        returns: 0,
        month: const YearMonth(2026, 5),
        deletedAt: now,
      ),
    ], throughMonth: const YearMonth(2026, 9));

    expect(history, hasLength(6));
    expect(history.map((point) => point.month), [
      const YearMonth(2026, 4),
      const YearMonth(2026, 5),
      const YearMonth(2026, 6),
      const YearMonth(2026, 7),
      const YearMonth(2026, 8),
      const YearMonth(2026, 9),
    ]);
    expect(history.map((point) => point.valueMinor), [
      1050,
      1050,
      3050,
      3050,
      3050,
      3650,
    ]);
  });

  test(
    'all-period history starts at the first saved position and stays monthly',
    () {
      final history = buildPortfolioHistory(
        [
          position(
            id: 'first',
            principal: 1000,
            returns: 100,
            month: const YearMonth(2024, 11),
          ),
          position(
            id: 'later',
            principal: 500,
            returns: -50,
            month: const YearMonth(2025, 2),
          ),
        ],
        throughMonth: const YearMonth(2025, 3),
        monthCount: null,
      );

      expect(history.map((point) => point.month), [
        const YearMonth(2024, 11),
        const YearMonth(2024, 12),
        const YearMonth(2025, 1),
        const YearMonth(2025, 2),
        const YearMonth(2025, 3),
      ]);
      expect(history.map((point) => point.valueMinor), [
        1100,
        1100,
        1100,
        1550,
        1550,
      ]);
    },
  );
}
