import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_console_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/trainer_console_shell.dart';

/// Trainer's home base: KPI row + client roster (grid/table toggle).
class TrainerDashboardScreen extends StatefulWidget {
  const TrainerDashboardScreen({super.key});

  @override
  State<TrainerDashboardScreen> createState() =>
      _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  late final TrainerConsoleProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = TrainerConsoleProvider();
    _provider.loadRoster();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TrainerConsoleProvider>.value(
      value: _provider,
      child: TrainerConsoleShell(
        currentRoute: TrainerConsoleRoute.dashboard,
        onRouteSelected: (route) {
          // TODO: navigate to Messages/Builder/Nutrition once those screens
          // exist.
        },
        child: Consumer<TrainerConsoleProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              // TODO: skeleton/shimmer matching the KPI row + roster layout,
              // not a bare spinner (CLAUDE.md: Loading state).
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              // TODO: inline error message + retry action, not a silent
              // failure (CLAUDE.md: Error state).
              return Center(
                child: TextButton(
                  onPressed: provider.loadRoster,
                  child: const Text('Retry'),
                ),
              );
            }

            if (provider.roster.isEmpty) {
              // TODO: real empty state — icon + "No clients yet — invite
              // your first client" + action (CLAUDE.md: Empty state).
              return const Center(child: Text('No clients yet'));
            }

            // TODO: KPI row (StatTile x3-4) + roster grid/table toggle
            // (segmented control) + ClientAvatar/StatusBadge per row.
            return ListView.builder(
              itemCount: provider.roster.length,
              itemBuilder: (context, index) {
                final client = provider.roster[index];
                return ListTile(title: Text(client.clientName));
              },
            );
          },
        ),
      ),
    );
  }
}
