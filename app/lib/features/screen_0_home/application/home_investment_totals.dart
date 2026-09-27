import '../../../core/money/money.dart';
import '../../screen_3_investments/domain/asset_family.dart';
import '../../screen_3_investments/domain/asset_market_series.dart';
import '../../screen_3_investments/domain/crypto_amount.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../../screen_3_investments/domain/investment_position.dart';
import '../../screen_3_investments/domain/investment_holding.dart';

final class HomeInvestmentTotals {
  const HomeInvestmentTotals({
    required this.assetsValueMinor,
    required this.assetsCount,
    required this.assetsMonthlyChangeBasisPoints,
    required this.cryptoValueMinor,
    required this.cryptoCount,
    required this.cryptoDailyChangeBasisPoints,
  }) : _cryptoPositions = const [],
       _baseCurrency = CurrencyCode.brl,
       _fx = null;

  HomeInvestmentTotals._({
    required this.assetsValueMinor,
    required this.assetsCount,
    required this.assetsMonthlyChangeBasisPoints,
    required this.cryptoValueMinor,
    required this.cryptoCount,
    required this.cryptoDailyChangeBasisPoints,
    required List<InvestmentPosition> cryptoPositions,
    required this._baseCurrency,
    required this._fx,
  }) : _cryptoPositions = List.unmodifiable(cryptoPositions);

  factory HomeInvestmentTotals.fromPositions(
    Iterable<InvestmentPosition> source, {
    required CurrencyCode baseCurrency,
    required FxQuoteSet? fx,
  }) {
    final positions = source.where((position) => position.active).toList();
    final assets = positions
        .where((position) => position.identity.family != AssetFamily.crypto)
        .toList();
    final crypto = positions
        .where((position) => position.identity.family == AssetFamily.crypto)
        .toList();
    final assetsPrincipal = _sumConverted(
      assets,
      (position) => position.principalMinor,
      baseCurrency,
      fx,
    );
    final assetsReturn = _sumConverted(
      assets,
      (position) => position.monthlyReturnMinor,
      baseCurrency,
      fx,
    );

    return HomeInvestmentTotals._(
      assetsValueMinor: _sumConverted(
        assets,
        (position) => position.currentValueMinor,
        baseCurrency,
        fx,
      ),
      assetsCount: uniqueInvestmentInstrumentCount(assets),
      assetsMonthlyChangeBasisPoints: assetsPrincipal == 0
          ? null
          : _basisPoints(assetsReturn, assetsPrincipal),
      cryptoValueMinor: _sumConverted(
        crypto,
        (position) => position.currentValueMinor,
        baseCurrency,
        fx,
      ),
      cryptoCount: uniqueInvestmentInstrumentCount(crypto),
      cryptoDailyChangeBasisPoints: null,
      cryptoPositions: crypto,
      baseCurrency: baseCurrency,
      fx: fx,
    );
  }

  final int assetsValueMinor;
  final int assetsCount;
  final int? assetsMonthlyChangeBasisPoints;
  final int cryptoValueMinor;
  final int cryptoCount;
  final int? cryptoDailyChangeBasisPoints;
  final List<InvestmentPosition> _cryptoPositions;
  final CurrencyCode _baseCurrency;
  final FxQuoteSet? _fx;

  int get totalValueMinor => assetsValueMinor + cryptoValueMinor;

  HomeInvestmentTotals withCryptoMarketData(
    Map<String, AssetMarketSeries> seriesByAssetId,
  ) {
    if (cryptoCount == 0) return this;

    var weightedChange = BigInt.zero;
    var totalWeight = BigInt.zero;
    var complete = true;
    var cryptoValue = 0;

    for (final position in _cryptoPositions) {
      final storedValue = _convert(
        position.currentValueMinor,
        position.currency,
      );
      final series = seriesByAssetId[position.identity.providerAssetId];
      var positionValue = storedValue;
      int? change;
      if (series != null &&
          series.identity.providerAssetId ==
              position.identity.providerAssetId &&
          series.unitPriceUsd != null &&
          position.quantity != null &&
          series.status != AssetMarketSeriesStatus.simulated &&
          series.status != AssetMarketSeriesStatus.unavailable) {
        try {
          final valueUsd = CryptoAmount.valueMinor(
            position.quantity!,
            series.unitPriceUsd!,
          );
          positionValue = _convert(valueUsd, CurrencyCode.usd);
          change = series.dayChangeBasisPoints;
        } on FormatException {
          complete = false;
        }
      } else {
        complete = false;
      }
      cryptoValue += positionValue;
      if (change == null || positionValue <= 0) {
        complete = false;
        continue;
      }
      weightedChange += BigInt.from(positionValue) * BigInt.from(change);
      totalWeight += BigInt.from(positionValue);
    }

    return HomeInvestmentTotals._(
      assetsValueMinor: assetsValueMinor,
      assetsCount: assetsCount,
      assetsMonthlyChangeBasisPoints: assetsMonthlyChangeBasisPoints,
      cryptoValueMinor: cryptoValue,
      cryptoCount: cryptoCount,
      cryptoDailyChangeBasisPoints: complete && totalWeight > BigInt.zero
          ? _roundedRatio(weightedChange, totalWeight)
          : null,
      cryptoPositions: _cryptoPositions,
      baseCurrency: _baseCurrency,
      fx: _fx,
    );
  }

  int _convert(int amount, CurrencyCode currency) => currency == _baseCurrency
      ? amount
      : _fx?.convertToBaseMinor(amount, currency) ?? 0;

  static int _sumConverted(
    Iterable<InvestmentPosition> positions,
    int Function(InvestmentPosition) amount,
    CurrencyCode baseCurrency,
    FxQuoteSet? fx,
  ) => positions.fold<int>(0, (sum, position) {
    final value = position.currency == baseCurrency
        ? amount(position)
        : fx?.convertToBaseMinor(amount(position), position.currency) ?? 0;
    return sum + value;
  });

  static int _basisPoints(int amount, int principal) => _roundedRatio(
    BigInt.from(amount) * BigInt.from(10000),
    BigInt.from(principal),
  );

  static int _roundedRatio(BigInt numerator, BigInt denominator) {
    final negative = numerator.isNegative != denominator.isNegative;
    final absoluteNumerator = numerator.abs();
    final absoluteDenominator = denominator.abs();
    final rounded =
        (absoluteNumerator + absoluteDenominator ~/ BigInt.two) ~/
        absoluteDenominator;
    return (negative ? -rounded : rounded).toInt();
  }
}
