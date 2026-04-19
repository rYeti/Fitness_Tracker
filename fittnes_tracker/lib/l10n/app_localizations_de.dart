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
  String get mealCategory => 'Mahlzeitenkategorie';

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
}
