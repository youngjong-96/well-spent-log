import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  Future<bool> getOnboardingCompleted() async =>
      (await _preferences).getBool('onboarding_completed') ?? false;

  Future<void> setOnboardingCompleted() async {
    if (!await (await _preferences).setBool('onboarding_completed', true)) {
      throw StateError('Could not save onboarding completion.');
    }
  }

  Future<bool> getFirstRecordHintPending() async =>
      (await _preferences).getBool('first_record_hint_pending') ?? false;

  Future<void> setFirstRecordHintPending(bool value) async {
    if (!await (await _preferences).setBool(
      'first_record_hint_pending',
      value,
    )) {
      throw StateError('Could not save first record hint.');
    }
  }

  static const _weeklyTotalsVisibleKey = 'weekly_totals_visible';
  static const _lastCategoryIdKey = 'last_category_id';
  static const _lastPaymentMethodIdKey = 'last_payment_method_id';
  static const _themeModeKey = 'theme_mode';
  static const _budgetAlertsEnabledKey = 'budget_alerts_enabled';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<bool> getBudgetAlertsEnabled() async =>
      (await _preferences).getBool(_budgetAlertsEnabledKey) ?? true;

  Future<void> setBudgetAlertsEnabled(bool enabled) async {
    if (!await (await _preferences).setBool(_budgetAlertsEnabledKey, enabled)) {
      throw StateError('Could not save budget alert preference.');
    }
  }

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
