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
