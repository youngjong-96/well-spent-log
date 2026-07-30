import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/account.dart';
import '../../domain/models/budget_period_range.dart';
import '../../domain/models/budget_usage.dart';
import '../../domain/models/category.dart';
import '../../domain/models/expense_template.dart';
import '../../domain/models/home_summary.dart';
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
    await _database.database;
    await purgeExpiredDeletedTransactions();
    await ensureBudgetPeriod(DateTime.now());
  }

  Future<HomeSummary> getHomeSummary([DateTime? anchorDate]) async {
    final anchor = anchorDate ?? DateTime.now();
    final db = await _database.database;
    final period = await ensureBudgetPeriod(anchor);
    final balanceRows = await db.rawQuery('''
      SELECT COALESCE(SUM(balance), 0) AS total
      FROM accounts
      WHERE include_in_total = 1 AND is_active = 1
    ''');
    final usages = await _getBudgetUsages(db, period);
    final recent = await listTransactions(limit: 8);
    return HomeSummary(
      totalBalance: Money(_asInt(balanceRows.first['total'])),
      budgetUsages: usages,
      period: BudgetPeriodRange(
        startDate: period.startDate,
        endDate: period.endDate,
      ),
      monthStartDay: period.monthStartDay,
      recentTransactions: recent,
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

  Future<List<Account>> listAccounts({bool includeInactive = false}) async {
    final db = await _database.database;
    final rows = await db.query(
      'accounts',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: "CASE type WHEN 'cash' THEN 0 ELSE 1 END, id",
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<List<PaymentMethod>> listPaymentMethods({
    bool includeInactive = false,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'payment_methods',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: "CASE type WHEN 'cash' THEN 0 ELSE 1 END, id",
    );
    return rows.map(PaymentMethod.fromMap).toList();
  }

  Future<List<ExpenseTemplate>> listTemplates() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT et.*
      FROM expense_templates et
      JOIN categories c ON c.id = et.category_id
      JOIN payment_methods pm ON pm.id = et.payment_method_id
      WHERE et.is_active = 1
        AND c.is_active = 1
        AND pm.is_active = 1
      ORDER BY et.updated_at DESC
    ''');
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

  Future<int> addTransaction(TransactionDraft draft) async {
    if (draft.amount <= 0) {
      throw ArgumentError.value(draft.amount, 'amount');
    }
    if (draft.type != RecordType.income && draft.categoryId == null) {
      throw ArgumentError('지출과 환불에는 카테고리가 필요합니다.');
    }
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final id = await db.transaction<int>((txn) async {
      final account = await _getAccount(txn, draft.accountId);
      final delta = draft.type.signedAmount(draft.amount);
      final nextBalance = account.balance + delta;
      final transactionId = await txn.insert('transactions', {
        'type': draft.type.name,
        'occurred_at': draft.occurredAt.toIso8601String(),
        'amount': draft.amount,
        'category_id': draft.categoryId,
        'payment_method_id': draft.paymentMethodId,
        'account_id': draft.accountId,
        'memo': draft.memo.trim(),
        'refunded_expense_id': draft.refundedExpenseId,
        'created_at': now,
        'updated_at': now,
      });
      await txn.update(
        'accounts',
        {'balance': nextBalance, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [draft.accountId],
      );
      await txn.insert('account_ledger', {
        'account_id': draft.accountId,
        'source_type': draft.type.name,
        'source_id': transactionId,
        'delta': delta,
        'balance_after': nextBalance,
        'created_at': now,
      });
      return transactionId;
    });
    if (draft.type != RecordType.income) {
      await _settingsStore.setLastExpenseSelection(
        categoryId: draft.categoryId!,
        paymentMethodId: draft.paymentMethodId!,
      );
      await _evaluateBudgetAlerts(
        categoryId: draft.categoryId!,
        anchor: draft.occurredAt,
      );
    }
    _notifyChanged();
    return id;
  }

  Future<void> softDeleteTransaction(int transactionId) async {
    final db = await _database.database;
    final now = DateTime.now();
    int? categoryId;
    DateTime? occurredAt;
    await db.transaction((txn) async {
      final record = await _getTransaction(txn, transactionId);
      if (record.isDeleted) {
        return;
      }
      categoryId = record.categoryId;
      occurredAt = record.occurredAt;
      final account = await _getAccount(txn, record.accountId);
      final delta = -record.signedAmount;
      final nextBalance = account.balance + delta;
      await txn.update(
        'transactions',
        {
          'deleted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      await txn.update(
        'accounts',
        {'balance': nextBalance, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [record.accountId],
      );
      await txn.insert('account_ledger', {
        'account_id': record.accountId,
        'source_type': 'delete',
        'source_id': transactionId,
        'delta': delta,
        'balance_after': nextBalance,
        'created_at': now.toIso8601String(),
      });
    });
    if (categoryId != null && occurredAt != null) {
      await _evaluateBudgetAlerts(categoryId: categoryId!, anchor: occurredAt!);
    }
    _notifyChanged();
  }

  Future<void> restoreTransaction(int transactionId) async {
    final db = await _database.database;
    final now = DateTime.now();
    int? categoryId;
    DateTime? occurredAt;
    await db.transaction((txn) async {
      final record = await _getTransaction(txn, transactionId);
      if (!record.isDeleted) {
        return;
      }
      categoryId = record.categoryId;
      occurredAt = record.occurredAt;
      final account = await _getAccount(txn, record.accountId);
      final delta = record.signedAmount;
      final nextBalance = account.balance + delta;
      await txn.update(
        'transactions',
        {'deleted_at': null, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      await txn.update(
        'accounts',
        {'balance': nextBalance, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [record.accountId],
      );
      await txn.insert('account_ledger', {
        'account_id': record.accountId,
        'source_type': 'restore',
        'source_id': transactionId,
        'delta': delta,
        'balance_after': nextBalance,
        'created_at': now.toIso8601String(),
      });
    });
    if (categoryId != null && occurredAt != null) {
      await _evaluateBudgetAlerts(categoryId: categoryId!, anchor: occurredAt!);
    }
    _notifyChanged();
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
        await txn.delete(
          'account_ledger',
          where: 'source_id = ?',
          whereArgs: [id],
        );
        await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<BudgetPeriod> ensureBudgetPeriod(DateTime anchor) async {
    final db = await _database.database;
    final monthStartDay = await _settingsStore.getMonthStartDay();
    final range = const CalculateBudgetPeriod()(
      anchorDate: anchor,
      monthStartDay: monthStartDay,
    );
    final start = _dateOnly(range.startDate);
    final end = _dateOnly(range.endDate);
    final existing = await db.query(
      'budget_periods',
      where: 'start_date = ? AND end_date = ?',
      whereArgs: [start, end],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return _periodFromMap(existing.first);
    }
    final now = DateTime.now().toIso8601String();
    final id = await db.transaction<int>((txn) async {
      final newId = await txn.insert('budget_periods', {
        'start_date': start,
        'end_date': end,
        'month_start_day': monthStartDay,
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
      return newId;
    });
    return BudgetPeriod(
      id: id,
      startDate: range.startDate,
      endDate: range.endDate,
      monthStartDay: monthStartDay,
    );
  }

  Future<void> setMonthStartDay(int day) async {
    if (day < 1 || day > 31) {
      throw ArgumentError.value(day, 'day');
    }
    await _settingsStore.setMonthStartDay(day);
    await ensureBudgetPeriod(DateTime.now());
    _notifyChanged();
  }

  Future<int> getMonthStartDay() => _settingsStore.getMonthStartDay();

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

  Future<void> addCategory({
    required String name,
    required String colorHex,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM categories',
    );
    await db.insert('categories', {
      'name': name.trim(),
      'color_hex': colorHex,
      'sort_order': _asInt(orderRows.first['next_order']),
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    _notifyChanged();
  }

  Future<void> updateCategory({
    required int id,
    required String name,
    required String colorHex,
  }) async {
    final db = await _database.database;
    await db.update(
      'categories',
      {
        'name': name.trim(),
        'color_hex': colorHex,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged();
  }

  Future<void> removeCategory(int id) async {
    final db = await _database.database;
    final references = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM transactions WHERE category_id = ?) +
        (SELECT COUNT(*) FROM monthly_budgets WHERE category_id = ?) +
        (SELECT COUNT(*) FROM expense_templates WHERE category_id = ?) AS count
      ''',
      [id, id, id],
    );
    if (_asInt(references.first['count']) > 0) {
      await db.update(
        'categories',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    }
    _notifyChanged();
  }

  Future<void> addAccount({
    required String name,
    required String bankName,
    required String accountNumber,
    required int openingBalance,
    required bool includeInTotal,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final id = await txn.insert('accounts', {
        'type': AccountType.bank.name,
        'name': name.trim(),
        'bank_name': bankName.trim(),
        'account_number': accountNumber.trim(),
        'balance': openingBalance,
        'include_in_total': includeInTotal ? 1 : 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      if (openingBalance != 0) {
        await txn.insert('account_ledger', {
          'account_id': id,
          'source_type': 'opening',
          'delta': openingBalance,
          'balance_after': openingBalance,
          'created_at': now,
        });
      }
    });
    _notifyChanged();
  }

  Future<void> adjustAccountBalance({
    required int accountId,
    required int newBalance,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final account = await _getAccount(txn, accountId);
      final delta = newBalance - account.balance;
      await txn.update(
        'accounts',
        {'balance': newBalance, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [accountId],
      );
      await txn.insert('account_ledger', {
        'account_id': accountId,
        'source_type': 'adjustment',
        'delta': delta,
        'balance_after': newBalance,
        'created_at': now,
      });
    });
    _notifyChanged();
  }

  Future<void> setAccountIncluded({
    required int accountId,
    required bool included,
  }) async {
    final db = await _database.database;
    await db.update(
      'accounts',
      {
        'include_in_total': included ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
    _notifyChanged();
  }

  Future<void> removeAccount(int id) async {
    final db = await _database.database;
    final references = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM transactions WHERE account_id = ?) +
        (SELECT COUNT(*) FROM payment_methods WHERE account_id = ?) +
        (SELECT COUNT(*) FROM account_ledger WHERE account_id = ?) AS count
      ''',
      [id, id, id],
    );
    if (_asInt(references.first['count']) > 0) {
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        await txn.update(
          'accounts',
          {'is_active': 0, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.update(
          'payment_methods',
          {'is_active': 0, 'updated_at': now},
          where: 'account_id = ?',
          whereArgs: [id],
        );
      });
    } else {
      await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    }
    _notifyChanged();
  }

  Future<void> addCard({
    required String name,
    required String company,
    required int billingDay,
    required int accountId,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('payment_methods', {
      'type': PaymentMethodType.card.name,
      'name': name.trim(),
      'card_company': company.trim(),
      'billing_day': billingDay,
      'account_id': accountId,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    _notifyChanged();
  }

  Future<void> updateAccount({
    required int id,
    required String name,
    required String bankName,
    required String accountNumber,
  }) async {
    final db = await _database.database;
    await db.update(
      'accounts',
      {
        'name': name.trim(),
        'bank_name': bankName.trim(),
        'account_number': accountNumber.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged();
  }

  Future<void> updateCard({
    required int id,
    required String name,
    required String company,
    required int billingDay,
    required int accountId,
  }) async {
    final db = await _database.database;
    await db.update(
      'payment_methods',
      {
        'name': name.trim(),
        'card_company': company.trim(),
        'billing_day': billingDay,
        'account_id': accountId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged();
  }

  Future<void> removePaymentMethod(int id) async {
    final db = await _database.database;
    final references = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM transactions WHERE payment_method_id = ?) +
        (SELECT COUNT(*) FROM expense_templates WHERE payment_method_id = ?)
        AS count
      ''',
      [id, id],
    );
    if (_asInt(references.first['count']) > 0) {
      await db.update(
        'payment_methods',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
    }
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
    final monthStartDay = await _settingsStore.getMonthStartDay();
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final period = await ensureBudgetPeriod(
      DateTime(
        month.year,
        month.month,
        monthStartDay > lastDay ? lastDay : monthStartDay,
      ),
    );
    final start = period.startDate;
    final end = period.endDate.add(const Duration(days: 1));
    final totalRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE
          WHEN type = 'expense' THEN amount
          WHEN type = 'refund' THEN -amount
          ELSE 0 END), 0) AS expense,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0)
          AS income
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
    final periodSpent = usages.fold<int>(
      0,
      (sum, item) => sum + item.spentAmount.amount,
    );
    return ReportSummary(
      totalExpense: _asInt(totalRows.first['expense']),
      totalIncome: _asInt(totalRows.first['income']),
      remainingBudget: totalBudget - periodSpent,
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
    final endExclusive = period.endDate.add(const Duration(days: 1));
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
    final rows = await db.rawQuery(
      '''
      SELECT c.name, COALESCE(mb.amount, 0) AS budget,
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
      GROUP BY c.id, c.name, mb.amount
      ''',
      [
        period.id,
        period.startDate.toIso8601String(),
        period.endDate.add(const Duration(days: 1)).toIso8601String(),
        categoryId,
      ],
    );
    if (rows.isEmpty) {
      return;
    }
    final budget = _asInt(rows.first['budget']);
    if (budget <= 0) {
      return;
    }
    final ratio = _asInt(rows.first['spent']) / budget * 100;
    final categoryName = rows.first['name']! as String;
    for (final threshold in const [50, 80, 100]) {
      if (ratio >= threshold) {
        final existing = await db.query(
          'alert_history',
          columns: ['id'],
          where: 'period_id = ? AND category_id = ? AND threshold = ?',
          whereArgs: [period.id, categoryId, threshold],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('alert_history', {
            'period_id': period.id,
            'category_id': categoryId,
            'threshold': threshold,
            'sent_at': DateTime.now().toIso8601String(),
          });
          await _notificationService.showBudgetAlert(
            id: period.id * 100000 + categoryId * 100 + threshold,
            categoryName: categoryName,
            threshold: threshold,
          );
        }
      } else {
        await db.delete(
          'alert_history',
          where: 'period_id = ? AND category_id = ? AND threshold = ?',
          whereArgs: [period.id, categoryId, threshold],
        );
      }
    }
  }

  Future<Account> _getAccount(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('계좌를 찾을 수 없습니다.');
    }
    return Account.fromMap(rows.first);
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
      monthStartDay: map['month_start_day']! as int,
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
      t.payment_method_id, t.account_id, t.memo, t.refunded_expense_id,
      t.deleted_at, c.name AS category_name,
      c.color_hex AS category_color_hex,
      pm.name AS payment_method_name,
      a.name AS account_name
    FROM transactions t
    LEFT JOIN categories c ON c.id = t.category_id
    LEFT JOIN payment_methods pm ON pm.id = t.payment_method_id
    JOIN accounts a ON a.id = t.account_id
  ''';
}
