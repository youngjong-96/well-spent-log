import 'budget_usage.dart';
import 'budget_period_range.dart';
import 'money.dart';
import 'transaction_record.dart';

class HomeSummary {
  const HomeSummary({
    required this.totalBalance,
    required this.budgetUsages,
    required this.period,
    required this.monthStartDay,
    required this.recentTransactions,
  });

  final Money totalBalance;
  final List<BudgetUsage> budgetUsages;
  final BudgetPeriodRange period;
  final int monthStartDay;
  final List<TransactionRecord> recentTransactions;

  static final empty = HomeSummary(
    totalBalance: Money.zero,
    budgetUsages: const [],
    period: BudgetPeriodRange(
      startDate: DateTime(2000),
      endDate: DateTime(2000),
    ),
    monthStartDay: 1,
    recentTransactions: const [],
  );
}
