import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/payment_method.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('결제수단')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(context, ref),
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
                  onTap: () => _edit(context, ref, method),
                  trailing: IconButton(
                    tooltip: '결제수단 삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(context, ref, method),
                  ),
                ),
            ],
          ),
        ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    PaymentMethod? method,
  ]) async {
    var name = method?.name ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final key = GlobalKey<FormState>();
        return AlertDialog(
          title: Text(method == null ? '결제수단 추가' : '결제수단 수정'),
          content: Form(
            key: key,
            child: TextFormField(
              initialValue: name,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '예: 네이버페이',
              ),
              onChanged: (value) => name = value,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '이름을 입력해 주세요.' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(context, name.trim());
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    try {
      await ref
          .read(financeRepositoryProvider)
          .savePaymentMethod(id: method?.id, name: result);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요.')));
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
    if (confirmed != true) return;
    try {
      await ref.read(financeRepositoryProvider).removePaymentMethod(method.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해 주세요.')));
      }
    }
  }
}
