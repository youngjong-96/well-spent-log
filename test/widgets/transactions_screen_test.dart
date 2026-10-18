import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/features/transactions/transactions_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('내역 탭은 목록과 달력을 전환하고 필터와 네 가지 정렬을 제공한다', (tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final controller = TransactionsScreenController();
    addTearDown(controller.dispose);
    final records = [
      TransactionRecord(
        id: 1,
        type: RecordType.expense,
        occurredAt: DateTime(now.year, now.month, 1),
        amount: 30000,
        memo: '큰 식비',
        accountId: 1,
        accountName: '현금',
        categoryId: 1,
        categoryName: '식비',
      ),
      TransactionRecord(
        id: 2,
        type: RecordType.expense,
        occurredAt: DateTime(now.year, now.month, 2),
        amount: 5000,
        memo: '작은 교통비',
        accountId: 1,
        accountName: '현금',
        categoryId: 2,
        categoryName: '교통',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthTransactionsProvider.overrideWith((ref, month) async => records),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: TransactionsScreen(controller: controller)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('내역'), findsOneWidget);
    expect(find.text('지출 검색'), findsOneWidget);
    expect(find.text('날짜 최신 순'), findsOneWidget);
    expect(find.text('작은 교통비'), findsOneWidget);

    await tester.tap(find.text('날짜 최신 순'));
    await tester.pumpAndSettle();
    expect(find.text('날짜 오래된 순'), findsOneWidget);
    expect(find.text('금액 높은 순'), findsOneWidget);
    expect(find.text('금액 낮은 순'), findsOneWidget);
    await tester.tap(find.text('금액 낮은 순'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('작은 교통비')).dy,
      lessThan(tester.getTopLeft(find.text('큰 식비')).dy),
    );

    controller.openCategory(1);
    await tester.pumpAndSettle();
    expect(find.text('큰 식비'), findsOneWidget);
    expect(find.text('작은 교통비'), findsNothing);

    await tester.tap(find.text('달력'));
    await tester.pumpAndSettle();
    expect(find.text('오늘'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
