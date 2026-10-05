import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/domain/models/budget_period_range.dart';
import 'package:well_spent_log/src/domain/models/report_summary.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/features/report/report_screen.dart';
import 'package:well_spent_log/src/shared/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('월간 보고서는 요약 카드, 막대 툴팁, 표 보기를 제공한다', (tester) async {
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final firstExpense = TransactionRecord(
      id: 1,
      type: RecordType.expense,
      occurredAt: DateTime(now.year, now.month, 1),
      amount: 10000,
      memo: '장보기',
      accountId: 1,
      accountName: '현금',
      categoryId: 1,
      categoryName: '식비',
      paymentMethodId: 1,
      paymentMethodName: '현금',
    );
    final largestExpense = TransactionRecord(
      id: 2,
      type: RecordType.expense,
      occurredAt: DateTime(now.year, now.month, 2),
      amount: 20000,
      memo: '병원',
      accountId: 1,
      accountName: '현금',
      categoryId: 2,
      categoryName: '건강',
      paymentMethodId: 1,
      paymentMethodName: '현금',
    );
    final report = ReportSummary(
      totalExpense: 30000,
      previousMonthExpense: 20000,
      totalIncome: 0,
      remainingBudget: 70000,
      period: BudgetPeriodRange(
        startDate: month,
        endDate: DateTime(now.year, now.month + 1, 0),
      ),
      budgetUsages: const [],
      dailyAmounts: [
        DailyAmount(date: firstExpense.occurredAt, amount: 10000),
        DailyAmount(date: largestExpense.occurredAt, amount: 20000),
      ],
      paymentMethodAmounts: const [NamedAmount(name: '현금', amount: 30000)],
      transactions: [firstExpense, largestExpense],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportProvider.overrideWith((ref, selectedMonth) async => report),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ReportScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('전월 대비'), findsOneWidget);
    expect(find.text('하루 평균 지출'), findsOneWidget);
    expect(find.text('가장 큰 지출'), findsOneWidget);
    expect(find.text('병원'), findsWidgets);

    final tooltipMessage = '${now.month}/1 · ${formatWon(10000)}';
    final barTooltip = find.byWidgetPredicate(
      (widget) => widget is Tooltip && widget.message == tooltipMessage,
    );
    expect(barTooltip, findsOneWidget);
    await tester.tap(barTooltip);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(tooltipMessage), findsOneWidget);

    final amountBefore = find.text(formatWon(10000)).evaluate().length;
    await tester.tap(find.text('표로 보기').first);
    await tester.pumpAndSettle();
    expect(
      find.text(formatWon(10000)).evaluate().length,
      greaterThan(amountBefore),
    );
    expect(tester.takeException(), isNull);
  });
}
