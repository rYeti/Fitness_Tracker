// Domain models for the new TrainerConsoleController/WorkoutPlanTemplateController
// endpoints. Field shapes mirror the backend DTOs (see TrainerConsoleDtos.cs);
// fromJson bodies are left as stubs since the backend endpoints themselves
// are still NotImplementedException stubs.

class TrainerDashboardKpis {
  final int activeClientCount;
  final double avgAdherencePercent;
  final int sessionsThisWeek;
  final int alertCount;

  const TrainerDashboardKpis({
    required this.activeClientCount,
    required this.avgAdherencePercent,
    required this.sessionsThisWeek,
    required this.alertCount,
  });

  factory TrainerDashboardKpis.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError();
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
}

class ClientWorkoutSummary {
  final List<AttendanceWeek> attendance;
  final List<StrengthProgression> strengthProgression;

  const ClientWorkoutSummary({
    required this.attendance,
    required this.strengthProgression,
  });

  factory ClientWorkoutSummary.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError();
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
}

class ClientNutritionSummary {
  final DateTime date;
  final int calorieGoal;
  final List<DailyCalorieTotal> sevenDayTrend;
  // TODO: today's meals list (breakfast/lunch/snack/dinner + kcal) — mirrors
  // MealResponseDto once that's needed here.

  const ClientNutritionSummary({
    required this.date,
    required this.calorieGoal,
    required this.sevenDayTrend,
  });

  factory ClientNutritionSummary.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError();
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
    throw UnimplementedError();
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
    throw UnimplementedError();
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
    throw UnimplementedError();
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
    throw UnimplementedError();
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
    throw UnimplementedError();
  }
}
