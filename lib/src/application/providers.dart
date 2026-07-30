import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/repositories/finance_repository.dart';
import '../data/services/backup_service.dart';
import '../data/services/lock_service.dart';
import '../data/services/notification_service.dart';
import '../data/settings/settings_store.dart';
import '../domain/models/account.dart';
import '../domain/models/category.dart';
import '../domain/models/expense_template.dart';
import '../domain/models/home_summary.dart';
import '../domain/models/payment_method.dart';
import '../domain/models/report_summary.dart';
import '../domain/models/transaction_record.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  return SettingsStore();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(settingsStoreProvider),
  );
});

final lockServiceProvider = Provider<LockService>((ref) {
  return const LockService();
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final repository = FinanceRepository(
    database: ref.watch(appDatabaseProvider),
    settingsStore: ref.watch(settingsStoreProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final appInitializationProvider = FutureProvider<void>((ref) async {
  await ref.watch(financeRepositoryProvider).initialize();
});

final dataRevisionProvider = StreamProvider<int>((ref) {
  return ref.watch(financeRepositoryProvider).changes;
});

final homeSummaryProvider = FutureProvider<HomeSummary>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(financeRepositoryProvider).getHomeSummary();
});

final categoriesProvider = FutureProvider<List<SpendingCategory>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(financeRepositoryProvider).listCategories();
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(financeRepositoryProvider).listAccounts();
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(financeRepositoryProvider).listPaymentMethods();
});

final templatesProvider = FutureProvider<List<ExpenseTemplate>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(financeRepositoryProvider).listTemplates();
});

final monthTransactionsProvider =
    FutureProvider.family<List<TransactionRecord>, DateTime>((
      ref,
      month,
    ) async {
      ref.watch(dataRevisionProvider);
      final start = DateTime(month.year, month.month);
      return ref
          .watch(financeRepositoryProvider)
          .listTransactions(
            start: start,
            endExclusive: DateTime(start.year, start.month + 1),
          );
    });

final reportProvider = FutureProvider.family<ReportSummary, DateTime>((
  ref,
  month,
) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(financeRepositoryProvider).getReport(month);
});

final annualReportProvider = FutureProvider.family<AnnualSummary, int>((
  ref,
  year,
) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(financeRepositoryProvider).getAnnualSummary(year);
});
