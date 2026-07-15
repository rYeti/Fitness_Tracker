import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/workout_builder_provider.dart';

/// isBuilderNew/isBuilderEdit state machine per design handoff. Client
/// picker uses the shared ActiveClientProvider (see nutrition_screen.dart's
/// note — same ancestor-provider assumption applies here).
class WorkoutBuilderScreen extends StatefulWidget {
  const WorkoutBuilderScreen({super.key});

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late final WorkoutBuilderProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = WorkoutBuilderProvider();
    _provider.loadTemplates();
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
      child: Scaffold(
        appBar: AppBar(title: const Text('Workout Builder')),
        body: Consumer2<ActiveClientProvider, WorkoutBuilderProvider>(
          builder: (context, activeClient, builder, _) {
            if (builder.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (builder.error != null) {
              return Center(
                child: TextButton(
                  onPressed: builder.loadTemplates,
                  child: const Text('Retry'),
                ),
              );
            }
            if (builder.isNew) {
              // TODO: name field, client picker (ActiveClientProvider), goal
              // chips, template grid (builder.templates) — see design
              // handoff's "Create new workout" state.
              return const SizedBox.shrink();
            }
            // TODO: day tabs rail, exercise cards with SET/REPS/WEIGHT/RPE
            // table (WorkoutSet.rpe once wired), exercise library sidebar,
            // Save / Assign to client actions (builder.assignToClient).
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
