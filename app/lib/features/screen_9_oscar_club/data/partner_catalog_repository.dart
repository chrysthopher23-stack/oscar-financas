import '../application/partner_catalog_port.dart';
import '../domain/partner_offer.dart';

final class LocalPartnerCatalogRepository implements PartnerCatalogPort {
  const LocalPartnerCatalogRepository([this.offers = const []]);
  final List<PartnerOffer> offers;

  @override
  Future<List<PartnerOffer>> availableOffers({
    required String countryCode,
  }) async {
    final now = DateTime.now();
    return offers
        .where(
          (offer) =>
              offer.isValidAt(now) &&
              (offer.countryCodes.isEmpty ||
                  offer.countryCodes.contains(countryCode)),
        )
        .toList(growable: false);
  }
}
