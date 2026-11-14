import '../models/transaction_record.dart';

class WeeklyTotal {
  const WeeklyTotal({
    required this.start,
    required this.end,
    required this.amount,
  });

  final DateTime start;
  final DateTime end;
  final int amount;

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

/// Sunday-start calendar weeks, clipped to the displayed month.
List<WeeklyTotal> calculateWeeklyTotals(
  DateTime month,
  List<TransactionRecord> records,
) {
  final first = DateTime(month.year, month.month);
  final last = DateTime(month.year, month.month + 1, 0);
  final weeks = <WeeklyTotal>[];
  var start = first;
  while (!start.isAfter(last)) {
    final saturday = DateTime(
      start.year,
      start.month,
      start.day + 6 - start.weekday % 7,
    );
    final end = saturday.isAfter(last) ? last : saturday;
    final endExclusive = DateTime(end.year, end.month, end.day + 1);
    final amount = records
        .where(
          (record) =>
              !record.isDeleted &&
              !record.occurredAt.isBefore(start) &&
              record.occurredAt.isBefore(endExclusive),
        )
        .fold<int>(0, (sum, record) => sum - record.signedAmount);
    weeks.add(WeeklyTotal(start: start, end: end, amount: amount));
    start = endExclusive;
  }
  return weeks;
}
