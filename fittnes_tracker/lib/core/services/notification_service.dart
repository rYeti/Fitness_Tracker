import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _planExpiryId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;

  /// Initialises the plugin at most once, on first use.
  ///
  /// Deliberately not called from `main()`: this loads the full timezone
  /// database and used to also raise the Android 13+ notification permission
  /// dialog, which blocks on the user's tap — so a first launch sat on the
  /// splash screen until they answered. The permission is now requested where
  /// it means something, in [schedulePlanExpiryWarning].
  Future<void> _ensureInitialized() {
    if (kIsWeb) return Future.value();
    return _initialization ??= _init();
  }

  Future<void> _init() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );
  }

  Future<void> schedulePlanExpiryWarning({
    required String planName,
    required DateTime planEndDate,
    int daysBeforeEnd = 7,
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await cancelPlanExpiryWarning();
    final fireAt = planEndDate.subtract(Duration(days: daysBeforeEnd));
    if (fireAt.isBefore(DateTime.now())) return;

    // Asked for here rather than at startup: the user has just created a plan
    // with an end date, so what the notification is for is obvious.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

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
    await _ensureInitialized();
    await _plugin.cancel(_planExpiryId);
  }
}
