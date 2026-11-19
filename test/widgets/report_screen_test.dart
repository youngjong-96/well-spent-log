import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
    for (final (family, asset) in [
      (
        'Moneygraphy',
        'assets/fonts/Moneygraphy Font/TTF/Moneygraphy-Rounded.ttf',
      ),
      ('NotoSansKR', 'assets/fonts/NotoSansKR-Variable.ttf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  testWidgets('월간 보고서는 표를 기본으로 보여주고 차트 보기로 전환한다', (tester) async {
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
      categoryId: 2,
      categoryName: '건강',
      paymentMethodId: 1,
      paymentMethodName: '현금',
    );
    final report = ReportSummary(
      totalExpense: 30000,
      previousMonthExpense: 20000,
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
    expect(find.text('지출 상세'), findsNothing);
    expect(find.text(formatWon(10000)), findsWidgets);
    expect(barTooltip, findsNothing);

    await tester.tap(find.text('차트 보기').first);
    await tester.pumpAndSettle();
    expect(barTooltip, findsOneWidget);
    await tester.tap(barTooltip);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(tooltipMessage), findsOneWidget);

    await tester.tap(find.text('표로 보기').first);
    await tester.pumpAndSettle();
    expect(find.text(formatWon(10000)), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale) in [
    for (final width in [320.0, 360.0, 384.0])
      for (final scale in [1.0, 1.3, 1.5]) (width, scale),
    (800.0, 1.5),
  ]) {
    testWidgets('date axes fit at $width dp and scale $scale', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 2400);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reportProvider.overrideWith(
              (ref, month) async => ReportSummary(
                totalExpense: 0,
                previousMonthExpense: 0,
                remainingBudget: 0,
                period: BudgetPeriodRange(
                  startDate: month,
                  endDate: DateTime(month.year, month.month + 1, 0),
                ),
                budgetUsages: const [],
                dailyAmounts: const [],
                paymentMethodAmounts: const [],
                transactions: const [],
              ),
            ),
            annualReportProvider.overrideWith(
              (ref, year) async => AnnualSummary(
                year: year,
                monthlyTotals: List.filled(12, 0),
                categoryTotals: const [],
                categoryTrends: [
                  CategoryAnnualTrend(
                    name: '식비',
                    colorHex: '#84B6E2',
                    monthlyAmounts: List.filled(12, 0),
                  ),
                ],
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ReportScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      void verifyTicks(List<String> labels) {
        final ticks = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'report-date-tick-',
              ),
        );
        final elements = ticks.evaluate().toList();
        expect(elements.length, greaterThanOrEqualTo(3));
        final texts = elements
            .map((element) => element.widget as Text)
            .toList();
        final step = labels.indexOf(texts[1].data!);
        expect(step, greaterThan(0));
        final expectedIndices = [
          for (var index = 0; index < labels.length; index += step) index,
        ];
        expect(
          texts.map((text) => text.data),
          expectedIndices.map((index) => labels[index]),
        );

        final spacing =
            tester.getCenter(find.byWidget(texts[1])).dx -
            tester.getCenter(find.byWidget(texts.first)).dx;
        Rect? previous;
        for (final (position, text) in texts.indexed) {
          expect(text.maxLines, 1);
          expect(text.softWrap, isFalse);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byWidget(text),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final bounds = tester.getRect(find.byWidget(text));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(width));
          final bar = find.byKey(
            ValueKey('report-bar-${expectedIndices[position]}'),
          );
          expect(bounds.center.dx, closeTo(tester.getCenter(bar).dx, 0.01));
          if (previous != null) {
            expect(bounds.left, greaterThan(previous.right));
            expect(
              bounds.center.dx - previous.center.dx,
              closeTo(spacing, 0.01),
            );
          }
          previous = bounds;
        }
        expect(tester.takeException(), isNull);
      }

      final now = DateTime.now();
      var month = DateTime(now.year, now.month);
      // Find a real example of each month length near the initial period.
      final monthsByLength = <int, DateTime>{};
      for (var offset = 0; monthsByLength.length < 4; offset++) {
        for (final delta in [-offset, offset]) {
          final candidate = DateTime(now.year, now.month + delta);
          final length = DateTime(candidate.year, candidate.month + 1, 0).day;
          monthsByLength.putIfAbsent(length, () => candidate);
        }
      }
      for (final entry in monthsByLength.entries) {
        final target = entry.value;
        while (month != target) {
          final delta = month.isBefore(target) ? 1 : -1;
          await tester.tap(find.byTooltip(delta == 1 ? '다음 기간' : '이전 기간'));
          await tester.pumpAndSettle();
          month = DateTime(month.year, month.month + delta);
        }
        await tester.tap(find.text('차트 보기').first);
        await tester.pumpAndSettle();
        verifyTicks([
          for (var day = 1; day <= entry.key; day++) '${month.month}/$day',
        ]);
      }
      final monthLabels = List.generate(12, (index) => '${index + 1}월');
      await tester.tap(find.text('연간'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('차트 보기').first);
      await tester.pumpAndSettle();
      verifyTicks(monthLabels);
      await tester.tap(find.text('표로 보기').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('차트 보기').last);
      await tester.pumpAndSettle();
      verifyTicks(monthLabels);
    });
  }

  testWidgets('refunds are drawn below the zero line', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(384, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportProvider.overrideWith(
            (ref, month) async => ReportSummary(
              totalExpense: 50,
              previousMonthExpense: -50,
              remainingBudget: 0,
              period: BudgetPeriodRange(
                startDate: month,
                endDate: DateTime(month.year, month.month + 1, 0),
              ),
              budgetUsages: const [],
              dailyAmounts: [
                DailyAmount(date: month, amount: 100),
                DailyAmount(
                  date: DateTime(month.year, month.month, 2),
                  amount: -50,
                ),
              ],
              paymentMethodAmounts: const [],
              transactions: const [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ReportScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('200% 증가'), findsOneWidget);
    await tester.tap(find.text('차트 보기'));
    await tester.pumpAndSettle();
    final positive = tester.getRect(find.byKey(const ValueKey('report-bar-0')));
    final negative = tester.getRect(find.byKey(const ValueKey('report-bar-1')));
    expect(negative.top, closeTo(positive.bottom, 0.01));
    expect(negative.height, closeTo(positive.height / 2, 0.01));
    expect(tester.takeException(), isNull);
  });
}
