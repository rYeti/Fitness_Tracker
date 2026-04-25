import 'dart:math' show min, max;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/premium/paywall_screen.dart';
import 'package:ForgeForm/feature/premium/premium_gate.dart';

enum TimeRange { week, month, threeMonths, allTime, custom }

final globalProgressKey = GlobalKey<_ProgressScreenState>();

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Gym tab state
  TimeRange _gymRange = TimeRange.month;
  DateTime? _gymCustomStart;
  DateTime? _gymCustomEnd;
  bool _gymLoading = true;

  // Nutrition tab state
  TimeRange _nutritionRange = TimeRange.month;
  DateTime? _nutritionCustomStart;
  DateTime? _nutritionCustomEnd;
  bool _nutritionLoading = true;

  // Gym data
  List<ExerciseProgressData> _exerciseProgress = [];
  WorkoutFrequencyData? _frequencyData;

  // Nutrition data
  List<DailyNutritionData> _dailyData = [];
  List<WeightRecordData> _weightRecords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadProgressData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _rangeStart(TimeRange range, DateTime? customStart) {
    final hasPremium = context.read<AccessProvider>().hasPremiumAccess;
    if (!hasPremium) return DateTime.now().subtract(const Duration(days: 7));
    if (range == TimeRange.custom && customStart != null) return customStart;
    final now = DateTime.now();
    switch (range) {
      case TimeRange.week:        return now.subtract(const Duration(days: 7));
      case TimeRange.month:       return now.subtract(const Duration(days: 30));
      case TimeRange.threeMonths: return now.subtract(const Duration(days: 90));
      case TimeRange.allTime:     return DateTime(2000);
      case TimeRange.custom:      return now.subtract(const Duration(days: 30));
    }
  }

  Future<void> _loadProgressData() async {
    await Future.wait([_loadGymData(), _loadNutritionData()]);
  }

  void reloadGymData() => _loadGymData();

  Future<void> _loadGymData() async {
    setState(() => _gymLoading = true);
    try {
      final db = context.read<AppDatabase>();
      final startDate = _rangeStart(_gymRange, _gymCustomStart);
      final endDate = _gymCustomEnd ?? DateTime.now();
      final exerciseProgress = await _loadExerciseProgress(db, startDate, endDate);
      final frequency = await _loadWorkoutFrequency(db, startDate, endDate);
      if (mounted) {
        setState(() {
          _exerciseProgress = exerciseProgress;
          _frequencyData = frequency;
          _gymLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gymLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingProgress(e))),
        );
      }
    }
  }

  Future<void> _loadNutritionData() async {
    setState(() => _nutritionLoading = true);
    try {
      final db = context.read<AppDatabase>();
      await db.mealDao.deduplicateMeals();
      final startDate = _rangeStart(_nutritionRange, _nutritionCustomStart);
      final endDate = _nutritionCustomEnd ?? DateTime.now();
      final nutritionData = await _loadNutritionDataForRange(db, startDate, endDate);
      final weightData = await _loadWeightData(db, startDate, endDate);
      if (mounted) {
        setState(() {
          _dailyData = nutritionData;
          _weightRecords = weightData;
          _nutritionLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _nutritionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingProgress(e))),
        );
      }
    }
  }

  // === GYM DATA LOADING ===

  Future<List<ExerciseProgressData>> _loadExerciseProgress(
    AppDatabase db,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rows = await db.customSelect(
      '''
    SELECT
      we.exercise_id,
      e.name            AS exercise_name,
      sw.scheduled_date,
      COALESCE(SUM(COALESCE(ws.weight, 0.0) * COALESCE(ws.reps, 0)), 0.0) AS total_volume,
      COALESCE(MAX(COALESCE(ws.weight, 0.0)), 0.0)  AS max_weight,
      COALESCE(SUM(COALESCE(ws.reps, 0)), 0)        AS total_reps,
      COUNT(ws.id)                                   AS set_count,
      COALESCE((SELECT ws2.reps FROM workout_set_table ws2
                WHERE ws2.scheduled_workout_exercise_id = swe.id
                ORDER BY ws2.set_number ASC LIMIT 1), 0) AS first_set_reps
    FROM scheduled_workout_table sw
    JOIN scheduled_workout_exercise_table swe ON swe.scheduled_workout_id = sw.id
    JOIN workout_exercise_table           we  ON we.id  = swe.workout_exercise_id
    JOIN exercise_table                   e   ON e.id   = we.exercise_id
    JOIN workout_set_table                ws  ON ws.scheduled_workout_exercise_id = swe.id
    WHERE sw.is_completed = 1
      AND (ws.reps IS NOT NULL OR ws.weight IS NOT NULL)
      AND sw.scheduled_date >= ?
      AND sw.scheduled_date <= ?
    GROUP BY we.exercise_id, sw.scheduled_date
    ORDER BY e.name ASC, sw.scheduled_date ASC
    ''',
      variables: [
        Variable<DateTime>(startDate),
        Variable<DateTime>(endDate),
      ],
    ).get();

    final Map<int, List<ExerciseSessionData>> exerciseMap = {};
    final Map<int, String> exerciseNames = {};

    for (final row in rows) {
      final exerciseId   = row.read<int>('exercise_id');
      final exerciseName = row.read<String>('exercise_name');
      final date         = row.read<DateTime>('scheduled_date');
      final totalVolume  = row.readNullable<double>('total_volume') ?? 0.0;
      final maxWeight    = row.readNullable<double>('max_weight')   ?? 0.0;
      final totalReps    = row.readNullable<int>('total_reps')      ?? 0;
      final setCount     = row.read<int>('set_count');
      final firstSetReps = row.readNullable<int>('first_set_reps')  ?? 0;

      exerciseNames[exerciseId] = exerciseName;
      exerciseMap.putIfAbsent(exerciseId, () => []).add(ExerciseSessionData(
        date: date,
        totalVolume: totalVolume,
        maxWeight: maxWeight,
        totalReps: totalReps,
        setCount: setCount,
        reps: firstSetReps,
      ));
    }

    final progressList = exerciseMap.entries.map((entry) {
      return ExerciseProgressData(
        exerciseName: exerciseNames[entry.key]!,
        sessions: entry.value,
      );
    }).toList();

    progressList.sort((a, b) => b.sessions.length.compareTo(a.sessions.length));
    return progressList;
  }

  Future<WorkoutFrequencyData> _loadWorkoutFrequency(AppDatabase db, DateTime startDate, DateTime endDate) async {
    final completedWorkouts =
        await (db.select(db.scheduledWorkoutTable)
              ..where((t) => t.isCompleted.equals(true))
              ..where((t) => t.scheduledDate.isBiggerOrEqualValue(startDate))
              ..where((t) => t.scheduledDate.isSmallerOrEqualValue(endDate))
              ..orderBy([(t) => OrderingTerm.asc(t.scheduledDate)]))
            .get();

    final Map<int, int> weeklyWorkouts = {};
    int currentStreak = 0;
    int longestStreak = 0;
    DateTime? lastWorkoutDate;

    for (final workout in completedWorkouts) {
      final weekNumber = _getWeekNumber(workout.scheduledDate);
      weeklyWorkouts[weekNumber] = (weeklyWorkouts[weekNumber] ?? 0) + 1;

      if (lastWorkoutDate == null) {
        currentStreak = 1;
      } else {
        final daysDiff =
            workout.scheduledDate.difference(lastWorkoutDate).inDays;
        if (daysDiff <= 2) {
          currentStreak++;
        } else {
          if (currentStreak > longestStreak) longestStreak = currentStreak;
          currentStreak = 1;
        }
      }

      lastWorkoutDate = workout.scheduledDate;
    }

    if (currentStreak > longestStreak) longestStreak = currentStreak;

    final isStreakActive =
        lastWorkoutDate != null &&
        DateTime.now().difference(lastWorkoutDate).inDays <= 2;

    return WorkoutFrequencyData(
      totalWorkouts: completedWorkouts.length,
      weeklyWorkouts: weeklyWorkouts,
      currentStreak: isStreakActive ? currentStreak : 0,
      longestStreak: longestStreak,
      averagePerWeek:
          weeklyWorkouts.isEmpty
              ? 0
              : weeklyWorkouts.values.reduce((a, b) => a + b) /
                  weeklyWorkouts.length,
    );
  }

  // === NUTRITION DATA LOADING ===

  Future<List<DailyNutritionData>> _loadNutritionDataForRange(AppDatabase db, DateTime startDate, DateTime endDate) async {
    final List<DailyNutritionData> dailyDataList = [];

    DateTime currentDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDate.isBefore(end) ||
        currentDate.isAtSameMomentAs(end)) {
      final dayEnd = currentDate.add(const Duration(days: 1));
      final meals =
          await (db.select(db.mealTable)
            ..where((t) =>
                t.date.isBiggerOrEqualValue(currentDate) &
                t.date.isSmallerThanValue(dayEnd))).get();

      int totalCalories = 0;
      int totalProtein = 0;
      int totalCarbs = 0;
      int totalFat = 0;

      for (final meal in meals) {
        final foodEntries =
            await (db.select(db.mealFoodTable)
              ..where((t) => t.mealId.equals(meal.id))).get();

        for (final entry in foodEntries) {
          final foodItem = await db.foodItemDao.getFoodItemById(
            entry.foodEntryId,
          );

          if (foodItem != null) {
            totalCalories += foodItem.calories;
            totalProtein += foodItem.protein;
            totalCarbs += foodItem.carbs;
            totalFat += foodItem.fat;
          }
        }
      }

      dailyDataList.add(
        DailyNutritionData(
          date: currentDate,
          calories: totalCalories,
          protein: totalProtein,
          carbs: totalCarbs,
          fat: totalFat,
        ),
      );

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dailyDataList;
  }

  Future<List<WeightRecordData>> _loadWeightData(AppDatabase db, DateTime startDate, DateTime endDate) async {
    final records = await db.weightRecordDao.getRecordsInRange(
      startDate,
      endDate,
    );

    return records;
  }

  int _getWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(startOfYear).inDays;
    return (days / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadProgressData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Color(0xFFFF6B3E),
          tabs: [
            Tab(text: AppLocalizations.of(context)!.gym),
            Tab(text: AppLocalizations.of(context)!.nutrition),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildGymTab(theme), _buildNutritionTab(theme)],
      ),
    );
  }

  // === GYM TAB ===

  Widget _buildGymTab(ThemeData theme) {
    if (_gymLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadGymData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeRangeSelector(
              theme,
              selectedRange: _gymRange,
              customStart: _gymCustomStart,
              customEnd: _gymCustomEnd,
              onChanged: (range, {customStart, customEnd}) {
                setState(() {
                  _gymRange = range;
                  _gymCustomStart = customStart;
                  _gymCustomEnd = customEnd;
                });
                _loadGymData();
              },
            ),
            const SizedBox(height: 24),

            if (_frequencyData != null) ...[
              _buildFrequencyOverview(theme),
              const SizedBox(height: 24),
            ],

            Text(
              AppLocalizations.of(context)!.exerciseProgress,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (_exerciseProgress.isEmpty)
              _buildEmptyState(
                theme,
                Icons.timeline,
                AppLocalizations.of(context)!.noWorkoutDataYet,
                AppLocalizations.of(context)!.completeWorkoutsProgress,
              )
            else
              PremiumGate(
                child: Column(
                  children: _exerciseProgress
                      .map((data) => _buildExerciseCard(data, theme))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyOverview(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.workoutFrequency,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    AppLocalizations.of(context)!.totalWorkouts,
                    _frequencyData!.totalWorkouts.toString(),
                    Icons.fitness_center,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    AppLocalizations.of(context)!.avgPerWeek,
                    _frequencyData!.averagePerWeek.toStringAsFixed(1),
                    Icons.bar_chart,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    AppLocalizations.of(context)!.currentStreak,
                    '${_frequencyData!.currentStreak} ${AppLocalizations.of(context)!.days}',
                    Icons.local_fire_department,
                    _frequencyData!.currentStreak > 0
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    AppLocalizations.of(context)!.longestStreak,
                    '${_frequencyData!.longestStreak} ${AppLocalizations.of(context)!.days}',
                    Icons.emoji_events,
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseProgressData data, ThemeData theme) {
    // Scale ranges for normalising the weight line onto the reps Y-axis.
    final minReps = data.sessions.map((s) => s.reps.toDouble()).reduce(min);
    final maxReps = data.sessions.map((s) => s.reps.toDouble()).reduce(max);
    final minWeight = data.sessions.map((s) => s.maxWeight).reduce(min);
    final maxWeight = data.sessions.map((s) => s.maxWeight).reduce(max);
    final repsRange = maxReps - minReps;
    final weightRange = maxWeight - minWeight;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          data.exerciseName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 46,
                            getTitlesWidget: (value, meta) {
                              // Back-map normalised Y value to actual kg.
                              final actualWeight =
                                  repsRange == 0
                                      ? minWeight
                                      : minWeight +
                                          (value - minReps) *
                                              weightRange /
                                              repsRange;
                              return Text(
                                '${actualWeight.toStringAsFixed(1)}kg',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= data.sessions.length) {
                                return const Text('');
                              }
                              final date = data.sessions[index].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('d/M').format(date),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        // Reps line — left axis, theme primary colour.
                        LineChartBarData(
                          spots:
                              data.sessions
                                  .asMap()
                                  .entries
                                  .map(
                                    (e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.reps.toDouble(),
                                    ),
                                  )
                                  .toList(),
                          isCurved: true,
                          color: theme.colorScheme.primary,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                        ),
                        // Weight line — normalised to reps scale, orange.
                        LineChartBarData(
                          spots:
                              data.sessions.asMap().entries.map((e) {
                                final normalized =
                                    repsRange == 0 || weightRange == 0
                                        ? minReps
                                        : minReps +
                                            (e.value.maxWeight - minWeight) *
                                                repsRange /
                                                weightRange;
                                return FlSpot(e.key.toDouble(), normalized);
                              }).toList(),
                          isCurved: true,
                          color: Colors.orange,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(AppLocalizations.of(context)!.reps, theme.colorScheme.primary),
                    const SizedBox(width: 16),
                    _buildLegendItem(AppLocalizations.of(context)!.weight, Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickStat(
                      AppLocalizations.of(context)!.maxWeight,
                      '${data.sessions.map((s) => s.maxWeight).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} kg',
                      theme,
                    ),
                    _buildQuickStat(
                      AppLocalizations.of(context)!.avgSets,
                      (data.sessions
                                  .map((s) => s.setCount)
                                  .reduce((a, b) => a + b) /
                              data.sessions.length)
                          .toStringAsFixed(1),
                      theme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === NUTRITION TAB ===

  Widget _buildNutritionTab(ThemeData theme) {
    if (_nutritionLoading) return const Center(child: CircularProgressIndicator());
    final calorieGoal = context.watch<UserGoalsProvider>().calorieGoal;

    return RefreshIndicator(
      onRefresh: _loadNutritionData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeRangeSelector(
              theme,
              selectedRange: _nutritionRange,
              customStart: _nutritionCustomStart,
              customEnd: _nutritionCustomEnd,
              onChanged: (range, {customStart, customEnd}) {
                setState(() {
                  _nutritionRange = range;
                  _nutritionCustomStart = customStart;
                  _nutritionCustomEnd = customEnd;
                });
                _loadNutritionData();
              },
            ),
            const SizedBox(height: 24),

            if (_dailyData.isNotEmpty) ...[
              _buildNutritionSummaryStats(theme, calorieGoal),
              const SizedBox(height: 24),

              _buildCalorieTrendChart(theme, calorieGoal),
              const SizedBox(height: 24),
            ],

            if (_weightRecords.isNotEmpty && _dailyData.isNotEmpty) ...[
              PremiumGate(child: _buildWeightCorrelationChart(theme)),
              const SizedBox(height: 24),
            ],

            if (_dailyData.isNotEmpty) ...[_buildWeeklyAverages(theme)],

            if (_dailyData.isEmpty)
              _buildEmptyState(
                theme,
                Icons.restaurant,
                AppLocalizations.of(context)!.noNutritionDataYet,
                AppLocalizations.of(context)!.logMealsProgress,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSummaryStats(ThemeData theme, int calorieGoal) {
    final avgCalories =
        _dailyData.map((d) => d.calories).reduce((a, b) => a + b) /
        _dailyData.length;
    final avgProtein =
        _dailyData.map((d) => d.protein).reduce((a, b) => a + b) /
        _dailyData.length;
    final avgCarbs =
        _dailyData.map((d) => d.carbs).reduce((a, b) => a + b) /
        _dailyData.length;
    final avgFat =
        _dailyData.map((d) => d.fat).reduce((a, b) => a + b) /
        _dailyData.length;

    final daysOnTarget =
        _dailyData.where((d) {
          final diff = (d.calories - calorieGoal).abs();
          return diff <= calorieGoal * 0.1;
        }).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.summaryStatistics,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    AppLocalizations.of(context)!.avgCalories,
                    avgCalories.toStringAsFixed(0),
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    AppLocalizations.of(context)!.daysOnTarget,
                    '$daysOnTarget/${_dailyData.length}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMacroStat(
                    AppLocalizations.of(context)!.proteinLabel,
                    avgProtein.toStringAsFixed(0),
                    Colors.red,
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildMacroStat(
                    AppLocalizations.of(context)!.carbsLabel,
                    avgCarbs.toStringAsFixed(0),
                    Colors.blue,
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildMacroStat(
                    AppLocalizations.of(context)!.fatLabel,
                    avgFat.toStringAsFixed(0),
                    Colors.green,
                    theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieTrendChart(ThemeData theme, int calorieGoal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.calorieTrend,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _dailyData.length > 60 ? 14 : _dailyData.length > 14 ? 7 : _dailyData.length > 7 ? 3 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _dailyData.length) {
                            return const Text('');
                          }
                          final date = _dailyData[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                DateFormat('d.M').format(date),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        _dailyData.length,
                        (i) => FlSpot(i.toDouble(), calorieGoal.toDouble()),
                      ),
                      isCurved: false,
                      color: Colors.grey,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      dashArray: [5, 5],
                    ),
                    LineChartBarData(
                      spots:
                          _dailyData.asMap().entries.map((e) {
                            return FlSpot(
                              e.key.toDouble(),
                              e.value.calories.toDouble(),
                            );
                          }).toList(),
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(AppLocalizations.of(context)!.actual, theme.colorScheme.primary),
                const SizedBox(width: 16),
                _buildLegendItem(AppLocalizations.of(context)!.goal, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCorrelationChart(ThemeData theme) {
    final correlationData = <CorrelationPoint>[];

    for (final weight in _weightRecords) {
      final matchingDay = _dailyData.firstWhere(
        (d) =>
            d.date.year == weight.date.year &&
            d.date.month == weight.date.month &&
            d.date.day == weight.date.day,
        orElse:
            () => DailyNutritionData(
              date: weight.date,
              calories: 0,
              protein: 0,
              carbs: 0,
              fat: 0,
            ),
      );

      if (matchingDay.calories > 0) {
        correlationData.add(
          CorrelationPoint(
            date: weight.date,
            weight: weight.weight,
            calories: matchingDay.calories,
          ),
        );
      }
    }

    if (correlationData.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.weightCalorieCorrelation,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)} kg',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()} cal',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= correlationData.length) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat(
                                'M/d',
                              ).format(correlationData[index].date),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots:
                          correlationData.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value.weight);
                          }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: () {
                        final minWeight = correlationData
                            .map((c) => c.weight)
                            .reduce((a, b) => a < b ? a : b);
                        final maxWeight = correlationData
                            .map((c) => c.weight)
                            .reduce((a, b) => a > b ? a : b);
                        final minCal = correlationData
                            .map((c) => c.calories)
                            .reduce((a, b) => a < b ? a : b);
                        final maxCal = correlationData
                            .map((c) => c.calories)
                            .reduce((a, b) => a > b ? a : b);
                        final calRange = maxCal - minCal;
                        final weightRange = maxWeight - minWeight;
                        return correlationData.asMap().entries.map((e) {
                          final normalizedCal =
                              calRange == 0
                                  ? (minWeight + maxWeight) / 2
                                  : minWeight +
                                      (e.value.calories - minCal) *
                                          weightRange /
                                          calRange;
                          return FlSpot(e.key.toDouble(), normalizedCal);
                        }).toList();
                      }(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(AppLocalizations.of(context)!.weight, Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem(AppLocalizations.of(context)!.calories, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyAverages(ThemeData theme) {
    final Map<int, List<DailyNutritionData>> weeklyData = {};

    for (final day in _dailyData) {
      final weekNum = _getWeekNumber(day.date);
      weeklyData.putIfAbsent(weekNum, () => []).add(day);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.weeklyAverages,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ...weeklyData.entries.map((entry) {
              final weekData = entry.value;
              final avgCal =
                  weekData.map((d) => d.calories).reduce((a, b) => a + b) /
                  weekData.length;

              final firstDay = weekData.first.date;
              final lastDay = weekData.last.date;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${DateFormat('MMM d').format(firstDay)} - ${DateFormat('MMM d').format(lastDay)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${avgCal.toStringAsFixed(0)} ${AppLocalizations.of(context)!.calPerDay}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // === SHARED WIDGETS ===

  Widget _buildTimeRangeSelector(
    ThemeData theme, {
    required TimeRange selectedRange,
    DateTime? customStart,
    DateTime? customEnd,
    required void Function(TimeRange range, {DateTime? customStart, DateTime? customEnd}) onChanged,
  }) {
    final hasPremium = context.watch<AccessProvider>().hasPremiumAccess;

    Widget premiumChip(String label, TimeRange range) => ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (!hasPremium) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock, size: 12),
              ],
            ],
          ),
          selected: selectedRange == range,
          onSelected: (_) {
            if (!hasPremium) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            } else {
              onChanged(range);
            }
          },
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.timeRange,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(AppLocalizations.of(context)!.sevenDays),
                  selected: selectedRange == TimeRange.week,
                  onSelected: (_) => onChanged(TimeRange.week),
                ),
                premiumChip(AppLocalizations.of(context)!.thirtyDays, TimeRange.month),
                premiumChip(AppLocalizations.of(context)!.ninetyDays, TimeRange.threeMonths),
                premiumChip(AppLocalizations.of(context)!.allTime, TimeRange.allTime),
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppLocalizations.of(context)!.custom),
                      if (!hasPremium) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock, size: 12),
                      ],
                    ],
                  ),
                  selected: selectedRange == TimeRange.custom,
                  onSelected: (_) async {
                    if (!hasPremium) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaywallScreen()),
                      );
                      return;
                    }
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 30)),
                        end: DateTime.now(),
                      ),
                    );
                    if (picked != null) {
                      onChanged(TimeRange.custom, customStart: picked.start, customEnd: picked.end);
                    }
                  },
                ),
              ],
            ),
            if (selectedRange == TimeRange.custom &&
                customStart != null &&
                customEnd != null) ...[
              const SizedBox(height: 8),
              Text(
                '${DateFormat('MMM d, y').format(customStart)} - ${DateFormat('MMM d, y').format(customEnd)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(
    String label,
    String value,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(
          '${value}g',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// === DATA MODELS ===

class ExerciseProgressData {
  final String exerciseName;
  final List<ExerciseSessionData> sessions;

  ExerciseProgressData({required this.exerciseName, required this.sessions});
}

class ExerciseSessionData {
  final DateTime date;
  final double totalVolume;
  final double maxWeight;
  final int totalReps;
  final int setCount;
  final int reps;

  ExerciseSessionData({
    required this.date,
    required this.totalVolume,
    required this.maxWeight,
    required this.totalReps,
    required this.setCount,
    required this.reps,
  });
}

class WorkoutFrequencyData {
  final int totalWorkouts;
  final Map<int, int> weeklyWorkouts;
  final int currentStreak;
  final int longestStreak;
  final double averagePerWeek;

  WorkoutFrequencyData({
    required this.totalWorkouts,
    required this.weeklyWorkouts,
    required this.currentStreak,
    required this.longestStreak,
    required this.averagePerWeek,
  });
}

class DailyNutritionData {
  final DateTime date;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  DailyNutritionData({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class CorrelationPoint {
  final DateTime date;
  final double weight;
  final int calories;

  CorrelationPoint({
    required this.date,
    required this.weight,
    required this.calories,
  });
}
