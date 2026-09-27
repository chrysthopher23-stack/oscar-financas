import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';

enum TransactionKind { income, expense }

enum DiscountType { none, fixed, percentage }

final class FinancialTransaction {
  static const legacyEmergencyFundTitles = <String>{
    'reserva de emergência',
    'reserva de emergencia',
    'reserva de emergência simulada',
    'reserva de emergencia simulada',
    'fundo de emergência',
    'fundo de emergencia',
    'emergency fund',
    'emergency fund contribution',
    'notgroschen',
    "fonds d'urgence",
    'fonds d’urgence',
    'आपातकालीन निधि',
  };

  const FinancialTransaction({
    required this.id,
    required this.title,
    required this.kind,
    required this.originalAmountMinor,
    required this.currency,
    required this.month,
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    this.recurring = false,
    this.installmentLabel,
    this.deletedAt,
  });

  final String id;
  final String title;
  final TransactionKind kind;
  final int originalAmountMinor;
  final CurrencyCode currency;
  final YearMonth month;
  final DiscountType discountType;
  final int discountValue;
  final bool recurring;
  final String? installmentLabel;
  final DateTime? deletedAt;

  bool get active => deletedAt == null;

  bool get isEmergencyFundContribution =>
      kind == TransactionKind.expense &&
      (id.startsWith('emergency-fund:') || isLegacyEmergencyFundContribution);

  bool get isLegacyEmergencyFundContribution =>
      kind == TransactionKind.expense &&
      !id.startsWith('emergency-fund:') &&
      legacyEmergencyFundTitles.contains(title.trim().toLowerCase());

  int get netAmountMinor {
    final discount = switch (discountType) {
      DiscountType.none => 0,
      DiscountType.fixed => discountValue.clamp(0, originalAmountMinor),
      DiscountType.percentage =>
        ((originalAmountMinor * discountValue.clamp(0, 10000)) + 5000) ~/ 10000,
    };
    return (originalAmountMinor - discount).clamp(0, originalAmountMinor);
  }

  FinancialTransaction copyWith({
    String? title,
    int? originalAmountMinor,
    DiscountType? discountType,
    int? discountValue,
    bool? recurring,
    DateTime? deletedAt,
    bool restore = false,
  }) {
    return FinancialTransaction(
      id: id,
      title: title ?? this.title,
      kind: kind,
      originalAmountMinor: originalAmountMinor ?? this.originalAmountMinor,
      currency: currency,
      month: month,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      recurring: recurring ?? this.recurring,
      installmentLabel: installmentLabel,
      deletedAt: restore ? null : deletedAt ?? this.deletedAt,
    );
  }
}
