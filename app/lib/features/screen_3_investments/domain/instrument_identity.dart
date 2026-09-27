import '../../../core/money/money.dart';
import 'asset_family.dart';

final class InstrumentIdentity {
  const InstrumentIdentity({
    required this.providerAssetId,
    required this.family,
    required this.symbol,
    required this.officialName,
    required this.exchangeMic,
    required this.countryCode,
    required this.currency,
    this.isin,
    this.institution = '',
    this.aliases = const [],
  });

  final String providerAssetId;
  final AssetFamily family;
  final String symbol;
  final String officialName;
  final String exchangeMic;
  final String countryCode;
  final CurrencyCode currency;
  final String? isin;
  final String institution;
  final List<String> aliases;

  Iterable<String> get searchableTerms => [
    symbol,
    officialName,
    exchangeMic,
    countryCode,
    ?isin,
    institution,
    ...aliases,
  ];
}
