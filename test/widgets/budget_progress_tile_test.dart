import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/domain/models/budget_usage.dart';
import 'package:well_spent_log/src/domain/models/money.dart';
import 'package:well_spent_log/src/shared/widgets/budget_progress_tile.dart';

void main() {
  testWidgets('shows a percentage and toggles when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BudgetProgressTile(
            usage: const BudgetUsage(
              categoryId: 1,
              categoryName: '식비',
              spentAmount: Money(400000),
              budgetAmount: Money(500000),
              colorHex: '#7A5CFA',
            ),
            showAmount: false,
            onToggleDisplay: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('식비'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);

    await tester.tap(find.byType(BudgetProgressTile));
    expect(tapped, isTrue);
  });
}
