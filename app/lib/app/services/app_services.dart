import '../../core/money/money.dart';
import '../../core/time/year_month.dart';
import '../../features/screen_1_financial/domain/financial_repository.dart';
import '../../features/screen_2_extra_income/application/extra_income_contribution_port.dart';
import '../../features/screen_2_extra_income/domain/extra_income_repository.dart';
import '../../features/screen_3_investments/domain/investment_repository.dart';
import '../../features/screen_4_objectives/domain/objective_repository.dart';
import '../../features/screen_6_agenda/application/notification_contracts.dart';
import '../../features/screen_6_agenda/domain/agenda_repository.dart';

abstract interface class AppServices {
  Future<void> ensureInitialDemoData({
    required YearMonth month,
    required CurrencyCode currency,
  });
  Future<void> resetPersonalHistory();
  Future<YearMonth?> earliestRecordedMonth();
  FinancialRepository get financialRepository;
  ExtraIncomeRepository get extraIncomeRepository;
  ExtraIncomeContributionPort get extraIncomeContributionPort;
  InvestmentRepository get investmentRepository;
  ObjectiveRepository get objectiveRepository;
  AgendaRepository get agendaRepository;
  LocalNotificationScheduler get notificationScheduler;
}
