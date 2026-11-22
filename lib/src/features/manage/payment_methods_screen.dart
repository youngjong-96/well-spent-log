import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/models/managed_name.dart';
import '../../domain/models/payment_method.dart';

import 'hidden_item_widgets.dart';

const _duplicateNameMessage = '이미 있는 결제수단 이름이에요';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenMethods = ref.watch(hiddenPaymentMethodsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('결제수단')),
      floatingActionButton: FloatingActionButton.extended(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('결제수단 추가'),
      ),
      body: ref
          .watch(paymentMethodsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(paymentMethodsProvider),
                child: const Text('다시 불러오기'),
              ),
            ),
            data: (methods) => ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('현금, 국민카드, 삼성카드, 네이버페이처럼 원하는 이름으로 등록해 주세요.'),
                ),
                if (methods.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('결제수단을 추가해 주세요.'),
                  ),
                for (final method in methods)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(method.name),
                    onTap: () => _edit(context, method),
                    trailing: IconButton(
                      tooltip: '결제수단 삭제',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(context, ref, method),
                    ),
                  ),
                if (hiddenMethods.hasError)
                  Center(
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(hiddenPaymentMethodsProvider),
                      child: const Text('숨긴 결제수단 다시 불러오기'),
                    ),
                  ),
                if (hiddenMethods.value case final hidden?)
                  HiddenItemsSection(
                    title: '숨긴 결제수단',
                    items: [
                      for (final item in hidden)
                        HiddenItemTile(
                          leading: const Icon(Icons.payments_outlined),
                          name: item.method.name,
                          transactionCount: item.transactionCount,
                          onRestore: () =>
                              _restore(context, ref, item.method.id),
                        ),
                    ],
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _edit(BuildContext context, [PaymentMethod? method]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PaymentMethodDialog(method: method),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .setPaymentMethodActive(id, true);
    } on DuplicateActivePaymentMethodName {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(_duplicateNameMessage)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다시 사용하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PaymentMethod method,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${method.name} 삭제'),
        content: const Text('연결된 지출이나 템플릿이 있으면 결제수단을 숨겨 기존 기록을 보존합니다.'),
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
      await ref.read(financeRepositoryProvider).removePaymentMethod(method.id);
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해 주세요.')));
      }
    }
  }
}

class _PaymentMethodDialog extends ConsumerStatefulWidget {
  const _PaymentMethodDialog({this.method});

  final PaymentMethod? method;

  @override
  ConsumerState<_PaymentMethodDialog> createState() =>
      _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends ConsumerState<_PaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name = widget.method?.name ?? '';
  String? _nameError;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final name = _name.trim();
    final id = widget.method?.id;
    final repository = ref.read(financeRepositoryProvider);
    final route = ModalRoute.of(context)!;
    setState(() {
      _nameError = null;
      _saving = true;
    });

    try {
      if (id == null) {
        final active = await repository.listPaymentMethods();
        if (!mounted || !route.isCurrent) return;
        final normalized = normalizeManagedName(name);
        if (active.any(
          (item) => normalizeManagedName(item.name) == normalized,
        )) {
          throw const DuplicateActivePaymentMethodName();
        }

        final hidden = await repository.findHiddenPaymentMethodByName(name);
        if (!mounted || !route.isCurrent) return;
        if (hidden != null) {
          final reuse = await showHiddenItemReuseDialog(
            context,
            message:
                "예전에 쓰던 '${hidden.method.name}' 결제수단이 숨겨져 있어요. "
                '(기존 내역 ${hidden.transactionCount}건이 함께 돌아와요)',
          );
          if (!mounted || !route.isCurrent || reuse == null) return;
          if (reuse) {
            await repository.setPaymentMethodActive(hidden.method.id, true);
            if (mounted && route.isCurrent) Navigator.pop(context);
            return;
          }
        }
      }
      await repository.savePaymentMethod(id: id, name: name);
      if (mounted && route.isCurrent) Navigator.pop(context);
    } on DuplicateActivePaymentMethodName {
      if (mounted) setState(() => _nameError = _duplicateNameMessage);
    } catch (_) {
      if (mounted && route.isCurrent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.method == null ? '결제수단 추가' : '결제수단 수정'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        initialValue: _name,
        autofocus: true,
        readOnly: _saving,
        maxLength: 40,
        decoration: InputDecoration(
          labelText: '이름',
          hintText: '예: 네이버페이',
          errorText: _nameError,
        ),
        onChanged: (value) => setState(() {
          _name = value;
          _nameError = null;
        }),
        validator: (value) =>
            value == null || value.trim().isEmpty ? '이름을 입력해 주세요.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(onPressed: _saving ? null : _save, child: const Text('저장')),
    ],
  );
}
