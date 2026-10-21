import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import 'theme/app_colors.dart';
import '../domain/models/transaction_type.dart';
import '../features/home/home_screen.dart';
import '../features/manage/manage_screen.dart';
import '../features/report/report_screen.dart';
import '../features/transaction/transaction_form_sheet.dart';
import '../features/transactions/transactions_screen.dart';
import '../shared/widgets/quick_entry_fab.dart';
import '../shared/widgets/transaction_type_sheet.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  late final TransactionsScreenController _transactionsController;

  @override
  void initState() {
    super.initState();
    _transactionsController = TransactionsScreenController();
  }

  @override
  void dispose() {
    _transactionsController.dispose();
    super.dispose();
  }

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
    final screens = [
      HomeScreen(onOpenCategoryDetails: _openCategoryDetails),
      TransactionsScreen(controller: _transactionsController),
      const ReportScreen(),
      const ManageScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      floatingActionButton: QuickEntryFab(
        onPressed: () => _showTransactionTypeSheet(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _BottomNavItem(
              label: '홈',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              selected: _selectedIndex == 0,
              onTap: () => _selectTab(0),
            ),
            _BottomNavItem(
              label: '내역',
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
              selected: _selectedIndex == 1,
              onTap: () => _selectTab(1),
            ),
            const SizedBox(width: 78),
            _BottomNavItem(
              label: '보고서',
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart_rounded,
              selected: _selectedIndex == 2,
              onTap: () => _selectTab(2),
            ),
            _BottomNavItem(
              label: '관리',
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              selected: _selectedIndex == 3,
              onTap: () => _selectTab(3),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openCategoryDetails(int categoryId) {
    _transactionsController.openCategory(categoryId);
    setState(() => _selectedIndex = 1);
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
            label: '저장 취소',
            onPressed: () => _undoCreatedTransaction(transactionId),
          ),
        ),
      );
  }

  Future<void> _undoCreatedTransaction(int transactionId) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .softDeleteTransaction(transactionId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('저장을 취소하지 못했어요.'),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () => _undoCreatedTransaction(transactionId),
            ),
          ),
        );
    }
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : AppColors.textSecondary.withValues(alpha: 0.62);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label 탭',
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 25),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
