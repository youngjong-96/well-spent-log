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
import 'package:well_spent_log/src/domain/models/category.dart';
import 'package:well_spent_log/src/domain/models/expense_template.dart';
import 'package:well_spent_log/src/domain/models/payment_method.dart';
import 'package:well_spent_log/src/domain/models/transaction_draft.dart';
import 'package:well_spent_log/src/domain/models/transaction_record.dart';
import 'package:well_spent_log/src/features/manage/payment_methods_screen.dart';
import 'package:well_spent_log/src/shared/formatters.dart';

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
      categoryName: '식비',
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
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
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
    final repository = _FakeSpendingRepository();
    addTearDown(repository.dispose);
    final record = TransactionRecord(
      id: 42,
      type: RecordType.expense,
      occurredAt: DateTime(2026, 8, 1),
      amount: 5000,
      memo: 'lunch',
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
    await tester.scrollUntilVisible(
      find.text('lunch'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('lunch'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '7000');
    await tester.tap(find.widgetWithText(OutlinedButton, '메모 입력'));
    await tester.pumpAndSettle();
    expect(
      find.text('데이트비용 · 현금 · ${formatShortDate(record.occurredAt)}'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '분류·결제 확인'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '메모 입력'), findsNothing);
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
    expect(find.text('수정했어요'), findsOneWidget);
    expect(find.text('되돌리기'), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();
    expect(repository.updatedDrafts.map((draft) => draft.amount), [7000, 5000]);
    expect(find.text('수정 전 내용으로 되돌렸어요'), findsOneWidget);
  });

  testWidgets('custom payment method can be created and renamed', (
    tester,
  ) async {
    final repository = _FakeSpendingRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PaymentMethodsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('결제수단 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '네이버페이');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('네이버페이'), findsOneWidget);
    await tester.tap(find.text('네이버페이'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '국민카드');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('국민카드'), findsOneWidget);
    expect(find.text('네이버페이'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장 실패 시 입력을 유지하고 다시 시도 동작을 제공한다', (tester) async {
    final repository = _FakeSpendingRepository()..failNextSave = true;
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const TransactionFormSheet(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '+1,000'));
    await tester.tap(find.widgetWithText(OutlinedButton, '+5,000'));
    expect(find.text('6,000'), findsOneWidget);
    final yesterdayButton = find.widgetWithText(OutlinedButton, '어제');
    await tester.scrollUntilVisible(
      yesterdayButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<OutlinedButton>(yesterdayButton).onPressed!();
    await tester.pump();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(find.text(formatShortDate(yesterday)), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionFormSheet), findsOneWidget);
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();
    expect(find.byType(TransactionFormSheet), findsNothing);
    expect(repository.savedTransactions.single.amount, 6000);
  });

  testWidgets('지출 저장 후 시트 종료와 데이터 갱신이 정상 동작한다', (tester) async {
    final repository = _FakeSpendingRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repository),
          appInitializationProvider.overrideWith((ref) async {}),
          onboardingNeededProvider.overrideWith((ref) async => false),
          firstRecordHintProvider.overrideWith((ref) async => false),
          lockServiceProvider.overrideWithValue(const _UnlockedLockService()),
        ],
        child: const WellSpentApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
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
    await tester.tap(find.widgetWithText(OutlinedButton, '메모 입력'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(OutlinedButton, '분류·결제 확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(categoryField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('데이트비용'), findsOneWidget);

    await tester.tap(find.text('데이트비용'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    final saveButton = find.widgetWithText(FilledButton, '저장');
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: saveButton,
      ),
      findsNothing,
    );
    await tester.ensureVisible(saveButton);
    await tester.pump();
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.savedTransactions, hasLength(1));
    expect(find.text('저장했어요'), findsOneWidget);
    expect(find.text('저장 취소'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('단계 안내로 메모와 확인을 오가고 언제든 저장한다', (tester) async {
    final repository = _FakeSpendingRepository();
    addTearDown(repository.dispose);
    await _openExpenseForm(
      tester,
      repository: repository,
      theme: AppTheme.light,
    );
    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.tap(find.widgetWithText(OutlinedButton, '메모 입력'));
    await tester.pumpAndSettle();
    expect(_textField('어떤 지출인가요?', tester).focusNode!.hasFocus, isTrue);
    expect(find.text('식비 · 현금 · 오늘'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '분류·결제 확인'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.widgetWithText(OutlinedButton, '메모 입력'), findsNothing);
    final save = find.widgetWithText(FilledButton, '저장');
    expect(tester.getSize(save).width, greaterThan(500));
    _textField('금액', tester).focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '메모 입력'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '분류·결제 확인'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transaction-summary')));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.savedTransactions.single.amount, 5000);
    expect(tester.takeException(), isNull);
  });
  testWidgets('메모는 펼쳐진 선택 입력이며 완료로 저장하지 않는다', (tester) async {
    final repository = _FakeSpendingRepository();
    addTearDown(repository.dispose);
    await _openExpenseForm(
      tester,
      repository: repository,
      theme: AppTheme.light,
    );
    final memo = find.byType(TextFormField).at(1);
    expect(
      tester.getTopLeft(memo).dy,
      greaterThan(tester.getTopLeft(find.byType(TextFormField).first).dy),
    );
    expect(
      tester.getTopLeft(memo).dy,
      lessThan(
        tester.getTopLeft(find.byType(DropdownButtonFormField<int>).first).dy,
      ),
    );
    expect(_textField('어떤 지출인가요?', tester).maxLength, 80);
    await tester.enterText(find.byType(TextFormField).first, '12000');
    await tester.enterText(memo, List.filled(81, '가').join());
    expect(_textField('어떤 지출인가요?', tester).controller!.text.length, 80);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repository.savedTransactions, isEmpty);
    expect(find.byType(TransactionFormSheet), findsOneWidget);
    await tester.enterText(memo, '');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(repository.savedTransactions.single.memo, isEmpty);
  });
  testWidgets('키보드 위에서 입력 필드와 요약이 보이고 메모 단계에서도 저장한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final repository = _FakeSpendingRepository();
    addTearDown(repository.dispose);
    await _openExpenseForm(
      tester,
      repository: repository,
      theme: AppTheme.dark,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, '저장');
    final amount = find.byType(TextFormField).first;
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(530));
    expect(
      tester.getBottomRight(amount).dy,
      lessThan(tester.getTopLeft(save).dy),
    );
    await tester.enterText(amount, '5000');
    await tester.tap(find.widgetWithText(OutlinedButton, '메모 입력'));
    await tester.pumpAndSettle();
    final memo = find.byType(TextFormField).at(1);
    final summary = find.byKey(const ValueKey('transaction-summary'));
    expect(tester.getTopLeft(memo).dy, greaterThanOrEqualTo(0));
    expect(
      tester.getBottomRight(summary).dy,
      lessThan(tester.getTopLeft(save).dy),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '+1,000'));
    await tester.pumpAndSettle();
    expect(_textField('어떤 지출인가요?', tester).focusNode!.hasFocus, isTrue);
    await tester.enterText(memo, '커피');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.savedTransactions.single.amount, 6000);
    expect(repository.savedTransactions.single.memo, '커피');
    expect(tester.takeException(), isNull);
  });

  testWidgets('환불 확인 단계에서도 원 지출 연결을 유지한다', (tester) async {
    final repository = _FakeSpendingRepository()
      ..transactions = [
        TransactionRecord(
          id: 7,
          type: RecordType.expense,
          occurredAt: DateTime(2026, 11, 1),
          amount: 3000,
          memo: '커피',
          categoryId: 1,
          categoryName: '식비',
          paymentMethodId: 1,
        ),
      ];
    addTearDown(repository.dispose);
    await _openExpenseForm(
      tester,
      repository: repository,
      theme: AppTheme.dark,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '메모 입력'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '분류·결제 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('환불/취소'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<int> &&
            widget.decoration.labelText == '원 지출 연결 (선택)',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, '저장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면과 큰 글자에서도 단계 안내와 저장이 겹치지 않는다', (tester) async {
    final repository = _FakeSpendingRepository();
    addTearDown(repository.dispose);
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openExpenseForm(
      tester,
      repository: repository,
      theme: AppTheme.dark,
      textScale: 2,
    );

    expect(find.widgetWithText(OutlinedButton, '메모 입력'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '저장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openExpenseForm(
  WidgetTester tester, {
  required FinanceRepository repository,
  required ThemeData theme,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [financeRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<int>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const TransactionFormSheet(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

TextField _textField(String label, WidgetTester tester) {
  return tester.widget<TextField>(
    find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    ),
  );
}

class _UnlockedLockService extends LockService {
  const _UnlockedLockService();

  @override
  Future<bool> hasPin() async => false;
}

class _FakeSpendingRepository extends FinanceRepository {
  _FakeSpendingRepository()
    : super(
        database: AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
        ),
        settingsStore: SettingsStore(),
        notificationService: NotificationService(),
      );

  final _controller = StreamController<int>.broadcast();
  int _revision = 0;
  int? updatedId;
  TransactionDraft? updatedDraft;
  final updatedDrafts = <TransactionDraft>[];
  bool failNextSave = false;
  @override
  Future<void> updateTransaction(int id, TransactionDraft draft) async {
    updatedId = id;
    updatedDraft = draft;
    updatedDrafts.add(draft);
  }

  final savedTransactions = <TransactionDraft>[];
  List<TransactionRecord> transactions = const [];
  final _methods = <PaymentMethod>[
    const PaymentMethod(id: 1, name: '현금', isActive: true),
  ];
  @override
  Stream<int> get changes => _controller.stream;
  @override
  Future<List<PaymentMethod>> listPaymentMethods({
    bool includeInactive = false,
  }) async => List.of(_methods);

  @override
  Future<void> savePaymentMethod({int? id, required String name}) async {
    if (id == null) {
      _methods.add(
        PaymentMethod(id: _methods.length + 1, name: name, isActive: true),
      );
    } else {
      final index = _methods.indexWhere((method) => method.id == id);
      _methods[index] = PaymentMethod(id: id, name: name, isActive: true);
    }
    _controller.add(++_revision);
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
    return transactions;
  }

  @override
  Future<(int?, int?)> getLastExpenseSelection() async => (1, 1);

  @override
  Future<int> addTransaction(TransactionDraft draft) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('test save failure');
    }
    savedTransactions.add(draft);
    _controller.add(savedTransactions.length);
    return savedTransactions.length;
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
