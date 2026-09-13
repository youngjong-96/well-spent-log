import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/domain/models/home_summary.dart';
import 'package:well_spent_log/src/domain/models/budget_period_range.dart';
import 'package:well_spent_log/src/domain/models/money.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/features/home/home_screen.dart';
import 'package:well_spent_log/src/shared/widgets/transaction_list_tile.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets(
    'home paginates ten records and clamps page when records disappear',
    (tester) async {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var count = 21;
      final container = ProviderContainer(
        overrides: [
          homeSummaryProvider.overrideWith(
            (ref) async => HomeSummary(
              totalBalance: const Money(999999),
              monthlyExpense: const Money(231000),
              month: DateTime(2026, 8),
              budgetUsages: const [],
              period: BudgetPeriodRange(
                startDate: DateTime(2026, 8),
                endDate: DateTime(2026, 8, 31),
              ),
              monthStartDay: 1,
              monthlyTransactions: [
                for (var i = count; i > 0; i--)
                  TransactionRecord(
                    id: i,
                    type: RecordType.expense,
                    occurredAt: DateTime(2026, 8, 1),
                    amount: i * 1000,
                    memo: 'record $i',
                    accountId: 1,
                    accountName: 'cash',
                  ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이번 달 지출 합계'), findsOneWidget);
      expect(find.text('231,000원'), findsOneWidget);
      expect(find.text('현재 총잔액'), findsNothing);
      expect(find.byType(TransactionListTile), findsNWidgets(10));
      expect(find.text('record 21'), findsOneWidget);
      Future<void> next() async {
        await tester.scrollUntilVisible(find.text('다음'), 400);
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }

      await tester.scrollUntilVisible(find.text('1 / 3 페이지'), 400);
      await next();
      expect(find.text('2 / 3 페이지'), findsOneWidget);
      expect(find.byType(TransactionListTile), findsNWidgets(10));
      expect(find.text('record 11'), findsOneWidget);
      await next();
      expect(find.text('3 / 3 페이지'), findsOneWidget);
      expect(find.byType(TransactionListTile), findsOneWidget);
      expect(find.text('record 1'), findsOneWidget);
      count = 20;
      container.invalidate(homeSummaryProvider);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('2 / 2 페이지'), 400);
      expect(find.text('2 / 2 페이지'), findsOneWidget);
      count = 0;
      container.invalidate(homeSummaryProvider);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('이번 달 지출 내역이 없어요.'), 400);
      expect(find.byType(TransactionListTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
