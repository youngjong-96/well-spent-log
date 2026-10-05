import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/features/calendar/calendar_screen.dart';
import 'package:well_spent_log/src/shared/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

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
}
