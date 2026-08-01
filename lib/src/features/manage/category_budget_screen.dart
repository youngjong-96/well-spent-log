import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/home_summary.dart';
import '../../shared/formatters.dart';

class CategoryBudgetScreen extends ConsumerWidget {
  const CategoryBudgetScreen({super.key});

  static const _swatches = [
    '#7A5CFA',
    '#8B6F47',
    '#007E9E',
    '#4C7C59',
    '#B04A82',
    '#5E6472',
    '#2A9D8F',
    '#8A817C',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final summary = ref.watch(homeSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('카테고리와 예산')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _RetryBody(onRetry: () => ref.invalidate(categoriesProvider)),
        data: (items) => summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _RetryBody(onRetry: () => ref.invalidate(homeSummaryProvider)),
          data: (home) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ListTile(
                minTileHeight: 64,
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('예산기간 시작일'),
                subtitle: Text(
                  home.monthStartDay == 1
                      ? '매월 1일'
                      : '매월 ${home.monthStartDay}일',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _changeStartDay(context, ref),
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '현재 예산',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _editCategory(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('카테고리'),
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('카테고리를 추가해 주세요.'),
                ),
              for (final category in items)
                _CategoryBudgetTile(
                  category: category,
                  budgetAmount: _budgetFor(home, category.id),
                  onBudgetTap: () => _editBudget(
                    context,
                    ref,
                    category,
                    _budgetFor(home, category.id),
                  ),
                  onEdit: () => _editCategory(context, ref, category),
                  onDelete: () => _deleteCategory(context, ref, category),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _budgetFor(HomeSummary home, int categoryId) {
    return home.budgetUsages
            .where((usage) => usage.categoryId == categoryId)
            .map((usage) => usage.budgetAmount.amount)
            .firstOrNull ??
        0;
  }

  Future<void> _changeStartDay(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(financeRepositoryProvider);
    var selected = await repository.getMonthStartDay();
    if (!context.mounted) {
      return;
    }
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('예산기간 시작일'),
          content: DropdownButtonFormField<int>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: '매월 시작일'),
            items: [
              for (var day = 1; day <= 31; day++)
                DropdownMenuItem(value: day, child: Text('$day일')),
            ],
            onChanged: (value) {
              if (value != null) {
                setDialogState(() => selected = value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await repository.setMonthStartDay(result);
    }
  }

  Future<void> _editBudget(
    BuildContext context,
    WidgetRef ref,
    SpendingCategory category,
    int currentAmount,
  ) async {
    var amount = currentAmount == 0 ? '' : '$currentAmount';
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${category.name} 예산'),
        content: TextFormField(
          initialValue: amount,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) => amount = value,
          decoration: const InputDecoration(
            labelText: '예산 금액',
            suffixText: '원',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, int.tryParse(amount.trim()) ?? 0);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref
          .read(financeRepositoryProvider)
          .setBudget(categoryId: category.id, amount: result);
    }
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref, [
    SpendingCategory? category,
  ]) async {
    var name = category?.name ?? '';
    var colorHex = category?.colorHex ?? _swatches.first;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? '카테고리 추가' : '카테고리 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: name,
                autofocus: true,
                maxLength: 20,
                onChanged: (value) => name = value,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 12),
              const Text('색상'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final swatch in _swatches)
                    Semantics(
                      label: '카테고리 색상 $swatch',
                      selected: colorHex == swatch,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          setDialogState(() => colorHex = swatch);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorFromHex(swatch),
                            shape: BoxShape.circle,
                            border: colorHex == swatch
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: colorHex == swatch
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final trimmedName = name.trim();
                if (trimmedName.isNotEmpty) {
                  Navigator.pop(context, (trimmedName, colorHex));
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result == null) {
      return;
    }
    final repository = ref.read(financeRepositoryProvider);
    if (category == null) {
      await repository.addCategory(name: result.$1, colorHex: result.$2);
    } else {
      await repository.updateCategory(
        id: category.id,
        name: result.$1,
        colorHex: result.$2,
      );
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    SpendingCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${category.name} 카테고리를 삭제할까요?'),
        content: const Text('기존 내역이 있으면 카테고리를 숨김 처리해 기록을 보존합니다.'),
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
    if (confirmed == true) {
      await ref.read(financeRepositoryProvider).removeCategory(category.id);
    }
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile({
    required this.category,
    required this.budgetAmount,
    required this.onBudgetTap,
    required this.onEdit,
    required this.onDelete,
  });

  final SpendingCategory category;
  final int budgetAmount;
  final VoidCallback onBudgetTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 68,
      leading: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: colorFromHex(category.colorHex),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(category.name),
      subtitle: Text(budgetAmount == 0 ? '예산 미설정' : formatWon(budgetAmount)),
      onTap: onBudgetTap,
      trailing: PopupMenuButton<String>(
        tooltip: '카테고리 메뉴',
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('수정')),
          PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    );
  }
}

class _RetryBody extends StatelessWidget {
  const _RetryBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('다시 불러오기'),
      ),
    );
  }
}
