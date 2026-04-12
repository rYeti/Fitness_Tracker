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
  /// **'Meal category'**
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
