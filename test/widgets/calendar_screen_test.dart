import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/features/calendar/calendar_screen.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/shared/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets('주별 합계 표시와 숨기기 (${dark ? 'dark' : 'light'})', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthTransactionsProvider.overrideWith((ref, month) async => []),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: Scaffold(body: CalendarScreen(month: DateTime(2026, 11))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('주별 합계 숨기기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('weekly-total-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('weekly-total-6')), findsNothing);
      expect(find.text('이달 0원'), findsOneWidget);
      await tester.tap(find.byTooltip('주별 합계 숨기기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekly-total-1')), findsNothing);
      expect(find.byTooltip('주별 합계 표시'), findsOneWidget);
      await tester.tap(find.byTooltip('주별 합계 표시'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekly-total-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('달력은 좌우 스와이프로 월을 바꾸고 오늘로 돌아온다', (tester) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthTransactionsProvider.overrideWith((ref, month) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: CalendarScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(formatMonth(currentMonth)), findsOneWidget);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text(formatMonth(nextMonth)), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '오늘'));
    await tester.pumpAndSettle();
    expect(find.text(formatMonth(currentMonth)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar cells fit expenses at 320 dp with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final month = DateTime(2024, 2);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthTransactionsProvider.overrideWith(
            (ref, _) async => [
              TransactionRecord(
                id: 1,
                type: RecordType.expense,
                occurredAt: month,
                amount: 10,
                memo: '',
                categoryColorHex: '#84B6E2',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: CalendarScreen(month: month)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
