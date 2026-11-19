import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';
import 'package:well_spent_log/src/data/repositories/finance_repository.dart';
import 'package:well_spent_log/src/data/services/backup_service.dart';
import 'package:well_spent_log/src/data/services/notification_service.dart';
import 'package:well_spent_log/src/data/settings/settings_store.dart';
import 'package:well_spent_log/src/domain/models/transaction_draft.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';

class _Alerts extends NotificationService {
  final thresholds = <int>[];
  bool fail = false;
  @override
  Future<void> showBudgetAlert({
    required int id,
    required String categoryName,
    required int threshold,
  }) async {
    if (fail) throw StateError('Notification unavailable');
    thresholds.add(threshold);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase database;
  late FinanceRepository repository;
  late _Alerts alerts;
  final month = DateTime(2026, 11);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    alerts = _Alerts();
    repository = FinanceRepository(
      database: database,
      settingsStore: SettingsStore(),
      notificationService: alerts,
    );
    await repository.initialize();
  });
  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  TransactionDraft draft(
    int amount, {
    RecordType type = RecordType.expense,
    int? source,
    int method = 1,
    int category = 1,
  }) => TransactionDraft(
    type: type,
    occurredAt: month,
    amount: amount,
    categoryId: category,
    paymentMethodId: method,
    refundedExpenseId: source,
  );

  test(
    'expense edits, refunds, delete and restore work without accounts',
    () async {
      final db = await database.database;
      expect(
        await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name IN ('accounts', 'account_ledger')",
        ),
        isEmpty,
      );
      await repository.setBudget(categoryId: 1, amount: 10000, anchor: month);
      final id = await repository.addTransaction(draft(6000));
      final refund = await repository.addTransaction(
        draft(1000, type: RecordType.refund, source: id),
      );
      expect((await repository.getReport(month)).totalExpense, 5000);
      await repository.updateTransaction(id, draft(8000));
      expect((await repository.getReport(month)).remainingBudget, 3000);
      await repository.softDeleteTransaction(refund);
      await repository.softDeleteTransaction(refund);
      expect((await repository.getReport(month)).totalExpense, 8000);
      await repository.restoreTransaction(refund);
      expect((await repository.getAnnualSummary(2026)).monthlyTotals[10], 7000);
      await expectLater(
        repository.updateTransaction(id, draft(4000, method: -1)),
        throwsArgumentError,
      );
      expect(
        (await repository.listTransactions())
            .singleWhere((row) => row.id == id)
            .amount,
        8000,
      );
      await expectLater(
        repository.addTransaction(draft(0)),
        throwsArgumentError,
      );
      await expectLater(
        db.insert('transactions', {'type': 'income'}),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'user names have no fixed payment type and referenced methods are hidden',
    () async {
      for (final name in ['국민카드', '삼성카드', '네이버페이']) {
        await repository.savePaymentMethod(name: name);
      }
      final method = (await repository.listPaymentMethods()).last;
      await repository.addTemplate(
        name: '커피',
        amount: 4000,
        categoryId: 1,
        paymentMethodId: method.id,
      );
      final id = await repository.addTransaction(
        draft(4000, method: method.id),
      );
      await repository.savePaymentMethod(id: method.id, name: '내 결제수단');
      expect(
        (await repository.listTransactions()).single.paymentMethodName,
        '내 결제수단',
      );
      await repository.removePaymentMethod(method.id);
      expect(
        (await repository.listPaymentMethods()).map((m) => m.id),
        isNot(contains(method.id)),
      );
      expect((await repository.listTransactions()).single.id, id);
      expect(await repository.listTemplates(), isEmpty);
      await repository.savePaymentMethod(name: '임시');
      final unused = (await repository.listPaymentMethods()).last;
      await repository.removePaymentMethod(unused.id);
      expect(
        (await repository.listPaymentMethods(
          includeInactive: true,
        )).map((m) => m.id),
        isNot(contains(unused.id)),
      );
      await expectLater(
        repository.savePaymentMethod(name: '  '),
        throwsArgumentError,
      );
    },
  );

  test('alert thresholds reset after refund and can trigger again', () async {
    await repository.setBudget(categoryId: 1, amount: 10000, anchor: month);
    await repository.addTransaction(draft(8000));
    expect(alerts.thresholds, [50, 80]);
    await repository.addTransaction(draft(4000, type: RecordType.refund));
    await repository.addTransaction(draft(1000));
    expect(alerts.thresholds, [50, 80, 50]);
  });

  test('expired soft-deleted originals detach surviving refunds', () async {
    final id = await repository.addTransaction(draft(5000));
    await repository.addTransaction(
      draft(1000, type: RecordType.refund, source: id),
    );
    await repository.softDeleteTransaction(id);
    final db = await database.database;
    await db.update(
      'transactions',
      {'deleted_at': '2020-01-01T00:00:00.000'},
      where: 'id = ?',
      whereArgs: [id],
    );
    await repository.purgeExpiredDeletedTransactions();
    expect(
      (await repository.listTransactions()).single.refundedExpenseId,
      isNull,
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('invalid backup rolls back the entire replacement', () async {
    await repository.addTransaction(draft(1234));
    final db = await database.database;
    final data = <String, Object?>{'schemaVersion': 2};
    for (final table in [
      'categories',
      'payment_methods',
      'budget_periods',
      'monthly_budgets',
      'transactions',
      'expense_templates',
      'alert_history',
    ]) {
      data[table] = await db.query(table);
    }
    data['transactions'] = [
      {...(data['transactions']! as List).first as Map, 'category_id': -1},
    ];
    await expectLater(
      BackupService(database).restoreJson(utf8.encode(jsonEncode(data))),
      throwsFormatException,
    );
    expect((await repository.listTransactions()).single.amount, 1234);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test(
    'offline JSON round trip and CSV omit accounts and deleted originals',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'spending_exports_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final backup = BackupService(database, exportDirectory: directory);
      await repository.savePaymentMethod(name: '네이버페이');
      final method = (await repository.listPaymentMethods()).last;
      await repository.setBudget(categoryId: 1, amount: 10000, anchor: month);
      await repository.addTemplate(
        name: '점심',
        amount: 5000,
        categoryId: 1,
        paymentMethodId: method.id,
      );
      final original = await repository.addTransaction(
        draft(5000, method: method.id),
      );
      await repository.addTransaction(
        draft(
          1000,
          method: method.id,
          type: RecordType.refund,
          source: original,
        ),
      );
      await repository.softDeleteTransaction(original);
      final json = await (await backup.createJsonBackup()).readAsBytes();
      final data = jsonDecode(utf8.decode(json)) as Map;
      expect(data['schemaVersion'], 2);
      expect(data.containsKey('accounts'), isFalse);
      expect(data.containsKey('account_ledger'), isFalse);
      expect(
        (data['transactions'] as List).single['refunded_expense_id'],
        isNull,
      );
      final csv = await (await backup.createCsvExport()).readAsString();
      expect(csv, contains('네이버페이'));
      expect(csv, contains('환불'));
      expect(csv, isNot(contains('계좌')));
      await repository.addTransaction(draft(999));
      await backup.restoreJson(json);
      expect((await repository.listTransactions()).single.amount, 1000);
      expect((await repository.listTemplates()).single.name, '점심');
      expect((await repository.getReport(month)).remainingBudget, 11000);
      expect(
        await (await database.database).rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );

  test(
    'ZIP contains an unmodified UTF-8 CSV including special memo characters',
    () async {
      final directory = await Directory.systemTemp.createTemp('spending_zip_');
      addTearDown(() => directory.delete(recursive: true));
      final backup = BackupService(database, exportDirectory: directory);
      await repository.addTransaction(
        TransactionDraft(
          type: RecordType.expense,
          occurredAt: month,
          amount: 1234,
          categoryId: 1,
          paymentMethodId: 1,
          memo: '점심, "메모"\n둘째 줄',
        ),
      );
      final csv = await backup.createCsvExport();
      final expectedBytes = await csv.readAsBytes();
      final zip = await backup.createCsvZipExport();
      final archive = ZipDecoder().decodeBytes(
        await zip.readAsBytes(),
        verify: true,
      );
      expect(archive.files, hasLength(1));
      final file = archive.files.single;
      expect(file.name, endsWith('.csv'));
      expect(file.name, isNot(contains('/')));
      expect(file.content, expectedBytes);
      expect(utf8.decode(file.content), contains('"점심, ""메모""\n둘째 줄"'));
    },
  );

  test(
    'alert thresholds are exact for large integers and reset at zero budget',
    () async {
      const budget = 9000000000000000000;
      await repository.setBudget(categoryId: 1, amount: budget, anchor: month);
      await repository.addTransaction(draft(budget ~/ 2 - 1));
      expect(alerts.thresholds, isEmpty);
      await repository.addTransaction(draft(1));
      expect(alerts.thresholds, [50]);

      await repository.setBudget(categoryId: 1, amount: 0, anchor: month);
      expect(
        (await database.database).query('alert_history'),
        completion(isEmpty),
      );
      await repository.setBudget(categoryId: 1, amount: budget, anchor: month);
      expect(alerts.thresholds, [50, 50]);
    },
  );

  test(
    'failed notification does not fail a saved expense or consume its threshold',
    () async {
      await repository.setBudget(categoryId: 1, amount: 100, anchor: month);
      alerts.fail = true;
      final id = await repository.addTransaction(draft(50));
      expect((await repository.listTransactions()).single.id, id);
      expect(await (await database.database).query('alert_history'), isEmpty);

      alerts.fail = false;
      await repository.updateTransaction(id, draft(50));
      expect(alerts.thresholds, [50]);
    },
  );

  test(
    'monthly and annual reports include leap day and exclude the next midnight',
    () async {
      for (final (date, amount) in [
        (DateTime(2023, 12, 31, 23, 59, 59, 999, 999), 1),
        (DateTime(2024), 2),
        (DateTime(2024, 2, 29, 23, 59, 59, 999, 999), 4),
        (DateTime(2024, 3), 8),
      ]) {
        await repository.addTransaction(
          TransactionDraft(
            type: RecordType.expense,
            occurredAt: date,
            amount: amount,
            categoryId: 1,
            paymentMethodId: 1,
          ),
        );
      }
      final january = await repository.getReport(DateTime(2024));
      expect(january.totalExpense, 2);
      expect(january.previousMonthExpense, 1);
      final february = await repository.getReport(DateTime(2024, 2));
      expect(february.dailyAmounts.single.date, DateTime(2024, 2, 29));
      expect(february.totalExpense, 4);
      expect((await repository.getAnnualSummary(2024)).monthlyTotals.take(3), [
        2,
        4,
        8,
      ]);
    },
  );

  test(
    'successive backups and CSV exports keep their original files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'spending_exports_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final backup = BackupService(database, exportDirectory: directory);
      final firstBackup = await backup.createJsonBackup();
      final firstCsv = await backup.createCsvExport();
      await repository.addTransaction(draft(1234));
      final secondBackup = await backup.createJsonBackup();
      final secondCsv = await backup.createCsvExport();

      expect(firstBackup.path, isNot(secondBackup.path));
      expect(firstCsv.path, isNot(secondCsv.path));
      expect(
        (jsonDecode(await firstBackup.readAsString()) as Map)['transactions'],
        isEmpty,
      );
      expect(await firstCsv.readAsString(), isNot(contains('1234')));
      expect(await secondCsv.readAsString(), contains('1234'));
    },
  );

  test(
    'concurrent requests create one period and carry budgets forward once',
    () async {
      await repository.setBudget(categoryId: 1, amount: 100, anchor: month);
      final nextMonth = DateTime(month.year, month.month + 1);
      final periods = await Future.wait([
        for (var i = 0; i < 3; i++) repository.ensureBudgetPeriod(nextMonth),
      ]);
      expect(periods.map((period) => period.id).toSet(), hasLength(1));
      final report = await repository.getReport(nextMonth);
      expect(report.remainingBudget, 100);
    },
  );

  test(
    'remaining budget agrees with home when a spent category is hidden',
    () async {
      await repository.setBudget(categoryId: 1, amount: 10000, anchor: month);
      await repository.addTransaction(draft(2500, category: 2));
      await repository.setCategoryActive(2, false);
      final home = await repository.getHomeSummary(month);
      final report = await repository.getReport(month);
      expect(home.monthlyExpense.amount, 2500);
      expect(report.totalExpense, home.monthlyExpense.amount);
      expect(report.remainingBudget, 7500);
    },
  );

  test(
    'restore rejects invalid transaction dates and noninteger amounts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'spending_exports_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final backup = BackupService(database, exportDirectory: directory);
      await repository.addTransaction(draft(1234));
      final file = await backup.createJsonBackup();
      final data = jsonDecode(await file.readAsString()) as Map;
      final record = (data['transactions'] as List).single as Map;
      for (final invalid in [
        {...record, 'occurred_at': '2026-invalid'},
        {...record, 'amount': 10.5},
      ]) {
        data['transactions'] = [invalid];
        await expectLater(
          backup.restoreJson(utf8.encode(jsonEncode(data))),
          throwsFormatException,
        );
        expect((await repository.listTransactions()).single.amount, 1234);
      }
    },
  );
}
