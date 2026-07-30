import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';
import 'package:well_spent_log/src/data/repositories/finance_repository.dart';
import 'package:well_spent_log/src/data/services/notification_service.dart';
import 'package:well_spent_log/src/data/settings/settings_store.dart';
import 'package:well_spent_log/src/domain/models/account.dart';
import 'package:well_spent_log/src/domain/models/transaction_draft.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';

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

  test('지출 삭제와 복원이 잔액 및 월 집계에 함께 반영된다', () async {
    await repository.addAccount(
      name: '생활비 통장',
      bankName: '테스트은행',
      accountNumber: '1234567890',
      openingBalance: 100000,
      includeInTotal: true,
    );

    final account = (await repository.listAccounts()).singleWhere(
      (item) => item.type == AccountType.bank,
    );
    await repository.addCard(
      name: '테스트 카드',
      company: '테스트카드',
      billingDay: 15,
      accountId: account.id,
    );
    final category = (await repository.listCategories()).first;
    final paymentMethod = (await repository.listPaymentMethods()).singleWhere(
      (item) => item.name == '테스트 카드',
    );
    final occurredAt = DateTime.now();

    final transactionId = await repository.addTransaction(
      TransactionDraft(
        type: RecordType.expense,
        occurredAt: occurredAt,
        amount: 10000,
        accountId: account.id,
        categoryId: category.id,
        paymentMethodId: paymentMethod.id,
        memo: '점심',
      ),
    );

    expect(
      (await repository.listAccounts())
          .singleWhere((item) => item.id == account.id)
          .balance,
      90000,
    );
    var summary = await repository.getHomeSummary(occurredAt);
    expect(summary.totalBalance.amount, 90000);
    expect(
      summary.budgetUsages
          .singleWhere((usage) => usage.categoryId == category.id)
          .spentAmount
          .amount,
      10000,
    );

    await repository.softDeleteTransaction(transactionId);

    expect(await repository.listTransactions(), isEmpty);
    expect(
      (await repository.listAccounts())
          .singleWhere((item) => item.id == account.id)
          .balance,
      100000,
    );
    summary = await repository.getHomeSummary(occurredAt);
    expect(summary.totalBalance.amount, 100000);
    expect(
      summary.budgetUsages
          .singleWhere((usage) => usage.categoryId == category.id)
          .spentAmount
          .amount,
      0,
    );

    await repository.restoreTransaction(transactionId);

    expect((await repository.listTransactions()).single.id, transactionId);
    expect(
      (await repository.listAccounts())
          .singleWhere((item) => item.id == account.id)
          .balance,
      90000,
    );
  });

  test('잔액 이력이 있는 계좌는 삭제 대신 숨김 처리한다', () async {
    await repository.addAccount(
      name: '비상금 통장',
      bankName: '테스트은행',
      accountNumber: '9876543210',
      openingBalance: 50000,
      includeInTotal: true,
    );
    final account = (await repository.listAccounts()).singleWhere(
      (item) => item.type == AccountType.bank,
    );

    await repository.removeAccount(account.id);

    expect(
      (await repository.listAccounts()).where((item) => item.id == account.id),
      isEmpty,
    );
    expect(
      (await repository.listAccounts(
        includeInactive: true,
      )).singleWhere((item) => item.id == account.id).isActive,
      isFalse,
    );
  });

  test('월 보고서는 선택한 달에 시작하는 예산기간 전체를 집계한다', () async {
    await repository.setMonthStartDay(25);
    final account = (await repository.listAccounts()).first;
    final category = (await repository.listCategories()).first;
    final paymentMethod = (await repository.listPaymentMethods()).first;

    for (final (date, amount) in [
      (DateTime(2026, 7, 10), 3000),
      (DateTime(2026, 7, 26), 7000),
      (DateTime(2026, 8, 20), 5000),
    ]) {
      await repository.addTransaction(
        TransactionDraft(
          type: RecordType.expense,
          occurredAt: date,
          amount: amount,
          accountId: account.id,
          categoryId: category.id,
          paymentMethodId: paymentMethod.id,
        ),
      );
    }

    final report = await repository.getReport(DateTime(2026, 7));

    expect(report.period.startDate, DateTime(2026, 7, 25));
    expect(report.period.endDate, DateTime(2026, 8, 24));
    expect(report.totalExpense, 12000);
    expect(
      report.dailyAmounts.map((item) => item.date),
      containsAll([DateTime(2026, 7, 26), DateTime(2026, 8, 20)]),
    );
  });
}
