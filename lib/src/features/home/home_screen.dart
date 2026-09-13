import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../application/providers.dart';
import '../transaction/transaction_form_sheet.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/budget_progress_tile.dart';
import '../../shared/widgets/transaction_list_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<int> _amountCategoryIds = {};
  int _page = 0;
  DateTime? _displayedMonth;
  final _listHeadingKey = GlobalKey();

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
          if (_displayedMonth != data.month) {
            _displayedMonth = data.month;
            _page = 0;
          }
          final pageCount = (data.monthlyTransactions.length / 10).ceil();
          _page = _page.clamp(0, pageCount == 0 ? 0 : pageCount - 1);
          final pageRecords = data.monthlyTransactions
              .skip(_page * 10)
              .take(10)
              .toList();
          final periodText =
              '${DateFormat('M.d').format(data.period.startDate)}'
              ' - ${DateFormat('M.d').format(data.period.endDate)}';
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '잘쓸결심',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Text(
                        '예산 $periodText',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _ExpenseSummary(
                    amount: data.monthlyExpense.amount,
                    month: data.month,
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(title: '예산 현황'),
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
                  sliver: SliverList.separated(
                    itemCount: data.budgetUsages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final usage = data.budgetUsages[index];
                      return BudgetProgressTile(
                        usage: usage,
                        showAmount: _amountCategoryIds.contains(
                          usage.categoryId,
                        ),
                        onToggleDisplay: () {
                          setState(() {
                            if (!_amountCategoryIds.add(usage.categoryId)) {
                              _amountCategoryIds.remove(usage.categoryId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    key: _listHeadingKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(title: '이번 달 지출 내역'),
                      const SizedBox(height: 4),
                      Text(
                        '금액 높은 순 · 총 ${data.monthlyTransactions.length}건',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (data.monthlyTransactions.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 120),
                  sliver: SliverToBoxAdapter(child: Text('이번 달 지출 내역이 없어요.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8),
                  sliver: SliverList.separated(
                    itemCount: pageRecords.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final record = pageRecords[index];
                      return TransactionListTile(
                        record: record,
                        onEdit: () =>
                            TransactionFormSheet.edit(context, record),
                        onDelete: () => _confirmDelete(record),
                      );
                    },
                  ),
                ),
              if (pageCount > 0)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _page > 0
                              ? () => _changePage(_page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('이전'),
                        ),
                        Text('${_page + 1} / $pageCount 페이지'),
                        TextButton.icon(
                          onPressed: _page + 1 < pageCount
                              ? () => _changePage(_page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('다음'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _changePage(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final heading = _listHeadingKey.currentContext;
      if (heading != null) {
        Scrollable.ensureVisible(
          heading,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
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
    await ref.read(financeRepositoryProvider).softDeleteTransaction(record.id);
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
            onPressed: () {
              ref.read(financeRepositoryProvider).restoreTransaction(record.id);
            },
          ),
        ),
      );
  }
}

class _ExpenseSummary extends StatelessWidget {
  const _ExpenseSummary({required this.amount, required this.month});

  final int amount;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '이번 달 지출 합계 ${formatWon(amount)}',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이번 달 지출 합계', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatWon(amount),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${month.month}월 1일–${DateTime(month.year, month.month + 1, 0).day}일 · 환불 차감',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
