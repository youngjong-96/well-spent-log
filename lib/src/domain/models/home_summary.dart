import 'budget_usage.dart';
import 'budget_period_range.dart';
import 'money.dart';
import 'transaction_record.dart';

class HomeSummary {
  const HomeSummary({
    required this.month,
    required this.monthlyExpense,
    required this.budgetUsages,
    required this.period,
    required this.monthlyTransactions,
  });

  final DateTime month;
  final Money monthlyExpense;
  final List<BudgetUsage> budgetUsages;
  final BudgetPeriodRange period;
  final List<TransactionRecord> monthlyTransactions;

  static final empty = HomeSummary(
    month: DateTime(2000),
    monthlyExpense: Money.zero,
    budgetUsages: const [],
    period: BudgetPeriodRange(
      startDate: DateTime(2000),
      endDate: DateTime(2000),
    ),
    monthlyTransactions: const [],
  );
}
