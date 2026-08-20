import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/workout_builder_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_switcher.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';

/// Create a plan for the active client, or view the plan they're on.
///
/// The design's full per-exercise editor (day tabs, sets/reps/weight/RPE) is
/// not built here: `WorkoutPlanRequestDto` carries plan metadata only, and
/// there is no trainer-scoped endpoint for a client's workouts/exercises. The
/// screen states that plainly rather than presenting an editor whose Save
/// would discard everything.
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

          final colors = Theme.of(context).colorScheme;
          final isDesktop = MediaQuery.of(context).size.width > 1024;
          final client = activeClient.activeClient;

          return Scaffold(
            backgroundColor: colors.surfaceContainerLowest,
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

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Workout Builder',
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
              ? 'Create and assign a plan'
              : 'Select a client to build a plan',
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
            label: const Text('New plan'),
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
    if (activeClient.isLoading && activeClient.clients.isEmpty) {
      return const ConsoleSkeleton(semanticsLabel: 'Loading workout builder');
    }
    if (activeClient.error != null) {
      return ConsoleErrorState(
        message: activeClient.error!,
        onRetry: activeClient.loadClients,
      );
    }

    final client = activeClient.activeClient;
    if (client == null) {
      return const ConsoleEmptyState(
        icon: Icons.group_outlined,
        title: 'No clients yet',
        message: 'Invite your first client to build them a plan.',
      );
    }
    if (builder.isLoading) {
      return const ConsoleSkeleton(semanticsLabel: 'Loading workout builder');
    }
    if (builder.error != null && !builder.isNew) {
      return ConsoleErrorState(
        message: builder.error!,
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
    return _CurrentPlanView(builder: builder, clientName: client.firstName);
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
        SnackBar(content: Text('Plan assigned to ${widget.clientName}')),
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
    final colors = Theme.of(context).colorScheme;
    final builder = widget.builder;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConsoleCard(
              radius: 16,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ConsoleSectionTitle(title: 'New plan'),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Plan name',
                      hintText: 'e.g. Push / Pull / Legs',
                    ),
                    textInputAction: TextInputAction.next,
                    // Validate on blur as well as submit, per CLAUDE.md.
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Give the plan a name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
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
                          child: const Text('Cancel'),
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
                              : Text('Assign to ${widget.clientName}'),
                        ),
                      ),
                    ],
                  ),
                  if (builder.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      builder.error!,
                      style: const TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 12.5,
                        color: ForgeColors.statusBad,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (builder.templates.isNotEmpty)
              ConsoleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ConsoleSectionTitle(title: 'Start from a template'),
                    for (final template in builder.templates)
                      _TemplateRow(
                        template: template,
                        selected: template.id == _selectedTemplateId,
                        onTap: () => _selectTemplate(template),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            _EditorUnavailableNote(colors: colors),
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
                        fontSize: 13.5,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      '${template.daysPerWeek} days · ${template.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 11.5,
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

class _CurrentPlanView extends StatelessWidget {
  final WorkoutBuilderProvider builder;
  final String clientName;

  const _CurrentPlanView({required this.builder, required this.clientName});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final plan = builder.currentPlan;

    if (plan == null) {
      return ConsoleEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No active plan',
        message: '$clientName isn’t on a plan yet.',
        action: FilledButton.icon(
          onPressed: builder.startNewPlan,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create a plan'),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsoleCard(
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
                    if (plan.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ForgeColors.statusOk.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontFamily: 'Exo 2',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ForgeColors.statusOk,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Started ${DateFormat('d MMM yyyy').format(plan.startDate)}',
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12.5,
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
          ),
          const SizedBox(height: 14),
          _EditorUnavailableNote(colors: colors),
        ],
      ),
    );
  }
}

/// Says why the per-exercise editor isn't here. Better an honest note than a
/// Save button that silently drops the trainer's work.
class _EditorUnavailableNote extends StatelessWidget {
  final ColorScheme colors;

  const _EditorUnavailableNote({required this.colors});

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: colors.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exercise editing isn’t available yet',
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Plans can be created and assigned. Editing a plan’s '
                  'exercises, sets and reps needs a trainer-facing API that '
                  'doesn’t exist yet.',
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12,
                    height: 1.45,
                    color: colors.onSurface.withValues(alpha: 0.65),
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
