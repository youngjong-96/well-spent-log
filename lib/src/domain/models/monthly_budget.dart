class MonthlyBudget {
  const MonthlyBudget({
    required this.periodId,
    required this.categoryId,
    required this.amount,
  });

  final int periodId;
  final int categoryId;
  final int amount;
}

class BudgetPeriod {
  const BudgetPeriod({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.monthStartDay,
  });

  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final int monthStartDay;
}
