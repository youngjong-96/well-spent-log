import 'dart:async';
import 'package:well_spent_log/src/shared/widgets/transaction_list_tile.dart';
import 'package:well_spent_log/src/features/transaction/transaction_form_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/app/well_spent_app.dart';
import 'package:well_spent_log/src/application/providers.dart';
import 'package:well_spent_log/src/data/local/app_database.dart';
import 'package:well_spent_log/src/data/repositories/finance_repository.dart';
import 'package:well_spent_log/src/data/services/lock_service.dart';
import 'package:well_spent_log/src/data/services/notification_service.dart';
import 'package:well_spent_log/src/data/settings/settings_store.dart';
import 'package:well_spent_log/src/domain/models/account.dart';
import 'package:well_spent_log/src/domain/models/category.dart';
import 'package:well_spent_log/src/domain/models/expense_template.dart';
import 'package:well_spent_log/src/domain/models/payment_method.dart';
import 'package:well_spent_log/src/domain/models/transaction_draft.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/features/manage/accounts_payment_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('menu actions invoke edit and delete callbacks', (tester) async {
    var edits = 0;
    var deletes = 0;
    final record = TransactionRecord(
      id: 1,
      type: RecordType.expense,
      occurredAt: DateTime(2026, 8, 1),
      amount: 5000,
      memo: 'lunch',
      accountId: 1,
      accountName: 'cash',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionListTile(
            record: record,
            onEdit: () => edits++,
            onDelete: () => deletes++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(edits, 0);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(edits, 1);
  });

  testWidgets('edit form prefills record and updates instead of adding', (
    tester,
  ) async {
    final repository = _FakeAccountsRepository();
    addTearDown(repository.dispose);
    final record = TransactionRecord(
      id: 42,
      type: RecordType.expense,
      occurredAt: DateTime(2026, 8, 1),
      amount: 5000,
      memo: 'lunch',
      accountId: 1,
      accountName: 'cash',
      categoryId: 9,
      paymentMethodId: 1,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => TransactionFormSheet.edit(context, record),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('5,000'), findsOneWidget);
    expect(find.text('lunch'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '7000');
    final save = find.byType(FilledButton);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.updatedId, 42);
    expect(repository.updatedDraft!.amount, 7000);
    expect(repository.updatedDraft!.categoryId, 9);
    expect(repository.updatedDraft!.occurredAt, record.occurredAt);
    expect(repository.savedTransactions, isEmpty);
    expect(find.byType(TransactionFormSheet), findsNothing);
  });

  testWidgets('계좌 저장 후 목록 갱신에서 위젯 트리 예외가 발생하지 않는다', (tester) async {
    final repository = _FakeAccountsRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AccountsPaymentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '추가').first);
    await tester.pumpAndSettle();
    final accountFields = find.byType(TextField);
    await tester.enterText(accountFields.at(0), '테스트 통장');
    await tester.enterText(accountFields.at(1), '테스트은행');
    await tester.enterText(accountFields.at(2), '1234567890');
    await tester.enterText(accountFields.at(3), '100000');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('테스트 통장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('지출 저장 후 시트 종료와 데이터 갱신이 정상 동작한다', (tester) async {
    final repository = _FakeAccountsRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repository),
          appInitializationProvider.overrideWith((ref) async {}),
          lockServiceProvider.overrideWithValue(const _UnlockedLockService()),
        ],
        child: const WellSpentApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, '지출'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, '12000');
    await tester.showKeyboard(amountField);
    expect(tester.testTextInput.isVisible, isTrue);

    final categoryField = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<int> &&
          widget.decoration.labelText == '카테고리',
    );
    await tester.tap(categoryField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('데이트비용'), findsOneWidget);

    await tester.tap(find.text('데이트비용'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    final saveButton = find.widgetWithText(FilledButton, '저장');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.savedTransactions, hasLength(1));
    expect(find.text('저장했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _UnlockedLockService extends LockService {
  const _UnlockedLockService();

  @override
  Future<bool> hasPin() async => false;
}

class _FakeAccountsRepository extends FinanceRepository {
  _FakeAccountsRepository()
    : super(
        database: AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
        ),
        settingsStore: SettingsStore(),
        notificationService: NotificationService(),
      );

  final _controller = StreamController<int>.broadcast();
  int? updatedId;
  TransactionDraft? updatedDraft;
  @override
  Future<void> updateTransaction(int id, TransactionDraft draft) async {
    updatedId = id;
    updatedDraft = draft;
  }

  final savedTransactions = <TransactionDraft>[];
  final _accounts = <Account>[
    const Account(
      id: 1,
      type: AccountType.cash,
      name: '현금',
      balance: 0,
      includeInTotal: true,
      isActive: true,
    ),
  ];

  @override
  Stream<int> get changes => _controller.stream;

  @override
  Future<List<Account>> listAccounts({bool includeInactive = false}) async {
    return List.unmodifiable(_accounts);
  }

  @override
  Future<List<PaymentMethod>> listPaymentMethods({
    bool includeInactive = false,
  }) async {
    return const [
      PaymentMethod(
        id: 1,
        type: PaymentMethodType.cash,
        name: '현금',
        accountId: 1,
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<SpendingCategory>> listCategories({
    bool includeInactive = false,
  }) async {
    return const [
      SpendingCategory(
        id: 1,
        name: '식비',
        colorHex: '#2F6B5F',
        sortOrder: 0,
        isActive: true,
      ),
      SpendingCategory(
        id: 9,
        name: '데이트비용',
        colorHex: '#B04A82',
        sortOrder: 8,
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<ExpenseTemplate>> listTemplates({
    bool includeInactive = false,
  }) async {
    return const [];
  }

  @override
  Future<List<TransactionRecord>> listTransactions({
    DateTime? start,
    DateTime? endExclusive,
    RecordType? type,
    bool includeDeleted = false,
    int? limit,
  }) async {
    return const [];
  }

  @override
  Future<(int?, int?)> getLastExpenseSelection() async => (1, 1);

  @override
  Future<int> addTransaction(TransactionDraft draft) async {
    savedTransactions.add(draft);
    _controller.add(savedTransactions.length);
    return savedTransactions.length;
  }

  @override
  Future<void> addAccount({
    required String name,
    required String bankName,
    required String accountNumber,
    required int openingBalance,
    required bool includeInTotal,
  }) async {
    _accounts.add(
      Account(
        id: 2,
        type: AccountType.bank,
        name: name,
        bankName: bankName,
        accountNumber: accountNumber,
        balance: openingBalance,
        includeInTotal: includeInTotal,
        isActive: true,
      ),
    );
    _controller.add(1);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
