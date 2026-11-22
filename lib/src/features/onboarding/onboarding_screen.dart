import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/budget_usage.dart';
import '../../domain/models/category.dart';
import '../../domain/models/category_colors.dart';
import '../../domain/models/home_summary.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/formatters.dart';
import '../manage/backup_screen.dart';
import '../transaction/transaction_form_sheet.dart';
import 'first_record_tour.dart';
import 'onboarding_style.dart';

enum _RecordStage { tour, transition, input, home, complete }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    required this.onFinished,
    this.replay = false,
    super.key,
  });

  final VoidCallback onFinished;
  final bool replay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _guides = [
    (
      '카테고리',
      Icons.category,
      '지출을 종류별로\n나눠요',
      '어디에 많이 썼는지 한눈에 확인할 수 있어요.',
      '자주 쓰는 항목을 고르고 새로 추가할 수도 있어요.',
    ),
    (
      '예산',
      Icons.account_balance_wallet,
      '한 달에 쓸\n예산을 정해요',
      '지출을 기록할 때마다 남은 예산을 바로 확인할 수 있어요.',
      '자주 쓰는 카테고리부터 설정해도 충분해요.',
    ),
    (
      '결제수단',
      Icons.credit_card,
      '자주 쓰는\n결제수단을 골라요',
      '어떤 수단으로 얼마나 사용했는지 나눠 볼 수 있어요.',
      '카드 번호 없이 이름만 저장해요.',
    ),
    (
      '첫 기록',
      Icons.edit,
      '첫 지출을\n기록해 봐요',
      '지출을 저장하면 홈에서 남은 예산을 확인할 수 있어요.',
      '화면 사용법을 먼저 살펴보고 직접 입력해요.',
    ),
  ];
  static const _defaultMethods = ['현금', '신용카드', '모바일티머니', '국민카드', '네이버페이'];

  int _step = 0;
  bool _guide = false;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  List<SpendingCategory> _categories = [];
  List<PaymentMethod> _methods = [];
  final Map<int, TextEditingController> _budgets = {};
  final _methodName = TextEditingController();
  final Map<int, int> _savedBudgets = {};
  int? _selectedBudget;
  int _tourStep = 1;
  _RecordStage _recordStage = _RecordStage.tour;
  int? _savedId;
  TransactionRecord? _savedRecord;
  HomeSummary? _home;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _budgets.values) {
      controller.dispose();
    }
    _methodName.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = '처리하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadSettings() async {
    final repository = ref.read(financeRepositoryProvider);
    final categories = await repository.listCategories(includeInactive: true);
    final methods = await repository.listPaymentMethods(includeInactive: true);
    if (!mounted) return;
    _categories = categories;
    _methods = methods;
    for (final category in categories) {
      _budgets.putIfAbsent(category.id, TextEditingController.new);
    }
  }

  Future<void> _load() => _run(() async {
    final summary = await ref.read(financeRepositoryProvider).getHomeSummary();
    if (!mounted) return;
    await _reloadSettings();
    if (!mounted) return;
    for (final usage in summary.budgetUsages) {
      final amount = usage.budgetAmount.amount;
      _savedBudgets[usage.categoryId] = amount;
      _budgets[usage.categoryId]?.text = amount == 0
          ? ''
          : formatAmount(amount);
    }
    _loaded = true;
  });

  void _goTo(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = step;
      _guide = step > 0;
      _error = null;
      _tourStep = 1;
      _recordStage = _RecordStage.tour;
    });
  }

  Future<void> _finish({bool skipped = false}) => _run(() async {
    if (!widget.replay) {
      final settings = ref.read(settingsStoreProvider);
      await settings.setFirstRecordHintPending(skipped);
      await settings.setOnboardingCompleted();
    }
    if (mounted) widget.onFinished();
  });

  Future<void> _next() async {
    if (_step == 1 && !_categories.any((category) => category.isActive)) {
      setState(() => _error = '기록에 사용할 카테고리를 선택해 주세요.');
      return;
    }
    if (_step == 3 && !_methods.any((method) => method.isActive)) {
      setState(() => _error = '기록에 사용할 결제수단을 선택해 주세요.');
      return;
    }
    if (_step == 2) {
      FocusManager.instance.primaryFocus?.unfocus();
      await _run(() async {
        final repository = ref.read(financeRepositoryProvider);
        for (final category in _categories.where((item) => item.isActive)) {
          final amount = parseAmount(_budgets[category.id]!.text) ?? 0;
          if (amount == (_savedBudgets[category.id] ?? 0)) continue;
          await repository.setBudget(categoryId: category.id, amount: amount);
          _savedBudgets[category.id] = amount;
        }
        if (mounted) _goTo(3);
      });
    } else {
      _goTo(_step + 1);
    }
  }

  void _afterSave(int id) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _savedId = id;
      _recordStage = _RecordStage.home;
    });
    _loadConfirmation();
  }

  Future<void> _loadConfirmation() => _run(() async {
    final repository = ref.read(financeRepositoryProvider);
    final summary = await repository.getHomeSummary();
    final record =
        summary.monthlyTransactions
            .where((item) => item.id == _savedId)
            .firstOrNull ??
        (await repository.listTransactions())
            .where((item) => item.id == _savedId)
            .firstOrNull;
    if (!mounted) return;
    _home = summary;
    _savedRecord = record;
  });

  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CategoryNameDialog(),
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    await _run(() async {
      final usedColors = _categories.map((item) => item.colorHex).toSet();
      final color = categoryColorPresets.firstWhere(
        (preset) => !usedColors.contains(preset),
        orElse: () =>
            categoryColorPresets[_categories.length %
                categoryColorPresets.length],
      );
      await ref
          .read(financeRepositoryProvider)
          .addCategory(name: name.trim(), colorHex: color);
      if (mounted) await _reloadSettings();
    });
  }

  Future<void> _setMethod(String name, {bool add = false}) => _run(() async {
    final repository = ref.read(financeRepositoryProvider);
    final method = _methods.where((item) => item.name == name).firstOrNull;
    if (method == null) {
      await repository.savePaymentMethod(name: name);
    } else if (!add || !method.isActive) {
      await repository.setPaymentMethodActive(
        method.id,
        add || !method.isActive,
      );
    }
    if (!mounted) return;
    if (add) _methodName.clear();
    await _reloadSettings();
  });

  void _addMethod() {
    final name = _methodName.text.trim();
    if (name.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _setMethod(name, add: true);
  }

  Widget _grid(List<Widget> children, {int columns = 2}) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final child in children)
          SizedBox(
            width: (constraints.maxWidth - (columns - 1) * 10) / columns,
            child: child,
          ),
      ],
    ),
  );

  Widget _chip(
    String name,
    bool selected,
    VoidCallback action, {
    String? detail,
    bool compact = false,
  }) => OutlinedButton(
    key: ValueKey('onboarding-chip-$name'),
    onPressed: _busy ? null : action,
    style: OutlinedButton.styleFrom(
      backgroundColor: selected ? onboardingLine : onboardingSurface,
      foregroundColor: onboardingText,
      side: BorderSide(color: selected ? onboardingAccent : onboardingLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      minimumSize: Size(
        0,
        detail != null
            ? 60
            : compact
            ? 43
            : 55,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: onboardingType(compact ? 17 : 19, height: 1.18),
                ),
                if (detail != null)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: onboardingType(15),
                  ),
              ],
            ),
          ),
        ),
        if (selected)
          const Align(
            alignment: Alignment.centerLeft,
            child: Icon(Icons.check, color: onboardingAccent, size: 17),
          ),
      ],
    ),
  );

  String _categoryLabel(SpendingCategory category) => switch (category.name) {
    '카페/간식' => '카페·간식',
    '구독/고정비' => '구독·고정비',
    _ => category.name,
  };

  Widget _panel(
    Widget child, {
    double padding = 17,
    bool highlighted = false,
  }) => Container(
    decoration: onboardingBox(
      border: highlighted ? onboardingAccent : onboardingLine,
      radius: 19,
    ),
    padding: EdgeInsets.all(padding),
    child: child,
  );

  Widget _title(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: onboardingType(36, bold: true, height: 1.2)),
      const SizedBox(height: 9),
      Text(
        description,
        style: onboardingType(18, color: onboardingMuted, height: 1.45),
      ),
    ],
  );

  Widget _hero(
    IconData icon,
    String title,
    String description, {
    String? label,
  }) => Column(
    children: [
      onboardingTile(icon, size: label == null ? 82 : 68),
      const SizedBox(height: 18),
      if (label != null) ...[
        Text(label, style: onboardingType(17, color: onboardingAccent)),
        const SizedBox(height: 18),
      ],
      Text(
        title,
        textAlign: TextAlign.center,
        style: onboardingType(36, bold: true, height: 1.2),
      ),
      const SizedBox(height: 18),
      Text(
        description,
        textAlign: TextAlign.center,
        style: onboardingType(20, color: onboardingMuted, height: 1.45),
      ),
    ],
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 45),
              onPressed: _busy
                  ? null
                  : () => _goTo(_step == 4 && !_guide ? 4 : _step - 1),
              icon: const Icon(
                Icons.arrow_back,
                color: onboardingAccent,
                size: 22,
              ),
            ),
            Expanded(
              child: Text(
                _guides[_step - 1].$1,
                style: onboardingType(17, color: onboardingMuted),
              ),
            ),
            Text(
              '$_step/4',
              style: onboardingType(19, color: onboardingAccent, bold: true),
            ),
          ],
        ),
        onboardingMeter(_step / 4),
      ],
    ),
  );

  List<Widget> _guideContent() {
    final guide = _guides[_step - 1];
    return [
      const SizedBox(height: 42),
      _panel(
        Column(
          key: const ValueKey('onboarding-introduction'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: onboardingTile(guide.$2),
            ),
            const SizedBox(height: 21),
            Text(guide.$1, style: onboardingType(17, color: onboardingAccent)),
            Text(guide.$3, style: onboardingType(32, bold: true, height: 1.2)),
            const SizedBox(height: 21),
            Text(
              guide.$4,
              style: onboardingType(20, color: onboardingMuted, height: 1.45),
            ),
            const SizedBox(height: 21),
            const Divider(height: 1, color: onboardingLine),
            const SizedBox(height: 21),
            onboardingInfo(guide.$5),
            const SizedBox(height: 29),
            onboardingButton(
              '시작',
              _busy ? null : () => setState(() => _guide = false),
            ),
          ],
        ),
        padding: 23,
      ),
    ];
  }

  List<Widget> _budgetContent() {
    final active = _categories.where((item) => item.isActive).toList();
    final selected =
        active.where((item) => item.id == _selectedBudget).firstOrNull ??
        active.firstOrNull;
    final total = active.fold(
      0,
      (sum, item) => sum + (parseAmount(_budgets[item.id]!.text) ?? 0),
    );
    return [
      const SizedBox(height: 20),
      _title('예산 정하기', '카테고리를 고르고 금액을 입력해요.'),
      const SizedBox(height: 13),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: onboardingBox(color: onboardingRaised),
        child: _metric('이번 달 예산 합계', formatWon(total)),
      ),
      const SizedBox(height: 12),
      _grid([
        for (final category in active)
          _chip(
            _categoryLabel(category),
            category.id == selected?.id,
            () => setState(() => _selectedBudget = category.id),
            detail: _budgets[category.id]!.text.isEmpty
                ? '예산 없음'
                : '${_budgets[category.id]!.text}원',
          ),
      ]),
      if (selected != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: onboardingBox(border: onboardingAccent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_categoryLabel(selected)} 예산',
                style: onboardingType(15, color: onboardingMuted),
              ),
              TextField(
                key: ValueKey('onboarding-budget-${selected.id}'),
                controller: _budgets[selected.id],
                keyboardType: TextInputType.number,
                inputFormatters: [const AmountInputFormatter()],
                style: onboardingType(31, bold: true),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0',
                  suffixText: '원',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFieldTapRegion(
          child: _grid([
            for (final amount in [10000, 50000, 100000])
              _chip('+${amount ~/ 10000}만', false, () {
                final controller = _budgets[selected.id]!;
                final formatted = formatAmount(
                  (parseAmount(controller.text) ?? 0) + amount,
                );
                controller.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                setState(() {});
              }, compact: true),
          ], columns: 3),
        ),
      ],
      const SizedBox(height: 12),
      onboardingInfo('예산은 매월 1일에 다시 계산돼요.'),
    ];
  }

  List<Widget> _paymentContent() => [
    const SizedBox(height: 17),
    onboardingInfo('카드 번호 없이 이름만 저장해요', icon: Icons.lock_outline, shaded: true),
    const SizedBox(height: 14),
    _title('결제수단 고르기', '자주 쓰는 항목을 선택해요.'),
    const SizedBox(height: 15),
    _grid([
      for (final name in _defaultMethods)
        _chip(
          name,
          _methods.any((item) => item.name == name && item.isActive),
          () => _setMethod(name),
        ),
    ]),
    const SizedBox(height: 22),
    _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('직접 추가', style: onboardingType(20, bold: true)),
          const SizedBox(height: 10),
          Text(
            '내가 원하는 대로 결제수단을 등록해요',
            style: onboardingType(17, color: onboardingMuted),
          ),
          const SizedBox(height: 10),
          if (_methods.any((item) => !_defaultMethods.contains(item.name))) ...[
            _grid([
              for (final method in _methods.where(
                (item) => !_defaultMethods.contains(item.name),
              ))
                _chip(
                  method.name,
                  method.isActive,
                  () => _setMethod(method.name),
                ),
            ]),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: onboardingBox(border: onboardingLine),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '결제수단 이름',
                  style: onboardingType(15, color: onboardingMuted),
                ),
                TextField(
                  controller: _methodName,
                  maxLength: 40,
                  style: onboardingType(20, bold: true),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '예: 가족카드',
                    hintStyle: onboardingType(
                      20,
                      bold: true,
                      color: onboardingMuted,
                    ),
                    counterText: '',
                    suffixIcon: const Icon(Icons.edit, size: 20),
                    suffixIconConstraints: const BoxConstraints(minWidth: 24),
                  ),
                  onSubmitted: (_) => _addMethod(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          onboardingButton(
            '추가하기',
            _busy ? null : _addMethod,
            secondary: true,
            icon: Icons.add,
            compact: true,
          ),
        ],
      ),
    ),
  ];

  Widget _metric(String label, String value, {Color color = onboardingText}) =>
      Row(
        children: [
          Expanded(child: Text(label, style: onboardingType(17))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: onboardingType(19, color: color, bold: true),
            ),
          ),
        ],
      );

  BudgetUsage? get _savedUsage => _home?.budgetUsages
      .where((item) => item.categoryId == _savedRecord?.categoryId)
      .firstOrNull;
  bool get _recordInMonth =>
      _home?.monthlyTransactions.any((item) => item.id == _savedId) ?? false;

  String _remaining(BudgetUsage usage) => usage.budgetAmount.amount == 0
      ? '예산 없음'
      : usage.remainingAmount < 0
      ? '${formatWon(-usage.remainingAmount)} 초과'
      : '${formatWon(usage.remainingAmount)} 남음';

  Widget _budgetReceipt(BudgetUsage usage, {bool preview = false}) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview) ...[
          Text('홈 미리보기', style: onboardingType(17, color: onboardingAccent)),
          const SizedBox(height: 13),
        ],
        _metric(
          preview ? '${usage.categoryName} 예산' : usage.categoryName,
          _remaining(usage),
          color: preview ? onboardingText : onboardingAccent,
        ),
        const SizedBox(height: 13),
        onboardingMeter(usage.usedRatio),
        const SizedBox(height: 13),
        Text(
          '사용한 금액 ${usage.spentAmount.format()} · 전체 ${usage.budgetAmount.format()}',
          style: onboardingType(16, color: onboardingMuted),
        ),
        if (preview && _savedRecord != null) ...[
          const SizedBox(height: 13),
          const Divider(height: 1, color: onboardingLine),
          const SizedBox(height: 13),
          _metric(_recordLabel(_savedRecord!), formatWon(_savedRecord!.amount)),
        ],
      ],
    ),
    highlighted: !preview,
  );

  String _recordLabel(TransactionRecord record) => record.memo.isEmpty
      ? record.categoryName ?? record.type.label
      : record.memo;

  Widget _recentRecord(TransactionRecord record) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metric(_recordLabel(record), formatWon(record.amount)),
        Text(
          [
            if (record.categoryName != null) record.categoryName!,
            if (record.paymentMethodName != null) record.paymentMethodName!,
            DateUtils.isSameDay(DateTime.now(), record.occurredAt)
                ? '오늘'
                : formatShortDate(record.occurredAt),
          ].join(' · '),
          style: onboardingType(16, color: onboardingMuted),
        ),
      ],
    ),
  );

  List<Widget> _homeContent(HomeSummary home) {
    final usage = _savedUsage;
    final record = _savedRecord;
    final total = home.budgetUsages.fold(
      0,
      (sum, item) => sum + item.budgetAmount.amount,
    );
    final spent = home.monthlyExpense.amount;
    return [
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: Text('잘쓸결심', style: onboardingType(26, bold: true))),
          Text('기록 저장 완료', style: onboardingType(16, color: onboardingAccent)),
        ],
      ),
      const SizedBox(height: 13),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이번 달 남은 예산',
              style: onboardingType(17, color: onboardingAccent),
            ),
            Text(
              total == 0
                  ? '예산 미설정'
                  : total < spent
                  ? '${formatWon(spent - total)} 초과'
                  : formatWon(total - spent),
              style: onboardingType(38, bold: true),
            ),
            _metric('사용한 금액', formatWon(spent)),
            _metric('전체 예산', formatWon(total)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      onboardingInfo(
        _recordInMonth && usage != null && usage.budgetAmount.amount > 0
            ? '저장한 ${usage.categoryName} 기록이 예산에 반영됐어요. 이 카드에서 남은 금액을 확인해요.'
            : _recordInMonth
            ? '기록을 저장했어요. 예산을 설정하면 남은 금액을 이 카드에서 확인할 수 있어요.'
            : '선택한 날짜에 기록을 저장했어요. 이 카드에서는 이번 달 예산을 확인해요.',
        shaded: true,
      ),
      if (usage != null) ...[
        const SizedBox(height: 19),
        Text('예산 현황', style: onboardingType(20, bold: true)),
        const SizedBox(height: 10),
        _budgetReceipt(usage),
      ],
      if (record != null) ...[
        const SizedBox(height: 20),
        Text('최근 기록', style: onboardingType(20, bold: true)),
        const SizedBox(height: 10),
        _recentRecord(record),
      ],
    ];
  }

  List<Widget> _content() {
    if (_guide) return _guideContent();
    switch (_step) {
      case 0:
        return [
          const SizedBox(height: 77),
          _hero(
            Icons.receipt_long,
            '쓰면 바로\n기록하자!',
            '사용한 금액을 기록하고\n이번 달 남은 예산을 확인해요.',
            label: '잘쓸결심',
          ),
          const SizedBox(height: 36),
          onboardingInfo('지출을 종류별로 모아보기', icon: Icons.category),
          const SizedBox(height: 12),
          onboardingInfo('한 달에 쓸 예산 정하기', icon: Icons.account_balance_wallet),
          const SizedBox(height: 12),
          onboardingInfo('사용한 곳을 메모로 남기기', icon: Icons.edit),
        ];
      case 1:
        return [
          const SizedBox(height: 26),
          _title('카테고리 고르기', '기록에 쓸 카테고리를 선택해요.'),
          const SizedBox(height: 20),
          _grid([
            for (final category in _categories)
              _chip(
                _categoryLabel(category),
                category.isActive,
                () => _run(() async {
                  await ref
                      .read(financeRepositoryProvider)
                      .setCategoryActive(category.id, !category.isActive);
                  if (mounted) await _reloadSettings();
                }),
              ),
          ]),
          const SizedBox(height: 12),
          onboardingButton(
            '카테고리 직접 추가',
            _busy ? null : _addCategory,
            secondary: true,
            icon: Icons.add,
          ),
          const SizedBox(height: 18),
          onboardingInfo('관리 탭에서 언제든 바꿀 수 있어요.'),
        ];
      case 2:
        return _budgetContent();
      case 3:
        return _paymentContent();
      default:
        if (_recordStage == _RecordStage.home) {
          final home = _home;
          return home == null
              ? [
                  if (_busy)
                    const Center(child: CircularProgressIndicator())
                  else
                    onboardingButton('다시 시도', _loadConfirmation),
                ]
              : _homeContent(home);
        }
        if (_recordStage == _RecordStage.complete) {
          final usage = _savedUsage;
          final record = _savedRecord;
          return [
            const SizedBox(height: 82),
            _hero(Icons.check, '첫 기록 완료!', '이제 홈에서 사용한 금액과\n남은 예산을 확인할 수 있어요.'),
            const SizedBox(height: 28),
            if (usage != null)
              _budgetReceipt(usage, preview: true)
            else if (record != null)
              _recentRecord(record),
          ];
        }
        return [
          const SizedBox(height: 82),
          _hero(Icons.edit, '이제 직접\n기록해 봐요', '최근 사용한 내역 하나를\n자유롭게 입력해 보세요.'),
          const SizedBox(height: 28),
          _panel(onboardingInfo('금액을 입력하고 필요하면 메모, 분류, 결제수단, 날짜를 바꿔요.')),
        ];
    }
  }

  Widget? _footer() {
    if (_guide || !_loaded) return null;
    if (_step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          onboardingButton('시작하기', _busy ? null : _next),
          const SizedBox(height: 10),
          onboardingButton(
            '백업에서 복원하기',
            _busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (routeContext) => BackupScreen(
                        onRestored: () {
                          Navigator.pop(routeContext);
                          _finish();
                        },
                      ),
                    ),
                  ),
            secondary: true,
          ),
        ],
      );
    }
    if (_step == 2) {
      return Row(
        children: [
          Expanded(
            child: onboardingButton(
              '건너뛰기',
              _busy ? null : () => _goTo(3),
              secondary: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: onboardingButton('다음', _busy ? null : _next)),
        ],
      );
    }
    if (_step < 4) return onboardingButton('다음', _busy ? null : _next);
    return switch (_recordStage) {
      _RecordStage.transition => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _finish(skipped: true),
            child: Text(widget.replay ? '첫 기록 건너뛰기' : '오늘은 아직 안 썼어요'),
          ),
          onboardingButton(
            '직접 기록하기',
            _busy
                ? null
                : () => setState(() => _recordStage = _RecordStage.input),
          ),
        ],
      ),
      _RecordStage.home =>
        _home == null
            ? null
            : onboardingButton(
                '확인',
                () => setState(() => _recordStage = _RecordStage.complete),
              ),
      _RecordStage.complete => onboardingButton(
        '홈으로',
        _busy ? null : () => _finish(),
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final firstRecord = _step == 4 && !_guide;
    final tour = firstRecord && _recordStage == _RecordStage.tour;
    final input = firstRecord && _recordStage == _RecordStage.input;
    final confirmation =
        firstRecord &&
        (_recordStage == _RecordStage.home ||
            _recordStage == _RecordStage.complete);
    final footer = _footer();
    return Theme(
      data: onboardingTheme(context),
      child: PopScope(
        canPop: widget.replay && !tour && !input && !confirmation,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: tour
                ? onboardingTourBackground
                : onboardingBackground,
            body: SafeArea(
              minimum: const EdgeInsets.only(top: 44),
              child: tour
                  ? FirstRecordTour(
                      step: _tourStep,
                      onNext: () => setState(() {
                        if (_tourStep == 5) {
                          _recordStage = _RecordStage.transition;
                        } else {
                          _tourStep++;
                        }
                      }),
                    )
                  : input
                  ? TransactionFormSheet(
                      onboarding: true,
                      onOnboardingSaved: _afterSave,
                      onOnboardingClose: () => setState(
                        () => _recordStage = _RecordStage.transition,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_step > 0 && !confirmation) _header(),
                        Expanded(
                          child: !_loaded
                              ? Center(
                                  child: _error == null
                                      ? const CircularProgressIndicator()
                                      : onboardingButton('다시 시도', _load),
                                )
                              : ListView(
                                  key: ValueKey((_step, _guide, _recordStage)),
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    0,
                                    22,
                                    12,
                                  ),
                                  children: _content(),
                                ),
                        ),
                        if (_loaded && _error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 6,
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (footer != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                            child: footer,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog();
  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('카테고리 추가'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(labelText: '이름'),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('추가'),
      ),
    ],
  );
}
