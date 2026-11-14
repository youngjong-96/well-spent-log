import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'spending_data.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePath = databasePath;

  final DatabaseFactory _factory;
  final String? _databasePath;
  Database? _database;

  Future<Database> get database async {
    return _database ??= await _open();
  }

  Future<Database> _open() async {
    final path =
        _databasePath ??
        p.join(await _factory.getDatabasesPath(), 'well_spent_log.db');
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
          await _seed(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              UPDATE categories
              SET color_hex = CASE ((id - 1) % 3)
                WHEN 0 THEN '#84B6E2'
                WHEN 1 THEN '#294761'
                ELSE '#D8E8F5'
              END
            ''');
          }
          if (oldVersion < 3) {
            final snapshot = <String, Object?>{
              'schemaVersion': 1,
              'exportedAt': DateTime.now().toIso8601String(),
            };
            for (final table in legacyTables) {
              snapshot[table] = await db.query(table);
            }
            // Keep the complete old data outside SQLite before removing fields.
            // Failure to write the backup aborts the upgrade transaction.
            if (path != inMemoryDatabasePath) {
              final backup = File('$path.pre-v3.json');
              if (!await backup.exists()) {
                final temporary = File('${backup.path}.tmp');
                await temporary.writeAsString(
                  jsonEncode(snapshot),
                  flush: true,
                );
                await temporary.rename(backup.path);
              }
            }
            final converted = convertLegacyData(snapshot);
            await db.execute('PRAGMA defer_foreign_keys = ON');
            // Self references must be cleared before dropping the old table.
            await db.update('transactions', {'refunded_expense_id': null});
            for (final table in legacyTables.reversed) {
              await db.execute('DROP TABLE $table');
            }
            await _createSchema(db);
            for (final table in spendingTables) {
              for (final row in converted[table]!) {
                await db.insert(table, row);
              }
            }
            if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
              throw const FormatException('기존 지출 데이터의 연결 정보를 확인해 주세요.');
            }
          }
        },
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK(length(trim(name)) > 0),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE budget_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        month_start_day INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(start_date, end_date)
      )
    ''');
    await db.execute('''
      CREATE TABLE monthly_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(period_id, category_id),
        FOREIGN KEY (period_id) REFERENCES budget_periods(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK(type IN ('expense', 'refund')),
        occurred_at TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK(amount > 0),
        category_id INTEGER NOT NULL,
        payment_method_id INTEGER NOT NULL,
        memo TEXT NOT NULL DEFAULT '',
        refunded_expense_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
        FOREIGN KEY (refunded_expense_id) REFERENCES transactions(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE expense_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        payment_method_id INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE alert_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        threshold INTEGER NOT NULL,
        sent_at TEXT NOT NULL,
        UNIQUE(period_id, category_id, threshold),
        FOREIGN KEY (period_id) REFERENCES budget_periods(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_transactions_date ON transactions(occurred_at)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_category ON transactions(category_id)',
    );
  }

  Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String();
    const categories = [
      ('식비', '#84B6E2'),
      ('카페/간식', '#294761'),
      ('교통', '#D8E8F5'),
      ('생활', '#84B6E2'),
      ('쇼핑', '#294761'),
      ('구독/고정비', '#D8E8F5'),
      ('건강', '#84B6E2'),
      ('기타', '#294761'),
    ];
    for (var index = 0; index < categories.length; index++) {
      await db.insert('categories', {
        'name': categories[index].$1,
        'color_hex': categories[index].$2,
        'sort_order': index,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await db.insert('payment_methods', {
      'name': '현금',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    await current?.close();
  }
}
