import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../local/spending_data.dart';

class BackupService {
  BackupService(this._appDatabase, {Directory? exportDirectory})
    : _exportDirectory = exportDirectory;

  final AppDatabase _appDatabase;
  final Directory? _exportDirectory;

  static const schemaVersion = 2;
  static const _tables = spendingTables;

  Future<File?> findMigrationBackup() async {
    final db = await _appDatabase.database;
    final file = File('${db.path}.pre-v3.json');
    return await file.exists() ? file : null;
  }

  Future<File> createJsonBackup() async {
    final db = await _appDatabase.database;
    final data = <String, Object?>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    for (final table in _tables) {
      data[table] = await _rowsForExport(db, table);
    }
    // A deleted original expense is excluded from backups; detach its refunds.
    final transactions = data['transactions']! as List<Map<String, Object?>>;
    final includedIds = transactions.map((row) => row['id']).toSet();
    data['transactions'] = transactions
        .map(
          (row) => {
            ...row,
            if (!includedIds.contains(row['refunded_expense_id']))
              'refunded_expense_id': null,
          },
        )
        .toList();
    final directory = _exportDirectory ?? await getTemporaryDirectory();
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
        pm.name AS payment_method, t.memo
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN payment_methods pm ON pm.id = t.payment_method_id
      WHERE t.deleted_at IS NULL
      ORDER BY t.occurred_at, t.id
    ''');
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('날짜,구분,금액,카테고리,결제수단,메모');
    for (final row in rows) {
      buffer.writeln(
        [
          row['occurred_at'],
          _typeLabel(row['type'] as String),
          row['amount'],
          row['category'] ?? '',
          row['payment_method'] ?? '',
          row['memo'] ?? '',
        ].map(_csvCell).join(','),
      );
    }
    final directory = _exportDirectory ?? await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'well_spent_log_${_timestamp()}.csv',
    );
    return file.writeAsString(buffer.toString(), flush: true);
  }

  Future<File> createCsvZipExport() async {
    final csv = await createCsvExport();
    final bytes = await csv.readAsBytes();
    final archive = Archive()
      ..addFile(ArchiveFile(csv.uri.pathSegments.last, bytes.length, bytes));
    final zip = File('${csv.path.substring(0, csv.path.length - 4)}.zip');
    return zip.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  }

  Future<void> restoreJson(List<int> bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?> ||
        ![1, schemaVersion].contains(decoded['schemaVersion'])) {
      throw const FormatException('지원하지 않는 백업 파일입니다.');
    }
    final data = decoded['schemaVersion'] == 1
        ? convertLegacyData(decoded)
        : decoded;
    for (final table in _tables) {
      if (data[table] is! List) {
        throw FormatException('$table 데이터가 없습니다.');
      }
    }
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      await txn.update('transactions', {'refunded_expense_id': null});
      for (final table in _tables.reversed) {
        await txn.delete(table);
      }
      for (final table in _tables) {
        final rows = data[table]! as List;
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
      // Reject deferred violations inside the transaction so replacement rolls
      // back cleanly rather than failing at COMMIT on a platform driver.
      if ((await txn.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const FormatException('백업 데이터의 연결 정보가 올바르지 않습니다.');
      }
    });
  }

  Future<List<Map<String, Object?>>> _rowsForExport(Database db, String table) {
    if (table == 'transactions') {
      return db.query(table, where: 'deleted_at IS NULL');
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
    'refund' => '환불',
    _ => type,
  };
}
