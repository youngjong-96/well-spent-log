import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/expense_template.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/models/transaction_draft.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/formatters.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({this.record, super.key});

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
      builder: (_) => TransactionFormSheet(record: record),
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
  final _amountFocus = FocusNode();
  final _categoryFocus = FocusNode();
  final _paymentFocus = FocusNode();
  final _refundFocus = FocusNode();
  final _dateFocus = FocusNode();
  final _memoFocus = FocusNode();
  late Future<_FormOptions> _optionsFuture;
  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _paymentMethodId;
  int? _refundedExpenseId;
  bool _isRefund = false;
  bool _saving = false;
  int _refundChoiceCount = 0;
  FocusNode? _lastFocusedField;

  List<FocusNode> get _fieldOrder => [
    _amountFocus,
    _categoryFocus,
    _paymentFocus,
    if (_isRefund && _refundChoiceCount > 0) _refundFocus,
    _dateFocus,
    _memoFocus,
  ];

  @override
  void initState() {
    super.initState();
    for (final node in [
      _amountFocus,
      _categoryFocus,
      _paymentFocus,
      _refundFocus,
      _dateFocus,
      _memoFocus,
    ]) {
      node.addListener(_onFieldFocusChanged);
    }
    final record = widget.record;
    if (record != null) {
      _amountController.text = formatAmount(record.amount);
      _memoController.text = record.memo;
      _date = record.occurredAt;
      _categoryId = record.categoryId;
      _paymentMethodId = record.paymentMethodId;
      _isRefund = record.type == RecordType.refund;
      _refundedExpenseId = record.refundedExpenseId;
    }
    _optionsFuture = _loadOptions();
  }

  @override
  void dispose() {
    for (final node in [
      _amountFocus,
      _categoryFocus,
      _paymentFocus,
      _refundFocus,
      _dateFocus,
      _memoFocus,
    ]) {
      node.removeListener(_onFieldFocusChanged);
      node.dispose();
    }
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<_FormOptions> _loadOptions() async {
    final repository = ref.read(financeRepositoryProvider);
    final categories = await repository.listCategories(
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
    } else {
      _categoryId = categories.any((item) => item.id == lastSelection.$1)
          ? lastSelection.$1
          : categories.firstOrNull?.id;
      _paymentMethodId = methods.any((item) => item.id == lastSelection.$2)
          ? lastSelection.$2
          : methods.firstOrNull?.id;
    }
    return _FormOptions(
      categories: categories,
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
            _refundChoiceCount = options.recentExpenses.length;
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
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.record != null ? '지출 수정' : '지출 추가',
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
                              focusNode: _amountFocus,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              inputFormatters: [const AmountInputFormatter()],
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _focusNextField(),
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
                            ...[
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
                                focusNode: _categoryFocus,
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
                                focusNode: _paymentFocus,
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
                                  focusNode: _refundFocus,
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
                            ],
                            const SizedBox(height: 12),
                            Focus(
                              focusNode: _dateFocus,
                              child: ListenableBuilder(
                                listenable: _dateFocus,
                                builder: (context, _) {
                                  final focused = _dateFocus.hasFocus;
                                  final scheme = Theme.of(context).colorScheme;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: focused
                                            ? scheme.primary
                                            : scheme.outlineVariant,
                                        width: focused ? 1.5 : 1,
                                      ),
                                    ),
                                    leading: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    title: const Text('날짜'),
                                    trailing: Text(formatShortDate(_date)),
                                    onTap: _pickDate,
                                  );
                                },
                              ),
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
                              focusNode: _memoFocus,
                              maxLength: 80,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _dismissKeyboard(),
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
                                  '입력한 금액만큼 지출이 줄고 남은 예산이 늘어납니다.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
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
                          child: TextFieldTapRegion(
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _canFocusNextField
                                        ? _focusNextField
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.arrow_downward),
                                    label: const Text('다음'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : () => _save(options),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                    ),
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
                              ],
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

  void _onFieldFocusChanged() {
    for (final node in _fieldOrder) {
      if (node.hasFocus) {
        _lastFocusedField = node;
        break;
      }
    }
    if (mounted) setState(() {});
  }

  // Index of the field that "다음" should advance from.
  // A tap outside the field can clear focus before the button runs. The last
  // field that actually had focus is used so the button keeps moving forward.
  int _anchorIndex(List<FocusNode> order) {
    final current = order.indexWhere((node) => node.hasFocus);
    if (current >= 0) return current;
    final last = _lastFocusedField;
    if (last == null) return -1;
    final stored = order.indexOf(last);
    if (stored >= 0) return stored;
    if (last == _refundFocus) {
      return order.indexOf(_dateFocus) - 1;
    }
    return -1;
  }

  bool get _canFocusNextField {
    if (_saving) return false;
    final order = _fieldOrder;
    return _anchorIndex(order) < order.length - 1;
  }

  void _focusNextField() {
    final order = _fieldOrder;
    final nextIndex = _anchorIndex(order) + 1;
    if (nextIndex < 0 || nextIndex >= order.length) return;
    final target = order[nextIndex];
    target.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fieldContext = target.context;
      if (fieldContext == null || !fieldContext.mounted) return;
      Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.25,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _save(_FormOptions options) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final amount = parseAmount(_amountController.text)!;
    setState(() => _saving = true);
    try {
      final repository = ref.read(financeRepositoryProvider);
      final draft = TransactionDraft(
        type: _isRefund ? RecordType.refund : RecordType.expense,
        occurredAt: _date,
        amount: amount,
        categoryId: _categoryId,
        paymentMethodId: _paymentMethodId,
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
    required this.methods,
    required this.templates,
    required this.recentExpenses,
  });

  final List<SpendingCategory> categories;
  final List<PaymentMethod> methods;
  final List<ExpenseTemplate> templates;
  final List<TransactionRecord> recentExpenses;
}
