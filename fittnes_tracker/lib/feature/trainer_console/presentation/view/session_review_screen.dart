import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/session_review_provider.dart';

/// "What did this client actually log" — session history list + detail
/// (prescribed vs. logged per exercise/set). See design handoff README
/// section 6 and trainer_console_models.dart's Session Review comment block
/// for the backend gap (needs a new session-history list endpoint) and the
/// fields that must be derived client-side (status/duration/volume/avgRpe/PR).
///
/// TODO: assumes an ancestor `ChangeNotifierProvider<ActiveClientProvider>`,
/// same assumption as NutritionScreen/WorkoutBuilderScreen — register once
/// at the shell/app level, not per-screen.
class SessionReviewScreen extends StatefulWidget {
  const SessionReviewScreen({super.key});

  @override
  State<SessionReviewScreen> createState() => _SessionReviewScreenState();
}

class _SessionReviewScreenState extends State<SessionReviewScreen> {
  late final SessionReviewProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SessionReviewProvider();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SessionReviewProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(title: const Text('Session Review')),
        body: Consumer2<ActiveClientProvider, SessionReviewProvider>(
          builder: (context, activeClient, review, _) {
            if (activeClient.activeClientId == null) {
              // TODO: real empty state — "Select a client" prompt, same
              // treatment as NutritionScreen.
              return const Center(child: Text('No client selected'));
            }
            if (review.isLoading) {
              // TODO: skeleton matching history-list + detail-card shape,
              // not a bare spinner (CLAUDE.md: Loading state).
              return const Center(child: CircularProgressIndicator());
            }
            if (review.error != null) {
              return Center(
                child: TextButton(
                  onPressed: () => review.load(activeClient.activeClientId!),
                  child: const Text('Retry'),
                ),
              );
            }
            if (review.sessions.isEmpty) {
              // TODO: real empty state — "No sessions logged yet".
              return const Center(child: Text('No sessions logged yet'));
            }
            // TODO desktop (>1024px): 2-column grid, minmax(0,330px) history
            // list | fluid detail column, per design handoff. TODO mobile:
            // client-switcher chip + horizontally-scrollable day tabs above a
            // single detail card, per design handoff's mobile Session Review
            // block.
            //
            // History row → StatusBadge with session.status, PR pill when
            // session.isPr (see status_badge.dart; the .dc.html's SES_ST
            // const has the exact tones).
            //
            // Detail card (review.selected) → Volume/Avg RPE stat-tile row
            // (let tiles wrap — don't hardcode min-width, per the .dc.html's
            // fix history). NOTE: no Duration tile — the schema has no
            // start/end timestamps, see trainer_console_models.dart. Then a
            // client-note block when selected.clientNote != null, then one
            // card per SessionExerciseLog: prescribed line built from
            // prescribed.targetRepsPerSet (collapse to "3 × 8" when uniform),
            // "Skipped" pill when skipped, else a SET/REPS/WEIGHT/RPE grid —
            // reps tinted amber when !set.hitTarget, no check/dash icon
            // column (removed per the design chat's last round of feedback).
            // selected.isEmpty → "No workout logged" empty state +
            // "Message {client}" action (reuse Chat once built).
            return ListView.builder(
              itemCount: review.sessions.length,
              itemBuilder: (context, index) {
                final session = review.sessions[index];
                return ListTile(
                  title: Text(session.workoutName),
                  subtitle: Text(session.date.toIso8601String()),
                  selected: session.scheduledWorkoutId ==
                      review.selected?.scheduledWorkoutId,
                  onTap: () => review.selectSession(session.scheduledWorkoutId),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
