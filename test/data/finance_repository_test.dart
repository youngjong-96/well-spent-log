import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';
import 'package:well_spent_log/src/data/repositories/finance_repository.dart';
import 'package:well_spent_log/src/data/services/notification_service.dart';
import 'package:well_spent_log/src/data/settings/settings_store.dart';
import 'package:well_spent_log/src/domain/models/transaction_draft.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late AppDatabase database;
  late FinanceRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'month_start_day': 25});
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

  test(
    'rejects normalized duplicate active names on create and rename',
    () async {
      await repository.addCategory(name: ' Travel ', colorHex: '#123456');
      final travel = (await repository.listCategories()).last;
      final other = (await repository.listCategories()).first;
      await expectLater(
        repository.addCategory(name: '\tTRAVEL ', colorHex: '#654321'),
        throwsA(isA<DuplicateActiveCategoryName>()),
      );
      await expectLater(
        repository.updateCategory(
          id: other.id,
          name: ' travel ',
          colorHex: '#654321',
        ),
        throwsA(isA<DuplicateActiveCategoryName>()),
      );
      await repository.updateCategory(
        id: travel.id,
        name: ' TRAVEL ',
        colorHex: '#654321',
      );
      final categories = await repository.listCategories();
      expect(categories.first.name, other.name);
      expect(categories.last.name, 'TRAVEL');

      await repository.setCategoryActive(travel.id, false);
      await repository.updateCategory(
        id: other.id,
        name: 'travel',
        colorHex: '#654321',
      );
      expect((await repository.listCategories()).first.name, 'travel');
    },
  );

  test(
    'finds the newest hidden match and counts only live transactions',
    () async {
      final method = (await repository.listPaymentMethods()).first;
      final now = DateTime.now();
      Future<int> createHidden(String name, int liveCount) async {
        await repository.addCategory(name: name, colorHex: '#123456');
        final category = (await repository.listCategories()).last;
        for (var i = 0; i <= liveCount; i++) {
          final id = await repository.addTransaction(
            TransactionDraft(
              type: RecordType.expense,
              occurredAt: now,
              amount: 1000,
              categoryId: category.id,
              paymentMethodId: method.id,
            ),
          );
          if (i == liveCount) await repository.softDeleteTransaction(id);
        }
        await repository.removeCategory(category.id);
        return category.id;
      }

      final olderId = await createHidden('Travel', 1);
      final newerId = await createHidden('TRAVEL', 2);
      final hidden = (await repository.findHiddenCategoryByName(' travel\t'))!;
      expect(hidden.category.id, newerId);
      expect(hidden.transactionCount, 2);
      expect(await repository.findHiddenCategoryByName('unknown'), isNull);
      await repository.setCategoryActive(
        newerId,
        true,
        colorHex: '#654321',
        alertsEnabled: false,
      );
      final restored = (await repository.listCategories()).last;
      expect(restored.id, newerId);
      expect(restored.name, 'TRAVEL');
      expect(restored.sortOrder, hidden.category.sortOrder);
      expect(restored.colorHex, '#654321');
      expect(restored.alertsEnabled, isFalse);
      expect(
        (await repository.findHiddenCategoryByName('travel'))?.category.id,
        olderId,
      );
      await expectLater(
        repository.setCategoryActive(olderId, true),
        throwsA(isA<DuplicateActiveCategoryName>()),
      );
    },
  );

  test(
    'payment methods reject normalized active duplicates on create and rename',
    () async {
      await repository.savePaymentMethod(name: ' Travel ');
      final methods = await repository.listPaymentMethods();
      final travel = methods.last;
      final other = methods.first;

      await expectLater(
        repository.savePaymentMethod(name: '\tTRAVEL '),
        throwsA(isA<DuplicateActivePaymentMethodName>()),
      );
      await expectLater(
        repository.savePaymentMethod(id: other.id, name: ' travel '),
        throwsA(isA<DuplicateActivePaymentMethodName>()),
      );
      await repository.savePaymentMethod(id: travel.id, name: ' TRAVEL ');
      expect((await repository.listPaymentMethods()).last.name, 'TRAVEL');

      await repository.setPaymentMethodActive(travel.id, false);
      await repository.savePaymentMethod(id: other.id, name: 'travel');
      expect((await repository.listPaymentMethods()).first.name, 'travel');
      await expectLater(
        repository.setPaymentMethodActive(travel.id, true),
        throwsA(isA<DuplicateActivePaymentMethodName>()),
      );
    },
  );

  test(
    'payment method reuse keeps the original ID, order, name and template',
    () async {
      final category = (await repository.listCategories()).first;
      await repository.savePaymentMethod(name: 'Travel');
      final original = (await repository.listPaymentMethods()).last;
      for (var i = 0; i < 3; i++) {
        final id = await repository.addTransaction(
          TransactionDraft(
            type: RecordType.expense,
            occurredAt: DateTime.now(),
            amount: 1000,
            categoryId: category.id,
            paymentMethodId: original.id,
          ),
        );
        if (i == 2) await repository.softDeleteTransaction(id);
      }
      await repository.addTemplate(
        name: 'Travel lunch',
        amount: 1000,
        categoryId: category.id,
        paymentMethodId: original.id,
      );
      await repository.removePaymentMethod(original.id);
      expect(await repository.listTemplates(), isEmpty);

      final match = (await repository.findHiddenPaymentMethodByName(
        ' TRAVEL\t',
      ))!;
      expect(match.method.id, original.id);
      expect(match.transactionCount, 2);
      expect(await repository.findHiddenPaymentMethodByName('unknown'), isNull);

      await repository.savePaymentMethod(name: 'TRAVEL');
      final separate = (await repository.listPaymentMethods()).last;
      expect(separate.id, isNot(original.id));
      expect(await repository.listTemplates(), isEmpty);
      await repository.setPaymentMethodActive(separate.id, false);
      expect(
        (await repository.findHiddenPaymentMethodByName('travel'))?.method.id,
        separate.id,
      );

      // A more recently updated method wins even when its ID is lower.
      await repository.setPaymentMethodActive(original.id, false);
      expect(
        (await repository.findHiddenPaymentMethodByName('travel'))?.method.id,
        original.id,
      );

      await repository.savePaymentMethod(name: 'Online');
      final online = (await repository.listPaymentMethods()).last;
      await repository.setPaymentMethodActive(original.id, true);
      final restored = await repository.listPaymentMethods();
      expect(restored[restored.length - 2].id, original.id);
      expect(restored[restored.length - 2].name, 'Travel');
      expect(restored.last.id, online.id);
      expect(
        (await repository.listTemplates()).single.paymentMethodId,
        original.id,
      );
    },
  );

  test(
    'home includes all calendar-month spending sorted by amount, net of refunds',
    () async {
      final category = (await repository.listCategories()).first;
      final method = (await repository.listPaymentMethods()).first;
      Future<int> add(
        DateTime date,
        int amount, {
        RecordType type = RecordType.expense,
      }) => repository.addTransaction(
        TransactionDraft(
          type: type,
          occurredAt: date,
          amount: amount,
          categoryId: category.id,
          paymentMethodId: method.id,
        ),
      );
      for (var i = 1; i <= 21; i++) {
        await add(DateTime(2026, 8, i), i * 1000);
      }
      await add(DateTime(2026, 7, 31, 23, 59), 999999);
      await add(DateTime(2026, 9), 999999);
      final refundId = await add(
        DateTime(2026, 8, 31, 23, 59),
        500,
        type: RecordType.refund,
      );
      final deletedId = await add(DateTime(2026, 8, 5), 888888);
      await repository.softDeleteTransaction(deletedId);
      final summary = await repository.getHomeSummary(DateTime(2026, 8, 15));
      expect(summary.period.startDate, DateTime(2026, 8));
      expect(summary.period.endDate, DateTime(2026, 8, 31));
      expect(
        summary.budgetUsages
            .singleWhere((usage) => usage.categoryId == category.id)
            .spentAmount
            .amount,
        230500,
      );
      expect(summary.monthlyTransactions, hasLength(22));
      expect(summary.monthlyTransactions.first.amount, 21000);
      expect(summary.monthlyTransactions.last.id, refundId);
      expect(
        summary.monthlyTransactions.map((r) => r.amount),
        orderedEquals([for (var i = 21; i >= 1; i--) i * 1000, 500]),
      );
      expect(summary.monthlyExpense.amount, 230500);
      final empty = await repository.getHomeSummary(DateTime(2025, 1));
      expect(empty.monthlyTransactions, isEmpty);
      expect(empty.monthlyExpense.amount, 0);
    },
  );

  test('월 보고서는 선택한 달의 1일부터 말일까지 집계한다', () async {
    final category = (await repository.listCategories()).first;
    final paymentMethod = (await repository.listPaymentMethods()).first;

    for (final (date, amount) in [
      (DateTime(2026, 6, 20), 2000),
      (DateTime(2026, 7, 10), 3000),
      (DateTime(2026, 7, 26), 7000),
      (DateTime(2026, 8, 20), 5000),
    ]) {
      await repository.addTransaction(
        TransactionDraft(
          type: RecordType.expense,
          occurredAt: date,
          amount: amount,
          categoryId: category.id,
          paymentMethodId: paymentMethod.id,
        ),
      );
    }

    final report = await repository.getReport(DateTime(2026, 7));

    expect(report.period.startDate, DateTime(2026, 7));
    expect(report.period.endDate, DateTime(2026, 7, 31));
    expect(report.totalExpense, 10000);
    expect(report.previousMonthExpense, 2000);
    expect(report.transactions.map((item) => item.amount), [7000, 3000]);
    expect(
      report.dailyAmounts.map((item) => item.date),
      containsAll([DateTime(2026, 7, 10), DateTime(2026, 7, 26)]),
    );
    expect(
      report.dailyAmounts.map((item) => item.date),
      isNot(contains(DateTime(2026, 8, 20))),
    );
  });
}
