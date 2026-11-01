import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/account.dart';
import '../../domain/models/category.dart';
import '../../domain/models/expense_template.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/models/transaction_draft.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/models/transaction_type.dart';
import '../../shared/formatters.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    required this.transactionType,
    this.record,
    super.key,
  });

  final TransactionType transactionType;
  final TransactionRecord? record;

  static Future<int?> edit(
    BuildContext context,
    TransactionRecord record,
  ) async {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final container = ProviderScope.containerOf(context, listen: false);
    final transactionId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TransactionFormSheet(
        transactionType: record.type == RecordType.income
            ? TransactionType.income
            : TransactionType.expense,
        record: record,
      ),
    );
    if (context.mounted && transactionId != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('수정했어요'),
            action: SnackBarAction(
              label: '되돌리기',
              onPressed: () => _restoreBeforeEdit(
                container: container,
                messenger: messenger,
                record: record,
              ),
            ),
          ),
        );
    }
    return transactionId;
  }

  static Future<void> _restoreBeforeEdit({
    required ProviderContainer container,
    required ScaffoldMessengerState messenger,
    required TransactionRecord record,
  }) async {
    try {
      await container
          .read(financeRepositoryProvider)
          .updateTransaction(
            record.id,
            TransactionDraft(
              type: record.type,
              occurredAt: record.occurredAt,
              amount: record.amount,
              categoryId: record.categoryId,
              paymentMethodId: record.paymentMethodId,
              accountId: record.accountId,
              memo: record.memo,
              refundedExpenseId: record.refundedExpenseId,
            ),
          );
      if (!messenger.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('수정 전 내용으로 되돌렸어요')));
    } catch (_) {
      if (!messenger.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('수정을 되돌리지 못했어요.'),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () => _restoreBeforeEdit(
                container: container,
                messenger: messenger,
                record: record,
              ),
            ),
          ),
        );
    }
  }

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  late Future<_FormOptions> _optionsFuture;
  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _paymentMethodId;
  int? _accountId;
  int? _refundedExpenseId;
  bool _isRefund = false;
  bool _saving = false;

  bool get _isExpense => widget.transactionType == TransactionType.expense;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      _amountController.text = formatAmount(record.amount);
      _memoController.text = record.memo;
      _date = record.occurredAt;
      _categoryId = record.categoryId;
      _paymentMethodId = record.paymentMethodId;
      _accountId = record.accountId;
      _isRefund = record.type == RecordType.refund;
      _refundedExpenseId = record.refundedExpenseId;
    }
    _optionsFuture = _loadOptions();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<_FormOptions> _loadOptions() async {
    final repository = ref.read(financeRepositoryProvider);
    final categories = await repository.listCategories(
      includeInactive: widget.record != null,
    );
    final accounts = await repository.listAccounts(
      includeInactive: widget.record != null,
    );
    final methods = await repository.listPaymentMethods(
      includeInactive: widget.record != null,
    );
    final templates = await repository.listTemplates();
    final recentExpenseCandidates = await repository.listTransactions(
      limit: widget.record == null ? 6 : null,
      type: RecordType.expense,
    );
    final categoryIds = categories.map((item) => item.id).toSet();
    final paymentMethodIds = methods.map((item) => item.id).toSet();
    final recentExpenses = recentExpenseCandidates
        .where(
          (record) =>
              record.id != widget.record?.id &&
              categoryIds.contains(record.categoryId) &&
              paymentMethodIds.contains(record.paymentMethodId),
        )
        .toList();
    final lastSelection = await repository.getLastExpenseSelection();
    if (widget.record != null) {
      // Keep the original selections, including archived options.
    } else if (_isExpense) {
      _categoryId = categories.any((item) => item.id == lastSelection.$1)
          ? lastSelection.$1
          : categories.firstOrNull?.id;
      _paymentMethodId = methods.any((item) => item.id == lastSelection.$2)
          ? lastSelection.$2
          : methods.firstOrNull?.id;
    } else {
      _accountId = accounts.firstOrNull?.id;
    }
    return _FormOptions(
      categories: categories,
      accounts: accounts,
      methods: methods,
      templates: templates,
      recentExpenses: recentExpenses,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FutureBuilder<_FormOptions>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SizedBox(
                height: 320,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('입력 정보를 불러오지 못했어요.'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _optionsFuture = _loadOptions());
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final options = snapshot.data!;
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.92,
              maxChildSize: 0.96,
              minChildSize: 0.6,
              builder: (context, scrollController) {
                return Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.record != null
                                        ? (_isExpense ? '지출 수정' : '수입 수정')
                                        : (_isExpense ? '지출 추가' : '수입 추가'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '닫기',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            if (widget.record == null &&
                                _isExpense &&
                                (options.templates.isNotEmpty ||
                                    options.recentExpenses.isNotEmpty)) ...[
                              const SizedBox(height: 12),
                              Text(
                                '빠른 불러오기',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final template in options.templates)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ActionChip(
                                          avatar: const Icon(
                                            Icons.bookmark_outline,
                                            size: 18,
                                          ),
                                          label: Text(template.name),
                                          onPressed: () =>
                                              _applyTemplate(template),
                                        ),
                                      ),
                                    for (final record
                                        in options.recentExpenses.take(3))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ActionChip(
                                          avatar: const Icon(
                                            Icons.history,
                                            size: 18,
                                          ),
                                          label: Text(
                                            record.memo.isEmpty
                                                ? record.categoryName ?? '최근 지출'
                                                : record.memo,
                                          ),
                                          onPressed: () => _applyRecent(record),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _amountController,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              inputFormatters: [const AmountInputFormatter()],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _dismissKeyboard(),
                              onTapOutside: (_) => _dismissKeyboard(),
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(
                                labelText: '금액',
                                suffixText: '원',
                                hintText: '0',
                              ),
                              validator: (value) {
                                final amount = parseAmount(value ?? '');
                                return amount == null || amount <= 0
                                    ? '1원 이상 입력해 주세요.'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final amount in [1000, 5000, 10000]) ...[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _addAmount(amount),
                                      child: Text('+${formatAmount(amount)}'),
                                    ),
                                  ),
                                  if (amount != 10000) const SizedBox(width: 8),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isExpense) ...[
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    icon: Icon(Icons.payments_outlined),
                                    label: Text('일반 지출'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    icon: Icon(Icons.replay_outlined),
                                    label: Text('환불/취소'),
                                  ),
                                ],
                                selected: {_isRefund},
                                onSelectionChanged: (selection) {
                                  setState(() => _isRefund = selection.first);
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                initialValue: _categoryId,
                                decoration: const InputDecoration(
                                  labelText: '카테고리',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: [
                                  for (final category in options.categories)
                                    DropdownMenuItem(
                                      value: category.id,
                                      child: Text(category.name),
                                    ),
                                ],
                                onTap: _dismissKeyboard,
                                onChanged: (value) =>
                                    setState(() => _categoryId = value),
                                validator: (value) =>
                                    value == null ? '카테고리를 선택해 주세요.' : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: _paymentMethodId,
                                decoration: const InputDecoration(
                                  labelText: '결제수단',
                                  prefixIcon: Icon(Icons.credit_card_outlined),
                                ),
                                items: [
                                  for (final method in options.methods)
                                    DropdownMenuItem(
                                      value: method.id,
                                      child: Text(method.name),
                                    ),
                                ],
                                onTap: _dismissKeyboard,
                                onChanged: (value) =>
                                    setState(() => _paymentMethodId = value),
                                validator: (value) =>
                                    value == null ? '결제수단을 선택해 주세요.' : null,
                              ),
                              if (_isRefund) ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      options.recentExpenses.any(
                                        (r) => r.id == _refundedExpenseId,
                                      )
                                      ? _refundedExpenseId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: '원 지출 연결 (선택)',
                                    prefixIcon: Icon(Icons.link),
                                  ),
                                  items: [
                                    for (final record in options.recentExpenses)
                                      DropdownMenuItem(
                                        value: record.id,
                                        child: Text(
                                          '${record.memo.isEmpty ? record.categoryName : record.memo}'
                                          ' · ${formatWon(record.amount)}',
                                        ),
                                      ),
                                  ],
                                  onTap: _dismissKeyboard,
                                  onChanged: (value) {
                                    setState(() => _refundedExpenseId = value);
                                  },
                                ),
                              ],
                            ] else
                              DropdownButtonFormField<int>(
                                initialValue: _accountId,
                                decoration: const InputDecoration(
                                  labelText: '입금 계좌',
                                  prefixIcon: Icon(
                                    Icons.account_balance_outlined,
                                  ),
                                ),
                                items: [
                                  for (final account in options.accounts)
                                    DropdownMenuItem(
                                      value: account.id,
                                      child: Text(account.name),
                                    ),
                                ],
                                onTap: _dismissKeyboard,
                                onChanged: (value) =>
                                    setState(() => _accountId = value),
                                validator: (value) =>
                                    value == null ? '입금 계좌를 선택해 주세요.' : null,
                              ),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              leading: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                              title: const Text('날짜'),
                              trailing: Text(formatShortDate(_date)),
                              onTap: _pickDate,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _setRelativeDate(0),
                                    icon: const Icon(Icons.today_outlined),
                                    label: const Text('오늘'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _setRelativeDate(-1),
                                    icon: const Icon(Icons.history),
                                    label: const Text('어제'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _memoController,
                              maxLength: 80,
                              onTapOutside: (_) => _dismissKeyboard(),
                              decoration: const InputDecoration(
                                labelText: '메모 (선택)',
                                prefixIcon: Icon(Icons.edit_note_outlined),
                              ),
                            ),
                            if (_isRefund)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '입력한 금액은 지출에서 차감되고 계좌 잔액에 더해집니다.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : () => _save(options),
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(_saving ? '저장 중' : '저장'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _applyTemplate(ExpenseTemplate template) {
    _dismissKeyboard();
    setState(() {
      _amountController.text = formatAmount(template.amount);
      _categoryId = template.categoryId;
      _paymentMethodId = template.paymentMethodId;
      _memoController.text = template.name;
    });
  }

  void _addAmount(int amount) {
    final current = parseAmount(_amountController.text) ?? 0;
    _amountController.text = formatAmount(current + amount);
    _amountController.selection = TextSelection.collapsed(
      offset: _amountController.text.length,
    );
  }

  void _setRelativeDate(int dayOffset) {
    _dismissKeyboard();
    final now = DateTime.now().add(Duration(days: dayOffset));
    setState(() => _date = DateTime(now.year, now.month, now.day));
  }

  void _applyRecent(TransactionRecord record) {
    _dismissKeyboard();
    setState(() {
      _amountController.text = formatAmount(record.amount);
      _categoryId = record.categoryId;
      _paymentMethodId = record.paymentMethodId;
      _memoController.text = record.memo;
    });
  }

  Future<void> _pickDate() async {
    _dismissKeyboard();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _save(_FormOptions options) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final amount = parseAmount(_amountController.text)!;
    final paymentMethod = _isExpense
        ? options.methods
              .where((item) => item.id == _paymentMethodId)
              .firstOrNull
        : null;
    final accountId = _isExpense ? paymentMethod?.accountId : _accountId;
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계좌 정보를 확인하지 못했어요. 결제수단이나 계좌를 다시 선택해 주세요.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(financeRepositoryProvider);
      final draft = TransactionDraft(
        type: _isExpense
            ? (_isRefund ? RecordType.refund : RecordType.expense)
            : RecordType.income,
        occurredAt: _date,
        amount: amount,
        categoryId: _isExpense ? _categoryId : null,
        paymentMethodId: _isExpense ? _paymentMethodId : null,
        accountId: accountId,
        memo: _memoController.text,
        refundedExpenseId: _isRefund ? _refundedExpenseId : null,
      );
      final int id;
      if (widget.record != null) {
        id = widget.record!.id;
        await repository.updateTransaction(id, draft);
      } else {
        id = await repository.addTransaction(draft);
      }
      if (mounted) {
        Navigator.pop(context, id);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('저장하지 못했어요. 다시 시도해 주세요.'),
              action: SnackBarAction(
                label: '다시 시도',
                onPressed: () => _save(options),
              ),
            ),
          );
      }
    }
  }
}

class _FormOptions {
  const _FormOptions({
    required this.categories,
    required this.accounts,
    required this.methods,
    required this.templates,
    required this.recentExpenses,
  });

  final List<SpendingCategory> categories;
  final List<Account> accounts;
  final List<PaymentMethod> methods;
  final List<ExpenseTemplate> templates;
  final List<TransactionRecord> recentExpenses;
}
