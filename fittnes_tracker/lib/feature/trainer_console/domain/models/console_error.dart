import 'package:ForgeForm/l10n/app_localizations.dart';

/// A failure the console needs to explain to a trainer.
///
/// Providers report the *case*, not the sentence: a [ChangeNotifier] has no
/// [BuildContext] and so no locale, and a String assembled at load time is
/// frozen in whatever language happened to be active. The screen turns this
/// into text at build time, where the locale is known.
enum ConsoleError {
  loadRoster,
  loadDashboard,
  loadClientDetail,
  loadNutrition,
  loadSessions,
  loadLicence,
  loadWorkoutPlans,
  planNameRequired,
  createPlan,
  workoutNameRequired,
  loadClientWorkouts,
  loadExerciseLibrary,
  exerciseNameRequired,
  createExercise,
  saveWorkout,
  deleteWorkout,
  workoutHasHistory,
  unknownExercise,
  scheduleWorkoutPlan,
  deletePlan,
  createInvite,
  withdrawInvite,
  openCheckout,
  openBilling,
  saveNutrientPins,
}

extension ConsoleErrorMessage on ConsoleError {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    ConsoleError.loadRoster => l10n.errorLoadRoster,
    ConsoleError.loadDashboard => l10n.errorLoadDashboard,
    ConsoleError.loadClientDetail => l10n.errorLoadClientDetail,
    ConsoleError.loadNutrition => l10n.errorLoadNutrition,
    ConsoleError.loadSessions => l10n.errorLoadSessions,
    ConsoleError.loadLicence => l10n.errorLoadLicence,
    ConsoleError.loadWorkoutPlans => l10n.errorLoadWorkoutPlans,
    ConsoleError.planNameRequired => l10n.errorPlanNameRequired,
    ConsoleError.createPlan => l10n.errorCreatePlan,
    ConsoleError.workoutNameRequired => l10n.errorWorkoutNameRequired,
    ConsoleError.loadClientWorkouts => l10n.errorLoadClientWorkouts,
    ConsoleError.loadExerciseLibrary => l10n.errorLoadExerciseLibrary,
    ConsoleError.exerciseNameRequired => l10n.errorExerciseNameRequired,
    ConsoleError.createExercise => l10n.errorCreateExercise,
    ConsoleError.saveWorkout => l10n.errorSaveWorkout,
    ConsoleError.deleteWorkout => l10n.errorDeleteWorkout,
    ConsoleError.workoutHasHistory => l10n.errorWorkoutHasHistory,
    ConsoleError.unknownExercise => l10n.errorUnknownExercise,
    ConsoleError.scheduleWorkoutPlan => l10n.errorScheduleWorkoutPlan,
    ConsoleError.deletePlan => l10n.errorDeletePlan,
    ConsoleError.createInvite => l10n.errorCreateInvite,
    ConsoleError.withdrawInvite => l10n.errorWithdrawInvite,
    ConsoleError.openCheckout => l10n.errorOpenCheckout,
    ConsoleError.openBilling => l10n.errorOpenBilling,
    ConsoleError.saveNutrientPins => l10n.errorSaveNutrientPins,
  };
}
