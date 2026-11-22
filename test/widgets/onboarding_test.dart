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
import 'package:well_spent_log/src/features/manage/category_budget_screen.dart';
import 'package:well_spent_log/src/features/onboarding/onboarding_screen.dart';
import 'package:well_spent_log/src/features/onboarding/first_record_tour.dart';
import 'package:well_spent_log/src/features/transaction/transaction_form_sheet.dart';

class _AlertPermissions extends NotificationService {
  bool granted = true;
  int requests = 0;
  int settingsVisits = 0;

  @override
  bool get canOpenNotificationSettings => true;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> requestPermission() async => requests++;

  @override
  Future<void> openNotificationSettings() async => settingsVisits++;
}

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

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    NotificationService? notificationService,
  }) async {
    tester.view.physicalSize = const Size(384, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repository),
          appDatabaseProvider.overrideWithValue(database),
          if (notificationService != null)
            notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    );
    await settle(tester);
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
  }

  testWidgets('신규 사용자만 시작 화면을 표시한다', (tester) async {
    await mount(tester, const AppShell());
    expect(find.text('쓰면 바로\n기록하자!'), findsOneWidget);
    expect(find.text('백업에서 복원하기'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  test('온보딩에 사용하는 기본 카테고리 색상이 서로 다르다', () async {
    final categories = await repository.listCategories();
    expect(categories, hasLength(8));
    expect(
      categories.map((category) => category.colorHex).toSet(),
      hasLength(8),
    );
  });

  testWidgets('예산 알림을 켜고 끄며 권한과 복귀 상태를 표시한다', (tester) async {
    final permissions = _AlertPermissions();
    await mount(
      tester,
      const Scaffold(body: ManageScreen()),
      notificationService: permissions,
    );
    final tile = find.byType(SwitchListTile);
    bool enabled() => tester.widget<SwitchListTile>(tile).value;
    expect(enabled(), isTrue);
    expect(find.text('설정 열기'), findsNothing);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(enabled(), isFalse);
    expect(await SettingsStore().getBudgetAlertsEnabled(), isFalse);

    permissions.granted = false;
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(permissions.requests, 1);
    expect(enabled(), isTrue);
    expect(find.text('알림 권한이 꺼져 있어요'), findsOneWidget);
    await tester.tap(find.text('설정 열기'));
    expect(permissions.settingsVisits, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    permissions.granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(enabled(), isTrue);
    expect(find.text('설정 열기'), findsNothing);
  });

  testWidgets('잘못된 HEX를 안내하고 대비가 낮은 직접 선택 색상도 저장한다', (tester) async {
    await mount(tester, const CategoryBudgetScreen());
    await tapLabel(tester, '카테고리');
    await tester.enterText(find.widgetWithText(TextFormField, '이름'), '맞춤 색상');
    await tapLabel(tester, '직접 선택');
    final hex = find.widgetWithText(TextField, 'HEX 색상');
    await tester.enterText(hex, '#00zz00');
    await tester.pumpAndSettle();
    expect(find.text('색상 코드 6자리를 입력해 주세요.'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, '저장');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(hex, 'fffffe');
    await tester.pumpAndSettle();
    expect(find.textContaining('배경과 비슷해서'), findsOneWidget);
    await tapLabel(tester, '저장');
    final categories = await tester.runAsync(repository.listCategories);
    expect(
      categories!.singleWhere((category) => category.name == '맞춤 색상').colorHex,
      '#FFFFFE',
    );
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
    expect(
      find.byKey(const ValueKey('onboarding-introduction')),
      findsOneWidget,
    );
    expect(find.text('지출을 종류별로\n나눠요'), findsOneWidget);
    await tester.tap(find.text('시작'));
    await settle(tester);
    expect(find.text('나만의 분류'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsWidgets);
  });

  Future<void> reachTour(WidgetTester tester, {bool setBudget = false}) async {
    await tapLabel(tester, '시작하기');
    const titles = [
      '지출을 종류별로\n나눠요',
      '한 달에 쓸\n예산을 정해요',
      '자주 쓰는\n결제수단을 골라요',
      '첫 지출을\n기록해 봐요',
    ];
    for (var step = 1; step <= 4; step++) {
      expect(
        find.byKey(const ValueKey('onboarding-introduction')),
        findsOneWidget,
        reason: '단계 $step',
      );
      expect(find.text('$step/4'), findsOneWidget);
      expect(find.text(titles[step - 1]), findsOneWidget);
      await tapLabel(tester, '시작');
      switch (step) {
        case 1:
          final food = find.byKey(const ValueKey('onboarding-chip-식비'));
          final cafe = find.byKey(const ValueKey('onboarding-chip-카페·간식'));
          expect(tester.getSize(food), tester.getSize(cafe));
          expect(tester.getSize(food).height, 55);
          expect(tester.getTopLeft(food).dy, tester.getTopLeft(cafe).dy);
          await tapLabel(tester, '다음');
        case 2:
          if (setBudget) {
            final field = find.byType(TextField);
            expect(field, findsOneWidget);
            await tester.enterText(field, '100000');
            await tapLabel(tester, '+1만');
            expect(find.text('110,000'), findsOneWidget);
            await tapLabel(tester, '다음');
          } else {
            await tapLabel(tester, '건너뛰기');
          }
        case 3:
          const methods = ['현금', '신용카드', '모바일티머니', '국민카드', '네이버페이'];
          final chips = find.byWidgetPredicate(
            (widget) => widget.key.toString().contains('onboarding-chip-'),
          );
          expect(chips, findsNWidgets(5));
          for (final method in methods) {
            expect(find.text(method), findsOneWidget);
          }
          expect(find.text('카드 번호 없이 이름만 저장해요'), findsOneWidget);
          expect(find.text('내가 원하는 대로 결제수단을 등록해요'), findsOneWidget);
          await tapLabel(tester, '국민카드');
          await tapLabel(tester, '다음');
      }
    }
  }

  Future<void> finishTour(WidgetTester tester) async {
    const titles = [
      '사용한 금액을 입력해요',
      '어디에 썼는지 메모해요',
      '기록 정보를 한눈에 확인해요',
      '필요하면 상세 정보를 바꿔요',
      '확인했다면 저장해요',
    ];
    for (var i = 0; i < titles.length; i++) {
      expect(find.text(titles[i]), findsOneWidget);
      expect(find.text('${i + 1}/5'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('건너뛰기'), findsNothing);
      expect(find.text('빠른 불러오기'), findsNothing);
      expect(find.text('15,000'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tour-details')),
        i < 3 ? findsNothing : findsOneWidget,
      );
      if (i == 4) {
        await tester.tapAt(tester.getCenter(find.text('저장')));
        await tester.pump();
        expect(find.text('5/5'), findsOneWidget);
      }
      await tapLabel(tester, '다음');
    }
    expect(find.byType(FirstRecordTour), findsNothing);
    expect(find.text('이제 직접\n기록해 봐요'), findsOneWidget);
    final records = await tester.runAsync(() => repository.listTransactions());
    expect(records, isEmpty);
  }

  testWidgets('다섯 단계 읽기 전용 투어를 거쳐 실제 저장과 홈 예산을 확인한다', (tester) async {
    await tester.runAsync(() async {
      await repository.addTemplate(
        name: '점심 식사',
        amount: 12000,
        categoryId: (await repository.listCategories()).first.id,
        paymentMethodId: (await repository.listPaymentMethods()).first.id,
      );
    });
    await mount(tester, const AppShell());
    await reachTour(tester, setBudget: true);
    await finishTour(tester);
    await tapLabel(tester, '직접 기록하기');
    expect(find.byType(TransactionFormSheet), findsOneWidget);
    expect(find.text('사용한 금액을 자유롭게 기록해 보세요.'), findsOneWidget);
    expect(find.text('점심 김치찌개'), findsNothing);
    expect(find.text('빠른 불러오기'), findsNothing);
    expect(find.text('15,000'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.enterText(find.byType(TextFormField).last, '실제 점심');
    await tapLabel(tester, '분류·결제 접기');
    expect(find.text('카테고리'), findsNothing);
    await tapLabel(tester, '분류·결제 확인');
    expect(find.text('카테고리'), findsOneWidget);
    expect(find.text('기록 저장 완료'), findsNothing);

    await tapLabel(tester, '저장');
    expect(find.text('기록 저장 완료'), findsOneWidget);
    expect(find.text('105,000원 남음'), findsOneWidget);
    expect(find.text('실제 점심'), findsOneWidget);
    expect(
      find.text('저장한 식비 기록이 예산에 반영됐어요. 이 카드에서 남은 금액을 확인해요.'),
      findsOneWidget,
    );
    await tapLabel(tester, '확인');
    expect(find.text('첫 기록 완료!'), findsOneWidget);
    await tapLabel(tester, '홈으로');
    expect(find.byType(FloatingActionButton), findsOneWidget);
    final records = await tester.runAsync(() => repository.listTransactions());
    expect(records!.single.amount, 5000);
    expect(records.single.memo, '실제 점심');
    expect(await SettingsStore().getOnboardingCompleted(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('첫 기록을 생략하면 홈 + 안내를 한 번 보여준다', (tester) async {
    await mount(tester, const AppShell());
    await reachTour(tester);
    await finishTour(tester);
    await tapLabel(tester, '오늘은 아직 안 썼어요');
    expect(find.text('+ 버튼으로 첫 기록을 남겨보세요'), findsOneWidget);
    await tapLabel(tester, '건너뛰기');
    expect(find.text('+ 버튼으로 첫 기록을 남겨보세요'), findsNothing);
    expect(await SettingsStore().getOnboardingCompleted(), isTrue);
    expect(await SettingsStore().getFirstRecordHintPending(), isFalse);
  });

  testWidgets('작은 화면에서도 상세 안내와 다음 버튼이 겹치지 않는다', (tester) async {
    await mount(
      tester,
      Scaffold(body: FirstRecordTour(step: 4, onNext: () {})),
    );
    tester.view.physicalSize = const Size(320, 610);
    await settle(tester);
    final note = tester.getRect(find.text('카테고리, 결제수단, 사용한 날짜를 바꿀 수 있어요.'));
    final details = tester.getRect(find.byKey(const ValueKey('tour-details')));
    final next = tester.getRect(find.text('다음'));
    expect(note.top, greaterThan(details.bottom));
    expect(note.bottom, lessThan(next.top));
    expect(tester.takeException(), isNull);
  });

  test('첫 기록 안내는 앱을 다시 실행해도 한 번만 표시한다', () async {
    await SettingsStore().setFirstRecordHintPending(true);
    final firstSession = ProviderContainer();
    expect(await firstSession.read(firstRecordHintProvider.future), isTrue);
    firstSession.dispose();
    final nextSession = ProviderContainer();
    addTearDown(nextSession.dispose);
    expect(await nextSession.read(firstRecordHintProvider.future), isFalse);
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
