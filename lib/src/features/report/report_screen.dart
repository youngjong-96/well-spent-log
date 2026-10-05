import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../application/providers.dart';
import '../../domain/models/report_summary.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/budget_progress_tile.dart';
import '../../shared/widgets/transaction_list_tile.dart';

enum _ReportMode { month, year }

enum _ReportSort { amountDesc, dateDesc, dateAsc }

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _month;
  _ReportMode _mode = _ReportMode.month;
  final Set<int> _amountCategoryIds = {};
  String _reportQuery = '';
  String? _categoryFilter;
  String? _paymentFilter;
  _ReportSort _reportSort = _ReportSort.amountDesc;

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
            query: _reportQuery,
            categoryFilter: _categoryFilter,
            paymentFilter: _paymentFilter,
            sort: _reportSort,
            onQueryChanged: (value) => setState(() => _reportQuery = value),
            onCategoryChanged: (value) =>
                setState(() => _categoryFilter = value),
            onPaymentChanged: (value) => setState(() => _paymentFilter = value),
            onSortChanged: (value) => setState(() => _reportSort = value),
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
      _reportQuery = '';
      _categoryFilter = null;
      _paymentFilter = null;
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
    required this.query,
    required this.categoryFilter,
    required this.paymentFilter,
    required this.sort,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onPaymentChanged,
    required this.onSortChanged,
  });

  final DateTime month;
  final Set<int> amountCategoryIds;
  final ValueChanged<int> onToggleCategory;
  final String query;
  final String? categoryFilter;
  final String? paymentFilter;
  final _ReportSort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onPaymentChanged;
  final ValueChanged<_ReportSort> onSortChanged;

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
        final categoryNames =
            data.transactions
                .map((record) => record.categoryName)
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
        final paymentNames =
            data.transactions
                .map(_paymentName)
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final effectiveCategory = categoryNames.contains(categoryFilter)
            ? categoryFilter
            : null;
        final effectivePayment = paymentNames.contains(paymentFilter)
            ? paymentFilter
            : null;
        final normalizedQuery = query.trim().toLowerCase();
        final filteredTransactions = data.transactions.where((record) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              record.memo.toLowerCase().contains(normalizedQuery) ||
              (record.categoryName ?? '').toLowerCase().contains(
                normalizedQuery,
              ) ||
              _paymentName(record).toLowerCase().contains(normalizedQuery);
          return matchesQuery &&
              (effectiveCategory == null ||
                  record.categoryName == effectiveCategory) &&
              (effectivePayment == null ||
                  _paymentName(record) == effectivePayment);
        }).toList()..sort((a, b) => _compareTransactions(a, b, sort));
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
              child: Column(
                children: [
                  _BarChart(
                    values: dailyValues,
                    labels: dailyLabels,
                    color: AppColors.primary,
                    semanticsLabel: '일별 지출 추이',
                  ),
                  _ChartDataTable(values: dailyValues, labels: dailyLabels),
                ],
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: _NamedAmountList(items: data.paymentMethodAmounts),
            ),
            const _ReportSectionTitle(title: '지출 상세'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _ReportListControls(
                key: ValueKey(month),
                query: query,
                categoryNames: categoryNames,
                paymentNames: paymentNames,
                categoryFilter: effectiveCategory,
                paymentFilter: effectivePayment,
                sort: sort,
                onQueryChanged: onQueryChanged,
                onCategoryChanged: onCategoryChanged,
                onPaymentChanged: onPaymentChanged,
                onSortChanged: onSortChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '검색 결과 ${filteredTransactions.length}건 · '
                '월 전체 ${data.transactions.length}건',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (filteredTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Text('조건에 맞는 지출 내역이 없어요.'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < filteredTransactions.length;
                      index++
                    ) ...[
                      TransactionListTile(record: filteredTransactions[index]),
                      if (index != filteredTransactions.length - 1)
                        const Divider(height: 1, indent: 72),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

String _paymentName(TransactionRecord record) {
  return record.paymentMethodName ?? record.accountName;
}

int _compareTransactions(
  TransactionRecord a,
  TransactionRecord b,
  _ReportSort sort,
) {
  return switch (sort) {
    _ReportSort.amountDesc =>
      b.amount.compareTo(a.amount) != 0
          ? b.amount.compareTo(a.amount)
          : b.occurredAt.compareTo(a.occurredAt),
    _ReportSort.dateDesc =>
      b.occurredAt.compareTo(a.occurredAt) != 0
          ? b.occurredAt.compareTo(a.occurredAt)
          : b.id.compareTo(a.id),
    _ReportSort.dateAsc =>
      a.occurredAt.compareTo(b.occurredAt) != 0
          ? a.occurredAt.compareTo(b.occurredAt)
          : a.id.compareTo(b.id),
  };
}

class _ReportListControls extends StatelessWidget {
  const _ReportListControls({
    required this.query,
    required this.categoryNames,
    required this.paymentNames,
    required this.categoryFilter,
    required this.paymentFilter,
    required this.sort,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onPaymentChanged,
    required this.onSortChanged,
    super.key,
  });

  final String query;
  final List<String> categoryNames;
  final List<String> paymentNames;
  final String? categoryFilter;
  final String? paymentFilter;
  final _ReportSort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onPaymentChanged;
  final ValueChanged<_ReportSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          initialValue: query,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: '지출 검색',
            hintText: '메모, 카테고리, 결제수단',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: categoryFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('전체')),
                  for (final name in categoryNames)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: onCategoryChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: paymentFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '결제수단'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('전체')),
                  for (final name in paymentNames)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: onPaymentChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<_ReportSort>(
          initialValue: sort,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '정렬'),
          items: const [
            DropdownMenuItem(
              value: _ReportSort.amountDesc,
              child: Text('금액 높은 순'),
            ),
            DropdownMenuItem(value: _ReportSort.dateDesc, child: Text('최신 순')),
            DropdownMenuItem(value: _ReportSort.dateAsc, child: Text('과거 순')),
          ],
          onChanged: (value) {
            if (value != null) onSortChanged(value);
          },
        ),
      ],
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
            child: Column(
              children: [
                _BarChart(
                  values: data.monthlyTotals,
                  labels: List.generate(12, (index) => '${index + 1}월'),
                  color: AppColors.info,
                  semanticsLabel: '$year년 월별 지출 추이',
                  showEveryLabel: true,
                ),
                _ChartDataTable(
                  values: data.monthlyTotals,
                  labels: List.generate(12, (index) => '${index + 1}월'),
                ),
              ],
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
                      labels: List.generate(12, (month) => '${month + 1}월'),
                      color: colorFromHex(data.categoryTrends[index].colorHex),
                      semanticsLabel:
                          '$year년 ${data.categoryTrends[index].name} 월별 지출',
                      showEveryLabel: true,
                    ),
                    _ChartDataTable(
                      values: data.categoryTrends[index].monthlyAmounts,
                      labels: List.generate(12, (month) => '${month + 1}월'),
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
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: const Icon(Icons.table_rows_outlined),
      title: const Text('표로 보기'),
      children: [
        for (var index = 0; index < values.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
