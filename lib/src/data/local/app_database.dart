import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
          await _seed(db);
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
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        bank_name TEXT,
        account_number TEXT,
        balance INTEGER NOT NULL DEFAULT 0,
        include_in_total INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        card_company TEXT,
        billing_day INTEGER,
        account_id INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
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
        type TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id INTEGER,
        payment_method_id INTEGER,
        account_id INTEGER NOT NULL,
        memo TEXT NOT NULL DEFAULT '',
        refunded_expense_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
        FOREIGN KEY (account_id) REFERENCES accounts(id),
        FOREIGN KEY (refunded_expense_id) REFERENCES transactions(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE account_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        source_type TEXT NOT NULL,
        source_id INTEGER,
        delta INTEGER NOT NULL,
        balance_after INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
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
      ('식비', '#7A5CFA'),
      ('카페/간식', '#8B6F47'),
      ('교통', '#007E9E'),
      ('생활', '#4C7C59'),
      ('쇼핑', '#B04A82'),
      ('구독/고정비', '#5E6472'),
      ('건강', '#2A9D8F'),
      ('기타', '#8A817C'),
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
    final cashAccountId = await db.insert('accounts', {
      'type': 'cash',
      'name': '현금',
      'balance': 0,
      'include_in_total': 1,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('payment_methods', {
      'type': 'cash',
      'name': '현금',
      'account_id': cashAccountId,
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
