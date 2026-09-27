import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../shared/controllers/financial_visibility_controller.dart';
import '../../../shared/controllers/month_controller.dart';
import '../../../shared/formatting/currency_amount_input_formatter.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../application/investments_view_model.dart';
import '../domain/asset_catalog.dart';
import '../domain/asset_market_series.dart';
import '../domain/asset_family.dart';
import '../domain/crypto_amount.dart';
import '../domain/fx_quote_set.dart';
import '../domain/instrument_identity.dart';
import '../domain/investment_holding.dart';
import '../domain/investment_position.dart';
import '../domain/investment_repository.dart';
import 'widgets/allocation_donut.dart';
import 'widgets/portfolio_chart.dart';
import 'widgets/related_assets_carousel.dart';

part 'widgets/investment_sections.dart';

final class InvestmentsPage extends StatefulWidget {
  const InvestmentsPage({
    super.key,
    required this.onDestinationSelected,
    required this.visibilityController,
    required this.repository,
    required this.catalog,
    required this.fxRepository,
    required this.marketRepository,
    required this.currency,
    required this.actionsEnabled,
    required this.onBlocked,
    this.minimumMonth,
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final FinancialVisibilityController visibilityController;
  final InvestmentRepository repository;
  final AssetCatalogRepository catalog;
  final FxRepository fxRepository;
  final AssetMarketRepository marketRepository;
  final CurrencyCode currency;
  final bool actionsEnabled;
  final VoidCallback onBlocked;
  final YearMonth? minimumMonth;

  @override
  State<InvestmentsPage> createState() => _InvestmentsPageState();
}

final class _InvestmentsPageState extends State<InvestmentsPage> {
  late final MonthController _monthController;
  late final InvestmentsViewModel _viewModel;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _searchLink = LayerLink();
  OverlayEntry? _searchOverlay;

  @override
  void initState() {
    super.initState();
    _monthController = MonthController(
      minimumMonth: widget.minimumMonth,
      currentMonthFloor: true,
    );
    _viewModel = InvestmentsViewModel(
      repository: widget.repository,
      catalog: widget.catalog,
      fxRepository: widget.fxRepository,
      marketRepository: widget.marketRepository,
      monthController: _monthController,
      baseCurrency: widget.currency,
    )..load();
    _searchFocus.addListener(_handleSearchFocus);
    _viewModel.addListener(_refreshOverlay);
  }

  @override
  void dispose() {
    _removeOverlay();
    _viewModel.removeListener(_refreshOverlay);
    _viewModel.dispose();
    _monthController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = MoneyFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: widget.currency,
    );
    return OscarFeatureScaffold(
      destination: AppDestination.investments,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.financialMonth,
      monthController: _monthController,
      visibilityController: widget.visibilityController,
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, widget.visibilityController]),
        builder: (context, _) => _CurrencyFooter(
          viewModel: _viewModel,
          baseCurrency: widget.currency,
          valuesHidden: widget.visibilityController.valuesHidden,
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, widget.visibilityController]),
        builder: (context, _) {
          final state = _viewModel.state;
          final canCombineCurrencies =
              state.positions.every(
                (position) => position.currency == widget.currency,
              ) ||
              state.fx?.status == QuoteStatus.current ||
              state.fx?.status == QuoteStatus.cached;
          return RefreshIndicator(
            onRefresh: () => _viewModel.load(waitForMarket: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              children: [
                if (state.error != null)
                  _InlineNotice(text: state.error!, icon: Icons.error_outline),
                if (canCombineCurrencies)
                  PortfolioChart(
                    history: _viewModel.portfolioHistory,
                    formatter: formatter,
                    valuesHidden: widget.visibilityController.valuesHidden,
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Câmbio indisponível: não é possível somar investimentos em moedas diferentes.',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                CompositedTransformTarget(
                  link: _searchLink,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: uiText(
                        context,
                        'Pesquisar ou adicionar investimento',
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: uiText(context, 'Limpar pesquisa'),
                              onPressed: () {
                                _searchController.clear();
                                _viewModel.clearSearch();
                                _refreshOverlay();
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (value) {
                      _viewModel.search(value);
                      _showOverlay();
                      setState(() {});
                    },
                    onTap: _showOverlay,
                  ),
                ),
                const SizedBox(height: 16),
                _AreaSelector(viewModel: _viewModel),
                const SizedBox(height: 12),
                _PositionsList(
                  positions: _viewModel.filteredHoldings,
                  formatter: formatter,
                  valuesHidden: widget.visibilityController.valuesHidden,
                  onOpen: (holding) => _showHoldingDetails(holding, formatter),
                  onAdd: () => _showPositionForm(null, manualName: ''),
                ),
                const SizedBox(height: 22),
                Text(
                  'Alocação de ativos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                AllocationDonut(
                  positions: _viewModel.displayHoldings,
                  formatter: formatter,
                  valuesHidden: widget.visibilityController.valuesHidden,
                ),
                const SizedBox(height: 20),
                if (_viewModel.displayHoldings.isNotEmpty) ...[
                  RelatedAssetsCarousel(
                    title: 'Ativos relacionados',
                    positions: _viewModel.displayHoldings
                        .where(
                          (item) => item.identity.family != AssetFamily.crypto,
                        )
                        .toList(),
                    marketSeries: state.marketSeries,
                    historicalMonth:
                        _viewModel.month.compareTo(YearMonth.now()) < 0,
                    recordedHistories: _viewModel.recordedAssetHistories,
                    formatter: formatter,
                    valuesHidden: widget.visibilityController.valuesHidden,
                  ),
                  if (_viewModel.displayHoldings.any(
                    (item) => item.identity.family == AssetFamily.crypto,
                  )) ...[
                    const SizedBox(height: 20),
                    RelatedAssetsCarousel(
                      title: 'Criptoativos relacionados',
                      positions: _viewModel.displayHoldings
                          .where(
                            (item) =>
                                item.identity.family == AssetFamily.crypto,
                          )
                          .toList(),
                      marketSeries: state.marketSeries,
                      historicalMonth:
                          _viewModel.month.compareTo(YearMonth.now()) < 0,
                      recordedHistories: _viewModel.recordedAssetHistories,
                      formatter: formatter,
                      valuesHidden: widget.visibilityController.valuesHidden,
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
                _InflationCard(
                  nominal: _viewModel.health.nominalReturnMinor,
                  effect: _viewModel.health.inflationEffectMinor,
                  real: _viewModel.health.realGrowthMinor,
                  formatter: formatter,
                  valuesHidden: widget.visibilityController.valuesHidden,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleSearchFocus() {
    if (_searchFocus.hasFocus) {
      _viewModel.search(_searchController.text);
      _showOverlay();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 120), _removeOverlay);
    }
  }

  void _refreshOverlay() => _searchOverlay?.markNeedsBuild();

  void _showOverlay() {
    if (!_searchFocus.hasFocus || _searchOverlay != null) return;
    _searchOverlay = OverlayEntry(
      builder: (overlayContext) {
        final media = MediaQuery.of(overlayContext);
        final keyboardTop = media.size.height - media.viewInsets.bottom;
        final targetBox = context.findRenderObject() as RenderBox?;
        final fieldBottom = targetBox == null
            ? 180.0
            : targetBox.localToGlobal(Offset.zero).dy + 120;
        final available = math.max(180.0, keyboardTop - fieldBottom - 12);
        final maxHeight = math.min(media.size.height * .70, available);
        final results = _viewModel.state.searchResults;
        return Positioned(
          width: math.min(media.size.width - 36, 680),
          child: CompositedTransformFollower(
            link: _searchLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 62),
            child: Material(
              elevation: 14,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: results.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                'Nenhum resultado local. O cadastro manual continua disponível.',
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final item = results[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.account_balance_outlined,
                                  ),
                                  title: material.Text(
                                    '${item.symbol} · ${item.officialName}',
                                  ),
                                  subtitle: Text(
                                    '${uiText(context, item.family.label)} · ${item.exchangeMic} · ${item.countryCode} · ${item.currency.isoCode}',
                                    translate: false,
                                  ),
                                  onTap: () =>
                                      _showPositionForm(item, manualName: ''),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(
                        'Cadastrar “${_searchController.text.trim()}” manualmente',
                      ),
                      onTap: () => _showPositionForm(
                        null,
                        manualName: _searchController.text.trim(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_searchOverlay!);
  }

  void _removeOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  Future<void> _showPositionForm(
    InstrumentIdentity? selected, {
    required String manualName,
  }) async {
    if (!widget.actionsEnabled) {
      widget.onBlocked();
      return;
    }
    _removeOverlay();
    _searchFocus.unfocus();
    final symbol = TextEditingController(
      text: selected?.symbol ?? manualName.toUpperCase(),
    );
    final name = TextEditingController(
      text: selected?.officialName ?? manualName,
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final principal = TextEditingController();
    final monthlyReturn = TextEditingController(text: '0');
    final quantity = TextEditingController();
    var family = selected?.family ?? AssetFamily.otherManual;
    var currency = selected?.currency ?? widget.currency;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    selected == null
                        ? 'Cadastrar investimento manualmente'
                        : 'Confirmar nova posição',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: symbol,
                    enabled: selected == null,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Símbolo ou código'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    enabled: selected == null,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Nome'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AssetFamily>(
                    isExpanded: true,
                    initialValue: family,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Família'),
                    ),
                    items: AssetFamily.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: selected == null
                        ? (value) => setSheetState(() => family = value!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CurrencyCode>(
                    isExpanded: true,
                    initialValue: currency,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Moeda original'),
                    ),
                    items: CurrencyCode.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              '${item.isoCode} · ${item.symbol}',
                              translate: false,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: selected == null
                        ? (value) => setSheetState(() => currency = value!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: principal,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [CurrencyAmountInputFormatter(locale)],
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Valor aplicado'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (family == AssetFamily.crypto) ...[
                    TextField(
                      controller: quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: uiText(context, 'Quantidade'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (family != AssetFamily.crypto)
                    TextField(
                      controller: monthlyReturn,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        CurrencyAmountInputFormatter(
                          locale,
                          allowNegative: true,
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: uiText(context, 'Rendimento do mês'),
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      final decimal = NumberFormat.decimalPattern(locale)
                          .symbols
                          .DECIMAL_SEP;
                      final normalizedQuantity = quantity.text
                          .trim()
                          .replaceAll(decimal, '.');
                      if (family == AssetFamily.crypto &&
                          !CryptoAmount.validQuantity(normalizedQuantity)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Informe uma quantidade válida.'),
                          ),
                        );
                        return;
                      }
                      final identity =
                          selected ??
                          _manualInstrumentIdentity(
                            symbol: symbol.text,
                            officialName: name.text,
                            family: family,
                            currency: currency,
                          );
                      await _viewModel.addPosition(
                        identity: identity,
                        quantity: family == AssetFamily.crypto
                            ? normalizedQuantity
                            : null,
                        principalMinor: parseCurrencyMinor(
                          principal.text,
                          locale,
                        ),
                        monthlyReturnMinor: parseCurrencyMinor(
                          monthlyReturn.text,
                          locale,
                        ),
                        manual: selected == null,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Confirmar posição'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showHoldingDetails(
    InvestmentHolding holding,
    MoneyFormatter formatter,
  ) async {
    if (!widget.actionsEnabled) {
      widget.onBlocked();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              material.Text(
                holding.identity.officialName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${holding.identity.symbol} · ${holding.identity.exchangeMic} · ${holding.identity.countryCode} · ${holding.identity.currency.isoCode}',
                translate: false,
              ),
              const SizedBox(height: 12),
              Text(
                'Aplicado: ${formatter.formatMinor(holding.principalMinor)}',
              ),
              Text(
                'Rendimento: ${formatter.formatMinor(holding.monthlyReturnMinor)}',
              ),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: holding.positions.length,
                  itemBuilder: (context, index) {
                    final position = holding.positions[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${position.month.year}-${position.month.month.toString().padLeft(2, '0')}',
                      ),
                      subtitle: Text(
                        'Aplicado: ${formatter.formatMinor(position.principalMinor)} · Rendimento: ${formatter.formatMinor(position.monthlyReturnMinor)}',
                      ),
                      trailing: IconButton(
                        tooltip: uiText(context, 'Excluir'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmRemovePosition(position, sheetContext),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemovePosition(
    InvestmentPosition position,
    BuildContext sheetContext,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir esta posição?'),
        content: const Text(
          'Ela sairá da carteira, mas poderá ser restaurada por alguns segundos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _viewModel.remove(position);
    if (!mounted || !sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Posição excluída.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: uiText(context, 'Desfazer'),
          onPressed: () => _viewModel.restore(position),
        ),
      ),
    );
  }
}

InstrumentIdentity _manualInstrumentIdentity({
  required String symbol,
  required String officialName,
  required AssetFamily family,
  required CurrencyCode currency,
}) {
  final normalizedSymbol = symbol.trim().isEmpty
      ? 'MANUAL'
      : symbol.trim().toUpperCase();
  final looksLikeBrazilianTicker =
      currency == CurrencyCode.brl &&
      RegExp(r'^[A-Z]{4}[0-9]{1,2}$').hasMatch(normalizedSymbol);
  final looksLikeUsTicker =
      currency == CurrencyCode.usd &&
      RegExp(r'^[A-Z][A-Z0-9.-]{0,9}$').hasMatch(normalizedSymbol);
  final isMarketAsset = looksLikeBrazilianTicker || looksLikeUsTicker;
  final inferredFamily = family == AssetFamily.otherManual && isMarketAsset
      ? (normalizedSymbol.endsWith('11')
            ? AssetFamily.realEstateVehicle
            : AssetFamily.equity)
      : family;
  return InstrumentIdentity(
    providerAssetId: isMarketAsset
        ? 'manual-${currency.isoCode.toLowerCase()}-${normalizedSymbol.toLowerCase()}'
        : 'manual-${DateTime.now().microsecondsSinceEpoch}',
    family: inferredFamily,
    symbol: normalizedSymbol,
    officialName: officialName.trim().isEmpty
        ? normalizedSymbol
        : officialName.trim(),
    exchangeMic: looksLikeBrazilianTicker
        ? 'BVMF'
        : looksLikeUsTicker
        ? 'XNAS'
        : 'MANUAL',
    countryCode: looksLikeBrazilianTicker
        ? 'BR'
        : looksLikeUsTicker
        ? 'US'
        : 'XX',
    currency: currency,
  );
}
