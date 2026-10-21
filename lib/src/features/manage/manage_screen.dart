import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';

class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

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
            const Divider(height: 32),
            const _SectionLabel('예산과 기록'),
            _ManageTile(
              icon: Icons.category_outlined,
              title: '카테고리와 예산',
              subtitle: '예산기간, 카테고리, 금액',
              route: '/manage/category-budget',
            ),
            _ManageTile(
              icon: Icons.account_balance_outlined,
              title: '결제수단과 계좌',
              subtitle: '현금, 카드, 통장 잔액',
              route: '/manage/accounts-payment',
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
