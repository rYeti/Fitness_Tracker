import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_client_summary.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/session_review_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_avatar.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/status_badge.dart';

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
          final isDesktop = MediaQuery.of(context).size.width > 1024;
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
  final TrainerClientSummary? client;
  final SessionReviewProvider review;
  final bool isDesktop;

  const _Header({
    required this.client,
    required this.review,
    required this.isDesktop,
  });

  String _subtitle() {
    if (client == null) return 'Select a client to review their sessions';
    final sessions = review.sessions;
    if (sessions.isEmpty) return 'What ${client!.firstName} actually logged';
    final done =
        sessions.where((s) => s.status == SessionStatus.done).length;
    final missed =
        sessions.where((s) => s.status == SessionStatus.missed).length;
    return 'What ${client!.firstName} actually logged — '
        '${sessions.length} sessions, $done completed, $missed missed';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Session Review',
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
          _subtitle(),
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
          const _ClientSwitcher(fullWidth: false),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 12),
        const _ClientSwitcher(fullWidth: true),
      ],
    );
  }
}

/// Chip (desktop) or full-width button (mobile) that opens the roster and
/// switches `ActiveClientProvider`'s selection.
class _ClientSwitcher extends StatelessWidget {
  final bool fullWidth;

  const _ClientSwitcher({required this.fullWidth});

  Future<void> _pick(BuildContext context, ActiveClientProvider provider) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _ClientPickerSheet(
        clients: provider.clients,
        activeClientId: provider.activeClient?.clientId,
      ),
    );
    if (chosen != null) provider.setActiveClient(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<ActiveClientProvider>();
    final client = provider.activeClient;

    if (client == null) return const SizedBox.shrink();

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        ClientAvatar(
          initials: client.initials,
          clientId: client.clientId,
          size: 28,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            client.clientName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.expand_more_rounded,
          size: 20,
          color: colors.onSurface.withValues(alpha: 0.55),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: 'Switch client. Currently ${client.clientName}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _pick(context, provider),
          child: Container(
            // 44px min height per CLAUDE.md's tap-target rule.
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _ClientPickerSheet extends StatelessWidget {
  final List<TrainerClientSummary> clients;
  final String? activeClientId;

  const _ClientPickerSheet({
    required this.clients,
    required this.activeClientId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'SWITCH CLIENT',
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                final selected = client.clientId == activeClientId;
                return ListTile(
                  leading: ClientAvatar(
                    initials: client.initials,
                    clientId: client.clientId,
                    size: 40,
                  ),
                  title: Text(
                    client.clientName,
                    style: const TextStyle(
                      fontFamily: 'Exo 2',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: client.programLabel == null
                      ? null
                      : Text(
                          client.programLabel!,
                          style: const TextStyle(
                            fontFamily: 'Exo 2',
                            fontSize: 12,
                          ),
                        ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: ForgeColors.forgeOrange,
                        )
                      : null,
                  selected: selected,
                  onTap: () => Navigator.of(context).pop(client.clientId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — routes between the four required states
// ---------------------------------------------------------------------------

class _Body extends StatelessWidget {
  final TrainerClientSummary? client;
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
    if (activeClient.isLoading && activeClient.clients.isEmpty) {
      return const _HistorySkeleton();
    }
    if (activeClient.error != null) {
      return _ErrorState(
        message: activeClient.error!,
        onRetry: activeClient.loadClients,
      );
    }
    if (client == null) {
      return const _EmptyState(
        icon: Icons.group_outlined,
        title: 'No clients yet',
        message: 'Invite your first client to start reviewing their sessions.',
      );
    }
    if (review.isLoading) return const _HistorySkeleton();
    if (review.error != null) {
      return _ErrorState(
        message: review.error!,
        onRetry: () => review.load(client!.clientId),
      );
    }
    if (review.sessions.isEmpty) {
      return _EmptyState(
        icon: Icons.event_note_outlined,
        title: 'No sessions logged yet',
        message: '${client!.firstName} hasn’t recorded a workout yet.',
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
({StatusTone tone, String label}) _statusDisplay(SessionStatus status) =>
    switch (status) {
      SessionStatus.done => (tone: StatusTone.ok, label: 'Completed'),
      SessionStatus.partial => (tone: StatusTone.warn, label: 'Partial'),
      SessionStatus.missed => (tone: StatusTone.bad, label: 'Missed'),
    };

String _formatDate(DateTime date) {
  final today = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final diff = DateTime(today.year, today.month, today.day).difference(day).inDays;
  final formatted = DateFormat('EEE d MMM').format(date);
  if (diff == 0) return 'Today · $formatted';
  if (diff == 1) return 'Yesterday · $formatted';
  return formatted;
}

class _HistoryList extends StatelessWidget {
  final List<ClientSessionSummary> sessions;
  final SessionReviewProvider review;

  const _HistoryList({required this.sessions, required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
            child: Text(
              'Session history',
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
    final status = _statusDisplay(session.status);

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
                                  ? 'Workout'
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
                        _formatDate(session.date),
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
                            ? 'Workout'
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
                        DateFormat('EEE d MMM').format(session.date),
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
  final TrainerClientSummary client;

  const _SessionDetail({required this.session, required this.client});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SessionHeroCard(session: session),
        const SizedBox(height: 14),
        if (session.isEmpty)
          _EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No workout logged',
            message: '${client.firstName} didn’t record this session.',
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
    final status = _statusDisplay(session.status);

    return _Card(
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
                session.workoutName.isEmpty ? 'Workout' : session.workoutName,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: colors.onSurface,
                ),
              ),
              StatusBadge(tone: status.tone, label: status.label),
              if (session.isPr) const _PrPill(label: 'NEW PR'),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _formatDate(session.date),
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
                value: _formatVolume(session.totalVolume),
                label: 'Volume',
              ),
              _StatChip(
                value: session.avgRpe == null
                    ? '—'
                    : session.avgRpe!.toStringAsFixed(1),
                label: 'Avg RPE',
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

  static String _formatVolume(double volume) {
    if (volume <= 0) return '—';
    return '${NumberFormat.decimalPattern().format(volume.round())} kg';
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
                  'CLIENT NOTE',
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
    final prescribed = exercise.prescribed?.summary;

    return _Card(
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
                                ? 'Exercise'
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
                        'Prescribed $prescribed',
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
                const StatusBadge(tone: StatusTone.bad, label: 'Skipped'),
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
            child: Text('SET', style: style),
          ),
          Expanded(child: Text('REPS', style: style)),
          Expanded(child: Text('WEIGHT', style: style)),
          Expanded(child: Text('RPE', style: style)),
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
      label: _semanticsLabel(set, missedTarget),
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

  static String _semanticsLabel(SessionSetLog set, bool missedTarget) {
    final parts = <String>[
      'Set ${set.setNumber}',
      if (set.reps != null) '${set.reps} reps',
      _formatWeight(set) == 'BW' ? 'bodyweight' : _formatWeight(set),
      if (set.rpe != null) 'RPE ${set.rpe}',
      if (missedTarget) 'under target',
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
  final String label;

  const _PrPill({this.label = 'PR'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ForgeColors.forgeOrange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
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
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

/// Skeleton shaped like the real list, per CLAUDE.md — not a bare spinner.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Semantics(
      label: 'Loading sessions',
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(140, 14),
                const SizedBox(height: 8),
                bar(90, 11),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 38,
            color: colors.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool inCard;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.inCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 38, color: colors.onSurface.withValues(alpha: 0.55)),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 12.5,
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );

    if (!inCard) return Center(child: content);
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
      child: Center(child: content),
    );
  }
}
