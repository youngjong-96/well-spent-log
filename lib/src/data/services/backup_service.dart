import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../settings/settings_store.dart';

class BackupService {
  BackupService(this._appDatabase, this._settingsStore);

  final AppDatabase _appDatabase;
  final SettingsStore _settingsStore;

  static const schemaVersion = 1;
  static const _tables = [
    'categories',
    'accounts',
    'payment_methods',
    'budget_periods',
    'monthly_budgets',
    'transactions',
    'account_ledger',
    'expense_templates',
    'alert_history',
  ];

  Future<File> createJsonBackup() async {
    final db = await _appDatabase.database;
    final data = <String, Object?>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {'monthStartDay': await _settingsStore.getMonthStartDay()},
    };
    for (final table in _tables) {
      data[table] = await _rowsForExport(db, table);
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'well_spent_log_backup_${_timestamp()}.json',
    );
    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  Future<File> createCsvExport() async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT t.occurred_at, t.type, t.amount, c.name AS category,
        pm.name AS payment_method, a.name AS account, t.memo
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN payment_methods pm ON pm.id = t.payment_method_id
      JOIN accounts a ON a.id = t.account_id
      WHERE t.deleted_at IS NULL
      ORDER BY t.occurred_at, t.id
    ''');
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('날짜,구분,금액,카테고리,결제수단,계좌,메모');
    for (final row in rows) {
      buffer.writeln(
        [
          row['occurred_at'],
          _typeLabel(row['type'] as String),
          row['amount'],
          row['category'] ?? '',
          row['payment_method'] ?? '',
          row['account'] ?? '',
          row['memo'] ?? '',
        ].map(_csvCell).join(','),
      );
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'well_spent_log_${_timestamp()}.csv',
    );
    return file.writeAsString(buffer.toString(), flush: true);
  }

  Future<void> restoreJson(List<int> bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException('지원하지 않는 백업 파일입니다.');
    }
    for (final table in _tables) {
      if (decoded[table] is! List) {
        throw FormatException('$table 데이터가 없습니다.');
      }
    }
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in _tables.reversed) {
        await txn.delete(table);
      }
      for (final table in _tables) {
        final rows = decoded[table]! as List;
        for (final row in rows) {
          if (row is! Map) {
            throw FormatException('$table 데이터 형식이 잘못됐습니다.');
          }
          await txn.insert(
            table,
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }
    });
    final settings = decoded['settings'];
    if (settings is Map && settings['monthStartDay'] is int) {
      await _settingsStore.setMonthStartDay(settings['monthStartDay']! as int);
    }
  }

  Future<List<Map<String, Object?>>> _rowsForExport(Database db, String table) {
    if (table == 'transactions') {
      return db.query(table, where: 'deleted_at IS NULL');
    }
    if (table == 'account_ledger') {
      return db.rawQuery('''
        SELECT l.*
        FROM account_ledger l
        WHERE l.source_id IS NULL
          OR EXISTS (
            SELECT 1 FROM transactions t
            WHERE t.id = l.source_id AND t.deleted_at IS NULL
          )
      ''');
    }
    return db.query(table);
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  String _typeLabel(String type) => switch (type) {
    'expense' => '지출',
    'income' => '수입',
    'refund' => '환불',
    _ => type,
  };
}
