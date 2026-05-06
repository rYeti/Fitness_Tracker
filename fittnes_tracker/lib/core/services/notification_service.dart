import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _planExpiryId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> schedulePlanExpiryWarning({
    required String planName,
    required DateTime planEndDate,
    int daysBeforeEnd = 7,
  }) async {
    if (kIsWeb) return;
    await cancelPlanExpiryWarning();
    final fireAt = planEndDate.subtract(Duration(days: daysBeforeEnd));
    if (fireAt.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'plan_expiry',
      'Workout Plan Expiry',
      channelDescription: 'Notifies when a workout plan is ending soon',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await _plugin.zonedSchedule(
      _planExpiryId,
      'Workout plan ending soon',
      'Your plan "$planName" ends in 7 days. Tap to extend or create a new one.',
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelPlanExpiryWarning() async {
    if (kIsWeb) return;
    await _plugin.cancel(_planExpiryId);
  }
}
