import 'budget_usage.dart';
import 'budget_period_range.dart';

class NamedAmount {
  const NamedAmount({required this.name, required this.amount, this.colorHex});

  final String name;
  final int amount;
  final String? colorHex;
}

class DailyAmount {
  const DailyAmount({required this.date, required this.amount});

  final DateTime date;
  final int amount;
}

class ReportSummary {
  const ReportSummary({
    required this.totalExpense,
    required this.totalIncome,
    required this.remainingBudget,
    required this.period,
    required this.budgetUsages,
    required this.dailyAmounts,
    required this.paymentMethodAmounts,
  });

  final int totalExpense;
  final int totalIncome;
  final int remainingBudget;
  final BudgetPeriodRange period;
  final List<BudgetUsage> budgetUsages;
  final List<DailyAmount> dailyAmounts;
  final List<NamedAmount> paymentMethodAmounts;
}

class AnnualSummary {
  const AnnualSummary({
    required this.year,
    required this.monthlyTotals,
    required this.categoryTotals,
    required this.categoryTrends,
  });

  final int year;
  final List<int> monthlyTotals;
  final List<NamedAmount> categoryTotals;
  final List<CategoryAnnualTrend> categoryTrends;
}

class CategoryAnnualTrend {
  const CategoryAnnualTrend({
    required this.name,
    required this.colorHex,
    required this.monthlyAmounts,
  });

  final String name;
  final String colorHex;
  final List<int> monthlyAmounts;
}
