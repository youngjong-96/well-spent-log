import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../application/providers.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/models/category.dart';
import '../../domain/models/category_colors.dart';
import '../../domain/models/home_summary.dart';
import '../../domain/models/managed_name.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/budget_progress_tile.dart';

import 'hidden_item_widgets.dart';

const _duplicateNameMessage = '이미 있는 카테고리 이름이에요';

class CategoryBudgetScreen extends ConsumerWidget {
  const CategoryBudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final hiddenCategories = ref.watch(hiddenCategoriesProvider);
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
                title: const Text('예산기간'),
                subtitle: const Text('매월 1일부터 말일까지'),
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
                      onPressed: () => _editCategory(context),
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
                  onEdit: () => _editCategory(context, category),
                  onDelete: () => _deleteCategory(context, ref, category),
                ),
              if (hiddenCategories.hasError)
                _RetryBody(
                  onRetry: () => ref.invalidate(hiddenCategoriesProvider),
                ),
              if (hiddenCategories.value case final hidden?)
                HiddenItemsSection(
                  title: '숨긴 카테고리',
                  items: [
                    for (final item in hidden)
                      HiddenItemTile(
                        leading: _CategoryColorDot(item.category.colorHex),
                        name: item.category.name,
                        transactionCount: item.transactionCount,
                        onRestore: () =>
                            _restoreCategory(context, ref, item.category.id),
                      ),
                  ],
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

  Future<void> _editBudget(
    BuildContext context,
    WidgetRef ref,
    SpendingCategory category,
    int currentAmount,
  ) async {
    var amount = currentAmount == 0 ? '' : formatAmount(currentAmount);
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${category.name} 예산'),
        content: TextFormField(
          initialValue: amount,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [const AmountInputFormatter()],
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
              Navigator.pop(context, parseAmount(amount) ?? 0);
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
    BuildContext context, [
    SpendingCategory? category,
  ]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CategoryDialog(category: category),
    );
  }

  Future<void> _restoreCategory(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    try {
      await ref.read(financeRepositoryProvider).setCategoryActive(id, true);
    } on DuplicateActiveCategoryName {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(_duplicateNameMessage)));
      }
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
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(financeRepositoryProvider).removeCategory(category.id);
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({this.category});

  final SpendingCategory? category;

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late String _name = widget.category?.name ?? '';
  late final _initialHex =
      widget.category?.colorHex ?? categoryColorPresets.first;
  late final _hexController = TextEditingController(text: _initialHex);
  late bool _alertsEnabled = widget.category?.alertsEnabled ?? true;
  bool _hexEdited = false;
  bool _saving = false;
  String? _nameError;

  Future<void> _save(String colorHex) async {
    final name = _name.trim();
    final alertsEnabled = _alertsEnabled;
    final category = widget.category;
    final repository = ref.read(financeRepositoryProvider);
    final route = ModalRoute.of(context)!;
    setState(() => _saving = true);
    try {
      if (category == null) {
        final active = await repository.listCategories();
        if (!mounted || !route.isCurrent) return;
        if (active.any(
          (item) =>
              normalizeManagedName(item.name) == normalizeManagedName(name),
        )) {
          throw const DuplicateActiveCategoryName();
        }
        final hidden = await repository.findHiddenCategoryByName(name);
        if (!mounted || !route.isCurrent) return;
        if (hidden != null) {
          final reuse = await showHiddenItemReuseDialog(
            context,
            message:
                "예전에 쓰던 '${hidden.category.name}' 카테고리가 숨겨져 있어요. "
                '(기존 내역 ${hidden.transactionCount}건과 예산이 함께 돌아와요)',
          );
          if (!mounted || !route.isCurrent || reuse == null) return;
          if (reuse) {
            await repository.setCategoryActive(
              hidden.category.id,
              true,
              colorHex: colorHex,
              alertsEnabled: alertsEnabled,
            );
            if (mounted && route.isCurrent) Navigator.pop(context);
            return;
          }
        }
        await repository.addCategory(
          name: name,
          colorHex: colorHex,
          alertsEnabled: alertsEnabled,
        );
      } else {
        await repository.updateCategory(
          id: category.id,
          name: name,
          colorHex: colorHex,
          alertsEnabled: alertsEnabled,
        );
      }
      if (mounted && route.isCurrent) Navigator.pop(context);
    } on DuplicateActiveCategoryName {
      if (mounted) setState(() => _nameError = _duplicateNameMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final masterEnabled = ref.watch(budgetAlertsEnabledProvider).value;
    final normalizedHex = normalizeCategoryHex(_hexController.text);
    final color = normalizedHex == null ? null : colorFromHex(normalizedHex);
    final lowContrast =
        _hexEdited &&
        color != null &&
        !categoryColorPresets.contains(normalizedHex) &&
        (BudgetProgressBar.usesFallback(AppTheme.light, color) ||
            BudgetProgressBar.usesFallback(AppTheme.dark, color));
    return AlertDialog(
      scrollable: true,
      title: Text(widget.category == null ? '카테고리 추가' : '카테고리 수정'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: _name,
              maxLength: 20,
              onChanged: (value) => setState(() {
                _name = value;
                _nameError = null;
              }),
              decoration: InputDecoration(
                labelText: '이름',
                errorText: _nameError,
              ),
            ),
            const Text('색상'),
            const SizedBox(height: 6),
            Wrap(
              children: [
                for (final hex in categoryColorPresets)
                  Semantics(
                    selected: normalizedHex == hex,
                    child: IconButton(
                      tooltip: '카테고리 색상 $hex',
                      onPressed: () => setState(() {
                        _hexController.text = hex;
                        _hexEdited = false;
                      }),
                      icon: CircleAvatar(
                        radius: 15,
                        backgroundColor: colorFromHex(hex),
                        foregroundColor: Colors.white,
                        child: normalizedHex == hex
                            ? const Icon(Icons.check, size: 18)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hexController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _hexEdited = true),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'HEX 색상',
                hintText: '#RRGGBB',
                errorText: normalizedHex == null ? '색상 코드 6자리를 입력해 주세요.' : null,
                suffixIcon: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (lowContrast)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '배경과 비슷해서 막대가 잘 안 보일 수 있어요. 이 경우 기본 색으로 보여요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('예산 알림 받기'),
              subtitle: masterEnabled == false
                  ? const Text('전체 예산 알림이 꺼져 있어요')
                  : null,
              value: _alertsEnabled,
              onChanged: masterEnabled == true
                  ? (value) => setState(() => _alertsEnabled = value)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving || normalizedHex == null || _name.trim().isEmpty
              ? null
              : () => _save(
                  _hexController.text == _initialHex
                      ? _initialHex
                      : normalizedHex,
                ),
          child: const Text('저장'),
        ),
      ],
    );
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
      leading: _CategoryColorDot(category.colorHex),
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

class _CategoryColorDot extends StatelessWidget {
  const _CategoryColorDot(this.colorHex);

  final String colorHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: visibleForeground(
          colorFromHex(colorHex),
          Theme.of(context).scaffoldBackgroundColor,
          Theme.of(context).colorScheme.primary,
        ),
        shape: BoxShape.circle,
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
