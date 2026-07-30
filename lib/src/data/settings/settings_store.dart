import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const _monthStartDayKey = 'month_start_day';
  static const _lastCategoryIdKey = 'last_category_id';
  static const _lastPaymentMethodIdKey = 'last_payment_method_id';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<int> getMonthStartDay() async {
    return (await _preferences).getInt(_monthStartDayKey) ?? 1;
  }

  Future<void> setMonthStartDay(int day) async {
    await (await _preferences).setInt(_monthStartDayKey, day);
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
}
