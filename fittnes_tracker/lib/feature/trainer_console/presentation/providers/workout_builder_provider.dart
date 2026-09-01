import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';

/// One prescribed set as the editor holds it — just enough to render a row
/// and re-serialize it. Reps are edited free-text ("8-12", "10", …).
class ExerciseSetDraft {
  String targetReps;
  ExerciseSetDraft(this.targetReps);
}

/// One exercise entry as the editor holds it.
class WorkoutExerciseDraft {
  /// The existing `WorkoutExercise` id, or null for one just added in this
  /// session. Carried through untouched on save so the server can tell a
  /// kept entry from a new or swapped one — see
  /// `docs/trainer-workout-builder.md`.
  final String? id;
  final String exerciseId;
  final String exerciseName;
  String? notes;
  final List<ExerciseSetDraft> sets;

  WorkoutExerciseDraft({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.notes,
    required this.sets,
  });

  factory WorkoutExerciseDraft.fromExisting(ClientWorkoutExercise e) {
    return WorkoutExerciseDraft(
      id: e.id,
      exerciseId: e.exerciseId,
      exerciseName: e.exerciseName,
      notes: e.notes,
      sets: e.sets.map((s) => ExerciseSetDraft(s.targetReps)).toList(),
    );
  }

  factory WorkoutExerciseDraft.fromOption(ClientExerciseOption option) {
    return WorkoutExerciseDraft(
      exerciseId: option.id,
      exerciseName: option.name,
      sets: [ExerciseSetDraft('10')],
    );
  }
}

/// The editable form of one of a client's workouts — a "day" in the Workout
/// Builder. `workoutId == null` means this is a day being created; otherwise
/// it's the id of the day being edited.
class WorkoutDraft {
  final String? workoutId;
  String name;
  String? description;
  int difficulty;
  int estimatedDurationMinutes;
  final List<WorkoutExerciseDraft> exercises;

  WorkoutDraft({
    this.workoutId,
    required this.name,
    this.description,
    required this.difficulty,
    required this.estimatedDurationMinutes,
    required this.exercises,
  });

  factory WorkoutDraft.blank() => WorkoutDraft(
    name: '',
    difficulty: 1,
    estimatedDurationMinutes: 60,
    exercises: [],
  );

  factory WorkoutDraft.fromExisting(ClientWorkout w) => WorkoutDraft(
    workoutId: w.id,
    name: w.name,
    description: w.description,
    difficulty: w.difficulty,
    estimatedDurationMinutes: w.estimatedDurationMinutes,
    exercises: w.exercises.map(WorkoutExerciseDraft.fromExisting).toList(),
  );

  bool get isNew => workoutId == null;
}

/// Drives the Workout Builder's create/edit state machine.
///
/// Two layers of state: the plan-level create/assign flow that already
/// existed (`isNew`/`currentPlan`/`createPlan`, unchanged), and — once a plan
/// exists — the list of the plan's days and an editable draft of whichever
/// one is selected. A day's exercises and sets live only in [draft] until
/// [saveDraft] is called; nothing is sent to the server mid-edit, so
/// switching away or discarding costs nothing.
class WorkoutBuilderProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  WorkoutBuilderProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  bool _isNew = false;
  List<WorkoutPlanTemplateSummary> _templates = [];
  WorkoutPlanSummary? _currentPlan;
  bool _isLoading = false;
  bool _isSaving = false;
  ConsoleError? _error;
  String? _loadedClientId;

  bool get isNew => _isNew;
  List<WorkoutPlanTemplateSummary> get templates => _templates;
  WorkoutPlanSummary? get currentPlan => _currentPlan;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  ConsoleError? get error => _error;
  String? get loadedClientId => _loadedClientId;

  // ── Days (workouts) under the current plan ──────────────────────────────

  List<ClientWorkout> _allWorkouts = [];
  List<ClientExerciseOption> _exerciseLibrary = [];
  bool _isLoadingDays = false;
  ConsoleError? _daysError;

  String? _selectedWorkoutId; // null while editing a brand-new day
  WorkoutDraft? _draft;
  WorkoutDraft? _savedSnapshot; // what `_draft` looked like right after load/save
  bool _isSavingDay = false;
  bool _isDeletingDay = false;
  ConsoleError? _dayError;

  /// The current plan's days, in no particular server-guaranteed order —
  /// newest-created last, which is how the screen lists them.
  List<ClientWorkout> get planWorkouts {
    final planId = _currentPlan?.id;
    if (planId == null) return const [];
    return _allWorkouts.where((w) => w.planIds.contains(planId)).toList();
  }

  List<ClientExerciseOption> get exerciseLibrary => _exerciseLibrary;
  bool get isLoadingDays => _isLoadingDays;
  ConsoleError? get daysError => _daysError;
  String? get selectedWorkoutId => _selectedWorkoutId;
  WorkoutDraft? get draft => _draft;
  bool get isSavingDay => _isSavingDay;
  bool get isDeletingDay => _isDeletingDay;
  ConsoleError? get dayError => _dayError;

  bool get isDraftDirty {
    final draft = _draft;
    final snapshot = _savedSnapshot;
    if (draft == null) return false;
    if (snapshot == null) return true; // a new, never-saved day
    return !_draftsEqual(draft, snapshot);
  }

  /// Loads the templates for the create flow plus the client's active plan for
  /// the read-only view.
  Future<void> load(String clientId) async {
    _isLoading = true;
    _error = null;
    _currentPlan = null;
    _loadedClientId = clientId;
    _resetDayState();
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getWorkoutPlanTemplates(),
        _repository.getClientWorkoutSummary(clientId),
      ]);
      if (_loadedClientId != clientId) return;
      _templates = results[0] as List<WorkoutPlanTemplateSummary>;
      _currentPlan = (results[1] as ClientWorkoutSummary).currentPlan;
      // A client with no plan lands straight in the create flow — there's
      // nothing to show them otherwise.
      _isNew = _currentPlan == null;
    } catch (_) {
      if (_loadedClientId != clientId) return;
      _error = ConsoleError.loadWorkoutPlans;
    } finally {
      if (_loadedClientId == clientId) {
        _isLoading = false;
        notifyListeners();
      }
    }

    if (_currentPlan != null) {
      await loadDays(clientId);
    }
  }

  /// Loads the client's workouts and exercise library — everything the day
  /// editor needs. Called once a plan exists to show its days against.
  Future<void> loadDays(String clientId) async {
    _isLoadingDays = true;
    _daysError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getClientWorkouts(clientId),
        _repository.getClientExerciseLibrary(clientId),
      ]);
      if (_loadedClientId != clientId) return;
      _allWorkouts = results[0] as List<ClientWorkout>;
      _exerciseLibrary = results[1] as List<ClientExerciseOption>;
      // Land on the first existing day rather than an empty editor — "no day
      // selected" and "no days yet" are different states, and only the second
      // one is actually empty.
      if (_draft == null && planWorkouts.isNotEmpty) {
        selectDay(planWorkouts.first);
      }
    } catch (_) {
      if (_loadedClientId != clientId) return;
      _daysError = ConsoleError.loadClientWorkouts;
    } finally {
      if (_loadedClientId == clientId) {
        _isLoadingDays = false;
        notifyListeners();
      }
    }
  }

  void _resetDayState() {
    _allWorkouts = [];
    _exerciseLibrary = [];
    _selectedWorkoutId = null;
    _draft = null;
    _savedSnapshot = null;
    _dayError = null;
  }

  // ── Selecting / starting a day ───────────────────────────────────────────

  /// Selects an existing day for editing, or starts a new one when [workout]
  /// is null. Callers must confirm with the trainer first when
  /// [isDraftDirty] is true — this always discards whatever draft exists.
  void selectDay(ClientWorkout? workout) {
    _dayError = null;
    if (workout == null) {
      _selectedWorkoutId = null;
      _draft = WorkoutDraft.blank();
      _savedSnapshot = null;
    } else {
      _selectedWorkoutId = workout.id;
      _draft = WorkoutDraft.fromExisting(workout);
      _savedSnapshot = WorkoutDraft.fromExisting(workout);
    }
    notifyListeners();
  }

  void closeDayEditor() {
    _selectedWorkoutId = null;
    _draft = null;
    _savedSnapshot = null;
    notifyListeners();
  }

  // ── Editing the draft ────────────────────────────────────────────────────

  void updateDayName(String name) {
    _draft?.name = name;
    notifyListeners();
  }

  void updateDayDescription(String? description) {
    _draft?.description = description;
    notifyListeners();
  }

  void updateDayDifficulty(int difficulty) {
    _draft?.difficulty = difficulty;
    notifyListeners();
  }

  void updateDayDuration(int minutes) {
    _draft?.estimatedDurationMinutes = minutes;
    notifyListeners();
  }

  void addExercise(ClientExerciseOption option) {
    _draft?.exercises.add(WorkoutExerciseDraft.fromOption(option));
    notifyListeners();
  }

  void removeExercise(int index) {
    final exercises = _draft?.exercises;
    if (exercises == null || index < 0 || index >= exercises.length) return;
    exercises.removeAt(index);
    notifyListeners();
  }

  void moveExercise(int oldIndex, int newIndex) {
    final exercises = _draft?.exercises;
    if (exercises == null) return;
    if (newIndex < 0 || newIndex >= exercises.length) return;
    final item = exercises.removeAt(oldIndex);
    exercises.insert(newIndex, item);
    notifyListeners();
  }

  void updateExerciseNote(int index, String? note) {
    final exercises = _draft?.exercises;
    if (exercises == null || index < 0 || index >= exercises.length) return;
    exercises[index].notes = note;
    notifyListeners();
  }

  void addSet(int exerciseIndex) {
    final exercises = _draft?.exercises;
    if (exercises == null || exerciseIndex < 0 || exerciseIndex >= exercises.length) {
      return;
    }
    exercises[exerciseIndex].sets.add(ExerciseSetDraft('10'));
    notifyListeners();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    final exercises = _draft?.exercises;
    if (exercises == null || exerciseIndex < 0 || exerciseIndex >= exercises.length) {
      return;
    }
    final sets = exercises[exerciseIndex].sets;
    if (setIndex < 0 || setIndex >= sets.length) return;
    sets.removeAt(setIndex);
    notifyListeners();
  }

  void updateSetReps(int exerciseIndex, int setIndex, String reps) {
    final exercises = _draft?.exercises;
    if (exercises == null || exerciseIndex < 0 || exerciseIndex >= exercises.length) {
      return;
    }
    final sets = exercises[exerciseIndex].sets;
    if (setIndex < 0 || setIndex >= sets.length) return;
    sets[setIndex].targetReps = reps;
    notifyListeners();
  }

  // ── Saving / deleting a day ──────────────────────────────────────────────

  /// Saves [draft] — creating it under the current plan if it's new,
  /// otherwise rewriting the existing day. Returns true on success.
  Future<bool> saveDraft(String clientId) async {
    final draft = _draft;
    final planId = _currentPlan?.id;
    if (draft == null) return false;
    if (draft.name.trim().isEmpty) {
      _dayError = ConsoleError.workoutNameRequired;
      notifyListeners();
      return false;
    }

    _isSavingDay = true;
    _dayError = null;
    notifyListeners();

    try {
      final exercises = draft.exercises
          .map(
            (e) => ClientWorkoutExerciseDraft(
              id: e.id,
              exerciseId: e.exerciseId,
              notes: e.notes?.trim().isEmpty == true ? null : e.notes?.trim(),
              targetReps: [
                for (final s in e.sets)
                  if (s.targetReps.trim().isNotEmpty) s.targetReps.trim(),
              ],
            ),
          )
          .toList();

      final ClientWorkout saved;
      if (draft.isNew) {
        saved = await _repository.createClientWorkout(
          clientId,
          name: draft.name.trim(),
          description: _trimmedOrNull(draft.description),
          difficulty: draft.difficulty,
          estimatedDurationMinutes: draft.estimatedDurationMinutes,
          planId: planId,
          exercises: exercises,
        );
      } else {
        saved = await _repository.updateClientWorkout(
          clientId,
          draft.workoutId!,
          name: draft.name.trim(),
          description: _trimmedOrNull(draft.description),
          difficulty: draft.difficulty,
          estimatedDurationMinutes: draft.estimatedDurationMinutes,
          exercises: exercises,
        );
      }

      _allWorkouts = [
        for (final w in _allWorkouts)
          if (w.id != saved.id) w,
        saved,
      ];
      _selectedWorkoutId = saved.id;
      _draft = WorkoutDraft.fromExisting(saved);
      _savedSnapshot = WorkoutDraft.fromExisting(saved);
      return true;
    } on WorkoutSaveException catch (e) {
      _dayError = switch (e.failure) {
        WorkoutSaveFailure.hasLoggedHistory => ConsoleError.workoutHasHistory,
        WorkoutSaveFailure.unknownExercise => ConsoleError.unknownExercise,
        WorkoutSaveFailure.other => ConsoleError.saveWorkout,
      };
      return false;
    } catch (_) {
      _dayError = ConsoleError.saveWorkout;
      return false;
    } finally {
      _isSavingDay = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCurrentDay(String clientId) async {
    final workoutId = _selectedWorkoutId;
    if (workoutId == null) return false;

    _isDeletingDay = true;
    _dayError = null;
    notifyListeners();

    try {
      await _repository.deleteClientWorkout(clientId, workoutId);
      _allWorkouts = [
        for (final w in _allWorkouts)
          if (w.id != workoutId) w,
      ];
      closeDayEditor();
      return true;
    } on WorkoutSaveException catch (e) {
      _dayError = e.failure == WorkoutSaveFailure.hasLoggedHistory
          ? ConsoleError.workoutHasHistory
          : ConsoleError.deleteWorkout;
      return false;
    } catch (_) {
      _dayError = ConsoleError.deleteWorkout;
      return false;
    } finally {
      _isDeletingDay = false;
      notifyListeners();
    }
  }

  // ── Creating a new exercise for the trainer's own library ───────────────

  bool _isCreatingExercise = false;
  bool get isCreatingExercise => _isCreatingExercise;

  Future<ClientExerciseOption?> createExercise(
    String clientId, {
    required String name,
    String? description,
  }) async {
    if (name.trim().isEmpty) {
      _dayError = ConsoleError.exerciseNameRequired;
      notifyListeners();
      return null;
    }

    _isCreatingExercise = true;
    _dayError = null;
    notifyListeners();

    try {
      final created = await _repository.createTrainerExercise(
        clientId,
        name: name.trim(),
        description: _trimmedOrNull(description),
      );
      _exerciseLibrary = [created, ..._exerciseLibrary];
      return created;
    } catch (_) {
      _dayError = ConsoleError.createExercise;
      return null;
    } finally {
      _isCreatingExercise = false;
      notifyListeners();
    }
  }

  // ── Plan create/assign flow (unchanged) ──────────────────────────────────

  void startNewPlan() {
    if (_isNew) return;
    _isNew = true;
    notifyListeners();
  }

  void cancelNewPlan() {
    // Nothing to go back to if they have no plan.
    if (!_isNew || _currentPlan == null) return;
    _isNew = false;
    notifyListeners();
  }

  /// Creates and assigns a plan. Returns true on success so the screen can
  /// confirm; the error is exposed via [error] on failure.
  Future<bool> createPlan({
    required String clientId,
    required String name,
    String? description,
  }) async {
    if (name.trim().isEmpty) {
      _error = ConsoleError.planNameRequired;
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final plan = await _repository.createClientWorkoutPlan(
        clientId: clientId,
        name: name.trim(),
        description: description?.trim(),
      );
      _currentPlan = plan;
      _isNew = false;
      unawaited(loadDays(clientId));
      return true;
    } catch (_) {
      _error = ConsoleError.createPlan;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  bool _draftsEqual(WorkoutDraft a, WorkoutDraft b) {
    if (a.name != b.name) return false;
    if ((a.description ?? '') != (b.description ?? '')) return false;
    if (a.difficulty != b.difficulty) return false;
    if (a.estimatedDurationMinutes != b.estimatedDurationMinutes) return false;
    if (a.exercises.length != b.exercises.length) return false;
    for (var i = 0; i < a.exercises.length; i++) {
      final ea = a.exercises[i];
      final eb = b.exercises[i];
      if (ea.exerciseId != eb.exerciseId) return false;
      if ((ea.notes ?? '') != (eb.notes ?? '')) return false;
      if (ea.sets.length != eb.sets.length) return false;
      for (var j = 0; j < ea.sets.length; j++) {
        if (ea.sets[j].targetReps != eb.sets[j].targetReps) return false;
      }
    }
    return true;
  }
}
