// Domain models for the new TrainerConsoleController/WorkoutPlanTemplateController
// endpoints. Field shapes mirror the backend DTOs (see TrainerConsoleDtos.cs);
// fromJson bodies are left as stubs since the backend endpoints themselves
// are still NotImplementedException stubs.

class TrainerDashboardKpis {
  final int activeClientCount;
  final double avgAdherencePercent;
  final int sessionsThisWeek;

  /// Always 0 today — TrainerConsoleService computes the other three but never
  /// assigns this one. Don't surface an "Alerts" tile until it's populated;
  /// a permanent zero reads as "nothing is wrong", which isn't known.
  final int alertCount;

  const TrainerDashboardKpis({
    required this.activeClientCount,
    required this.avgAdherencePercent,
    required this.sessionsThisWeek,
    required this.alertCount,
  });

  factory TrainerDashboardKpis.fromJson(Map<String, dynamic> json) {
    return TrainerDashboardKpis(
      activeClientCount: json['activeClientCount'] as int? ?? 0,
      avgAdherencePercent:
          (json['avgAdherencePercent'] as num?)?.toDouble() ?? 0,
      sessionsThisWeek: json['sessionsThisWeek'] as int? ?? 0,
      alertCount: json['alertCount'] as int? ?? 0,
    );
  }
}

/// One Dashboard roster row — the relationship plus its training stats.
class TrainerRosterEntry {
  final String clientId;
  final String clientName;
  final String? programLabel;

  /// 0-100, or null when nothing was scheduled in the window. Null is "no
  /// data", which the UI must not render as 0%.
  final double? adherencePercent;
  final DateTime? lastSessionDate;

  const TrainerRosterEntry({
    required this.clientId,
    required this.clientName,
    this.programLabel,
    this.adherencePercent,
    this.lastSessionDate,
  });

  factory TrainerRosterEntry.fromJson(Map<String, dynamic> json) {
    final last = json['lastSessionDate'] as String?;
    return TrainerRosterEntry(
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String? ?? '',
      programLabel: json['programLabel'] as String?,
      adherencePercent: (json['adherencePercent'] as num?)?.toDouble(),
      lastSessionDate: last == null ? null : DateTime.parse(last),
    );
  }

  String get initials {
    final parts =
        clientName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class AttendanceWeek {
  final DateTime weekStart;
  final int plannedSessions;
  final int completedSessions;

  const AttendanceWeek({
    required this.weekStart,
    required this.plannedSessions,
    required this.completedSessions,
  });

  factory AttendanceWeek.fromJson(Map<String, dynamic> json) {
    return AttendanceWeek(
      weekStart: DateTime.parse(json['weekStart'] as String),
      plannedSessions: json['plannedSessions'] as int? ?? 0,
      completedSessions: json['completedSessions'] as int? ?? 0,
    );
  }

  /// 0.0-1.0, clamped: a client can log more sessions than were scheduled,
  /// which would otherwise overflow a progress bar.
  double get ratio => plannedSessions <= 0
      ? 0
      : (completedSessions / plannedSessions).clamp(0.0, 1.0);
}

class StrengthProgression {
  final String exerciseId;
  final String exerciseName;
  final double bestWeight;
  final double deltaFromPrevious;

  const StrengthProgression({
    required this.exerciseId,
    required this.exerciseName,
    required this.bestWeight,
    required this.deltaFromPrevious,
  });

  /// Note the wire field is `currentWeight` (StrengthProgressionDto); the Dart
  /// side has always called it bestWeight.
  factory StrengthProgression.fromJson(Map<String, dynamic> json) {
    return StrengthProgression(
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String? ?? '',
      bestWeight: (json['currentWeight'] as num?)?.toDouble() ?? 0,
      deltaFromPrevious: (json['deltaFromPrevious'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WorkoutPlanSummary {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime startDate;

  const WorkoutPlanSummary({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.startDate,
  });

  factory WorkoutPlanSummary.fromJson(Map<String, dynamic> json) {
    return WorkoutPlanSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      startDate: DateTime.parse(json['startDate'] as String),
    );
  }
}

class ClientWorkoutSummary {
  final WorkoutPlanSummary? currentPlan;
  final List<AttendanceWeek> attendance;
  final List<StrengthProgression> strengthProgression;

  const ClientWorkoutSummary({
    this.currentPlan,
    required this.attendance,
    required this.strengthProgression,
  });

  factory ClientWorkoutSummary.fromJson(Map<String, dynamic> json) {
    final plan = json['currentPlan'] as Map<String, dynamic>?;
    return ClientWorkoutSummary(
      currentPlan: plan == null ? null : WorkoutPlanSummary.fromJson(plan),
      attendance: ((json['attendance'] as List?) ?? const [])
          .map((a) => AttendanceWeek.fromJson(a as Map<String, dynamic>))
          .toList(),
      strengthProgression: ((json['strengthProgression'] as List?) ?? const [])
          .map((s) => StrengthProgression.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ClientWorkoutHistory {
  final DateTime date;
  // TODO: shape of the logged scheduled workout (exercises/sets/reps/weight/rpe)
  // — mirrors ScheduledWorkoutResponseDto once that's needed here.

  const ClientWorkoutHistory({required this.date});

  factory ClientWorkoutHistory.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError();
  }
}

class DailyCalorieTotal {
  final DateTime date;
  final int totalCalories;
  final int goal;

  const DailyCalorieTotal({
    required this.date,
    required this.totalCalories,
    required this.goal,
  });

  factory DailyCalorieTotal.fromJson(Map<String, dynamic> json) {
    return DailyCalorieTotal(
      date: DateTime.parse(json['date'] as String),
      totalCalories: json['totalCalories'] as int? ?? 0,
      goal: json['goal'] as int? ?? 0,
    );
  }

  bool get isOverBudget => goal > 0 && totalCalories > goal;
}

/// Protein/carbs/fat in grams.
class MacroTotals {
  final int protein;
  final int carbs;
  final int fat;

  const MacroTotals({this.protein = 0, this.carbs = 0, this.fat = 0});

  factory MacroTotals.fromJson(Map<String, dynamic> json) {
    return MacroTotals(
      protein: json['protein'] as int? ?? 0,
      carbs: json['carbs'] as int? ?? 0,
      fat: json['fat'] as int? ?? 0,
    );
  }

  int get totalGrams => protein + carbs + fat;
}

/// One food inside a logged meal, with its own nutrition — the meal detail
/// view's row. Resolved server-side against the client's food catalogue,
/// which the trainer has no route to.
class LoggedFood {
  final String foodItemId;
  final String name;

  /// Serving size in grams. 0 when the client's food item never recorded one,
  /// in which case the detail row leaves the weight out rather than showing
  /// "0 g".
  final int grams;
  final int calories;
  final MacroTotals macros;

  const LoggedFood({
    required this.foodItemId,
    required this.name,
    this.grams = 0,
    this.calories = 0,
    this.macros = const MacroTotals(),
  });

  factory LoggedFood.fromJson(Map<String, dynamic> json) {
    final macros = json['macros'] as Map<String, dynamic>?;
    return LoggedFood(
      foodItemId: json['foodItemId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      grams: json['grams'] as int? ?? 0,
      calories: json['calories'] as int? ?? 0,
      macros: macros == null ? const MacroTotals() : MacroTotals.fromJson(macros),
    );
  }
}

/// One meal the client logged, already totalled server-side.
class LoggedMeal {
  final String mealId;
  final String category;
  final List<String> foodNames;

  /// The same foods as [foodNames], each carrying its own nutrition, in the
  /// order they were logged. Empty against an API build that predates the
  /// meal detail view — the meal row is then simply not tappable.
  final List<LoggedFood> foods;
  final int calories;
  final MacroTotals macros;

  const LoggedMeal({
    required this.mealId,
    required this.category,
    required this.foodNames,
    required this.calories,
    required this.macros,
    this.foods = const [],
  });

  factory LoggedMeal.fromJson(Map<String, dynamic> json) {
    final macros = json['macros'] as Map<String, dynamic>?;
    return LoggedMeal(
      mealId: json['mealId'] as String,
      category: json['category'] as String? ?? '',
      foodNames: ((json['foodNames'] as List?) ?? const []).cast<String>(),
      foods: ((json['foods'] as List?) ?? const [])
          .map((f) => LoggedFood.fromJson(f as Map<String, dynamic>))
          .toList(),
      calories: json['calories'] as int? ?? 0,
      macros: macros == null ? const MacroTotals() : MacroTotals.fromJson(macros),
    );
  }
}

class ClientNutritionSummary {
  final DateTime date;
  final int calorieGoal;
  final int totalCalories;
  final MacroTotals macros;
  final List<LoggedMeal> loggedMeals;

  /// Oldest-first, so it renders left-to-right as a bar chart.
  final List<DailyCalorieTotal> sevenDayTrend;

  const ClientNutritionSummary({
    required this.date,
    required this.calorieGoal,
    required this.totalCalories,
    required this.macros,
    required this.loggedMeals,
    required this.sevenDayTrend,
  });

  factory ClientNutritionSummary.fromJson(Map<String, dynamic> json) {
    final macros = json['macros'] as Map<String, dynamic>?;
    return ClientNutritionSummary(
      date: DateTime.parse(json['date'] as String),
      calorieGoal: json['calorieGoal'] as int? ?? 0,
      totalCalories: json['totalCalories'] as int? ?? 0,
      macros: macros == null ? const MacroTotals() : MacroTotals.fromJson(macros),
      loggedMeals: ((json['loggedMeals'] as List?) ?? const [])
          .map((m) => LoggedMeal.fromJson(m as Map<String, dynamic>))
          .toList(),
      sevenDayTrend: ((json['sevenDayTrend'] as List?) ?? const [])
          .map((d) => DailyCalorieTotal.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Negative when over budget — the ring shows "over by" instead of
  /// "remaining" in that case.
  int get remaining => calorieGoal - totalCalories;
}

class ClientWeightEntry {
  final DateTime date;
  final double weight;
  final String? note;

  const ClientWeightEntry({
    required this.date,
    required this.weight,
    this.note,
  });

  factory ClientWeightEntry.fromJson(Map<String, dynamic> json) {
    return ClientWeightEntry(
      date: DateTime.parse(json['date'] as String),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Session Review
// ---------------------------------------------------------------------------
// Maps to `ScheduledWorkoutResponseDto` / `ScheduledWorkoutExerciseResponseDto`
// / `WorkoutSetResponseDto` (FitTracker.Api/DTOs) — the trainer-facing "what
// did this client actually log" view reuses the same shape the trainee app
// already writes to, it's not a new backend concept. See design handoff
// README section 6 ("Session Review") for the screen spec this backs.
//
// Backed by `GET api/TrainerConsole/{clientId}/session-history?count=`
// (TrainerConsoleService.GetClientSessionHistoryAsync), which returns
// `List<ClientSessionSummaryDto>` newest-first. Each entry carries both the
// history-row fields AND its full exercise/set detail, so selecting a row in
// the UI needs no second request — load once, select locally.
//
// The endpoint derives server-side (don't recompute these client-side):
//   - status (done/partial/missed) — skipped or nothing-logged is missed,
//     completed is done, sets-logged-but-not-completed is partial.
//   - totalVolume — sum(reps × weight) over completed sets. Note the schema
//     doesn't normalise weight units, so mixed-unit sessions sum naively.
//   - avgRpe — mean RPE over completed sets that recorded one.
//   - isPr — a set beat the client's best-ever weight on that exercise,
//     counting only strictly-earlier sessions. Computed over the client's
//     whole history, so it stays correct even though the list is truncated.
//   - hitTarget per set — reps vs. that set's own target (a 12/10/8 pyramid
//     compares each set to its own target, not all to the first).
//
// Two things the design mock shows that the schema genuinely can't back yet —
// both need new columns, not a computation:
//   - duration: ScheduledWorkout has no start/end timestamps.
//     (WorkoutResponseDto.EstimatedDurationMinutes is the template's estimate,
//     not what the client actually spent — deliberately not surfaced.)
//   - prescribed weight ("@ 82.5 kg"): WorkoutSetTemplate only has TargetReps.
// Until those exist, the UI should omit those fields rather than fake them.

/// Mirrors `SessionStatusDto` — serialised by index, matching the
/// MediaType/`ChatMessage.fromJson` convention already used in this feature.
enum SessionStatus { done, partial, missed }

class SessionSetLog {
  final int setNumber;
  final int? reps;
  final double? weight;
  final String? weightUnit;
  final int? rpe;

  /// Reps met the low end of *this* set's own target. True when there was no
  /// parseable target, so an unprogrammed exercise doesn't render as a miss.
  final bool hitTarget;

  const SessionSetLog({
    required this.setNumber,
    this.reps,
    this.weight,
    this.weightUnit,
    this.rpe,
    required this.hitTarget,
  });

  factory SessionSetLog.fromJson(Map<String, dynamic> json) {
    return SessionSetLog(
      setNumber: json['setNumber'] as int,
      reps: json['reps'] as int?,
      // Whole numbers can arrive as int from System.Text.Json, so go via num.
      weight: (json['weight'] as num?)?.toDouble(),
      weightUnit: json['weightUnit'] as String?,
      rpe: json['rpe'] as int?,
      hitTarget: json['hitTarget'] as bool? ?? true,
    );
  }
}

/// What was programmed for one exercise. Structured rather than a formatted
/// string because the app is localised — build the "3 × 8" display string
/// client-side (collapse [targetRepsPerSet] when every entry is equal).
class PrescribedSets {
  final int setCount;
  final List<String> targetRepsPerSet;

  const PrescribedSets({required this.setCount, required this.targetRepsPerSet});

  factory PrescribedSets.fromJson(Map<String, dynamic> json) {
    return PrescribedSets(
      setCount: json['setCount'] as int? ?? 0,
      targetRepsPerSet:
          (json['targetRepsPerSet'] as List?)?.cast<String>() ?? const [],
    );
  }

  /// "3 × 8" when every set shares a target, "12/10/8" when they differ, and
  /// null when there's nothing to show. Formatting lives here rather than
  /// server-side so it stays localisable.
  String? get summary {
    if (targetRepsPerSet.isEmpty) return null;
    final first = targetRepsPerSet.first;
    final uniform = targetRepsPerSet.every((t) => t == first);
    return uniform
        ? '${targetRepsPerSet.length} × $first'
        : targetRepsPerSet.join('/');
  }
}

class SessionExerciseLog {
  final String workoutExerciseId;
  final String exerciseName;

  /// Null when the logged exercise has no matching template (e.g. a
  /// substituted exercise) — show the logged sets without a prescription.
  final PrescribedSets? prescribed;
  final bool skipped;
  final bool isPr;
  final List<SessionSetLog> sets;

  const SessionExerciseLog({
    required this.workoutExerciseId,
    required this.exerciseName,
    this.prescribed,
    required this.skipped,
    required this.isPr,
    required this.sets,
  });

  factory SessionExerciseLog.fromJson(Map<String, dynamic> json) {
    final prescribed = json['prescribed'] as Map<String, dynamic>?;
    return SessionExerciseLog(
      workoutExerciseId: json['workoutExerciseId'] as String,
      exerciseName: json['exerciseName'] as String? ?? '',
      prescribed: prescribed == null ? null : PrescribedSets.fromJson(prescribed),
      skipped: json['skipped'] as bool? ?? false,
      isPr: json['isPr'] as bool? ?? false,
      sets: ((json['sets'] as List?) ?? const [])
          .map((s) => SessionSetLog.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One logged session — serves as both the history-list row (left column /
/// mobile day tabs) and its detail (right column / mobile detail card). The
/// endpoint returns both in one payload, so selecting a row is local state,
/// not another request.
class ClientSessionSummary {
  final String scheduledWorkoutId;
  final DateTime date;
  final String workoutName;
  final SessionStatus status;
  final bool isPr;
  final double totalVolume;
  final double? avgRpe;
  final String? clientNote;
  final List<SessionExerciseLog> exercises;

  const ClientSessionSummary({
    required this.scheduledWorkoutId,
    required this.date,
    required this.workoutName,
    required this.status,
    required this.isPr,
    required this.totalVolume,
    this.avgRpe,
    this.clientNote,
    required this.exercises,
  });

  factory ClientSessionSummary.fromJson(Map<String, dynamic> json) {
    final statusIndex = json['status'] as int? ?? 0;
    return ClientSessionSummary(
      scheduledWorkoutId: json['scheduledWorkoutId'] as String,
      date: DateTime.parse(json['date'] as String),
      workoutName: json['workoutName'] as String? ?? '',
      // Guard the index: a server-side enum addition shouldn't crash an older
      // client, it should degrade to "partial".
      status: statusIndex >= 0 && statusIndex < SessionStatus.values.length
          ? SessionStatus.values[statusIndex]
          : SessionStatus.partial,
      isPr: json['isPr'] as bool? ?? false,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0,
      avgRpe: (json['avgRpe'] as num?)?.toDouble(),
      clientNote: json['clientNote'] as String?,
      exercises: ((json['exercises'] as List?) ?? const [])
          .map((e) => SessionExerciseLog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// A session with nothing logged — drives the "No workout logged" empty
  /// state rather than being treated as an error.
  bool get isEmpty => exercises.every((e) => e.sets.isEmpty);
}

class WorkoutPlanTemplateSummary {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int daysPerWeek;

  const WorkoutPlanTemplateSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.daysPerWeek,
  });

  factory WorkoutPlanTemplateSummary.fromJson(Map<String, dynamic> json) {
    return WorkoutPlanTemplateSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      daysPerWeek: json['daysPerWeek'] as int? ?? 0,
    );
  }
}
