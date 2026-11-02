import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';
import 'package:well_spent_log/src/data/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for (final oldVersion in [1, 2]) {
    test(
      'version $oldVersion migrates spending and preserves the complete original backup',
      () async {
        final temporary = await Directory.systemTemp.createTemp(
          'spending_migration_',
        );
        addTearDown(() => temporary.delete(recursive: true));
        final path = temporary.path;
        final databasePath = '$path/palette_migration_test.db';
        await databaseFactoryFfi.deleteDatabase(databasePath);
        addTearDown(() => databaseFactoryFfi.deleteDatabase(databasePath));

        final oldDatabase = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: oldVersion,
            onCreate: (db, version) async {
              for (final sql in (await File(
                'test/fixtures/legacy_v2.sql',
              ).readAsString()).split(';')) {
                if (sql.trim().isNotEmpty) await db.execute(sql);
              }
              for (var id = 1; id <= 4; id++) {
                await db.insert('categories', {
                  'id': id,
                  'name': 'category$id',
                  'color_hex': '#FF0000',
                  'created_at': '2026-01-01',
                  'updated_at': '2026-01-01',
                });
              }
              await db.insert('accounts', {
                'id': 1,
                'type': 'cash',
                'name': 'cash',
                'balance': 12345,
                'created_at': '2026-01-01',
                'updated_at': '2026-01-01',
              });
              await db.insert('payment_methods', {
                'id': 1,
                'type': 'card',
                'name': '국민카드',
                'account_id': 1,
                'billing_day': 20,
                'created_at': '2026-01-01',
                'updated_at': '2026-01-01',
              });
              await db.insert('budget_periods', {
                'id': 1,
                'start_date': '2026-01-01',
                'end_date': '2026-01-31',
                'month_start_day': 1,
                'created_at': '2026-01-01',
              });
              await db.insert('monthly_budgets', {
                'id': 1,
                'period_id': 1,
                'category_id': 1,
                'amount': 10000,
                'created_at': '2026-01-01',
                'updated_at': '2026-01-01',
              });
              for (final (id, type, amount) in [
                (1, 'expense', 5000),
                (2, 'income', 10000),
                (3, 'refund', 1000),
              ]) {
                await db.insert('transactions', {
                  'id': id,
                  'type': type,
                  'amount': amount,
                  'category_id': type == 'income' ? null : 1,
                  'payment_method_id': type == 'income' ? null : 1,
                  'account_id': 1,
                  'occurred_at': '2026-01-02',
                  'created_at': '2026-01-02',
                  'updated_at': '2026-01-02',
                  'refunded_expense_id': type == 'refund' ? 1 : null,
                });
              }
              await db.insert('expense_templates', {
                'id': 1,
                'name': 'coffee',
                'amount': 5000,
                'category_id': 1,
                'payment_method_id': 1,
                'created_at': '2026-01-01',
                'updated_at': '2026-01-01',
              });
            },
          ),
        );
        await oldDatabase.close();

        final appDatabase = AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: databasePath,
        );
        addTearDown(appDatabase.close);
        final rows = await (await appDatabase.database).query(
          'categories',
          orderBy: 'id',
        );

        expect(
          rows.map((row) => row['color_hex']),
          oldVersion == 2
              ? List.filled(4, '#FF0000')
              : ['#84B6E2', '#294761', '#D8E8F5', '#84B6E2'],
        );
        final db = await appDatabase.database;
        expect(await db.getVersion(), 3);
        expect((await db.query('transactions')).map((row) => row['id']), [
          1,
          3,
        ]);
        expect((await db.query('transactions')).last['refunded_expense_id'], 1);
        expect((await db.query('payment_methods')).single['name'], '국민카드');
        expect(
          (await db.query('payment_methods')).single.containsKey('account_id'),
          isFalse,
        );
        expect((await db.query('monthly_budgets')).single['amount'], 10000);
        expect(
          (await db.query('expense_templates')).single['payment_method_id'],
          1,
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        final backup =
            jsonDecode(await File('$databasePath.pre-v3.json').readAsString())
                as Map;
        expect((backup['transactions'] as List).length, 3);
        expect((backup['accounts'] as List).single['balance'], 12345);
        // The same full old snapshot remains importable by the new app offline.
        await BackupService(
          appDatabase,
        ).restoreJson(utf8.encode(jsonEncode(backup)));
        expect((await db.query('transactions')).map((row) => row['id']), [
          1,
          3,
        ]);
        expect((await db.query('transactions')).last['refunded_expense_id'], 1);
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );
  }
}
