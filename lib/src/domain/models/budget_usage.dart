import 'money.dart';

class BudgetUsage {
  const BudgetUsage({
    required this.categoryId,
    required this.categoryName,
    required this.spentAmount,
    required this.budgetAmount,
    required this.colorHex,
  });

  final int categoryId;
  final String categoryName;
  final Money spentAmount;
  final Money budgetAmount;
  final String colorHex;

  double get usedRatio {
    if (budgetAmount.amount == 0) {
      return 0;
    }
    return spentAmount.amount / budgetAmount.amount;
  }

  int get usedPercent => (usedRatio * 100).floor();

  int get remainingAmount => budgetAmount.amount - spentAmount.amount;
}
