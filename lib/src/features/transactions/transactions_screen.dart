import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/transaction_record.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/transaction_list_tile.dart';
import '../calendar/calendar_screen.dart';
import '../transaction/transaction_form_sheet.dart';

enum _TransactionsView { list, calendar }

enum _TransactionSort { amountDesc, amountAsc, dateDesc, dateAsc }

class TransactionsScreenController extends ChangeNotifier {
  int? _categoryId;

  int? get categoryId => _categoryId;

  void openCategory(int categoryId) {
    _categoryId = categoryId;
    notifyListeners();
  }
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({required this.controller, super.key});

  final TransactionsScreenController controller;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late DateTime _month;
  _TransactionsView _view = _TransactionsView.list;
  String _query = '';
  int? _categoryFilterId;
  String? _paymentFilter;
  _TransactionSort _sort = _TransactionSort.dateDesc;
  int _page = 0;
  final _listTopKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    widget.controller.addListener(_handleOpenCategory);
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleOpenCategory);
      widget.controller.addListener(_handleOpenCategory);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleOpenCategory);
    super.dispose();
  }

  void _handleOpenCategory() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _view = _TransactionsView.list;
      _query = '';
      _categoryFilterId = widget.controller.categoryId;
      _paymentFilter = null;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '내역',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              SegmentedButton<_TransactionsView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _TransactionsView.list,
                    icon: Icon(Icons.list_alt_outlined),
                    label: Text('목록'),
                  ),
                  ButtonSegment(
                    value: _TransactionsView.calendar,
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('달력'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (selection) {
                  setState(() => _view = selection.first);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _view == _TransactionsView.calendar
              ? CalendarScreen(
                  month: _month,
                  showTitle: false,
                  onMonthChanged: (month) => _month = month,
                )
              : _buildList(),
        ),
      ],
    );
  }

  Widget _buildList() {
    final transactions = ref.watch(monthTransactionsProvider(_month));
    return transactions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: OutlinedButton.icon(
          onPressed: () => ref.invalidate(monthTransactionsProvider(_month)),
          icon: const Icon(Icons.refresh),
          label: const Text('내역 다시 불러오기'),
        ),
      ),
      data: (records) {
        final expenseRecords = records
            .where((record) => record.type != RecordType.income)
            .toList();
        final categories = <int, String>{
          for (final record in expenseRecords)
            if (record.categoryId != null && record.categoryName != null)
              record.categoryId!: record.categoryName!,
        };
        final paymentNames =
            expenseRecords
                .map(_paymentName)
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final effectiveCategory = categories.containsKey(_categoryFilterId)
            ? _categoryFilterId
            : null;
        final effectivePayment = paymentNames.contains(_paymentFilter)
            ? _paymentFilter
            : null;
        final normalizedQuery = _query.trim().toLowerCase();
        final filtered = expenseRecords.where((record) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              record.memo.toLowerCase().contains(normalizedQuery) ||
              (record.categoryName ?? '').toLowerCase().contains(
                normalizedQuery,
              ) ||
              _paymentName(record).toLowerCase().contains(normalizedQuery);
          return matchesQuery &&
              (effectiveCategory == null ||
                  record.categoryId == effectiveCategory) &&
              (effectivePayment == null ||
                  _paymentName(record) == effectivePayment);
        }).toList()..sort((a, b) => _compareTransactions(a, b, _sort));
        final pageCount = (filtered.length / 10).ceil();
        _page = _page.clamp(0, pageCount == 0 ? 0 : pageCount - 1);
        final pageRecords = filtered.skip(_page * 10).take(10).toList();

        return CustomScrollView(
          key: ValueKey('transactions-${_month.year}-${_month.month}'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _PeriodNavigator(
                  month: _month,
                  onPrevious: () => _moveMonth(-1),
                  onNext: () => _moveMonth(1),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _ListControls(
                  key: ValueKey(_month),
                  query: _query,
                  categories: categories,
                  categoryFilterId: effectiveCategory,
                  paymentNames: paymentNames,
                  paymentFilter: effectivePayment,
                  sort: _sort,
                  onQueryChanged: (value) {
                    setState(() {
                      _query = value;
                      _page = 0;
                    });
                  },
                  onCategoryChanged: (value) {
                    setState(() {
                      _categoryFilterId = value;
                      _page = 0;
                    });
                  },
                  onPaymentChanged: (value) {
                    setState(() {
                      _paymentFilter = value;
                      _page = 0;
                    });
                  },
                  onSortChanged: (value) {
                    setState(() {
                      _sort = value;
                      _page = 0;
                    });
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  key: _listTopKey,
                  '검색 결과 ${filtered.length}건 · 월 전체 ${expenseRecords.length}건',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (pageRecords.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverToBoxAdapter(child: Text('조건에 맞는 지출 내역이 없어요.')),
              )
            else
              SliverList.separated(
                itemCount: pageRecords.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final record = pageRecords[index];
                  return TransactionListTile(
                    record: record,
                    onEdit: () => TransactionFormSheet.edit(context, record),
                    onDelete: () => _confirmDelete(record),
                  );
                },
              ),
            if (pageCount > 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _page > 0
                            ? () => _changePage(_page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('이전'),
                      ),
                      Text('${_page + 1} / $pageCount 페이지'),
                      TextButton.icon(
                        onPressed: _page + 1 < pageCount
                            ? () => _changePage(_page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('다음'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _moveMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _query = '';
      _categoryFilterId = null;
      _paymentFilter = null;
      _page = 0;
    });
  }

  void _changePage(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _listTopKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  Future<void> _confirmDelete(TransactionRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('삭제한 내역은 2개월 동안 되돌릴 수 있습니다.'),
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
    if (confirmed != true || !mounted) return;
    await _deleteRecord(record);
  }

  Future<void> _deleteRecord(TransactionRecord record) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .softDeleteTransaction(record.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('삭제하지 못했어요.'),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () => _deleteRecord(record),
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('삭제했어요'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () => _restoreRecord(record),
          ),
        ),
      );
  }

  Future<void> _restoreRecord(TransactionRecord record) async {
    try {
      await ref.read(financeRepositoryProvider).restoreTransaction(record.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('내역을 되돌리지 못했어요.'),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () => _restoreRecord(record),
            ),
          ),
        );
    }
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '이전 달',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 132,
          child: Text(
            formatMonth(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ListControls extends StatelessWidget {
  const _ListControls({
    required this.query,
    required this.categories,
    required this.categoryFilterId,
    required this.paymentNames,
    required this.paymentFilter,
    required this.sort,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onPaymentChanged,
    required this.onSortChanged,
    super.key,
  });

  final String query;
  final Map<int, String> categories;
  final int? categoryFilterId;
  final List<String> paymentNames;
  final String? paymentFilter;
  final _TransactionSort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<String?> onPaymentChanged;
  final ValueChanged<_TransactionSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          initialValue: query,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: '지출 검색',
            hintText: '메모, 카테고리, 결제수단',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: categoryFilterId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('전체')),
                  for (final entry in categories.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: onCategoryChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: paymentFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '결제수단'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('전체')),
                  for (final name in paymentNames)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: onPaymentChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<_TransactionSort>(
          initialValue: sort,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '정렬'),
          items: const [
            DropdownMenuItem(
              value: _TransactionSort.dateDesc,
              child: Text('날짜 최신 순'),
            ),
            DropdownMenuItem(
              value: _TransactionSort.dateAsc,
              child: Text('날짜 오래된 순'),
            ),
            DropdownMenuItem(
              value: _TransactionSort.amountDesc,
              child: Text('금액 높은 순'),
            ),
            DropdownMenuItem(
              value: _TransactionSort.amountAsc,
              child: Text('금액 낮은 순'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onSortChanged(value);
          },
        ),
      ],
    );
  }
}

String _paymentName(TransactionRecord record) {
  return record.paymentMethodName ?? record.accountName;
}

int _compareTransactions(
  TransactionRecord a,
  TransactionRecord b,
  _TransactionSort sort,
) {
  int compareAmount(bool descending) {
    final amount = descending
        ? b.amount.compareTo(a.amount)
        : a.amount.compareTo(b.amount);
    return amount != 0 ? amount : b.occurredAt.compareTo(a.occurredAt);
  }

  int compareDate(bool descending) {
    final date = descending
        ? b.occurredAt.compareTo(a.occurredAt)
        : a.occurredAt.compareTo(b.occurredAt);
    return date != 0 ? date : b.amount.compareTo(a.amount);
  }

  return switch (sort) {
    _TransactionSort.amountDesc => compareAmount(true),
    _TransactionSort.amountAsc => compareAmount(false),
    _TransactionSort.dateDesc => compareDate(true),
    _TransactionSort.dateAsc => compareDate(false),
  };
}
