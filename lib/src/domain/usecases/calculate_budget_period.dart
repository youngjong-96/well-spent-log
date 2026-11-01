import '../models/budget_period_range.dart';

class CalculateBudgetPeriod {
  const CalculateBudgetPeriod();

  BudgetPeriodRange call({
    required DateTime anchorDate,
  }) {
    final startDate = DateTime(anchorDate.year, anchorDate.month);
    final endDate = DateTime(anchorDate.year, anchorDate.month + 1, 0);

    return BudgetPeriodRange(
      startDate: startDate,
      endDate: endDate,
    );
  }
}
