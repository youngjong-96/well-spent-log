import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/domain/models/budget_period_range.dart';
import 'package:well_spent_log/src/domain/models/budget_usage.dart';
import 'package:well_spent_log/src/domain/models/home_summary.dart';
import 'package:well_spent_log/src/domain/models/money.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/features/home/home_screen.dart';
import 'package:well_spent_log/src/shared/widgets/transaction_list_tile.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('홈은 요약과 예산만 표시하고 카테고리 내역을 바로 연다', (tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? openedCategory;
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final summary = HomeSummary(
      totalBalance: const Money(999999),
      monthlyExpense: const Money(35000),
      month: month,
      budgetUsages: const [
        BudgetUsage(
          categoryId: 1,
          categoryName: '식비',
          spentAmount: Money(30000),
          budgetAmount: Money(100000),
          colorHex: '#84B6E2',
        ),
      ],
      period: BudgetPeriodRange(
        startDate: month,
        endDate: DateTime(month.year, month.month + 1, 0),
      ),
      monthlyTransactions: [
        TransactionRecord(
          id: 1,
          type: RecordType.expense,
          occurredAt: DateTime(month.year, month.month, 2),
          amount: 30000,
          memo: '장보기',
          accountId: 1,
          accountName: '현금',
          categoryId: 1,
          categoryName: '식비',
        ),
        TransactionRecord(
          id: 2,
          type: RecordType.expense,
          occurredAt: DateTime(month.year, month.month, 1),
          amount: 5000,
          memo: '버스',
          accountId: 1,
          accountName: '현금',
          categoryId: 2,
          categoryName: '교통',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeSummaryProvider.overrideWith((ref) async => summary)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeScreen(
              onOpenCategoryDetails: (id) => openedCategory = id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이번 달 남은 예산'), findsOneWidget);
    expect(find.text('65,000원'), findsOneWidget);
    expect(find.text('사용한 금액'), findsOneWidget);
    expect(find.text('전체 예산'), findsOneWidget);
    expect(find.text('35,000원'), findsOneWidget);
    expect(find.text('100,000원'), findsOneWidget);
    expect(find.text('35% 사용'), findsOneWidget);
    expect(find.text('이번 달 진행률'), findsOneWidget);
    expect(find.textContaining('오늘'), findsOneWidget);
    expect(find.text('이번 달 지출 내역'), findsNothing);
    expect(find.byType(TransactionListTile), findsNothing);
    expect(find.text('30%'), findsOneWidget);

    await tester.tap(find.text('식비'));
    await tester.pump();
    expect(find.text('30,000원 / 100,000원'), findsOneWidget);

    await tester.tap(find.text('내역 보기'));
    await tester.pumpAndSettle();
    expect(find.text('장보기'), findsOneWidget);
    expect(find.text('버스'), findsNothing);
    expect(find.text('전체 내역에서 보기'), findsOneWidget);

    await tester.tap(find.text('전체 내역에서 보기'));
    await tester.pumpAndSettle();
    expect(openedCategory, 1);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
