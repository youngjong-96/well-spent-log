import 'dart:async';
import 'dart:developer';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/budget_period_range.dart';
import '../../domain/models/budget_usage.dart';
import '../../domain/models/category.dart';
import '../../domain/models/expense_template.dart';
import '../../domain/models/home_summary.dart';
import '../../domain/models/managed_name.dart';
import '../../domain/models/money.dart';
import '../../domain/models/monthly_budget.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/models/report_summary.dart';
import '../../domain/models/transaction_draft.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/usecases/calculate_budget_period.dart';
import '../local/app_database.dart';
import '../services/notification_service.dart';
import '../settings/settings_store.dart';

class DuplicateActiveCategoryName implements Exception {
  const DuplicateActiveCategoryName();
}

class DuplicateActivePaymentMethodName implements Exception {
  const DuplicateActivePaymentMethodName();
}

class FinanceRepository {
  FinanceRepository({
    required AppDatabase database,
    required SettingsStore settingsStore,
    required NotificationService notificationService,
  }) : _database = database,
       _settingsStore = settingsStore,
       _notificationService = notificationService;

  final AppDatabase _database;
  final SettingsStore _settingsStore;
  final NotificationService _notificationService;
  final _changes = StreamController<int>.broadcast();
  int _revision = 0;

  Stream<int> get changes => _changes.stream;

  Future<void> initialize() async {
    final db = await _database.database;
    // Include soft-deleted records before retention cleanup.
    if ((await db.query(
      'transactions',
      columns: ['id'],
      limit: 1,
    )).isNotEmpty) {
      await _settingsStore.setOnboardingCompleted();
    }
    await purgeExpiredDeletedTransactions();
    await ensureBudgetPeriod(DateTime.now());
  }

  Future<HomeSummary> getHomeSummary([DateTime? anchorDate]) async {
    final anchor = anchorDate ?? DateTime.now();
    final db = await _database.database;
    final period = await ensureBudgetPeriod(anchor);
    final usages = await _getBudgetUsages(db, period);
    final month = DateTime(anchor.year, anchor.month);
    final monthly =
        (await listTransactions(
          start: month,
          endExclusive: DateTime(month.year, month.month + 1),
        )).toList()..sort((a, b) {
          final amountOrder = b.amount.compareTo(a.amount);
          if (amountOrder != 0) return amountOrder;
          final dateOrder = b.occurredAt.compareTo(a.occurredAt);
          return dateOrder != 0 ? dateOrder : b.id.compareTo(a.id);
        });
    return HomeSummary(
      budgetUsages: usages,
      period: BudgetPeriodRange(
        startDate: period.startDate,
        endDate: period.endDate,
      ),
      monthlyTransactions: monthly,
      month: month,
      monthlyExpense: Money(
        monthly.fold(0, (sum, record) => sum - record.signedAmount),
      ),
    );
  }

  Future<List<SpendingCategory>> listCategories({
    bool includeInactive = false,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'categories',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'sort_order, id',
    );
    return rows.map(SpendingCategory.fromMap).toList();
  }

  Future<List<HiddenCategory>> listHiddenCategories() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT c.*, (
        SELECT COUNT(*) FROM transactions t
        WHERE t.category_id = c.id AND t.deleted_at IS NULL
      ) AS transaction_count
      FROM categories c
      WHERE c.is_active = 0
      ORDER BY c.updated_at DESC, c.id DESC
      ''');
    return [
      for (final row in rows)
        HiddenCategory(
          SpendingCategory.fromMap(row),
          _asInt(row['transaction_count']),
        ),
    ];
  }

  Future<HiddenCategory?> findHiddenCategoryByName(String name) async {
    final normalized = normalizeManagedName(name);
    return (await listHiddenCategories())
        .where((item) => normalizeManagedName(item.category.name) == normalized)
        .firstOrNull;
  }

  Future<List<PaymentMethod>> listPaymentMethods({
    bool includeInactive = false,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'payment_methods',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'id',
    );
    return rows.map(PaymentMethod.fromMap).toList();
  }

  Future<List<HiddenPaymentMethod>> listHiddenPaymentMethods() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT pm.*, (
        SELECT COUNT(*) FROM transactions t
        WHERE t.payment_method_id = pm.id AND t.deleted_at IS NULL
      ) AS transaction_count
      FROM payment_methods pm
      WHERE pm.is_active = 0
      ORDER BY pm.updated_at DESC, pm.id DESC
      ''');
    return [
      for (final row in rows)
        HiddenPaymentMethod(
          PaymentMethod.fromMap(row),
          _asInt(row['transaction_count']),
        ),
    ];
  }

  Future<HiddenPaymentMethod?> findHiddenPaymentMethodByName(
    String name,
  ) async {
    final normalized = normalizeManagedName(name);
    return (await listHiddenPaymentMethods())
        .where((item) => normalizeManagedName(item.method.name) == normalized)
        .firstOrNull;
  }

  Future<List<ExpenseTemplate>> listTemplates({
    bool includeUnavailable = false,
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT et.*
      FROM expense_templates et
      JOIN categories c ON c.id = et.category_id
      JOIN payment_methods pm ON pm.id = et.payment_method_id
      WHERE et.is_active = 1
        AND (? = 1 OR (c.is_active = 1 AND pm.is_active = 1))
      ORDER BY et.updated_at DESC
    ''',
      [includeUnavailable ? 1 : 0],
    );
    return rows.map(ExpenseTemplate.fromMap).toList();
  }

  Future<List<TransactionRecord>> listTransactions({
    DateTime? start,
    DateTime? endExclusive,
    int? limit,
    RecordType? type,
  }) async {
    final db = await _database.database;
    final where = <String>['t.deleted_at IS NULL'];
    final arguments = <Object?>[];
    if (start != null) {
      where.add('t.occurred_at >= ?');
      arguments.add(start.toIso8601String());
    }
    if (endExclusive != null) {
      where.add('t.occurred_at < ?');
      arguments.add(endExclusive.toIso8601String());
    }
    if (type != null) {
      where.add('t.type = ?');
      arguments.add(type.name);
    }
    final rows = await db.rawQuery('''
      $_transactionSelect
      WHERE ${where.join(' AND ')}
      ORDER BY t.occurred_at DESC, t.id DESC
      ${limit == null ? '' : 'LIMIT $limit'}
      ''', arguments);
    return rows.map(TransactionRecord.fromMap).toList();
  }

  void _validateDraft(TransactionDraft draft) {
    if (draft.amount <= 0 ||
        draft.categoryId == null ||
        draft.paymentMethodId == null) {
      throw ArgumentError(
        'A positive amount, category and payment method are required.',
      );
    }
  }

  Map<String, Object?> _draftValues(TransactionDraft draft) => {
    'type': draft.type.name,
    'occurred_at': draft.occurredAt.toIso8601String(),
    'amount': draft.amount,
    'category_id': draft.categoryId,
    'payment_method_id': draft.paymentMethodId,
    'memo': draft.memo.trim(),
    'refunded_expense_id': draft.type == RecordType.refund
        ? draft.refundedExpenseId
        : null,
    'updated_at': DateTime.now().toIso8601String(),
  };

  Future<void> _validateReferences(
    DatabaseExecutor db,
    TransactionDraft draft, {
    int? id,
  }) async {
    for (final entry in {
      'categories': draft.categoryId,
      'payment_methods': draft.paymentMethodId,
    }.entries) {
      if ((await db.query(
        entry.key,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [entry.value],
      )).isEmpty) {
        throw ArgumentError('Missing category or payment method.');
      }
    }
    if (draft.type == RecordType.refund && draft.refundedExpenseId != null) {
      final source = await _getTransaction(db, draft.refundedExpenseId!);
      if (source.id == id ||
          source.type != RecordType.expense ||
          source.isDeleted) {
        throw ArgumentError('Invalid original expense.');
      }
    }
  }

  Future<int> addTransaction(TransactionDraft draft) async {
    _validateDraft(draft);
    final db = await _database.database;
    final id = await db.transaction<int>((txn) async {
      await _validateReferences(txn, draft);
      return txn.insert('transactions', {
        ..._draftValues(draft),
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    await _settingsStore.setLastExpenseSelection(
      categoryId: draft.categoryId!,
      paymentMethodId: draft.paymentMethodId!,
    );
    _notifyChanged();
    await _evaluateBudgetAlerts(
      categoryId: draft.categoryId!,
      anchor: draft.occurredAt,
    );
    return id;
  }

  Future<void> updateTransaction(
    int transactionId,
    TransactionDraft draft,
  ) async {
    _validateDraft(draft);
    final db = await _database.database;
    final previous = await db.transaction<TransactionRecord>((txn) async {
      final record = await _getTransaction(txn, transactionId);
      if (record.isDeleted) throw StateError('Deleted transaction.');
      await _validateReferences(txn, draft, id: transactionId);
      await txn.update(
        'transactions',
        _draftValues(draft),
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      return record;
    });
    _notifyChanged();
    await _evaluateBudgetAlerts(
      categoryId: previous.categoryId!,
      anchor: previous.occurredAt,
    );
    await _evaluateBudgetAlerts(
      categoryId: draft.categoryId!,
      anchor: draft.occurredAt,
    );
  }

  Future<void> softDeleteTransaction(int id) => _setDeleted(id, true);
  Future<void> restoreTransaction(int id) => _setDeleted(id, false);

  Future<void> _setDeleted(int id, bool deleted) async {
    final db = await _database.database;
    final record = await db.transaction<TransactionRecord>((txn) async {
      final record = await _getTransaction(txn, id);
      if (record.isDeleted == deleted) return record;
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'transactions',
        {'deleted_at': deleted ? now : null, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      return record;
    });
    _notifyChanged();
    await _evaluateBudgetAlerts(
      categoryId: record.categoryId!,
      anchor: record.occurredAt,
    );
  }

  Future<void> purgeExpiredDeletedTransactions() async {
    final db = await _database.database;
    final cutoff = _subtractMonthsClamped(DateTime.now(), 2);
    final rows = await db.query(
      'transactions',
      columns: ['id'],
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
    if (rows.isEmpty) {
      return;
    }
    await db.transaction((txn) async {
      for (final row in rows) {
        final id = row['id']! as int;
        await txn.update(
          'transactions',
          {'refunded_expense_id': null},
          where: 'refunded_expense_id = ?',
          whereArgs: [id],
        );
        await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<BudgetPeriod> ensureBudgetPeriod(DateTime anchor) async {
    final db = await _database.database;
    final range = const CalculateBudgetPeriod()(anchorDate: anchor);
    final start = _dateOnly(range.startDate);
    final end = _dateOnly(range.endDate);
    return db.transaction((txn) async {
      final existing = await txn.query(
        'budget_periods',
        where: 'start_date = ? AND end_date = ?',
        whereArgs: [start, end],
        limit: 1,
      );
      if (existing.isNotEmpty) return _periodFromMap(existing.first);

      final now = DateTime.now().toIso8601String();
      final newId = await txn.insert('budget_periods', {
        'start_date': start,
        'end_date': end,
        'month_start_day': 1,
        'created_at': now,
      });
      final previous = await txn.query(
        'budget_periods',
        columns: ['id'],
        where: 'start_date < ?',
        whereArgs: [start],
        orderBy: 'start_date DESC',
        limit: 1,
      );
      if (previous.isNotEmpty) {
        final budgets = await txn.query(
          'monthly_budgets',
          where: 'period_id = ?',
          whereArgs: [previous.first['id']],
        );
        for (final budget in budgets) {
          await txn.insert('monthly_budgets', {
            'period_id': newId,
            'category_id': budget['category_id'],
            'amount': budget['amount'],
            'created_at': now,
            'updated_at': now,
          });
        }
      }
      return BudgetPeriod(
        id: newId,
        startDate: range.startDate,
        endDate: range.endDate,
      );
    });
  }

  Future<void> setBudget({
    required int categoryId,
    required int amount,
    DateTime? anchor,
  }) async {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    final db = await _database.database;
    final period = await ensureBudgetPeriod(anchor ?? DateTime.now());
    final now = DateTime.now().toIso8601String();
    await db.insert('monthly_budgets', {
      'period_id': period.id,
      'category_id': categoryId,
      'amount': amount,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _evaluateBudgetAlerts(
      categoryId: categoryId,
      anchor: anchor ?? DateTime.now(),
    );
    _notifyChanged();
  }

  Future<void> _checkActiveCategoryName(
    DatabaseExecutor db,
    String name, {
    int? excludingId,
  }) async {
    if (await _hasActiveName(db, 'categories', name, excludingId)) {
      throw const DuplicateActiveCategoryName();
    }
  }

  Future<void> _checkActivePaymentMethodName(
    DatabaseExecutor db,
    String name, {
    int? excludingId,
  }) async {
    if (await _hasActiveName(db, 'payment_methods', name, excludingId)) {
      throw const DuplicateActivePaymentMethodName();
    }
  }

  Future<bool> _hasActiveName(
    DatabaseExecutor db,
    String table,
    String name,
    int? excludingId,
  ) async {
    final normalized = normalizeManagedName(name);
    final rows = await db.query(
      table,
      columns: ['id', 'name'],
      where: 'is_active = 1',
    );
    return rows.any(
      (row) =>
          row['id'] != excludingId &&
          normalizeManagedName(row['name'] as String) == normalized,
    );
  }

  Future<void> addCategory({
    required String name,
    required String colorHex,
    bool alertsEnabled = true,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await _checkActiveCategoryName(txn, name);
      final now = DateTime.now().toIso8601String();
      final orderRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM categories',
      );
      await txn.insert('categories', {
        'name': name.trim(),
        'color_hex': colorHex,
        'sort_order': _asInt(orderRows.first['next_order']),
        'is_active': 1,
        'alerts_enabled': alertsEnabled ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });
    });
    _notifyChanged();
  }

  Future<void> updateCategory({
    required int id,
    required String name,
    required String colorHex,
    bool? alertsEnabled,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await _checkActiveCategoryName(txn, name, excludingId: id);
      await txn.update(
        'categories',
        {
          'name': name.trim(),
          'color_hex': colorHex,
          if (alertsEnabled != null) 'alerts_enabled': alertsEnabled ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    _notifyChanged();
  }

  Future<void> setCategoryAlertsEnabled(bool enabled, {int? categoryId}) async {
    final db = await _database.database;
    await db.update(
      'categories',
      {
        'alerts_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: categoryId == null ? 'is_active = 1' : 'is_active = 1 AND id = ?',
      whereArgs: categoryId == null ? null : [categoryId],
    );
    _notifyChanged();
  }

  Future<void> setCategoryActive(
    int id,
    bool active, {
    String? colorHex,
    bool? alertsEnabled,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      if (active) {
        final rows = await txn.query(
          'categories',
          columns: ['name'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) return;
        await _checkActiveCategoryName(
          txn,
          rows.single['name'] as String,
          excludingId: id,
        );
      } else {
        final others = await txn.query(
          'categories',
          where: 'is_active = 1 AND id != ?',
          whereArgs: [id],
          limit: 1,
        );
        if (others.isEmpty) throw StateError('최소 1개 카테고리를 유지해 주세요.');
      }
      await txn.update(
        'categories',
        {
          'is_active': active ? 1 : 0,
          'color_hex': ?colorHex,
          if (alertsEnabled != null) 'alerts_enabled': alertsEnabled ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    _notifyChanged();
  }

  Future<void> setPaymentMethodActive(int id, bool active) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      if (active) {
        final rows = await txn.query(
          'payment_methods',
          columns: ['name'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) return;
        await _checkActivePaymentMethodName(
          txn,
          rows.single['name'] as String,
          excludingId: id,
        );
      }
      await txn.update(
        'payment_methods',
        {
          'is_active': active ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    _notifyChanged();
  }

  Future<void> removeCategory(int id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final active = await txn.query(
        'categories',
        columns: ['id'],
        where: 'is_active = 1',
        limit: 2,
      );
      if (active.length == 1 && active.single['id'] == id) {
        throw StateError('최소 1개 카테고리를 유지해 주세요.');
      }
      final references = await txn.rawQuery(
        '''
        SELECT
          (SELECT COUNT(*) FROM transactions WHERE category_id = ?) +
          (SELECT COUNT(*) FROM monthly_budgets WHERE category_id = ?) +
          (SELECT COUNT(*) FROM expense_templates WHERE category_id = ?) AS count
        ''',
        [id, id, id],
      );
      if (_asInt(references.first['count']) > 0) {
        await txn.update(
          'categories',
          {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
      }
    });
    _notifyChanged();
  }

  Future<void> savePaymentMethod({int? id, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw ArgumentError('Invalid payment method name.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      await _checkActivePaymentMethodName(txn, trimmed, excludingId: id);
      final now = DateTime.now().toIso8601String();
      if (id == null) {
        await txn.insert('payment_methods', {
          'name': trimmed,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'payment_methods',
          {'name': trimmed, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
    _notifyChanged();
  }

  Future<void> removePaymentMethod(int id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final active = await txn.query(
        'payment_methods',
        columns: ['id'],
        where: 'is_active = 1',
        limit: 2,
      );
      if (active.length == 1 && active.single['id'] == id) {
        throw StateError('최소 1개의 결제수단을 유지해 주세요.');
      }
      final references = await txn.rawQuery(
        '''
        SELECT
          (SELECT COUNT(*) FROM transactions WHERE payment_method_id = ?) +
          (SELECT COUNT(*) FROM expense_templates WHERE payment_method_id = ?)
          AS count
        ''',
        [id, id],
      );
      if (_asInt(references.first['count']) > 0) {
        await txn.update(
          'payment_methods',
          {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
      }
    });
    _notifyChanged();
  }

  Future<void> addTemplate({
    required String name,
    required int amount,
    required int categoryId,
    required int paymentMethodId,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('expense_templates', {
      'name': name.trim(),
      'amount': amount,
      'category_id': categoryId,
      'payment_method_id': paymentMethodId,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    _notifyChanged();
  }

  Future<void> removeTemplate(int id) async {
    final db = await _database.database;
    await db.delete('expense_templates', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  Future<ReportSummary> getReport(DateTime month) async {
    final db = await _database.database;
    final period = await ensureBudgetPeriod(DateTime(month.year, month.month));
    final start = period.startDate;
    final end = period.endExclusive;
    final previousStart = DateTime(start.year, start.month - 1);
    final previousRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE
        WHEN type = 'expense' THEN amount
        WHEN type = 'refund' THEN -amount
        ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE deleted_at IS NULL AND occurred_at >= ? AND occurred_at < ?
      ''',
      [previousStart.toIso8601String(), start.toIso8601String()],
    );
    final totalRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE
          WHEN type = 'expense' THEN amount
          WHEN type = 'refund' THEN -amount
          ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE deleted_at IS NULL AND occurred_at >= ? AND occurred_at < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final usages = await _getBudgetUsages(db, period);
    final dailyRows = await db.rawQuery(
      '''
      SELECT substr(occurred_at, 1, 10) AS date,
        COALESCE(SUM(CASE
          WHEN type = 'expense' THEN amount
          WHEN type = 'refund' THEN -amount
          ELSE 0 END), 0) AS amount
      FROM transactions
      WHERE deleted_at IS NULL AND occurred_at >= ? AND occurred_at < ?
      GROUP BY date
      ORDER BY date
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final paymentRows = await db.rawQuery(
      '''
      SELECT COALESCE(pm.name, '기타') AS name,
        COALESCE(SUM(CASE
          WHEN t.type = 'expense' THEN t.amount
          WHEN t.type = 'refund' THEN -t.amount
          ELSE 0 END), 0) AS amount
      FROM transactions t
      LEFT JOIN payment_methods pm ON pm.id = t.payment_method_id
      WHERE t.deleted_at IS NULL
        AND t.type IN ('expense', 'refund')
        AND t.occurred_at >= ? AND t.occurred_at < ?
      GROUP BY pm.id, pm.name
      ORDER BY amount DESC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final totalBudget = usages.fold<int>(
      0,
      (sum, item) => sum + item.budgetAmount.amount,
    );
    final totalExpense = _asInt(totalRows.first['expense']);
    final transactions = (await listTransactions(
      start: start,
      endExclusive: end,
    )).toList();
    return ReportSummary(
      totalExpense: totalExpense,
      previousMonthExpense: _asInt(previousRows.first['expense']),
      remainingBudget: totalBudget - totalExpense,
      period: BudgetPeriodRange(
        startDate: period.startDate,
        endDate: period.endDate,
      ),
      budgetUsages: usages,
      dailyAmounts: dailyRows
          .map(
            (row) => DailyAmount(
              date: DateTime.parse(row['date']! as String),
              amount: _asInt(row['amount']),
            ),
          )
          .toList(),
      paymentMethodAmounts: paymentRows
          .map(
            (row) => NamedAmount(
              name: row['name']! as String,
              amount: _asInt(row['amount']),
            ),
          )
          .toList(),
      transactions: transactions,
    );
  }

  Future<AnnualSummary> getAnnualSummary(int year) async {
    final db = await _database.database;
    final start = DateTime(year);
    final end = DateTime(year + 1);
    final monthlyRows = await db.rawQuery(
      '''
      SELECT CAST(strftime('%m', occurred_at) AS INTEGER) AS month,
        COALESCE(SUM(CASE
          WHEN type = 'expense' THEN amount
          WHEN type = 'refund' THEN -amount
          ELSE 0 END), 0) AS amount
      FROM transactions
      WHERE deleted_at IS NULL AND occurred_at >= ? AND occurred_at < ?
      GROUP BY month
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final monthlyTotals = List<int>.filled(12, 0);
    for (final row in monthlyRows) {
      monthlyTotals[_asInt(row['month']) - 1] = _asInt(row['amount']);
    }
    final categoryRows = await db.rawQuery(
      '''
      SELECT c.name, c.color_hex,
        COALESCE(SUM(CASE
          WHEN t.type = 'expense' THEN t.amount
          WHEN t.type = 'refund' THEN -t.amount
          ELSE 0 END), 0) AS amount
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.deleted_at IS NULL
        AND t.occurred_at >= ? AND t.occurred_at < ?
      GROUP BY c.id, c.name, c.color_hex
      ORDER BY amount DESC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final trendRows = await db.rawQuery(
      '''
      SELECT c.id, c.name, c.color_hex,
        CAST(strftime('%m', t.occurred_at) AS INTEGER) AS month,
        COALESCE(SUM(CASE
          WHEN t.type = 'expense' THEN t.amount
          WHEN t.type = 'refund' THEN -t.amount
          ELSE 0 END), 0) AS amount
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.deleted_at IS NULL
        AND t.occurred_at >= ? AND t.occurred_at < ?
      GROUP BY c.id, c.name, c.color_hex, month
      ORDER BY c.sort_order, c.id, month
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final trendMap = <int, CategoryAnnualTrend>{};
    for (final row in trendRows) {
      final categoryId = _asInt(row['id']);
      final existing = trendMap[categoryId];
      final amounts = existing?.monthlyAmounts ?? List<int>.filled(12, 0);
      amounts[_asInt(row['month']) - 1] = _asInt(row['amount']);
      trendMap[categoryId] = CategoryAnnualTrend(
        name: row['name']! as String,
        colorHex: row['color_hex']! as String,
        monthlyAmounts: amounts,
      );
    }
    return AnnualSummary(
      year: year,
      monthlyTotals: monthlyTotals,
      categoryTotals: categoryRows
          .map(
            (row) => NamedAmount(
              name: row['name']! as String,
              amount: _asInt(row['amount']),
              colorHex: row['color_hex']! as String,
            ),
          )
          .toList(),
      categoryTrends: trendMap.values.toList(),
    );
  }

  Future<(int?, int?)> getLastExpenseSelection() async {
    return (
      await _settingsStore.getLastCategoryId(),
      await _settingsStore.getLastPaymentMethodId(),
    );
  }

  Future<void> refreshAfterRestore() async {
    await purgeExpiredDeletedTransactions();
    await ensureBudgetPeriod(DateTime.now());
    _notifyChanged();
  }

  Future<List<BudgetUsage>> _getBudgetUsages(
    DatabaseExecutor db,
    BudgetPeriod period,
  ) async {
    final endExclusive = period.endExclusive;
    final rows = await db.rawQuery(
      '''
      SELECT c.id AS category_id, c.name AS category_name,
        c.color_hex AS color_hex,
        COALESCE(mb.amount, 0) AS budget_amount,
        COALESCE(SUM(CASE
          WHEN t.type = 'expense' THEN t.amount
          WHEN t.type = 'refund' THEN -t.amount
          ELSE 0 END), 0) AS spent_amount
      FROM categories c
      LEFT JOIN monthly_budgets mb
        ON mb.category_id = c.id AND mb.period_id = ?
      LEFT JOIN transactions t
        ON t.category_id = c.id
        AND t.deleted_at IS NULL
        AND t.occurred_at >= ?
        AND t.occurred_at < ?
      WHERE c.is_active = 1
      GROUP BY c.id, c.name, c.color_hex, mb.amount
      ORDER BY c.sort_order, c.id
      ''',
      [
        period.id,
        period.startDate.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
    );
    return rows
        .map(
          (row) => BudgetUsage(
            categoryId: _asInt(row['category_id']),
            categoryName: row['category_name']! as String,
            spentAmount: Money(_asInt(row['spent_amount'])),
            budgetAmount: Money(_asInt(row['budget_amount'])),
            colorHex: row['color_hex']! as String,
          ),
        )
        .toList();
  }

  Future<void> _evaluateBudgetAlerts({
    required int categoryId,
    required DateTime anchor,
  }) async {
    final db = await _database.database;
    final period = await ensureBudgetPeriod(anchor);
    final pending = await db.transaction((txn) async {
      final alerts = <(int, String, int)>[];
      final rows = await txn.rawQuery(
        '''
      SELECT c.name, c.alerts_enabled, COALESCE(mb.amount, 0) AS budget,
        COALESCE(SUM(CASE
          WHEN t.type = 'expense' THEN t.amount
          WHEN t.type = 'refund' THEN -t.amount
          ELSE 0 END), 0) AS spent
      FROM categories c
      LEFT JOIN monthly_budgets mb
        ON mb.category_id = c.id AND mb.period_id = ?
      LEFT JOIN transactions t
        ON t.category_id = c.id
        AND t.deleted_at IS NULL
        AND t.occurred_at >= ?
        AND t.occurred_at < ?
      WHERE c.id = ?
      GROUP BY c.id, c.name, c.alerts_enabled, mb.amount
      ''',
        [
          period.id,
          period.startDate.toIso8601String(),
          period.endExclusive.toIso8601String(),
          categoryId,
        ],
      );
      if (rows.isEmpty) return alerts;

      final budget = BigInt.from(_asInt(rows.first['budget']));
      final spentPercent =
          BigInt.from(_asInt(rows.first['spent'])) * BigInt.from(100);
      final categoryName = rows.first['name']! as String;
      final alertsEnabled = rows.first['alerts_enabled'] == 1;
      for (final threshold in const [50, 80, 100]) {
        const where = 'period_id = ? AND category_id = ? AND threshold = ?';
        final keys = [period.id, categoryId, threshold];
        if (budget <= BigInt.zero ||
            spentPercent < budget * BigInt.from(threshold)) {
          await txn.delete('alert_history', where: where, whereArgs: keys);
          continue;
        }
        if (!alertsEnabled) continue;

        final existing = await txn.query(
          'alert_history',
          columns: ['id'],
          where: where,
          whereArgs: keys,
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        final id = await txn.insert('alert_history', {
          'period_id': period.id,
          'category_id': categoryId,
          'threshold': threshold,
          'sent_at': DateTime.now().toIso8601String(),
        });
        alerts.add((id, categoryName, threshold));
      }
      return alerts;
    });

    for (final (alertId, categoryName, threshold) in pending) {
      try {
        // Re-enabling only affects subsequent budget evaluations.
        final shown =
            await _settingsStore.getBudgetAlertsEnabled() &&
            await _notificationService.showBudgetAlert(
              id: alertId,
              categoryName: categoryName,
              threshold: threshold,
            );
        if (!shown) {
          await db.delete(
            'alert_history',
            where: 'id = ?',
            whereArgs: [alertId],
          );
        }
      } catch (error, stackTrace) {
        await db.delete('alert_history', where: 'id = ?', whereArgs: [alertId]);
        log(
          'Could not show budget alert',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<TransactionRecord> _getTransaction(DatabaseExecutor db, int id) async {
    final rows = await db.rawQuery(
      '$_transactionSelect WHERE t.id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) {
      throw StateError('거래 내역을 찾을 수 없습니다.');
    }
    return TransactionRecord.fromMap(rows.first);
  }

  BudgetPeriod _periodFromMap(Map<String, Object?> map) {
    return BudgetPeriod(
      id: map['id']! as int,
      startDate: DateTime.parse(map['start_date']! as String),
      endDate: DateTime.parse(map['end_date']! as String),
    );
  }

  void _notifyChanged() {
    _revision++;
    _changes.add(_revision);
  }

  void dispose() {
    _changes.close();
  }

  static int _asInt(Object? value) {
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };
  }

  static String _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day).toIso8601String();
  }

  static DateTime _subtractMonthsClamped(DateTime value, int months) {
    final targetMonth = DateTime(value.year, value.month - months);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    return DateTime(
      targetMonth.year,
      targetMonth.month,
      value.day.clamp(1, lastDay),
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  static const _transactionSelect = '''
    SELECT t.id, t.type, t.occurred_at, t.amount, t.category_id,
      t.payment_method_id, t.memo, t.refunded_expense_id,
      t.deleted_at, c.name AS category_name,
      c.color_hex AS category_color_hex,
      pm.name AS payment_method_name
    FROM transactions t
    LEFT JOIN categories c ON c.id = t.category_id
    LEFT JOIN payment_methods pm ON pm.id = t.payment_method_id
  ''';
}
