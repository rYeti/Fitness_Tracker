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
