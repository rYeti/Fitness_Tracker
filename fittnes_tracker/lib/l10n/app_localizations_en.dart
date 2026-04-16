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
  String get pleaseEnterValidAgeAndHeight => 'Please enter valid age and height';

  @override
  String get pleaseEnterValidNumber => 'Please enter a valid number';

  @override
  String get calculatedAndSavedCalorieGoal => 'Calculated and saved calorie goal';

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
  String get addCustomFood => 'Add Custom Food';

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
  String get mealCategory => 'Meal category';

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
  String get pleaseEnterAtLeastOneWorkoutDay => 'Please enter at least one workout day in the cycle';

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
  String get noExercisesForWorkout => 'No exercises configured for this workout';

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
  String get barcodeNotSupportedOnWeb => 'Barcode scanning not supported on web';

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
  String get onboardingWelcomeBody => 'Track your nutrition, workouts and weight all in one place.';

  @override
  String get onboardingFeatureWeight => 'Weight Tracking';

  @override
  String get onboardingProfileTitle => 'About You';

  @override
  String get onboardingProfileSubtitle => 'We\'ll use this to personalise your experience';

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
  String get enterSearchTermsOnline => 'Enter search terms to find foods online';

  @override
  String get noResultsFoundSearch => 'No results found for this search';

  @override
  String get tryUsingMoreGeneralTerms => 'Try using more general terms or check spelling';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get noFoodsAdded => 'No foods added yet';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get barcodeNotSupportedMobile => 'Barcode scanning is only supported on mobile devices.';

  @override
  String get barcodeNotSupportedWeb => 'Barcode scanning is not supported on web';

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
  String get freeChoiceMode => 'Free Choice Mode';

  @override
  String get freeChoiceModeSubtitle => 'Pick workouts manually for each day';

  @override
  String get cycleModeSubtitle => 'Workouts follow a repeating cycle';

  @override
  String get switchToFreeChoiceTitle => 'Switch to Free Choice?';

  @override
  String get switchToFreeChoiceBody => 'All future scheduled workouts for this plan will be removed. You can pick workouts day by day.';

  @override
  String get switchToCyclePlanTitle => 'Switch to Cycle Plan?';

  @override
  String get switchToCyclePlanBody => 'The plan will switch back to cycle mode. No scheduled workouts will be created automatically.';

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
  String get freeChoiceAddHint => 'Add workout templates to choose from each day';

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
  String get selectAtLeastOneMuscleGroup => 'Please select at least one muscle group';

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
  String get tryMoreGeneralTerms => 'Try using more general terms or check spelling';

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
  String get barcodeScanningMobileOnly => 'Barcode scanning is only supported on mobile devices.';

  @override
  String get barcodeScanningWebNotSupported => 'Barcode scanning is not supported on web';

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
  String get cannotAddExerciseToUnsavedWorkout => 'Cannot add exercise to unsaved workout';

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
  String get premiumFeatureBody => 'Upgrade to Premium to see detailed nutrition data including vitamins and minerals.';

  @override
  String get premiumBadge => 'Premium';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';
}
