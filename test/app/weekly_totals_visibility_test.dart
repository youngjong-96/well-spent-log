import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:well_spent_log/src/application/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('weekly totals default to visible and choice survives a new session', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(weeklyTotalsVisibleProvider.future), isTrue);
    await container.read(weeklyTotalsVisibleProvider.notifier).setVisible(false);
    expect(container.read(weeklyTotalsVisibleProvider).value, isFalse);

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect(await restored.read(weeklyTotalsVisibleProvider.future), isFalse);
    await restored.read(weeklyTotalsVisibleProvider.notifier).setVisible(true);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('weekly_totals_visible'), isTrue);
  });
}
