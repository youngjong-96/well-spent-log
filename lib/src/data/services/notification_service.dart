import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const _settingsChannel = MethodChannel(
    'well_spent_log/notification_settings',
  );

  bool get canOpenNotificationSettings =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> openNotificationSettings() =>
      _settingsChannel.invokeMethod<void>('open');

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> showBudgetAlert({
    required int id,
    required String categoryName,
    required int threshold,
  }) async {
    if (kIsWeb) return false;
    await initialize();
    if (!await hasPermission()) return false;
    await _plugin.show(
      id: id,
      title: '$categoryName 예산 알림',
      body: threshold >= 100
          ? '설정한 예산을 모두 사용했어요.'
          : '설정한 예산의 $threshold%를 사용했어요.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alerts',
          '예산 알림',
          channelDescription: '카테고리별 예산 사용률을 알려줍니다.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    return true;
  }

  Future<bool> hasPermission() async {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ==
            true,
      TargetPlatform.iOS =>
        (await _plugin
                    .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin
                    >()
                    ?.checkPermissions())
                ?.isEnabled ==
            true,
      _ => true,
    };
  }

  Future<void> requestPermission() async {
    if (kIsWeb || await hasPermission()) return;
    await initialize();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      case TargetPlatform.iOS:
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true);
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        break;
    }
  }
}
