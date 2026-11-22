import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';
import 'package:well_spent_log/src/data/repositories/finance_repository.dart';
import 'package:well_spent_log/src/data/services/notification_service.dart';
import 'package:well_spent_log/src/data/settings/settings_store.dart';
import 'package:well_spent_log/src/domain/models/payment_method.dart';
import 'package:well_spent_log/src/domain/models/transaction_draft.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/features/manage/payment_methods_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
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

  Future<PaymentMethod> hideMethod() async {
    await repository.savePaymentMethod(name: 'Travel Pay');
    final method = (await repository.listPaymentMethods()).last;
    final category = (await repository.listCategories()).first;
    await repository.addTransaction(
      TransactionDraft(
        type: RecordType.expense,
        occurredAt: DateTime.now(),
        amount: 1000,
        categoryId: category.id,
        paymentMethodId: method.id,
      ),
    );
    await repository.removePaymentMethod(method.id);
    return method;
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PaymentMethodsScreen()),
      ),
    );
    await _settle(tester);
  }

  Future<void> enterName(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextFormField), name);
    await _tap(tester, find.text('저장'));
  }

  for (final choice in [null, '다시 사용', '새로 만들기']) {
    testWidgets('hidden payment method prompt: ${choice ?? 'dismiss'}', (
      tester,
    ) async {
      final original = (await tester.runAsync(hideMethod))!;
      await mount(tester);
      await _tap(tester, find.text('결제수단 추가'));
      await enterName(tester, ' trAVEL pAY ');

      expect(find.text('다시 사용할까요?'), findsOneWidget);
      expect(find.textContaining("'Travel Pay' 결제수단이 숨겨져 있어요"), findsOneWidget);
      expect(find.textContaining('기존 내역 1건이 함께 돌아와요'), findsOneWidget);

      if (choice == null) {
        await tester.tapAt(const Offset(4, 4));
        await _settle(tester);
        expect(find.byType(TextFormField), findsOneWidget);
      } else {
        await _tap(
          tester,
          find.descendant(
            of: find.byType(AlertDialog).last,
            matching: find.text(choice),
          ),
        );
        expect(find.byType(TextFormField), findsNothing);
      }
      expect(find.text('다시 사용할까요?'), findsNothing);
      final methods = (await tester.runAsync(
        () => repository.listPaymentMethods(includeInactive: true),
      ))!.where((item) => item.name.toLowerCase() == 'travel pay').toList();
      expect(methods, hasLength(choice == '새로 만들기' ? 2 : 1));
      expect(methods.first.id, original.id);
      expect(methods.first.name, original.name);
      expect(methods.first.isActive, choice == '다시 사용');
      if (choice == '새로 만들기') {
        expect(methods.last.name, 'trAVEL pAY');
        expect(methods.last.isActive, isTrue);
      }
    });
  }

  testWidgets('active name is an inline error on create and rename', (
    tester,
  ) async {
    final original = (await tester.runAsync(hideMethod))!;
    await tester.runAsync(
      () => repository.savePaymentMethod(name: 'Daily Pay'),
    );
    await mount(tester);

    await _tap(tester, find.text('결제수단 추가'));
    await enterName(tester, '  DAILY PAY ');
    expect(find.text('이미 있는 결제수단 이름이에요'), findsOneWidget);
    await _tap(tester, find.text('취소'));

    final other = (await tester.runAsync(repository.listPaymentMethods))!.first;
    await _tap(tester, find.text(other.name));
    await enterName(tester, ' daily pay ');
    expect(find.text('이미 있는 결제수단 이름이에요'), findsOneWidget);
    await enterName(tester, ' travel pay ');
    expect(find.byType(AlertDialog), findsNothing);
    final methods = (await tester.runAsync(repository.listPaymentMethods))!;
    expect(methods.first.name, 'travel pay');
    expect(
      (await tester.runAsync(
        repository.listHiddenPaymentMethods,
      ))!.single.method.id,
      original.id,
    );
  });

  testWidgets('hidden section updates on hide and restore', (tester) async {
    await mount(tester);
    expect(find.text('숨긴 결제수단'), findsNothing);
    final hidden = (await tester.runAsync(hideMethod))!;
    await _settle(tester);
    expect(find.text('숨긴 결제수단'), findsOneWidget);
    expect(find.text(hidden.name), findsOneWidget);
    expect(find.text('기존 내역 1건'), findsOneWidget);

    await _tap(tester, find.text('다시 사용'));
    expect(find.text('숨긴 결제수단'), findsNothing);
    expect(find.text(hidden.name), findsOneWidget);
    expect(await tester.runAsync(repository.listHiddenPaymentMethods), isEmpty);
  });

  testWidgets('hidden section blocks restore of an active name', (
    tester,
  ) async {
    final hidden = (await tester.runAsync(hideMethod))!;
    await tester.runAsync(
      () => repository.savePaymentMethod(name: 'TRAVEL PAY'),
    );
    await mount(tester);

    await _tap(tester, find.text('다시 사용'));
    expect(find.text('이미 있는 결제수단 이름이에요'), findsOneWidget);
    expect(find.text('숨긴 결제수단'), findsOneWidget);
    expect(
      (await tester.runAsync(
        repository.listHiddenPaymentMethods,
      ))!.single.method.id,
      hidden.id,
    );
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  await tester.pumpAndSettle();
}
