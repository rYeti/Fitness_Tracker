import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// Where a chat notification wants to take you.
///
/// A payload rather than a route string: the two surfaces are reached completely
/// differently — the trainee pushes a screen, the trainer opens a console tab —
/// and only `main.dart` knows how to do either.
class ChatNotificationTarget {
  /// The other party in the thread, from this device's point of view.
  final String threadId;

  const ChatNotificationTarget({required this.threadId});
}

/// Owns this device's FCM registration: permission, the token, and the two
/// halves of its lifetime (register on sign-in, delete on sign-out).
///
/// Push is a **second, independent delivery path**. SignalR only carries a
/// message while a chat screen is mounted and holding a socket; everything else —
/// backgrounded, on another tab, force-closed — is this class's job. The two do
/// not coordinate, and deliberately so: coordinating them would need server-side
/// presence, which is state that goes stale on every dropped connection.
class PushService {
  final ApiClient _client;

  /// Injected so tests never touch a real Firebase instance.
  final FirebaseMessaging? _messagingOverride;

  PushService({ApiClient? client, FirebaseMessaging? messaging})
    : _client = client ?? sl<ApiClient>(instanceName: backendApiClient),
      _messagingOverride = messaging;

  /// Emits when the user taps a notification. `main.dart` listens and navigates.
  final _taps = StreamController<ChatNotificationTarget>.broadcast();
  Stream<ChatNotificationTarget> get onNotificationTap => _taps.stream;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _tapSub;

  /// The token last handed to the server, so sign-out knows what to delete.
  ///
  /// Held here rather than re-read at sign-out time because `getToken()` is a
  /// network call that can fail exactly when connectivity is poor — and failing
  /// to unregister is the failure that leaks one user's messages to the next
  /// person to use the phone.
  String? _currentToken;
  String? get currentToken => _currentToken;

  /// Puts this device in the "already registered" state without a Firebase
  /// instance, so the sign-out path can be tested at all.
  @visibleForTesting
  void debugSetToken(String? token) => _currentToken = token;

  bool _available = false;

  /// True once Firebase actually initialised. False is normal and not an error:
  /// the config file is absent on web, on any dev machine without it, and on
  /// every platform we have not set up yet.
  bool get isAvailable => _available;

  FirebaseMessaging get _messaging => _messagingOverride ?? FirebaseMessaging.instance;

  /// Brings Firebase up. Safe to call when it is not configured — it simply
  /// leaves [isAvailable] false and every other method a no-op.
  Future<void> init() async {
    // Web push needs a service worker and a VAPID key, neither of which exists
    // here yet; the Trainer Console is a browser app and must not trip over this.
    if (kIsWeb) return;

    try {
      if (_messagingOverride == null) await Firebase.initializeApp();
      _available = true;
    } catch (error) {
      // Overwhelmingly this means google-services.json is missing. That is a
      // configuration state, not a crash: the app keeps working without push.
      debugPrint('Push unavailable: $error');
      _available = false;
      return;
    }

    // Asked for at startup rather than at sign-in: on Android 13+ and iOS this
    // shows a system dialog, and the answer is remembered per install. Denial is
    // a normal outcome and nothing below depends on it succeeding.
    await _messaging.requestPermission();

    _tapSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // A tap that launched the app from cold has no stream event — the message is
    // waiting here instead, exactly once.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // FCM reissues tokens on its own schedule. Treating registration as a
    // one-time event is how a device quietly stops receiving anything weeks
    // later, with nothing to indicate it happened.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      unawaited(_register(token));
    });
  }

  /// Registers this device against the signed-in user. Call after every path
  /// that establishes a session — login, register, and cold-start restore.
  Future<void> registerForCurrentUser() async {
    if (!_available) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      _currentToken = token;
      await _register(token);
    } catch (error) {
      // A device that fails to register just doesn't get notified. Nothing about
      // signing in should fail because of it.
      debugPrint('Could not register for push: $error');
    }
  }

  /// Unregisters this device. **Call before clearing the session**, or the
  /// request goes out without an Authorization header and silently 401s.
  ///
  /// The token left behind would keep delivering the previous user's messages to
  /// this phone — which is the single worst outcome this class can produce, and
  /// the reason it is worth being careful about ordering.
  Future<void> unregisterForCurrentUser() async {
    final token = _currentToken;
    if (token == null) return;

    _currentToken = null;
    try {
      await _client.delete('api/devicetoken/$token');
    } catch (error) {
      debugPrint('Could not unregister push token: $error');
    }
  }

  Future<void> _register(String token) async {
    await _client.post(
      'api/devicetoken',
      data: {
        'token': token,
        // Matches DevicePlatform on the server. Android is the only value the
        // app can currently produce; iOS has never been built here.
        'platform': 0,
      },
    );
  }

  void _handleTap(RemoteMessage message) {
    if (message.data['type'] != 'chat_message') return;
    final threadId = message.data['threadId'];
    if (threadId is! String || threadId.isEmpty) return;

    _taps.add(ChatNotificationTarget(threadId: threadId));
  }

  /// Routes a tap that arrived through the local-notifications plugin instead —
  /// the foreground case, where the OS does not display anything itself.
  void handleLocalTap(String? threadId) {
    if (threadId == null || threadId.isEmpty) return;
    _taps.add(ChatNotificationTarget(threadId: threadId));
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _tapSub?.cancel();
    await _taps.close();
  }
}
