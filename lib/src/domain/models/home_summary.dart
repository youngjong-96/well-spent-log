import 'budget_usage.dart';
import 'budget_period_range.dart';
import 'money.dart';
import 'transaction_record.dart';

class HomeSummary {
  const HomeSummary({
    required this.totalBalance,
    required this.month,
    required this.monthlyExpense,
    required this.budgetUsages,
    required this.period,
    required this.monthStartDay,
    required this.monthlyTransactions,
  });

  final Money totalBalance;
  final DateTime month;
  final Money monthlyExpense;
  final List<BudgetUsage> budgetUsages;
  final BudgetPeriodRange period;
  final int monthStartDay;
  final List<TransactionRecord> monthlyTransactions;

  static final empty = HomeSummary(
    totalBalance: Money.zero,
    month: DateTime(2000),
    monthlyExpense: Money.zero,
    budgetUsages: const [],
    period: BudgetPeriodRange(
      startDate: DateTime(2000),
      endDate: DateTime(2000),
    ),
    monthStartDay: 1,
    monthlyTransactions: const [],
  );
}
