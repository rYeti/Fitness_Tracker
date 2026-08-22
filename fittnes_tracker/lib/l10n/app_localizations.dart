import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @sedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get sedentary;

  /// No description provided for @lightlyActive.
  ///
  /// In en, this message translates to:
  /// **'Lightly Active'**
  String get lightlyActive;

  /// No description provided for @moderatelyActive.
  ///
  /// In en, this message translates to:
  /// **'Moderately Active'**
  String get moderatelyActive;

  /// No description provided for @veryActive.
  ///
  /// In en, this message translates to:
  /// **'Very Active'**
  String get veryActive;

  /// No description provided for @extremelyActive.
  ///
  /// In en, this message translates to:
  /// **'Extremely Active'**
  String get extremelyActive;

  /// No description provided for @weightLoss.
  ///
  /// In en, this message translates to:
  /// **'Weight Loss'**
  String get weightLoss;

  /// No description provided for @muscleGain.
  ///
  /// In en, this message translates to:
  /// **'Muscle Gain'**
  String get muscleGain;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @gym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get gym;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @dailyCalorieGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily Calorie Goal'**
  String get dailyCalorieGoal;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveCalorieGoal.
  ///
  /// In en, this message translates to:
  /// **'Calorie goal saved'**
  String get saveCalorieGoal;

  /// No description provided for @addFood.
  ///
  /// In en, this message translates to:
  /// **'{category}'**
  String addFood(Object category);

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan Barcode'**
  String get scanBarcode;

  /// No description provided for @nutritionProgress.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Progress'**
  String get nutritionProgress;

  /// No description provided for @foodDetails.
  ///
  /// In en, this message translates to:
  /// **'Food Details'**
  String get foodDetails;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(Object error);

  /// No description provided for @pleaseEnterValidAgeAndHeight.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid age and height'**
  String get pleaseEnterValidAgeAndHeight;

  /// No description provided for @pleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// No description provided for @calculatedAndSavedCalorieGoal.
  ///
  /// In en, this message translates to:
  /// **'Calculated and saved calorie goal'**
  String get calculatedAndSavedCalorieGoal;

  /// No description provided for @failedToSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile: {error}'**
  String failedToSaveProfile(Object error);

  /// No description provided for @failedToUpdateCalorieGoal.
  ///
  /// In en, this message translates to:
  /// **'Failed to update calorie goal: {error}'**
  String failedToUpdateCalorieGoal(Object error);

  /// No description provided for @failedToLoadData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data: {error}'**
  String failedToLoadData(Object error);

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @addCustomFood.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Food'**
  String get addCustomFood;

  /// No description provided for @foodName.
  ///
  /// In en, this message translates to:
  /// **'Food Name'**
  String get foodName;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get protein;

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs (g)'**
  String get carbs;

  /// No description provided for @fat.
  ///
  /// In en, this message translates to:
  /// **'Fat (g)'**
  String get fat;

  /// No description provided for @addedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'added successfully!'**
  String get addedSuccessfully;

  /// No description provided for @pleaseEnterAName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterAName;

  /// No description provided for @pleaseEnterCalories.
  ///
  /// In en, this message translates to:
  /// **'Please enter calories'**
  String get pleaseEnterCalories;

  /// No description provided for @foodTracker.
  ///
  /// In en, this message translates to:
  /// **'Tracker'**
  String get foodTracker;

  /// No description provided for @proteinLabel.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get proteinLabel;

  /// No description provided for @carbsLabel.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbsLabel;

  /// No description provided for @fatLabel.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fatLabel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @addFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add'**
  String get addFailed;

  /// No description provided for @nutritionInformation.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Information'**
  String get nutritionInformation;

  /// No description provided for @portionSize.
  ///
  /// In en, this message translates to:
  /// **'Portion size'**
  String get portionSize;

  /// No description provided for @quantityInGrams.
  ///
  /// In en, this message translates to:
  /// **'Quantity in grams'**
  String get quantityInGrams;

  /// No description provided for @addToTodayLog.
  ///
  /// In en, this message translates to:
  /// **'Add to today\'s log'**
  String get addToTodayLog;

  /// No description provided for @mealCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get mealCategory;

  /// No description provided for @addToLog.
  ///
  /// In en, this message translates to:
  /// **'Add to log'**
  String get addToLog;

  /// No description provided for @mealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// No description provided for @mealSnacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get mealSnacks;

  /// No description provided for @searchForFood.
  ///
  /// In en, this message translates to:
  /// **'Search for food'**
  String get searchForFood;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get recentlyAdded;

  /// No description provided for @addedToRecentFoods.
  ///
  /// In en, this message translates to:
  /// **'{name} added to recent foods'**
  String addedToRecentFoods(Object name);

  /// No description provided for @noFoodAdded.
  ///
  /// In en, this message translates to:
  /// **'No foods added yet'**
  String get noFoodAdded;

  /// No description provided for @calculateAndSave.
  ///
  /// In en, this message translates to:
  /// **'Calculated and saved calorie goal'**
  String get calculateAndSave;

  /// No description provided for @workoutName.
  ///
  /// In en, this message translates to:
  /// **'Workout name'**
  String get workoutName;

  /// No description provided for @createWorkout.
  ///
  /// In en, this message translates to:
  /// **'Create Workout'**
  String get createWorkout;

  /// No description provided for @workoutSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Workout saved successfully'**
  String get workoutSavedSuccessfully;

  /// No description provided for @pleaseEnterWorkoutName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a workout name'**
  String get pleaseEnterWorkoutName;

  /// No description provided for @pleaseEnterAtLeastOneWorkoutDay.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least one workout day in the cycle'**
  String get pleaseEnterAtLeastOneWorkoutDay;

  /// No description provided for @pleaseSelectStartDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a start date'**
  String get pleaseSelectStartDate;

  /// No description provided for @dayRestDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day}: Rest Day'**
  String dayRestDay(int day);

  /// No description provided for @dayWorkout.
  ///
  /// In en, this message translates to:
  /// **'Day {day}: {workout}'**
  String dayWorkout(int day, String workout);

  /// No description provided for @noExercisesYet.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet'**
  String get noExercisesYet;

  /// No description provided for @addWorkout.
  ///
  /// In en, this message translates to:
  /// **'Add Workout'**
  String get addWorkout;

  /// No description provided for @addRestDay.
  ///
  /// In en, this message translates to:
  /// **'Add Rest Day'**
  String get addRestDay;

  /// No description provided for @workoutNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Workout Name'**
  String get workoutNameLabel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @selectStartDate.
  ///
  /// In en, this message translates to:
  /// **'Select Start Date'**
  String get selectStartDate;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @stepXofY.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepXofY(int current, int total);

  /// No description provided for @noScheduledWorkouts.
  ///
  /// In en, this message translates to:
  /// **'No scheduled workouts'**
  String get noScheduledWorkouts;

  /// No description provided for @unknownWorkout.
  ///
  /// In en, this message translates to:
  /// **'Unknown Workout'**
  String get unknownWorkout;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @seedWorkoutTemplates.
  ///
  /// In en, this message translates to:
  /// **'Seed workout templates (debug)'**
  String get seedWorkoutTemplates;

  /// No description provided for @seedingTemplates.
  ///
  /// In en, this message translates to:
  /// **'Seeding templates...'**
  String get seedingTemplates;

  /// No description provided for @seedingFailed.
  ///
  /// In en, this message translates to:
  /// **'Seeding failed: {error}'**
  String seedingFailed(Object error);

  /// No description provided for @createOrEditWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Create or edit workouts'**
  String get createOrEditWorkouts;

  /// No description provided for @newWorkout.
  ///
  /// In en, this message translates to:
  /// **'New Workout'**
  String get newWorkout;

  /// No description provided for @viewWorkouts.
  ///
  /// In en, this message translates to:
  /// **'View workouts'**
  String get viewWorkouts;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @noSetTemplates.
  ///
  /// In en, this message translates to:
  /// **'No sets configured'**
  String get noSetTemplates;

  /// No description provided for @setTemplatesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String setTemplatesCount(int count);

  /// No description provided for @copyToAll.
  ///
  /// In en, this message translates to:
  /// **'Copy to all'**
  String get copyToAll;

  /// No description provided for @repsHelperText.
  ///
  /// In en, this message translates to:
  /// **'e.g., 8-12 or 10'**
  String get repsHelperText;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'Add Set'**
  String get addSet;

  /// No description provided for @noSetsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No sets configured'**
  String get noSetsConfigured;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'sets'**
  String get sets;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @removeSet.
  ///
  /// In en, this message translates to:
  /// **'Remove Set'**
  String get removeSet;

  /// No description provided for @setLabel.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setLabel;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @kg.
  ///
  /// In en, this message translates to:
  /// **'KG'**
  String get kg;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @noExercisesForWorkout.
  ///
  /// In en, this message translates to:
  /// **'No exercises configured for this workout'**
  String get noExercisesForWorkout;

  /// No description provided for @errorLoadingExercises.
  ///
  /// In en, this message translates to:
  /// **'Error loading exercises: {error}'**
  String errorLoadingExercises(Object error);

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @saveWorkout.
  ///
  /// In en, this message translates to:
  /// **'Save workout'**
  String get saveWorkout;

  /// No description provided for @workoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Workout has been saved.'**
  String get workoutSaved;

  /// No description provided for @restDay.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get restDay;

  /// No description provided for @editWorkout.
  ///
  /// In en, this message translates to:
  /// **'Edit Workout'**
  String get editWorkout;

  /// No description provided for @workoutUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Workout updated successfully'**
  String get workoutUpdatedSuccessfully;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(Object error);

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add Exercise'**
  String get addExercise;

  /// No description provided for @editSet.
  ///
  /// In en, this message translates to:
  /// **'Edit Set {setNumber}'**
  String editSet(int setNumber);

  /// No description provided for @noExercisesInWorkout.
  ///
  /// In en, this message translates to:
  /// **'No exercises in this workout'**
  String get noExercisesInWorkout;

  /// No description provided for @setsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get setsLabel;

  /// No description provided for @noSetsFound.
  ///
  /// In en, this message translates to:
  /// **'No sets found for this exercise'**
  String get noSetsFound;

  /// No description provided for @exerciseName.
  ///
  /// In en, this message translates to:
  /// **'Exercise Name'**
  String get exerciseName;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @repsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get repsLabel;

  /// No description provided for @weightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightLabel;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @noWorkoutsFound.
  ///
  /// In en, this message translates to:
  /// **'No workouts found'**
  String get noWorkoutsFound;

  /// No description provided for @setWeightGoal.
  ///
  /// In en, this message translates to:
  /// **'Set Weight Goals'**
  String get setWeightGoal;

  /// No description provided for @calculateBMI.
  ///
  /// In en, this message translates to:
  /// **'Calculate BMI'**
  String get calculateBMI;

  /// No description provided for @currentWeight.
  ///
  /// In en, this message translates to:
  /// **'Current Weight'**
  String get currentWeight;

  /// No description provided for @weightProgress.
  ///
  /// In en, this message translates to:
  /// **'Weight Progress'**
  String get weightProgress;

  /// No description provided for @nutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get nutrition;

  /// No description provided for @exerciseProgress.
  ///
  /// In en, this message translates to:
  /// **'Exercise Progress'**
  String get exerciseProgress;

  /// No description provided for @weightGoals.
  ///
  /// In en, this message translates to:
  /// **'Weight Goals'**
  String get weightGoals;

  /// No description provided for @startingWeight.
  ///
  /// In en, this message translates to:
  /// **'Starting Weight'**
  String get startingWeight;

  /// No description provided for @goalWeight.
  ///
  /// In en, this message translates to:
  /// **'Goal Weight'**
  String get goalWeight;

  /// No description provided for @enterStartingWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 90'**
  String get enterStartingWeightHint;

  /// No description provided for @enterGoalWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 75'**
  String get enterGoalWeightHint;

  /// No description provided for @pleaseEnterValidWeights.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid weights'**
  String get pleaseEnterValidWeights;

  /// No description provided for @weightGoalsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Weight goals updated'**
  String get weightGoalsUpdated;

  /// No description provided for @saveWeightGoals.
  ///
  /// In en, this message translates to:
  /// **'Save Weight Goals'**
  String get saveWeightGoals;

  /// No description provided for @weightGoalsSaved.
  ///
  /// In en, this message translates to:
  /// **'Weight goals saved'**
  String get weightGoalsSaved;

  /// No description provided for @estimatedCompletion.
  ///
  /// In en, this message translates to:
  /// **'Estimated Completion'**
  String get estimatedCompletion;

  /// No description provided for @movingAwayFromGoal.
  ///
  /// In en, this message translates to:
  /// **'Moving away from goal'**
  String get movingAwayFromGoal;

  /// No description provided for @weightStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get weightStarting;

  /// No description provided for @weightCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get weightCurrent;

  /// No description provided for @weightToGo.
  ///
  /// In en, this message translates to:
  /// **'To Go'**
  String get weightToGo;

  /// No description provided for @weightComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get weightComplete;

  /// No description provided for @weightGained.
  ///
  /// In en, this message translates to:
  /// **'Gained'**
  String get weightGained;

  /// No description provided for @weightGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get weightGoalLabel;

  /// No description provided for @completionLessThanWeek.
  ///
  /// In en, this message translates to:
  /// **'Less than a week away!'**
  String get completionLessThanWeek;

  /// No description provided for @completionWeeks.
  ///
  /// In en, this message translates to:
  /// **'About {n} week(s) away'**
  String completionWeeks(int n);

  /// No description provided for @completionMonths.
  ///
  /// In en, this message translates to:
  /// **'About {n} month(s) away'**
  String completionMonths(int n);

  /// No description provided for @completionYears.
  ///
  /// In en, this message translates to:
  /// **'About {n} year(s) away'**
  String completionYears(int n);

  /// No description provided for @errorLoadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Error loading progress: {error}'**
  String errorLoadingProgress(Object error);

  /// No description provided for @addBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Add Breakfast'**
  String get addBreakfast;

  /// No description provided for @addLunch.
  ///
  /// In en, this message translates to:
  /// **'Add Lunch'**
  String get addLunch;

  /// No description provided for @addDinner.
  ///
  /// In en, this message translates to:
  /// **'Add Dinner'**
  String get addDinner;

  /// No description provided for @addSnack.
  ///
  /// In en, this message translates to:
  /// **'Add Snack'**
  String get addSnack;

  /// No description provided for @addWeight.
  ///
  /// In en, this message translates to:
  /// **'Add Weight'**
  String get addWeight;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @dailyCalories.
  ///
  /// In en, this message translates to:
  /// **'Daily Calories'**
  String get dailyCalories;

  /// No description provided for @todaysWorkout.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Workout'**
  String get todaysWorkout;

  /// No description provided for @errorLoadingWorkout.
  ///
  /// In en, this message translates to:
  /// **'Error loading workout: {error}'**
  String errorLoadingWorkout(Object error);

  /// No description provided for @calorieTrend.
  ///
  /// In en, this message translates to:
  /// **'Calorie Trend'**
  String get calorieTrend;

  /// No description provided for @avgCalories.
  ///
  /// In en, this message translates to:
  /// **'Avg Calories'**
  String get avgCalories;

  /// No description provided for @calPerDay.
  ///
  /// In en, this message translates to:
  /// **'kcal/day'**
  String get calPerDay;

  /// No description provided for @noNutritionDataYet.
  ///
  /// In en, this message translates to:
  /// **'No nutrition data yet'**
  String get noNutritionDataYet;

  /// No description provided for @sevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 Days'**
  String get sevenDays;

  /// No description provided for @thirtyDays.
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get thirtyDays;

  /// No description provided for @ninetyDays.
  ///
  /// In en, this message translates to:
  /// **'90 Days'**
  String get ninetyDays;

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get timeRange;

  /// No description provided for @weeklyAverages.
  ///
  /// In en, this message translates to:
  /// **'Weekly Averages'**
  String get weeklyAverages;

  /// No description provided for @daysOnTarget.
  ///
  /// In en, this message translates to:
  /// **'Days on Target'**
  String get daysOnTarget;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get currentStreak;

  /// No description provided for @longestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest Streak'**
  String get longestStreak;

  /// No description provided for @logMealsProgress.
  ///
  /// In en, this message translates to:
  /// **'Log Meals'**
  String get logMealsProgress;

  /// No description provided for @completeWorkoutsProgress.
  ///
  /// In en, this message translates to:
  /// **'Complete Workouts'**
  String get completeWorkoutsProgress;

  /// No description provided for @summaryStatistics.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryStatistics;

  /// No description provided for @myFoods.
  ///
  /// In en, this message translates to:
  /// **'My Foods'**
  String get myFoods;

  /// No description provided for @onlineResults.
  ///
  /// In en, this message translates to:
  /// **'Online Results'**
  String get onlineResults;

  /// No description provided for @editPortion.
  ///
  /// In en, this message translates to:
  /// **'Edit Portion'**
  String get editPortion;

  /// No description provided for @portionGrams.
  ///
  /// In en, this message translates to:
  /// **'Portion (g)'**
  String get portionGrams;

  /// No description provided for @portionLabel.
  ///
  /// In en, this message translates to:
  /// **'Portion'**
  String get portionLabel;

  /// No description provided for @updatePortion.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updatePortion;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @couldNotReachFoodDatabase.
  ///
  /// In en, this message translates to:
  /// **'Could not reach food database'**
  String get couldNotReachFoodDatabase;

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @barcodeNotSupportedOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning not supported on web'**
  String get barcodeNotSupportedOnWeb;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @addToMealTemplate.
  ///
  /// In en, this message translates to:
  /// **'Add to Meal Template'**
  String get addToMealTemplate;

  /// No description provided for @mealTemplates.
  ///
  /// In en, this message translates to:
  /// **'Meal Templates'**
  String get mealTemplates;

  /// No description provided for @createTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create Template'**
  String get createTemplate;

  /// No description provided for @createMealTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create Meal Template'**
  String get createMealTemplate;

  /// No description provided for @deleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete Template'**
  String get deleteTemplate;

  /// No description provided for @deleteTemplateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this template?'**
  String get deleteTemplateQuestion;

  /// No description provided for @noTemplatesFound.
  ///
  /// In en, this message translates to:
  /// **'No templates found'**
  String get noTemplatesFound;

  /// No description provided for @saveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save Template'**
  String get saveTemplate;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get templateName;

  /// No description provided for @pleaseAddAtLeastOneFood.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one food'**
  String get pleaseAddAtLeastOneFood;

  /// No description provided for @templateCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Template created successfully'**
  String get templateCreatedSuccessfully;

  /// No description provided for @addedToTemplate.
  ///
  /// In en, this message translates to:
  /// **'Added {name} to template'**
  String addedToTemplate(String name);

  /// No description provided for @templateApplied.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" applied to {category}'**
  String templateApplied(String name, String category);

  /// No description provided for @errorApplyingTemplate.
  ///
  /// In en, this message translates to:
  /// **'Error applying template: {error}'**
  String errorApplyingTemplate(Object error);

  /// No description provided for @errorCreatingTemplate.
  ///
  /// In en, this message translates to:
  /// **'Error creating template: {error}'**
  String errorCreatingTemplate(Object error);

  /// No description provided for @errorScanningBarcode.
  ///
  /// In en, this message translates to:
  /// **'Error scanning barcode: {error}'**
  String errorScanningBarcode(Object error);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @applyTemplate.
  ///
  /// In en, this message translates to:
  /// **'Apply Template'**
  String get applyTemplate;

  /// No description provided for @applyTemplateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Apply this template?'**
  String get applyTemplateQuestion;

  /// No description provided for @addToTemplate.
  ///
  /// In en, this message translates to:
  /// **'Add to Template'**
  String get addToTemplate;

  /// No description provided for @addWeightRecord.
  ///
  /// In en, this message translates to:
  /// **'Add Weight Record'**
  String get addWeightRecord;

  /// No description provided for @addWeightRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Weight'**
  String get addWeightRecordTitle;

  /// No description provided for @editWeightRecord.
  ///
  /// In en, this message translates to:
  /// **'Edit Weight Record'**
  String get editWeightRecord;

  /// No description provided for @deleteWeightRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete Weight Record'**
  String get deleteWeightRecord;

  /// No description provided for @deleteWeightRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this weight record?'**
  String get deleteWeightRecordConfirm;

  /// No description provided for @noWeightRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'No weight records yet'**
  String get noWeightRecordsYet;

  /// No description provided for @invalidWeight.
  ///
  /// In en, this message translates to:
  /// **'Invalid weight'**
  String get invalidWeight;

  /// No description provided for @weightCalorieCorrelation.
  ///
  /// In en, this message translates to:
  /// **'Weight & Calorie Correlation'**
  String get weightCalorieCorrelation;

  /// No description provided for @maxWeight.
  ///
  /// In en, this message translates to:
  /// **'Max Weight'**
  String get maxWeight;

  /// No description provided for @workoutProgress.
  ///
  /// In en, this message translates to:
  /// **'Workout Progress'**
  String get workoutProgress;

  /// No description provided for @workoutComplete.
  ///
  /// In en, this message translates to:
  /// **'Workout Complete!'**
  String get workoutComplete;

  /// No description provided for @workoutNotes.
  ///
  /// In en, this message translates to:
  /// **'Workout Notes'**
  String get workoutNotes;

  /// No description provided for @workoutDayHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Monday'**
  String get workoutDayHint;

  /// No description provided for @workoutSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Workout Summary'**
  String get workoutSummaryLabel;

  /// No description provided for @workoutHasNoExercises.
  ///
  /// In en, this message translates to:
  /// **'This workout has no exercises'**
  String get workoutHasNoExercises;

  /// No description provided for @workoutFrequency.
  ///
  /// In en, this message translates to:
  /// **'Workout Frequency'**
  String get workoutFrequency;

  /// No description provided for @workoutDeleted.
  ///
  /// In en, this message translates to:
  /// **'Workout deleted'**
  String get workoutDeleted;

  /// No description provided for @workoutDetailsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Workout details updated'**
  String get workoutDetailsUpdated;

  /// No description provided for @workoutPlanSetActive.
  ///
  /// In en, this message translates to:
  /// **'Plan set as active'**
  String get workoutPlanSetActive;

  /// No description provided for @workoutPlanNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. My 5-Day Split'**
  String get workoutPlanNameHint;

  /// No description provided for @workoutAddedToPlan.
  ///
  /// In en, this message translates to:
  /// **'Workout added to plan'**
  String get workoutAddedToPlan;

  /// No description provided for @workoutRemovedFromPlan.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" removed from plan'**
  String workoutRemovedFromPlan(String name);

  /// No description provided for @workoutRenamedTo.
  ///
  /// In en, this message translates to:
  /// **'Workout renamed to \"{name}\"'**
  String workoutRenamedTo(String name);

  /// No description provided for @workoutPostponedTo.
  ///
  /// In en, this message translates to:
  /// **'Workout postponed to {date}'**
  String workoutPostponedTo(String date);

  /// No description provided for @deleteWorkoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteWorkoutConfirmation(String name);

  /// No description provided for @deleteWorkout.
  ///
  /// In en, this message translates to:
  /// **'Delete Workout'**
  String get deleteWorkout;

  /// No description provided for @editWorkoutName.
  ///
  /// In en, this message translates to:
  /// **'Edit Workout Name'**
  String get editWorkoutName;

  /// No description provided for @editWorkoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Workouts'**
  String get editWorkoutsTitle;

  /// No description provided for @editWorkoutDetailsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit workout details'**
  String get editWorkoutDetailsTooltip;

  /// No description provided for @manageWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Manage Workouts'**
  String get manageWorkouts;

  /// No description provided for @createFirstWorkout.
  ///
  /// In en, this message translates to:
  /// **'Create your first workout'**
  String get createFirstWorkout;

  /// No description provided for @noWorkoutsAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No workouts added yet'**
  String get noWorkoutsAddedYet;

  /// No description provided for @noWorkoutsAvailableToAdd.
  ///
  /// In en, this message translates to:
  /// **'No workouts available to add'**
  String get noWorkoutsAvailableToAdd;

  /// No description provided for @noWorkoutsInPlanYet.
  ///
  /// In en, this message translates to:
  /// **'No workouts in this plan yet'**
  String get noWorkoutsInPlanYet;

  /// No description provided for @noWorkoutPlansFound.
  ///
  /// In en, this message translates to:
  /// **'No workout plans found'**
  String get noWorkoutPlansFound;

  /// No description provided for @noWorkoutDataYet.
  ///
  /// In en, this message translates to:
  /// **'No workout data yet'**
  String get noWorkoutDataYet;

  /// No description provided for @addWorkoutToPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Workout to Plan'**
  String get addWorkoutToPlanTitle;

  /// No description provided for @addWorkoutsToBuildCycle.
  ///
  /// In en, this message translates to:
  /// **'Add workouts to build your cycle'**
  String get addWorkoutsToBuildCycle;

  /// No description provided for @removeWorkoutFromPlan.
  ///
  /// In en, this message translates to:
  /// **'Remove from Plan'**
  String get removeWorkoutFromPlan;

  /// No description provided for @removeWorkoutFromPlanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove workout from plan'**
  String get removeWorkoutFromPlanTooltip;

  /// No description provided for @removeWorkoutFromPlanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from plan?'**
  String removeWorkoutFromPlanConfirm(String name);

  /// No description provided for @failedToRemoveWorkoutFromPlan.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove workout from plan: {error}'**
  String failedToRemoveWorkoutFromPlan(Object error);

  /// No description provided for @openPlanEditor.
  ///
  /// In en, this message translates to:
  /// **'Open Plan Editor'**
  String get openPlanEditor;

  /// No description provided for @deletePlanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete plan'**
  String get deletePlanTooltip;

  /// No description provided for @setActive.
  ///
  /// In en, this message translates to:
  /// **'Set Active'**
  String get setActive;

  /// No description provided for @activatePlan.
  ///
  /// In en, this message translates to:
  /// **'Activate Plan'**
  String get activatePlan;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @activePlanBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activePlanBadge;

  /// No description provided for @noWorkoutDataYetLabel.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noWorkoutDataYetLabel;

  /// No description provided for @nameYourWorkoutPlan.
  ///
  /// In en, this message translates to:
  /// **'Name Your Workout Plan'**
  String get nameYourWorkoutPlan;

  /// No description provided for @chooseMemorableName.
  ///
  /// In en, this message translates to:
  /// **'Choose a memorable name'**
  String get chooseMemorableName;

  /// No description provided for @workoutPlanNameHintAlt.
  ///
  /// In en, this message translates to:
  /// **'e.g. Summer Shred'**
  String get workoutPlanNameHintAlt;

  /// No description provided for @buildYourCycle.
  ///
  /// In en, this message translates to:
  /// **'Build Your Cycle'**
  String get buildYourCycle;

  /// No description provided for @stepStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get stepStart;

  /// No description provided for @stepCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get stepCycle;

  /// No description provided for @whenToBeginProgram.
  ///
  /// In en, this message translates to:
  /// **'When to Begin Program'**
  String get whenToBeginProgram;

  /// No description provided for @chooseStartDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a start date'**
  String get chooseStartDate;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDateLabel;

  /// No description provided for @scheduledWorkoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Workout'**
  String get scheduledWorkoutLabel;

  /// No description provided for @scheduledForNextDays.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for next days'**
  String get scheduledForNextDays;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @jumpTo.
  ///
  /// In en, this message translates to:
  /// **'Jump To'**
  String get jumpTo;

  /// No description provided for @postponeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Postpone Workout'**
  String get postponeWorkout;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @skipWorkout.
  ///
  /// In en, this message translates to:
  /// **'Skip Workout'**
  String get skipWorkout;

  /// No description provided for @viewLabel.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewLabel;

  /// No description provided for @dayCycleLength.
  ///
  /// In en, this message translates to:
  /// **'{n}-day cycle'**
  String dayCycleLength(int n);

  /// No description provided for @exerciseFeelingHint.
  ///
  /// In en, this message translates to:
  /// **'How did it feel?'**
  String get exerciseFeelingHint;

  /// No description provided for @exerciseNotes.
  ///
  /// In en, this message translates to:
  /// **'Exercise Notes'**
  String get exerciseNotes;

  /// No description provided for @exerciseRemovedFromWorkout.
  ///
  /// In en, this message translates to:
  /// **'Exercise removed'**
  String get exerciseRemovedFromWorkout;

  /// No description provided for @exercisesSummary.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercisesSummary;

  /// No description provided for @noExercisesCount.
  ///
  /// In en, this message translates to:
  /// **'No exercises'**
  String get noExercisesCount;

  /// No description provided for @noPreviousDataForSet.
  ///
  /// In en, this message translates to:
  /// **'No previous data for this set'**
  String get noPreviousDataForSet;

  /// No description provided for @prevExercise.
  ///
  /// In en, this message translates to:
  /// **'Previous Exercise'**
  String get prevExercise;

  /// No description provided for @nextExercise.
  ///
  /// In en, this message translates to:
  /// **'Next Exercise'**
  String get nextExercise;

  /// No description provided for @nextSet.
  ///
  /// In en, this message translates to:
  /// **'Next Set'**
  String get nextSet;

  /// No description provided for @currentSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Set'**
  String get currentSetLabel;

  /// No description provided for @restTimer.
  ///
  /// In en, this message translates to:
  /// **'Rest Timer'**
  String get restTimer;

  /// No description provided for @restTimerSetting.
  ///
  /// In en, this message translates to:
  /// **'Rest Timer'**
  String get restTimerSetting;

  /// No description provided for @restTimerSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-start after completing a set'**
  String get restTimerSettingSubtitle;

  /// No description provided for @setTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Set type'**
  String get setTypeLabel;

  /// No description provided for @setTypeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get setTypeNormal;

  /// No description provided for @setTypeWarmup.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get setTypeWarmup;

  /// No description provided for @setTypeDropset.
  ///
  /// In en, this message translates to:
  /// **'Drop set'**
  String get setTypeDropset;

  /// No description provided for @setTypeFailure.
  ///
  /// In en, this message translates to:
  /// **'Failure'**
  String get setTypeFailure;

  /// No description provided for @sideLabel.
  ///
  /// In en, this message translates to:
  /// **'Side'**
  String get sideLabel;

  /// No description provided for @sideBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get sideBoth;

  /// No description provided for @sideLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get sideLeft;

  /// No description provided for @sideRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get sideRight;

  /// No description provided for @rpeTrackingSetting.
  ///
  /// In en, this message translates to:
  /// **'Track RPE'**
  String get rpeTrackingSetting;

  /// No description provided for @rpeTrackingSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log Rate of Perceived Exertion (6–10) for each set'**
  String get rpeTrackingSettingSubtitle;

  /// No description provided for @rpeLabel.
  ///
  /// In en, this message translates to:
  /// **'RPE'**
  String get rpeLabel;

  /// No description provided for @lastTime.
  ///
  /// In en, this message translates to:
  /// **'Last Time'**
  String get lastTime;

  /// No description provided for @actual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get actual;

  /// No description provided for @tapButtonToAddExercises.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add exercises'**
  String get tapButtonToAddExercises;

  /// No description provided for @addExercisesToTemplate.
  ///
  /// In en, this message translates to:
  /// **'Add Exercises to Template'**
  String get addExercisesToTemplate;

  /// No description provided for @templateWorkoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Template Workout'**
  String get templateWorkoutLabel;

  /// No description provided for @removeExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Exercise'**
  String get removeExerciseTitle;

  /// No description provided for @removeExerciseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove exercise'**
  String get removeExerciseTooltip;

  /// No description provided for @setRemovedFromExercise.
  ///
  /// In en, this message translates to:
  /// **'Set removed'**
  String get setRemovedFromExercise;

  /// No description provided for @setAddedToExercise.
  ///
  /// In en, this message translates to:
  /// **'Set added'**
  String get setAddedToExercise;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get moreOptions;

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get editDetails;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editName;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @descriptionAndDuration.
  ///
  /// In en, this message translates to:
  /// **'Description & Duration'**
  String get descriptionAndDuration;

  /// No description provided for @overallWorkoutHint.
  ///
  /// In en, this message translates to:
  /// **'Overall workout feel?'**
  String get overallWorkoutHint;

  /// No description provided for @completedWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout completed!'**
  String get completedWorkout;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get startWorkout;

  /// No description provided for @bmiComingSoon.
  ///
  /// In en, this message translates to:
  /// **'BMI coming soon'**
  String get bmiComingSoon;

  /// No description provided for @importButton.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importButton;

  /// No description provided for @importOptions.
  ///
  /// In en, this message translates to:
  /// **'Import Options'**
  String get importOptions;

  /// No description provided for @importFitNotes.
  ///
  /// In en, this message translates to:
  /// **'Import FitNotes'**
  String get importFitNotes;

  /// No description provided for @importFitNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Import from FitNotes CSV export'**
  String get importFitNotesHint;

  /// No description provided for @verifiedFoodBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified ✓'**
  String get verifiedFoodBadge;

  /// No description provided for @adaptiveTdeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Adaptive calorie target'**
  String get adaptiveTdeeTitle;

  /// No description provided for @adaptiveTdeeEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated daily expenditure'**
  String get adaptiveTdeeEstimate;

  /// No description provided for @adaptiveTdeeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended daily target'**
  String get adaptiveTdeeRecommended;

  /// No description provided for @adaptiveTdeeBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on {days} days of weight and food logs'**
  String adaptiveTdeeBasis(int days);

  /// No description provided for @adaptiveTdeeInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Log your weight and food for at least 2 weeks to unlock an adaptive calorie target.'**
  String get adaptiveTdeeInsufficient;

  /// No description provided for @adaptiveTdeeUncertainty.
  ///
  /// In en, this message translates to:
  /// **'Estimate quality depends on logging consistency — under-logging inflates it.'**
  String get adaptiveTdeeUncertainty;

  /// No description provided for @adaptiveTdeeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply as daily goal'**
  String get adaptiveTdeeApply;

  /// No description provided for @adaptiveTdeeApplied.
  ///
  /// In en, this message translates to:
  /// **'Daily calorie goal updated to {kcal} kcal'**
  String adaptiveTdeeApplied(int kcal);

  /// No description provided for @exportSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Data export'**
  String get exportSectionLabel;

  /// No description provided for @exportWorkoutsCsv.
  ///
  /// In en, this message translates to:
  /// **'Export workouts (CSV)'**
  String get exportWorkoutsCsv;

  /// No description provided for @exportWeightCsv.
  ///
  /// In en, this message translates to:
  /// **'Export weight history (CSV)'**
  String get exportWeightCsv;

  /// No description provided for @exportNutritionCsv.
  ///
  /// In en, this message translates to:
  /// **'Export nutrition (CSV)'**
  String get exportNutritionCsv;

  /// No description provided for @exportFullJson.
  ///
  /// In en, this message translates to:
  /// **'Export all data (JSON)'**
  String get exportFullJson;

  /// No description provided for @exportFullJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Complete backup of your local data'**
  String get exportFullJsonHint;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Export saved'**
  String get exportSaved;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @importingWorkoutHistory.
  ///
  /// In en, this message translates to:
  /// **'Importing workout history...'**
  String get importingWorkoutHistory;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importComplete;

  /// No description provided for @readyToImport.
  ///
  /// In en, this message translates to:
  /// **'Ready to Import'**
  String get readyToImport;

  /// No description provided for @noValidDataInFile.
  ///
  /// In en, this message translates to:
  /// **'No valid data found in file'**
  String get noValidDataInFile;

  /// No description provided for @selectCsvFile.
  ///
  /// In en, this message translates to:
  /// **'Select CSV File'**
  String get selectCsvFile;

  /// No description provided for @csvSelectFileButton.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get csvSelectFileButton;

  /// No description provided for @csvImportExercisesButton.
  ///
  /// In en, this message translates to:
  /// **'Import Exercises'**
  String get csvImportExercisesButton;

  /// No description provided for @csvFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'CSV Format'**
  String get csvFormatTitle;

  /// No description provided for @csvFormatDescription.
  ///
  /// In en, this message translates to:
  /// **'Import exercises from a CSV file'**
  String get csvFormatDescription;

  /// No description provided for @csvCreateWorkoutHint.
  ///
  /// In en, this message translates to:
  /// **'Create workout from CSV'**
  String get csvCreateWorkoutHint;

  /// No description provided for @csvPleaseSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a file'**
  String get csvPleaseSelectFile;

  /// No description provided for @csvImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get csvImporting;

  /// No description provided for @totalWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Total Workouts'**
  String get totalWorkouts;

  /// No description provided for @avgSets.
  ///
  /// In en, this message translates to:
  /// **'Avg Sets'**
  String get avgSets;

  /// No description provided for @avgPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Avg / Week'**
  String get avgPerWeek;

  /// No description provided for @uniqueExercisesLabel.
  ///
  /// In en, this message translates to:
  /// **'Unique Exercises'**
  String get uniqueExercisesLabel;

  /// No description provided for @unknownExercise.
  ///
  /// In en, this message translates to:
  /// **'Unknown Exercise'**
  String get unknownExercise;

  /// No description provided for @exerciseXofY.
  ///
  /// In en, this message translates to:
  /// **'Exercise {x} of {y}'**
  String exerciseXofY(int x, int y);

  /// No description provided for @exerciseCount.
  ///
  /// In en, this message translates to:
  /// **'{n} exercise(s)'**
  String exerciseCount(int n);

  /// No description provided for @setCount.
  ///
  /// In en, this message translates to:
  /// **'{n} set(s)'**
  String setCount(int n);

  /// No description provided for @exercisesAndSets.
  ///
  /// In en, this message translates to:
  /// **'{exercises} exercise(s), {sets} set(s)'**
  String exercisesAndSets(int exercises, int sets);

  /// No description provided for @exerciseAddedToWorkout.
  ///
  /// In en, this message translates to:
  /// **'{name} added to workout'**
  String exerciseAddedToWorkout(String name);

  /// No description provided for @failedToAddExercise.
  ///
  /// In en, this message translates to:
  /// **'Failed to add exercise: {error}'**
  String failedToAddExercise(Object error);

  /// No description provided for @failedToAddSet.
  ///
  /// In en, this message translates to:
  /// **'Failed to add set: {error}'**
  String failedToAddSet(Object error);

  /// No description provided for @failedToRemoveExercise.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove exercise: {error}'**
  String failedToRemoveExercise(Object error);

  /// No description provided for @errorCompletingWorkout.
  ///
  /// In en, this message translates to:
  /// **'Error completing workout: {error}'**
  String errorCompletingWorkout(Object error);

  /// No description provided for @errorUpdatingDetails.
  ///
  /// In en, this message translates to:
  /// **'Error updating details: {error}'**
  String errorUpdatingDetails(Object error);

  /// No description provided for @errorUpdatingName.
  ///
  /// In en, this message translates to:
  /// **'Error updating name: {error}'**
  String errorUpdatingName(Object error);

  /// No description provided for @createdExercises.
  ///
  /// In en, this message translates to:
  /// **'{n} exercise(s) created'**
  String createdExercises(int n);

  /// No description provided for @importedSessions.
  ///
  /// In en, this message translates to:
  /// **'{n} session(s) imported'**
  String importedSessions(int n);

  /// No description provided for @importedSets.
  ///
  /// In en, this message translates to:
  /// **'{n} set(s) imported'**
  String importedSets(int n);

  /// No description provided for @importedWorkoutsCreated.
  ///
  /// In en, this message translates to:
  /// **'{n} workout(s) created'**
  String importedWorkoutsCreated(int n);

  /// No description provided for @newExercisesWillBeCreated.
  ///
  /// In en, this message translates to:
  /// **'{n} new exercise(s) will be created'**
  String newExercisesWillBeCreated(int n);

  /// No description provided for @sessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{n} session(s)'**
  String sessionsCount(int n);

  /// No description provided for @setsCount.
  ///
  /// In en, this message translates to:
  /// **'{n} set(s)'**
  String setsCount(int n);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(Object error);

  /// No description provided for @csvExercisesAdded.
  ///
  /// In en, this message translates to:
  /// **'{n} exercise(s) added'**
  String csvExercisesAdded(int n);

  /// No description provided for @csvExercisesSkipped.
  ///
  /// In en, this message translates to:
  /// **'{n} exercise(s) skipped'**
  String csvExercisesSkipped(int n);

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning!'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon!'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening!'**
  String get goodEvening;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal fitness companion'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get onboardingCreateAccount;

  /// No description provided for @profileSetupSkip.
  ///
  /// In en, this message translates to:
  /// **'Set up later'**
  String get profileSetupSkip;

  /// No description provided for @onboardingAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get onboardingAlreadyHaveAccount;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Track your nutrition, workouts and weight all in one place.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingFeatureWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight Tracking'**
  String get onboardingFeatureWeight;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'About You'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll use this to personalise your experience'**
  String get onboardingProfileSubtitle;

  /// No description provided for @onboardingGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Goals'**
  String get onboardingGoalsTitle;

  /// No description provided for @onboardingGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you\'re working towards'**
  String get onboardingGoalsSubtitle;

  /// No description provided for @onboardingSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get onboardingSummaryTitle;

  /// No description provided for @onboardingSummaryCaloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated daily calorie target'**
  String get onboardingSummaryCaloriesLabel;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @undoSkip.
  ///
  /// In en, this message translates to:
  /// **'Undo Skip'**
  String get undoSkip;

  /// No description provided for @replaceExercise.
  ///
  /// In en, this message translates to:
  /// **'Replace Exercise'**
  String get replaceExercise;

  /// No description provided for @resumeWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume workout?'**
  String get resumeWorkoutTitle;

  /// No description provided for @resumeWorkoutBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" was interrupted. Resume where you left off?'**
  String resumeWorkoutBody(String name);

  /// No description provided for @resumeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeWorkout;

  /// No description provided for @discardWorkout.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardWorkout;

  /// No description provided for @removeSupersetLink.
  ///
  /// In en, this message translates to:
  /// **'Remove from superset'**
  String get removeSupersetLink;

  /// No description provided for @superset.
  ///
  /// In en, this message translates to:
  /// **'Superset'**
  String get superset;

  /// No description provided for @supersetPickHint.
  ///
  /// In en, this message translates to:
  /// **'Select exercises for the superset'**
  String get supersetPickHint;

  /// No description provided for @targetReps.
  ///
  /// In en, this message translates to:
  /// **'Target Reps'**
  String get targetReps;

  /// No description provided for @targetRepsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 8-12'**
  String get targetRepsHint;

  /// No description provided for @targetRepsHintLong.
  ///
  /// In en, this message translates to:
  /// **'e.g. 8 - 12'**
  String get targetRepsHintLong;

  /// No description provided for @createWorkoutPlan.
  ///
  /// In en, this message translates to:
  /// **'Create Workout Plan'**
  String get createWorkoutPlan;

  /// No description provided for @planName.
  ///
  /// In en, this message translates to:
  /// **'Plan Name'**
  String get planName;

  /// No description provided for @planNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Beginner Strength Program'**
  String get planNameHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @foods.
  ///
  /// In en, this message translates to:
  /// **'Foods'**
  String get foods;

  /// No description provided for @addFromScheduledWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Add from Scheduled Workouts'**
  String get addFromScheduledWorkouts;

  /// No description provided for @importCsvWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Import CSV Workouts'**
  String get importCsvWorkouts;

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTimer;

  /// No description provided for @pauseTimer.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseTimer;

  /// No description provided for @resetTimer.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetTimer;

  /// No description provided for @stopTimer.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopTimer;

  /// No description provided for @restTimeComplete.
  ///
  /// In en, this message translates to:
  /// **'Rest time complete! 💪'**
  String get restTimeComplete;

  /// No description provided for @selectFood.
  ///
  /// In en, this message translates to:
  /// **'Select Food'**
  String get selectFood;

  /// No description provided for @doneCount.
  ///
  /// In en, this message translates to:
  /// **'Done ({count})'**
  String doneCount(int count);

  /// No description provided for @searchFoods.
  ///
  /// In en, this message translates to:
  /// **'Search Foods'**
  String get searchFoods;

  /// No description provided for @noLocalFoodsFound.
  ///
  /// In en, this message translates to:
  /// **'No local foods found'**
  String get noLocalFoodsFound;

  /// No description provided for @enterSearchTermsOnline.
  ///
  /// In en, this message translates to:
  /// **'Enter search terms to find foods online'**
  String get enterSearchTermsOnline;

  /// No description provided for @noResultsFoundSearch.
  ///
  /// In en, this message translates to:
  /// **'No results found for this search'**
  String get noResultsFoundSearch;

  /// No description provided for @tryUsingMoreGeneralTerms.
  ///
  /// In en, this message translates to:
  /// **'Try using more general terms or check spelling'**
  String get tryUsingMoreGeneralTerms;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @noFoodsAdded.
  ///
  /// In en, this message translates to:
  /// **'No foods added yet'**
  String get noFoodsAdded;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterName;

  /// No description provided for @barcodeNotSupportedMobile.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning is only supported on mobile devices.'**
  String get barcodeNotSupportedMobile;

  /// No description provided for @barcodeNotSupportedWeb.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning is not supported on web'**
  String get barcodeNotSupportedWeb;

  /// No description provided for @selectWorkoutDates.
  ///
  /// In en, this message translates to:
  /// **'Select Workout Dates'**
  String get selectWorkoutDates;

  /// No description provided for @useSelectedDates.
  ///
  /// In en, this message translates to:
  /// **'Use selected dates'**
  String get useSelectedDates;

  /// No description provided for @searchExercisesHint.
  ///
  /// In en, this message translates to:
  /// **'Search exercises...'**
  String get searchExercisesHint;

  /// No description provided for @invalidAgeHeight.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid age and height'**
  String get invalidAgeHeight;

  /// No description provided for @searchOnlineTab.
  ///
  /// In en, this message translates to:
  /// **'Search Online'**
  String get searchOnlineTab;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @selectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Select Date of Birth'**
  String get selectDateOfBirth;

  /// No description provided for @loginToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginToYourAccount;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @noAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountQuestion;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @pleaseSelectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Please select a date of birth'**
  String get pleaseSelectDateOfBirth;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmailFormat;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @minimumAgeRequired.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 13 years old'**
  String get minimumAgeRequired;

  /// No description provided for @freeChoiceMode.
  ///
  /// In en, this message translates to:
  /// **'Free Choice Mode'**
  String get freeChoiceMode;

  /// No description provided for @freeChoiceModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick workouts manually for each day'**
  String get freeChoiceModeSubtitle;

  /// No description provided for @cycleModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts follow a repeating cycle'**
  String get cycleModeSubtitle;

  /// No description provided for @switchToFreeChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to Free Choice?'**
  String get switchToFreeChoiceTitle;

  /// No description provided for @switchToFreeChoiceBody.
  ///
  /// In en, this message translates to:
  /// **'All future scheduled workouts for this plan will be removed. You can pick workouts day by day.'**
  String get switchToFreeChoiceBody;

  /// No description provided for @switchToCyclePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to Cycle Plan?'**
  String get switchToCyclePlanTitle;

  /// No description provided for @switchToCyclePlanBody.
  ///
  /// In en, this message translates to:
  /// **'The plan will switch back to cycle mode. No scheduled workouts will be created automatically.'**
  String get switchToCyclePlanBody;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @addWorkoutForDate.
  ///
  /// In en, this message translates to:
  /// **'Add workout for {date}'**
  String addWorkoutForDate(String date);

  /// No description provided for @pickWorkoutForDate.
  ///
  /// In en, this message translates to:
  /// **'Pick workout for {date}'**
  String pickWorkoutForDate(String date);

  /// No description provided for @freeChoiceAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add workout templates to choose from each day'**
  String get freeChoiceAddHint;

  /// No description provided for @cyclePattern.
  ///
  /// In en, this message translates to:
  /// **'Cycle Pattern'**
  String get cyclePattern;

  /// No description provided for @freeChoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Free Choice'**
  String get freeChoiceLabel;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirm;

  /// No description provided for @createExercise.
  ///
  /// In en, this message translates to:
  /// **'Create Exercise'**
  String get createExercise;

  /// No description provided for @editExercise.
  ///
  /// In en, this message translates to:
  /// **'Edit Exercise'**
  String get editExercise;

  /// No description provided for @createCustomExercise.
  ///
  /// In en, this message translates to:
  /// **'Create custom exercise'**
  String get createCustomExercise;

  /// No description provided for @exerciseType.
  ///
  /// In en, this message translates to:
  /// **'Exercise Type'**
  String get exerciseType;

  /// No description provided for @muscleGroupsLabel.
  ///
  /// In en, this message translates to:
  /// **'Muscle Groups'**
  String get muscleGroupsLabel;

  /// No description provided for @exerciseSaved.
  ///
  /// In en, this message translates to:
  /// **'Exercise saved'**
  String get exerciseSaved;

  /// No description provided for @exerciseUpdated.
  ///
  /// In en, this message translates to:
  /// **'Exercise updated'**
  String get exerciseUpdated;

  /// No description provided for @exerciseCreated.
  ///
  /// In en, this message translates to:
  /// **'Exercise created'**
  String get exerciseCreated;

  /// No description provided for @exerciseDeleted.
  ///
  /// In en, this message translates to:
  /// **'Exercise deleted'**
  String get exerciseDeleted;

  /// No description provided for @deleteExercise.
  ///
  /// In en, this message translates to:
  /// **'Delete Exercise'**
  String get deleteExercise;

  /// No description provided for @deleteExerciseConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteExerciseConfirmation(String name);

  /// No description provided for @selectAtLeastOneMuscleGroup.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one muscle group'**
  String get selectAtLeastOneMuscleGroup;

  /// No description provided for @exerciseTypeStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get exerciseTypeStrength;

  /// No description provided for @exerciseTypeCardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get exerciseTypeCardio;

  /// No description provided for @exerciseTypeFlexibility.
  ///
  /// In en, this message translates to:
  /// **'Flexibility'**
  String get exerciseTypeFlexibility;

  /// No description provided for @exerciseTypeCalisthenics.
  ///
  /// In en, this message translates to:
  /// **'Calisthenics'**
  String get exerciseTypeCalisthenics;

  /// No description provided for @customBadge.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customBadge;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// No description provided for @errorSavingExercise.
  ///
  /// In en, this message translates to:
  /// **'Error saving exercise: {error}'**
  String errorSavingExercise(Object error);

  /// No description provided for @errorDeletingExercise.
  ///
  /// In en, this message translates to:
  /// **'Error deleting exercise: {error}'**
  String errorDeletingExercise(Object error);

  /// No description provided for @newExercise.
  ///
  /// In en, this message translates to:
  /// **'New Exercise'**
  String get newExercise;

  /// No description provided for @noExercisesFoundForQuery.
  ///
  /// In en, this message translates to:
  /// **'No exercises found matching \"{query}\"'**
  String noExercisesFoundForQuery(String query);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @muscleGroupChest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get muscleGroupChest;

  /// No description provided for @muscleGroupBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get muscleGroupBack;

  /// No description provided for @muscleGroupShoulders.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get muscleGroupShoulders;

  /// No description provided for @muscleGroupBiceps.
  ///
  /// In en, this message translates to:
  /// **'Biceps'**
  String get muscleGroupBiceps;

  /// No description provided for @muscleGroupTriceps.
  ///
  /// In en, this message translates to:
  /// **'Triceps'**
  String get muscleGroupTriceps;

  /// No description provided for @muscleGroupLegs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get muscleGroupLegs;

  /// No description provided for @muscleGroupAbs.
  ///
  /// In en, this message translates to:
  /// **'Abs'**
  String get muscleGroupAbs;

  /// No description provided for @muscleGroupFullBody.
  ///
  /// In en, this message translates to:
  /// **'Full Body'**
  String get muscleGroupFullBody;

  /// No description provided for @exercisesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse, create & edit exercises'**
  String get exercisesSubtitle;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @selectTrainingDays.
  ///
  /// In en, this message translates to:
  /// **'Select Training Days'**
  String get selectTrainingDays;

  /// No description provided for @daysSelected.
  ///
  /// In en, this message translates to:
  /// **'{n} days selected'**
  String daysSelected(int n);

  /// No description provided for @manageExercises.
  ///
  /// In en, this message translates to:
  /// **'Manage Exercises'**
  String get manageExercises;

  /// No description provided for @noResultsFoundForSearch.
  ///
  /// In en, this message translates to:
  /// **'No results found for this search'**
  String get noResultsFoundForSearch;

  /// No description provided for @tryMoreGeneralTerms.
  ///
  /// In en, this message translates to:
  /// **'Try using more general terms or check spelling'**
  String get tryMoreGeneralTerms;

  /// No description provided for @doneWithCount.
  ///
  /// In en, this message translates to:
  /// **'Done ({count})'**
  String doneWithCount(int count);

  /// No description provided for @addingFoodToYours.
  ///
  /// In en, this message translates to:
  /// **'Adding {name} to your foods...'**
  String addingFoodToYours(String name);

  /// No description provided for @foodAddedToYours.
  ///
  /// In en, this message translates to:
  /// **'{name} added to your foods'**
  String foodAddedToYours(String name);

  /// No description provided for @errorAddingFood.
  ///
  /// In en, this message translates to:
  /// **'Error adding food: {error}'**
  String errorAddingFood(Object error);

  /// No description provided for @brandLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand: {brand}'**
  String brandLabel(String brand);

  /// No description provided for @editMealTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit Meal Template'**
  String get editMealTemplate;

  /// No description provided for @templateUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Template updated successfully'**
  String get templateUpdatedSuccessfully;

  /// No description provided for @barcodeScanningMobileOnly.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning is only supported on mobile devices.'**
  String get barcodeScanningMobileOnly;

  /// No description provided for @barcodeScanningWebNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning is not supported on web'**
  String get barcodeScanningWebNotSupported;

  /// No description provided for @setUpdated.
  ///
  /// In en, this message translates to:
  /// **'Set updated'**
  String get setUpdated;

  /// No description provided for @failedToRemoveSet.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove set: {error}'**
  String failedToRemoveSet(Object error);

  /// No description provided for @failedToUpdateSet.
  ///
  /// In en, this message translates to:
  /// **'Failed to update set: {error}'**
  String failedToUpdateSet(Object error);

  /// No description provided for @workoutPlanCreated.
  ///
  /// In en, this message translates to:
  /// **'Workout plan \"{name}\" created'**
  String workoutPlanCreated(String name);

  /// No description provided for @failedToCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Failed to create workout plan: {error}'**
  String failedToCreatePlan(Object error);

  /// No description provided for @failedToAddWorkout.
  ///
  /// In en, this message translates to:
  /// **'Failed to add workout: {error}'**
  String failedToAddWorkout(Object error);

  /// No description provided for @deletedWorkoutPlan.
  ///
  /// In en, this message translates to:
  /// **'Deleted workout plan \"{name}\"'**
  String deletedWorkoutPlan(String name);

  /// No description provided for @failedToDeletePlan.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete plan: {error}'**
  String failedToDeletePlan(Object error);

  /// No description provided for @cannotAddExerciseToUnsavedWorkout.
  ///
  /// In en, this message translates to:
  /// **'Cannot add exercise to unsaved workout'**
  String get cannotAddExerciseToUnsavedWorkout;

  /// No description provided for @removeExerciseConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{name}\" from this workout?'**
  String removeExerciseConfirmBody(String name);

  /// No description provided for @removeSetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove set {setNumber} from \"{exerciseName}\"?'**
  String removeSetConfirmBody(int setNumber, String exerciseName);

  /// No description provided for @deletePlanConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This will remove the plan but keep the workouts.'**
  String deletePlanConfirmBody(String name);

  /// No description provided for @pleaseEnterDuration.
  ///
  /// In en, this message translates to:
  /// **'Please enter duration'**
  String get pleaseEnterDuration;

  /// No description provided for @pleaseEnterValidDuration.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid duration'**
  String get pleaseEnterValidDuration;

  /// No description provided for @minutesSuffix.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutesSuffix;

  /// No description provided for @selectMuscleGroup.
  ///
  /// In en, this message translates to:
  /// **'Select Muscle Group'**
  String get selectMuscleGroup;

  /// No description provided for @selectExercise.
  ///
  /// In en, this message translates to:
  /// **'Select Exercise'**
  String get selectExercise;

  /// No description provided for @extendedNutrientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed Nutrition'**
  String get extendedNutrientsTitle;

  /// No description provided for @extendedNutrientsMacrosSection.
  ///
  /// In en, this message translates to:
  /// **'Macros Detail'**
  String get extendedNutrientsMacrosSection;

  /// No description provided for @extendedNutrientsVitaminsSection.
  ///
  /// In en, this message translates to:
  /// **'Vitamins'**
  String get extendedNutrientsVitaminsSection;

  /// No description provided for @extendedNutrientsMineralsSection.
  ///
  /// In en, this message translates to:
  /// **'Minerals'**
  String get extendedNutrientsMineralsSection;

  /// No description provided for @nutrientFiber.
  ///
  /// In en, this message translates to:
  /// **'Fibre'**
  String get nutrientFiber;

  /// No description provided for @nutrientSugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get nutrientSugar;

  /// No description provided for @nutrientSaturatedFat.
  ///
  /// In en, this message translates to:
  /// **'Saturated Fat'**
  String get nutrientSaturatedFat;

  /// No description provided for @nutrientSalt.
  ///
  /// In en, this message translates to:
  /// **'Salt'**
  String get nutrientSalt;

  /// No description provided for @nutrientSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get nutrientSodium;

  /// No description provided for @nutrientVitaminA.
  ///
  /// In en, this message translates to:
  /// **'Vitamin A'**
  String get nutrientVitaminA;

  /// No description provided for @nutrientVitaminC.
  ///
  /// In en, this message translates to:
  /// **'Vitamin C'**
  String get nutrientVitaminC;

  /// No description provided for @nutrientVitaminD.
  ///
  /// In en, this message translates to:
  /// **'Vitamin D'**
  String get nutrientVitaminD;

  /// No description provided for @nutrientVitaminE.
  ///
  /// In en, this message translates to:
  /// **'Vitamin E'**
  String get nutrientVitaminE;

  /// No description provided for @nutrientVitaminK.
  ///
  /// In en, this message translates to:
  /// **'Vitamin K'**
  String get nutrientVitaminK;

  /// No description provided for @nutrientVitaminB1.
  ///
  /// In en, this message translates to:
  /// **'Vitamin B1 (Thiamine)'**
  String get nutrientVitaminB1;

  /// No description provided for @nutrientVitaminB2.
  ///
  /// In en, this message translates to:
  /// **'Vitamin B2 (Riboflavin)'**
  String get nutrientVitaminB2;

  /// No description provided for @nutrientVitaminB3.
  ///
  /// In en, this message translates to:
  /// **'Vitamin B3 (Niacin)'**
  String get nutrientVitaminB3;

  /// No description provided for @nutrientVitaminB6.
  ///
  /// In en, this message translates to:
  /// **'Vitamin B6'**
  String get nutrientVitaminB6;

  /// No description provided for @nutrientVitaminB9.
  ///
  /// In en, this message translates to:
  /// **'Vitamin B9 (Folate)'**
  String get nutrientVitaminB9;

  /// No description provided for @nutrientVitaminB12.
  ///
  /// In en, this message translates to:
  /// **'Vitamin B12'**
  String get nutrientVitaminB12;

  /// No description provided for @nutrientCalcium.
  ///
  /// In en, this message translates to:
  /// **'Calcium'**
  String get nutrientCalcium;

  /// No description provided for @nutrientIron.
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get nutrientIron;

  /// No description provided for @nutrientMagnesium.
  ///
  /// In en, this message translates to:
  /// **'Magnesium'**
  String get nutrientMagnesium;

  /// No description provided for @nutrientPotassium.
  ///
  /// In en, this message translates to:
  /// **'Potassium'**
  String get nutrientPotassium;

  /// No description provided for @nutrientZinc.
  ///
  /// In en, this message translates to:
  /// **'Zinc'**
  String get nutrientZinc;

  /// No description provided for @unitMg.
  ///
  /// In en, this message translates to:
  /// **'mg'**
  String get unitMg;

  /// No description provided for @unitUg.
  ///
  /// In en, this message translates to:
  /// **'µg'**
  String get unitUg;

  /// No description provided for @premiumFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Feature'**
  String get premiumFeatureTitle;

  /// No description provided for @premiumFeatureBody.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium to see detailed nutrition data including vitamins and minerals.'**
  String get premiumFeatureBody;

  /// No description provided for @premiumBadge.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumBadge;

  /// No description provided for @upgradeToPremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremium;

  /// No description provided for @goPremiumBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get goPremiumBannerTitle;

  /// No description provided for @goPremiumBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlimited plans, full history & analytics'**
  String get goPremiumBannerSubtitle;

  /// No description provided for @goPremiumBannerButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get goPremiumBannerButton;

  /// No description provided for @paywallUnlockPotential.
  ///
  /// In en, this message translates to:
  /// **'Unlock your full potential'**
  String get paywallUnlockPotential;

  /// No description provided for @paywallNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No plans available.'**
  String get paywallNoPlans;

  /// No description provided for @paywallRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestorePurchases;

  /// No description provided for @paywallError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong loading the paywall. Please try again.'**
  String get paywallError;

  /// No description provided for @noActivePurchasesFound.
  ///
  /// In en, this message translates to:
  /// **'No active purchases found for this account.'**
  String get noActivePurchasesFound;

  /// No description provided for @paywallFinePrint.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime. Subscription auto-renews until cancelled.'**
  String get paywallFinePrint;

  /// No description provided for @paywallFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'{duration} free trial'**
  String paywallFreeTrial(String duration);

  /// No description provided for @paywallIntroPrice.
  ///
  /// In en, this message translates to:
  /// **'{price} for {duration}'**
  String paywallIntroPrice(String price, String duration);

  /// No description provided for @paywallPeriodDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get paywallPeriodDay;

  /// No description provided for @paywallPeriodDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get paywallPeriodDays;

  /// No description provided for @paywallPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get paywallPeriodWeek;

  /// No description provided for @paywallPeriodWeeks.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get paywallPeriodWeeks;

  /// No description provided for @paywallPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get paywallPeriodMonth;

  /// No description provided for @paywallPeriodMonths.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get paywallPeriodMonths;

  /// No description provided for @paywallPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get paywallPeriodYear;

  /// No description provided for @paywallPeriodYears.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get paywallPeriodYears;

  /// No description provided for @paywallFeatureProgress.
  ///
  /// In en, this message translates to:
  /// **'All-time history & custom date ranges'**
  String get paywallFeatureProgress;

  /// No description provided for @paywallFeaturePlans.
  ///
  /// In en, this message translates to:
  /// **'Unlimited workout plans'**
  String get paywallFeaturePlans;

  /// No description provided for @paywallFeatureTemplates.
  ///
  /// In en, this message translates to:
  /// **'Unlimited meal templates'**
  String get paywallFeatureTemplates;

  /// No description provided for @paywallFeatureCorrelation.
  ///
  /// In en, this message translates to:
  /// **'Weight & calorie correlation chart'**
  String get paywallFeatureCorrelation;

  /// No description provided for @paywallFeatureGraphs.
  ///
  /// In en, this message translates to:
  /// **'Exercise progress graphs'**
  String get paywallFeatureGraphs;

  /// No description provided for @paywallFeatureExport.
  ///
  /// In en, this message translates to:
  /// **'Export workout data (CSV)'**
  String get paywallFeatureExport;

  /// No description provided for @paywallFeatureNutrition.
  ///
  /// In en, this message translates to:
  /// **'Detailed nutrition breakdown — vitamins & minerals'**
  String get paywallFeatureNutrition;

  /// No description provided for @paywallFeatureCustomFoods.
  ///
  /// In en, this message translates to:
  /// **'Unlimited custom foods (free: up to 10)'**
  String get paywallFeatureCustomFoods;

  /// No description provided for @paywallFeatureLongPlans.
  ///
  /// In en, this message translates to:
  /// **'Extended workout plan durations — up to 1 year'**
  String get paywallFeatureLongPlans;

  /// No description provided for @paywallFeatureFreeChoice.
  ///
  /// In en, this message translates to:
  /// **'Free choice workout mode — schedule any workout on any day'**
  String get paywallFeatureFreeChoice;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all your data including workouts, meals, and weight history. Any trainer relationships will also be removed. This cannot be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please check your password and try again.'**
  String get deleteAccountError;

  /// No description provided for @planDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan Duration'**
  String get planDurationLabel;

  /// No description provided for @nWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count} weeks'**
  String nWeeks(int count);

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @resetYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetYourPassword;

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the email address linked to your account and we\'ll send you a reset link.'**
  String get forgotPasswordDescription;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @resetLinkSentBody.
  ///
  /// In en, this message translates to:
  /// **'If an account is linked to {email}, you\'ll receive a reset link shortly.'**
  String resetLinkSentBody(String email);

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push all pending local changes to the server'**
  String get syncNowSubtitle;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncComplete;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailed(Object error);

  /// No description provided for @restoreFromServer.
  ///
  /// In en, this message translates to:
  /// **'Restore from server'**
  String get restoreFromServer;

  /// No description provided for @restoreFromServerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download server data to this device'**
  String get restoreFromServerSubtitle;

  /// No description provided for @restoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get restoreComplete;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailed(Object error);

  /// No description provided for @premiumUpgradeMultiplePlans.
  ///
  /// In en, this message translates to:
  /// **'Premium — upgrade to create unlimited plans'**
  String get premiumUpgradeMultiplePlans;

  /// No description provided for @freeTemplateLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Free limit reached — upgrade to create more than 3 templates'**
  String get freeTemplateLimitReached;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(int count);

  /// No description provided for @sortResults.
  ///
  /// In en, this message translates to:
  /// **'Sort results'**
  String get sortResults;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @sortRelevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get sortRelevance;

  /// No description provided for @sortHighestProtein.
  ///
  /// In en, this message translates to:
  /// **'Highest protein'**
  String get sortHighestProtein;

  /// No description provided for @sortLowestCalories.
  ///
  /// In en, this message translates to:
  /// **'Lowest calories'**
  String get sortLowestCalories;

  /// No description provided for @sortLowestCarbs.
  ///
  /// In en, this message translates to:
  /// **'Lowest carbs'**
  String get sortLowestCarbs;

  /// No description provided for @sortLowestFat.
  ///
  /// In en, this message translates to:
  /// **'Lowest fat'**
  String get sortLowestFat;

  /// No description provided for @sortHighestFibre.
  ///
  /// In en, this message translates to:
  /// **'Highest fibre'**
  String get sortHighestFibre;

  /// No description provided for @tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests — please wait a moment and try again.'**
  String get tooManyRequests;

  /// No description provided for @couldNotFetchProductData.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch product data. Please try again.'**
  String get couldNotFetchProductData;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @requestedPlanNotFound.
  ///
  /// In en, this message translates to:
  /// **'Requested plan not found and no plans exist'**
  String get requestedPlanNotFound;

  /// No description provided for @requestedPlanNotFoundShowingAll.
  ///
  /// In en, this message translates to:
  /// **'Requested plan not found — showing all plans'**
  String get requestedPlanNotFoundShowingAll;

  /// No description provided for @foundTemplateWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Found {count} template workout(s) from your scheduled workouts that can be added to this plan.'**
  String foundTemplateWorkouts(int count);

  /// No description provided for @addWorkoutsToPlanHint.
  ///
  /// In en, this message translates to:
  /// **'To add workouts to this plan:\n\n1. Import workout templates using the CSV import button\n2. Use the + button to add imported workouts to this plan\n3. Scheduled workouts are separate from plan templates'**
  String get addWorkoutsToPlanHint;

  /// No description provided for @syncSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncSectionLabel;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter and confirm your new password below.'**
  String get resetPasswordDescription;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordButton;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully. You can now log in.'**
  String get passwordResetSuccess;

  /// No description provided for @passwordResetExpired.
  ///
  /// In en, this message translates to:
  /// **'This link has expired or has already been used.'**
  String get passwordResetExpired;

  /// No description provided for @templateBatchWeight.
  ///
  /// In en, this message translates to:
  /// **'Total batch weight (g)'**
  String get templateBatchWeight;

  /// No description provided for @templateBatchWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. weigh your full pot / tray after cooking'**
  String get templateBatchWeightHint;

  /// No description provided for @templateFullBatch.
  ///
  /// In en, this message translates to:
  /// **'Full batch: {weight}g • {calories} kcal'**
  String templateFullBatch(String weight, String calories);

  /// No description provided for @templatePortionLabel.
  ///
  /// In en, this message translates to:
  /// **'Your portion (g)'**
  String get templatePortionLabel;

  /// No description provided for @templateLogFull.
  ///
  /// In en, this message translates to:
  /// **'Log Full Template'**
  String get templateLogFull;

  /// No description provided for @templateLogPortion.
  ///
  /// In en, this message translates to:
  /// **'Log Portion'**
  String get templateLogPortion;

  /// No description provided for @coachChat.
  ///
  /// In en, this message translates to:
  /// **'Your coach'**
  String get coachChat;

  /// No description provided for @coachChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Message your trainer'**
  String get coachChatSubtitle;

  /// No description provided for @coachChatNoCoach.
  ///
  /// In en, this message translates to:
  /// **'No coach yet'**
  String get coachChatNoCoach;

  /// No description provided for @coachChatNoCoachBody.
  ///
  /// In en, this message translates to:
  /// **'When a trainer adds you to their roster you can message them here.'**
  String get coachChatNoCoachBody;

  /// No description provided for @coachChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get coachChatEmpty;

  /// No description provided for @coachChatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Ask your coach anything — they will see it right away.'**
  String get coachChatEmptyBody;

  /// No description provided for @coachChatLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this conversation.'**
  String get coachChatLoadError;

  /// No description provided for @chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatComposerHint;

  /// No description provided for @chatSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatSendMessage;

  /// No description provided for @chatSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get chatSending;

  /// No description provided for @chatFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to send — tap to retry'**
  String get chatFailedRetry;

  /// No description provided for @chatReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get chatReconnecting;

  /// No description provided for @chatOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatOffline;

  /// No description provided for @chatAttachmentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachments are not available yet'**
  String get chatAttachmentsUnavailable;

  /// No description provided for @chatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Messaging is unavailable'**
  String get chatUnavailable;

  /// No description provided for @chatUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Chat could not start on this device. Restart the app, and if it keeps happening let support know.'**
  String get chatUnavailableBody;

  /// No description provided for @trainerConsole.
  ///
  /// In en, this message translates to:
  /// **'Trainer Console'**
  String get trainerConsole;

  /// No description provided for @trainerConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your clients'**
  String get trainerConsoleSubtitle;

  /// No description provided for @consoleNavDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get consoleNavDashboard;

  /// No description provided for @consoleNavMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get consoleNavMessages;

  /// No description provided for @consoleNavBuilder.
  ///
  /// In en, this message translates to:
  /// **'Workout Builder'**
  String get consoleNavBuilder;

  /// No description provided for @consoleNavNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get consoleNavNutrition;

  /// No description provided for @consoleNavSessionReview.
  ///
  /// In en, this message translates to:
  /// **'Session Review'**
  String get consoleNavSessionReview;

  /// No description provided for @consoleNavDashboardShort.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get consoleNavDashboardShort;

  /// No description provided for @consoleNavMessagesShort.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get consoleNavMessagesShort;

  /// No description provided for @consoleNavBuilderShort.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get consoleNavBuilderShort;

  /// No description provided for @consoleNavNutritionShort.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get consoleNavNutritionShort;

  /// No description provided for @consoleNavSessionReviewShort.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get consoleNavSessionReviewShort;

  /// No description provided for @consoleMyTraining.
  ///
  /// In en, this message translates to:
  /// **'My training'**
  String get consoleMyTraining;

  /// No description provided for @consoleSwitchToMyTraining.
  ///
  /// In en, this message translates to:
  /// **'Switch to my training'**
  String get consoleSwitchToMyTraining;

  /// No description provided for @consoleLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get consoleLoading;

  /// No description provided for @trainerAccessOnly.
  ///
  /// In en, this message translates to:
  /// **'Trainer access only'**
  String get trainerAccessOnly;

  /// No description provided for @trainerAccessOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'This area is for trainers managing clients. If you should have access, ask your gym to enable it on your account.'**
  String get trainerAccessOnlyBody;

  /// No description provided for @dashboardLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading dashboard'**
  String get dashboardLoading;

  /// No description provided for @clientsHeading.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clientsHeading;

  /// No description provided for @kpiActiveClients.
  ///
  /// In en, this message translates to:
  /// **'Active clients'**
  String get kpiActiveClients;

  /// No description provided for @kpiAvgAdherence.
  ///
  /// In en, this message translates to:
  /// **'Avg adherence'**
  String get kpiAvgAdherence;

  /// No description provided for @kpiSessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Sessions this week'**
  String get kpiSessionsThisWeek;

  /// No description provided for @rosterEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get rosterEmptyTitle;

  /// No description provided for @rosterEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create an invite code and share it with your first client. They enter it under \"Join a trainer\".'**
  String get rosterEmptyBody;

  /// No description provided for @rosterGridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get rosterGridView;

  /// No description provided for @rosterTableView.
  ///
  /// In en, this message translates to:
  /// **'Table view'**
  String get rosterTableView;

  /// No description provided for @rosterColumnClient.
  ///
  /// In en, this message translates to:
  /// **'CLIENT'**
  String get rosterColumnClient;

  /// No description provided for @rosterColumnProgram.
  ///
  /// In en, this message translates to:
  /// **'PROGRAM'**
  String get rosterColumnProgram;

  /// No description provided for @rosterColumnAdherence.
  ///
  /// In en, this message translates to:
  /// **'ADHERENCE'**
  String get rosterColumnAdherence;

  /// No description provided for @rosterColumnLastSession.
  ///
  /// In en, this message translates to:
  /// **'LAST SESSION'**
  String get rosterColumnLastSession;

  /// No description provided for @noActivePlan.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get noActivePlan;

  /// No description provided for @noSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsYet;

  /// No description provided for @lastSessionOn.
  ///
  /// In en, this message translates to:
  /// **'Last: {date}'**
  String lastSessionOn(String date);

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @inviteAClient.
  ///
  /// In en, this message translates to:
  /// **'Invite a client'**
  String get inviteAClient;

  /// No description provided for @inviteSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Share the code with your client. They enter it under \"Join a trainer\" in their app.'**
  String get inviteSheetBody;

  /// No description provided for @createInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get createInviteCode;

  /// No description provided for @createNewInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Create a new invite code'**
  String get createNewInviteCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied'**
  String get inviteCodeCopied;

  /// No description provided for @inviteCodeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Invite code {code}'**
  String inviteCodeSemantics(String code);

  /// No description provided for @inviteExpiresInSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in 7 days.'**
  String get inviteExpiresInSevenDays;

  /// No description provided for @copyInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Copy {code}'**
  String copyInviteCode(String code);

  /// No description provided for @withdrawInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Withdraw {code}'**
  String withdrawInviteCode(String code);

  /// No description provided for @outstandingInvites.
  ///
  /// In en, this message translates to:
  /// **'Outstanding invites'**
  String get outstandingInvites;

  /// No description provided for @outstandingInvitesBody.
  ///
  /// In en, this message translates to:
  /// **'Each of these holds a seat until it is used or withdrawn.'**
  String get outstandingInvitesBody;

  /// No description provided for @inviteExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get inviteExpired;

  /// No description provided for @inviteExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get inviteExpiresToday;

  /// No description provided for @inviteExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Expires in 1 day} other{Expires in {days} days}}'**
  String inviteExpiresInDays(num days);

  /// No description provided for @withdrawInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw this invite?'**
  String get withdrawInviteTitle;

  /// No description provided for @withdrawInviteBody.
  ///
  /// In en, this message translates to:
  /// **'{code} will stop working and its seat is freed. Anyone you already sent it to will need a new code.'**
  String withdrawInviteBody(String code);

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @inviteBlockedLapsed.
  ///
  /// In en, this message translates to:
  /// **'Renew your licence to invite clients.'**
  String get inviteBlockedLapsed;

  /// No description provided for @inviteBlockedFull.
  ///
  /// In en, this message translates to:
  /// **'All {seats} seats are in use. Withdraw an invite or upgrade.'**
  String inviteBlockedFull(int seats);

  /// No description provided for @seatMeterUsage.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} clients'**
  String seatMeterUsage(int used, int limit);

  /// No description provided for @seatMeterOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Over your plan. Existing clients keep working; you can\'t add more.'**
  String get seatMeterOverLimit;

  /// No description provided for @seatMeterFull.
  ///
  /// In en, this message translates to:
  /// **'Plan full. Free a seat or upgrade to add more.'**
  String get seatMeterFull;

  /// No description provided for @seatMeterRemaining.
  ///
  /// In en, this message translates to:
  /// **'{seats} seats left'**
  String seatMeterRemaining(int seats);

  /// No description provided for @seatMeterSemantics.
  ///
  /// In en, this message translates to:
  /// **'{usage}. {caption}'**
  String seatMeterSemantics(String usage, String caption);

  /// No description provided for @seatChipSemantics.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} client seats used. {tier} plan. Open plan settings.'**
  String seatChipSemantics(int used, int limit, String tier);

  /// No description provided for @seatChipTooltip.
  ///
  /// In en, this message translates to:
  /// **'{tier} — {used}/{limit} clients'**
  String seatChipTooltip(String tier, int used, int limit);

  /// No description provided for @licenceTierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get licenceTierFree;

  /// No description provided for @licenceTierSolo.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get licenceTierSolo;

  /// No description provided for @licenceTierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get licenceTierPro;

  /// No description provided for @licenceTierStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get licenceTierStudio;

  /// No description provided for @licenceStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get licenceStatusActive;

  /// No description provided for @licenceStatusTrialing.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get licenceStatusTrialing;

  /// No description provided for @licenceStatusPastDue.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get licenceStatusPastDue;

  /// No description provided for @licenceStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get licenceStatusCanceled;

  /// No description provided for @licenceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your plan…'**
  String get licenceLoading;

  /// No description provided for @licenceLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading your plan'**
  String get licenceLoadingLabel;

  /// No description provided for @yourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get yourPlan;

  /// No description provided for @yourPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Seats, billing and invites'**
  String get yourPlanSubtitle;

  /// No description provided for @noPlanYet.
  ///
  /// In en, this message translates to:
  /// **'No plan yet'**
  String get noPlanYet;

  /// No description provided for @noPlanYetBody.
  ///
  /// In en, this message translates to:
  /// **'Set up a trainer plan to start taking on clients.'**
  String get noPlanYetBody;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setUp;

  /// No description provided for @setUpTrainerConsole.
  ///
  /// In en, this message translates to:
  /// **'Set up Trainer Console'**
  String get setUpTrainerConsole;

  /// No description provided for @setUpTrainerConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coach up to 3 clients free'**
  String get setUpTrainerConsoleSubtitle;

  /// No description provided for @changePlan.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get changePlan;

  /// No description provided for @planLadderFootnote.
  ///
  /// In en, this message translates to:
  /// **'Paid plans include ForgeForm Pro for you and every client on your roster. The free plan covers {seats} clients without Pro.'**
  String planLadderFootnote(int seats);

  /// No description provided for @tierPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'{tier} plan'**
  String tierPlanTitle(String tier);

  /// No description provided for @proIncluded.
  ///
  /// In en, this message translates to:
  /// **'Pro included for you and every client'**
  String get proIncluded;

  /// No description provided for @proNotIncluded.
  ///
  /// In en, this message translates to:
  /// **'Pro not included — upgrade to cover your clients'**
  String get proNotIncluded;

  /// No description provided for @manageBilling.
  ///
  /// In en, this message translates to:
  /// **'Manage billing'**
  String get manageBilling;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusLabel(String status);

  /// No description provided for @tierSeatsAndPro.
  ///
  /// In en, this message translates to:
  /// **'Up to {seats} clients, Pro included'**
  String tierSeatsAndPro(int seats);

  /// No description provided for @planCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get planCurrent;

  /// No description provided for @licenceLapsedBanner.
  ///
  /// In en, this message translates to:
  /// **'Your licence has lapsed. Your clients are still here, but you can\'t change their plans and they\'ve lost Pro.'**
  String get licenceLapsedBanner;

  /// No description provided for @licenceRenew.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get licenceRenew;

  /// No description provided for @licenceGraceBanner.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Everything keeps working until {date} — after that your clients lose Pro.'**
  String licenceGraceBanner(String date);

  /// No description provided for @licenceFixPayment.
  ///
  /// In en, this message translates to:
  /// **'Fix payment'**
  String get licenceFixPayment;

  /// No description provided for @licenceOverLimitBanner.
  ///
  /// In en, this message translates to:
  /// **'You have {used} clients on a {limit}-seat plan. Nobody is removed, but you can\'t add more.'**
  String licenceOverLimitBanner(int used, int limit);

  /// No description provided for @licenceUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get licenceUpgrade;

  /// No description provided for @licenceFullBanner.
  ///
  /// In en, this message translates to:
  /// **'All {limit} seats on your {tier} plan are in use.'**
  String licenceFullBanner(int limit, String tier);

  /// No description provided for @traineeProLapsingBanner.
  ///
  /// In en, this message translates to:
  /// **'Pro through your trainer ends {date}. Your data stays put — Pro features just lock.'**
  String traineeProLapsingBanner(String date);

  /// No description provided for @traineeKeepPro.
  ///
  /// In en, this message translates to:
  /// **'Keep Pro'**
  String get traineeKeepPro;

  /// No description provided for @inviteFailureSeatLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Your plan is full. Upgrade or free up a seat to invite another client.'**
  String get inviteFailureSeatLimitReached;

  /// No description provided for @inviteFailureLicenceLapsed.
  ///
  /// In en, this message translates to:
  /// **'Your licence has lapsed. Renew it to take on new clients.'**
  String get inviteFailureLicenceLapsed;

  /// No description provided for @inviteFailureNotATrainer.
  ///
  /// In en, this message translates to:
  /// **'Set up a trainer plan before inviting clients.'**
  String get inviteFailureNotATrainer;

  /// No description provided for @inviteFailureInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match an invite. Check it and try again.'**
  String get inviteFailureInvalidCode;

  /// No description provided for @inviteFailureExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'That invite has expired. Ask your trainer for a new code.'**
  String get inviteFailureExpiredCode;

  /// No description provided for @inviteFailureSelfInvite.
  ///
  /// In en, this message translates to:
  /// **'That\'s your own invite code.'**
  String get inviteFailureSelfInvite;

  /// No description provided for @inviteFailureTrainerAtSeatLimit.
  ///
  /// In en, this message translates to:
  /// **'Your trainer\'s plan is full. Ask them to free up a seat.'**
  String get inviteFailureTrainerAtSeatLimit;

  /// No description provided for @inviteFailureTrainerNotEntitled.
  ///
  /// In en, this message translates to:
  /// **'Your trainer\'s plan isn\'t active. Ask them to renew it.'**
  String get inviteFailureTrainerNotEntitled;

  /// No description provided for @inviteFailureNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach ForgeForm. Check your connection and try again.'**
  String get inviteFailureNetwork;

  /// No description provided for @errorLoadRoster.
  ///
  /// In en, this message translates to:
  /// **'Could not load your clients.'**
  String get errorLoadRoster;

  /// No description provided for @errorLoadDashboard.
  ///
  /// In en, this message translates to:
  /// **'Could not load your dashboard.'**
  String get errorLoadDashboard;

  /// No description provided for @errorLoadClientDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not load this client’s details.'**
  String get errorLoadClientDetail;

  /// No description provided for @errorLoadNutrition.
  ///
  /// In en, this message translates to:
  /// **'Could not load this client’s nutrition.'**
  String get errorLoadNutrition;

  /// No description provided for @errorLoadSessions.
  ///
  /// In en, this message translates to:
  /// **'Could not load this client’s sessions.'**
  String get errorLoadSessions;

  /// No description provided for @errorLoadLicence.
  ///
  /// In en, this message translates to:
  /// **'Could not load your plan.'**
  String get errorLoadLicence;

  /// No description provided for @errorLoadWorkoutPlans.
  ///
  /// In en, this message translates to:
  /// **'Could not load workout plans.'**
  String get errorLoadWorkoutPlans;

  /// No description provided for @errorPlanNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the plan a name.'**
  String get errorPlanNameRequired;

  /// No description provided for @errorCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Could not create the plan.'**
  String get errorCreatePlan;

  /// No description provided for @errorCreateInvite.
  ///
  /// In en, this message translates to:
  /// **'Could not create an invite. Try again.'**
  String get errorCreateInvite;

  /// No description provided for @errorWithdrawInvite.
  ///
  /// In en, this message translates to:
  /// **'Could not withdraw that invite. Try again.'**
  String get errorWithdrawInvite;

  /// No description provided for @errorOpenCheckout.
  ///
  /// In en, this message translates to:
  /// **'Could not open checkout. Try again.'**
  String get errorOpenCheckout;

  /// No description provided for @errorOpenBilling.
  ///
  /// In en, this message translates to:
  /// **'Could not open billing. Try again.'**
  String get errorOpenBilling;

  /// No description provided for @clientDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading client details'**
  String get clientDetailLoading;

  /// No description provided for @adherence.
  ///
  /// In en, this message translates to:
  /// **'Adherence'**
  String get adherence;

  /// No description provided for @clientCurrentWeight.
  ///
  /// In en, this message translates to:
  /// **'Current weight'**
  String get clientCurrentWeight;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @planStartedOn.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String planStartedOn(String date);

  /// No description provided for @weightTrend.
  ///
  /// In en, this message translates to:
  /// **'Weight trend'**
  String get weightTrend;

  /// No description provided for @weightTrendEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Not enough weight data'**
  String get weightTrendEmptyTitle;

  /// No description provided for @weightTrendEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Two or more logged weigh-ins are needed to show a trend.'**
  String get weightTrendEmptyBody;

  /// No description provided for @entryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String entryCount(num count);

  /// No description provided for @weightTrendSemantics.
  ///
  /// In en, this message translates to:
  /// **'Weight from {from} to {to} kilograms'**
  String weightTrendSemantics(String from, String to);

  /// No description provided for @attendanceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No attendance data'**
  String get attendanceEmptyTitle;

  /// No description provided for @attendanceEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Attendance appears once sessions are scheduled.'**
  String get attendanceEmptyBody;

  /// No description provided for @attendanceByWeek.
  ///
  /// In en, this message translates to:
  /// **'Attendance by week'**
  String get attendanceByWeek;

  /// No description provided for @attendanceWeekSemantics.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}: {completed} of {planned} sessions'**
  String attendanceWeekSemantics(String date, int completed, int planned);

  /// No description provided for @strengthEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No strength data'**
  String get strengthEmptyTitle;

  /// No description provided for @strengthEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Progression appears once completed sets are logged.'**
  String get strengthEmptyBody;

  /// No description provided for @strengthProgression.
  ///
  /// In en, this message translates to:
  /// **'Strength progression'**
  String get strengthProgression;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @todaysMacros.
  ///
  /// In en, this message translates to:
  /// **'Today’s macros'**
  String get todaysMacros;

  /// No description provided for @caloriesOfGoal.
  ///
  /// In en, this message translates to:
  /// **'{eaten} / {goal} kcal'**
  String caloriesOfGoal(int eaten, int goal);

  /// No description provided for @macroSummaryNone.
  ///
  /// In en, this message translates to:
  /// **'No macros logged'**
  String get macroSummaryNone;

  /// No description provided for @macroSummarySemantics.
  ///
  /// In en, this message translates to:
  /// **'Protein {protein}g, carbs {carbs}g, fat {fat}g'**
  String macroSummarySemantics(String protein, String carbs, String fat);

  /// No description provided for @switchClientSemantics.
  ///
  /// In en, this message translates to:
  /// **'Switch client. Currently {name}'**
  String switchClientSemantics(String name);

  /// No description provided for @switchClientHeading.
  ///
  /// In en, this message translates to:
  /// **'SWITCH CLIENT'**
  String get switchClientHeading;

  /// No description provided for @conversationsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading conversations'**
  String get conversationsLoading;

  /// No description provided for @conversationsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your conversations.'**
  String get conversationsLoadError;

  /// No description provided for @conversationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get conversationsEmpty;

  /// No description provided for @conversationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Once a client accepts your invite you can message them here.'**
  String get conversationsEmptyBody;

  /// No description provided for @backToConversations.
  ///
  /// In en, this message translates to:
  /// **'Back to conversations'**
  String get backToConversations;

  /// No description provided for @pickAConversation.
  ///
  /// In en, this message translates to:
  /// **'Pick a conversation'**
  String get pickAConversation;

  /// No description provided for @pickAConversationBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a client on the left to see your messages.'**
  String get pickAConversationBody;

  /// No description provided for @messagesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading messages'**
  String get messagesLoading;

  /// No description provided for @trainerThreadEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Say hello — this is the start of your conversation.'**
  String get trainerThreadEmptyBody;

  /// No description provided for @clientStatsElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Client stats appear on the dashboard and client detail screens.'**
  String get clientStatsElsewhere;

  /// No description provided for @nutritionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily intake and 7-day trend'**
  String get nutritionSubtitle;

  /// No description provided for @nutritionSubtitleNoClient.
  ///
  /// In en, this message translates to:
  /// **'Select a client to review their intake'**
  String get nutritionSubtitleNoClient;

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @nutritionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading nutrition'**
  String get nutritionLoading;

  /// No description provided for @nutritionNoClientsBody.
  ///
  /// In en, this message translates to:
  /// **'Invite your first client to monitor their nutrition.'**
  String get nutritionNoClientsBody;

  /// No description provided for @nothingLogged.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged'**
  String get nothingLogged;

  /// No description provided for @nothingLoggedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} didn’t log any meals on this day.'**
  String nothingLoggedBody(String name);

  /// No description provided for @mealsLogged.
  ///
  /// In en, this message translates to:
  /// **'Meals logged'**
  String get mealsLogged;

  /// No description provided for @meal.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get meal;

  /// No description provided for @noTrendYet.
  ///
  /// In en, this message translates to:
  /// **'No trend yet'**
  String get noTrendYet;

  /// No description provided for @noTrendYetBody.
  ///
  /// In en, this message translates to:
  /// **'Once meals are logged, the 7-day trend appears here.'**
  String get noTrendYetBody;

  /// No description provided for @caloriesVsTarget.
  ///
  /// In en, this message translates to:
  /// **'Calories vs. target'**
  String get caloriesVsTarget;

  /// No description provided for @withinTarget.
  ///
  /// In en, this message translates to:
  /// **'Within target'**
  String get withinTarget;

  /// No description provided for @overTarget.
  ///
  /// In en, this message translates to:
  /// **'Over target'**
  String get overTarget;

  /// No description provided for @targetCalories.
  ///
  /// In en, this message translates to:
  /// **'Target {goal} kcal'**
  String targetCalories(int goal);

  /// No description provided for @trendBarSemantics.
  ///
  /// In en, this message translates to:
  /// **'{day}: {calories} kcal'**
  String trendBarSemantics(String day, int calories);

  /// No description provided for @trendBarSemanticsOver.
  ///
  /// In en, this message translates to:
  /// **'{day}: {calories} kcal, over target'**
  String trendBarSemanticsOver(String day, int calories);

  /// No description provided for @builderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create and assign a plan'**
  String get builderSubtitle;

  /// No description provided for @builderSubtitleNoClient.
  ///
  /// In en, this message translates to:
  /// **'Select a client to build a plan'**
  String get builderSubtitleNoClient;

  /// No description provided for @newPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlan;

  /// No description provided for @builderLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading workout builder'**
  String get builderLoading;

  /// No description provided for @builderNoClientsBody.
  ///
  /// In en, this message translates to:
  /// **'Invite your first client to build them a plan.'**
  String get builderNoClientsBody;

  /// No description provided for @planAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Plan assigned to {name}'**
  String planAssignedTo(String name);

  /// No description provided for @builderPlanName.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get builderPlanName;

  /// No description provided for @builderPlanNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Push / Pull / Legs'**
  String get builderPlanNameHint;

  /// No description provided for @planNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the plan a name'**
  String get planNameRequired;

  /// No description provided for @planDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get planDescriptionOptional;

  /// No description provided for @assignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to {name}'**
  String assignTo(String name);

  /// No description provided for @startFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get startFromTemplate;

  /// No description provided for @templateDaysAndDescription.
  ///
  /// In en, this message translates to:
  /// **'{days} days · {description}'**
  String templateDaysAndDescription(int days, String description);

  /// No description provided for @noActivePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get noActivePlanTitle;

  /// No description provided for @noActivePlanBody.
  ///
  /// In en, this message translates to:
  /// **'{name} isn’t on a plan yet.'**
  String noActivePlanBody(String name);

  /// No description provided for @createAPlan.
  ///
  /// In en, this message translates to:
  /// **'Create a plan'**
  String get createAPlan;

  /// No description provided for @planActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get planActive;

  /// No description provided for @exerciseEditingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Exercise editing isn’t available yet'**
  String get exerciseEditingUnavailable;

  /// No description provided for @exerciseEditingUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Plans can be created and assigned. Editing a plan’s exercises, sets and reps needs a trainer-facing API that doesn’t exist yet.'**
  String get exerciseEditingUnavailableBody;

  /// No description provided for @sessionReviewSubtitleNoClient.
  ///
  /// In en, this message translates to:
  /// **'Select a client to review their sessions'**
  String get sessionReviewSubtitleNoClient;

  /// No description provided for @sessionReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What {name} actually logged'**
  String sessionReviewSubtitle(String name);

  /// No description provided for @sessionReviewSubtitleWithCounts.
  ///
  /// In en, this message translates to:
  /// **'What {name} actually logged — {total} sessions, {done} completed, {missed} missed'**
  String sessionReviewSubtitleWithCounts(
    String name,
    int total,
    int done,
    int missed,
  );

  /// No description provided for @sessionsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading sessions'**
  String get sessionsLoading;

  /// No description provided for @sessionReviewNoClientsBody.
  ///
  /// In en, this message translates to:
  /// **'Invite your first client to start reviewing their sessions.'**
  String get sessionReviewNoClientsBody;

  /// No description provided for @noSessionsLoggedTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions logged yet'**
  String get noSessionsLoggedTitle;

  /// No description provided for @noSessionsLoggedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} hasn’t recorded a workout yet.'**
  String noSessionsLoggedBody(String name);

  /// No description provided for @sessionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sessionCompleted;

  /// No description provided for @sessionPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get sessionPartial;

  /// No description provided for @sessionMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get sessionMissed;

  /// No description provided for @sessionSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get sessionSkipped;

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String dateToday(String date);

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday · {date}'**
  String dateYesterday(String date);

  /// No description provided for @sessionHistory.
  ///
  /// In en, this message translates to:
  /// **'Session history'**
  String get sessionHistory;

  /// No description provided for @workout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @noWorkoutLoggedTitle.
  ///
  /// In en, this message translates to:
  /// **'No workout logged'**
  String get noWorkoutLoggedTitle;

  /// No description provided for @noWorkoutLoggedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} didn’t record this session.'**
  String noWorkoutLoggedBody(String name);

  /// No description provided for @newPr.
  ///
  /// In en, this message translates to:
  /// **'NEW PR'**
  String get newPr;

  /// No description provided for @pr.
  ///
  /// In en, this message translates to:
  /// **'PR'**
  String get pr;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @avgRpe.
  ///
  /// In en, this message translates to:
  /// **'Avg RPE'**
  String get avgRpe;

  /// No description provided for @clientNote.
  ///
  /// In en, this message translates to:
  /// **'CLIENT NOTE'**
  String get clientNote;

  /// No description provided for @prescribedSummary.
  ///
  /// In en, this message translates to:
  /// **'Prescribed {summary}'**
  String prescribedSummary(String summary);

  /// No description provided for @setColumn.
  ///
  /// In en, this message translates to:
  /// **'SET'**
  String get setColumn;

  /// No description provided for @repsColumn.
  ///
  /// In en, this message translates to:
  /// **'REPS'**
  String get repsColumn;

  /// No description provided for @weightColumn.
  ///
  /// In en, this message translates to:
  /// **'WEIGHT'**
  String get weightColumn;

  /// No description provided for @rpeColumn.
  ///
  /// In en, this message translates to:
  /// **'RPE'**
  String get rpeColumn;

  /// No description provided for @setNumber.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String setNumber(int number);

  /// No description provided for @repsCount.
  ///
  /// In en, this message translates to:
  /// **'{reps} reps'**
  String repsCount(int reps);

  /// No description provided for @bodyweight.
  ///
  /// In en, this message translates to:
  /// **'bodyweight'**
  String get bodyweight;

  /// No description provided for @rpeValue.
  ///
  /// In en, this message translates to:
  /// **'RPE {value}'**
  String rpeValue(String value);

  /// No description provided for @underTarget.
  ///
  /// In en, this message translates to:
  /// **'under target'**
  String get underTarget;

  /// No description provided for @joinATrainer.
  ///
  /// In en, this message translates to:
  /// **'Join a trainer'**
  String get joinATrainer;

  /// No description provided for @joinATrainerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code your trainer gave you'**
  String get joinATrainerSubtitle;

  /// No description provided for @joinTrainerTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a Trainer'**
  String get joinTrainerTitle;

  /// No description provided for @joinTrainerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the code your trainer gave you.'**
  String get joinTrainerPrompt;

  /// No description provided for @trainerCode.
  ///
  /// In en, this message translates to:
  /// **'Trainer Code'**
  String get trainerCode;

  /// No description provided for @joinTrainerAction.
  ///
  /// In en, this message translates to:
  /// **'Join Trainer'**
  String get joinTrainerAction;

  /// No description provided for @joinTrainerDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Your trainer will be able to see your workouts, weight and nutrition. If their plan includes Pro, you get it while you are on their roster.'**
  String get joinTrainerDisclosure;

  /// No description provided for @joinTrainerCodeMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter the 12-character code from your trainer.'**
  String get joinTrainerCodeMissing;

  /// No description provided for @joinTrainerCodeMalformed.
  ///
  /// In en, this message translates to:
  /// **'Codes are 12 characters, digits and letters A–F.'**
  String get joinTrainerCodeMalformed;

  /// No description provided for @joinTrainerConnected.
  ///
  /// In en, this message translates to:
  /// **'You\'re connected to your trainer.'**
  String get joinTrainerConnected;

  /// No description provided for @somethingWentWrongRetry.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get somethingWentWrongRetry;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @searchOnline.
  ///
  /// In en, this message translates to:
  /// **'Search Online'**
  String get searchOnline;

  /// No description provided for @resetEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email. Please try again.'**
  String get resetEmailFailed;

  /// No description provided for @kcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcal;

  /// No description provided for @calorieRingNoGoal.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal logged, no goal set'**
  String calorieRingNoGoal(int kcal);

  /// No description provided for @calorieRingOver.
  ///
  /// In en, this message translates to:
  /// **'{eaten} of {goal} kcal, over by {over}'**
  String calorieRingOver(int eaten, int goal, int over);

  /// No description provided for @calorieRingRemaining.
  ///
  /// In en, this message translates to:
  /// **'{eaten} of {goal} kcal, {remaining} remaining'**
  String calorieRingRemaining(int eaten, int goal, int remaining);

  /// No description provided for @calorieRingGoal.
  ///
  /// In en, this message translates to:
  /// **'/ {goal} kcal'**
  String calorieRingGoal(int goal);

  /// No description provided for @calorieRingOverBy.
  ///
  /// In en, this message translates to:
  /// **'over by {over}'**
  String calorieRingOverBy(int over);

  /// No description provided for @calorieRingLeft.
  ///
  /// In en, this message translates to:
  /// **'{remaining} left'**
  String calorieRingLeft(int remaining);

  /// No description provided for @proteinShort.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get proteinShort;

  /// No description provided for @carbsShort.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get carbsShort;

  /// No description provided for @fatShort.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get fatShort;

  /// No description provided for @gramsShort.
  ///
  /// In en, this message translates to:
  /// **'{grams} g'**
  String gramsShort(int grams);

  /// No description provided for @foodCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 food} other{{count} foods}}'**
  String foodCount(num count);

  /// No description provided for @mealDetailSemantics.
  ///
  /// In en, this message translates to:
  /// **'{meal}, {calories} kcal. Open to see every food logged.'**
  String mealDetailSemantics(String meal, int calories);

  /// No description provided for @foodRowSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {grams} grams, {calories} kcal, protein {protein}g, carbs {carbs}g, fat {fat}g'**
  String foodRowSemantics(
    String name,
    int grams,
    int calories,
    int protein,
    int carbs,
    int fat,
  );

  /// No description provided for @foodRowSemanticsNoWeight.
  ///
  /// In en, this message translates to:
  /// **'{name}, {calories} kcal, protein {protein}g, carbs {carbs}g, fat {fat}g'**
  String foodRowSemanticsNoWeight(
    String name,
    int calories,
    int protein,
    int carbs,
    int fat,
  );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
