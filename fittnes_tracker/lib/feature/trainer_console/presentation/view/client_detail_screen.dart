import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/client_detail_provider.dart';

/// Deep dive on one client: quick stats, weight chart, strength progression,
/// attendance, nutrition-this-week, current program, and a day-switchable
/// workout history (see plan: "workout-history" endpoint).
class ClientDetailScreen extends StatefulWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late final ClientDetailProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ClientDetailProvider(clientId: widget.clientId);
    _provider.load();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ClientDetailProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(title: const Text('Client Detail')),
        body: Consumer<ClientDetailProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              // TODO: skeleton matching header + stat tiles + charts layout.
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(
                child: TextButton(
                  onPressed: provider.load,
                  child: const Text('Retry'),
                ),
              );
            }
            // TODO: header (back arrow, ClientAvatar, name, StatusBadge), 4
            // StatTiles, weight LineChart (mirror weight_chart.dart), strength
            // progression bars, attendance bars, MacroSummary + nutrition
            // bars, current-program card, and a day-switcher (prev/next +
            // date picker, mirroring food_tracking_screen.dart) over the
            // workout-history section.
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
