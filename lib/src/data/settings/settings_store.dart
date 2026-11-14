import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const _weeklyTotalsVisibleKey = 'weekly_totals_visible';
  static const _lastCategoryIdKey = 'last_category_id';
  static const _lastPaymentMethodIdKey = 'last_payment_method_id';
  static const _themeModeKey = 'theme_mode';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<bool> getWeeklyTotalsVisible() async {
    return (await _preferences).getBool(_weeklyTotalsVisibleKey) ?? true;
  }

  Future<void> setWeeklyTotalsVisible(bool visible) async {
    final saved = await (await _preferences).setBool(
      _weeklyTotalsVisibleKey,
      visible,
    );
    if (!saved) throw StateError('Could not save weekly totals visibility.');
  }

  Future<int?> getLastCategoryId() async {
    return (await _preferences).getInt(_lastCategoryIdKey);
  }

  Future<int?> getLastPaymentMethodId() async {
    return (await _preferences).getInt(_lastPaymentMethodIdKey);
  }

  Future<void> setLastExpenseSelection({
    required int categoryId,
    required int paymentMethodId,
  }) async {
    final preferences = await _preferences;
    await preferences.setInt(_lastCategoryIdKey, categoryId);
    await preferences.setInt(_lastPaymentMethodIdKey, paymentMethodId);
  }

  Future<String> getThemeMode() async {
    return (await _preferences).getString(_themeModeKey) ?? 'system';
  }

  Future<void> setThemeMode(String value) async {
    await (await _preferences).setString(_themeModeKey, value);
  }
}
