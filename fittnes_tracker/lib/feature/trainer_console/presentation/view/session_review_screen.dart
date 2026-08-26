import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/session_review_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_switcher.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/status_badge.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// "What did this client actually log" — session history list + detail
/// (prescribed vs. logged per exercise/set), backed by
/// `GET api/TrainerConsole/{clientId}/session-history`.
///
/// Assumes an ancestor `ChangeNotifierProvider<ActiveClientProvider>`, same as
/// NutritionScreen/WorkoutBuilderScreen — register it once at the shell/app
/// level so switching a client re-derives every visible pane.
class SessionReviewScreen extends StatefulWidget {
  /// Injection seam for tests; production passes nothing and the provider
  /// builds the real repository itself.
  final TrainerConsoleRepository? repository;

  const SessionReviewScreen({super.key, this.repository});

  @override
  State<SessionReviewScreen> createState() => _SessionReviewScreenState();
}

class _SessionReviewScreenState extends State<SessionReviewScreen> {
  late final SessionReviewProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SessionReviewProvider(repository: widget.repository);
    // Deferred: reading ActiveClientProvider needs a mounted context, and the
    // roster may not have arrived yet on a cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncToActiveClient());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToActiveClient();
  }

  /// Reloads whenever the shared active client changes — the switcher drives
  /// this screen, it doesn't own a selection of its own.
  void _syncToActiveClient() {
    if (!mounted) return;
    final clientId = context.read<ActiveClientProvider>().activeClient?.clientId;
    if (clientId == null) return;
    if (_provider.loadedClientId == clientId) return;
    _provider.load(clientId);
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
      child: Consumer2<ActiveClientProvider, SessionReviewProvider>(
        builder: (context, activeClient, review, _) {
          // Keep the screen in step when the active client changes underneath
          // it (e.g. switched from another pane on a wide desktop layout).
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _syncToActiveClient(),
          );

          final client = activeClient.activeClient;
          final isDesktop = Breakpoints.isDesktop(context);
          final padding = isDesktop ? 32.0 : 16.0;

          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      client: client,
                      review: review,
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _Body(
                        client: client,
                        activeClient: activeClient,
                        review: review,
                        isDesktop: isDesktop,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header + client switcher
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final TrainerRosterEntry? client;
  final SessionReviewProvider review;
  final bool isDesktop;

  const _Header({
    required this.client,
    required this.review,
    required this.isDesktop,
  });

  String _subtitle(AppLocalizations l10n) {
    if (client == null) return l10n.sessionReviewSubtitleNoClient;
    final sessions = review.sessions;
    if (sessions.isEmpty) {
      return l10n.sessionReviewSubtitle(client!.firstName);
    }
    final done =
        sessions.where((s) => s.status == SessionStatus.done).length;
    final missed =
        sessions.where((s) => s.status == SessionStatus.missed).length;
    return l10n.sessionReviewSubtitleWithCounts(
      client!.firstName,
      sessions.length,
      done,
      missed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.consoleNavSessionReview,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            fontSize: isDesktop ? 26 : 20,
            letterSpacing: -0.3,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _subtitle(l10n),
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 13,
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );

    // Desktop puts the switcher inline beside the title; on mobile it becomes
    // a full-width row beneath, where a chip would be an awkward tap target.
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: title),
          const SizedBox(width: 16),
          const ClientSwitcher(fullWidth: false),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 12),
        const ClientSwitcher(fullWidth: true),
      ],
    );
  }
}

/// Routes between the four required states, then the desktop/mobile layouts.
class _Body extends StatelessWidget {
  final TrainerRosterEntry? client;
  final ActiveClientProvider activeClient;
  final SessionReviewProvider review;
  final bool isDesktop;

  const _Body({
    required this.client,
    required this.activeClient,
    required this.review,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (activeClient.isLoading && activeClient.clients.isEmpty) {
      return ConsoleSkeleton(semanticsLabel: l10n.sessionsLoading);
    }
    if (activeClient.error != null) {
      return ConsoleErrorState(
        message: activeClient.error!.localizedMessage(l10n),
        onRetry: activeClient.loadClients,
      );
    }
    if (client == null) {
      return ConsoleEmptyState(
        icon: Icons.group_outlined,
        title: l10n.rosterEmptyTitle,
        message: l10n.sessionReviewNoClientsBody,
      );
    }
    if (review.isLoading) {
      return ConsoleSkeleton(semanticsLabel: l10n.sessionsLoading);
    }
    if (review.error != null) {
      return ConsoleErrorState(
        message: review.error!.localizedMessage(l10n),
        onRetry: () => review.load(client!.clientId),
      );
    }
    if (review.sessions.isEmpty) {
      return ConsoleEmptyState(
        icon: Icons.event_note_outlined,
        title: l10n.noSessionsLoggedTitle,
        message: l10n.noSessionsLoggedBody(client!.firstName),
      );
    }

    final selected = review.selected!;
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 330,
            child: _HistoryList(sessions: review.sessions, review: review),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: SingleChildScrollView(
              child: _SessionDetail(session: selected, client: client!),
            ),
          ),
        ],
      );
    }

    // Mobile: horizontally-scrollable day tabs above the detail card.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SessionTabs(sessions: review.sessions, review: review),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: _SessionDetail(session: selected, client: client!),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// History list (desktop) / tabs (mobile)
// ---------------------------------------------------------------------------

/// Maps a session status onto the shared StatusBadge tones — a completed
/// session is "ok", a partial one "warn", a missed one "bad".
({StatusTone tone, String label}) _statusDisplay(
  SessionStatus status,
  AppLocalizations l10n,
) => switch (status) {
  SessionStatus.done => (tone: StatusTone.ok, label: l10n.sessionCompleted),
  SessionStatus.partial => (tone: StatusTone.warn, label: l10n.sessionPartial),
  SessionStatus.missed => (tone: StatusTone.bad, label: l10n.sessionMissed),
};

String _formatDate(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context)!;
  final today = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final diff = DateTime(today.year, today.month, today.day).difference(day).inDays;
  final formatted = DateFormat(
    'EEE d MMM',
    Localizations.localeOf(context).toString(),
  ).format(date);
  if (diff == 0) return l10n.dateToday(formatted);
  if (diff == 1) return l10n.dateYesterday(formatted);
  return formatted;
}

class _HistoryList extends StatelessWidget {
  final List<ClientSessionSummary> sessions;
  final SessionReviewProvider review;

  const _HistoryList({required this.sessions, required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConsoleCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
            child: Text(
              AppLocalizations.of(context)!.sessionHistory,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: colors.onSurface,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: colors.onSurface.withValues(alpha: 0.08),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _HistoryRow(
                  session: session,
                  selected: session.scheduledWorkoutId ==
                      review.selected?.scheduledWorkoutId,
                  onTap: () =>
                      review.selectSession(session.scheduledWorkoutId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ClientSessionSummary session;
  final bool selected;
  final VoidCallback onTap;

  const _HistoryRow({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final status = _statusDisplay(session.status, l10n);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? ForgeColors.forgeOrange.withValues(alpha: 0.1)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  width: 3,
                  color:
                      selected ? ForgeColors.forgeOrange : Colors.transparent,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(11, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              session.workoutName.isEmpty
                                  ? l10n.workout
                                  : session.workoutName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Exo 2',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          if (session.isPr) ...[
                            const SizedBox(width: 6),
                            const _PrPill(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(context, session.date),
                        style: TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 11.5,
                          color: colors.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(tone: status.tone, label: status.label, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionTabs extends StatelessWidget {
  final List<ClientSessionSummary> sessions;
  final SessionReviewProvider review;

  const _SessionTabs({required this.sessions, required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final session = sessions[index];
          final selected = session.scheduledWorkoutId ==
              review.selected?.scheduledWorkoutId;
          return Semantics(
            selected: selected,
            button: true,
            child: Material(
              color: selected ? ForgeColors.forgeOrange : colors.surface,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => review.selectSession(session.scheduledWorkoutId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : colors.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.workoutName.isEmpty
                            ? l10n.workout
                            : session.workoutName,
                        style: TextStyle(
                          fontFamily: 'Exo 2',
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: selected ? Colors.white : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat(
                          'EEE d MMM',
                          Localizations.localeOf(context).toString(),
                        ).format(session.date),
                        style: TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 9.5,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.85)
                              : colors.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

class _SessionDetail extends StatelessWidget {
  final ClientSessionSummary session;
  final TrainerRosterEntry client;

  const _SessionDetail({required this.session, required this.client});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SessionHeroCard(session: session),
        const SizedBox(height: 14),
        if (session.isEmpty)
          ConsoleEmptyState(
            icon: Icons.event_busy_outlined,
            title: AppLocalizations.of(context)!.noWorkoutLoggedTitle,
            message: AppLocalizations.of(
              context,
            )!.noWorkoutLoggedBody(client.firstName),
            inCard: true,
          )
        else
          ...session.exercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _ExerciseCard(exercise: exercise),
            ),
          ),
      ],
    );
  }
}

class _SessionHeroCard extends StatelessWidget {
  final ClientSessionSummary session;

  const _SessionHeroCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final status = _statusDisplay(session.status, l10n);

    return ConsoleCard(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                session.workoutName.isEmpty
                    ? l10n.workout
                    : session.workoutName,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: colors.onSurface,
                ),
              ),
              StatusBadge(tone: status.tone, label: status.label),
              if (session.isPr) _PrPill(label: l10n.newPr),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _formatDate(context, session.date),
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12.5,
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          // Wraps rather than fixing widths — the .dc.html had to be fixed
          // twice for these tiles clipping at narrow widths.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // NOTE: no Duration tile — ScheduledWorkout has no start/end
              // timestamps. See trainer_console_models.dart.
              _StatChip(
                value: _formatVolume(session.totalVolume, context),
                label: l10n.volume,
              ),
              _StatChip(
                value: session.avgRpe == null
                    ? '—'
                    : session.avgRpe!.toStringAsFixed(1),
                label: l10n.avgRpe,
                accent: true,
              ),
            ],
          ),
          if (session.clientNote != null && session.clientNote!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ClientNote(note: session.clientNote!),
          ],
        ],
      ),
    );
  }

  static String _formatVolume(double volume, BuildContext context) {
    if (volume <= 0) return '—';
    // Locale-aware grouping: 12,500 kg for an English trainer, 12.500 kg for
    // a German one.
    final locale = Localizations.localeOf(context).toString();
    return '${NumberFormat.decimalPattern(locale).format(volume.round())} kg';
  }
}

class _ClientNote extends StatelessWidget {
  final String note;

  const _ClientNote({required this.note});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 19,
            color: colors.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.clientNote,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  note,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 13,
                    height: 1.5,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final SessionExerciseLog exercise;

  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final prescribed = exercise.prescribed?.summary;

    return ConsoleCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            exercise.exerciseName.isEmpty
                                ? l10n.exercise
                                : exercise.exerciseName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Exo 2',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        if (exercise.isPr) ...[
                          const SizedBox(width: 7),
                          const _PrPill(),
                        ],
                      ],
                    ),
                    if (prescribed != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.prescribedSummary(prescribed),
                        style: TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 11.5,
                          color: colors.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (exercise.skipped)
                StatusBadge(tone: StatusTone.bad, label: l10n.sessionSkipped),
            ],
          ),
          if (exercise.sets.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SetTableHeader(),
            const SizedBox(height: 6),
            ...exercise.sets.map((set) => _SetRow(set: set)),
          ],
        ],
      ),
    );
  }
}

/// SET / REPS / WEIGHT / RPE column widths, shared by the header and rows so
/// they can't drift apart.
const _setColumnFlex = [36, 1, 1, 1];

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final style = TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: colors.onSurface.withValues(alpha: 0.55),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          SizedBox(
            width: _setColumnFlex[0].toDouble(),
            child: Text(l10n.setColumn, style: style),
          ),
          Expanded(child: Text(l10n.repsColumn, style: style)),
          Expanded(child: Text(l10n.weightColumn, style: style)),
          Expanded(child: Text(l10n.rpeColumn, style: style)),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final SessionSetLog set;

  const _SetRow({required this.set});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sunken = colors.onSurface.withValues(alpha: 0.05);

    // Under-target reps tint amber. Per the design chat's final round, there's
    // deliberately no check/dash icon column — the tint carries it. The
    // Semantics label below keeps that accessible without relying on colour.
    final missedTarget = !set.hitTarget;

    Widget cell(String text, {Color? color, FontWeight? weight}) => Container(
      margin: const EdgeInsets.only(left: 9),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: sunken,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Exo 2',
          fontSize: 13,
          fontWeight: weight ?? FontWeight.w600,
          color: color ?? colors.onSurface,
        ),
      ),
    );

    // One node for the whole row: a screen reader announcing
    // "Set 2, 5 reps, 80 kg, RPE 9, under target" is far more useful than
    // tabbing through four disconnected numbers. The "under target" suffix is
    // what keeps the amber tint from being colour-only.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticsLabel(set, missedTarget, l10n),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sunken,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${set.setNumber}',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: colors.onSurface,
                ),
              ),
            ),
            Expanded(
              child: cell(
                set.reps?.toString() ?? '—',
                color: missedTarget ? ForgeColors.statusWarn : null,
                weight: FontWeight.w600,
              ),
            ),
            Expanded(child: cell(_formatWeight(set))),
            Expanded(
              child: cell(
                set.rpe?.toString() ?? '—',
                color: colors.onSurface.withValues(alpha: 0.65),
                weight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _semanticsLabel(
    SessionSetLog set,
    bool missedTarget,
    AppLocalizations l10n,
  ) {
    final parts = <String>[
      l10n.setNumber(set.setNumber),
      if (set.reps != null) l10n.repsCount(set.reps!),
      _formatWeight(set) == 'BW' ? l10n.bodyweight : _formatWeight(set),
      if (set.rpe != null) l10n.rpeValue('${set.rpe}'),
      if (missedTarget) l10n.underTarget,
    ];
    return parts.join(', ');
  }

  static String _formatWeight(SessionSetLog set) {
    final weight = set.weight;
    if (weight == null || weight <= 0) return 'BW';
    final unit = set.weightUnit?.isNotEmpty == true ? set.weightUnit! : 'kg';
    // Trim a trailing .0 so 82.5 stays 82.5 but 80.0 reads 80.
    final text = weight == weight.roundToDouble()
        ? weight.round().toString()
        : weight.toString();
    return '$text $unit';
  }
}

// ---------------------------------------------------------------------------
// Shared small pieces
// ---------------------------------------------------------------------------

class _PrPill extends StatelessWidget {
  /// Null keeps the short "PR" badge; the hero card passes "NEW PR".
  final String? label;

  const _PrPill({this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ForgeColors.forgeOrange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? AppLocalizations.of(context)!.pr,
        style: const TextStyle(
          fontFamily: 'Exo 2',
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: ForgeColors.forgeOrange,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final bool accent;

  const _StatChip({
    required this.value,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: accent ? ForgeColors.forgeOrange : colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card chrome from the handoff: 12px radius (16 for hero), hairline border,
/// soft shadow.
