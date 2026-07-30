import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../application/providers.dart';
import '../../domain/models/report_summary.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/budget_progress_tile.dart';

enum _ReportMode { month, year }

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _month;
  _ReportMode _mode = _ReportMode.month;
  final Set<int> _amountCategoryIds = {};

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
          _MonthlyReport(
            month: _month,
            amountCategoryIds: _amountCategoryIds,
            onToggleCategory: (id) {
              setState(() {
                if (!_amountCategoryIds.add(id)) {
                  _amountCategoryIds.remove(id);
                }
              });
            },
          )
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
  const _MonthlyReport({
    required this.month,
    required this.amountCategoryIds,
    required this.onToggleCategory,
  });

  final DateTime month;
  final Set<int> amountCategoryIds;
  final ValueChanged<int> onToggleCategory;

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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: _SummaryBand(data: data),
            ),
            const _ReportSectionTitle(title: '일별 지출 추이'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: _BarChart(
                values: [
                  for (final date in dates)
                    data.dailyAmounts
                            .where(
                              (item) => DateUtils.isSameDay(item.date, date),
                            )
                            .map((item) => item.amount)
                            .firstOrNull ??
                        0,
                ],
                labels: [for (final date in dates) '${date.month}/${date.day}'],
                color: AppColors.primary,
                semanticsLabel: '일별 지출 추이',
              ),
            ),
            const _ReportSectionTitle(title: '카테고리별 예산'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < data.budgetUsages.length;
                    index++
                  ) ...[
                    BudgetProgressTile(
                      usage: data.budgetUsages[index],
                      showAmount: amountCategoryIds.contains(
                        data.budgetUsages[index].categoryId,
                      ),
                      onToggleDisplay: () =>
                          onToggleCategory(data.budgetUsages[index].categoryId),
                    ),
                    if (index != data.budgetUsages.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const _ReportSectionTitle(title: '결제수단별 지출'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              child: _NamedAmountList(items: data.paymentMethodAmounts),
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
            child: _BarChart(
              values: data.monthlyTotals,
              labels: List.generate(12, (index) => '${index + 1}'),
              color: AppColors.info,
              semanticsLabel: '$year년 월별 지출 추이',
              showEveryLabel: true,
            ),
          ),
          const _ReportSectionTitle(title: '카테고리별 연간 지출'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: _NamedAmountList(items: data.categoryTotals),
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
                    _BarChart(
                      values: data.categoryTrends[index].monthlyAmounts,
                      labels: List.generate(12, (month) => '${month + 1}'),
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
              color: AppColors.income,
            ),
          ),
          SizedBox(
            width: MediaQuery.sizeOf(context).width - 64,
            child: _Metric(
              label: '남은 예산',
              value: formatWon(data.remainingBudget),
              color: data.remainingBudget < 0
                  ? AppColors.overBudget
                  : AppColors.primary,
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

class _NamedAmountList extends StatelessWidget {
  const _NamedAmountList({required this.items});

  final List<NamedAmount> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('표시할 지출이 없어요.'),
      );
    }
    final maxAmount = items.fold<int>(
      1,
      (current, item) => math.max(current, item.amount),
    );
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.name)),
                    Text(formatWon(item.amount)),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (item.amount / maxAmount).clamp(0, 1),
                  color: item.colorHex == null
                      ? AppColors.info
                      : colorFromHex(item.colorHex!),
                  backgroundColor: AppColors.surfaceVariant,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: FractionallySizedBox(
                          heightFactor: (values[index] / maxValue).clamp(
                            0.02,
                            1.0,
                          ),
                          alignment: Alignment.bottomCenter,
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
