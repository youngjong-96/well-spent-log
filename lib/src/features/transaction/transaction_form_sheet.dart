import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/expense_template.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/models/transaction_draft.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/formatters.dart';
import '../onboarding/first_record_tour.dart';
import '../onboarding/onboarding_style.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    this.record,
    this.onboarding = false,
    this.onOnboardingSaved,
    this.onOnboardingClose,
    super.key,
  });

  final TransactionRecord? record;
  final bool onboarding;
  final ValueChanged<int>? onOnboardingSaved;
  final VoidCallback? onOnboardingClose;

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

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet>
    with WidgetsBindingObserver {
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
  final _amountKey = GlobalKey();
  final _memoSectionKey = GlobalKey();
  final _reviewKey = GlobalKey();
  bool _reviewing = false;
  double _keyboardInset = 0;
  bool get _editingMemo => _memoFocus.hasFocus;
  bool _onboardingDetails = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
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
          bottom: widget.onboarding
              ? 0
              : MediaQuery.viewInsetsOf(context).bottom,
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
            if (widget.onboarding) return _buildOnboardingForm(options);
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.92,
              maxChildSize: 0.96,
              minChildSize: 0.6,
              builder: (context, scrollController) {
                final form = Form(
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                _quickLoadOptions(options),
                              ],
                              const SizedBox(height: 20),
                              TextFormField(
                                key: _amountKey,
                                controller: _amountController,
                                focusNode: _amountFocus,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [const AmountInputFormatter()],
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => _focusMemo(),
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
                              const SizedBox(height: 12),
                              Column(
                                key: _memoSectionKey,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _memoController,
                                    focusNode: _memoFocus,
                                    maxLength: 80,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _dismissKeyboard(),
                                    onTapOutside: (_) => _dismissKeyboard(),
                                    decoration: const InputDecoration(
                                      labelText: '어떤 지출인가요?',
                                      hintText: '예: 친구와 점심',
                                      prefixIcon: Icon(
                                        Icons.edit_note_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _quickAmounts(),
                                  if (_editingMemo) ...[
                                    const SizedBox(height: 12),
                                    TextFieldTapRegion(
                                      child: Material(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          key: const ValueKey(
                                            'transaction-summary',
                                          ),
                                          onTap: _showReview,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(
                                              _selectionSummary(options),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...[
                                SizedBox(key: _reviewKey),
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
                                  isExpanded: true,
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
                                        child: Text(
                                          category.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onTap: _dismissKeyboard,
                                  onChanged: (value) {
                                    setState(() => _categoryId = value);
                                  },
                                  validator: (value) =>
                                      value == null ? '카테고리를 선택해 주세요.' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  focusNode: _paymentFocus,
                                  initialValue: _paymentMethodId,
                                  decoration: const InputDecoration(
                                    labelText: '결제수단',
                                    prefixIcon: Icon(
                                      Icons.credit_card_outlined,
                                    ),
                                  ),
                                  items: [
                                    for (final method in options.methods)
                                      DropdownMenuItem(
                                        value: method.id,
                                        child: Text(
                                          method.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onTap: _dismissKeyboard,
                                  onChanged: (value) {
                                    setState(() => _paymentMethodId = value);
                                  },
                                  validator: (value) =>
                                      value == null ? '결제수단을 선택해 주세요.' : null,
                                ),
                                if (_isRefund) ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<int>(
                                    isExpanded: true,
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
                                      for (final record
                                          in options.recentExpenses)
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
                                      setState(
                                        () => _refundedExpenseId = value,
                                      );
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
                                    final scheme = Theme.of(
                                      context,
                                    ).colorScheme;
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                              if (_isRefund)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    '입력한 금액만큼 지출이 줄고 남은 예산이 늘어납니다.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                                if (!_reviewing) ...[
                                  Expanded(
                                    flex: 3,
                                    child: OutlinedButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : (_editingMemo || _reviewing
                                                ? _showReview
                                                : _focusMemo),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(Icons.arrow_downward),
                                      label: Text(
                                        _editingMemo || _reviewing
                                            ? '분류·결제 확인'
                                            : '메모 입력',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  flex: 2,
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
                return form;
              },
            );
          },
        ),
      ),
    );
  }

  Widget _quickAmounts() => TextFieldTapRegion(
    child: Row(
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
  );

  Widget _quickLoadOptions(_FormOptions options) {
    Widget choice(String name, IconData icon, VoidCallback onPressed) {
      final label = Text(name, maxLines: 1, overflow: TextOverflow.ellipsis);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          avatar: Icon(icon, size: 18),
          label: label,
          onPressed: onPressed,
        ),
      );
    }

    final children = [
      for (final template in options.templates)
        choice(
          template.name,
          Icons.bookmark_outline,
          () => _applyTemplate(template),
        ),
      for (final record in options.recentExpenses.take(3))
        choice(
          record.memo.isEmpty ? record.categoryName ?? '최근 지출' : record.memo,
          Icons.history,
          () => _applyRecent(record),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }

  Widget _buildOnboardingForm(_FormOptions options) {
    final category = options.categories
        .where((item) => item.id == _categoryId)
        .firstOrNull;
    final method = options.methods
        .where((item) => item.id == _paymentMethodId)
        .firstOrNull;
    final now = DateTime.now();
    final dateLabel = DateUtils.isSameDay(now, _date)
        ? '오늘 · ${_date.month}월 ${_date.day}일'
        : formatShortDate(_date);
    void toggleDetails() =>
        setState(() => _onboardingDetails = !_onboardingDetails);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        firstRecordHeader(live: true),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: onboardingSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          firstRecordSheetTitle(
                            onClose: _saving ? null : widget.onOnboardingClose,
                          ),
                          const SizedBox(height: 11),
                          firstRecordField(
                            '금액',
                            TextFormField(
                              key: _amountKey,
                              controller: _amountController,
                              focusNode: _amountFocus,
                              keyboardType: TextInputType.number,
                              inputFormatters: [const AmountInputFormatter()],
                              style: onboardingType(34, bold: true),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: onboardingType(
                                  34,
                                  color: onboardingMuted,
                                  bold: true,
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                              onTapOutside: (_) => _dismissKeyboard(),
                              validator: (text) =>
                                  (parseAmount(text ?? '') ?? 0) <= 0
                                  ? '금액을 입력해 주세요.'
                                  : null,
                            ),
                            height: 80,
                            trailing: const Text('원'),
                          ),
                          const SizedBox(height: 11),
                          firstRecordField(
                            '어떤 지출인가요?',
                            TextFormField(
                              key: _memoSectionKey,
                              controller: _memoController,
                              focusNode: _memoFocus,
                              maxLength: 80,
                              style: onboardingType(20, bold: true),
                              decoration: InputDecoration(
                                hintText: '예: 친구와 점심',
                                hintStyle: onboardingType(
                                  20,
                                  color: onboardingMuted,
                                  bold: true,
                                ),
                                counterText: '',
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                              textInputAction: TextInputAction.done,
                              onTapOutside: (_) => _dismissKeyboard(),
                            ),
                            height: 72,
                            trailing: const Icon(Icons.edit, size: 20),
                          ),
                          const SizedBox(height: 11),
                          firstRecordSummary(
                            _selectionSummary(options),
                            _onboardingDetails,
                            onTap: toggleDetails,
                          ),
                          if (_onboardingDetails) ...[
                            const SizedBox(height: 11),
                            firstRecordType(
                              _isRefund,
                              onChanged: (value) =>
                                  setState(() => _isRefund = value),
                            ),
                            const SizedBox(height: 6),
                            firstRecordDetail(
                              '카테고리',
                              category?.name ?? '카테고리 선택',
                              Icons.expand_more,
                              onTap: () =>
                                  _selectOnboardingOption('카테고리', _categoryId, {
                                    for (final item in options.categories)
                                      item.id: item.name,
                                  }, (id) => _categoryId = id),
                            ),
                            const SizedBox(height: 6),
                            firstRecordDetail(
                              '결제수단',
                              method?.name ?? '결제수단 선택',
                              Icons.expand_more,
                              onTap: () => _selectOnboardingOption(
                                '결제수단',
                                _paymentMethodId,
                                {
                                  for (final item in options.methods)
                                    item.id: item.name,
                                },
                                (id) => _paymentMethodId = id,
                              ),
                            ),
                            if (_isRefund &&
                                options.recentExpenses.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              firstRecordDetail(
                                '원 지출 연결',
                                _refundedExpenseId == null ? '선택 안 함' : '연결됨',
                                Icons.expand_more,
                                onTap: () => _selectOnboardingOption(
                                  '원 지출 연결',
                                  _refundedExpenseId ?? 0,
                                  {
                                    0: '선택 안 함',
                                    for (final item in options.recentExpenses)
                                      item.id:
                                          '${item.memo.isEmpty ? item.categoryName : item.memo} · ${formatWon(item.amount)}',
                                  },
                                  (id) =>
                                      _refundedExpenseId = id == 0 ? null : id,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            firstRecordDetail(
                              '날짜',
                              dateLabel,
                              Icons.chevron_right,
                              onTap: _pickDate,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 128,
                          child: onboardingButton(
                            _onboardingDetails ? '분류·결제 접기' : '분류·결제 확인',
                            toggleDetails,
                            secondary: true,
                            icon: _onboardingDetails
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 100,
                          child: onboardingButton(
                            _saving ? '저장 중' : '저장',
                            _saving ? null : () => _save(options),
                            icon: Icons.check,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectOnboardingOption(
    String label,
    int? selected,
    Map<int, String> choices,
    ValueChanged<int> apply,
  ) async {
    _dismissKeyboard();
    final id = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(label),
        children: [
          for (final choice in choices.entries)
            ListTile(
              title: Text(choice.value),
              trailing: choice.key == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, choice.key),
            ),
        ],
      ),
    );
    if (mounted && id != null) setState(() => apply(id));
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
    final total = current + amount;
    if (total < current) return;
    _amountController.text = formatAmount(total);
    _amountController.selection = TextSelection.collapsed(
      offset: _amountController.text.length,
    );
  }

  void _setRelativeDate(int dayOffset) {
    _dismissKeyboard();
    final now = DateTime.now();
    setState(() => _date = DateTime(now.year, now.month, now.day + dayOffset));
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
    final now = DateTime.now();
    final earliest = DateTime(2000);
    final latest = DateTime(now.year, now.month, now.day + 365);
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(earliest) ? _date : earliest,
      lastDate: _date.isAfter(latest) ? _date : latest,
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) setState(() => _reviewing = true);
  }

  void _onFieldFocusChanged() {
    if (!mounted) return;
    if (_amountFocus.hasFocus || _memoFocus.hasFocus) {
      setState(() => _reviewing = false);
      _revealEditingField();
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeMetrics() {
    final inset = View.of(context).viewInsets.bottom;
    if (_keyboardInset > 0 && inset == 0 && !_reviewing) {
      _dismissKeyboard();
      setState(() => _reviewing = true);
    }
    _keyboardInset = inset;
    if (_reviewing) {
      _reveal(_reviewKey);
    } else {
      _revealEditingField();
    }
  }

  void _revealEditingField() {
    if (_reviewing) return;
    _reveal(_editingMemo ? _memoSectionKey : _amountKey);
  }

  void _reveal(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A focus change or keyboard dismissal can supersede a queued scroll.
      if ((key == _reviewKey) != _reviewing) return;
      final target = key.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.05,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _focusMemo() {
    _memoFocus.requestFocus();
    _reveal(_memoSectionKey);
  }

  void _showReview() {
    _dismissKeyboard();
    setState(() => _reviewing = true);
    _reveal(_reviewKey);
  }

  String _selectionSummary(_FormOptions options) {
    final category =
        options.categories
            .where((item) => item.id == _categoryId)
            .firstOrNull
            ?.name ??
        '카테고리 선택';
    final method =
        options.methods
            .where((item) => item.id == _paymentMethodId)
            .firstOrNull
            ?.name ??
        '결제수단 선택';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(_date.year, _date.month, _date.day);
    final day = date == today
        ? '오늘'
        : date == DateTime(today.year, today.month, today.day - 1)
        ? '어제'
        : formatShortDate(_date);
    return '$category · $method · $day';
  }

  Future<void> _save(_FormOptions options) async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    if (widget.onboarding &&
        (_categoryId == null || _paymentMethodId == null)) {
      setState(() => _onboardingDetails = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카테고리와 결제수단을 선택해 주세요.')));
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
        final onSaved = widget.onOnboardingSaved;
        if (onSaved != null) {
          onSaved(id);
        } else {
          Navigator.pop(context, id);
        }
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
