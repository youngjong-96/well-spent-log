import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/domain/usecases/calculate_weekly_totals.dart';

TransactionRecord record(
  DateTime date,
  int amount, {
  RecordType type = RecordType.expense,
  bool deleted = false,
}) => TransactionRecord(
  id: 1,
  type: type,
  occurredAt: date,
  amount: amount,
  memo: '',
  deletedAt: deleted ? date : null,
);

void main() {
  test('Sunday weeks clip month edges and omit empty trailing weeks', () {
    final weeks = calculateWeeklyTotals(DateTime(2026, 11), []);
    expect(weeks.length, 5);
    expect(weeks.first.start, DateTime(2026, 11, 1));
    expect(weeks.first.end, DateTime(2026, 11, 7));
    expect(weeks.last.start, DateTime(2026, 11, 29));
    expect(weeks.last.end, DateTime(2026, 11, 30));
    expect(calculateWeeklyTotals(DateTime(2026, 2), []).length, 4);
  });

  test('partial first week and real sixth week are retained', () {
    final weeks = calculateWeeklyTotals(DateTime(2026, 8), []);
    expect(weeks.length, 6);
    expect(weeks.first.start, DateTime(2026, 8, 1));
    expect(weeks.first.end, DateTime(2026, 8, 1));
    expect(weeks.last.start, DateTime(2026, 8, 30));
    expect(weeks.last.end, DateTime(2026, 8, 31));
    final leap = calculateWeeklyTotals(DateTime(2024, 2), []);
    expect(leap.last.end, DateTime(2024, 2, 29));
    final december = calculateWeeklyTotals(DateTime(2026, 12), []);
    expect(december.last.end, DateTime(2026, 12, 31));
  });

  test('refunds use their own date and deleted/outside records are excluded', () {
    final weeks = calculateWeeklyTotals(DateTime(2026, 11), [
      record(DateTime(2026, 10, 31), 9000),
      record(DateTime(2026, 11, 7, 23, 59, 59), 10000),
      record(DateTime(2026, 11, 8), 2000),
      record(DateTime(2026, 11, 8), 3000, type: RecordType.refund),
      record(DateTime(2026, 11, 9), 8000, deleted: true),
      record(DateTime(2026, 11, 30, 23, 59, 59), 500),
      record(DateTime(2026, 12, 1), 9000),
    ]);
    expect(weeks.map((week) => week.amount), [10000, -1000, 0, 0, 500]);
    expect(weeks.fold<int>(0, (sum, week) => sum + week.amount), 9500);
    expect(weeks[1].contains(DateTime(2026, 11, 14, 23, 59)), isTrue);
    expect(weeks[1].contains(DateTime(2026, 11, 15)), isFalse);
  });
}
