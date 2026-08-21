import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_console_home.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Role guard for the Trainer Console.
///
/// The console reads and writes other people's training data, so it is only
/// ever shown to a user the server confirms is a trainer
/// (`AccessProvider.isTrainer`, populated from `api/TrainerClient/status`).
///
/// This is a *UX* guard, not a security boundary — every Trainer Console
/// endpoint independently re-checks the caller against an Active
/// TrainerClient relationship (see ITrainerConsoleService). Rendering the
/// console for a non-trainer would produce empty screens and 401s, not a data
/// leak; the guard exists so they get an explanation instead.
class TrainerConsoleGate extends StatelessWidget {
  /// Shown when the signed-in user isn't a trainer. On web this is the
  /// trainee app, so a client visiting the same URL still lands somewhere
  /// useful; pushed as a route it's null and the user gets an explanation.
  final Widget? fallback;

  /// Passed to the console so web trainers can switch to the trainee app.
  final VoidCallback? onExitConsole;

  /// Injection seam for tests, matching the console's own screens.
  final TrainerConsoleRepository? repository;

  /// Injection seam for tests. Passed straight through to the console, which
  /// owns the licence provider for its seat affordances.
  final TrainerLicenceProvider? licenceProvider;

  const TrainerConsoleGate({
    super.key,
    this.fallback,
    this.onExitConsole,
    this.repository,
    this.licenceProvider,
  });

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final l10n = AppLocalizations.of(context)!;

    // initialize() restores the cached flag and notifies before the network
    // re-check, so this window is brief — but on a cold start it's the
    // difference between a flash of "not a trainer" and a spinner.
    if (!access.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (access.isTrainer) {
      return TrainerConsoleHome(
        onExitConsole: onExitConsole,
        repository: repository,
        licenceProvider: licenceProvider,
      );
    }
    if (fallback != null) return fallback!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainerConsole)),
      body: SafeArea(
        child: ConsoleEmptyState(
          icon: Icons.lock_outline_rounded,
          title: l10n.trainerAccessOnly,
          message: l10n.trainerAccessOnlyBody,
        ),
      ),
    );
  }
}
