import '../../core/localization/app_locale.dart';
import '../../core/localization/language_brain.dart';

({int current, int total})? parseInstallmentProgress(String? stored) {
  if (stored == null || stored.trim().isEmpty) return null;
  final values = RegExp(r'\d+')
      .allMatches(stored)
      .map((m) => int.parse(m.group(0)!))
      .toList();
  if (values.length < 2 || values[0] < 1 || values[1] < values[0]) return null;
  return (current: values[0], total: values[1]);
}

String encodeInstallmentProgress(int current, int total) => '$current/$total';

int monthsBetween({
  required int fromYear,
  required int fromMonth,
  required int toYear,
  required int toMonth,
}) => (toYear - fromYear) * 12 + toMonth - fromMonth;

({int current, int total})? advanceInstallmentProgress(
  String? stored, {
  required int elapsedMonths,
}) {
  final progress = parseInstallmentProgress(stored);
  if (progress == null || elapsedMonths < 1) return null;
  final next = progress.current + elapsedMonths;
  if (next > progress.total) return null;
  return (current: next, total: progress.total);
}

String installmentProgressText(String stored, String locale) {
  final progress = parseInstallmentProgress(stored);
  if (progress == null) return stored;
  final current = progress.current;
  final total = progress.total;
  return LanguageBrain(SupportedAppLocale.requireTag(locale)).message(
    'Parcela {current} de {total}',
    {'current': '$current', 'total': '$total'},
  );
}
