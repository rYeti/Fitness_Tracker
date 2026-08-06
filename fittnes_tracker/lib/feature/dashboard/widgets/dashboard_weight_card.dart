import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/feature/weight_tracking/presentation/widgets/weight_progress_card.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class DashboardWeightCard extends StatefulWidget {
  final UserGoalsProvider goalsProvider;
  final VoidCallback onNavigateToWeightTracking;

  const DashboardWeightCard({
    Key? key,
    required this.goalsProvider,
    required this.onNavigateToWeightTracking,
  }) : super(key: key);

  @override
  State<DashboardWeightCard> createState() => _DashboardWeightCardState();
}

class _DashboardWeightCardState extends State<DashboardWeightCard> {
  bool _isEditing = false;
  late TextEditingController _startingWeightController;
  late TextEditingController _goalWeightController;
  String? _completionEstimate;

  @override
  void initState() {
    super.initState();
    _startingWeightController = TextEditingController(
      text: widget.goalsProvider.startingWeight.toString(),
    );
    _goalWeightController = TextEditingController(
      text: widget.goalsProvider.goalWeight.toString(),
    );
    _loadCompletionEstimate();
  }

  Future<void> _loadCompletionEstimate() async {
    final l10n = AppLocalizations.of(context)!;
    final estimate = await widget.goalsProvider.getCompletionEstimate(l10n);
    if (mounted) setState(() => _completionEstimate = estimate);
  }

  @override
  void dispose() {
    _startingWeightController.dispose();
    _goalWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalWeight = widget.goalsProvider.goalWeight;
    final startingWeight = widget.goalsProvider.startingWeight;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (!_isEditing) {
      _startingWeightController.text = startingWeight.toString();
      _goalWeightController.text = goalWeight.toString();
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (!_isEditing)
            _buildInfoCard()
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.weightProgress,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.startingWeight,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _startingWeightController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: l10n.enterStartingWeightHint,
                      suffixText: l10n.kg,
                      filled: true,
                      fillColor: colorScheme.onSurface.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: colorScheme.onSurface.withValues(alpha: 0.10),
                          width: 0.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: colorScheme.onSurface.withValues(alpha: 0.10),
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1,
                        ),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.goalWeight,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _goalWeightController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: l10n.enterGoalWeightHint,
                      suffixText: l10n.kg,
                      filled: true,
                      fillColor: colorScheme.onSurface.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: colorScheme.onSurface.withValues(alpha: 0.10),
                          width: 0.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: colorScheme.onSurface.withValues(alpha: 0.10),
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1,
                        ),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _isEditing = false);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        child: Text(l10n.cancel.toUpperCase()),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveWeightGoals,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(l10n.save.toUpperCase()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Positioned(
            right: 8,
            top: 8,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.close : Icons.edit,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  tooltip: _isEditing ? l10n.cancel : l10n.edit,
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                ),
                if (!_isEditing)
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    tooltip: l10n.weightProgress,
                    onPressed: widget.onNavigateToWeightTracking,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveWeightGoals() {
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
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
    widget.goalsProvider.setWeightGoals(startingWeight, goalWeight);
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.weightGoalsUpdated)));
    _loadCompletionEstimate();
  }

  Widget _buildInfoCard() {
    return WeightProgressCard(
      currentWeight: widget.goalsProvider.currentWeight,
      startingWeight: widget.goalsProvider.startingWeight,
      goalWeight: widget.goalsProvider.goalWeight,
      progress: widget.goalsProvider.getWeightProgress(),
      completionEstimate: _completionEstimate,
    );
  }
}
