import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/pane_reads.dart';

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

  /// Every read and write the builder makes of the client's plan and days.
  /// A refresh a write overlapped is read again once the write settles.
  late final PaneReads _reads = PaneReads(
    onRefreshOwed: () {
      final clientId = _loadedClientId;
      if (clientId != null) unawaited(refresh(clientId));
    },
  );

  bool _isNew = false;
  List<WorkoutPlanTemplateSummary> _templates = [];
  WorkoutPlanSummary? _currentPlan;
  bool _isLoading = false;
  bool _isSaving = false;
  ConsoleError? _error;
  String? _loadedClientId;
  bool _isDeletingPlan = false;
  ConsoleError? _planError;

  /// Whether the plan and the templates have come back for the loaded
  /// client — by a load, or by a refresh after a load that failed.
  bool _planLoaded = false;

  bool get isNew => _isNew;
  List<WorkoutPlanTemplateSummary> get templates => _templates;
  WorkoutPlanSummary? get currentPlan => _currentPlan;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  ConsoleError? get error => _error;
  String? get loadedClientId => _loadedClientId;
  bool get isDeletingPlan => _isDeletingPlan;
  ConsoleError? get planError => _planError;

  /// Whether the last refresh failed, so the plan and days shown are older
  /// than they could be.
  bool get refreshFailed => _reads.refreshFailed && _error == null;

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
  /// the read-only view, then the plan's days.
  ///
  /// [keepShown] is a refresh ([refresh]). One that arrives while a load or
  /// [loadDays] is still reading becomes a load itself and supersedes it
  /// ([PaneReads.start]): the read in flight may have been answered before the
  /// change was committed.
  ///
  /// Superseding a read is not the same as starting over, though. A refresh
  /// that overtakes a [loadDays] of the client on screen still reads in place
  /// ([_refreshInPlace]) and finishes that read's job, rather than running
  /// this method's body: that body clears the plan and the open day and
  /// shows the whole builder's skeleton, and [loadDays] had done neither. It
  /// used to run it, and so discarded a day with unsaved edits without
  /// asking — a trainer who created a plan with an edited day open, and whose
  /// refresh landed while the new plan's days were loading, lost the edits.
  /// Overtaking a load of the same client runs the body again, which clears
  /// nothing that load hadn't cleared already.
  Future<void> load(String clientId, {bool keepShown = false}) async {
    final sameClient = _loadedClientId == clientId;
    final read = _reads.start(keepShown: keepShown, shown: sameClient);
    if (read.keep || (keepShown && sameClient && !_isLoading)) {
      return _refreshInPlace(clientId, read);
    }

    _isLoading = true;
    _isLoadingDays = false;
    _error = null;
    _currentPlan = null;
    _planLoaded = false;
    _loadedClientId = clientId;
    _resetDayState();
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getWorkoutPlanTemplates(),
        _repository.getClientWorkoutSummary(clientId),
      ]);
      if (!read.settle()) return;
      _templates = results[0] as List<WorkoutPlanTemplateSummary>;
      _currentPlan = (results[1] as ClientWorkoutSummary).currentPlan;
      _planLoaded = true;
      // A client with no plan lands straight in the create flow — there's
      // nothing to show them otherwise.
      _isNew = _currentPlan == null;
    } catch (_) {
      if (!read.settle(failed: true)) return;
      _error = ConsoleError.loadWorkoutPlans;
    }
    _isLoading = false;
    notifyListeners();

    if (_currentPlan != null) {
      await loadDays(clientId);
    }
  }

  /// Loads the client's workouts and exercise library — everything the day
  /// editor needs. Called once a plan exists to show its days against.
  Future<void> loadDays(String clientId) async {
    final read = _reads.start();
    _isLoadingDays = true;
    _daysError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getClientWorkouts(clientId),
        _repository.getClientExerciseLibrary(clientId),
      ]);
      if (!read.settle()) return;
      _allWorkouts = results[0] as List<ClientWorkout>;
      _exerciseLibrary = results[1] as List<ClientExerciseOption>;
      // Land on the first existing day rather than an empty editor — "no day
      // selected" and "no days yet" are different states, and only the second
      // one is actually empty.
      if (_draft == null && planWorkouts.isNotEmpty) {
        _open(planWorkouts.first);
      }
    } catch (_) {
      if (!read.settle(failed: true)) return;
      _daysError = ConsoleError.loadClientWorkouts;
    }
    _isLoadingDays = false;
    notifyListeners();
  }

  // ── Refreshing in place ──────────────────────────────────────────────────

  /// Bumped when a [refresh] replaces the open day's draft with the server's
  /// copy. The editor builds its text fields from the draft once, when the day
  /// is opened; the screen keys the editor on this so they are built again
  /// from the new copy instead of still showing the old one.
  int _draftRevision = 0;
  int get draftRevision => _draftRevision;

  /// Re-reads the client's plan and days in place — the console heard that
  /// their workouts changed (`docs/sync-architecture.md`, part four).
  ///
  /// Nothing is taken off screen while it reads, and a read that fails
  /// changes nothing but [refreshFailed]. Reads are ordered like every
  /// console pane's ([PaneReads]): the latest one asked wins, and one that
  /// arrives during a load supersedes it. A refresh a save, delete or create
  /// overlapped is read again once that write settles, since its answer may
  /// be from before it.
  ///
  /// Where the plan itself changed, it lands where [load] would — the plan
  /// that now exists and its first day, or the create flow if there is none —
  /// with one exception, which is the rule for the whole refresh: the open day
  /// is the trainer's. A draft with unsaved edits is left exactly as it is
  /// while the rest of the pane updates around it; only a clean one takes the
  /// server's copy. It is the same rule the device's pull keeps for a row with
  /// an unsent change.
  Future<void> refresh(String clientId) => load(clientId, keepShown: true);

  /// [read] is a refresh, or a load that took over a [loadDays] still in
  /// flight, whose job — the days, and the loading state it raised — it then
  /// finishes.
  Future<void> _refreshInPlace(String clientId, PaneRead read) async {
    // A first load that failed never got the templates, and the create flow
    // a refresh may land in needs them. No change of the client's moves them
    // otherwise, so a builder that has them doesn't ask again.
    final withTemplates = !_planLoaded;
    final List<Object> results;
    try {
      results = await Future.wait<Object>([
        _repository.getClientWorkoutSummary(clientId),
        _repository.getClientWorkouts(clientId),
        _repository.getClientExerciseLibrary(clientId),
        if (withTemplates) _repository.getWorkoutPlanTemplates(),
      ]);
    } catch (_) {
      if (!read.settle(failed: true)) return;
      // A read that took over loadDays fails the way loadDays would have.
      if (read.isLoad) {
        _isLoadingDays = false;
        _daysError = ConsoleError.loadClientWorkouts;
      }
      notifyListeners();
      return;
    }
    if (!read.settle()) return;

    _takeRefresh(
      plan: (results[0] as ClientWorkoutSummary).currentPlan,
      workouts: results[1] as List<ClientWorkout>,
      library: results[2] as List<ClientExerciseOption>,
      templates: withTemplates
          ? results[3] as List<WorkoutPlanTemplateSummary>
          : null,
    );
    notifyListeners();
  }

  void _takeRefresh({
    required WorkoutPlanSummary? plan,
    required List<ClientWorkout> workouts,
    required List<ClientExerciseOption> library,
    required List<WorkoutPlanTemplateSummary>? templates,
  }) {
    final dirty = isDraftDirty;
    final previous = _currentPlan;
    // Days that never loaded — their read failed, or this one took it over
    // while it was still in flight — land where loadDays would have put them.
    final daysUnread = _daysError != null || _isLoadingDays;
    _isLoadingDays = false;
    // The plan was deleted elsewhere. Unsaved edits hold the pane where it is
    // until the trainer saves or discards them, rather than taking the plan
    // they belong to out from under them.
    if (plan == null && previous != null && dirty) return;

    if (templates != null) _templates = templates;
    // A refresh is also how a builder whose first load failed recovers.
    if (!_planLoaded) _error = null;
    _planLoaded = true;
    _currentPlan = plan;

    if (plan == null) {
      // No plan, or none any more: where load() lands a client with none.
      _isNew = true;
      _resetDayState();
      return;
    }

    // A plan that has appeared ends the create flow load() put a client with
    // no plan in. One the trainer opened themselves, over a plan, is theirs,
    // like a draft, and stays open.
    final trainerStartedCreate = _isNew && previous != null;
    if (!trainerStartedCreate) _isNew = false;
    _allWorkouts = workouts;
    _exerciseLibrary = library;
    _daysError = null;
    if (dirty) return;
    _openServerDay(landOnFirstDay: plan.id != previous?.id || daysUnread);
  }

  /// Gives a clean open day the server's copy, or — when it isn't in the
  /// plan any more — lands on the plan's first day where [load] would have
  /// ([landOnFirstDay]: the plan appeared or changed, or its days had never
  /// loaded), or closes the editor.
  ///
  /// Only when the copy differs: a refresh that follows the trainer's own
  /// save finds what they saved, and rebuilding the editor then would only
  /// take their cursor away.
  ///
  /// Measured against the plan's days, not every workout the client has. A
  /// new plan assigned elsewhere may not contain the day that was open, and
  /// keeping it open left the editor showing a day the list beside it didn't.
  void _openServerDay({required bool landOnFirstDay}) {
    final days = planWorkouts;
    final selectedId = _selectedWorkoutId;
    final fresh = selectedId == null
        ? null
        : days.where((w) => w.id == selectedId).firstOrNull;
    if (fresh != null) {
      final copy = WorkoutDraft.fromExisting(fresh);
      final snapshot = _savedSnapshot;
      if (snapshot != null && _draftsEqual(copy, snapshot)) return;
      _draft = copy;
      _savedSnapshot = WorkoutDraft.fromExisting(fresh);
      _draftRevision++;
      return;
    }
    if (landOnFirstDay && days.isNotEmpty) {
      _open(days.first);
    } else if (selectedId != null) {
      _selectedWorkoutId = null;
      _draft = null;
      _savedSnapshot = null;
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
    _open(workout);
    notifyListeners();
  }

  void _open(ClientWorkout? workout) {
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

    _dayError = null;
    return _write(
      clientId,
      busy: (busy) => _isSavingDay = busy,
      send: () => draft.isNew
          ? _repository.createClientWorkout(
              clientId,
              name: draft.name.trim(),
              description: _trimmedOrNull(draft.description),
              difficulty: draft.difficulty,
              estimatedDurationMinutes: draft.estimatedDurationMinutes,
              planId: planId,
              exercises: exercises,
            )
          : _repository.updateClientWorkout(
              clientId,
              draft.workoutId!,
              name: draft.name.trim(),
              description: _trimmedOrNull(draft.description),
              difficulty: draft.difficulty,
              estimatedDurationMinutes: draft.estimatedDurationMinutes,
              exercises: exercises,
            ),
      applied: (saved) {
        _allWorkouts = [
          for (final w in _allWorkouts)
            if (w.id != saved.id) w,
          saved,
        ];
        _selectedWorkoutId = saved.id;
        _draft = WorkoutDraft.fromExisting(saved);
        _savedSnapshot = WorkoutDraft.fromExisting(saved);
        return true;
      },
      failed: (error) {
        _dayError = error is WorkoutSaveException
            ? switch (error.failure) {
                WorkoutSaveFailure.hasLoggedHistory =>
                  ConsoleError.workoutHasHistory,
                WorkoutSaveFailure.unknownExercise =>
                  ConsoleError.unknownExercise,
                WorkoutSaveFailure.other => ConsoleError.saveWorkout,
              }
            : ConsoleError.saveWorkout;
        return false;
      },
      dropped: false,
    );
  }

  Future<bool> deleteCurrentDay(String clientId) async {
    final workoutId = _selectedWorkoutId;
    if (workoutId == null) return false;

    _dayError = null;
    return _write(
      clientId,
      busy: (busy) => _isDeletingDay = busy,
      send: () => _repository.deleteClientWorkout(clientId, workoutId),
      applied: (_) {
        _allWorkouts = [
          for (final w in _allWorkouts)
            if (w.id != workoutId) w,
        ];
        closeDayEditor();
        return true;
      },
      failed: (error) {
        _dayError = error is WorkoutSaveException &&
                error.failure == WorkoutSaveFailure.hasLoggedHistory
            ? ConsoleError.workoutHasHistory
            : ConsoleError.deleteWorkout;
        return false;
      },
      dropped: false,
    );
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

    _dayError = null;
    return _write<ClientExerciseOption, ClientExerciseOption?>(
      clientId,
      busy: (busy) => _isCreatingExercise = busy,
      send: () => _repository.createTrainerExercise(
        clientId,
        name: name.trim(),
        description: _trimmedOrNull(description),
      ),
      applied: (created) {
        _exerciseLibrary = [created, ..._exerciseLibrary];
        return created;
      },
      failed: (_) {
        _dayError = ConsoleError.createExercise;
        return null;
      },
      dropped: null,
    );
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

    _error = null;
    final created = await _write(
      clientId,
      busy: (busy) => _isSaving = busy,
      send: () => _repository.createClientWorkoutPlan(
        clientId: clientId,
        name: name.trim(),
        description: description?.trim(),
      ),
      applied: (plan) {
        _currentPlan = plan;
        _isNew = false;
        return true;
      },
      failed: (_) {
        _error = ConsoleError.createPlan;
        return false;
      },
      dropped: false,
    );
    // After the write has settled, not inside it: a refresh it owes runs as
    // it settles, and the days read, started after, is the one that wins.
    if (created) unawaited(loadDays(clientId));
    return created;
  }

  /// Deletes the current plan. The plan's days stay with the client — only the
  /// grouping goes away, so this lands the screen back where a client with no
  /// plan starts: the create flow.
  Future<bool> deletePlan(String clientId) async {
    final plan = _currentPlan;
    if (plan == null) return false;

    _planError = null;
    return _write(
      clientId,
      busy: (busy) => _isDeletingPlan = busy,
      send: () => _repository.deleteClientWorkoutPlan(clientId, plan.id),
      applied: (_) {
        _currentPlan = null;
        _isNew = true;
        _resetDayState();
        return true;
      },
      failed: (_) {
        _planError = ConsoleError.deletePlan;
        return false;
      },
      dropped: false,
    );
  }

  /// Runs one of the trainer's writes to [clientId]'s plan, days or library,
  /// and puts its outcome on screen only if the builder still shows
  /// [clientId] when the answer arrives.
  ///
  /// [send] makes the request. [applied] takes its answer and [failed] its
  /// error, and each is called only if the trainer hasn't switched client
  /// since the write began; otherwise the write returns [dropped] and
  /// changes nothing. [busy] marks it in flight, whatever the outcome.
  ///
  /// Every write went through [PaneReads.write] already, so a refresh it
  /// overlapped is read again once it settles. What none of them checked was
  /// *whose* builder they were writing into. A delete of client A's plan that
  /// answered after the trainer had switched to client B cleared B's plan and
  /// opened the create flow over it, and a plan created there was B's second;
  /// A's saved day landed in B's list and opened in B's editor; A's new
  /// exercise joined B's library; A's new plan read A's days as a load over B.
  /// A failure was no better: an error about A shown on B. The check lives
  /// here so a write added later can't forget it.
  Future<T> _write<R, T>(
    String clientId, {
    required void Function(bool busy) busy,
    required Future<R> Function() send,
    required T Function(R answer) applied,
    required T Function(Object error) failed,
    required T dropped,
  }) => _reads.write(() async {
    busy(true);
    notifyListeners();
    try {
      final R answer;
      try {
        answer = await send();
      } catch (error) {
        return _loadedClientId == clientId ? failed(error) : dropped;
      }
      return _loadedClientId == clientId ? applied(answer) : dropped;
    } finally {
      busy(false);
      notifyListeners();
    }
  });

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
