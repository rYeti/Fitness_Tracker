import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/workout_builder_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_switcher.dart';
import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/core/widgets/app_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Create a plan for the active client, and build out its days — exercises,
/// sets and per-exercise coach notes included. See
/// `docs/trainer-workout-builder.md`.
class WorkoutBuilderScreen extends StatefulWidget {
  /// Injection seam for tests.
  final TrainerConsoleRepository? repository;

  const WorkoutBuilderScreen({super.key, this.repository});

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late final WorkoutBuilderProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = WorkoutBuilderProvider(repository: widget.repository);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncToActiveClient());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToActiveClient();
  }

  void _syncToActiveClient() {
    if (!mounted) return;
    final clientId = context.read<ActiveClientProvider>().activeClient?.clientId;
    if (clientId == null || _provider.loadedClientId == clientId) return;
    _provider.load(clientId);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WorkoutBuilderProvider>.value(
      value: _provider,
      child: Consumer2<ActiveClientProvider, WorkoutBuilderProvider>(
        builder: (context, activeClient, builder, _) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _syncToActiveClient(),
          );

          final isDesktop = Breakpoints.isDesktop(context);
          final client = activeClient.activeClient;

          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 32 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      isDesktop: isDesktop,
                      builder: builder,
                      hasClient: client != null,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _Body(
                        activeClient: activeClient,
                        builder: builder,
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

class _Header extends StatelessWidget {
  final bool isDesktop;
  final WorkoutBuilderProvider builder;
  final bool hasClient;

  const _Header({
    required this.isDesktop,
    required this.builder,
    required this.hasClient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.consoleNavBuilder,
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
          hasClient
              ? l10n.builderSubtitle
              : l10n.builderSubtitleNoClient,
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 13,
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );

    // Only offer "New" when there's an existing plan to leave — otherwise the
    // create flow is already on screen.
    final newButton = hasClient && !builder.isNew && builder.currentPlan != null
        ? FilledButton.icon(
            onPressed: builder.startNewPlan,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.newPlan),
          )
        : const SizedBox.shrink();

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: title),
          const SizedBox(width: 16),
          newButton,
          const SizedBox(width: 12),
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
        if (builder.currentPlan != null && !builder.isNew) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: newButton),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final ActiveClientProvider activeClient;
  final WorkoutBuilderProvider builder;

  const _Body({required this.activeClient, required this.builder});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (activeClient.isLoading && activeClient.clients.isEmpty) {
      return LoadingSkeleton(semanticsLabel: l10n.builderLoading);
    }
    if (activeClient.error != null) {
      return ErrorStateView(
        message: activeClient.error!.localizedMessage(l10n),
        onRetry: activeClient.loadClients,
      );
    }

    final client = activeClient.activeClient;
    if (client == null) {
      return EmptyStateView(
        icon: Icons.group_outlined,
        title: l10n.rosterEmptyTitle,
        message: l10n.builderNoClientsBody,
      );
    }
    if (builder.isLoading) {
      return LoadingSkeleton(semanticsLabel: l10n.builderLoading);
    }
    if (builder.error != null && !builder.isNew) {
      return ErrorStateView(
        message: builder.error!.localizedMessage(l10n),
        onRetry: () => builder.load(client.clientId),
      );
    }

    if (builder.isNew) {
      return _CreatePlanForm(
        builder: builder,
        clientId: client.clientId,
        clientName: client.clientName,
      );
    }
    return _PlanWithDaysView(
      builder: builder,
      clientId: client.clientId,
      clientName: client.clientName,
    );
  }
}

class _CreatePlanForm extends StatefulWidget {
  final WorkoutBuilderProvider builder;
  final String clientId;
  final String clientName;

  const _CreatePlanForm({
    required this.builder,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<_CreatePlanForm> createState() => _CreatePlanFormState();
}

class _CreatePlanFormState extends State<_CreatePlanForm> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedTemplateId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final created = await widget.builder.createPlan(
      clientId: widget.clientId,
      name: _nameController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
    );
    if (!mounted) return;
    if (created) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.planAssignedTo(widget.clientName),
          ),
        ),
      );
    }
  }

  /// Picking a template pre-fills the name — the plan endpoint has no template
  /// field, so this is a shortcut for the trainer, not a server-side link.
  void _selectTemplate(WorkoutPlanTemplateSummary template) {
    setState(() {
      _selectedTemplateId = template.id;
      _nameController.text = template.name;
      if (_descriptionController.text.isEmpty) {
        _descriptionController.text = template.description;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final builder = widget.builder;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              radius: 16,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(title: l10n.newPlan),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.builderPlanName,
                      hintText: l10n.builderPlanNameHint,
                    ),
                    textInputAction: TextInputAction.next,
                    // Validate on blur as well as submit, per CLAUDE.md.
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.planNameRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: l10n.planDescriptionOptional,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (builder.currentPlan != null) ...[
                        TextButton(
                          onPressed:
                              builder.isSaving ? null : builder.cancelNewPlan,
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: builder.isSaving ? null : _submit,
                          child: builder.isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.assignTo(widget.clientName)),
                        ),
                      ),
                    ],
                  ),
                  if (builder.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      builder.error!.localizedMessage(l10n),
                      style: const TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 12,
                        color: ForgeColors.statusBad,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (builder.templates.isNotEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: l10n.startFromTemplate),
                    for (final template in builder.templates)
                      _TemplateRow(
                        template: template,
                        selected: template.id == _selectedTemplateId,
                        onTap: () => _selectTemplate(template),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final WorkoutPlanTemplateSummary template;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateRow({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? ForgeColors.forgeOrange.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ForgeColors.forgeOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 18,
                  color: ForgeColors.forgeOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.templateDaysAndDescription(
                        template.daysPerWeek,
                        template.description,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: ForgeColors.forgeOrange,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The plan summary plus its days — the create/edit editor the design's
/// SET/REPS table describes. See `docs/trainer-workout-builder.md` for what
/// isn't here yet (prescribed weight/RPE, and a UI for the cycle-schedule
/// endpoint) and why.
class _PlanWithDaysView extends StatelessWidget {
  final WorkoutBuilderProvider builder;
  final String clientId;
  final String clientName;

  const _PlanWithDaysView({
    required this.builder,
    required this.clientId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final plan = builder.currentPlan;

    if (plan == null) {
      return EmptyStateView(
        icon: Icons.assignment_outlined,
        title: l10n.noActivePlanTitle,
        message: l10n.noActivePlanBody(clientName),
        action: FilledButton.icon(
          onPressed: builder.startNewPlan,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.createAPlan),
        ),
      );
    }

    final isDesktop = Breakpoints.isDesktop(context);

    final activePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ForgeColors.statusOk.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        l10n.planActive,
        style: const TextStyle(
          fontFamily: 'Exo 2',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ForgeColors.statusOk,
        ),
      ),
    );

    final startedOn = l10n.planStartedOn(
      DateFormat(
        'd MMM yyyy',
        Localizations.localeOf(context).toString(),
      ).format(plan.startDate),
    );

    // On mobile the exercise editor below is what the screen is for, and
    // every line spent here is a line it doesn't get — see
    // `docs/trainer-workout-builder.md`. The full card (name, date,
    // description) stays on desktop, where there's room for it.
    final planCard = isDesktop
        ? AppCard(
            radius: 16,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (plan.isActive) activePill,
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  startedOn,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                if (plan.description != null &&
                    plan.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    plan.description!,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: 13,
                      height: 1.5,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          )
        : AppCard(
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (plan.isActive) activePill,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  startedOn,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          );

    Widget daysArea;
    if (builder.isLoadingDays && builder.planWorkouts.isEmpty) {
      daysArea = LoadingSkeleton(semanticsLabel: l10n.builderDays, rows: 3);
    } else if (builder.daysError != null) {
      daysArea = ErrorStateView(
        message: builder.daysError!.localizedMessage(l10n),
        onRetry: () => builder.loadDays(clientId),
      );
    } else {
      daysArea = _DaysEditor(
        builder: builder,
        clientId: clientId,
        clientName: clientName,
        isDesktop: isDesktop,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        planCard,
        SizedBox(height: isDesktop ? 24 : 16),
        Expanded(child: daysArea),
      ],
    );
  }
}

/// Confirms discarding an unsaved draft before switching away from it.
/// Returns true if the caller should proceed.
Future<bool> _confirmDiscardIfDirty(
  BuildContext context,
  WorkoutBuilderProvider builder,
) async {
  if (!builder.isDraftDirty) return true;
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.builderDiscardChangesTitle),
      content: Text(l10n.builderDiscardChangesBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.builderKeepEditing),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.builderDiscard),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _DaysEditor extends StatelessWidget {
  final WorkoutBuilderProvider builder;
  final String clientId;
  final String clientName;
  final bool isDesktop;

  const _DaysEditor({
    required this.builder,
    required this.clientId,
    required this.clientName,
    required this.isDesktop,
  });

  Future<void> _selectDay(BuildContext context, ClientWorkout? workout) async {
    if (!await _confirmDiscardIfDirty(context, builder)) return;
    builder.selectDay(workout);
  }

  @override
  Widget build(BuildContext context) {
    final dayList = _DayList(
      builder: builder,
      onSelect: (w) => _selectDay(context, w),
    );

    final editor = builder.draft == null
        ? _NoDaySelected(
            clientName: clientName,
            onAddFirstDay: () => _selectDay(context, null),
          )
        : _DayEditorForm(
            key: ValueKey(builder.selectedWorkoutId ?? 'new-day'),
            builder: builder,
            clientId: clientId,
          );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 220, child: dayList),
          const SizedBox(width: 24),
          Expanded(child: editor),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dayList,
        const SizedBox(height: 16),
        Expanded(child: editor),
      ],
    );
  }
}

class _DayList extends StatelessWidget {
  final WorkoutBuilderProvider builder;
  final ValueChanged<ClientWorkout?> onSelect;

  const _DayList({required this.builder, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final days = builder.planWorkouts;
    final isDesktop = Breakpoints.isDesktop(context);

    final chips = [
      for (final day in days)
        Padding(
          padding: EdgeInsets.only(
            right: isDesktop ? 0 : 8,
            bottom: isDesktop ? 8 : 0,
          ),
          child: ChoiceChip(
            label: Text(day.name.isEmpty ? l10n.builderNewDay : day.name),
            selected: builder.selectedWorkoutId == day.id,
            onSelected: (_) => onSelect(day),
          ),
        ),
      Padding(
        padding: EdgeInsets.only(
          right: isDesktop ? 0 : 8,
          bottom: isDesktop ? 8 : 0,
        ),
        child: ActionChip(
          avatar: Icon(Icons.add_rounded, size: 16, color: colors.onSurface),
          label: Text(l10n.builderNewDay),
          onPressed:
              builder.selectedWorkoutId == null && builder.draft?.isNew == true
                  ? null
                  : () => onSelect(null),
        ),
      ),
    ];

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.builderDays),
          Wrap(spacing: 0, runSpacing: 0, children: chips),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }
}

class _NoDaySelected extends StatelessWidget {
  final String clientName;
  final VoidCallback onAddFirstDay;

  const _NoDaySelected({required this.clientName, required this.onAddFirstDay});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      icon: Icons.fitness_center_rounded,
      title: l10n.builderNoWorkoutsTitle,
      message: l10n.builderNoWorkoutsBody(clientName),
      action: FilledButton.icon(
        onPressed: onAddFirstDay,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(l10n.builderNewDay),
      ),
      inCard: true,
    );
  }
}

/// Edits one day's name, metadata and exercises. Keyed by the selected day id
/// in the parent so Flutter tears this state down and rebuilds it fresh
/// whenever the trainer switches days, instead of one controller set being
/// reused across different drafts.
class _DayEditorForm extends StatefulWidget {
  final WorkoutBuilderProvider builder;
  final String clientId;

  const _DayEditorForm({super.key, required this.builder, required this.clientId});

  @override
  State<_DayEditorForm> createState() => _DayEditorFormState();
}

class _DayEditorFormState extends State<_DayEditorForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;
  final _formKey = GlobalKey<FormState>();

  WorkoutBuilderProvider get _builder => widget.builder;

  /// Whether the day's name/description/difficulty/duration fields are shown,
  /// on mobile — desktop always shows them. Starts open for a new day (there
  /// is nothing else to do yet) and closed for an existing one, so the
  /// exercise list — what the screen is for — isn't pushed off the bottom of
  /// a phone-height viewport by fields the trainer opened the day to leave
  /// alone. See `docs/trainer-workout-builder.md`.
  late bool _detailsExpanded;

  @override
  void initState() {
    super.initState();
    final draft = _builder.draft!;
    _detailsExpanded = draft.isNew;
    _nameController = TextEditingController(text: draft.name)
      ..addListener(() => _builder.updateDayName(_nameController.text));
    _descriptionController = TextEditingController(text: draft.description ?? '')
      ..addListener(
        () => _builder.updateDayDescription(_descriptionController.text),
      );
    _durationController =
        TextEditingController(text: draft.estimatedDurationMinutes.toString())
          ..addListener(() {
            final parsed = int.tryParse(_durationController.text);
            if (parsed != null) _builder.updateDayDuration(parsed);
          });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickExercise() async {
    final option = await showModalBottomSheet<ClientExerciseOption>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExercisePickerSheet(
        builder: _builder,
        clientId: widget.clientId,
      ),
    );
    if (option != null) _builder.addExercise(option);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // A collapsed section has no fields for the Form to validate, so a
      // problem it would have caught only surfaces once `saveDraft` itself
      // rejects the day below. Either way, reveal the fields the trainer
      // needs to see.
      if (!Breakpoints.isDesktop(context)) setState(() => _detailsExpanded = true);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final name = _builder.draft!.name;
    final saved = await _builder.saveDraft(widget.clientId);
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.builderDaySavedConfirmation(name))),
      );
    } else if (!Breakpoints.isDesktop(context)) {
      setState(() => _detailsExpanded = true);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _builder.draft!.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.builderDeleteDayConfirmTitle),
        content: Text(l10n.builderDeleteDayConfirmBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ForgeColors.statusBad,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.builderDeleteDay),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await _builder.deleteCurrentDay(widget.clientId);
    if (!mounted) return;
    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.builderDayDeletedConfirmation(name))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final draft = _builder.draft!;
    final isDesktop = Breakpoints.isDesktop(context);
    final showDetails = isDesktop || _detailsExpanded;

    final dirtyBadge = _builder.isDraftDirty
        ? Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ForgeColors.statusWarn.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.builderUnsavedChangesBadge,
              style: const TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ForgeColors.statusWarn,
              ),
            ),
          )
        : const SizedBox.shrink();

    final dayDetailsHeader = Row(
      children: [
        Expanded(
          child: SectionTitle(
            title: draft.isNew ? l10n.builderNewDay : draft.name,
          ),
        ),
        dirtyBadge,
        if (!isDesktop)
          Semantics(
            button: true,
            label: _detailsExpanded
                ? l10n.builderCollapseDayDetails
                : l10n.builderExpandDayDetails,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AnimatedRotation(
                  turns: _detailsExpanded ? 0.5 : 0,
                  duration: ForgeMotion.of(context, ForgeMotion.quick),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final dayDetailsFields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.builderDayName,
            hintText: l10n.builderDayNameHint,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => (value ?? '').trim().isEmpty
              ? l10n.errorWorkoutNameRequired
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(labelText: l10n.planDescriptionOptional),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final level in const [0, 1, 2])
              ChoiceChip(
                label: Text(_difficultyLabel(l10n, level)),
                selected: draft.difficulty == level,
                onSelected: (_) => _builder.updateDayDifficulty(level),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _durationController,
          decoration: InputDecoration(labelText: l10n.builderDurationMinutes),
          keyboardType: TextInputType.number,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            final parsed = int.tryParse(value ?? '');
            if (parsed == null || parsed < 1 || parsed > 1440) {
              return l10n.builderDurationRange;
            }
            return null;
          },
        ),
      ],
    );

    final dayDetailsCard = AppCard(
      radius: isDesktop ? 16 : 12,
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dayDetailsHeader,
          AnimatedSize(
            duration: ForgeMotion.of(context),
            curve: ForgeMotion.curve,
            alignment: Alignment.topCenter,
            child: showDetails ? dayDetailsFields : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    final exercisesCard = AppCard(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: l10n.builderExercises,
            trailing: TextButton.icon(
              onPressed: _pickExercise,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.builderAddExercise),
            ),
          ),
          if (draft.exercises.isEmpty)
            EmptyStateView(
              icon: Icons.list_alt_rounded,
              title: l10n.builderNoExercisesYetTitle,
              message: l10n.builderNoExercisesYetBody,
            )
          else
            for (var i = 0; i < draft.exercises.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExerciseEditorCard(
                  builder: _builder,
                  index: i,
                  isFirst: i == 0,
                  isLast: i == draft.exercises.length - 1,
                ),
              ),
        ],
      ),
    );

    // Save/Delete are a sibling of the scroll view, not the last thing inside
    // it, so they stay reachable without scrolling on a phone-height
    // viewport — only the exercises card should ever need to scroll. Per
    // `docs/app-chrome-and-insets.md` this is a plain child of the body
    // Column, not a `bottomNavigationBar` or its own `SafeArea`: the shell's
    // `Scaffold` already owns those insets.
    final actionRow = Row(
      children: [
        if (!draft.isNew) ...[
          TextButton(
            onPressed: _builder.isDeletingDay ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBad),
            child: _builder.isDeletingDay
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.builderDeleteDay),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: FilledButton(
            onPressed: _builder.isSavingDay ? null : _save,
            child: _builder.isSavingDay
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.builderSaveDay),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dayDetailsCard,
                  SizedBox(height: isDesktop ? 14 : 12),
                  exercisesCard,
                ],
              ),
            ),
          ),
        ),
        if (_builder.dayError != null) ...[
          const SizedBox(height: 12),
          Text(
            _builder.dayError!.localizedMessage(l10n),
            style: const TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12,
              color: ForgeColors.statusBad,
            ),
          ),
        ],
        const SizedBox(height: 12),
        actionRow,
        // Extra bottom padding so the action row clears the nav bar/FAB area
        // on mobile rather than being covered by it.
        const SizedBox(height: 12),
      ],
    );
  }

  String _difficultyLabel(AppLocalizations l10n, int value) => switch (value) {
    0 => l10n.builderDifficultyBeginner,
    2 => l10n.builderDifficultyAdvanced,
    _ => l10n.builderDifficultyIntermediate,
  };
}

class _ExerciseEditorCard extends StatelessWidget {
  final WorkoutBuilderProvider builder;
  final int index;
  final bool isFirst;
  final bool isLast;

  const _ExerciseEditorCard({
    required this.builder,
    required this.index,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final entry = builder.draft!.exercises[index];
    final isDesktop = Breakpoints.isDesktop(context);

    // On mobile the sets are a full-width column, not a wrapped row of
    // pills: a 56px reps field and a 26px remove target were the two things
    // making the set list itself cramped, on top of the screen-level space
    // problem `docs/trainer-workout-builder.md` covers. Desktop keeps the
    // pill layout as-is.
    final setRows = isDesktop
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var setIndex = 0; setIndex < entry.sets.length; setIndex++)
                _SetChip(
                  key: ObjectKey(entry.sets[setIndex]),
                  builder: builder,
                  exerciseIndex: index,
                  setIndex: setIndex,
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: Text(l10n.builderAddSet),
                onPressed: () => builder.addSet(index),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var setIndex = 0; setIndex < entry.sets.length; setIndex++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SetChip(
                    key: ObjectKey(entry.sets[setIndex]),
                    builder: builder,
                    exerciseIndex: index,
                    setIndex: setIndex,
                    dense: true,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => builder.addSet(index),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.builderAddSet),
                ),
              ),
            ],
          );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.exerciseName,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colors.onSurface,
                  ),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                tooltip: l10n.builderMoveExerciseUp,
                onPressed: isFirst
                    ? null
                    : () => builder.moveExercise(index, index - 1),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                tooltip: l10n.builderMoveExerciseDown,
                onPressed: isLast
                    ? null
                    : () => builder.moveExercise(index, index + 1),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
                tooltip: l10n.builderRemoveExercise,
                onPressed: () => builder.removeExercise(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('note-${entry.id}-${entry.exerciseId}-$index'),
            initialValue: entry.notes,
            decoration: InputDecoration(
              labelText: l10n.builderCoachNoteLabel,
              hintText: l10n.builderCoachNoteHint,
              isDense: true,
            ),
            style: const TextStyle(fontFamily: 'Exo 2', fontSize: 13),
            maxLines: 2,
            onChanged: (value) => builder.updateExerciseNote(index, value),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.builderSets,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          setRows,
        ],
      ),
    );
  }
}

class _SetChip extends StatefulWidget {
  final WorkoutBuilderProvider builder;
  final int exerciseIndex;
  final int setIndex;

  /// Renders as a fixed-width pill on desktop (unchanged) or a full-width
  /// row with a real 44x44 remove target on mobile — see the call sites in
  /// `_ExerciseEditorCard` for which is which.
  final bool dense;

  const _SetChip({
    super.key,
    required this.builder,
    required this.exerciseIndex,
    required this.setIndex,
    this.dense = false,
  });

  @override
  State<_SetChip> createState() => _SetChipState();
}

class _SetChipState extends State<_SetChip> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final set = widget
        .builder
        .draft!
        .exercises[widget.exerciseIndex]
        .sets[widget.setIndex];
    _controller = TextEditingController(text: set.targetReps);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    final removeButton = Semantics(
      button: true,
      label: l10n.builderRemoveSet,
      child: InkWell(
        borderRadius: BorderRadius.circular(widget.dense ? 8 : 999),
        onTap: () => widget.builder.removeSet(
          widget.exerciseIndex,
          widget.setIndex,
        ),
        child: widget.dense
            ? const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.close_rounded, size: 18),
              )
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
      ),
    );

    final repsField = TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: l10n.builderTargetRepsHint,
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: widget.dense ? 12 : 0,
        ),
      ),
      style: const TextStyle(fontFamily: 'Exo 2', fontSize: 13),
      textAlign: widget.dense ? TextAlign.start : TextAlign.center,
      onChanged: (value) => widget.builder.updateSetReps(
        widget.exerciseIndex,
        widget.setIndex,
        value,
      ),
    );

    if (widget.dense) {
      return Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${widget.setIndex + 1}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
            Expanded(child: repsField),
            removeButton,
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.setIndex + 1}.',
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(width: 56, child: repsField),
          removeButton,
        ],
      ),
    );
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  final WorkoutBuilderProvider builder;
  final String clientId;

  const _ExercisePickerSheet({required this.builder, required this.clientId});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createExercise() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<ClientExerciseOption>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.builderNewExerciseTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.builderExerciseNameLabel),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => (value ?? '').trim().isEmpty
                ? l10n.errorExerciseNameRequired
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final option = await widget.builder.createExercise(
                widget.clientId,
                name: nameController.text,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(option);
              }
            },
            child: Text(l10n.builderCreateExercise),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final matches = widget.builder.exerciseLibrary
        .where((e) => query.isEmpty || e.name.toLowerCase().contains(query))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.builderPickExerciseTitle,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.builderSearchExercisesHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minLeadingWidth: 0,
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ForgeColors.forgeOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: ForgeColors.forgeOrange,
                        ),
                      ),
                      title: Text(
                        l10n.builderNewExerciseAction,
                        style: const TextStyle(
                          fontFamily: 'Exo 2',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      onTap: _createExercise,
                    ),
                    const Divider(height: 1),
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            l10n.builderNoExercisesFound,
                            style: TextStyle(
                              fontFamily: 'Exo 2',
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      )
                    else
                      for (final option in matches)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            option.name,
                            style: const TextStyle(
                              fontFamily: 'Exo 2',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: option.isTrainerOwned
                              ? Text(
                                  l10n.builderTrainerOwnedTag,
                                  style: TextStyle(
                                    fontFamily: 'Exo 2',
                                    fontSize: 11,
                                    color: ForgeColors.forgeOrange,
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(option),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
