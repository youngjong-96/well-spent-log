import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/payment_method.dart';
import '../../shared/formatters.dart';
import '../manage/backup_screen.dart';
import '../transaction/transaction_form_sheet.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    required this.onFinished,
    this.replay = false,
    super.key,
  });
  final void Function(int? categoryId, int total) onFinished;
  final bool replay;
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  List<SpendingCategory> _categories = [];
  List<PaymentMethod> _methods = [];
  final Map<int, TextEditingController> _budgets = {};
  int? _selectedBudget;
  static const _recommendations = [
    '신용카드',
    '체크카드',
    '카카오페이',
    '네이버페이',
    '토스페이',
    '삼성카드',
    '현대카드',
    '신한카드',
    '국민카드',
  ];

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
    super.dispose();
  }

  Future<void> _load() async {
    await _run(() async {
      final repository = ref.read(financeRepositoryProvider);
      _categories = await repository.listCategories(includeInactive: true);
      _methods = await repository.listPaymentMethods(includeInactive: true);
      final summary = await repository.getHomeSummary();
      for (final category in _categories) {
        final amount =
            summary.budgetUsages
                .where((u) => u.categoryId == category.id)
                .firstOrNull
                ?.budgetAmount
                .amount ??
            0;
        _budgets.putIfAbsent(
          category.id,
          () => TextEditingController(
            text: amount == 0 ? '' : formatAmount(amount),
          ),
        );
      }
      _loaded = true;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (mounted)
      setState(() {
        _busy = true;
        _error = null;
      });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadSettings() async {
    final repository = ref.read(financeRepositoryProvider);
    _categories = await repository.listCategories(includeInactive: true);
    _methods = await repository.listPaymentMethods(includeInactive: true);
    for (final category in _categories) {
      _budgets.putIfAbsent(category.id, TextEditingController.new);
    }
  }

  Future<void> _finish({
    int? categoryId,
    int total = 8,
    bool skipped = false,
  }) async {
    await _run(() async {
      final settings = ref.read(settingsStoreProvider);
      await settings.setFirstRecordHintPending(skipped && !widget.replay);
      await settings.setOnboardingCompleted();
      if (mounted) widget.onFinished(categoryId, total);
    });
  }

  Future<void> _next() async {
    if (_step == 3 && !_methods.any((method) => method.isActive)) {
      setState(() => _error = '기록에 사용할 결제수단을 선택해 주세요.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == 2) {
      await _run(() async {
        final repository = ref.read(financeRepositoryProvider);
        for (final category in _categories.where((c) => c.isActive)) {
          await repository.setBudget(
            categoryId: category.id,
            amount: parseAmount(_budgets[category.id]!.text) ?? 0,
          );
        }
        if (mounted) setState(() => _step++);
      });
    } else {
      setState(() => _step++);
      if (_step == 4) await _record();
    }
  }

  Future<void> _record() => _run(() async {
    final templates = await ref.read(financeRepositoryProvider).listTemplates();
    if (!mounted) return;
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => TransactionFormSheet(
        onboarding: true,
        onboardingReplay: widget.replay,
      ),
    );
    if (!mounted || id == null) return;
    if (id == -1) {
      await _finish(skipped: true);
      return;
    }
    final records = await ref
        .read(financeRepositoryProvider)
        .listTransactions();
    final categoryId = records.where((r) => r.id == id).firstOrNull?.categoryId;
    await ref.read(settingsStoreProvider).setFirstRecordHintPending(false);
    await ref.read(settingsStoreProvider).setOnboardingCompleted();
    if (mounted) widget.onFinished(categoryId, templates.isEmpty ? 8 : 9);
  });
  Future<void> _addName(bool category) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(category: category),
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    await _run(() async {
      final repository = ref.read(financeRepositoryProvider);
      if (category) {
        await repository.addCategory(name: name.trim(), colorHex: '#2F6FEB');
      } else {
        final existing = _methods
            .where((m) => m.name == name.trim())
            .firstOrNull;
        if (existing != null) {
          await repository.setPaymentMethodActive(existing.id, true);
        } else {
          await repository.savePaymentMethod(name: name.trim());
        }
      }
      await _reloadSettings();
    });
  }

  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final child in children)
          SizedBox(width: (constraints.maxWidth - 10) / 2, child: child),
      ],
    ),
  );
  Widget _chip(String name, bool selected, VoidCallback onTap) => FilterChip(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outlineVariant,
    ),
    selectedColor: Theme.of(context).colorScheme.primaryContainer,
    avatar: selected
        ? Icon(
            Icons.circle,
            size: 8,
            color: Theme.of(context).colorScheme.primary,
          )
        : null,
    label: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(name),
    ),
    selected: selected,
    onSelected: _busy ? null : (_) => onTap(),
    showCheckmark: false,
  );

  @override
  Widget build(BuildContext context) {
    final active = _categories.where((c) => c.isActive).toList();
    final titles = ['쓰면 바로 기록하자!', '카테고리 고르기', '예산 정하기', '결제수단', '첫 기록'];
    final total = active.fold<int>(
      0,
      (sum, c) => sum + (parseAmount(_budgets[c.id]?.text ?? '') ?? 0),
    );
    return PopScope(
      canPop: widget.replay,
      child: Scaffold(
        appBar: AppBar(
          leading: _step > 0
              ? BackButton(
                  onPressed: _busy ? null : () => setState(() => _step--),
                )
              : null,
          actions: [
            if (_step > 0)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$_step/4'),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LinearProgressIndicator(value: _step / 4),
                ),
              Expanded(
                child: !_loaded
                    ? Center(
                        child: _error == null
                            ? const CircularProgressIndicator()
                            : TextButton(
                                onPressed: _load,
                                child: const Text('다시 시도'),
                              ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            titles[_step],
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 24),
                          if (_step == 0) ...[
                            const Icon(Icons.edit_note_rounded, size: 72),
                            const SizedBox(height: 28),
                            for (final text in [
                              '쓰자마자 기록',
                              '카테고리별 예산 확인',
                              '메모로 어디에 썼는지 남기기',
                            ])
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(text),
                                ),
                              ),
                          ],
                          if (_step == 1) ...[
                            _grid([
                              for (final category in _categories)
                                _chip(
                                  category.name,
                                  category.isActive,
                                  () => _run(() async {
                                    await ref
                                        .read(financeRepositoryProvider)
                                        .setCategoryActive(
                                          category.id,
                                          !category.isActive,
                                        );
                                    await _reloadSettings();
                                  }),
                                ),
                              OutlinedButton(
                                onPressed: _busy ? null : () => _addName(true),
                                child: const Text('+ 직접 추가'),
                              ),
                            ]),
                            const SizedBox(height: 24),
                            const Text('관리 탭에서 언제든 바꿀 수 있어요'),
                          ],
                          if (_step == 2) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('이번 달 예산 합계'),
                                    Text(
                                      formatWon(total),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                    const Text('매월 1일~말일'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _grid([
                              for (final category in active)
                                TextField(
                                  controller: _budgets[category.id],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    const AmountInputFormatter(),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: category.name,
                                    suffixText: '원',
                                    hintText: '예산 없음',
                                  ),
                                  onTap: () => setState(
                                    () => _selectedBudget = category.id,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                            ]),
                            const SizedBox(height: 20),
                            const Text('자주 쓰는 2~3개만 정해도 충분해요'),
                          ],
                          if (_step == 3) ...[
                            const Text('등록됨'),
                            const SizedBox(height: 8),
                            _grid([
                              for (final method in _methods.where(
                                (m) => m.isActive,
                              ))
                                _chip(
                                  method.name,
                                  true,
                                  () => _toggleMethod(method.name),
                                ),
                            ]),
                            const Divider(height: 32),
                            const Text('추천'),
                            const SizedBox(height: 8),
                            _grid([
                              for (final name in _recommendations)
                                _chip(
                                  name,
                                  _methods.any(
                                    (m) => m.name == name && m.isActive,
                                  ),
                                  () => _toggleMethod(name),
                                ),
                              OutlinedButton(
                                onPressed: _busy ? null : () => _addName(false),
                                child: const Text('+ 직접 입력'),
                              ),
                            ]),
                            const SizedBox(height: 24),
                            const Text('카드번호 없이 이름만 저장해요'),
                          ],
                          if (_step == 4) ...[
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _finish(skipped: true),
                              child: Text(
                                widget.replay ? '첫 기록 건너뛰기' : '오늘은 아직 안 썼어요',
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text('직접 기록하며 사용법을 알아보세요.'),
                          ],
                        ],
                      ),
              ),
              if (_error != null && _loaded)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_step == 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextFieldTapRegion(
                    child: Row(
                      children: [
                        for (final amount in [10000, 50000, 100000])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        final id =
                                            _selectedBudget ?? active.first.id;
                                        final controller = _budgets[id]!;
                                        controller.text = formatAmount(
                                          (parseAmount(controller.text) ?? 0) +
                                              amount,
                                        );
                                        setState(() {});
                                      },
                                child: Text('+${amount ~/ 10000}만'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    if (_step == 2) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() => _step++);
                                },
                          child: const Text('나중에 할게요'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy || !_loaded
                            ? null
                            : _step == 4
                            ? _record
                            : _next,
                        child: Text(
                          _step == 0
                              ? '시작하기'
                              : _step == 4
                              ? '첫 기록 시작'
                              : '다음',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_step == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: OutlinedButton(
                    onPressed: _busy
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
                    child: const Text('백업에서 복원하기'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMethod(String name) => _run(() async {
    final repository = ref.read(financeRepositoryProvider);
    final method = _methods.where((m) => m.name == name).firstOrNull;
    if (method == null) {
      await repository.savePaymentMethod(name: name);
    } else {
      await repository.setPaymentMethodActive(method.id, !method.isActive);
    }
    await _reloadSettings();
  });
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.category});
  final bool category;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.category ? '카테고리 추가' : '결제수단 추가'),
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
