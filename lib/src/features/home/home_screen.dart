import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/budget_usage.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/category_icon.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/transaction_list_tile.dart';
import '../transaction/transaction_form_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({this.onOpenCategoryDetails, super.key});

  final ValueChanged<int>? onOpenCategoryDetails;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<int> _amountCategoryIds = {};

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(homeSummaryProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(homeSummaryProvider.future),
      child: summary.when(
        loading: () => const _LoadingBody(),
        error: (error, stackTrace) =>
            _ErrorBody(onRetry: () => ref.invalidate(homeSummaryProvider)),
        data: (data) {
          final totalBudget = data.budgetUsages.fold<int>(
            0,
            (sum, usage) => sum + usage.budgetAmount.amount,
          );
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '잘쓸결심',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      _MonthChip(month: data.month),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _BudgetSummary(
                    spentAmount: data.monthlyExpense.amount,
                    totalBudget: totalBudget,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _MonthProgressCard(month: data.month),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Expanded(child: _SectionTitle(title: '예산 현황')),
                      Text(
                        '${data.budgetUsages.length}개',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (data.budgetUsages.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('관리에서 카테고리와 예산을 설정해 주세요.'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: data.budgetUsages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final usage = data.budgetUsages[index];
                          return SizedBox(
                            width: 164,
                            child: _BudgetCategoryCard(
                              usage: usage,
                              showAmount: _amountCategoryIds.contains(
                                usage.categoryId,
                              ),
                              onToggleDisplay: () {
                                setState(() {
                                  if (!_amountCategoryIds.add(
                                    usage.categoryId,
                                  )) {
                                    _amountCategoryIds.remove(usage.categoryId);
                                  }
                                });
                              },
                              onViewDetails: () => _showCategoryDetails(usage),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 120),
                sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCategoryDetails(BudgetUsage usage) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _CategoryDetailsSheet(
        categoryId: usage.categoryId,
        onDelete: _confirmDelete,
        onOpenFullList: widget.onOpenCategoryDetails == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                widget.onOpenCategoryDetails!(usage.categoryId);
              },
      ),
    );
  }

  Future<void> _confirmDelete(TransactionRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('내역은 2개월 동안 보관되며 지금은 화면에서 숨겨집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _deleteRecord(record);
  }

  Future<void> _deleteRecord(TransactionRecord record) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .softDeleteTransaction(record.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('삭제하지 못했어요.'),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () => _deleteRecord(record),
            ),
          ),
        );
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('삭제했어요'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () => _restoreRecord(record),
          ),
        ),
      );
  }

  Future<void> _restoreRecord(TransactionRecord record) async {
    try {
      await ref.read(financeRepositoryProvider).restoreTransaction(record.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('내역을 되돌리지 못했어요.'),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () => _restoreRecord(record),
            ),
          ),
        );
    }
  }
}

class _CategoryDetailsSheet extends ConsumerWidget {
  const _CategoryDetailsSheet({
    required this.categoryId,
    required this.onDelete,
    required this.onOpenFullList,
  });

  final int categoryId;
  final Future<void> Function(TransactionRecord) onDelete;
  final VoidCallback? onOpenFullList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(homeSummaryProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('내역 다시 불러오기'),
          ),
        ),
        data: (data) {
          BudgetUsage? usage;
          for (final item in data.budgetUsages) {
            if (item.categoryId == categoryId) {
              usage = item;
              break;
            }
          }
          if (usage == null) {
            return const Center(child: Text('카테고리 정보를 찾을 수 없어요.'));
          }
          final records =
              data.monthlyTransactions
                  .where(
                    (record) =>
                        record.categoryId == categoryId &&
                        record.type != RecordType.income,
                  )
                  .toList()
                ..sort((a, b) {
                  final date = b.occurredAt.compareTo(a.occurredAt);
                  return date != 0 ? date : b.id.compareTo(a.id);
                });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usage.categoryName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.month.month}월 사용 ${usage.spentAmount.format()} · '
                      '예산 ${usage.budgetAmount.format()} · ${usage.usedPercent}%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.month.month}월 1일–${data.period.endDate.day}일 · '
                      '총 ${records.length}건',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text('이번 달에 해당 카테고리 내역이 없어요.'))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: records.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return TransactionListTile(
                            record: record,
                            onEdit: () =>
                                TransactionFormSheet.edit(context, record),
                            onDelete: () => onDelete(record),
                          );
                        },
                      ),
              ),
              if (onOpenFullList != null)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    onPressed: onOpenFullList,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('전체 내역에서 보기'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: scheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            '${month.month}월',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.spentAmount, required this.totalBudget});

  final int spentAmount;
  final int totalBudget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = totalBudget - spentAmount;
    final ratio = totalBudget == 0 ? 0.0 : spentAmount / totalBudget;
    final usedPercent = totalBudget == 0 ? 0 : (ratio * 100).floor();
    final remainingLabel = totalBudget == 0
        ? '예산 미설정'
        : remaining < 0
        ? '${formatWon(remaining.abs())} 초과'
        : formatWon(remaining);
    return Semantics(
      label:
          '이번 달 남은 예산 $remainingLabel, '
          '사용한 금액 ${formatWon(spentAmount)}, '
          '전체 예산 ${formatWon(totalBudget)}',
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이번 달 남은 예산', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                remainingLabel,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: remaining < 0
                      ? scheme.secondary
                      : scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0, 1),
                    color: ratio >= 1 ? scheme.secondary : scheme.primary,
                    backgroundColor: scheme.surface.withValues(alpha: 0.7),
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  totalBudget == 0 ? '예산 없음' : '$usedPercent% 사용',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: scheme.outline),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BudgetMetric(
                    label: '사용한 금액',
                    value: formatWon(spentAmount),
                  ),
                ),
                Container(width: 1, height: 44, color: scheme.outline),
                const SizedBox(width: 20),
                Expanded(
                  child: _BudgetMetric(
                    label: '전체 예산',
                    value: formatWon(totalBudget),
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

class _BudgetMetric extends StatelessWidget {
  const _BudgetMetric({required this.label, required this.value});

  final String label;
  final String value;

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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _MonthProgressCard extends StatelessWidget {
  const _MonthProgressCard({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final selectedMonth = DateTime(month.year, month.month);
    final currentMonth = DateTime(now.year, now.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrentMonth = selectedMonth == currentMonth;
    final day = selectedMonth.isBefore(currentMonth)
        ? daysInMonth
        : selectedMonth.isAfter(currentMonth)
        ? 1
        : now.day;
    final progress = day / daysInMonth;
    final percent = (progress * 100).round();
    final markerLabel = isCurrentMonth ? '$day일 오늘' : '$day일';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이번 달 진행률', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const markerWidth = 72.0;
              final markerLeft =
                  (constraints.maxWidth - markerWidth) * progress.clamp(0, 1);
              return SizedBox(
                height: 61,
                child: Stack(
                  children: [
                    Positioned(
                      left: markerLeft,
                      top: 0,
                      width: markerWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          markerLabel,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 38,
                      child: LinearProgressIndicator(
                        value: progress,
                        color: scheme.secondary,
                        backgroundColor: scheme.surfaceContainerHighest,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Text(
                        '1일',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Text(
                        '$daysInMonth일',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '이번 달의 $percent%가 지났어요',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCategoryCard extends StatelessWidget {
  const _BudgetCategoryCard({
    required this.usage,
    required this.showAmount,
    required this.onToggleDisplay,
    required this.onViewDetails,
  });

  final BudgetUsage usage;
  final bool showAmount;
  final VoidCallback onToggleDisplay;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = usage.usedRatio.clamp(0.0, 1.0);
    final progressColor = switch (usage.usedPercent) {
      >= 100 => scheme.secondary,
      >= 80 => scheme.secondary,
      >= 50 => scheme.primary,
      _ =>
        Theme.of(context).brightness == Brightness.dark
            ? scheme.primary
            : colorFromHex(usage.colorHex),
    };
    final valueText = showAmount
        ? '${usage.spentAmount.format()} / ${usage.budgetAmount.format()}'
        : usage.budgetAmount.amount == 0
        ? '예산 미설정'
        : '${usage.usedPercent}%';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggleDisplay,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categoryIconFor(usage.categoryName),
                      color: scheme.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      usage.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 30,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      valueText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: ratio,
                color: progressColor,
                backgroundColor: scheme.surfaceContainerHighest,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const Spacer(),
              const Divider(height: 1),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onViewDetails,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('내역 보기'),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('데이터를 불러오지 못했어요.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
