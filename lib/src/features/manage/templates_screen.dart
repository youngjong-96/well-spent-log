import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/expense_template.dart';
import '../../domain/models/payment_method.dart';
import '../../shared/formatters.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);
    final categories = ref.watch(categoriesProvider);
    final methods = ref.watch(paymentMethodsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('빠른 기록 템플릿'),
        actions: [
          IconButton(
            tooltip: '템플릿 추가',
            onPressed: () => _addTemplate(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('템플릿을 불러오지 못했어요.')),
        data: (items) => categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              const Center(child: Text('카테고리를 불러오지 못했어요.')),
          data: (categoryItems) => methods.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Center(child: Text('결제수단을 불러오지 못했어요.')),
            data: (methodItems) => items.isEmpty
                ? _EmptyTemplates(onAdd: () => _addTemplate(context, ref))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final template = items[index];
                      return ListTile(
                        minTileHeight: 68,
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(template.name),
                        subtitle: Text(
                          '${_categoryName(categoryItems, template)} · '
                          '${_methodName(methodItems, template)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatWon(template.amount)),
                            IconButton(
                              tooltip: '템플릿 삭제',
                              onPressed: () =>
                                  _deleteTemplate(context, ref, template),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  String _categoryName(
    List<SpendingCategory> categories,
    ExpenseTemplate template,
  ) {
    return categories
            .where((item) => item.id == template.categoryId)
            .map((item) => item.name)
            .firstOrNull ??
        '숨긴 카테고리';
  }

  String _methodName(List<PaymentMethod> methods, ExpenseTemplate template) {
    return methods
            .where((item) => item.id == template.paymentMethodId)
            .map((item) => item.name)
            .firstOrNull ??
        '숨긴 결제수단';
  }

  Future<void> _addTemplate(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(financeRepositoryProvider);
    final categories = await repository.listCategories();
    final methods = await repository.listPaymentMethods();
    if (!context.mounted) {
      return;
    }
    if (categories.isEmpty || methods.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카테고리와 결제수단을 먼저 준비해 주세요.')));
      return;
    }
    var name = '';
    var amount = '';
    var categoryId = categories.first.id;
    var paymentMethodId = methods.first.id;
    final result = await showDialog<_TemplateInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('템플릿 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (value) => name = value,
                  decoration: const InputDecoration(labelText: '지출명'),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => amount = value,
                  decoration: const InputDecoration(
                    labelText: '금액',
                    suffixText: '원',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => categoryId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: paymentMethodId,
                  decoration: const InputDecoration(labelText: '결제수단'),
                  items: [
                    for (final method in methods)
                      DropdownMenuItem(
                        value: method.id,
                        child: Text(method.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => paymentMethodId = value);
                    }
                  },
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
              onPressed: () {
                final parsedAmount = int.tryParse(amount);
                if (name.trim().isNotEmpty &&
                    parsedAmount != null &&
                    parsedAmount > 0) {
                  Navigator.pop(
                    context,
                    _TemplateInput(
                      name: name.trim(),
                      amount: parsedAmount,
                      categoryId: categoryId,
                      paymentMethodId: paymentMethodId,
                    ),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await repository.addTemplate(
        name: result.name,
        amount: result.amount,
        categoryId: result.categoryId,
        paymentMethodId: result.paymentMethodId,
      );
    }
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    ExpenseTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${template.name} 템플릿을 삭제할까요?'),
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
      await ref.read(financeRepositoryProvider).removeTemplate(template.id);
    }
  }
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmarks_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('저장된 템플릿이 없어요.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('템플릿 추가'),
          ),
        ],
      ),
    );
  }
}

class _TemplateInput {
  const _TemplateInput({
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.paymentMethodId,
  });

  final String name;
  final int amount;
  final int categoryId;
  final int paymentMethodId;
}
