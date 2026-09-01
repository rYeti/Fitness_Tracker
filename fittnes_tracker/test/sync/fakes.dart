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

/// A scheduled workout (a logged session) as `GET api/ScheduledWorkout`
/// returns it.
Map<String, dynamic> serverScheduledWorkout({
  required String id,
  required String workoutId,
  String scheduledDate = '2026-01-05T00:00:00Z',
  bool isCompleted = true,
  List<Map<String, dynamic>> exercises = const [],
}) => {
  'id': id,
  'workoutId': workoutId,
  'workoutPlanId': null,
  'templateWorkoutId': null,
  'scheduledDate': scheduledDate,
  'createdAt': scheduledDate,
  'notes': null,
  'isCompleted': isCompleted,
  'isSkipped': false,
  'exercises': exercises,
};

/// A scheduled workout's exercise as the API nests it inside a scheduled
/// workout. `workoutExerciseId` links back to the workout-template slot
/// (`serverWorkoutExercise.id`) this session performed.
Map<String, dynamic> serverScheduledExercise({
  required String id,
  required String workoutExerciseId,
  bool isCompleted = true,
  List<Map<String, dynamic>> sets = const [],
}) => {
  'id': id,
  'workoutExerciseId': workoutExerciseId,
  'isCompleted': isCompleted,
  'notes': null,
  'sets': sets,
};

/// A logged set as the API nests it inside a scheduled exercise.
Map<String, dynamic> serverSet({
  required String id,
  required int setNumber,
  int? reps,
  num? weight,
  bool isCompleted = true,
}) => {
  'id': id,
  'setNumber': setNumber,
  'reps': reps,
  'weight': weight,
  'weightUnit': 'kg',
  'durationSeconds': null,
  'isCompleted': isCompleted,
  'notes': null,
};

/// A food item as `GET api/FoodItem` returns it.
Map<String, dynamic> serverFoodItem({
  required String id,
  required String name,
  int calories = 100,
  int protein = 10,
  int carbs = 10,
  int fat = 5,
}) => {
  'id': id,
  'name': name,
  'calories': calories,
  'protein': protein,
  'carbs': carbs,
  'fat': fat,
  'gramm': 100,
  'hiddenFromRecent': false,
  'extendedNutrientsJson': null,
};

/// A meal as `GET api/Meal/all` returns it.
Map<String, dynamic> serverMeal({
  required String id,
  required String foodItemId,
  String date = '2026-01-05T00:00:00Z',
  String category = 'breakfast',
  List<Map<String, dynamic>> foodEntries = const [],
}) => {
  'id': id,
  'date': date,
  'category': category,
  'foodItemId': foodItemId,
  'foodEntries': foodEntries,
};

/// A food entry as the API nests it inside a meal.
Map<String, dynamic> serverFoodEntry({
  required String id,
  required String foodItemId,
}) => {'id': id, 'foodItemId': foodItemId};
