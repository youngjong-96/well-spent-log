import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../application/providers.dart';
import '../../domain/models/report_summary.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/formatters.dart';

enum _ReportMode { month, year }

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _month;
  _ReportMode _mode = _ReportMode.month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '보고서',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                SegmentedButton<_ReportMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _ReportMode.month, label: Text('월간')),
                    ButtonSegment(value: _ReportMode.year, label: Text('연간')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: _PeriodNavigator(
              label: _mode == _ReportMode.month
                  ? formatMonth(_month)
                  : '${_month.year}년',
              onPrevious: () => _movePeriod(-1),
              onNext: () => _movePeriod(1),
            ),
          ),
        ),
        if (_mode == _ReportMode.month)
          _MonthlyReport(month: _month)
        else
          _AnnualReport(year: _month.year),
      ],
    );
  }

  void _movePeriod(int offset) {
    setState(() {
      _month = _mode == _ReportMode.month
          ? DateTime(_month.year, _month.month + offset)
          : DateTime(_month.year + offset, _month.month);
    });
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '이전 기간',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 132,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '다음 기간',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MonthlyReport extends ConsumerWidget {
  const _MonthlyReport({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider(month));
    return report.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SliverFillRemaining(
        child: Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(reportProvider(month)),
            icon: const Icon(Icons.refresh),
            label: const Text('보고서 다시 불러오기'),
          ),
        ),
      ),
      data: (data) {
        final dates = List.generate(
          data.period.endDate.difference(data.period.startDate).inDays + 1,
          (index) => data.period.startDate.add(Duration(days: index)),
        );
        final dailyValues = [
          for (final date in dates)
            data.dailyAmounts
                    .where((item) => DateUtils.isSameDay(item.date, date))
                    .map((item) => item.amount)
                    .firstOrNull ??
                0,
        ];
        final dailyLabels = [
          for (final date in dates) '${date.month}/${date.day}',
        ];
        final categoryTotals = <String, int>{};
        for (final record in data.transactions) {
          if (record.type == RecordType.income) continue;
          final category = record.categoryName ?? '미분류';
          final amount = record.type == RecordType.refund
              ? -record.amount
              : record.amount;
          categoryTotals.update(
            category,
            (current) => current + amount,
            ifAbsent: () => amount,
          );
        }
        final categoryEntries = categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final categoryAmounts = [
          for (final entry in categoryEntries) math.max(0, entry.value),
        ];
        final categoryLabels = [for (final entry in categoryEntries) entry.key];
        final paymentValues = [
          for (final item in data.paymentMethodAmounts) item.amount,
        ];
        final paymentLabels = [
          for (final item in data.paymentMethodAmounts) item.name,
        ];
        return SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '예산기간 ${formatShortDate(data.period.startDate)}'
                ' - ${formatShortDate(data.period.endDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SummaryBand(data: data),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: _InsightCards(data: data, month: month),
            ),
            const _ReportSectionTitle(title: '일별 지출 추이'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: _TableChartView(
                values: dailyValues,
                labels: dailyLabels,
                color: AppColors.primary,
                semanticsLabel: '일별 지출 추이',
              ),
            ),
            const _ReportSectionTitle(title: '카테고리별 지출'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: _TableChartView(
                values: categoryAmounts,
                labels: categoryLabels,
                color: AppColors.info,
                semanticsLabel: '카테고리별 지출',
              ),
            ),
            const _ReportSectionTitle(title: '결제수단별 지출'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              child: _TableChartView(
                values: paymentValues,
                labels: paymentLabels,
                color: AppColors.primary,
                semanticsLabel: '결제수단별 지출',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnnualReport extends ConsumerWidget {
  const _AnnualReport({required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(annualReportProvider(year));
    return report.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SliverFillRemaining(
        child: Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(annualReportProvider(year)),
            icon: const Icon(Icons.refresh),
            label: const Text('연간 보고서 다시 불러오기'),
          ),
        ),
      ),
      data: (data) => SliverList.list(
        children: [
          const SizedBox(height: 16),
          const _ReportSectionTitle(title: '월별 지출 추이'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: _TableChartView(
              values: data.monthlyTotals,
              labels: List.generate(12, (index) => '${index + 1}월'),
              color: AppColors.info,
              semanticsLabel: '$year년 월별 지출 추이',
              showEveryLabel: true,
            ),
          ),
          const _ReportSectionTitle(title: '카테고리별 연간 지출'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: _TableChartView(
              values: [for (final item in data.categoryTotals) item.amount],
              labels: [for (final item in data.categoryTotals) item.name],
              color: AppColors.primary,
              semanticsLabel: '$year년 카테고리별 지출',
            ),
          ),
          const _ReportSectionTitle(title: '카테고리별 월 추이'),
          if (data.categoryTrends.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Text('표시할 지출이 없어요.'),
            )
          else
            for (var index = 0; index < data.categoryTrends.length; index++)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  index == data.categoryTrends.length - 1 ? 120 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.categoryTrends[index].name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    _TableChartView(
                      values: data.categoryTrends[index].monthlyAmounts,
                      labels: List.generate(12, (month) => '${month + 1}월'),
                      color: colorFromHex(data.categoryTrends[index].colorHex),
                      semanticsLabel:
                          '$year년 ${data.categoryTrends[index].name} 월별 지출',
                      showEveryLabel: true,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.data});

  final ReportSummary data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        runSpacing: 16,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width / 2 - 40,
            child: _Metric(
              label: '총지출',
              value: formatWon(data.totalExpense),
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(
            width: MediaQuery.sizeOf(context).width / 2 - 40,
            child: _Metric(
              label: '총수입',
              value: formatWon(data.totalIncome, signed: true),
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(
            width: MediaQuery.sizeOf(context).width - 64,
            child: _Metric(
              label: '남은 예산',
              value: formatWon(data.remainingBudget),
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCards extends StatelessWidget {
  const _InsightCards({required this.data, required this.month});

  final ReportSummary data;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final previous = data.previousMonthExpense;
    final difference = data.totalExpense - previous;
    final comparison = previous == 0
        ? (data.totalExpense == 0 ? '변화 없음' : '전월 지출 없음')
        : '${((difference.abs() / previous) * 100).round()}% '
              '${difference >= 0 ? '증가' : '감소'}';
    final now = DateTime.now();
    final selectedMonth = DateTime(month.year, month.month);
    final currentMonth = DateTime(now.year, now.month);
    final elapsedDays = selectedMonth.isAfter(currentMonth)
        ? 0
        : selectedMonth == currentMonth
        ? now.day
        : data.period.endDate.day;
    final average = elapsedDays == 0 ? 0 : data.totalExpense ~/ elapsedDays;
    final expenses =
        data.transactions
            .where((record) => record.type == RecordType.expense)
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    final largest = expenses.firstOrNull;

    return Column(
      children: [
        _InsightCard(
          icon: Icons.compare_arrows,
          label: '전월 대비',
          value: comparison,
          description: formatWon(difference, signed: true),
        ),
        const SizedBox(height: 8),
        _InsightCard(
          icon: Icons.calendar_view_day_outlined,
          label: '하루 평균 지출',
          value: formatWon(average),
          description: elapsedDays == 0 ? '아직 시작하지 않은 달' : '$elapsedDays일 기준',
        ),
        const SizedBox(height: 8),
        _InsightCard(
          icon: Icons.arrow_upward,
          label: '가장 큰 지출',
          value: largest == null ? '지출 없음' : formatWon(largest.amount),
          description: largest == null
              ? '기록을 추가하면 표시돼요'
              : (largest.memo.isEmpty
                    ? largest.categoryName ?? '지출'
                    : largest.memo),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navyBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              description,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportSectionTitle extends StatelessWidget {
  const _ReportSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _TableChartView extends StatefulWidget {
  const _TableChartView({
    required this.values,
    required this.labels,
    required this.color,
    required this.semanticsLabel,
    this.showEveryLabel = false,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final String semanticsLabel;
  final bool showEveryLabel;

  @override
  State<_TableChartView> createState() => _TableChartViewState();
}

class _TableChartViewState extends State<_TableChartView> {
  bool _showChart = false;

  @override
  void didUpdateWidget(covariant _TableChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values ||
        oldWidget.labels != widget.labels) {
      _showChart = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('표시할 지출이 없어요.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _showChart = !_showChart),
            icon: Icon(
              _showChart ? Icons.table_rows_outlined : Icons.bar_chart,
            ),
            label: Text(_showChart ? '표로 보기' : '차트 보기'),
          ),
        ),
        const SizedBox(height: 4),
        if (_showChart)
          _BarChart(
            values: widget.values,
            labels: widget.labels,
            color: widget.color,
            semanticsLabel: widget.semanticsLabel,
            showEveryLabel: widget.showEveryLabel,
          )
        else
          _ChartDataTable(values: widget.values, labels: widget.labels),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.labels,
    required this.color,
    required this.semanticsLabel,
    this.showEveryLabel = false,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final String semanticsLabel;
  final bool showEveryLabel;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(1, math.max);
    return Semantics(
      label:
          '$semanticsLabel, 최대 ${formatWon(maxValue)}, '
          '합계 ${formatWon(values.fold(0, (sum, value) => sum + value))}',
      child: SizedBox(
        height: 184,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < values.length; index++)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${labels[index]} · ${formatWon(values[index])}',
                        triggerMode: TooltipTriggerMode.tap,
                        preferBelow: false,
                        child: Semantics(
                          button: true,
                          label: '${labels[index]} ${formatWon(values[index])}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                widthFactor: 1,
                                heightFactor: (values[index] / maxValue).clamp(
                                  0.02,
                                  1.0,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: values[index] == 0
                                        ? AppColors.border
                                        : color,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    child: Text(
                      showEveryLabel ||
                              index == 0 ||
                              index == labels.length ~/ 2 ||
                              index == labels.length - 1
                          ? labels[index]
                          : '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartDataTable extends StatelessWidget {
  const _ChartDataTable({required this.values, required this.labels});

  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < values.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(labels[index])),
                Text(
                  formatWon(values[index]),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
