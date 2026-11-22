import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/category.dart';
import '../../domain/models/category_colors.dart';
import '../../domain/models/home_summary.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/budget_progress_tile.dart';

class CategoryBudgetScreen extends ConsumerWidget {
  const CategoryBudgetScreen({super.key});

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
    BuildContext context,
    WidgetRef ref, [
    SpendingCategory? category,
  ]) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _CategoryDialog(category: category),
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

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final SpendingCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late String _name = widget.category?.name ?? '';
  late String _colorHex =
      normalizeCategoryHex(widget.category?.colorHex ?? '') ??
      categoryColorPresets.first;
  late final _hexController = TextEditingController(text: _colorHex);
  late HSVColor _hsv = _hsvFromHex(_colorHex);
  late bool _custom = !categoryColorPresets.contains(_colorHex);

  HSVColor _hsvFromHex(String hex) => HSVColor.fromColor(
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16)),
  );

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _selectPreset(String hex) => setState(() {
    _custom = false;
    _hsv = _hsvFromHex(hex);
    _colorHex = _hexController.text = hex;
  });

  void _updateHex(String text) {
    setState(() {
      final hex = normalizeCategoryHex(text);
      if (hex == null) return;
      _hsv = _hsvFromHex(hex);
      _colorHex = hex;
    });
  }

  void _updateSliders(HSVColor hsv) => setState(() {
    _hsv = hsv;
    final rgb = hsv.toColor().toARGB32() & 0xFFFFFF;
    _colorHex = _hexController.text =
        '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  });

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(_colorHex);
    final light = AppTheme.light;
    final dark = AppTheme.dark;
    final invalidHex =
        _custom && normalizeCategoryHex(_hexController.text) == null;
    final lowContrast =
        BudgetProgressBar.usesFallback(light, color) ||
        BudgetProgressBar.usesFallback(dark, color);
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
              onChanged: (value) => setState(() => _name = value),
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const Text('색상'),
            const SizedBox(height: 6),
            Wrap(
              children: [
                for (final hex in categoryColorPresets)
                  Semantics(
                    selected: !_custom && _colorHex == hex,
                    child: IconButton(
                      tooltip: '카테고리 색상 $hex',
                      onPressed: () => _selectPreset(hex),
                      icon: CircleAvatar(
                        radius: 15,
                        backgroundColor: colorFromHex(hex),
                        foregroundColor: Colors.white,
                        child: !_custom && _colorHex == hex
                            ? const Icon(Icons.check, size: 18)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            FilterChip(
              label: const Text('직접 선택'),
              selected: _custom,
              onSelected: (selected) => setState(() {
                _custom = selected;
                _hexController.text = _colorHex;
              }),
            ),
            if (_custom) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _hexController,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: _updateHex,
                decoration: InputDecoration(
                  labelText: 'HEX 색상',
                  hintText: '#RRGGBB',
                  errorText: invalidHex ? '색상 코드 6자리를 입력해 주세요.' : null,
                ),
              ),
              _slider('색조', _hsv.hue, 360, (value) {
                _updateSliders(_hsv.withHue(value));
              }),
              _slider('채도', _hsv.saturation, 1, (value) {
                _updateSliders(_hsv.withSaturation(value));
              }),
              _slider('밝기', _hsv.value, 1, (value) {
                _updateSliders(_hsv.withValue(value));
              }),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _preview(light, '라이트 모드', color)),
                const SizedBox(width: 8),
                Expanded(child: _preview(dark, '다크 모드', color)),
              ],
            ),
            if (lowContrast)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('배경과 비슷해서 막대가 잘 안 보일 수 있어요. 이 경우 기본 색으로 보여요.'),
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
          onPressed: invalidHex || _name.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (_name.trim(), _colorHex)),
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged,
  ) => Row(
    children: [
      Text(label),
      Expanded(
        child: Semantics(
          label: label,
          child: Slider(value: value, max: max, onChanged: onChanged),
        ),
      ),
    ],
  );

  Widget _preview(ThemeData theme, String label, Color color) => Theme(
    data: theme,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            BudgetProgressBar(value: 0.42, color: color),
          ],
        ),
      ),
    ),
  );
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
          color: visibleForeground(
            colorFromHex(category.colorHex),
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).colorScheme.primary,
          ),
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
