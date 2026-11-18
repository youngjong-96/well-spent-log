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
    expect(
      find.byKey(const ValueKey('onboarding-introduction')),
      findsOneWidget,
    );
    expect(find.text('지출을 어떤 종류로 나눌지 정해요'), findsOneWidget);
    await tester.tap(find.text('시작'));
    await settle(tester);
    expect(find.text('나만의 분류'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsWidgets);
  });

  for (final replay in [false, true]) {
    testWidgets('네 단계 소개와 동일 크기 선택 격자를 표시한다 (다시 보기 $replay)', (tester) async {
      await tester.runAsync(
        () => repository.addCategory(
          name: '아주 긴 이름으로 직접 추가한 카테고리',
          colorHex: '#84B6E2',
        ),
      );
      await mount(
        tester,
        OnboardingScreen(replay: replay, onFinished: (_, _) {}),
      );
      await tester.tap(find.text('시작하기'));
      await settle(tester);
      const descriptions = [
        '지출을 어떤 종류로 나눌지 정해요',
        '카테고리별 한 달 예산을 정해요',
        '자주 쓰는 카드와 페이를 등록해요',
        '실제로 지출 하나를 기록해봐요',
      ];
      for (var step = 1; step <= 4; step++) {
        expect(
          find.byKey(const ValueKey('onboarding-introduction')),
          findsOneWidget,
          reason:
              'step $step: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(', ')}',
        );
        expect(find.text('$step/4'), findsOneWidget);
        expect(find.text(descriptions[step - 1]), findsOneWidget);
        expect(find.byType(TransactionFormSheet), findsNothing);
        await tester.tap(find.text('시작'));
        await settle(tester);
        expect(
          find.byKey(const ValueKey('onboarding-introduction')),
          findsNothing,
        );
        if (step == 1 || step == 3) {
          final buttons = find.byType(OutlinedButton).evaluate().toList();
          final sizes = buttons
              .map((e) => tester.getSize(find.byWidget(e.widget)))
              .toList();
          expect(sizes.every((size) => size == sizes.first), isTrue);
          expect(sizes.first.height, 72);
          expect(sizes.first.width, 190);
          final first = tester.getTopLeft(find.byWidget(buttons[0].widget));
          final second = tester.getTopLeft(find.byWidget(buttons[1].widget));
          if (step == 1) {
            expect(first.dy, second.dy);
            expect(first.dx, lessThan(second.dx));
          }
        }
        if (step == 2) {
          final fields = find.byType(TextField).evaluate().toList();
          final sizes = fields
              .map((e) => tester.getSize(find.byWidget(e.widget)))
              .toList();
          expect(sizes.every((size) => size == sizes.first), isTrue);
          expect(sizes.first.height, 72);
        }
        if (step < 4) {
          await tester.tap(find.widgetWithText(FilledButton, '다음'));
          await settle(tester);
          if (step == 2) {
            for (
              var attempt = 0;
              attempt < 10 &&
                  find
                      .byKey(const ValueKey('onboarding-introduction'))
                      .evaluate()
                      .isEmpty;
              attempt++
            ) {
              await settle(tester);
            }
          }
        }
      }
      expect(find.byType(TransactionFormSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('입력과 선택은 안내를 유지하고 다음 버튼만 위에서 아래로 진행한다', (tester) async {
    await mount(
      tester,
      const Scaffold(body: TransactionFormSheet(onboarding: true)),
    );
    final titles = [
      '사용한 금액을 입력해 보세요',
      '금액을 빠르게 더하세요',
      '어디에 썼는지 적어두세요',
      '지난번 선택을 기억해요',
      '필요하면 여기서 바꿔요',
      '다음 할 일을 버튼이 알려줘요',
      '저장하면 첫 기록 완료!',
    ];
    await tester.enterText(find.byType(TextFormField).first, '15000');
    await settle(tester);
    expect(find.text('1 / 8'), findsOneWidget);
    final amountTop = tester.getTopLeft(find.byType(TextFormField).first).dy;
    final quickTop = tester.getTopLeft(find.text('+1,000')).dy;
    final memoTop = tester.getTopLeft(find.byType(TextFormField).at(1)).dy;
    expect(amountTop, lessThan(quickTop));
    expect(quickTop, lessThan(memoTop));
    for (var i = 0; i < titles.length; i++) {
      expect(find.text(titles[i]), findsOneWidget);
      expect(find.text('${i + 1} / 8'), findsOneWidget);
      if (i == 1) {
        await tester.ensureVisible(find.text('+1,000'));
        await tester.tap(find.text('+1,000'));
      }
      if (i == 2) {
        await tester.enterText(find.byType(TextFormField).at(1), '점심');
      }
      if (i == 3) {
        await tester.tap(find.byKey(const ValueKey('transaction-summary')));
      }
      if (i == 4) {
        await tester.ensureVisible(find.text('어제'));
        await tester.tap(find.text('어제'));
      }
      await settle(tester);
      expect(find.text('${i + 1} / 8'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '다음'));
      await settle(tester);
    }
    expect(find.byType(CoachMark), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('템플릿은 첫 안내이고 불러와도 다음을 눌러야 진행한다', (tester) async {
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
    expect(tester.widget<CoachMark>(find.byType(CoachMark)).title, '빠른 불러오기');
    await tester.tap(find.text('점심 식사'));
    await settle(tester);
    expect(find.text('1 / 9'), findsOneWidget);
    expect(find.text('12,000'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    expect(find.text('2 / 9'), findsOneWidget);
    expect(find.text('사용한 금액을 입력해 보세요'), findsOneWidget);
  });

  testWidgets('첫 기록 저장 후 실제 홈 예산 안내와 완료 화면을 표시한다', (tester) async {
    await mount(tester, const AppShell());
    await tester.tap(find.text('시작하기'));
    await settle(tester);
    await tester.tap(find.text('시작'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    await tester.tap(find.text('시작'));
    await settle(tester);
    await tester.tap(find.text('나중에 할게요'));
    await settle(tester);
    await tester.tap(find.text('시작'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    await tester.tap(find.text('시작'));
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
    await tester.tap(find.text('시작'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    await tester.tap(find.text('시작'));
    await settle(tester);
    await tester.tap(find.text('나중에 할게요'));
    await settle(tester);
    await tester.tap(find.text('시작'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await settle(tester);
    await tester.tap(find.text('시작'));
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
