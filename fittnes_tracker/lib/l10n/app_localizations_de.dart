// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get male => 'Männlich';

  @override
  String get female => 'Weiblich';

  @override
  String get other => 'Andere';

  @override
  String get sedentary => 'Sitzend';

  @override
  String get lightlyActive => 'Leicht aktiv';

  @override
  String get moderatelyActive => 'Mäßig aktiv';

  @override
  String get veryActive => 'Sehr aktiv';

  @override
  String get extremelyActive => 'Extrem aktiv';

  @override
  String get weightLoss => 'Gewichtsverlust';

  @override
  String get muscleGain => 'Muskelaufbau';

  @override
  String get maintenance => 'Erhaltung';

  @override
  String get dashboard => 'Übersicht';

  @override
  String get food => 'Essen';

  @override
  String get gym => 'Fitnessstudio';

  @override
  String get progress => 'Fortschritt';

  @override
  String get settings => 'Einstellungen';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get hidePassword => 'Passwort verbergen';

  @override
  String get quickAdd => 'Schnell hinzufügen';

  @override
  String get age => 'Alter';

  @override
  String get heightCm => 'Größe (cm)';

  @override
  String get dailyCalorieGoal => 'Tägliches Kalorienziel';

  @override
  String get save => 'Speichern';

  @override
  String get saveCalorieGoal => 'Kalorienziel gespeichert';

  @override
  String addFood(Object category) {
    return '$category';
  }

  @override
  String get scanBarcode => 'Barcode scannen';

  @override
  String get nutritionProgress => 'Ernährungsfortschritt';

  @override
  String get foodDetails => 'Lebensmitteldetails';

  @override
  String searchFailed(Object error) {
    return 'Suche fehlgeschlagen: $error';
  }

  @override
  String get pleaseEnterValidAgeAndHeight =>
      'Bitte gültiges Alter und Größe eingeben';

  @override
  String get pleaseEnterValidNumber => 'Bitte eine gültige Zahl eingeben';

  @override
  String get calculatedAndSavedCalorieGoal =>
      'Kalorienziel berechnet und gespeichert';

  @override
  String failedToSaveProfile(Object error) {
    return 'Profil konnte nicht gespeichert werden: $error';
  }

  @override
  String failedToUpdateCalorieGoal(Object error) {
    return 'Kalorienziel konnte nicht aktualisiert werden: $error';
  }

  @override
  String failedToLoadData(Object error) {
    return 'Daten konnten nicht geladen werden: $error';
  }

  @override
  String get sex => 'Geschlecht';

  @override
  String get activity => 'Aktivität';

  @override
  String get goal => 'Ziel';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get addCustomFood => 'Eigenes Lebensmittel hinzufügen';

  @override
  String get foodName => 'Lebensmittelname';

  @override
  String get calories => 'Kalorien';

  @override
  String get protein => 'Protein (g)';

  @override
  String get carbs => 'Kohlenhydrate (g)';

  @override
  String get fat => 'Fett (g)';

  @override
  String get addedSuccessfully => 'erfolgreich hinzugefügt!';

  @override
  String get pleaseEnterAName => 'Bitte einen Namen eingeben';

  @override
  String get pleaseEnterCalories => 'Bitte Kalorien eingeben';

  @override
  String get foodTracker => 'Tracker';

  @override
  String get proteinLabel => 'Protein';

  @override
  String get carbsLabel => 'Kohlenhydrate';

  @override
  String get fatLabel => 'Fett';

  @override
  String get ok => 'OK';

  @override
  String get addFailed => 'Hinzufügen fehlgeschlagen';

  @override
  String get nutritionInformation => 'Nährwertinformationen';

  @override
  String get portionSize => 'Portionsgröße';

  @override
  String get quantityInGrams => 'Menge in Gramm';

  @override
  String get addToTodayLog => 'Zum heutigen Protokoll hinzufügen';

  @override
  String get mealCategory => 'Kategorie';

  @override
  String get addToLog => 'Zum Protokoll hinzufügen';

  @override
  String get mealBreakfast => 'Frühstück';

  @override
  String get mealLunch => 'Mittagessen';

  @override
  String get mealDinner => 'Abendessen';

  @override
  String get mealSnacks => 'Snacks';

  @override
  String get searchForFood => 'Nach Lebensmitteln suchen';

  @override
  String get recentEatenAtThisMeal => 'Bei dieser Mahlzeit gegessen';

  @override
  String get recentOtherFoods => 'Weitere Lebensmittel';

  @override
  String get recentlyAdded => 'Kürzlich hinzugefügt';

  @override
  String addedToRecentFoods(Object name) {
    return '$name wurde zu den kürzlich hinzugefügten Lebensmitteln hinzugefügt';
  }

  @override
  String get noFoodAdded => 'Noch nichts hinzugefügt';

  @override
  String get calculateAndSave => 'Kalorienziel berechnet und gespeichert';

  @override
  String get workoutName => 'Workout Name';

  @override
  String get createWorkout => 'Training erstellen';

  @override
  String get workoutSavedSuccessfully => 'Training erfolgreich gespeichert';

  @override
  String get pleaseEnterWorkoutName =>
      'Bitte geben Sie einen Trainingsnamen ein';

  @override
  String get pleaseEnterAtLeastOneWorkoutDay =>
      'Bitte fügen Sie mindestens einen Trainingstag zum Zyklus hinzu';

  @override
  String get pleaseSelectStartDate => 'Bitte wählen Sie ein Startdatum';

  @override
  String dayRestDay(int day) {
    return 'Tag $day: Ruhetag';
  }

  @override
  String dayWorkout(int day, String workout) {
    return 'Tag $day: $workout';
  }

  @override
  String get noExercisesYet => 'Noch keine Übungen';

  @override
  String get addWorkout => 'Training hinzufügen';

  @override
  String get addRestDay => 'Ruhetag hinzufügen';

  @override
  String get addWorkoutDay => 'Tag hinzufügen';

  @override
  String get workoutNameLabel => 'Trainingsname';

  @override
  String get add => 'Hinzufügen';

  @override
  String get selectStartDate => 'Startdatum wählen';

  @override
  String get back => 'Zurück';

  @override
  String get next => 'Weiter';

  @override
  String stepXofY(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get noScheduledWorkouts => 'Keine geplanten Trainings';

  @override
  String get unknownWorkout => 'Unbekanntes Training';

  @override
  String get workouts => 'Trainings';

  @override
  String get seedWorkoutTemplates => 'Trainingsvorlagen laden (Debug)';

  @override
  String get seedingTemplates => 'Lade Vorlagen...';

  @override
  String seedingFailed(Object error) {
    return 'Laden fehlgeschlagen: $error';
  }

  @override
  String get createOrEditWorkouts => 'Trainings erstellen oder bearbeiten';

  @override
  String get newWorkout => 'Neues Training';

  @override
  String get viewWorkouts => 'Trainings ansehen';

  @override
  String minutesShort(int minutes) {
    return '$minutes Min';
  }

  @override
  String get noSetTemplates => 'Keine Sätze konfiguriert';

  @override
  String setTemplatesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sätze',
      one: '1 Satz',
    );
    return '$_temp0';
  }

  @override
  String get copyToAll => 'Auf alle kopieren';

  @override
  String get repsHelperText => 'z.B. 8-12 oder 10';

  @override
  String get addSet => 'Satz hinzufügen';

  @override
  String get noSetsConfigured => 'Keine Sätze konfiguriert';

  @override
  String get sets => 'Sätze';

  @override
  String get reps => 'Wiederholungen';

  @override
  String get removeSet => 'Satz entfernen';

  @override
  String get setLabel => 'Set';

  @override
  String get previous => 'Vorheriges';

  @override
  String get kg => 'KG';

  @override
  String get weight => 'Gewicht';

  @override
  String get noExercisesForWorkout =>
      'Keine Übungen für dieses Training konfiguriert';

  @override
  String errorLoadingExercises(Object error) {
    return 'Fehler beim Laden der Übungen: $error';
  }

  @override
  String get target => 'Ziel';

  @override
  String get saveWorkout => 'Workout Speichern';

  @override
  String get workoutSaved => 'Training wurde gespeichert.';

  @override
  String get restDay => 'Ruhetag';

  @override
  String get editWorkout => 'Training bearbeiten';

  @override
  String get workoutUpdatedSuccessfully => 'Training erfolgreich aktualisiert';

  @override
  String saveFailed(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get addExercise => 'Übung hinzufügen';

  @override
  String editSet(int setNumber) {
    return 'Satz $setNumber bearbeiten';
  }

  @override
  String get noExercisesInWorkout => 'Keine Übungen in diesem Training';

  @override
  String get setsLabel => 'Sätze';

  @override
  String get noSetsFound => 'Keine Sätze für diese Übung gefunden';

  @override
  String get exerciseName => 'Übungsname';

  @override
  String get description => 'Beschreibung';

  @override
  String get duration => 'Dauer';

  @override
  String get difficulty => 'Schwierigkeit';

  @override
  String get repsLabel => 'Wiederholungen';

  @override
  String get weightLabel => 'Gewicht';

  @override
  String get unit => 'Einheit';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get addButton => 'Hinzufügen';

  @override
  String get saveButton => 'Speichern';

  @override
  String get exercises => 'Übungen';

  @override
  String get noWorkoutsFound => 'Kein Workout gefunden.';

  @override
  String get createFirstWorkoutHint =>
      'Erstelle einen Plan einmal und plane ihn so oft ein, wie du möchtest.';

  @override
  String get setWeightGoal => 'Gewichtsziel setzen';

  @override
  String get calculateBMI => 'BMI berechnen';

  @override
  String get currentWeight => 'Aktuelles Gewicht';

  @override
  String get weightProgress => 'Gewichtsfortschritt';

  @override
  String get nutrition => 'Ernährung';

  @override
  String get exerciseProgress => 'Übungsfortschritt';

  @override
  String get weightGoals => 'Gewichtsziele';

  @override
  String get startingWeight => 'Startgewicht';

  @override
  String get goalWeight => 'Zielgewicht';

  @override
  String get enterStartingWeightHint => 'z.B. 90';

  @override
  String get enterGoalWeightHint => 'z.B. 75';

  @override
  String get pleaseEnterValidWeights => 'Bitte gültige Gewichte eingeben';

  @override
  String get weightGoalsUpdated => 'Gewichtsziele aktualisiert';

  @override
  String get saveWeightGoals => 'Gewichtsziele speichern';

  @override
  String get weightGoalsSaved => 'Gewichtsziele gespeichert';

  @override
  String get estimatedCompletion => 'Voraussichtliche Fertigstellung';

  @override
  String get movingAwayFromGoal => 'Entfernung vom Ziel';

  @override
  String get weightStarting => 'Start';

  @override
  String get weightCurrent => 'Aktuell';

  @override
  String get weightToGo => 'Noch';

  @override
  String get weightComplete => 'Erreicht';

  @override
  String get weightGained => 'Zugenommen';

  @override
  String get weightGoalLabel => 'Ziel';

  @override
  String get completionLessThanWeek => 'Weniger als eine Woche!';

  @override
  String completionWeeks(int n) {
    return 'Noch ca. $n Woche(n)';
  }

  @override
  String completionMonths(int n) {
    return 'Noch ca. $n Monat(e)';
  }

  @override
  String completionYears(int n) {
    return 'Noch ca. $n Jahr(e)';
  }

  @override
  String errorLoadingProgress(Object error) {
    return 'Fehler beim Laden des Fortschritts: $error';
  }

  @override
  String get addBreakfast => 'Frühstück hinzufügen';

  @override
  String get addLunch => 'Mittagessen hinzufügen';

  @override
  String get addDinner => 'Abendessen hinzufügen';

  @override
  String get addSnack => 'Snack hinzufügen';

  @override
  String get addWeight => 'Gewicht hinzufügen';

  @override
  String hideFromRecents(String name) {
    return '$name aus den letzten entfernen';
  }

  @override
  String quickAddFood(String name) {
    return '$name schnell hinzufügen';
  }

  @override
  String get createTemplateAction => 'Vorlage erstellen';

  @override
  String get allTime => 'Gesamt';

  @override
  String get dailyCalories => 'Tageskalorien';

  @override
  String get todaysWorkout => 'Heutiges Training';

  @override
  String errorLoadingWorkout(Object error) {
    return 'Fehler beim Laden des Trainings: $error';
  }

  @override
  String get calorieTrend => 'Kalorientrend';

  @override
  String get avgCalories => 'Ø Kalorien';

  @override
  String get calPerDay => 'kcal/Tag';

  @override
  String get noNutritionDataYet => 'Noch keine Ernährungsdaten';

  @override
  String get sevenDays => '7 Tage';

  @override
  String get thirtyDays => '30 Tage';

  @override
  String get ninetyDays => '90 Tage';

  @override
  String get timeRange => 'Zeitraum';

  @override
  String get weeklyAverages => 'Wochendurchschnitt';

  @override
  String get daysOnTarget => 'Tage im Ziel';

  @override
  String get currentStreak => 'Aktuelle Serie';

  @override
  String get longestStreak => 'Längste Serie';

  @override
  String get logMealsProgress => 'Mahlzeiten protokollieren';

  @override
  String get completeWorkoutsProgress => 'Trainings abschließen';

  @override
  String get summaryStatistics => 'Zusammenfassung';

  @override
  String get myFoods => 'Meine Lebensmittel';

  @override
  String get onlineResults => 'Online-Ergebnisse';

  @override
  String get editPortion => 'Portion bearbeiten';

  @override
  String get portionGrams => 'Portion (g)';

  @override
  String get portionLabel => 'Portion';

  @override
  String get updatePortion => 'Aktualisieren';

  @override
  String get updateButton => 'Aktualisieren';

  @override
  String get today => 'Heute';

  @override
  String get couldNotReachFoodDatabase =>
      'Lebensmitteldatenbank nicht erreichbar';

  @override
  String noResultsFor(String query) {
    return 'Keine Ergebnisse für \"$query\"';
  }

  @override
  String get barcodeNotSupportedOnWeb => 'Barcode-Scan im Web nicht verfügbar';

  @override
  String get scan => 'Scannen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get addToMealTemplate => 'Zur Mahlzeitvorlage hinzufügen';

  @override
  String get mealTemplates => 'Mahlzeitvorlagen';

  @override
  String get createTemplate => 'Vorlage erstellen';

  @override
  String get createMealTemplate => 'Mahlzeitvorlage erstellen';

  @override
  String get deleteTemplate => 'Vorlage löschen';

  @override
  String get deleteTemplateQuestion => 'Diese Vorlage löschen?';

  @override
  String get noTemplatesFound => 'Keine Vorlagen gefunden';

  @override
  String get createTemplateHint =>
      'Speichere eine Mahlzeit, die du oft isst, und füge sie mit einem Tipp hinzu.';

  @override
  String get saveTemplate => 'Vorlage speichern';

  @override
  String get templateName => 'Vorlagenname';

  @override
  String get pleaseAddAtLeastOneFood =>
      'Bitte mindestens ein Lebensmittel hinzufügen';

  @override
  String get templateCreatedSuccessfully => 'Vorlage erfolgreich erstellt';

  @override
  String addedToTemplate(String name) {
    return '$name zur Vorlage hinzugefügt';
  }

  @override
  String templateApplied(String name, String category) {
    return '\"$name\" auf $category angewendet';
  }

  @override
  String errorApplyingTemplate(Object error) {
    return 'Fehler beim Anwenden der Vorlage: $error';
  }

  @override
  String errorCreatingTemplate(Object error) {
    return 'Fehler beim Erstellen der Vorlage: $error';
  }

  @override
  String errorScanningBarcode(Object error) {
    return 'Fehler beim Scannen: $error';
  }

  @override
  String get apply => 'Anwenden';

  @override
  String get applyTemplate => 'Vorlage anwenden';

  @override
  String get applyTemplateQuestion => 'Diese Vorlage anwenden?';

  @override
  String get addToTemplate => 'Zur Vorlage hinzufügen';

  @override
  String get addWeightRecord => 'Gewichtseintrag hinzufügen';

  @override
  String get addWeightRecordTitle => 'Gewicht hinzufügen';

  @override
  String get editWeightRecord => 'Gewichtseintrag bearbeiten';

  @override
  String get deleteWeightRecord => 'Gewichtseintrag löschen';

  @override
  String get deleteWeightRecordConfirm => 'Diesen Gewichtseintrag löschen?';

  @override
  String get noWeightRecordsYet => 'Noch keine Gewichtseinträge';

  @override
  String get invalidWeight => 'Ungültiges Gewicht';

  @override
  String get weightCalorieCorrelation => 'Gewicht & Kalorien Korrelation';

  @override
  String get maxWeight => 'Maximalgewicht';

  @override
  String get workoutProgress => 'Trainingsfortschritt';

  @override
  String get workoutComplete => 'Training abgeschlossen!';

  @override
  String get workoutNotes => 'Trainingsnotizen';

  @override
  String get coachNote => 'Notiz vom Trainer';

  @override
  String get workoutDayHint => 'z.B. Montag';

  @override
  String get workoutSummaryLabel => 'Trainingsübersicht';

  @override
  String get workoutHasNoExercises => 'Dieses Training hat keine Übungen';

  @override
  String get workoutFrequency => 'Trainingshäufigkeit';

  @override
  String get workoutDeleted => 'Training gelöscht';

  @override
  String get workoutDetailsUpdated => 'Trainingsdetails aktualisiert';

  @override
  String get workoutPlanSetActive => 'Plan als aktiv gesetzt';

  @override
  String get workoutPlanNameHint => 'z.B. Mein 5-Tage-Split';

  @override
  String get workoutAddedToPlan => 'Training zum Plan hinzugefügt';

  @override
  String workoutRemovedFromPlan(String name) {
    return '\"$name\" aus dem Plan entfernt';
  }

  @override
  String workoutRenamedTo(String name) {
    return 'Training umbenannt in \"$name\"';
  }

  @override
  String workoutPostponedTo(String date) {
    return 'Training verschoben auf $date';
  }

  @override
  String deleteWorkoutConfirmation(String name) {
    return '\"$name\" löschen?';
  }

  @override
  String get deleteWorkout => 'Training löschen';

  @override
  String get editWorkoutName => 'Trainingsname bearbeiten';

  @override
  String get editWorkoutsTitle => 'Trainings bearbeiten';

  @override
  String get editWorkoutDetailsTooltip => 'Trainingsdetails bearbeiten';

  @override
  String get manageWorkouts => 'Trainings verwalten';

  @override
  String get createFirstWorkout => 'Erstes Training erstellen';

  @override
  String get noWorkoutsAddedYet => 'Noch keine Trainings hinzugefügt';

  @override
  String get noWorkoutsAvailableToAdd => 'Keine Trainings verfügbar';

  @override
  String get noWorkoutsInPlanYet => 'Noch keine Trainings im Plan';

  @override
  String get noWorkoutPlansFound => 'Keine Trainingspläne gefunden';

  @override
  String get noWorkoutDataYet => 'Noch keine Trainingsdaten';

  @override
  String get addWorkoutToPlanTitle => 'Training zum Plan hinzufügen';

  @override
  String get addWorkoutsToBuildCycle =>
      'Trainings hinzufügen um den Zyklus aufzubauen';

  @override
  String get removeWorkoutFromPlan => 'Aus Plan entfernen';

  @override
  String get removeWorkoutFromPlanTooltip => 'Training aus Plan entfernen';

  @override
  String removeWorkoutFromPlanConfirm(String name) {
    return '\"$name\" aus dem Plan entfernen?';
  }

  @override
  String failedToRemoveWorkoutFromPlan(Object error) {
    return 'Fehler beim Entfernen aus Plan: $error';
  }

  @override
  String get openPlanEditor => 'Plan-Editor öffnen';

  @override
  String get deletePlanTooltip => 'Plan löschen';

  @override
  String get setActive => 'Aktivieren';

  @override
  String get activatePlan => 'Plan aktivieren';

  @override
  String get active => 'Aktiv';

  @override
  String get activePlanBadge => 'Aktiv';

  @override
  String get noWorkoutDataYetLabel => 'Noch keine Daten';

  @override
  String get nameYourWorkoutPlan => 'Trainingsplan benennen';

  @override
  String get chooseMemorableName => 'Wähle einen einprägsamen Namen';

  @override
  String get workoutPlanNameHintAlt => 'z.B. Sommer-Definition';

  @override
  String get buildYourCycle => 'Deinen Zyklus aufbauen';

  @override
  String get stepStart => 'Start';

  @override
  String get stepCycle => 'Zyklus';

  @override
  String get whenToBeginProgram => 'Programmbeginn';

  @override
  String get chooseStartDate => 'Startdatum wählen';

  @override
  String get startDateLabel => 'Startdatum';

  @override
  String get scheduledWorkoutLabel => 'Geplantes Training';

  @override
  String get scheduledForNextDays => 'Geplant für die nächsten Tage';

  @override
  String get upcoming => 'Kommend';

  @override
  String get skipped => 'Übersprungen';

  @override
  String get jumpTo => 'Springen zu';

  @override
  String get postponeWorkout => 'Training verschieben';

  @override
  String get move => 'Verschieben';

  @override
  String get skipWorkout => 'Training überspringen';

  @override
  String get viewLabel => 'Ansicht';

  @override
  String dayCycleLength(int n) {
    return '$n-Tage-Zyklus';
  }

  @override
  String get exerciseFeelingHint => 'Wie war es?';

  @override
  String get exerciseNotes => 'Übungsnotizen';

  @override
  String get exerciseRemovedFromWorkout => 'Übung entfernt';

  @override
  String get exercisesSummary => 'Übungen';

  @override
  String get noExercisesCount => 'Keine Übungen';

  @override
  String get noPreviousDataForSet => 'Keine Vordaten für diesen Satz';

  @override
  String get prevExercise => 'Vorherige Übung';

  @override
  String get nextExercise => 'Nächste Übung';

  @override
  String get nextSet => 'Nächster Satz';

  @override
  String get currentSetLabel => 'Aktueller Satz';

  @override
  String get restTimer => 'Pausentimer';

  @override
  String get restTimerSetting => 'Pausentimer';

  @override
  String get restTimerSettingSubtitle => 'Automatisch nach einem Satz starten';

  @override
  String get setTypeLabel => 'Satzart';

  @override
  String get setTypeNormal => 'Normal';

  @override
  String get setTypeWarmup => 'Aufwärmsatz';

  @override
  String get setTypeDropset => 'Dropset';

  @override
  String get setTypeFailure => 'Bis Muskelversagen';

  @override
  String get sideLabel => 'Seite';

  @override
  String get sideBoth => 'Beidseitig';

  @override
  String get sideLeft => 'Links';

  @override
  String get sideRight => 'Rechts';

  @override
  String get rpeTrackingSetting => 'RPE erfassen';

  @override
  String get rpeTrackingSettingSubtitle =>
      'Gefühlte Anstrengung (RPE, 6–10) pro Satz erfassen';

  @override
  String get rpeLabel => 'RPE';

  @override
  String get lastTime => 'Letztes Mal';

  @override
  String get actual => 'Tatsächlich';

  @override
  String get tapButtonToAddExercises => '+ drücken um Übungen hinzuzufügen';

  @override
  String get addExercisesToTemplate => 'Übungen zur Vorlage hinzufügen';

  @override
  String get templateWorkoutLabel => 'Vorlagentraining';

  @override
  String get removeExerciseTitle => 'Übung entfernen';

  @override
  String get removeExerciseTooltip => 'Übung entfernen';

  @override
  String get setRemovedFromExercise => 'Satz entfernt';

  @override
  String get setAddedToExercise => 'Satz hinzugefügt';

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get editDetails => 'Details bearbeiten';

  @override
  String get editName => 'Name bearbeiten';

  @override
  String get remove => 'Entfernen';

  @override
  String get goBack => 'Zurück';

  @override
  String get close => 'Schließen';

  @override
  String get done => 'Fertig';

  @override
  String get loading => 'Lädt...';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get category => 'Kategorie';

  @override
  String get days => 'Tage';

  @override
  String get noteOptional => 'Notiz (optional)';

  @override
  String get descriptionOptional => 'Beschreibung (optional)';

  @override
  String get descriptionAndDuration => 'Beschreibung & Dauer';

  @override
  String get overallWorkoutHint => 'Gesamteindruck des Trainings?';

  @override
  String get completedWorkout => 'Training abgeschlossen!';

  @override
  String get startWorkout => 'Training starten';

  @override
  String get bmiComingSoon => 'BMI demnächst verfügbar';

  @override
  String get importButton => 'Importieren';

  @override
  String get importOptions => 'Importoptionen';

  @override
  String get importFitNotes => 'FitNotes importieren';

  @override
  String get importFitNotesHint => 'Aus FitNotes CSV-Export importieren';

  @override
  String get verifiedFoodBadge => 'Verifiziert ✓';

  @override
  String get adaptiveTdeeTitle => 'Adaptives Kalorienziel';

  @override
  String get adaptiveTdeeEstimate => 'Geschätzter Tagesverbrauch';

  @override
  String get adaptiveTdeeRecommended => 'Empfohlenes Tagesziel';

  @override
  String adaptiveTdeeBasis(int days) {
    return 'Basierend auf $days Tagen Gewichts- und Ernährungsdaten';
  }

  @override
  String get adaptiveTdeeInsufficient =>
      'Erfasse mindestens 2 Wochen lang Gewicht und Ernährung, um ein adaptives Kalorienziel zu erhalten.';

  @override
  String get adaptiveTdeeUncertainty =>
      'Die Genauigkeit hängt von der Konsistenz des Trackings ab — unvollständiges Logging erhöht die Schätzung.';

  @override
  String get adaptiveTdeeApply => 'Als Tagesziel übernehmen';

  @override
  String adaptiveTdeeApplied(int kcal) {
    return 'Tägliches Kalorienziel auf $kcal kcal aktualisiert';
  }

  @override
  String get exportSectionLabel => 'Datenexport';

  @override
  String get exportWorkoutsCsv => 'Trainings exportieren (CSV)';

  @override
  String get exportWeightCsv => 'Gewichtsverlauf exportieren (CSV)';

  @override
  String get exportNutritionCsv => 'Ernährung exportieren (CSV)';

  @override
  String get exportFullJson => 'Alle Daten exportieren (JSON)';

  @override
  String get exportFullJsonHint =>
      'Vollständige Sicherung deiner lokalen Daten';

  @override
  String get exportSaved => 'Export gespeichert';

  @override
  String get exportFailed => 'Export fehlgeschlagen';

  @override
  String get importingWorkoutHistory => 'Trainingshistorie wird importiert...';

  @override
  String get importComplete => 'Import abgeschlossen';

  @override
  String get readyToImport => 'Bereit zum Importieren';

  @override
  String get noValidDataInFile => 'Keine gültigen Daten in der Datei gefunden';

  @override
  String get selectCsvFile => 'CSV-Datei auswählen';

  @override
  String get csvSelectFileButton => 'Datei auswählen';

  @override
  String get csvImportExercisesButton => 'Übungen importieren';

  @override
  String get csvFormatTitle => 'CSV-Format';

  @override
  String get csvFormatDescription => 'Übungen aus CSV-Datei importieren';

  @override
  String get csvCreateWorkoutHint => 'Training aus CSV erstellen';

  @override
  String get csvPleaseSelectFile => 'Bitte Datei auswählen';

  @override
  String get csvImporting => 'Importiert...';

  @override
  String get totalWorkouts => 'Gesamte Trainings';

  @override
  String get avgSets => 'Ø Sätze';

  @override
  String get avgPerWeek => 'Ø / Woche';

  @override
  String get uniqueExercisesLabel => 'Einzigartige Übungen';

  @override
  String get unknownExercise => 'Unbekannte Übung';

  @override
  String exerciseXofY(int x, int y) {
    return 'Übung $x von $y';
  }

  @override
  String exerciseCount(int n) {
    return '$n Übung(en)';
  }

  @override
  String setCount(int n) {
    return '$n Satz/Sätze';
  }

  @override
  String exercisesAndSets(int exercises, int sets) {
    return '$exercises Übung(en), $sets Satz/Sätze';
  }

  @override
  String exerciseAddedToWorkout(String name) {
    return '$name zum Training hinzugefügt';
  }

  @override
  String failedToAddExercise(Object error) {
    return 'Fehler beim Hinzufügen der Übung: $error';
  }

  @override
  String failedToAddSet(Object error) {
    return 'Fehler beim Hinzufügen des Satzes: $error';
  }

  @override
  String failedToRemoveExercise(Object error) {
    return 'Fehler beim Entfernen der Übung: $error';
  }

  @override
  String errorCompletingWorkout(Object error) {
    return 'Fehler beim Abschließen des Trainings: $error';
  }

  @override
  String errorUpdatingDetails(Object error) {
    return 'Fehler beim Aktualisieren der Details: $error';
  }

  @override
  String errorUpdatingName(Object error) {
    return 'Fehler beim Aktualisieren des Namens: $error';
  }

  @override
  String createdExercises(int n) {
    return '$n Übung(en) erstellt';
  }

  @override
  String importedSessions(int n) {
    return '$n Einheit(en) importiert';
  }

  @override
  String importedSets(int n) {
    return '$n Satz/Sätze importiert';
  }

  @override
  String importedWorkoutsCreated(int n) {
    return '$n Training(s) erstellt';
  }

  @override
  String newExercisesWillBeCreated(int n) {
    return '$n neue Übung(en) werden erstellt';
  }

  @override
  String sessionsCount(int n) {
    return '$n Einheit(en)';
  }

  @override
  String setsCount(int n) {
    return '$n Satz/Sätze';
  }

  @override
  String importFailed(Object error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String csvExercisesAdded(int n) {
    return '$n Übung(en) hinzugefügt';
  }

  @override
  String csvExercisesSkipped(int n) {
    return '$n Übung(en) übersprungen';
  }

  @override
  String get nameLabel => 'Name';

  @override
  String get goodMorning => 'Guten Morgen!';

  @override
  String get goodAfternoon => 'Guten Tag!';

  @override
  String get goodEvening => 'Guten Abend!';

  @override
  String get onboardingWelcomeSubtitle => 'Dein persönlicher Fitness-Begleiter';

  @override
  String get onboardingCreateAccount => 'Konto erstellen';

  @override
  String get profileSetupSkip => 'Später einrichten';

  @override
  String get onboardingAlreadyHaveAccount =>
      'Du hast schon ein Konto? Anmelden';

  @override
  String get onboardingWelcomeBody =>
      'Verfolge Ernährung, Training und Gewicht — alles an einem Ort.';

  @override
  String get onboardingFeatureWeight => 'Gewichtsverfolgung';

  @override
  String get onboardingProfileTitle => 'Über dich';

  @override
  String get onboardingProfileSubtitle =>
      'Damit personalisieren wir deine Erfahrung';

  @override
  String get onboardingGoalsTitle => 'Deine Ziele';

  @override
  String get onboardingGoalsSubtitle => 'Sag uns, worauf du hinarbeitest';

  @override
  String get onboardingSummaryTitle => 'Alles bereit!';

  @override
  String get onboardingSummaryCaloriesLabel =>
      'Geschätztes tägliches Kalorienziel';

  @override
  String get onboardingGetStarted => 'Loslegen';

  @override
  String get undoSkip => 'Überspringen rückgängig';

  @override
  String get replaceExercise => 'Übung ersetzen';

  @override
  String get resumeWorkoutTitle => 'Training fortsetzen?';

  @override
  String resumeWorkoutBody(String name) {
    return '\"$name\" wurde unterbrochen. Dort weitermachen, wo du aufgehört hast?';
  }

  @override
  String get resumeWorkout => 'Fortsetzen';

  @override
  String get discardWorkout => 'Verwerfen';

  @override
  String get removeSupersetLink => 'Superset-Verbindung entfernen';

  @override
  String get superset => 'Superset';

  @override
  String get supersetPickHint => 'Wählen Sie Übungen für das Superset aus';

  @override
  String get targetReps => 'Ziel-Wiederholungen';

  @override
  String get targetRepsHint => 'z.B. 8-12';

  @override
  String get targetRepsHintLong => 'z.B. 8 - 12';

  @override
  String get createWorkoutPlan => 'Trainingsplan erstellen';

  @override
  String get planName => 'Planname';

  @override
  String get planNameHint => 'z.B. Anfänger-Kraftprogramm';

  @override
  String get create => 'Erstellen';

  @override
  String get foods => 'Lebensmittel';

  @override
  String get addFromScheduledWorkouts => 'Aus geplanten Trainings hinzufügen';

  @override
  String get importCsvWorkouts => 'CSV-Trainings importieren';

  @override
  String get startTimer => 'Starten';

  @override
  String get pauseTimer => 'Pausieren';

  @override
  String get resetTimer => 'Zurücksetzen';

  @override
  String get stopTimer => 'Stoppen';

  @override
  String get restTimeComplete => 'Pause beendet! 💪';

  @override
  String get selectFood => 'Lebensmittel auswählen';

  @override
  String doneCount(int count) {
    return 'Fertig ($count)';
  }

  @override
  String get searchFoods => 'Lebensmittel suchen';

  @override
  String get noLocalFoodsFound => 'Keine lokalen Lebensmittel gefunden';

  @override
  String get enterSearchTermsOnline =>
      'Suchbegriffe eingeben, um Lebensmittel online zu finden';

  @override
  String get noResultsFoundSearch =>
      'Keine Ergebnisse für diese Suche gefunden';

  @override
  String get tryUsingMoreGeneralTerms =>
      'Allgemeinere Begriffe verwenden oder Schreibweise prüfen';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get noFoodsAdded => 'Noch keine Lebensmittel hinzugefügt';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get pleaseEnterName => 'Bitte einen Namen eingeben';

  @override
  String get barcodeNotSupportedMobile =>
      'Barcode-Scannen wird nur auf Mobilgeräten unterstützt.';

  @override
  String get barcodeNotSupportedWeb =>
      'Barcode-Scannen wird im Web nicht unterstützt';

  @override
  String get selectWorkoutDates => 'Trainingsdaten auswählen';

  @override
  String get useSelectedDates => 'Ausgewählte Daten verwenden';

  @override
  String get searchExercisesHint => 'Übungen suchen...';

  @override
  String get invalidAgeHeight =>
      'Bitte gültiges Alter und gültige Körpergröße eingeben';

  @override
  String get searchOnlineTab => 'Online suchen';

  @override
  String get login => 'Anmelden';

  @override
  String get register => 'Registrieren';

  @override
  String get username => 'Benutzername';

  @override
  String get password => 'Passwort';

  @override
  String get confirmPassword => 'Passwort bestätigen';

  @override
  String get email => 'E-Mail';

  @override
  String get firstName => 'Vorname';

  @override
  String get lastName => 'Nachname';

  @override
  String get dateOfBirth => 'Geburtsdatum';

  @override
  String get selectDateOfBirth => 'Geburtsdatum auswählen';

  @override
  String get loginToYourAccount => 'Willkommen zurück';

  @override
  String get createYourAccount => 'Konto erstellen';

  @override
  String get noAccountQuestion => 'Noch kein Konto?';

  @override
  String get alreadyHaveAccount => 'Bereits ein Konto?';

  @override
  String get passwordsDoNotMatch => 'Passwörter stimmen nicht überein';

  @override
  String get pleaseSelectDateOfBirth => 'Bitte Geburtsdatum auswählen';

  @override
  String get fieldRequired => 'Dieses Feld ist erforderlich';

  @override
  String get invalidEmailFormat => 'Bitte eine gültige E-Mail-Adresse eingeben';

  @override
  String get passwordTooShort =>
      'Das Passwort muss mindestens 8 Zeichen lang sein';

  @override
  String get minimumAgeRequired => 'Du musst mindestens 13 Jahre alt sein';

  @override
  String get freeChoiceMode => 'Freie Auswahl';

  @override
  String get freeChoiceModeSubtitle =>
      'Trainingseinheiten täglich manuell auswählen';

  @override
  String get cycleModeSubtitle =>
      'Trainingseinheiten folgen einem festen Zyklus';

  @override
  String get switchToFreeChoiceTitle => 'Zur freien Auswahl wechseln?';

  @override
  String get switchToFreeChoiceBody =>
      'Alle zukünftigen geplanten Trainingseinheiten für diesen Plan werden entfernt. Du kannst täglich selbst wählen.';

  @override
  String get switchToCyclePlanTitle => 'Zum Zyklus-Plan wechseln?';

  @override
  String get switchToCyclePlanBody =>
      'Der Plan wechselt zurück in den Zyklus-Modus. Keine Trainingseinheiten werden automatisch eingeplant.';

  @override
  String get confirm => 'Bestätigen';

  @override
  String addWorkoutForDate(String date) {
    return 'Training für $date hinzufügen';
  }

  @override
  String pickWorkoutForDate(String date) {
    return 'Training für $date auswählen';
  }

  @override
  String get freeChoiceAddHint =>
      'Trainingsvorlagen hinzufügen, aus denen täglich gewählt werden kann';

  @override
  String get cyclePattern => 'Zyklus-Muster';

  @override
  String get freeChoiceLabel => 'Freie Auswahl';

  @override
  String get accountSettings => 'Kontoeinstellungen';

  @override
  String get profile => 'Profil';

  @override
  String get security => 'Sicherheit';

  @override
  String get changePassword => 'Passwort ändern';

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signOutConfirm =>
      'Bist du sicher, dass du dich abmelden möchtest?';

  @override
  String get signOutUnsyncedTitle => 'Nicht synchronisierte Änderungen';

  @override
  String signOutUnsyncedBody(int count) {
    return '$count Änderungen haben den Server noch nicht erreicht. Beim Abmelden werden die lokalen Daten dieses Geräts gelöscht, sie gingen also verloren — einschließlich gelöschter Übungen, die dadurch zurückkämen.';
  }

  @override
  String get signOutAnyway => 'Trotzdem abmelden';

  @override
  String get createExercise => 'Übung erstellen';

  @override
  String get editExercise => 'Übung bearbeiten';

  @override
  String get createCustomExercise => 'Eigene Übung erstellen';

  @override
  String get exerciseType => 'Übungstyp';

  @override
  String get muscleGroupsLabel => 'Muskelgruppen';

  @override
  String get exerciseSaved => 'Übung gespeichert';

  @override
  String get exerciseUpdated => 'Übung aktualisiert';

  @override
  String get exerciseCreated => 'Übung erstellt';

  @override
  String get exerciseDeleted => 'Übung gelöscht';

  @override
  String get deleteExercise => 'Übung löschen';

  @override
  String deleteExerciseConfirmation(String name) {
    return '\"$name\" löschen?';
  }

  @override
  String get selectAtLeastOneMuscleGroup =>
      'Bitte mindestens eine Muskelgruppe auswählen';

  @override
  String get exerciseTypeStrength => 'Kraft';

  @override
  String get exerciseTypeCardio => 'Cardio';

  @override
  String get exerciseTypeFlexibility => 'Flexibilität';

  @override
  String get exerciseTypeCalisthenics => 'Calisthenics';

  @override
  String get customBadge => 'Eigene';

  @override
  String get saveChangesButton => 'Änderungen speichern';

  @override
  String errorSavingExercise(Object error) {
    return 'Fehler beim Speichern der Übung: $error';
  }

  @override
  String errorDeletingExercise(Object error) {
    return 'Fehler beim Löschen der Übung: $error';
  }

  @override
  String get newExercise => 'Neue Übung';

  @override
  String noExercisesFoundForQuery(String query) {
    return 'Keine Übungen gefunden für \"$query\"';
  }

  @override
  String get all => 'Alle';

  @override
  String get muscleGroupChest => 'Brust';

  @override
  String get muscleGroupBack => 'Rücken';

  @override
  String get muscleGroupShoulders => 'Schultern';

  @override
  String get muscleGroupBiceps => 'Bizeps';

  @override
  String get muscleGroupTriceps => 'Trizeps';

  @override
  String get muscleGroupLegs => 'Beine';

  @override
  String get muscleGroupAbs => 'Bauch';

  @override
  String get muscleGroupFullBody => 'Ganzkörper';

  @override
  String get exercisesSubtitle => 'Übungen durchsuchen, erstellen & bearbeiten';

  @override
  String get darkMode => 'Dunkelmodus';

  @override
  String get lightMode => 'Hellmodus';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemstandard';

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
  String get reset => 'Zurücksetzen';

  @override
  String get selectTrainingDays => 'Trainingstage auswählen';

  @override
  String daysSelected(int n) {
    return '$n Tage ausgewählt';
  }

  @override
  String get manageExercises => 'Übungen verwalten';

  @override
  String get noResultsFoundForSearch =>
      'Keine Ergebnisse für diese Suche gefunden';

  @override
  String get tryMoreGeneralTerms =>
      'Versuche allgemeinere Begriffe oder überprüfe die Schreibweise';

  @override
  String doneWithCount(int count) {
    return 'Fertig ($count)';
  }

  @override
  String addingFoodToYours(String name) {
    return '$name wird hinzugefügt...';
  }

  @override
  String foodAddedToYours(String name) {
    return '$name wurde hinzugefügt';
  }

  @override
  String errorAddingFood(Object error) {
    return 'Fehler beim Hinzufügen: $error';
  }

  @override
  String brandLabel(String brand) {
    return 'Marke: $brand';
  }

  @override
  String get editMealTemplate => 'Mahlzeitvorlage bearbeiten';

  @override
  String get templateUpdatedSuccessfully => 'Vorlage erfolgreich aktualisiert';

  @override
  String get barcodeScanningMobileOnly =>
      'Barcode-Scanning wird nur auf Mobilgeräten unterstützt.';

  @override
  String get barcodeScanningWebNotSupported =>
      'Barcode-Scanning wird im Web nicht unterstützt';

  @override
  String get setUpdated => 'Satz aktualisiert';

  @override
  String failedToRemoveSet(Object error) {
    return 'Satz konnte nicht entfernt werden: $error';
  }

  @override
  String failedToUpdateSet(Object error) {
    return 'Satz konnte nicht aktualisiert werden: $error';
  }

  @override
  String workoutPlanCreated(String name) {
    return 'Trainingsplan \"$name\" erstellt';
  }

  @override
  String failedToCreatePlan(Object error) {
    return 'Trainingsplan konnte nicht erstellt werden: $error';
  }

  @override
  String failedToAddWorkout(Object error) {
    return 'Training konnte nicht hinzugefügt werden: $error';
  }

  @override
  String deletedWorkoutPlan(String name) {
    return 'Trainingsplan \"$name\" gelöscht';
  }

  @override
  String failedToDeletePlan(Object error) {
    return 'Plan konnte nicht gelöscht werden: $error';
  }

  @override
  String get cannotAddExerciseToUnsavedWorkout =>
      'Übung kann nicht zu ungespeichertem Training hinzugefügt werden';

  @override
  String removeExerciseConfirmBody(String name) {
    return 'Möchtest du \"$name\" wirklich aus diesem Training entfernen?';
  }

  @override
  String removeSetConfirmBody(int setNumber, String exerciseName) {
    return 'Möchtest du Satz $setNumber von \"$exerciseName\" wirklich entfernen?';
  }

  @override
  String deletePlanConfirmBody(String name) {
    return 'Möchtest du \"$name\" wirklich löschen? Der Plan wird entfernt, aber die Trainings bleiben erhalten.';
  }

  @override
  String get pleaseEnterDuration => 'Bitte Dauer eingeben';

  @override
  String get pleaseEnterValidDuration => 'Bitte eine gültige Dauer eingeben';

  @override
  String get minutesSuffix => 'Minuten';

  @override
  String get selectMuscleGroup => 'Muskelgruppe auswählen';

  @override
  String get selectExercise => 'Übung auswählen';

  @override
  String get extendedNutrientsTitle => 'Detaillierte Nährwerte';

  @override
  String get extendedNutrientsMacrosSection => 'Makro-Details';

  @override
  String get extendedNutrientsVitaminsSection => 'Vitamine';

  @override
  String get extendedNutrientsMineralsSection => 'Mineralstoffe';

  @override
  String get nutrientFiber => 'Ballaststoffe';

  @override
  String get nutrientSugar => 'Zucker';

  @override
  String get nutrientSaturatedFat => 'Gesättigte Fettsäuren';

  @override
  String get nutrientSalt => 'Salz';

  @override
  String get nutrientSodium => 'Natrium';

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
  String get nutrientVitaminB1 => 'Vitamin B1 (Thiamin)';

  @override
  String get nutrientVitaminB2 => 'Vitamin B2 (Riboflavin)';

  @override
  String get nutrientVitaminB3 => 'Vitamin B3 (Niacin)';

  @override
  String get nutrientVitaminB6 => 'Vitamin B6';

  @override
  String get nutrientVitaminB9 => 'Vitamin B9 (Folsäure)';

  @override
  String get nutrientVitaminB12 => 'Vitamin B12';

  @override
  String get nutrientCalcium => 'Calcium';

  @override
  String get nutrientIron => 'Eisen';

  @override
  String get nutrientMagnesium => 'Magnesium';

  @override
  String get nutrientPotassium => 'Kalium';

  @override
  String get nutrientZinc => 'Zink';

  @override
  String get unitMg => 'mg';

  @override
  String get unitUg => 'µg';

  @override
  String get premiumFeatureTitle => 'Premium-Funktion';

  @override
  String get premiumFeatureBody =>
      'Upgrade auf Premium, um detaillierte Nährwertdaten einschließlich Vitamine und Mineralstoffe zu sehen.';

  @override
  String get premiumBadge => 'Premium';

  @override
  String get upgradeToPremium => 'Auf Premium upgraden';

  @override
  String get goPremiumBannerTitle => 'Premium freischalten';

  @override
  String get goPremiumBannerSubtitle =>
      'Unbegrenzte Pläne, vollständiger Verlauf & Analysen';

  @override
  String get goPremiumBannerButton => 'Upgraden';

  @override
  String get paywallUnlockPotential => 'Entfalte dein volles Potenzial';

  @override
  String get paywallNoPlans => 'Keine Tarife verfügbar.';

  @override
  String get paywallRestorePurchases => 'Käufe wiederherstellen';

  @override
  String get paywallError =>
      'Der Kauf-Bildschirm konnte nicht geladen werden. Bitte versuche es erneut.';

  @override
  String get noActivePurchasesFound =>
      'Für dieses Konto wurden keine aktiven Käufe gefunden.';

  @override
  String get paywallFinePrint =>
      'Jederzeit kündbar. Das Abo verlängert sich automatisch bis zur Kündigung.';

  @override
  String paywallFreeTrial(String duration) {
    return '$duration kostenlos testen';
  }

  @override
  String paywallIntroPrice(String price, String duration) {
    return '$price für $duration';
  }

  @override
  String get paywallPeriodDay => 'Tag';

  @override
  String get paywallPeriodDays => 'Tage';

  @override
  String get paywallPeriodWeek => 'Woche';

  @override
  String get paywallPeriodWeeks => 'Wochen';

  @override
  String get paywallPeriodMonth => 'Monat';

  @override
  String get paywallPeriodMonths => 'Monate';

  @override
  String get paywallPeriodYear => 'Jahr';

  @override
  String get paywallPeriodYears => 'Jahre';

  @override
  String get paywallFeatureProgress => 'Gesamter Verlauf & eigene Zeiträume';

  @override
  String get paywallFeaturePlans => 'Unbegrenzte Trainingspläne';

  @override
  String get paywallFeatureTemplates => 'Unbegrenzte Mahlzeiten-Vorlagen';

  @override
  String get paywallFeatureCorrelation =>
      'Gewichts- & Kalorien-Korrelationsdiagramm';

  @override
  String get paywallFeatureGraphs => 'Übungsfortschrittsgraphen';

  @override
  String get paywallFeatureExport => 'Trainingsdaten exportieren (CSV)';

  @override
  String get paywallFeatureNutrition =>
      'Detaillierte Nährwertanalyse — Vitamine & Mineralstoffe';

  @override
  String get paywallFeatureCustomFoods =>
      'Unbegrenzte eigene Lebensmittel (kostenlos: bis zu 10)';

  @override
  String get paywallFeatureLongPlans =>
      'Erweiterte Trainingsplandauer — bis zu 1 Jahr';

  @override
  String get paywallFeatureFreeChoice =>
      'Freie Auswahl — beliebige Workouts an beliebigen Tagen einplanen';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountWarning =>
      'Dies löscht dauerhaft dein Konto und alle deine Daten, einschließlich Trainings, Mahlzeiten und Gewichtsverlauf. Trainer-Beziehungen werden ebenfalls entfernt. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountError =>
      'Konto konnte nicht gelöscht werden. Bitte überprüfe dein Passwort und versuche es erneut.';

  @override
  String get planDurationLabel => 'Plan-Dauer';

  @override
  String nWeeks(int count) {
    return '$count Wochen';
  }

  @override
  String get forgotPasswordTitle => 'Passwort vergessen';

  @override
  String get resetYourPassword => 'Passwort zurücksetzen';

  @override
  String get forgotPasswordDescription =>
      'Gib die E-Mail-Adresse ein, die mit deinem Konto verknüpft ist, und wir schicken dir einen Link zum Zurücksetzen.';

  @override
  String get sendResetLink => 'Link senden';

  @override
  String get checkYourEmail => 'Prüfe deine E-Mails';

  @override
  String resetLinkSentBody(String email) {
    return 'Falls ein Konto mit $email verknüpft ist, erhältst du in Kürze einen Reset-Link.';
  }

  @override
  String get backToLogin => 'Zurück zur Anmeldung';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncNowSubtitle =>
      'Alle ausstehenden lokalen Änderungen auf den Server übertragen';

  @override
  String get syncComplete => 'Synchronisierung abgeschlossen';

  @override
  String syncFailed(Object error) {
    return 'Synchronisierung fehlgeschlagen: $error';
  }

  @override
  String get restoreFromServer => 'Vom Server wiederherstellen';

  @override
  String get restoreFromServerSubtitle =>
      'Serverdaten auf dieses Gerät herunterladen';

  @override
  String get restoreComplete => 'Wiederherstellung abgeschlossen';

  @override
  String restoreFailed(Object error) {
    return 'Wiederherstellung fehlgeschlagen: $error';
  }

  @override
  String get premiumUpgradeMultiplePlans =>
      'Premium — upgrade für unbegrenzte Pläne erforderlich';

  @override
  String get freeTemplateLimitReached =>
      'Kostenloses Limit erreicht — upgrade für mehr als 3 Vorlagen';

  @override
  String itemsCount(int count) {
    return '$count Einträge';
  }

  @override
  String get sortResults => 'Ergebnisse sortieren';

  @override
  String get sortTooltip => 'Sortieren';

  @override
  String get sortRelevance => 'Relevanz';

  @override
  String get sortHighestProtein => 'Höchstes Protein';

  @override
  String get sortLowestCalories => 'Wenigste Kalorien';

  @override
  String get sortLowestCarbs => 'Wenigste Kohlenhydrate';

  @override
  String get sortLowestFat => 'Wenigste Fette';

  @override
  String get sortHighestFibre => 'Höchster Ballaststoffgehalt';

  @override
  String get tooManyRequests =>
      'Zu viele Anfragen – bitte warte einen Moment und versuche es erneut.';

  @override
  String get couldNotFetchProductData =>
      'Produktdaten konnten nicht abgerufen werden. Bitte versuche es erneut.';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get requestedPlanNotFound =>
      'Angeforderter Plan nicht gefunden und keine Pläne vorhanden';

  @override
  String get requestedPlanNotFoundShowingAll =>
      'Angeforderter Plan nicht gefunden – alle Pläne werden angezeigt';

  @override
  String foundTemplateWorkouts(int count) {
    return '$count Vorlagen-Training(s) aus geplanten Trainings können zu diesem Plan hinzugefügt werden.';
  }

  @override
  String get addWorkoutsToPlanHint =>
      'Um Trainings zu diesem Plan hinzuzufügen:\n\n1. Importiere Trainingsvorlagen über den CSV-Import-Button\n2. Verwende den +-Button, um importierte Trainings zu diesem Plan hinzuzufügen\n3. Geplante Trainings sind getrennt von Plan-Vorlagen';

  @override
  String get syncSectionLabel => 'Synchronisierung';

  @override
  String get showMore => 'Mehr anzeigen';

  @override
  String get showLess => 'Weniger anzeigen';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get resetPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get resetPasswordDescription =>
      'Gib dein neues Passwort ein und bestätige es.';

  @override
  String get resetPasswordButton => 'Passwort zurücksetzen';

  @override
  String get passwordResetSuccess =>
      'Passwort erfolgreich geändert. Du kannst dich jetzt einloggen.';

  @override
  String get passwordResetExpired =>
      'Dieser Link ist abgelaufen oder wurde bereits verwendet.';

  @override
  String get templateBatchWeight => 'Gesamtgewicht der Portion (g)';

  @override
  String get templateBatchWeightHint =>
      'z. B. Gesamtgewicht des gekochten Gerichts abwiegen';

  @override
  String templateFullBatch(String weight, String calories) {
    return 'Gesamt: ${weight}g • $calories kcal';
  }

  @override
  String get templatePortionLabel => 'Deine Portion (g)';

  @override
  String get templateLogFull => 'Gesamte Vorlage eintragen';

  @override
  String get templateLogPortion => 'Portion eintragen';

  @override
  String get coachChat => 'Dein Coach';

  @override
  String get coachChatSubtitle => 'Schreib deinem Trainer';

  @override
  String get coachChatNoCoach => 'Noch kein Coach';

  @override
  String get coachChatNoCoachBody =>
      'Sobald dich ein Trainer aufnimmt, kannst du hier schreiben.';

  @override
  String get coachChatEmpty => 'Noch keine Nachrichten';

  @override
  String get coachChatEmptyBody =>
      'Frag deinen Coach alles — er sieht es sofort.';

  @override
  String get coachChatLoadError => 'Unterhaltung konnte nicht geladen werden.';

  @override
  String get chatComposerHint => 'Nachricht';

  @override
  String get chatSendMessage => 'Nachricht senden';

  @override
  String get chatSending => 'Wird gesendet';

  @override
  String get chatFailedRetry =>
      'Senden fehlgeschlagen — zum Wiederholen tippen';

  @override
  String get chatUndecryptable =>
      'Nachricht kann auf diesem Gerät nicht entschlüsselt werden';

  @override
  String get chatNewMessage => 'Neue Nachricht';

  @override
  String get chatReconnecting => 'Verbindung wird wiederhergestellt…';

  @override
  String get chatOffline => 'Offline';

  @override
  String chatUnreadCount(Object count) {
    return '$count ungelesen';
  }

  @override
  String get chatSendFailed =>
      'Nachricht nicht gesendet. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get chatDismiss => 'Schließen';

  @override
  String get chatAttachmentsUnavailable => 'Anhänge sind noch nicht verfügbar';

  @override
  String get chatAttachPhoto => 'Foto';

  @override
  String get chatAttachCamera => 'Kamera';

  @override
  String get chatAttachDocument => 'Dokument';

  @override
  String get chatAttachmentTooLarge => 'Die Datei ist zu groß zum Anhängen';

  @override
  String get chatPhotoLabel => 'Foto';

  @override
  String get chatDocumentLabel => 'Dokument';

  @override
  String get chatUnsupportedAttachment =>
      'Dieser Anhang wird auf diesem Gerät noch nicht unterstützt';

  @override
  String get chatAttachmentUploading => 'wird hochgeladen';

  @override
  String get chatAttachmentUploadFailed =>
      'Hochladen fehlgeschlagen, zum Wiederholen doppelt tippen';

  @override
  String get chatAttachmentDownloading => 'wird heruntergeladen';

  @override
  String get chatAttachmentDownloadFailed =>
      'Herunterladen fehlgeschlagen, zum Wiederholen doppelt tippen';

  @override
  String get chatAttachmentExpired => 'Nicht mehr verfügbar';

  @override
  String get chatAttachmentTapToDownload => 'zum Herunterladen tippen';

  @override
  String get chatAttachmentOpen => 'Öffnen';

  @override
  String get chatUnavailable => 'Nachrichten nicht verfügbar';

  @override
  String get chatUnavailableBody =>
      'Der Chat konnte auf diesem Gerät nicht starten. Starte die App neu und melde dich beim Support, falls es weiter auftritt.';

  @override
  String get trainerConsole => 'Trainer-Konsole';

  @override
  String get trainerConsoleSubtitle => 'Verwalte deine Kunden';

  @override
  String get consoleNavDashboard => 'Dashboard';

  @override
  String get consoleNavMessages => 'Nachrichten';

  @override
  String get consoleNavBuilder => 'Trainingsplaner';

  @override
  String get consoleNavNutrition => 'Ernährung';

  @override
  String get consoleNavSessionReview => 'Trainingsrückblick';

  @override
  String get consoleNavDashboardShort => 'Start';

  @override
  String get consoleNavMessagesShort => 'Chat';

  @override
  String get consoleNavBuilderShort => 'Pläne';

  @override
  String get consoleNavNutritionShort => 'Ernährung';

  @override
  String get consoleNavSessionReviewShort => 'Rückblick';

  @override
  String get consoleMyTraining => 'Mein Training';

  @override
  String get consoleSwitchToMyTraining => 'Zu meinem Training wechseln';

  @override
  String get consoleLoading => 'Wird geladen';

  @override
  String get trainerAccessOnly => 'Nur für Trainer';

  @override
  String get trainerAccessOnlyBody =>
      'Dieser Bereich ist für Trainer, die Kunden betreuen. Ein Trainerkonto wird bei der Registrierung gewählt — ein bestehendes Konto lässt sich nicht umstellen.';

  @override
  String get accountType => 'Kontotyp';

  @override
  String get accountTypeTrainee => 'Für mich';

  @override
  String get accountTypeTrainer => 'Ich betreue Kunden';

  @override
  String get accountTypeLockedNote =>
      'Ein Trainerkonto öffnet die Trainer-Konsole. Das lässt sich später nicht ändern — ein bestehendes Konto kann nicht umgestellt werden.';

  @override
  String get dashboardLoading => 'Dashboard wird geladen';

  @override
  String get rosterLoading => 'Kunden werden geladen';

  @override
  String get kpisLoading => 'Übersicht wird geladen';

  @override
  String get clientsHeading => 'Kunden';

  @override
  String get kpiActiveClients => 'Aktive Kunden';

  @override
  String get kpiAvgAdherence => 'Ø Planerfüllung';

  @override
  String get kpiSessionsThisWeek => 'Einheiten diese Woche';

  @override
  String get rosterEmptyTitle => 'Noch keine Kunden';

  @override
  String get rosterEmptyBody =>
      'Erstelle einen Einladungscode und gib ihn deinem ersten Kunden. Er trägt ihn unter „Trainer beitreten“ ein.';

  @override
  String get rosterGridView => 'Kachelansicht';

  @override
  String get rosterTableView => 'Tabellenansicht';

  @override
  String get rosterColumnClient => 'KUNDE';

  @override
  String get rosterColumnProgram => 'PROGRAMM';

  @override
  String get rosterColumnAdherence => 'PLANERFÜLLUNG';

  @override
  String get rosterColumnLastSession => 'LETZTE EINHEIT';

  @override
  String get noActivePlan => 'Kein aktiver Plan';

  @override
  String get noSessionsYet => 'Noch keine Einheiten';

  @override
  String lastSessionOn(String date) {
    return 'Zuletzt: $date';
  }

  @override
  String get noData => 'Keine Daten';

  @override
  String get invite => 'Einladen';

  @override
  String get inviteAClient => 'Kunden einladen';

  @override
  String get inviteSheetBody =>
      'Gib den Code an deinen Kunden weiter. Er trägt ihn in seiner App unter „Trainer beitreten“ ein.';

  @override
  String get createInviteCode => 'Einladungscode erstellen';

  @override
  String get createNewInviteCode => 'Einen neuen Einladungscode erstellen';

  @override
  String get copyCode => 'Code kopieren';

  @override
  String get inviteCodeCopied => 'Einladungscode kopiert';

  @override
  String inviteCodeSemantics(String code) {
    return 'Einladungscode $code';
  }

  @override
  String get inviteExpiresInSevenDays => 'Läuft in 7 Tagen ab.';

  @override
  String copyInviteCode(String code) {
    return '$code kopieren';
  }

  @override
  String withdrawInviteCode(String code) {
    return '$code zurückziehen';
  }

  @override
  String get outstandingInvites => 'Offene Einladungen';

  @override
  String get outstandingInvitesBody =>
      'Jede davon belegt einen Platz, bis sie eingelöst oder zurückgezogen wird.';

  @override
  String get inviteExpired => 'Abgelaufen';

  @override
  String get inviteExpiresToday => 'Läuft heute ab';

  @override
  String inviteExpiresInDays(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Läuft in $days Tagen ab',
      one: 'Läuft in 1 Tag ab',
    );
    return '$_temp0';
  }

  @override
  String get withdrawInviteTitle => 'Diese Einladung zurückziehen?';

  @override
  String withdrawInviteBody(String code) {
    return '$code funktioniert dann nicht mehr und der Platz wird frei. Wer den Code schon hat, braucht einen neuen.';
  }

  @override
  String get keep => 'Behalten';

  @override
  String get withdraw => 'Zurückziehen';

  @override
  String get inviteBlockedLapsed =>
      'Erneuere deine Lizenz, um Kunden einzuladen.';

  @override
  String inviteBlockedFull(int seats) {
    return 'Alle $seats Plätze sind belegt. Zieh eine Einladung zurück oder wechsle den Tarif.';
  }

  @override
  String seatMeterUsage(int used, int limit) {
    return '$used von $limit Kunden';
  }

  @override
  String get seatMeterOverLimit =>
      'Über deinem Tarif. Bestehende Kunden bleiben aktiv; neue kannst du nicht aufnehmen.';

  @override
  String get seatMeterFull =>
      'Tarif voll. Mach einen Platz frei oder wechsle den Tarif, um mehr aufzunehmen.';

  @override
  String seatMeterRemaining(int seats) {
    return 'Noch $seats Plätze frei';
  }

  @override
  String seatMeterSemantics(String usage, String caption) {
    return '$usage. $caption';
  }

  @override
  String seatChipSemantics(int used, int limit, String tier) {
    return '$used von $limit Kundenplätzen belegt. Tarif $tier. Tarifeinstellungen öffnen.';
  }

  @override
  String seatChipTooltip(String tier, int used, int limit) {
    return '$tier — $used/$limit Kunden';
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
  String get licenceStatusActive => 'Aktiv';

  @override
  String get licenceStatusTrialing => 'Testphase';

  @override
  String get licenceStatusPastDue => 'Zahlung fehlgeschlagen';

  @override
  String get licenceStatusCanceled => 'Gekündigt';

  @override
  String get licenceLoading => 'Dein Tarif wird geladen…';

  @override
  String get licenceLoadingLabel => 'Dein Tarif wird geladen';

  @override
  String get yourPlan => 'Dein Tarif';

  @override
  String get yourPlanSubtitle => 'Plätze, Abrechnung und Einladungen';

  @override
  String get changePlan => 'Tarif wechseln';

  @override
  String planLadderFootnote(int seats) {
    return 'Bezahlte Tarife enthalten ForgeForm Pro für dich und alle Kunden auf deiner Liste. Der kostenlose Tarif deckt $seats Kunden ohne Pro ab.';
  }

  @override
  String tierPlanTitle(String tier) {
    return 'Tarif $tier';
  }

  @override
  String get proIncluded => 'Pro für dich und alle Kunden enthalten';

  @override
  String get proNotIncluded =>
      'Pro nicht enthalten — wechsle den Tarif, um deine Kunden abzudecken';

  @override
  String get manageBilling => 'Abrechnung verwalten';

  @override
  String statusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String tierSeatsAndPro(int seats) {
    return 'Bis zu $seats Kunden, Pro enthalten';
  }

  @override
  String get planCurrent => 'Aktuell';

  @override
  String get licenceLapsedBanner =>
      'Deine Lizenz ist abgelaufen. Deine Kunden bleiben, aber du kannst ihre Pläne nicht ändern und sie haben Pro verloren.';

  @override
  String get licenceRenew => 'Erneuern';

  @override
  String licenceGraceBanner(String date) {
    return 'Zahlung fehlgeschlagen. Bis $date funktioniert alles weiter — danach verlieren deine Kunden Pro.';
  }

  @override
  String get licenceFixPayment => 'Zahlung korrigieren';

  @override
  String licenceOverLimitBanner(int used, int limit) {
    return 'Du hast $used Kunden in einem Tarif mit $limit Plätzen. Niemand wird entfernt, aber du kannst keine weiteren aufnehmen.';
  }

  @override
  String get licenceUpgrade => 'Upgrade';

  @override
  String licenceFullBanner(int limit, String tier) {
    return 'Alle $limit Plätze deines Tarifs $tier sind belegt.';
  }

  @override
  String traineeProLapsingBanner(String date) {
    return 'Pro über deinen Trainer endet am $date. Deine Daten bleiben erhalten — nur die Pro-Funktionen werden gesperrt.';
  }

  @override
  String get traineeKeepPro => 'Pro behalten';

  @override
  String get inviteFailureSeatLimitReached =>
      'Dein Tarif ist voll. Wechsle den Tarif oder mach einen Platz frei, um einen weiteren Kunden einzuladen.';

  @override
  String get inviteFailureLicenceLapsed =>
      'Deine Lizenz ist abgelaufen. Erneuere sie, um neue Kunden aufzunehmen.';

  @override
  String get inviteFailureNotATrainer =>
      'Nur ein Trainerkonto kann Kunden einladen.';

  @override
  String get inviteFailureInvalidCode =>
      'Zu diesem Code gibt es keine Einladung. Prüfe ihn und versuch es erneut.';

  @override
  String get inviteFailureExpiredCode =>
      'Diese Einladung ist abgelaufen. Frag deinen Trainer nach einem neuen Code.';

  @override
  String get inviteFailureSelfInvite => 'Das ist dein eigener Einladungscode.';

  @override
  String get inviteFailureTrainerAtSeatLimit =>
      'Der Tarif deines Trainers ist voll. Bitte ihn, einen Platz frei zu machen.';

  @override
  String get inviteFailureTrainerNotEntitled =>
      'Der Tarif deines Trainers ist nicht aktiv. Bitte ihn, ihn zu erneuern.';

  @override
  String get inviteFailureNetwork =>
      'ForgeForm ist nicht erreichbar. Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get authFailureInvalidCredentials =>
      'Benutzername oder Passwort ist falsch.';

  @override
  String get authFailureRegistrationFailed =>
      'Dieser Benutzername oder diese E-Mail-Adresse ist bereits vergeben.';

  @override
  String get authFailureUnknownAccountType =>
      'Dieser Kontotyp ist unbekannt. Wähle eine der Optionen und versuche es erneut.';

  @override
  String get authFailureNetwork =>
      'ForgeForm ist nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get authFailureUnknown =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get resetFailureLinkNoLongerValid =>
      'Dieser Link ist abgelaufen oder wurde bereits verwendet.';

  @override
  String inviteFailureSeatLimitReachedDetailed(int seatsUsed, int seatLimit) {
    return 'Dein Tarif umfasst $seatLimit Kunden und alle $seatsUsed sind belegt. Upgrade oder gib einen Platz frei.';
  }

  @override
  String get errorLoadRoster => 'Deine Kunden konnten nicht geladen werden.';

  @override
  String get errorLoadDashboard =>
      'Dein Dashboard konnte nicht geladen werden.';

  @override
  String get errorLoadClientDetail =>
      'Die Details dieses Kunden konnten nicht geladen werden.';

  @override
  String get errorLoadNutrition =>
      'Die Ernährung dieses Kunden konnte nicht geladen werden.';

  @override
  String get errorLoadSessions =>
      'Die Einheiten dieses Kunden konnten nicht geladen werden.';

  @override
  String get errorLoadLicence => 'Dein Tarif konnte nicht geladen werden.';

  @override
  String get errorLoadWorkoutPlans =>
      'Trainingspläne konnten nicht geladen werden.';

  @override
  String get errorPlanNameRequired => 'Gib dem Plan einen Namen.';

  @override
  String get errorCreatePlan => 'Der Plan konnte nicht erstellt werden.';

  @override
  String get errorCreateInvite =>
      'Die Einladung konnte nicht erstellt werden. Versuch es erneut.';

  @override
  String get errorWithdrawInvite =>
      'Die Einladung konnte nicht zurückgezogen werden. Versuch es erneut.';

  @override
  String get errorOpenCheckout =>
      'Die Kasse konnte nicht geöffnet werden. Versuch es erneut.';

  @override
  String get errorOpenBilling =>
      'Die Abrechnung konnte nicht geöffnet werden. Versuch es erneut.';

  @override
  String get clientDetailLoading => 'Kundendetails werden geladen';

  @override
  String get adherence => 'Planerfüllung';

  @override
  String get clientCurrentWeight => 'Aktuelles Gewicht';

  @override
  String get change => 'Veränderung';

  @override
  String planStartedOn(String date) {
    return 'Start $date';
  }

  @override
  String get weightTrend => 'Gewichtsverlauf';

  @override
  String get weightTrendEmptyTitle => 'Zu wenig Gewichtsdaten';

  @override
  String get weightTrendEmptyBody =>
      'Für einen Verlauf braucht es mindestens zwei erfasste Wiegungen.';

  @override
  String entryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String weightTrendSemantics(String from, String to) {
    return 'Gewicht von $from auf $to Kilogramm';
  }

  @override
  String get attendanceEmptyTitle => 'Keine Anwesenheitsdaten';

  @override
  String get attendanceEmptyBody =>
      'Die Anwesenheit erscheint, sobald Einheiten geplant sind.';

  @override
  String get attendanceByWeek => 'Anwesenheit nach Woche';

  @override
  String attendanceWeekSemantics(String date, int completed, int planned) {
    return 'Woche ab $date: $completed von $planned Einheiten';
  }

  @override
  String get strengthEmptyTitle => 'Keine Kraftdaten';

  @override
  String get strengthEmptyBody =>
      'Die Entwicklung erscheint, sobald abgeschlossene Sätze erfasst sind.';

  @override
  String get strengthProgression => 'Kraftentwicklung';

  @override
  String get exercise => 'Übung';

  @override
  String get todaysMacros => 'Makros von heute';

  @override
  String caloriesOfGoal(int eaten, int goal) {
    return '$eaten / $goal kcal';
  }

  @override
  String get macroSummaryNone => 'Keine Makros erfasst';

  @override
  String macroSummarySemantics(String protein, String carbs, String fat) {
    return 'Protein $protein g, Kohlenhydrate $carbs g, Fett $fat g';
  }

  @override
  String switchClientSemantics(String name) {
    return 'Kunde wechseln. Aktuell $name';
  }

  @override
  String get switchClientHeading => 'KUNDE WECHSELN';

  @override
  String get conversationsLoading => 'Unterhaltungen werden geladen';

  @override
  String get conversationsLoadError =>
      'Deine Unterhaltungen konnten nicht geladen werden.';

  @override
  String get conversationsEmpty => 'Noch keine Unterhaltungen';

  @override
  String get conversationsEmptyBody =>
      'Sobald ein Kunde deine Einladung annimmt, kannst du ihm hier schreiben.';

  @override
  String get backToConversations => 'Zurück zu den Unterhaltungen';

  @override
  String get pickAConversation => 'Unterhaltung auswählen';

  @override
  String get pickAConversationBody =>
      'Wähle links einen Kunden, um eure Nachrichten zu sehen.';

  @override
  String get messagesLoading => 'Nachrichten werden geladen';

  @override
  String get trainerThreadEmptyBody =>
      'Sag Hallo — hier beginnt eure Unterhaltung.';

  @override
  String get clientStatsElsewhere =>
      'Kundenstatistiken findest du im Dashboard und in den Kundendetails.';

  @override
  String get nutritionSubtitle => 'Tagesaufnahme und 7-Tage-Verlauf';

  @override
  String get nutritionSubtitleNoClient =>
      'Wähle einen Kunden, um seine Aufnahme zu prüfen';

  @override
  String get previousDay => 'Vorheriger Tag';

  @override
  String get nextDay => 'Nächster Tag';

  @override
  String get nutritionLoading => 'Ernährung wird geladen';

  @override
  String get nutritionNoClientsBody =>
      'Lade deinen ersten Kunden ein, um seine Ernährung zu verfolgen.';

  @override
  String get nothingLogged => 'Nichts erfasst';

  @override
  String nothingLoggedBody(String name) {
    return '$name hat an diesem Tag keine Mahlzeiten erfasst.';
  }

  @override
  String get mealsLogged => 'Erfasste Mahlzeiten';

  @override
  String get meal => 'Mahlzeit';

  @override
  String get noTrendYet => 'Noch kein Verlauf';

  @override
  String get noTrendYetBody =>
      'Sobald Mahlzeiten erfasst sind, erscheint hier der 7-Tage-Verlauf.';

  @override
  String get caloriesVsTarget => 'Kalorien vs. Ziel';

  @override
  String get withinTarget => 'Im Ziel';

  @override
  String get overTarget => 'Über dem Ziel';

  @override
  String targetCalories(int goal) {
    return 'Ziel $goal kcal';
  }

  @override
  String trendBarSemantics(String day, int calories) {
    return '$day: $calories kcal';
  }

  @override
  String trendBarSemanticsOver(String day, int calories) {
    return '$day: $calories kcal, über dem Ziel';
  }

  @override
  String get builderSubtitle => 'Plan erstellen und zuweisen';

  @override
  String get builderSubtitleNoClient =>
      'Wähle einen Kunden, um einen Plan zu erstellen';

  @override
  String get newPlan => 'Neuer Plan';

  @override
  String get builderLoading => 'Trainingsplaner wird geladen';

  @override
  String get builderNoClientsBody =>
      'Lade deinen ersten Kunden ein, um ihm einen Plan zu erstellen.';

  @override
  String planAssignedTo(String name) {
    return 'Plan an $name zugewiesen';
  }

  @override
  String get builderPlanName => 'Planname';

  @override
  String get builderPlanNameHint => 'z. B. Push / Pull / Beine';

  @override
  String get planNameRequired => 'Gib dem Plan einen Namen';

  @override
  String get planDescriptionOptional => 'Beschreibung (optional)';

  @override
  String assignTo(String name) {
    return '$name zuweisen';
  }

  @override
  String get startFromTemplate => 'Mit einer Vorlage starten';

  @override
  String templateDaysAndDescription(int days, String description) {
    return '$days Tage · $description';
  }

  @override
  String get noActivePlanTitle => 'Kein aktiver Plan';

  @override
  String noActivePlanBody(String name) {
    return '$name hat noch keinen Plan.';
  }

  @override
  String get createAPlan => 'Plan erstellen';

  @override
  String get planActive => 'Aktiv';

  @override
  String get sessionReviewSubtitleNoClient =>
      'Wähle einen Kunden, um seine Einheiten zu prüfen';

  @override
  String sessionReviewSubtitle(String name) {
    return 'Was $name tatsächlich erfasst hat';
  }

  @override
  String sessionReviewSubtitleWithCounts(
    String name,
    int total,
    int done,
    int missed,
  ) {
    return 'Was $name tatsächlich erfasst hat — $total Einheiten, $done abgeschlossen, $missed verpasst';
  }

  @override
  String get sessionsLoading => 'Einheiten werden geladen';

  @override
  String get sessionReviewNoClientsBody =>
      'Lade deinen ersten Kunden ein, um seine Einheiten zu prüfen.';

  @override
  String get noSessionsLoggedTitle => 'Noch keine Einheiten erfasst';

  @override
  String noSessionsLoggedBody(String name) {
    return '$name hat noch kein Training erfasst.';
  }

  @override
  String get sessionCompleted => 'Abgeschlossen';

  @override
  String get sessionPartial => 'Teilweise';

  @override
  String get sessionMissed => 'Verpasst';

  @override
  String get sessionSkipped => 'Übersprungen';

  @override
  String dateToday(String date) {
    return 'Heute · $date';
  }

  @override
  String dateYesterday(String date) {
    return 'Gestern · $date';
  }

  @override
  String get sessionHistory => 'Verlauf der Einheiten';

  @override
  String get workout => 'Training';

  @override
  String get noWorkoutLoggedTitle => 'Kein Training erfasst';

  @override
  String noWorkoutLoggedBody(String name) {
    return '$name hat diese Einheit nicht erfasst.';
  }

  @override
  String get newPr => 'NEUER PR';

  @override
  String get pr => 'PR';

  @override
  String get volume => 'Volumen';

  @override
  String get avgRpe => 'Ø RPE';

  @override
  String get clientNote => 'NOTIZ DES KUNDEN';

  @override
  String prescribedSummary(String summary) {
    return 'Vorgabe $summary';
  }

  @override
  String get setColumn => 'SATZ';

  @override
  String get repsColumn => 'WDH.';

  @override
  String get weightColumn => 'GEWICHT';

  @override
  String get rpeColumn => 'RPE';

  @override
  String setNumber(int number) {
    return 'Satz $number';
  }

  @override
  String repsCount(int reps) {
    return '$reps Wiederholungen';
  }

  @override
  String get bodyweight => 'Körpergewicht';

  @override
  String rpeValue(String value) {
    return 'RPE $value';
  }

  @override
  String get underTarget => 'unter Vorgabe';

  @override
  String get joinATrainer => 'Trainer beitreten';

  @override
  String get joinATrainerSubtitle =>
      'Gib den Code ein, den dein Trainer dir gegeben hat';

  @override
  String get joinTrainerTitle => 'Trainer beitreten';

  @override
  String get joinTrainerPrompt =>
      'Gib den Code ein, den dein Trainer dir gegeben hat.';

  @override
  String get trainerCode => 'Trainer-Code';

  @override
  String get joinTrainerAction => 'Trainer beitreten';

  @override
  String get joinTrainerDisclosure =>
      'Dein Trainer kann deine Trainings, dein Gewicht und deine Ernährung sehen. Wenn sein Tarif Pro enthält, bekommst du Pro, solange du auf seiner Liste stehst.';

  @override
  String get joinTrainerCodeMissing =>
      'Gib den 12-stelligen Code deines Trainers ein.';

  @override
  String get joinTrainerCodeMalformed =>
      'Codes bestehen aus 12 Zeichen: Ziffern und die Buchstaben A–F.';

  @override
  String get joinTrainerConnected => 'Du bist mit deinem Trainer verbunden.';

  @override
  String get somethingWentWrongRetry =>
      'Etwas ist schiefgelaufen. Versuch es erneut.';

  @override
  String get dismiss => 'Ausblenden';

  @override
  String get searchOnline => 'Online suchen';

  @override
  String get resetEmailFailed =>
      'Die E-Mail zum Zurücksetzen konnte nicht gesendet werden. Bitte versuch es erneut.';

  @override
  String get kcal => 'kcal';

  @override
  String calorieRingNoGoal(int kcal) {
    return '$kcal kcal erfasst, kein Ziel gesetzt';
  }

  @override
  String calorieRingOver(int eaten, int goal, int over) {
    return '$eaten von $goal kcal, $over darüber';
  }

  @override
  String calorieRingRemaining(int eaten, int goal, int remaining) {
    return '$eaten von $goal kcal, $remaining übrig';
  }

  @override
  String calorieRingGoal(int goal) {
    return '/ $goal kcal';
  }

  @override
  String calorieRingOverBy(int over) {
    return '$over darüber';
  }

  @override
  String calorieRingLeft(int remaining) {
    return '$remaining übrig';
  }

  @override
  String get proteinShort => 'P';

  @override
  String get carbsShort => 'K';

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
      other: '$count Lebensmittel',
      one: '1 Lebensmittel',
    );
    return '$_temp0';
  }

  @override
  String mealDetailSemantics(String meal, int calories) {
    return '$meal, $calories kcal. Öffnen, um alle erfassten Lebensmittel zu sehen.';
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
    return '$name, $grams Gramm, $calories kcal, Protein $protein g, Kohlenhydrate $carbs g, Fett $fat g';
  }

  @override
  String foodRowSemanticsNoWeight(
    String name,
    int calories,
    int protein,
    int carbs,
    int fat,
  ) {
    return '$name, $calories kcal, Protein $protein g, Kohlenhydrate $carbs g, Fett $fat g';
  }

  @override
  String editFoodEntry(String food) {
    return '$food bearbeiten';
  }

  @override
  String deleteFoodEntry(String food) {
    return '$food löschen';
  }

  @override
  String addFoodToCategory(String category) {
    return 'Lebensmittel zu $category hinzufügen';
  }

  @override
  String get pickDate => 'Datum wählen';

  @override
  String get noCalorieTarget => 'Kein Ziel festgelegt';

  @override
  String get kpiAvgAdherenceThisWeek => 'Ø Adhärenz, diese Woche';

  @override
  String get rosterColumnAdherence28d => 'ADHÄRENZ (28 T)';

  @override
  String get adherence28d => 'Adhärenz, letzte 28 Tage';

  @override
  String get couldNotLoad => 'Daten konnten nicht geladen werden';

  @override
  String get couldNotLoadBody =>
      'Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get errorWorkoutNameRequired => 'Gib dem Tag einen Namen.';

  @override
  String get errorLoadClientWorkouts =>
      'Die Workouts dieses Kunden konnten nicht geladen werden.';

  @override
  String get errorLoadExerciseLibrary =>
      'Die Übungsbibliothek konnte nicht geladen werden.';

  @override
  String get errorExerciseNameRequired => 'Gib der Übung einen Namen.';

  @override
  String get errorCreateExercise => 'Die Übung konnte nicht erstellt werden.';

  @override
  String get errorSaveWorkout => 'Dieser Tag konnte nicht gespeichert werden.';

  @override
  String get errorDeleteWorkout => 'Dieser Tag konnte nicht gelöscht werden.';

  @override
  String get errorWorkoutHasHistory =>
      'Für diesen Tag sind bereits Einheiten protokolliert — er kann nicht gelöscht werden.';

  @override
  String get errorUnknownExercise =>
      'Eine der Übungen in diesem Tag konnte nicht zugewiesen werden. Entferne sie und füge sie erneut hinzu.';

  @override
  String get errorScheduleWorkoutPlan =>
      'Dieser Plan konnte nicht eingeplant werden.';

  @override
  String get builderDays => 'Tage';

  @override
  String get builderNewDay => 'Neuer Tag';

  @override
  String get builderDayName => 'Name des Tages';

  @override
  String get builderDayNameHint => 'z. B. Push Day';

  @override
  String get builderDifficulty => 'Schwierigkeit';

  @override
  String get builderDifficultyBeginner => 'Anfänger';

  @override
  String get builderDifficultyIntermediate => 'Fortgeschritten';

  @override
  String get builderDifficultyAdvanced => 'Experte';

  @override
  String get builderDurationMinutes => 'Dauer (Minuten)';

  @override
  String get builderExercises => 'Übungen';

  @override
  String get builderNoExercisesYetTitle => 'Noch keine Übungen';

  @override
  String get builderNoExercisesYetBody =>
      'Füge Übungen hinzu, um diesen Tag aufzubauen.';

  @override
  String get builderAddExercise => 'Übung hinzufügen';

  @override
  String get builderRemoveExercise => 'Übung entfernen';

  @override
  String get builderMoveExerciseUp => 'Nach oben verschieben';

  @override
  String get builderMoveExerciseDown => 'Nach unten verschieben';

  @override
  String get builderSets => 'Sätze';

  @override
  String get builderAddSet => 'Satz hinzufügen';

  @override
  String get builderRemoveSet => 'Satz entfernen';

  @override
  String get builderExpandDayDetails => 'Tagesdetails anzeigen';

  @override
  String get builderCollapseDayDetails => 'Tagesdetails ausblenden';

  @override
  String get builderTargetRepsLabel => 'Ziel-Wiederholungen';

  @override
  String get builderTargetRepsHint => 'z. B. 8-12';

  @override
  String get builderCoachNoteLabel => 'Notiz vom Trainer';

  @override
  String get builderCoachNoteHint => 'z. B. Ellbogen anlegen, RPE 8';

  @override
  String get builderSaveDay => 'Tag speichern';

  @override
  String get builderDeleteDay => 'Tag löschen';

  @override
  String get builderDeleteDayConfirmTitle => 'Diesen Tag löschen?';

  @override
  String builderDeleteDayConfirmBody(String name) {
    return '$name wird aus diesem Plan entfernt. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get builderDiscardChangesTitle => 'Änderungen verwerfen?';

  @override
  String get builderDiscardChangesBody =>
      'Du hast ungespeicherte Änderungen an diesem Tag.';

  @override
  String get builderDiscard => 'Verwerfen';

  @override
  String get builderKeepEditing => 'Weiter bearbeiten';

  @override
  String get builderNoWorkoutsTitle => 'Noch keine Tage';

  @override
  String builderNoWorkoutsBody(String name) {
    return 'Füge den ersten Tag zu ${name}s Plan hinzu.';
  }

  @override
  String get builderPickExerciseTitle => 'Übung hinzufügen';

  @override
  String get builderSearchExercisesHint => 'Übungen suchen';

  @override
  String get builderNoExercisesFound => 'Keine Übungen gefunden.';

  @override
  String get builderNewExerciseAction => 'Neue Übung';

  @override
  String get builderNewExerciseTitle => 'Neue Übung';

  @override
  String get builderExerciseNameLabel => 'Name der Übung';

  @override
  String get builderTrainerOwnedTag =>
      'Deine eigene — wird beim Zuweisen als Kopie mit dem Kunden geteilt';

  @override
  String builderDaySavedConfirmation(String name) {
    return '$name gespeichert';
  }

  @override
  String builderDayDeletedConfirmation(String name) {
    return '$name gelöscht';
  }

  @override
  String get builderUnsavedChangesBadge => 'Ungespeicherte Änderungen';

  @override
  String get builderCreateExercise => 'Erstellen';

  @override
  String get builderDurationRange => 'Muss zwischen 1 und 1440 Minuten liegen.';
}
