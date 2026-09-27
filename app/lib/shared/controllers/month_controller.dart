import 'package:flutter/foundation.dart';

import '../../core/time/year_month.dart';

final class MonthController extends ChangeNotifier {
  MonthController({
    YearMonth? initialMonth,
    this.minimumMonth,
    this.currentMonthFloor = false,
  }) : _focusedMonth = initialMonth ?? YearMonth.now();

  final YearMonth? minimumMonth;
  final bool currentMonthFloor;
  YearMonth? get _effectiveMinimum {
    final current = YearMonth.now();
    if (!currentMonthFloor) return minimumMonth;
    final recorded = minimumMonth;
    return recorded != null && recorded.compareTo(current) < 0
        ? recorded
        : current;
  }

  bool get canGoPrevious =>
      _effectiveMinimum == null ||
      focusedMonth.compareTo(_effectiveMinimum!) > 0;

  YearMonth _focusedMonth;
  YearMonth get focusedMonth {
    final floor = _effectiveMinimum;
    if (floor != null && _focusedMonth.compareTo(floor) < 0) {
      _focusedMonth = floor;
    }
    return _focusedMonth;
  }

  void changeMonth(int offset) {
    if (offset == 0) return;
    final target = focusedMonth.addMonths(offset);
    final floor = _effectiveMinimum;
    if (floor != null && target.compareTo(floor) < 0) return;
    _focusedMonth = target;
    notifyListeners();
  }
}
