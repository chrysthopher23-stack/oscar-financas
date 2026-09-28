import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:flutter/services.dart';
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../shared/controllers/financial_visibility_controller.dart';
import '../../../shared/controllers/month_controller.dart';
import '../../../shared/formatting/currency_amount_input_formatter.dart';
import '../../../shared/formatting/installment_formatter.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../../../shared/widgets/bounded_modal_sheet.dart';
import '../../../shared/widgets/demo_display_names.dart';
import '../../screen_2_extra_income/screen_2_extra_income.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../application/financial_view_model.dart';
import '../domain/financial_repository.dart';
import '../domain/financial_transaction.dart';
import 'widgets/expense_donut.dart';
import 'widgets/financial_overview_chart.dart';
import 'widgets/oscar_score_gauge.dart';

part 'widgets/financial_page_sections.dart';

final class FinancialPage extends StatefulWidget {
  const FinancialPage({
    super.key,
    required this.onDestinationSelected,
    required this.visibilityController,
    required this.repository,
    required this.extraIncomePort,
    required this.currency,
    required this.fxRepository,
    this.initialMonth,
    this.minimumMonth,
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final FinancialVisibilityController visibilityController;
  final FinancialRepository repository;
  final ExtraIncomeContributionPort extraIncomePort;
  final CurrencyCode currency;
  final FxRepository fxRepository;
  final YearMonth? initialMonth;
  final YearMonth? minimumMonth;

  @override
  State<FinancialPage> createState() => _FinancialPageState();
}

final class _FinancialPageState extends State<FinancialPage> {
  late final MonthController _monthController;
  late final FinancialViewModel _viewModel;
  Timer? _undoExpiryTimer;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _undoSnackController;

  @override
  void initState() {
    super.initState();
    _monthController = MonthController(
      initialMonth: widget.initialMonth,
      minimumMonth: widget.minimumMonth,
      currentMonthFloor: true,
    );
    _viewModel = FinancialViewModel(
      repository: widget.repository,
      extraIncomePort: widget.extraIncomePort,
      monthController: _monthController,
      currency: widget.currency,
      fxRepository: widget.fxRepository,
    )..load();
  }

  @override
  void dispose() {
    _undoExpiryTimer?.cancel();
    _undoSnackController?.close();
    _viewModel.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = MoneyFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: widget.currency,
    );
    return OscarFeatureScaffold(
      destination: AppDestination.financial,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.financialMonth,
      monthController: _monthController,
      visibilityController: widget.visibilityController,
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, widget.visibilityController]),
        builder: (context, _) => _FinancialFooter(
          state: _viewModel.state,
          formatter: formatter,
          valuesHidden: widget.visibilityController.valuesHidden,
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, widget.visibilityController]),
        builder: (context, _) {
          final state = _viewModel.state;
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == FinancialLoadStatus.failure) {
            return _ErrorState(onRetry: _viewModel.load);
          }
          final hidden = widget.visibilityController.valuesHidden;
          final incomes = state.transactions
              .where((item) => item.kind == TransactionKind.income)
              .toList();
          final expenses = state.transactions
              .where((item) => item.kind == TransactionKind.expense)
              .toList();
          final installments = expenses
              .where((item) => item.installmentLabel != null)
              .toList();
          final regularExpenses = expenses
              .where((item) => item.installmentLabel == null)
              .toList();
          final totalBasisPoints = state.summary.grossIncomeMinor == 0
              ? 0
              : (state.summary.expenseMinor * 10000) ~/
                    state.summary.grossIncomeMinor;

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              children: [
                FinancialOverviewChart(
                  summaries: state.chartSummaries,
                  formatter: formatter,
                  valuesHidden: hidden,
                ),
                _TransactionSection(
                  title: 'Entradas',
                  emptyText: 'Nenhuma entrada neste mês.',
                  actionLabel: 'Adicionar entrada',
                  transactions: incomes,
                  extraServicesMinor: state.extraServicesMinor,
                  extraSalesMinor: state.extraSalesMinor,
                  formatter: formatter,
                  valuesHidden: hidden,
                  onAdd: () => _showTransactionForm(TransactionKind.income),
                  onOpen: (item) => _showTransactionDetails(item, formatter),
                ),
                _TransactionSection(
                  title: 'Gastos',
                  emptyText: 'Nenhum gasto neste mês.',
                  actionLabel: 'Adicionar gasto',
                  transactions: regularExpenses,
                  formatter: formatter,
                  valuesHidden: hidden,
                  onAdd: () => _showTransactionForm(TransactionKind.expense),
                  onOpen: (item) => _showTransactionDetails(item, formatter),
                ),
                _TransactionSection(
                  title: 'Parcelas Longas',
                  emptyText: 'Nenhuma parcela neste mês.',
                  actionLabel: 'Adicionar parcela',
                  transactions: installments,
                  formatter: formatter,
                  valuesHidden: hidden,
                  onAdd: () => _showTransactionForm(
                    TransactionKind.expense,
                    longInstallment: true,
                  ),
                  onOpen: (item) => _showTransactionDetails(item, formatter),
                ),
                const SizedBox(height: 20),
                Text(
                  'Participação das despesas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ExpenseDonut(
                  shares: state.expenseShares,
                  totalBasisPoints: totalBasisPoints,
                  formatter: formatter,
                  valuesHidden: hidden,
                ),
                const SizedBox(height: 20),
                OscarScoreGauge(result: state.score),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTransactionForm(
    TransactionKind kind, {
    FinancialTransaction? existing,
    bool longInstallment = false,
  }) async {
    final isInstallment = longInstallment || existing?.installmentLabel != null;
    final locale = Localizations.localeOf(context).toString();
    final title = TextEditingController(text: existing?.title ?? '');
    final amount = TextEditingController(
      text: existing == null
          ? ''
          : formatCurrencyInputMinor(existing.originalAmountMinor, locale),
    );
    var recurring = existing?.recurring ?? false;
    var discountType = existing?.discountType ?? DiscountType.none;
    final discount = TextEditingController(
      text: existing == null || existing.discountType == DiscountType.none
          ? ''
          : existing.discountType == DiscountType.percentage
          ? (existing.discountValue / 100).toString()
          : formatCurrencyInputMinor(existing.discountValue, locale),
    );
    final savedProgress = parseInstallmentProgress(existing?.installmentLabel);
    final currentInstallment = TextEditingController(
      text: savedProgress?.current.toString() ?? '1',
    );
    final totalInstallments = TextEditingController(
      text: savedProgress?.total.toString() ?? '',
    );
    await showOscarBoundedModalSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                  isInstallment
                      ? existing == null
                            ? 'Nova parcela'
                            : 'Editar parcela'
                      : existing != null
                      ? kind == TransactionKind.income
                            ? 'Editar entrada'
                            : 'Editar gasto'
                      : kind == TransactionKind.income
                      ? 'Nova entrada'
                      : 'Novo gasto',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Nome'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [CurrencyAmountInputFormatter(locale)],
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Valor'),
                    prefixText: '${widget.currency.symbol} ',
                  ),
                ),
                if (isInstallment) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: currentInstallment,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Parcela atual'),
                      hintText: '5',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: totalInstallments,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Total de parcelas'),
                      hintText: '36',
                    ),
                  ),
                ],
                if (kind == TransactionKind.expense) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DiscountType>(
                    isExpanded: true,
                    initialValue: discountType,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Desconto'),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DiscountType.none,
                        child: Text('Sem desconto'),
                      ),
                      DropdownMenuItem(
                        value: DiscountType.fixed,
                        child: Text('Valor fixo'),
                      ),
                      DropdownMenuItem(
                        value: DiscountType.percentage,
                        child: Text('Percentual'),
                      ),
                    ],
                    onChanged: (value) => setSheetState(
                      () => discountType = value ?? DiscountType.none,
                    ),
                  ),
                  if (discountType != DiscountType.none) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: discount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: discountType == DiscountType.fixed
                          ? [CurrencyAmountInputFormatter(locale)]
                          : null,
                      decoration: InputDecoration(
                        labelText: discountType == DiscountType.fixed
                            ? 'Valor do desconto'
                            : 'Percentual',
                        suffixText: discountType == DiscountType.percentage
                            ? '%'
                            : null,
                      ),
                    ),
                  ],
                ],
                if (!isInstallment)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recorrente'),
                    value: recurring,
                    onChanged: (value) =>
                        setSheetState(() => recurring = value),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final amountMinor = parseCurrencyMinor(
                            amount.text,
                            locale,
                          );
                          String? installmentLabel;
                          if (isInstallment) {
                            final current =
                                int.tryParse(currentInstallment.text) ?? 0;
                            final total =
                                int.tryParse(totalInstallments.text) ?? 0;
                            if (current < 1 || total < current) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    uiText(
                                      context,
                                      'Informe uma parcela válida, como 5 de 36.',
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }
                            installmentLabel = encodeInstallmentProgress(
                              current,
                              total,
                            );
                          }
                          final discountValue =
                              discountType == DiscountType.percentage
                              ? (_parseDecimalPercentageBasisPoints(
                                  discount.text,
                                ))
                              : parseCurrencyMinor(discount.text, locale);
                          if (existing == null) {
                            await _viewModel.addTransaction(
                              title: title.text,
                              amountMinor: amountMinor,
                              kind: kind,
                              discountType: discountType,
                              discountValue: discountValue,
                              recurring: isInstallment ? false : recurring,
                              installmentLabel: installmentLabel,
                            );
                          } else {
                            await _viewModel.updateTransaction(
                              existing: existing,
                              title: title.text,
                              amountMinor: amountMinor,
                              discountType: discountType,
                              discountValue: discountValue,
                              recurring: isInstallment ? false : recurring,
                              installmentLabel: installmentLabel,
                            );
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    title.dispose();
    amount.dispose();
    discount.dispose();
    currentInstallment.dispose();
    totalInstallments.dispose();
  }

  Future<void> _showTransactionDetails(
    FinancialTransaction item,
    MoneyFormatter formatter,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: material.Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: uiText(context, 'Editar'),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 200),
                      );
                      if (!mounted) return;
                      await _showTransactionForm(item.kind, existing: item);
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              Text(formatter.formatMinor(item.netAmountMinor)),
              Text(item.month.databaseKey),
              if (item.installmentLabel != null)
                Text(
                  installmentProgressText(
                    item.installmentLabel!,
                    Localizations.localeOf(context).toLanguageTag(),
                  ),
                ),
              const SizedBox(height: 24),
              const Divider(),
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await _confirmRemoval(
                    item.title,
                    formatter.formatMinor(item.netAmountMinor),
                  );
                  if (!confirmed) return;
                  await _viewModel.remove(item.id);
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  _showUndo(item.id);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmRemoval(String title, String amount) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar exclusão'),
            content: Text('$title · $amount será removido deste mês.'),
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
        ) ??
        false;
  }

  void _showUndo(String id) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    _undoExpiryTimer?.cancel();
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: const Text('Item removido.'),
        action: SnackBarAction(
          label: uiText(context, 'Desfazer'),
          onPressed: () => _viewModel.undoRemove(id),
        ),
      ),
    );
    _undoSnackController = controller;
    _undoExpiryTimer = Timer(const Duration(seconds: 5), controller.close);
    controller.closed.whenComplete(() {
      if (!identical(_undoSnackController, controller)) return;
      _undoExpiryTimer?.cancel();
      _undoExpiryTimer = null;
      _undoSnackController = null;
    });
  }
}

int _parseDecimalPercentageBasisPoints(String input) {
  final normalized = input.replaceAll(',', '.');
  final value = num.tryParse(normalized) ?? 0;
  return (value * 100).round().clamp(0, 10000);
}
