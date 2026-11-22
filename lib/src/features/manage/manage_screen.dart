import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../onboarding/onboarding_screen.dart';

class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key, this.visible = true});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              '관리',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        SliverList.list(
          children: [
            const _SectionLabel('화면'),
            const _ThemeModeTile(),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('온보딩 다시 보기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (routeContext) => OnboardingScreen(
                    replay: true,
                    onFinished: () => Navigator.pop(routeContext),
                  ),
                ),
              ),
            ),
            const Divider(height: 32),
            const _SectionLabel('예산과 기록'),
            _BudgetAlertsTile(visible: visible),
            _ManageTile(
              icon: Icons.category_outlined,
              title: '카테고리와 예산',
              subtitle: '예산기간, 카테고리, 금액',
              route: '/manage/category-budget',
            ),
            _ManageTile(
              icon: Icons.account_balance_outlined,
              title: '결제수단',
              subtitle: '내가 쓰는 결제수단 이름 관리',
              route: '/manage/payment-methods',
            ),
            _ManageTile(
              icon: Icons.bookmarks_outlined,
              title: '빠른 기록 템플릿',
              subtitle: '자주 쓰는 지출 저장',
              route: '/manage/templates',
            ),
            const Divider(height: 32),
            const _SectionLabel('데이터와 보안'),
            _ManageTile(
              icon: Icons.import_export_outlined,
              title: '백업과 내보내기',
              subtitle: 'JSON 복원, CSV 내보내기',
              route: '/manage/backup',
            ),
            _ManageTile(
              icon: Icons.lock_outline,
              title: '앱 잠금',
              subtitle: '숫자 PIN 설정',
              route: '/manage/security',
            ),
            const SizedBox(height: 120),
          ],
        ),
      ],
    );
  }
}

class _BudgetAlertsTile extends ConsumerStatefulWidget {
  const _BudgetAlertsTile({required this.visible});

  final bool visible;

  @override
  ConsumerState<_BudgetAlertsTile> createState() => _BudgetAlertsTileState();
}

class _BudgetAlertsTileState extends ConsumerState<_BudgetAlertsTile> {
  late final AppLifecycleListener _lifecycle;
  Future<bool>? _permission;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshPermission);
    if (widget.visible) _refreshPermission();
  }

  @override
  void didUpdateWidget(covariant _BudgetAlertsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) _refreshPermission();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshPermission() {
    if (!widget.visible) return;
    setState(() {
      _permission = ref.read(notificationServiceProvider).hasPermission();
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsStoreProvider).setBudgetAlertsEnabled(enabled);
      if (!mounted) return;
      ref.invalidate(budgetAlertsEnabledProvider);
      if (enabled) {
        await ref.read(notificationServiceProvider).requestPermission();
      }
    } catch (_) {
      if (mounted) _showError('예산 알림 설정을 변경하지 못했어요.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refreshPermission();
      }
    }
  }

  Future<void> _openSettings() async {
    try {
      await ref.read(notificationServiceProvider).openNotificationSettings();
    } catch (_) {
      if (mounted) _showError('휴대전화 설정에서 이 앱의 알림을 켜 주세요.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(budgetAlertsEnabledProvider);
    return FutureBuilder<bool>(
      future: _permission,
      builder: (context, permission) {
        final needsPermission =
            enabled.value == true &&
            (permission.hasError || permission.data == false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('예산 알림'),
              subtitle: Text(
                needsPermission
                    ? '알림 권한이 꺼져 있어요'
                    : '50% · 80% · 100%에 알려드려요',
              ),
              value: enabled.value ?? false,
              onChanged: _busy || !enabled.hasValue ? null : _setEnabled,
            ),
            if (needsPermission &&
                ref
                    .watch(notificationServiceProvider)
                    .canOpenNotificationSettings)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton(
                  onPressed: _busy ? null : _openSettings,
                  child: const Text('설정 열기'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return ListTile(
      minTileHeight: 68,
      leading: Icon(
        mode == ThemeMode.dark
            ? Icons.dark_mode_outlined
            : mode == ThemeMode.light
            ? Icons.light_mode_outlined
            : Icons.brightness_auto_outlined,
      ),
      title: const Text('화면 모드'),
      subtitle: Text(_themeModeLabel(mode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeSheet(context, ref, mode),
    );
  }

  Future<void> _showThemeModeSheet(
    BuildContext context,
    WidgetRef ref,
    ThemeMode selectedMode,
  ) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Text(
                  '화면 모드',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final mode in ThemeMode.values)
                ListTile(
                  leading: Icon(_themeModeIcon(mode)),
                  title: Text(_themeModeLabel(mode)),
                  subtitle: mode == ThemeMode.system
                      ? const Text('휴대전화의 밝기 설정을 따라요')
                      : null,
                  trailing: selectedMode == mode
                      ? const Icon(Icons.check_rounded)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => Navigator.pop(context, mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await ref.read(themeModeProvider.notifier).setMode(selected);
    }
  }
}

String _themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '시스템 설정',
  ThemeMode.light => '라이트 모드',
  ThemeMode.dark => '다크 모드',
};

IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 68,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
