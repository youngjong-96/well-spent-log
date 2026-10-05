import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/domain/usecases/calculate_budget_period.dart';

void main() {
  const calculate = CalculateBudgetPeriod();

  group('CalculateBudgetPeriod', () {
    test('uses the first and last day of the anchor month', () {
      final range = calculate(anchorDate: DateTime(2026, 7, 30));

      expect(range.startDate, DateTime(2026, 7));
      expect(range.endDate, DateTime(2026, 7, 31));
    });

    test('uses the leap-day month end in February', () {
      final range = calculate(anchorDate: DateTime(2028, 2, 14));

      expect(range.startDate, DateTime(2028, 2));
      expect(range.endDate, DateTime(2028, 2, 29));
    });

    test('normalizes the time component of the anchor date', () {
      final range = calculate(anchorDate: DateTime(2026, 4, 1, 23, 59, 59));

      expect(range.startDate, DateTime(2026, 4));
      expect(range.endDate, DateTime(2026, 4, 30));
    });
  });
}
