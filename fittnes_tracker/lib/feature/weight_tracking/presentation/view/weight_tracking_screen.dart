import 'package:ForgeForm/core/providers/theme_provider.dart';
import 'package:ForgeForm/feature/weight_tracking/presentation/providers/weight_provider.dart';
import 'package:ForgeForm/feature/weight_tracking/presentation/widgets/weight_chart.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class WeightTrackingScreen extends StatelessWidget {
  const WeightTrackingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Forge',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Color(0xFFFF6B3E),
                  ),
                ),
                TextSpan(
                  text: 'Form',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: Colors.white,
              ),
              onPressed:
                  () =>
                      Provider.of<ThemeProvider>(
                        context,
                        listen: false,
                      ).toggleTheme(),
            ),
            IconButton(
              icon: const Icon(Icons.flag, color: Colors.white),
              tooltip: l10n.weightGoals,
              onPressed: () => Navigator.pushNamed(context, '/weight-goals'),
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              itemBuilder:
                  (ctx) => [
                    PopupMenuItem(child: Text(l10n.setWeightGoal)),
                    PopupMenuItem(value: 'bmi', child: Text(l10n.calculateBMI)),
                  ],
              onSelected: (value) {
                if (value == 'goals') {
                  Navigator.pushNamed(context, '/weight-goals');
                } else if (value == 'bmi') {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.bmiComingSoon)));
                }
              },
            ),
          ],
        ),
        body: Consumer<WeightProvider>(
          builder: (context, weightProvider, _) {
            final colorScheme = Theme.of(context).colorScheme;
            if (weightProvider.isLoading) {
              return Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              );
            }
            final weightRecords = weightProvider.weightRecords;
            if (weightRecords.isEmpty) {
              return _buildEmptyState(context, weightProvider);
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.10),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.currentWeight,
                          style: TextStyle(
                            fontFamily: 'Exo 2',
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${weightProvider.latestWeightRecord?.weight.toStringAsFixed(1) ?? '--'} kg',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.10),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      height: 180,
                      child: WeightChart(weightRecords: weightRecords),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.10),
                          width: 0.5,
                        ),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: weightRecords.length,
                        separatorBuilder:
                            (_, __) => Divider(
                              height: 0.5,
                              thickness: 0.5,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.10,
                              ),
                            ),
                        itemBuilder: (context, index) {
                          final record = weightRecords[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${record.weight.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('EEEE, MMMM d, y').format(record.date),
                              style: TextStyle(
                                fontFamily: 'Exo 2',
                                fontSize: 11,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                  onPressed:
                                      () => _showAddEditWeightDialog(
                                        context,
                                        weightProvider,
                                        record: record,
                                      ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                  onPressed:
                                      () => _confirmDelete(
                                        context,
                                        weightProvider,
                                        record.id,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed:
              () => _showAddEditWeightDialog(
                context,
                Provider.of<WeightProvider>(context, listen: false),
              ),
          elevation: 2,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WeightProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monitor_weight_outlined,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noWeightRecordsYet,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.addWeightRecord,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddEditWeightDialog(context, provider),
            icon: const Icon(Icons.add),
            label: Text(
              l10n.addWeight,
              style: const TextStyle(
                fontFamily: 'Exo 2',
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditWeightDialog(
    BuildContext context,
    WeightProvider provider, {
    dynamic record,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AddEditWeightDialog(provider: provider, record: record),
    );
  }

  void _confirmDelete(BuildContext context, WeightProvider provider, int id) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            title: Text(
              l10n.deleteWeightRecord,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
            content: Text(
              l10n.deleteWeightRecordConfirm,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.55,
                  ),
                ),
                child: Text(l10n.cancel.toUpperCase()),
              ),
              TextButton(
                onPressed: () {
                  provider.deleteWeightRecord(id);
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.delete.toUpperCase()),
              ),
            ],
          ),
    );
  }
}

class AddEditWeightDialog extends StatefulWidget {
  final WeightProvider provider;
  final dynamic record;
  const AddEditWeightDialog({Key? key, required this.provider, this.record})
    : super(key: key);

  @override
  _AddEditWeightDialogState createState() => _AddEditWeightDialogState();
}

class _AddEditWeightDialogState extends State<AddEditWeightDialog> {
  late TextEditingController _weightController;
  late DateTime _selectedDate;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _weightController = TextEditingController(
        text: widget.record.weight.toString(),
      );
      _selectedDate = widget.record.date;
      _noteController = TextEditingController(text: widget.record.note ?? '');
    } else {
      _weightController = TextEditingController();
      _selectedDate = DateTime.now();
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
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
        borderSide: BorderSide(color: colorScheme.primary, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.record != null;
    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      title: Text(
        isEditing ? l10n.editWeightRecord : l10n.addWeightRecordTitle,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: colorScheme.onSurface,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _weightController,
              decoration: _dec(l10n.weight),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.fatLabel,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.10),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, y').format(_selectedDate),
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              decoration: _dec(l10n.noteOptional),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          child: Text(l10n.cancel.toUpperCase()),
        ),
        ElevatedButton(
          onPressed: () => _saveWeight(isEditing, l10n),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: Text(
            isEditing
                ? l10n.updateButton.toUpperCase()
                : l10n.save.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Exo 2',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate)
      setState(() => _selectedDate = picked);
  }

  void _saveWeight(bool isEditing, AppLocalizations l10n) {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    if (weight == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invalidWeight)));
      return;
    }
    if (isEditing) {
      widget.provider.updateWeightRecord(
        id: widget.record.id,
        date: _selectedDate,
        weight: weight,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );
    } else {
      widget.provider.addWeightRecord(
        date: _selectedDate,
        weight: weight,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );
    }
    Navigator.pop(context);
  }
}
