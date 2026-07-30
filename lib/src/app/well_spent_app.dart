import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import '../features/lock/lock_gate.dart';
import '../features/manage/accounts_payment_screen.dart';
import '../features/manage/backup_screen.dart';
import '../features/manage/category_budget_screen.dart';
import '../features/manage/security_screen.dart';
import '../features/manage/templates_screen.dart';
import 'theme/app_theme.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AppShell()),
    GoRoute(
      path: '/manage/category-budget',
      builder: (context, state) => const CategoryBudgetScreen(),
    ),
    GoRoute(
      path: '/manage/accounts-payment',
      builder: (context, state) => const AccountsPaymentScreen(),
    ),
    GoRoute(
      path: '/manage/templates',
      builder: (context, state) => const TemplatesScreen(),
    ),
    GoRoute(
      path: '/manage/backup',
      builder: (context, state) => const BackupScreen(),
    ),
    GoRoute(
      path: '/manage/security',
      builder: (context, state) => const SecurityScreen(),
    ),
  ],
);

class WellSpentApp extends StatelessWidget {
  const WellSpentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '잘쓸결심',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      routerConfig: _router,
      builder: (context, child) =>
          LockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
