import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../application/partner_catalog_port.dart';
import '../domain/partner_category.dart';
import '../domain/partner_offer.dart';

final class OscarClubPage extends StatefulWidget {
  const OscarClubPage({
    super.key,
    required this.onDestinationSelected,
    required this.catalog,
    this.offerOpener = const DisabledPartnerOfferOpenPort(),
    this.countryCode = 'BR',
  });
  final ValueChanged<AppDestination> onDestinationSelected;
  final PartnerCatalogPort catalog;
  final PartnerOfferOpenPort offerOpener;
  final String countryCode;
  @override
  State<OscarClubPage> createState() => _OscarClubPageState();
}

final class _OscarClubPageState extends State<OscarClubPage> {
  late Future<List<PartnerOffer>> _loading;
  @override
  void initState() {
    super.initState();
    _loading = widget.catalog.availableOffers(countryCode: widget.countryCode);
  }

  @override
  Widget build(BuildContext context) => OscarFeatureScaffold(
    destination: AppDestination.club,
    onDestinationSelected: widget.onDestinationSelected,
    headerKind: FeatureHeaderKind.menuOnly,
    body: FutureBuilder<List<PartnerOffer>>(
      future: _loading,
      builder: (context, snapshot) {
        final offers = snapshot.data ?? const <PartnerOffer>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.handshake_outlined, size: 34),
                    const SizedBox(height: 10),
                    Text(
                      'Oscar Clube',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Benefícios úteis e transparentes para apoiar sua educação, bem-estar e vida prática. Ofertas nunca alteram seu Oscar Score nem acessam seus dados financeiros.',
                    ),
                  ],
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            for (final category in PartnerCategory.values)
              _CategorySection(
                category: category,
                offers: offers
                    .where((offer) => offer.category == category)
                    .toList(growable: false),
                onOpen: _showOffer,
              ),
          ],
        );
      },
    ),
  );

  Future<void> _showOffer(PartnerOffer offer) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              offer.partnerName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(offer.benefit),
            Text(offer.condition),
            const SizedBox(height: 14),
            if (offer.paidPartnership)
              const Text(
                'Parceria remunerada',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            const Text(
              'O Oscar Finanças poderá receber uma comissão se você contratar ou comprar por este link. Você será direcionado ao ambiente do parceiro.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar para o parceiro'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final opened = await widget.offerOpener.open(offer);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O link deste parceiro ainda não está disponível.'),
        ),
      );
    }
  }
}

final class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.offers,
    required this.onOpen,
  });
  final PartnerCategory category;
  final List<PartnerOffer> offers;
  final ValueChanged<PartnerOffer> onOpen;
  @override
  Widget build(BuildContext context) {
    final data = switch (category) {
      PartnerCategory.educationCareer => (
        'Educação e Carreira',
        'Cursos, idiomas, livros, certificações e ferramentas profissionais.',
      ),
      PartnerCategory.healthBeautyWellness => (
        'Saúde, Beleza e Bem-estar',
        'Cuidados pessoais, academias, exames e soluções de bem-estar.',
      ),
      PartnerCategory.travelExperiences => (
        'Viagens e Experiências',
        'Hospedagem, cultura, gastronomia, passeios e serviços relacionados.',
      ),
      PartnerCategory.technologyPracticalLife => (
        'Tecnologia e Vida Prática',
        'Dispositivos, software, conectividade, casa, estudo e trabalho.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.$1, style: Theme.of(context).textTheme.titleLarge),
          Text(data.$2),
          const SizedBox(height: 10),
          SizedBox(
            height: 178,
            child: offers.isEmpty
                ? Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'Nenhum benefício válido disponível para sua região neste momento.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: PageController(viewportFraction: .9),
                    itemCount: offers.length,
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      offer.partnerName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  Text('${index + 1}/${offers.length}'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(offer.benefit),
                              Text(
                                offer.condition,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              if (offer.paidPartnership)
                                const Text(
                                  'Parceria remunerada',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => onOpen(offer),
                                  child: const Text('Ver benefício'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
