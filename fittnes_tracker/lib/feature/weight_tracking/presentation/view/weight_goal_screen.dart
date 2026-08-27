import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';
import 'package:ForgeForm/core/widgets/content_pane.dart';

class WeightGoalScreen extends StatefulWidget {
  const WeightGoalScreen({Key? key}) : super(key: key);

  @override
  _WeightGoalScreenState createState() => _WeightGoalScreenState();
}

class _WeightGoalScreenState extends State<WeightGoalScreen> {
  late TextEditingController _startingWeightController;
  late TextEditingController _goalWeightController;
  late UserGoalsProvider _goalsProvider;
  String? _completionEstimate;

  @override
  void initState() {
    super.initState();
    _goalsProvider = Provider.of<UserGoalsProvider>(context, listen: false);
    _startingWeightController = TextEditingController(
      text: _goalsProvider.startingWeight.toString(),
    );
    _goalWeightController = TextEditingController(
      text: _goalsProvider.goalWeight.toString(),
    );
    _loadCompletionEstimate();
  }

  Future<void> _loadCompletionEstimate() async {
    final l10n = AppLocalizations.of(context)!;
    final estimate = await _goalsProvider.getCompletionEstimate(l10n);
    if (mounted) {
      setState(() {
        _completionEstimate = estimate;
      });
    }
  }

  @override
  void dispose() {
    _startingWeightController.dispose();
    _goalWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: ForgeAppBar(
        title: l10n.weightGoals,
      ),
      body: ContentPane(
        child: Consumer<UserGoalsProvider>(
          builder: (context, provider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.startingWeight,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _startingWeightController,
                    decoration: InputDecoration(
                      labelText: l10n.startingWeight,
                      hintText: l10n.enterStartingWeightHint,
                      suffixText: 'kg',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.goalWeight,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _goalWeightController,
                    decoration: InputDecoration(
                      labelText: l10n.goalWeight,
                      hintText: l10n.enterGoalWeightHint,
                      suffixText: 'kg',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveWeightGoals,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(l10n.saveWeightGoals),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _saveWeightGoals() {
    final l10n = AppLocalizations.of(context)!;
    final startingWeight = double.tryParse(
      _startingWeightController.text.replaceAll(',', '.'),
    );
    final goalWeight = double.tryParse(
      _goalWeightController.text.replaceAll(',', '.'),
    );

    if (startingWeight == null || goalWeight == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pleaseEnterValidWeights)));
      return;
    }

    _goalsProvider.setWeightGoals(startingWeight, goalWeight);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.weightGoalsSaved)));

    Navigator.pop(context);
  }
}
