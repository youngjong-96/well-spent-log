import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/account.dart';
import '../../domain/models/payment_method.dart';
import '../../shared/formatters.dart';

class AccountsPaymentScreen extends ConsumerWidget {
  const AccountsPaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final methods = ref.watch(paymentMethodsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('결제수단과 계좌')),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('계좌를 불러오지 못했어요.')),
        data: (accountItems) => methods.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              const Center(child: Text('결제수단을 불러오지 못했어요.')),
          data: (methodItems) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _SectionHeader(
                title: '계좌',
                onAdd: () => _addAccount(context, ref),
              ),
              for (final account in accountItems)
                _AccountTile(
                  account: account,
                  onIncludedChanged: (included) => ref
                      .read(financeRepositoryProvider)
                      .setAccountIncluded(
                        accountId: account.id,
                        included: included,
                      ),
                  onEdit: account.type == AccountType.cash
                      ? null
                      : () => _editAccount(context, ref, account),
                  onAdjust: () => _adjustBalance(context, ref, account),
                  onDelete: account.type == AccountType.cash
                      ? null
                      : () => _deleteAccount(context, ref, account),
                ),
              const Divider(height: 32),
              _SectionHeader(
                title: '결제수단',
                onAdd: () => _addCard(context, ref, accountItems),
              ),
              for (final method in methodItems)
                _PaymentMethodTile(
                  method: method,
                  accountName: accountItems
                      .where((item) => item.id == method.accountId)
                      .map((item) => item.name)
                      .firstOrNull,
                  onEdit: method.type == PaymentMethodType.cash
                      ? null
                      : () => _addCard(context, ref, accountItems, method),
                  onDelete: method.type == PaymentMethodType.cash
                      ? null
                      : () => _deletePaymentMethod(context, ref, method),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final bank = TextEditingController();
    final number = TextEditingController();
    final balance = TextEditingController(text: '0');
    var included = true;
    final result = await showDialog<_AccountInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('통장계좌 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '계좌명'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bank,
                  decoration: const InputDecoration(labelText: '은행명'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: number,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '계좌번호'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balance,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: '현재 기준 잔액',
                    suffixText: '원',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('현재 총잔액에 포함'),
                  value: included,
                  onChanged: (value) {
                    setDialogState(() => included = value);
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
                if (name.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  _AccountInput(
                    name: name.text.trim(),
                    bank: bank.text.trim(),
                    number: number.text.trim(),
                    balance: int.tryParse(balance.text) ?? 0,
                    included: included,
                  ),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    bank.dispose();
    number.dispose();
    balance.dispose();
    if (result != null) {
      await ref
          .read(financeRepositoryProvider)
          .addAccount(
            name: result.name,
            bankName: result.bank,
            accountNumber: result.number,
            openingBalance: result.balance,
            includeInTotal: result.included,
          );
    }
  }

  Future<void> _adjustBalance(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final controller = TextEditingController(text: '${account.balance}');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${account.name} 잔액 보정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
          ],
          decoration: const InputDecoration(
            labelText: '변경 후 잔액',
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
              final parsed = int.tryParse(controller.text);
              if (parsed != null) {
                Navigator.pop(context, parsed);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      await ref
          .read(financeRepositoryProvider)
          .adjustAccountBalance(accountId: account.id, newBalance: value);
    }
  }

  Future<void> _editAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final name = TextEditingController(text: account.name);
    final bank = TextEditingController(text: account.bankName ?? '');
    final number = TextEditingController(text: account.accountNumber ?? '');
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계좌 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: '계좌명'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bank,
                decoration: const InputDecoration(labelText: '은행명'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '계좌번호'),
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
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(context, (
                  name.text.trim(),
                  bank.text.trim(),
                  number.text.trim(),
                ));
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    name.dispose();
    bank.dispose();
    number.dispose();
    if (result != null) {
      await ref
          .read(financeRepositoryProvider)
          .updateAccount(
            id: account.id,
            name: result.$1,
            bankName: result.$2,
            accountNumber: result.$3,
          );
    }
  }

  Future<void> _addCard(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts, [
    PaymentMethod? existing,
  ]) async {
    final bankAccounts = accounts
        .where((account) => account.type == AccountType.bank)
        .toList();
    if (bankAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 결제계좌로 사용할 통장계좌를 추가해 주세요.')),
      );
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final company = TextEditingController(text: existing?.cardCompany ?? '');
    final billingDay = TextEditingController(
      text: existing?.billingDay?.toString() ?? '',
    );
    var accountId =
        bankAccounts.any((account) => account.id == existing?.accountId)
        ? existing!.accountId
        : bankAccounts.first.id;
    final result = await showDialog<_CardInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '카드 추가' : '카드 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '카드 이름'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: company,
                  decoration: const InputDecoration(labelText: '카드사'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: billingDay,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '결제일',
                    suffixText: '일',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: '결제계좌'),
                  items: [
                    for (final account in bankAccounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => accountId = value);
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
                final day = int.tryParse(billingDay.text);
                if (name.text.trim().isNotEmpty &&
                    day != null &&
                    day >= 1 &&
                    day <= 31) {
                  Navigator.pop(
                    context,
                    _CardInput(
                      name: name.text.trim(),
                      company: company.text.trim(),
                      billingDay: day,
                      accountId: accountId,
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
    name.dispose();
    company.dispose();
    billingDay.dispose();
    if (result != null) {
      if (existing == null) {
        await ref
            .read(financeRepositoryProvider)
            .addCard(
              name: result.name,
              company: result.company,
              billingDay: result.billingDay,
              accountId: result.accountId,
            );
      } else {
        await ref
            .read(financeRepositoryProvider)
            .updateCard(
              id: existing.id,
              name: result.name,
              company: result.company,
              billingDay: result.billingDay,
              accountId: result.accountId,
            );
      }
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      '${account.name} 계좌를 삭제할까요?',
      '연결된 내역이나 카드가 있으면 숨김 처리됩니다.',
    );
    if (confirmed) {
      await ref.read(financeRepositoryProvider).removeAccount(account.id);
    }
  }

  Future<void> _deletePaymentMethod(
    BuildContext context,
    WidgetRef ref,
    PaymentMethod method,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      '${method.name} 카드를 삭제할까요?',
      '연결된 내역이 있으면 숨김 처리됩니다.',
    );
    if (confirmed) {
      await ref.read(financeRepositoryProvider).removePaymentMethod(method.id);
    }
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    String title,
    String content,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
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
        ) ??
        false;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onIncludedChanged,
    required this.onEdit,
    required this.onAdjust,
    required this.onDelete,
  });

  final Account account;
  final ValueChanged<bool> onIncludedChanged;
  final VoidCallback? onEdit;
  final VoidCallback onAdjust;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if ((account.bankName ?? '').isNotEmpty) account.bankName!,
      if (account.maskedAccountNumber.isNotEmpty) account.maskedAccountNumber,
      '앱 기록 기준 ${formatWon(account.balance)}',
    ].join(' · ');
    return ListTile(
      minTileHeight: 72,
      leading: Icon(
        account.type == AccountType.cash
            ? Icons.payments_outlined
            : Icons.account_balance_outlined,
      ),
      title: Text(account.name),
      subtitle: Text(detail),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: account.includeInTotal, onChanged: onIncludedChanged),
          PopupMenuButton<String>(
            tooltip: '계좌 메뉴',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit?.call();
              } else if (value == 'adjust') {
                onAdjust();
              } else {
                onDelete?.call();
              }
            },
            itemBuilder: (context) => [
              if (onEdit != null)
                const PopupMenuItem(value: 'edit', child: Text('정보 수정')),
              const PopupMenuItem(value: 'adjust', child: Text('잔액 보정')),
              if (onDelete != null)
                const PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.accountName,
    required this.onEdit,
    required this.onDelete,
  });

  final PaymentMethod method;
  final String? accountName;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = method.type == PaymentMethodType.cash
        ? '현금 계좌 연결'
        : '${method.cardCompany ?? '카드'} · 매월 ${method.billingDay}일'
              ' · ${accountName ?? '연결 계좌 없음'}';
    return ListTile(
      minTileHeight: 68,
      leading: Icon(
        method.type == PaymentMethodType.cash
            ? Icons.payments_outlined
            : Icons.credit_card_outlined,
      ),
      title: Text(method.name),
      subtitle: Text(subtitle),
      trailing: onDelete == null
          ? null
          : PopupMenuButton<String>(
              tooltip: '카드 메뉴',
              onSelected: (value) =>
                  value == 'edit' ? onEdit?.call() : onDelete?.call(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
    );
  }
}

class _AccountInput {
  const _AccountInput({
    required this.name,
    required this.bank,
    required this.number,
    required this.balance,
    required this.included,
  });

  final String name;
  final String bank;
  final String number;
  final int balance;
  final bool included;
}

class _CardInput {
  const _CardInput({
    required this.name,
    required this.company,
    required this.billingDay,
    required this.accountId,
  });

  final String name;
  final String company;
  final int billingDay;
  final int accountId;
}
