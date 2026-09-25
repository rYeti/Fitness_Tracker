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

  /// Response bodies for POSTs, keyed by path. A missing entry answers the
  /// way the API does for a create it accepts: with what it was sent — so a
  /// create comes back under the id the app minted, and a batch comes back as
  /// the rows it was given, each naming the id it was sent with
  /// (`requestedId`), as the API's batch answers do.
  final Map<String, dynamic> postResponses = {};

  /// Status codes POSTs fail with, keyed by path — a 409 for an id the server
  /// refuses, say. A missing entry is a success.
  final Map<String, int> postStatuses = {};

  /// Bodies of the failures in [postStatuses], keyed by path — the API's 409
  /// names the id it refused (`{error: id_in_use, id: …}`).
  final Map<String, dynamic> postErrorBodies = {};

  /// Status codes PUTs fail with, keyed by path. A missing entry is a success.
  final Map<String, int> putStatuses = {};

  /// Paths whose next POST reaches the server but whose response never comes
  /// back: the request is recorded, then the call fails as a dropped
  /// connection does, with no response at all. Each path loses one response.
  final Set<String> postsLosingResponse = {};

  /// Status codes DELETEs answer with, keyed by path. A missing entry is a
  /// success.
  final Map<String, int> deleteStatuses = {};

  /// Runs while a PUT is in flight — after the request is made, before the
  /// response arrives — to stand in for the user editing meanwhile.
  Future<void> Function(String path)? duringPut;

  final List<String> gets = [];
  final List<({String path, dynamic data})> posts = [];
  final List<({String path, dynamic data})> puts = [];
  final List<String> deletes = [];

  /// Every request, in the order made, as `METHOD path` — for a test about
  /// what goes before what.
  final List<String> requests = [];

  /// What `GET api/Sync/changes` answers: the changes feed, in the API's
  /// shape. Every list starts empty, with no deletions and a fixed cursor; a
  /// test puts in what the server has changed. It answers the same whatever
  /// `since` is sent — for a test that pulls twice, the second answer is what
  /// this holds by then. [changesSince] records what was sent.
  final Map<String, dynamic> changes = emptyChanges();

  /// The `since` each changes request carried, in order.
  final List<String?> changesSince = [];

  /// Ids the server holds a deletion of: a POST naming one — as a create, or
  /// as an entry of a batch — is refused with 410 `{error: id_deleted, id}`,
  /// as the API refuses to create a deleted id again.
  final Set<String> deletedIds = {};

  /// A changes answer holding nothing, with [cursor] as its cursor.
  static Map<String, dynamic> emptyChanges({
    String cursor = '2026-01-01T00:00:00.000Z',
  }) => {
    'exercises': <dynamic>[],
    'workouts': <dynamic>[],
    'workoutPlans': <dynamic>[],
    'scheduledWorkouts': <dynamic>[],
    'foodItems': <dynamic>[],
    'meals': <dynamic>[],
    'mealTemplates': <dynamic>[],
    'weights': <dynamic>[],
    'settings': null,
    'deleted': <dynamic>[],
    'cursor': cursor,
  };

  /// Stubs what `pullAll` asks for with an empty result — the built-in
  /// exercise catalogue, and a changes answer with nothing in it — so a test
  /// only has to describe what it cares about.
  void stubEmptyPull() {
    getResponses['api/Exercise/AllExercises'] = <dynamic>[];
    changes
      ..clear()
      ..addAll(emptyChanges());
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
    requests.add('GET $path');
    if (path == 'api/Sync/changes') {
      changesSince.add(queryParameters?['since'] as String?);
      return _ok(path, Map<String, dynamic>.from(changes));
    }
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
    requests.add('POST $path');
    if (postsLosingResponse.remove(path)) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
        message: 'FakeApiClient: response to POST $path lost',
      );
    }
    final deleted = _deletedIdIn(data);
    if (deleted != null) {
      _failIfStubbed(path, 410, {'error': 'id_deleted', 'id': deleted});
    }
    _failIfStubbed(path, postStatuses[path], postErrorBodies[path]);
    return _ok(path, postResponses[path] ?? _echo(data));
  }

  String? _deletedIdIn(dynamic data) {
    for (final item in data is List ? data : [data]) {
      if (item is Map && deletedIds.contains(item['id'])) {
        return item['id'] as String;
      }
    }
    return null;
  }

  static dynamic _echo(dynamic data) => switch (data) {
    final Map m => Map<String, dynamic>.from(m),
    final List l => [
      for (final e in l)
        e is Map
            ? {...Map<String, dynamic>.from(e), 'requestedId': e['id']}
            : e,
    ],
    _ => <String, dynamic>{},
  };

  void _failIfStubbed(String path, int? status, [dynamic body]) {
    if (status == null) return;
    final options = RequestOptions(path: path);
    throw DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        data: body,
      ),
    );
  }

  @override
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    puts.add((path: path, data: data));
    requests.add('PUT $path');
    await duringPut?.call(path);
    _failIfStubbed(path, putStatuses[path]);
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
    requests.add('DELETE $path');
    final status = deleteStatuses[path];
    if (status != null) {
      final options = RequestOptions(path: path);
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: status),
      );
    }
    return _ok(path, null);
  }
}

/// A deletion as the changes feed lists it.
Map<String, dynamic> serverTombstone(String entityType, String entityId) => {
  'entityType': entityType,
  'entityId': entityId,
  'deletedAt': '2026-01-10T00:00:00Z',
};

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
