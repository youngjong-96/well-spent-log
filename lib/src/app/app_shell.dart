import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models/transaction_type.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/home/home_screen.dart';
import '../features/manage/manage_screen.dart';
import '../features/report/report_screen.dart';
import '../features/transaction/transaction_form_sheet.dart';
import '../shared/widgets/quick_entry_fab.dart';
import '../shared/widgets/transaction_type_sheet.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const _screens = [
    HomeScreen(),
    CalendarScreen(),
    ReportScreen(),
    ManageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final initialization = ref.watch(appInitializationProvider);
    if (initialization.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (initialization.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('앱을 시작하지 못했어요.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(appInitializationProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _screens),
      ),
      floatingActionButton: QuickEntryFab(
        onPressed: () => _showTransactionTypeSheet(context),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '달력',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '보고서',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '관리',
          ),
        ],
      ),
    );
  }

  Future<void> _showTransactionTypeSheet(BuildContext context) async {
    final type = await showModalBottomSheet<TransactionType>(
      context: context,
      showDragHandle: true,
      builder: (context) => const TransactionTypeSheet(),
    );

    if (!context.mounted || type == null) {
      return;
    }

    final transactionId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => TransactionFormSheet(transactionType: type),
    );
    if (!context.mounted || transactionId == null) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('저장했어요'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () {
              ref
                  .read(financeRepositoryProvider)
                  .softDeleteTransaction(transactionId);
            },
          ),
        ),
      );
  }
}
