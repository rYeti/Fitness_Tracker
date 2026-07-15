import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/nutrition_provider.dart';

/// Client-switcher (via ActiveClientProvider, shared with Workout Builder)
/// + a day-switcher (mirroring food_tracking_screen.dart's _selectedDate
/// pattern) so the trainer can browse any past day's nutrition, not just
/// today.
///
/// TODO: assumes an ancestor `ChangeNotifierProvider<ActiveClientProvider>`
/// — that needs to be registered above wherever Builder/Nutrition are both
/// reachable (e.g. in TrainerConsoleShell or main.dart), not created here.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = NutritionProvider();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NutritionProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nutrition')),
        body: Consumer2<ActiveClientProvider, NutritionProvider>(
          builder: (context, activeClient, nutrition, _) {
            if (activeClient.activeClientId == null) {
              // TODO: real empty state — "Select a client" prompt.
              return const Center(child: Text('No client selected'));
            }
            if (nutrition.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (nutrition.error != null) {
              return Center(
                child: TextButton(
                  onPressed: () => nutrition.load(activeClient.activeClientId!),
                  child: const Text('Retry'),
                ),
              );
            }
            // TODO: client-switcher chip, day-switcher (prev/next + date
            // picker), CalorieRing + MacroSummary, today's meals list
            // (unlogged at 50% opacity), 7-day trend bars, flags rail,
            // weekly-compliance bars.
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
