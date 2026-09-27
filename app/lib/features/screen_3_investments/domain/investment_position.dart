import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import 'instrument_identity.dart';

final class InvestmentPosition {
  const InvestmentPosition({
    required this.id,
    required this.identity,
    required this.principalMinor,
    required this.monthlyReturnMinor,
    required this.month,
    required this.createdAt,
    required this.updatedAt,
    this.source = 'manual',
    this.deletedAt,
    this.quantity,
    this.marketValueMinor,
  });

  final String id;
  final InstrumentIdentity identity;
  final int principalMinor;
  final int monthlyReturnMinor;
  final YearMonth month;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? quantity;

  /// Display-only market valuation, never persisted as monthly income.
  final int? marketValueMinor;

  int get currentValueMinor =>
      marketValueMinor ?? principalMinor + monthlyReturnMinor;
  CurrencyCode get currency => identity.currency;
  bool get active => deletedAt == null;
}
