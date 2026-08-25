import 'package:ForgeForm/core/network/api_client.dart';
import 'package:dio/dio.dart';

/// An [ApiClient] that answers from a map instead of the network, and records
/// what was asked of it.
///
/// [ApiClient]'s HTTP methods are ordinary instance methods, so overriding them
/// is enough — the real Dio instance the superclass builds is never used.
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://localhost/');

  /// Response bodies keyed by path. A path with no entry throws, the same way a
  /// 404 would, so a test that forgets to stub something fails loudly.
  final Map<String, dynamic> getResponses = {};

  /// Response bodies for POSTs, keyed by path. Missing entries return `{}`.
  final Map<String, dynamic> postResponses = {};

  final List<String> gets = [];
  final List<({String path, dynamic data})> posts = [];
  final List<({String path, dynamic data})> puts = [];
  final List<String> deletes = [];

  /// Stubs every endpoint `pullAll` touches with an empty result, so a test only
  /// has to describe the one it cares about.
  void stubEmptyPull() {
    getResponses.addAll({
      'api/Exercise/AllExercises': <dynamic>[],
      'api/Exercise/UserExercise': <dynamic>[],
      'api/UserSettings': null,
      'api/Workout': <dynamic>[],
      'api/WorkoutPlan': <dynamic>[],
      'api/ScheduledWorkout': <dynamic>[],
      'api/WeightTracking/TrackWeight': <dynamic>[],
      'api/FoodItem': <dynamic>[],
      'api/Meal/all': <dynamic>[],
      'api/MealTemplate': <dynamic>[],
    });
  }

  Response<dynamic> _ok(String path, dynamic data) => Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: data,
  );

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    gets.add(path);
    if (!getResponses.containsKey(path)) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        message: 'FakeApiClient: no stub for GET $path',
      );
    }
    return _ok(path, getResponses[path]);
  }

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add((path: path, data: data));
    return _ok(path, postResponses[path] ?? <String, dynamic>{});
  }

  @override
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    puts.add((path: path, data: data));
    return _ok(path, <String, dynamic>{});
  }

  @override
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    deletes.add(path);
    return _ok(path, null);
  }
}

/// A workout as `GET api/Workout` returns it.
Map<String, dynamic> serverWorkout({
  required String id,
  required String name,
  List<Map<String, dynamic>> exercises = const [],
}) => {
  'id': id,
  'name': name,
  'description': null,
  'difficulty': 0,
  'estimatedDurationMinutes': 30,
  'isTemplate': true,
  'scheduledDate': null,
  'completedDate': null,
  'color': null,
  'exercises': exercises,
};

/// A workout exercise as the API nests it inside a workout.
Map<String, dynamic> serverWorkoutExercise({
  required String id,
  required String exerciseId,
  required int orderPosition,
  String? removedAt,
  List<Map<String, dynamic>> setTemplates = const [],
}) => {
  'id': id,
  'exerciseId': exerciseId,
  'orderPosition': orderPosition,
  'notes': null,
  'supersetGroupId': null,
  'removedAt': removedAt,
  'setTemplates': setTemplates,
};

/// A set template as the API nests it inside a workout exercise.
Map<String, dynamic> serverSetTemplate({
  required String id,
  required int setNumber,
  String targetReps = '8 - 12',
}) => {
  'id': id,
  'setNumber': setNumber,
  'targetReps': targetReps,
  'orderPosition': setNumber - 1,
};
