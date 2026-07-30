import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/domain/models/budget_usage.dart';
import 'package:well_spent_log/src/domain/models/money.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';

void main() {
  test('calculates budget usage and remaining amount', () {
    const usage = BudgetUsage(
      categoryId: 1,
      categoryName: '식비',
      spentAmount: Money(375000),
      budgetAmount: Money(500000),
      colorHex: '#7A5CFA',
    );

    expect(usage.usedPercent, 75);
    expect(usage.remainingAmount, 125000);
  });

  test('applies the correct account sign for every record type', () {
    expect(RecordType.expense.signedAmount(10000), -10000);
    expect(RecordType.income.signedAmount(10000), 10000);
    expect(RecordType.refund.signedAmount(10000), 10000);
  });
}
