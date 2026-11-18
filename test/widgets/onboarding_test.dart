import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/app/app_shell.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';
import 'package:well_spent_log/src/data/local/spending_data.dart';
import 'package:well_spent_log/src/data/repositories/finance_repository.dart';
import 'package:well_spent_log/src/data/services/backup_service.dart';
import 'package:well_spent_log/src/data/services/notification_service.dart';
import 'package:well_spent_log/src/data/settings/settings_store.dart';
import 'package:well_spent_log/src/domain/models/transaction_draft.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/features/manage/manage_screen.dart';
import 'package:well_spent_log/src/features/onboarding/onboarding_screen.dart';
import 'package:well_spent_log/src/features/onboarding/coach_mark.dart';
import 'package:well_spent_log/src/features/transaction/transaction_form_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(() => initializeDateFormatting('ko_KR'));
  late AppDatabase database;
  late FinanceRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = FinanceRepository(
      database: database,
      settingsStore: SettingsStore(),
      notificationService: NotificationService(),
    );
    await repository.initialize();
  });
  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repository),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    );
    await settle(tester);
  }

  testWidgets('신규 사용자만 시작 화면을 표시한다', (tester) async {
    await mount(tester, const AppShell());
    expect(find.text('쓰면 바로 기록하자!'), findsOneWidget);
    expect(find.text('백업에서 복원하기'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('이전 달 거래가 있으면 자동 완료하고 홈을 표시한다', (tester) async {
    await tester.runAsync(() async {
      final category = (await repository.listCategories()).first;
      final method = (await repository.listPaymentMethods()).first;
      await repository.addTransaction(
        TransactionDraft(
          type: RecordType.expense,
          occurredAt: DateTime(2020),
          amount: 1000,
          categoryId: category.id,
          paymentMethodId: method.id,
        ),
      );
    });
    await mount(tester, const AppShell());
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(await SettingsStore().getOnboardingCompleted(), isTrue);
  });

  testWidgets('완료 플래그가 있으면 거래가 없어도 온보딩을 생략한다', (tester) async {
    await SettingsStore().setOnboardingCompleted();
    await mount(tester, const AppShell());
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('관리에서 데이터를 유지하며 현재 설정을 다시 본다', (tester) async {
    await tester.runAsync(
      () => repository.addCategory(name: '나만의 분류', colorHex: '#84B6E2'),
    );
    await mount(tester, const Scaffold(body: ManageScreen()));
    await tester.tap(find.text('온보딩 다시 보기'));
    await settle(tester);
    await tester.tap(find.text('시작하기'));
    await settle(tester);
    expect(find.text('나만의 분류'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets);
  });

  testWidgets('숫자 코치마크가 금액과 빠른 더하기와 메모 동작으로 자동 진행한다', (tester) async {
    await mount(
      tester,
      const Scaffold(body: TransactionFormSheet(onboarding: true)),
    );
    expect(find.text('1 / 8'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '15000');
    await settle(tester);
    expect(find.text('2 / 8'), findsOneWidget);
    await tester.ensureVisible(find.text('+1,000'));
    await tester.tap(find.text('+1,000'));
    await settle(tester);
    expect(find.text('3 / 8'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '메모 입력'));
    await settle(tester);
    expect(find.text('4 / 8'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), '점심');
    await settle(tester);
    expect(find.text('5 / 8'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '분류·결제 확인'));
    await settle(tester);
    expect(find.text('6 / 8'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    expect(find.text('7 / 8'), findsOneWidget);
    expect(find.text('저장하면 첫 기록 완료!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('템플릿이 있으면 전체 9단계에 빠른 불러오기를 포함한다', (tester) async {
    await tester.runAsync(() async {
      await repository.addTemplate(
        name: '점심 식사',
        amount: 12000,
        categoryId: (await repository.listCategories()).first.id,
        paymentMethodId: (await repository.listPaymentMethods()).first.id,
      );
    });
    await mount(
      tester,
      const Scaffold(body: TransactionFormSheet(onboarding: true)),
    );
    expect(find.text('1 / 9'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.widgetWithText(FilledButton, '다음'));
      await settle(tester);
    }
    expect(find.text('7 / 9'), findsOneWidget);
    await tester.ensureVisible(find.text('점심 식사'));
    await tester.tap(find.text('점심 식사'));
    await settle(tester);
    expect(find.text('8 / 9'), findsOneWidget);
    expect(find.text('12,000'), findsOneWidget);
  });

  testWidgets('첫 기록 저장 후 실제 홈 예산 안내와 완료 화면을 표시한다', (tester) async {
    await mount(tester, const AppShell());
    await tester.tap(find.text('시작하기'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    await tester.tap(find.text('나중에 할게요'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    expect(find.byType(TransactionFormSheet), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await settle(tester);
    expect(find.text('기록하면 예산이 바로 줄어들어요'), findsOneWidget);
    expect(find.text('8 / 8'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    expect(find.text('첫 기록 완료!'), findsOneWidget);
    await tester.tap(find.text('홈으로'));
    await settle(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    final records = await tester.runAsync(() => repository.listTransactions());
    expect(records!.single.amount, 5000);
    expect(await SettingsStore().getOnboardingCompleted(), isTrue);
  });

  testWidgets('첫 기록을 생략하면 홈 + 안내를 한 번 보여준다', (tester) async {
    await mount(tester, const AppShell());
    await tester.tap(find.text('시작하기'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    await tester.tap(find.text('나중에 할게요'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    await tester.tap(find.text('오늘은 아직 안 썼어요').last);
    await settle(tester);
    expect(find.text('+ 버튼으로 첫 기록을 남겨보세요'), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await settle(tester);
    expect(find.text('+ 버튼으로 첫 기록을 남겨보세요'), findsNothing);
    expect(await SettingsStore().getOnboardingCompleted(), isTrue);
    expect(await SettingsStore().getFirstRecordHintPending(), isFalse);
    final records = await tester.runAsync(() => repository.listTransactions());
    expect(records, isEmpty);
  });

  testWidgets('좁은 화면의 키패드 위에서도 말풍선과 금액 입력칸이 겹치지 않는다', (tester) async {
    await mount(
      tester,
      const Scaffold(body: TransactionFormSheet(onboarding: true)),
    );
    tester.view.physicalSize = const Size(360, 800);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await settle(tester);
    final coach = find.byType(CoachMark);
    final bubble = find.widgetWithText(Material, '사용한 금액을 입력해 보세요').first;
    final bubbleRect = tester.getRect(bubble);
    expect(bubbleRect.bottom, lessThanOrEqualTo(480));
    expect(
      bubbleRect.overlaps(tester.getRect(find.byType(TextFormField).first)),
      isFalse,
    );
    expect(tester.getSize(coach).height, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });

  test('소프트 삭제된 기존 거래도 온보딩 완료 대상이다', () async {
    final category = (await repository.listCategories()).first;
    final method = (await repository.listPaymentMethods()).first;
    final id = await repository.addTransaction(
      TransactionDraft(
        type: RecordType.expense,
        occurredAt: DateTime.now(),
        amount: 1000,
        categoryId: category.id,
        paymentMethodId: method.id,
      ),
    );
    await repository.softDeleteTransaction(id);
    await repository.initialize();
    expect(await SettingsStore().getOnboardingCompleted(), isTrue);
  });

  test('빈 백업 복원도 온보딩을 완료한다', () async {
    final db = await database.database;
    // Export rows directly to avoid the platform file picker in this service test.
    final data = <String, Object?>{
      'schemaVersion': BackupService.schemaVersion,
    };
    for (final table in spendingTables) {
      data[table] = await db.query(table);
    }
    await SettingsStore().setFirstRecordHintPending(true);
    final service = BackupService(database);
    await service.restoreJson(utf8.encode(jsonEncode(data)));
    expect(await SettingsStore().getOnboardingCompleted(), isTrue);
    expect(await SettingsStore().getFirstRecordHintPending(), isFalse);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  await tester.pumpAndSettle();
}
