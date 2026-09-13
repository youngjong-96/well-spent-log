import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../application/providers.dart';
import '../transaction/transaction_form_sheet.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/transaction_list_tile.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _month = DateTime(today.year, today.month);
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(monthTransactionsProvider(_month));
    return transactions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _CalendarError(
        onRetry: () => ref.invalidate(monthTransactionsProvider(_month)),
      ),
      data: (records) {
        final selectedRecords = records
            .where(
              (record) => DateUtils.isSameDay(record.occurredAt, _selectedDate),
            )
            .toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '달력',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '이전 달',
                      onPressed: () => _moveMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    SizedBox(
                      width: 108,
                      child: Text(
                        formatMonth(_month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '다음 달',
                      onPressed: () => _moveMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverToBoxAdapter(
                child: _MonthCalendar(
                  month: _month,
                  selectedDate: _selectedDate,
                  records: records,
                  onDateSelected: (date) {
                    setState(() => _selectedDate = date);
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  formatDate(_selectedDate),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (selectedRecords.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverToBoxAdapter(child: Text('이날의 기록이 없어요.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 120),
                sliver: SliverList.separated(
                  itemCount: selectedRecords.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final record = selectedRecords[index];
                    return TransactionListTile(
                      record: record,
                      onEdit: () => TransactionFormSheet.edit(context, record),
                      onDelete: () => _deleteRecord(record),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _moveMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selectedDate = _month;
    });
  }

  Future<void> _deleteRecord(TransactionRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('삭제한 내역은 2개월 동안 되돌릴 수 있습니다.'),
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
    await ref.read(financeRepositoryProvider).softDeleteTransaction(record.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('삭제했어요'),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () =>
              ref.read(financeRepositoryProvider).restoreTransaction(record.id),
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDate,
    required this.records,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<TransactionRecord> records;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDayOffset = DateTime(month.year, month.month).weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return Column(
      children: [
        Row(
          children: [
            for (var index = 0; index < 7; index++)
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(
                      weekdays[index],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: index == 0
                            ? AppColors.overBudget
                            : index == 6
                            ? AppColors.info
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final day = index - firstDayOffset + 1;
            if (day < 1 || day > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(month.year, month.month, day);
            final dayRecords = records
                .where((record) => DateUtils.isSameDay(record.occurredAt, date))
                .toList();
            final expenseAmount = dayRecords.fold<int>(
              0,
              (sum, record) => switch (record.type) {
                RecordType.expense => sum + record.amount,
                RecordType.refund => sum - record.amount,
                RecordType.income => sum,
              },
            );
            final colors = dayRecords
                .where((record) => record.categoryColorHex != null)
                .map((record) => record.categoryColorHex!)
                .toSet()
                .take(3)
                .toList();
            final selected = DateUtils.isSameDay(date, selectedDate);
            final today = DateUtils.isSameDay(date, DateTime.now());
            return Semantics(
              label:
                  '$day일, 지출 ${formatWon(expenseAmount)}, 기록 ${dayRecords.length}건',
              button: true,
              selected: selected,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onDateSelected(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: today ? Border.all(color: AppColors.primary) : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$day',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: selected || today
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (expenseAmount != 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatAmount(expenseAmount),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final color in colors)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: colorFromHex(color),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('달력 다시 불러오기'),
      ),
    );
  }
}
