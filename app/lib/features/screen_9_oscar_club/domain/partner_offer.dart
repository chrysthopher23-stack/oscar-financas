import 'partner_category.dart';

final class PartnerOffer {
  const PartnerOffer({
    required this.id,
    required this.category,
    required this.partnerName,
    required this.benefit,
    required this.condition,
    required this.destinationUrl,
    required this.validFrom,
    required this.validUntil,
    required this.paidPartnership,
    required this.countryCodes,
  });
  final String id;
  final PartnerCategory category;
  final String partnerName;
  final String benefit;
  final String condition;
  final Uri destinationUrl;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool paidPartnership;
  final Set<String> countryCodes;

  bool isValidAt(DateTime clock) =>
      destinationUrl.scheme == 'https' &&
      !clock.isBefore(validFrom) &&
      !clock.isAfter(validUntil);
}
