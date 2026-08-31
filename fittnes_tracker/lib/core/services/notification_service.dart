import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _planExpiryId = 1001;

  /// The Android channel every chat notification is drawn on.
  ///
  /// Wholly this app's business now. It used to have to match a constant on the
  /// server, which sent a `notification` payload and named the channel the OS
  /// should render it on. Push went data-only when chat became end-to-end
  /// encrypted — the server cannot read a message, so it cannot render one — so
  /// this app raises every chat notification itself and names its own channel.
  ///
  /// Android silently drops a notification naming a channel that does not
  /// exist: no error anywhere, just nothing on screen. [_ensureInitialized]
  /// creates it before anything can be shown.
  static const chatChannelId = 'chat_messages';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;

  /// Invoked when the user taps a chat notification this plugin displayed, with
  /// the thread id carried in its payload. Wired up by [PushService].
  ///
  /// Read inside the plugin's tap callback rather than captured, so it can be
  /// set after initialisation — which it is, since initialisation is lazy.
  void Function(String? threadId)? onChatNotificationTap;

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
      // Was an empty stub, which meant a tap on any locally-shown notification
      // opened the app and did nothing else. Chat needs the tap to land
      // somewhere, so the payload is routed out to whoever is listening.
      onDidReceiveNotificationResponse: (response) {
        onChatNotificationTap?.call(response.payload);
      },
    );

    // Created up front so it exists before the first push names it. Android
    // creates channels lazily from a notification otherwise, which loses the
    // name and importance we want it to have.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            chatChannelId,
            'Messages',
            description: 'Messages from your trainer or your clients',
            importance: Importance.high,
          ),
        );
  }

  /// Shows a chat notification this app is rendering itself.
  ///
  /// **Every** chat notification now, foreground or not. It used to be the
  /// foreground-only case, because a backgrounded app let the OS draw the FCM
  /// `notification` payload directly. Encryption removed that option — the
  /// server cannot write a notification for a message it cannot read — so push
  /// is data-only and this is on the delivery path for the case push exists to
  /// solve. See docs/chat-encryption.md.
  Future<void> showChatMessage({
    required String title,
    required String body,
    required String? threadId,
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await presentChatNotification(
      plugin: _plugin,
      title: title,
      body: body,
      threadId: threadId,
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

/// Draws one chat notification on [plugin].
///
/// Top-level, and takes its plugin as an argument, because the push background
/// isolate has no [NotificationService] and no service locator to find one
/// with. Both callers have to agree on the notification id and channel or a
/// backgrounded message and a foregrounded one would stack instead of replacing
/// each other, so there is exactly one place that decides.
Future<void> presentChatNotification({
  required FlutterLocalNotificationsPlugin plugin,
  required String title,
  required String body,
  required String? threadId,
}) {
  return plugin.show(
    // Hashed off the thread so a second message from the same person replaces
    // the first rather than stacking. Chat is a conversation, not a log.
    threadId.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationService.chatChannelId,
        'Messages',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: threadId,
  );
}
