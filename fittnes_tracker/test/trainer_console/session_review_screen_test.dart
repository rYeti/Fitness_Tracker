import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_client_summary.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/session_review_screen.dart';

/// Stands in for the network layer so the screen's four states can each be
/// driven deterministically.
class _FakeRepository implements TrainerConsoleRepository {
  final List<TrainerClientSummary> roster;
  final List<ClientSessionSummary> sessions;
  final bool throwOnSessions;

  /// Completes only when the test says so, to hold the screen in its
  /// loading state.
  final Completer<void>? gate;

  _FakeRepository({
    this.roster = const [],
    this.sessions = const [],
    this.throwOnSessions = false,
    this.gate,
  });

  @override
  Future<List<TrainerClientSummary>> getRoster() async => roster;

  @override
  Future<List<ClientSessionSummary>> getClientSessionHistory(
    String clientId, {
    int count = 10,
  }) async {
    if (gate != null) await gate!.future;
    if (throwOnSessions) throw Exception('boom');
    return sessions;
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

TrainerClientSummary _client({
  String id = 'client-1',
  String name = 'Robert Meyer',
}) => TrainerClientSummary(
  relationshipId: 'rel-$id',
  clientId: id,
  clientName: name,
  status: 'Active',
);

ClientSessionSummary _session({
  String id = 'sess-1',
  String name = 'Push Day A',
  SessionStatus status = SessionStatus.done,
  bool isPr = false,
  String? note,
  List<SessionExerciseLog> exercises = const [],
}) => ClientSessionSummary(
  scheduledWorkoutId: id,
  date: DateTime(2026, 8, 17),
  workoutName: name,
  status: status,
  isPr: isPr,
  totalVolume: 8420,
  avgRpe: 8.2,
  clientNote: note,
  exercises: exercises,
);

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repository, {
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final activeClient = ActiveClientProvider(repository: repository);
  await activeClient.loadClients();

  await tester.pumpWidget(
    ChangeNotifierProvider<ActiveClientProvider>.value(
      value: activeClient,
      child: MaterialApp(home: SessionReviewScreen(repository: repository)),
    ),
  );
}

void main() {
  testWidgets('empty roster shows the no-clients empty state', (tester) async {
    await _pump(tester, _FakeRepository());
    await tester.pumpAndSettle();

    expect(find.text('No clients yet'), findsOneWidget);
  });

  testWidgets('client with no sessions shows the no-sessions empty state', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository(roster: [_client()]));
    await tester.pumpAndSettle();

    expect(find.text('No sessions logged yet'), findsOneWidget);
    // Empty-state copy addresses the client by first name only.
    expect(find.textContaining('Robert'), findsWidgets);
  });

  testWidgets('a failing request shows an inline error with retry', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeRepository(roster: [_client()], throwOnSessions: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Could not load'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton, not a bare spinner', (tester) async {
    final gate = Completer<void>();
    await _pump(
      tester,
      _FakeRepository(roster: [_client()], sessions: [_session()], gate: gate),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Loading sessions'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('populated desktop renders history list and detail', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeRepository(
        roster: [_client()],
        sessions: [
          _session(note: 'Felt strong today'),
          _session(id: 'sess-2', name: 'Legs', status: SessionStatus.missed),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Session history'), findsOneWidget);
    // Newest session is selected by default, so its name appears in both the
    // list row and the detail hero.
    expect(find.text('Push Day A'), findsNWidgets(2));
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Missed'), findsWidgets);
    expect(find.text('CLIENT NOTE'), findsOneWidget);
    expect(find.textContaining('8,420 kg'), findsOneWidget);
  });

  testWidgets('selecting a session swaps the detail pane', (tester) async {
    await _pump(
      tester,
      _FakeRepository(
        roster: [_client()],
        sessions: [
          _session(),
          _session(id: 'sess-2', name: 'Leg Day', status: SessionStatus.missed),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Missed session has no exercises -> the detail shows its empty state.
    await tester.tap(find.text('Leg Day').last);
    await tester.pumpAndSettle();

    expect(find.text('No workout logged'), findsOneWidget);
  });

  testWidgets('under-target reps are flagged for screen readers', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeRepository(
        roster: [_client()],
        sessions: [
          _session(
            exercises: [
              const SessionExerciseLog(
                workoutExerciseId: 'we-1',
                exerciseName: 'Bench Press',
                prescribed: PrescribedSets(
                  setCount: 2,
                  targetRepsPerSet: ['8', '8'],
                ),
                skipped: false,
                isPr: false,
                sets: [
                  SessionSetLog(
                    setNumber: 1,
                    reps: 8,
                    weight: 80,
                    rpe: 7,
                    hitTarget: true,
                  ),
                  SessionSetLog(
                    setNumber: 2,
                    reps: 5,
                    weight: 80,
                    rpe: 9,
                    hitTarget: false,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    // Uniform targets collapse to "2 × 8".
    expect(find.text('Prescribed 2 × 8'), findsOneWidget);
    // Colour is never the only signal (CLAUDE.md accessibility rule) — the
    // under-target set says so out loud, the on-target one doesn't.
    expect(
      find.bySemanticsLabel('Set 2, 5 reps, 80 kg, RPE 9, under target'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Set 1, 8 reps, 80 kg, RPE 7'),
      findsOneWidget,
    );
  });

  testWidgets('mobile layout uses session tabs instead of the list pane', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeRepository(roster: [_client()], sessions: [_session()]),
      size: const Size(420, 900),
    );
    await tester.pumpAndSettle();

    expect(find.text('Session history'), findsNothing);
    expect(find.text('Push Day A'), findsNWidgets(2)); // tab + detail hero
  });
}
