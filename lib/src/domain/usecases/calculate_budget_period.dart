import '../models/budget_period_range.dart';

class CalculateBudgetPeriod {
  const CalculateBudgetPeriod();

  BudgetPeriodRange call({
    required DateTime anchorDate,
    required int monthStartDay,
  }) {
    if (monthStartDay < 1 || monthStartDay > 31) {
      throw ArgumentError.value(monthStartDay, 'monthStartDay');
    }

    final normalizedAnchor = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
    );
    final currentStart = _dateWithClampedDay(
      normalizedAnchor.year,
      normalizedAnchor.month,
      monthStartDay,
    );
    final startDate = normalizedAnchor.isBefore(currentStart)
        ? _dateWithClampedDay(
            normalizedAnchor.year,
            normalizedAnchor.month - 1,
            monthStartDay,
          )
        : currentStart;
    final nextStartDate = _dateWithClampedDay(
      startDate.year,
      startDate.month + 1,
      monthStartDay,
    );

    return BudgetPeriodRange(
      startDate: startDate,
      endDate: nextStartDate.subtract(const Duration(days: 1)),
    );
  }

  DateTime _dateWithClampedDay(int year, int month, int day) {
    final firstDay = DateTime(year, month);
    final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0).day;
    return DateTime(firstDay.year, firstDay.month, day.clamp(1, lastDay));
  }
}
