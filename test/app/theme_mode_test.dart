import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:well_spent_log/src/application/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saved theme mode is restored and a new selection is persisted',
    () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(
        (await SharedPreferences.getInstance()).getString('theme_mode'),
        'light',
      );
    },
  );
}
