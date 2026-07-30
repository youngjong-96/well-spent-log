import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/domain/usecases/calculate_budget_period.dart';

void main() {
  const calculate = CalculateBudgetPeriod();

  group('CalculateBudgetPeriod', () {
    test('uses the first day for a calendar month budget', () {
      final range = calculate(
        anchorDate: DateTime(2026, 7, 30),
        monthStartDay: 1,
      );

      expect(range.startDate, DateTime(2026, 7));
      expect(range.endDate, DateTime(2026, 7, 31));
    });

    test('moves to the previous period before the configured start day', () {
      final range = calculate(
        anchorDate: DateTime(2026, 7, 20),
        monthStartDay: 25,
      );

      expect(range.startDate, DateTime(2026, 6, 25));
      expect(range.endDate, DateTime(2026, 7, 24));
    });

    test('clamps a day that does not exist in a short month', () {
      final range = calculate(
        anchorDate: DateTime(2027, 2, 28),
        monthStartDay: 31,
      );

      expect(range.startDate, DateTime(2027, 2, 28));
      expect(range.endDate, DateTime(2027, 3, 30));
    });

    test('rejects a start day outside the supported range', () {
      expect(
        () => calculate(anchorDate: DateTime(2026, 7, 30), monthStartDay: 0),
        throwsArgumentError,
      );
    });
  });
}
