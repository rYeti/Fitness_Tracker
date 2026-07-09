import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/premium/paywall_launcher.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/meal_template.dart';
import '../../data/repositories/meal_template_repository.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'food_tracking_screen.dart';
import 'create_meal_template_screen.dart';
import 'edit_meal_template_screen.dart';

class MealTemplatesScreen extends StatefulWidget {
  const MealTemplatesScreen({Key? key}) : super(key: key);

  @override
  State<MealTemplatesScreen> createState() => _MealTemplatesScreenState();
}

class _MealTemplatesScreenState extends State<MealTemplatesScreen> {
  final GlobalKey _tabControllerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      key: _tabControllerKey,
      length: 4,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.mealTemplates,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.white54,
            indicatorColor: colorScheme.primary,
            labelStyle: const TextStyle(
              fontFamily: 'Exo 2',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: AppLocalizations.of(context)!.mealBreakfast),
              Tab(text: AppLocalizations.of(context)!.mealLunch),
              Tab(text: AppLocalizations.of(context)!.mealDinner),
              Tab(text: AppLocalizations.of(context)!.mealSnacks),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TemplateListTab(category: 'Breakfast'),
            TemplateListTab(category: 'Lunch'),
            TemplateListTab(category: 'Dinner'),
            TemplateListTab(category: 'Snack'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final hasPremium = context.read<AccessProvider>().hasPremiumAccess;
            if (!hasPremium) {
              final repo = context.read<MealTemplateRepository>();
              final all = await repo.getAllTemplates();
              if (!context.mounted) return;
              if (all.length >= 3) {
                openPaywall(context);
                return;
              }
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateMealTemplateScreen(),
              ),
            );
            if (result == true && context.mounted) setState(() {});
          },
          elevation: 2,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class TemplateListTab extends StatefulWidget {
  final String category;
  const TemplateListTab({Key? key, required this.category}) : super(key: key);

  @override
  State<TemplateListTab> createState() => _TemplateListTabState();
}

class _TemplateListTabState extends State<TemplateListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final repository = Provider.of<MealTemplateRepository>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurface.withValues(alpha: 0.55);

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async => setState(() {}),
      child: FutureBuilder<List<MealTemplate>>(
        key: ValueKey(
          'templates-${widget.category}-${DateTime.now().millisecondsSinceEpoch}',
        ),
        future: repository.getTemplatesByCategory(widget.category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(AppLocalizations.of(context)!.failedToLoadData(snapshot.error ?? '')));
          }
          final templates = snapshot.data ?? [];
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: muted),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noTemplatesFound,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: 15,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final hasPremium = context.read<AccessProvider>().hasPremiumAccess;
                      if (!hasPremium) {
                        final repo = context.read<MealTemplateRepository>();
                        final all = await repo.getAllTemplates();
                        if (!context.mounted) return;
                        if (all.length >= 3) {
                          openPaywall(context);
                          return;
                        }
                      }
                      if (!context.mounted) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => CreateMealTemplateScreen(
                                initialCategory: widget.category,
                              ),
                        ),
                      );
                      if (result == true && mounted) setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.createTemplate,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: templates.length,
            itemBuilder:
                (context, index) => TemplateCard(
                  template: templates[index],
                  onDelete: () => setState(() {}),
                ),
          );
        },
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  final MealTemplate template;
  final VoidCallback? onDelete;

  const TemplateCard({Key? key, required this.template, this.onDelete})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card    = colorScheme.surfaceContainerLow;
    final text    = colorScheme.onSurface;
    final muted   = colorScheme.onSurface.withValues(alpha: 0.55);
    final mutedBg = colorScheme.onSurface.withValues(alpha: 0.07);
    final border  = colorScheme.onSurface.withValues(alpha: 0.10);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () => _showApplyTemplateDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: text,
                      ),
                    ),
                  ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: muted, size: 20),
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(AppLocalizations.of(context)!.edit),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(AppLocalizations.of(context)!.delete),
                          ),
                        ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    EditMealTemplateScreen(template: template),
                          ),
                        );
                        if (result == true && onDelete != null) onDelete!();
                      } else if (value == 'delete') {
                        _confirmDeleteTemplate(context);
                      }
                    },
                  ),
                ],
              ),
              if (template.description != null &&
                  template.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  template.description!,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _infoBadge(context, AppLocalizations.of(context)!.itemsCount(template.items.length), mutedBg, muted),
                  _infoBadge(
                    context,
                    '${template.totalCalories.toStringAsFixed(0)} kcal',
                    mutedBg,
                    muted,
                  ),
                  if (template.totalWeightGrams != null)
                    _infoBadge(
                      context,
                      '${template.totalWeightGrams!.toStringAsFixed(0)}g batch',
                      colorScheme.primaryContainer,
                      colorScheme.onPrimaryContainer,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(BuildContext context, String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Exo 2',
          fontSize: 11,
          color: textColor,
        ),
      ),
    );
  }

  void _showApplyTemplateDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PortionBottomSheet(template: template),
    );
  }

  void _confirmDeleteTemplate(BuildContext context) {  // keep below _showApplyTemplateDialog
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            title: Text(
              AppLocalizations.of(context)!.deleteTemplate,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
            content: Text(
              AppLocalizations.of(context)!.deleteTemplateQuestion,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  final repository = Provider.of<MealTemplateRepository>(
                    context,
                    listen: false,
                  );
                  repository.deleteMealTemplate(template.id!);
                  if (onDelete != null) onDelete!();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          ),
    );
  }
}

// ── Portion Bottom Sheet ─────────────────────────────────────────────────────

class _PortionBottomSheet extends StatefulWidget {
  final MealTemplate template;
  const _PortionBottomSheet({required this.template});

  @override
  State<_PortionBottomSheet> createState() => _PortionBottomSheetState();
}

class _PortionBottomSheetState extends State<_PortionBottomSheet> {
  final _portionController = TextEditingController();
  late String _category;
  double? _portionGrams;

  static const _categories = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _category = widget.template.category;
  }

  @override
  void dispose() {
    _portionController.dispose();
    super.dispose();
  }

  bool get _hasBatchWeight =>
      widget.template.totalWeightGrams != null &&
      widget.template.totalWeightGrams! > 0;

  double get _ratio =>
      (_portionGrams != null && _hasBatchWeight)
          ? (_portionGrams! / widget.template.totalWeightGrams!)
          : 1.0;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final t = widget.template;

    final scaledCal = (t.totalCalories * _ratio).round();
    final scaledP   = (t.totalProtein  * _ratio).round();
    final scaledC   = (t.totalCarbs    * _ratio).round();
    final scaledF   = (t.totalFat      * _ratio).round();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // template name
            Text(
              t.name,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: colorScheme.onSurface,
              ),
            ),
            if (_hasBatchWeight) ...[
              const SizedBox(height: 4),
              Text(
                loc.templateFullBatch(
                  t.totalWeightGrams!.toStringAsFixed(0),
                  t.totalCalories.toStringAsFixed(0),
                ),
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // portion input (only when batch weight is set)
            if (_hasBatchWeight) ...[
              TextField(
                controller: _portionController,
                decoration: InputDecoration(
                  labelText: loc.templatePortionLabel,
                  border: const OutlineInputBorder(),
                  suffixText: 'g',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  setState(() {
                    _portionGrams = double.tryParse(v);
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // live macro preview card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroChip('$scaledCal', 'kcal', colorScheme),
                  _macroChip('${scaledP}g', 'P', colorScheme),
                  _macroChip('${scaledC}g', 'C', colorScheme),
                  _macroChip('${scaledF}g', 'F', colorScheme),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // category dropdown
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: loc.mealCategory,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(_localizedCategory(loc, c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),

            // log button
            ElevatedButton(
              onPressed: _log,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                textStyle: const TextStyle(
                  fontFamily: 'Exo 2',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _hasBatchWeight ? loc.templateLogPortion : loc.templateLogFull,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String value, String label, ColorScheme cs) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: cs.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  String _localizedCategory(AppLocalizations loc, String cat) {
    switch (cat) {
      case 'Breakfast': return loc.mealBreakfast;
      case 'Lunch':     return loc.mealLunch;
      case 'Dinner':    return loc.mealDinner;
      default:          return loc.mealSnacks;
    }
  }

  Future<void> _log() async {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final db = Provider.of<AppDatabase>(context, listen: false);
    final repo = NutritionRepository(db);

    final portionArg = _hasBatchWeight ? _portionGrams : null;

    try {
      await repo.applyTemplatePortion(_category, widget.template, portionArg);
      if (!mounted) return;
      Navigator.pop(context); // close sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.templateApplied(
              widget.template.name,
              _localizedCategory(loc, _category),
            ),
          ),
          backgroundColor: colorScheme.primary,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      final currentState = globalFoodTrackingKey.currentState;
      if (currentState != null) {
        currentState.loadNutritionData();
      }
    } catch (e) {
      AppLogger.i('Error applying template: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorApplyingTemplate(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
