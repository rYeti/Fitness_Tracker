// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get other => 'Other';

  @override
  String get sedentary => 'Sedentary';

  @override
  String get lightlyActive => 'Lightly Active';

  @override
  String get moderatelyActive => 'Moderately Active';

  @override
  String get veryActive => 'Very Active';

  @override
  String get extremelyActive => 'Extremely Active';

  @override
  String get weightLoss => 'Weight Loss';

  @override
  String get muscleGain => 'Muscle Gain';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get food => 'Food';

  @override
  String get gym => 'Gym';

  @override
  String get progress => 'Progress';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get refresh => 'Refresh';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get age => 'Age';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get dailyCalorieGoal => 'Daily Calorie Goal';

  @override
  String get save => 'Save';

  @override
  String get saveCalorieGoal => 'Calorie goal saved';

  @override
  String addFood(Object category) {
    return '$category';
  }

  @override
  String get scanBarcode => 'Scan Barcode';

  @override
  String get nutritionProgress => 'Nutrition Progress';

  @override
  String get foodDetails => 'Food Details';

  @override
  String searchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get pleaseEnterValidAgeAndHeight =>
      'Please enter valid age and height';

  @override
  String get pleaseEnterValidNumber => 'Please enter a valid number';

  @override
  String get calculatedAndSavedCalorieGoal =>
      'Calculated and saved calorie goal';

  @override
  String failedToSaveProfile(Object error) {
    return 'Failed to save profile: $error';
  }

  @override
  String failedToUpdateCalorieGoal(Object error) {
    return 'Failed to update calorie goal: $error';
  }

  @override
  String failedToLoadData(Object error) {
    return 'Failed to load data: $error';
  }

  @override
  String get sex => 'Sex';

  @override
  String get activity => 'Activity';

  @override
  String get goal => 'Goal';

  @override
  String get cancel => 'Cancel';

  @override
  String get addCustomFood => 'Add a custom food';

  @override
  String get foodName => 'Food Name';

  @override
  String get calories => 'Calories';

  @override
  String get protein => 'Protein (g)';

  @override
  String get carbs => 'Carbs (g)';

  @override
  String get fat => 'Fat (g)';

  @override
  String get addedSuccessfully => 'added successfully!';

  @override
  String get pleaseEnterAName => 'Please enter a name';

  @override
  String get pleaseEnterCalories => 'Please enter calories';

  @override
  String get foodTracker => 'Tracker';

  @override
  String get proteinLabel => 'Protein';

  @override
  String get carbsLabel => 'Carbs';

  @override
  String get fatLabel => 'Fat';

  @override
  String get ok => 'OK';

  @override
  String get addFailed => 'Failed to add';

  @override
  String get nutritionInformation => 'Nutrition Information';

  @override
  String get portionSize => 'Portion size';

  @override
  String get quantityInGrams => 'Quantity in grams';

  @override
  String get addToTodayLog => 'Add to today\'s log';

  @override
  String get mealCategory => 'Category';

  @override
  String get addToLog => 'Add to log';

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnacks => 'Snacks';

  @override
  String get searchForFood => 'Search for food';

  @override
  String get recentEatenAtThisMeal => 'Eaten at this meal';

  @override
  String get recentOtherFoods => 'Other foods';

  @override
  String get recentlyAdded => 'Recently Added';

  @override
  String addedToRecentFoods(Object name) {
    return '$name added to recent foods';
  }

  @override
  String get noFoodAdded => 'No foods added yet';

  @override
  String get calculateAndSave => 'Calculated and saved calorie goal';

  @override
  String get workoutName => 'Workout name';

  @override
  String get createWorkout => 'Create Workout';

  @override
  String get workoutSavedSuccessfully => 'Workout saved successfully';

  @override
  String get pleaseEnterWorkoutName => 'Please enter a workout name';

  @override
  String get pleaseEnterAtLeastOneWorkoutDay =>
      'Please enter at least one workout day in the cycle';

  @override
  String get pleaseSelectStartDate => 'Please select a start date';

  @override
  String dayRestDay(int day) {
    return 'Day $day: Rest Day';
  }

  @override
  String dayWorkout(int day, String workout) {
    return 'Day $day: $workout';
  }

  @override
  String get noExercisesYet => 'No exercises yet';

  @override
  String get addWorkout => 'Add Workout';

  @override
  String get addRestDay => 'Add Rest Day';

  @override
  String get addWorkoutDay => 'Add a day';

  @override
  String get workoutNameLabel => 'Workout Name';

  @override
  String get add => 'Add';

  @override
  String get selectStartDate => 'Select Start Date';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String stepXofY(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get noScheduledWorkouts => 'No scheduled workouts';

  @override
  String get unknownWorkout => 'Unknown Workout';

  @override
  String get workouts => 'Workouts';

  @override
  String get seedWorkoutTemplates => 'Seed workout templates (debug)';

  @override
  String get seedingTemplates => 'Seeding templates...';

  @override
  String seedingFailed(Object error) {
    return 'Seeding failed: $error';
  }

  @override
  String get createOrEditWorkouts => 'Create or edit workouts';

  @override
  String get newWorkout => 'New Workout';

  @override
  String get viewWorkouts => 'View workouts';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get noSetTemplates => 'No sets configured';

  @override
  String setTemplatesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String get copyToAll => 'Copy to all';

  @override
  String get repsHelperText => 'e.g., 8-12 or 10';

  @override
  String get addSet => 'Add Set';

  @override
  String get noSetsConfigured => 'No sets configured';

  @override
  String get sets => 'sets';

  @override
  String get reps => 'Reps';

  @override
  String get removeSet => 'Remove Set';

  @override
  String get setLabel => 'Set';

  @override
  String get previous => 'Previous';

  @override
  String get kg => 'KG';

  @override
  String get weight => 'Weight';

  @override
  String get noExercisesForWorkout =>
      'No exercises configured for this workout';

  @override
  String errorLoadingExercises(Object error) {
    return 'Error loading exercises: $error';
  }

  @override
  String get target => 'Target';

  @override
  String get saveWorkout => 'Save workout';

  @override
  String get workoutSaved => 'Workout has been saved.';

  @override
  String get restDay => 'Rest day';

  @override
  String get editWorkout => 'Edit Workout';

  @override
  String get workoutUpdatedSuccessfully => 'Workout updated successfully';

  @override
  String saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get addExercise => 'Add Exercise';

  @override
  String editSet(int setNumber) {
    return 'Edit Set $setNumber';
  }

  @override
  String get noExercisesInWorkout => 'No exercises in this workout';

  @override
  String get setsLabel => 'Sets';

  @override
  String get noSetsFound => 'No sets found for this exercise';

  @override
  String get exerciseName => 'Exercise Name';

  @override
  String get description => 'Description';

  @override
  String get duration => 'Duration';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get repsLabel => 'Reps';

  @override
  String get weightLabel => 'Weight';

  @override
  String get unit => 'Unit';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get addButton => 'Add';

  @override
  String get saveButton => 'Save';

  @override
  String get exercises => 'Exercises';

  @override
  String get noWorkoutsFound => 'No workouts found';

  @override
  String get createFirstWorkoutHint =>
      'Build a plan once, then schedule it as often as you like.';

  @override
  String get setWeightGoal => 'Set Weight Goals';

  @override
  String get calculateBMI => 'Calculate BMI';

  @override
  String get currentWeight => 'Current Weight';

  @override
  String get weightProgress => 'Weight Progress';

  @override
  String get nutrition => 'Nutrition';

  @override
  String get exerciseProgress => 'Exercise Progress';

  @override
  String get weightGoals => 'Weight Goals';

  @override
  String get startingWeight => 'Starting Weight';

  @override
  String get goalWeight => 'Goal Weight';

  @override
  String get enterStartingWeightHint => 'e.g. 90';

  @override
  String get enterGoalWeightHint => 'e.g. 75';

  @override
  String get pleaseEnterValidWeights => 'Please enter valid weights';

  @override
  String get weightGoalsUpdated => 'Weight goals updated';

  @override
  String get saveWeightGoals => 'Save Weight Goals';

  @override
  String get weightGoalsSaved => 'Weight goals saved';

  @override
  String get estimatedCompletion => 'Estimated Completion';

  @override
  String get movingAwayFromGoal => 'Moving away from goal';

  @override
  String get weightStarting => 'Starting';

  @override
  String get weightCurrent => 'Current';

  @override
  String get weightToGo => 'To Go';

  @override
  String get weightComplete => 'Complete';

  @override
  String get weightGained => 'Gained';

  @override
  String get weightGoalLabel => 'Goal';

  @override
  String get completionLessThanWeek => 'Less than a week away!';

  @override
  String completionWeeks(int n) {
    return 'About $n week(s) away';
  }

  @override
  String completionMonths(int n) {
    return 'About $n month(s) away';
  }

  @override
  String completionYears(int n) {
    return 'About $n year(s) away';
  }

  @override
  String errorLoadingProgress(Object error) {
    return 'Error loading progress: $error';
  }

  @override
  String get addBreakfast => 'Add Breakfast';

  @override
  String get addLunch => 'Add Lunch';

  @override
  String get addDinner => 'Add Dinner';

  @override
  String get addSnack => 'Add Snack';

  @override
  String get addWeight => 'Add Weight';

  @override
  String hideFromRecents(String name) {
    return 'Remove $name from recents';
  }

  @override
  String quickAddFood(String name) {
    return 'Quick add $name';
  }

  @override
  String get createTemplateAction => 'Create template';

  @override
  String get allTime => 'All Time';

  @override
  String get dailyCalories => 'Daily Calories';

  @override
  String get todaysWorkout => 'Today\'s Workout';

  @override
  String errorLoadingWorkout(Object error) {
    return 'Error loading workout: $error';
  }

  @override
  String get calorieTrend => 'Calorie Trend';

  @override
  String get avgCalories => 'Avg Calories';

  @override
  String get calPerDay => 'kcal/day';

  @override
  String get noNutritionDataYet => 'No nutrition data yet';

  @override
  String get sevenDays => '7 Days';

  @override
  String get thirtyDays => '30 Days';

  @override
  String get ninetyDays => '90 Days';

  @override
  String get timeRange => 'Time Range';

  @override
  String get weeklyAverages => 'Weekly Averages';

  @override
  String get daysOnTarget => 'Days on Target';

  @override
  String get currentStreak => 'Current Streak';

  @override
  String get longestStreak => 'Longest Streak';

  @override
  String get logMealsProgress => 'Log Meals';

  @override
  String get completeWorkoutsProgress => 'Complete Workouts';

  @override
  String get summaryStatistics => 'Summary';

  @override
  String get myFoods => 'My Foods';

  @override
  String get onlineResults => 'Online Results';

  @override
  String get editPortion => 'Edit Portion';

  @override
  String get portionGrams => 'Portion (g)';

  @override
  String get portionLabel => 'Portion';

  @override
  String get updatePortion => 'Update';

  @override
  String get updateButton => 'Update';

  @override
  String get today => 'Today';

  @override
  String get couldNotReachFoodDatabase => 'Could not reach food database';

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get barcodeNotSupportedOnWeb =>
      'Barcode scanning not supported on web';

  @override
  String get scan => 'Scan';

  @override
  String get retry => 'Retry';

  @override
  String get addToMealTemplate => 'Add to Meal Template';

  @override
  String get mealTemplates => 'Meal Templates';

  @override
  String get createTemplate => 'Create Template';

  @override
  String get createMealTemplate => 'Create Meal Template';

  @override
  String get deleteTemplate => 'Delete Template';

  @override
  String get deleteTemplateQuestion => 'Delete this template?';

  @override
  String get noTemplatesFound => 'No templates found';

  @override
  String get createTemplateHint =>
      'Save a meal you log often and add it in one tap.';

  @override
  String get saveTemplate => 'Save Template';

  @override
  String get templateName => 'Template Name';

  @override
  String get pleaseAddAtLeastOneFood => 'Please add at least one food';

  @override
  String get templateCreatedSuccessfully => 'Template created successfully';

  @override
  String addedToTemplate(String name) {
    return 'Added $name to template';
  }

  @override
  String templateApplied(String name, String category) {
    return '\"$name\" applied to $category';
  }

  @override
  String errorApplyingTemplate(Object error) {
    return 'Error applying template: $error';
  }

  @override
  String errorCreatingTemplate(Object error) {
    return 'Error creating template: $error';
  }

  @override
  String errorScanningBarcode(Object error) {
    return 'Error scanning barcode: $error';
  }

  @override
  String get apply => 'Apply';

  @override
  String get applyTemplate => 'Apply Template';

  @override
  String get applyTemplateQuestion => 'Apply this template?';

  @override
  String get addToTemplate => 'Add to Template';

  @override
  String get addWeightRecord => 'Add Weight Record';

  @override
  String get addWeightRecordTitle => 'Add Weight';

  @override
  String get editWeightRecord => 'Edit Weight Record';

  @override
  String get deleteWeightRecord => 'Delete Weight Record';

  @override
  String get deleteWeightRecordConfirm => 'Delete this weight record?';

  @override
  String get noWeightRecordsYet => 'No weight records yet';

  @override
  String get invalidWeight => 'Invalid weight';

  @override
  String get weightCalorieCorrelation => 'Weight & Calorie Correlation';

  @override
  String get maxWeight => 'Max Weight';

  @override
  String get workoutProgress => 'Workout Progress';

  @override
  String get workoutComplete => 'Workout Complete!';

  @override
  String get workoutNotes => 'Workout Notes';

  @override
  String get coachNote => 'Coach\'s note';

  @override
  String get workoutDayHint => 'e.g. Monday';

  @override
  String get workoutSummaryLabel => 'Workout Summary';

  @override
  String get workoutHasNoExercises => 'This workout has no exercises';

  @override
  String get workoutFrequency => 'Workout Frequency';

  @override
  String get workoutDeleted => 'Workout deleted';

  @override
  String get workoutDetailsUpdated => 'Workout details updated';

  @override
  String get workoutPlanSetActive => 'Plan set as active';

  @override
  String get workoutPlanNameHint => 'e.g. My 5-Day Split';

  @override
  String get workoutAddedToPlan => 'Workout added to plan';

  @override
  String workoutRemovedFromPlan(String name) {
    return '\"$name\" removed from plan';
  }

  @override
  String workoutRenamedTo(String name) {
    return 'Workout renamed to \"$name\"';
  }

  @override
  String workoutPostponedTo(String date) {
    return 'Workout postponed to $date';
  }

  @override
  String deleteWorkoutConfirmation(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteWorkout => 'Delete Workout';

  @override
  String get editWorkoutName => 'Edit Workout Name';

  @override
  String get editWorkoutsTitle => 'Edit Workouts';

  @override
  String get editWorkoutDetailsTooltip => 'Edit workout details';

  @override
  String get manageWorkouts => 'Manage Workouts';

  @override
  String get createFirstWorkout => 'Create your first workout';

  @override
  String get noWorkoutsAddedYet => 'No workouts added yet';

  @override
  String get noWorkoutsAvailableToAdd => 'No workouts available to add';

  @override
  String get noWorkoutsInPlanYet => 'No workouts in this plan yet';

  @override
  String get noWorkoutPlansFound => 'No workout plans found';

  @override
  String get noWorkoutDataYet => 'No workout data yet';

  @override
  String get addWorkoutToPlanTitle => 'Add Workout to Plan';

  @override
  String get addWorkoutsToBuildCycle => 'Add workouts to build your cycle';

  @override
  String get removeWorkoutFromPlan => 'Remove from Plan';

  @override
  String get removeWorkoutFromPlanTooltip => 'Remove workout from plan';

  @override
  String removeWorkoutFromPlanConfirm(String name) {
    return 'Remove \"$name\" from plan?';
  }

  @override
  String failedToRemoveWorkoutFromPlan(Object error) {
    return 'Failed to remove workout from plan: $error';
  }

  @override
  String get openPlanEditor => 'Open Plan Editor';

  @override
  String get deletePlanTooltip => 'Delete plan';

  @override
  String get setActive => 'Set Active';

  @override
  String get activatePlan => 'Activate Plan';

  @override
  String get active => 'Active';

  @override
  String get activePlanBadge => 'Active';

  @override
  String get noWorkoutDataYetLabel => 'No data yet';

  @override
  String get nameYourWorkoutPlan => 'Name Your Workout Plan';

  @override
  String get chooseMemorableName => 'Choose a memorable name';

  @override
  String get workoutPlanNameHintAlt => 'e.g. Summer Shred';

  @override
  String get buildYourCycle => 'Build Your Cycle';

  @override
  String get stepStart => 'Start';

  @override
  String get stepCycle => 'Cycle';

  @override
  String get whenToBeginProgram => 'When to Begin Program';

  @override
  String get chooseStartDate => 'Choose a start date';

  @override
  String get startDateLabel => 'Start Date';

  @override
  String get scheduledWorkoutLabel => 'Scheduled Workout';

  @override
  String get scheduledForNextDays => 'Scheduled for next days';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get skipped => 'Skipped';

  @override
  String get jumpTo => 'Jump To';

  @override
  String get postponeWorkout => 'Postpone Workout';

  @override
  String get move => 'Move';

  @override
  String get skipWorkout => 'Skip Workout';

  @override
  String get viewLabel => 'View';

  @override
  String dayCycleLength(int n) {
    return '$n-day cycle';
  }

  @override
  String get exerciseFeelingHint => 'How did it feel?';

  @override
  String get exerciseNotes => 'Exercise Notes';

  @override
  String get exerciseRemovedFromWorkout => 'Exercise removed';

  @override
  String get exercisesSummary => 'Exercises';

  @override
  String get noExercisesCount => 'No exercises';

  @override
  String get noPreviousDataForSet => 'No previous data for this set';

  @override
  String get prevExercise => 'Previous Exercise';

  @override
  String get nextExercise => 'Next Exercise';

  @override
  String get nextSet => 'Next Set';

  @override
  String get currentSetLabel => 'Current Set';

  @override
  String get restTimer => 'Rest Timer';

  @override
  String get restTimerSetting => 'Rest Timer';

  @override
  String get restTimerSettingSubtitle => 'Auto-start after completing a set';

  @override
  String get setTypeLabel => 'Set type';

  @override
  String get setTypeNormal => 'Normal';

  @override
  String get setTypeWarmup => 'Warm-up';

  @override
  String get setTypeDropset => 'Drop set';

  @override
  String get setTypeFailure => 'Failure';

  @override
  String get sideLabel => 'Side';

  @override
  String get sideBoth => 'Both';

  @override
  String get sideLeft => 'Left';

  @override
  String get sideRight => 'Right';

  @override
  String get rpeTrackingSetting => 'Track RPE';

  @override
  String get rpeTrackingSettingSubtitle =>
      'Log Rate of Perceived Exertion (6–10) for each set';

  @override
  String get rpeLabel => 'RPE';

  @override
  String get lastTime => 'Last Time';

  @override
  String get actual => 'Actual';

  @override
  String get tapButtonToAddExercises => 'Tap + to add exercises';

  @override
  String get addExercisesToTemplate => 'Add Exercises to Template';

  @override
  String get templateWorkoutLabel => 'Template Workout';

  @override
  String get removeExerciseTitle => 'Remove Exercise';

  @override
  String get removeExerciseTooltip => 'Remove exercise';

  @override
  String get setRemovedFromExercise => 'Set removed';

  @override
  String get setAddedToExercise => 'Set added';

  @override
  String get moreOptions => 'More Options';

  @override
  String get editDetails => 'Edit Details';

  @override
  String get editName => 'Edit Name';

  @override
  String get remove => 'Remove';

  @override
  String get goBack => 'Go Back';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get loading => 'Loading...';

  @override
  String get custom => 'Custom';

  @override
  String get category => 'Category';

  @override
  String get days => 'Days';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get descriptionAndDuration => 'Description & Duration';

  @override
  String get overallWorkoutHint => 'Overall workout feel?';

  @override
  String get completedWorkout => 'Workout completed!';

  @override
  String get startWorkout => 'Start Workout';

  @override
  String get bmiComingSoon => 'BMI coming soon';

  @override
  String get importButton => 'Import';

  @override
  String get importOptions => 'Import Options';

  @override
  String get importFitNotes => 'Import FitNotes';

  @override
  String get importFitNotesHint => 'Import from FitNotes CSV export';

  @override
  String get verifiedFoodBadge => 'Verified ✓';

  @override
  String get adaptiveTdeeTitle => 'Adaptive calorie target';

  @override
  String get adaptiveTdeeEstimate => 'Estimated daily expenditure';

  @override
  String get adaptiveTdeeRecommended => 'Recommended daily target';

  @override
  String adaptiveTdeeBasis(int days) {
    return 'Based on $days days of weight and food logs';
  }

  @override
  String get adaptiveTdeeInsufficient =>
      'Log your weight and food for at least 2 weeks to unlock an adaptive calorie target.';

  @override
  String get adaptiveTdeeUncertainty =>
      'Estimate quality depends on logging consistency — under-logging inflates it.';

  @override
  String get adaptiveTdeeApply => 'Apply as daily goal';

  @override
  String adaptiveTdeeApplied(int kcal) {
    return 'Daily calorie goal updated to $kcal kcal';
  }

  @override
  String get exportSectionLabel => 'Data export';

  @override
  String get exportWorkoutsCsv => 'Export workouts (CSV)';

  @override
  String get exportWeightCsv => 'Export weight history (CSV)';

  @override
  String get exportNutritionCsv => 'Export nutrition (CSV)';

  @override
  String get exportFullJson => 'Export all data (JSON)';

  @override
  String get exportFullJsonHint => 'Complete backup of your local data';

  @override
  String get exportSaved => 'Export saved';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get importingWorkoutHistory => 'Importing workout history...';

  @override
  String get importComplete => 'Import Complete';

  @override
  String get readyToImport => 'Ready to Import';

  @override
  String get noValidDataInFile => 'No valid data found in file';

  @override
  String get selectCsvFile => 'Select CSV File';

  @override
  String get csvSelectFileButton => 'Select File';

  @override
  String get csvImportExercisesButton => 'Import Exercises';

  @override
  String get csvFormatTitle => 'CSV Format';

  @override
  String get csvFormatDescription => 'Import exercises from a CSV file';

  @override
  String get csvCreateWorkoutHint => 'Create workout from CSV';

  @override
  String get csvPleaseSelectFile => 'Please select a file';

  @override
  String get csvImporting => 'Importing...';

  @override
  String get totalWorkouts => 'Total Workouts';

  @override
  String get avgSets => 'Avg Sets';

  @override
  String get avgPerWeek => 'Avg / Week';

  @override
  String get uniqueExercisesLabel => 'Unique Exercises';

  @override
  String get unknownExercise => 'Unknown Exercise';

  @override
  String exerciseXofY(int x, int y) {
    return 'Exercise $x of $y';
  }

  @override
  String exerciseCount(int n) {
    return '$n exercise(s)';
  }

  @override
  String setCount(int n) {
    return '$n set(s)';
  }

  @override
  String exercisesAndSets(int exercises, int sets) {
    return '$exercises exercise(s), $sets set(s)';
  }

  @override
  String exerciseAddedToWorkout(String name) {
    return '$name added to workout';
  }

  @override
  String failedToAddExercise(Object error) {
    return 'Failed to add exercise: $error';
  }

  @override
  String failedToAddSet(Object error) {
    return 'Failed to add set: $error';
  }

  @override
  String failedToRemoveExercise(Object error) {
    return 'Failed to remove exercise: $error';
  }

  @override
  String errorCompletingWorkout(Object error) {
    return 'Error completing workout: $error';
  }

  @override
  String errorUpdatingDetails(Object error) {
    return 'Error updating details: $error';
  }

  @override
  String errorUpdatingName(Object error) {
    return 'Error updating name: $error';
  }

  @override
  String createdExercises(int n) {
    return '$n exercise(s) created';
  }

  @override
  String importedSessions(int n) {
    return '$n session(s) imported';
  }

  @override
  String importedSets(int n) {
    return '$n set(s) imported';
  }

  @override
  String importedWorkoutsCreated(int n) {
    return '$n workout(s) created';
  }

  @override
  String newExercisesWillBeCreated(int n) {
    return '$n new exercise(s) will be created';
  }

  @override
  String sessionsCount(int n) {
    return '$n session(s)';
  }

  @override
  String setsCount(int n) {
    return '$n set(s)';
  }

  @override
  String importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String csvExercisesAdded(int n) {
    return '$n exercise(s) added';
  }

  @override
  String csvExercisesSkipped(int n) {
    return '$n exercise(s) skipped';
  }

  @override
  String get nameLabel => 'Name';

  @override
  String get goodMorning => 'Good morning!';

  @override
  String get goodAfternoon => 'Good afternoon!';

  @override
  String get goodEvening => 'Good evening!';

  @override
  String get onboardingWelcomeSubtitle => 'Your personal fitness companion';

  @override
  String get onboardingCreateAccount => 'Create account';

  @override
  String get profileSetupSkip => 'Set up later';

  @override
  String get onboardingAlreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get onboardingWelcomeBody =>
      'Track your nutrition, workouts and weight all in one place.';

  @override
  String get onboardingFeatureWeight => 'Weight Tracking';

  @override
  String get onboardingProfileTitle => 'About You';

  @override
  String get onboardingProfileSubtitle =>
      'We\'ll use this to personalise your experience';

  @override
  String get onboardingGoalsTitle => 'Your Goals';

  @override
  String get onboardingGoalsSubtitle => 'Tell us what you\'re working towards';

  @override
  String get onboardingSummaryTitle => 'You\'re all set!';

  @override
  String get onboardingSummaryCaloriesLabel => 'Estimated daily calorie target';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get undoSkip => 'Undo Skip';

  @override
  String get replaceExercise => 'Replace Exercise';

  @override
  String get resumeWorkoutTitle => 'Resume workout?';

  @override
  String resumeWorkoutBody(String name) {
    return '\"$name\" was interrupted. Resume where you left off?';
  }

  @override
  String get resumeWorkout => 'Resume';

  @override
  String get discardWorkout => 'Discard';

  @override
  String get removeSupersetLink => 'Remove from superset';

  @override
  String get superset => 'Superset';

  @override
  String get supersetPickHint => 'Select exercises for the superset';

  @override
  String get targetReps => 'Target Reps';

  @override
  String get targetRepsHint => 'e.g., 8-12';

  @override
  String get targetRepsHintLong => 'e.g. 8 - 12';

  @override
  String get createWorkoutPlan => 'Create Workout Plan';

  @override
  String get planName => 'Plan Name';

  @override
  String get planNameHint => 'e.g., Beginner Strength Program';

  @override
  String get create => 'Create';

  @override
  String get foods => 'Foods';

  @override
  String get addFromScheduledWorkouts => 'Add from Scheduled Workouts';

  @override
  String get importCsvWorkouts => 'Import CSV Workouts';

  @override
  String get startTimer => 'Start';

  @override
  String get pauseTimer => 'Pause';

  @override
  String get resetTimer => 'Reset';

  @override
  String get stopTimer => 'Stop';

  @override
  String get restTimeComplete => 'Rest time complete! 💪';

  @override
  String get selectFood => 'Select Food';

  @override
  String doneCount(int count) {
    return 'Done ($count)';
  }

  @override
  String get searchFoods => 'Search Foods';

  @override
  String get noLocalFoodsFound => 'No local foods found';

  @override
  String get enterSearchTermsOnline =>
      'Enter search terms to find foods online';

  @override
  String get noResultsFoundSearch => 'No results found for this search';

  @override
  String get tryUsingMoreGeneralTerms =>
      'Try using more general terms or check spelling';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get noFoodsAdded => 'No foods added yet';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get barcodeNotSupportedMobile =>
      'Barcode scanning is only supported on mobile devices.';

  @override
  String get barcodeNotSupportedWeb =>
      'Barcode scanning is not supported on web';

  @override
  String get selectWorkoutDates => 'Select Workout Dates';

  @override
  String get useSelectedDates => 'Use selected dates';

  @override
  String get searchExercisesHint => 'Search exercises...';

  @override
  String get invalidAgeHeight => 'Please enter valid age and height';

  @override
  String get searchOnlineTab => 'Search Online';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get email => 'Email';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get selectDateOfBirth => 'Select Date of Birth';

  @override
  String get loginToYourAccount => 'Welcome back';

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get noAccountQuestion => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get pleaseSelectDateOfBirth => 'Please select a date of birth';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidEmailFormat => 'Enter a valid email address';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get minimumAgeRequired => 'You must be at least 13 years old';

  @override
  String get freeChoiceMode => 'Free Choice Mode';

  @override
  String get freeChoiceModeSubtitle => 'Pick workouts manually for each day';

  @override
  String get cycleModeSubtitle => 'Workouts follow a repeating cycle';

  @override
  String get switchToFreeChoiceTitle => 'Switch to Free Choice?';

  @override
  String get switchToFreeChoiceBody =>
      'All future scheduled workouts for this plan will be removed. You can pick workouts day by day.';

  @override
  String get switchToCyclePlanTitle => 'Switch to Cycle Plan?';

  @override
  String get switchToCyclePlanBody =>
      'The plan will switch back to cycle mode. No scheduled workouts will be created automatically.';

  @override
  String get confirm => 'Confirm';

  @override
  String addWorkoutForDate(String date) {
    return 'Add workout for $date';
  }

  @override
  String pickWorkoutForDate(String date) {
    return 'Pick workout for $date';
  }

  @override
  String get freeChoiceAddHint =>
      'Add workout templates to choose from each day';

  @override
  String get cyclePattern => 'Cycle Pattern';

  @override
  String get freeChoiceLabel => 'Free Choice';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get profile => 'Profile';

  @override
  String get security => 'Security';

  @override
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get signOutUnsyncedTitle => 'Unsynced changes';

  @override
  String signOutUnsyncedBody(int count) {
    return '$count changes haven\'t reached the server yet. Signing out clears this device\'s copy of your account, so they would be lost — including any exercises you deleted, which would come back.';
  }

  @override
  String get signOutAnyway => 'Sign out anyway';

  @override
  String get createExercise => 'Create Exercise';

  @override
  String get editExercise => 'Edit Exercise';

  @override
  String get createCustomExercise => 'Create custom exercise';

  @override
  String get exerciseType => 'Exercise Type';

  @override
  String get muscleGroupsLabel => 'Muscle Groups';

  @override
  String get exerciseSaved => 'Exercise saved';

  @override
  String get exerciseUpdated => 'Exercise updated';

  @override
  String get exerciseCreated => 'Exercise created';

  @override
  String get exerciseDeleted => 'Exercise deleted';

  @override
  String get deleteExercise => 'Delete Exercise';

  @override
  String deleteExerciseConfirmation(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get selectAtLeastOneMuscleGroup =>
      'Please select at least one muscle group';

  @override
  String get exerciseTypeStrength => 'Strength';

  @override
  String get exerciseTypeCardio => 'Cardio';

  @override
  String get exerciseTypeFlexibility => 'Flexibility';

  @override
  String get exerciseTypeCalisthenics => 'Calisthenics';

  @override
  String get customBadge => 'Custom';

  @override
  String get saveChangesButton => 'Save Changes';

  @override
  String errorSavingExercise(Object error) {
    return 'Error saving exercise: $error';
  }

  @override
  String errorDeletingExercise(Object error) {
    return 'Error deleting exercise: $error';
  }

  @override
  String get newExercise => 'New Exercise';

  @override
  String noExercisesFoundForQuery(String query) {
    return 'No exercises found matching \"$query\"';
  }

  @override
  String get all => 'All';

  @override
  String get muscleGroupChest => 'Chest';

  @override
  String get muscleGroupBack => 'Back';

  @override
  String get muscleGroupShoulders => 'Shoulders';

  @override
  String get muscleGroupBiceps => 'Biceps';

  @override
  String get muscleGroupTriceps => 'Triceps';

  @override
  String get muscleGroupLegs => 'Legs';

  @override
  String get muscleGroupAbs => 'Abs';

  @override
  String get muscleGroupFullBody => 'Full Body';

  @override
  String get exercisesSubtitle => 'Browse, create & edit exercises';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get pause => 'Pause';

  @override
  String get reset => 'Reset';

  @override
  String get selectTrainingDays => 'Select Training Days';

  @override
  String daysSelected(int n) {
    return '$n days selected';
  }

  @override
  String get manageExercises => 'Manage Exercises';

  @override
  String get noResultsFoundForSearch => 'No results found for this search';

  @override
  String get tryMoreGeneralTerms =>
      'Try using more general terms or check spelling';

  @override
  String doneWithCount(int count) {
    return 'Done ($count)';
  }

  @override
  String addingFoodToYours(String name) {
    return 'Adding $name to your foods...';
  }

  @override
  String foodAddedToYours(String name) {
    return '$name added to your foods';
  }

  @override
  String errorAddingFood(Object error) {
    return 'Error adding food: $error';
  }

  @override
  String brandLabel(String brand) {
    return 'Brand: $brand';
  }

  @override
  String get editMealTemplate => 'Edit Meal Template';

  @override
  String get templateUpdatedSuccessfully => 'Template updated successfully';

  @override
  String get barcodeScanningMobileOnly =>
      'Barcode scanning is only supported on mobile devices.';

  @override
  String get barcodeScanningWebNotSupported =>
      'Barcode scanning is not supported on web';

  @override
  String get setUpdated => 'Set updated';

  @override
  String failedToRemoveSet(Object error) {
    return 'Failed to remove set: $error';
  }

  @override
  String failedToUpdateSet(Object error) {
    return 'Failed to update set: $error';
  }

  @override
  String workoutPlanCreated(String name) {
    return 'Workout plan \"$name\" created';
  }

  @override
  String failedToCreatePlan(Object error) {
    return 'Failed to create workout plan: $error';
  }

  @override
  String failedToAddWorkout(Object error) {
    return 'Failed to add workout: $error';
  }

  @override
  String deletedWorkoutPlan(String name) {
    return 'Deleted workout plan \"$name\"';
  }

  @override
  String failedToDeletePlan(Object error) {
    return 'Failed to delete plan: $error';
  }

  @override
  String get cannotAddExerciseToUnsavedWorkout =>
      'Cannot add exercise to unsaved workout';

  @override
  String removeExerciseConfirmBody(String name) {
    return 'Are you sure you want to remove \"$name\" from this workout?';
  }

  @override
  String removeSetConfirmBody(int setNumber, String exerciseName) {
    return 'Are you sure you want to remove set $setNumber from \"$exerciseName\"?';
  }

  @override
  String deletePlanConfirmBody(String name) {
    return 'Are you sure you want to delete \"$name\"? This will remove the plan but keep the workouts.';
  }

  @override
  String get pleaseEnterDuration => 'Please enter duration';

  @override
  String get pleaseEnterValidDuration => 'Please enter a valid duration';

  @override
  String get minutesSuffix => 'minutes';

  @override
  String get selectMuscleGroup => 'Select Muscle Group';

  @override
  String get selectExercise => 'Select Exercise';

  @override
  String get extendedNutrientsTitle => 'Detailed Nutrition';

  @override
  String get extendedNutrientsMacrosSection => 'Macros Detail';

  @override
  String get extendedNutrientsVitaminsSection => 'Vitamins';

  @override
  String get extendedNutrientsMineralsSection => 'Minerals';

  @override
  String get nutrientFiber => 'Fibre';

  @override
  String get nutrientSugar => 'Sugar';

  @override
  String get nutrientSaturatedFat => 'Saturated Fat';

  @override
  String get nutrientSalt => 'Salt';

  @override
  String get nutrientSodium => 'Sodium';

  @override
  String get nutrientVitaminA => 'Vitamin A';

  @override
  String get nutrientVitaminC => 'Vitamin C';

  @override
  String get nutrientVitaminD => 'Vitamin D';

  @override
  String get nutrientVitaminE => 'Vitamin E';

  @override
  String get nutrientVitaminK => 'Vitamin K';

  @override
  String get nutrientVitaminB1 => 'Vitamin B1 (Thiamine)';

  @override
  String get nutrientVitaminB2 => 'Vitamin B2 (Riboflavin)';

  @override
  String get nutrientVitaminB3 => 'Vitamin B3 (Niacin)';

  @override
  String get nutrientVitaminB6 => 'Vitamin B6';

  @override
  String get nutrientVitaminB9 => 'Vitamin B9 (Folate)';

  @override
  String get nutrientVitaminB12 => 'Vitamin B12';

  @override
  String get nutrientCalcium => 'Calcium';

  @override
  String get nutrientIron => 'Iron';

  @override
  String get nutrientMagnesium => 'Magnesium';

  @override
  String get nutrientPotassium => 'Potassium';

  @override
  String get nutrientZinc => 'Zinc';

  @override
  String get unitMg => 'mg';

  @override
  String get unitUg => 'µg';

  @override
  String get premiumFeatureTitle => 'Premium Feature';

  @override
  String get premiumFeatureBody =>
      'Upgrade to Premium to see detailed nutrition data including vitamins and minerals.';

  @override
  String get premiumBadge => 'Premium';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';

  @override
  String get goPremiumBannerTitle => 'Go Premium';

  @override
  String get goPremiumBannerSubtitle =>
      'Unlimited plans, full history & analytics';

  @override
  String get goPremiumBannerButton => 'Upgrade';

  @override
  String get paywallUnlockPotential => 'Unlock your full potential';

  @override
  String get paywallNoPlans => 'No plans available.';

  @override
  String get paywallRestorePurchases => 'Restore purchases';

  @override
  String get paywallError =>
      'Something went wrong loading the paywall. Please try again.';

  @override
  String get noActivePurchasesFound =>
      'No active purchases found for this account.';

  @override
  String get paywallFinePrint =>
      'Cancel anytime. Subscription auto-renews until cancelled.';

  @override
  String paywallFreeTrial(String duration) {
    return '$duration free trial';
  }

  @override
  String paywallIntroPrice(String price, String duration) {
    return '$price for $duration';
  }

  @override
  String get paywallPeriodDay => 'day';

  @override
  String get paywallPeriodDays => 'days';

  @override
  String get paywallPeriodWeek => 'week';

  @override
  String get paywallPeriodWeeks => 'weeks';

  @override
  String get paywallPeriodMonth => 'month';

  @override
  String get paywallPeriodMonths => 'months';

  @override
  String get paywallPeriodYear => 'year';

  @override
  String get paywallPeriodYears => 'years';

  @override
  String get paywallFeatureProgress => 'All-time history & custom date ranges';

  @override
  String get paywallFeaturePlans => 'Unlimited workout plans';

  @override
  String get paywallFeatureTemplates => 'Unlimited meal templates';

  @override
  String get paywallFeatureCorrelation => 'Weight & calorie correlation chart';

  @override
  String get paywallFeatureGraphs => 'Exercise progress graphs';

  @override
  String get paywallFeatureExport => 'Export workout data (CSV)';

  @override
  String get paywallFeatureNutrition =>
      'Detailed nutrition breakdown — vitamins & minerals';

  @override
  String get paywallFeatureCustomFoods =>
      'Unlimited custom foods (free: up to 10)';

  @override
  String get paywallFeatureLongPlans =>
      'Extended workout plan durations — up to 1 year';

  @override
  String get paywallFeatureFreeChoice =>
      'Free choice workout mode — schedule any workout on any day';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountWarning =>
      'This will permanently delete your account and all your data including workouts, meals, and weight history. Any trainer relationships will also be removed. This cannot be undone.';

  @override
  String get deleteAccountError =>
      'Failed to delete account. Please check your password and try again.';

  @override
  String get planDurationLabel => 'Plan Duration';

  @override
  String nWeeks(int count) {
    return '$count weeks';
  }

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get resetYourPassword => 'Reset your password';

  @override
  String get forgotPasswordDescription =>
      'Enter the email address linked to your account and we\'ll send you a reset link.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String resetLinkSentBody(String email) {
    return 'If an account is linked to $email, you\'ll receive a reset link shortly.';
  }

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncNowSubtitle => 'Push all pending local changes to the server';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String syncFailed(Object error) {
    return 'Sync failed: $error';
  }

  @override
  String get restoreFromServer => 'Restore from server';

  @override
  String get restoreFromServerSubtitle => 'Download server data to this device';

  @override
  String get restoreComplete => 'Restore complete';

  @override
  String restoreFailed(Object error) {
    return 'Restore failed: $error';
  }

  @override
  String get premiumUpgradeMultiplePlans =>
      'Premium — upgrade to create unlimited plans';

  @override
  String get freeTemplateLimitReached =>
      'Free limit reached — upgrade to create more than 3 templates';

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String get sortResults => 'Sort results';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get sortRelevance => 'Relevance';

  @override
  String get sortHighestProtein => 'Highest protein';

  @override
  String get sortLowestCalories => 'Lowest calories';

  @override
  String get sortLowestCarbs => 'Lowest carbs';

  @override
  String get sortLowestFat => 'Lowest fat';

  @override
  String get sortHighestFibre => 'Highest fibre';

  @override
  String get tooManyRequests =>
      'Too many requests — please wait a moment and try again.';

  @override
  String get couldNotFetchProductData =>
      'Could not fetch product data. Please try again.';

  @override
  String get unknown => 'Unknown';

  @override
  String get requestedPlanNotFound =>
      'Requested plan not found and no plans exist';

  @override
  String get requestedPlanNotFoundShowingAll =>
      'Requested plan not found — showing all plans';

  @override
  String foundTemplateWorkouts(int count) {
    return 'Found $count template workout(s) from your scheduled workouts that can be added to this plan.';
  }

  @override
  String get addWorkoutsToPlanHint =>
      'To add workouts to this plan:\n\n1. Import workout templates using the CSV import button\n2. Use the + button to add imported workouts to this plan\n3. Scheduled workouts are separate from plan templates';

  @override
  String get syncSectionLabel => 'Sync';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get resetPasswordDescription =>
      'Enter and confirm your new password below.';

  @override
  String get resetPasswordButton => 'Reset Password';

  @override
  String get passwordResetSuccess =>
      'Password updated successfully. You can now log in.';

  @override
  String get passwordResetExpired =>
      'This link has expired or has already been used.';

  @override
  String get templateBatchWeight => 'Total batch weight (g)';

  @override
  String get templateBatchWeightHint =>
      'e.g. weigh your full pot / tray after cooking';

  @override
  String templateFullBatch(String weight, String calories) {
    return 'Full batch: ${weight}g • $calories kcal';
  }

  @override
  String get templatePortionLabel => 'Your portion (g)';

  @override
  String get templateLogFull => 'Log Full Template';

  @override
  String get templateLogPortion => 'Log Portion';

  @override
  String get coachChat => 'Your coach';

  @override
  String get coachChatSubtitle => 'Message your trainer';

  @override
  String get coachChatNoCoach => 'No coach yet';

  @override
  String get coachChatNoCoachBody =>
      'When a trainer adds you to their roster you can message them here.';

  @override
  String get coachChatEmpty => 'No messages yet';

  @override
  String get coachChatEmptyBody =>
      'Ask your coach anything — they will see it right away.';

  @override
  String get coachChatLoadError => 'Could not load this conversation.';

  @override
  String get chatComposerHint => 'Message';

  @override
  String get chatSendMessage => 'Send message';

  @override
  String get chatSending => 'Sending';

  @override
  String get chatFailedRetry => 'Failed to send — tap to retry';

  @override
  String get chatUndecryptable => 'Message can\'t be decrypted on this device';

  @override
  String get chatNewMessage => 'New message';

  @override
  String get chatReconnecting => 'Reconnecting…';

  @override
  String get chatOffline => 'Offline';

  @override
  String chatUnreadCount(Object count) {
    return '$count unread';
  }

  @override
  String get chatSendFailed =>
      'Message not sent. Check your connection and try again.';

  @override
  String get chatDismiss => 'Dismiss';

  @override
  String get chatAttachmentsUnavailable => 'Attachments are not available yet';

  @override
  String get chatAttachPhoto => 'Photo';

  @override
  String get chatAttachCamera => 'Camera';

  @override
  String get chatAttachDocument => 'Document';

  @override
  String get chatAttachmentTooLarge => 'File is too large to attach';

  @override
  String get chatPhotoLabel => 'Photo';

  @override
  String get chatDocumentLabel => 'Document';

  @override
  String get chatUnsupportedAttachment =>
      'This attachment isn\'t supported on this device yet';

  @override
  String get chatAttachmentUploading => 'uploading';

  @override
  String get chatAttachmentUploadFailed => 'upload failed, double tap to retry';

  @override
  String get chatAttachmentDownloading => 'downloading';

  @override
  String get chatAttachmentDownloadFailed =>
      'could not be downloaded, double tap to retry';

  @override
  String get chatAttachmentExpired => 'No longer available';

  @override
  String get chatAttachmentTapToDownload => 'tap to download';

  @override
  String get chatAttachmentOpen => 'Open';

  @override
  String get chatVoiceNoteLabel => 'Voice message';

  @override
  String get chatAudioLabel => 'Audio';

  @override
  String get chatAttachmentPlay => 'Play';

  @override
  String get chatAttachmentPause => 'Pause';

  @override
  String get chatAttachVoiceNote => 'Voice note';

  @override
  String get chatAttachAudio => 'Audio file';

  @override
  String get chatRecording => 'Recording';

  @override
  String get chatRecordingCancel => 'Cancel recording';

  @override
  String get chatMicUnavailable => 'Microphone access was denied';

  @override
  String get chatSendVoiceNote => 'Send voice note';

  @override
  String get chatVideoLabel => 'Video';

  @override
  String get chatAttachVideo => 'Video';

  @override
  String get chatStorageTitle => 'Chat storage';

  @override
  String get chatStorageLoading => 'Loading storage usage';

  @override
  String get chatStorageLoadError => 'Could not load storage usage.';

  @override
  String get chatStorageEmpty => 'No chat media stored';

  @override
  String get chatStorageEmptyBody =>
      'Photos, videos and files you\'ve received will appear here once downloaded.';

  @override
  String get chatStorageTotalUsed => 'Total used';

  @override
  String get chatStorageByThread => 'By conversation';

  @override
  String get chatStorageClearAll => 'Clear all';

  @override
  String get chatStorageClear => 'Clear';

  @override
  String get chatStorageClearThreadTitle => 'Clear this conversation\'s media?';

  @override
  String chatStorageClearThreadBody(String name) {
    return 'This removes downloaded photos, videos and files for $name from this device. They can be downloaded again if still available.';
  }

  @override
  String get chatStorageClearAllTitle => 'Clear all chat media?';

  @override
  String get chatStorageClearAllBody =>
      'This removes every downloaded photo, video and file from this device across all conversations. They can be downloaded again if still available.';

  @override
  String get chatUnavailable => 'Messaging is unavailable';

  @override
  String get chatUnavailableBody =>
      'Chat could not start on this device. Restart the app, and if it keeps happening let support know.';

  @override
  String get trainerConsole => 'Trainer Console';

  @override
  String get trainerConsoleSubtitle => 'Manage your clients';

  @override
  String get consoleNavDashboard => 'Dashboard';

  @override
  String get consoleNavMessages => 'Messages';

  @override
  String get consoleNavBuilder => 'Workout Builder';

  @override
  String get consoleNavNutrition => 'Nutrition';

  @override
  String get consoleNavSessionReview => 'Session Review';

  @override
  String get consoleNavDashboardShort => 'Home';

  @override
  String get consoleNavMessagesShort => 'Chat';

  @override
  String get consoleNavBuilderShort => 'Workouts';

  @override
  String get consoleNavNutritionShort => 'Nutrition';

  @override
  String get consoleNavSessionReviewShort => 'Review';

  @override
  String get consoleMyTraining => 'My training';

  @override
  String get consoleSwitchToMyTraining => 'Switch to my training';

  @override
  String get consoleLoading => 'Loading';

  @override
  String get trainerAccessOnly => 'Trainer access only';

  @override
  String get trainerAccessOnlyBody =>
      'This area is for trainers managing clients. Trainer accounts are chosen when the account is created — an existing account can\'t be switched over.';

  @override
  String get accountType => 'Account type';

  @override
  String get accountTypeTrainee => 'For myself';

  @override
  String get accountTypeTrainer => 'Coaching clients';

  @override
  String get accountTypeLockedNote =>
      'A trainer account opens the Trainer Console. This can\'t be changed later — an existing account can\'t be switched over.';

  @override
  String get dashboardLoading => 'Loading dashboard';

  @override
  String get rosterLoading => 'Loading clients';

  @override
  String get kpisLoading => 'Loading summary';

  @override
  String get clientsHeading => 'Clients';

  @override
  String get kpiActiveClients => 'Active clients';

  @override
  String get kpiAvgAdherence => 'Avg adherence';

  @override
  String get kpiSessionsThisWeek => 'Sessions this week';

  @override
  String get rosterEmptyTitle => 'No clients yet';

  @override
  String get rosterEmptyBody =>
      'Create an invite code and share it with your first client. They enter it under \"Join a trainer\".';

  @override
  String get rosterGridView => 'Grid view';

  @override
  String get rosterTableView => 'Table view';

  @override
  String get rosterColumnClient => 'CLIENT';

  @override
  String get rosterColumnProgram => 'PROGRAM';

  @override
  String get rosterColumnAdherence => 'ADHERENCE';

  @override
  String get rosterColumnLastSession => 'LAST SESSION';

  @override
  String get noActivePlan => 'No active plan';

  @override
  String get noSessionsYet => 'No sessions yet';

  @override
  String lastSessionOn(String date) {
    return 'Last: $date';
  }

  @override
  String get noData => 'No data';

  @override
  String get invite => 'Invite';

  @override
  String get inviteAClient => 'Invite a client';

  @override
  String get inviteSheetBody =>
      'Share the code with your client. They enter it under \"Join a trainer\" in their app.';

  @override
  String get createInviteCode => 'Create invite code';

  @override
  String get createNewInviteCode => 'Create a new invite code';

  @override
  String get copyCode => 'Copy code';

  @override
  String get inviteCodeCopied => 'Invite code copied';

  @override
  String inviteCodeSemantics(String code) {
    return 'Invite code $code';
  }

  @override
  String get inviteExpiresInSevenDays => 'Expires in 7 days.';

  @override
  String copyInviteCode(String code) {
    return 'Copy $code';
  }

  @override
  String withdrawInviteCode(String code) {
    return 'Withdraw $code';
  }

  @override
  String get outstandingInvites => 'Outstanding invites';

  @override
  String get outstandingInvitesBody =>
      'Each of these holds a seat until it is used or withdrawn.';

  @override
  String get inviteExpired => 'Expired';

  @override
  String get inviteExpiresToday => 'Expires today';

  @override
  String inviteExpiresInDays(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expires in $days days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get withdrawInviteTitle => 'Withdraw this invite?';

  @override
  String withdrawInviteBody(String code) {
    return '$code will stop working and its seat is freed. Anyone you already sent it to will need a new code.';
  }

  @override
  String get keep => 'Keep';

  @override
  String get withdraw => 'Withdraw';

  @override
  String get inviteBlockedLapsed => 'Renew your licence to invite clients.';

  @override
  String inviteBlockedFull(int seats) {
    return 'All $seats seats are in use. Withdraw an invite or upgrade.';
  }

  @override
  String seatMeterUsage(int used, int limit) {
    return '$used of $limit clients';
  }

  @override
  String get seatMeterOverLimit =>
      'Over your plan. Existing clients keep working; you can\'t add more.';

  @override
  String get seatMeterFull => 'Plan full. Free a seat or upgrade to add more.';

  @override
  String seatMeterRemaining(int seats) {
    return '$seats seats left';
  }

  @override
  String seatMeterSemantics(String usage, String caption) {
    return '$usage. $caption';
  }

  @override
  String seatChipSemantics(int used, int limit, String tier) {
    return '$used of $limit client seats used. $tier plan. Open plan settings.';
  }

  @override
  String seatChipTooltip(String tier, int used, int limit) {
    return '$tier — $used/$limit clients';
  }

  @override
  String get licenceTierFree => 'Free';

  @override
  String get licenceTierSolo => 'Solo';

  @override
  String get licenceTierPro => 'Pro';

  @override
  String get licenceTierStudio => 'Studio';

  @override
  String get licenceStatusActive => 'Active';

  @override
  String get licenceStatusTrialing => 'Trial';

  @override
  String get licenceStatusPastDue => 'Payment failed';

  @override
  String get licenceStatusCanceled => 'Cancelled';

  @override
  String get licenceLoading => 'Loading your plan…';

  @override
  String get licenceLoadingLabel => 'Loading your plan';

  @override
  String get yourPlan => 'Your plan';

  @override
  String get yourPlanSubtitle => 'Seats, billing and invites';

  @override
  String get changePlan => 'Change plan';

  @override
  String planLadderFootnote(int seats) {
    return 'Paid plans include ForgeForm Pro for you and every client on your roster. The free plan covers $seats clients without Pro.';
  }

  @override
  String tierPlanTitle(String tier) {
    return '$tier plan';
  }

  @override
  String get proIncluded => 'Pro included for you and every client';

  @override
  String get proNotIncluded =>
      'Pro not included — upgrade to cover your clients';

  @override
  String get manageBilling => 'Manage billing';

  @override
  String statusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String tierSeatsAndPro(int seats) {
    return 'Up to $seats clients, Pro included';
  }

  @override
  String get planCurrent => 'Current';

  @override
  String get licenceLapsedBanner =>
      'Your licence has lapsed. Your clients are still here, but you can\'t change their plans and they\'ve lost Pro.';

  @override
  String get licenceRenew => 'Renew';

  @override
  String licenceGraceBanner(String date) {
    return 'Payment failed. Everything keeps working until $date — after that your clients lose Pro.';
  }

  @override
  String get licenceFixPayment => 'Fix payment';

  @override
  String licenceOverLimitBanner(int used, int limit) {
    return 'You have $used clients on a $limit-seat plan. Nobody is removed, but you can\'t add more.';
  }

  @override
  String get licenceUpgrade => 'Upgrade';

  @override
  String licenceFullBanner(int limit, String tier) {
    return 'All $limit seats on your $tier plan are in use.';
  }

  @override
  String traineeProLapsingBanner(String date) {
    return 'Pro through your trainer ends $date. Your data stays put — Pro features just lock.';
  }

  @override
  String get traineeKeepPro => 'Keep Pro';

  @override
  String get inviteFailureSeatLimitReached =>
      'Your plan is full. Upgrade or free up a seat to invite another client.';

  @override
  String get inviteFailureLicenceLapsed =>
      'Your licence has lapsed. Renew it to take on new clients.';

  @override
  String get inviteFailureNotATrainer =>
      'Only a trainer account can invite clients.';

  @override
  String get inviteFailureInvalidCode =>
      'That code doesn\'t match an invite. Check it and try again.';

  @override
  String get inviteFailureExpiredCode =>
      'That invite has expired. Ask your trainer for a new code.';

  @override
  String get inviteFailureSelfInvite => 'That\'s your own invite code.';

  @override
  String get inviteFailureTrainerAtSeatLimit =>
      'Your trainer\'s plan is full. Ask them to free up a seat.';

  @override
  String get inviteFailureTrainerNotEntitled =>
      'Your trainer\'s plan isn\'t active. Ask them to renew it.';

  @override
  String get inviteFailureNetwork =>
      'Couldn\'t reach ForgeForm. Check your connection and try again.';

  @override
  String get authFailureInvalidCredentials => 'Invalid username or password.';

  @override
  String get authFailureRegistrationFailed =>
      'That username or email is already taken.';

  @override
  String get authFailureUnknownAccountType =>
      'That account type isn\'t recognised. Choose one of the options and try again.';

  @override
  String get authFailureNetwork =>
      'Couldn\'t reach ForgeForm. Check your connection and try again.';

  @override
  String get authFailureUnknown => 'Something went wrong. Please try again.';

  @override
  String get resetFailureLinkNoLongerValid =>
      'This link has expired or has already been used.';

  @override
  String inviteFailureSeatLimitReachedDetailed(int seatsUsed, int seatLimit) {
    return 'Your plan covers $seatLimit clients and all $seatsUsed are in use. Upgrade or free up a seat.';
  }

  @override
  String get errorLoadRoster => 'Could not load your clients.';

  @override
  String get errorLoadDashboard => 'Could not load your dashboard.';

  @override
  String get errorLoadClientDetail => 'Could not load this client’s details.';

  @override
  String get errorLoadNutrition => 'Could not load this client’s nutrition.';

  @override
  String get errorLoadSessions => 'Could not load this client’s sessions.';

  @override
  String get errorLoadLicence => 'Could not load your plan.';

  @override
  String get errorLoadWorkoutPlans => 'Could not load workout plans.';

  @override
  String get errorPlanNameRequired => 'Give the plan a name.';

  @override
  String get errorCreatePlan => 'Could not create the plan.';

  @override
  String get errorCreateInvite => 'Could not create an invite. Try again.';

  @override
  String get errorWithdrawInvite =>
      'Could not withdraw that invite. Try again.';

  @override
  String get errorOpenCheckout => 'Could not open checkout. Try again.';

  @override
  String get errorOpenBilling => 'Could not open billing. Try again.';

  @override
  String get clientDetailLoading => 'Loading client details';

  @override
  String get adherence => 'Adherence';

  @override
  String get clientCurrentWeight => 'Current weight';

  @override
  String get change => 'Change';

  @override
  String planStartedOn(String date) {
    return 'Started $date';
  }

  @override
  String get weightTrend => 'Weight trend';

  @override
  String get weightTrendEmptyTitle => 'Not enough weight data';

  @override
  String get weightTrendEmptyBody =>
      'Two or more logged weigh-ins are needed to show a trend.';

  @override
  String entryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String weightTrendSemantics(String from, String to) {
    return 'Weight from $from to $to kilograms';
  }

  @override
  String get attendanceEmptyTitle => 'No attendance data';

  @override
  String get attendanceEmptyBody =>
      'Attendance appears once sessions are scheduled.';

  @override
  String get attendanceByWeek => 'Attendance by week';

  @override
  String attendanceWeekSemantics(String date, int completed, int planned) {
    return 'Week of $date: $completed of $planned sessions';
  }

  @override
  String get strengthEmptyTitle => 'No strength data';

  @override
  String get strengthEmptyBody =>
      'Progression appears once completed sets are logged.';

  @override
  String get strengthProgression => 'Strength progression';

  @override
  String get exercise => 'Exercise';

  @override
  String get todaysMacros => 'Today’s macros';

  @override
  String caloriesOfGoal(int eaten, int goal) {
    return '$eaten / $goal kcal';
  }

  @override
  String get macroSummaryNone => 'No macros logged';

  @override
  String macroSummarySemantics(String protein, String carbs, String fat) {
    return 'Protein ${protein}g, carbs ${carbs}g, fat ${fat}g';
  }

  @override
  String switchClientSemantics(String name) {
    return 'Switch client. Currently $name';
  }

  @override
  String get switchClientHeading => 'SWITCH CLIENT';

  @override
  String get conversationsLoading => 'Loading conversations';

  @override
  String get conversationsLoadError => 'Could not load your conversations.';

  @override
  String get conversationsEmpty => 'No conversations yet';

  @override
  String get conversationsEmptyBody =>
      'Once a client accepts your invite you can message them here.';

  @override
  String get backToConversations => 'Back to conversations';

  @override
  String get pickAConversation => 'Pick a conversation';

  @override
  String get pickAConversationBody =>
      'Choose a client on the left to see your messages.';

  @override
  String get messagesLoading => 'Loading messages';

  @override
  String get trainerThreadEmptyBody =>
      'Say hello — this is the start of your conversation.';

  @override
  String get clientStatsElsewhere =>
      'Client stats appear on the dashboard and client detail screens.';

  @override
  String get nutritionSubtitle => 'Daily intake and 7-day trend';

  @override
  String get nutritionSubtitleNoClient =>
      'Select a client to review their intake';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get nutritionLoading => 'Loading nutrition';

  @override
  String get nutritionNoClientsBody =>
      'Invite your first client to monitor their nutrition.';

  @override
  String get nothingLogged => 'Nothing logged';

  @override
  String nothingLoggedBody(String name) {
    return '$name didn’t log any meals on this day.';
  }

  @override
  String get mealsLogged => 'Meals logged';

  @override
  String get meal => 'Meal';

  @override
  String get noTrendYet => 'No trend yet';

  @override
  String get noTrendYetBody =>
      'Once meals are logged, the 7-day trend appears here.';

  @override
  String get caloriesVsTarget => 'Calories vs. target';

  @override
  String get withinTarget => 'Within target';

  @override
  String get overTarget => 'Over target';

  @override
  String targetCalories(int goal) {
    return 'Target $goal kcal';
  }

  @override
  String trendBarSemantics(String day, int calories) {
    return '$day: $calories kcal';
  }

  @override
  String trendBarSemanticsOver(String day, int calories) {
    return '$day: $calories kcal, over target';
  }

  @override
  String get builderSubtitle => 'Create and assign a plan';

  @override
  String get builderSubtitleNoClient => 'Select a client to build a plan';

  @override
  String get newPlan => 'New plan';

  @override
  String get builderLoading => 'Loading workout builder';

  @override
  String get builderNoClientsBody =>
      'Invite your first client to build them a plan.';

  @override
  String planAssignedTo(String name) {
    return 'Plan assigned to $name';
  }

  @override
  String get builderPlanName => 'Plan name';

  @override
  String get builderPlanNameHint => 'e.g. Push / Pull / Legs';

  @override
  String get planNameRequired => 'Give the plan a name';

  @override
  String get planDescriptionOptional => 'Description (optional)';

  @override
  String assignTo(String name) {
    return 'Assign to $name';
  }

  @override
  String get startFromTemplate => 'Start from a template';

  @override
  String templateDaysAndDescription(int days, String description) {
    return '$days days · $description';
  }

  @override
  String get noActivePlanTitle => 'No active plan';

  @override
  String noActivePlanBody(String name) {
    return '$name isn’t on a plan yet.';
  }

  @override
  String get createAPlan => 'Create a plan';

  @override
  String get planActive => 'Active';

  @override
  String get sessionReviewSubtitleNoClient =>
      'Select a client to review their sessions';

  @override
  String sessionReviewSubtitle(String name) {
    return 'What $name actually logged';
  }

  @override
  String sessionReviewSubtitleWithCounts(
    String name,
    int total,
    int done,
    int missed,
  ) {
    return 'What $name actually logged — $total sessions, $done completed, $missed missed';
  }

  @override
  String get sessionsLoading => 'Loading sessions';

  @override
  String get sessionReviewNoClientsBody =>
      'Invite your first client to start reviewing their sessions.';

  @override
  String get noSessionsLoggedTitle => 'No sessions logged yet';

  @override
  String noSessionsLoggedBody(String name) {
    return '$name hasn’t recorded a workout yet.';
  }

  @override
  String get sessionCompleted => 'Completed';

  @override
  String get sessionPartial => 'Partial';

  @override
  String get sessionMissed => 'Missed';

  @override
  String get sessionSkipped => 'Skipped';

  @override
  String dateToday(String date) {
    return 'Today · $date';
  }

  @override
  String dateYesterday(String date) {
    return 'Yesterday · $date';
  }

  @override
  String get sessionHistory => 'Session history';

  @override
  String get workout => 'Workout';

  @override
  String get noWorkoutLoggedTitle => 'No workout logged';

  @override
  String noWorkoutLoggedBody(String name) {
    return '$name didn’t record this session.';
  }

  @override
  String get newPr => 'NEW PR';

  @override
  String get pr => 'PR';

  @override
  String get volume => 'Volume';

  @override
  String get avgRpe => 'Avg RPE';

  @override
  String get clientNote => 'CLIENT NOTE';

  @override
  String prescribedSummary(String summary) {
    return 'Prescribed $summary';
  }

  @override
  String get setColumn => 'SET';

  @override
  String get repsColumn => 'REPS';

  @override
  String get weightColumn => 'WEIGHT';

  @override
  String get rpeColumn => 'RPE';

  @override
  String setNumber(int number) {
    return 'Set $number';
  }

  @override
  String repsCount(int reps) {
    return '$reps reps';
  }

  @override
  String get bodyweight => 'bodyweight';

  @override
  String rpeValue(String value) {
    return 'RPE $value';
  }

  @override
  String get underTarget => 'under target';

  @override
  String get joinATrainer => 'Join a trainer';

  @override
  String get joinATrainerSubtitle => 'Enter the code your trainer gave you';

  @override
  String get joinTrainerTitle => 'Join a Trainer';

  @override
  String get joinTrainerPrompt => 'Enter the code your trainer gave you.';

  @override
  String get trainerCode => 'Trainer Code';

  @override
  String get joinTrainerAction => 'Join Trainer';

  @override
  String get joinTrainerDisclosure =>
      'Your trainer will be able to see your workouts, weight and nutrition. If their plan includes Pro, you get it while you are on their roster.';

  @override
  String get joinTrainerCodeMissing =>
      'Enter the 12-character code from your trainer.';

  @override
  String get joinTrainerCodeMalformed =>
      'Codes are 12 characters, digits and letters A–F.';

  @override
  String get joinTrainerConnected => 'You\'re connected to your trainer.';

  @override
  String get somethingWentWrongRetry => 'Something went wrong. Try again.';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get searchOnline => 'Search Online';

  @override
  String get resetEmailFailed =>
      'Failed to send reset email. Please try again.';

  @override
  String get kcal => 'kcal';

  @override
  String calorieRingNoGoal(int kcal) {
    return '$kcal kcal logged, no goal set';
  }

  @override
  String calorieRingOver(int eaten, int goal, int over) {
    return '$eaten of $goal kcal, over by $over';
  }

  @override
  String calorieRingRemaining(int eaten, int goal, int remaining) {
    return '$eaten of $goal kcal, $remaining remaining';
  }

  @override
  String calorieRingGoal(int goal) {
    return '/ $goal kcal';
  }

  @override
  String calorieRingOverBy(int over) {
    return 'over by $over';
  }

  @override
  String calorieRingLeft(int remaining) {
    return '$remaining left';
  }

  @override
  String get proteinShort => 'P';

  @override
  String get carbsShort => 'C';

  @override
  String get fatShort => 'F';

  @override
  String gramsShort(int grams) {
    return '$grams g';
  }

  @override
  String foodCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foods',
      one: '1 food',
    );
    return '$_temp0';
  }

  @override
  String mealDetailSemantics(String meal, int calories) {
    return '$meal, $calories kcal. Open to see every food logged.';
  }

  @override
  String foodRowSemantics(
    String name,
    int grams,
    int calories,
    int protein,
    int carbs,
    int fat,
  ) {
    return '$name, $grams grams, $calories kcal, protein ${protein}g, carbs ${carbs}g, fat ${fat}g';
  }

  @override
  String foodRowSemanticsNoWeight(
    String name,
    int calories,
    int protein,
    int carbs,
    int fat,
  ) {
    return '$name, $calories kcal, protein ${protein}g, carbs ${carbs}g, fat ${fat}g';
  }

  @override
  String editFoodEntry(String food) {
    return 'Edit $food';
  }

  @override
  String deleteFoodEntry(String food) {
    return 'Delete $food';
  }

  @override
  String addFoodToCategory(String category) {
    return 'Add food to $category';
  }

  @override
  String get pickDate => 'Choose a date';

  @override
  String get noCalorieTarget => 'No target set';

  @override
  String get kpiAvgAdherenceThisWeek => 'Avg adherence, this week';

  @override
  String get rosterColumnAdherence28d => 'ADHERENCE (28D)';

  @override
  String get adherence28d => 'Adherence, last 28 days';

  @override
  String get couldNotLoad => 'Couldn\'t load your data';

  @override
  String get couldNotLoadBody => 'Check your connection and try again.';

  @override
  String get errorWorkoutNameRequired => 'Give the day a name.';

  @override
  String get errorLoadClientWorkouts =>
      'Could not load this client’s workouts.';

  @override
  String get errorLoadExerciseLibrary => 'Could not load the exercise library.';

  @override
  String get errorExerciseNameRequired => 'Give the exercise a name.';

  @override
  String get errorCreateExercise => 'Could not create the exercise.';

  @override
  String get errorSaveWorkout => 'Could not save this day.';

  @override
  String get errorDeleteWorkout => 'Could not delete this day.';

  @override
  String get errorWorkoutHasHistory =>
      'This day has logged sessions and can’t be deleted.';

  @override
  String get errorUnknownExercise =>
      'One of the exercises in this day couldn’t be prescribed. Try removing and re-adding it.';

  @override
  String get errorScheduleWorkoutPlan => 'Could not schedule this plan.';

  @override
  String get builderDays => 'Days';

  @override
  String get builderNewDay => 'New day';

  @override
  String get builderDayName => 'Day name';

  @override
  String get builderDayNameHint => 'e.g. Push Day';

  @override
  String get builderDifficulty => 'Difficulty';

  @override
  String get builderDifficultyBeginner => 'Beginner';

  @override
  String get builderDifficultyIntermediate => 'Intermediate';

  @override
  String get builderDifficultyAdvanced => 'Advanced';

  @override
  String get builderDurationMinutes => 'Duration (minutes)';

  @override
  String get builderExercises => 'Exercises';

  @override
  String get builderNoExercisesYetTitle => 'No exercises yet';

  @override
  String get builderNoExercisesYetBody =>
      'Add exercises to build out this day.';

  @override
  String get builderAddExercise => 'Add exercise';

  @override
  String get builderRemoveExercise => 'Remove exercise';

  @override
  String get builderMoveExerciseUp => 'Move up';

  @override
  String get builderMoveExerciseDown => 'Move down';

  @override
  String get builderSets => 'Sets';

  @override
  String get builderAddSet => 'Add set';

  @override
  String get builderRemoveSet => 'Remove set';

  @override
  String get builderExpandDayDetails => 'Show day details';

  @override
  String get builderCollapseDayDetails => 'Hide day details';

  @override
  String get builderTargetRepsLabel => 'Target reps';

  @override
  String get builderTargetRepsHint => 'e.g. 8-12';

  @override
  String get builderCoachNoteLabel => 'Coach’s note';

  @override
  String get builderCoachNoteHint => 'e.g. Keep elbows tucked, RPE 8';

  @override
  String get builderSaveDay => 'Save day';

  @override
  String get builderDeleteDay => 'Delete day';

  @override
  String get builderDeleteDayConfirmTitle => 'Delete this day?';

  @override
  String builderDeleteDayConfirmBody(String name) {
    return '$name will be removed from this plan. This can’t be undone.';
  }

  @override
  String get builderDiscardChangesTitle => 'Discard changes?';

  @override
  String get builderDiscardChangesBody =>
      'You have unsaved changes to this day.';

  @override
  String get builderDiscard => 'Discard';

  @override
  String get builderKeepEditing => 'Keep editing';

  @override
  String get builderNoWorkoutsTitle => 'No days yet';

  @override
  String builderNoWorkoutsBody(String name) {
    return 'Add the first day to $name’s plan.';
  }

  @override
  String get builderPickExerciseTitle => 'Add an exercise';

  @override
  String get builderSearchExercisesHint => 'Search exercises';

  @override
  String get builderNoExercisesFound => 'No exercises match your search.';

  @override
  String get builderNewExerciseAction => 'New exercise';

  @override
  String get builderNewExerciseTitle => 'New exercise';

  @override
  String get builderExerciseNameLabel => 'Exercise name';

  @override
  String get builderTrainerOwnedTag =>
      'Yours — prescribing this shares a copy with the client';

  @override
  String builderDaySavedConfirmation(String name) {
    return '$name saved';
  }

  @override
  String builderDayDeletedConfirmation(String name) {
    return '$name deleted';
  }

  @override
  String get builderUnsavedChangesBadge => 'Unsaved changes';

  @override
  String get builderCreateExercise => 'Create';

  @override
  String get builderDurationRange => 'Must be between 1 and 1440 minutes.';
}
