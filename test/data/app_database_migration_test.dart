import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'version 1 category colors migrate to the pastel blue palette',
    () async {
      final path = await databaseFactoryFfi.getDatabasesPath();
      final databasePath = '$path/palette_migration_test.db';
      await databaseFactoryFfi.deleteDatabase(databasePath);
      addTearDown(() => databaseFactoryFfi.deleteDatabase(databasePath));

      final oldDatabase = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY,
              color_hex TEXT NOT NULL
            )
          ''');
            for (var id = 1; id <= 4; id++) {
              await db.insert('categories', {'id': id, 'color_hex': '#FF0000'});
            }
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

      expect(rows.map((row) => row['color_hex']), [
        '#84B6E2',
        '#294761',
        '#D8E8F5',
        '#84B6E2',
      ]);
    },
  );
}
