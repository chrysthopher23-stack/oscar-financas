// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../shared/controllers/month_controller.dart';
import '../domain/asset_catalog.dart';
import '../domain/asset_market_series.dart';
import '../domain/asset_family.dart';
import '../domain/crypto_amount.dart';
import '../domain/fx_quote_set.dart';
import '../domain/instrument_identity.dart';
import '../domain/investment_health.dart';
import '../domain/investment_holding.dart';
import '../domain/investment_portfolio_history.dart';
import '../domain/investment_position.dart';
import '../domain/investment_repository.dart';

enum InvestmentArea { fixedIncome, realEstate, equitiesEtfs, crypto }

final class InvestmentsState {
  const InvestmentsState({
    this.loading = true,
    this.positions = const [],
    this.searchResults = const [],
    this.area = InvestmentArea.fixedIncome,
    this.marketSeries = const {},
    this.fx,
    this.error,
  });

  final bool loading;
  final List<InvestmentPosition> positions;
  final List<InstrumentIdentity> searchResults;
  final InvestmentArea area;
  final Map<String, AssetMarketSeries> marketSeries;
  final FxQuoteSet? fx;
  final String? error;

  InvestmentsState copyWith({
    bool? loading,
    List<InvestmentPosition>? positions,
    List<InstrumentIdentity>? searchResults,
    InvestmentArea? area,
    Map<String, AssetMarketSeries>? marketSeries,
    FxQuoteSet? fx,
    String? error,
    bool clearError = false,
  }) => InvestmentsState(
    loading: loading ?? this.loading,
    positions: positions ?? this.positions,
    searchResults: searchResults ?? this.searchResults,
    area: area ?? this.area,
    marketSeries: marketSeries ?? this.marketSeries,
    fx: fx ?? this.fx,
    error: clearError ? null : error ?? this.error,
  );
}

final class InvestmentsViewModel extends ChangeNotifier {
  InvestmentsViewModel({
    required InvestmentRepository repository,
    required AssetCatalogRepository catalog,
    required FxRepository fxRepository,
    required AssetMarketRepository marketRepository,
    required MonthController monthController,
    required CurrencyCode baseCurrency,
  }) : _repository = repository,
       _catalog = catalog,
       _fxRepository = fxRepository,
       _marketRepository = marketRepository,
       _monthController = monthController,
       _baseCurrency = baseCurrency {
    _monthController.addListener(load);
  }

  final InvestmentRepository _repository;
  final AssetCatalogRepository _catalog;
  final FxRepository _fxRepository;
  final AssetMarketRepository _marketRepository;
  final MonthController _monthController;
  final CurrencyCode _baseCurrency;
  InvestmentsState state = const InvestmentsState();
  int _searchRevision = 0;
  int _loadRevision = 0;

  YearMonth get month => _monthController.focusedMonth;

  Future<void> load({bool waitForMarket = false}) async {
    final revision = ++_loadRevision;
    final selectedMonth = month;
    state = state.copyWith(loading: true, clearError: true);
    notifyListeners();
    try {
      final positions = await _repository.listForMonth(selectedMonth);
      if (revision != _loadRevision) return;
      state = state.copyWith(loading: false, positions: positions);
      notifyListeners();
      final refresh = _refreshMarketData(
        revision,
        positions,
        forceRefresh: waitForMarket,
      );
      if (waitForMarket) {
        await refresh;
      } else {
        unawaited(refresh);
      }
      return;
    } catch (_) {
      if (revision != _loadRevision) return;
      state = state.copyWith(
        loading: false,
        error: 'Não foi possível carregar os investimentos.',
      );
    }
    notifyListeners();
  }

  Future<void> _refreshMarketData(
    int revision,
    List<InvestmentPosition> positions, {
    required bool forceRefresh,
  }) async {
    try {
      final historicalMonth = month.compareTo(YearMonth.now()) < 0;
      final results = await Future.wait<Object?>([
        _fxRepository.latest(_baseCurrency, forceRefresh: forceRefresh),
        historicalMonth
            ? Future.value(<String, AssetMarketSeries>{})
            : _marketRepository.latestFor(
                positions.map((position) => position.identity).toList(),
                forceRefresh: forceRefresh,
              ),
      ]);
      if (revision != _loadRevision) return;
      state = state.copyWith(
        fx: results[0] as FxQuoteSet?,
        marketSeries: results[1]! as Map<String, AssetMarketSeries>,
      );
      notifyListeners();
    } catch (_) {
      // Market data is optional: never block investments already stored locally.
    }
  }

  Future<void> search(String query) async {
    final revision = ++_searchRevision;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (revision != _searchRevision) return;
    final results = await _catalog.search(query);
    if (revision != _searchRevision) return;
    state = state.copyWith(searchResults: results);
    notifyListeners();
  }

  void clearSearch() {
    _searchRevision++;
    state = state.copyWith(searchResults: const []);
    notifyListeners();
  }

  void selectArea(InvestmentArea value) {
    state = state.copyWith(area: value);
    notifyListeners();
  }

  Future<void> addPosition({
    required InstrumentIdentity identity,
    required int principalMinor,
    required int monthlyReturnMinor,
    required bool manual,
    String? quantity,
  }) async {
    final now = DateTime.now().toUtc();
    await _repository.save(
      InvestmentPosition(
        id: 'position-${now.microsecondsSinceEpoch}',
        identity: identity,
        principalMinor: principalMinor,
        monthlyReturnMinor: monthlyReturnMinor,
        quantity: quantity,
        month: month,
        source: manual ? 'manual' : 'catalog',
        createdAt: now,
        updatedAt: now,
      ),
    );
    clearSearch();
    await load();
  }

  Future<void> remove(InvestmentPosition position) async {
    await _repository.softDelete(position.id, DateTime.now().toUtc());
    await load();
  }

  Future<void> restore(InvestmentPosition position) async {
    await _repository.restore(position.id);
    await load();
  }

  List<InvestmentPosition> get displayPositions =>
      state.positions.map(_toBasePosition).toList(growable: false);

  List<InvestmentHolding> get displayHoldings =>
      InvestmentHolding.group(displayPositions);

  List<PortfolioHistoryPoint> get portfolioHistory => buildPortfolioHistory(
    displayPositions,
    throughMonth: month,
    monthCount: null,
  );

  Map<String, List<int>> get recordedAssetHistories {
    final positions = displayPositions;
    final ids = positions
        .map((position) => position.identity.providerAssetId)
        .toSet();
    return {
      for (final id in ids)
        id: buildPortfolioHistory(
          positions.where(
            (position) => position.identity.providerAssetId == id,
          ),
          throughMonth: month,
          monthCount: 6,
        ).map((point) => point.valueMinor).toList(growable: false),
    };
  }

  List<InvestmentHolding> get filteredHoldings => displayHoldings
      .where((position) {
        return switch (state.area) {
          InvestmentArea.fixedIncome => {
            AssetFamily.governmentBond,
            AssetFamily.bankFixedIncome,
            AssetFamily.corporateBond,
          }.contains(position.identity.family),
          InvestmentArea.realEstate =>
            position.identity.family == AssetFamily.realEstateVehicle,
          InvestmentArea.crypto =>
            position.identity.family == AssetFamily.crypto,
          InvestmentArea.equitiesEtfs => {
            AssetFamily.equity,
            AssetFamily.etf,
          }.contains(position.identity.family),
        };
      })
      .toList(growable: false);

  int get totalPrincipalMinor =>
      displayPositions.fold(0, (sum, item) => sum + item.principalMinor);
  int get totalReturnMinor =>
      displayPositions.fold(0, (sum, item) => sum + item.monthlyReturnMinor);
  InvestmentPosition _toBasePosition(InvestmentPosition position) {
    final fx = state.fx;
    final quote = state.marketSeries[position.identity.providerAssetId];
    int? marketMinor;
    if (position.quantity != null &&
        quote?.unitPriceUsd != null &&
        month.compareTo(YearMonth.now()) >= 0) {
      try {
        final usd = CryptoAmount.valueMinor(
          position.quantity!,
          quote!.unitPriceUsd!,
        );
        marketMinor = _baseCurrency == CurrencyCode.usd
            ? usd
            : fx?.convertToBaseMinor(usd, CurrencyCode.usd);
      } on FormatException {
        marketMinor = null;
      }
    }
    int convert(int amount) => position.currency == _baseCurrency
        ? amount
        : fx?.convertToBaseMinor(amount, position.currency) ?? amount;
    return InvestmentPosition(
      id: position.id,
      identity: position.identity,
      principalMinor: convert(position.principalMinor),
      monthlyReturnMinor: convert(position.monthlyReturnMinor),
      quantity: position.quantity,
      marketValueMinor: marketMinor,
      month: position.month,
      createdAt: position.createdAt,
      updatedAt: position.updatedAt,
      source: position.source,
      deletedAt: position.deletedAt,
    );
  }

  int get totalValueMinor =>
      displayPositions.fold(0, (sum, item) => sum + item.currentValueMinor);

  InvestmentHealthSnapshot get health => calculateInvestmentHealth(
    month: month,
    openingPrincipalMinor: totalPrincipalMinor,
    nominalReturnMinor: totalReturnMinor,
    monthlyInflationScaled: 4000000,
    referenceMonth: month.addMonths(-1),
    sourceStatus: 'estimativa local; índice oficial pendente de atualização',
  );

  @override
  void dispose() {
    _loadRevision++;
    _searchRevision++;
    _monthController.removeListener(load);
    super.dispose();
  }
}
