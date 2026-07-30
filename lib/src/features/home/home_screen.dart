import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../application/providers.dart';
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
                        periodText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _BalanceSummary(amount: data.totalBalance.amount),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(title: '예산 현황'),
                ),
              ),
              if (data.budgetUsages.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('관리에서 카테고리와 예산을 설정해 주세요.')),
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
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(title: '최근 기록'),
                ),
              ),
              if (data.recentTransactions.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 120),
                  sliver: SliverToBoxAdapter(
                    child: Text('아직 기록이 없어요. 아래 기록 버튼으로 시작해 보세요.'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8, bottom: 120),
                  sliver: SliverList.separated(
                    itemCount: data.recentTransactions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final record = data.recentTransactions[index];
                      return TransactionListTile(
                        record: record,
                        onDelete: () => _confirmDelete(record),
                      );
                    },
                  ),
                ),
            ],
          );
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

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '앱 기록 기준 현재 총잔액 ${formatWon(amount)}',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 총잔액', style: Theme.of(context).textTheme.bodyMedium),
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
              '앱 기록 기준 · 실제 은행 잔액과 다를 수 있어요',
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
