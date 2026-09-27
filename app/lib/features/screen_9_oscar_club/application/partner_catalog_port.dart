import '../domain/partner_offer.dart';

abstract interface class PartnerCatalogPort {
  Future<List<PartnerOffer>> availableOffers({required String countryCode});
}

abstract interface class PartnerOfferOpenPort {
  Future<bool> open(PartnerOffer offer);
}

final class DisabledPartnerOfferOpenPort implements PartnerOfferOpenPort {
  const DisabledPartnerOfferOpenPort();
  @override
  Future<bool> open(PartnerOffer offer) async => false;
}
