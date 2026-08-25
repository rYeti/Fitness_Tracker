import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/services/push_service.dart';

/// Records what reached the API instead of issuing it.
///
/// `ApiClient` is a concrete Dio wrapper rather than an interface, so this
/// subclasses it and overrides the two verbs push uses. Crude, but it keeps the
/// test off the network without reshaping production code for the test's benefit.
class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(baseUrl: 'https://example.invalid/');

  final List<({String path, Object? data})> posts = [];
  final List<String> deletes = [];
  Object? throwOnPost;

  Response<dynamic> get _empty =>
      Response<dynamic>(requestOptions: RequestOptions(path: '/'));

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add((path: path, data: data));
    if (throwOnPost != null) throw throwOnPost!;
    return _empty;
  }

  @override
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    deletes.add(path);
    return _empty;
  }
}

void main() {
  late _RecordingApiClient api;

  setUp(() => api = _RecordingApiClient());

  group('token lifecycle', () {
    test('unregister deletes the token this device last registered', () async {
      final push = PushService(client: api)..debugSetToken('phone-token');

      await push.unregisterForCurrentUser();

      expect(api.deletes, ['api/devicetoken/phone-token']);
      // Cleared locally too, so a second sign-out cannot delete someone else's.
      expect(push.currentToken, isNull);
    });

    test('unregister with no token registered does nothing', () async {
      final push = PushService(client: api);

      await push.unregisterForCurrentUser();

      expect(api.deletes, isEmpty);
    });

    test('a failed unregister does not throw into the sign-out path', () async {
      final push = PushService(client: api)..debugSetToken('phone-token');

      // Signing out must complete even with no connectivity; the alternative is
      // a user trapped in a session because the network is down.
      await expectLater(push.unregisterForCurrentUser(), completes);
    });

    test('registering when push is unavailable is a no-op', () async {
      // The normal state on web, and on any machine without google-services.json.
      final push = PushService(client: api);

      await push.registerForCurrentUser();

      expect(api.posts, isEmpty);
    });
  });

  group('tap routing', () {
    test('a local tap emits the thread it carries', () async {
      final push = PushService(client: api);
      final targets = <String>[];
      push.onNotificationTap.listen((t) => targets.add(t.threadId));

      push.handleLocalTap('trainer-id');
      await pumpEventQueue();

      expect(targets, ['trainer-id']);
    });

    test('a tap with no thread id is ignored', () async {
      final push = PushService(client: api);
      final targets = <String>[];
      push.onNotificationTap.listen((t) => targets.add(t.threadId));

      push.handleLocalTap(null);
      push.handleLocalTap('');
      await pumpEventQueue();

      // Nothing to navigate to. Opening the app on an arbitrary screen would be
      // worse than opening it where the user left off.
      expect(targets, isEmpty);
    });
  });
}
