import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';
import 'package:well_spent_log/src/data/services/backup_service.dart';
import 'package:well_spent_log/src/features/manage/backup_screen.dart';

class _Backup extends BackupService {
  _Backup()
    : super(
        AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
        ),
      );
  @override
  Future<File?> findMigrationBackup() async => null;
  @override
  Future<File> createCsvExport() async =>
      File('${Directory.systemTemp.path}/test_export.csv');
  @override
  Future<File> createCsvZipExport() async =>
      File('${Directory.systemTemp.path}/test_export.zip');
  @override
  Future<File> createJsonBackup() async =>
      File('${Directory.systemTemp.path}/test_backup.json');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final calls = <MethodCall>[];
  String result = 'com.kakao.talk';
  setUp(() {
    calls.clear();
    result = 'com.kakao.talk';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return result;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backupServiceProvider.overrideWithValue(_Backup())],
        child: const MaterialApp(home: BackupScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (label, mime, extension) in [
    ('CSV 파일 공유', 'application/octet-stream', '.csv'),
    ('ZIP으로 공유', 'application/zip', '.zip'),
  ]) {
    testWidgets(
      '$label sends a file attachment to the Android sharing channel',
      (tester) async {
        await open(tester);
        await tester.tap(find.text('거래내역 내보내기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('계속'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(calls.single.method, 'share');
        final args = calls.single.arguments as Map;
        expect(args['mimeTypes'], [mime]);
        expect((args['paths'] as List).single, endsWith(extension));
        // Do not convert private CSV content into a chat message.
        expect(args.containsKey('text'), isFalse);
        expect(
          find.text('파일 공유를 요청했어요. 전송 결과는 공유 앱에서 확인해 주세요.'),
          findsOneWidget,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'JSON still shares as JSON and cancelling is reported',
    (tester) async {
      result = '';
      await open(tester);
      await tester.tap(find.text('전체 백업 내보내기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속'));
      await tester.pumpAndSettle();
      expect((calls.single.arguments as Map)['mimeTypes'], [
        'application/json',
      ]);
      expect(find.text('공유를 취소했어요.'), findsOneWidget);
      expect(find.textContaining('파일 공유를 요청했어요.'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'cancelling export consent never opens a share sheet',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('거래내역 내보내기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('CSV 파일 공유'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
