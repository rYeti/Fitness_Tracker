// AUTO-GENERATED — run `python3 tool/generate_seeds.py` to regenerate.
// Do not edit by hand.
import 'package:drift/drift.dart' as drift;
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';

Future<void> seedExercisesIfEmpty(AppDatabase db) async {
  final existingExercises = await db.exerciseDao.getAllExercises();
  if (existingExercises.isEmpty) {
    await _insertAll(db);
  } else {
    await _backfillTranslations(db);
    await _insertMissing(db, existingExercises.map((e) => e.name).toSet());
  }
}

/// Inserts any seed exercise that is not yet present in the local DB.
/// Runs after the backfill so new exercises also get their German name.
Future<void> _insertMissing(AppDatabase db, Set<String> existingNames) async {
  for (final exercise in _exercises) {
    if (!existingNames.contains(exercise.name)) {
      await db.exerciseDao.saveExercise(db.exerciseDao.modelToEntity(exercise));
    }
  }
}

Future<void> _insertAll(AppDatabase db) async {
  for (final exercise in _exercises) {
    await db.exerciseDao.saveExercise(db.exerciseDao.modelToEntity(exercise));
  }
}

/// Updates any pre-existing exercise that still has a null nameDe,
/// matched by English name. Custom exercises are never touched.
Future<void> _backfillTranslations(AppDatabase db) async {
  final all = await db.exerciseDao.getAllExercises();
  final needsUpdate = all.where((e) => (e.nameDe == null || e.descriptionDe == null) && !e.isCustom);
  if (needsUpdate.isEmpty) return;

  final translationMap = {
    for (final ex in _exercises)
      if (ex.nameDe != null)
        ex.name: (nameDe: ex.nameDe!, descriptionDe: ex.descriptionDe),
  };

  for (final row in needsUpdate) {
    final t = translationMap[row.name];
    if (t == null) continue;
    await (db.update(db.exerciseTable)..where((e) => e.id.equals(row.id)))
        .write(ExerciseTableCompanion(
      nameDe: drift.Value(t.nameDe),
      descriptionDe: drift.Value(t.descriptionDe),
    ));
  }
}

final _exercises = <Exercise>[

  // ── STRENGTH (581) ────────────────────────────────────────────────────────────

  Exercise(
    name: '3/4 Sit-Up',
    description: 'Lie down on the floor and secure your feet. Your legs should be bent at the knees. Place your hands behind or to the side of your head. You will begin with your back on the ground. This will be your starting position. Flex your hips and spine to raise your torso toward your knees. At the top of the contraction your torso should be perpendicular to the ground. Reverse the motion, going only ¾ of...',
    nameDe: 'Dreiviertel Sit-Up',
    descriptionDe: 'Lie down on the Boden and secure your feet. Your legs should be bent at the knees. Place your hands behind or to the side of your Kopf. You will begin with your Rücken on the ground. This will be your starting position. Flex your Hüften and Wirbelsäule to Heben your torso toward your knees. At the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Ab Crunch Machine',
    description: 'Select a light resistance and sit down on the ab machine placing your feet under the pads provided and grabbing the top handles. Your arms should be bent at a 90 degree angle as you rest the triceps on the pads provided. This will be your starting position. At the same time, begin to lift the legs up as you crunch your upper torso. Breathe out as you perform this movement. Tip: Be sure to use a...',
    nameDe: 'Bauchcrunch-Maschine',
    descriptionDe: 'Select a light resistance and sit down on the ab Maschine placing your feet under the pads provided and grabbing the top handles. Your arms should be bent at a 90 degree angle as you rest the Trizeps on the pads provided. This will be your starting position. At the same time, begin to lift the legs...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Ab Roller',
    description: 'Hold the Ab Roller with both hands and kneel on the floor. Now place the ab roller on the floor in front of you so that you are on all your hands and knees (as in a kneeling push up position). This will be your starting position. Slowly roll the ab roller straight forward, stretching your body into a straight position. Tip: Go down as far as you can without touching the floor with your body....',
    nameDe: 'Bauchradtrainer',
    descriptionDe: 'Hold the Bauchradtrainer with both hands and kneel on the Boden. Now place the Bauchradtrainer on the Boden in front of you so that you are on all your hands and knees (as in a Kniend Liegestütz position). This will be your starting position. Slowly roll the Bauchradtrainer straight forward,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Advanced Kettlebell Windmill',
    description: 'Clean and press a kettlebell overhead with one arm. Keeping the kettlebell locked out at all times, push your butt out in the direction of the locked out kettlebell. Keep the non-working arm behind your back and turn your feet out at a forty-five degree angle from the arm with the kettlebell. Lower yourself as far as possible. Pause for a second and reverse the motion back to the starting...',
    nameDe: 'Fortgeschritten Kettlebell Windmühle',
    descriptionDe: 'Stoßen and Drücken a Kettlebell Überkopf with Einarmig. Keeping the Kettlebell locked out at all times, push your butt out in the direction of the locked out Kettlebell. Keep the non-working arm behind your Rücken and turn your feet out at a forty-five degree angle from the arm with the Kettlebell....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Air Bike',
    description: 'Lie flat on the floor with your lower back pressed to the ground. For this exercise, you will need to put your hands beside your head. Be careful however to not strain with the neck as you perform it. Now lift your shoulders into the crunch position. Bring knees up to where they are perpendicular to the floor, with your lower legs parallel to the floor. This will be your starting position. Now...',
    nameDe: 'Air-Bike',
    descriptionDe: 'Lie Flachbank on the Boden with your Unterer Rücken pressed to the ground. For this exercise, you will need to put your hands beside your Kopf. Be careful however to not strain with the Nacken as you perform it. Now lift your Schultern into the Crunch position. Bring knees up to where they are...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Alternate Hammer Curl',
    description: 'Stand up with your torso upright and a dumbbell in each hand being held at arms length. The elbows should be close to the torso. The palms of the hands should be facing your torso. This will be your starting position. While holding the upper arm stationary, curl the right weight forward while contracting the biceps as you breathe out. Continue the movement until your biceps is fully contracted...',
    nameDe: 'Alternierend Hammer-Curl',
    descriptionDe: 'Stand up with your torso Aufrecht and a Kurzhantel in each hand being held at arms length. The elbows should be close to the torso. The palms of the hands should be facing your torso. This will be your starting position. While holding the Oberer arm stationary, Curl the right weight forward while...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Alternate Heel Touchers',
    description: 'Lie on the floor with the knees bent and the feet on the floor around 18-24 inches apart. Your arms should be extended by your side. This will be your starting position. Crunch over your torso forward and up about 3-4 inches to the right side and touch your right heel as you hold the contraction for a second. Exhale while performing this movement. Now go back slowly to the starting position as...',
    nameDe: 'Alternierend Heel Touchers',
    descriptionDe: 'Lie on the Boden with the knees bent and the feet on the Boden around 18-24 inches apart. Your arms should be extended by your side. This will be your starting position. Crunch over your torso forward and up about 3-4 inches to the right side and touch your right heel as you hold the contraction...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Alternate Incline Dumbbell Curl',
    description: 'Sit down on an incline bench with a dumbbell in each hand being held at arms length. Tip: Keep the elbows close to the torso.This will be your starting position. While holding the upper arm stationary, curl the right weight forward while contracting the biceps as you breathe out. As you do so, rotate the hand so that the palm is facing up. Continue the movement until your biceps is fully...',
    nameDe: 'Alternierend Schrägbank Kurzhantel Curl',
    descriptionDe: 'Sit down on an Schrägbank Bank with a Kurzhantel in each hand being held at arms length. Tip: Keep the elbows close to the torso.This will be your starting position. While holding the Oberer arm stationary, Curl the right weight forward while contracting the Bizeps as you breathe out. As you do so,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Alternating Cable Shoulder Press',
    description: 'Move the cables to the bottom of the tower and select an appropriate weight. Grasp the cables and hold them at shoulder height, palms facing forward. This will be your starting position. Keeping your head and chest up, extend through the elbow to press one side directly over head. After pausing at the top, return to the starting position and repeat on the opposite side.',
    nameDe: 'Alternierend Kabelzug Schulterdrücken',
    descriptionDe: 'Move the cables to the bottom of the tower and select an appropriate weight. Grasp the cables and hold them at Schulter height, palms facing forward. This will be your starting position. Keeping your Kopf and Brust up, extend through the elbow to Drücken one side directly over Kopf. After pausing...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Alternating Deltoid Raise',
    description: 'In a standing position, hold a pair of dumbbells at your side. Keeping your elbows slightly bent, raise the weights directly in front of you to shoulder height, avoiding any swinging or cheating. Return the weights to your side. On the next repetition, raise the weights laterally, raising them out to your side to about shoulder height. Return the weights to the starting position and continue...',
    nameDe: 'Alternierend Deltamuskel Heben',
    descriptionDe: 'In a Stehend position, hold a pair of Kurzhanteln at your side. Keeping your elbows slightly bent, Heben the weights directly in front of you to Schulter height, avoiding any swinging or cheating. Return the weights to your side. On the next repetition, Heben the weights laterally, raising them out...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Alternating Floor Press',
    description: 'Lie on the floor with two kettlebells next to your shoulders. Position one in place on your chest and then the other, gripping the kettlebells on the handle with the palms facing forward. Extend both arms, so that the kettlebells are being held above your chest. Lower one kettlebell, bringing it to your chest and turn the wrist in the direction of the locked out kettlebell. Raise the kettlebell...',
    nameDe: 'Alternierend Boden Drücken',
    descriptionDe: 'Lie on the Boden with two Kettlebells next to your Schultern. Position one in place on your Brust and then the other, gripping the Kettlebells on the handle with the palms facing forward. Extend both arms, so that the Kettlebells are being held above your Brust. Unterer one Kettlebell, bringing it...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Alternating Hang Clean',
    description: 'Place two kettlebells between your feet. To get in the starting position, push your butt back and look straight ahead. Clean one kettlebell to your shoulder and hold on to the other kettlebell in a hanging position. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulders. Rotate your wrist as you do so. Lower the cleaned...',
    nameDe: 'Alternierend Hang-Stoßen',
    descriptionDe: 'Place two Kettlebells between your feet. To get in the starting position, push your butt Rücken and look straight ahead. Stoßen one Kettlebell to your Schulter and hold on to the other Kettlebell in a hanging position. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Alternating Kettlebell Press',
    description: 'Clean two kettlebells to your shoulders. Clean the kettlebells to your shoulders by extending through the legs and hips as you pull the kettlebells towards your shoulders. Rotate your wrists as you do so. Press one directly overhead by extending through the elbow, turning it so the palm faces forward while holding the other kettlebell stationary . Lower the pressed kettlebell to the starting...',
    nameDe: 'Alternierend Kettlebell Drücken',
    descriptionDe: 'Stoßen two Kettlebells to your Schultern. Stoßen the Kettlebells to your Schultern by extending through the legs and Hüften as you pull the Kettlebells towards your Schultern. Rotate your wrists as you do so. Drücken one directly Überkopf by extending through the elbow, turning it so the palm faces...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Alternating Kettlebell Row',
    description: 'Place two kettlebells in front of your feet. Bend your knees slightly and push your butt out as much as possible. As you bend over to get into the starting position grab both kettlebells by the handles. Pull one kettlebell off of the floor while holding on to the other kettlebell. Retract the shoulder blade of the working side, as you flex the elbow, drawing the kettlebell towards your stomach or...',
    nameDe: 'Alternierend Kettlebell Rudern',
    descriptionDe: 'Place two Kettlebells in front of your feet. Bend your knees slightly and push your butt out as much as possible. As you bend over to get into the starting position grab both Kettlebells by the handles. Pull one Kettlebell off of the Boden while holding on to the other Kettlebell. Retract the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Alternating Renegade Row',
    description: 'Place two kettlebells on the floor about shoulder width apart. Position yourself on your toes and your hands as though you were doing a pushup, with the body straight and extended. Use the handles of the kettlebells to support your upper body. You may need to position your feet wide for support. Push one kettlebell into the floor and row the other kettlebell, retracting the shoulder blade of the...',
    nameDe: 'Alternierend Renegade Rudern',
    descriptionDe: 'Place two Kettlebells on the Boden about Schulter width apart. Position yourself on your toes and your hands as though you were doing a Liegestütz, with the body straight and extended. Use the handles of the Kettlebells to support your Oberer body. You may need to position your feet wide for...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Anti-Gravity Press',
    description: 'Place a bar on the ground behind the head of an incline bench. Lay on the bench face down. With a pronated grip, pick the barbell up from the floor. Flex the elbows, performing a reverse curl to bring the bar near your chest. This will be your starting position. To begin, press the barbell out in front of your head by extending your elbows. Keep your arms parallel to the ground throughout the...',
    nameDe: 'Anti-Schwerkraft Drücken',
    descriptionDe: 'Place a Stange on the ground behind the Kopf of an Schrägbank Bank. Lay on the Bank face down. With a Proniert grip, pick the Langhantel up from the Boden. Flex the elbows, performing a Umgekehrt-Curl to bring the Stange near your Brust. This will be your starting position. To begin, Drücken the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Arnold Dumbbell Press',
    description: 'Sit on an exercise bench with back support and hold two dumbbells in front of you at about upper chest level with your palms facing your body and your elbows bent. Tip: Your arms should be next to your torso. The starting position should look like the contracted portion of a dumbbell curl. Now to perform the movement, raise the dumbbells as you rotate the palms of your hands until they are facing...',
    nameDe: 'Arnold-Schulterdrücken',
    descriptionDe: 'Sit on an exercise Bank with Rücken support and hold two Kurzhanteln in front of you at about Oberer Brust level with your palms facing your body and your elbows bent. Tip: Your arms should be next to your torso. The starting position should look like the contracted portion of a Kurzhantel Curl....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Around The Worlds',
    description: 'Lay down on a flat bench holding a dumbbell in each hand with the palms of the hands facing towards the ceiling. Tip: Your arms should be parallel to the floor and next to your thighs. To avoid injury, make sure that you keep your elbows slightly bent. This will be your starting position. Now move the dumbbells by creating a semi-circle as you displace them from the initial position to over the...',
    nameDe: 'Um die Welt',
    descriptionDe: 'Lay down on a Flachbank Bank holding a Kurzhantel in each hand with the palms of the hands facing towards the ceiling. Tip: Your arms should be parallel to the Boden and next to your thighs. To avoid injury, make sure that you keep your elbows slightly bent. This will be your starting position. Now...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Back Flyes - With Bands',
    description: 'Run a band around a stationary post like that of a squat rack. Grab the band by the handles and stand back so that the tension in the band rises. Extend and lift the arms straight in front of you. Tip: Your arms should be straight and parallel to the floor while perpendicular to your torso. Your feet should be firmly planted on the floor spread at shoulder width. This will be your starting...',
    nameDe: 'Rücken Flyes - mit Band',
    descriptionDe: 'Laufen a Band around a stationary post like that of a Kniebeuge Ständer. Grab the Band by the handles and stand Rücken so that the tension in the Band rises. Extend and lift the arms straight in front of you. Tip: Your arms should be straight and parallel to the Boden while perpendicular to your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Balance Board',
    description: 'Place a balance board in front of you. Stand up on it and try to balance yourself. Hold the balance for as long as desired.',
    nameDe: 'Gleichgewichtsbrett',
    descriptionDe: 'Place a Gleichgewichtsbrett in front of you. Stand up on it and try to balance yourself. Hold the balance for as long as desired.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Ball Leg Curl',
    description: 'Begin on the floor laying on your back with your feet on top of the ball. Position the ball so that when your legs are extended your ankles are on top of the ball. This will be your starting position. Raise your hips off of the ground, keeping your weight on the shoulder blades and your feet. Flex the knees, pulling the ball as close to you as you can, contracting the hamstrings. After a brief...',
    nameDe: 'Beincurl auf dem Ball',
    descriptionDe: 'Begin on the Boden laying on your Rücken with your feet on top of the Ball. Position the Ball so that when your legs are extended your ankles are on top of the Ball. This will be your starting position. Heben your Hüften off of the ground, keeping your weight on the Schulter blades and your feet....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Band Assisted Pull-Up',
    description: 'Choke the band around the center of the pullup bar. You can use different bands to provide varying levels of assistance. Pull the end of the band down, and place one bent knee into the loop, ensuring it won\'t slip out. Take a medium to wide grip on the bar. This will be your starting position. Pull yourself upward by contracting the lats as you flex the elbow. The elbow should be driven to your...',
    nameDe: 'Klimmzug mit Bandunterstützung',
    descriptionDe: 'Choke the Band around the center of the Klimmzug Stange. You can use different bands to provide varying levels of assistance. Pull the end of the Band down, and place one bent Knie into the loop, ensuring it won\'t slip out. Take a medium to Weiter Griff on the Stange. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Band Hip Adductions',
    description: 'Anchor a band around a solid post or other object. Stand with your left side to the post, and put your right foot through the band, getting it around the ankle. Stand up straight and hold onto the post if needed. This will be your starting position. Keeping the knee straight, raise your right legs out to the side as far as you can. Return to the starting position and repeat for the desired rep...',
    nameDe: 'Hüftadduktion mit Band',
    descriptionDe: 'Anchor a Band around a solid post or other object. Stand with your left side to the post, and put your right foot through the Band, getting it around the Knöchel. Stand up straight and hold onto the post if needed. This will be your starting position. Keeping the Knie straight, Heben your right...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Band Pull Apart',
    description: 'Begin with your arms extended straight out in front of you, holding the band with both hands. Initiate the movement by performing a reverse fly motion, moving your hands out laterally to your sides. Keep your elbows extended as you perform the movement, bringing the band to your chest. Ensure that you keep your shoulders back during the exercise. Pause as you complete the movement, returning to...',
    nameDe: 'Bandauseinanderziehen',
    descriptionDe: 'Begin with your arms extended straight out in front of you, holding the Band with both hands. Initiate the movement by performing a Umgekehrt Fliegender motion, moving your hands out laterally to your sides. Keep your elbows extended as you perform the movement, bringing the Band to your Brust....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Band Skull Crusher',
    description: 'Secure a band to the base of a rack or the bench. Lay on the bench so that the band is lined up with your head. Take hold of the band, raising your elbows so that the upper arm is perpendicular to the floor. With the elbow flexed, the band should be above your head. This will be your starting position. Extend through the elbow to straighten your arm, keeping your upper arm in place. Pause at the...',
    nameDe: 'Band Stirndrücken',
    descriptionDe: 'Secure a Band to the base of a Ständer or the Bank. Lay on the Bank so that the Band is lined up with your Kopf. Take hold of the Band, raising your elbows so that the Oberer arm is perpendicular to the Boden. With the elbow flexed, the Band should be above your Kopf. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Barbell Ab Rollout',
    description: 'For this exercise you will need to get into a pushup position, but instead of having your hands of the floor, you will be grabbing on to an Olympic barbell (loaded with 5-10 lbs on each side) instead. This will be your starting position. While keeping a slight arch on your back, lift your hips and roll the barbell towards your feet as you exhale. Tip: As you perform the movement, your glutes...',
    nameDe: 'Langhantel-Bauchausrollen',
    descriptionDe: 'For this exercise you will need to get into a Liegestütz position, but instead of having your hands of the Boden, you will be grabbing on to an Olympia-Langhantel (loaded with 5-10 lbs on each side) instead. This will be your starting position. While keeping a slight arch on your Rücken, lift your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Barbell Ab Rollout - On Knees',
    description: 'Hold an Olympic barbell loaded with 5-10lbs on each side and kneel on the floor. Now place the barbell on the floor in front of you so that you are on all your hands and knees (as in a kneeling push up position). This will be your starting position. Slowly roll the barbell straight forward, stretching your body into a straight position. Tip: Go down as far as you can without touching the floor...',
    nameDe: 'Langhantel Ab Ausrollen - On Knees',
    descriptionDe: 'Hold an Olympia-Langhantel loaded with 5-10lbs on each side and kneel on the Boden. Now place the Langhantel on the Boden in front of you so that you are on all your hands and knees (as in a Kniend Liegestütz position). This will be your starting position. Slowly roll the Langhantel straight...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Barbell Bench Press - Medium Grip',
    description: 'Lie back on a flat bench. Using a medium width grip (a grip that creates a 90-degree angle in the middle of the movement between the forearms and the upper arms), lift the bar from the rack and hold it straight over you with your arms locked. This will be your starting position. From the starting position, breathe in and begin coming down slowly until the bar touches your middle chest. After a...',
    nameDe: 'Langhantel Bank Drücken - Medium Grip',
    descriptionDe: 'Lie Rücken on a Flachbank Bank. Using a medium width grip (a grip that creates a 90-degree angle in the middle of the movement between the Unterarme and the Oberer arms), lift the Stange from the Ständer and hold it straight over you with your arms locked. This will be your starting position. From...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Barbell Curl',
    description: 'Stand up with your torso upright while holding a barbell at a shoulder-width grip. The palm of your hands should be facing forward and the elbows should be close to the torso. This will be your starting position. While holding the upper arms stationary, curl the weights forward while contracting the biceps as you breathe out. Tip: Only the forearms should move. Continue the movement until your...',
    nameDe: 'Langhantel-Curl',
    descriptionDe: 'Stand up with your torso Aufrecht while holding a Langhantel at a Schulter-width grip. The palm of your hands should be facing forward and the elbows should be close to the torso. This will be your starting position. While holding the Oberer arms stationary, Curl the weights forward while...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Barbell Curls Lying Against An Incline',
    description: 'Lie against an incline bench, with your arms holding a barbell and hanging down in a horizontal line. This will be your starting position. While keeping the upper arms stationary, curl the weight up as high as you can while squeezing the biceps. Breathe out as you perform this portion of the movement. Tip: Only the forearms should move. Do not swing the arms. After a second contraction, slowly go...',
    nameDe: 'Langhantel Curls Liegend Against An Schrägbank',
    descriptionDe: 'Lie against an Schrägbank Bank, with your arms holding a Langhantel and hanging down in a Horizontal line. This will be your starting position. While keeping the Oberer arms stationary, Curl the weight up as high as you can while squeezing the Bizeps. Breathe out as you perform this portion of the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Barbell Deadlift',
    description: 'Stand in front of a loaded barbell. While keeping the back as straight as possible, bend your knees, bend forward and grasp the bar using a medium (shoulder width) overhand grip. This will be the starting position of the exercise. Tip: If it is difficult to hold on to the bar with this grip, alternate your grip or use wrist straps. While holding the bar, start the lift by pushing with your legs...',
    nameDe: 'Langhantel Kreuzheben',
    descriptionDe: 'Stand in front of a loaded Langhantel. While keeping the Rücken as straight as possible, bend your knees, bend forward and grasp the Stange using a medium (Schulter width) Obergriff grip. This will be the starting position of the exercise. Tip: If it is difficult to hold on to the Stange with this...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Barbell Full Squat',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack just above shoulder level. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs and at...',
    nameDe: 'Volle Langhantel-Kniebeuge',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer just above Schulter level. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Guillotine Bench Press',
    description: 'Using a medium width grip (a grip that creates a 90-degree angle in the middle of the movement between the forearms and the upper arms), lift the bar from the rack and hold it straight over your neck with your arms locked. This will be your starting position. As you breathe in, bring the bar down slowly until it is about 1 inch from your neck. After a second pause, bring the bar back to the...',
    nameDe: 'Langhantel Guillotine Bank Drücken',
    descriptionDe: 'Using a medium width grip (a grip that creates a 90-degree angle in the middle of the movement between the Unterarme and the Oberer arms), lift the Stange from the Ständer and hold it straight over your Nacken with your arms locked. This will be your starting position. As you breathe in, bring the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Barbell Hack Squat',
    description: 'Stand up straight while holding a barbell behind you at arms length and your feet at shoulder width. Tip: A shoulder width grip is best with the palms of your hands facing back. You can use wrist wraps for this exercise for a better grip. This will be your starting position. While keeping your head and eyes up and back straight, squat until your upper thighs are parallel to the floor. Breathe in...',
    nameDe: 'Langhantel Hack Kniebeuge',
    descriptionDe: 'Stand up straight while holding a Langhantel behind you at arms length and your feet at Schulter width. Tip: A Schulter width grip is best with the palms of your hands facing Rücken. You can use Handgelenk wraps for this exercise for a better grip. This will be your starting position. While keeping...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Incline Bench Press - Medium Grip',
    description: 'Lie back on an incline bench. Using a medium-width grip (a grip that creates a 90-degree angle in the middle of the movement between the forearms and the upper arms), lift the bar from the rack and hold it straight over you with your arms locked. This will be your starting position. As you breathe in, come down slowly until you feel the bar on you upper chest. After a second pause, bring the bar...',
    nameDe: 'Langhantel Schrägbank Bank Drücken - Medium Grip',
    descriptionDe: 'Lie Rücken on an Schrägbank Bank. Using a medium-width grip (a grip that creates a 90-degree angle in the middle of the movement between the Unterarme and the Oberer arms), lift the Stange from the Ständer and hold it straight over you with your arms locked. This will be your starting position. As...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Barbell Incline Shoulder Raise',
    description: 'Lie back on an Incline Bench. Using a medium width grip (a grip that is slightly wider than shoulder width), lift the bar from the rack and hold it straight over you with your arms straight. This will be your starting position. While keeping the arms straight, lift the bar by protracting your shoulder blades, raising the shoulders from the bench as you breathe out. Bring back the bar to the...',
    nameDe: 'Langhantel Schrägbank Schulter Heben',
    descriptionDe: 'Lie Rücken on an Schrägbank Bank. Using a medium width grip (a grip that is slightly wider than Schulter width), lift the Stange from the Ständer and hold it straight over you with your arms straight. This will be your starting position. While keeping the arms straight, lift the Stange by...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Barbell Lunge',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack just below shoulder level. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs and at...',
    nameDe: 'Langhantel Ausfallschritt',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer just below Schulter level. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Rear Delt Row',
    description: 'Stand up straight while holding a barbell using a wide (higher than shoulder width) and overhand (palms facing your body) grip. Bend knees slightly and bend over as you keep the natural arch of your back. Let the arms hang in front of you as they hold the bar. Once your torso is parallel to the floor, flare the elbows out and away from your body. Tip: Your torso and your arms should resemble the...',
    nameDe: 'Langhantel Rear Delt Rudern',
    descriptionDe: 'Stand up straight while holding a Langhantel using a wide (higher than Schulter width) and Obergriff (palms facing your body) grip. Bend knees slightly and bend over as you keep the natural arch of your Rücken. Let the arms hang in front of you as they hold the Stange. Once your torso is parallel...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Barbell Rollout from Bench',
    description: 'Place a loaded barbell on the ground, near the end of a bench. Kneel with both legs on the bench, and take a medium to narrow grip on the barbell. This will be your starting position. To begin, extend through the hips to slowly roll the bar forward. As you roll out, flex the shoulder to roll the bar above your head. Ensure that your arms remain extended throughout the movement. When the bar has...',
    nameDe: 'Langhantel Ausrollen from Bank',
    descriptionDe: 'Place a loaded Langhantel on the ground, near the end of a Bank. Kneel with both legs on the Bank, and take a medium to Enger Griff on the Langhantel. This will be your starting position. To begin, extend through the Hüften to slowly roll the Stange forward. As you roll out, flex the Schulter to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Barbell Seated Calf Raise',
    description: 'Place a block about 12 inches in front of a flat bench. Sit on the bench and place the ball of your feet on the block. Have someone place a barbell over your upper thighs about 3 inches above your knees and hold it there. This will be your starting position. Raise up on your toes as high as possible as you squeeze the calves and as you breathe out. After a second contraction, slowly go back to...',
    nameDe: 'Langhantel Sitzend Wadenlifte',
    descriptionDe: 'Place a block about 12 inches in front of a Flachbank Bank. Sit on the Bank and place the Ball of your feet on the block. Have someone place a Langhantel over your Oberer thighs about 3 inches above your knees and hold it there. This will be your starting position. Heben up on your toes as high as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Shoulder Press',
    description: 'Sit on a bench with back support in a squat rack. Position a barbell at a height that is just above your head. Grab the barbell with a pronated grip (palms facing forward). Once you pick up the barbell with the correct grip width, lift the bar up over your head by locking your arms. Hold at about shoulder level and slightly in front of your head. This is your starting position. Lower the bar down...',
    nameDe: 'Langhantel-Schulterdrücken',
    descriptionDe: 'Sit on a Bank with Rücken support in a Kniebeuge Ständer. Position a Langhantel at a height that is just above your Kopf. Grab the Langhantel with a Proniert grip (palms facing forward). Once you pick up the Langhantel with the correct grip width, lift the Stange up over your Kopf by locking your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Barbell Shrug',
    description: 'Stand up straight with your feet at shoulder width as you hold a barbell with both hands in front of you using a pronated grip (palms facing the thighs). Tip: Your hands should be a little wider than shoulder width apart. You can use wrist wraps for this exercise for a better grip. This will be your starting position. Raise your shoulders up as far as you can go as you breathe out and hold the...',
    nameDe: 'Langhantel Schulterziehen',
    descriptionDe: 'Stand up straight with your feet at Schulter width as you hold a Langhantel with both hands in front of you using a Proniert grip (palms facing the thighs). Tip: Your hands should be a little wider than Schulter width apart. You can use Handgelenk wraps for this exercise for a better grip. This...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Barbell Shrug Behind The Back',
    description: 'Stand up straight with your feet at shoulder width as you hold a barbell with both hands behind your back using a pronated grip (palms facing back). Tip: Your hands should be a little wider than shoulder width apart. You can use wrist wraps for this exercise for better grip. This will be your starting position. Raise your shoulders up as far as you can go as you breathe out and hold the...',
    nameDe: 'Langhantel Schulterziehen Behind The Rücken',
    descriptionDe: 'Stand up straight with your feet at Schulter width as you hold a Langhantel with both hands behind your Rücken using a Proniert grip (palms facing Rücken). Tip: Your hands should be a little wider than Schulter width apart. You can use Handgelenk wraps for this exercise for better grip. This will...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Barbell Side Bend',
    description: 'Stand up straight while holding a barbell placed on the back of your shoulders (slightly below the neck). Your feet should be shoulder width apart. This will be your starting position. While keeping your back straight and your head up, bend only at the waist to the right as far as possible. Breathe in as you bend to the side. Then hold for a second and come back up to the starting position as you...',
    nameDe: 'Langhantel Side Bend',
    descriptionDe: 'Stand up straight while holding a Langhantel placed on the Rücken of your Schultern (slightly below the Nacken). Your feet should be Schulter width apart. This will be your starting position. While keeping your Rücken straight and your Kopf up, bend only at the waist to the right as far as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Barbell Side Split Squat',
    description: 'Stand up straight while holding a barbell placed on the back of your shoulders (slightly below the neck). Your feet should be placed wide apart with the foot of the lead leg angled out to the side. This will be your starting position. Lower your body towards the side of your angled foot by bending the knee and hip of your lead leg and while keeping the opposite leg only slightly bent. Breathe in...',
    nameDe: 'Langhantel-Seitkniebeuge',
    descriptionDe: 'Stand up straight while holding a Langhantel placed on the Rücken of your Schultern (slightly below the Nacken). Your feet should be placed wide apart with the foot of the lead leg angled out to the side. This will be your starting position. Unterer your body towards the side of your angled foot by...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Squat',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack to just below shoulder level. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs and...',
    nameDe: 'Langhantel Kniebeuge',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer to just below Schulter level. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Squat To A Bench',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first place a flat bench or a box behind you. The flat bench is used to teach you to set your hips back and to hit depth.  Then, set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the...',
    nameDe: 'Langhantel Kniebeuge To A Bank',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first place a Flachbank Bank or a Box behind you. The Flachbank Bank is used to teach you to set your Hüften Rücken and to hit depth.  Then, set the Stange on a Ständer that best matches your height. Once the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Step Ups',
    description: 'Stand up straight while holding a barbell placed on the back of your shoulders (slightly below the neck) and stand upright behind an elevated platform (such as the one used for spotting behind a flat bench). This is your starting position. Place the right foot on the elevated platform. Step on the platform by extending the hip and the knee of your right leg. Use the heel mainly to lift the rest...',
    nameDe: 'Langhantel Stufe Ups',
    descriptionDe: 'Stand up straight while holding a Langhantel placed on the Rücken of your Schultern (slightly below the Nacken) and stand Aufrecht behind an elevated platform (such as the one used for spotting behind a Flachbank Bank). This is your starting position. Place the right foot on the elevated platform....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Walking Lunge',
    description: 'Begin standing with your feet shoulder width apart and a barbell across your upper back. Step forward with one leg, flexing the knees to drop your hips. Descend until your rear knee nearly touches the ground. Your posture should remain upright, and your front knee should stay above the front foot. Drive through the heel of your lead foot and extend both knees to raise yourself back up. Step...',
    nameDe: 'Langhantel-Ausfallschritte',
    descriptionDe: 'Begin Stehend with your feet Schulter width apart and a Langhantel across your Oberer Rücken. Stufe forward with one leg, flexing the knees to drop your Hüften. Descend until your rear Knie nearly touches the ground. Your posture should remain Aufrecht, and your front Knie should stay above the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Battling Ropes',
    description: 'For this exercise you will need a heavy rope anchored at its center 15-20 feet away. Standing in front of the rope, take an end in each hand with your arms extended at your side. This will be your starting position. Initiate the movement by rapidly raising one arm to shoulder level as quickly as you can. As you let that arm drop to the starting position, raise the opposite side. Continue...',
    nameDe: 'Battling Ropes',
    descriptionDe: 'For this exercise you will need a heavy Seil anchored at its center 15-20 feet away. Stehend in front of the Seil, take an end in each hand with your arms extended at your side. This will be your starting position. Initiate the movement by rapidly raising Einarmig to Schulter level as quickly as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Bench Dips',
    description: 'For this exercise you will need to place a bench behind your back. With the bench perpendicular to your body, and while looking away from it, hold on to the bench on its edge with the hands fully extended, separated at shoulder width. The legs will be extended forward, bent at the waist and perpendicular to your torso. This will be your starting position. Slowly lower your body as you inhale by...',
    nameDe: 'Bank Dips',
    descriptionDe: 'For this exercise you will need to place a Bank behind your Rücken. With the Bank perpendicular to your body, and while looking away from it, hold on to the Bank on its edge with the hands fully extended, separated at Schulter width. The legs will be extended forward, bent at the waist and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Bench Press - With Bands',
    description: 'Using a flat bench secure a band under the leg of the bench that is nearest to your head. Once the band is secure, grab it by both handles and lie down on the bench. Extend your arms so that you are holding the band handles in front of you at shoulder width. Once at shoulder width, rotate your wrists forward so that the palms of your hands are facing away from you. This will be your starting...',
    nameDe: 'Bank Drücken - mit Band',
    descriptionDe: 'Using a Flachbank Bank secure a Band under the leg of the Bank that is nearest to your Kopf. Once the Band is secure, grab it by both handles and lie down on the Bank. Extend your arms so that you are holding the Band handles in front of you at Schulter width. Once at Schulter width, rotate your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Bent-Arm Barbell Pullover',
    description: 'Lie on a flat bench with a barbell using a shoulder grip width. Hold the bar straight over your chest with a bend in your arms. This will be your starting position. While keeping your arms in the bent arm position, lower the weight slowly in an arc behind your head while breathing in until you feel a stretch on the chest. At that point, bring the barbell back to the starting position using the...',
    nameDe: 'Bent-Arm Langhantel Pullover',
    descriptionDe: 'Lie on a Flachbank Bank with a Langhantel using a Schulter grip width. Hold the Stange straight over your Brust with a bend in your arms. This will be your starting position. While keeping your arms in the bent arm position, Unterer the weight slowly in an arc behind your Kopf while breathing in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Bent-Arm Dumbbell Pullover',
    description: 'Place a dumbbell standing up on a flat bench. Ensuring that the dumbbell stays securely placed at the top of the bench, lie perpendicular to the bench (torso across it as in forming a cross) with only your shoulders lying on the surface. Hips should be below the bench and legs bent with feet firmly on the floor. The head will be off the bench as well. Grasp the dumbbell with both hands and hold...',
    nameDe: 'Bent-Arm Kurzhantel Pullover',
    descriptionDe: 'Place a Kurzhantel Stehend up on a Flachbank Bank. Ensuring that the Kurzhantel stays securely placed at the top of the Bank, lie perpendicular to the Bank (torso across it as in forming a Überkreuz) with only your Schultern Liegend on the surface. Hüften should be below the Bank and legs bent with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Bent-Knee Hip Raise',
    description: 'Lay flat on the floor with your arms next to your sides. Now bend your knees at around a 75 degree angle and lift your feet off the floor by around 2 inches. Using your lower abs, bring your knees in towards you as you maintain the 75 degree angle bend in your legs. Continue this movement until you raise your hips off of the floor by rolling your pelvis backward. Breathe out as you perform this...',
    nameDe: 'Hüftheben mit gebeugten Knien',
    descriptionDe: 'Lay Flachbank on the Boden with your arms next to your sides. Now bend your knees at around a 75 degree angle and lift your feet off the Boden by around 2 inches. Using your Unterer Bauch, bring your knees in towards you as you maintain the 75 degree angle bend in your legs. Continue this movement...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Bent Over Barbell Row',
    description: 'Holding a barbell with a pronated grip (palms facing down), bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the back straight until it is almost parallel to the floor. Tip: Make sure that you keep the head up. The barbell should hang directly in front of you as your arms hang perpendicular to the floor and your torso. This is your starting position....',
    nameDe: 'Vorgebeugt Langhantel Rudern',
    descriptionDe: 'Holding a Langhantel with a Proniert grip (palms facing down), bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the Rücken straight until it is almost parallel to the Boden. Tip: Make sure that you keep the Kopf up. The Langhantel should hang directly in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Bent Over Dumbbell Rear Delt Raise With Head On Bench',
    description: 'Stand up straight while holding a dumbbell in each hand and with an incline bench in front of you. While keeping your back straight and maintaining the natural arch of your back, lean forward until your forehead touches the bench in front of you. Let the arms hang in front of you perpendicular to the ground. The palms of your hands should be facing each other and your torso should be parallel to...',
    nameDe: 'Vorgebeugt Kurzhantel Rear Delt Heben With Kopf On Bank',
    descriptionDe: 'Stand up straight while holding a Kurzhantel in each hand and with an Schrägbank Bank in front of you. While keeping your Rücken straight and maintaining the natural arch of your Rücken, lean forward until your forehead touches the Bank in front of you. Let the arms hang in front of you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Bent Over Low-Pulley Side Lateral',
    description: 'Select a weight and hold the handle of the low pulley with your right hand. Bend at the waist until your torso is nearly parallel to the floor. Your legs should be slightly bent with your left hand placed on your lower left thigh. Your right arm should be hanging from your shoulder in front of you and with a slight bend at the elbow. This will be your starting position. Raise your right arm,...',
    nameDe: 'Vorgebeugt Low-Pulley Side Seitlich',
    descriptionDe: 'Select a weight and hold the handle of the low pulley with your right hand. Bend at the waist until your torso is nearly parallel to the Boden. Your legs should be slightly bent with your left hand placed on your Unterer left Oberschenkel. Your right arm should be hanging from your Schulter in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Bent Over One-Arm Long Bar Row',
    description: 'Put weight on one of the ends of an Olympic barbell. Make sure that you either place the other end of the barbell in the corner of two walls; or put a heavy object on the ground so the barbell cannot slide backward. Bend forward until your torso is as close to parallel with the floor as you can and keep your knees slightly bent. Now grab the bar with one arm just behind the plates on the side...',
    nameDe: 'Vorgebeugt Einarmig Long Stange Rudern',
    descriptionDe: 'Put weight on one of the ends of an Olympia-Langhantel. Make sure that you either place the other end of the Langhantel in the corner of two walls; or put a heavy object on the ground so the Langhantel cannot slide backward. Bend forward until your torso is as close to parallel with the Boden as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Bent Over Two-Arm Long Bar Row',
    description: 'Put weight on one of the ends of an Olympic barbell. Make sure that you either place the other end of the barbell in the corner of two walls; or put a heavy object on the ground so the barbell cannot slide backward. Bend forward until your torso is as close to parallel with the floor as you can and keep your knees slightly bent. Now grab the bar with both arms just behind the plates on the side...',
    nameDe: 'Vorgebeugt Beidarmig Long Stange Rudern',
    descriptionDe: 'Put weight on one of the ends of an Olympia-Langhantel. Make sure that you either place the other end of the Langhantel in the corner of two walls; or put a heavy object on the ground so the Langhantel cannot slide backward. Bend forward until your torso is as close to parallel with the Boden as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Bent Over Two-Dumbbell Row',
    description: 'With a dumbbell in each hand (palms facing your torso), bend your knees slightly and bring your torso forward by bending at the waist; as you bend make sure to keep your back straight until it is almost parallel to the floor. Tip: Make sure that you keep the head up. The weights should hang directly in front of you as your arms hang perpendicular to the floor and your torso. This is your starting...',
    nameDe: 'Vorgebeugt Two-Kurzhantel Rudern',
    descriptionDe: 'With a Kurzhantel in each hand (palms facing your torso), bend your knees slightly and bring your torso forward by bending at the waist; as you bend make sure to keep your Rücken straight until it is almost parallel to the Boden. Tip: Make sure that you keep the Kopf up. The weights should hang...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Bent Over Two-Dumbbell Row With Palms In',
    description: 'With a dumbbell in each hand (palms facing each other), bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the back straight until it is almost parallel to the floor. Tip: Make sure that you keep the head up. The weights should hang directly in front of you as your arms hang perpendicular to the floor and your torso. This is your starting position. While...',
    nameDe: 'Vorgebeugt Two-Kurzhantel Rudern With Palms In',
    descriptionDe: 'With a Kurzhantel in each hand (palms facing each other), bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the Rücken straight until it is almost parallel to the Boden. Tip: Make sure that you keep the Kopf up. The weights should hang directly in front...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Bent Press',
    description: 'Clean a kettlebell to your shoulder. Clean the kettlebell to your shoulders by extending through the legs and hips as you raise the kettlebell towards your shoulder. The wrist should rotate as you do so. This will be your starting position. Begin my leaning to the side opposite the kettlebell, continuing until you are able to touch the ground with your free hand, keeping your eyes on the...',
    nameDe: 'Bent Drücken',
    descriptionDe: 'Stoßen a Kettlebell to your Schulter. Stoßen the Kettlebell to your Schultern by extending through the legs and Hüften as you Heben the Kettlebell towards your Schulter. The Handgelenk should rotate as you do so. This will be your starting position. Begin my leaning to the side opposite the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Body-Up',
    description: 'Assume a plank position on the ground. You should be supporting your bodyweight on your toes and forearms, keeping your torso straight. Your forearms should be shoulder-width apart. This will be your starting position. Pressing your palms firmly into the ground, extend through the elbows to raise your body from the ground. Keep your torso rigid as you perform the movement. Slowly lower your...',
    nameDe: 'Body-Up',
    descriptionDe: 'Assume a Planke position on the ground. You should be supporting your Körpergewicht on your toes and Unterarme, keeping your torso straight. Your Unterarme should be Schulter-width apart. This will be your starting position. Pressing your palms firmly into the ground, extend through the elbows to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Body Tricep Press',
    description: 'Position a bar in a rack at chest height. Standing, take a shoulder width grip on the bar and step a yard or two back, feet together and arms extended so that you are leaning on the bar. This will be your starting position. Begin by flexing the elbow, lowering yourself towards the bar. Pause, and then reverse the motion by extending the elbows. Progress from bodyweight by adding chains over your...',
    nameDe: 'Körpergewicht-Trizepsdrücken',
    descriptionDe: 'Position a Stange in a Ständer at Brust height. Stehend, take a Schulter width grip on the Stange and Stufe a yard or two Rücken, feet together and arms extended so that you are leaning on the Stange. This will be your starting position. Begin by flexing the elbow, lowering yourself towards the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Bodyweight Flyes',
    description: 'Position two equally loaded EZ bars on the ground next to each other. Ensure they are able to roll. Assume a push-up position over the bars, supporting your weight on your toes and hands with your arms extended and body straight. Place your hands on the bars. This will be your starting position. Using a slow and controlled motion, move your hands away from the midline of your body, rolling the...',
    nameDe: 'Körpergewicht Flyes',
    descriptionDe: 'Position two equally loaded EZ bars on the ground next to each other. Ensure they are able to roll. Assume a Liegestütz position over the bars, supporting your weight on your toes and hands with your arms extended and body straight. Place your hands on the bars. This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Bodyweight Mid Row',
    description: 'Begin by taking a medium to wide grip on a pull-up apparatus with your palms facing away from you. From a hanging position, tuck your knees to your chest, leaning back and getting your legs over your side of the pull-up apparatus. This will be your starting position. Beginning with your arms straight, flex the elbows and retract the shoulder blades to raise your body up until your legs contact...',
    nameDe: 'Körpergewicht Mid Rudern',
    descriptionDe: 'Begin by taking a medium to Weiter Griff on a Klimmzug apparatus with your palms facing away from you. From a hanging position, tuck your knees to your Brust, leaning Rücken and getting your legs over your side of the Klimmzug apparatus. This will be your starting position. Beginning with your arms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Bodyweight Squat',
    description: 'Stand with your feet shoulder width apart. You can place your hands behind your head. This will be your starting position. Begin the movement by flexing your knees and hips, sitting back with your hips. Continue down to full depth if you are able,and quickly reverse the motion until you return to the starting position. As you squat, keep your head and chest up and push your knees out.',
    nameDe: 'Körpergewicht-Kniebeuge',
    descriptionDe: 'Stand with your feet Schulter width apart. You can place your hands behind your Kopf. This will be your starting position. Begin the movement by flexing your knees and Hüften, sitting Rücken with your Hüften. Continue down to Komplett depth if you are able,and quickly Umgekehrt the motion until you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Bodyweight Walking Lunge',
    description: 'Begin standing with your feet shoulder width apart and your hands on your hips. Step forward with one leg, flexing the knees to drop your hips. Descend until your rear knee nearly touches the ground. Your posture should remain upright, and your front knee should stay above the front foot. Drive through the heel of your lead foot and extend both knees to raise yourself back up. Step forward with...',
    nameDe: 'Körpergewicht Walking Ausfallschritt',
    descriptionDe: 'Begin Stehend with your feet Schulter width apart and your hands on your Hüften. Stufe forward with one leg, flexing the knees to drop your Hüften. Descend until your rear Knie nearly touches the ground. Your posture should remain Aufrecht, and your front Knie should stay above the front foot....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Bosu Ball Cable Crunch With Side Bends',
    description: 'Connect a standard handle to each arm of a cable machine, and position them in the most downward position. Grab a Bosu Ball and position it in front and center of the cable machine. Lie down on the Bosu Ball with the small of your back arched around the ball. Your rear end should be close to the floor without touching it. With both hands, reach back and grab the handle of each cable. With your...',
    nameDe: 'Bosu-Ball Kabelzug Crunch With Side Bends',
    descriptionDe: 'Connect a standard handle to each arm of a Kabelzug-Maschine, and position them in the most downward position. Grab a Bosu-Ball and position it in front and center of the Kabelzug-Maschine. Lie down on the Bosu-Ball with the small of your Rücken arched around the Ball. Your rear end should be close...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Bottoms-Up Clean From The Hang Position',
    description: 'Initiate the exercise by standing upright with a kettlebell in one hand. Swing the kettlebell back forcefully and then reverse the motion forcefully. Crush the kettlebell handle as hard as possible and raise the kettlebell to your shoulder.',
    nameDe: 'Bottoms-Up Stoßen aus der Hängeposition',
    descriptionDe: 'Initiate the exercise by Stehend Aufrecht with a Kettlebell in one hand. Schwingen the Kettlebell Rücken forcefully and then Umgekehrt the motion forcefully. Crush the Kettlebell handle as hard as possible and Heben the Kettlebell to your Schulter.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Bottoms Up',
    description: 'Begin by lying on your back on the ground. Your legs should be straight and your arms at your side. This will be your starting position. To perform the movement, tuck the knees toward your chest by flexing the hips and knees. Following this, extend your legs directly above you so that they are perpendicular to the ground. Rotate and elevate your pelvis to raise your glutes from the floor. After a...',
    nameDe: 'Bottoms Up',
    descriptionDe: 'Begin by Liegend on your Rücken on the ground. Your legs should be straight and your arms at your side. This will be your starting position. To perform the movement, tuck the knees toward your Brust by flexing the Hüften and knees. Following this, extend your legs directly above you so that they...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Box Squat with Chains',
    description: 'Begin in a power rack with a box at the appropriate height behind you. Typically, you would aim for a box height that brings you to a parallel squat, but you can train higher or lower if desired. To set up the chains, begin by looping the leader chain over the sleeves of the bar. The heavy chain should be attached using a snap hook. Adjust the length of the lead chain so that a few links are...',
    nameDe: 'Box Kniebeuge with Ketten',
    descriptionDe: 'Begin in a power Ständer with a Box at the appropriate height behind you. Typically, you would aim for a Box height that brings you to a parallel Kniebeuge, but you can train higher or Unterer if desired. To set up the Ketten, begin by looping the leader chain over the sleeves of the Stange. The...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Bradford/Rocky Presses',
    description: 'Sit on a Military Press Bench with a bar at shoulder level with a pronated grip (palms facing forward). Tip: Your grip should be wider than shoulder width and it should create a 90-degree angle between the forearm and the upper arm as the barbell goes down. This is your starting position. Once you pick up the barbell with the correct grip, lift the bar up over your head by locking your arms. Now...',
    nameDe: 'Bradford/Rocky Presses',
    descriptionDe: 'Sit on a Military Drücken Bank with a Stange at Schulter level with a Proniert grip (palms facing forward). Tip: Your grip should be wider than Schulter width and it should create a 90-degree angle between the Unterarm and the Oberer arm as the Langhantel goes down. This is your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Butt-Ups',
    description: 'Begin a pushup position but with your elbows on the ground and resting on your forearms. Your arms should be bent at a 90 degree angle. Arch your back slightly out rather than keeping your back completely straight. Raise your glutes toward the ceiling, squeezing your abs tightly to close the distance between your ribcage and hips. The end result will be that you\'ll end up in a high bridge...',
    nameDe: 'Butt-Ups',
    descriptionDe: 'Begin a Liegestütz position but with your elbows on the ground and resting on your Unterarme. Your arms should be bent at a 90 degree angle. Arch your Rücken slightly out rather than keeping your Rücken completely straight. Heben your Gesäß toward the ceiling, squeezing your Bauch tightly to close...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Butt Lift (Bridge)',
    description: 'Lie flat on the floor on your back with the hands by your side and your knees bent. Your feet should be placed around shoulder width. This will be your starting position. Pushing mainly with your heels, lift your hips off the floor while keeping your back straight. Breathe out as you perform this part of the motion and hold at the top for a second. Slowly go back to the starting position as you...',
    nameDe: 'Butt Lift (Brücke)',
    descriptionDe: 'Lie Flachbank on the Boden on your Rücken with the hands by your side and your knees bent. Your feet should be placed around Schulter width. This will be your starting position. Pushing mainly with your heels, lift your Hüften off the Boden while keeping your Rücken straight. Breathe out as you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Butterfly',
    description: 'Sit on the machine with your back flat on the pad. Take hold of the handles. Tip: Your upper arms should be positioned parallel to the floor; adjust the machine accordingly. This will be your starting position. Push the handles together slowly as you squeeze your chest in the middle. Breathe out during this part of the motion and hold the contraction for a second. Return back to the starting...',
    nameDe: 'Schmetterling',
    descriptionDe: 'Sit on the Maschine with your Rücken Flachbank on the pad. Take hold of the handles. Tip: Your Oberer arms should be positioned parallel to the Boden; adjust the Maschine accordingly. This will be your starting position. Push the handles together slowly as you squeeze your Brust in the middle....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Cable Chest Press',
    description: 'Adjust the weight to an appropriate amount and be seated, grasping the handles. Your upper arms should be about 45 degrees to the body, with your head and chest up. The elbows should be bent to about 90 degrees. This will be your starting position. Begin by extending through the elbow, pressing the handles together straight in front of you. Keep your shoulder blades retracted as you execute the...',
    nameDe: 'Kabelzug Brustdrücken',
    descriptionDe: 'Adjust the weight to an appropriate amount and be Sitzend, grasping the handles. Your Oberer arms should be about 45 degrees to the body, with your Kopf and Brust up. The elbows should be bent to about 90 degrees. This will be your starting position. Begin by extending through the elbow, pressing...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Cable Crossover',
    description: 'To get yourself into the starting position, place the pulleys on a high position (above your head), select the resistance to be used and hold the pulleys in each hand. Step forward in front of an imaginary straight line between both pulleys while pulling your arms together in front of you. Your torso should have a small forward bend from the waist. This will be your starting position. With a...',
    nameDe: 'Kabelzugkreuzung',
    descriptionDe: 'To get yourself into the starting position, place the pulleys on a high position (above your Kopf), select the resistance to be used and hold the pulleys in each hand. Stufe forward in front of an imaginary straight line between both pulleys while pulling your arms together in front of you. Your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Cable Crunch',
    description: 'Kneel below a high pulley that contains a rope attachment. Grasp cable rope attachment and lower the rope until your hands are placed next to your face. Flex your hips slightly and allow the weight to hyperextend the lower back. This will be your starting position. With the hips stationary, flex the waist as you contract the abs so that the elbows travel towards the middle of the thighs. Exhale...',
    nameDe: 'Kabelzug-Crunch',
    descriptionDe: 'Kneel below a high pulley that contains a Seil attachment. Grasp Kabelzug Seil attachment and Unterer the Seil until your hands are placed next to your face. Flex your Hüften slightly and allow the weight to hyperextend the Unterer Rücken. This will be your starting position. With the Hüften...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Cable Deadlifts',
    description: 'Move the cables to the bottom of the towers and select an appropriate weight. Stand directly in between the uprights. To begin, squat down be flexing your hips and knees until you can reach the handles. After grasping them, begin your ascent. Driving through your heels extend your hips and knees keeping your hands hanging at your side. Keep your head and chest up throughout the movement. After...',
    nameDe: 'Kabelzug Deadlifts',
    descriptionDe: 'Move the cables to the bottom of the towers and select an appropriate weight. Stand directly in between the uprights. To begin, Kniebeuge down be flexing your Hüften and knees until you can reach the handles. After grasping them, begin your ascent. Driving through your heels extend your Hüften and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Cable Hammer Curls - Rope Attachment',
    description: 'Attach a rope attachment to a low pulley and stand facing the machine about 12 inches away from it. Grasp the rope with a neutral (palms-in) grip and stand straight up keeping the natural arch of the back and your torso stationary. Put your elbows in by your side and keep them there stationary during the entire movement. Tip: Only the forearms should move; not your upper arms. This will be your...',
    nameDe: 'Kabelzug Hammer Curls - Seil Attachment',
    descriptionDe: 'Attach a Seil attachment to a low pulley and stand facing the Maschine about 12 inches away from it. Grasp the Seil with a neutral (palms-in) grip and stand straight up keeping the natural arch of the Rücken and your torso stationary. Put your elbows in by your side and keep them there stationary...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Cable Hip Adduction',
    description: 'Stand in front of a low pulley facing forward with one leg next to the pulley and the other one away. Attach the ankle cuff to the cable and also to the ankle of the leg that is next to the pulley. Now step out and away from the stack with a wide stance and grasp the bar of the pulley system. Stand on the foot that does not have the ankle cuff (the far foot) and allow the leg with the cuff to be...',
    nameDe: 'Kabelzug-Hüftadduktion',
    descriptionDe: 'Stand in front of a low pulley facing forward with one leg next to the pulley and the other one away. Attach the Knöchel cuff to the Kabelzug and also to the Knöchel of the leg that is next to the pulley. Now Stufe out and away from the stack with a wide stance and grasp the Stange of the pulley...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Cable Incline Pushdown',
    description: 'Lie on incline an bench facing away from a high pulley machine that has a straight bar attachment on it. Grasp the straight bar attachment overhead with a pronated (overhand; palms down) shoulder width grip and extend your arms in front of you. The bar should be around 2 inches away from your upper thighs. This will be your starting position. Keeping the upper arms stationary, lift your arms back...',
    nameDe: 'Kabelzug Schrägbank Pushdown',
    descriptionDe: 'Lie on Schrägbank an Bank facing away from a high pulley Maschine that has a straight Stange attachment on it. Grasp the straight Stange attachment Überkopf with a Proniert (Obergriff; palms down) Schulter width grip and extend your arms in front of you. The Stange should be around 2 inches away...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Cable Incline Triceps Extension',
    description: 'Lie on incline an bench facing away from a high pulley machine that has a straight bar attachment on it. Grasp the straight bar attachment overhead with a pronated (overhand; palms down) narrow grip (less than shoulder width) and keep your elbows tucked in to your sides. Your upper arms should create around a 25 degree angle when measured from the floor. Keeping the upper arms stationary, extend...',
    nameDe: 'Kabelzug Schrägbank Trizepsstreckung',
    descriptionDe: 'Lie on Schrägbank an Bank facing away from a high pulley Maschine that has a straight Stange attachment on it. Grasp the straight Stange attachment Überkopf with a Proniert (Obergriff; palms down) Enger Griff (less than Schulter width) and keep your elbows tucked in to your sides. Your Oberer arms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Cable Internal Rotation',
    description: 'Sit next to a low pulley sideways (with legs stretched in front of you or crossed) and grasp the single hand cable attachment with the arm nearest to the cable. Tip: If you can adjust the pulley\'s height, you can use a flat bench to sit on instead. Position the elbow against your side with the elbow bent at 90° and the arm pointing towards the pulley. This will be your starting position. Pull the...',
    nameDe: 'Kabelzug Internal Rotation',
    descriptionDe: 'Sit next to a low pulley sideways (with legs stretched in front of you or crossed) and grasp the single hand Kabelzug attachment with the arm nearest to the Kabelzug. Tip: If you can adjust the pulley\'s height, you can use a Flachbank Bank to sit on instead. Position the elbow against your side...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Cable Iron Cross',
    description: 'Begin by moving the pulleys to the high position, select the resistance to be used, and take a handle in each hand. Stand directly between both pulleys with your arms extended out to your sides. Your head and chest should be up while your arms form a "T". This will be your starting position. Keeping the elbows extended, pull your arms straight to your sides. Return your arms back to the starting...',
    nameDe: 'Kabelzug Iron Überkreuz',
    descriptionDe: 'Begin by moving the pulleys to the high position, select the resistance to be used, and take a handle in each hand. Stand directly between both pulleys with your arms extended out to your sides. Your Kopf and Brust should be up while your arms form a "T". This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Cable Judo Flip',
    description: 'Connect a rope attachment to a tower, and move the cable to the lowest pulley position. Stand with your side to the cable with a wide stance, and grab the rope with both hands. Twist your body away from the pulley as you bring the rope over your shoulder like you\'re performing a judo flip. Shift your weight between your feet as you twist and crunch forward, pulling the cable downward. Return to...',
    nameDe: 'Kabelzug Judo Umwerfen',
    descriptionDe: 'Connect a Seil attachment to a tower, and move the Kabelzug to the lowest pulley position. Stand with your side to the Kabelzug with a wide stance, and grab the Seil with both hands. Twist your body away from the pulley as you bring the Seil over your Schulter like you\'re performing a judo...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Cable Lying Triceps Extension',
    description: 'Lie on a flat bench and grasp the straight bar attachment of a low pulley with a narrow overhand grip. Tip: The easiest way to do this is to have someone hand you the bar as you lay down. With your arms extended, position the bar over your torso. Your arms and your torso should create a 90-degree angle. This will be your starting position. Lower the bar by bending at the elbow while keeping the...',
    nameDe: 'Kabelzug-Trizepsstreckung liegend',
    descriptionDe: 'Lie on a Flachbank Bank and grasp the straight Stange attachment of a low pulley with a narrow Obergriff grip. Tip: The easiest way to do this is to have someone hand you the Stange as you lay down. With your arms extended, position the Stange over your torso. Your arms and your torso should create...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Cable One Arm Tricep Extension',
    description: 'With your right hand, grasp a single handle attached to the high-cable pulley using a supinated (underhand; palms facing up) grip. You should be standing directly in front of the weight stack. Now pull the handle down so that your upper arm and elbow are locked in to the side of your body. Your upper arm and forearm should form an acute angle (less than 90-degrees). You can keep the other arm by...',
    nameDe: 'Kabelzug Einarmig Trizepsstreckung',
    descriptionDe: 'With your right hand, grasp a single handle attached to the high-Kabelzug pulley using a Supiniert (Untergriff; palms facing up) grip. You should be Stehend directly in front of the weight stack. Now pull the handle down so that your Oberer arm and elbow are locked in to the side of your body. Your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Cable Preacher Curl',
    description: 'Place a preacher bench about 2 feet in front of a pulley machine. Attach a straight bar to the low pulley. Sit at the preacher bench with your elbow and upper arms firmly on top of the bench pad and have someone hand you the bar from the low pulley. Grab the bar and fully extend your arms on top of the preacher bench pad. This will be your starting position. Now start pilling the weight up...',
    nameDe: 'Kabelzug Preacher-Curl',
    descriptionDe: 'Place a preacher Bank about 2 feet in front of a pulley Maschine. Attach a straight Stange to the low pulley. Sit at the preacher Bank with your elbow and Oberer arms firmly on top of the Bank pad and have someone hand you the Stange from the low pulley. Grab the Stange and fully extend your arms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Cable Rear Delt Fly',
    description: 'Adjust the pulleys to the appropriate height and adjust the weight. The pulleys should be above your head. Grab the left pulley with your right hand and the right pulley with your left hand, crossing them in front of you. This will be your starting position. Initiate the movement by moving your arms back and outward, keeping your arms straight as you execute the movement. Pause at the end of the...',
    nameDe: 'Kabelzug-Deltaheben hinten',
    descriptionDe: 'Adjust the pulleys to the appropriate height and adjust the weight. The pulleys should be above your Kopf. Grab the left pulley with your right hand and the right pulley with your left hand, crossing them in front of you. This will be your starting position. Initiate the movement by moving your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Cable Reverse Crunch',
    description: 'Connect an ankle strap attachment to a low pulley cable and position a mat on the floor in front of it. Sit down with your feet toward the pulley and attach the cable to your ankles. Lie down, elevate your legs and bend your knees at a 90-degree angle. Your legs and the cable should be aligned. If not, adjust the pulley up or down until they are. With your hands behind your head, bring your knees...',
    nameDe: 'Kabelzug Umgekehrt Crunch',
    descriptionDe: 'Connect an Knöchel strap attachment to a low pulley Kabelzug and position a mat on the Boden in front of it. Sit down with your feet toward the pulley and attach the Kabelzug to your ankles. Lie down, elevate your legs and bend your knees at a 90-degree angle. Your legs and the Kabelzug should be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Cable Rope Overhead Triceps Extension',
    description: 'Attach a rope to the bottom pulley of the pulley machine. Grasping the rope with both hands, extend your arms with your hands directly above your head using a neutral grip (palms facing each other). Your elbows should be in close to your head and the arms should be perpendicular to the floor with the knuckles aimed at the ceiling. This will be your starting position. Slowly lower the rope behind...',
    nameDe: 'Kabelzug Seil Überkopf Trizepsstreckung',
    descriptionDe: 'Attach a Seil to the bottom pulley of the pulley Maschine. Grasping the Seil with both hands, extend your arms with your hands directly above your Kopf using a Neutralgriff (palms facing each other). Your elbows should be in close to your Kopf and the arms should be perpendicular to the Boden with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Cable Rope Rear-Delt Rows',
    description: 'Sit in the same position on a low pulley row station as you would if you were doing seated cable rows for the back. Attach a rope to the pulley and grasp it with an overhand grip. Your arms should be extended and parallel to the floor with the elbows flared out. Keep your lower back upright and slide your hips back so that your knees are slightly bent. This will be your starting position. Pull...',
    nameDe: 'Kabelzug-Seil-Rudern hinten',
    descriptionDe: 'Sit in the same position on a low pulley Rudern station as you would if you were doing Sitzend Kabelzug rows for the Rücken. Attach a Seil to the pulley and grasp it with an Obergriff grip. Your arms should be extended and parallel to the Boden with the elbows flared out. Keep your Unterer Rücken...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Cable Russian Twists',
    description: 'Connect a standard handle attachment, and position the cable to a middle pulley position. Lie on a stability ball perpendicular to the cable and grab the handle with one hand. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the cable. Grab the handle with both hands and fully extend your arms above your chest. You hands should be directly in-line...',
    nameDe: 'Kabelzug Russian Twists',
    descriptionDe: 'Connect a standard handle attachment, and position the Kabelzug to a middle pulley position. Lie on a Stabilityball perpendicular to the Kabelzug and grab the handle with one hand. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the Kabelzug. Grab...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Cable Seated Crunch',
    description: 'Seat on a flat bench with your back facing a high pulley. Grasp the cable rope attachment with both hands (with the palms of the hands facing each other) and place your hands securely over both shoulders. Tip: Allow the weight to hyperextend the lower back slightly. This will be your starting position. With the hips stationary, flex the waist so the elbows travel toward the hips. Breathe out as...',
    nameDe: 'Kabelzug Sitzend Crunch',
    descriptionDe: 'Seat on a Flachbank Bank with your Rücken facing a high pulley. Grasp the Kabelzug Seil attachment with both hands (with the palms of the hands facing each other) and place your hands securely over both Schultern. Tip: Allow the weight to hyperextend the Unterer Rücken slightly. This will be your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Cable Seated Lateral Raise',
    description: 'Stand in the middle of two low pulleys that are opposite to each other and place a flat bench right behind you (in perpendicular fashion to you; the narrow edge of the bench should be the one behind you). Select the weight to be used on each pulley. Now sit at the edge of the flat bench behind you with your feet placed in front of your knees. Bend forward while keeping your back flat and rest...',
    nameDe: 'Kabelzug Sitzend Seitlich Heben',
    descriptionDe: 'Stand in the middle of two low pulleys that are opposite to each other and place a Flachbank Bank right behind you (in perpendicular fashion to you; the narrow edge of the Bank should be the one behind you). Select the weight to be used on each pulley. Now sit at the edge of the Flachbank Bank...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Cable Shoulder Press',
    description: 'Move the cables to the bottom of the towers and select an appropriate weight. Stand directly in between the uprights. Grasp the cables and hold them at shoulder height, palms facing forward. This will be your starting position. Keeping your head and chest up, extend through the elbow to press the handles directly over head. After pausing at the top, return to the starting position and repeat.',
    nameDe: 'Kabelzug Schulterdrücken',
    descriptionDe: 'Move the cables to the bottom of the towers and select an appropriate weight. Stand directly in between the uprights. Grasp the cables and hold them at Schulter height, palms facing forward. This will be your starting position. Keeping your Kopf and Brust up, extend through the elbow to Drücken the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Cable Shrugs',
    description: 'Grasp a cable bar attachment that is attached to a low pulley with a shoulder width or slightly wider overhand (palms facing down) grip. Stand erect close to the pulley with your arms extended in front of you holding the bar. This will be your starting position. Lift the bar by elevating the shoulders as high as possible as you exhale. Hold the contraction at the top for a second. Tip: The arms...',
    nameDe: 'Kabelzug Shrugs',
    descriptionDe: 'Grasp a Kabelzug Stange attachment that is attached to a low pulley with a Schulter width or slightly wider Obergriff (palms facing down) grip. Stand erect close to the pulley with your arms extended in front of you holding the Stange. This will be your starting position. Lift the Stange by...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Cable Wrist Curl',
    description: 'Start out by placing a flat bench in front of a low pulley cable that has a straight bar attachment. Use your arms to grab the cable bar with a narrow to shoulder width supinated grip (palms up) and bring them up so that your forearms are resting against the top of your thighs. Your wrists should be hanging just beyond your knees. Start out by curling your wrist upwards and exhaling. Keep the...',
    nameDe: 'Kabelzug-Handgelenk-Curl',
    descriptionDe: 'Start out by placing a Flachbank Bank in front of a low pulley Kabelzug that has a straight Stange attachment. Use your arms to grab the Kabelzug Stange with a narrow to Schulter width Supiniert grip (palms up) and bring them up so that your Unterarme are resting against the top of your thighs....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Calf-Machine Shoulder Shrug',
    description: 'Position yourself on the calf machine so that the shoulder pads are above your shoulders. Your torso should be straight with the arms extended normally by your side. This will be your starting position. Raise your shoulders up towards your ears as you exhale and hold the contraction for a full second. Slowly return to the starting position as you inhale. Repeat for the recommended amount of...',
    nameDe: 'Wade-Maschine Schulter Schulterziehen',
    descriptionDe: 'Position yourself on the Wade Maschine so that the Schulter pads are above your Schultern. Your torso should be straight with the arms extended normally by your side. This will be your starting position. Heben your Schultern up towards your ears as you exhale and hold the contraction for a Komplett...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Calf Press',
    description: 'Adjust the seat so that your legs are only slightly bent in the start position. The balls of your feet should be firmly on the platform. Select an appropriate weight, and grasp the handles. This will be your starting position. Straighten the legs by extending the knees, just barely lifting the weight from the stack. Your ankle should be fully flexed, toes pointing up. Execute the movement by...',
    nameDe: 'Wadendrücken',
    descriptionDe: 'Adjust the seat so that your legs are only slightly bent in the start position. The balls of your feet should be firmly on the platform. Select an appropriate weight, and grasp the handles. This will be your starting position. Straighten the legs by extending the knees, just barely lifting the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Calf Press On The Leg Press Machine',
    description: 'Using a leg press machine, sit down on the machine and place your legs on the platform directly in front of you at a medium (shoulder width) foot stance. Lower the safety bars holding the weighted platform in place and press the platform all the way up until your legs are fully extended in front of you without locking your knees. (Note: In some leg press units you can leave the safety bars on for...',
    nameDe: 'Wadendrücken On The Beinpresse Maschine',
    descriptionDe: 'Using a Beinpresse Maschine, sit down on the Maschine and place your legs on the platform directly in front of you at a medium (Schulter width) foot stance. Unterer the safety bars holding the Gewichtet platform in place and Drücken the platform all the way up until your legs are fully extended in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Calf Raise On A Dumbbell',
    description: 'Hang on to a sturdy object for balance and stand on a dumbbell handle, preferably one with round plates so that it rolls as in this manner you have to work harder to stabilize yourself; thus increasing the effectiveness of the exercise. Now roll your foot slightly forward so that you can get a nice stretch of the calf. This will be your starting position. Lift the calf as you roll your foot over...',
    nameDe: 'Wadenlifte On A Kurzhantel',
    descriptionDe: 'Hang on to a sturdy object for balance and stand on a Kurzhantel handle, preferably one with round plates so that it rolls as in this manner you have to work harder to stabilize yourself; thus increasing the effectiveness of the exercise. Now roll your foot slightly forward so that you can get a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Calf Raises - With Bands',
    description: 'Grab an exercise band and stand on it with your toes making sure that the length of the band between the foot and the arms is the same for both sides. While holding the handles of the band, raise the arms to the side of your head as if you were getting ready to perform a shoulder press. The palms should be facing forward with the elbows bent and to the sides. This movement will create tension on...',
    nameDe: 'Wade Raises - mit Band',
    descriptionDe: 'Grab an exercise Band and stand on it with your toes making sure that the length of the Band between the foot and the arms is the same for both sides. While holding the handles of the Band, Heben the arms to the side of your Kopf as if you were getting ready to perform a Schulterdrücken. The palms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Car Drivers',
    description: 'While standing upright, hold a barbell plate in both hands at the 3 and 9 o\'clock positions. Your palms should be facing each other and your arms should be extended straight out in front of you. This will be your starting position. Initiate the movement by rotating the plate as far to one side as possible. Use the same type of movement you would use to turn a steering wheel to one side. Reverse...',
    nameDe: 'Car Drivers',
    descriptionDe: 'While Stehend Aufrecht, hold a Langhantel Scheibe in both hands at the 3 and 9 o\'clock positions. Your palms should be facing each other and your arms should be extended straight out in front of you. This will be your starting position. Initiate the movement by rotating the Scheibe as far to one...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Chair Squat',
    description: 'To begin, first set the bar to a position that best matches your height. Once the bar is loaded, step under it and position it across the back of your shoulders. Take the bar with your hands facing forward, unlock it and lift it off the rack by extending your legs. Move your feet forward about 18 inches in front of the bar. Position your legs using a shoulder width stance with the toes slightly...',
    nameDe: 'Stuhl Kniebeuge',
    descriptionDe: 'To begin, first set the Stange to a position that best matches your height. Once the Stange is loaded, Stufe under it and position it across the Rücken of your Schultern. Take the Stange with your hands facing forward, unlock it and lift it off the Ständer by extending your legs. Move your feet...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Chin-Up',
    description: 'Grab the pull-up bar with the palms facing your torso and a grip closer than the shoulder width. As you have both arms extended in front of you holding the bar at the chosen grip width, keep your torso as straight as possible while creating a curvature on your lower back and sticking your chest out. This is your starting position. Tip: Keeping the torso as straight as possible maximizes biceps...',
    nameDe: 'Klimmzug (Enger Griff)',
    descriptionDe: 'Grab the Klimmzugstange with the palms facing your torso and a grip closer than the Schulter width. As you have both arms extended in front of you holding the Stange at the chosen grip width, keep your torso as straight as possible while creating a curvature on your Unterer Rücken and sticking your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Clean and Press',
    description: 'Assume a shoulder-width stance, with knees inside the arms. Now while keeping the back flat, bend at the knees and hips so that you can grab the bar with the arms fully extended and a pronated grip that is slightly wider than shoulder width. Point the elbows out to sides. The bar should be close to the shins. Position the shoulders over or slightly ahead of the bar. Establish a flat back posture....',
    nameDe: 'Stoßen und Drücken',
    descriptionDe: 'Assume a Schulter-width stance, with knees inside the arms. Now while keeping the Rücken Flachbank, bend at the knees and Hüften so that you can grab the Stange with the arms fully extended and a Proniert grip that is slightly wider than Schulter width. Point the elbows out to sides. The Stange...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Clock Push-Up',
    description: 'Move into a prone position on the floor, supporting your weight on your hands and toes. Your arms should be fully extended with the hands around shoulder width. Keep your body straight throughout the movement. This will be your starting position. Descend by flexing at the elbow, lowering your chest toward the ground. At the bottom, reverse the motion by pushing yourself up through elbow extension...',
    nameDe: 'Clock Liegestütz',
    descriptionDe: 'Move into a Bauchlage position on the Boden, supporting your weight on your hands and toes. Your arms should be fully extended with the hands around Schulter width. Keep your body straight throughout the movement. This will be your starting position. Descend by flexing at the elbow, lowering your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Close-Grip Barbell Bench Press',
    description: 'Lie back on a flat bench. Using a close grip (around shoulder width), lift the bar from the rack and hold it straight over you with your arms locked. This will be your starting position. As you breathe in, come down slowly until you feel the bar on your middle chest. Tip: Make sure that - as opposed to a regular bench press - you keep the elbows close to the torso at all times in order to...',
    nameDe: 'Langhantel-Bankdrücken eng',
    descriptionDe: 'Lie Rücken on a Flachbank Bank. Using a Enger Griff (around Schulter width), lift the Stange from the Ständer and hold it straight over you with your arms locked. This will be your starting position. As you breathe in, come down slowly until you feel the Stange on your middle Brust. Tip: Make sure...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Close-Grip Dumbbell Press',
    description: 'Place a dumbbell standing up on a flat bench. Ensuring that the dumbbell stays securely placed at the top of the bench, lie perpendicular to the bench with only your shoulders lying on the surface. Hips should be below the bench and your legs bent with your feet firmly on the floor. Grasp the dumbbell with both hands and hold it straight over your chest at arm\'s length. Both palms should be...',
    nameDe: 'Enger Griff Kurzhantel Drücken',
    descriptionDe: 'Place a Kurzhantel Stehend up on a Flachbank Bank. Ensuring that the Kurzhantel stays securely placed at the top of the Bank, lie perpendicular to the Bank with only your Schultern Liegend on the surface. Hüften should be below the Bank and your legs bent with your feet firmly on the Boden. Grasp...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Close-Grip EZ-Bar Curl with Band',
    description: 'Attach a band to each end of the bar. Take the bar, placing a foot on the middle of the band. Stand upright with a narrow, supinated grip on the EZ bar. The elbows should be close to the torso. This will be your starting position. While keeping the upper arms in place, flex the elbows to execute the curl. Exhale as the weight is lifted. Continue the movement until your biceps are fully contracted...',
    nameDe: 'Enger Griff EZ-Stange Curl mit Band',
    descriptionDe: 'Attach a Band to each end of the Stange. Take the Stange, placing a foot on the middle of the Band. Stand Aufrecht with a narrow, Supiniert grip on the EZ-Stange. The elbows should be close to the torso. This will be your starting position. While keeping the Oberer arms in place, flex the elbows to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Close-Grip EZ-Bar Press',
    description: 'Lie on a flat bench with an EZ bar loaded to an appropriate weight. Using a narrow grip lift the bar and hold it straight over your torso with your elbows in. The arms should be perpendicular to the floor. This will be your starting position. Now lower the bar down to your lower chest as you breathe in. Keep the elbows in as you perform this movement. Using the triceps to push the bar back up,...',
    nameDe: 'EZ-Stange Drücken eng',
    descriptionDe: 'Lie on a Flachbank Bank with an EZ-Stange loaded to an appropriate weight. Using a Enger Griff lift the Stange and hold it straight over your torso with your elbows in. The arms should be perpendicular to the Boden. This will be your starting position. Now Unterer the Stange down to your Unterer...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Close-Grip EZ Bar Curl',
    description: 'Stand up with your torso upright while holding an E-Z Curl Bar at the closer inner handle. The palm of your hands should be facing forward and they should be slightly tilted inwards due to the shape of the bar. The elbows should be close to the torso. This will be your starting position. While holding the upper arms stationary, curl the weights forward while contracting the biceps as you breathe...',
    nameDe: 'Enger Griff EZ-Stange Curl',
    descriptionDe: 'Stand up with your torso Aufrecht while holding an E-Z Curl Stange at the closer Innen handle. The palm of your hands should be facing forward and they should be slightly tilted inwards due to the shape of the Stange. The elbows should be close to the torso. This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Close-Grip Front Lat Pulldown',
    description: 'Sit down on a pull-down machine with a wide bar attached to the top pulley. Make sure that you adjust the knee pad of the machine to fit your height. These pads will prevent your body from being raised by the resistance attached to the bar. Grab the bar with the palms facing forward using the prescribed grip. Note on grips: For a wide grip, your hands need to be spaced out at a distance wider...',
    nameDe: 'Latzug eng vorne',
    descriptionDe: 'Sit down on a Latzug Maschine with a wide Stange attached to the top pulley. Make sure that you adjust the Knie pad of the Maschine to fit your height. These pads will prevent your body from being raised by the resistance attached to the Stange. Grab the Stange with the palms facing forward using...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Close-Grip Push-Up off of a Dumbbell',
    description: 'Lie on the floor and place your hands on an upright dumbbell. Supporting your weight on your toes and hands, keep your torso rigid and your elbows in with your arms straight. This will be your starting position. Lower your body, allowing the elbows to flex while you inhale. Keep your body straight, not allowing your hips to rise or sag. Press yourself back up to the starting position by extending...',
    nameDe: 'Enger Griff Liegestütz off of a Kurzhantel',
    descriptionDe: 'Lie on the Boden and place your hands on an Aufrecht Kurzhantel. Supporting your weight on your toes and hands, keep your torso rigid and your elbows in with your arms straight. This will be your starting position. Unterer your body, allowing the elbows to flex while you inhale. Keep your body...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Close-Grip Standing Barbell Curl',
    description: 'Hold a barbell with both hands, palms up and a few inches apart. Stand with your torso straight and your head up. Your feet should be about shoulder width and your elbows close to your torso. This will be your starting position. Tip: You will keep your upper arms and elbows stationary throughout the movement. Curl the bar up in a semicircular motion until the forearms touch your biceps. Exhale as...',
    nameDe: 'Enger Griff Stehend Langhantel Curl',
    descriptionDe: 'Hold a Langhantel with both hands, palms up and a few inches apart. Stand with your torso straight and your Kopf up. Your feet should be about Schulter width and your elbows close to your torso. This will be your starting position. Tip: You will keep your Oberer arms and elbows stationary...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Cocoons',
    description: 'Begin by lying on your back on the ground. Your legs should be straight and your arms extended behind your head. This will be your starting position. To perform the movement, tuck the knees toward your chest, rotating your pelvis to lift your glutes from the floor. As you do so, flex the spine, bringing your arms back over your head to perform a simultaneous crunch motion. After a brief pause,...',
    nameDe: 'Cocoons',
    descriptionDe: 'Begin by Liegend on your Rücken on the ground. Your legs should be straight and your arms extended behind your Kopf. This will be your starting position. To perform the movement, tuck the knees toward your Brust, rotating your pelvis to lift your Gesäß from the Boden. As you do so, flex the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Concentration Curls',
    description: 'Sit down on a flat bench with one dumbbell in front of you between your legs. Your legs should be spread with your knees bent and feet on the floor. Use your right arm to pick the dumbbell up. Place the back of your right upper arm on the top of your inner right thigh. Rotate the palm of your hand until it is facing forward away from your thigh. Tip: Your arm should be extended and the dumbbell...',
    nameDe: 'Concentration Curls',
    descriptionDe: 'Sit down on a Flachbank Bank with one Kurzhantel in front of you between your legs. Your legs should be spread with your knees bent and feet on the Boden. Use your right arm to pick the Kurzhantel up. Place the Rücken of your right Oberer arm on the top of your Innen right Oberschenkel. Rotate the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Cross-Body Crunch',
    description: 'Lie flat on your back and bend your knees about 60 degrees. Keep your feet flat on the floor and place your hands loosely behind your head. This will be your starting position. Now curl up and bring your right elbow and shoulder across your body while bring your left knee in toward your left shoulder at the same time. Reach with your elbow and try to touch your knee. Exhale as you perform this...',
    nameDe: 'Überkreuz-Body Crunch',
    descriptionDe: 'Lie Flachbank on your Rücken and bend your knees about 60 degrees. Keep your feet Flachbank on the Boden and place your hands loosely behind your Kopf. This will be your starting position. Now Curl up and bring your right elbow and Schulter across your body while bring your left Knie in toward your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Cross Body Hammer Curl',
    description: 'Stand up straight with a dumbbell in each hand. Your hands should be down at your side with your palms facing in. While keeping your palms facing in and without twisting your arm, curl the dumbbell of the right arm up towards your left shoulder as you exhale. Touch the top of the dumbbell to your shoulder and hold the contraction for a second. Slowly lower the dumbbell along the same path as you...',
    nameDe: 'Überkreuz Body Hammer-Curl',
    descriptionDe: 'Stand up straight with a Kurzhantel in each hand. Your hands should be down at your side with your palms facing in. While keeping your palms facing in and without twisting your arm, Curl the Kurzhantel of the right arm up towards your left Schulter as you exhale. Touch the top of the Kurzhantel to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Cross Over - With Bands',
    description: 'Secure an exercise band around a stationary post. While facing away from the post, grab the handles on both ends of the band and step forward enough to create tension on the band. Raise your arms to the sides, parallel to the floor, perpendicular to your torso (your torso and the arms should resemble the letter "T") and with the palms facing forward. Have them extended with a slight bend at the...',
    nameDe: 'Überkreuz Over - mit Band',
    descriptionDe: 'Secure an exercise Band around a stationary post. While facing away from the post, grab the handles on both ends of the Band and Stufe forward enough to create tension on the Band. Heben your arms to the sides, parallel to the Boden, perpendicular to your torso (your torso and the arms should...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Crunch - Hands Overhead',
    description: 'Lie on the floor with your back flat and knees bent with around a 60-degree angle between the hamstrings and the calves. Keep your feet flat on the floor and stretch your arms overhead with your palms crossed. This will be your starting position. Curl your upper body forward and bring your shoulder blades just off the floor. At all times, keep your arms aligned with your head, neck and shoulder....',
    nameDe: 'Crunch - Hands Überkopf',
    descriptionDe: 'Lie on the Boden with your Rücken Flachbank and knees bent with around a 60-degree angle between the Oberschenkelrückseite and the Waden. Keep your feet Flachbank on the Boden and Dehnung your arms Überkopf with your palms crossed. This will be your starting position. Curl your Oberer body forward...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Crunch - Legs On Exercise Ball',
    description: 'Lie flat on your back with your feet resting on an exercise ball and your knees bent at a 90 degree angle. Place your feet three to four inches apart and point your toes inward so they touch. Place your hands lightly on either side of your head keeping your elbows in. Tip: Don\'t lock your fingers behind your head. Push the small of your back down in the floor in order to better isolate your...',
    nameDe: 'Crunch - Legs On Trainingsball',
    descriptionDe: 'Lie Flachbank on your Rücken with your feet resting on an Trainingsball and your knees bent at a 90 degree angle. Place your feet three to four inches apart and point your toes inward so they touch. Place your hands lightly on either side of your Kopf keeping your elbows in. Tip: Don\'t lock your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Crunches',
    description: 'Lie flat on your back with your feet flat on the ground, or resting on a bench with your knees bent at a 90 degree angle. If you are resting your feet on a bench, place them three to four inches apart and point your toes inward so they touch. Now place your hands lightly on either side of your head keeping your elbows in. Tip: Don\'t lock your fingers behind your head. While pushing the small of...',
    nameDe: 'Crunches',
    descriptionDe: 'Lie Flachbank on your Rücken with your feet Flachbank on the ground, or resting on a Bank with your knees bent at a 90 degree angle. If you are resting your feet on a Bank, place them three to four inches apart and point your toes inward so they touch. Now place your hands lightly on either side of...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Cuban Press',
    description: 'Take a dumbbell in each hand with a pronated grip in a standing position. Raise your upper arms so that they are parallel to the floor, allowing your lower arms to hang in the "scarecrow" position. This will be your starting position. To initiate the movement, externally rotate the shoulders to move the upper arm 180 degrees. Keep the upper arms in place, rotating the upper arms until the wrists...',
    nameDe: 'Cuban Drücken',
    descriptionDe: 'Take a Kurzhantel in each hand with a Proniert grip in a Stehend position. Heben your Oberer arms so that they are parallel to the Boden, allowing your Unterer arms to hang in the "scarecrow" position. This will be your starting position. To initiate the movement, externally rotate the Schultern to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dead Bug',
    description: 'Begin lying on your back with your hands extended above you toward the ceiling. Bring your feet, knees, and hips up to 90 degrees. Exhale hard to bring your ribcage down and flatten your back onto the floor, rotating your pelvis up and squeezing your glutes. Hold this position throughout the movement. This will be your starting position. Initiate the exercise by extending one leg, straightening...',
    nameDe: 'Dead Bug',
    descriptionDe: 'Begin Liegend on your Rücken with your hands extended above you toward the ceiling. Bring your feet, knees, and Hüften up to 90 degrees. Exhale hard to bring your ribcage down and flatten your Rücken onto the Boden, rotating your pelvis up and squeezing your Gesäß. Hold this position throughout the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Decline Barbell Bench Press',
    description: 'Secure your legs at the end of the decline bench and slowly lay down on the bench. Using a medium width grip (a grip that creates a 90-degree angle in the middle of the movement between the forearms and the upper arms), lift the bar from the rack and hold it straight over you with your arms locked. The arms should be perpendicular to the floor. This will be your starting position. Tip: In order...',
    nameDe: 'Negativbank Langhantel-Bankdrücken',
    descriptionDe: 'Secure your legs at the end of the Negativbank Bank and slowly lay down on the Bank. Using a medium width grip (a grip that creates a 90-degree angle in the middle of the movement between the Unterarme and the Oberer arms), lift the Stange from the Ständer and hold it straight over you with your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Decline Close-Grip Bench To Skull Crusher',
    description: 'Secure your legs at the end of the decline bench and slowly lay down on the bench. Using a close grip (a grip that is slightly less than shoulder width), lift the bar from the rack and hold it straight over you with your arms locked and elbows in. The arms should be perpendicular to the floor. This will be your starting position. Tip: In order to protect your rotator cuff, it is best if you have...',
    nameDe: 'Negativbank Enger Griff Bank To Stirndrücken',
    descriptionDe: 'Secure your legs at the end of the Negativbank Bank and slowly lay down on the Bank. Using a Enger Griff (a grip that is slightly less than Schulter width), lift the Stange from the Ständer and hold it straight over you with your arms locked and elbows in. The arms should be perpendicular to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Decline Crunch',
    description: 'Secure your legs at the end of the decline bench and lie down. Now place your hands lightly on either side of your head keeping your elbows in. Tip: Don\'t lock your fingers behind your head. While pushing the small of your back down in the bench to better isolate your abdominal muscles, begin to roll your shoulders off it. Continue to push down as hard as you can with your lower back as you...',
    nameDe: 'Negative Crunches',
    descriptionDe: 'Secure your legs at the end of the Negativbank Bank and lie down. Now place your hands lightly on either side of your Kopf keeping your elbows in. Tip: Don\'t lock your fingers behind your Kopf. While pushing the small of your Rücken down in the Bank to better isolate your Bauch muscles, begin to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Decline Dumbbell Bench Press',
    description: 'Secure your legs at the end of the decline bench and lie down with a dumbbell on each hand on top of your thighs. The palms of your hand will be facing each other. Once you are laying down, move the dumbbells in front of you at shoulder width. Once at shoulder width, rotate your wrists forward so that the palms of your hands are facing away from you. This will be your starting position. Bring...',
    nameDe: 'Negativbank Kurzhantel-Bankdrücken',
    descriptionDe: 'Secure your legs at the end of the Negativbank Bank and lie down with a Kurzhantel on each hand on top of your thighs. The palms of your hand will be facing each other. Once you are laying down, move the Kurzhanteln in front of you at Schulter width. Once at Schulter width, rotate your wrists...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Decline Dumbbell Flyes',
    description: 'Secure your legs at the end of the decline bench and lie down with a dumbbell on each hand on top of your thighs. The palms of your hand will be facing each other. Once you are laying down, move the dumbbells in front of you at shoulder width. The palms of the hands should be facing each other and the arms should be perpendicular to the floor and fully extended. This will be your starting...',
    nameDe: 'Negativbank Kurzhantel Flyes',
    descriptionDe: 'Secure your legs at the end of the Negativbank Bank and lie down with a Kurzhantel on each hand on top of your thighs. The palms of your hand will be facing each other. Once you are laying down, move the Kurzhanteln in front of you at Schulter width. The palms of the hands should be facing each...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Decline Dumbbell Triceps Extension',
    description: 'Secure your legs at the end of the decline bench and lie down with a dumbbell on each hand on top of your thighs. The palms of your hand will be facing each other. Once you are laying down, move the dumbbells in front of you at shoulder width. The palms of the hands should be facing each other and the arms should be perpendicular to the floor and fully extended. This will be your starting...',
    nameDe: 'Negativbank Kurzhantel Trizepsstreckung',
    descriptionDe: 'Secure your legs at the end of the Negativbank Bank and lie down with a Kurzhantel on each hand on top of your thighs. The palms of your hand will be facing each other. Once you are laying down, move the Kurzhanteln in front of you at Schulter width. The palms of the hands should be facing each...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Decline EZ Bar Triceps Extension',
    description: 'Secure your legs at the end of the decline bench and slowly lay down on the bench. Using a close grip (a grip that is slightly less than shoulder width), lift the EZ bar from the rack and hold it straight over you with your arms locked and elbows in. The arms should be perpendicular to the floor. This will be your starting position. Tip: In order to protect your rotator cuff, it is best if you...',
    nameDe: 'Negativbank EZ-Stange Trizepsstreckung',
    descriptionDe: 'Secure your legs at the end of the Negativbank Bank and slowly lay down on the Bank. Using a Enger Griff (a grip that is slightly less than Schulter width), lift the EZ-Stange from the Ständer and hold it straight over you with your arms locked and elbows in. The arms should be perpendicular to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Decline Oblique Crunch',
    description: 'Secure your legs at the end of the decline bench and slowly lay down on the bench. Raise your upper body off the bench until your torso is about 35-45 degrees if measured from the floor. Put one hand beside your head and the other on your thigh. This will be your starting position. Raise your upper body slowly from the starting position while turning your torso to the left. Continue crunching up...',
    nameDe: 'Negativbank Schräger Bauchmuskel Crunch',
    descriptionDe: 'Secure your legs at the end of the Negativbank Bank and slowly lay down on the Bank. Heben your Oberer body off the Bank until your torso is about 35-45 degrees if measured from the Boden. Put one hand beside your Kopf and the other on your Oberschenkel. This will be your starting position. Heben...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Decline Push-Up',
    description: 'Lie on the floor face down and place your hands about 36 inches apart while holding your torso up at arms length. Move your feet up to a box or bench. This will be your starting position. Next, lower yourself downward until your chest almost touches the floor as you inhale. Now breathe out and press your upper body back up to the starting position while squeezing your chest. After a brief pause...',
    nameDe: 'Negativbank Liegestütz',
    descriptionDe: 'Lie on the Boden face down and place your hands about 36 inches apart while holding your torso up at arms length. Move your feet up to a Box or Bank. This will be your starting position. Next, Unterer yourself downward until your Brust almost touches the Boden as you inhale. Now breathe out and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Decline Reverse Crunch',
    description: 'Lie on your back on a decline bench and hold on to the top of the bench with both hands. Don\'t let your body slip down from this position. Hold your legs parallel to the floor using your abs to hold them there while keeping your knees and feet together. Tip: Your legs should be fully extended with a slight bend on the knee. This will be your starting position. While exhaling, move your legs...',
    nameDe: 'Negativbank Umgekehrt Crunch',
    descriptionDe: 'Lie on your Rücken on a Negativbank Bank and hold on to the top of the Bank with both hands. Don\'t let your body slip down from this position. Hold your legs parallel to the Boden using your Bauch to hold them there while keeping your knees and feet together. Tip: Your legs should be fully extended...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Decline Smith Press',
    description: 'Place a decline bench underneath the Smith machine. Now place the barbell at a height that you can reach when lying down and your arms are almost fully extended. Using a pronated grip that is wider than shoulder width, unlock the bar from the rack and hold it straight over you with your arms extended. This will be your starting position. As you inhale, lower the bar under control by allowing the...',
    nameDe: 'Negativbank Smith Drücken',
    descriptionDe: 'Place a Negativbank Bank underneath the Smith-Maschine. Now place the Langhantel at a height that you can reach when Liegend down and your arms are almost fully extended. Using a Proniert grip that is wider than Schulter width, unlock the Stange from the Ständer and hold it straight over you with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Dip Machine',
    description: 'Sit securely in a dip machine, select the weight and firmly grasp the handles. Now keep your elbows in at your sides in order to place emphasis on the triceps. The elbows should be bent at a 90 degree angle. As you contract the triceps, extend your arms downwards as you exhale. Tip: At the bottom of the movement, focus on keeping a little bend in your arms to keep tension on the triceps muscle....',
    nameDe: 'Dip Maschine',
    descriptionDe: 'Sit securely in a Dip Maschine, select the weight and firmly grasp the handles. Now keep your elbows in at your sides in order to place emphasis on the Trizeps. The elbows should be bent at a 90 degree angle. As you contract the Trizeps, extend your arms downwards as you exhale. Tip: At the bottom...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Dips - Chest Version',
    description: 'For this exercise you will need access to parallel bars. To get yourself into the starting position, hold your body at arms length (arms locked) above the bars. While breathing in, lower yourself slowly with your torso leaning forward around 30 degrees or so and your elbows flared out slightly until you feel a slight stretch in the chest. Once you feel the stretch, use your chest to bring your...',
    nameDe: 'Dips - Brust Version',
    descriptionDe: 'For this exercise you will need access to parallel bars. To get yourself into the starting position, hold your body at arms length (arms locked) above the bars. While breathing in, Unterer yourself slowly with your torso leaning forward around 30 degrees or so and your elbows flared out slightly...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Dips - Triceps Version',
    description: 'To get into the starting position, hold your body at arm\'s length with your arms nearly locked above the bars. Now, inhale and slowly lower yourself downward. Your torso should remain upright and your elbows should stay close to your body. This helps to better focus on tricep involvement. Lower yourself until there is a 90 degree angle formed between the upper arm and forearm. Then, exhale and...',
    nameDe: 'Dips - Trizeps Version',
    descriptionDe: 'To get into the starting position, hold your body at arm\'s length with your arms nearly locked above the bars. Now, inhale and slowly Unterer yourself downward. Your torso should remain Aufrecht and your elbows should stay close to your body. This helps to better focus on Trizeps involvement....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Donkey Calf Raises',
    description: 'For this exercise you will need access to a donkey calf raise machine. Start by positioning your lower back and hips under the padded lever provided. The tailbone area should be the one making contact with the pad. Place both of your arms on the side handles and place the balls of your feet on the calf block with the heels extending off. Align the toes forward, inward or outward, depending on the...',
    nameDe: 'Esel-Wadenlifte',
    descriptionDe: 'For this exercise you will need access to a Esel Wadenlifte Maschine. Start by positioning your Unterer Rücken and Hüften under the padded lever provided. The tailbone area should be the one making contact with the pad. Place both of your arms on the side handles and place the balls of your feet on...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Double Kettlebell Alternating Hang Clean',
    description: 'Place two kettlebells between your feet. To get in the starting position, push your butt back and look straight ahead. Clean one kettlebell to your shoulder and hold on to the other kettlebell. With a fluid motion, lower the top kettlebell while driving the bottom kettlebell up.',
    nameDe: 'Doppelt Kettlebell Alternierend Hang-Stoßen',
    descriptionDe: 'Place two Kettlebells between your feet. To get in the starting position, push your butt Rücken and look straight ahead. Stoßen one Kettlebell to your Schulter and hold on to the other Kettlebell. With a fluid motion, Unterer the top Kettlebell while driving the bottom Kettlebell up.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Double Kettlebell Jerk',
    description: 'Hold a kettlebell by the handle in each hand. Clean the kettlebells to your shoulders by extending through the legs and hips as you pull the kettlebells towards your shoulders. Rotate your wrists as you do so, so that the palms face forward. This will be your starting position. Dip your body by bending the knees, keeping your torso upright. Immediately reverse direction, driving through the...',
    nameDe: 'Doppelt Kettlebell Ausstoßen',
    descriptionDe: 'Hold a Kettlebell by the handle in each hand. Stoßen the Kettlebells to your Schultern by extending through the legs and Hüften as you pull the Kettlebells towards your Schultern. Rotate your wrists as you do so, so that the palms face forward. This will be your starting position. Dip your body by...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Double Kettlebell Push Press',
    description: 'Clean two kettlebells to your shoulders. Squat down a few inches and reverse the motion rapidly. Use the momentum from the legs to drive the kettlebells overhead. Once the kettlebells are locked out, lower the kettlebells to your shoulders and repeat.',
    nameDe: 'Doppelt Kettlebell Push Drücken',
    descriptionDe: 'Stoßen two Kettlebells to your Schultern. Kniebeuge down a few inches and Umgekehrt the motion rapidly. Use the momentum from the legs to drive the Kettlebells Überkopf. Once the Kettlebells are locked out, Unterer the Kettlebells to your Schultern and repeat.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Double Kettlebell Snatch',
    description: 'Place two kettlebells behind your feet. Bend your knees and sit back to pick up the kettlebells. Swing the kettlebells between your legs forcefully and reverse the direction. Drive through with your hips and lock the ketttlebells overhead in one uninterrupted motion.',
    nameDe: 'Doppelt Kettlebell Reißen',
    descriptionDe: 'Place two Kettlebells behind your feet. Bend your knees and sit Rücken to pick up the Kettlebells. Schwingen the Kettlebells between your legs forcefully and Umgekehrt the direction. Drive through with your Hüften and lock the ketttlebells Überkopf in one uninterrupted motion.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Double Kettlebell Windmill',
    description: 'Place a kettlebell in front of your front foot and clean and press a kettlebell overhead with your opposite arm. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulders. Rotate your wrist as you do so, so that the palm faces forward. Keeping the kettlebell locked out at all times, push your butt out in the direction of the...',
    nameDe: 'Doppelt Kettlebell Windmühle',
    descriptionDe: 'Place a Kettlebell in front of your front foot and Stoßen and Drücken a Kettlebell Überkopf with your opposite arm. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schultern. Rotate your Handgelenk as you do so, so that the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Downward Facing Balance',
    description: 'Lie facedown on top of an exercise ball. While resting on your stomach on the ball, walk your hands forward along the floor and lift your legs, extending your elbows and knees.',
    nameDe: 'Downward Facing Balance',
    descriptionDe: 'Lie facedown on top of an Trainingsball. While resting on your stomach on the Ball, Gehen your hands forward along the Boden and lift your legs, extending your elbows and knees.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Drag Curl',
    description: 'Grab a barbell with a supinated grip (palms facing forward) and get your elbows close to your torso and back. This will be your starting position. As you exhale, curl the bar up while keeping the elbows to the back as you "Drag" the bar up by keeping it in contact with your torso. Tip: As you can see, you will not be keeping the elbows pinned to your sides, but instead you will be bringing them...',
    nameDe: 'Ziehen Curl',
    descriptionDe: 'Grab a Langhantel with a Supiniert grip (palms facing forward) and get your elbows close to your torso and Rücken. This will be your starting position. As you exhale, Curl the Stange up while keeping the elbows to the Rücken as you "Ziehen" the Stange up by keeping it in contact with your torso....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Dumbbell Alternate Bicep Curl',
    description: 'Stand (torso upright) with a dumbbell in each hand held at arms length. The elbows should be close to the torso and the palms of your hand should be facing your thighs. While holding the upper arm stationary, curl the right weight as you rotate the palm of the hands until they are facing forward. At this point continue contracting the biceps as you breathe out until your biceps is fully...',
    nameDe: 'Kurzhantel Alternierend Bizepscurl',
    descriptionDe: 'Stand (torso Aufrecht) with a Kurzhantel in each hand held at arms length. The elbows should be close to the torso and the palms of your hand should be facing your thighs. While holding the Oberer arm stationary, Curl the right weight as you rotate the palm of the hands until they are facing...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Dumbbell Bench Press',
    description: 'Lie down on a flat bench with a dumbbell in each hand resting on top of your thighs. The palms of your hands will be facing each other. Then, using your thighs to help raise the dumbbells up, lift the dumbbells one at a time so that you can hold them in front of you at shoulder width. Once at shoulder width, rotate your wrists forward so that the palms of your hands are facing away from you. The...',
    nameDe: 'Kurzhantel-Bankdrücken',
    descriptionDe: 'Lie down on a Flachbank Bank with a Kurzhantel in each hand resting on top of your thighs. The palms of your hands will be facing each other. Then, using your thighs to help Heben the Kurzhanteln up, lift the Kurzhanteln one at a time so that you can hold them in front of you at Schulter width....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Dumbbell Bench Press with Neutral Grip',
    description: 'Take a dumbbell in each hand and lay back onto a flat bench. Your feet should be flat on the floor and your shoulder blades retracted. Maintaining a neutral grip, palms facing each other, begin with your arms extended directly above you, perpendicular to the floor. This will be your starting position. Begin the movement by flexing the elbow, lowering the upper arms to the side. Descend until the...',
    nameDe: 'Kurzhantel Bank Drücken with Neutralgriff',
    descriptionDe: 'Take a Kurzhantel in each hand and lay Rücken onto a Flachbank Bank. Your feet should be Flachbank on the Boden and your Schulter blades retracted. Maintaining a Neutralgriff, palms facing each other, begin with your arms extended directly above you, perpendicular to the Boden. This will be your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Dumbbell Bicep Curl',
    description: 'Stand up straight with a dumbbell in each hand at arm\'s length. Keep your elbows close to your torso and rotate the palms of your hands until they are facing forward. This will be your starting position. Now, keeping the upper arms stationary, exhale and curl the weights while contracting your biceps. Continue to raise the weights until your biceps are fully contracted and the dumbbells are at...',
    nameDe: 'Kurzhantel-Bizepscurl',
    descriptionDe: 'Stand up straight with a Kurzhantel in each hand at arm\'s length. Keep your elbows close to your torso and rotate the palms of your hands until they are facing forward. This will be your starting position. Now, keeping the Oberer arms stationary, exhale and Curl the weights while contracting your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Dumbbell Clean',
    description: 'Begin standing with a dumbbell in each hand with your feet shoulder width apart. Lower the weights to the floor by flexing at the hips and knees, pushing your hips back until the dumbbells reach the floor. This will be your starting position. To initiate the movement, violently jump upward by extending the hips, knees, and ankles to acclerate the weights upward. Maintaining a neutral grip on the...',
    nameDe: 'Kurzhantel Stoßen',
    descriptionDe: 'Begin Stehend with a Kurzhantel in each hand with your feet Schulter width apart. Unterer the weights to the Boden by flexing at the Hüften and knees, pushing your Hüften Rücken until the Kurzhanteln reach the Boden. This will be your starting position. To initiate the movement, violently Sprung...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Dumbbell Flyes',
    description: 'Lie down on a flat bench with a dumbbell on each hand resting on top of your thighs. The palms of your hand will be facing each other. Then using your thighs to help raise the dumbbells, lift the dumbbells one at a time so you can hold them in front of you at shoulder width with the palms of your hands facing each other. Raise the dumbbells up like you\'re pressing them, but stop and hold just...',
    nameDe: 'Kurzhantel-Fliegender',
    descriptionDe: 'Lie down on a Flachbank Bank with a Kurzhantel on each hand resting on top of your thighs. The palms of your hand will be facing each other. Then using your thighs to help Heben the Kurzhanteln, lift the Kurzhanteln one at a time so you can hold them in front of you at Schulter width with the palms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Dumbbell Incline Row',
    description: 'Using a neutral grip, lean into an incline bench. Take a dumbbell in each hand with a neutral grip, beginning with the arms straight. This will be your starting position. Retract the shoulder blades and flex the elbows to row the dumbbells to your side. Pause at the top of the motion, and then return to the starting position.',
    nameDe: 'Kurzhantel Schrägbank Rudern',
    descriptionDe: 'Using a Neutralgriff, lean into an Schrägbank Bank. Take a Kurzhantel in each hand with a Neutralgriff, beginning with the arms straight. This will be your starting position. Retract the Schulter blades and flex the elbows to Rudern the Kurzhanteln to your side. Pause at the top of the motion, and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Dumbbell Incline Shoulder Raise',
    description: 'Sit on an Incline Bench while holding a dumbbell on each hand on top of your thighs. Lift your legs up to kick the weights to your shoulders and lean back. Position the dumbbells above your shoulders with your arms extended. The arms should be perpendicular to the floor with your palms facing forward and knuckles pointing towards the ceiling. This will be your starting position. While keeping the...',
    nameDe: 'Kurzhantel Schrägbank Schulter Heben',
    descriptionDe: 'Sit on an Schrägbank Bank while holding a Kurzhantel on each hand on top of your thighs. Lift your legs up to kick the weights to your Schultern and lean Rücken. Position the Kurzhanteln above your Schultern with your arms extended. The arms should be perpendicular to the Boden with your palms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dumbbell Lunges',
    description: 'Stand with your torso upright holding two dumbbells in your hands by your sides. This will be your starting position. Step forward with your right leg around 2 feet or so from the foot being left stationary behind and lower your upper body down, while keeping the torso upright and maintaining balance. Inhale as you go down. Note: As in the other exercises, do not allow your knee to go forward...',
    nameDe: 'Kurzhantel-Ausfallschritte',
    descriptionDe: 'Stand with your torso Aufrecht holding two Kurzhanteln in your hands by your sides. This will be your starting position. Stufe forward with your right leg around 2 feet or so from the foot being left stationary behind and Unterer your Oberer body down, while keeping the torso Aufrecht and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Dumbbell Lying One-Arm Rear Lateral Raise',
    description: 'While holding a dumbbell in one hand, lay with your chest down on a slightly inclined (around 15 degrees when measured from the floor) adjustable bench. The other hand can be used to hold to the leg of the bench for stability. Position the palm of the hand that is holding the dumbbell in a neutral manner (palms facing your torso) as you keep the arm extended with the elbow slightly bent. This...',
    nameDe: 'Kurzhantel Liegend Einarmig Rear Seitlich Heben',
    descriptionDe: 'While holding a Kurzhantel in one hand, lay with your Brust down on a slightly inclined (around 15 degrees when measured from the Boden) adjustable Bank. The other hand can be used to hold to the leg of the Bank for stability. Position the palm of the hand that is holding the Kurzhantel in a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dumbbell Lying Pronation',
    description: 'Lie on a flat bench face down with one arm holding a dumbbell and the other hand on top of the bench folded so that you can rest your head on it. Bend the elbows of the arm holding the dumbbell so that it creates a 90-degree angle between the upper arm and the forearm. Now raise the upper arm so that the forearm is perpendicular to the floor and the upper arm is perpendicular to your torso. Tip:...',
    nameDe: 'Kurzhantel Liegend Pronation',
    descriptionDe: 'Lie on a Flachbank Bank face down with Einarmig holding a Kurzhantel and the other hand on top of the Bank folded so that you can rest your Kopf on it. Bend the elbows of the arm holding the Kurzhantel so that it creates a 90-degree angle between the Oberer arm and the Unterarm. Now Heben the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Dumbbell Lying Rear Lateral Raise',
    description: 'While holding a dumbbell in each hand, lay with your chest down on a slightly inclined (around 15 degrees when measured from the floor) adjustable bench. Position the palms of the hands in a neutral manner (palms facing your torso) as you keep the arms extended with the elbows slightly bent. This will be your starting position. Now raise the arms to the side until your elbows are at shoulder...',
    nameDe: 'Kurzhantel Liegend Rear Seitlich Heben',
    descriptionDe: 'While holding a Kurzhantel in each hand, lay with your Brust down on a slightly inclined (around 15 degrees when measured from the Boden) adjustable Bank. Position the palms of the hands in a neutral manner (palms facing your torso) as you keep the arms extended with the elbows slightly bent. This...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dumbbell Lying Supination',
    description: 'Lie sideways on a flat bench with one arm holding a dumbbell and the other hand on top of the bench folded so that you can rest your head on it. Bend the elbows of the arm holding the dumbbell so that it creates a 90-degree angle between the upper arm and the forearm. Now raise the upper arm so that the forearm is parallel to the floor and perpendicular to your torso (Tip: So the forearm will be...',
    nameDe: 'Kurzhantel Liegend Supination',
    descriptionDe: 'Lie sideways on a Flachbank Bank with Einarmig holding a Kurzhantel and the other hand on top of the Bank folded so that you can rest your Kopf on it. Bend the elbows of the arm holding the Kurzhantel so that it creates a 90-degree angle between the Oberer arm and the Unterarm. Now Heben the Oberer...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Dumbbell One-Arm Shoulder Press',
    description: 'Grab a dumbbell and either sit on a military press bench or a utility bench that has a back support on it as you place the dumbbells upright on top of your thighs or stand up straight. Clean the dumbbell up to bring it to shoulder height. The other hand can be kept fully extended to the side, by the waist or grabbing a fixed surface. Rotate the wrist so that the palm of your hand is facing...',
    nameDe: 'Kurzhantel Einarmig Schulterdrücken',
    descriptionDe: 'Grab a Kurzhantel and either sit on a military Drücken Bank or a utility Bank that has a Rücken support on it as you place the Kurzhanteln Aufrecht on top of your thighs or stand up straight. Stoßen the Kurzhantel up to bring it to Schulter height. The other hand can be kept fully extended to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dumbbell One-Arm Triceps Extension',
    description: 'Grab a dumbbell and either sit on a military press bench or a utility bench that has a back support on it as you place the dumbbells upright on top of your thighs or stand up straight. Clean the dumbbell up to bring it to shoulder height and then extend the arm over your head so that the whole arm is perpendicular to the floor and next to your head. The dumbbell should be on top of you. The other...',
    nameDe: 'Kurzhantel Einarmig Trizepsstreckung',
    descriptionDe: 'Grab a Kurzhantel and either sit on a military Drücken Bank or a utility Bank that has a Rücken support on it as you place the Kurzhanteln Aufrecht on top of your thighs or stand up straight. Stoßen the Kurzhantel up to bring it to Schulter height and then extend the arm over your Kopf so that the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Dumbbell One-Arm Upright Row',
    description: 'Grab a dumbbell and stand up straight with your arm extended in front of you with a slight bend at the elbows and your back straight. This will be your starting position. Tip: The dumbbell should be resting on top of your thigh with the palm of your hands facing your thighs. Keep the other hand can be kept fully extended to the side, by the waist or grabbing a fixed surface. This will be your...',
    nameDe: 'Kurzhantel Einarmig Aufrechtes Rudern',
    descriptionDe: 'Grab a Kurzhantel and stand up straight with your arm extended in front of you with a slight bend at the elbows and your Rücken straight. This will be your starting position. Tip: The Kurzhantel should be resting on top of your Oberschenkel with the palm of your hands facing your thighs. Keep the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dumbbell Prone Incline Curl',
    description: 'Grab a dumbbell on each hand and lie face down on an incline bench with your shoulders near top of the incline. Your knees can rest on the seat or your legs can be straddled to the sides (my preferred way). Let your arms extend and hang naturally in front of you so that they are perpendicular to the floor. Now keep your elbows in by your side and face the palms forward. This will be your starting...',
    nameDe: 'Kurzhantel Bauchlage Schrägbank Curl',
    descriptionDe: 'Grab a Kurzhantel on each hand and lie face down on an Schrägbank Bank with your Schultern near top of the Schrägbank. Your knees can rest on the seat or your legs can be straddled to the sides (my preferred way). Let your arms extend and hang naturally in front of you so that they are...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Dumbbell Raise',
    description: 'Grab a dumbbell in each arm and stand up straight with your arms extended by your sides with a slight bend at the elbows and your back straight. This will be your starting position. Tip: The dumbbell should be next to your thighs with the palm of your hands facing back. Use your side shoulders to lift the dumbbells as you exhale. The dumbbells should be to the side of the body as you move them...',
    nameDe: 'Kurzhantel Heben',
    descriptionDe: 'Grab a Kurzhantel in each arm and stand up straight with your arms extended by your sides with a slight bend at the elbows and your Rücken straight. This will be your starting position. Tip: The Kurzhantel should be next to your thighs with the palm of your hands facing Rücken. Use your side...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dumbbell Rear Lunge',
    description: 'Stand with your torso upright holding two dumbbells in your hands by your sides. This will be your starting position. Step backward with your right leg around two feet or so from the left foot and lower your upper body down, while keeping the torso upright and maintaining balance. Inhale as you go down. Tip: As in the other exercises, do not allow your knee to go forward beyond your toes as you...',
    nameDe: 'Kurzhantel Rear Ausfallschritt',
    descriptionDe: 'Stand with your torso Aufrecht holding two Kurzhanteln in your hands by your sides. This will be your starting position. Stufe backward with your right leg around two feet or so from the left foot and Unterer your Oberer body down, while keeping the torso Aufrecht and maintaining balance. Inhale as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Dumbbell Scaption',
    description: 'This corrective exercise strengthens the muscles that stabilize your shoulder blade. Hold a light weight in each hand, hanging at your sides. Your thumbs should pointing up. Begin the movement raising your arms out in front of you, about 30 degrees off center. Your arms should be fully extended as you perform the movement. Continue until your arms are parallel to the ground, and then return to...',
    nameDe: 'Kurzhantel-Scaption',
    descriptionDe: 'This corrective exercise strengthens the muscles that stabilize your Schulter blade. Hold a light weight in each hand, hanging at your sides. Your thumbs should pointing up. Begin the movement raising your arms out in front of you, about 30 degrees off center. Your arms should be fully extended as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dumbbell Seated One-Leg Calf Raise',
    description: 'Place a block on the floor about 12 inches from a flat bench. Sit on a flat bench and place a dumbbell on your upper left thigh about 3 inches above your knee. Now place the ball of your left foot on the block. This will be your starting position. Raise your toes up as high as possible as you exhale and you contract your calf muscle. Hold the contraction for a second. Slowly return to the...',
    nameDe: 'Kurzhantel Sitzend One-Leg Wadenlifte',
    descriptionDe: 'Place a block on the Boden about 12 inches from a Flachbank Bank. Sit on a Flachbank Bank and place a Kurzhantel on your Oberer left Oberschenkel about 3 inches above your Knie. Now place the Ball of your left foot on the block. This will be your starting position. Heben your toes up as high as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Dumbbell Shoulder Press',
    description: 'While holding a dumbbell in each hand, sit on a military press bench or utility bench that has back support. Place the dumbbells upright on top of your thighs. Now raise the dumbbells to shoulder height one at a time using your thighs to help propel them up into position. Make sure to rotate your wrists so that the palms of your hands are facing forward. This is your starting position. Now,...',
    nameDe: 'Kurzhantel-Schulterdrücken',
    descriptionDe: 'While holding a Kurzhantel in each hand, sit on a military Drücken Bank or utility Bank that has Rücken support. Place the Kurzhanteln Aufrecht on top of your thighs. Now Heben the Kurzhanteln to Schulter height one at a time using your thighs to help propel them up into position. Make sure to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Dumbbell Shrug',
    description: 'Stand erect with a dumbbell on each hand (palms facing your torso), arms extended on the sides. Lift the dumbbells by elevating the shoulders as high as possible while you exhale. Hold the contraction at the top for a second. Tip: The arms should remain extended at all times. Refrain from using the biceps to help lift the dumbbells. Only the shoulders should be moving up and down. Lower the...',
    nameDe: 'Kurzhantel-Schulterziehen',
    descriptionDe: 'Stand erect with a Kurzhantel on each hand (palms facing your torso), arms extended on the sides. Lift the Kurzhanteln by elevating the Schultern as high as possible while you exhale. Hold the contraction at the top for a second. Tip: The arms should remain extended at all times. Refrain from using...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Dumbbell Side Bend',
    description: 'Stand up straight while holding a dumbbell on the left hand (palms facing the torso) as you have the right hand holding your waist. Your feet should be placed at shoulder width. This will be your starting position. While keeping your back straight and your head up, bend only at the waist to the right as far as possible. Breathe in as you bend to the side. Then hold for a second and come back up...',
    nameDe: 'Kurzhantel Side Bend',
    descriptionDe: 'Stand up straight while holding a Kurzhantel on the left hand (palms facing the torso) as you have the right hand holding your waist. Your feet should be placed at Schulter width. This will be your starting position. While keeping your Rücken straight and your Kopf up, bend only at the waist to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Dumbbell Squat',
    description: 'Stand up straight while holding a dumbbell on each hand (palms facing the side of your legs). Position your legs using a shoulder width medium stance with the toes slightly pointed out. Keep your head up at all times as looking down will get you off balance and also maintain a straight back. This will be your starting position. Note: For the purposes of this discussion we will use the medium...',
    nameDe: 'Kurzhantel-Kniebeuge',
    descriptionDe: 'Stand up straight while holding a Kurzhantel on each hand (palms facing the side of your legs). Position your legs using a Schulter width medium stance with the toes slightly pointed out. Keep your Kopf up at all times as looking down will get you off balance and also maintain a straight Rücken....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Dumbbell Squat To A Bench',
    description: 'Stand up straight with a flat bench behind you while holding a dumbbell on each hand (palms facing the side of your legs). Position your legs using a shoulder width medium stance with the toes slightly pointed out. Keep your head up at all times as looking down will get you off balance and also maintain a straight back. This will be your starting position. Note: For the purposes of this...',
    nameDe: 'Kurzhantel Kniebeuge To A Bank',
    descriptionDe: 'Stand up straight with a Flachbank Bank behind you while holding a Kurzhantel on each hand (palms facing the side of your legs). Position your legs using a Schulter width medium stance with the toes slightly pointed out. Keep your Kopf up at all times as looking down will get you off balance and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Dumbbell Step Ups',
    description: 'Stand up straight while holding a dumbbell on each hand (palms facing the side of your legs). Place the right foot on the elevated platform. Step on the platform by extending the hip and the knee of your right leg. Use the heel mainly to lift the rest of your body up and place the foot of the left leg on the platform as well. Breathe out as you execute the force required to come up. Step down...',
    nameDe: 'Kurzhantel-Aufsteigen',
    descriptionDe: 'Stand up straight while holding a Kurzhantel on each hand (palms facing the side of your legs). Place the right foot on the elevated platform. Stufe on the platform by extending the Hüfte and the Knie of your right leg. Use the heel mainly to lift the rest of your body up and place the foot of the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Dumbbell Tricep Extension -Pronated Grip',
    description: 'Lie down on a flat bench holding two dumbbells directly above your shoulders. Your arms should be fully extended and form a 90 degree angle from your torso and the floor. The palms of your hands should be facing forward, and your elbows should be tucked in. This will be your starting position. Now, inhale and slowly lower the dumbbells until they are near your ears. Be sure to keep your upper...',
    nameDe: 'Kurzhantel Trizepsstreckung -Proniert Grip',
    descriptionDe: 'Lie down on a Flachbank Bank holding two Kurzhanteln directly above your Schultern. Your arms should be fully extended and form a 90 degree angle from your torso and the Boden. The palms of your hands should be facing forward, and your elbows should be tucked in. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'EZ-Bar Curl',
    description: 'Stand up straight while holding an EZ curl bar at the wide outer handle. The palms of your hands should be facing forward and slightly tilted inward due to the shape of the bar. Keep your elbows close to your torso. This will be your starting position. Now, while keeping your upper arms stationary, exhale and curl the weights forward while contracting the biceps. Focus on only moving your...',
    nameDe: 'EZ-Stange Curl',
    descriptionDe: 'Stand up straight while holding an EZ Curl Stange at the wide Außen handle. The palms of your hands should be facing forward and slightly tilted inward due to the shape of the Stange. Keep your elbows close to your torso. This will be your starting position. Now, while keeping your Oberer arms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'EZ-Bar Skullcrusher',
    description: 'Using a close grip, lift the EZ bar and hold it with your elbows in as you lie on the bench. Your arms should be perpendicular to the floor. This will be your starting position. Keeping the upper arms stationary, lower the bar by allowing the elbows to flex. Inhale as you perform this portion of the movement. Pause once the bar is directly above the forehead. Lift the bar back to the starting...',
    nameDe: 'EZ-Stange Skullcrusher',
    descriptionDe: 'Using a Enger Griff, lift the EZ-Stange and hold it with your elbows in as you lie on the Bank. Your arms should be perpendicular to the Boden. This will be your starting position. Keeping the Oberer arms stationary, Unterer the Stange by allowing the elbows to flex. Inhale as you perform this...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Elbow to Knee',
    description: 'Lie on the floor, crossing your right leg across your bent left knee. Clasp your hands behind your head, beginning with your shoulder blades on the ground. This will be your starting position. Perform the motion by flexing the spine and rotating your torso to bring the left elbow to the right knee. Return to the starting position and repeat the movement for the desired number of repetitions...',
    nameDe: 'Elbow to Knie',
    descriptionDe: 'Lie on the Boden, crossing your right leg across your bent left Knie. Clasp your hands behind your Kopf, beginning with your Schulter blades on the ground. This will be your starting position. Perform the motion by flexing the Wirbelsäule and rotating your torso to bring the left elbow to the right...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Elevated Back Lunge',
    description: 'Position a bar onto a rack at shoulder height loaded to an appropriate weight. Place a short, raised platform behind you. Rack the bar onto your upper back, keeping your back arched and tight. Step onto your raised platform with both feet. This will be your starting position. Begin by stepping backwards with one leg. Descend by flexing your hips and knees until your knee touches the floor. Pause,...',
    nameDe: 'Elevated Rücken Ausfallschritt',
    descriptionDe: 'Position a Stange onto a Ständer at Schulter height loaded to an appropriate weight. Place a short, raised platform behind you. Ständer the Stange onto your Oberer Rücken, keeping your Rücken arched and tight. Stufe onto your raised platform with both feet. This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Elevated Cable Rows',
    description: 'Get a platform of some sort (it can be an aerobics or calf raise platform) that is around 4-6 inches in height. Place it on the seat of the cable row machine. Sit down on the machine and place your feet on the front platform or crossbar provided making sure that your knees are slightly bent and not locked. Lean over as you keep the natural alignment of your back and grab the V-bar handles. With...',
    nameDe: 'Erhöhtes Kabelzugrudern',
    descriptionDe: 'Get a platform of some sort (it can be an aerobics or Wadenlifte platform) that is around 4-6 inches in height. Place it on the seat of the Kabelzug Rudern Maschine. Sit down on the Maschine and place your feet on the front platform or crossbar provided making sure that your knees are slightly bent...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Exercise Ball Crunch',
    description: 'Lie on an exercise ball with your lower back curvature pressed against the spherical surface of the ball. Your feet should be bent at the knee and pressed firmly against the floor. The upper torso should be hanging off the top of the ball. The arms should either be kept alongside the body or crossed on top of your chest as these positions avoid neck strains (as opposed to the hands behind the...',
    nameDe: 'Trainingsball Crunch',
    descriptionDe: 'Lie on an Trainingsball with your Unterer Rücken curvature pressed against the spherical surface of the Ball. Your feet should be bent at the Knie and pressed firmly against the Boden. The Oberer torso should be hanging off the top of the Ball. The arms should either be kept alongside the body or...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Exercise Ball Pull-In',
    description: 'Place an exercise ball nearby and lay on the floor in front of it with your hands on the floor shoulder width apart in a push-up position. Now place your lower shins on top of an exercise ball. Tip: At this point your legs should be fully extended with the shins on top of the ball and the upper body should be in a push-up type of position being supported by your two extended arms in front of you....',
    nameDe: 'Trainingsball Pull-In',
    descriptionDe: 'Place an Trainingsball nearby and lay on the Boden in front of it with your hands on the Boden Schulter width apart in a Liegestütz position. Now place your Unterer shins on top of an Trainingsball. Tip: At this point your legs should be fully extended with the shins on top of the Ball and the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Extended Range One-Arm Kettlebell Floor Press',
    description: 'Lie on the floor and position a kettlebell for one arm to press. The kettlebell should be held by the handle. The leg on the same side that you are pressing should be bent, with the knee crossing over the midline of the body. Press the kettlebell by extending the elbow and adducting the arm, pressing it above your body. Return to the starting position.',
    nameDe: 'Extended Range Einarmig Kettlebell Boden Drücken',
    descriptionDe: 'Lie on the Boden and position a Kettlebell for Einarmig to Drücken. The Kettlebell should be held by the handle. The leg on the same side that you are pressing should be bent, with the Knie crossing over the midline of the body. Drücken the Kettlebell by extending the elbow and adducting the arm,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'External Rotation',
    description: 'Lie sideways on a flat bench with one arm holding a dumbbell and the other hand on top of the bench folded so that you can rest your head on it. Bend the elbows of the arm holding the dumbbell so that it creates a 90-degree angle between the upper arm and the forearm. Tip: Keep the arm parallel to your torso. Now bend the elbow while keeping the upper arm stationary. In this manner, the forearm...',
    nameDe: 'External Rotation',
    descriptionDe: 'Lie sideways on a Flachbank Bank with Einarmig holding a Kurzhantel and the other hand on top of the Bank folded so that you can rest your Kopf on it. Bend the elbows of the arm holding the Kurzhantel so that it creates a 90-degree angle between the Oberer arm and the Unterarm. Tip: Keep the arm...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'External Rotation with Band',
    description: 'Choke the band around a post. The band should be at the same height as your elbow. Stand with your left side to the band a couple of feet away. Grasp the end of the band with your right hand, and keep your elbow pressed firmly to your side. We recommend you hold a pad or foam roll in place with your elbow to keep it firmly in position. With your upper arm in position, your elbow should be flexed...',
    nameDe: 'External Rotation mit Band',
    descriptionDe: 'Choke the Band around a post. The Band should be at the same height as your elbow. Stand with your left side to the Band a couple of feet away. Grasp the end of the Band with your right hand, and keep your elbow pressed firmly to your side. We recommend you hold a pad or Schaumstoffrolle in place...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'External Rotation with Cable',
    description: 'Adjust the cable to the same height as your elbow. Stand with your left side to the band a couple of feet away. Grasp the handle with your right hand, and keep your elbow pressed firmly to your side. We recommend you hold a pad or foam roll in place with your elbow to keep it firmly in position. With your upper arm in position, your elbow should be flexed to 90 degrees with your hand reaching...',
    nameDe: 'External Rotation with Kabelzug',
    descriptionDe: 'Adjust the Kabelzug to the same height as your elbow. Stand with your left side to the Band a couple of feet away. Grasp the handle with your right hand, and keep your elbow pressed firmly to your side. We recommend you hold a pad or Schaumstoffrolle in place with your elbow to keep it firmly in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Face Pull',
    description: 'Facing a high pulley with a rope or dual handles attached, pull the weight directly towards your face, separating your hands as you do so. Keep your upper arms parallel to the ground.',
    nameDe: 'Gesichtszug',
    descriptionDe: 'Facing a high pulley with a Seil or dual handles attached, pull the weight directly towards your face, separating your hands as you do so. Keep your Oberer arms parallel to the ground.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Finger Curls',
    description: 'Hold a barbell with both hands and your palms facing up; hands spaced about shoulder width. Place your feet flat on the floor, at a distance that is slightly wider than shoulder width apart. This will be your starting position. Lower the bar as far as possible by extending the fingers. Allowing the bar to roll down the hands, catch the bar with the final joint in the fingers. Now curl bar up as...',
    nameDe: 'Finger Curls',
    descriptionDe: 'Hold a Langhantel with both hands and your palms facing up; hands spaced about Schulter width. Place your feet Flachbank on the Boden, at a distance that is slightly wider than Schulter width apart. This will be your starting position. Unterer the Stange as far as possible by extending the fingers....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Flat Bench Cable Flyes',
    description: 'Position a flat bench between two low pulleys so that when you are laying on it, your chest will be lined up with the cable pulleys. Lay flat on the bench and keep your feet on the ground. Have someone hand you the handles on each hand. You will grab each single handle attachment with a palms up grip. Extend your arms by your side with a slight bend on your elbows. Tip: You will keep this bend...',
    nameDe: 'Flachbank Kabelzug Fliegender',
    descriptionDe: 'Position a Flachbank Bank between two low pulleys so that when you are laying on it, your Brust will be lined up with the Kabelzug pulleys. Lay Flachbank on the Bank and keep your feet on the ground. Have someone hand you the handles on each hand. You will grab each single handle attachment with a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Flat Bench Leg Pull-In',
    description: 'Lie on an exercise mat or a flat bench with your legs off the end. Place your hands either under your glutes with your palms down or by the sides holding on to the bench (or with palms down by the side on an exercise mat). Also extend your legs straight out. This will be your starting position. Bend your knees and pull your upper thighs into your midsection as you breathe out. Continue this...',
    nameDe: 'Flachbank Bank Leg Pull-In',
    descriptionDe: 'Lie on an exercise mat or a Flachbank Bank with your legs off the end. Place your hands either under your Gesäß with your palms down or by the sides holding on to the Bank (or with palms down by the side on an exercise mat). Also extend your legs straight out. This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Flat Bench Lying Leg Raise',
    description: 'Lie with your back flat on a bench and your legs extended in front of you off the end. Place your hands either under your glutes with your palms down or by the sides holding on to the bench. This will be your starting position. As you keep your legs extended, straight as possible with your knees slightly bent but locked raise your legs until they make a 90-degree angle with the floor. Exhale as...',
    nameDe: 'Flachbank Bank Liegend Leg Heben',
    descriptionDe: 'Lie with your Rücken Flachbank on a Bank and your legs extended in front of you off the end. Place your hands either under your Gesäß with your palms down or by the sides holding on to the Bank. This will be your starting position. As you keep your legs extended, straight as possible with your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Flexor Incline Dumbbell Curls',
    description: 'Hold the dumbbell towards the side farther from you so that you have more weight on the side closest to you. (This can be done for a good effect on all bicep dumbbell exercises). Now do a normal incline dumbbell curl, but keep your wrists as far back as possible so as to neutralize any stress that is placed on them. Sit on an incline bench that is angled at 45-degrees while holding a dumbbell on...',
    nameDe: 'Flexor Schrägbank Kurzhantel Curls',
    descriptionDe: 'Hold the Kurzhantel towards the side farther from you so that you have more weight on the side closest to you. (This can be done for a good effect on all Bizeps Kurzhantel exercises). Now do a normal Schrägbank Kurzhantel Curl, but keep your wrists as far Rücken as possible so as to neutralize any...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Floor Glute-Ham Raise',
    description: 'You can use a partner for this exercise or brace your feet under something stable. Begin on your knees with your upper legs and torso upright. If using a partner, they will firmly hold your feet to keep you in position. This will be your starting position. Lower yourself by extending at the knee, taking care to NOT flex the hips as you go forward. Place your hands in front of you as you reach the...',
    nameDe: 'Boden Gesäß-Ham Heben',
    descriptionDe: 'You can use a partner for this exercise or brace your feet under something stable. Begin on your knees with your Oberer legs and torso Aufrecht. If using a partner, they will firmly hold your feet to keep you in position. This will be your starting position. Unterer yourself by extending at the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Flutter Kicks',
    description: 'On a flat bench lie facedown with the hips on the edge of the bench, the legs straight with toes high off the floor and with the arms on top of the bench holding on to the front edge. Squeeze your glutes and hamstrings and straighten the legs until they are level with the hips. This will be your starting position. Start the movement by lifting the left leg higher than the right leg. Then lower...',
    nameDe: 'Fußschläge',
    descriptionDe: 'On a Flachbank Bank lie facedown with the Hüften on the edge of the Bank, the legs straight with toes high off the Boden and with the arms on top of the Bank holding on to the front edge. Squeeze your Gesäß and Oberschenkelrückseite and straighten the legs until they are level with the Hüften. This...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Freehand Jump Squat',
    description: 'Cross your arms over your chest. With your head up and your back straight, position your feet at shoulder width. Keeping your back straight and chest up, squat down as you inhale until your upper thighs are parallel, or lower, to the floor. Now pressing mainly with the ball of your feet, jump straight up in the air as high as possible, using the thighs like springs. Exhale during this portion of...',
    nameDe: 'Freehand Sprung Kniebeuge',
    descriptionDe: 'Überkreuz your arms over your Brust. With your Kopf up and your Rücken straight, position your feet at Schulter width. Keeping your Rücken straight and Brust up, Kniebeuge down as you inhale until your Oberer thighs are parallel, or Unterer, to the Boden. Now pressing mainly with the Ball of your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Frog Sit-Ups',
    description: 'Lie with your back flat on the floor (or exercise mat) and your legs extended in front of you. Now bend at the knees and place your outer thighs by the floor (or mat) as you make the soles of your feet touch each other. Now try pushing both soles and bringing them up as near you as possible while you keep the outer thighs on the floor (or at least almost touching it). Tip: In this position your...',
    nameDe: 'Frosch Sit-Ups',
    descriptionDe: 'Lie with your Rücken Flachbank on the Boden (or exercise mat) and your legs extended in front of you. Now bend at the knees and place your Außen thighs by the Boden (or mat) as you make the soles of your feet touch each other. Now try pushing both soles and bringing them up as near you as possible...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Front Barbell Squat',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, bring your arms up under the bar while keeping the elbows high and the upper arm slightly above parallel to the floor. Rest the bar on top of the deltoids and cross your arms while grasping the bar...',
    nameDe: 'Front Langhantel Kniebeuge',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, bring your arms up under the Stange while keeping the elbows high and the Oberer arm...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Front Barbell Squat To A Bench',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set a flat bench behind you and set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, bring your arms up under the bar while keeping the elbows high and the upper arm slightly above parallel to the floor. Rest the bar on top of the deltoids and cross...',
    nameDe: 'Front Langhantel Kniebeuge To A Bank',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set a Flachbank Bank behind you and set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, bring your arms up under the Stange while...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Front Cable Raise',
    description: 'Select the weight on a low pulley machine and grasp the single hand cable attachment that is attached to the low pulley with your left hand. Face away from the pulley and put your arm straight down with the hand cable attachment in front of your thighs at arms\' length with the palms of the hand facing your thighs. This will be your starting position. While maintaining the torso stationary (no...',
    nameDe: 'Front Kabelzug Heben',
    descriptionDe: 'Select the weight on a low pulley Maschine and grasp the single hand Kabelzug attachment that is attached to the low pulley with your left hand. Face away from the pulley and put your arm straight down with the hand Kabelzug attachment in front of your thighs at arms\' length with the palms of the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Front Dumbbell Raise',
    description: 'Pick a couple of dumbbells and stand with a straight torso and the dumbbells on front of your thighs at arms length with the palms of the hand facing your thighs. This will be your starting position. While maintaining the torso stationary (no swinging), lift the left dumbbell to the front with a slight bend on the elbow and the palms of the hands always facing down. Continue to go up until you...',
    nameDe: 'Front Kurzhantel Heben',
    descriptionDe: 'Pick a couple of Kurzhanteln and stand with a straight torso and the Kurzhanteln on front of your thighs at arms length with the palms of the hand facing your thighs. This will be your starting position. While maintaining the torso stationary (no swinging), lift the left Kurzhantel to the front...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Front Incline Dumbbell Raise',
    description: 'Sit down on an incline bench with the incline set anywhere between 30 to 60 degrees while holding a dumbbell on each hand. Tip: You can change the angle to hit the muscle a little differently each time. Extend your arms straight in front of you and have your palms facing down with the dumbbells raised about 1 inch above your thighs. This will be your starting position. Slowly raise the dumbbells...',
    nameDe: 'Front Schrägbank Kurzhantel Heben',
    descriptionDe: 'Sit down on an Schrägbank Bank with the Schrägbank set anywhere between 30 to 60 degrees while holding a Kurzhantel on each hand. Tip: You can change the angle to hit the muscle a little differently each time. Extend your arms straight in front of you and have your palms facing down with the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Front Plate Raise',
    description: 'While standing straight, hold a barbell plate in both hands at the 3 and 9 o\'clock positions. Your palms should be facing each other and your arms should be extended and locked with a slight bend at the elbows and the plate should be down near your waist in front of you as far as you can go. Tip: The arms will remain in this position throughout the exercise. This will be your starting position....',
    nameDe: 'Front Scheibe Heben',
    descriptionDe: 'While Stehend straight, hold a Langhantel Scheibe in both hands at the 3 and 9 o\'clock positions. Your palms should be facing each other and your arms should be extended and locked with a slight bend at the elbows and the Scheibe should be down near your waist in front of you as far as you can go....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Front Raise And Pullover',
    description: 'Lie on a flat bench while holding a barbell using a palms down grip that is about 15 inches apart. Place the bar on your upper thighs, extend your arms and lock them while keeping a slight bend on the elbows. This will be your starting position. Now raise the weight using a semicircular motion and keeping your arms straight as you inhale. Continue the same movement until the bar is on the other...',
    nameDe: 'Front Heben And Pullover',
    descriptionDe: 'Lie on a Flachbank Bank while holding a Langhantel using a palms down grip that is about 15 inches apart. Place the Stange on your Oberer thighs, extend your arms and lock them while keeping a slight bend on the elbows. This will be your starting position. Now Heben the weight using a semicircular...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Front Squat (Clean Grip)',
    description: 'To begin, first set the bar in a rack slightly below shoulder level. Rest the bar on top of the deltoids, pushing into the clavicles, and lightly touching the throat. Your hands should be in a clean grip, touching the bar only with your fingers to help keep it in position. Lift the bar off the rack by first pushing with your legs and at the same time straightening your torso. Step away from the...',
    nameDe: 'Front Kniebeuge (Stoßen Grip)',
    descriptionDe: 'To begin, first set the Stange in a Ständer slightly below Schulter level. Rest the Stange on top of the deltoids, pushing into the clavicles, and lightly touching the throat. Your hands should be in a Stoßen grip, touching the Stange only with your fingers to help keep it in position. Lift the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Front Squats With Two Kettlebells',
    description: 'Clean two kettlebells to your shoulders. Clean the kettlebells to your shoulders by extending through the legs and hips as you pull the kettlebells towards your shoulders. Rotate your wrists as you do so. Looking straight ahead at all times, squat as low as you can and pause at the bottom. As you squat down, push your knees out. You should squat between your legs, keeping an upright torso, with...',
    nameDe: 'Front Squats With Two Kettlebells',
    descriptionDe: 'Stoßen two Kettlebells to your Schultern. Stoßen the Kettlebells to your Schultern by extending through the legs and Hüften as you pull the Kettlebells towards your Schultern. Rotate your wrists as you do so. Looking straight ahead at all times, Kniebeuge as low as you can and Pause at the bottom....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Front Two-Dumbbell Raise',
    description: 'Pick a couple of dumbbells and stand with a straight torso and the dumbbells on front of your thighs at arms length with the palms of the hand facing your thighs. This will be your starting position. While maintaining the torso stationary (no swinging), lift the dumbbells to the front with a slight bend on the elbow and the palms of the hands always facing down. Continue to go up until you arms...',
    nameDe: 'Front Two-Kurzhantel Heben',
    descriptionDe: 'Pick a couple of Kurzhanteln and stand with a straight torso and the Kurzhanteln on front of your thighs at arms length with the palms of the hand facing your thighs. This will be your starting position. While maintaining the torso stationary (no swinging), lift the Kurzhanteln to the front with a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Full Range-Of-Motion Lat Pulldown',
    description: 'Either standing or seated on a high bench, grasp two stirrup cables that are attached to the high pulleys. Grab with the opposing hand so your arms are crisscrossed about you and your palms are facing forward. Keeping your chest up and maintaining a slight arch in your lower back, pull the handles down as if you were doing a regular pulldown. The range of motion will be more of an arc. During the...',
    nameDe: 'Komplett Range-Of-Motion Lat Latzug',
    descriptionDe: 'Either Stehend or Sitzend on a high Bank, grasp two stirrup cables that are attached to the high pulleys. Grab with the opposing hand so your arms are crisscrossed about you and your palms are facing forward. Keeping your Brust up and maintaining a slight arch in your Unterer Rücken, pull the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Gironda Sternum Chins',
    description: 'Grasp the pull-up bar with a shoulder width underhand grip. Now hang with your arms fully extended and stick your chest out and lean back. Tip: You will be leaning back throughout the entire movement. This will be your starting position. Start pulling yourself towards the bar with your spine arched throughout the movement and your head leaning back as far away from the bar as possible. Exhale as...',
    nameDe: 'Gironda Sternum Chins',
    descriptionDe: 'Grasp the Klimmzugstange with a Schulter width Untergriff grip. Now hang with your arms fully extended and stick your Brust out and lean Rücken. Tip: You will be leaning Rücken throughout the entire movement. This will be your starting position. Start pulling yourself towards the Stange with your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Glute Kickback',
    description: 'Kneel on the floor or an exercise mat and bend at the waist with your arms extended in front of you (perpendicular to the torso) in order to get into a kneeling push-up position but with the arms spaced at shoulder width. Your head should be looking forward and the bend of the knees should create a 90-degree angle between the hamstrings and the calves. This will be your starting position. As you...',
    nameDe: 'Gesäß Kickback',
    descriptionDe: 'Kneel on the Boden or an exercise mat and bend at the waist with your arms extended in front of you (perpendicular to the torso) in order to get into a Kniend Liegestütz position but with the arms spaced at Schulter width. Your Kopf should be looking forward and the bend of the knees should create...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Goblet Squat',
    description: 'Stand holding a light kettlebell by the horns close to your chest. This will be your starting position. Squat down between your legs until your hamstrings are on your calves. Keep your chest and head up and your back straight. At the bottom position, pause and use your elbows to push your knees out. Return to the starting position, and repeat for 10-20 repetitions.',
    nameDe: 'Goblet-Kniebeuge',
    descriptionDe: 'Stand holding a light Kettlebell by the horns close to your Brust. This will be your starting position. Kniebeuge down between your legs until your Oberschenkelrückseite are on your Waden. Keep your Brust and Kopf up and your Rücken straight. At the bottom position, Pause and use your elbows to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Gorilla Chin/Crunch',
    description: 'Hang from a chin-up bar using an underhand grip (palms facing you) that is slightly wider than shoulder width. Now bend your knees at a 90 degree angle so that the calves are parallel to the floor while the thighs remain perpendicular to it. This will be your starting position. As you exhale, pull yourself up while crunching your knees up at the same time until your knees are at chest level. You...',
    nameDe: 'Gorilla Chin/Crunch',
    descriptionDe: 'Hang from a Klimmzugstange using an Untergriff grip (palms facing you) that is slightly wider than Schulter width. Now bend your knees at a 90 degree angle so that the Waden are parallel to the Boden while the thighs remain perpendicular to it. This will be your starting position. As you exhale,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Hack Squat',
    description: 'Place the back of your torso against the back pad of the machine and hook your shoulders under the shoulder pads provided. Position your legs in the platform using a shoulder width medium stance with the toes slightly pointed out. Tip: Keep your head up at all times and also maintain the back on the pad at all times. Place your arms on the side handles of the machine and disengage the safety bars...',
    nameDe: 'Hack Kniebeuge',
    descriptionDe: 'Place the Rücken of your torso against the Rücken pad of the Maschine and hook your Schultern under the Schulter pads provided. Position your legs in the platform using a Schulter width medium stance with the toes slightly pointed out. Tip: Keep your Kopf up at all times and also maintain the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hammer Curls',
    description: 'Stand up with your torso upright and a dumbbell on each hand being held at arms length. The elbows should be close to the torso. The palms of the hands should be facing your torso. This will be your starting position. Now, while holding your upper arm stationary, exhale and curl the weight forward while contracting the biceps. Continue to raise the weight until the biceps are fully contracted and...',
    nameDe: 'Hammer Curls',
    descriptionDe: 'Stand up with your torso Aufrecht and a Kurzhantel on each hand being held at arms length. The elbows should be close to the torso. The palms of the hands should be facing your torso. This will be your starting position. Now, while holding your Oberer arm stationary, exhale and Curl the weight...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Hammer Grip Incline DB Bench Press',
    description: 'Lie back on an incline bench with a dumbbell on each hand on top of your thighs. The palms of your hand will be facing each other. By using your thighs to help you get the dumbbells up, clean the dumbbells one arm at a time so that you can hold them at shoulder width. Once at shoulder width, keep the palms of your hands with a neutral grip (palms facing each other). Keep your elbows flared out...',
    nameDe: 'Hammer Grip Schrägbank DB Bank Drücken',
    descriptionDe: 'Lie Rücken on an Schrägbank Bank with a Kurzhantel on each hand on top of your thighs. The palms of your hand will be facing each other. By using your thighs to help you get the Kurzhanteln up, Stoßen the Kurzhanteln Einarmig at a time so that you can hold them at Schulter width. Once at Schulter...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Handstand Push-Ups',
    description: 'With your back to the wall bend at the waist and place both hands on the floor at shoulder width. Kick yourself up against the wall with your arms straight. Your body should be upside down with the arms and legs fully extended. Keep your whole body as straight as possible. Tip: If doing this for the first time, have a spotter help you. Also, make sure that you keep facing the wall with your head,...',
    nameDe: 'Handstand Push-Ups',
    descriptionDe: 'With your Rücken to the Wand bend at the waist and place both hands on the Boden at Schulter width. Kick yourself up against the Wand with your arms straight. Your body should be upside down with the arms and legs fully extended. Keep your whole body as straight as possible. Tip: If doing this for...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Hanging Leg Raise',
    description: 'Hang from a chin-up bar with both arms extended at arms length in top of you using either a wide grip or a medium grip. The legs should be straight down with the pelvis rolled slightly backwards. This will be your starting position. Raise your legs until the torso makes a 90-degree angle with the legs. Exhale as you perform this movement and hold the contraction for a second or so. Go back slowly...',
    nameDe: 'Hanging Leg Heben',
    descriptionDe: 'Hang from a Klimmzugstange with both arms extended at arms length in top of you using either a Weiter Griff or a medium grip. The legs should be straight down with the pelvis rolled slightly backwards. This will be your starting position. Heben your legs until the torso makes a 90-degree angle with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Hanging Pike',
    description: 'Hang from a chin-up bar with your legs and feet together using an overhand grip (palms facing away from you) that is slightly wider than shoulder width. Tip: You may use wrist wraps in order to facilitate holding on to the bar. Now bend your knees at a 90 degree angle and bring the upper legs forward so that the calves are perpendicular to the floor while the thighs remain parallel to it. This...',
    nameDe: 'Hanging Pike',
    descriptionDe: 'Hang from a Klimmzugstange with your legs and feet together using an Obergriff grip (palms facing away from you) that is slightly wider than Schulter width. Tip: You may use Handgelenk wraps in order to facilitate holding on to the Stange. Now bend your knees at a 90 degree angle and bring the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'High Cable Curls',
    description: 'Stand between a couple of high pulleys and grab a handle in each arm. Position your upper arms in a way that they are parallel to the floor with the palms of your hands facing you. This will be your starting position. Curl the handles towards you until they are next to your ears. Make sure that as you do so you flex your biceps and exhale. The upper arms should remain stationary and only the...',
    nameDe: 'High Kabelzug Curls',
    descriptionDe: 'Stand between a couple of high pulleys and grab a handle in each arm. Position your Oberer arms in a way that they are parallel to the Boden with the palms of your hands facing you. This will be your starting position. Curl the handles towards you until they are next to your ears. Make sure that as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Hip Extension with Bands',
    description: 'Secure one end of the band to the lower portion of a post and attach the other to one ankle. Facing the attachment point of the band, hold on to the column to stabilize yourself. Keeping your head and your chest up, move the resisted leg back as far as you can while keeping the knee straight. Return the leg to the starting position.',
    nameDe: 'Hüftstreckung mit Band',
    descriptionDe: 'Secure one end of the Band to the Unterer portion of a post and attach the other to one Knöchel. Facing the attachment point of the Band, hold on to the column to stabilize yourself. Keeping your Kopf and your Brust up, move the resisted leg Rücken as far as you can while keeping the Knie straight....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hip Flexion with Band',
    description: 'Secure one end of the band to the lower portion of a post and attach the other to one ankle. Face away from the attachment point of the band. Keeping your head and your chest up, raise your knee up to 90 degrees and pause. Return the leg to the starting position.',
    nameDe: 'Hüftbeugung mit Band',
    descriptionDe: 'Secure one end of the Band to the Unterer portion of a post and attach the other to one Knöchel. Face away from the attachment point of the Band. Keeping your Kopf and your Brust up, Heben your Knie up to 90 degrees and Pause. Return the leg to the starting position.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hyperextensions (Back Extensions)',
    description: 'Lie face down on a hyperextension bench, tucking your ankles securely under the footpads. Adjust the upper pad if possible so your upper thighs lie flat across the wide pad, leaving enough room for you to bend at the waist without any restriction. With your body straight, cross your arms in front of you (my preference) or behind your head. This will be your starting position. Tip: You can also...',
    nameDe: 'Hyperextensions (Rücken Extensions)',
    descriptionDe: 'Lie face down on a hyperextension Bank, tucking your ankles securely under the footpads. Adjust the Oberer pad if possible so your Oberer thighs lie Flachbank across the wide pad, leaving enough room for you to bend at the waist without any restriction. With your body straight, Überkreuz your arms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Hyperextensions With No Hyperextension Bench',
    description: 'With someone holding down your legs, slide yourself down to the edge a flat bench until your hips hang off the end of the bench. Tip: Your entire upper body should be hanging down towards the floor. Also, you will be in the same position as if you were on a hyperextension bench but the range of motion will be shorter due to the height of the flat bench vs. that of the hyperextension bench. With...',
    nameDe: 'Hyperextensions With No Hyperextension Bank',
    descriptionDe: 'With someone holding down your legs, slide yourself down to the edge a Flachbank Bank until your Hüften hang off the end of the Bank. Tip: Your entire Oberer body should be hanging down towards the Boden. Also, you will be in the same position as if you were on a hyperextension Bank but the range...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Incline Barbell Triceps Extension',
    description: 'Hold a barbell with an overhand grip (palms down) that is a little closer together than shoulder width. Lie back on an incline bench set at any angle between 45-75-degrees. Bring the bar overhead with your arms extended and elbows in. The arms should be in line with the torso above the head. This will be your starting position. Now lower the bar in a semicircular motion behind your head until...',
    nameDe: 'Schrägbank Langhantel Trizepsstreckung',
    descriptionDe: 'Hold a Langhantel with an Obergriff grip (palms down) that is a little closer together than Schulter width. Lie Rücken on an Schrägbank Bank set at any angle between 45-75-degrees. Bring the Stange Überkopf with your arms extended and elbows in. The arms should be in line with the torso above the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Incline Bench Pull',
    description: 'Grab a dumbbell in each hand and lie face down on an incline bench that is set to an incline that is approximately 30 degrees. Let the arms hang to your sides fully extended as they point to the floor. Turn the wrists until your hands have a pronated (palms down) grip. Now flare the elbows out. This will be your starting position. As you breathe out, start to pull the dumbbells up as if you are...',
    nameDe: 'Schrägbank Bank Pull',
    descriptionDe: 'Grab a Kurzhantel in each hand and lie face down on an Schrägbank Bank that is set to an Schrägbank that is approximately 30 degrees. Let the arms hang to your sides fully extended as they point to the Boden. Turn the wrists until your hands have a Proniert (palms down) grip. Now flare the elbows...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Incline Cable Chest Press',
    description: 'Adjust the weight to an appropriate amount and be seated, grasping the handles. Your upper arms should be about 45 degrees to the body, with your head and chest up. The elbows should be bent to about 90 degrees. This will be your starting position. Begin by extending through the elbow, pressing the handles together straight in front of you. Keep your shoulder blades retracted as you execute the...',
    nameDe: 'Schrägbank Kabelzug Brustdrücken',
    descriptionDe: 'Adjust the weight to an appropriate amount and be Sitzend, grasping the handles. Your Oberer arms should be about 45 degrees to the body, with your Kopf and Brust up. The elbows should be bent to about 90 degrees. This will be your starting position. Begin by extending through the elbow, pressing...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Cable Flye',
    description: 'To get yourself into the starting position, set the pulleys at the floor level (lowest level possible on the machine that is below your torso). Place an incline bench (set at 45 degrees) in between the pulleys, select a weight on each one and grab a pulley on each hand. With a handle on each hand, lie on the incline bench and bring your hands together at arms length in front of your face. This...',
    nameDe: 'Schrägbank Kabelzug Fliegender',
    descriptionDe: 'To get yourself into the starting position, set the pulleys at the Boden level (lowest level possible on the Maschine that is below your torso). Place an Schrägbank Bank (set at 45 degrees) in between the pulleys, select a weight on each one and grab a pulley on each hand. With a handle on each...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Dumbbell Bench With Palms Facing In',
    description: 'Lie back on an incline bench with a dumbbell on each hand on top of your thighs. The palms of your hand will be facing each other. By using your thighs to help you get the dumbbells up, clean the dumbbells one arm at a time so that you can hold them at shoulder width. Once at shoulder width, keep the palms of your hands with a neutral grip (palms facing each other). Keep your elbows flared out...',
    nameDe: 'Schrägbank Kurzhantel Bank With Palms Facing In',
    descriptionDe: 'Lie Rücken on an Schrägbank Bank with a Kurzhantel on each hand on top of your thighs. The palms of your hand will be facing each other. By using your thighs to help you get the Kurzhanteln up, Stoßen the Kurzhanteln Einarmig at a time so that you can hold them at Schulter width. Once at Schulter...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Dumbbell Curl',
    description: 'Sit back on an incline bench with a dumbbell in each hand held at arms length. Keep your elbows close to your torso and rotate the palms of your hands until they are facing forward. This will be your starting position. While holding the upper arm stationary, curl the weights forward while contracting the biceps as you breathe out. Only the forearms should move. Continue the movement until your...',
    nameDe: 'Schrägbank Kurzhantel Curl',
    descriptionDe: 'Sit Rücken on an Schrägbank Bank with a Kurzhantel in each hand held at arms length. Keep your elbows close to your torso and rotate the palms of your hands until they are facing forward. This will be your starting position. While holding the Oberer arm stationary, Curl the weights forward while...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Incline Dumbbell Flyes',
    description: 'Hold a dumbbell on each hand and lie on an incline bench that is set to an incline angle of no more than 30 degrees. Extend your arms above you with a slight bend at the elbows. Now rotate the wrists so that the palms of your hands are facing you. Tip: The pinky fingers should be next to each other. This will be your starting position. As you breathe in, start to slowly lower the arms to the side...',
    nameDe: 'Schrägbank Kurzhantel Flyes',
    descriptionDe: 'Hold a Kurzhantel on each hand and lie on an Schrägbank Bank that is set to an Schrägbank angle of no more than 30 degrees. Extend your arms above you with a slight bend at the elbows. Now rotate the wrists so that the palms of your hands are facing you. Tip: The pinky fingers should be next to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Dumbbell Flyes - With A Twist',
    description: 'Hold a dumbbell in each hand and lie on an incline bench that is set to an incline angle of no more than 30 degrees. Extend your arms above you with a slight bend at the elbows. Now rotate the wrists so that the palms of your hands are facing you. Tip: The pinky fingers should be next to each other. This will be your starting position. As you breathe in, start to slowly lower the arms to the side...',
    nameDe: 'Schrägbank Kurzhantel Flyes - With A Twist',
    descriptionDe: 'Hold a Kurzhantel in each hand and lie on an Schrägbank Bank that is set to an Schrägbank angle of no more than 30 degrees. Extend your arms above you with a slight bend at the elbows. Now rotate the wrists so that the palms of your hands are facing you. Tip: The pinky fingers should be next to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Dumbbell Press',
    description: 'Lie back on an incline bench with a dumbbell in each hand atop your thighs. The palms of your hands will be facing each other. Then, using your thighs to help push the dumbbells up, lift the dumbbells one at a time so that you can hold them at shoulder width. Once you have the dumbbells raised to shoulder width, rotate your wrists forward so that the palms of your hands are facing away from you....',
    nameDe: 'Schrägbank Kurzhantel Drücken',
    descriptionDe: 'Lie Rücken on an Schrägbank Bank with a Kurzhantel in each hand atop your thighs. The palms of your hands will be facing each other. Then, using your thighs to help push the Kurzhanteln up, lift the Kurzhanteln one at a time so that you can hold them at Schulter width. Once you have the Kurzhanteln...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Hammer Curls',
    description: 'Seat yourself on an incline bench with a dumbbell in each hand. You should pressed firmly against he back with your feet together. Allow the dumbbells to hang straight down at your side, holding them with a neutral grip. This will be your starting position. Initiate the movement by flexing at the elbow, attempting to keep the upper arm stationary. Continue to the top of the movement and pause,...',
    nameDe: 'Schrägbank Hammer Curls',
    descriptionDe: 'Seat yourself on an Schrägbank Bank with a Kurzhantel in each hand. You should pressed firmly against he Rücken with your feet together. Allow the Kurzhanteln to hang straight down at your side, holding them with a Neutralgriff. This will be your starting position. Initiate the movement by flexing...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Incline Inner Biceps Curl',
    description: 'Hold a dumbbell in each hand and lie back on an incline bench. The dumbbells should be at arm\'s length hanging at your sides and your palms should be facing out. This will be your starting position. Now as you exhale curl the weight outward and up while keeping your forearms in line with your side deltoids. Continue the curl until the dumbbells are at shoulder height and to the sides of your...',
    nameDe: 'Schrägbank Innen Bizepscurl',
    descriptionDe: 'Hold a Kurzhantel in each hand and lie Rücken on an Schrägbank Bank. The Kurzhanteln should be at arm\'s length hanging at your sides and your palms should be facing out. This will be your starting position. Now as you exhale Curl the weight outward and up while keeping your Unterarme in line with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Incline Push-Up',
    description: 'Stand facing bench or sturdy elevated platform. Place hands on edge of bench or platform, slightly wider than shoulder width. Position forefoot back from bench or platform with arms and body straight. Arms should be perpendicular to body. Keeping body straight, lower chest to edge of box or platform by bending arms. Push body up until arms are extended. Repeat.',
    nameDe: 'Schrägbank Liegestütz',
    descriptionDe: 'Stand facing Bank or sturdy elevated platform. Place hands on edge of Bank or platform, slightly wider than Schulter width. Position forefoot Rücken from Bank or platform with arms and body straight. Arms should be perpendicular to body. Keeping body straight, Unterer Brust to edge of Box or...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Push-Up Close-Grip',
    description: 'Stand facing a Smith machine bar or sturdy elevated platform at an appropriate height. Place your hands next to one another on the bar. Position your feet back from the bar with arms and body straight. This will be your starting position. Keeping your body straight, lower your chest to the bar by bending the arms. Return to the starting position by extending the elbows, pressing yourself back up.',
    nameDe: 'Schrägbank Liegestütz Enger Griff',
    descriptionDe: 'Stand facing a Smith-Maschine Stange or sturdy elevated platform at an appropriate height. Place your hands next to one another on the Stange. Position your feet Rücken from the Stange with arms and body straight. This will be your starting position. Keeping your body straight, Unterer your Brust...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Incline Push-Up Medium',
    description: 'Stand facing a Smith machine bar or sturdy elevated platform at an appropriate height. Place your hands on the bar, with your hands about shoulder width apart. Position your feet back from the bar with arms and body straight. This will be your starting position. Keeping your body straight, lower your chest to the bar by bending the arms. Return to the starting position by extending the elbows,...',
    nameDe: 'Schrägbank Liegestütz Medium',
    descriptionDe: 'Stand facing a Smith-Maschine Stange or sturdy elevated platform at an appropriate height. Place your hands on the Stange, with your hands about Schulter width apart. Position your feet Rücken from the Stange with arms and body straight. This will be your starting position. Keeping your body...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Push-Up Reverse Grip',
    description: 'Stand facing a Smith machine bar or sturdy elevated platform at an appropriate height. Place your hands on the bar palms up, with your hands about shoulder width apart. Position your feet back from the bar with arms and body straight. This will be your starting position. Keeping your body straight, lower your chest to the bar by bending the arms. Return to the starting position by extending the...',
    nameDe: 'Schrägbank Liegestütz Umgekehrt Grip',
    descriptionDe: 'Stand facing a Smith-Maschine Stange or sturdy elevated platform at an appropriate height. Place your hands on the Stange palms up, with your hands about Schulter width apart. Position your feet Rücken from the Stange with arms and body straight. This will be your starting position. Keeping your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Incline Push-Up Wide',
    description: 'Stand facing a Smith machine bar or sturdy elevated platform at an appropriate height. Place your hands on the bar, with your hands wider than shoulder width. Position your feet back from the bar with arms and body straight. Your arms should be perpendicular to the body. This will be your starting position. Keeping your body straight, lower your chest to the bar by bending the arms. Return to the...',
    nameDe: 'Schrägbank Liegestütz Wide',
    descriptionDe: 'Stand facing a Smith-Maschine Stange or sturdy elevated platform at an appropriate height. Place your hands on the Stange, with your hands wider than Schulter width. Position your feet Rücken from the Stange with arms and body straight. Your arms should be perpendicular to the body. This will be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Internal Rotation with Band',
    description: 'Choke the band around a post. The band should be at the same height as your elbow. Stand with your right side to the band a couple of feet away. Grasp the end of the band with your right hand, and keep your elbow pressed firmly to your side. We recommend you hold a pad or foam roll in place with your elbow to keep it firmly in position. With your upper arm in position, your elbow should be flexed...',
    nameDe: 'Internal Rotation mit Band',
    descriptionDe: 'Choke the Band around a post. The Band should be at the same height as your elbow. Stand with your right side to the Band a couple of feet away. Grasp the end of the Band with your right hand, and keep your elbow pressed firmly to your side. We recommend you hold a pad or Schaumstoffrolle in place...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Inverted Row',
    description: 'Position a bar in a rack to about waist height. You can also use a smith machine. Take a wider than shoulder width grip on the bar and position yourself hanging underneath the bar. Your body should be straight with your heels on the ground with your arms fully extended. This will be your starting position. Begin by flexing the elbow, pulling your chest towards the bar. Retract your shoulder...',
    nameDe: 'Umgekehrtes Rudern',
    descriptionDe: 'Position a Stange in a Ständer to about waist height. You can also use a Smith-Maschine. Take a wider than Schulter width grip on the Stange and position yourself hanging underneath the Stange. Your body should be straight with your heels on the ground with your arms fully extended. This will be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Inverted Row with Straps',
    description: 'Hang a rope or suspension straps from a rack or other stable object. Grasp the ends and position yourself in a supine position hanging from the ropes. Your body should be straight with your heels on the ground with your arms fully extended. This will be your starting position. Begin by flexing the elbow, pulling your chest to your hands. Retract your shoulder blades as you perform the movement....',
    nameDe: 'Inverted Rudern with Straps',
    descriptionDe: 'Hang a Seil or Schlingentrainer straps from a Ständer or other stable object. Grasp the ends and position yourself in a Rückenlage position hanging from the ropes. Your body should be straight with your heels on the ground with your arms fully extended. This will be your starting position. Begin by...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Iron Cross',
    nameDe: 'Eisernes Kreuz',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Isometric Neck Exercise - Front And Back',
    description: 'With your head and neck in a neutral position (normal position with head erect facing forward), place both of your hands on the front side of your head. Now gently push forward as you contract the neck muscles but resisting any movement of your head. Start with slow tension and increase slowly. Keep breathing normally as you execute this contraction. Hold for the recommended number of seconds....',
    nameDe: 'Isometrisch Nacken Exercise - Front And Rücken',
    descriptionDe: 'With your Kopf and Nacken in a neutral position (normal position with Kopf erect facing forward), place both of your hands on the front side of your Kopf. Now gently push forward as you contract the Nacken muscles but resisting any movement of your Kopf. Start with Langsam tension and increase...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.fullBody],
  ),

  Exercise(
    name: 'Isometric Neck Exercise - Sides',
    description: 'With your head and neck in a neutral position (normal position with head erect facing forward), place your left hand on the left side of your head. Now gently push towards the left as you contract the left neck muscles but resisting any movement of your head. Start with slow tension and increase slowly. Keep breathing normally as you execute this contraction. Hold for the recommended number of...',
    nameDe: 'Isometrisch Nacken Exercise - Sides',
    descriptionDe: 'With your Kopf and Nacken in a neutral position (normal position with Kopf erect facing forward), place your left hand on the left side of your Kopf. Now gently push towards the left as you contract the left Nacken muscles but resisting any movement of your Kopf. Start with Langsam tension and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.fullBody],
  ),

  Exercise(
    name: 'Isometric Wipers',
    description: 'Assume a push-up position, supporting your weight on your hands and toes while keeping your body straight. Your hands should be just outside of shoulder width. This will be your starting position. Begin by shifting your body weight as far to one side as possible, allowing the elbow on that side to flex as you lower your body. Reverse the motion by extending the flexed arm, pushing yourself up and...',
    nameDe: 'Isometrisch Wipers',
    descriptionDe: 'Assume a Liegestütz position, supporting your weight on your hands and toes while keeping your body straight. Your hands should be just outside of Schulter width. This will be your starting position. Begin by shifting your body weight as far to one side as possible, allowing the elbow on that side...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'JM Press',
    description: 'Start the exercise the same way you would a close grip bench press. You will lie on a flat bench while holding a barbell at arms length (fully extended) with the elbows in. However, instead of having the arms perpendicular to the torso, make sure the bar is set in a direct line above the upper chest. This will be your starting position. Now beginning from a fully extended position lower the bar...',
    nameDe: 'JM Drücken',
    descriptionDe: 'Start the exercise the same way you would a Enger Griff Bank Drücken. You will lie on a Flachbank Bank while holding a Langhantel at arms length (fully extended) with the elbows in. However, instead of having the arms perpendicular to the torso, make sure the Stange is set in a direct line above...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Jackknife Sit-Up',
    description: 'Lie flat on the floor (or exercise mat) on your back with your arms extended straight back behind your head and your legs extended also. This will be your starting position. As you exhale, bend at the waist while simultaneously raising your legs and arms to meet in a jackknife position. Tip: The legs should be extended and lifted at approximately a 35-45 degree angle from the floor and the arms...',
    nameDe: 'Jackknife Sit-Up',
    descriptionDe: 'Lie Flachbank on the Boden (or exercise mat) on your Rücken with your arms extended straight Rücken behind your Kopf and your legs extended also. This will be your starting position. As you exhale, bend at the waist while simultaneously raising your legs and arms to meet in a jackknife position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Janda Sit-Up',
    description: 'Position your body on the floor in the basic sit-up position; knees to a ninety degree angle with feet flat on the floor and arms either crossed over your chest or to the sides. This will be your starting position. As you strongly tighten your glutes and hamstrings, fill your lungs with air and in a slow (three to six second count) ascent, slowly exhale. Tip: It is important to tighten the glutes...',
    nameDe: 'Janda Sit-Up',
    descriptionDe: 'Position your body on the Boden in the basic Sit-Up position; knees to a ninety degree angle with feet Flachbank on the Boden and arms either crossed over your Brust or to the sides. This will be your starting position. As you strongly tighten your Gesäß and Oberschenkelrückseite, fill your lungs...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Jefferson Squats',
    description: 'Place a barbell on the floor. Stand in the middle of the bar length wise. Bend down by bending at the knees and keeping your back straight and grasp the front of the bar with your right hand. Your palm should be in (neutral grip) facing the left side. Grasp the rear of the bar with your left hand. The palm of your hand should be in neutral grip alignment (palms facing the right side). Tip: Ensure...',
    nameDe: 'Jefferson Squats',
    descriptionDe: 'Place a Langhantel on the Boden. Stand in the middle of the Stange length wise. Bend down by bending at the knees and keeping your Rücken straight and grasp the front of the Stange with your right hand. Your palm should be in (Neutralgriff) facing the left side. Grasp the rear of the Stange with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kettlebell Arnold Press',
    description: 'Clean a kettlebell to your shoulder. Clean the kettlebell to your shoulder by extending through the legs and hips as you raise the kettlebell towards your shoulder. The palm should be facing inward. Looking straight ahead, press the kettlebell out and overhead, rotating your wrist so that your palm faces forward at the top of the motion. Return the kettlebell to the starting position, with the...',
    nameDe: 'Kettlebell Arnold Drücken',
    descriptionDe: 'Stoßen a Kettlebell to your Schulter. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you Heben the Kettlebell towards your Schulter. The palm should be facing inward. Looking straight ahead, Drücken the Kettlebell out and Überkopf, rotating your Handgelenk so...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Kettlebell Dead Clean',
    description: 'Place kettlebell between your feet. To get in the starting position, push your butt back and look straight ahead. Clean the kettlebell to your shoulder. Clean the kettlebell to your shoulders by extending through the legs and hips as you raise the kettlebell towards your shoulder. The wrist should rotate as you do so. Lower the kettlebell, keeping the hamstrings loaded by keeping your back...',
    nameDe: 'Kettlebell Dead Stoßen',
    descriptionDe: 'Place Kettlebell between your feet. To get in the starting position, push your butt Rücken and look straight ahead. Stoßen the Kettlebell to your Schulter. Stoßen the Kettlebell to your Schultern by extending through the legs and Hüften as you Heben the Kettlebell towards your Schulter. The...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kettlebell Figure 8',
    description: 'Place one kettlebell between your legs and take a wider than shoulder width stance. Bend over by pushing your butt out and keeping your back flat. Pick up a kettlebell and pass it to your other hand between your legs. The receiving hand should reach from behind the legs. Go back and forth for several repetitions.',
    nameDe: 'Kettlebell Figure 8',
    descriptionDe: 'Place one Kettlebell between your legs and take a wider than Schulter width stance. Bend over by pushing your butt out and keeping your Rücken Flachbank. Pick up a Kettlebell and pass it to your other hand between your legs. The receiving hand should reach from behind the legs. Go Rücken and forth...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Kettlebell Hang Clean',
    description: 'Place kettlebell between your feet. To get in the starting position, push your butt back and look straight ahead. Clean kettlebell to your shoulder. Clean the kettlebell to your shoulders by extending through the legs and hips as you raise the kettlebell towards your shoulder. The wrist should rotate as you do so. Lower kettlebell to a hanging position between your legs while keeping the...',
    nameDe: 'Kettlebell Hang-Stoßen',
    descriptionDe: 'Place Kettlebell between your feet. To get in the starting position, push your butt Rücken and look straight ahead. Stoßen Kettlebell to your Schulter. Stoßen the Kettlebell to your Schultern by extending through the legs and Hüften as you Heben the Kettlebell towards your Schulter. The Handgelenk...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kettlebell One-Legged Deadlift',
    description: 'Hold a kettlebell by the handle in one hand. Stand on one leg, on the same side that you hold the kettlebell. Keeping that knee slightly bent, perform a stiff legged deadlift by bending at the hip, extending your free leg behind you for balance. Continue lowering the kettlebell until you are parallel to the ground, and then return to the upright position.',
    nameDe: 'Kettlebell One-Legged Kreuzheben',
    descriptionDe: 'Hold a Kettlebell by the handle in one hand. Stand on one leg, on the same side that you hold the Kettlebell. Keeping that Knie slightly bent, perform a stiff legged Kreuzheben by bending at the Hüfte, extending your free leg behind you for balance. Continue lowering the Kettlebell until you are...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kettlebell Pass Between The Legs',
    description: 'Place one kettlebell between your legs and take a comfortable stance. Bend over by pushing your butt out and keeping your back flat. Pick up a kettlebell and pass it to your other hand between your legs, in the fashion of a "W". Go back and forth for several repetitions.',
    nameDe: 'Kettlebell Pass Between The Legs',
    descriptionDe: 'Place one Kettlebell between your legs and take a comfortable stance. Bend over by pushing your butt out and keeping your Rücken Flachbank. Pick up a Kettlebell and pass it to your other hand between your legs, in the fashion of a "W". Go Rücken and forth for several repetitions.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Kettlebell Pirate Ships',
    description: 'With a wide stance, hold a kettlebell with both hands. Allow it to hang at waist level with your arms extended. This will be your starting position. Initiate the movement by turning to one side, swinging the kettlebell to head height. Briefly pause at the top of the motion. Allow the bell to drop as you rotate to the opposite side, again raising the kettlebell to head height. Repeat for the...',
    nameDe: 'Kettlebell Pirate Ships',
    descriptionDe: 'With a wide stance, hold a Kettlebell with both hands. Allow it to hang at waist level with your arms extended. This will be your starting position. Initiate the movement by turning to one side, swinging the Kettlebell to Kopf height. Briefly Pause at the top of the motion. Allow the bell to drop...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Kettlebell Pistol Squat',
    description: 'Pick up a kettlebell with two hands and hold it by the horns. Hold one leg off of the floor and squat down on the other. Squat down by flexing the knee and sitting back with the hips, holding the kettlebell up in front of you. Hold the bottom position for a second and then reverse the motion, driving through the heel and keeping your head and chest up. Lower yourself again and repeat.',
    nameDe: 'Kettlebell Pistol Kniebeuge',
    descriptionDe: 'Pick up a Kettlebell with two hands and hold it by the horns. Hold one leg off of the Boden and Kniebeuge down on the other. Kniebeuge down by flexing the Knie and sitting Rücken with the Hüften, holding the Kettlebell up in front of you. Hold the bottom position for a second and then Umgekehrt the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kettlebell Seated Press',
    description: 'Sit on the floor and spread your legs out comfortably. Clean one kettlebell to your shoulder. Press the kettlebell up and out until it is locked out overhead. Return to the starting position.',
    nameDe: 'Kettlebell Sitzend Drücken',
    descriptionDe: 'Sit on the Boden and spread your legs out comfortably. Stoßen one Kettlebell to your Schulter. Drücken the Kettlebell up and out until it is locked out Überkopf. Return to the starting position.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Kettlebell Seesaw Press',
    description: 'Clean two kettlebells two your shoulders. Press one kettlebell. Lower the kettlebell and immediately press the other kettlebell. Make sure to do the same amount of reps on both sides.',
    nameDe: 'Kettlebell Seesaw Drücken',
    descriptionDe: 'Stoßen two Kettlebells two your Schultern. Drücken one Kettlebell. Unterer the Kettlebell and immediately Drücken the other Kettlebell. Make sure to do the same amount of reps on both sides.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Kettlebell Sumo High Pull',
    description: 'Place a kettlebell on the ground between your feet. Position your feet in a wide stance, and grasp the kettlebell with two hands. Set your hips back as far as possible, with your knees bent. Keep your chest and head up. This will be your starting position. Begin by extending the hips and knees, simultaneously pulling the kettlebell to your shoulders, raising your elbows as you do so. Reverse the...',
    nameDe: 'Kettlebell Sumo High Pull',
    descriptionDe: 'Place a Kettlebell on the ground between your feet. Position your feet in a wide stance, and grasp the Kettlebell with two hands. Set your Hüften Rücken as far as possible, with your knees bent. Keep your Brust and Kopf up. This will be your starting position. Begin by extending the Hüften and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Kettlebell Thruster',
    description: 'Clean two kettlebells to your shoulders. Clean the kettlebells to your shoulders by extending through the legs and hips as you pull the kettlebells towards your shoulders. Rotate your wrists as you do so. This will be your starting position. Begin to squat by flexing your hips and knees, lowering your hips between your legs. Maintain an upright, straight back as you descend as low as you can. At...',
    nameDe: 'Kettlebell Thruster',
    descriptionDe: 'Stoßen two Kettlebells to your Schultern. Stoßen the Kettlebells to your Schultern by extending through the legs and Hüften as you pull the Kettlebells towards your Schultern. Rotate your wrists as you do so. This will be your starting position. Begin to Kniebeuge by flexing your Hüften and knees,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Kettlebell Turkish Get-Up (Lunge style)',
    description: 'Lie on your back on the floor and press a kettlebell to the top position by extending the elbow. Bend the knee on the same side as the kettlebell. Keeping the kettlebell locked out at all times, pivot to the opposite side and use your non- working arm to assist you in driving forward to the lunge position. Using your free hand, push yourself to a seated position, then progressing to one knee....',
    nameDe: 'Kettlebell Türkisches Aufstehen (Ausfallschritt style)',
    descriptionDe: 'Lie on your Rücken on the Boden and Drücken a Kettlebell to the top position by extending the elbow. Bend the Knie on the same side as the Kettlebell. Keeping the Kettlebell locked out at all times, pivot to the opposite side and use your non- working arm to assist you in driving forward to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Kettlebell Turkish Get-Up (Squat style)',
    description: 'Lie on your back on the floor and press a kettlebell to the top position by extending the elbow. Bend the knee on the same side as the kettlebell. Keeping the kettlebell locked out at all times, pivot to the opposite side and use your non- working arm to assist you in driving forward to the lunge position. Using your free hand, push yourself to a seated position, then progressing to your feet....',
    nameDe: 'Kettlebell Türkisches Aufstehen (Kniebeuge style)',
    descriptionDe: 'Lie on your Rücken on the Boden and Drücken a Kettlebell to the top position by extending the elbow. Bend the Knie on the same side as the Kettlebell. Keeping the Kettlebell locked out at all times, pivot to the opposite side and use your non- working arm to assist you in driving forward to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Kettlebell Windmill',
    description: 'Place a kettlebell in front of your lead foot and clean and press it overhead with your opposite arm. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulders. Rotate your wrist as you do so, so that the palm faces forward. Press it overhead by extending the elbow. Keeping the kettlebell locked out at all times, push your butt...',
    nameDe: 'Kettlebell Windmühle',
    descriptionDe: 'Place a Kettlebell in front of your lead foot and Stoßen and Drücken it Überkopf with your opposite arm. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schultern. Rotate your Handgelenk as you do so, so that the palm faces...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Kipping Muscle Up',
    description: 'Grip the rings using a false grip, with the base of your palms on top of the rings. Begin with a movement swinging your legs backward slightly. Counter that movement by swinging your legs forward and up, jerking your chin and chest back, pulling yourself up with both arms as you do so. As you reach the top position of the pull-up, pull the rings to your armpits as you roll your shoulders forward,...',
    nameDe: 'Kipping Muscle-Up',
    descriptionDe: 'Grip the Turnringe using a false grip, with the base of your palms on top of the Turnringe. Begin with a movement swinging your legs backward slightly. Counter that movement by swinging your legs forward and up, jerking your chin and Brust Rücken, pulling yourself up with both arms as you do so. As...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Knee/Hip Raise On Parallel Bars',
    description: 'Position your body on the vertical leg raise bench so that your forearms are resting on the pads next to the torso and holding on to the handles. Your arms will be bent at a 90 degree angle. The torso should be straight with the lower back pressed against the pad of the machine and the legs extended pointing towards the floor. This will be your starting position. Now as you breathe out, lift your...',
    nameDe: 'Knie/Hüfte Heben On Parallel Bars',
    descriptionDe: 'Position your body on the Vertikal leg Heben Bank so that your Unterarme are resting on the pads next to the torso and holding on to the handles. Your arms will be bent at a 90 degree angle. The torso should be straight with the Unterer Rücken pressed against the pad of the Maschine and the legs...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Kneeling Cable Crunch With Alternating Oblique Twists',
    description: 'Connect a rope attachment to a high pulley cable and position a mat on the floor in front of it. Grab the rope with both hands and kneel approximately two feet back from the tower. Position the rope behind your head with your hands by your ears. Keep your hands in the same place, contract your abs and pull downward on the rope in a crunching movement until your elbows reach your knees. Pause...',
    nameDe: 'Kniend Kabelzug Crunch With Alternierend Schräger Bauchmuskel Twists',
    descriptionDe: 'Connect a Seil attachment to a high pulley Kabelzug and position a mat on the Boden in front of it. Grab the Seil with both hands and kneel approximately two feet Rücken from the tower. Position the Seil behind your Kopf with your hands by your ears. Keep your hands in the same place, contract your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Kneeling Cable Triceps Extension',
    description: 'Place a bench sideways in front of a high pulley machine. Hold a straight bar attachment above your head with your hands about 6 inches apart with your palms facing down. Face away from the machine and kneel. Place your head and the back of your upper arms on the bench. Your elbows should be bent with the forearms pointing towards the high pulley. This will be your starting position. While...',
    nameDe: 'Kniend Kabelzug Trizepsstreckung',
    descriptionDe: 'Place a Bank sideways in front of a high pulley Maschine. Hold a straight Stange attachment above your Kopf with your hands about 6 inches apart with your palms facing down. Face away from the Maschine and kneel. Place your Kopf and the Rücken of your Oberer arms on the Bank. Your elbows should be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Kneeling High Pulley Row',
    description: 'Select the appropriate weight using a pulley that is above your head. Attach a rope to the cable and kneel a couple of feet away, holding the rope out in front of you with both arms extended. This will be your starting position. Initiate the movement by flexing the elbows and fully retracting your shoulders, pulling the rope toward your upper chest with your elbows out. After pausing briefly,...',
    nameDe: 'Kniend High Pulley Rudern',
    descriptionDe: 'Select the appropriate weight using a pulley that is above your Kopf. Attach a Seil to the Kabelzug and kneel a couple of feet away, holding the Seil out in front of you with both arms extended. This will be your starting position. Initiate the movement by flexing the elbows and fully retracting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Kneeling Single-Arm High Pulley Row',
    description: 'Attach a single handle to a high pulley and make your weight selection. Kneel in front of the cable tower, taking the cable with one hand with your arm extended. This will be your starting position. Starting with your palm facing forward, pull the weight down to your torso by flexing the elbow and retract the shoulder blade. As you do so, rotate the wrist so that at the completion of the...',
    nameDe: 'Kniend Einarmig High Pulley Rudern',
    descriptionDe: 'Attach a single handle to a high pulley and make your weight selection. Kneel in front of the Kabelzug tower, taking the Kabelzug with one hand with your arm extended. This will be your starting position. Starting with your palm facing forward, pull the weight down to your torso by flexing the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Landmine 180\'s',
    description: 'Position a bar into a landmine or securely anchor it in a corner. Load the bar to an appropriate weight. Raise the bar from the floor, taking it to shoulder height with both hands with your arms extended in front of you. Adopt a wide stance. This will be your starting position. Perform the movement by rotating the trunk and hips as you swing the weight all the way down to one side. Keep your arms...',
    nameDe: 'Landmine 180\'s',
    descriptionDe: 'Position a Stange into a landmine or securely anchor it in a corner. Load the Stange to an appropriate weight. Heben the Stange from the Boden, taking it to Schulter height with both hands with your arms extended in front of you. Adopt a wide stance. This will be your starting position. Perform the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Landmine Linear Jammer',
    description: 'Position a bar into landmine or, lacking one, securely anchor it in a corner. Load the bar to an appropriate weight and position the handle attachment on the bar. Raise the bar from the floor, taking the handles to your shoulders. This will be your starting position. In an athletic stance, squat by flexing your hips and setting your hips back, keeping your arms flexed. Reverse the motion by...',
    nameDe: 'Landmine Linear Jammer',
    descriptionDe: 'Position a Stange into landmine or, lacking one, securely anchor it in a corner. Load the Stange to an appropriate weight and position the handle attachment on the Stange. Heben the Stange from the Boden, taking the handles to your Schultern. This will be your starting position. In an athletic...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Lateral Raise - With Bands',
    description: 'To begin, stand on an exercise band so that tension begins at arm\'s length. Grasp the handles using a pronated (palms facing your thighs) grip that is slightly less than shoulder width. The handles should be resting on the sides of your thighs. Your arms should be extended with a slight bend at the elbows and your back should be straight. This will be your starting position. Use your side...',
    nameDe: 'Seitlich Heben - mit Band',
    descriptionDe: 'To begin, stand on an exercise Band so that tension begins at arm\'s length. Grasp the handles using a Proniert (palms facing your thighs) grip that is slightly less than Schulter width. The handles should be resting on the sides of your thighs. Your arms should be extended with a slight bend at the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Leg-Over Floor Press',
    description: 'Lie on the floor with one kettlebell in place on your chest, holding it by the handle. Extend leg on working side over leg on non-working side.Your free arm can be extended out to your side for support. Press the kettlebll into a locked out position. Lower the weight until the elbow touches the ground, keeping the kettlebell above the elbow. Repeat for the desired number of repetitions.',
    nameDe: 'Leg-Over Boden Drücken',
    descriptionDe: 'Lie on the Boden with one Kettlebell in place on your Brust, holding it by the handle. Extend leg on working side over leg on non-working side.Your free arm can be extended out to your side for support. Drücken the kettlebll into a locked out position. Unterer the weight until the elbow touches the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Leg Extensions',
    description: 'For this exercise you will need to use a leg extension machine. First choose your weight and sit on the machine with your legs under the pad (feet pointed forward) and the hands holding the side bars. This will be your starting position. Tip: You will need to adjust the pad so that it falls on top of your lower leg (just above your feet). Also, make sure that your legs form a 90-degree angle...',
    nameDe: 'Leg Extensions',
    descriptionDe: 'For this exercise you will need to use a leg Streckung Maschine. First choose your weight and sit on the Maschine with your legs under the pad (feet pointed forward) and the hands holding the side bars. This will be your starting position. Tip: You will need to adjust the pad so that it falls on...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Leg Lift',
    description: 'While standing up straight with both feet next to each other at around shoulder width, grab a sturdy surface such as the sides of a squat rack or the top of a chair to brace yourself and keep balance. With or without an ankle weight, lift one leg behind you as if performing a leg curl but standing up while keeping the other leg straight. Breathe out as you perform this movement. Slowly bring the...',
    nameDe: 'Leg Lift',
    descriptionDe: 'While Stehend up straight with both feet next to each other at around Schulter width, grab a sturdy surface such as the sides of a Kniebeuge Ständer or the top of a Stuhl to brace yourself and keep balance. With or without an Knöchel weight, lift one leg behind you as if performing a Beincurl but...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Leg Press',
    description: 'Using a leg press machine, sit down on the machine and place your legs on the platform directly in front of you at a medium (shoulder width) foot stance. (Note: For the purposes of this discussion we will use the medium stance described above which targets overall development; however you can choose any of the three stances described in the foot positioning section). Lower the safety bars holding...',
    nameDe: 'Beinpresse',
    descriptionDe: 'Using a Beinpresse Maschine, sit down on the Maschine and place your legs on the platform directly in front of you at a medium (Schulter width) foot stance. (Note: For the purposes of this discussion we will use the medium stance described above which targets overall development; however you can...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Leg Pull-In',
    description: 'Lie on an exercise mat with your legs extended and your hands either palms facing down next to you or under your glutes. Tip: My preference is with the hands next to me. This will be your starting position. Bend your knees and pull your upper thighs into your midsection as you breathe out. Continue the motion until your knees are around chest level. Contract your abs as you execute this movement...',
    nameDe: 'Leg Pull-In',
    descriptionDe: 'Lie on an exercise mat with your legs extended and your hands either palms facing down next to you or under your Gesäß. Tip: My preference is with the hands next to me. This will be your starting position. Bend your knees and pull your Oberer thighs into your midsection as you breathe out. Continue...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Leverage Chest Press',
    description: 'Load an appropriate weight onto the pins and adjust the seat for your height. The handles should be near the bottom or middle of the pectorals at the beginning of the motion. Your chest and head should be up and your shoulder blades retracted. This will be your starting position. Press the handles forward by extending through the elbow. After a brief pause at the top, return the weight just above...',
    nameDe: 'Leverage Brustdrücken',
    descriptionDe: 'Load an appropriate weight onto the pins and adjust the seat for your height. The handles should be near the bottom or middle of the Brustmuskeln at the beginning of the motion. Your Brust and Kopf should be up and your Schulter blades retracted. This will be your starting position. Drücken the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Leverage Deadlift',
    description: 'Load the pins to an appropriate weight. Position yourself directly between the handles. Grasp the bottom handles with a comfortable grip, and then lower your hips as you take a breath. Look forward with your head and keep your chest up. This will be your starting position. Return the weight to the starting position.',
    nameDe: 'Leverage Kreuzheben',
    descriptionDe: 'Load the pins to an appropriate weight. Position yourself directly between the handles. Grasp the bottom handles with a comfortable grip, and then Unterer your Hüften as you take a breath. Look forward with your Kopf and keep your Brust up. This will be your starting position. Return the weight to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Leverage Decline Chest Press',
    description: 'Load an appropriate weight onto the pins and adjust the seat for your height. The handles should be near the bottom of the pectorals at the beginning of the motion. Your chest and head should be up and your shoulder blades retracted. This will be your starting position. Press the handles forward by extending through the elbow. After a brief pause at the top, return the weight just above the start...',
    nameDe: 'Leverage Negativbank Brustdrücken',
    descriptionDe: 'Load an appropriate weight onto the pins and adjust the seat for your height. The handles should be near the bottom of the Brustmuskeln at the beginning of the motion. Your Brust and Kopf should be up and your Schulter blades retracted. This will be your starting position. Drücken the handles...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Leverage High Row',
    description: 'Load an appropriate weight onto the pins and adjust the seat height so that you can just reach the handles above you. Adjust the knee pad to help keep you down. Grasp the handles with a pronated grip. This will be your starting position. Pull the handles towards your torso, retracting your shoulder blades as you flex the elbow. Pause at the bottom of the motion, and then slowly return the handles...',
    nameDe: 'Leverage High Rudern',
    descriptionDe: 'Load an appropriate weight onto the pins and adjust the seat height so that you can just reach the handles above you. Adjust the Knie pad to help keep you down. Grasp the handles with a Proniert grip. This will be your starting position. Pull the handles towards your torso, retracting your Schulter...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Leverage Incline Chest Press',
    description: 'Load an appropriate weight onto the pins and adjust the seat for your height. The handles should be near the top of the pectorals at the beginning of the motion. Your chest and head should be up and your shoulder blades retracted. This will be your starting position. Press the handles forward by extending through the elbow. After a brief pause at the top, return the weight just above the start...',
    nameDe: 'Leverage Schrägbank Brustdrücken',
    descriptionDe: 'Load an appropriate weight onto the pins and adjust the seat for your height. The handles should be near the top of the Brustmuskeln at the beginning of the motion. Your Brust and Kopf should be up and your Schulter blades retracted. This will be your starting position. Drücken the handles forward...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Leverage Iso Row',
    description: 'Load an appropriate weight onto the pins and adjust the seat height so that the handles are at chest level. Grasp the handles with either a neutral or pronated grip. This will be your starting position. Pull the handles towards your torso, retracting your shoulder blades as you flex the elbow. Pause at the bottom of the motion, and then slowly return the handles to the starting position. For...',
    nameDe: 'Leverage Iso Rudern',
    descriptionDe: 'Load an appropriate weight onto the pins and adjust the seat height so that the handles are at Brust level. Grasp the handles with either a neutral or Proniert grip. This will be your starting position. Pull the handles towards your torso, retracting your Schulter blades as you flex the elbow....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Leverage Shoulder Press',
    description: 'Load an appropriate weight onto the pins and adjust the seat for your height. The handles should be near the top of the shoulders at the beginning of the motion. Your chest and head should be up and handles held with a pronated grip. This will be your starting position. Press the handles upward by extending through the elbow. After a brief pause at the top, return the weight to just above the...',
    nameDe: 'Leverage Schulterdrücken',
    descriptionDe: 'Load an appropriate weight onto the pins and adjust the seat for your height. The handles should be near the top of the Schultern at the beginning of the motion. Your Brust and Kopf should be up and handles held with a Proniert grip. This will be your starting position. Drücken the handles upward...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Leverage Shrug',
    description: 'Load the pins to an appropriate weight. Position yourself directly between the handles. Grasp the top handles with a comfortable grip, and then lower your hips as you take a breath. Look forward with your head and keep your chest up. Drive through the floor with your heels, extending your hips and knees as you rise to a standing position. Keep your arms straight throughout the movement, finishing...',
    nameDe: 'Leverage Schulterziehen',
    descriptionDe: 'Load the pins to an appropriate weight. Position yourself directly between the handles. Grasp the top handles with a comfortable grip, and then Unterer your Hüften as you take a breath. Look forward with your Kopf and keep your Brust up. Drive through the Boden with your heels, extending your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'London Bridges',
    description: 'Attach a climbing rope to a high beam or cross member. Below it, ensure that the smith machine bar is locked in place with the safeties and cannot move. Alternatively, a secure box could also be utilized. Stand on the bar, using the rope to balance yourself. This will be your starting position. Keeping your body straight, lean back and lower your body by slowly going hand over hand with the rope....',
    nameDe: 'London Bridges',
    descriptionDe: 'Attach a climbing Seil to a high beam or Überkreuz member. Below it, ensure that the Smith-Maschine Stange is locked in place with the safeties and cannot move. Alternatively, a secure Box could also be utilized. Stand on the Stange, using the Seil to balance yourself. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Low Cable Crossover',
    description: 'To move into the starting position, place the pulleys at the low position, select the resistance to be used and grasp a handle in each hand. Step forward, gaining tension in the pulleys. Your palms should be facing forward, hands below the waist, and your arms straight. This will be your starting position. With a slight bend in your arms, draw your hands upward and toward the midline of your...',
    nameDe: 'Low Kabelzug Crossover',
    descriptionDe: 'To move into the starting position, place the pulleys at the low position, select the resistance to be used and grasp a handle in each hand. Stufe forward, gaining tension in the pulleys. Your palms should be facing forward, hands below the waist, and your arms straight. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Low Cable Triceps Extension',
    description: 'Select the desired weight and lay down face up on the bench of a seated row machine that has a rope attached to it. Your head should be pointing towards the attachment. Grab the outside of the rope ends with your palms facing each other (neutral grip). Position your elbows so that they are bent at a 90 degree angle and your upper arms are perpendicular (90 degree angle) to your torso. Tip: Keep...',
    nameDe: 'Low Kabelzug Trizepsstreckung',
    descriptionDe: 'Select the desired weight and lay down face up on the Bank of a Sitzrudern Maschine that has a Seil attached to it. Your Kopf should be pointing towards the attachment. Grab the outside of the Seil ends with your palms facing each other (Neutralgriff). Position your elbows so that they are bent at...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Low Pulley Row To Neck',
    description: 'Sit on a low pulley row machine with a rope attachment. Grab the ends of the rope using a palms-down grip and sit with your back straight and your knees slightly bent. Tip: Keep your back almost completely vertical and your arms fully extended in front of you. This will be your starting position. While keeping your torso stationary, lift your elbows and start bending them as you pull the rope...',
    nameDe: 'Low Pulley Rudern To Nacken',
    descriptionDe: 'Sit on a low pulley Rudern Maschine with a Seil attachment. Grab the ends of the Seil using a palms-down grip and sit with your Rücken straight and your knees slightly bent. Tip: Keep your Rücken almost completely Vertikal and your arms fully extended in front of you. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Lunge Pass Through',
    description: 'Stand with your torso upright holding a kettlebell in your right hand. This will be your starting position. Step forward with your left foot and lower your upper body down by flexing the hip and the knee, keeping the torso upright. Lower your back knee until it nearly touches the ground. As you lunge, pass the kettlebell under your front leg to your opposite hand. Pressing through the heel of...',
    nameDe: 'Ausfallschritt Pass Through',
    descriptionDe: 'Stand with your torso Aufrecht holding a Kettlebell in your right hand. This will be your starting position. Stufe forward with your left foot and Unterer your Oberer body down by flexing the Hüfte and the Knie, keeping the torso Aufrecht. Unterer your Rücken Knie until it nearly touches the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lunge Sprint',
    description: 'Adjust a bar in a Smith machine to an appropriate height. Position yourself under the bar, racking it across the back of your shoulders. Unrack the bar, and then split your feet, moving one foot forward and one foot back. This will be your starting position. Lower your back knee nearly to the ground, flexing the knees and lowering your hips as you do so. At the bottom of the descent, immediately...',
    nameDe: 'Ausfallschritt Sprint',
    descriptionDe: 'Adjust a Stange in a Smith-Maschine to an appropriate height. Position yourself under the Stange, racking it across the Rücken of your Schultern. Unrack the Stange, and then split your feet, moving one foot forward and one foot Rücken. This will be your starting position. Unterer your Rücken Knie...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lying Cable Curl',
    description: 'Grab a straight bar or E-Z bar attachment that is attached to the low pulley with both hands, using an underhand (palms facing up) shoulder-width grip. Lie flat on your back on top of an exercise mat in front of the weight stack with your feet flat against the frame of the pulley machine and your legs straight. With your arms extended and your elbows close to your body slightly bend your arms....',
    nameDe: 'Liegend Kabelzug Curl',
    descriptionDe: 'Grab a straight Stange or E-Z Stange attachment that is attached to the low pulley with both hands, using an Untergriff (palms facing up) Schulter-width grip. Lie Flachbank on your Rücken on top of an exercise mat in front of the weight stack with your feet Flachbank against the frame of the pulley...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Lying Cambered Barbell Row',
    description: 'Place a cambered bar underneath an exercise bench. Lie face down on the exercise bench and grab the bar using a palms down (pronated grip) that is wider than shoulder width. This will be your starting position. As you exhale row the bar up as you keep the elbows close to your body to either your chest, in order to target the upper mid back, or to your stomach if targeting the lats is your goal....',
    nameDe: 'Liegend Cambered Langhantel Rudern',
    descriptionDe: 'Place a cambered Stange underneath an exercise Bank. Lie face down on the exercise Bank and grab the Stange using a palms down (Proniert grip) that is wider than Schulter width. This will be your starting position. As you exhale Rudern the Stange up as you keep the elbows close to your body to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Lying Close-Grip Bar Curl On High Pulley',
    description: 'Place a flat bench in front of a high pulley or lat pulldown machine. Hold the straight bar attachment using an underhand grip (palms up) that is about shoulder width. Lie on your back with your head over the end of the bench. Now extend your arms straight above your shoulders. Your torso and your arms should make a 90-degree angle and the elbows should be in. This will be your starting position....',
    nameDe: 'Liegend Enger Griff Stange Curl On High Pulley',
    descriptionDe: 'Place a Flachbank Bank in front of a high pulley or Lat Latzug Maschine. Hold the straight Stange attachment using an Untergriff grip (palms up) that is about Schulter width. Lie on your Rücken with your Kopf over the end of the Bank. Now extend your arms straight above your Schultern. Your torso...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Lying Close-Grip Barbell Triceps Extension Behind The Head',
    description: 'While holding a barbell or EZ Curl bar with a pronated grip (palms facing forward), lie on your back on a flat bench with your head close to the end of the bench. Tip: If you are holding a barbell grab it using a shoulder-width grip and if you are using an E-Z Bar grab it on the inner handles. Extend your arms in front of you and slowly bring the bar back in a semi circular motion (while keeping...',
    nameDe: 'Liegend Enger Griff Langhantel Trizepsstreckung Behind The Kopf',
    descriptionDe: 'While holding a Langhantel or EZ Curl Stange with a Proniert grip (palms facing forward), lie on your Rücken on a Flachbank Bank with your Kopf close to the end of the Bank. Tip: If you are holding a Langhantel grab it using a Schulter-width grip and if you are using an E-Z Stange grab it on the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Lying Close-Grip Barbell Triceps Press To Chin',
    description: 'While holding a barbell or EZ Curl bar with a pronated grip (palms facing forward), lie on your back on a flat bench with your head off the end of the bench. Tip: If you are holding a barbell grab it using a shoulder-width grip and if you are using an E-Z Bar grab it on the inner handles. Extend your arms in front of you as you hold the barbell over your chest. The arms should be perpendicular to...',
    nameDe: 'Liegend Enger Griff Langhantel Trizeps Drücken To Chin',
    descriptionDe: 'While holding a Langhantel or EZ Curl Stange with a Proniert grip (palms facing forward), lie on your Rücken on a Flachbank Bank with your Kopf off the end of the Bank. Tip: If you are holding a Langhantel grab it using a Schulter-width grip and if you are using an E-Z Stange grab it on the Innen...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Lying Dumbbell Tricep Extension',
    description: 'Lie on a flat bench while holding two dumbbells directly in front of you. Your arms should be fully extended at a 90-degree angle from your torso and the floor. The palms should be facing in and the elbows should be tucked in. This is the starting position. As you breathe in and you keep the upper arms stationary with the elbows in, slowly lower the weight until the dumbbells are near your ears....',
    nameDe: 'Liegend Kurzhantel Trizepsstreckung',
    descriptionDe: 'Lie on a Flachbank Bank while holding two Kurzhanteln directly in front of you. Your arms should be fully extended at a 90-degree angle from your torso and the Boden. The palms should be facing in and the elbows should be tucked in. This is the starting position. As you breathe in and you keep the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Lying Face Down Plate Neck Resistance',
    description: 'Lie face down with your whole body straight on a flat bench while holding a weight plate behind your head. Tip: You will need to position yourself so that your shoulders are slightly above the end of a flat bench in order for the upper chest, neck and face to be off the bench. This will be your starting position. While keeping the plate secure on the back of your head slowly lower your head (as...',
    nameDe: 'Liegend Face Down Scheibe Nacken Resistance',
    descriptionDe: 'Lie face down with your whole body straight on a Flachbank Bank while holding a weight Scheibe behind your Kopf. Tip: You will need to position yourself so that your Schultern are slightly above the end of a Flachbank Bank in order for the Oberer Brust, Nacken and face to be off the Bank. This will...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.fullBody],
  ),

  Exercise(
    name: 'Lying Face Up Plate Neck Resistance',
    description: 'Lie face up with your whole body straight on a flat bench while holding a weight plate on top of your forehead. Tip: You will need to position yourself so that your shoulders are slightly above the end of a flat bench in order for the traps, neck and head to be off the bench. This will be your starting position. While keeping the plate secure on your forehead slowly lower your head back in a...',
    nameDe: 'Liegend Face Up Scheibe Nacken Resistance',
    descriptionDe: 'Lie face up with your whole body straight on a Flachbank Bank while holding a weight Scheibe on top of your forehead. Tip: You will need to position yourself so that your Schultern are slightly above the end of a Flachbank Bank in order for the Trapezmuskel, Nacken and Kopf to be off the Bank. This...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.fullBody],
  ),

  Exercise(
    name: 'Lying High Bench Barbell Curl',
    description: 'Lie face forward on a tall flat bench while holding a barbell with a supinated grip (palms facing up). Tip: If you are holding a barbell grab it using a shoulder-width grip and if you are using an E-Z Bar grab it on the inner handles. Your upper body should be positioned in a way that the upper chest is over the end of the bench and the barbell is hanging in front of you with the arms extended...',
    nameDe: 'Liegend High Bank Langhantel Curl',
    descriptionDe: 'Lie face forward on a tall Flachbank Bank while holding a Langhantel with a Supiniert grip (palms facing up). Tip: If you are holding a Langhantel grab it using a Schulter-width grip and if you are using an E-Z Stange grab it on the Innen handles. Your Oberer body should be positioned in a way that...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Lying Leg Curls',
    description: 'Adjust the machine lever to fit your height and lie face down on the leg curl machine with the pad of the lever on the back of your legs (just a few inches under the calves). Tip: Preferably use a leg curl machine that is angled as opposed to flat since an angled position is more favorable for hamstrings recruitment. Keeping the torso flat on the bench, ensure your legs are fully stretched and...',
    nameDe: 'Liegend Leg Curls',
    descriptionDe: 'Adjust the Maschine lever to fit your height and lie face down on the Beincurl Maschine with the pad of the lever on the Rücken of your legs (just a few inches under the Waden). Tip: Preferably use a Beincurl Maschine that is angled as opposed to Flachbank since an angled position is more favorable...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lying Machine Squat',
    description: 'Adjust the leg machine to a height that will allow you to get inside it with your knees bent and the thighs slightly below parallel. Once you select the weight, position yourself inside the machine face up with the knees bent and thighs slightly below parallel to the platform. Make sure that the knees do not go past the toes. The angle created between the hamstrings and the calves should be one...',
    nameDe: 'Liegend Maschine Kniebeuge',
    descriptionDe: 'Adjust the leg Maschine to a height that will allow you to get inside it with your knees bent and the thighs slightly below parallel. Once you select the weight, position yourself inside the Maschine face up with the knees bent and thighs slightly below parallel to the platform. Make sure that the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lying One-Arm Lateral Raise',
    description: 'While holding a dumbbell in one hand, lay with your chest down on a flat bench. The other hand can be used to hold to the leg of the bench for stability. Position the palm of the hand that is holding the dumbbell in a neutral manner (palms facing your torso) as you keep the arm extended with the elbow slightly bent. This will be your starting position. Now raise the arm with the dumbbell to the...',
    nameDe: 'Liegend Einarmig Seitlich Heben',
    descriptionDe: 'While holding a Kurzhantel in one hand, lay with your Brust down on a Flachbank Bank. The other hand can be used to hold to the leg of the Bank for stability. Position the palm of the hand that is holding the Kurzhantel in a neutral manner (palms facing your torso) as you keep the arm extended with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Lying Rear Delt Raise',
    description: 'While holding a dumbbell in each hand, lay with your chest down on a flat bench. Position the palms of the hands in a neutral manner (palms facing your torso) as you keep the arms extended with the elbows slightly bent. This will be your starting position. Now raise the arms to the side until your elbows are at shoulder height and your arms are roughly parallel to the floor as you exhale. Tip:...',
    nameDe: 'Liegend Rear Delt Heben',
    descriptionDe: 'While holding a Kurzhantel in each hand, lay with your Brust down on a Flachbank Bank. Position the palms of the hands in a neutral manner (palms facing your torso) as you keep the arms extended with the elbows slightly bent. This will be your starting position. Now Heben the arms to the side until...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Lying Supine Dumbbell Curl',
    description: 'Lie down on a flat bench face up while holding a dumbbell in each arm on top of your thighs. Bring the dumbbells to the sides with the arms extended and the palms of the hands facing your thighs (neutral grip). While keeping the arms close to your torso and elbows in, slowly lower your arms (as you keep them extended with a slight bend at the elbows) as far down towards the floor as you can go....',
    nameDe: 'Liegend Rückenlage Kurzhantel Curl',
    descriptionDe: 'Lie down on a Flachbank Bank face up while holding a Kurzhantel in each arm on top of your thighs. Bring the Kurzhanteln to the sides with the arms extended and the palms of the hands facing your thighs (Neutralgriff). While keeping the arms close to your torso and elbows in, slowly Unterer your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Lying T-Bar Row',
    description: 'Load up the T-bar Row Machine with the desired weight and adjust the leg height so that your upper chest is at the top of the pad. Tip: In some machines all you can do is stand on the appropriate step that allows you to be at a height that has the upper chest at the top of the pad. Lay face down on the pad and grab the handles. You can either use a palms down, palms up, or palms in position...',
    nameDe: 'Liegend T-Stangenrudern',
    descriptionDe: 'Load up the T-Stangenrudern Maschine with the desired weight and adjust the leg height so that your Oberer Brust is at the top of the pad. Tip: In some machines all you can do is stand on the appropriate Stufe that allows you to be at a height that has the Oberer Brust at the top of the pad. Lay...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Lying Triceps Press',
    description: 'Lie on a flat bench with either an e-z bar (my preference) or a straight bar placed on the floor behind your head and your feet on the floor. Grab the bar behind you, using a medium overhand (pronated) grip, and raise the bar in front of you at arms length. Tip: The arms should be perpendicular to the torso and the floor. The elbows should be tucked in. This is the starting position. As you...',
    nameDe: 'Liegend Trizeps Drücken',
    descriptionDe: 'Lie on a Flachbank Bank with either an e-z Stange (my preference) or a straight Stange placed on the Boden behind your Kopf and your feet on the Boden. Grab the Stange behind you, using a medium Obergriff (Proniert) grip, and Heben the Stange in front of you at arms length. Tip: The arms should be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Machine Bench Press',
    description: 'Sit down on the Chest Press Machine and select the weight. Step on the lever provided by the machine since it will help you to bring the handles forward so that you can grab the handles and fully extend the arms. Grab the handles with a palms-down grip and lift your elbows so that your upper arms are parallel to the floor to the sides of your torso. Tip: Your forearms will be pointing forward...',
    nameDe: 'Maschine Bank Drücken',
    descriptionDe: 'Sit down on the Brustdrücken Maschine and select the weight. Stufe on the lever provided by the Maschine since it will help you to bring the handles forward so that you can grab the handles and fully extend the arms. Grab the handles with a palms-down grip and lift your elbows so that your Oberer...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Machine Bicep Curl',
    description: 'Adjust the seat to the appropriate height and make your weight selection. Place your upper arms against the pads and grasp the handles. This will be your starting position. Perform the movement by flexing the elbow, pulling your lower arm towards your upper arm. Pause at the top of the movement, and then slowly return the weight to the starting position. Avoid returning the weight all the way to...',
    nameDe: 'Maschine Bizepscurl',
    descriptionDe: 'Adjust the seat to the appropriate height and make your weight selection. Place your Oberer arms against the pads and grasp the handles. This will be your starting position. Perform the movement by flexing the elbow, pulling your Unterer arm towards your Oberer arm. Pause at the top of the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Machine Preacher Curls',
    description: 'Sit down on the Preacher Curl Machine and select the weight. Place the back of your upper arms (your triceps) on the preacher pad provided and grab the handles using an underhand grip (palms facing up). Tip: Make sure that when you place the arms on the pad you keep the elbows in. This will be your starting position. Now lift the handles as you exhale and you contract the biceps. At the top of...',
    nameDe: 'Maschine Preacher Curls',
    descriptionDe: 'Sit down on the Preacher-Curl Maschine and select the weight. Place the Rücken of your Oberer arms (your Trizeps) on the preacher pad provided and grab the handles using an Untergriff grip (palms facing up). Tip: Make sure that when you place the arms on the pad you keep the elbows in. This will be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Machine Shoulder (Military) Press',
    description: 'Sit down on the Shoulder Press Machine and select the weight. Grab the handles to your sides as you keep the elbows bent and in line with your torso. This will be your starting position. Now lift the handles as you exhale and you extend the arms fully. At the top of the position make sure that you hold the contraction for a second. Lower the handles slowly back to the starting position as you...',
    nameDe: 'Maschine Schulter (Military) Drücken',
    descriptionDe: 'Sit down on the Schulterdrücken Maschine and select the weight. Grab the handles to your sides as you keep the elbows bent and in line with your torso. This will be your starting position. Now lift the handles as you exhale and you extend the arms fully. At the top of the position make sure that...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Machine Triceps Extension',
    description: 'Adjust the seat to the appropriate height and make your weight selection. Place your upper arms against the pads and grasp the handles. This will be your starting position. Perform the movement by extending the elbow, pulling your lower arm away from your upper arm. Pause at the completion of the movement, and then slowly return the weight to the starting position. Avoid returning the weight all...',
    nameDe: 'Maschine Trizepsstreckung',
    descriptionDe: 'Adjust the seat to the appropriate height and make your weight selection. Place your Oberer arms against the pads and grasp the handles. This will be your starting position. Perform the movement by extending the elbow, pulling your Unterer arm away from your Oberer arm. Pause at the completion of...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Middle Back Shrug',
    description: 'Lie facedown on an incline bench while holding a dumbbell in each hand. Your arms should be fully extended hanging down and pointing towards the floor. The palms of your hands should be facing each other. This will be your starting position. As you exhale, squeeze your shoulder blades together and hold the contraction for a full second. Tip: This movement is just like the reverse action of a hug,...',
    nameDe: 'Middle Rücken Schulterziehen',
    descriptionDe: 'Lie facedown on an Schrägbank Bank while holding a Kurzhantel in each hand. Your arms should be fully extended hanging down and pointing towards the Boden. The palms of your hands should be facing each other. This will be your starting position. As you exhale, squeeze your Schulter blades together...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Mixed Grip Chin',
    description: 'Using a spacing that is just about 1 inch wider than shoulder width, grab a pull-up bar with the palms of one hand facing forward and the palms of the other hand facing towards you. This will be your starting position. Now start to pull yourself up as you exhale. Tip: With the arm that has the palms facing up concentrate on using the back muscles in order to perform the movement. The elbow of...',
    nameDe: 'Mixed Grip Chin',
    descriptionDe: 'Using a spacing that is just about 1 inch wider than Schulter width, grab a Klimmzugstange with the palms of one hand facing forward and the palms of the other hand facing towards you. This will be your starting position. Now start to pull yourself up as you exhale. Tip: With the arm that has the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Monster Walk',
    description: 'Place a band around both ankles and another around both knees. There should be enough tension that they are tight when your feet are shoulder width apart. To begin, take short steps forward alternating your left and right foot. After several steps, do just the opposite and walk backward to where you started.',
    nameDe: 'Monster Gehen',
    descriptionDe: 'Place a Band around both ankles and another around both knees. There should be enough tension that they are tight when your feet are Schulter width apart. To begin, take short steps forward Alternierend your left and right foot. After several steps, do just the opposite and Gehen backward to where...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Muscle Up',
    description: 'Grip the rings using a false grip, with the base of your palms on top of the rings. Initiate a pull up by pulling the elbows down to your side, flexing the elbows. As you reach the top position of the pull-up, pull the rings to your armpits as you roll your shoulders forward, allowing your elbows to move straight back behind you. This puts you into the proper position to continue into the dip...',
    nameDe: 'Muscle Up',
    descriptionDe: 'Grip the Turnringe using a false grip, with the base of your palms on top of the Turnringe. Initiate a Klimmzug by pulling the elbows down to your side, flexing the elbows. As you reach the top position of the Klimmzug, pull the Turnringe to your armpits as you roll your Schultern forward, allowing...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Narrow Stance Hack Squats',
    description: 'Place the back of your torso against the back pad of the machine and hook your shoulders under the shoulder pads provided. Position your legs in the platform using a less than shoulder width narrow stance with the toes slightly pointed out. Your feet should be around 3 inches or less apart. Tip: Keep your head up at all times and also maintain the back on the pad at all times. Place your arms on...',
    nameDe: 'Narrow Stance Hack Squats',
    descriptionDe: 'Place the Rücken of your torso against the Rücken pad of the Maschine and hook your Schultern under the Schulter pads provided. Position your legs in the platform using a less than Schulter width narrow stance with the toes slightly pointed out. Your feet should be around 3 inches or less apart....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Narrow Stance Leg Press',
    description: 'Using a leg press machine, sit down on the machine and place your legs on the platform directly in front of you at a less-than-shoulder-width narrow stance with the toes slightly pointed out. Your feet should be around 3 inches or less apart. Tip: Keep your head up at all times and also maintain the back on the pad at all times. Lower the safety bars holding the weighted platform in place and...',
    nameDe: 'Narrow Stance Beinpresse',
    descriptionDe: 'Using a Beinpresse Maschine, sit down on the Maschine and place your legs on the platform directly in front of you at a less-than-Schulter-width narrow stance with the toes slightly pointed out. Your feet should be around 3 inches or less apart. Tip: Keep your Kopf up at all times and also maintain...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Narrow Stance Squats',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs...',
    nameDe: 'Narrow Stance Squats',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Natural Glute Ham Raise',
    description: 'Using the leg pad of a lat pulldown machine or a preacher bench, position yourself so that your ankles are under the pads, knees on the seat, and you are facing away from the machine. You should be upright and maintaining good posture. This will be your starting position. Lower yourself under control until your knees are almost completely straight. Remaining in control, raise yourself back up to...',
    nameDe: 'Natural Gesäß Ham Heben',
    descriptionDe: 'Using the leg pad of a Lat Latzug Maschine or a preacher Bank, position yourself so that your ankles are under the pads, knees on the seat, and you are facing away from the Maschine. You should be Aufrecht and maintaining good posture. This will be your starting position. Unterer yourself under...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Neck Press',
    description: 'Lie back on a flat bench. Using a medium-width grip (a grip that creates a 90-degree angle in the middle of the movement between the forearms and the upper arms), lift the bar from the rack and hold it straight over your neck with your arms locked. This will be your starting position. As you breathe in, come down slowly until you feel the bar on your neck. After a second pause, bring the bar back...',
    nameDe: 'Nacken Drücken',
    descriptionDe: 'Lie Rücken on a Flachbank Bank. Using a medium-width grip (a grip that creates a 90-degree angle in the middle of the movement between the Unterarme and the Oberer arms), lift the Stange from the Ständer and hold it straight over your Nacken with your arms locked. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Oblique Crunches',
    description: 'Lie flat on the floor with your lower back pressed to the ground. For this exercise, you will need to put one hand beside your head and the other to the side against the floor. Make sure your feet are elevated and resting on a flat surface. Now lift the shoulder in which your hand is touching your head. Simply elevate your shoulder and body upward until you touch your knee. For example, if you...',
    nameDe: 'Schrägbauch-Crunches',
    descriptionDe: 'Lie Flachbank on the Boden with your Unterer Rücken pressed to the ground. For this exercise, you will need to put one hand beside your Kopf and the other to the side against the Boden. Make sure your feet are elevated and resting on a Flachbank surface. Now lift the Schulter in which your hand is...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Oblique Crunches - On The Floor',
    description: 'Start out by lying on your right side with your legs lying on top of each other. Make sure your knees are bent a little bit. Place your left hand behind your head. Once you are in this set position, begin by moving your left elbow up as you would perform a normal crunch except this time the main emphasis is on your obliques. Crunch as high as you can, hold the contraction for a second and then...',
    nameDe: 'Schräger Bauchmuskel Crunches - On The Boden',
    descriptionDe: 'Start out by Liegend on your right side with your legs Liegend on top of each other. Make sure your knees are bent a little bit. Place your left hand behind your Kopf. Once you are in this set position, begin by moving your left elbow up as you would perform a normal Crunch except this time the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'One-Arm Dumbbell Row',
    description: 'Choose a flat bench and place a dumbbell on each side of it. Place the right leg on top of the end of the bench, bend your torso forward from the waist until your upper body is parallel to the floor, and place your right hand on the other end of the bench for support. Use the left hand to pick up the dumbbell on the floor and hold the weight while keeping your lower back straight. The palm of the...',
    nameDe: 'Einarmig Kurzhantel Rudern',
    descriptionDe: 'Choose a Flachbank Bank and place a Kurzhantel on each side of it. Place the right leg on top of the end of the Bank, bend your torso forward from the waist until your Oberer body is parallel to the Boden, and place your right hand on the other end of the Bank for support. Use the left hand to pick...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'One-Arm Flat Bench Dumbbell Flye',
    description: 'Lie down on a flat bench with a dumbbell in one hand resting on top of your thigh. The palm of your hand with the dumbbell in it should be at a neutral grip. By using your thighs to help you get the dumbbell up, clean the dumbbell so that you can hold it in front of you with your lifting arm being fully extended. Remember to maintain a neutral grip with this exercise. Your non lifting hand should...',
    nameDe: 'Einarmig Flachbank Bank Kurzhantel Fliegender',
    descriptionDe: 'Lie down on a Flachbank Bank with a Kurzhantel in one hand resting on top of your Oberschenkel. The palm of your hand with the Kurzhantel in it should be at a Neutralgriff. By using your thighs to help you get the Kurzhantel up, Stoßen the Kurzhantel so that you can hold it in front of you with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'One-Arm High-Pulley Cable Side Bends',
    description: 'Connect a standard handle to a tower. Move cable to highest pulley position. Stand with side to cable. With one hand, reach up and grab handle with underhand grip. Pull down cable until elbow touches your side and the handle is by your shoulder. Position feet hip-width apart. Place free hand on hip to help gauge pivot point. Keep arm in static position. Contract oblique to bring the weight down...',
    nameDe: 'Einarmig High-Pulley Kabelzug Side Bends',
    descriptionDe: 'Connect a standard handle to a tower. Move Kabelzug to highest pulley position. Stand with side to Kabelzug. With one hand, reach up and grab handle with Untergriff grip. Pull down Kabelzug until elbow touches your side and the handle is by your Schulter. Position feet Hüfte-width apart. Place free...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'One-Arm Incline Lateral Raise',
    description: 'Lie down sideways on an incline bench press with a dumbbell in the hand. Make sure the shoulder is pressing against the incline bench and the arm is lying across your body with the palm around your navel. Hold a dumbbell in your uppermost arm while keeping it extended in front of you parallel to the floor. This is your starting position. While keeping the dumbbell parallel to the floor at all...',
    nameDe: 'Einarmig Schrägbank Seitlich Heben',
    descriptionDe: 'Lie down sideways on an Schrägbank Bank Drücken with a Kurzhantel in the hand. Make sure the Schulter is pressing against the Schrägbank Bank and the arm is Liegend across your body with the palm around your navel. Hold a Kurzhantel in your uppermost arm while keeping it extended in front of you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Clean',
    description: 'Place a kettlebell between your feet. As you bend down to grab the kettlebell, push your butt back and keep your eyes looking forward. Clean the kettlebell to your shoulders by extending through the legs and hips as you raise the kettlebell towards your shoulder. The wrist should rotate as you do so. Return the weight to the starting position.',
    nameDe: 'Einarmig Kettlebell Stoßen',
    descriptionDe: 'Place a Kettlebell between your feet. As you bend down to grab the Kettlebell, push your butt Rücken and keep your eyes looking forward. Stoßen the Kettlebell to your Schultern by extending through the legs and Hüften as you Heben the Kettlebell towards your Schulter. The Handgelenk should rotate...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Clean and Jerk',
    description: 'Hold a kettlebell by the handle. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulder. Rotate your wrist as you do so, so that the palm faces forward. Dip your body by bending the knees, keeping your torso upright. Immediately reverse direction, driving through the heels, in essence jumping to create momentum. As you do so,...',
    nameDe: 'Einarmig Kettlebell Stoßen und Reißen',
    descriptionDe: 'Hold a Kettlebell by the handle. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schulter. Rotate your Handgelenk as you do so, so that the palm faces forward. Dip your body by bending the knees, keeping your torso Aufrecht....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Floor Press',
    description: 'Lie on the floor holding a kettlebell with one hand, with your upper arm supported by the floor. The palm should be facing in. Press the kettlebell straight up toward the ceiling, rotating your wrist. Lower the kettlebell back to the starting position and repeat.',
    nameDe: 'Einarmig Kettlebell Boden Drücken',
    descriptionDe: 'Lie on the Boden holding a Kettlebell with one hand, with your Oberer arm supported by the Boden. The palm should be facing in. Drücken the Kettlebell straight up toward the ceiling, rotating your Handgelenk. Unterer the Kettlebell Rücken to the starting position and repeat.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Jerk',
    description: 'Hold a kettlebell by the handle. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulder. Rotate your wrist as you do so, so that the palm faces forward. This will be your starting position. Dip your body by bending the knees, keeping your torso upright. Immediately reverse direction, driving through the heels, in essence...',
    nameDe: 'Einarmig Kettlebell Ausstoßen',
    descriptionDe: 'Hold a Kettlebell by the handle. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schulter. Rotate your Handgelenk as you do so, so that the palm faces forward. This will be your starting position. Dip your body by bending the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Military Press To The Side',
    description: 'Clean a kettlebell to your shoulder. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulder. Rotate your wrist as you do so, so that the palm faces inward. This will be your starting position. Look at the kettlebell and press it up and out until it is locked out overhead. Lower the kettlebell back to your shoulder under...',
    nameDe: 'Einarmig Kettlebell Military Drücken To The Side',
    descriptionDe: 'Stoßen a Kettlebell to your Schulter. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schulter. Rotate your Handgelenk as you do so, so that the palm faces inward. This will be your starting position. Look at the Kettlebell and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Para Press',
    description: 'Clean a kettlebell to your shoulder. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulder. Rotate your wrist as you do so, so that the palm faces forward. This will be your starting position. Hold the kettlebell with the elbow out to the side, and press it up and out until it is locked out overhead. Lower the kettlebell back...',
    nameDe: 'Einarmig Kettlebell Para Drücken',
    descriptionDe: 'Stoßen a Kettlebell to your Schulter. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schulter. Rotate your Handgelenk as you do so, so that the palm faces forward. This will be your starting position. Hold the Kettlebell with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Push Press',
    description: 'Hold a kettlebell by the handle. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulder. Rotate your wrist as you do so, so that the palm faces forward. This will be your starting position. Dip your body by bending the knees, keeping your torso upright. Immediately reverse direction, driving through the heels, in essence...',
    nameDe: 'Einarmig Kettlebell Push Drücken',
    descriptionDe: 'Hold a Kettlebell by the handle. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schulter. Rotate your Handgelenk as you do so, so that the palm faces forward. This will be your starting position. Dip your body by bending the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Row',
    description: 'Place a kettlebell in front of your feet. Bend your knees slightly and then push your butt out as much as possible as you bend over to get in the starting position. Grab the kettlebell and pull it to your stomach, retracting your shoulder blade and flexing the elbow. Keep your back straight. Lower and repeat.',
    nameDe: 'Einarmig Kettlebell Rudern',
    descriptionDe: 'Place a Kettlebell in front of your feet. Bend your knees slightly and then push your butt out as much as possible as you bend over to get in the starting position. Grab the Kettlebell and pull it to your stomach, retracting your Schulter blade and flexing the elbow. Keep your Rücken straight....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Snatch',
    description: 'Place a kettlebell between your feet. Bend your knees and push your butt back to get in the proper starting position. Look straight ahead and swing the kettlebell back between your legs. Immediately reverse the direction and drive through with your hips and knees, accelerating the kettlebell upward. As the kettlebell rises to your shoulder rotate your hand and punch straight up, using momentum to...',
    nameDe: 'Einarmig Kettlebell Reißen',
    descriptionDe: 'Place a Kettlebell between your feet. Bend your knees and push your butt Rücken to get in the proper starting position. Look straight ahead and Schwingen the Kettlebell Rücken between your legs. Immediately Umgekehrt the direction and drive through with your Hüften and knees, accelerating the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Split Jerk',
    description: 'Hold a kettlebell by the handle. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulder. Rotate your wrist as you do so, so that the palm faces forward. This will be your starting position. Dip your body by bending the knees, keeping your torso upright. Immediately reverse direction, driving through the heels, in essence...',
    nameDe: 'Einarmig Kettlebell Split Ausstoßen',
    descriptionDe: 'Hold a Kettlebell by the handle. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schulter. Rotate your Handgelenk as you do so, so that the palm faces forward. This will be your starting position. Dip your body by bending the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Split Snatch',
    description: 'Hold a kettlebell in one hand by the handle. Squat towards the floor, and then reverse the motion, extending the hips, knees, and finally the ankles, to raise the kettlebell overhead. After fully extending the body, descend into a lunge position to receive the weights overhead, one leg forward and one leg back. Ensure you drive through with your hips and lock the ketttlebells overhead in one...',
    nameDe: 'Einarmig Kettlebell Split Reißen',
    descriptionDe: 'Hold a Kettlebell in one hand by the handle. Kniebeuge towards the Boden, and then Umgekehrt the motion, extending the Hüften, knees, and finally the ankles, to Heben the Kettlebell Überkopf. After fully extending the body, descend into a Ausfallschritt position to receive the weights Überkopf, one...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Arm Kettlebell Swings',
    nameDe: 'Einarmig Kettlebell Swings',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'One-Arm Long Bar Row',
    description: 'Position a bar into a landmine or in a corner to keep it from moving. Load an appropriate weight onto your end. Stand next to the bar, and take a grip with one hand close to the collar. Using your hips and legs, rise to a standing position. Assume a bent-knee stance with your hips back and your chest up. Your arm should be extended. This will be your starting position. Pull the weight to your...',
    nameDe: 'Einarmig Long Stange Rudern',
    descriptionDe: 'Position a Stange into a landmine or in a corner to keep it from moving. Load an appropriate weight onto your end. Stand next to the Stange, and take a grip with one hand close to the collar. Using your Hüften and legs, rise to a Stehend position. Assume a bent-Knie stance with your Hüften Rücken...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'One-Arm Medicine Ball Slam',
    description: 'Start in a standing position with a staggered, athletic stance. Hold a medicine ball in one hand, on the same side as your back leg. This will be your starting position. Begin by winding the arm, raising the medicine ball above your head. As you do so, extend through the hips, knees, and ankles to load up for the slam. At peak extension, flex the shoulders, spine, and hips to throw the ball hard...',
    nameDe: 'Einarmig Medizinball Slam',
    descriptionDe: 'Start in a Stehend position with a staggered, athletic stance. Hold a Medizinball in one hand, on the same side as your Rücken leg. This will be your starting position. Begin by winding the arm, raising the Medizinball above your Kopf. As you do so, extend through the Hüften, knees, and ankles to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'One-Arm Open Palm Kettlebell Clean',
    description: 'Place one kettlebell between your feet. Grab the handle with one hand and raise the kettlebell rapidly, let it flip so that the ball of the kettlebell lands in the palm of your hand. Throw the kettlebell out in front of you and catch the handle with one hand. Take the kettlebell to the floor and repeat. Make sure to work both arms.',
    nameDe: 'Einarmig Open Palm Kettlebell Stoßen',
    descriptionDe: 'Place one Kettlebell between your feet. Grab the handle with one hand and Heben the Kettlebell rapidly, let it Umwerfen so that the Ball of the Kettlebell lands in the palm of your hand. Throw the Kettlebell out in front of you and catch the handle with one hand. Take the Kettlebell to the Boden...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'One-Arm Overhead Kettlebell Squats',
    description: 'Clean and press a kettlebell with one arm. Clean the kettlebell to your shoulder by extending through the legs and hips as you pull the kettlebell towards your shoulder. Rotate your wrist as you do so. Press the weight overhead by extending through the elbow.This will be your starting position. Looking straight ahead and keeping a kettlebell locked out above you, flex the knees and hips and lower...',
    nameDe: 'Einarmig Überkopf Kettlebell Squats',
    descriptionDe: 'Stoßen and Drücken a Kettlebell with Einarmig. Stoßen the Kettlebell to your Schulter by extending through the legs and Hüften as you pull the Kettlebell towards your Schulter. Rotate your Handgelenk as you do so. Drücken the weight Überkopf by extending through the elbow.This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'One-Arm Side Deadlift',
    description: 'Stand to the side of a barbell next to its center. Bend your knees and lower your body until you are able to reach the barbell. Grasp the bar as if you were grabbing a briefcase (palms facing you since the bar is sideways). You may need a wrist wrap if you are using a significant amount of weight. This is your starting position. Use your legs to help lift the barbell up while exhaling. Your arms...',
    nameDe: 'Einarmig Side Kreuzheben',
    descriptionDe: 'Stand to the side of a Langhantel next to its center. Bend your knees and Unterer your body until you are able to reach the Langhantel. Grasp the Stange as if you were grabbing a briefcase (palms facing you since the Stange is sideways). You may need a Handgelenk wrap if you are using a significant...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'One-Arm Side Laterals',
    description: 'Pick a dumbbell and place it in one of your hands. Your non lifting hand should be used to grab something steady such as an incline bench press. Lean towards your lifting arm and away from the hand that is gripping the incline bench as this will allow you to keep your balance. Stand with a straight torso and have the dumbbell by your side at arm\'s length with the palm of the hand facing you. This...',
    nameDe: 'Einarmig Side Laterals',
    descriptionDe: 'Pick a Kurzhantel and place it in one of your hands. Your non lifting hand should be used to grab something steady such as an Schrägbank Bank Drücken. Lean towards your lifting arm and away from the hand that is gripping the Schrägbank Bank as this will allow you to keep your balance. Stand with a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'One-Legged Cable Kickback',
    description: 'Hook a leather ankle cuff to a low cable pulley and then attach the cuff to your ankle. Face the weight stack from a distance of about two feet, grasping the steel frame for support. While keeping your knees and hips bent slightly and your abs tight, contract your glutes to slowly "kick" the working leg back in a semicircular arc as high as it will comfortably go as you breathe out. Tip: At full...',
    nameDe: 'Einbeiniger Kabelzug-Kickback',
    descriptionDe: 'Hook a leather Knöchel cuff to a low Kabelzug pulley and then attach the cuff to your Knöchel. Face the weight stack from a distance of about two feet, grasping the steel frame for support. While keeping your knees and Hüften bent slightly and your Bauch tight, contract your Gesäß to slowly "kick"...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'One Arm Chin-Up',
    description: 'For this exercise, start out by placing a towel around a chin up bar. Grab the chin-up bar with your palm facing you. One hand will be grabbing the chin-up bar and the other will be grabbing the towel. Bring your torso back around 30 degrees or so while creating a curvature on your lower back and sticking your chest out. This is your starting position.v Pull your torso up until the bar touches...',
    nameDe: 'Einarmig Klimmzug (Enger Griff)',
    descriptionDe: 'For this exercise, start out by placing a towel around a Klimmzug (Enger Griff) Stange. Grab the Klimmzugstange with your palm facing you. One hand will be grabbing the Klimmzugstange and the other will be grabbing the towel. Bring your torso Rücken around 30 degrees or so while creating a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'One Arm Dumbbell Bench Press',
    description: 'Lie down on a flat bench with a dumbbell in one hand on top of your thigh. By using your thigh to help you get the dumbbell up, clean the dumbbell up so that you can hold it in front of you at shoulder width. Use the hand you are not lifting with to help position the dumbbell over you properly. Once at shoulder width, rotate your wrist forward so that the palm of your hand is facing away from...',
    nameDe: 'Einarmig Kurzhantel Bank Drücken',
    descriptionDe: 'Lie down on a Flachbank Bank with a Kurzhantel in one hand on top of your Oberschenkel. By using your Oberschenkel to help you get the Kurzhantel up, Stoßen the Kurzhantel up so that you can hold it in front of you at Schulter width. Use the hand you are not lifting with to help position the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'One Arm Dumbbell Preacher Curl',
    description: 'Grab a dumbbell with the right arm and place the upper arm on top of the preacher bench or the incline bench. The dumbbell should be held at shoulder length. This will be your starting position. As you breathe in, slowly lower the dumbbell until your upper arm is extended and the biceps is fully stretched. As you exhale, use the biceps to curl the weight up until your biceps is fully contracted...',
    nameDe: 'Einarmig Kurzhantel Preacher-Curl',
    descriptionDe: 'Grab a Kurzhantel with the right arm and place the Oberer arm on top of the preacher Bank or the Schrägbank Bank. The Kurzhantel should be held at Schulter length. This will be your starting position. As you breathe in, slowly Unterer the Kurzhantel until your Oberer arm is extended and the Bizeps...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'One Arm Floor Press',
    description: 'Lie down on a flat surface with your back pressing against the floor or an exercise mat. Make sure your knees are bent. Have a partner hand you the bar on one hand. When starting, your arm should be just about fully extended, similar to the starting position of a barbell bench press. However, this time your grip will be neutral (palms facing your torso). Make sure the hand you are not using to...',
    nameDe: 'Einarmig Boden Drücken',
    descriptionDe: 'Lie down on a Flachbank surface with your Rücken pressing against the Boden or an exercise mat. Make sure your knees are bent. Have a partner hand you the Stange on one hand. When starting, your arm should be just about fully extended, similar to the starting position of a Langhantel Bank Drücken....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'One Arm Lat Pulldown',
    description: 'Select an appropriate weight and adjust the knee pad to help keep you down. Grasp the handle with a pronated grip. This will be your starting position. Pull the handle down, squeezing your elbow to your side as you flex the elbow. Pause at the bottom of the motion, and then slowly return the handle to the starting position. For multiple repetitions, avoid completely returning the weight to keep...',
    nameDe: 'Einarmig Lat Latzug',
    descriptionDe: 'Select an appropriate weight and adjust the Knie pad to help keep you down. Grasp the handle with a Proniert grip. This will be your starting position. Pull the handle down, squeezing your elbow to your side as you flex the elbow. Pause at the bottom of the motion, and then slowly return the handle...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'One Arm Pronated Dumbbell Triceps Extension',
    description: 'Lie flat on a bench while holding a dumbbell at arms length. Your arm should be perpendicular to your body. The palm of your hand should be facing towards your feet as a pronated grip is required to perform this exercise. Place your non lifting hand on your bicep for support. Slowly begin to lower the dumbbell down as you breathe in. Then, begin lifting the dumbbell upward as you contract the...',
    nameDe: 'Einarmig Proniert Kurzhantel Trizepsstreckung',
    descriptionDe: 'Lie Flachbank on a Bank while holding a Kurzhantel at arms length. Your arm should be perpendicular to your body. The palm of your hand should be facing towards your feet as a Proniert grip is required to perform this exercise. Place your non lifting hand on your Bizeps for support. Slowly begin to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'One Arm Supinated Dumbbell Triceps Extension',
    description: 'Lie flat on a bench while holding a dumbbell at arms length. Your arm should be perpendicular to your body. The palm of your hand should be facing towards your face as a supinated grip is required to perform this exercise. Place your non lifting hand on your bicep for support. Slowly begin to lower the dumbbell down as you breathe in. Then, begin lifting the dumbbell upward as you contract the...',
    nameDe: 'Einarmig Supiniert Kurzhantel Trizepsstreckung',
    descriptionDe: 'Lie Flachbank on a Bank while holding a Kurzhantel at arms length. Your arm should be perpendicular to your body. The palm of your hand should be facing towards your face as a Supiniert grip is required to perform this exercise. Place your non lifting hand on your Bizeps for support. Slowly begin...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'One Leg Barbell Squat',
    description: 'Start by standing about 2 to 3 feet in front of a flat bench with your back facing the bench. Have a barbell in front of you on the floor. Tip: Your feet should be shoulder width apart from each other. Bend the knees and use a pronated grip with your hands being wider than shoulder width apart from each other to lift the barbell up until you can rest it on your chest. Then lift the barbell over...',
    nameDe: 'One Leg Langhantel Kniebeuge',
    descriptionDe: 'Start by Stehend about 2 to 3 feet in front of a Flachbank Bank with your Rücken facing the Bank. Have a Langhantel in front of you on the Boden. Tip: Your feet should be Schulter width apart from each other. Bend the knees and use a Proniert grip with your hands being wider than Schulter width...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Open Palm Kettlebell Clean',
    description: 'Place one kettlebell between your feet. Clean the kettlebell by extending through the legs and hips as you raise the kettlebell towards your shoulders. Release the kettlebell as it comes up, and let it flip so that the ball of the kettlebell lands in the palms of your hands. Release the kettlebell out in front of you and catch the handle with both hands. Lower the kettlebell to the starting...',
    nameDe: 'Open Palm Kettlebell Stoßen',
    descriptionDe: 'Place one Kettlebell between your feet. Stoßen the Kettlebell by extending through the legs and Hüften as you Heben the Kettlebell towards your Schultern. Release the Kettlebell as it comes up, and let it Umwerfen so that the Ball of the Kettlebell lands in the palms of your hands. Release the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Otis-Up',
    description: 'Secure your feet and lay back on the floor. Your knees should be bent. Hold a weight with both hands to your chest. This will be your starting position. Initiate the movement by flexing the hips and spine to raise your torso up from the ground. As you move up, press the weight up so that it is above your head at the top of the movement. Return the weight to your chest as you reverse the sit-up...',
    nameDe: 'Otis-Up',
    descriptionDe: 'Secure your feet and lay Rücken on the Boden. Your knees should be bent. Hold a weight with both hands to your Brust. This will be your starting position. Initiate the movement by flexing the Hüften and Wirbelsäule to Heben your torso up from the ground. As you move up, Drücken the weight up so...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Overhead Cable Curl',
    description: 'To begin, set a weight that is comfortable on each side of the pulley machine. Note: Make sure that the amount of weight selected is the same on each side. Now adjust the height of the pulleys on each side and make sure that they are positioned at a height higher than that of your shoulders. Stand in the middle of both sides and use an underhand grip (palms facing towards the ceiling) to grab...',
    nameDe: 'Überkopf Kabelzug Curl',
    descriptionDe: 'To begin, set a weight that is comfortable on each side of the pulley Maschine. Note: Make sure that the amount of weight selected is the same on each side. Now adjust the height of the pulleys on each side and make sure that they are positioned at a height higher than that of your Schultern. Stand...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Pallof Press',
    description: 'Connect a standard handle to a tower, and—if possible—position the cable to shoulder height. If not, a low pulley will suffice. With your side to the cable, grab the handle with both hands and step away from the tower. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the cable. With your feet positioned hip-width apart and knees slightly bent, hold...',
    nameDe: 'Pallof-Press',
    descriptionDe: 'Connect a standard handle to a tower, and—if possible—position the Kabelzug to Schulter height. If not, a low pulley will suffice. With your side to the Kabelzug, grab the handle with both hands and Stufe away from the tower. You should be approximately arm\'s length away from the pulley, with the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Pallof Press With Rotation',
    description: 'Connect a standard handle to a tower, and position the cable to shoulder height. With your side to the cable, grab the handle with one hand and step away from the tower. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the cable. Align outstretched arm with cable. With your feet positioned hip-width apart, pull the cable into your chest and grab the...',
    nameDe: 'Pallof Drücken With Rotation',
    descriptionDe: 'Connect a standard handle to a tower, and position the Kabelzug to Schulter height. With your side to the Kabelzug, grab the handle with one hand and Stufe away from the tower. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the Kabelzug. Align...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Palms-Down Dumbbell Wrist Curl Over A Bench',
    description: 'Start out by placing two dumbbells on one side of a flat bench. Kneel down on both of your knees so that your body is facing the flat bench. Use your arms to grab both of the dumbbells with a pronated grip (palms facing down) and bring them up so that your forearms are resting against the flat bench. Your wrists should be hanging over the edge. Start out by curling your wrist upwards and...',
    nameDe: 'Palms-Down Kurzhantel Handgelenk-Curl Over A Bank',
    descriptionDe: 'Start out by placing two Kurzhanteln on one side of a Flachbank Bank. Kneel down on both of your knees so that your body is facing the Flachbank Bank. Use your arms to grab both of the Kurzhanteln with a Proniert grip (palms facing down) and bring them up so that your Unterarme are resting against...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Palms-Down Wrist Curl Over A Bench',
    description: 'Start out by placing a barbell on one side of a flat bench. Kneel down on both of your knees so that your body is facing the flat bench. Use your arms to grab the barbell with a pronated grip (palms down) and bring them up so that your forearms are resting against the flat bench. Your wrists should be hanging over the edge. Start out by curling your wrist upwards and exhaling. Slowly lower your...',
    nameDe: 'Palms-Down Handgelenk-Curl Over A Bank',
    descriptionDe: 'Start out by placing a Langhantel on one side of a Flachbank Bank. Kneel down on both of your knees so that your body is facing the Flachbank Bank. Use your arms to grab the Langhantel with a Proniert grip (palms down) and bring them up so that your Unterarme are resting against the Flachbank Bank....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Palms-Up Barbell Wrist Curl Over A Bench',
    description: 'Start out by placing a barbell on one side of a flat bench. Kneel down on both of your knees so that your body is facing the flat bench. Use your arms to grab the barbell with a supinated grip (palms up) and bring them up so that your forearms are resting against the flat bench. Your wrists should be hanging over the edge. Start out by curling your wrist upwards and exhaling. Slowly lower your...',
    nameDe: 'Palms-Up Langhantel Handgelenk-Curl Over A Bank',
    descriptionDe: 'Start out by placing a Langhantel on one side of a Flachbank Bank. Kneel down on both of your knees so that your body is facing the Flachbank Bank. Use your arms to grab the Langhantel with a Supiniert grip (palms up) and bring them up so that your Unterarme are resting against the Flachbank Bank....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Palms-Up Dumbbell Wrist Curl Over A Bench',
    description: 'Start out by placing two dumbbells on one side of a flat bench. Kneel down on both of your knees so that your body is facing the flat bench. Use your arms to grab both of the dumbbells with a supinated grip (palms up) and bring them up so that your forearms are resting against the flat bench. Your wrists should be hanging over the edge. Start out by curling your wrist upwards and exhaling. Slowly...',
    nameDe: 'Palms-Up Kurzhantel Handgelenk-Curl Over A Bank',
    descriptionDe: 'Start out by placing two Kurzhanteln on one side of a Flachbank Bank. Kneel down on both of your knees so that your body is facing the Flachbank Bank. Use your arms to grab both of the Kurzhanteln with a Supiniert grip (palms up) and bring them up so that your Unterarme are resting against the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Parallel Bar Dip',
    description: 'Stand between a set of parallel bars. Place a hand on each bar, and then take a small jump to help you get into the starting position with your arms locked out. Begin by flexing the elbow, lowering your body until your arms break 90 degrees. Avoid swinging, and maintain good posture throughout the descent. Reverse the motion by extending the elbow, pushing yourself back up into the starting...',
    nameDe: 'Parallel Stange Dip',
    descriptionDe: 'Stand between a set of parallel bars. Place a hand on each Stange, and then take a small Sprung to help you get into the starting position with your arms locked out. Begin by flexing the elbow, lowering your body until your arms break 90 degrees. Avoid swinging, and maintain good posture throughout...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Physioball Hip Bridge',
    description: 'Lay on a ball so that your upper back is on the ball with your hips unsupported. Both feet should be flat on the floor, hip width apart or wider. This will be your starting position. Begin by extending the hips using your glutes and hamstrings, raising your hips upward as you bridge. Pause at the top of the motion and return to the starting position.',
    nameDe: 'Physioball Hüfte Brücke',
    descriptionDe: 'Lay on a Ball so that your Oberer Rücken is on the Ball with your Hüften unsupported. Both feet should be Flachbank on the Boden, Hüfte width apart or wider. This will be your starting position. Begin by extending the Hüften using your Gesäß and Oberschenkelrückseite, raising your Hüften upward as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Plank',
    description: 'Get into a prone position on the floor, supporting your weight on your toes and your forearms. Your arms are bent and directly below the shoulder. Keep your body straight at all times, and hold this position as long as possible. To increase difficulty, an arm or leg can be raised.',
    nameDe: 'Planke',
    descriptionDe: 'Get into a Bauchlage position on the Boden, supporting your weight on your toes and your Unterarme. Your arms are bent and directly below the Schulter. Keep your body straight at all times, and hold this position as long as possible. To increase difficulty, an arm or leg can be raised.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Plate Pinch',
    description: 'Grab two wide-rimmed plates and put them together with the smooth sides facing outward Use your fingers to grip the outside part of the plate and your thumb for the other side thus holding both plates together. This is the starting position. Squeeze the plate with your fingers and thumb. Hold this position for as long as you can. Repeat for the recommended amount of sets prescribed in your...',
    nameDe: 'Scheibe Pinch',
    descriptionDe: 'Grab two wide-rimmed plates and put them together with the smooth sides facing outward Use your fingers to grip the outside part of the Scheibe and your thumb for the other side thus holding both plates together. This is the starting position. Squeeze the Scheibe with your fingers and thumb. Hold...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Plate Twist',
    description: 'Lie down on the floor or an exercise mat with your legs fully extended and your upper body upright. Grab the plate by its sides with both hands out in front of your abdominals with your arms slightly bent. Slowly cross your legs near your ankles and lift them up off the ground. Your knees should also be bent slightly. Note: Move your upper body back slightly to help keep you balanced turning this...',
    nameDe: 'Scheibe Twist',
    descriptionDe: 'Lie down on the Boden or an exercise mat with your legs fully extended and your Oberer body Aufrecht. Grab the Scheibe by its sides with both hands out in front of your Bauch with your arms slightly bent. Slowly Überkreuz your legs near your ankles and lift them up off the ground. Your knees should...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Platform Hamstring Slides',
    description: 'For this movement a wooden floor or similar is needed. Lay on your back with your legs extended. Place a gym towel or a light weight underneath your heel. This will be your starting position. Begin the movement by flexing the knee, keeping your other leg straight. Continue bringing the heel closer to you, sliding it on the floor. At full knee flexion, reverse the movement to return to the...',
    nameDe: 'Platform Oberschenkelrückseite Slides',
    descriptionDe: 'For this movement a wooden Boden or similar is needed. Lay on your Rücken with your legs extended. Place a gym towel or a light weight underneath your heel. This will be your starting position. Begin the movement by flexing the Knie, keeping your other leg straight. Continue bringing the heel...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Plie Dumbbell Squat',
    description: 'Hold a dumbbell at the base with both hands and stand straight up. Move your legs so that they are wider than shoulder width apart from each other with your knees slightly bent. Your toes should be facing out. Note: Your arms should be stationary while performing the exercise. This is the starting position. Slowly bend the knees and lower your legs until your thighs are parallel to the floor....',
    nameDe: 'Plie Kurzhantel Kniebeuge',
    descriptionDe: 'Hold a Kurzhantel at the base with both hands and stand straight up. Move your legs so that they are wider than Schulter width apart from each other with your knees slightly bent. Your toes should be facing out. Note: Your arms should be stationary while performing the exercise. This is the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Plyo Kettlebell Pushups',
    description: 'Place a kettlebell on the floor. Place yourself in a pushup position, on your toes with one hand on the ground and one hand holding the kettlebell, with your elbows extended. This will be your starting position. Begin by lowering yourself as low as you can, keeping your back straight. Quickly and forcefully reverse direction, pushing yourself up to the other side of the kettlebell, switching...',
    nameDe: 'Plyo Kettlebell Pushups',
    descriptionDe: 'Place a Kettlebell on the Boden. Place yourself in a Liegestütz position, on your toes with one hand on the ground and one hand holding the Kettlebell, with your elbows extended. This will be your starting position. Begin by lowering yourself as low as you can, keeping your Rücken straight. Quickly...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Power Clean',
    description: 'Stand with your feet slightly wider than shoulder width apart and toes pointing out slightly. Squat down and grasp bar with a closed, pronated grip. Your hands should be slightly wider than shoulder width apart outside knees with elbows fully extended. Place the bar about 1 inch in front of your shins and over the balls of your feet. Your back should be flat or slightly arched, your chest held up...',
    nameDe: 'Power-Stoßen',
    descriptionDe: 'Stand with your feet slightly wider than Schulter width apart and toes pointing out slightly. Kniebeuge down and grasp Stange with a closed, Proniert grip. Your hands should be slightly wider than Schulter width apart outside knees with elbows fully extended. Place the Stange about 1 inch in front...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Power Partials',
    description: 'Stand up with your torso upright and a dumbbell on each hand being held at arms length. The elbows should be close to the torso. The palms of the hands should be facing your torso. Your feet should be about shoulder width apart. This will be your starting position. Keeping your arms straight and the torso stationary, lift the weights out to your sides until they are about shoulder level height...',
    nameDe: 'Power Partials',
    descriptionDe: 'Stand up with your torso Aufrecht and a Kurzhantel on each hand being held at arms length. The elbows should be close to the torso. The palms of the hands should be facing your torso. Your feet should be about Schulter width apart. This will be your starting position. Keeping your arms straight and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Preacher Curl',
    description: 'To perform this movement you will need a preacher bench and an E-Z bar. Grab the E-Z curl bar at the close inner handle (either have someone hand you the bar which is preferable or grab the bar from the front bar rest provided by most preacher benches). The palm of your hands should be facing forward and they should be slightly tilted inwards due to the shape of the bar. With the upper arms...',
    nameDe: 'Preacher-Curl',
    descriptionDe: 'To perform this movement you will need a preacher Bank and an E-Z Stange. Grab the E-Z Curl Stange at the close Innen handle (either have someone hand you the Stange which is preferable or grab the Stange from the front Stange rest provided by most preacher benches). The palm of your hands should...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Preacher Hammer Dumbbell Curl',
    description: 'Place the upper part of both arms on top of the preacher bench as you hold a dumbbell in each hand with the palms facing each other (neutral grip). As you breathe in, slowly lower the dumbbells until your upper arm is extended and the biceps is fully stretched. As you exhale, use the biceps to curl the weight up until your biceps is fully contracted and the dumbbells are at shoulder height....',
    nameDe: 'Preacher Hammer Kurzhantel Curl',
    descriptionDe: 'Place the Oberer part of both arms on top of the preacher Bank as you hold a Kurzhantel in each hand with the palms facing each other (Neutralgriff). As you breathe in, slowly Unterer the Kurzhanteln until your Oberer arm is extended and the Bizeps is fully stretched. As you exhale, use the Bizeps...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Press Sit-Up',
    description: 'To begin, lie down on a bench with a barbell resting on your chest. Position your legs so they are secure on the extension of the abdominal bench. This is the starting position. While inhaling, tighten your abdominals and glutes. Simultaneously curl your torso as you do when performing a sit-up and press the barbell to an overhead position while exhaling. Tip: Use your arms to push the barbell...',
    nameDe: 'Drücken Sit-Up',
    descriptionDe: 'To begin, lie down on a Bank with a Langhantel resting on your Brust. Position your legs so they are secure on the Streckung of the Bauch Bank. This is the starting position. While inhaling, tighten your Bauch and Gesäß. Simultaneously Curl your torso as you do when performing a Sit-Up and Drücken...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Prone Manual Hamstring',
    description: 'You will need a partner for this exercise. Lay face down with your legs straight. Your assistant will place their hand on your heel. To begin, flex the knee to curl your leg up. Your partner should provide resistance, starting light and increasing the pressure as the movement is completed. Communicate with your partner to monitor appropriate resistance levels. Pause at the top, returning the leg...',
    nameDe: 'Bauchlage Manual Oberschenkelrückseite',
    descriptionDe: 'You will need a partner for this exercise. Lay face down with your legs straight. Your assistant will place their hand on your heel. To begin, flex the Knie to Curl your leg up. Your partner should provide resistance, starting light and increasing the pressure as the movement is completed....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Pull Through',
    description: 'Begin standing a few feet in front of a low pulley with a rope or handle attached. Face away from the machine, straddling the cable, with your feet set wide apart. Begin the movement by reaching through your legs as far as possible, bending at the hips. Keep your knees slightly bent. Keeping your arms straight, extend through the hip to stand straight up. Avoid pulling upward through the...',
    nameDe: 'Kabel-Durchzug',
    descriptionDe: 'Begin Stehend a few feet in front of a low pulley with a Seil or handle attached. Face away from the Maschine, straddling the Kabelzug, with your feet set wide apart. Begin the movement by reaching through your legs as far as possible, bending at the Hüften. Keep your knees slightly bent. Keeping...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Pullups',
    description: 'Grab the pull-up bar with the palms facing forward using the prescribed grip. Note on grips: For a wide grip, your hands need to be spaced out at a distance wider than your shoulder width. For a medium grip, your hands need to be spaced out at a distance equal to your shoulder width and for a close grip at a distance smaller than your shoulder width. As you have both arms extended in front of you...',
    nameDe: 'Pullups',
    descriptionDe: 'Grab the Klimmzugstange with the palms facing forward using the prescribed grip. Note on grips: For a Weiter Griff, your hands need to be spaced out at a distance wider than your Schulter width. For a medium grip, your hands need to be spaced out at a distance equal to your Schulter width and for a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Push-Up Wide',
    description: 'With your hands wide apart, support your body on your toes and hands in a plank position. Your elbows should be extended and your body straight. Do not allow your hips to sag. This will be your starting position. To begin, allow the elbows to flex, lowering your chest to the floor as you inhale. Using your pectoral muscles, press your upper body back up to the starting position by extending the...',
    nameDe: 'Liegestütz Wide',
    descriptionDe: 'With your hands wide apart, support your body on your toes and hands in a Planke position. Your elbows should be extended and your body straight. Do not allow your Hüften to sag. This will be your starting position. To begin, allow the elbows to flex, lowering your Brust to the Boden as you inhale....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Push-Ups - Close Triceps Position',
    description: 'Lie on the floor face down and place your hands closer than shoulder width for a close hand position. Make sure that you are holding your torso up at arms\' length. Lower yourself until your chest almost touches the floor as you inhale. Using your triceps and some of your pectoral muscles, press your upper body back up to the starting position and squeeze your chest. Breathe out as you perform...',
    nameDe: 'Push-Ups - Close Trizeps Position',
    descriptionDe: 'Lie on the Boden face down and place your hands closer than Schulter width for a close hand position. Make sure that you are holding your torso up at arms\' length. Unterer yourself until your Brust almost touches the Boden as you inhale. Using your Trizeps and some of your Brustmuskel muscles,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Push-Ups With Feet Elevated',
    description: 'Lie on the floor face down and place your hands about 36 inches apart from each other holding your torso up at arms length. Place your toes on top of a flat bench. This will allow your body to be elevated. Note: The higher the elevation of the flat bench, the higher the resistance of the exercise is. Lower yourself until your chest almost touches the floor as you inhale. Using your pectoral...',
    nameDe: 'Push-Ups With Feet Elevated',
    descriptionDe: 'Lie on the Boden face down and place your hands about 36 inches apart from each other holding your torso up at arms length. Place your toes on top of a Flachbank Bank. This will allow your body to be elevated. Note: The higher the elevation of the Flachbank Bank, the higher the resistance of the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Push-Ups With Feet On An Exercise Ball',
    description: 'Lie on the floor face down and place your hands about 36 inches apart from each other holding your torso up at arms length. Place your toes on top of an exercise ball. This will allow your body to be elevated. Lower yourself until your chest almost touches the floor as you inhale. Using your pectoral muscles, press your upper body back up to the starting position and squeeze your chest. Breathe...',
    nameDe: 'Push-Ups With Feet On An Trainingsball',
    descriptionDe: 'Lie on the Boden face down and place your hands about 36 inches apart from each other holding your torso up at arms length. Place your toes on top of an Trainingsball. This will allow your body to be elevated. Unterer yourself until your Brust almost touches the Boden as you inhale. Using your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Push Up to Side Plank',
    description: 'Get into pushup position on the toes with your hands just outside of shoulder width. Perform a pushup by allowing the elbows to flex. As you descend, keep your body straight. Do one pushup and as you come up, shift your weight on the left side of the body, twist to the side while bringing the right arm up towards the ceiling in a side plank. Lower the arm back to the floor for another pushup and...',
    nameDe: 'Liegestütz to Side Planke',
    descriptionDe: 'Get into Liegestütz position on the toes with your hands just outside of Schulter width. Perform a Liegestütz by allowing the elbows to flex. As you descend, keep your body straight. Do one Liegestütz and as you come up, shift your weight on the left side of the body, twist to the side while...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Pushups',
    description: 'Lie on the floor face down and place your hands about 36 inches apart while holding your torso up at arms length. Next, lower yourself downward until your chest almost touches the floor as you inhale. Now breathe out and press your upper body back up to the starting position while squeezing your chest. After a brief pause at the top contracted position, you can begin to lower yourself downward...',
    nameDe: 'Pushups',
    descriptionDe: 'Lie on the Boden face down and place your hands about 36 inches apart while holding your torso up at arms length. Next, Unterer yourself downward until your Brust almost touches the Boden as you inhale. Now breathe out and Drücken your Oberer body Rücken up to the starting position while squeezing...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Pushups (Close and Wide Hand Positions)',
    description: 'Lie on the floor face down and body straight with your toes on the floor and the hands wider than shoulder width for a wide hand position and closer than shoulder width for a close hand position. Make sure you are holding your torso up at arms length. Lower yourself until your chest almost touches the floor as you inhale. Using your pectoral muscles, press your upper body back up to the starting...',
    nameDe: 'Pushups (Close and Wide Hand Positions)',
    descriptionDe: 'Lie on the Boden face down and body straight with your toes on the Boden and the hands wider than Schulter width for a wide hand position and closer than Schulter width for a close hand position. Make sure you are holding your torso up at arms length. Unterer yourself until your Brust almost...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Reverse Barbell Curl',
    description: 'Stand up with your torso upright while holding a barbell at shoulder width with the elbows close to the torso. The palm of your hands should be facing down (pronated grip). This will be your starting position. While holding the upper arms stationary, curl the weights while contracting the biceps as you breathe out. Only the forearms should move. Continue the movement until your biceps are fully...',
    nameDe: 'Umgekehrt Langhantel Curl',
    descriptionDe: 'Stand up with your torso Aufrecht while holding a Langhantel at Schulter width with the elbows close to the torso. The palm of your hands should be facing down (Proniert grip). This will be your starting position. While holding the Oberer arms stationary, Curl the weights while contracting the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Reverse Barbell Preacher Curls',
    description: 'Grab an EZ-bar using a shoulder width and palms down (pronated) grip. Now place the upper part of both arms on top of the preacher bench and have your arms extended. This will be your starting position. As you exhale, use the biceps to curl the weight up until your biceps are fully contracted and the barbell is at shoulder height. Squeeze the biceps hard for a second at the contracted position....',
    nameDe: 'Umgekehrt Langhantel Preacher Curls',
    descriptionDe: 'Grab an EZ-Stange using a Schulter width and palms down (Proniert) grip. Now place the Oberer part of both arms on top of the preacher Bank and have your arms extended. This will be your starting position. As you exhale, use the Bizeps to Curl the weight up until your Bizeps are fully contracted...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Reverse Cable Curl',
    description: 'Stand up with your torso upright while holding a bar attachment that is attached to a low pulley using a pronated (palms down) and shoulder width grip. Make sure also that you keep the elbows close to the torso. This will be your starting position. While holding the upper arms stationary, curl the weights while contracting the biceps as you breathe out. Only the forearms should move. Continue the...',
    nameDe: 'Umgekehrt Kabelzug Curl',
    descriptionDe: 'Stand up with your torso Aufrecht while holding a Stange attachment that is attached to a low pulley using a Proniert (palms down) and Schulter width grip. Make sure also that you keep the elbows close to the torso. This will be your starting position. While holding the Oberer arms stationary, Curl...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Reverse Crunch',
    description: 'Lie down on the floor with your legs fully extended and arms to the side of your torso with the palms on the floor. Your arms should be stationary for the entire exercise. Move your legs up so that your thighs are perpendicular to the floor and feet are together and parallel to the floor. This is the starting position. While inhaling, move your legs towards the torso as you roll your pelvis...',
    nameDe: 'Umgekehrt Crunch',
    descriptionDe: 'Lie down on the Boden with your legs fully extended and arms to the side of your torso with the palms on the Boden. Your arms should be stationary for the entire exercise. Move your legs up so that your thighs are perpendicular to the Boden and feet are together and parallel to the Boden. This is...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Reverse Flyes',
    description: 'To begin, lie down on an incline bench with the chest and stomach pressing against the incline. Have the dumbbells in each hand with the palms facing each other (neutral grip). Extend the arms in front of you so that they are perpendicular to the angle of the bench. The legs should be stationary while applying pressure with the ball of your toes. This is the starting position. Maintaining the...',
    nameDe: 'Umgekehrt Flyes',
    descriptionDe: 'To begin, lie down on an Schrägbank Bank with the Brust and stomach pressing against the Schrägbank. Have the Kurzhanteln in each hand with the palms facing each other (Neutralgriff). Extend the arms in front of you so that they are perpendicular to the angle of the Bank. The legs should be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Reverse Flyes With External Rotation',
    description: 'To begin, lie down on an incline bench set at a 30-degree angle with the chest and stomach pressing against the incline. Have the dumbbells in each hand with the palms facing down to the floor. Your arms should be in front of you so that they are perpendicular to the angle of the bench. Tip: Your elbows should have a slight bend. The legs should be stationary while applying pressure with the ball...',
    nameDe: 'Umgekehrt Flyes With External Rotation',
    descriptionDe: 'To begin, lie down on an Schrägbank Bank set at a 30-degree angle with the Brust and stomach pressing against the Schrägbank. Have the Kurzhanteln in each hand with the palms facing down to the Boden. Your arms should be in front of you so that they are perpendicular to the angle of the Bank. Tip:...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Reverse Grip Bent-Over Rows',
    description: 'Stand erect while holding a barbell with a supinated grip (palms facing up). Bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the back straight until it is almost parallel to the floor. Tip: Make sure that you keep the head up. The barbell should hang directly in front of you as your arms hang perpendicular to the floor and your torso. This is your...',
    nameDe: 'Umgekehrt Grip Vorgebeugt Rows',
    descriptionDe: 'Stand erect while holding a Langhantel with a Supiniert grip (palms facing up). Bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the Rücken straight until it is almost parallel to the Boden. Tip: Make sure that you keep the Kopf up. The Langhantel should...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Reverse Grip Triceps Pushdown',
    description: 'Start by setting a bar attachment (straight or e-z) on a high pulley machine. Facing the bar attachment, grab it with the palms facing up (supinated grip) at shoulder width. Lower the bar by using your lats until your arms are fully extended by your sides. Tip: Elbows should be in by your sides and your feet should be shoulder width apart from each other. This is the starting position. Slowly...',
    nameDe: 'Umgekehrt Grip Trizeps Pushdown',
    descriptionDe: 'Start by setting a Stange attachment (straight or e-z) on a high pulley Maschine. Facing the Stange attachment, grab it with the palms facing up (Supiniert grip) at Schulter width. Unterer the Stange by using your Latissimus until your arms are fully extended by your sides. Tip: Elbows should be in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Reverse Hyperextension',
    description: 'Place your feet between the pads after loading an appropriate weight. Lay on the top pad, allowing your hips to hang off the back, while grasping the handles to hold your position. To begin the movement, flex the hips, pulling the legs forward. Reverse the motion by extending the hips, kicking the leg back. It is very important not to over-extend the hip on this movement, stopping short of your...',
    nameDe: 'Umgekehrt Hyperextension',
    descriptionDe: 'Place your feet between the pads after loading an appropriate weight. Lay on the top pad, allowing your Hüften to hang off the Rücken, while grasping the handles to hold your position. To begin the movement, flex the Hüften, pulling the legs forward. Umgekehrt the motion by extending the Hüften,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Reverse Machine Flyes',
    description: 'Adjust the handles so that they are fully to the rear. Make an appropriate weight selection and adjust the seat height so the handles are at shoulder level. Grasp the handles with your hands facing inwards. This will be your starting position. In a semicircular motion, pull your hands out to your side and back, contracting your rear delts. Keep your arms slightly bent throughout the movement,...',
    nameDe: 'Umgekehrt Maschine Flyes',
    descriptionDe: 'Adjust the handles so that they are fully to the rear. Make an appropriate weight selection and adjust the seat height so the handles are at Schulter level. Grasp the handles with your hands facing inwards. This will be your starting position. In a semicircular motion, pull your hands out to your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Reverse Plate Curls',
    description: 'Start by standing straight with a weighted plate held by both hands and arms fully extended. Use a pronated grip (palms facing down) and make sure your fingers grab the rough side of the plate while your thumb grabs the smooth side. Note: For the best results, grab the weighted plate at an 11:00 and 1:00 o\'clock position. Your feet should be shoulder width apart from each other and the weighted...',
    nameDe: 'Umgekehrt Scheibe Curls',
    descriptionDe: 'Start by Stehend straight with a Gewichtet Scheibe held by both hands and arms fully extended. Use a Proniert grip (palms facing down) and make sure your fingers grab the rough side of the Scheibe while your thumb grabs the smooth side. Note: For the best results, grab the Gewichtet Scheibe at an...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Reverse Triceps Bench Press',
    description: 'Lie back on a flat bench. Using a close, supinated grip (around shoulder width), lift the bar from the rack and hold it straight over you with your arms locked extended in front of you and perpendicular to the floor. This will be your starting position. As you breathe in, come down slowly until you feel the bar on your middle chest. Tip: Make sure that as opposed to a regular bench press, you...',
    nameDe: 'Umgekehrt Trizeps Bank Drücken',
    descriptionDe: 'Lie Rücken on a Flachbank Bank. Using a close, Supiniert grip (around Schulter width), lift the Stange from the Ständer and hold it straight over you with your arms locked extended in front of you and perpendicular to the Boden. This will be your starting position. As you breathe in, come down...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Ring Dips',
    description: 'Grip a ring in each hand, and then take a small jump to help you get into the starting position with your arms locked out. Begin by flexing the elbow, lowering your body until your arms break 90 degrees. Avoid swinging, and maintain good posture throughout the descent. Reverse the motion by extending the elbow, pushing yourself back up into the starting position. Repeat for the desired number of...',
    nameDe: 'Ring Dips',
    descriptionDe: 'Grip a ring in each hand, and then take a small Sprung to help you get into the starting position with your arms locked out. Begin by flexing the elbow, lowering your body until your arms break 90 degrees. Avoid swinging, and maintain good posture throughout the descent. Umgekehrt the motion by...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Rocking Standing Calf Raise',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place it on the back of your shoulders (slightly below the neck). Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs and at...',
    nameDe: 'Rocking Stehend Wadenlifte',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place it on the Rücken of your Schultern (slightly below...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Rocky Pull-Ups/Pulldowns',
    description: 'Grab the pull-up bar with the palms facing forward using a wide grip. As you have both arms extended in front of you holding the bar at the chosen grip width, bring your torso back around 30 degrees or so while creating a curvature on your lower back and sticking your chest out. This is your starting position. Pull your torso up until the bar touches your upper chest by drawing the shoulders and...',
    nameDe: 'Rocky Pull-Ups/Pulldowns',
    descriptionDe: 'Grab the Klimmzugstange with the palms facing forward using a Weiter Griff. As you have both arms extended in front of you holding the Stange at the chosen grip width, bring your torso Rücken around 30 degrees or so while creating a curvature on your Unterer Rücken and sticking your Brust out. This...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Romanian Deadlift',
    description: 'Put a barbell in front of you on the ground and grab it using a pronated (palms facing down) grip that a little wider than shoulder width. Tip: Depending on the weight used, you may need wrist wraps to perform the exercise and also a raised platform in order to allow for better range of motion. Bend the knees slightly and keep the shins vertical, hips back and back straight. This will be your...',
    nameDe: 'Rumänisches Kreuzheben',
    descriptionDe: 'Put a Langhantel in front of you on the ground and grab it using a Proniert (palms facing down) grip that a little wider than Schulter width. Tip: Depending on the weight used, you may need Handgelenk wraps to perform the exercise and also a raised platform in order to allow for better range of...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Rope Climb',
    description: 'Grab the rope with both hands above your head. Pull down on the rope as you take a small jump. Wrap the rope around one leg, using your feet to pinch the rope. Reach up as high as possible with your arms, gripping the rope tightly. Release the rope from your feet as you pull yourself up with your arms, bringing your knees towards your chest. Resecure your feet on the rope, and then stand up to...',
    nameDe: 'Seil Climb',
    descriptionDe: 'Grab the Seil with both hands above your Kopf. Pull down on the Seil as you take a small Sprung. Wrap the Seil around one leg, using your feet to pinch the Seil. Reach up as high as possible with your arms, gripping the Seil tightly. Release the Seil from your feet as you pull yourself up with your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Rope Crunch',
    description: 'Kneel 1-2 feet in front of a cable system with a rope attached. After selecting an appropriate weight, grasp the rope with both hands reaching overhead. Your torso should be upright in the starting position. To begin, flex at the spine, attempting to bring your rib cage to your legs as you pull the cable down. Pause at the bottom of the motion, and then slowly return to the starting position....',
    nameDe: 'Seil-Crunch',
    descriptionDe: 'Kneel 1-2 feet in front of a Kabelzug system with a Seil attached. After selecting an appropriate weight, grasp the Seil with both hands reaching Überkopf. Your torso should be Aufrecht in the starting position. To begin, flex at the Wirbelsäule, attempting to bring your rib cage to your legs as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Rope Straight-Arm Pulldown',
    description: 'Attach a rope to a high pulley and make your weight selection. Stand a couple feet back from the pulley with your feet staggered and take the rope with both hands. Lean forward from the hip, keeping your back straight, with your arms extended up in front of you. This will be your starting position. Keeping your arms straight, extend the shoulder to pull the rope down to your thighs. Pause at the...',
    nameDe: 'Seil Straight-Arm Latzug',
    descriptionDe: 'Attach a Seil to a high pulley and make your weight selection. Stand a couple feet Rücken from the pulley with your feet staggered and take the Seil with both hands. Lean forward from the Hüfte, keeping your Rücken straight, with your arms extended up in front of you. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Russian Twist',
    description: 'Lie down on the floor placing your feet either under something that will not move or by having a partner hold them. Your legs should be bent at the knees. Elevate your upper body so that it creates an imaginary V-shape with your thighs. Your arms should be fully extended in front of you perpendicular to your torso and with the hands clasped. This is the starting position. Twist your torso to the...',
    nameDe: 'Russischer Twist',
    descriptionDe: 'Lie down on the Boden placing your feet either under something that will not move or by having a partner hold them. Your legs should be bent at the knees. Elevate your Oberer body so that it creates an imaginary V-shape with your thighs. Your arms should be fully extended in front of you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Scapular Pull-Up',
    description: 'Take a pronated grip on a pull-up bar. From a hanging position, raise yourself a few inches without using your arms. Do this by depressing your shoulder girdle in a reverse shrugging motion. Pause at the completion of the movement, and then slowly return to the starting position before performing more repetitions.',
    nameDe: 'Schulterblatt-Klimmzug',
    descriptionDe: 'Take a Proniert grip on a Klimmzugstange. From a hanging position, Heben yourself a few inches without using your arms. Do this by depressing your Schulter girdle in a Umgekehrt shrugging motion. Pause at the completion of the movement, and then slowly return to the starting position before...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Seated Band Hamstring Curl',
    description: 'Secure a band close to the ground and place a bench a couple feet away from it. Seat yourself on the bench and secure the band behind your ankles, beginning with your legs straight. This will be your starting position. Flex the knees, bringing your feet towards the bench. You may need to lean back slightly to keep your feet from striking the floor. Pause at the completion of the movement, and...',
    nameDe: 'Sitzend Band Oberschenkelrückseite-Curl',
    descriptionDe: 'Secure a Band close to the ground and place a Bank a couple feet away from it. Seat yourself on the Bank and secure the Band behind your ankles, beginning with your legs straight. This will be your starting position. Flex the knees, bringing your feet towards the Bank. You may need to lean Rücken...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Barbell Military Press',
    description: 'Sit on a Military Press Bench with a bar behind your head and either have a spotter give you the bar (better on the rotator cuff this way) or pick it up yourself carefully with a pronated grip (palms facing forward). Tip: Your grip should be wider than shoulder width and it should create a 90-degree angle between the forearm and the upper arm as the barbell goes down. Once you pick up the barbell...',
    nameDe: 'Militärdrücken sitzend',
    descriptionDe: 'Sit on a Military Drücken Bank with a Stange behind your Kopf and either have a spotter give you the Stange (better on the rotator cuff this way) or pick it up yourself carefully with a Proniert grip (palms facing forward). Tip: Your grip should be wider than Schulter width and it should create a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Seated Barbell Twist',
    description: 'Start out by sitting at the end of a flat bench with a barbell placed on top of your thighs. Your feet should be shoulder width apart from each other. Grip the bar with your palms facing down and make sure your hands are wider than shoulder width apart from each other. Begin to lift the barbell up over your head until your arms are fully extended. Now lower the barbell behind your head until it...',
    nameDe: 'Sitzend Langhantel Twist',
    descriptionDe: 'Start out by sitting at the end of a Flachbank Bank with a Langhantel placed on top of your thighs. Your feet should be Schulter width apart from each other. Grip the Stange with your palms facing down and make sure your hands are wider than Schulter width apart from each other. Begin to lift the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Seated Bent-Over One-Arm Dumbbell Triceps Extension',
    description: 'Sit down at the end of a flat bench with a dumbbell in one arm using a neutral grip (palms of the hand facing you). Bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the back straight until it is almost parallel to the floor. Make sure that you keep the head up. The upper arm with the dumbbell should be close to the torso and aligned with it (lifted up...',
    nameDe: 'Sitzend Vorgebeugt Einarmig Kurzhantel Trizepsstreckung',
    descriptionDe: 'Sit down at the end of a Flachbank Bank with a Kurzhantel in Einarmig using a Neutralgriff (palms of the hand facing you). Bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the Rücken straight until it is almost parallel to the Boden. Make sure that you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Seated Bent-Over Rear Delt Raise',
    description: 'Place a couple of dumbbells looking forward in front of a flat bench. Sit on the end of the bench with your legs together and the dumbbells behind your calves. Bend at the waist while keeping the back straight in order to pick up the dumbbells. The palms of your hands should be facing each other as you pick them. This will be your starting position. Keeping your torso forward and stationary, and...',
    nameDe: 'Sitzend Vorgebeugt Rear Delt Heben',
    descriptionDe: 'Place a couple of Kurzhanteln looking forward in front of a Flachbank Bank. Sit on the end of the Bank with your legs together and the Kurzhanteln behind your Waden. Bend at the waist while keeping the Rücken straight in order to pick up the Kurzhanteln. The palms of your hands should be facing...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Seated Bent-Over Two-Arm Dumbbell Triceps Extension',
    description: 'Sit down at the end of a flat bench with a dumbbell in both arms using a neutral grip (palms of the hand facing you). Bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the back straight until it is almost parallel to the floor. Make sure that you keep the head up. The upper arms with the dumbbells should be close to the torso and aligned with it (lifted...',
    nameDe: 'Sitzend Vorgebeugt Beidarmig Kurzhantel Trizepsstreckung',
    descriptionDe: 'Sit down at the end of a Flachbank Bank with a Kurzhantel in both arms using a Neutralgriff (palms of the hand facing you). Bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the Rücken straight until it is almost parallel to the Boden. Make sure that you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Seated Cable Rows',
    description: 'For this exercise you will need access to a low pulley row machine with a V-bar. Note: The V-bar will enable you to have a neutral grip where the palms of your hands face each other. To get into the starting position, first sit down on the machine and place your feet on the front platform or crossbar provided making sure that your knees are slightly bent and not locked. Lean over as you keep the...',
    nameDe: 'Sitzend Kabelzug Rows',
    descriptionDe: 'For this exercise you will need access to a low pulley Rudern Maschine with a V-Stange. Note: The V-Stange will enable you to have a Neutralgriff where the palms of your hands face each other. To get into the starting position, first sit down on the Maschine and place your feet on the front...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Seated Cable Shoulder Press',
    description: 'Adjust the weight to an appropriate amount and be seated, grasping the handles. Your upper arms should be about 90 degrees to the body, with your head and chest up. The elbows should also be bent to about 90 degrees. This will be your starting position. Begin by extending through the elbow, pressing the handles together above your head. After pausing at the top, return the handles to the starting...',
    nameDe: 'Sitzend Kabelzug Schulterdrücken',
    descriptionDe: 'Adjust the weight to an appropriate amount and be Sitzend, grasping the handles. Your Oberer arms should be about 90 degrees to the body, with your Kopf and Brust up. The elbows should also be bent to about 90 degrees. This will be your starting position. Begin by extending through the elbow,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Seated Calf Raise',
    description: 'Sit on the machine and place your toes on the lower portion of the platform provided with the heels extending off. Choose the toe positioning of your choice (forward, in, or out) as per the beginning of this chapter. Place your lower thighs under the lever pad, which will need to be adjusted according to the height of your thighs. Now place your hands on top of the lever pad in order to prevent...',
    nameDe: 'Wadenlifte sitzend',
    descriptionDe: 'Sit on the Maschine and place your toes on the Unterer portion of the platform provided with the heels extending off. Choose the toe positioning of your choice (forward, in, or out) as per the beginning of this chapter. Place your Unterer thighs under the lever pad, which will need to be adjusted...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Close-Grip Concentration Barbell Curl',
    description: 'Sit down on a flat bench with a barbell or E-Z Bar in front of you in between your legs. Your legs should be spread with the knees bent and the feet on the floor. Use your arms to pick the barbell up and place the back of your upper arms on top of your inner thighs (around three and a half inches away from the front of the knee). A supinated grip closer than shoulder width is needed to perform...',
    nameDe: 'Sitzend Enger Griff Concentration Langhantel Curl',
    descriptionDe: 'Sit down on a Flachbank Bank with a Langhantel or E-Z Stange in front of you in between your legs. Your legs should be spread with the knees bent and the feet on the Boden. Use your arms to pick the Langhantel up and place the Rücken of your Oberer arms on top of your Innen thighs (around three and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated Dumbbell Curl',
    description: 'Sit on a flat bench with a dumbbell on each hand being held at arms length. The elbows should be close to the torso. Rotate the palms of the hands so that they are facing your torso. This will be your starting position. While holding the upper arm stationary, curl the weights and start twisting the wrists once the dumbbells pass your thighs so that the palms of your hands face forward at the end...',
    nameDe: 'Sitzend Kurzhantel Curl',
    descriptionDe: 'Sit on a Flachbank Bank with a Kurzhantel on each hand being held at arms length. The elbows should be close to the torso. Rotate the palms of the hands so that they are facing your torso. This will be your starting position. While holding the Oberer arm stationary, Curl the weights and start...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated Dumbbell Inner Biceps Curl',
    description: 'Sit on the end of a flat bench with a dumbbell in each hand being held at arms length. The elbows should be close to the torso. Rotate the palms of the hands so that they are facing inward in a neutral position. This will be your starting position. While holding the upper arms stationary, curl the dumbbells out and up, turning the palms out as you lift and keeping your forearms in line with your...',
    nameDe: 'Sitzend Kurzhantel Innen Bizepscurl',
    descriptionDe: 'Sit on the end of a Flachbank Bank with a Kurzhantel in each hand being held at arms length. The elbows should be close to the torso. Rotate the palms of the hands so that they are facing inward in a neutral position. This will be your starting position. While holding the Oberer arms stationary,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated Dumbbell Palms-Down Wrist Curl',
    description: 'Start out by placing two dumbbells on the floor in front of a flat bench. Sit down on the edge of the flat bench with your legs at about shoulder width apart. Make sure to keep your feet on the floor. Use your arms to grab both of the dumbbells and bring them up so that your forearms are resting against your thighs with the palms of the hands facing down. Your wrists should be hanging over the...',
    nameDe: 'Sitzend Kurzhantel Palms-Down Handgelenk-Curl',
    descriptionDe: 'Start out by placing two Kurzhanteln on the Boden in front of a Flachbank Bank. Sit down on the edge of the Flachbank Bank with your legs at about Schulter width apart. Make sure to keep your feet on the Boden. Use your arms to grab both of the Kurzhanteln and bring them up so that your Unterarme...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated Dumbbell Palms-Up Wrist Curl',
    description: 'Start out by placing two dumbbells on the floor in front of a flat bench. Sit down on the edge of the flat bench with your legs at about shoulder width apart. Make sure to keep your feet on the floor. Use your arms to grab both of the dumbbells and bring them up so that your forearms are resting against your thighs with the palms of the hands facing up. Your wrists should be hanging over the edge...',
    nameDe: 'Sitzend Kurzhantel Palms-Up Handgelenk-Curl',
    descriptionDe: 'Start out by placing two Kurzhanteln on the Boden in front of a Flachbank Bank. Sit down on the edge of the Flachbank Bank with your legs at about Schulter width apart. Make sure to keep your feet on the Boden. Use your arms to grab both of the Kurzhanteln and bring them up so that your Unterarme...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated Dumbbell Press',
    description: 'Grab a couple of dumbbells and sit on a military press bench or a utility bench that has a back support on it as you place the dumbbells upright on top of your thighs. Clean the dumbbells up one at a time by using your thighs to bring the dumbbells up to shoulder height at each side. Rotate the wrists so that the palms of your hands are facing forward. This is your starting position. As you...',
    nameDe: 'Sitzend Kurzhantel Drücken',
    descriptionDe: 'Grab a couple of Kurzhanteln and sit on a military Drücken Bank or a utility Bank that has a Rücken support on it as you place the Kurzhanteln Aufrecht on top of your thighs. Stoßen the Kurzhanteln up one at a time by using your thighs to bring the Kurzhanteln up to Schulter height at each side....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Seated Flat Bench Leg Pull-In',
    description: 'Sit on a bench with the legs stretched out in front of you slightly below parallel and your arms holding on to the sides of the bench. Your torso should be leaning backwards around a 45-degree angle from the bench. This will be your starting position. Bring the knees in toward you as you move your torso closer to them at the same time. Breathe out as you perform this movement. After a second...',
    nameDe: 'Sitzend Flachbank Bank Leg Pull-In',
    descriptionDe: 'Sit on a Bank with the legs stretched out in front of you slightly below parallel and your arms holding on to the sides of the Bank. Your torso should be leaning backwards around a 45-degree angle from the Bank. This will be your starting position. Bring the knees in toward you as you move your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Seated Head Harness Neck Resistance',
    description: 'Place a neck strap on the floor at the end of a flat bench. Once you have selected the weights, sit at the end of the flat bench with your feet wider than shoulder width apart from each other. Your toes should be pointed out. Slowly move your torso forward until it is almost parallel with the floor. Using both hands, securely position the neck strap around your head. Tip: Make sure the weights...',
    nameDe: 'Sitzend Kopf Harness Nacken Resistance',
    descriptionDe: 'Place a Nacken strap on the Boden at the end of a Flachbank Bank. Once you have selected the weights, sit at the end of the Flachbank Bank with your feet wider than Schulter width apart from each other. Your toes should be pointed out. Slowly move your torso forward until it is almost parallel with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.fullBody],
  ),

  Exercise(
    name: 'Seated Leg Curl',
    description: 'Adjust the machine lever to fit your height and sit on the machine with your back against the back support pad. Place the back of lower leg on top of padded lever (just a few inches under the calves) and secure the lap pad against your thighs, just above the knees. Then grasp the side handles on the machine as you point your toes straight (or you can also use any of the other two stances) and...',
    nameDe: 'Sitzend Beincurl',
    descriptionDe: 'Adjust the Maschine lever to fit your height and sit on the Maschine with your Rücken against the Rücken support pad. Place the Rücken of Unterer leg on top of padded lever (just a few inches under the Waden) and secure the lap pad against your thighs, just above the knees. Then grasp the side...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Leg Tucks',
    description: 'Sit on a bench with the legs stretched out in front of you slightly below parallel and your arms holding on to the sides of the bench. Your torso should be leaning backwards around a 45-degree angle from the bench. This will be your starting position. Bring the knees in toward you as you move your torso closer to them at the same time. Breathe out as you perform this movement. After a second...',
    nameDe: 'Sitzend Leg Tucks',
    descriptionDe: 'Sit on a Bank with the legs stretched out in front of you slightly below parallel and your arms holding on to the sides of the Bank. Your torso should be leaning backwards around a 45-degree angle from the Bank. This will be your starting position. Bring the knees in toward you as you move your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Seated One-Arm Dumbbell Palms-Down Wrist Curl',
    description: 'Sit on a flat bench with a dumbbell in your right hand. Place your feet flat on the floor, at a distance that is slightly wider than shoulder width apart. Lean forward and place your right forearm on top of your upper right thigh with your palm down. Tip: Make sure that the back of the wrist lies on top of your knees. This will be your starting position. Lower the dumbbell as far as possible as...',
    nameDe: 'Sitzend Einarmig Kurzhantel Palms-Down Handgelenk-Curl',
    descriptionDe: 'Sit on a Flachbank Bank with a Kurzhantel in your right hand. Place your feet Flachbank on the Boden, at a distance that is slightly wider than Schulter width apart. Lean forward and place your right Unterarm on top of your Oberer right Oberschenkel with your palm down. Tip: Make sure that the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated One-Arm Dumbbell Palms-Up Wrist Curl',
    description: 'Sit on a flat bench with a dumbbell in your right hand. Place your feet flat on the floor, at a distance that is slightly wider than shoulder width apart. Lean forward and place your right forearm on top of your upper right thigh with your palm up. Tip: Make sure that the front of the wrist lies on top of your knees. This will be your starting position. Lower the dumbbell as far as possible as...',
    nameDe: 'Sitzend Einarmig Kurzhantel Palms-Up Handgelenk-Curl',
    descriptionDe: 'Sit on a Flachbank Bank with a Kurzhantel in your right hand. Place your feet Flachbank on the Boden, at a distance that is slightly wider than Schulter width apart. Lean forward and place your right Unterarm on top of your Oberer right Oberschenkel with your palm up. Tip: Make sure that the front...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated One-arm Cable Pulley Rows',
    description: 'To get into the starting position, first sit down on the machine and place your feet on the front platform or crossbar provided making sure that your knees are slightly bent and not locked. Lean over as you keep the natural alignment of your back and grab the single handle attachment with your left arm using a palms-down grip. With your arm extended pull back until your torso is at a 90-degree...',
    nameDe: 'Sitzend Einarmig Kabelzug Pulley Rows',
    descriptionDe: 'To get into the starting position, first sit down on the Maschine and place your feet on the front platform or crossbar provided making sure that your knees are slightly bent and not locked. Lean over as you keep the natural alignment of your Rücken and grab the single handle attachment with your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Seated Palm-Up Barbell Wrist Curl',
    description: 'Hold a barbell with both hands and your palms facing up; hands spaced about shoulder width. Place your feet flat on the floor, at a distance that is slightly wider than shoulder width apart. Lean forward and place your forearms on top of your upper thighs with your palms up. Tip: Make sure that the front of the wrists lay on top of your knees. This will be your starting position. Lower the bar as...',
    nameDe: 'Sitzend Palm-Up Langhantel Handgelenk-Curl',
    descriptionDe: 'Hold a Langhantel with both hands and your palms facing up; hands spaced about Schulter width. Place your feet Flachbank on the Boden, at a distance that is slightly wider than Schulter width apart. Lean forward and place your Unterarme on top of your Oberer thighs with your palms up. Tip: Make...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated Palms-Down Barbell Wrist Curl',
    description: 'Hold a barbell with both hands and your palms facing down; hands spaced about shoulder width. Place your feet flat on the floor, at a distance that is slightly wider than shoulder width apart. Lean forward and place your forearms on top of your upper thighs with your palms down. Tip: Make sure that the back of the wrists lay on top of your knees. This will be your starting position. Lower the bar...',
    nameDe: 'Sitzend Palms-Down Langhantel Handgelenk-Curl',
    descriptionDe: 'Hold a Langhantel with both hands and your palms facing down; hands spaced about Schulter width. Place your feet Flachbank on the Boden, at a distance that is slightly wider than Schulter width apart. Lean forward and place your Unterarme on top of your Oberer thighs with your palms down. Tip: Make...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated Side Lateral Raise',
    description: 'Pick a couple of dumbbells and sit at the end of a flat bench with your feet firmly on the floor. Hold the dumbbells with your palms facing in and your arms straight down at your sides at arms\' length. This will be your starting position. While maintaining the torso stationary (no swinging), lift the dumbbells to your side with a slight bend on the elbow and the hands slightly tilted forward as...',
    nameDe: 'Sitzend Side Seitlich Heben',
    descriptionDe: 'Pick a couple of Kurzhanteln and sit at the end of a Flachbank Bank with your feet firmly on the Boden. Hold the Kurzhanteln with your palms facing in and your arms straight down at your sides at arms\' length. This will be your starting position. While maintaining the torso stationary (no...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Seated Triceps Press',
    description: 'Sit down on a bench with back support and grasp a dumbbell with both hands and hold it overhead at arm\'s length. Tip: a better way is to have somebody hand it to you especially if it is very heavy. The resistance should be resting in the palms of your hands with your thumbs around it. The palm of the hand should be facing inward. This will be your starting position. Keeping your upper arms close...',
    nameDe: 'Sitzend Trizeps Drücken',
    descriptionDe: 'Sit down on a Bank with Rücken support and grasp a Kurzhantel with both hands and hold it Überkopf at arm\'s length. Tip: a better way is to have somebody hand it to you especially if it is very heavy. The resistance should be resting in the palms of your hands with your thumbs around it. The palm...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Seated Two-Arm Palms-Up Low-Pulley Wrist Curl',
    description: 'Put a bench in front of a low pulley machine that has a barbell or EZ Curl attachment on it. Move the bench far enough away so that when you bring the handle to the top of your thighs tension is created on the cable due to the weight stack being moved up. Now hold the handle with both hands, palms up, using a shoulder-width grip. Step back and sit on the bench with your feet about shoulder width...',
    nameDe: 'Sitzend Beidarmig Palms-Up Low-Pulley Handgelenk-Curl',
    descriptionDe: 'Put a Bank in front of a low pulley Maschine that has a Langhantel or EZ Curl attachment on it. Move the Bank far enough away so that when you bring the handle to the top of your thighs tension is created on the Kabelzug due to the weight stack being moved up. Now hold the handle with both hands,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'See-Saw Press (Alternating Side Press)',
    description: 'Grab a dumbbell with each hand and stand up erect. Clean (lift) the dumbbells to the chest/shoulder level and then rotate your wrists so that your palms are facing towards you as if you were getting ready to perform an Arnold Press. This will be your starting position. Now start extending your left arm overhead as you rotate the wrist so that the palm of your hand faces forward as you go up. Your...',
    nameDe: 'See-Saw Drücken (Alternierend Side Drücken)',
    descriptionDe: 'Grab a Kurzhantel with each hand and stand up erect. Stoßen (lift) the Kurzhanteln to the Brust/Schulter level and then rotate your wrists so that your palms are facing towards you as if you were getting ready to perform an Arnold Drücken. This will be your starting position. Now start extending...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Shotgun Row',
    description: 'Attach a single handle to a low cable. After selecting the correct weight, stand a couple feet back with a wide-split stance. Your arm should be extended and your shoulder forward. This will be your starting position. Perform the movement by retracting the shoulder and flexing the elbow. As you pull, supinate the wrist, turning the palm upward as you go. After a brief pause, return to the...',
    nameDe: 'Shotgun Rudern',
    descriptionDe: 'Attach a single handle to a low Kabelzug. After selecting the correct weight, stand a couple feet Rücken with a wide-split stance. Your arm should be extended and your Schulter forward. This will be your starting position. Perform the movement by retracting the Schulter and flexing the elbow. As...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Shoulder Press - With Bands',
    description: 'To begin, stand on an exercise band so that tension begins at arm\'s length. Grasp the handles and lift them so that the hands are at shoulder height at each side. Rotate the wrists so that the palms of your hands are facing forward. Your elbows should be bent, with the upper arms and forearms in line to the torso. This is your starting position. As you exhale, lift the handles up until your arms...',
    nameDe: 'Schulterdrücken - mit Band',
    descriptionDe: 'To begin, stand on an exercise Band so that tension begins at arm\'s length. Grasp the handles and lift them so that the hands are at Schulter height at each side. Rotate the wrists so that the palms of your hands are facing forward. Your elbows should be bent, with the Oberer arms and Unterarme in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Side Bridge',
    nameDe: 'Side Brücke',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Side Jackknife',
    nameDe: 'Side Jackknife',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Side Lateral Raise',
    description: 'Pick a couple of dumbbells and stand with a straight torso and the dumbbells by your side at arms length with the palms of the hand facing you. This will be your starting position. While maintaining the torso in a stationary position (no swinging), lift the dumbbells to your side with a slight bend on the elbow and the hands slightly tilted forward as if pouring water in a glass. Continue to go...',
    nameDe: 'Seitliches Seitheben',
    descriptionDe: 'Pick a couple of Kurzhanteln and stand with a straight torso and the Kurzhanteln by your side at arms length with the palms of the hand facing you. This will be your starting position. While maintaining the torso in a stationary position (no swinging), lift the Kurzhanteln to your side with a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Side Laterals to Front Raise',
    description: 'In a standing position, hold a pair of dumbbells at your side. This will be your starting position. Keeping your elbows slightly bent, raise the weights directly in front of you to shoulder height, avoiding any swinging or cheating. At the top of the exercise move the weights out in front of you, keeping your arms extended. Lower the weights with a controlled motion. On the next repetition, raise...',
    nameDe: 'Side Laterals to Front Heben',
    descriptionDe: 'In a Stehend position, hold a pair of Kurzhanteln at your side. This will be your starting position. Keeping your elbows slightly bent, Heben the weights directly in front of you to Schulter height, avoiding any swinging or cheating. At the top of the exercise move the weights out in front of you,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Side To Side Chins',
    description: 'Grab the pull-up bar with the palms facing forward using a wide grip. As you have both arms extended in front of you holding the bar at a wide grip, bring your torso back around 30 degrees or so while creating a curvature on your lower back and sticking your chest out. This is your starting position. Pull your torso up while leaning to the left hand side until the bar almost touches your upper...',
    nameDe: 'Side To Side Chins',
    descriptionDe: 'Grab the Klimmzugstange with the palms facing forward using a Weiter Griff. As you have both arms extended in front of you holding the Stange at a Weiter Griff, bring your torso Rücken around 30 degrees or so while creating a curvature on your Unterer Rücken and sticking your Brust out. This is...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Single-Arm Cable Crossover',
    description: 'Begin by moving the pulleys to the high position, select the resistance to be used, and take a handle in each hand. Step forward in front of both pulleys with your arms extended in front of you, bringing your hands together. Your head and chest should be up as you lean forward, while your feet should be staggered. This will be your starting position. Keeping your left arm in place, allow your...',
    nameDe: 'Einarmig Kabelzug Crossover',
    descriptionDe: 'Begin by moving the pulleys to the high position, select the resistance to be used, and take a handle in each hand. Stufe forward in front of both pulleys with your arms extended in front of you, bringing your hands together. Your Kopf and Brust should be up as you lean forward, while your feet...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Single-Arm Linear Jammer',
    description: 'Position a bar into a landmine or securely anchor it in a corner. Load the bar to an appropriate weight. Raise the bar from the floor, taking it to your shoulders with one or both hands. Adopt a wide stance. This will be your starting position. Perform the movement by extending the elbow, pressing the weight up. Move explosively, extending the hips and knees fully to produce maximal force. Return...',
    nameDe: 'Einarmig Linear Jammer',
    descriptionDe: 'Position a Stange into a landmine or securely anchor it in a corner. Load the Stange to an appropriate weight. Heben the Stange from the Boden, taking it to your Schultern with one or both hands. Adopt a wide stance. This will be your starting position. Perform the movement by extending the elbow,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Single-Arm Push-Up',
    description: 'Begin laying prone on the ground. Move yourself into a position supporting your weight on your toes and one arm. Your working arm should be placed directly under the shoulder, fully extended. Your legs should be extended, and for this movement you may need a wider base, placing your feet further apart than in a normal push-up. Maintain good posture, and place your free hand behind your back. This...',
    nameDe: 'Einarmig Liegestütz',
    descriptionDe: 'Begin laying Bauchlage on the ground. Move yourself into a position supporting your weight on your toes and Einarmig. Your working arm should be placed directly under the Schulter, fully extended. Your legs should be extended, and for this movement you may need a wider base, placing your feet...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Single-Leg High Box Squat',
    description: 'Position a box in a rack. Secure a band or rope in place above the box. Standing in front of it, step onto the box to a full standing position, letting your other leg remain unsupported. Hold onto the band for balance . Continue stepping up and down on the same leg before switching to the opposite side.',
    nameDe: 'Single-Leg High Box Kniebeuge',
    descriptionDe: 'Position a Box in a Ständer. Secure a Band or Seil in place above the Box. Stehend in front of it, Stufe onto the Box to a Komplett Stehend position, letting your other leg remain unsupported. Hold onto the Band for balance . Continue stepping up and down on the same leg before switching to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Single-Leg Leg Extension',
    description: 'Seat yourself in the machine and adjust it so that you are positioned properly. The pad should be against the lower part of the shin but not in contact with the ankle. Adjust the seat so that the pivot point is in line with your knee. Select a weight appropriate for your abilities. Maintaining good posture, fully extend one leg, pausing at the top of the motion. Return to the starting position...',
    nameDe: 'Single-Leg Leg Streckung',
    descriptionDe: 'Seat yourself in the Maschine and adjust it so that you are positioned properly. The pad should be against the Unterer part of the Schienbein but not in contact with the Knöchel. Adjust the seat so that the pivot point is in line with your Knie. Select a weight appropriate for your abilities....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Single Dumbbell Raise',
    description: 'With a wide stance, hold a dumbell with both hands, grasping the head of the dumbbell instead of the handle. Your arms should be extended and hanging at the waist. This will be your starting position. Raise the weight until it is above shoulder level, keeping your arms extended. Your torso and hips should remain stationary throughout the movement. Return to the starting position and repeat for...',
    nameDe: 'Single Kurzhantel Heben',
    descriptionDe: 'With a wide stance, hold a dumbell with both hands, grasping the Kopf of the Kurzhantel instead of the handle. Your arms should be extended and hanging at the waist. This will be your starting position. Heben the weight until it is above Schulter level, keeping your arms extended. Your torso and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Single Leg Glute Bridge',
    description: 'Lay on the floor with your feet flat and knees bent. Raise one leg off of the ground, pulling the knee to your chest. This will be your starting position. Execute the movement by driving through the heel, extending your hip upward and raising your glutes off of the ground. Extend as far as possible, pause and then return to the starting position.',
    nameDe: 'Single Leg Gesäßbrücke',
    descriptionDe: 'Lay on the Boden with your feet Flachbank and knees bent. Heben one leg off of the ground, pulling the Knie to your Brust. This will be your starting position. Execute the movement by driving through the heel, extending your Hüfte upward and raising your Gesäß off of the ground. Extend as far as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Sit-Up',
    description: 'Lie down on the floor placing your feet either under something that will not move or by having a partner hold them. Your legs should be bent at the knees. Place your hands behind your head and lock them together by clasping your fingers. This is the starting position. Elevate your upper body so that it creates an imaginary V-shape with your thighs. Breathe out when performing this part of the...',
    nameDe: 'Sit-Up',
    descriptionDe: 'Lie down on the Boden placing your feet either under something that will not move or by having a partner hold them. Your legs should be bent at the knees. Place your hands behind your Kopf and lock them together by clasping your fingers. This is the starting position. Elevate your Oberer body so...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Sled Overhead Backward Walk',
    description: 'Attach dual handles to a sled connected by a rope or chain. Load the sled to a light weight. Face the sled, backing up until there is some tension in the line. Hold your hands directly above your head with your elbows extended. This will be your starting position. Walk backwards, keeping your arms raised above your head. Avoid jerky movements.',
    nameDe: 'Schlitten Überkopf Backward Gehen',
    descriptionDe: 'Attach dual handles to a Schlitten connected by a Seil or chain. Load the Schlitten to a light weight. Face the Schlitten, backing up until there is some tension in the line. Hold your hands directly above your Kopf with your elbows extended. This will be your starting position. Gehen backwards,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Sled Overhead Triceps Extension',
    description: 'Attach dual handles to a sled using a chain or rope. Load the sled to an appropriate load. Facing away from the sled, step away until there is tension in the line. Raise your hands above your head, keeping them together, palms facing each other. Your elbows should be pointed upward with the elbows flexed. This will be your starting position. Extend through the elbow to straighten the arm. Ensure...',
    nameDe: 'Schlitten Überkopf Trizepsstreckung',
    descriptionDe: 'Attach dual handles to a Schlitten using a chain or Seil. Load the Schlitten to an appropriate load. Facing away from the Schlitten, Stufe away until there is tension in the line. Heben your hands above your Kopf, keeping them together, palms facing each other. Your elbows should be pointed upward...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Sled Reverse Flye',
    description: 'Attach dual handles to a sled connected by a rope or chain. Load the sled to a light weight. Face the sled, backing up until there is some tension in the line. Take both handles at arms length at about waist level. Bend the knees slightly and keep your chest and head up. This will be your starting position. Without flexing the elbow, pull the handles upward and apart, performing a reverse fly...',
    nameDe: 'Schlitten Umgekehrt Fliegender',
    descriptionDe: 'Attach dual handles to a Schlitten connected by a Seil or chain. Load the Schlitten to a light weight. Face the Schlitten, backing up until there is some tension in the line. Take both handles at arms length at about waist level. Bend the knees slightly and keep your Brust and Kopf up. This will be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Sled Row',
    description: 'Attach dual handles to a sled connected by a rope or chain. Load the sled to an appropriate weight. Face the sled, backing up until there is some tension in the line. With a handle in each hand, bend the knees slightly, keep your head and chest up, and begin with your arms extended. To initiate the movement, flex the elbow as you retract your shoulder blades, pulling the sled towards you. Take a...',
    nameDe: 'Schlitten Rudern',
    descriptionDe: 'Attach dual handles to a Schlitten connected by a Seil or chain. Load the Schlitten to an appropriate weight. Face the Schlitten, backing up until there is some tension in the line. With a handle in each hand, bend the knees slightly, keep your Kopf and Brust up, and begin with your arms extended....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Smith Incline Shoulder Raise',
    description: 'Place an incline bench underneath the smith machine. Place the barbell at a height that you can reach when lying down and your arms are almost fully extended. Once the weight you need is selected, lie down on the incline bench and make sure your shoulders are aligned right under the barbell. Using a shoulder width pronated (palms forward) grip, lift the bar from the rack and hold it straight over...',
    nameDe: 'Smith Schrägbank Schulter Heben',
    descriptionDe: 'Place an Schrägbank Bank underneath the Smith-Maschine. Place the Langhantel at a height that you can reach when Liegend down and your arms are almost fully extended. Once the weight you need is selected, lie down on the Schrägbank Bank and make sure your Schultern are aligned right under the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Smith Machine Behind the Back Shrug',
    description: 'With the bar at thigh level, load an appropriate weight. Stand with the bar behind you, taking a shoulder-width, pronated grip on the bar and unhook the weight. You should be standing up straight with your head and chest up and your arms extended. This will be your starting position. Initiate the movement by shrugging your shoulders straight up. Do not flex the arms or wrist during the movement....',
    nameDe: 'Smith-Maschine Behind the Rücken Schulterziehen',
    descriptionDe: 'With the Stange at Oberschenkel level, load an appropriate weight. Stand with the Stange behind you, taking a Schulter-width, Proniert grip on the Stange and unhook the weight. You should be Stehend up straight with your Kopf and Brust up and your arms extended. This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Smith Machine Bench Press',
    description: 'Place a flat bench underneath the smith machine. Now place the barbell at a height that you can reach when lying down and your arms are almost fully extended. Once the weight you need is selected, lie down on the flat bench. Using a pronated grip that is wider than shoulder width, unlock the bar from the rack and hold it straight over you with your arms locked. This will be your starting...',
    nameDe: 'Smith-Maschine Bank Drücken',
    descriptionDe: 'Place a Flachbank Bank underneath the Smith-Maschine. Now place the Langhantel at a height that you can reach when Liegend down and your arms are almost fully extended. Once the weight you need is selected, lie down on the Flachbank Bank. Using a Proniert grip that is wider than Schulter width,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Smith Machine Bent Over Row',
    description: 'Set the barbell attached to the smith machine to a height that is about 2 inches below your knees. Bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the back straight until it is almost parallel to the floor. Tip: Make sure that you keep the head up. Now grasp the barbell using an overhand (pronated) grip and unlock it from the smith machine rack. Then...',
    nameDe: 'Smith-Maschine Vorgebeugtes Rudern',
    descriptionDe: 'Set the Langhantel attached to the Smith-Maschine to a height that is about 2 inches below your knees. Bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the Rücken straight until it is almost parallel to the Boden. Tip: Make sure that you keep the Kopf...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Smith Machine Calf Raise',
    description: 'Place a block or weight plate below the bar on the Smith machine. Set the bar to a position that best matches your height. Once the correct height is chosen and the bar is loaded, step onto the plates with the balls of your feet and place the bar on the back of your shoulders. Take the bar with both hands facing forward. Rotate the bar to unrack it. This will be your starting position. Raise your...',
    nameDe: 'Smith-Maschine Wadenlifte',
    descriptionDe: 'Place a block or weight Scheibe below the Stange on the Smith-Maschine. Set the Stange to a position that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe onto the plates with the balls of your feet and place the Stange on the Rücken of your Schultern....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Smith Machine Close-Grip Bench Press',
    description: 'Place a flat bench underneath the smith machine. Place the barbell at a height that you can reach when lying down and your arms are almost fully extended. Once the weight you need is selected, lie down on the flat bench. Using a close and pronated grip (palms facing forward) that is around shoulder width, unlock the bar from the rack and hold it straight over you with your arms locked. This will...',
    nameDe: 'Smith-Maschine Enger Griff Bank Drücken',
    descriptionDe: 'Place a Flachbank Bank underneath the Smith-Maschine. Place the Langhantel at a height that you can reach when Liegend down and your arms are almost fully extended. Once the weight you need is selected, lie down on the Flachbank Bank. Using a close and Proniert grip (palms facing forward) that is...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Smith Machine Decline Press',
    description: 'Position a decline bench in the rack so that the bar will be above your chest. Load an appropriate weight and take your place on the bench. Rotate the bar to unhook it from the rack and fully extend your arms. Your back should be slightly arched and your shoulder blades retracted. This will be your starting position. Begin the movement by flexing your arms, lowering the bar to your chest. Pause...',
    nameDe: 'Smith-Maschine Negativbank Drücken',
    descriptionDe: 'Position a Negativbank Bank in the Ständer so that the Stange will be above your Brust. Load an appropriate weight and take your place on the Bank. Rotate the Stange to unhook it from the Ständer and fully extend your arms. Your Rücken should be slightly arched and your Schulter blades retracted....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Smith Machine Hang Power Clean',
    description: 'Position the bar at knee height and load it to an appropriate weight. Take a pronated grip on the bar outside of shoulder width and unhook the bar from the machine. Your arms should be fully extended with your head and chest up. Your elbows should be pointed out with your shoulders back and down. Your hips should be back, loading the tension into the hamstrings. This will be your starting...',
    nameDe: 'Smith-Maschine Hang Power-Stoßen',
    descriptionDe: 'Position the Stange at Knie height and load it to an appropriate weight. Take a Proniert grip on the Stange outside of Schulter width and unhook the Stange from the Maschine. Your arms should be fully extended with your Kopf and Brust up. Your elbows should be pointed out with your Schultern Rücken...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Smith Machine Hip Raise',
    description: 'Position a bench in the rack and load the bar to an appropriate weight. Lie down on the bench, placing the bottom of your feet against the bar. Unlock the bar and extend your legs. You may need to use your hands to assist you. For added stability grasp the sides of the Smith Machine. This will be your starting position. Initiate the movement by rotating your pelvis, flexing your spine to raise...',
    nameDe: 'Smith-Maschine Hüfte Heben',
    descriptionDe: 'Position a Bank in the Ständer and load the Stange to an appropriate weight. Lie down on the Bank, placing the bottom of your feet against the Stange. Unlock the Stange and extend your legs. You may need to use your hands to assist you. For added stability grasp the sides of the Smith-Maschine....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Smith Machine Incline Bench Press',
    description: 'Place an incline bench underneath the smith machine. Place the barbell at a height that you can reach when lying down and your arms are almost fully extended. Once the weight you need is selected, lie down on the incline bench and make sure your upper chest is aligned with the barbell. Using a pronated grip (palms facing forward) that is wider than shoulder width, unlock the bar from the rack and...',
    nameDe: 'Smith-Maschine Schrägbank Bank Drücken',
    descriptionDe: 'Place an Schrägbank Bank underneath the Smith-Maschine. Place the Langhantel at a height that you can reach when Liegend down and your arms are almost fully extended. Once the weight you need is selected, lie down on the Schrägbank Bank and make sure your Oberer Brust is aligned with the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Smith Machine Leg Press',
    description: 'Position a Smith machine bar a couple feet off of the ground. Ensure that it is resting on the safeties. After loading the bar to an appropriate weight, lie underneath the bar. Place the middle of your feet on the bar, tucking your knees to your chest. This will be your starting position. Begin the movement by driving through your feet to move the bar upward, extending the hips and knees. Do not...',
    nameDe: 'Smith-Maschine Beinpresse',
    descriptionDe: 'Position a Smith-Maschine Stange a couple feet off of the ground. Ensure that it is resting on the safeties. After loading the Stange to an appropriate weight, lie underneath the Stange. Place the middle of your feet on the Stange, tucking your knees to your Brust. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Smith Machine One-Arm Upright Row',
    description: 'With the bar at thigh level, load an appropriate weight. Take a wide grip on the bar and unhook the weight, removing your off hand from the bar. Your arm should be extended as you stand up straight with your head and chest up. This will be your starting position. Begin the movement by flexing the elbow, raising the upper arm with the elbow pointed out. Continue until your upper arm is parallel to...',
    nameDe: 'Smith-Maschine Einarmig Aufrechtes Rudern',
    descriptionDe: 'With the Stange at Oberschenkel level, load an appropriate weight. Take a Weiter Griff on the Stange and unhook the weight, removing your off hand from the Stange. Your arm should be extended as you stand up straight with your Kopf and Brust up. This will be your starting position. Begin the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Smith Machine Overhead Shoulder Press',
    description: 'To begin, place a flat bench (or preferably one with back support) underneath a smith machine. Position the barbell at a height so that when seated on the flat bench, the arms must be almost fully extended to reach the barbell. Once you have the correct height, sit slightly in behind the barbell so that there is an imaginary straight line from the tip of your nose to the barbell. Your feet should...',
    nameDe: 'Smith-Maschine Überkopf Schulterdrücken',
    descriptionDe: 'To begin, place a Flachbank Bank (or preferably one with Rücken support) underneath a Smith-Maschine. Position the Langhantel at a height so that when Sitzend on the Flachbank Bank, the arms must be almost fully extended to reach the Langhantel. Once you have the correct height, sit slightly in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Smith Machine Pistol Squat',
    description: 'To begin, first set the bar to a position that best matches your height. Step under it and position the bar across the back of your shoulders. Take the bar with your hands facing forward, unlock it and lift it off the rack by extending your legs. 3 Move one foot forward about 12 inches in front of the bar. Extend the other leg out in front of you, holding it off the ground. Look forward at all...',
    nameDe: 'Smith-Maschine Pistol Kniebeuge',
    descriptionDe: 'To begin, first set the Stange to a position that best matches your height. Stufe under it and position the Stange across the Rücken of your Schultern. Take the Stange with your hands facing forward, unlock it and lift it off the Ständer by extending your legs. 3 Move one foot forward about 12...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Smith Machine Reverse Calf Raises',
    description: 'Adjust the barbell on the smith machine to fit your height and align a raised platform right under the bar. Stand on the platform with the heels of your feet secured on top of it with the balls of your feet extending off it. Position your toes facing forward with a shoulder width stance. Now, place your shoulders under the barbell while maintaining the foot positioning described and push the...',
    nameDe: 'Smith-Maschine Umgekehrt Wade Raises',
    descriptionDe: 'Adjust the Langhantel on the Smith-Maschine to fit your height and align a raised platform right under the Stange. Stand on the platform with the heels of your feet secured on top of it with the balls of your feet extending off it. Position your toes facing forward with a Schulter width stance....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Smith Machine Squat',
    description: 'To begin, first set the bar on the height that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side (palms facing forward), unlock it and lift it off the rack by first pushing with your legs and at the same time straightening...',
    nameDe: 'Smith-Maschine Kniebeuge',
    descriptionDe: 'To begin, first set the Stange on the height that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the Nacken) across it. Hold on to the Stange using both arms at each side (palms...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Smith Machine Stiff-Legged Deadlift',
    description: 'To begin, set the bar on the smith machine to a height that is around the middle of your thighs. Once the correct height is chosen and the bar is loaded, grasp the bar using a pronated (palms forward) grip that is shoulder width apart. You may need some wrist wraps if using a significant amount of weight. Lift the bar up by fully extending your arms while keeping your back straight. Stand with...',
    nameDe: 'Smith-Maschine Stiff-Legged Kreuzheben',
    descriptionDe: 'To begin, set the Stange on the Smith-Maschine to a height that is around the middle of your thighs. Once the correct height is chosen and the Stange is loaded, grasp the Stange using a Proniert (palms forward) grip that is Schulter width apart. You may need some Handgelenk wraps if using a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Smith Machine Upright Row',
    description: 'To begin, set the bar on the smith machine to a height that is around the middle of your thighs. Once the correct height is chosen and the bar is loaded, grasp the bar using a pronated (palms forward) grip that is shoulder width apart. You may need some wrist wraps if using a significant amount of weight. Lift the barbell up and fully extend your arms with your back straight. There should be a...',
    nameDe: 'Smith-Maschine Aufrechtes Rudern',
    descriptionDe: 'To begin, set the Stange on the Smith-Maschine to a height that is around the middle of your thighs. Once the correct height is chosen and the Stange is loaded, grasp the Stange using a Proniert (palms forward) grip that is Schulter width apart. You may need some Handgelenk wraps if using a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Smith Single-Leg Split Squat',
    description: 'To begin, place a flat bench 2-3 feet behind the smith machine. Then, set the bar on the height that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side (palms facing forward), unlock it and lift it off the rack by first...',
    nameDe: 'Smith Single-Leg Split Kniebeuge',
    descriptionDe: 'To begin, place a Flachbank Bank 2-3 feet behind the Smith-Maschine. Then, set the Stange on the height that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the Nacken) across it....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Snatch Pull',
    description: 'With a barbell on the floor close to the shins, take a wide snatch grip. Lower your hips with the weight focused on the heels, back straight, head facing forward, chest up, with your shoulders just in front of the bar. This will be your starting position. Begin the first pull by driving through the heels, extending your knees. Your back angle should stay the same, and your arms should remain...',
    nameDe: 'Reißen-Zug',
    descriptionDe: 'With a Langhantel on the Boden close to the shins, take a wide Reißen grip. Unterer your Hüften with the weight focused on the heels, Rücken straight, Kopf facing forward, Brust up, with your Schultern just in front of the Stange. This will be your starting position. Begin the first pull by driving...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Speed Band Overhead Triceps',
    description: 'For this exercise anchor a band to the ground. We used an incline bench and anchored the band to the base, standing over the bench. Alternatively, this could be performed standing on the band. To begin, pull the band behind your head, holding it with a pronated grip and your elbows up. This will be your starting position. To perform the movement, extend through the elbow to to straighten your...',
    nameDe: 'Speed Band Überkopf Trizeps',
    descriptionDe: 'For this exercise anchor a Band to the ground. We used an Schrägbank Bank and anchored the Band to the base, Stehend over the Bank. Alternatively, this could be performed Stehend on the Band. To begin, pull the Band behind your Kopf, holding it with a Proniert grip and your elbows up. This will be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Speed Squats',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs...',
    nameDe: 'Speed Squats',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Spell Caster',
    description: 'Hold a dumbbell in each hand with a pronated grip. Your feet should be wide with your hips and knees extended. This will be your starting position. Begin the movement by pulling both of the dumbbells to one side next to your hip, rotating your torso. Keeping your arms straight and the dumbbells parallel to the ground, rotate your torso to swing the weights to your opposite side. Continue...',
    nameDe: 'Spell Caster',
    descriptionDe: 'Hold a Kurzhantel in each hand with a Proniert grip. Your feet should be wide with your Hüften and knees extended. This will be your starting position. Begin the movement by pulling both of the Kurzhanteln to one side next to your Hüfte, rotating your torso. Keeping your arms straight and the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Spider Crawl',
    description: 'Begin in a prone position on the floor. Support your weight on your hands and toes, with your feet together and your body straight. Your arms should be bent to 90 degrees. This will be your starting position. Initiate the movement by raising one foot off of the ground. Externally rotate the leg and bring the knee toward your elbow, as far forward as possible. Return this leg to the starting...',
    nameDe: 'Spinne Crawl',
    descriptionDe: 'Begin in a Bauchlage position on the Boden. Support your weight on your hands and toes, with your feet together and your body straight. Your arms should be bent to 90 degrees. This will be your starting position. Initiate the movement by raising one foot off of the ground. Externally rotate the leg...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Spider Curl',
    description: 'Start out by setting the bar on the part of the preacher bench that you would normally sit on. Make sure to align the barbell properly so that it is balanced and will not fall off. Move to the front side of the preacher bench (the part where the arms usually lay) and position yourself to lay at a 45 degree slant with your torso and stomach pressed against the front side of the preacher bench....',
    nameDe: 'Spinne Curl',
    descriptionDe: 'Start out by setting the Stange on the part of the preacher Bank that you would normally sit on. Make sure to align the Langhantel properly so that it is balanced and will not fall off. Move to the front side of the preacher Bank (the part where the arms usually lay) and position yourself to lay at...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Split Squat with Dumbbells',
    description: 'Position yourself into a staggered stance with the rear foot elevated and front foot forward. Hold a dumbbell in each hand, letting them hang at the sides. This will be your starting position. Begin by descending, flexing your knee and hip to lower your body down. Maintain good posture througout the movement. Keep the front knee in line with the foot as you perform the exercise. At the bottom of...',
    nameDe: 'Split Kniebeuge with Kurzhanteln',
    descriptionDe: 'Position yourself into a staggered stance with the rear foot elevated and front foot forward. Hold a Kurzhantel in each hand, letting them hang at the sides. This will be your starting position. Begin by descending, flexing your Knie and Hüfte to Unterer your body down. Maintain good posture...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Squat Jerk',
    description: 'Standing with the weight racked on the front of the shoulders, begin with the dip. With your feet directly under your hips, flex the knees without moving the hips backward. Go down only slightly, and reverse direction as powerfully as possible. Drive through the heels create as much speed and force as possible, and be sure to move your head out of the way as the bar leaves the shoulders. At this...',
    nameDe: 'Kniebeuge Ausstoßen',
    descriptionDe: 'Stehend with the weight racked on the front of the Schultern, begin with the Dip. With your feet directly under your Hüften, flex the knees without moving the Hüften backward. Go down only slightly, and Umgekehrt direction as powerfully as possible. Drive through the heels create as much speed and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Squat with Plate Movers',
    description: 'To begin, first set the bar on a rack to just below shoulder level. Position a weight plate on the ground a couple feet back from the rack. Once the bar is loaded, step under it and place the back of your shoulders across it. Hold on to the bar with both hands and lift it off the rack by first pushing with your legs and at the same time straighten your torso. Step away from the rack and adopt a...',
    nameDe: 'Kniebeuge with Scheibe Movers',
    descriptionDe: 'To begin, first set the Stange on a Ständer to just below Schulter level. Position a weight Scheibe on the ground a couple feet Rücken from the Ständer. Once the Stange is loaded, Stufe under it and place the Rücken of your Schultern across it. Hold on to the Stange with both hands and lift it off...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Squats - With Bands',
    description: 'To start out, make sure that the exercise band is at an even split between both the left and right side of the body. To do this, use your hands to grab both sides of the band and place both feet in the middle of the band. Your feet should be shoulder width apart from each other. When holding the bands, they should be the same height on each side. You should be using a pronated grip (palms facing...',
    nameDe: 'Squats - mit Band',
    descriptionDe: 'To start out, make sure that the exercise Band is at an even split between both the left and right side of the body. To do this, use your hands to grab both sides of the Band and place both feet in the middle of the Band. Your feet should be Schulter width apart from each other. When holding the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Alternating Dumbbell Press',
    description: 'Stand with a dumbbell in each hand. Raise the dumbbells to your shoulders with your palms facing forward and your elbows pointed out. This will be your starting position. Extend one arm to press the dumbbell straight up, keeping your off hand in place. Do not lean or jerk the weight during the movement. After a brief pause, return the weight to the starting position. Repeat for the opposite side,...',
    nameDe: 'Stehend Alternierend Kurzhantel Drücken',
    descriptionDe: 'Stand with a Kurzhantel in each hand. Heben the Kurzhanteln to your Schultern with your palms facing forward and your elbows pointed out. This will be your starting position. Extend Einarmig to Drücken the Kurzhantel straight up, keeping your off hand in place. Do not lean or Ausstoßen the weight...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Barbell Calf Raise',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the bar on the back of your shoulders (slightly below the neck). Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs...',
    nameDe: 'Stehend Langhantel Wadenlifte',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Stange on the Rücken of your Schultern...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Barbell Press Behind Neck',
    description: 'This exercise is best performed inside a squat rack for easier pick up of the bar. To begin, first set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side and lift it off the rack by first pushing with...',
    nameDe: 'Stehend Langhantel Drücken Im Nacken',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for easier pick up of the Stange. To begin, first set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Bent-Over One-Arm Dumbbell Triceps Extension',
    description: 'With a dumbbell in one hand and the palm facing your torso, bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the back straight until it is almost parallel to the floor. Make sure that you keep the head up. The upper arm should be close to the torso and parallel to the floor while the forearm is pointing towards the floor as the hand holds the weight....',
    nameDe: 'Stehend Vorgebeugt Einarmig Kurzhantel Trizepsstreckung',
    descriptionDe: 'With a Kurzhantel in one hand and the palm facing your torso, bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the Rücken straight until it is almost parallel to the Boden. Make sure that you keep the Kopf up. The Oberer arm should be close to the torso...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Standing Bent-Over Two-Arm Dumbbell Triceps Extension',
    description: 'With a dumbbell in each hand and the palms facing your torso, bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the back straight until it is almost parallel to the floor. Make sure that you keep the head up. The upper arms should be close to the torso and parallel to the floor while the forearms are pointing towards the floor as the hands hold the...',
    nameDe: 'Stehend Vorgebeugt Beidarmig Kurzhantel Trizepsstreckung',
    descriptionDe: 'With a Kurzhantel in each hand and the palms facing your torso, bend your knees slightly and bring your torso forward, by bending at the waist, while keeping the Rücken straight until it is almost parallel to the Boden. Make sure that you keep the Kopf up. The Oberer arms should be close to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Standing Biceps Cable Curl',
    description: 'Stand up with your torso upright while holding a cable curl bar that is attached to a low pulley. Grab the cable bar at shoulder width and keep the elbows close to the torso. The palm of your hands should be facing up (supinated grip). This will be your starting position. While holding the upper arms stationary, curl the weights while contracting the biceps as you breathe out. Only the forearms...',
    nameDe: 'Stehend Bizeps Kabelzug Curl',
    descriptionDe: 'Stand up with your torso Aufrecht while holding a Kabelzug Curl Stange that is attached to a low pulley. Grab the Kabelzug Stange at Schulter width and keep the elbows close to the torso. The palm of your hands should be facing up (Supiniert grip). This will be your starting position. While holding...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing Bradford Press',
    description: 'Place a loaded bar at shoulder level in a rack. With a pronated grip at shoulder width, begin with the bar racked across the front of your shoulders. This is your starting position. Initiate the lift by extending the elbows to press the bar overhead. Avoid locking out the elbow as you move the weight behind your head. Lower the bar down to the back of the head until your elbow forms a right...',
    nameDe: 'Stehend Bradford Drücken',
    descriptionDe: 'Place a loaded Stange at Schulter level in a Ständer. With a Proniert grip at Schulter width, begin with the Stange racked across the front of your Schultern. This is your starting position. Initiate the lift by extending the elbows to Drücken the Stange Überkopf. Avoid locking out the elbow as you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Cable Chest Press',
    description: 'Position dual pulleys to chest height and select an appropriate weight. Stand a foot or two in front of the cables, holding one in each hand. You can stagger your stance for better stability. Position the upper arm at a 90 degree angle with the shoulder blades together. This will be your starting position. Keeping the rest of the body stationary, extend through the elbows to press the handles...',
    nameDe: 'Kabelzug-Brustdrücken stehend',
    descriptionDe: 'Position dual pulleys to Brust height and select an appropriate weight. Stand a foot or two in front of the cables, holding one in each hand. You can stagger your stance for better stability. Position the Oberer arm at a 90 degree angle with the Schulter blades together. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Standing Cable Lift',
    description: 'Connect a standard handle on a tower, and move the cable to the lowest pulley position. With your side to the cable, grab the handle with one hand and step away from the tower. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the cable. Your outstretched arm should be aligned with the cable. With your feet positioned shoulder width apart, squat down...',
    nameDe: 'Stehend Kabelzug Lift',
    descriptionDe: 'Connect a standard handle on a tower, and move the Kabelzug to the lowest pulley position. With your side to the Kabelzug, grab the handle with one hand and Stufe away from the tower. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the Kabelzug. Your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Standing Cable Wood Chop',
    description: 'Connect a standard handle to a tower, and move the cable to the highest pulley position. With your side to the cable, grab the handle with one hand and step away from the tower. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the cable. Your outstretched arm should be aligned with the cable. With your feet positioned shoulder width apart, reach...',
    nameDe: 'Stehend Kabelzug Wood Chop',
    descriptionDe: 'Connect a standard handle to a tower, and move the Kabelzug to the highest pulley position. With your side to the Kabelzug, grab the handle with one hand and Stufe away from the tower. You should be approximately arm\'s length away from the pulley, with the tension of the weight on the Kabelzug....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Standing Calf Raises',
    description: 'Adjust the padded lever of the calf raise machine to fit your height. Place your shoulders under the pads provided and position your toes facing forward (or using any of the two other positions described at the beginning of the chapter). The balls of your feet should be secured on top of the calf block with the heels extending off it. Push the lever up by extending your hips and knees until your...',
    nameDe: 'Stehend Wade Raises',
    descriptionDe: 'Adjust the padded lever of the Wadenlifte Maschine to fit your height. Place your Schultern under the pads provided and position your toes facing forward (or using any of the two other positions described at the beginning of the chapter). The balls of your feet should be secured on top of the Wade...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Concentration Curl',
    description: 'Taking a dumbbell in your working hand, lean forward. Allow your working arm to hang perpendicular to the ground with the elbow pointing out. This will be your starting position. Flex the elbow to curl the weight, keeping the upper arm stationary. At the top of the repetition, flex the biceps and pause. Lower the dumbbell back to the starting position. Repeat the movement for the prescribed...',
    nameDe: 'Stehend Konzentrations-Curl',
    descriptionDe: 'Taking a Kurzhantel in your working hand, lean forward. Allow your working arm to hang perpendicular to the ground with the elbow pointing out. This will be your starting position. Flex the elbow to Curl the weight, keeping the Oberer arm stationary. At the top of the repetition, flex the Bizeps...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing Dumbbell Calf Raise',
    description: 'Stand with your torso upright holding two dumbbells in your hands by your sides. Place the ball of the foot on a sturdy and stable wooden board (that is around 2-3 inches tall) while your heels extend off and touch the floor. This will be your starting position. With the toes pointing either straight (to hit all parts equally), inwards (for emphasis on the outer head) or outwards (for emphasis on...',
    nameDe: 'Stehend Kurzhantel Wadenlifte',
    descriptionDe: 'Stand with your torso Aufrecht holding two Kurzhanteln in your hands by your sides. Place the Ball of the foot on a sturdy and stable wooden board (that is around 2-3 inches tall) while your heels extend off and touch the Boden. This will be your starting position. With the toes pointing either...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Dumbbell Press',
    description: 'Standing with your feet shoulder width apart, take a dumbbell in each hand. Raise the dumbbells to head height, the elbows out and about 90 degrees. This will be your starting position. Maintaining strict technique with no leg drive or leaning back, extend through the elbow to raise the weights together directly above your head. Pause, and slowly return the weight to the starting position.',
    nameDe: 'Stehend Kurzhantel Drücken',
    descriptionDe: 'Stehend with your feet Schulter width apart, take a Kurzhantel in each hand. Heben the Kurzhanteln to Kopf height, the elbows out and about 90 degrees. This will be your starting position. Maintaining strict technique with no leg drive or leaning Rücken, extend through the elbow to Heben the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Dumbbell Reverse Curl',
    description: 'To begin, stand straight with a dumbbell in each hand using a pronated grip (palms facing down). Your arms should be fully extended while your feet are shoulder width apart from each other. This is the starting position. While holding the upper arms stationary, curl the weights while contracting the biceps as you breathe out. Only the forearms should move. Continue the movement until your biceps...',
    nameDe: 'Stehend Kurzhantel Umgekehrt-Curl',
    descriptionDe: 'To begin, stand straight with a Kurzhantel in each hand using a Proniert grip (palms facing down). Your arms should be fully extended while your feet are Schulter width apart from each other. This is the starting position. While holding the Oberer arms stationary, Curl the weights while contracting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing Dumbbell Straight-Arm Front Delt Raise Above Head',
    description: 'Hold the dumbbells in front of your thighs, palms facing your thighs. Keep your arms straight with a slight bend at the elbows but keep them locked. This will be your starting position. Raise the dumbbells in a semicircular motion to arm\'s length overhead as you exhale. Slowly return to the starting position using the same path as you inhale. Repeat for the recommended amount of repetitions.',
    nameDe: 'Stehend Kurzhantel Straight-Arm Front Delt Heben Above Kopf',
    descriptionDe: 'Hold the Kurzhanteln in front of your thighs, palms facing your thighs. Keep your arms straight with a slight bend at the elbows but keep them locked. This will be your starting position. Heben the Kurzhanteln in a semicircular motion to arm\'s length Überkopf as you exhale. Slowly return to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Dumbbell Triceps Extension',
    description: 'To begin, stand up with a dumbbell held by both hands. Your feet should be about shoulder width apart from each other. Slowly use both hands to grab the dumbbell and lift it over your head until both arms are fully extended. The resistance should be resting in the palms of your hands with your thumbs around it. The palm of the hands should be facing up towards the ceiling. This will be your...',
    nameDe: 'Stehend Kurzhantel Trizepsstreckung',
    descriptionDe: 'To begin, stand up with a Kurzhantel held by both hands. Your feet should be about Schulter width apart from each other. Slowly use both hands to grab the Kurzhantel and lift it over your Kopf until both arms are fully extended. The resistance should be resting in the palms of your hands with your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Standing Dumbbell Upright Row',
    description: 'Grasp a dumbbell in each hand with a pronated (palms forward) grip that is slightly less than shoulder width. The dumbbells should be resting on top of your thighs. Your arms should be extended with a slight bend at the elbows and your back should be straight. This will be your starting position. Use your side shoulders to lift the dumbbells as you exhale. The dumbbells should be close to the...',
    nameDe: 'Stehend Kurzhantel Aufrechtes Rudern',
    descriptionDe: 'Grasp a Kurzhantel in each hand with a Proniert (palms forward) grip that is slightly less than Schulter width. The Kurzhanteln should be resting on top of your thighs. Your arms should be extended with a slight bend at the elbows and your Rücken should be straight. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Standing Front Barbell Raise Over Head',
    description: 'To begin, stand straight with a barbell in your hands. You should grip the bar with palms facing down and a closer than shoulder width grip apart from each other. Your feet should be shoulder width apart from each other. Your elbows should be slightly bent. This is the starting position. Lift the barbell up until it is directly over your head while exhaling. Make sure to keep your elbows slightly...',
    nameDe: 'Stehend Front Langhantel Heben Over Kopf',
    descriptionDe: 'To begin, stand straight with a Langhantel in your hands. You should grip the Stange with palms facing down and a closer than Schulter width grip apart from each other. Your feet should be Schulter width apart from each other. Your elbows should be slightly bent. This is the starting position. Lift...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Inner-Biceps Curl',
    description: 'Stand up with a dumbbell in each hand being held at arms length. The elbows should be close to the torso. Your legs should be at about shoulder\'s width apart from each other. Rotate the palms of the hands so that they are facing inward in a neutral position. This will be your starting position. While holding the upper arms stationary, curl the weights out while contracting the biceps as you...',
    nameDe: 'Stehend Innen-Bizepscurl',
    descriptionDe: 'Stand up with a Kurzhantel in each hand being held at arms length. The elbows should be close to the torso. Your legs should be at about Schulter\'s width apart from each other. Rotate the palms of the hands so that they are facing inward in a neutral position. This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing Leg Curl',
    description: 'Adjust the machine lever to fit your height and lie with your torso bent at the waist facing forward around 30-45 degrees (since an angled position is more favorable for hamstrings recruitment) with the pad of the lever on the back of your right leg (just a few inches under the calves) and the front of the right leg on top of the machine pad. Keeping the torso bent forward, ensure your leg is...',
    nameDe: 'Beincurl stehend',
    descriptionDe: 'Adjust the Maschine lever to fit your height and lie with your torso bent at the waist facing forward around 30-45 degrees (since an angled position is more favorable for Oberschenkelrückseite recruitment) with the pad of the lever on the Rücken of your right leg (just a few inches under the Waden)...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Low-Pulley Deltoid Raise',
    description: 'Start by standing to the right side of a low pulley row. Use your left hand to come across the body and grab a single handle attached to the low pulley with a pronated grip (palms facing down). Rest your arm in front of you. Your right hand should grab the machine for better support and balance. Make sure that your back is erect and your feet are shoulder width apart from each other. This is the...',
    nameDe: 'Stehend Low-Pulley Deltamuskel Heben',
    descriptionDe: 'Start by Stehend to the right side of a low pulley Rudern. Use your left hand to come across the body and grab a single handle attached to the low pulley with a Proniert grip (palms facing down). Rest your arm in front of you. Your right hand should grab the Maschine for better support and balance....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Low-Pulley One-Arm Triceps Extension',
    description: 'Grab a single handle with your left arm next to the low pulley machine. Turn away from the machine keeping the handle to the side of your body with your arm fully extended. Now use both hands to elevate the single handle directly above the head with the palm facing forward. Keep your upper arm completely vertical (perpendicular to the floor) and put your right hand on your left elbow to help keep...',
    nameDe: 'Stehend Low-Pulley Einarmig Trizepsstreckung',
    descriptionDe: 'Grab a single handle with your left arm next to the low pulley Maschine. Turn away from the Maschine keeping the handle to the side of your body with your arm fully extended. Now use both hands to elevate the single handle directly above the Kopf with the palm facing forward. Keep your Oberer arm...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Standing Military Press',
    description: 'Start by placing a barbell that is about chest high on a squat rack. Once you have selected the weights, grab the barbell using a pronated (palms facing forward) grip. Make sure to grip the bar wider than shoulder width apart from each other. Slightly bend the knees and place the barbell on your collar bone. Lift the barbell up keeping it lying on your chest. Take a step back and position your...',
    nameDe: 'Stehend Military Drücken',
    descriptionDe: 'Start by placing a Langhantel that is about Brust high on a Kniebeuge Ständer. Once you have selected the weights, grab the Langhantel using a Proniert (palms facing forward) grip. Make sure to grip the Stange wider than Schulter width apart from each other. Slightly bend the knees and place the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Olympic Plate Hand Squeeze',
    description: 'To begin, stand straight while holding a weight plate by the ridge at arm\'s length in each hand using a neutral grip (palms facing in). You feet should be shoulder width apart from each other. This will be your starting position. Lower the plates until the fingers are nearly extended but can still hold weights. Inhale as you lower the plates. Now raise the plates back to the starting position as...',
    nameDe: 'Stehend Olympic Scheibe Hand Squeeze',
    descriptionDe: 'To begin, stand straight while holding a weight Scheibe by the ridge at arm\'s length in each hand using a Neutralgriff (palms facing in). You feet should be Schulter width apart from each other. This will be your starting position. Unterer the plates until the fingers are nearly extended but can...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing One-Arm Cable Curl',
    description: 'Start out by grabbing single handle next to the low pulley machine. Make sure you are far enough from the machine so that your arm is supporting the weight. Make sure that your upper arm is stationary, perpendicular to the floor with elbows in and palms facing forward. Your non lifting arm should be grabbing your waist. This will allow you to keep your balance. Slowly begin to curl the single...',
    nameDe: 'Stehend Einarmig Kabelzug Curl',
    descriptionDe: 'Start out by grabbing single handle next to the low pulley Maschine. Make sure you are far enough from the Maschine so that your arm is supporting the weight. Make sure that your Oberer arm is stationary, perpendicular to the Boden with elbows in and palms facing forward. Your non lifting arm...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing One-Arm Dumbbell Curl Over Incline Bench',
    description: 'Stand on the back side of an incline bench as if you were going to be a spotter for someone. Have a dumbbell in one hand and rest it across the incline bench with a supinated (palms up) grip. Position your non lifting hand at the corner or side of the incline bench. The chest should be pressed against the top part of the incline and your feet should be pressed against the floor at a wide stance....',
    nameDe: 'Stehend Einarmig Kurzhantel Curl Over Schrägbank Bank',
    descriptionDe: 'Stand on the Rücken side of an Schrägbank Bank as if you were going to be a spotter for someone. Have a Kurzhantel in one hand and rest it across the Schrägbank Bank with a Supiniert (palms up) grip. Position your non lifting hand at the corner or side of the Schrägbank Bank. The Brust should be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing One-Arm Dumbbell Triceps Extension',
    description: 'To begin, stand up with a dumbbell held in one hand. Your feet should be about shoulder width apart from each other. Now fully extend the arm with the dumbbell over your head. Tip: The small finger of your hand should be facing the ceiling and the palm of your hand should be facing forward. The dumbbell should be above your head. This will be your starting position. Keeping your upper arm close...',
    nameDe: 'Stehend Einarmig Kurzhantel Trizepsstreckung',
    descriptionDe: 'To begin, stand up with a Kurzhantel held in one hand. Your feet should be about Schulter width apart from each other. Now fully extend the arm with the Kurzhantel over your Kopf. Tip: The small finger of your hand should be facing the ceiling and the palm of your hand should be facing forward. The...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Standing Overhead Barbell Triceps Extension',
    description: 'To begin, stand up holding a barbell or e-z bar using a pronated grip (palms facing forward) with your hands closer than shoulder width apart from each other. Your feet should be about shoulder width apart. Now elevate the barbell above your head until your arms are fully extended. Keep your elbows in. This will be your starting position. Keeping your upper arms close to your head and elbows in,...',
    nameDe: 'Stehend Überkopf Langhantel Trizepsstreckung',
    descriptionDe: 'To begin, stand up holding a Langhantel or e-z Stange using a Proniert grip (palms facing forward) with your hands closer than Schulter width apart from each other. Your feet should be about Schulter width apart. Now elevate the Langhantel above your Kopf until your arms are fully extended. Keep...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Standing Palm-In One-Arm Dumbbell Press',
    description: 'Start by having a dumbbell in one hand with your arm fully extended to the side using a neutral grip. Use your other arm to hold on to an incline bench to keep your balance. Your feet should be shoulder width apart from each other. Now slowly lift the dumbbell up until you create a 90 degree angle with your arm. Note: Your forearm should be perpendicular to the floor. Continue to maintain a...',
    nameDe: 'Stehend Palm-In Einarmig Kurzhantel Drücken',
    descriptionDe: 'Start by having a Kurzhantel in one hand with your arm fully extended to the side using a Neutralgriff. Use your other arm to hold on to an Schrägbank Bank to keep your balance. Your feet should be Schulter width apart from each other. Now slowly lift the Kurzhantel up until you create a 90 degree...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Palms-In Dumbbell Press',
    description: 'Start by having a dumbbell in each hand with your arm fully extended to the side using a neutral grip. Your feet should be shoulder width apart from each other. Now slowly lift the dumbbells up until you create a 90 degree angle with your arms. Note: Your forearms should be perpendicular to the floor. This the starting position. Continue to maintain a neutral grip throughout the entire exercise....',
    nameDe: 'Stehend Palms-In Kurzhantel Drücken',
    descriptionDe: 'Start by having a Kurzhantel in each hand with your arm fully extended to the side using a Neutralgriff. Your feet should be Schulter width apart from each other. Now slowly lift the Kurzhanteln up until you create a 90 degree angle with your arms. Note: Your Unterarme should be perpendicular to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Standing Palms-Up Barbell Behind The Back Wrist Curl',
    description: 'Start by standing straight and holding a barbell behind your glutes at arm\'s length while using a pronated grip (palms will be facing back away from the glutes) and having your hands shoulder width apart from each other. You should be looking straight forward while your feet are shoulder width apart from each other. This is the starting position. While exhaling, slowly elevate the barbell up by...',
    nameDe: 'Stehend Palms-Up Langhantel Behind The Rücken Handgelenk-Curl',
    descriptionDe: 'Start by Stehend straight and holding a Langhantel behind your Gesäß at arm\'s length while using a Proniert grip (palms will be facing Rücken away from the Gesäß) and having your hands Schulter width apart from each other. You should be looking straight forward while your feet are Schulter width...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing Rope Crunch',
    description: 'Attach a rope to a high pulley and select an appropriate weight. Stand with your back to the cable tower. Take the rope with both hands over your shoulders, holding it to your upper chest. This will be your starting position. Perform the movement by flexing the spine, crunching the weight down as far as you can. Hold the peak contraction for a moment before returning to the starting position.',
    nameDe: 'Stehend Seil Crunch',
    descriptionDe: 'Attach a Seil to a high pulley and select an appropriate weight. Stand with your Rücken to the Kabelzug tower. Take the Seil with both hands over your Schultern, holding it to your Oberer Brust. This will be your starting position. Perform the movement by flexing the Wirbelsäule, crunching the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Standing Towel Triceps Extension',
    description: 'To begin, stand up with both arms fully extended above the head holding one end of a towel with both hands. Your elbows should be in and the arms perpendicular to the floor with the palms facing each other while your feet should be shoulder width apart from each other. This is the starting position. Now communicate with your partner so that he/she can grip the other side of the towel to apply...',
    nameDe: 'Stehend Towel Trizepsstreckung',
    descriptionDe: 'To begin, stand up with both arms fully extended above the Kopf holding one end of a towel with both hands. Your elbows should be in and the arms perpendicular to the Boden with the palms facing each other while your feet should be Schulter width apart from each other. This is the starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Step-up with Knee Raise',
    description: 'Stand facing a box or bench of an appropriate height with your feet together. This will be your starting position. Begin the movement by stepping up, putting your left foot on the top of the bench. Extend through the hip and knee of your front leg to stand up on the box. As you stand on the box with your left leg, flex your right knee and hip, bringing your knee as high as you can. Reverse this...',
    nameDe: 'Stufe-up with Knie Heben',
    descriptionDe: 'Stand facing a Box or Bank of an appropriate height with your feet together. This will be your starting position. Begin the movement by stepping up, putting your left foot on the top of the Bank. Extend through the Hüfte and Knie of your front leg to stand up on the Box. As you stand on the Box...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Stiff-Legged Barbell Deadlift',
    description: 'Grasp a bar using an overhand grip (palms facing down). You may need some wrist wraps if using a significant amount of weight. Stand with your torso straight and your legs spaced using a shoulder width or narrower stance. The knees should be slightly bent. This is your starting position. Keeping the knees stationary, lower the barbell to over the top of your feet by bending at the hips while...',
    nameDe: 'Stiff-Legged Langhantel Kreuzheben',
    descriptionDe: 'Grasp a Stange using an Obergriff grip (palms facing down). You may need some Handgelenk wraps if using a significant amount of weight. Stand with your torso straight and your legs spaced using a Schulter width or narrower stance. The knees should be slightly bent. This is your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Stiff-Legged Dumbbell Deadlift',
    description: 'Grasp a couple of dumbbells holding them by your side at arm\'s length. Stand with your torso straight and your legs spaced using a shoulder width or narrower stance. The knees should be slightly bent. This is your starting position. Keeping the knees stationary, lower the dumbbells to over the top of your feet by bending at the waist while keeping your back straight. Keep moving forward as if you...',
    nameDe: 'Kurzhantel-Kreuzheben mit gestreckten Beinen',
    descriptionDe: 'Grasp a couple of Kurzhanteln holding them by your side at arm\'s length. Stand with your torso straight and your legs spaced using a Schulter width or narrower stance. The knees should be slightly bent. This is your starting position. Keeping the knees stationary, Unterer the Kurzhanteln to over...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Stiff Leg Barbell Good Morning',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs...',
    nameDe: 'Stiff Leg Langhantel Good Morning',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Straight-Arm Dumbbell Pullover',
    description: 'Place a dumbbell standing up on a flat bench. Ensuring that the dumbbell stays securely placed at the top of the bench, lie perpendicular to the bench (torso across it as in forming a cross) with only your shoulders lying on the surface. Hips should be below the bench and legs bent with feet firmly on the floor. The head will be off the bench as well. Grasp the dumbbell with both hands and hold...',
    nameDe: 'Straight-Arm Kurzhantel Pullover',
    descriptionDe: 'Place a Kurzhantel Stehend up on a Flachbank Bank. Ensuring that the Kurzhantel stays securely placed at the top of the Bank, lie perpendicular to the Bank (torso across it as in forming a Überkreuz) with only your Schultern Liegend on the surface. Hüften should be below the Bank and legs bent with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Straight-Arm Pulldown',
    description: 'You will start by grabbing the wide bar from the top pulley of a pulldown machine and using a wider than shoulder-width pronated (palms down) grip. Step backwards two feet or so. Bend your torso forward at the waist by around 30-degrees with your arms fully extended in front of you and a slight bend at the elbows. If your arms are not fully extended then you need to step a bit more backwards...',
    nameDe: 'Straight-Arm Latzug',
    descriptionDe: 'You will start by grabbing the wide Stange from the top pulley of a Latzug Maschine and using a wider than Schulter-width Proniert (palms down) grip. Stufe backwards two feet or so. Bend your torso forward at the waist by around 30-degrees with your arms fully extended in front of you and a slight...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Straight Bar Bench Mid Rows',
    description: 'Place a loaded barbell on the end of a bench. Standing on the bench behind the bar, take a medium, pronated grip. Stand with your hips back and chest up, maintaining a neutral spine. This will be your starting position. Row the bar to your torso by retracting the shoulder blades and flexing the elbows. Use a controlled movement with no jerking. After a brief pause, slowly return the bar to the...',
    nameDe: 'Straight Stange Bank Mid Rows',
    descriptionDe: 'Place a loaded Langhantel on the end of a Bank. Stehend on the Bank behind the Stange, take a medium, Proniert grip. Stand with your Hüften Rücken and Brust up, maintaining a neutral Wirbelsäule. This will be your starting position. Rudern the Stange to your torso by retracting the Schulter blades...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Straight Raises on Incline Bench',
    description: 'Place a bar on the ground behind the head of an incline bench. Lay on the bench face down. With a pronated grip, pick the barbell up from the floor, keeping your arms straight. Allow the bar to hang straight down. This will be your starting position. To begin, raise the barbell out in front of your head while keeping your arms extended. Return to the starting position.',
    nameDe: 'Straight Raises on Schrägbank Bank',
    descriptionDe: 'Place a Stange on the ground behind the Kopf of an Schrägbank Bank. Lay on the Bank face down. With a Proniert grip, pick the Langhantel up from the Boden, keeping your arms straight. Allow the Stange to hang straight down. This will be your starting position. To begin, Heben the Langhantel out in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Suspended Fallout',
    description: 'Adjust the straps so the handles are at an appropriate height, below waist level. Begin standing and grasping the handles. Lean into the straps, moving to an incline push-up position. This will be your starting position. Keeping your arms straight, lean further into the suspension straps, bringing your body closer to the ground, allowing your shoulders to extend, raising your arms up and over...',
    nameDe: 'Suspended Fallout',
    descriptionDe: 'Adjust the straps so the handles are at an appropriate height, below waist level. Begin Stehend and grasping the handles. Lean into the straps, moving to an Schrägbank Liegestütz position. This will be your starting position. Keeping your arms straight, lean further into the Schlingentrainer...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Suspended Push-Up',
    description: 'Anchor your suspension straps securely to the top of a rack or other object. Leaning into the straps, take a handle in each hand and move into a push-up plank position. You should be as close to parallel to the ground as you can manage with your arms fully extended, maintaining good posture. Maintaining a straight, rigid torso, descend slowly by allowing the elbows to flex. Continue until your...',
    nameDe: 'Suspended Liegestütz',
    descriptionDe: 'Anchor your Schlingentrainer straps securely to the top of a Ständer or other object. Leaning into the straps, take a handle in each hand and move into a Liegestütz Planke position. You should be as close to parallel to the ground as you can manage with your arms fully extended, maintaining good...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Suspended Reverse Crunch',
    description: 'Secure a set of suspension straps with the handles hanging about a foot off of the ground. Move yourself into a pushup plank position facing away from the rack. Place your feet into the handles. You should maintain a straight posture, not allowing the hips to sag. This will be your starting position. Begin the movement by flexing the knees and hips, drawing the knees to your torso. As you do so,...',
    nameDe: 'Suspended Umgekehrt Crunch',
    descriptionDe: 'Secure a set of Schlingentrainer straps with the handles hanging about a foot off of the ground. Move yourself into a Liegestütz Planke position facing away from the Ständer. Place your feet into the handles. You should maintain a straight posture, not allowing the Hüften to sag. This will be your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Suspended Row',
    description: 'Suspend your straps at around chest height. Take a handle in each hand and lean back. Keep your body erect and your head and chest up. Your arms should be fully extended. This will be your starting position. Begin by flexing the elbow to initiate the movement. Protract your shoulder blades as you do so. At the completion of the motion pause, and then return to the starting position.',
    nameDe: 'Suspended Rudern',
    descriptionDe: 'Suspend your straps at around Brust height. Take a handle in each hand and lean Rücken. Keep your body erect and your Kopf and Brust up. Your arms should be fully extended. This will be your starting position. Begin by flexing the elbow to initiate the movement. Protract your Schulter blades as you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Suspended Split Squat',
    description: 'Suspend your straps so the handles are 18-30 inches from the floor. Facing away from the setup, place your rear foot into the handle behind you. Keep your head looking forward and your chest up, with your knee slightly bent. This will be your starting position. Descend by flexing the knee and hips, lowering yourself to the ground. Keep your weight on the heel of your foot and maintain your...',
    nameDe: 'Suspended Split Kniebeuge',
    descriptionDe: 'Suspend your straps so the handles are 18-30 inches from the Boden. Facing away from the setup, place your rear foot into the handle behind you. Keep your Kopf looking forward and your Brust up, with your Knie slightly bent. This will be your starting position. Descend by flexing the Knie and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Svend Press',
    description: 'Begin in a standing position. Press two lightweight plates together with your hands. Hold the plates together close to your chest to create an isometric contraction in your chest muscles. Your fingers should be pointed forward. This is your starting position. Squeeze the plates between your palms and extend your arms directly out in front of you in a controlled motion. Pause at the top of the...',
    nameDe: 'Svend Drücken',
    descriptionDe: 'Begin in a Stehend position. Drücken two lightweight plates together with your hands. Hold the plates together close to your Brust to create an Isometrisch contraction in your Brust muscles. Your fingers should be pointed forward. This is your starting position. Squeeze the plates between your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'T-Bar Row with Handle',
    description: 'Position a bar into a landmine or in a corner to keep it from moving. Load an appropriate weight onto your end. Stand over the bar, and position a Double D row handle around the bar next to the collar. Using your hips and legs, rise to a standing position. Assume a wide stance with your hips back and your chest up. Your arms should be extended. This will be your starting position. Pull the weight...',
    nameDe: 'T-Stangenrudern with Handle',
    descriptionDe: 'Position a Stange into a landmine or in a corner to keep it from moving. Load an appropriate weight onto your end. Stand over the Stange, and position a Doppelt D Rudern handle around the Stange next to the collar. Using your Hüften and legs, rise to a Stehend position. Assume a wide stance with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Tate Press',
    description: 'Lie down on a flat bench with a dumbbell in each hand on top of your thighs. The palms of your hand will be facing each other. By using your thighs to help you get the dumbbells up, clean the dumbbells one arm at a time so that you can hold them in front of you at shoulder width. Note: when holding the dumbbells in front of you, make sure your arms are wider than shoulder width apart from each...',
    nameDe: 'Tate-Press',
    descriptionDe: 'Lie down on a Flachbank Bank with a Kurzhantel in each hand on top of your thighs. The palms of your hand will be facing each other. By using your thighs to help you get the Kurzhanteln up, Stoßen the Kurzhanteln Einarmig at a time so that you can hold them in front of you at Schulter width. Note:...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Thigh Abductor',
    description: 'To begin, sit down on the abductor machine and select a weight you are comfortable with. When your legs are positioned properly, grip the handles on each side. Your entire upper body (from the waist up) should be stationary. This is the starting position. Slowly press against the machine with your legs to move them away from each other while exhaling. Feel the contraction for a second and begin...',
    nameDe: 'Oberschenkel Abduktoren',
    descriptionDe: 'To begin, sit down on the Abduktoren Maschine and select a weight you are comfortable with. When your legs are positioned properly, grip the handles on each side. Your entire Oberer body (from the waist up) should be stationary. This is the starting position. Slowly Drücken against the Maschine...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Thigh Adductor',
    description: 'To begin, sit down on the adductor machine and select a weight you are comfortable with. When your legs are positioned properly on the leg pads of the machine, grip the handles on each side. Your entire upper body (from the waist up) should be stationary. This is the starting position. Slowly press against the machine with your legs to move them towards each other while exhaling. Feel the...',
    nameDe: 'Oberschenkel Adduktoren',
    descriptionDe: 'To begin, sit down on the Adduktoren Maschine and select a weight you are comfortable with. When your legs are positioned properly on the leg pads of the Maschine, grip the handles on each side. Your entire Oberer body (from the waist up) should be stationary. This is the starting position. Slowly...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Trap Bar Deadlift',
    description: 'For this exercise load a trap bar, also known as a hex bar, to an appropriate weight resting on the ground. Stand in the center of the apparatus and grasp both handles. Lower your hips, look forward with your head and keep your chest up. Begin the movement by driving through the heels and extend your hips and knees. Avoid rounding your back at all times. At the completion of the movement, lower...',
    nameDe: 'Trap-Stangen-Kreuzheben',
    descriptionDe: 'For this exercise load a Trap-Stange, also known as a hex Stange, to an appropriate weight resting on the ground. Stand in the center of the apparatus and grasp both handles. Unterer your Hüften, look forward with your Kopf and keep your Brust up. Begin the movement by driving through the heels and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Tricep Dumbbell Kickback',
    description: 'Start with a dumbbell in each hand and your palms facing your torso. Keep your back straight with a slight bend in the knees and bend forward at the waist. Your torso should be almost parallel to the floor. Make sure to keep your head up. Your upper arms should be close to your torso and parallel to the floor. Your forearms should be pointed towards the floor as you hold the weights. There should...',
    nameDe: 'Trizeps Kurzhantel Kickback',
    descriptionDe: 'Start with a Kurzhantel in each hand and your palms facing your torso. Keep your Rücken straight with a slight bend in the knees and bend forward at the waist. Your torso should be almost parallel to the Boden. Make sure to keep your Kopf up. Your Oberer arms should be close to your torso and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Triceps Overhead Extension with Rope',
    description: 'Attach a rope to a low pulley. After selecting an appropriate weight, grasp the rope with both hands and face away from the cable. Position your hands behind your head with your elbows point straight up. Your elbows should start out flexed, and you can stagger your stance and lean gently away from the machine to create greater stability. This will be your starting position. To perform the...',
    nameDe: 'Trizeps Überkopf-Streckung with Seil',
    descriptionDe: 'Attach a Seil to a low pulley. After selecting an appropriate weight, grasp the Seil with both hands and face away from the Kabelzug. Position your hands behind your Kopf with your elbows point straight up. Your elbows should start out flexed, and you can stagger your stance and lean gently away...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Triceps Pushdown',
    description: 'Attach a straight or angled bar to a high pulley and grab with an overhand grip (palms facing down) at shoulder width. Standing upright with the torso straight and a very small inclination forward, bring the upper arms close to your body and perpendicular to the floor. The forearms should be pointing up towards the pulley as they hold the bar. This is your starting position. Using the triceps,...',
    nameDe: 'Trizeps Pushdown',
    descriptionDe: 'Attach a straight or angled Stange to a high pulley and grab with an Obergriff grip (palms facing down) at Schulter width. Stehend Aufrecht with the torso straight and a very small inclination forward, bring the Oberer arms close to your body and perpendicular to the Boden. The Unterarme should be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Triceps Pushdown - Rope Attachment',
    description: 'Attach a rope attachment to a high pulley and grab with a neutral grip (palms facing each other). Standing upright with the torso straight and a very small inclination forward, bring the upper arms close to your body and perpendicular to the floor. The forearms should be pointing up towards the pulley as they hold the rope with the palms facing each other. This is your starting position. Using...',
    nameDe: 'Trizeps Pushdown - Seil Attachment',
    descriptionDe: 'Attach a Seil attachment to a high pulley and grab with a Neutralgriff (palms facing each other). Stehend Aufrecht with the torso straight and a very small inclination forward, bring the Oberer arms close to your body and perpendicular to the Boden. The Unterarme should be pointing up towards the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Triceps Pushdown - V-Bar Attachment',
    description: 'Attach a V-Bar to a high pulley and grab with an overhand grip (palms facing down) at shoulder width. Standing upright with the torso straight and a very small inclination forward, bring the upper arms close to your body and perpendicular to the floor. The forearms should be pointing up towards the pulley as they hold the bar. The thumbs should be higher than the small finger. This is your...',
    nameDe: 'Trizeps Pushdown - V-Stange Attachment',
    descriptionDe: 'Attach a V-Stange to a high pulley and grab with an Obergriff grip (palms facing down) at Schulter width. Stehend Aufrecht with the torso straight and a very small inclination forward, bring the Oberer arms close to your body and perpendicular to the Boden. The Unterarme should be pointing up...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Tuck Crunch',
    description: 'To begin, lie down on the floor or an exercise mat with your back pressed against the floor. Your arms should be lying across your sides with the palms facing down. Your legs should be crossed by wrapping one ankle around the other. Slowly elevate your legs up in the air until your thighs are perpendicular to the floor with a slight bend at the knees. Note: Your knees and toes should be parallel...',
    nameDe: 'Tuck Crunch',
    descriptionDe: 'To begin, lie down on the Boden or an exercise mat with your Rücken pressed against the Boden. Your arms should be Liegend across your sides with the palms facing down. Your legs should be crossed by wrapping one Knöchel around the other. Slowly elevate your legs up in the Luft until your thighs...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Two-Arm Dumbbell Preacher Curl',
    description: 'Grab a dumbbell with each arm and place the upper arms on top of the preacher bench or the incline bench. The dumbbell should be held at shoulder length. This will be your starting position. As you breathe in, slowly lower the dumbbells until your upper arm is extended and the biceps is fully stretched. As you exhale, use the biceps to curl the weights up until your biceps is fully contracted and...',
    nameDe: 'Beidarmiger Kurzhantel-Preacher-Curl',
    descriptionDe: 'Grab a Kurzhantel with each arm and place the Oberer arms on top of the preacher Bank or the Schrägbank Bank. The Kurzhantel should be held at Schulter length. This will be your starting position. As you breathe in, slowly Unterer the Kurzhanteln until your Oberer arm is extended and the Bizeps is...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Two-Arm Kettlebell Clean',
    description: 'Place two kettlebells between your feet. To get in the starting position, push your butt back and look straight ahead. Clean the kettlebells to your shoulders by extending through the legs and hips as you raise the kettlebells towards your shoulders. Rotate your wrists as you do so. Lower the kettlebells back to the starting position and repeat.',
    nameDe: 'Beidarmig Kettlebell Stoßen',
    descriptionDe: 'Place two Kettlebells between your feet. To get in the starting position, push your butt Rücken and look straight ahead. Stoßen the Kettlebells to your Schultern by extending through the legs and Hüften as you Heben the Kettlebells towards your Schultern. Rotate your wrists as you do so. Unterer...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Two-Arm Kettlebell Jerk',
    description: 'Clean two kettlebells to your shoulders. Clean the kettlebells to your shoulders by extending through the legs and hips as you swing the kettlebells towards your shoulders. Rotate your wrists as you do so, so that the palms face forward. Squat down a few inches and reverse the motion rapidly driving both kettlebells overhead. Immediately after the initial push, squat down again and get under the...',
    nameDe: 'Beidarmig Kettlebell Ausstoßen',
    descriptionDe: 'Stoßen two Kettlebells to your Schultern. Stoßen the Kettlebells to your Schultern by extending through the legs and Hüften as you Schwingen the Kettlebells towards your Schultern. Rotate your wrists as you do so, so that the palms face forward. Kniebeuge down a few inches and Umgekehrt the motion...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Two-Arm Kettlebell Military Press',
    description: 'Clean two kettlebells to your shoulders. Clean the kettlebells to your shoulders by extending through the legs and hips as you swing the kettlebells towards your shoulders. Rotate your wrists as you do so, so that the palms face forward. Press the kettlebells up and out. As the kettlebells pass your head, lean into the weights so that the kettlebells are racked behind your head. Make sure to...',
    nameDe: 'Beidarmig Kettlebell Military Drücken',
    descriptionDe: 'Stoßen two Kettlebells to your Schultern. Stoßen the Kettlebells to your Schultern by extending through the legs and Hüften as you Schwingen the Kettlebells towards your Schultern. Rotate your wrists as you do so, so that the palms face forward. Drücken the Kettlebells up and out. As the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Two-Arm Kettlebell Row',
    description: 'Place two kettlebells in front of your feet. Bend your knees slightly and then push your butt out as much as possible as you bend over to get in the starting position. Grab both kettlebells and pull them to your stomach, retracting your shoulder blades and flexing the elbows. Keep your back straight. Lower and repeat.',
    nameDe: 'Beidarmig Kettlebell Rudern',
    descriptionDe: 'Place two Kettlebells in front of your feet. Bend your knees slightly and then push your butt out as much as possible as you bend over to get in the starting position. Grab both Kettlebells and pull them to your stomach, retracting your Schulter blades and flexing the elbows. Keep your Rücken...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Underhand Cable Pulldowns',
    description: 'Sit down on a pull-down machine with a wide bar attached to the top pulley. Adjust the knee pad of the machine to fit your height. These pads will prevent your body from being raised by the resistance attached to the bar. Grab the pull-down bar with the palms facing your torso (a supinated grip). Make sure that the hands are placed closer than the shoulder width. As you have both arms extended in...',
    nameDe: 'Untergriff Kabelzug Pulldowns',
    descriptionDe: 'Sit down on a Latzug Maschine with a wide Stange attached to the top pulley. Adjust the Knie pad of the Maschine to fit your height. These pads will prevent your body from being raised by the resistance attached to the Stange. Grab the Latzug Stange with the palms facing your torso (a Supiniert...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Upright Barbell Row',
    description: 'Grasp a barbell with an overhand grip that is slightly less than shoulder width. The bar should be resting on the top of your thighs with your arms extended and a slight bend in your elbows. Your back should also be straight. This will be your starting position. Now exhale and use the sides of your shoulders to lift the bar, raising your elbows up and to the side. Keep the bar close to your body...',
    nameDe: 'Aufrecht Langhantel Rudern',
    descriptionDe: 'Grasp a Langhantel with an Obergriff grip that is slightly less than Schulter width. The Stange should be resting on the top of your thighs with your arms extended and a slight bend in your elbows. Your Rücken should also be straight. This will be your starting position. Now exhale and use the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Upright Cable Row',
    description: 'Grasp a straight bar cable attachment that is attached to a low pulley with a pronated (palms facing your thighs) grip that is slightly less than shoulder width. The bar should be resting on top of your thighs. Your arms should be extended with a slight bend at the elbows and your back should be straight. This will be your starting position. Use your side shoulders to lift the cable bar as you...',
    nameDe: 'Aufrecht Kabelzug Rudern',
    descriptionDe: 'Grasp a straight Stange Kabelzug attachment that is attached to a low pulley with a Proniert (palms facing your thighs) grip that is slightly less than Schulter width. The Stange should be resting on top of your thighs. Your arms should be extended with a slight bend at the elbows and your Rücken...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Upright Row - With Bands',
    description: 'To begin, stand on an exercise band so that tension begins at arm\'s length. Grasp the handles using a pronated (palms facing your thighs) grip that is slightly less than shoulder width. The handles should be resting on top of your thighs. Your arms should be extended with a slight bend at the elbows and your back should be straight. This will be your starting position. Use your side shoulders to...',
    nameDe: 'Aufrechtes Rudern - mit Band',
    descriptionDe: 'To begin, stand on an exercise Band so that tension begins at arm\'s length. Grasp the handles using a Proniert (palms facing your thighs) grip that is slightly less than Schulter width. The handles should be resting on top of your thighs. Your arms should be extended with a slight bend at the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'V-Bar Pulldown',
    description: 'Sit down on a pull-down machine with a V-Bar attached to the top pulley. Adjust the knee pad of the machine to fit your height. These pads will prevent your body from being raised by the resistance attached to the bar. Grab the V-bar with the palms facing each other (a neutral grip). Stick your chest out and lean yourself back slightly (around 30-degrees) in order to better engage the lats. This...',
    nameDe: 'V-Stangen-Latzug',
    descriptionDe: 'Sit down on a Latzug Maschine with a V-Stange attached to the top pulley. Adjust the Knie pad of the Maschine to fit your height. These pads will prevent your body from being raised by the resistance attached to the Stange. Grab the V-Stange with the palms facing each other (a Neutralgriff). Stick...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'V-Bar Pullup',
    description: 'Start by placing the middle of the V-bar in the middle of the pull-up bar (assuming that the pull-up station you are using does not have neutral grip handles). The V-Bar handles will be facing down so that you can hang from the pull-up bar through the use of the handles. Once you securely place the V-bar, take a hold of the bar from each side and hang from it. Stick your chest out and lean...',
    nameDe: 'V-Stange Klimmzug',
    descriptionDe: 'Start by placing the middle of the V-Stange in the middle of the Klimmzugstange (assuming that the Klimmzug station you are using does not have Neutralgriff handles). The V-Stange handles will be facing down so that you can hang from the Klimmzugstange through the use of the handles. Once you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Weighted Ball Hyperextension',
    description: 'To begin, lie down on an exercise ball with your torso pressing against the ball and parallel to the floor. The ball of your feet should be pressed against the floor to help keep you balanced. Place a weighted plate under your chin or behind your neck. This is the starting position. Slowly raise your torso up by bending at the waist and lower back. Remember to exhale during this movement. Hold...',
    nameDe: 'Gewichteter Ball-Rückenstreckung',
    descriptionDe: 'To begin, lie down on an Trainingsball with your torso pressing against the Ball and parallel to the Boden. The Ball of your feet should be pressed against the Boden to help keep you balanced. Place a Gewichtet Scheibe under your chin or behind your Nacken. This is the starting position. Slowly...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Weighted Ball Side Bend',
    description: 'To begin, lie down on an exercise ball with your left side of the torso (waist, hips and shoulder) pressed against the ball. Your feet should be on the floor while your legs are crossed and hanging from the ball. Hold a weighted plate with your right hand directly to the right side of your head. Tip: Make sure the smooth side of the plate is resting against your head. Place your left arm across...',
    nameDe: 'Gewichtet Ball Side Bend',
    descriptionDe: 'To begin, lie down on an Trainingsball with your left side of the torso (waist, Hüften and Schulter) pressed against the Ball. Your feet should be on the Boden while your legs are crossed and hanging from the Ball. Hold a Gewichtet Scheibe with your right hand directly to the right side of your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Weighted Bench Dip',
    description: 'For this exercise you will need to place a bench behind your back and another one in front of you. With the benches perpendicular to your body, hold on to one bench on its edge with the hands close to your body, separated at shoulder width. Your arms should be fully extended. The legs will be extended forward on top of the other bench. Your legs should be parallel to the floor while your torso is...',
    nameDe: 'Gewichtet Bank Dip',
    descriptionDe: 'For this exercise you will need to place a Bank behind your Rücken and another one in front of you. With the benches perpendicular to your body, hold on to one Bank on its edge with the hands close to your body, separated at Schulter width. Your arms should be fully extended. The legs will be...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Weighted Crunches',
    description: 'Lie flat on your back with your feet flat on the ground or resting on a bench with your knees bent at a 90 degree angle. Hold a weight to your chest, or you may hold it extended above your torso. This will be your starting position. Now, exhale and slowly begin to roll your shoulders off the floor. Your shoulders should come up off the floor about 4 inches while your lower back remains on the...',
    nameDe: 'Gewichtet Crunches',
    descriptionDe: 'Lie Flachbank on your Rücken with your feet Flachbank on the ground or resting on a Bank with your knees bent at a 90 degree angle. Hold a weight to your Brust, or you may hold it extended above your torso. This will be your starting position. Now, exhale and slowly begin to roll your Schultern off...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Weighted Jump Squat',
    description: 'Position a lightly loaded barbell across the back of your shoulders. You could also use a weighted vest, sandbag, or other type of resistance for this exercise. The weight should be light enough that it doesn\'t slow you down significantly. Your feet should be just outside of shoulder width with your head and chest up. This will be your starting position. Using a countermovement, squat partially...',
    nameDe: 'Gewichtet Sprung Kniebeuge',
    descriptionDe: 'Position a lightly loaded Langhantel across the Rücken of your Schultern. You could also use a Gewichtet vest, Sandsack, or other type of resistance for this exercise. The weight should be light enough that it doesn\'t Langsam you down significantly. Your feet should be just outside of Schulter...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Weighted Pull Ups',
    description: 'Attach a weight to a dip belt and secure it around your waist. Grab the pull-up bar with the palms of your hands facing forward. For a medium grip, your hands should be spaced at shoulder width. Both arms should be extended in front of you holding the bar at the chosen grip. You\'ll want to bring your torso back about 30 degrees while creating a curvature in your lower back and sticking your chest...',
    nameDe: 'Gewichtet Pull Ups',
    descriptionDe: 'Attach a weight to a Dip belt and secure it around your waist. Grab the Klimmzugstange with the palms of your hands facing forward. For a medium grip, your hands should be spaced at Schulter width. Both arms should be extended in front of you holding the Stange at the chosen grip. You\'ll want to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Weighted Sissy Squat',
    description: 'Standing upright, with feet at shoulder width and toes raised, use one hand to hold onto the beams of a squat rack and the opposite arm to hold a plate on top of your chest. This is your starting position. As you use one arm to hold yourself, bend at the knees and slowly lower your torso toward the ground by bringing your pelvis and knees forward. Inhale as you go down and stop when your upper...',
    nameDe: 'Gewichtet Sissy Kniebeuge',
    descriptionDe: 'Stehend Aufrecht, with feet at Schulter width and toes raised, use one hand to hold onto the beams of a Kniebeuge Ständer and the opposite arm to hold a Scheibe on top of your Brust. This is your starting position. As you use Einarmig to hold yourself, bend at the knees and slowly Unterer your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Weighted Sit-Ups - With Bands',
    description: 'Start out by strapping the bands around the base of the decline bench. Place the handles towards the inside of the decline bench so that when lying down, you can reach for both of them. Position your legs through the decline machine until they are secured. Now reach for the exercise bands with both hands. Use a pronated (palms forward) grip to grasp the handles. Position them near your collar...',
    nameDe: 'Gewichtet Sit-Ups - mit Band',
    descriptionDe: 'Start out by strapping the bands around the base of the Negativbank Bank. Place the handles towards the inside of the Negativbank Bank so that when Liegend down, you can reach for both of them. Position your legs through the Negativbank Maschine until they are secured. Now reach for the exercise...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Weighted Squat',
    description: 'Start by positioning two flat benches shoulder width apart from each other. Stand on top of them and wrap the weighted belt around your waist with the amount of weight you feel comfortable with. Make sure your toes are facing out. Once you are standing straight up with the weight hanging in between your legs, position your arms so that they are fully extended to the side of your body. This is the...',
    nameDe: 'Gewichtet Kniebeuge',
    descriptionDe: 'Start by positioning two Flachbank benches Schulter width apart from each other. Stand on top of them and wrap the Gewichtet belt around your waist with the amount of weight you feel comfortable with. Make sure your toes are facing out. Once you are Stehend straight up with the weight hanging in...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Wide-Grip Barbell Bench Press',
    description: 'Lie back on a flat bench with feet firm on the floor. Using a wide, pronated (palms forward) grip that is around 3 inches away from shoulder width (for each hand), lift the bar from the rack and hold it straight over you with your arms locked. The bar will be perpendicular to the torso and the floor. This will be your starting position. As you breathe in, come down slowly until you feel the bar...',
    nameDe: 'Langhantel-Bankdrücken weiter Griff',
    descriptionDe: 'Lie Rücken on a Flachbank Bank with feet firm on the Boden. Using a wide, Proniert (palms forward) grip that is around 3 inches away from Schulter width (for each hand), lift the Stange from the Ständer and hold it straight over you with your arms locked. The Stange will be perpendicular to the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Wide-Grip Decline Barbell Bench Press',
    description: 'Lie back on a decline bench with the feet securely locked at the front of the bench. Using a wide, pronated (palms forward) grip that is around 3 inches away from shoulder width (for each hand), lift the bar from the rack and hold it straight over you with your arms locked. The bar will be perpendicular to the torso and the floor. This will be your starting position. As you breathe in, come down...',
    nameDe: 'Weiter Griff Negativbank Langhantel Bank Drücken',
    descriptionDe: 'Lie Rücken on a Negativbank Bank with the feet securely locked at the front of the Bank. Using a wide, Proniert (palms forward) grip that is around 3 inches away from Schulter width (for each hand), lift the Stange from the Ständer and hold it straight over you with your arms locked. The Stange...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Wide-Grip Decline Barbell Pullover',
    description: 'Lie down on a decline bench with both legs securely locked in position. Reach for the barbell behind the head using a pronated grip (palms facing out). Make sure to grab the barbell wider than shoulder width apart for this exercise. Slowly lift the barbell up from the floor by using your arms. When positioned properly, your arms should be fully extended and perpendicular to the floor. This is the...',
    nameDe: 'Weiter Griff Negativbank Langhantel Pullover',
    descriptionDe: 'Lie down on a Negativbank Bank with both legs securely locked in position. Reach for the Langhantel behind the Kopf using a Proniert grip (palms facing out). Make sure to grab the Langhantel wider than Schulter width apart for this exercise. Slowly lift the Langhantel up from the Boden by using...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Wide-Grip Lat Pulldown',
    description: 'Sit down on a pull-down machine with a wide bar attached to the top pulley. Make sure that you adjust the knee pad of the machine to fit your height. These pads will prevent your body from being raised by the resistance attached to the bar. Grab the bar with the palms facing forward using the prescribed grip. Note on grips: For a wide grip, your hands need to be spaced out at a distance wider...',
    nameDe: 'Weiter Griff Lat Latzug',
    descriptionDe: 'Sit down on a Latzug Maschine with a wide Stange attached to the top pulley. Make sure that you adjust the Knie pad of the Maschine to fit your height. These pads will prevent your body from being raised by the resistance attached to the Stange. Grab the Stange with the palms facing forward using...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Wide-Grip Pulldown Behind The Neck',
    description: 'Sit down on a pull-down machine with a wide bar attached to the top pulley. Make sure that you adjust the knee pad of the machine to fit your height. These pads will prevent your body from being raised by the resistance attached to the bar. Grab the bar with the palms facing forward using the prescribed grip. Note on grips: For a wide grip, your hands need to be spaced out at a distance wider...',
    nameDe: 'Weiter Griff Latzug Behind The Nacken',
    descriptionDe: 'Sit down on a Latzug Maschine with a wide Stange attached to the top pulley. Make sure that you adjust the Knie pad of the Maschine to fit your height. These pads will prevent your body from being raised by the resistance attached to the Stange. Grab the Stange with the palms facing forward using...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Wide-Grip Rear Pull-Up',
    description: 'Grab the pull-up bar with the palms facing forward using a wide grip. As you have both arms extended in front of you holding the bar, bring your torso forward and head so that there is an imaginary line from the pull-up bar to the back of your neck. This is your starting position. Pull your torso up until the bar is near the back of your neck. To do this, draw the shoulders and upper arms down...',
    nameDe: 'Klimmzug weiter Griff hinten',
    descriptionDe: 'Grab the Klimmzugstange with the palms facing forward using a Weiter Griff. As you have both arms extended in front of you holding the Stange, bring your torso forward and Kopf so that there is an imaginary line from the Klimmzugstange to the Rücken of your Nacken. This is your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Wide-Grip Standing Barbell Curl',
    description: 'Stand up with your torso upright while holding a barbell at the wide outer handle. The palm of your hands should be facing forward. The elbows should be close to the torso. This will be your starting position. While holding the upper arms stationary, curl the weights forward while contracting the biceps as you breathe out. Tip: Only the forearms should move. Continue the movement until your...',
    nameDe: 'Weiter Griff Stehend Langhantel Curl',
    descriptionDe: 'Stand up with your torso Aufrecht while holding a Langhantel at the wide Außen handle. The palm of your hands should be facing forward. The elbows should be close to the torso. This will be your starting position. While holding the Oberer arms stationary, Curl the weights forward while contracting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Wide Stance Barbell Squat',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack that best matches your height. Once the correct height is chosen and the bar is loaded, step under the bar and place the back of your shoulders (slightly below the neck) across it. Hold on to the bar using both arms at each side and lift it off the rack by first pushing with your legs...',
    nameDe: 'Wide Stance Langhantel Kniebeuge',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer that best matches your height. Once the correct height is chosen and the Stange is loaded, Stufe under the Stange and place the Rücken of your Schultern (slightly below the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Wind Sprints',
    description: 'Hang from a pull-up bar using a pronated grip. Your arms and legs should be extended. This will be your starting position. Begin by quickly raising one knee as high as you can. Do not swing your body or your legs. 3 Immediately reverse the motion, returning that leg to the starting position. Simultaneously raise the opposite knee as high as possible. Continue alternating between legs until the...',
    nameDe: 'Wind Sprints',
    descriptionDe: 'Hang from a Klimmzugstange using a Proniert grip. Your arms and legs should be extended. This will be your starting position. Begin by quickly raising one Knie as high as you can. Do not Schwingen your body or your legs. 3 Immediately Umgekehrt the motion, returning that leg to the starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Wrist Roller',
    description: 'To begin, stand straight up grabbing a wrist roller using a pronated grip (palms facing down). Your feet should be shoulder width apart. Slowly lift both arms until they are fully extended and parallel to the floor in front of you. Note: Make sure the rope is not wrapped around the roller. Your entire body should be stationary except for the forearms. This is the starting position. Rotate one...',
    nameDe: 'Handgelenk-Roller',
    descriptionDe: 'To begin, stand straight up grabbing a Handgelenk roller using a Proniert grip (palms facing down). Your feet should be Schulter width apart. Slowly lift both arms until they are fully extended and parallel to the Boden in front of you. Note: Make sure the Seil is not wrapped around the roller....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Wrist Rotations with Straight Bar',
    description: 'Hold a barbell with both hands and your palms facing down; hands spaced about shoulder width. This will be your starting position. Alternating between each of your hands, perform the movement by extending the wrist as though you were rolling up a newspaper. Continue alternating back and forth until failure. Reverse the motion by flexing the wrist, rolling the opposite direction. Continue the...',
    nameDe: 'Handgelenk Rotations with Straight Stange',
    descriptionDe: 'Hold a Langhantel with both hands and your palms facing down; hands spaced about Schulter width. This will be your starting position. Alternierend between each of your hands, perform the movement by extending the Handgelenk as though you were rolling up a newspaper. Continue Alternierend Rücken and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Zercher Squats',
    description: 'This exercise is best performed inside a squat rack for safety purposes. To begin, first set the bar on a rack that best matches your height. The correct height should be anywhere above the waist but below the chest. Once the correct height is chosen and the bar is loaded, lock your hands together and place the bar on top of your arms in between the forearm and upper arm. Lift the bar up so that...',
    nameDe: 'Zercher Squats',
    descriptionDe: 'This exercise is best performed inside a Kniebeuge Ständer for safety purposes. To begin, first set the Stange on a Ständer that best matches your height. The correct height should be anywhere above the waist but below the Brust. Once the correct height is chosen and the Stange is loaded, lock your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Zottman Curl',
    description: 'Stand up with your torso upright and a dumbbell in each hand being held at arms length. The elbows should be close to the torso. Make sure the palms of the hands are facing each other. This will be your starting position. While holding the upper arm stationary, curl the weights while contracting the biceps as you breathe out. Only the forearms should move. Your wrist should rotate so that you...',
    nameDe: 'Zottman Curl',
    descriptionDe: 'Stand up with your torso Aufrecht and a Kurzhantel in each hand being held at arms length. The elbows should be close to the torso. Make sure the palms of the hands are facing each other. This will be your starting position. While holding the Oberer arm stationary, Curl the weights while...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Zottman Preacher Curl',
    description: 'Grab a dumbbell in each hand and place your upper arms on top of the preacher bench or the incline bench. The dumbbells should be held at shoulder height and the elbows should be flexed. Hold the dumbbells with the palms of your hands facing down. This will be your starting position. As you breathe in, slowly lower the dumbbells keeping the palms down until your upper arm is extended and your...',
    nameDe: 'Zottman Preacher-Curl',
    descriptionDe: 'Grab a Kurzhantel in each hand and place your Oberer arms on top of the preacher Bank or the Schrägbank Bank. The Kurzhanteln should be held at Schulter height and the elbows should be flexed. Hold the Kurzhanteln with the palms of your hands facing down. This will be your starting position. As you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  // ── POWERLIFTING (38) ────────────────────────────────────────────────────────────

  Exercise(
    name: 'Band Good Morning',
    description: 'Using a 41 inch band, stand on one end, spreading your feet a small amount. Bend at the hips to loop the end of the band behind your neck. This will be your starting position. Keeping your legs straight, extend through the hips to come to a near vertical position. Ensure that you do not round your back as you go down back to the starting position.',
    nameDe: 'Good Morning mit Band',
    descriptionDe: 'Using a 41 inch Band, stand on one end, spreading your feet a small amount. Bend at the Hüften to loop the end of the Band behind your Nacken. This will be your starting position. Keeping your legs straight, extend through the Hüften to come to a near Vertikal position. Ensure that you do not round...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Band Good Morning (Pull Through)',
    description: 'Loop the band around a post. Standing a little ways away, loop the opposite end around the neck. Your hands can help hold the band in position. Begin by bending at the hips, getting your butt back as far as possible. Keep your back flat and bend forward to about 90 degrees. Your knees should be only slightly bent. Return to the starting position be driving through with the hips to come back to a...',
    nameDe: 'Good Morning mit Band (Durchzug)',
    descriptionDe: 'Loop the Band around a post. Stehend a little ways away, loop the opposite end around the Nacken. Your hands can help hold the Band in position. Begin by bending at the Hüften, getting your butt Rücken as far as possible. Keep your Rücken Flachbank and bend forward to about 90 degrees. Your knees...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Glute Bridge',
    description: 'Begin seated on the ground with a loaded barbell over your legs. Using a fat bar or having a pad on the bar can greatly reduce the discomfort caused by this exercise. Roll the bar so that it is directly above your hips, and lay down flat on the floor. Begin the movement by driving through with your heels, extending your hips vertically through the bar. Your weight should be supported by your...',
    nameDe: 'Langhantel-Gesäßbrücke',
    descriptionDe: 'Begin Sitzend on the ground with a loaded Langhantel over your legs. Using a fat Stange or having a pad on the Stange can greatly reduce the discomfort caused by this exercise. Roll the Stange so that it is directly above your Hüften, and lay down Flachbank on the Boden. Begin the movement by...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Barbell Hip Thrust',
    description: 'Begin seated on the ground with a bench directly behind you. Have a loaded barbell over your legs. Using a fat bar or having a pad on the bar can greatly reduce the discomfort caused by this exercise. Roll the bar so that it is directly above your hips, and lean back against the bench so that your shoulder blades are near the top of it. Begin the movement by driving through your feet, extending...',
    nameDe: 'Langhantel-Hüftstrecken',
    descriptionDe: 'Begin Sitzend on the ground with a Bank directly behind you. Have a loaded Langhantel over your legs. Using a fat Stange or having a pad on the Stange can greatly reduce the discomfort caused by this exercise. Roll the Stange so that it is directly above your Hüften, and lean Rücken against the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Bench Press - Powerlifting',
    description: 'Begin by lying on the bench, getting your head beyond the bar if possible. Tuck your feet underneath you and arch your back. Using the bar to help support your weight, lift your shoulder off the bench and retract them, squeezing the shoulder blades together. Use your feet to drive your traps into the bench. Maintain this tight body position throughout the movement. However wide your grip, it...',
    nameDe: 'Bank Drücken - Powerlifting',
    descriptionDe: 'Begin by Liegend on the Bank, getting your Kopf beyond the Stange if possible. Tuck your feet underneath you and arch your Rücken. Using the Stange to help support your weight, lift your Schulter off the Bank and retract them, squeezing the Schulter blades together. Use your feet to drive your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Bench Press with Chains',
    description: 'Adjust the leader chain, shortening it to the desired length.Place the chains on the sleeves of the bar. Lying on the bench, get your head beyond the bar if possible. Tuck your feet underneath you and arch your back. Using the bar to help support your weight, lift your shoulder off the bench and retract them, squeezing the shoulder blades together. Use your feet to drive your traps into the...',
    nameDe: 'Bank Drücken with Ketten',
    descriptionDe: 'Adjust the leader chain, shortening it to the desired length.Place the Ketten on the sleeves of the Stange. Liegend on the Bank, get your Kopf beyond the Stange if possible. Tuck your feet underneath you and arch your Rücken. Using the Stange to help support your weight, lift your Schulter off the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Board Press',
    description: 'Begin by lying on the bench, getting your head beyond the bar if possible. One to five boards, made out of 2x6\'s, can be screwed together and held in place by a training partner, bands, or just tucked under your shirt. Tuck your feet underneath you and arch your back. Using the bar to help support your weight, lift your shoulder off the bench and retract them, squeezing the shoulder blades...',
    nameDe: 'Board Press',
    descriptionDe: 'Begin by Liegend on the Bank, getting your Kopf beyond the Stange if possible. One to five boards, made out of 2x6\'s, can be screwed together and held in place by a training partner, bands, or just tucked under your shirt. Tuck your feet underneath you and arch your Rücken. Using the Stange to help...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Box Squat',
    description: 'The box squat allows you to squat to desired depth and develop explosive strength in the squat movement. Begin in a power rack with a box at the appropriate height behind you. Typically, you would aim for a box height that brings you to a parallel squat, but you can train higher or lower if desired. Begin by stepping under the bar and placing it across the back of the shoulders. Squeeze your...',
    nameDe: 'Box Kniebeuge',
    descriptionDe: 'The Box Kniebeuge allows you to Kniebeuge to desired depth and develop Explosiv strength in the Kniebeuge movement. Begin in a power Ständer with a Box at the appropriate height behind you. Typically, you would aim for a Box height that brings you to a parallel Kniebeuge, but you can train higher...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Box Squat with Bands',
    description: 'Begin in a power rack with a box at the appropriate height behind you. Set up the bands on the sleeves, secured to either band pegs, the rack, or dumbbells so that there is appropriate tension. If dumbbells are used, secure them so that they don\'t move. Also, ensure that the dumbbells you are using are heavy enough for the bands that you are using. Additional plates can be used to hold the...',
    nameDe: 'Box Kniebeuge mit Band',
    descriptionDe: 'Begin in a power Ständer with a Box at the appropriate height behind you. Set up the bands on the sleeves, secured to either Band pegs, the Ständer, or Kurzhanteln so that there is appropriate tension. If Kurzhanteln are used, secure them so that they don\'t move. Also, ensure that the Kurzhanteln...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Chain Handle Extension',
    description: 'You will need two cable handle attachments and a flat bench, as well as chains, for this exercise. Clip the middle of the chains to the handles, and position yourself on the flat bench. Your elbows should be pointing straight up. Begin by extending through the elbow, keeping your upper arm still, with your wrists pronated. Pause at the lockout, and reverse the motion to return to the starting...',
    nameDe: 'Chain Handle Streckung',
    descriptionDe: 'You will need two Kabelzug handle attachments and a Flachbank Bank, as well as Ketten, for this exercise. Clip the middle of the Ketten to the handles, and position yourself on the Flachbank Bank. Your elbows should be pointing straight up. Begin by extending through the elbow, keeping your Oberer...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Chain Press',
    description: 'Begin by connecting the chains to the cable handle attachments. Position yourself on the flat bench in the same position as for a dumbbell press. Your wrists should be pronated and arms perpendicular to the floor. This will be your starting position. Lower the chains by flexing the elbows, unloading some of the chain onto the floor. Continue until your elbow forms a 90 degree angle, and then...',
    nameDe: 'Chain Drücken',
    descriptionDe: 'Begin by connecting the Ketten to the Kabelzug handle attachments. Position yourself on the Flachbank Bank in the same position as for a Kurzhantel Drücken. Your wrists should be Proniert and arms perpendicular to the Boden. This will be your starting position. Unterer the Ketten by flexing the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Deadlift with Bands',
    description: 'To deadlift with short bands, simply loop them over the bar before you start, and step into them to set up. For long bands, they will need to be anchored to a secure base, such as heavy dumbbells or a rack. With your feet, and your grip set, take a big breath and then lower your hips and bend the knees until your shins contact the bar. Look forward with your head, keep your chest up and your back...',
    nameDe: 'Kreuzheben mit Band',
    descriptionDe: 'To Kreuzheben with short bands, simply loop them over the Stange before you start, and Stufe into them to set up. For long bands, they will need to be anchored to a secure base, such as heavy Kurzhanteln or a Ständer. With your feet, and your grip set, take a big breath and then Unterer your Hüften...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Deadlift with Chains',
    description: 'You can attach the chains to the sleeves of the bar, or just drape the middle over the bar so there is a greater weight increase as you lift. Approach the bar so that it is centered over your feet. You feet should be about hip width apart. Bend at the hip to grip the bar at shoulder width, allowing your shoulder blades to protract. Typically, you would use an overhand grip or an over/under grip...',
    nameDe: 'Kreuzheben with Ketten',
    descriptionDe: 'You can attach the Ketten to the sleeves of the Stange, or just drape the middle over the Stange so there is a greater weight increase as you lift. Approach the Stange so that it is centered over your feet. You feet should be about Hüfte width apart. Bend at the Hüfte to grip the Stange at Schulter...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Deficit Deadlift',
    description: 'Begin by having a platform or weight plates that you can stand on, usually 1-3 inches in height. Approach the bar so that it is centered over your feet. You feet should be about hip width apart. Bend at the hip to grip the bar at shoulder width, allowing your shoulder blades to protract. Typically, you would use an overhand grip or an over/under grip on heavier sets. With your feet, and your grip...',
    nameDe: 'Deficit Kreuzheben',
    descriptionDe: 'Begin by having a platform or weight plates that you can stand on, usually 1-3 inches in height. Approach the Stange so that it is centered over your feet. You feet should be about Hüfte width apart. Bend at the Hüfte to grip the Stange at Schulter width, allowing your Schulter blades to protract....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Dumbbell Floor Press',
    description: 'Lay on the floor holding dumbbells in your hands. Your knees can be bent. Begin with the weights fully extended above you. Lower the weights until your upper arm comes in contact with the floor. You can tuck your elbows to emphasize triceps size and strength, or to focus on your chest angle your arms to the side. Pause at the bottom, and then bring the weight together at the top by extending...',
    nameDe: 'Kurzhantel Boden Drücken',
    descriptionDe: 'Lay on the Boden holding Kurzhanteln in your hands. Your knees can be bent. Begin with the weights fully extended above you. Unterer the weights until your Oberer arm comes in contact with the Boden. You can tuck your elbows to emphasize Trizeps size and strength, or to focus on your Brust angle...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Floor Press',
    description: 'Adjust the j-hooks so they are at the appropriate height to rack the bar. Begin lying on the floor with your head near the end of a power rack. Keeping your shoulder blades pulled together; pull the bar off of the hooks. Lower the bar towards the bottom of your chest or upper stomach, squeezing the bar and attempting to pull it apart as you do so. Ensure that you tuck your elbows throughout the...',
    nameDe: 'Bodendrücken',
    descriptionDe: 'Adjust the j-hooks so they are at the appropriate height to Ständer the Stange. Begin Liegend on the Boden with your Kopf near the end of a power Ständer. Keeping your Schulter blades pulled together; pull the Stange off of the hooks. Unterer the Stange towards the bottom of your Brust or Oberer...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Floor Press with Chains',
    description: 'Adjust the j-hooks so they are at the appropriate height to rack the bar. For this exercise, drape the chains directly over the end of the bar, trying to keep the ends away from the plates. Begin lying on the floor with your head near the end of a power rack. Keeping your shoulder blades pulled together, pull the bar off of the hooks. Lower the bar towards the bottom of your chest or upper...',
    nameDe: 'Boden Drücken with Ketten',
    descriptionDe: 'Adjust the j-hooks so they are at the appropriate height to Ständer the Stange. For this exercise, drape the Ketten directly over the end of the Stange, trying to keep the ends away from the plates. Begin Liegend on the Boden with your Kopf near the end of a power Ständer. Keeping your Schulter...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Glute Ham Raise',
    description: 'Begin by adjusting the equipment to fit your body. Place your feet against the footplate in between the rollers as you lie facedown. Your knees should be just behind the pad. Start from the bottom of the movement. Keep your back arched as you begin the movement by flexing the knees. Drive your toes into the foot plate as you do so. Keep your upper body straight, and continue until your body is...',
    nameDe: 'Gesäß Ham Heben',
    descriptionDe: 'Begin by adjusting the equipment to fit your body. Place your feet against the footplate in between the rollers as you lie facedown. Your knees should be just behind the pad. Start from the bottom of the movement. Keep your Rücken arched as you begin the movement by flexing the knees. Drive your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Good Morning',
    description: 'Begin with a bar on a rack at shoulder height. Rack the bar across the rear of your shoulders as you would a power squat, not on top of your shoulders. Keep your back tight, shoulder blades pinched together, and your knees slightly bent. Step back from the rack. Begin by bending at the hips, moving them back as you bend over to near parallel. Keep your back arched and your cervical spine in...',
    nameDe: 'Good Morning',
    descriptionDe: 'Begin with a Stange on a Ständer at Schulter height. Ständer the Stange across the rear of your Schultern as you would a power Kniebeuge, not on top of your Schultern. Keep your Rücken tight, Schulter blades pinched together, and your knees slightly bent. Stufe Rücken from the Ständer. Begin by...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Good Morning off Pins',
    description: 'Begin with a bar on a rack at about the same height as your stomach. Bend over underneath the bar and rack the bar across the rear of your shoulders as you would a power squat, not on top of your shoulders. At the proper height, you should be near parallel to the floor when bent over. Keep your back tight, shoulder blades pinched together, and your knees slightly bent. Keep your back arched and...',
    nameDe: 'Good Morning off Pins',
    descriptionDe: 'Begin with a Stange on a Ständer at about the same height as your stomach. Bend over underneath the Stange and Ständer the Stange across the rear of your Schultern as you would a power Kniebeuge, not on top of your Schultern. At the proper height, you should be near parallel to the Boden when...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hanging Bar Good Morning',
    description: 'Begin with a bar on a rack at about the same height as your stomach. Suspend the bar using chains or suspension straps. Bend over underneath the bar and rack the bar across the rear of your shoulders as you would a power squat, not on top of your traps. At the proper height, you should be near parallel to the floor when bent over. Keep your back tight, shoulder blades pinched together, and your...',
    nameDe: 'Hanging Stange Good Morning',
    descriptionDe: 'Begin with a Stange on a Ständer at about the same height as your stomach. Suspend the Stange using Ketten or Schlingentrainer straps. Bend over underneath the Stange and Ständer the Stange across the rear of your Schultern as you would a power Kniebeuge, not on top of your Trapezmuskel. At the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hip Lift with Band',
    description: 'After choosing a suitable band, lay down in the middle of the rack, after securing the band on either side of you. If your rack doesn\'t have pegs, the band can be secured using heavy dumbbells or similar objects, just ensure they won\'t move. Adjust your position so that the band is directly over your hips. Bend your knees and place your feet flat on the floor. Your hands can be on the floor or...',
    nameDe: 'Hüfte Lift mit Band',
    descriptionDe: 'After choosing a suitable Band, lay down in the middle of the Ständer, after securing the Band on either side of you. If your Ständer doesn\'t have pegs, the Band can be secured using heavy Kurzhanteln or similar objects, just ensure they won\'t move. Adjust your position so that the Band is directly...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kneeling Squat',
    description: 'Set the bar to the proper height in a power rack. Kneel behind the bar; it may be beneficial to put a mat down to pad your knees. Slide under the bar, racking it across the back of your shoulders. Your shoulder blades should be retracted and the bar tight across your back. Unrack the weight. With your head looking forward, sit back with your butt until you touch your calves. Reverse the motion,...',
    nameDe: 'Kniend Kniebeuge',
    descriptionDe: 'Set the Stange to the proper height in a power Ständer. Kneel behind the Stange; it may be beneficial to put a mat down to pad your knees. Slide under the Stange, racking it across the Rücken of your Schultern. Your Schulter blades should be retracted and the Stange tight across your Rücken. Unrack...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Pin Presses',
    description: 'Pin presses remove the eccentric phase of the bench press, developing starting strength. They also allow you to train a desired range of motion. The bench should be set up in a power rack. Set the pins to the desired point in your range of motion, whether it just be lockout or an inch off of your chest. The bar should be moved to the pins and prepared for lifting. Begin by lying on the bench,...',
    nameDe: 'Pin Presses',
    descriptionDe: 'Pin presses remove the eccentric phase of the Bank Drücken, developing starting strength. They also allow you to train a desired range of motion. The Bank should be set up in a power Ständer. Set the pins to the desired point in your range of motion, whether it just be lockout or an inch off of...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Rack Pull with Bands',
    description: 'Set up in a power rack with the bar on the pins. The pins should be set to the desired point; just below the knees, just above, or in the mid thigh position. Attach bands to the base of the rack, or secure them with dumbbells. Attach the other end to the bar. You may need to choke the bands to provide tension. Position yourself against the bar in proper deadlifting position. Your feet should be...',
    nameDe: 'Ständer Pull mit Band',
    descriptionDe: 'Set up in a power Ständer with the Stange on the pins. The pins should be set to the desired point; just below the knees, just above, or in the mid Oberschenkel position. Attach bands to the base of the Ständer, or secure them with Kurzhanteln. Attach the other end to the Stange. You may need to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Rack Pulls',
    description: 'Set up in a power rack with the bar on the pins. The pins should be set to the desired point; just below the knees, just above, or in the mid thigh position. Position yourself against the bar in proper deadlifting position. Your feet should be under your hips, your grip shoulder width, back arched, and hips back to engage the hamstrings. Since the weight is typically heavy, you may use a mixed...',
    nameDe: 'Ständer Pulls',
    descriptionDe: 'Set up in a power Ständer with the Stange on the pins. The pins should be set to the desired point; just below the knees, just above, or in the mid Oberschenkel position. Position yourself against the Stange in proper deadlifting position. Your feet should be under your Hüften, your grip Schulter...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Reverse Band Bench Press',
    description: 'Position a bench inside a power rack, with the bar set to the correct height. Begin by anchoring bands either to band pegs or to the top of the rack. Ensure that you will be position properly under the bands. Attach the other end to the barbell. Lie on the bench, tuck your feet underneath you and arch your back. Using the bar to help support your weight, lift your shoulder off the bench and...',
    nameDe: 'Umgekehrt Band Bank Drücken',
    descriptionDe: 'Position a Bank inside a power Ständer, with the Stange set to the correct height. Begin by anchoring bands either to Band pegs or to the top of the Ständer. Ensure that you will be position properly under the bands. Attach the other end to the Langhantel. Lie on the Bank, tuck your feet underneath...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Reverse Band Box Squat',
    description: 'Begin in a power rack with a box at the appropriate height behind you. Set up the bands either on band pegs or attached to the top of the rack, ensuring they will be directly above the bar during the squat. Attach the other end to the bar. Begin by stepping under the bar and placing it across the back of the shoulders. Squeeze your shoulder blades together and rotate your elbows forward,...',
    nameDe: 'Umgekehrt Band Box Kniebeuge',
    descriptionDe: 'Begin in a power Ständer with a Box at the appropriate height behind you. Set up the bands either on Band pegs or attached to the top of the Ständer, ensuring they will be directly above the Stange during the Kniebeuge. Attach the other end to the Stange. Begin by stepping under the Stange and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Reverse Band Deadlift',
    description: 'Set the bar up in a power rack. Attach bands to the top of the rack, using either bands pegs or the frame itself. Attach the other end of the bands to the bar. Approach the bar so that it is centered over your feet. You feet should be about hip width apart. Bend at the hip to grip the bar at shoulder width, allowing your shoulder blades to protract. Typically, you would use an overhand grip or an...',
    nameDe: 'Umgekehrt Band Kreuzheben',
    descriptionDe: 'Set the Stange up in a power Ständer. Attach bands to the top of the Ständer, using either bands pegs or the frame itself. Attach the other end of the bands to the Stange. Approach the Stange so that it is centered over your feet. You feet should be about Hüfte width apart. Bend at the Hüfte to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Reverse Band Power Squat',
    description: 'Begin in a power rack with the pins and bar set at the appropriate height. After loading the bar, attach bands to the top of the rack, using either pegs or the frame itself. Attach the other end of the bands to the bar. Begin by stepping under the bar and placing it across the back of the shoulders. Squeeze your shoulder blades together and rotate your elbows forward, attempting to bend the bar...',
    nameDe: 'Umgekehrt Band Power Kniebeuge',
    descriptionDe: 'Begin in a power Ständer with the pins and Stange set at the appropriate height. After loading the Stange, attach bands to the top of the Ständer, using either pegs or the frame itself. Attach the other end of the bands to the Stange. Begin by stepping under the Stange and placing it across the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Reverse Band Sumo Deadlift',
    description: 'Begin with a bar loaded on the floor inside of a power rack. Attach bands to the top of the rack, using either pegs or the frame itself. Attach the other end to the barbell. Approach the bar so that the bar intersects the middle of the feet. The feet should be set very wide, near the collars. Bend at the hips to grip the bar. The arms should be directly below the shoulders, inside the legs, and...',
    nameDe: 'Umgekehrt Band Sumo Kreuzheben',
    descriptionDe: 'Begin with a Stange loaded on the Boden inside of a power Ständer. Attach bands to the top of the Ständer, using either pegs or the frame itself. Attach the other end to the Langhantel. Approach the Stange so that the Stange intersects the middle of the feet. The feet should be set very wide, near...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Good Mornings',
    description: 'Set up a box in a power rack. The pins should be set at an appropriate height. Begin by stepping under the bar and placing it across the back of the shoulders, not on top of your traps. Squeeze your shoulder blades together and rotate your elbows forward, attempting to bend the bar across your shoulders. Remove the bar from the rack, creating a tight arch in your lower back. Keep your head facing...',
    nameDe: 'Sitzend Good Mornings',
    descriptionDe: 'Set up a Box in a power Ständer. The pins should be set at an appropriate height. Begin by stepping under the Stange and placing it across the Rücken of the Schultern, not on top of your Trapezmuskel. Squeeze your Schulter blades together and rotate your elbows forward, attempting to bend the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Speed Box Squat',
    description: 'Attach bands to the bar that are securely anchored near the ground. You may need to choke the bands to get adequate tension. Use a box of an appropriate height for this exercise. Load the bar to a weight that still requires effort, but isn\'t so heavy that speed is compromised. Typically, that will be between 50-70% of your one rep max. Position the bar on your upper back, shoulder blades...',
    nameDe: 'Speed Box Kniebeuge',
    descriptionDe: 'Attach bands to the Stange that are securely anchored near the ground. You may need to choke the bands to get adequate tension. Use a Box of an appropriate height for this exercise. Load the Stange to a weight that still requires effort, but isn\'t so heavy that speed is compromised. Typically, that...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Squat with Bands',
    description: 'Set up the bands on the sleeves, secured to either band pegs, the rack, or dumbbells so that there is appropriate tension. Begin by stepping under the bar and placing it across the back of the shoulders. Squeeze your shoulder blades together and rotate your elbows forward, attempting to bend the bar across your shoulders. Remove the bar from the rack, creating a tight arch in your lower back, and...',
    nameDe: 'Kniebeuge mit Band',
    descriptionDe: 'Set up the bands on the sleeves, secured to either Band pegs, the Ständer, or Kurzhanteln so that there is appropriate tension. Begin by stepping under the Stange and placing it across the Rücken of the Schultern. Squeeze your Schulter blades together and rotate your elbows forward, attempting to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Squat with Chains',
    description: 'To set up the chains, begin by looping the leader chain over the sleeves of the bar. The heavy chain should be attached using a snap hook. Adjust the length of the lead chain so that a few links are still on the floor at the top of the movement. Begin by stepping under the bar and placing it across the back of the shoulders. Squeeze your shoulder blades together and rotate your elbows forward,...',
    nameDe: 'Kniebeuge with Ketten',
    descriptionDe: 'To set up the Ketten, begin by looping the leader chain over the sleeves of the Stange. The heavy chain should be attached using a snap hook. Adjust the length of the lead chain so that a few links are still on the Boden at the top of the movement. Begin by stepping under the Stange and placing it...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Sumo Deadlift',
    description: 'Begin with a bar loaded on the ground. Approach the bar so that the bar intersects the middle of the feet. The feet should be set very wide, near the collars. Bend at the hips to grip the bar. The arms should be directly below the shoulders, inside the legs, and you can use a pronated grip, a mixed grip, or hook grip. Relax the shoulders, which in effect lengthens your arms. Take a breath, and...',
    nameDe: 'Sumo-Kreuzheben',
    descriptionDe: 'Begin with a Stange loaded on the ground. Approach the Stange so that the Stange intersects the middle of the feet. The feet should be set very wide, near the collars. Bend at the Hüften to grip the Stange. The arms should be directly below the Schultern, inside the legs, and you can use a Proniert...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Sumo Deadlift with Bands',
    description: 'To deadlift with short bands, simply loop them over the bar before you start, and step into them to set up. Ensure that they under the back half of your foot, directly where you are driving into the floor. Begin with a bar loaded on the ground. Approach the bar so that the bar intersects the middle of the feet. The feet should be set very wide, near the collars. Bend at the hips to grip the bar....',
    nameDe: 'Sumo Kreuzheben mit Band',
    descriptionDe: 'To Kreuzheben with short bands, simply loop them over the Stange before you start, and Stufe into them to set up. Ensure that they under the Rücken Halb of your foot, directly where you are driving into the Boden. Begin with a Stange loaded on the ground. Approach the Stange so that the Stange...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Sumo Deadlift with Chains',
    description: 'You can attach the chains to the sleeves of the bar, or just drape the middle over the bar so there is a greater weight increase as you lift. Attempt to keep the ends of the chains away from the plates so you don\'t hit them when you lower the weight. Begin with a bar loaded on the ground. Approach the bar so that the bar intersects the middle of the feet. The feet should be set very wide, near...',
    nameDe: 'Sumo Kreuzheben with Ketten',
    descriptionDe: 'You can attach the Ketten to the sleeves of the Stange, or just drape the middle over the Stange so there is a greater weight increase as you lift. Attempt to keep the ends of the Ketten away from the plates so you don\'t hit them when you Unterer the weight. Begin with a Stange loaded on the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  // ── OLYMPIC WEIGHTLIFTING (35) ────────────────────────────────────────────────────────────

  Exercise(
    name: 'Clean',
    description: 'With a barbell on the floor close to the shins, take an overhand (or hook) grip just outside the legs. Lower your hips with the weight focused on the heels, back straight, head facing forward, chest up, with your shoulders just in front of the bar. This will be your starting position.  Begin the first pull by driving through the heels, extending your knees. Your back angle should stay the same,...',
    nameDe: 'Stoßen',
    descriptionDe: 'With a Langhantel on the Boden close to the shins, take an Obergriff (or hook) grip just outside the legs. Unterer your Hüften with the weight focused on the heels, Rücken straight, Kopf facing forward, Brust up, with your Schultern just in front of the Stange. This will be your starting position. ...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Clean Deadlift',
    description: 'Begin standing with a barbell close to your shins. Your feet should be directly under your hips with your feet turned out slightly. Grip the bar with a double overhand grip or hook grip, about shoulder width apart. Squat down to the bar. Your spine should be in full extension, with a back angle that places your shoulders in front of the bar and your back as vertical as possible. Begin by driving...',
    nameDe: 'Stoßen-Kreuzheben',
    descriptionDe: 'Begin Stehend with a Langhantel close to your shins. Your feet should be directly under your Hüften with your feet turned out slightly. Grip the Stange with a Doppelt Obergriff grip or hook grip, about Schulter width apart. Kniebeuge down to the Stange. Your Wirbelsäule should be in Komplett...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Clean Pull',
    description: 'With a barbell on the floor close to the shins, take an overhand or hook grip just outside the legs. Lower your hips with the weight focused on the heels, back straight, head facing forward, chest up, with your shoulders just in front of the bar. This will be your starting position. Begin the first pull by driving through the heels, extending your knees. Your back angle should stay the same, and...',
    nameDe: 'Stoßen Pull',
    descriptionDe: 'With a Langhantel on the Boden close to the shins, take an Obergriff or hook grip just outside the legs. Unterer your Hüften with the weight focused on the heels, Rücken straight, Kopf facing forward, Brust up, with your Schultern just in front of the Stange. This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Clean Shrug',
    description: 'Begin with a shoulder width, double overhand or hook grip, with the bar hanging at the mid thigh position. Your back should be straight and inclined slightly forward. Shrug your shoulders towards your ears. While this exercise can usually by loaded with heavier weight than a clean, avoid overloading to the point that the execution slows down.',
    nameDe: 'Stoßen Schulterziehen',
    descriptionDe: 'Begin with a Schulter width, Doppelt Obergriff or hook grip, with the Stange hanging at the mid Oberschenkel position. Your Rücken should be straight and inclined slightly forward. Schulterziehen your Schultern towards your ears. While this exercise can usually by loaded with heavier weight than a...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Clean and Jerk',
    description: 'With a barbell on the floor close to the shins, take an overhand or hook grip just outside the legs. Lower your hips with the weight focused on the heels, back straight, head facing forward, chest up, with your shoulders just in front of the bar. This will be your starting position. Begin the first pull by driving through the heels, extending your knees. Your back angle should stay the same, and...',
    nameDe: 'Stoßen und Reißen',
    descriptionDe: 'With a Langhantel on the Boden close to the shins, take an Obergriff or hook grip just outside the legs. Unterer your Hüften with the weight focused on the heels, Rücken straight, Kopf facing forward, Brust up, with your Schultern just in front of the Stange. This will be your starting position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Clean from Blocks',
    description: 'With a barbell on boxes or stands of the desired height, take an overhand or hook grip just outside the legs. Lower your hips with the weight focused on the heels, back straight, head facing forward, chest up, with your shoulders just in front of the bar. This will be your starting position. Begin the first pull by driving through the heels, extending your knees. Your back angle should stay the...',
    nameDe: 'Stoßen from Blocks',
    descriptionDe: 'With a Langhantel on boxes or stands of the desired height, take an Obergriff or hook grip just outside the legs. Unterer your Hüften with the weight focused on the heels, Rücken straight, Kopf facing forward, Brust up, with your Schultern just in front of the Stange. This will be your starting...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Frankenstein Squat',
    description: 'This drill teaches you the proper positioning of both the bar and your body during the clean and front squat. Place the barbell on the front of the shoulders, releasing your grip and extending your arms out in front of you. The shoulders should be pushed forward to create a shelf, and the bar should be in contact with the throat. Ensure that you only move your shoulder blades forward; don\'t round...',
    nameDe: 'Frankenstein Kniebeuge',
    descriptionDe: 'This drill teaches you the proper positioning of both the Stange and your body during the Stoßen and front Kniebeuge. Place the Langhantel on the front of the Schultern, releasing your grip and extending your arms out in front of you. The Schultern should be pushed forward to create a shelf, and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hang Clean',
    description: 'Begin with a shoulder width, double overhand or hook grip, with the bar hanging at the mid thigh position. Your back should be straight and inclined slightly forward. Begin by aggressively extending through the hips, knees and ankles, driving the weight upward. As you do so, shrug your shoulders towards your ears. Immediately recover by driving through the heels, keeping the torso upright and...',
    nameDe: 'Hang-Stoßen',
    descriptionDe: 'Begin with a Schulter width, Doppelt Obergriff or hook grip, with the Stange hanging at the mid Oberschenkel position. Your Rücken should be straight and inclined slightly forward. Begin by aggressively extending through the Hüften, knees and ankles, driving the weight upward. As you do so,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hang Clean - Below the Knees',
    description: 'Begin with a shoulder width, double overhand or hook grip, with the bar hanging just below the knees. Your back should be straight and inclined slightly forward. Begin by aggressively extending through the hips, knees and ankles, driving the weight upward. As you do so, shrug your shoulders towards your ears. As full extension is achieved, transition into the third pull by aggressively shrugging...',
    nameDe: 'Hang-Stoßen - Below the Knees',
    descriptionDe: 'Begin with a Schulter width, Doppelt Obergriff or hook grip, with the Stange hanging just below the knees. Your Rücken should be straight and inclined slightly forward. Begin by aggressively extending through the Hüften, knees and ankles, driving the weight upward. As you do so, Schulterziehen your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hang Snatch',
    description: 'Begin with a wide grip on the bar, with an overhand or hook grip. The feet should be directly below the hips with the feet turned out. Your knees should be slightly bent, and the torso inclined forward. The spine should be fully extended and the head facing forward. The bar should be at the hips. This will be your starting position. Aggressively extend through the legs and hips. At peak...',
    nameDe: 'Hang Reißen',
    descriptionDe: 'Begin with a Weiter Griff on the Stange, with an Obergriff or hook grip. The feet should be directly below the Hüften with the feet turned out. Your knees should be slightly bent, and the torso inclined forward. The Wirbelsäule should be fully extended and the Kopf facing forward. The Stange should...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hang Snatch - Below Knees',
    description: 'Begin with a wide grip on the bar, with an overhand or hook grip. The feet should be directly below the hips with the feet turned out. Your knees should be slightly bent, and the torso inclined forward. The spine should be fully extended and the head facing forward. The bar should be just below the knees. This will be your starting position. Aggressively extend through the legs and hips. At peak...',
    nameDe: 'Hang Reißen - Below Knees',
    descriptionDe: 'Begin with a Weiter Griff on the Stange, with an Obergriff or hook grip. The feet should be directly below the Hüften with the feet turned out. Your knees should be slightly bent, and the torso inclined forward. The Wirbelsäule should be fully extended and the Kopf facing forward. The Stange should...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Heaving Snatch Balance',
    description: 'This drill helps you learn the snatch. Begin by holding a light weight across the back of the shoulders. Your feet should be slightly wider than hip width apart with the feet turned out, the same position that you would perform a squat with. Begin by dipping with the knees slightly, and popping back up to briefly unload the bar. Drive yourself underneath the bar, elevating it overhead as you...',
    nameDe: 'Heaving Reißen Balance',
    descriptionDe: 'This drill helps you learn the Reißen. Begin by holding a light weight across the Rücken of the Schultern. Your feet should be slightly wider than Hüfte width apart with the feet turned out, the same position that you would perform a Kniebeuge with. Begin by dipping with the knees slightly, and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Jerk Balance',
    description: 'This drill helps you learn to drive yourself low enough during the jerk and corrects those who move backward during the movement. Begin with the bar racked in the jerk position, with the shoulders forward, torso upright, and the feet split slightly apart. Initiate the movement as you would a normal jerk, dipping at the knees while keeping your torso vertical, and driving back up forcefully, using...',
    nameDe: 'Ausstoßen Balance',
    descriptionDe: 'This drill helps you learn to drive yourself low enough during the Ausstoßen and corrects those who move backward during the movement. Begin with the Stange racked in the Ausstoßen position, with the Schultern forward, torso Aufrecht, and the feet split slightly apart. Initiate the movement as you...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Jerk Dip Squat',
    description: 'This movement strengthens the dip portion of the jerk. Begin with the bar racked in the jerk position, with the shoulders forward to create a shelf and the bar lightly contacting the throat. The feet should be directly under the hips, with the feet turned out as is comfortable. Keeping the torso vertical, dip by flexing the knees, allowing them to travel forward and without moving the hips to the...',
    nameDe: 'Ausstoßen Dip Kniebeuge',
    descriptionDe: 'This movement strengthens the Dip portion of the Ausstoßen. Begin with the Stange racked in the Ausstoßen position, with the Schultern forward to create a shelf and the Stange lightly contacting the throat. The feet should be directly under the Hüften, with the feet turned out as is comfortable....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kneeling Jump Squat',
    description: 'Begin kneeling on the floor with a barbell racked across the back of your shoulders, or you can use your body weight for this exercise. This can be done inside of a power rack to make unracking easier. Sit back with your hips until your glutes touch your feet, keeping your head and chest up. Explode up with your hips, generating enough power to land with your feet flat on the floor. Continue with...',
    nameDe: 'Kniend Sprung Kniebeuge',
    descriptionDe: 'Begin Kniend on the Boden with a Langhantel racked across the Rücken of your Schultern, or you can use your body weight for this exercise. This can be done inside of a power Ständer to make unracking easier. Sit Rücken with your Hüften until your Gesäß touch your feet, keeping your Kopf and Brust...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Muscle Snatch',
    description: 'Begin with a loaded barbell held at the mid thigh position with a wide grip. The feet should be directly below the hips, with the feet turned out as needed. Lower the hips, with the chest up and the head looking forward. The shoulders should be just in front of the bar. This will be the starting position. Begin the pull by driving through the front of the heels, raising the bar. Transition into...',
    nameDe: 'Muskelreißen',
    descriptionDe: 'Begin with a loaded Langhantel held at the mid Oberschenkel position with a Weiter Griff. The feet should be directly below the Hüften, with the feet turned out as needed. Unterer the Hüften, with the Brust up and the Kopf looking forward. The Schultern should be just in front of the Stange. This...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Olympic Squat',
    description: 'Begin with a barbell supported on top of the traps. The chest should be up, and the head facing forward. Adopt a hip width stance with the feet turned out as needed. Descend by flexing the knees, refraining from moving the hips back as much as possible. This requires that the knees travel forward; ensure that they stay aligned with the feet. The goal is to keep the torso as upright as possible....',
    nameDe: 'Olympic Kniebeuge',
    descriptionDe: 'Begin with a Langhantel supported on top of the Trapezmuskel. The Brust should be up, and the Kopf facing forward. Adopt a Hüfte width stance with the feet turned out as needed. Descend by flexing the knees, refraining from moving the Hüften Rücken as much as possible. This requires that the knees...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Overhead Squat',
    description: 'Start out by having a barbell in front of you on the floor. Your feet should be wider than shoulder width apart from each other. Bend the knees and use a pronated grip (palms facing you) to grab the barbell. Your hands should be at a wider than shoulder width apart from each other before lifting. Once you are positioned, lift the barbell up until you can rest it on your chest. Move the barbell...',
    nameDe: 'Überkopf Kniebeuge',
    descriptionDe: 'Start out by having a Langhantel in front of you on the Boden. Your feet should be wider than Schulter width apart from each other. Bend the knees and use a Proniert grip (palms facing you) to grab the Langhantel. Your hands should be at a wider than Schulter width apart from each other before...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Power Clean from Blocks',
    description: 'With a barbell on boxes of the desired height, take a grip just outside the legs. Lower your hips with the weight focused on the heels, back straight, head facing forward, chest up, with your shoulders just in front of the bar. This will be your starting position. Begin the first pull by driving through the heels, extending your knees. Your back angle should stay the same, and your arms should...',
    nameDe: 'Power-Stoßen von Blöcken',
    descriptionDe: 'With a Langhantel on boxes of the desired height, take a grip just outside the legs. Unterer your Hüften with the weight focused on the heels, Rücken straight, Kopf facing forward, Brust up, with your Schultern just in front of the Stange. This will be your starting position. Begin the first pull...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Power Jerk',
    description: 'Standing with the weight racked on the front of the shoulders, begin with the dip. With your feet directly under your hips, flex the knees without moving the hips backward. Go down only slightly, and reverse direction as powerfully as possible. Drive through the heels create as much speed and force as possible, and be sure to move your head out of the way as the bar leaves the shoulders. At this...',
    nameDe: 'Power-Jerk',
    descriptionDe: 'Stehend with the weight racked on the front of the Schultern, begin with the Dip. With your feet directly under your Hüften, flex the knees without moving the Hüften backward. Go down only slightly, and Umgekehrt direction as powerfully as possible. Drive through the heels create as much speed and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Power Snatch',
    description: 'Begin with a loaded barbell on the floor. The bar should be close to or touching the shins, and a wide grip should be taken on the bar. The feet should be directly below the hips, with the feet turned out as needed. Lower the hips, with the chest up and the head looking forward. The shoulders should be just in front of the bar. This will be the starting position. Begin the first pull by driving...',
    nameDe: 'Power Reißen',
    descriptionDe: 'Begin with a loaded Langhantel on the Boden. The Stange should be close to or touching the shins, and a Weiter Griff should be taken on the Stange. The feet should be directly below the Hüften, with the feet turned out as needed. Unterer the Hüften, with the Brust up and the Kopf looking forward....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Power Snatch from Blocks',
    description: 'Begin with a loaded barbell on boxes or stands of the desired height. A wide grip should be taken on the bar. The feet should be directly below the hips, with the feet turned out as needed. Lower the hips, with the chest up and the head looking forward. The shoulders should be just in front of the bar, with the elbows pointed out. This will be the starting position. Begin the first pull by...',
    nameDe: 'Power Reißen from Blocks',
    descriptionDe: 'Begin with a loaded Langhantel on boxes or stands of the desired height. A Weiter Griff should be taken on the Stange. The feet should be directly below the Hüften, with the feet turned out as needed. Unterer the Hüften, with the Brust up and the Kopf looking forward. The Schultern should be just...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Push Press',
    nameDe: 'Push Drücken',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Push Press - Behind the Neck',
    description: 'Standing with the weight racked on the back of the shoulders, begin with the dip. With your feet directly under your hips, flex the knees without moving the hips backward. Go down only slightly, and reverse direction as powerfully as possible. Drive through the heels create as much speed and force as possible, moving the bar in a vertical path. Using the momentum generated, finish pressing the...',
    nameDe: 'Push Drücken - Behind the Nacken',
    descriptionDe: 'Stehend with the weight racked on the Rücken of the Schultern, begin with the Dip. With your feet directly under your Hüften, flex the knees without moving the Hüften backward. Go down only slightly, and Umgekehrt direction as powerfully as possible. Drive through the heels create as much speed and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Rack Delivery',
    description: 'This drill teaches the delivery of the barbell to the rack position on the shoulders. Begin holding a bar in the scarecrow position, with the upper arms parallel to the floor, and the forearms hanging down. Use a hook grip, with your fingers wrapped over your thumbs. Begin by rotating the elbows around the bar, delivering the bar to the shoulders. As your elbows come forward, relax your grip. The...',
    nameDe: 'Ständer Delivery',
    descriptionDe: 'This drill teaches the delivery of the Langhantel to the Ständer position on the Schultern. Begin holding a Stange in the scarecrow position, with the Oberer arms parallel to the Boden, and the Unterarme hanging down. Use a hook grip, with your fingers wrapped over your thumbs. Begin by rotating...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Romanian Deadlift from Deficit',
    description: 'Begin standing while holding a bar at arm\'s length in front of you. You can stand on a raised platform to increase the range of motion. Begin by flexing the knees slightly, and then flex at the hip, moving your butt back as far as possible, lowering the torso as far as flexibility allows. The back should remain in absolute extension at all times, and the bar should remain in contact with the...',
    nameDe: 'Rumänisch Kreuzheben from Deficit',
    descriptionDe: 'Begin Stehend while holding a Stange at arm\'s length in front of you. You can stand on a raised platform to increase the range of motion. Begin by flexing the knees slightly, and then flex at the Hüfte, moving your butt Rücken as far as possible, lowering the torso as far as flexibility allows. The...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Snatch',
    description: 'Place your feet at a shoulder width stance with the barbell resting right above the connection between the toes and the rest of the foot. With a palms facing down grip, bend at the knees and keeping the back flat grab the bar using a wider than shoulder width grip. Bring the hips down and make sure that your body drops as if you were going to sit on a chair. This will be your starting position....',
    nameDe: 'Reißen',
    descriptionDe: 'Place your feet at a Schulter width stance with the Langhantel resting right above the connection between the toes and the rest of the foot. With a palms facing down grip, bend at the knees and keeping the Rücken Flachbank grab the Stange using a wider than Schulter width grip. Bring the Hüften...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Snatch Balance',
    description: 'Begin with the feet in the pulling position, the bar racked across the back of the shoulders, and the hands placed in a wide snatch grip. Pop the bar with an abrupt dip and drive of the knees, and aggressively drive under the bar, transitioning the feet into the receiving position. Receive the bar locked out overhead near the bottom of the squat. The torso should remain vertical, lowering the...',
    nameDe: 'Reißen Balance',
    descriptionDe: 'Begin with the feet in the pulling position, the Stange racked across the Rücken of the Schultern, and the hands placed in a wide Reißen grip. Pop the Stange with an abrupt Dip and drive of the knees, and aggressively drive under the Stange, transitioning the feet into the receiving position....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Snatch Deadlift',
    description: 'The snatch deadlift strengthens the first pull of the snatch. Begin with a wide snatch grip with the barbell placed on the platform. The feet should be directly under the hips, with the feet turned out. Squat down to the bar, keeping the back in absolute extension with the head facing forward. Initiate the movement by driving through the heels, raising the hips. The back angle should remain the...',
    nameDe: 'Reißen-Kreuzheben',
    descriptionDe: 'The Reißen Kreuzheben strengthens the first pull of the Reißen. Begin with a wide Reißen grip with the Langhantel placed on the platform. The feet should be directly under the Hüften, with the feet turned out. Kniebeuge down to the Stange, keeping the Rücken in absolute Streckung with the Kopf...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Snatch Shrug',
    description: 'Begin with a wide grip, with the bar hanging at the mid thigh position. You can use a hook or overhand grip. Your back should be straight and inclined slightly forward. Shrug your shoulders towards your ears. While this exercise can usually by loaded with heavier weight than a snatch, avoid overloading to the point that the execution slows down.',
    nameDe: 'Reißen-Schulterziehen',
    descriptionDe: 'Begin with a Weiter Griff, with the Stange hanging at the mid Oberschenkel position. You can use a hook or Obergriff grip. Your Rücken should be straight and inclined slightly forward. Schulterziehen your Schultern towards your ears. While this exercise can usually by loaded with heavier weight...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Snatch from Blocks',
    description: 'Begin with a loaded barbell on boxes or stands of the desired height. A wide grip should be taken on the bar. The feet should be directly below the hips, with the feet turned out as needed. Lower the hips, with the chest up and the head looking forward. The shoulders should be just in front of the bar, with the elbows pointed out. This will be the starting position. Begin the first pull by...',
    nameDe: 'Reißen from Blocks',
    descriptionDe: 'Begin with a loaded Langhantel on boxes or stands of the desired height. A Weiter Griff should be taken on the Stange. The feet should be directly below the Hüften, with the feet turned out as needed. Unterer the Hüften, with the Brust up and the Kopf looking forward. The Schultern should be just...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Split Clean',
    description: 'With a barbell on the floor close to the shins, take an overhand grip just outside the legs. Lower your hips with the weight focused on the heels, back straight, head facing forward, chest up, with your shoulders just in front of the bar. This will be your starting position. Begin the first pull by driving through the heels, extending your knees. Your back angle should stay the same, and your...',
    nameDe: 'Split Stoßen',
    descriptionDe: 'With a Langhantel on the Boden close to the shins, take an Obergriff grip just outside the legs. Unterer your Hüften with the weight focused on the heels, Rücken straight, Kopf facing forward, Brust up, with your Schultern just in front of the Stange. This will be your starting position. Begin the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Split Jerk',
    description: 'Standing with the weight racked on the front of the shoulders, begin with the dip. With your feet directly under your hips, flex the knees without moving the hips backward. Go down only slightly, and reverse direction as powerfully as possible. Drive through the heels create as much speed and force as possible, and be sure to move your head out of the way as the bar leaves the shoulders. At this...',
    nameDe: 'Split Ausstoßen',
    descriptionDe: 'Stehend with the weight racked on the front of the Schultern, begin with the Dip. With your feet directly under your Hüften, flex the knees without moving the Hüften backward. Go down only slightly, and Umgekehrt direction as powerfully as possible. Drive through the heels create as much speed and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Split Snatch',
    description: 'Begin with a loaded barbell on the floor. The bar should be close to or touching the shins, and a wide grip should be taken on the bar. The feet should be directly below the hips, with the feet turned out as needed. Lower the hips, with the chest up and the head looking forward. The shoulders should be just in front of the bar. This will be the starting position. Begin the first pull by driving...',
    nameDe: 'Split Reißen',
    descriptionDe: 'Begin with a loaded Langhantel on the Boden. The Stange should be close to or touching the shins, and a Weiter Griff should be taken on the Stange. The feet should be directly below the Hüften, with the feet turned out as needed. Unterer the Hüften, with the Brust up and the Kopf looking forward....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Wide Stance Stiff Legs',
    description: 'Begin with a barbell loaded on the floor. Adopt a wide stance, and then bend at the hips to grab the bar. Your hips should be as far back as possible, and your legs nearly straight. Keep your back straight, and your head and chest up. This will be your starting position. Begin the movement be engaging the hips, driving them forward as you allow the arms to hang straight. Continue until you are...',
    nameDe: 'Wide Stance Stiff Legs',
    descriptionDe: 'Begin with a Langhantel loaded on the Boden. Adopt a wide stance, and then bend at the Hüften to grab the Stange. Your Hüften should be as far Rücken as possible, and your legs nearly straight. Keep your Rücken straight, and your Kopf and Brust up. This will be your starting position. Begin the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  // ── STRONGMAN (21) ────────────────────────────────────────────────────────────

  Exercise(
    name: 'Atlas Stone Trainer',
    description: 'This trainer is effective for developing Atlas Stone strength for those who don\'t have access to stones, and are typically made from bar ends or heavy pipe. Begin by loading the desired weight onto the bar. Straddle the weight, wrapping your arms around the implement, bending at the hips. Begin by pulling the weight up past the knees, extending through the hips. As the weight clears the knees, it...',
    nameDe: 'Atlas-Stein-Trainer',
    descriptionDe: 'This trainer is effective for developing Atlas-Stein strength for those who don\'t have access to stones, and are typically made from Stange ends or heavy pipe. Begin by loading the desired weight onto the Stange. Straddle the weight, wrapping your arms around the implement, bending at the Hüften....',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Atlas Stones',
    description: 'Begin with the atlas stone between your feet. Bend at the hips to wrap your arms vertically around the Atlas Stone, attempting to get your fingers underneath the stone. Many stones will have a small flat portion on the bottom, which will make the stone easier to hold. Pulling the stone into your torso, drive through the back half of your feet to pull the stone from the ground. As the stone passes...',
    nameDe: 'Atlas-Steine',
    descriptionDe: 'Begin with the Atlas-Stein between your feet. Bend at the Hüften to wrap your arms vertically around the Atlas-Stein, attempting to get your fingers underneath the stone. Many stones will have a small Flachbank portion on the bottom, which will make the stone easier to hold. Pulling the stone into...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Axle Deadlift',
    description: 'Approach the bar so that it is centered over your feet. You feet should be about hip width apart. Bend at the hip to grip the bar at shoulder width, allowing your shoulder blades to protract. Typically, you would use an over/under grip. With your feet and your grip set, take a big breath and then lower your hips and flex the knees until your shins contact the bar. Look forward with your head,...',
    nameDe: 'Achse Kreuzheben',
    descriptionDe: 'Approach the Stange so that it is centered over your feet. You feet should be about Hüfte width apart. Bend at the Hüfte to grip the Stange at Schulter width, allowing your Schulter blades to protract. Typically, you would use an over/under grip. With your feet and your grip set, take a big breath...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Backward Drag',
    description: 'Load a sled with the desired weight, attaching a rope or straps to the sled that you can hold onto. Begin the exercise by moving backwards for a given distance. Leaning back, extend through the legs for short steps to move as quickly as possible.',
    nameDe: 'Rückwärtiges Schlittenziehen',
    descriptionDe: 'Load a Schlitten with the desired weight, attaching a Seil or straps to the Schlitten that you can hold onto. Begin the exercise by moving backwards for a given distance. Leaning Rücken, extend through the legs for short steps to move as quickly as possible.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Bear Crawl Sled Drags',
    description: 'Wearing either a harness or a loose weight belt, attach the chain to the back so that you will be facing away from the sled. Bend down so that your hands are on the ground. Your back should be flat and knees bent. This is your starting position. Begin by driving with legs, alternating left and right. Use your hands to maintain balance and to help pull. Try to keep your back flat as you move over...',
    nameDe: 'Bärengang Schlitten Drags',
    descriptionDe: 'Wearing either a harness or a loose weight belt, attach the chain to the Rücken so that you will be facing away from the Schlitten. Bend down so that your hands are on the ground. Your Rücken should be Flachbank and knees bent. This is your starting position. Begin by driving with legs,...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Car Deadlift',
    description: 'This event apparatus typically has neutral grip handles, however some have a straight bar that you can approach like a normal deadlift. The apparatus can be loaded with a vehicle or other heavy objects such as tractor tires or kegs. Center yourself between the handles if you are a strong squatter, or back a couple inches if you are a strong deadlifter. You feet should be about hip width apart....',
    nameDe: 'Car Kreuzheben',
    descriptionDe: 'This event apparatus typically has Neutralgriff handles, however some have a straight Stange that you can approach like a normal Kreuzheben. The apparatus can be loaded with a vehicle or other heavy objects such as tractor tires or kegs. Center yourself between the handles if you are a strong...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Circus Bell',
    description: 'The circus bell is an oversized dumbbell with a thick handle. Begin with the dumbbell between your feet, and grip the handle with both hands. Clean the dumbbell by extending through your hips and knees to deliver the implement to the desired shoulder, letting go with the extra hand. Ensure that you get one of the dumbbell heads behind the shoulder to keep from being thrown off balance. To raise...',
    nameDe: 'Circus Bell',
    descriptionDe: 'The circus bell is an oversized Kurzhantel with a thick handle. Begin with the Kurzhantel between your feet, and grip the handle with both hands. Stoßen the Kurzhantel by extending through your Hüften and knees to deliver the implement to the desired Schulter, letting go with the extra hand. Ensure...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Conan\'s Wheel',
    description: 'With the weight loaded, take a zurcher hold on the end of the implement. Place the bar in the crook of the elbow and hold onto your wrist. Try to keep the weight off of the forearms. Begin by lifting the weight from the ground. Keep a tight, upright posture as you being to walk, taking short, fast steps. Look up and away as you turn in a circle. Do not hold your breath during the event. Continue...',
    nameDe: 'Conan\'s Wheel',
    descriptionDe: 'With the weight loaded, take a zurcher hold on the end of the implement. Place the Stange in the crook of the elbow and hold onto your Handgelenk. Try to keep the weight off of the Unterarme. Begin by lifting the weight from the ground. Keep a tight, Aufrecht posture as you being to Gehen, taking...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Crucifix',
    description: 'In the crucifix, you statically hold weights out to the side for time. While the event can be practiced using dumbbells, it is best to practice with one of the various implements used, such as axes and hammers, as it feels different. Begin standing, and raise your arms out to the side holding the implements. Your arms should be parallel to the ground. In competition, judges or sensors are used to...',
    nameDe: 'Crucifix',
    descriptionDe: 'In the crucifix, you statically hold weights out to the side for time. While the event can be practiced using Kurzhanteln, it is best to practice with one of the various implements used, such as axes and hammers, as it feels different. Begin Stehend, and Heben your arms out to the side holding the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Farmer\'s Walk',
    description: 'There are various implements that can be used for the farmers walk. These can also be performed with heavy dumbbells or short bars if these implements aren\'t available. Begin by standing between the implements. After gripping the handles, lift them up by driving through your heels, keeping your back straight and your head up. Walk taking short, quick steps, and don\'t forget to breathe. Move for a...',
    nameDe: 'Farmergehen',
    descriptionDe: 'There are various implements that can be used for the farmers Gehen. These can also be performed with heavy Kurzhanteln or short bars if these implements aren\'t available. Begin by Stehend between the implements. After gripping the handles, lift them up by driving through your heels, keeping your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Forward Drag with Press',
    description: 'Attach a dual handled chain or rope attachment to the sled. You should be facing away from the sled, holding a handle in each hand. Begin the movement by moving forward for one step. Leaning forward, extend through the legs and hips to move, pausing with each step to extend through the elbows, pressing your hands forward. Step forward until you return to the start position prepared to press.',
    nameDe: 'Forward Ziehen with Drücken',
    descriptionDe: 'Attach a dual handled chain or Seil attachment to the Schlitten. You should be facing away from the Schlitten, holding a handle in each hand. Begin the movement by moving forward for one Stufe. Leaning forward, extend through the legs and Hüften to move, pausing with each Stufe to extend through...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Keg Load',
    description: 'To load kegs, place the desired number a distance from the loading platform, typically 30-50 feet. Begin by grabbing the close handle of the first keg, tilting it onto its side to grab the opposite edge of the bottom of the keg. Lift the keg up to your chest. The higher you can place the keg, the faster you should be able to move to the platform. Shouldering is usually not allowed. Be sure to...',
    nameDe: 'Keg Load',
    descriptionDe: 'To load kegs, place the desired number a distance from the loading platform, typically 30-50 feet. Begin by grabbing the close handle of the first keg, tilting it onto its side to grab the opposite edge of the bottom of the keg. Lift the keg up to your Brust. The higher you can place the keg, the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Log Lift',
    description: 'Begin standing with the log in front of you. Grasp the handles, and begin to clean the log. As you are bent over to start the clean, attempt to get the log as high as possible, pulling it into your chest. Extend through the hips and knees to bring it up to complete the clean. Push your head back and look up, creating a shelf on your chest to rest the log. Begin the press by dipping, flexing...',
    nameDe: 'Stamm Lift',
    descriptionDe: 'Begin Stehend with the Stamm in front of you. Grasp the handles, and begin to Stoßen the Stamm. As you are Vorgebeugt to start the Stoßen, attempt to get the Stamm as high as possible, pulling it into your Brust. Extend through the Hüften and knees to bring it up to complete the Stoßen. Push your...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Power Stairs',
    description: 'In the power stairs, implements are moved up a staircase. For training purposes, these can be performed with a tire or box. Begin by taking the implement with both hands. Set your feet wide, with your head and chest up. Drive through the ground with your heels, extending your knees and hips to raise the weight from the ground. As you lean back, attempt to swing the weight onto the stairs, which...',
    nameDe: 'Power Stairs',
    descriptionDe: 'In the power stairs, implements are moved up a staircase. For training purposes, these can be performed with a Reifen or Box. Begin by taking the implement with both hands. Set your feet wide, with your Kopf and Brust up. Drive through the ground with your heels, extending your knees and Hüften to...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Rickshaw Carry',
    description: 'Position the frame at the starting point, and load with the appropriate weight. Standing in the center of the frame, begin by gripping the handles and driving through your heels to lift the frame. Ensure your chest and head are up and your back is straight. Immediately begin walking briskly with quick, controlled steps. Keep your chest up and head forward, and make sure you continue breathing....',
    nameDe: 'Rickshaw Tragen',
    descriptionDe: 'Position the frame at the starting point, and load with the appropriate weight. Stehend in the center of the frame, begin by gripping the handles and driving through your heels to lift the frame. Ensure your Brust and Kopf are up and your Rücken is straight. Immediately begin walking briskly with...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Rickshaw Deadlift',
    description: 'Load the frame with the desired weight. Center yourself between the handles. You feet should be about hip width apart. Bend at the hips to grip the handles, allowing your shoulder blades to protract. With your feet and your grip set, take a big breath and then lower your hips and flex the knees. Look forward with your head, keep your chest up and your back arched, and begin driving through the...',
    nameDe: 'Rickshaw Kreuzheben',
    descriptionDe: 'Load the frame with the desired weight. Center yourself between the handles. You feet should be about Hüfte width apart. Bend at the Hüften to grip the handles, allowing your Schulter blades to protract. With your feet and your grip set, take a big breath and then Unterer your Hüften and flex the...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Sandbag Load',
    description: 'To load sandbags or other objects, begin with the implements placed a distance from the loading platform, typically 50 feet. Begin by lifting the sandbag. Sandbags are extremely awkward, and the manner of lifting them can vary depending on the particular sandbag used. Reach as far around it as possible, extending through the hips and knees to pull it up high. Shouldering is usually not allowed....',
    nameDe: 'Sandsack Load',
    descriptionDe: 'To load sandbags or other objects, begin with the implements placed a distance from the loading platform, typically 50 feet. Begin by lifting the Sandsack. Sandbags are extremely awkward, and the manner of lifting them can vary depending on the particular Sandsack used. Reach as far around it as...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Sled Drag - Harness',
    description: 'To begin, load the sled with the desired weight and attach the pulling strap. You can pull with handles, use a harness, or attach the pulling strap to a weight belt. Whether pulling forwards or backwards, lean in the direction of travel and progress by extending through the hips and knees.',
    nameDe: 'Schlitten Ziehen - Harness',
    descriptionDe: 'To begin, load the Schlitten with the desired weight and attach the pulling strap. You can pull with handles, use a harness, or attach the pulling strap to a weight belt. Whether pulling forwards or backwards, lean in the direction of travel and progress by extending through the Hüften and knees.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Sled Push',
    description: 'Load your pushing sled with the desired weight. Take an athletic posture, leaning into the sled with your arms fully extended, grasping the handles. Push the sled as fast as possible, focusing on extending your hips and knees to strengthen your posterior chain.',
    nameDe: 'Schlitten Push',
    descriptionDe: 'Load your pushing Schlitten with the desired weight. Take an athletic posture, leaning into the Schlitten with your arms fully extended, grasping the handles. Push the Schlitten as fast as possible, focusing on extending your Hüften and knees to strengthen your Hinterer chain.',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Tire Flip',
    description: 'Begin by gripping the bottom of the tire on the tread, and position your feet back a bit. Your chest should be driving into the tire. To lift the tire, extend through the hips, knees, and ankles, driving into the tire and up. As the tire reaches a 45 degree angle, step forward and drive a knee into the tire. As you do so adjust your grip to the upper portion of the tire and push it forward as...',
    nameDe: 'Reifenumwerfen',
    descriptionDe: 'Begin by gripping the bottom of the Reifen on the tread, and position your feet Rücken a bit. Your Brust should be driving into the Reifen. To lift the Reifen, extend through the Hüften, knees, and ankles, driving into the Reifen and up. As the Reifen reaches a 45 degree angle, Stufe forward and...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Yoke Walk',
    description: 'The yoke is usually done with a yoke apparatus, but is sometimes seen with refrigerators or other heavy objects. Begin by racking the apparatus across the back of the shoulders. With your head looking forward and back arched, lift the yoke by driving through the heels. Begin walking as quickly as possible using short, quick steps. You may hold the side posts of the yoke to help steady it and hold...',
    nameDe: 'Yoke Gehen',
    descriptionDe: 'The yoke is usually done with a yoke apparatus, but is sometimes seen with refrigerators or other heavy objects. Begin by racking the apparatus across the Rücken of the Schultern. With your Kopf looking forward and Rücken arched, lift the yoke by driving through the heels. Begin walking as quickly...',
    type: ExerciseType.strength,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  // ── PLYOMETRICS (61) ────────────────────────────────────────────────────────────

  Exercise(
    name: 'Alternate Leg Diagonal Bound',
    description: 'Assume a comfortable stance with one foot slightly in front of the other. Begin by pushing off with the front leg, driving the opposite knee forward and as high as possible before landing. Attempt to cover as much distance to each side with each bound. It may help to use a line on the ground to guage distance from side to side. Repeat the sequence with the other leg.',
    nameDe: 'Alternierend Leg Diagonal Sprung',
    descriptionDe: 'Assume a comfortable stance with one foot slightly in front of the other. Begin by pushing off with the front leg, driving the opposite Knie forward and as high as possible before landing. Attempt to cover as much distance to each side with each Sprung. It may help to use a line on the ground to...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Backward Medicine Ball Throw',
    description: 'This exercise is best done with a partner. If you lack a partner, the ball can be thrown and retrieved or thrown against a wall. Begin standing a few meters in front of your partner, both facing the same direction. Begin holding the ball between your legs. Squat down and then forcefully reverse direction, coming to full extension and you toss the ball over your head to your partner. Your partner...',
    nameDe: 'Rückwärtiger Medizinballwurf',
    descriptionDe: 'This exercise is best done with a partner. If you lack a partner, the Ball can be thrown and retrieved or thrown against a Wand. Begin Stehend a few meters in front of your partner, both facing the same direction. Begin holding the Ball between your legs. Kniebeuge down and then forcefully...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Bench Jump',
    description: 'Begin with a box or bench 1-2 feet in front of you. Stand with your feet shoulder width apart. This will be your starting position. Perform a short squat in preparation for the jump; swing your arms behind you. Rebound out of this position, extending through the hips, knees, and ankles to jump as high as possible. Swing your arms forward and up. Jump over the bench, landing with the knees bent,...',
    nameDe: 'Bank Sprung',
    descriptionDe: 'Begin with a Box or Bank 1-2 feet in front of you. Stand with your feet Schulter width apart. This will be your starting position. Perform a short Kniebeuge in preparation for the Sprung; Schwingen your arms behind you. Rebound out of this position, extending through the Hüften, knees, and ankles...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Bench Sprint',
    description: 'Stand on the ground with one foot resting on a bench or box with your heel close to the edge. Push off with your foot on top of the bench, extending through the hip and knee. Land with the opposite foot on top of the box, returning your other foot back to the start position. Continue alternating from one foot to another to complete the set.',
    nameDe: 'Bank Sprint',
    descriptionDe: 'Stand on the ground with one foot resting on a Bank or Box with your heel close to the edge. Push off with your foot on top of the Bank, extending through the Hüfte and Knie. Land with the opposite foot on top of the Box, returning your other foot Rücken to the start position. Continue Alternierend...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Box Jump (Multiple Response)',
    description: 'Assume a relaxed stance facing the box or platform approximately an arm\'s length away. Arms should be down at the sides and legs slightly bent. Using the arms to aid in the initial burst, jump upward and forward, landing with feet simultaneously on top of the box or platform. Immediately drop or jump back down to the original starting place; then repeat the sequence.',
    nameDe: 'Box-Sprung (Multiple Response)',
    descriptionDe: 'Assume a relaxed stance facing the Box or platform approximately an arm\'s length away. Arms should be down at the sides and legs slightly bent. Using the arms to aid in the initial burst, Sprung upward and forward, landing with feet simultaneously on top of the Box or platform. Immediately drop or...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Box Skip',
    description: 'You will need several boxes lined up about 8 feet apart. Begin facing the first box with one leg slightly behind the other. Drive off the back leg, attempting to gain as much height with the hips as possible. Immediately upon landing on the box, drive the other leg forward and upward to gain height and distance, leaping from the box. Land between the first two boxes with the same leg that landed...',
    nameDe: 'Box-Sprung',
    descriptionDe: 'You will need several boxes lined up about 8 feet apart. Begin facing the first Box with one leg slightly behind the other. Drive off the Rücken leg, attempting to gain as much height with the Hüften as possible. Immediately upon landing on the Box, drive the other leg forward and upward to gain...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Carioca Quick Step',
    description: 'Begin with your feet a few inches apart and your left arm up in a relaxed, athletic position. With your right foot, quick step behind and pull the knee up. Fire your arms back up when you pull the right knee, being sure that your knee goes straight up and down. Avoid turning your feet as you move and continue to look forward as you move to the side.',
    nameDe: 'Carioca Quick Stufe',
    descriptionDe: 'Begin with your feet a few inches apart and your left arm up in a relaxed, athletic position. With your right foot, quick Stufe behind and pull the Knie up. Fire your arms Rücken up when you pull the right Knie, being sure that your Knie goes straight up and down. Avoid turning your feet as you...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Catch and Overhead Throw',
    description: 'Begin standing while facing a wall or a partner. Using both hands, position the ball behind your head, stretching as much as possible, and forcefully throw the ball forward. Ensure that you follow your throw through, being prepared to receive your rebound from your throw. If you are throwing against the wall, make sure that you stand close enough to the wall to receive the rebound, and aim a...',
    nameDe: 'Catch and Überkopf Throw',
    descriptionDe: 'Begin Stehend while facing a Wand or a partner. Using both hands, position the Ball behind your Kopf, stretching as much as possible, and forcefully throw the Ball forward. Ensure that you follow your throw through, being prepared to receive your rebound from your throw. If you are throwing against...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Chest Push from 3 point stance',
    description: 'Begin in a three point stance, squatted down with your back flat and one hand on the ground. Place the medicine ball directly in front of you. To begin, take your first step as you pull the ball to your chest, positioning both hands to prepare for the throw. As you execute the second step, explosively release the ball forward as hard as possible.',
    nameDe: 'Brust Push from 3 point stance',
    descriptionDe: 'Begin in a three point stance, squatted down with your Rücken Flachbank and one hand on the ground. Place the Medizinball directly in front of you. To begin, take your first Stufe as you pull the Ball to your Brust, positioning both hands to prepare for the throw. As you execute the second Stufe,...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Chest Push (multiple response)',
    description: 'Begin in a kneeling position facing a wall or utilize a partner. Hold the ball with both hands tight into the chest. Execute the pass by exploding forward and outward with the hips while pushing the ball as hard as possible. Follow through by falling forward, catching yourself with your hands. Immediately return to an upright position. Repeat for the desired number of repetitions.',
    nameDe: 'Brust Push (multiple response)',
    descriptionDe: 'Begin in a Kniend position facing a Wand or utilize a partner. Hold the Ball with both hands tight into the Brust. Execute the pass by exploding forward and outward with the Hüften while pushing the Ball as hard as possible. Follow through by falling forward, catching yourself with your hands....',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Chest Push (single response)',
    description: 'Begin in a kneeling position holding the medicine ball with both hands tightly into the chest. Execute the pass by exploding forward and outward with the hips while pushing the ball as far as possible. Follow through by falling forward, catching yourself with your hands.',
    nameDe: 'Brust Push (single response)',
    descriptionDe: 'Begin in a Kniend position holding the Medizinball with both hands tightly into the Brust. Execute the pass by exploding forward and outward with the Hüften while pushing the Ball as far as possible. Follow through by falling forward, catching yourself with your hands.',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Chest Push with Run Release',
    description: 'Begin in an athletic stance with the knees bent, hips back, and back flat. Hold the medicine ball near your legs. This will be your starting position. While taking your first step draw the medicine ball into your chest. As you take the second step, explosively push the ball forward, immediately sprinting for 10 yards after the release. If you are really fast, you can catch your own pass!',
    nameDe: 'Brust Push with Laufen Release',
    descriptionDe: 'Begin in an athletic stance with the knees bent, Hüften Rücken, and Rücken Flachbank. Hold the Medizinball near your legs. This will be your starting position. While taking your first Stufe draw the Medizinball into your Brust. As you take the second Stufe, explosively push the Ball forward,...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Depth Jump Leap',
    description: 'For this drill you will need two boxes or benches, one 12 to 16 inches high and the other 22 to 26 inches high. Stand on one of the two boxes with arms at the sides; feet should be together and slightly off the edge as in the depth jump. Place the other box approximately two or three feet in front of and facing the performer. Begin by dropping off the initial box, landing and simultaneously...',
    nameDe: 'Tiefsprung Leap',
    descriptionDe: 'For this drill you will need two boxes or benches, one 12 to 16 inches high and the other 22 to 26 inches high. Stand on one of the two boxes with arms at the sides; feet should be together and slightly off the edge as in the Tiefsprung. Place the other Box approximately two or three feet in front...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Double Leg Butt Kick',
    description: 'Begin standing with your knees slightly bent. Quickly squat a short distance, flexing the hips and knees, and immediately extend to jump for maximum vertical height. As you go up, tuck your heels by flexing the knees, attempting to touch the buttocks. Finish the motion by landing with the knees only partially bent, using your legs to absorb the impact.',
    nameDe: 'Doppelt Leg Butt Kick',
    descriptionDe: 'Begin Stehend with your knees slightly bent. Quickly Kniebeuge a short distance, flexing the Hüften and knees, and immediately extend to Sprung for maximum Vertikal height. As you go up, tuck your heels by flexing the knees, attempting to touch the Gesäß. Finish the motion by landing with the knees...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Drop Push',
    description: 'Position low boxes or other platforms 2-3 feet apart. Move to a pushup position between them, supporting yourself by placing your hands on the boxes. With good posture, drop from the platforms by pressing up and moving your hands to shoulder width, cushioning your landing by absorbing the impact through the arm.',
    nameDe: 'Drop Push',
    descriptionDe: 'Position low boxes or other platforms 2-3 feet apart. Move to a Liegestütz position between them, supporting yourself by placing your hands on the boxes. With good posture, drop from the platforms by pressing up and moving your hands to Schulter width, cushioning your landing by absorbing the...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Dumbbell Seated Box Jump',
    description: 'Position a box a couple feet to the side of a bench. Hold a dumbbell to your chest with both hands and seat yourself on the bench facing the box. This will be your starting position. Plant your feet firmly on the ground as you lean forward, extending through the hips and knees to jump up and forward. Land on the box with both feet, absorbing the impact by allowing the hips and knees to bend. Step...',
    nameDe: 'Kurzhantel-Box-Sprung sitzend',
    descriptionDe: 'Position a Box a couple feet to the side of a Bank. Hold a Kurzhantel to your Brust with both hands and seat yourself on the Bank facing the Box. This will be your starting position. Plant your feet firmly on the ground as you lean forward, extending through the Hüften and knees to Sprung up and...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Fast Skipping',
    description: 'Start in a relaxed position with one leg slightly forward. This will be your starting position. Skip by executing a step-hop pattern of right-right-step to left-left-step, and so on, alternating back and forth. Perform fast skips by maintaining close contact with the ground and reduce air time, moving as quickly as possible.',
    nameDe: 'Fast Skipping',
    descriptionDe: 'Start in a relaxed position with one leg slightly forward. This will be your starting position. Seilspringen by executing a Stufe-Hüpfen pattern of right-right-Stufe to left-left-Stufe, and so on, Alternierend Rücken and forth. Perform fast skips by maintaining close contact with the ground and...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Front Box Jump',
    description: 'Begin with a box of an appropriate height 1-2 feet in front of you. Stand with your feet should width apart. This will be your starting position. Perform a short squat in preparation for jumping, swinging your arms behind you. Rebound out of this position, extending through the hips, knees, and ankles to jump as high as possible. Swing your arms forward and up. Land on the box with the knees...',
    nameDe: 'Vorderer Box-Sprung',
    descriptionDe: 'Begin with a Box of an appropriate height 1-2 feet in front of you. Stand with your feet should width apart. This will be your starting position. Perform a short Kniebeuge in preparation for jumping, swinging your arms behind you. Rebound out of this position, extending through the Hüften, knees,...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Front Cone Hops (or hurdle hops)',
    description: 'Set up a row of cones or other small barriers, placing them a few feet apart. Stand in front of the first cone with your feet shoulder width apart. This will be your starting position. Begin by jumping with both feet over the first cone, swinging both arms as you jump. Absorb the impact of landing by bending the knees, rebounding out of the first leap by jumping over the next cone. Continue until...',
    nameDe: 'Front Cone Hops (or hurdle hops)',
    descriptionDe: 'Set up a Rudern of cones or other small barriers, placing them a few feet apart. Stand in front of the first cone with your feet Schulter width apart. This will be your starting position. Begin by jumping with both feet over the first cone, swinging both arms as you Sprung. Absorb the impact of...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Heavy Bag Thrust',
    description: 'Utilize a heavy bag for this exercise. Assume an upright stance next to the bag, with your feet staggered, fairly wide apart. Place your hand on the bag at about chest height. This will be your starting position. Begin by twisting at the waist, pushing the bag forward as hard as possible. Perform this move quickly, pushing the bag away from your body. Receive the bag as it swings back by...',
    nameDe: 'Heavy Bag Thrust',
    descriptionDe: 'Utilize a heavy bag for this exercise. Assume an Aufrecht stance next to the bag, with your feet staggered, fairly wide apart. Place your hand on the bag at about Brust height. This will be your starting position. Begin by twisting at the waist, pushing the bag forward as hard as possible. Perform...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Hurdle Hops',
    description: 'Set up a row of hurdles or other small barriers, placing them a few feet apart. Stand in front of the first hurdle with your feet shoulder width apart. This will be your starting position. Begin by jumping with both feet over the first hurdle, swinging both arms as you jump. Absorb the impact of landing by bending the knees, rebounding out of the first leap by jumping over the next hurdle....',
    nameDe: 'Hurdle Hops',
    descriptionDe: 'Set up a Rudern of hurdles or other small barriers, placing them a few feet apart. Stand in front of the first hurdle with your feet Schulter width apart. This will be your starting position. Begin by jumping with both feet over the first hurdle, swinging both arms as you Sprung. Absorb the impact...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Incline Push-Up Depth Jump',
    description: 'For this drill you will need a box about 12 inches high, and two thick mats or aerobics steps. Place the steps just outside of your shoulders, and place your feet on top of the box so that you are in an incline pushup position, your hands just inside the steps. This will be your starting position. Begin by bending at the elbows to lower your body, quickly reversing position to push your body off...',
    nameDe: 'Schrägbank Liegestütz Tiefsprung',
    descriptionDe: 'For this drill you will need a Box about 12 inches high, and two thick mats or aerobics steps. Place the steps just outside of your Schultern, and place your feet on top of the Box so that you are in an Schrägbank Liegestütz position, your hands just inside the steps. This will be your starting...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Isometric Chest Squeezes',
    description: 'While either seating or standing, bend your arms at a 90-degree angle and place the palms of your hands together in front of your chest. Tip: Your hands should be open with the palms together and fingers facing forward (perpendicular to your torso). Push both hands against each other as you contract your chest. Start with slow tension and increase slowly. Keep breathing normally as you execute...',
    nameDe: 'Isometrisch Brust Squeezes',
    descriptionDe: 'While either seating or Stehend, bend your arms at a 90-degree angle and place the palms of your hands together in front of your Brust. Tip: Your hands should be open with the palms together and fingers facing forward (perpendicular to your torso). Push both hands against each other as you contract...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Knee Tuck Jump',
    description: 'Begin in a comfortable standing position with your knees slightly bent. Hold your hands in front of you, palms down with your fingertips together at chest height. This will be your starting position. Rapidly dip down into a quarter squat and immediately explode upward. Drive the knees towards the chest, attempting to touch them to the palms of the hands. Jump as high as you can, raising your...',
    nameDe: 'Knie Tuck Sprung',
    descriptionDe: 'Begin in a comfortable Stehend position with your knees slightly bent. Hold your hands in front of you, palms down with your fingertips together at Brust height. This will be your starting position. Rapidly Dip down into a quarter Kniebeuge and immediately explode upward. Drive the knees towards...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kneeling Arm Drill',
    description: 'This drill helps increase arm efficiency during the run. Begin kneeling, left foot in front, right knee down. Apply pressure through the front heel to keep your glutes and hamstrings activated. Begin by blocking the arms in long, pendulum like swings. Close the arm angle, blocking with the arms as you would when jogging, progressing to a run and finally a sprint. As soon as your hands pass the...',
    nameDe: 'Kniend Arm Drill',
    descriptionDe: 'This drill helps increase arm efficiency during the Laufen. Begin Kniend, left foot in front, right Knie down. Apply pressure through the front heel to keep your Gesäß and Oberschenkelrückseite activated. Begin by blocking the arms in long, Pendel like swings. Close the arm angle, blocking with the...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Lateral Bound',
    description: 'Assume a half squat position facing 90 degrees from your direction of travel. This will be your starting position. Allow your lead leg to do a countermovement inward as you shift your weight to the outside leg. Immediately push off and extend, attempting to bound to the side as far as possible. Upon landing, immediately push off in the opposite direction, returning to your original start...',
    nameDe: 'Seitlich Sprung',
    descriptionDe: 'Assume a Halb Kniebeuge position facing 90 degrees from your direction of travel. This will be your starting position. Allow your lead leg to do a countermovement inward as you shift your weight to the outside leg. Immediately push off and extend, attempting to Sprung to the side as far as...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lateral Box Jump',
    description: 'Assume a comfortable standing position, with a short box positioned next to you. This will be your starting position. Quickly dip into a quarter squat to initiate the stretch reflex, and immediately reverse direction to jump up and to the side. Bring your knees high enough to ensure your feet have good clearance over the box. Land on the center of the box, using your legs to absorb the impact....',
    nameDe: 'Seitlich Box-Sprung',
    descriptionDe: 'Assume a comfortable Stehend position, with a short Box positioned next to you. This will be your starting position. Quickly Dip into a quarter Kniebeuge to initiate the Dehnung reflex, and immediately Umgekehrt direction to Sprung up and to the side. Bring your knees high enough to ensure your...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lateral Cone Hops',
    description: 'Position a number of cones in a row several feet apart. Stand next to the end of the cones, facing 90 degrees to the direction of travel. This will be your starting position. Begin the jump by dipping with the knees to initiate a stretch reflex, and immediately reverse direction to push off the ground, jumping up and sideways over the cone. Use your legs to absorb impact upon landing, and rebound...',
    nameDe: 'Seitlich Cone Hops',
    descriptionDe: 'Position a number of cones in a Rudern several feet apart. Stand next to the end of the cones, facing 90 degrees to the direction of travel. This will be your starting position. Begin the Sprung by dipping with the knees to initiate a Dehnung reflex, and immediately Umgekehrt direction to push off...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Linear 3-Part Start Technique',
    description: 'This drill helps you accelerate as quickly as possible into a sprint from a dead stop. It helps to use a line to start from. Begin with two feet on the line. Place your left foot with the toe next to your right ankle. Place your right foot 4-6 inches behind the left. Place your right hand onto the line, and thing bring your nose close to your left knee. Squat down as you lean foward, your head...',
    nameDe: 'Linear 3-Part Start Technique',
    descriptionDe: 'This drill helps you accelerate as quickly as possible into a Sprint from a dead stop. It helps to use a line to start from. Begin with two feet on the line. Place your left foot with the toe next to your right Knöchel. Place your right foot 4-6 inches behind the left. Place your right hand onto...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Linear Acceleration Wall Drill',
    description: 'Lean at around 45 degrees against a wall. Your feet should be together, glutes contracted. Begin by lifting your right knee quickly, pausing, and then driving it straight down into the ground. Switch legs, raising the opposite knee, and then attacking the ground straight down. Repeat once more with your right leg, and as soon as the right foot strikes the ground hammer them out rapidly,...',
    nameDe: 'Linear Acceleration Wand Drill',
    descriptionDe: 'Lean at around 45 degrees against a Wand. Your feet should be together, Gesäß contracted. Begin by lifting your right Knie quickly, pausing, and then driving it straight down into the ground. Switch legs, raising the opposite Knie, and then attacking the ground straight down. Repeat once more with...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Linear Depth Jump',
    description: 'You will need two boxes or benches spaced a few feet away from each other. Begin by standing on one box facing towards the other platform. To initiate the movement, gently drop down to the ground between your platforms, allowing the knees and hips to flex. Reverse the motion by exploding, extending through the hips, knees, and ankles to jump onto the other platform. Land softly, asborbing the...',
    nameDe: 'Linear Tiefsprung',
    descriptionDe: 'You will need two boxes or benches spaced a few feet away from each other. Begin by Stehend on one Box facing towards the other platform. To initiate the movement, gently drop down to the ground between your platforms, allowing the knees and Hüften to flex. Umgekehrt the motion by exploding,...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Medicine Ball Chest Pass',
    description: 'You will need a partner for this exercise. Lacking one, this movement can be performed against a wall. Begin facing your partner holding the medicine ball at your torso with both hands. Pull the ball to your chest, and reverse the motion by extending through the elbows. For sports applications, you can take a step as you throw. Your partner should catch the ball, and throw it back to you. Receive...',
    nameDe: 'Medizinball-Brustpass',
    descriptionDe: 'You will need a partner for this exercise. Lacking one, this movement can be performed against a Wand. Begin facing your partner holding the Medizinball at your torso with both hands. Pull the Ball to your Brust, and Umgekehrt the motion by extending through the elbows. For sports applications, you...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Medicine Ball Full Twist',
    description: 'For this exercise you will need a medicine ball and a partner. Stand back to back with your partner, spaced 2-3 feet apart. This will be your starting position. Hold the ball in front of the trunk. Open the hips and turn the shoulders at the same time as your partner. For full rotation, you and your partner should twist in the same direction, i.e. counter-clockwise. Pass the ball to your partner,...',
    nameDe: 'Medizinball Komplett Twist',
    descriptionDe: 'For this exercise you will need a Medizinball and a partner. Stand Rücken to Rücken with your partner, spaced 2-3 feet apart. This will be your starting position. Hold the Ball in front of the trunk. Open the Hüften and turn the Schultern at the same time as your partner. For Komplett rotation, you...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Medicine Ball Scoop Throw',
    description: 'Assume a semisquat stance with a medicine ball in your hands. Your arms should hang so the ball is near your feet. Begin by thrusting the hips forward as you extend through the legs, jumping up. As you do, swing your arms up and over your head, keeping them extended, releasing the ball at the peak of your movement. The goal is to throw the ball the greatest distance behind you.',
    nameDe: 'Medizinball Scoop Throw',
    descriptionDe: 'Assume a semisquat stance with a Medizinball in your hands. Your arms should hang so the Ball is near your feet. Begin by thrusting the Hüften forward as you extend through the legs, jumping up. As you do, Schwingen your arms up and over your Kopf, keeping them extended, releasing the Ball at the...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Mountain Climbers',
    description: 'Begin in a pushup position, with your weight supported by your hands and toes. Flexing the knee and hip, bring one leg until the knee is approximately under the hip. This will be your starting position. Explosively reverse the positions of your legs, extending the bent leg until the leg is straight and supported by the toe, and bringing the other foot up with the hip and knee flexed. Repeat in an...',
    nameDe: 'Mountain Climbers',
    descriptionDe: 'Begin in a Liegestütz position, with your weight supported by your hands and toes. Flexing the Knie and Hüfte, bring one leg until the Knie is approximately under the Hüfte. This will be your starting position. Explosively Umgekehrt the positions of your legs, extending the bent leg until the leg...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Moving Claw Series',
    description: 'This move helps prepare your running form to help you excel at sprinting. As you run, be sure to flex the knee, aiming to kick your glutes as the hip extends. Reload the quad as the leg moves back forward, attacking the ground on the next step. Ensure that as you run, you block with the arms, punching through in a rapid 1-2 motion.',
    nameDe: 'Moving Claw Series',
    descriptionDe: 'This move helps prepare your running form to help you excel at sprinting. As you Laufen, be sure to flex the Knie, aiming to kick your Gesäß as the Hüfte extends. Reload the Quadrizeps as the leg moves Rücken forward, attacking the ground on the next Stufe. Ensure that as you Laufen, you block with...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Overhead Slam',
    description: 'Hold a medine ball with both hands and stand with your feet at shoulder width. This will be your starting position. Initiate the countermovement by raising the ball above your head and fully extending your body. Reverse the motion, slamming the ball into the ground directly in front of you as hard as you can. Receive the ball with both hands on the bounce and repeat the movement.',
    nameDe: 'Überkopf Slam',
    descriptionDe: 'Hold a medine Ball with both hands and stand with your feet at Schulter width. This will be your starting position. Initiate the countermovement by raising the Ball above your Kopf and fully extending your body. Umgekehrt the motion, slamming the Ball into the ground directly in front of you as...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Plyo Push-up',
    description: 'Move into a prone position on the floor, supporting your weight on your hands and toes. Your arms should be fully extended with the hands around shoulder width. Keep your body straight throughout the movement. This will be your starting position. Descend by flexing at the elbow, lowering your chest towards the ground. At the bottom, reverse the motion by pushing yourself up through elbow...',
    nameDe: 'Plyo Liegestütz',
    descriptionDe: 'Move into a Bauchlage position on the Boden, supporting your weight on your hands and toes. Your arms should be fully extended with the hands around Schulter width. Keep your body straight throughout the movement. This will be your starting position. Descend by flexing at the elbow, lowering your...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Quick Leap',
    description: 'You will need a box for this exerise. Begin facing the box standing 1-2 feet from its edge. By utilizing your hips, hop onto the box, landing on both legs. Ensure that you land with your legs bent and your feet flat. Immediately upon landing, fully extend through the entire body and swing your arms overhead to explode off of the box. Use your legs to absorb the impact of landing.',
    nameDe: 'Quick Leap',
    descriptionDe: 'You will need a Box for this exerise. Begin facing the Box Stehend 1-2 feet from its edge. By utilizing your Hüften, Hüpfen onto the Box, landing on both legs. Ensure that you land with your legs bent and your feet Flachbank. Immediately upon landing, fully extend through the entire body and...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Return Push from Stance',
    description: 'You will need a partner for this drill. Begin in an athletic 2 or 3 point stance. At the signal, move into a position to receive the pass from your partner. Catch the medicine ball with both hands and immediately throw it back to your partner. You can modify this drill by running different routes.',
    nameDe: 'Return Push from Stance',
    descriptionDe: 'You will need a partner for this drill. Begin in an athletic 2 or 3 point stance. At the signal, move into a position to receive the pass from your partner. Catch the Medizinball with both hands and immediately throw it Rücken to your partner. You can modify this drill by running different routes.',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Rocket Jump',
    description: 'Begin in a relaxed stance with your feet shoulder width apart and hold your arms close to the body. To initiate the move, squat down halfway and explode back up as high as possible. Fully extend your entire body, reaching overhead as far as possible. As you land, absorb your impact through the legs.',
    nameDe: 'Rocket Sprung',
    descriptionDe: 'Begin in a relaxed stance with your feet Schulter width apart and hold your arms close to the body. To initiate the move, Kniebeuge down halfway and explode Rücken up as high as possible. Fully extend your entire body, reaching Überkopf as far as possible. As you land, absorb your impact through...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Scissors Jump',
    description: 'Assume a lunge stance position with one foot forward with the knee bent, and the rear knee nearly touching the ground. Ensure that the front knee is over the midline of the foot. Extending through both legs, jump as high as possible, swinging your arms to gain lift. As you jump as high as you can, switch the position of your legs, moving your front leg to the back and the rear leg to the front....',
    nameDe: 'Scissors Sprung',
    descriptionDe: 'Assume a Ausfallschritt stance position with one foot forward with the Knie bent, and the rear Knie nearly touching the ground. Ensure that the front Knie is over the midline of the foot. Extending through both legs, Sprung as high as possible, swinging your arms to gain lift. As you Sprung as high...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Side Hop-Sprint',
    description: 'Stand to the side of a cone or hurdle. Begin this drill by hopping sideways over the obstacle, rebounding out of your landing to hop back to where you started. Hop for a prescribed number or repetitions as quickly as possible, and finish this drill by sprinting a short distance upon landing the last hop.',
    nameDe: 'Side Hüpfen-Sprint',
    descriptionDe: 'Stand to the side of a cone or hurdle. Begin this drill by hopping sideways over the obstacle, rebounding out of your landing to Hüpfen Rücken to where you started. Hüpfen for a prescribed number or repetitions as quickly as possible, and finish this drill by sprinting a short distance upon landing...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Side Standing Long Jump',
    description: 'Begin standing with your feet hip width apart in an athletic stance. Your head and chest should be up, knees and hips slightly bent. This will be your starting position. Leaning to your right, extend through your hips, knees, and ankles to jump into the air. Block with the arms to lead the movement, jumping as far to your right as you can. Land facing the same direction with your feet hip width...',
    nameDe: 'Side Stehend Long Sprung',
    descriptionDe: 'Begin Stehend with your feet Hüfte width apart in an athletic stance. Your Kopf and Brust should be up, knees and Hüften slightly bent. This will be your starting position. Leaning to your right, extend through your Hüften, knees, and ankles to Sprung into the Luft. Block with the arms to lead the...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Side to Side Box Shuffle',
    description: 'Stand to one side of the box with your left foot resting on the middle of it. To begin, jump up and over to the other side of the box, landing with your right foot on top of the box and your left foot on the floor. Swing your arms to aid your movement. Continue shuffling back and forth across the box.',
    nameDe: 'Side to Side Box Shuffle',
    descriptionDe: 'Stand to one side of the Box with your left foot resting on the middle of it. To begin, Sprung up and over to the other side of the Box, landing with your right foot on top of the Box and your left foot on the Boden. Schwingen your arms to aid your movement. Continue shuffling Rücken and forth...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Single-Cone Sprint Drill',
    description: 'This drill teaches quick foot action. You need a single cone. Begin standing next to the cone with one arm back and one arm forward. Chop the feet as quickly as possible, blocking with the arms. Circle the cone, keep your knees up, with violent foot action. Rest after three trips around the cone.',
    nameDe: 'Single-Cone Sprint Drill',
    descriptionDe: 'This drill teaches quick foot action. You need a single cone. Begin Stehend next to the cone with Einarmig Rücken and Einarmig forward. Chop the feet as quickly as possible, blocking with the arms. Circle the cone, keep your knees up, with violent foot action. Rest after three trips around the cone.',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Single-Leg Hop Progression',
    description: 'Arrange a line of cones in front of you. Assume a relaxed standing position, balanced on one leg. Raise the knee of your opposite leg. This will be your starting position. Hop forward, jumping and landing with the same leg over the cone. Use a countermovement jump to hop from cone to cone. At the end, turn around and go back on the other leg.',
    nameDe: 'Single-Leg Hüpfen Progression',
    descriptionDe: 'Arrange a line of cones in front of you. Assume a relaxed Stehend position, balanced on one leg. Heben the Knie of your opposite leg. This will be your starting position. Hüpfen forward, jumping and landing with the same leg over the cone. Use a countermovement Sprung to Hüpfen from cone to cone....',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Single-Leg Lateral Hop',
    description: 'Stand to the side of a cone or hurdle. To get into the start position, stand on one leg with your knee slightly bent. To begin, execute a counterjump to hop sideways over the cone. Land on your jumping leg, and immediately rebound out of it by jumping back to the start position. Continue hopping back and forth.',
    nameDe: 'Single-Leg Seitlich Hüpfen',
    descriptionDe: 'Stand to the side of a cone or hurdle. To get into the start position, stand on one leg with your Knie slightly bent. To begin, execute a counterjump to Hüpfen sideways over the cone. Land on your jumping leg, and immediately rebound out of it by jumping Rücken to the start position. Continue...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Single-Leg Stride Jump',
    description: 'Stand to the side of a box with your inside foot on top of it, close to the edge. Begin by swinging the arms upward as you push through the top leg, jumping upward as high as possible. Attempt to drive the opposite knee upward. Land in the same position that you started, using your inside leg to decelerate the impact.',
    nameDe: 'Single-Leg Stride Sprung',
    descriptionDe: 'Stand to the side of a Box with your inside foot on top of it, close to the edge. Begin by swinging the arms upward as you push through the top leg, jumping upward as high as possible. Attempt to drive the opposite Knie upward. Land in the same position that you started, using your inside leg to...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Single Leg Butt Kick',
    description: 'Begin by standing on one leg, with the bent knee raised. This will be your start position. Using a countermovement jump, take off upward by extending the hip, knee, and ankle of the grounded leg. Immediately flex the knee and attempt to touch your butt with the heel of your jumping leg. Return the leg to a partially bent position underneath the hips and land. Your opposite leg should stay in...',
    nameDe: 'Single Leg Butt Kick',
    descriptionDe: 'Begin by Stehend on one leg, with the bent Knie raised. This will be your start position. Using a countermovement Sprung, take off upward by extending the Hüfte, Knie, and Knöchel of the grounded leg. Immediately flex the Knie and attempt to touch your butt with the heel of your jumping leg. Return...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Single Leg Push-off',
    description: 'Stand on the ground with one foot resting on the box, heel close to the edge. Push off with your foot on top of the box, trying to gain as much height as possible by extending through the hip and knee. Land with the same foot on top of the box, returning your other foot back to the start position.',
    nameDe: 'Single Leg Push-off',
    descriptionDe: 'Stand on the ground with one foot resting on the Box, heel close to the edge. Push off with your foot on top of the Box, trying to gain as much height as possible by extending through the Hüfte and Knie. Land with the same foot on top of the Box, returning your other foot Rücken to the start...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Sledgehammer Swings',
    description: 'You will need a tire and a sledgehammer for this exercise. Stand in front of the tire about two feet away from it with a staggered stance. Grip the sledgehammer. If you are right handed, your left hand should be at the bottom of the handle, and your right hand should be choking up closer to the head. As you bring the sledge up, your right hand slides toward the head; as you swing down, your right...',
    nameDe: 'Sledgehammer Swings',
    descriptionDe: 'You will need a Reifen and a sledgehammer for this exercise. Stand in front of the Reifen about two feet away from it with a staggered stance. Grip the sledgehammer. If you are right handed, your left hand should be at the bottom of the handle, and your right hand should be choking up closer to the...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Split Jump',
    description: 'Assume a lunge stance position with one foot forward with the knee bent, and the rear knee nearly touching the ground. Ensure that the front knee is over the midline of the foot. Extending through both legs, jump as high as possible, swinging your arms to gain lift. As you jump, bring your feet together, and move them back to their initial positions as you land. Absorb the impact by reverting...',
    nameDe: 'Split Sprung',
    descriptionDe: 'Assume a Ausfallschritt stance position with one foot forward with the Knie bent, and the rear Knie nearly touching the ground. Ensure that the front Knie is over the midline of the foot. Extending through both legs, Sprung as high as possible, swinging your arms to gain lift. As you Sprung, bring...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Long Jump',
    description: 'This drill is best done in sand or other soft landing surface. Ensure that you are able to measure distance. Stand in a partial squat stance with feet shoulder width apart. Utilizing a big arm swing and a countermovement of the legs, jump forward as far as you can. Attempt to land with your feet out in front you, reaching as far as possible with your legs. Measure the distance from your landing...',
    nameDe: 'Stehend Long Sprung',
    descriptionDe: 'This drill is best done in sand or other soft landing surface. Ensure that you are able to measure distance. Stand in a Teilweise Kniebeuge stance with feet Schulter width apart. Utilizing a big arm Schwingen and a countermovement of the legs, Sprung forward as far as you can. Attempt to land with...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Two-Arm Overhead Throw',
    description: 'Stand with your feet shoulder width apart holding a medicine ball in both hands. To begin, reach the medicine ball deep behind your head as you bend the knees slightly and lean back. Violently throw the ball forward, flexing at the hip and using your whole body to complete the movement. The medicine ball can be thrown to a partner or to a wall, receiving it as it bounces back.',
    nameDe: 'Stehend Beidarmig Überkopf Throw',
    descriptionDe: 'Stand with your feet Schulter width apart holding a Medizinball in both hands. To begin, reach the Medizinball deep behind your Kopf as you bend the knees slightly and lean Rücken. Violently throw the Ball forward, flexing at the Hüfte and using your whole body to complete the movement. The...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Star Jump',
    description: 'Begin in a relaxed stance with your feet shoulder width apart and hold your arms close to the body. To initiate the move, squat down halfway and explode back up as high as possible. Fully extend your entire body, spreading your legs and arms away from the body. As you land, bring your limbs back in and absorb your impact through the legs.',
    nameDe: 'Sternensprung',
    descriptionDe: 'Begin in a relaxed stance with your feet Schulter width apart and hold your arms close to the body. To initiate the move, Kniebeuge down halfway and explode Rücken up as high as possible. Fully extend your entire body, spreading your legs and arms away from the body. As you land, bring your limbs...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Stride Jump Crossover',
    description: 'Stand to the side of a box with your inside foot on top of it, close to the edge. Begin by swinging the arms upward as you push through the top leg, jumping upward as high as possible. Attempt to drive the opposite knee upward. Land in the opposite position that you started, on the opposite side of the box. The foot that was initially on the box will now be on the ground, with the opposite foot...',
    nameDe: 'Stride Sprung Crossover',
    descriptionDe: 'Stand to the side of a Box with your inside foot on top of it, close to the edge. Begin by swinging the arms upward as you push through the top leg, jumping upward as high as possible. Attempt to drive the opposite Knie upward. Land in the opposite position that you started, on the opposite side of...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Supine Chest Throw',
    description: 'This drill is great for chest passes when you lack a partner or a wall of sufficient strength. Lay on the ground on your back with your knees bent. Begin with the ball on your chest, held with both hands on the bottom. Explode up, extending through the elbow to throw the ball directly above you as high as possible. Catch the ball with both hands as it comes down.',
    nameDe: 'Rückenlage Brust Throw',
    descriptionDe: 'This drill is great for Brust passes when you lack a partner or a Wand of sufficient strength. Lay on the ground on your Rücken with your knees bent. Begin with the Ball on your Brust, held with both hands on the bottom. Explode up, extending through the elbow to throw the Ball directly above you...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Supine One-Arm Overhead Throw',
    description: 'Lay on the ground on your back with your knees bent. Hold the ball with one hand, extending the arm fully behind your head. This will be your starting position. Initiate the movement at the shoulder, throwing the ball directly forward of you as you sit up, attempting to go for maximum distance. The ball can be thrown to a partner or bounced off of a wall.',
    nameDe: 'Rückenlage Einarmig Überkopf Throw',
    descriptionDe: 'Lay on the ground on your Rücken with your knees bent. Hold the Ball with one hand, extending the arm fully behind your Kopf. This will be your starting position. Initiate the movement at the Schulter, throwing the Ball directly forward of you as you Sit-Up, attempting to go for maximum distance....',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Supine Two-Arm Overhead Throw',
    description: 'Lay on the ground on your back with your knees bent. Hold the ball with both hands, extending the arms fully behind your head. This will be your starting position. Initiate the movement at the shoulder, throwing the ball directly forward of you as you sit up, attempting to go for maximum distance. The ball can be thrown to a partner or bounced off of a wall.',
    nameDe: 'Rückenlage Beidarmig Überkopf Throw',
    descriptionDe: 'Lay on the ground on your Rücken with your knees bent. Hold the Ball with both hands, extending the arms fully behind your Kopf. This will be your starting position. Initiate the movement at the Schulter, throwing the Ball directly forward of you as you Sit-Up, attempting to go for maximum...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Vertical Swing',
    description: 'Allow the dumbbell to hang at arms length between your legs, holding it with both hands. Keep your back straight and your head up. Swing the dumbbell between your legs, flexing at the hips and bending the knees slightly. Powerfully reverse the motion by extending at the hips, knees, and ankles to propel yourself upward, swinging the dumbell over your head. As you land, absorb the impact through...',
    nameDe: 'Vertikal Schwingen',
    descriptionDe: 'Allow the Kurzhantel to hang at arms length between your legs, holding it with both hands. Keep your Rücken straight and your Kopf up. Schwingen the Kurzhantel between your legs, flexing at the Hüften and bending the knees slightly. Powerfully Umgekehrt the motion by extending at the Hüften, knees,...',
    type: ExerciseType.calisthenics,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  // ── CARDIO (14) ────────────────────────────────────────────────────────────

  Exercise(
    name: 'Bicycling',
    description: 'To begin, seat yourself on the bike and adjust the seat to your height.',
    nameDe: 'Bicycling',
    descriptionDe: 'To begin, seat yourself on the bike and adjust the seat to your height.',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Bicycling, Stationary',
    description: 'To begin, seat yourself on the bike and adjust the seat to your height. Select the desired option from the menu. You may have to start pedaling to turn it on. You can use the manual setting, or you can select a program to use. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. The level of resistance can be changed throughout the workout. The...',
    nameDe: 'Bicycling, Stationary',
    descriptionDe: 'To begin, seat yourself on the bike and adjust the seat to your height. Select the desired option from the menu. You may have to start pedaling to turn it on. You can use the manual setting, or you can select a program to use. Typically, you can enter your age and weight to estimate the amount of...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Elliptical Trainer',
    description: 'To begin, step onto the elliptical and select the desired option from the menu. Most ellipticals have a manual setting, or you can select a program to run. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Elevation can be adjusted to change the intensity of the workout. The handles can be used to monitor your heart rate to help you stay at an...',
    nameDe: 'Elliptical Trainer',
    descriptionDe: 'To begin, Stufe onto the elliptical and select the desired option from the menu. Most ellipticals have a manual setting, or you can select a program to Laufen. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Elevation can be adjusted to change...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Jogging, Treadmill',
    description: 'To begin, step onto the treadmill and select the desired option from the menu. Most treadmills have a manual setting, or you can select a program to run. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Elevation can be adjusted to change the intensity of the workout. Treadmills offer convenience, cardiovascular benefits, and usually have...',
    nameDe: 'Jogging, Treadmill',
    descriptionDe: 'To begin, Stufe onto the treadmill and select the desired option from the menu. Most treadmills have a manual setting, or you can select a program to Laufen. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Elevation can be adjusted to change...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Prowler Sprint',
    description: 'Place your sled on an appropriate surface, loaded to a suitable weight. The sled should provide enough resistance to require effort, but not so heavy that you are significantly slowed down. You may use the upright or the low handles for this exercise. Place your hands on the handles with your arms extended, leaning into the implement. With good posture, drive through the ground with alternating,...',
    nameDe: 'Prowler Sprint',
    descriptionDe: 'Place your Schlitten on an appropriate surface, loaded to a suitable weight. The Schlitten should provide enough resistance to require effort, but not so heavy that you are significantly slowed down. You may use the Aufrecht or the low handles for this exercise. Place your hands on the handles with...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Recumbent Bike',
    description: 'To begin, seat yourself on the bike and adjust the seat to your height. Select the desired option from the menu. You may have to start pedaling to turn it on. You can use the manual setting, or you can select a program to use. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. The level of resistance can be changed throughout the workout. The...',
    nameDe: 'Recumbent Bike',
    descriptionDe: 'To begin, seat yourself on the bike and adjust the seat to your height. Select the desired option from the menu. You may have to start pedaling to turn it on. You can use the manual setting, or you can select a program to use. Typically, you can enter your age and weight to estimate the amount of...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Rope Jumping',
    description: 'Hold an end of the rope in each hand. Position the rope behind you on the ground. Raise your arms up and turn the rope over your head bringing it down in front of you. When it reaches the ground, jump over it. Find a good turning pace that can be maintained. Different speeds and techniques can be used to introduce variation. Rope jumping is exciting, challenges your coordination, and requires a...',
    nameDe: 'Seil Jumping',
    descriptionDe: 'Hold an end of the Seil in each hand. Position the Seil behind you on the ground. Heben your arms up and turn the Seil over your Kopf bringing it down in front of you. When it reaches the ground, Sprung over it. Find a good turning pace that can be maintained. Different speeds and techniques can be...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Rowing, Stationary',
    description: 'To begin, seat yourself on the rower. Make sure that your heels are resting comfortably against the base of the foot pedals and that the straps are secured. Select the program that you wish to use, if applicable. Sit up straight and bend forward at the hips. There are three phases of movement when using a rower. The first phase is when you come forward on the rower. Your knees are bent and...',
    nameDe: 'Rowing, Stationary',
    descriptionDe: 'To begin, seat yourself on the rower. Make sure that your heels are resting comfortably against the base of the foot pedals and that the straps are secured. Select the program that you wish to use, if applicable. Sit-Up straight and bend forward at the Hüften. There are three phases of movement...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Running, Treadmill',
    description: 'To begin, step onto the treadmill and select the desired option from the menu. Most treadmills have a manual setting, or you can select a program to run. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Elevation can be adjusted to change the intensity of the workout. Treadmills offer convenience, cardiovascular benefits, and usually have...',
    nameDe: 'Running, Treadmill',
    descriptionDe: 'To begin, Stufe onto the treadmill and select the desired option from the menu. Most treadmills have a manual setting, or you can select a program to Laufen. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Elevation can be adjusted to change...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Skating',
    description: 'Roller skating is a fun activity which can be effective in improving cardiorespiratory fitness and muscular endurance. It requires relatively good balance and coordination. It is necessary to learn the basics of skating including turning and stopping and to wear protective gear to avoid possible injury. You can skate at a comfortable pace for 30 minutes straight. If you want a cardio challenge,...',
    nameDe: 'Skating',
    descriptionDe: 'Roller skating is a fun activity which can be effective in improving cardiorespiratory fitness and muscular endurance. It requires relatively good balance and coordination. It is necessary to learn the basics of skating including turning and stopping and to wear protective gear to avoid possible...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Stairmaster',
    description: 'To begin, step onto the stairmaster and select the desired option from the menu. You can choose a manual setting, or you can select a program to run. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Pump your legs up and down in an established rhythm, driving the pedals down but not all the way to the floor. It is recommended that you...',
    nameDe: 'Stairmaster',
    descriptionDe: 'To begin, Stufe onto the stairmaster and select the desired option from the menu. You can choose a manual setting, or you can select a program to Laufen. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Pump your legs up and down in an...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Step Mill',
    description: 'To begin, step onto the stepmill and select the desired option from the menu. You can choose a manual setting, or you can select a program to run. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Use caution so that you don\'t trip as you climb the stairs. It is recommended that you maintain your grip on the handles so that you don\'t fall....',
    nameDe: 'Stufe Mill',
    descriptionDe: 'To begin, Stufe onto the stepmill and select the desired option from the menu. You can choose a manual setting, or you can select a program to Laufen. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Use caution so that you don\'t trip as you...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Trail Running/Walking',
    description: 'Running or hiking on trails will get the blood pumping and heart beating almost immediately. Make sure you have good shoes. While you use the muscles in your calves and buttocks to pull yourself up a hill, the knees, joints and ankles absorb the bulk of the pounding coming back down. Take smaller steps as you walk downhill, keep your knees bent to reduce the impact and slow down to avoid falling....',
    nameDe: 'Trail Running/Walking',
    descriptionDe: 'Running or hiking on trails will get the blood pumping and heart beating almost immediately. Make sure you have good shoes. While you use the muscles in your Waden and Gesäß to pull yourself up a hill, the knees, joints and ankles absorb the bulk of the pounding coming Rücken down. Take smaller...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Walking, Treadmill',
    description: 'To begin, step onto the treadmill and select the desired option from the menu. Most treadmills have a manual setting, or you can select a program to run. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Elevation can be adjusted to change the intensity of the workout. Treadmills offer convenience, cardiovascular benefits, and usually have...',
    nameDe: 'Walking, Treadmill',
    descriptionDe: 'To begin, Stufe onto the treadmill and select the desired option from the menu. Most treadmills have a manual setting, or you can select a program to Laufen. Typically, you can enter your age and weight to estimate the amount of calories burned during exercise. Elevation can be adjusted to change...',
    type: ExerciseType.cardio,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  // ── STRETCHING (123) ────────────────────────────────────────────────────────────

  Exercise(
    name: '90/90 Hamstring',
    description: 'Lie on your back, with one leg extended straight out. With the other leg, bend the hip and knee to 90 degrees. You may brace your leg with your hands if necessary. This will be your starting position. Extend your leg straight into the air, pausing briefly at the top. Return the leg to the starting position. Repeat for 10-20 repetitions, and then switch to the other leg.',
    nameDe: '90/90 Oberschenkelrückseite-Dehnung',
    descriptionDe: 'Lie on your Rücken, with one leg extended straight out. With the other leg, bend the Hüfte and Knie to 90 degrees. You may brace your leg with your hands if necessary. This will be your starting position. Extend your leg straight into the Luft, pausing briefly at the top. Return the leg to the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Adductor',
    description: 'Lie face down with one leg on a foam roll. Rotate the leg so that the foam roll contacts against your inner thigh. Shift as much weight onto the foam roll as can be tolerated. While trying to relax the muscles if the inner thigh, roll over the foam between your hip and knee, holding points of tension for 10-30 seconds. Repeat with the other leg.',
    nameDe: 'Adduktoren',
    descriptionDe: 'Lie face down with one leg on a Schaumstoffrolle. Rotate the leg so that the Schaumstoffrolle contacts against your Innen Oberschenkel. Shift as much weight onto the Schaumstoffrolle as can be tolerated. While trying to relax the muscles if the Innen Oberschenkel, roll over the foam between your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Adductor/Groin',
    description: 'Lie on your back with your feet raised towards the ceiling. Have your partner hold your feet or ankles. Abduct your legs as far as you can. This will be your starting position. Attempt to squeeze your legs together for 10 or more seconds, while your partner prevents you from doing so. Now, relax the muscles in your legs as your partner pushes your feet apart, stretching as far as is comfortable...',
    nameDe: 'Adduktoren/Leiste',
    descriptionDe: 'Lie on your Rücken with your feet raised towards the ceiling. Have your partner hold your feet or ankles. Abduct your legs as far as you can. This will be your starting position. Attempt to squeeze your legs together for 10 or more seconds, while your partner prevents you from doing so. Now, relax...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'All Fours Quad Stretch',
    description: 'Start off on your hands and knees, then lift your leg off the floor and hold the foot with your hand. Use your hand to hold the foot or ankle, keeping the knee fully flexed, stretching the quadriceps and hip flexors. Focus on extending your hips, thrusting them towards the floor. Hold for 10-20 seconds and then switch sides.',
    nameDe: 'Quadrizepsdehnung im Vierfüßlerstand',
    descriptionDe: 'Start off on your hands and knees, then lift your leg off the Boden and hold the foot with your hand. Use your hand to hold the foot or Knöchel, keeping the Knie fully flexed, stretching the Quadrizeps and Hüfte flexors. Focus on extending your Hüften, thrusting them towards the Boden. Hold for...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Ankle Circles',
    description: 'Use a sturdy object like a squat rack to hold yourself. Lift the right leg in the air (just around 2 inches from the floor) and perform a circular motion with the big toe. Pretend that you are drawing a big circle with it. Tip: One circle equals 1 repetition. Breathe normally as you perform the movement. When you are done with the right foot, then repeat with the left leg.',
    nameDe: 'Knöchel Circles',
    descriptionDe: 'Use a sturdy object like a Kniebeuge Ständer to hold yourself. Lift the right leg in the Luft (just around 2 inches from the Boden) and perform a circular motion with the big toe. Pretend that you are drawing a big circle with it. Tip: One circle equals 1 repetition. Breathe normally as you perform...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Ankle On The Knee',
    description: 'From a lying position, bend your knees and keep your feet on the floor. Place your ankle of one foot on your opposite knee. Grasp the thigh or knee of the bottom leg and pull both of your legs into the chest. Relax your neck and shoulders. Hold for 10-20 seconds and then switch sides.',
    nameDe: 'Knöchel On The Knie',
    descriptionDe: 'From a Liegend position, bend your knees and keep your feet on the Boden. Place your Knöchel of one foot on your opposite Knie. Grasp the Oberschenkel or Knie of the bottom leg and pull both of your legs into the Brust. Relax your Nacken and Schultern. Hold for 10-20 seconds and then switch sides.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Anterior Tibialis-SMR',
    description: 'Begin seated on the ground with your legs bent and your feet on the floor. Using a Muscle Roller or a rolling pin, apply pressure to the muscles on the outside of your shins. Work from just below the knee to above the ankle, pausing at points of tension for 10-30 seconds. Repeat on the other leg.',
    nameDe: 'Vorderer Schienbeinmuskel SMR',
    descriptionDe: 'Begin Sitzend on the ground with your legs bent and your feet on the Boden. Using a Muscle Roller or a rolling pin, apply pressure to the muscles on the outside of your shins. Work from just below the Knie to above the Knöchel, pausing at points of tension for 10-30 seconds. Repeat on the other leg.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Arm Circles',
    description: 'Stand up and extend your arms straight out by the sides. The arms should be parallel to the floor and perpendicular (90-degree angle) to your torso. This will be your starting position. Slowly start to make circles of about 1 foot in diameter with each outstretched arm. Breathe normally as you perform the movement. Continue the circular motion of the outstretched arms for about ten seconds. Then...',
    nameDe: 'Arm Circles',
    descriptionDe: 'Stand up and extend your arms straight out by the sides. The arms should be parallel to the Boden and perpendicular (90-degree angle) to your torso. This will be your starting position. Slowly start to make circles of about 1 foot in diameter with each outstretched arm. Breathe normally as you...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Behind Head Chest Stretch',
    description: 'Sit upright on the floor with your partner behind you. Place your hands behind your hand, and push your elbows back as far as you can. Your partner should hold your elbows. This will be your starting position. Gently attempt to pull your elbows forward with your hands still behind your head for 10 or more seconds. Your partner should prevent your elbows from moving. Now, relax your muscles and...',
    nameDe: 'Behind Kopf Brust Dehnung',
    descriptionDe: 'Sit Aufrecht on the Boden with your partner behind you. Place your hands behind your hand, and push your elbows Rücken as far as you can. Your partner should hold your elbows. This will be your starting position. Gently attempt to pull your elbows forward with your hands still behind your Kopf for...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Brachialis-SMR',
    description: 'Lie on your side, with your upper arm against the foam roller. The upper arm should be more or less aligned with your body, with the outside of the bicep pressed against the foam roller. Raise your hips off of the floor, supporting your weight on your arm and on your feet. Hold for 10-30 seconds, and then switch sides.',
    nameDe: 'Brachialis-SMR',
    descriptionDe: 'Lie on your side, with your Oberer arm against the Schaumstoffrolle. The Oberer arm should be more or less aligned with your body, with the outside of the Bizeps pressed against the Schaumstoffrolle. Heben your Hüften off of the Boden, supporting your weight on your arm and on your feet. Hold for...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Calf Stretch Elbows Against Wall',
    description: 'Stand facing a wall from a couple feet away. Lean against the wall, placing your weight on your forearms. Attempt to keep your heels on the ground. Hold for 10-20 seconds. You may move further or closer the wall, making it more or less difficult, respectively.',
    nameDe: 'Wade Dehnung Elbows Against Wand',
    descriptionDe: 'Stand facing a Wand from a couple feet away. Lean against the Wand, placing your weight on your Unterarme. Attempt to keep your heels on the ground. Hold for 10-20 seconds. You may move further or closer the Wand, making it more or less difficult, respectively.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Calf Stretch Hands Against Wall',
    description: 'Stand facing a wall from several feet away. Stagger your stance, placing one foot forward. Lean forward and rest your hands on the wall, keeping your heel, hip and head in a straight line. Attempt to keep your heel on the ground. Hold for 10-20 seconds and then switch sides.',
    nameDe: 'Wade Dehnung Hands Against Wand',
    descriptionDe: 'Stand facing a Wand from several feet away. Stagger your stance, placing one foot forward. Lean forward and rest your hands on the Wand, keeping your heel, Hüfte and Kopf in a straight line. Attempt to keep your heel on the ground. Hold for 10-20 seconds and then switch sides.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Calves-SMR',
    description: 'Begin seated on the floor. Place a foam roller underneath your lower leg. Your other leg can either be crossed over the opposite or be placed on the floor, supporting some of your weight. This will be your starting position. Place your hands to your side or just behind you, and press down to raise your hips off of the floor, placing much of your weight against your calf muscle. Roll from below...',
    nameDe: 'Waden-SMR',
    descriptionDe: 'Begin Sitzend on the Boden. Place a Schaumstoffrolle underneath your Unterer leg. Your other leg can either be crossed over the opposite or be placed on the Boden, supporting some of your weight. This will be your starting position. Place your hands to your side or just behind you, and Drücken down...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Cat Stretch',
    description: 'Position yourself on the floor on your hands and knees. Pull your belly in and round your spine, lower back, shoulders, and neck, letting your head drop. Hold for 15 seconds.',
    nameDe: 'Katze Dehnung',
    descriptionDe: 'Position yourself on the Boden on your hands and knees. Pull your belly in and round your Wirbelsäule, Unterer Rücken, Schultern, and Nacken, letting your Kopf drop. Hold for 15 seconds.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Chair Leg Extended Stretch',
    description: 'Sit upright in a chair and grip the seat on the sides. Raise one leg, extending the knee, flexing the ankle as you do so. Slowly move that leg outward as far as you can, and then back to the center and down. Repeat for your other leg.',
    nameDe: 'Stuhl Leg Extended Dehnung',
    descriptionDe: 'Sit Aufrecht in a Stuhl and grip the seat on the sides. Heben one leg, extending the Knie, flexing the Knöchel as you do so. Slowly move that leg outward as far as you can, and then Rücken to the center and down. Repeat for your other leg.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Chair Lower Back Stretch',
    description: 'Sit upright on a chair. Bend to one side with your arm over your head. You can hold onto the chair with your free hand. Hold for 10 seconds, and repeat for your other side.',
    nameDe: 'Stuhl Unterer Rücken Dehnung',
    descriptionDe: 'Sit Aufrecht on a Stuhl. Bend to one side with your arm over your Kopf. You can hold onto the Stuhl with your free hand. Hold for 10 seconds, and repeat for your other side.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Chair Upper Body Stretch',
    description: 'Sit on the edge of a chair, gripping the back of it. Straighten your arms, keeping your back straight, and pull your upper body forward so you feel a stretch. Hold for 20-30 seconds.',
    nameDe: 'Stuhl Oberer Body Dehnung',
    descriptionDe: 'Sit on the edge of a Stuhl, gripping the Rücken of it. Straighten your arms, keeping your Rücken straight, and pull your Oberer body forward so you feel a Dehnung. Hold for 20-30 seconds.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Chest And Front Of Shoulder Stretch',
    description: 'Start off by standing with your legs together, holding a bodybar or a broomstick. Take a slightly wider than shoulder width grip on the pole and hold it in front of you with your palms facing down. Carefully lift the pole up and behind your head.',
    nameDe: 'Brust And Front Of Schulter Dehnung',
    descriptionDe: 'Start off by Stehend with your legs together, holding a bodybar or a broomstick. Take a slightly wider than Schulter width grip on the pole and hold it in front of you with your palms facing down. Carefully lift the pole up and behind your Kopf.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Chest Stretch on Stability Ball',
    description: 'Get on your hands and knees next to an exercise ball. Place your elbows on top of the ball, keeping your arm out to your side. This will be your starting position. Lower your torso towards the floor, keeping your elbow on top of the ball. Hold the stretch for 20-30 seconds, and repeat with the other arm.',
    nameDe: 'Brust Dehnung on Stabilityball',
    descriptionDe: 'Get on your hands and knees next to an Trainingsball. Place your elbows on top of the Ball, keeping your arm out to your side. This will be your starting position. Unterer your torso towards the Boden, keeping your elbow on top of the Ball. Hold the Dehnung for 20-30 seconds, and repeat with the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Child\'s Pose',
    description: 'Get on your hands and knees, walk your hands in front of you. Lower your buttocks down to sit on your heels. Let your arms drag along the floor as you sit back to stretch your entire spine. Once you settle onto your heels, bring your hands next to your feet and relax. "breathe" into your back. Rest your forehead on the floor. Avoid this position if you have knee problems.',
    nameDe: 'Child\'s Pose',
    descriptionDe: 'Get on your hands and knees, Gehen your hands in front of you. Unterer your Gesäß down to sit on your heels. Let your arms Ziehen along the Boden as you sit Rücken to Dehnung your entire Wirbelsäule. Once you settle onto your heels, bring your hands next to your feet and relax. "breathe" into your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Chin To Chest Stretch',
    description: 'Get into a seated position on the floor. Place both hands at the rear of your head, fingers interlocked, thumbs pointing down and elbows pointing straight ahead. Slowly pull your head down to your chest. Hold for 20-30 seconds.',
    nameDe: 'Chin To Brust Dehnung',
    descriptionDe: 'Get into a Sitzend position on the Boden. Place both hands at the rear of your Kopf, fingers interlocked, thumbs pointing down and elbows pointing straight ahead. Slowly pull your Kopf down to your Brust. Hold for 20-30 seconds.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.fullBody],
  ),

  Exercise(
    name: 'Crossover Reverse Lunge',
    description: 'Stand with your feet shoulder width apart. This will be your starting position. Perform a rear lunge by stepping back with one foot and flexing the hips and front knee. As you do so, rotate your torso across the front leg. After a brief pause, return to the starting position and repeat on the other side, continuing in an alternating fashion.',
    nameDe: 'Crossover Umgekehrt Ausfallschritt',
    descriptionDe: 'Stand with your feet Schulter width apart. This will be your starting position. Perform a rear Ausfallschritt by stepping Rücken with one foot and flexing the Hüften and front Knie. As you do so, rotate your torso across the front leg. After a brief Pause, return to the starting position and repeat...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Dancer\'s Stretch',
    description: 'Sit up on the floor. Cross your right leg over your left, keeping the knee bent. Your left leg is straight and down on the floor. Place your left arm on your right leg and your right hand on the floor. Rotate your upper body to the right, and hold for 10-20 seconds. Switch sides.',
    nameDe: 'Dancer\'s Dehnung',
    descriptionDe: 'Sit-Up on the Boden. Überkreuz your right leg over your left, keeping the Knie bent. Your left leg is straight and down on the Boden. Place your left arm on your right leg and your right hand on the Boden. Rotate your Oberer body to the right, and hold for 10-20 seconds. Switch sides.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Dynamic Back Stretch',
    description: 'Stand with your feet shoulder width apart. This will be your starting position. Keeping your arms straight, swing them straight up in front of you 5-10 times, increasing the range of motion each time until your arms are above your head.',
    nameDe: 'Dynamic Rücken Dehnung',
    descriptionDe: 'Stand with your feet Schulter width apart. This will be your starting position. Keeping your arms straight, Schwingen them straight up in front of you 5-10 times, increasing the range of motion each time until your arms are above your Kopf.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Dynamic Chest Stretch',
    description: 'Stand with your hands together, arms extended directly in front of you. This will be your starting position. Keeping your arms straight, quickly move your arms back as far as possible and back in again, similar to an exaggerated clapping motion. Repeat 5-10 times, increasing speed as you do so.',
    nameDe: 'Dynamic Brust Dehnung',
    descriptionDe: 'Stand with your hands together, arms extended directly in front of you. This will be your starting position. Keeping your arms straight, quickly move your arms Rücken as far as possible and Rücken in again, similar to an exaggerated clapping motion. Repeat 5-10 times, increasing speed as you do so.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Elbow Circles',
    description: 'Sit or stand with your feet slightly apart. Place your hands on your shoulders with your elbows at shoulder level and pointing out. Slowly make a circle with your elbows. Breathe out as you start the circle and breathe in as you complete the circle.',
    nameDe: 'Elbow Circles',
    descriptionDe: 'Sit or stand with your feet slightly apart. Place your hands on your Schultern with your elbows at Schulter level and pointing out. Slowly make a circle with your elbows. Breathe out as you start the circle and breathe in as you complete the circle.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Elbows Back',
    description: 'Stand up straight. Place both hands on your lower back, fingers pointing downward and elbows out. Then gently pull your elbows back aiming to touch them together.',
    nameDe: 'Elbows Rücken',
    descriptionDe: 'Stand up straight. Place both hands on your Unterer Rücken, fingers pointing downward and elbows out. Then gently pull your elbows Rücken aiming to touch them together.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.chest],
  ),

  Exercise(
    name: 'Foot-SMR',
    description: 'This exercise stretches the fascia of the muscles in the feet. Start off seated with your shoes removed. Using a foot roller or a similar object, such as a small section of pvc pipe, place your foot against the roller across the arch of your foot. This will be your starting position. Press down firmly, rolling across the arch of your foot. Hold for 10-30 seconds, and then switch feet.',
    nameDe: 'Foot-SMR',
    descriptionDe: 'This exercise stretches the fascia of the muscles in the feet. Start off Sitzend with your shoes removed. Using a foot roller or a similar object, such as a small section of pvc pipe, place your foot against the roller across the arch of your foot. This will be your starting position. Drücken down...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Frog Hops',
    description: 'Stand with your hands behind your head, and squat down keeping your torso upright and your head up. This will be your starting position. Jump forward several feet, avoiding jumping unnecessarily high. As your feet contact the ground, absorb the impact through your legs, and jump again. Repeat this action 5-10 times.',
    nameDe: 'Frosch Hops',
    descriptionDe: 'Stand with your hands behind your Kopf, and Kniebeuge down keeping your torso Aufrecht and your Kopf up. This will be your starting position. Sprung forward several feet, avoiding jumping unnecessarily high. As your feet contact the ground, absorb the impact through your legs, and Sprung again....',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Front Leg Raises',
    description: 'Stand next to a chair or other support, holding on with one hand. Swing your leg forward, keeping the leg straight. Continue with a downward swing, bringing the leg as far back as your flexibility allows. Repeat 5-10 times, and then switch legs.',
    nameDe: 'Front Leg Raises',
    descriptionDe: 'Stand next to a Stuhl or other support, holding on with one hand. Schwingen your leg forward, keeping the leg straight. Continue with a downward Schwingen, bringing the leg as far Rücken as your flexibility allows. Repeat 5-10 times, and then switch legs.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Groin and Back Stretch',
    description: 'Sit on the floor with your knees bent and feet together. Interlock your fingers behind your head. This will be your starting position. Curl downwards, bringing your elbows to the inside of your thighs. After a brief pause, return to the starting position with your head up and your back straight. Repeat for 10-20 repetitions.',
    nameDe: 'Leiste and Rücken Dehnung',
    descriptionDe: 'Sit on the Boden with your knees bent and feet together. Interlock your fingers behind your Kopf. This will be your starting position. Curl downwards, bringing your elbows to the inside of your thighs. After a brief Pause, return to the starting position with your Kopf up and your Rücken straight....',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Groiners',
    description: 'Begin in a pushup position on the floor. This will be your starting position. Using both legs, jump forward landing with your feet next to your hands. Keep your head up as you do so. Return to the starting position and immediately repeat the movement, continuing for 10-20 repetitions.',
    nameDe: 'Groiners',
    descriptionDe: 'Begin in a Liegestütz position on the Boden. This will be your starting position. Using both legs, Sprung forward landing with your feet next to your hands. Keep your Kopf up as you do so. Return to the starting position and immediately repeat the movement, continuing for 10-20 repetitions.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hamstring-SMR',
    description: 'In a seated position, extend your legs over a foam roll so that it is position on the back of the upper legs. Place your hands to the side or behind you to help support your weight. This will be your starting position. Using your hands, lift your hips off of the floor and shift your weight on the foam roll to one leg. Relax the hamstrings of the leg you are stretching. Roll over the foam from...',
    nameDe: 'Oberschenkelrückseite-SMR',
    descriptionDe: 'In a Sitzend position, extend your legs over a Schaumstoffrolle so that it is position on the Rücken of the Oberer legs. Place your hands to the side or behind you to help support your weight. This will be your starting position. Using your hands, lift your Hüften off of the Boden and shift your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hamstring Stretch',
    description: 'Lie on your back with one leg extended above you, with the hip at ninety degrees. Keep the other leg flat on the floor. Loop a belt, band, or rope over the ball of your foot. This will be your starting position. Pull on the belt to create tension in the calves and hamstrings. Hold this stretch for 10-30 seconds, and repeat with the other leg.',
    nameDe: 'Oberschenkelrückseite Dehnung',
    descriptionDe: 'Lie on your Rücken with one leg extended above you, with the Hüfte at ninety degrees. Keep the other leg Flachbank on the Boden. Loop a belt, Band, or Seil over the Ball of your foot. This will be your starting position. Pull on the belt to create tension in the Waden and Oberschenkelrückseite....',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hip Circles (prone)',
    description: 'Position yourself on your hands and knees on the ground. Maintaining good posture, raise one bent knee off of the ground. This will be your starting position. Keeping the knee in a bent position, rotate the femur in an arc, attempting to make a big circle with your knee. Perform this slowly for a number of repetitions, and repeat on the other side.',
    nameDe: 'Hüfte Circles (Bauchlage)',
    descriptionDe: 'Position yourself on your hands and knees on the ground. Maintaining good posture, Heben one bent Knie off of the ground. This will be your starting position. Keeping the Knie in a bent position, rotate the femur in an arc, attempting to make a big circle with your Knie. Perform this slowly for a...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Hug A Ball',
    description: 'Seat yourself on the floor. Straddle an exercise ball between both legs and lower your hips down toward the floor. Hug your arms around the ball to support your body. Adjust your legs so that your feet are flat on the floor and your knees line up over your ankles. Keep a good grip on the ball so it doesn\'t roll away from you and send you back onto your buttocks.',
    nameDe: 'Hug A Ball',
    descriptionDe: 'Seat yourself on the Boden. Straddle an Trainingsball between both legs and Unterer your Hüften down toward the Boden. Hug your arms around the Ball to support your body. Adjust your legs so that your feet are Flachbank on the Boden and your knees line up over your ankles. Keep a good grip on the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Hug Knees To Chest',
    description: 'Lie down on your back and pull both knees up to your chest. Hold your arms under the knees, not over (that would put to much pressure on your knee joints). Slowly pull the knees toward your shoulders. This also stretches your buttocks muscles.',
    nameDe: 'Hug Knees To Brust',
    descriptionDe: 'Lie down on your Rücken and pull both knees up to your Brust. Hold your arms under the knees, not over (that would put to much pressure on your Knie joints). Slowly pull the knees toward your Schultern. This also stretches your Gesäß muscles.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'IT Band and Glute Stretch',
    description: 'Loop a belt, rope, or band around one of your feet, and swing that leg across your body to the opposite side, keeping the leg extended as you lay on the ground. This will be your starting position. Keeping your foot off of the floor, pull on the belt, using the tension to pull the toes up. Hold for 10-20 seconds, and repeat on the other side.',
    nameDe: 'IT Band and Gesäß Dehnung',
    descriptionDe: 'Loop a belt, Seil, or Band around one of your feet, and Schwingen that leg across your body to the opposite side, keeping the leg extended as you lay on the ground. This will be your starting position. Keeping your foot off of the Boden, pull on the belt, using the tension to pull the toes up. Hold...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Iliotibial Tract-SMR',
    description: 'Lay on your side, with the bottom leg placed onto a foam roller between the hip and the knee. The other leg can be crossed in front of you. Place as much of your weight as is tolerable onto your bottom leg; there is no need to keep your bottom leg in contact with the ground. Be sure to relax the muscles of the leg you are stretching. Roll your leg over the foam from you hip to your knee, pausing...',
    nameDe: 'Iliotibial Tract-SMR',
    descriptionDe: 'Lay on your side, with the bottom leg placed onto a Schaumstoffrolle between the Hüfte and the Knie. The other leg can be crossed in front of you. Place as much of your weight as is tolerable onto your bottom leg; there is no need to keep your bottom leg in contact with the ground. Be sure to relax...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Inchworm',
    description: 'Stand with your feet close together. Keeping your legs straight, stretch down and put your hands on the floor directly in front of you. This will be your starting position. Begin by walking your hands forward slowly, alternating your left and your right. As you do so, bend only at the hip, keeping your legs straight. Keep going until your body is parallel to the ground in a pushup position. Now,...',
    nameDe: 'Raupengang',
    descriptionDe: 'Stand with your feet close together. Keeping your legs straight, Dehnung down and put your hands on the Boden directly in front of you. This will be your starting position. Begin by walking your hands forward slowly, Alternierend your left and your right. As you do so, bend only at the Hüfte,...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Intermediate Groin Stretch',
    description: 'Lie on your back with your legs extended. Loop a belt, rope, or band around one of your feet, and swing that leg as far to the side as you can. This will be your starting position. Pull gently on the belt to create tension in your groin and hamstring muscles. Hold for 10-20 seconds, and repeat on the other side.',
    nameDe: 'Intermediate Leiste Dehnung',
    descriptionDe: 'Lie on your Rücken with your legs extended. Loop a belt, Seil, or Band around one of your feet, and Schwingen that leg as far to the side as you can. This will be your starting position. Pull gently on the belt to create tension in your Leiste and Oberschenkelrückseite muscles. Hold for 10-20...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Intermediate Hip Flexor and Quad Stretch',
    description: 'Lie face down on the floor, with a rope, belt, or band looped around one foot. Flex the knee and extend the hip of the leg to be stretched, using both hands to pull on the belt. Your knee and your hip should come off of the floor, creating tension in the hip flexors and quadriceps. Hold the stretch for 10-20 seconds, and repeat on the other leg.',
    nameDe: 'Intermediate Hüfte Flexor and Quadrizeps Dehnung',
    descriptionDe: 'Lie face down on the Boden, with a Seil, belt, or Band looped around one foot. Flex the Knie and extend the Hüfte of the leg to be stretched, using both hands to pull on the belt. Your Knie and your Hüfte should come off of the Boden, creating tension in the Hüfte flexors and Quadrizeps. Hold the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Iron Crosses (stretch)',
    description: 'Lie face down on the floor, with your arms extended out to your side, palms pressed to the floor. This will be your starting position. To begin, flex one knee and bring that leg across the back of your body, attempting to touch it to the ground near the opposite hand. Promptly return the leg to the starting postion, and quickly repeat with the other leg. Continue alternating for 10-20 repetitions.',
    nameDe: 'Iron Crosses (Dehnung)',
    descriptionDe: 'Lie face down on the Boden, with your arms extended out to your side, palms pressed to the Boden. This will be your starting position. To begin, flex one Knie and bring that leg across the Rücken of your body, attempting to touch it to the ground near the opposite hand. Promptly return the leg to...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Knee Across The Body',
    description: 'Lie down on the floor with your right leg straight. Bend your left leg and lower it across your body, holding the knee down toward the floor with your right hand. (The knee doesn\'t need to touch the floor if you\'re tight.) Place your left arm comfortably beside you and turn your head to the left. Imagine you have a weight tied to your tailbone. let your tailbone fall back toward the floor as your...',
    nameDe: 'Knie Across The Body',
    descriptionDe: 'Lie down on the Boden with your right leg straight. Bend your left leg and Unterer it across your body, holding the Knie down toward the Boden with your right hand. (The Knie doesn\'t need to touch the Boden if you\'re tight.) Place your left arm comfortably beside you and turn your Kopf to the left....',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Knee Circles',
    description: 'Stand with your legs together and hands by your waist. Now move your knees in a circular motion as you breathe normally. Repeat for the recommended amount of repetitions.',
    nameDe: 'Knie Circles',
    descriptionDe: 'Stand with your legs together and hands by your waist. Now move your knees in a circular motion as you breathe normally. Repeat for the recommended amount of repetitions.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Kneeling Forearm Stretch',
    description: 'Start by kneeling on a mat with your palms flat and your fingers pointing back toward your knees. Slowly lean back keeping your palms flat on the floor until you feel a stretch in your wrists and forearms. Hold for 20-30 seconds.',
    nameDe: 'Kniend Unterarm Dehnung',
    descriptionDe: 'Start by Kniend on a mat with your palms Flachbank and your fingers pointing Rücken toward your knees. Slowly lean Rücken keeping your palms Flachbank on the Boden until you feel a Dehnung in your wrists and Unterarme. Hold for 20-30 seconds.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Kneeling Hip Flexor',
    description: 'Kneel on a mat and bring your right knee up so the bottom of your foot is on the floor and extend your left leg out behind you so the top of your foot is on the floor. Shift your weight forward until you feel a stretch in your hip. Hold for 15 seconds, then repeat for your other side.',
    nameDe: 'Kniend Hüfte Flexor',
    descriptionDe: 'Kneel on a mat and bring your right Knie up so the bottom of your foot is on the Boden and extend your left leg out behind you so the top of your foot is on the Boden. Shift your weight forward until you feel a Dehnung in your Hüfte. Hold for 15 seconds, then repeat for your other side.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Latissimus Dorsi-SMR',
    description: 'While lying on the floor, place a foam roll under your back and to one side, just behind your arm pit. This will be your starting position. Keep the arm of the side being stretched behind and to the side of you as you shift your weight onto your lats, keeping your upper body off of the ground. Hold for 10-30 seconds, and switch sides.',
    nameDe: 'Latissimus Dorsi-SMR',
    descriptionDe: 'While Liegend on the Boden, place a Schaumstoffrolle under your Rücken and to one side, just behind your arm pit. This will be your starting position. Keep the arm of the side being stretched behind and to the side of you as you shift your weight onto your Latissimus, keeping your Oberer body off...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Leg-Up Hamstring Stretch',
    description: 'Lie flat on your back, bend one knee, and put that foot flat on the floor to stabilize your spine. Extend the other leg in the air. If you\'re tight, you wont be able to straighten it. That\'s okay. Extend the knee so that the sole of the lifted foot faces the ceiling (or as close as you can get it). Slowly straighten the legs as much as possible and then pull the leg toward your nose. Switch sides.',
    nameDe: 'Hamstring-Dehnung mit Beinanheben',
    descriptionDe: 'Lie Flachbank on your Rücken, bend one Knie, and put that foot Flachbank on the Boden to stabilize your Wirbelsäule. Extend the other leg in the Luft. If you\'re tight, you wont be able to straighten it. That\'s okay. Extend the Knie so that the sole of the lifted foot faces the ceiling (or as close...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Looking At Ceiling',
    description: 'Kneel on the floor, holding your heels with both hands. Lift your buttocks up and forward while bringing your head back to look up at the ceiling, to give an arch in your back.',
    nameDe: 'Looking At Ceiling',
    descriptionDe: 'Kneel on the Boden, holding your heels with both hands. Lift your Gesäß up and forward while bringing your Kopf Rücken to look up at the ceiling, to give an arch in your Rücken.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lower Back-SMR',
    description: 'In a seated position, place a foam roll under your lower back. Cross your arms in front of you and protract your shoulders. This will be your starting position. Raise your hips off of the floor and lean back, keeping your weight on your lower back. Now shift your weight slightly to one side, keeping your weight off of the spine and on the muscles to the side of it. Roll over your lower back,...',
    nameDe: 'Unterer Rücken-SMR',
    descriptionDe: 'In a Sitzend position, place a Schaumstoffrolle under your Unterer Rücken. Überkreuz your arms in front of you and protract your Schultern. This will be your starting position. Heben your Hüften off of the Boden and lean Rücken, keeping your weight on your Unterer Rücken. Now shift your weight...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Lower Back Curl',
    description: 'Lie on your stomach with your arms out to your sides. This will be your starting position. Using your lower back muscles, extend your spine lifting your chest off of the ground. Do not use your arms to push yourself up. Keep your head up during the movement. Repeat for 10-20 repetitions.',
    nameDe: 'Unterer Rücken Curl',
    descriptionDe: 'Lie on your stomach with your arms out to your sides. This will be your starting position. Using your Unterer Rücken muscles, extend your Wirbelsäule lifting your Brust off of the ground. Do not use your arms to push yourself up. Keep your Kopf up during the movement. Repeat for 10-20 repetitions.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Lying Bent Leg Groin',
    description: 'Lie on your back with your knees bent and the soles of the feet pressed together. Have your partner hold your knees. This will be your starting position. Attempt to squeeze your knees together, while your partner prevents any movement from occurring. After 10-20 seconds, relax your muscles as your partner gently pushes your knees towards the floor. Be sure to inform your helper when the stretch...',
    nameDe: 'Liegend Bent Leg Leiste',
    descriptionDe: 'Lie on your Rücken with your knees bent and the soles of the feet pressed together. Have your partner hold your knees. This will be your starting position. Attempt to squeeze your knees together, while your partner prevents any movement from occurring. After 10-20 seconds, relax your muscles as...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lying Crossover',
    description: 'Lie on your back with your legs extended. Cross one leg over your body with the knee bent, attempting to touch the knee to the ground. Your partner should kneel beside you, holding your shoulder down with one hand and controlling the crossed leg with the other. this will be your starting position. Attempt to raise the bent knee off of the ground as your partner prevents any actual movement. After...',
    nameDe: 'Liegend Crossover',
    descriptionDe: 'Lie on your Rücken with your legs extended. Überkreuz one leg over your body with the Knie bent, attempting to touch the Knie to the ground. Your partner should kneel beside you, holding your Schulter down with one hand and controlling the crossed leg with the other. this will be your starting...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lying Glute',
    description: 'Lie on your back with your partner kneeling beside you. Flex the hip of one leg, raising it off of the floor. Rotate the leg so the foot is over the opposite hip, the lower leg perpendicular to your body. Your partner should hold the knee and ankle in place. This will be your starting position. Attempt to push your leg towards your partner, who should be preventing any actual movement of the leg....',
    nameDe: 'Liegend Gesäß',
    descriptionDe: 'Lie on your Rücken with your partner Kniend beside you. Flex the Hüfte of one leg, raising it off of the Boden. Rotate the leg so the foot is over the opposite Hüfte, the Unterer leg perpendicular to your body. Your partner should hold the Knie and Knöchel in place. This will be your starting...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lying Hamstring',
    description: 'Lie on your back with your legs extended. Your partner should be kneeling beside you. Raise one leg up towards the ceiling and have your partner hold the ankle. Your partner can use their shoulder to brace your leg if necessary. This will be your starting position. With your partner holding your leg in place, attempt to flex the knee, contracting the hamstrings for 10-20 seconds. Then relax your...',
    nameDe: 'Liegend Oberschenkelrückseite',
    descriptionDe: 'Lie on your Rücken with your legs extended. Your partner should be Kniend beside you. Heben one leg up towards the ceiling and have your partner hold the Knöchel. Your partner can use their Schulter to brace your leg if necessary. This will be your starting position. With your partner holding your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Lying Prone Quadriceps',
    description: 'Lay face down on the floor with your partner kneeling beside you. Flex one knee and raise that leg off the ground, attempting to touch your glutes with your foot. Your partner should hold the knee and ankle. This will be your starting position. Attempt to extend your knee while your partner prevents any actual movement. After 10-20 seconds, relax your muscles as your partner gently pushes the...',
    nameDe: 'Liegend Bauchlage Quadrizeps',
    descriptionDe: 'Lay face down on the Boden with your partner Kniend beside you. Flex one Knie and Heben that leg off the ground, attempting to touch your Gesäß with your foot. Your partner should hold the Knie and Knöchel. This will be your starting position. Attempt to extend your Knie while your partner prevents...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Middle Back Stretch',
    description: 'Stand so your feet are shoulder width apart and your hands are on your hips. Twist at your waist until you feel a stretch. Hold for 10 to 15 seconds, then twist to the other side.',
    nameDe: 'Middle Rücken Dehnung',
    descriptionDe: 'Stand so your feet are Schulter width apart and your hands are on your Hüften. Twist at your waist until you feel a Dehnung. Hold for 10 to 15 seconds, then twist to the other side.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Neck-SMR',
    description: 'Using a muscle roller or a rolling pin, place the roller behind your head and against your neck. Make sure that you do not place the roller directly against the spine, but turned slightly so that the roller is pressed against the muscles to either side of the spine. This will be your starting position. Starting at the top of your neck, slowly roll down the muscles of your neck, pausing at points...',
    nameDe: 'Nacken-SMR',
    descriptionDe: 'Using a muscle roller or a rolling pin, place the roller behind your Kopf and against your Nacken. Make sure that you do not place the roller directly against the Wirbelsäule, but turned slightly so that the roller is pressed against the muscles to either side of the Wirbelsäule. This will be your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.fullBody],
  ),

  Exercise(
    name: 'On-Your-Back Quad Stretch',
    description: 'Lie on a flat bench or step, and hang one leg and arm over the side. Bend the knee and hold the top of the foot. As you do this, be careful not to arch your lower back. Pull the belly button to the spine to stay in neutral. Press your foot down and into your hand. To add the hip stretch, lift the hip of the leg you\'re holding up toward the ceiling. Switch sides.',
    nameDe: 'On-Your-Rücken Quadrizeps Dehnung',
    descriptionDe: 'Lie on a Flachbank Bank or Stufe, and hang one leg and arm over the side. Bend the Knie and hold the top of the foot. As you do this, be careful not to arch your Unterer Rücken. Pull the belly button to the Wirbelsäule to stay in neutral. Drücken your foot down and into your hand. To add the Hüfte...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'On Your Side Quad Stretch',
    description: 'Start off by lying on your right side, with your right knee bent at a 90-degree angle resting on the floor in front of you (this stabilizes the torso). Bend your left knee behind you and hold your left foot with your left hand. To stretch your hip flexor, press your left hip forward as you push your left foot back into your hand. Switch sides.',
    nameDe: 'On Your Side Quadrizeps Dehnung',
    descriptionDe: 'Start off by Liegend on your right side, with your right Knie bent at a 90-degree angle resting on the Boden in front of you (this stabilizes the torso). Bend your left Knie behind you and hold your left foot with your left hand. To Dehnung your Hüfte flexor, Drücken your left Hüfte forward as you...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'One Arm Against Wall',
    description: 'From a standing position, place a bent arm against a wall or doorway. Slowly lean toward your arm until you feel a stretch in your lats.',
    nameDe: 'Einarmig Against Wand',
    descriptionDe: 'From a Stehend position, place a bent arm against a Wand or doorway. Slowly lean toward your arm until you feel a Dehnung in your Latissimus.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'One Half Locust',
    description: 'Lie facedown on the floor. Put your left hand under your left hipbone to pad your hip and pubic bone. Bend your right knee so you can hold the foot in your right hand. Lift the foot in the air and simultaneously lift your shoulders off the floor. This also stretches the right hip flexor and the chest and shoulders. Switch sides. If it doesn\'t bother your back, you can try it with both arms and...',
    nameDe: 'One Halb Locust',
    descriptionDe: 'Lie facedown on the Boden. Put your left hand under your left hipbone to pad your Hüfte and pubic bone. Bend your right Knie so you can hold the foot in your right hand. Lift the foot in the Luft and simultaneously lift your Schultern off the Boden. This also stretches the right Hüfte flexor and...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'One Handed Hang',
    description: 'Grab onto a chinup bar with one hand, using a pronated grip. Keep your feet on the floor or a step. Allow the majority of your weight to hang from that hand, while keeping your feet on the ground. Hold for 10-20 seconds and switch sides.',
    nameDe: 'One Handed Hang',
    descriptionDe: 'Grab onto a chinup Stange with one hand, using a Proniert grip. Keep your feet on the Boden or a Stufe. Allow the majority of your weight to hang from that hand, while keeping your feet on the ground. Hold for 10-20 seconds and switch sides.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'One Knee To Chest',
    description: 'Start off by lying on the floor. Extend one leg straight and pull the other knee to your chest. Hold under the knee joint to protect the kneecap. Gently tug that knee toward your nose. Switch sides. This stretches the buttocks and lower back of the bent leg and the hip flexor of the straight leg.',
    nameDe: 'One Knie To Brust',
    descriptionDe: 'Start off by Liegend on the Boden. Extend one leg straight and pull the other Knie to your Brust. Hold under the Knie joint to protect the kneecap. Gently tug that Knie toward your nose. Switch sides. This stretches the Gesäß and Unterer Rücken of the bent leg and the Hüfte flexor of the straight...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Overhead Lat',
    description: 'Sit upright on the floor with your partner behind you. Raise one arm straight up, and flex the elbow, attempting to touch your hand to your back. Your parner should hold your tricep and wrist. This will be your starting position. Attempt to pull your upper arm to your side as your partner prevents you from doing actually doing so. After 10-20 seconds, relax the arm and allow your partner to...',
    nameDe: 'Überkopf Lat',
    descriptionDe: 'Sit Aufrecht on the Boden with your partner behind you. Heben Einarmig straight up, and flex the elbow, attempting to touch your hand to your Rücken. Your parner should hold your Trizeps and Handgelenk. This will be your starting position. Attempt to pull your Oberer arm to your side as your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Overhead Stretch',
    description: 'Standing straight up, lace your fingers together and open your palms to the ceiling. Keep your shoulders down as you extend your arms up. To create a full torso stretch, pull your tailbone down and stabilize your torso as you do this. Stretch the muscles on both the front and the back of the torso.',
    nameDe: 'Überkopf Dehnung',
    descriptionDe: 'Stehend straight up, lace your fingers together and open your palms to the ceiling. Keep your Schultern down as you extend your arms up. To create a Komplett torso Dehnung, pull your tailbone down and stabilize your torso as you do this. Dehnung the muscles on both the front and the Rücken of the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Overhead Triceps',
    description: 'Sit upright on the floor with your partner behind you. Raise one arm straight up, and flex the elbow, attempting to touch your hand to your back. Your parner should hold your elbow and wrist. This will be your starting position. Attempt to extend the arm straight into the air as your partner prevents you from doing actually doing so. After 10-20 seconds, relax the arm and allow your partner to...',
    nameDe: 'Überkopf Trizeps',
    descriptionDe: 'Sit Aufrecht on the Boden with your partner behind you. Heben Einarmig straight up, and flex the elbow, attempting to touch your hand to your Rücken. Your parner should hold your elbow and Handgelenk. This will be your starting position. Attempt to extend the arm straight into the Luft as your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Pelvic Tilt Into Bridge',
    description: 'Lie down with your feet on the floor, heels directly under your knees. Lift only your tailbone to the ceiling to stretch your lower back. (Don\'t lift the entire spine yet.) Pull in your stomach. To go into a bridge, lift the entire spine except the neck.',
    nameDe: 'Pelvic Tilt Into Brücke',
    descriptionDe: 'Lie down with your feet on the Boden, heels directly under your knees. Lift only your tailbone to the ceiling to Dehnung your Unterer Rücken. (Don\'t lift the entire Wirbelsäule yet.) Pull in your stomach. To go into a Brücke, lift the entire Wirbelsäule except the Nacken.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Peroneals-SMR',
    description: 'Lay on your side, supporting your weight on your forearm and on a foam roller placed on the outside of your lower leg. Your upper leg can either be on top of your lower leg, or you can cross it in front of you. This will be your starting position. Raise your hips off of the ground and begin to roll from below the knee to above the ankle on the side of your leg, pausing at points of tension for...',
    nameDe: 'Peroneals-SMR',
    descriptionDe: 'Lay on your side, supporting your weight on your Unterarm and on a Schaumstoffrolle placed on the outside of your Unterer leg. Your Oberer leg can either be on top of your Unterer leg, or you can Überkreuz it in front of you. This will be your starting position. Heben your Hüften off of the ground...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Peroneals Stretch',
    description: 'In a seated position, loop a belt, rope, or band around one foot. This will be your starting position. With the leg extended and the heel off of the ground, pull on the belt so that the foot is inverted, with the inside of the foot being pulled towards you. Hold for 10-20 seconds, and then switch sides.',
    nameDe: 'Peroneals Dehnung',
    descriptionDe: 'In a Sitzend position, loop a belt, Seil, or Band around one foot. This will be your starting position. With the leg extended and the heel off of the ground, pull on the belt so that the foot is inverted, with the inside of the foot being pulled towards you. Hold for 10-20 seconds, and then switch...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Piriformis-SMR',
    description: 'Sit with your buttocks on top of a foam roll. Bend your knees, and then cross one leg so that the ankle is over the knee. This will be your starting position. Shift your weight to the side of the crossed leg, rolling over the buttocks until you feel tension in your upper glute. You may assist the stretch by using one hand to pull the bent knee towards your chest. Hold this position for 10-30...',
    nameDe: 'Piriformis-SMR',
    descriptionDe: 'Sit with your Gesäß on top of a Schaumstoffrolle. Bend your knees, and then Überkreuz one leg so that the Knöchel is over the Knie. This will be your starting position. Shift your weight to the side of the crossed leg, rolling over the Gesäß until you feel tension in your Oberer Gesäß. You may...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Posterior Tibialis Stretch',
    description: 'In a seated position, loop a belt, rope, or band around one foot. This will be your starting position. With the leg extended and the heel off of the ground, pull on the belt so that the foot is everted, with the outside of the foot being pulled towards you. Hold for 10-20 seconds, and then switch sides.',
    nameDe: 'Hinterer Schienbeinmuskel Dehnung',
    descriptionDe: 'In a Sitzend position, loop a belt, Seil, or Band around one foot. This will be your starting position. With the leg extended and the heel off of the ground, pull on the belt so that the foot is everted, with the outside of the foot being pulled towards you. Hold for 10-20 seconds, and then switch...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Pyramid',
    description: 'Start off by rolling your torso forward onto the ball so your hips rest on top of the ball and become the highest point of your body. Rest your hands and feet on the floor. Your arms and legs can be slightly bent or straight, depending on the size of the ball, your flexibility, and the length of your limbs. This also helps develop stabilizing strength in your torso and shoulders.',
    nameDe: 'Pyramid',
    descriptionDe: 'Start off by rolling your torso forward onto the Ball so your Hüften rest on top of the Ball and become the highest point of your body. Rest your hands and feet on the Boden. Your arms and legs can be slightly bent or straight, depending on the size of the Ball, your flexibility, and the length of...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Quad Stretch',
    description: 'Lay on your side. Loop a belt, rope, or band around your top foot. Flex the knee and extend your hip, attempting to touch your glutes with your foot, and holding the belt with your hands. This will be your starting position. With the belt being held over the shoulder or overhead, gently pull to increase the stretch in the quadriceps. Hold for 10-20 seconds, and then switch sides.',
    nameDe: 'Quadrizeps Dehnung',
    descriptionDe: 'Lay on your side. Loop a belt, Seil, or Band around your top foot. Flex the Knie and extend your Hüfte, attempting to touch your Gesäß with your foot, and holding the belt with your hands. This will be your starting position. With the belt being held over the Schulter or Überkopf, gently pull to...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Quadriceps-SMR',
    description: 'Lay facedown on the floor with your weight supported by your hands or forearms. Place a foam roll underneath one leg on the quadriceps, and keep the foot off of the ground. Make sure to relax the leg as much as possible. This will be your starting position. Shifting as much weight onto the leg to be stretched as is tolerable, roll over the foam from above the knee to below the hip, holding points...',
    nameDe: 'Quadrizeps-SMR',
    descriptionDe: 'Lay facedown on the Boden with your weight supported by your hands or Unterarme. Place a Schaumstoffrolle underneath one leg on the Quadrizeps, and keep the foot off of the ground. Make sure to relax the leg as much as possible. This will be your starting position. Shifting as much weight onto the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Rear Leg Raises',
    description: 'Place yourself on your hands knees on an exercise mat. Your head should be looking forward and the bend of the knees should create a 90-degree angle between the hamstrings and the calves. This will be your starting position. Extend one leg up and behind you. The knee and hip should both extend. Repeat for 5-10 repetitions, and then switch sides.',
    nameDe: 'Rear Leg Raises',
    descriptionDe: 'Place yourself on your hands knees on an exercise mat. Your Kopf should be looking forward and the bend of the knees should create a 90-degree angle between the Oberschenkelrückseite and the Waden. This will be your starting position. Extend one leg up and behind you. The Knie and Hüfte should both...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Rhomboids-SMR',
    description: 'Lay down with your back on the floor. Place a foam roll underneath your upper back, and cross your arms in front of you, protracting your shoulders. This will be your starting position. Raise your hips off of the ground, placing your weight onto the foam roll. Shift your weight to one side at a time, rolling over your middle and upper back. Pause at points of tension for 10-30 seconds.',
    nameDe: 'Rhomboids-SMR',
    descriptionDe: 'Lay down with your Rücken on the Boden. Place a Schaumstoffrolle underneath your Oberer Rücken, and Überkreuz your arms in front of you, protracting your Schultern. This will be your starting position. Heben your Hüften off of the ground, placing your weight onto the Schaumstoffrolle. Shift your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Round The World Shoulder Stretch',
    description: 'Stand up straight with your legs together, holding a bodybar or broomstick. Hold the pole behind your hips with a wider than shoulder width grip. Your palms should be down and your thumbs facing out. Slowly lift your arms up behind your head. Don\'t force it if it gets hard to lift further.',
    nameDe: 'Round The World Schulter Dehnung',
    descriptionDe: 'Stand up straight with your legs together, holding a bodybar or broomstick. Hold the pole behind your Hüften with a wider than Schulter width grip. Your palms should be down and your thumbs facing out. Slowly lift your arms up behind your Kopf. Don\'t force it if it gets hard to lift further.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Runner\'s Stretch',
    description: 'It\'s easiest to get into this stretch if you start standing up, put one leg behind you, and slowly lower your torso down to the floor. Keep the front heel on the floor (if it lifts up, scoot your other leg further back). Place your hands on either side of your front leg. To get more out of this stretch, push your butt up toward the ceiling, and then gradually lower it back toward the floor....',
    nameDe: 'Runner\'s Dehnung',
    descriptionDe: 'It\'s easiest to get into this Dehnung if you start Stehend up, put one leg behind you, and slowly Unterer your torso down to the Boden. Keep the front heel on the Boden (if it lifts up, scoot your other leg further Rücken). Place your hands on either side of your front leg. To get more out of this...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Scissor Kick',
    description: 'To begin, lie down with your back pressed against the floor or on an exercise mat (optional). Your arms should be fully extended to the sides with your palms facing down. Note: The arms should be stationary the entire time. With a slight bend at the knees, lift your legs up so that your heels are about 6 inches off the ground. This is the starting position. Now lift your left leg up to about a 45...',
    nameDe: 'Scissor Kick',
    descriptionDe: 'To begin, lie down with your Rücken pressed against the Boden or on an exercise mat (optional). Your arms should be fully extended to the sides with your palms facing down. Note: The arms should be stationary the entire time. With a slight bend at the knees, lift your legs up so that your heels are...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Seated Biceps',
    description: 'Sit on the floor with your knees bent and your partner standing behind you. Extend your arms straight behind you with your palms facing each other. Your partner will hold your wrists for you. This will be the starting position. Attempt to flex your elbows, while your partner prevents any actual movement. After 10-20 seconds, relax your arms while your partner gently pulls your wrists up to...',
    nameDe: 'Sitzend Bizeps',
    descriptionDe: 'Sit on the Boden with your knees bent and your partner Stehend behind you. Extend your arms straight behind you with your palms facing each other. Your partner will hold your wrists for you. This will be the starting position. Attempt to flex your elbows, while your partner prevents any actual...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Seated Calf Stretch',
    description: 'Sit up straight on an exercise mat. Bend one knee and put that foot on the floor to stabilize the torso. Straighten your other leg and flex your ankle. Using a band, towel, or your hand if you can reach, pull the toes toward you. Hold for 10 to 20 seconds, then switch sides.',
    nameDe: 'Sitzend Wade Dehnung',
    descriptionDe: 'Sit-Up straight on an exercise mat. Bend one Knie and put that foot on the Boden to stabilize the torso. Straighten your other leg and flex your Knöchel. Using a Band, towel, or your hand if you can reach, pull the toes toward you. Hold for 10 to 20 seconds, then switch sides.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Floor Hamstring Stretch',
    description: 'Sit on a mat with your right leg extended in front of you and your left leg bent with your foot against your right inner thigh. Lean forward from your hips and reach for your ankle until you feel a stretch in your hamstring. Hold for 15 seconds, then repeat for your other side.',
    nameDe: 'Sitzend Boden Oberschenkelrückseite Dehnung',
    descriptionDe: 'Sit on a mat with your right leg extended in front of you and your left leg bent with your foot against your right Innen Oberschenkel. Lean forward from your Hüften and reach for your Knöchel until you feel a Dehnung in your Oberschenkelrückseite. Hold for 15 seconds, then repeat for your other...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Front Deltoid',
    description: 'Sit upright on the floor with your legs bent, your partner standing behind you. Stick your arms straight out to your sides, with your palms facing the ground. Attempt to move them as far behind you as possible, as your assistant holds your wrists. This will be your starting position. Keeping your elbows straight, attempt to move your arms to the front, with your partner gently restraining you to...',
    nameDe: 'Sitzend Front Deltamuskel',
    descriptionDe: 'Sit Aufrecht on the Boden with your legs bent, your partner Stehend behind you. Stick your arms straight out to your sides, with your palms facing the ground. Attempt to move them as far behind you as possible, as your assistant holds your wrists. This will be your starting position. Keeping your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Seated Glute',
    description: 'In a seated position with your knees bent, cross one ankle over the opposite knee. Your partner will stand behind you. Now, lean forward as your partner braces your shoulders with their hands. This will be your starting position. Attempt to push your torso back for 10-20 seconds, as your partner prevents any actual movement of your torso. Now relax your muscles as your partner increases the...',
    nameDe: 'Sitzend Gesäß',
    descriptionDe: 'In a Sitzend position with your knees bent, Überkreuz one Knöchel over the opposite Knie. Your partner will stand behind you. Now, lean forward as your partner braces your Schultern with their hands. This will be your starting position. Attempt to push your torso Rücken for 10-20 seconds, as your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Hamstring',
    description: 'In a seated position with your legs extended, have your partner stand behind you. Now, lean forward as your partner braces your shoulders with their hands. This will be your starting position. Attempt to push your torso back for 10-20 seconds, as your partner prevents any actual movement of your torso. Now relax your muscles as your partner increases the stretch by gently pushing your torso...',
    nameDe: 'Sitzend Oberschenkelrückseite',
    descriptionDe: 'In a Sitzend position with your legs extended, have your partner stand behind you. Now, lean forward as your partner braces your Schultern with their hands. This will be your starting position. Attempt to push your torso Rücken for 10-20 seconds, as your partner prevents any actual movement of your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Hamstring and Calf Stretch',
    description: 'Loop a belt, rope, or band around one foot. Sit down with both legs extended . This will be your starting position. Leaning forward slightly, pull on the belt to draw the toes of your foot back. Hold this position for 10-20 seconds and then repeat with the other leg.',
    nameDe: 'Sitzend Oberschenkelrückseite and Wade Dehnung',
    descriptionDe: 'Loop a belt, Seil, or Band around one foot. Sit down with both legs extended . This will be your starting position. Leaning forward slightly, pull on the belt to draw the toes of your foot Rücken. Hold this position for 10-20 seconds and then repeat with the other leg.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Seated Overhead Stretch',
    description: 'Sit up straight on an exercise mat. Touch the soles of your feet together with your feet six to eight inches in front of your hips. Place one hand on the floor beside you and your other hand behind your head. Lift your elbow to the ceiling as you incline your torso to the other side. Hold for 10 to 20 seconds, then switch sides.',
    nameDe: 'Sitzend Überkopf Dehnung',
    descriptionDe: 'Sit-Up straight on an exercise mat. Touch the soles of your feet together with your feet six to eight inches in front of your Hüften. Place one hand on the Boden beside you and your other hand behind your Kopf. Lift your elbow to the ceiling as you Schrägbank your torso to the other side. Hold for...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Shoulder Circles',
    description: 'With shoulders relaxed and arms resting loosely at your sides (or in your lap if you\'re seated), gently roll your shoulders forward, up, back, and down. Reverse direction. You can do this exercise alternating shoulders or both at the same time.',
    nameDe: 'Schulter Circles',
    descriptionDe: 'With Schultern relaxed and arms resting loosely at your sides (or in your lap if you\'re Sitzend), gently roll your Schultern forward, up, Rücken, and down. Umgekehrt direction. You can do this exercise Alternierend Schultern or both at the same time.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Shoulder Raise',
    description: 'Relax your arms to your sides and raise your shoulders up toward your ears, then back down.',
    nameDe: 'Schulter Heben',
    descriptionDe: 'Relax your arms to your sides and Heben your Schultern up toward your ears, then Rücken down.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Shoulder Stretch',
    description: 'Reach your left arm across your body and hold it straight.',
    nameDe: 'Schulter Dehnung',
    descriptionDe: 'Reach your left arm across your body and hold it straight.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Side-Lying Floor Stretch',
    description: 'First lie on your left side, bending your left knee in front of you to stabilize your torso (use your abdominal muscles as well to hold you upright). Straighten your right leg and rest the right foot on the floor behind your left. Straighten your right arm over your head and gently pull on your right wrist to stretch the entire right side of the body. Switch sides.',
    nameDe: 'Side-Liegend Boden Dehnung',
    descriptionDe: 'First lie on your left side, bending your left Knie in front of you to stabilize your torso (use your Bauch muscles as well to hold you Aufrecht). Straighten your right leg and rest the right foot on the Boden behind your left. Straighten your right arm over your Kopf and gently pull on your right...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Side Leg Raises',
    description: 'Stand next to a chair, which you may hold onto as a support. Stand on one leg. This will be your starting position. Keeping your leg straight, raise it as far out to the side as possible, and swing it back down, allowing it to cross the opposite leg. Repeat this swinging motion 5-10 times, increasing the range of motion as you do so.',
    nameDe: 'Side Leg Raises',
    descriptionDe: 'Stand next to a Stuhl, which you may hold onto as a support. Stand on one leg. This will be your starting position. Keeping your leg straight, Heben it as far out to the side as possible, and Schwingen it Rücken down, allowing it to Überkreuz the opposite leg. Repeat this swinging motion 5-10...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Side Lying Groin Stretch',
    description: 'Start off by lying on your right side and bend your right knee in front of you to stabilize the torso. Rest your head on your right hand or shoulder. Lift your left leg upward and hold it by the back of the knee (easier) or the foot (harder). Pull your left knee in toward your left shoulder and simultaneously press your foot or knee down to the floor. To intensify this stretch, straighten your...',
    nameDe: 'Side Liegend Leiste Dehnung',
    descriptionDe: 'Start off by Liegend on your right side and bend your right Knie in front of you to stabilize the torso. Rest your Kopf on your right hand or Schulter. Lift your left leg upward and hold it by the Rücken of the Knie (easier) or the foot (harder). Pull your left Knie in toward your left Schulter and...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Side Neck Stretch',
    description: 'Start with your shoulders relaxed, gently tilt your head towards your shoulder. Assist stretch with a gentle pull on the side of the head.',
    nameDe: 'Side Nacken Dehnung',
    descriptionDe: 'Start with your Schultern relaxed, gently tilt your Kopf towards your Schulter. Assist Dehnung with a gentle pull on the side of the Kopf.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.fullBody],
  ),

  Exercise(
    name: 'Side Wrist Pull',
    description: 'This stretch works best standing. Cross your left arm over the midline of your body and hold the left wrist in your right hand down at the level of your hips. Start the stretch with a bent left arm. Slowly straighten, pull, and lift it up to shoulder height, as pictured. Feel this stretch originate in your back, not your shoulders, and don\'t pull too hard on the shoulders joint. Switch sides.',
    nameDe: 'Side Handgelenk Pull',
    descriptionDe: 'This Dehnung works best Stehend. Überkreuz your left arm over the midline of your body and hold the left Handgelenk in your right hand down at the level of your Hüften. Start the Dehnung with a bent left arm. Slowly straighten, pull, and lift it up to Schulter height, as pictured. Feel this Dehnung...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Sit Squats',
    description: 'Stand with your feet shoulder width apart. This will be your starting position. Begin the movement by flexing your knees and hips, sitting back with your hips. Continue until you have squatted a portion of the way down, but are above parallel, and quickly reverse the motion until you return to the starting position. Repeat for 5-10 repetitions.',
    nameDe: 'Sit Squats',
    descriptionDe: 'Stand with your feet Schulter width apart. This will be your starting position. Begin the movement by flexing your knees and Hüften, sitting Rücken with your Hüften. Continue until you have squatted a portion of the way down, but are above parallel, and quickly Umgekehrt the motion until you return...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Spinal Stretch',
    description: 'Sit in a chair so your back is straight and your feet planted on the floor. Interlace your fingers behind your head, elbows out and your chin down. Twist your upper body to one side about 3 times as far as you can. Then lean forward and twist your torso to reach your elbow to the floor on the inside of your knee. Return to upright position and then repeat for your other side.',
    nameDe: 'Wirbelsäule Dehnung',
    descriptionDe: 'Sit in a Stuhl so your Rücken is straight and your feet planted on the Boden. Interlace your fingers behind your Kopf, elbows out and your chin down. Twist your Oberer body to one side about 3 times as far as you can. Then lean forward and twist your torso to reach your elbow to the Boden on the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Split Squats',
    description: 'Being in a standing position. Jump into a split leg position, with one leg forward and one leg back, flexing the knees and lowering your hips slightly as you do so. As you descend, immediately reverse direction, standing back up and jumping, reversing the position of your legs. Repeat 5-10 times on each leg.',
    nameDe: 'Split Squats',
    descriptionDe: 'Being in a Stehend position. Sprung into a split leg position, with one leg forward and one leg Rücken, flexing the knees and lowering your Hüften slightly as you do so. As you descend, immediately Umgekehrt direction, Stehend Rücken up and jumping, reversing the position of your legs. Repeat 5-10...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Biceps Stretch',
    description: 'Clasp your hands behind your back with your palms together, straighten arms and then rotate them so your palms face downward. Raise your arms up and hold until you feel a stretch in your biceps.',
    nameDe: 'Stehend Bizeps Dehnung',
    descriptionDe: 'Clasp your hands behind your Rücken with your palms together, straighten arms and then rotate them so your palms face downward. Heben your arms up and hold until you feel a Dehnung in your Bizeps.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

  Exercise(
    name: 'Standing Elevated Quad Stretch',
    description: 'Start by standing with your back about two to three feet away from a bench or step. Lift one leg behind you and rest your foot on the step,either on your instep or the ball of your foot, whichever you find most comfortable. Keep your supporting knee slightly bent and avoid letting that knee extend out beyond your toes. Switch sides.',
    nameDe: 'Stehend Elevated Quadrizeps Dehnung',
    descriptionDe: 'Start by Stehend with your Rücken about two to three feet away from a Bank or Stufe. Lift one leg behind you and rest your foot on the Stufe,either on your instep or the Ball of your foot, whichever you find most comfortable. Keep your supporting Knie slightly bent and avoid letting that Knie...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Gastrocnemius Calf Stretch',
    description: 'Place your right heel on a step with your knee extended and lean forward to grab your right toe with your right hand. Your left knee should be slightly bent and your back should be straight. Support your weight on your left leg and place your left hand on your left thigh. Pull your right toes toward your knee until you feel a stretch in your calf.',
    nameDe: 'Stehend Gastrocnemius Wade Dehnung',
    descriptionDe: 'Place your right heel on a Stufe with your Knie extended and lean forward to grab your right toe with your right hand. Your left Knie should be slightly bent and your Rücken should be straight. Support your weight on your left leg and place your left hand on your left Oberschenkel. Pull your right...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Hamstring and Calf Stretch',
    description: 'Being by looping a belt, band, or rope around one foot. While standing, place that foot forward. Bend your back leg, while keeping the front one straight. Now raise the toes of your front foot off of the ground and lean forward. Using the belt, pull on the top of the foot to increase the stretch in the calf. Hold for 10-20 seconds and repeat with the other foot.',
    nameDe: 'Stehend Oberschenkelrückseite and Wade Dehnung',
    descriptionDe: 'Being by looping a belt, Band, or Seil around one foot. While Stehend, place that foot forward. Bend your Rücken leg, while keeping the front one straight. Now Heben the toes of your front foot off of the ground and lean forward. Using the belt, pull on the top of the foot to increase the Dehnung...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Hip Circles',
    description: 'Begin standing on one leg, holding to a vertical support. Raise the unsupported knee to 90 degrees. This will be your starting position. Open the hip as far as possible, attempting to make a big circle with your knee. Perform this movement slowly for a number of repetitions, and repeat on the other side.',
    nameDe: 'Stehend Hüfte Circles',
    descriptionDe: 'Begin Stehend on one leg, holding to a Vertikal support. Heben the unsupported Knie to 90 degrees. This will be your starting position. Open the Hüfte as far as possible, attempting to make a big circle with your Knie. Perform this movement slowly for a number of repetitions, and repeat on the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Hip Flexors',
    description: 'Stand up straight with the spine vertical, the left foot slightly in front of the right. Bend both knees and lift the back heel off the floor as you press the right hip forward. You can\'t get a thorough, deep stretch in this position, however, because it\'s hard to relax the hip flexor and stand on it at the same time. Switch sides.',
    nameDe: 'Stehend Hüfte Flexors',
    descriptionDe: 'Stand up straight with the Wirbelsäule Vertikal, the left foot slightly in front of the right. Bend both knees and lift the Rücken heel off the Boden as you Drücken the right Hüfte forward. You can\'t get a thorough, deep Dehnung in this position, however, because it\'s hard to relax the Hüfte flexor...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Lateral Stretch',
    description: 'Take a slightly wider than hip distance stance with your knees slightly bent. Place your right hand on your right hip to support the spine. Raise your left arm in a vertical line and place your left hand behind your head. Keep it there as you incline your torso to the right. Keep your weight evenly distributed between both legs (don\'t lean into your left hip). Switch sides.',
    nameDe: 'Stehend Seitlich Dehnung',
    descriptionDe: 'Take a slightly wider than Hüfte distance stance with your knees slightly bent. Place your right hand on your right Hüfte to support the Wirbelsäule. Heben your left arm in a Vertikal line and place your left hand behind your Kopf. Keep it there as you Schrägbank your torso to the right. Keep your...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Standing Pelvic Tilt',
    description: 'Start off with your feet hip-distance apart. Bend your knees slightly to keep them soft and springy. You may want to move your pelvis forward and backward and back few times before holding the tailbone forward in this stretch.',
    nameDe: 'Stehend Pelvic Tilt',
    descriptionDe: 'Start off with your feet Hüfte-distance apart. Bend your knees slightly to keep them soft and springy. You may want to move your pelvis forward and backward and Rücken few times before holding the tailbone forward in this Dehnung.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Standing Soleus And Achilles Stretch',
    description: 'Stand with your feet hip-distance apart, one foot slightly in front of the other. Bend both knees, keeping your back heel on the floor. Switch sides.',
    nameDe: 'Stehend Soleus And Achilles Dehnung',
    descriptionDe: 'Stand with your feet Hüfte-distance apart, one foot slightly in front of the other. Bend both knees, keeping your Rücken heel on the Boden. Switch sides.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Standing Toe Touches',
    description: 'Stand with some space in front and behind you. Bend at the waist, keeping your legs straight, until you can relax and let your upper body hang down in front of you. Let your arms and hands hang down naturally. Hold for 10 to 20 seconds.',
    nameDe: 'Stehend Toe Touches',
    descriptionDe: 'Stand with some space in front and behind you. Bend at the waist, keeping your legs straight, until you can relax and let your Oberer body hang down in front of you. Let your arms and hands hang down naturally. Hold for 10 to 20 seconds.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Stomach Vacuum',
    description: 'To begin, stand straight with your feet shoulder width apart from each other. Place your hands on your hips. This is the starting position. Now slowly inhale as much air as possible and then start to exhale as much as possible while bringing your stomach in as much as possible and hold this position. Try to visualize your navel touching your backbone. One isometric contraction is around 20...',
    nameDe: 'Stomach Vacuum',
    descriptionDe: 'To begin, stand straight with your feet Schulter width apart from each other. Place your hands on your Hüften. This is the starting position. Now slowly inhale as much Luft as possible and then start to exhale as much as possible while bringing your stomach in as much as possible and hold this...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Superman',
    description: 'To begin, lie straight and face down on the floor or exercise mat. Your arms should be fully extended in front of you. This is the starting position. Simultaneously raise your arms, legs, and chest off of the floor and hold this contraction for 2 seconds. Tip: Squeeze your lower back to get the best results from this exercise. Remember to exhale during this movement. Note: When holding the...',
    nameDe: 'Superman',
    descriptionDe: 'To begin, lie straight and face down on the Boden or exercise mat. Your arms should be fully extended in front of you. This is the starting position. Simultaneously Heben your arms, legs, and Brust off of the Boden and hold this contraction for 2 seconds. Tip: Squeeze your Unterer Rücken to get the...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'The Straddle',
    description: 'Begin in a seated, upright position. Start by extending your legs in front of you in a V. With your hands on the floor, lean forward as far as possible. Hold for 10 to 20 seconds.',
    nameDe: 'The Straddle',
    descriptionDe: 'Begin in a Sitzend, Aufrecht position. Start by extending your legs in front of you in a V. With your hands on the Boden, lean forward as far as possible. Hold for 10 to 20 seconds.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Toe Touchers',
    description: 'To begin, lie down on the floor or an exercise mat with your back pressed against the floor. Your arms should be lying across your sides with the palms facing down. Your legs should be touching each other. Slowly elevate your legs up in the air until they are almost perpendicular to the floor with a slight bend at the knees. Your feet should be parallel to the floor. Move your arms so that they...',
    nameDe: 'Toe Touchers',
    descriptionDe: 'To begin, lie down on the Boden or an exercise mat with your Rücken pressed against the Boden. Your arms should be Liegend across your sides with the palms facing down. Your legs should be touching each other. Slowly elevate your legs up in the Luft until they are almost perpendicular to the Boden...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Torso Rotation',
    description: 'Stand upright holding an exercise ball with both hands. Extend your arms so the ball is straight out in front of you. This will be your starting position. Rotate your torso to one side, keeping your eyes on the ball as you move. Now, rotate back to the opposite direction. Repeat for 10-20 repetitions.',
    nameDe: 'Torso Rotation',
    descriptionDe: 'Stand Aufrecht holding an Trainingsball with both hands. Extend your arms so the Ball is straight out in front of you. This will be your starting position. Rotate your torso to one side, keeping your eyes on the Ball as you move. Now, rotate Rücken to the opposite direction. Repeat for 10-20...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.abs],
  ),

  Exercise(
    name: 'Tricep Side Stretch',
    description: 'Bring right arm across your body and over your left shoulder, holding your elbow with your left hand, until you feel a stretch in your tricep. Then repeat for your other arm.',
    nameDe: 'Trizeps Side Dehnung',
    descriptionDe: 'Bring right arm across your body and over your left Schulter, holding your elbow with your left hand, until you feel a Dehnung in your Trizeps. Then repeat for your other arm.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Triceps Stretch',
    description: 'Reach your hand behind your head, grasp your elbow and gently pull. Hold for 10 to 20 seconds, then switch sides.',
    nameDe: 'Trizeps Dehnung',
    descriptionDe: 'Reach your hand behind your Kopf, grasp your elbow and gently pull. Hold for 10 to 20 seconds, then switch sides.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.triceps],
  ),

  Exercise(
    name: 'Upper Back-Leg Grab',
    description: 'While seated, bend forward to hug your thighs from underneath with both arms. Keep your knees together and your legs extended out as you bring your chest down to your knees. You can also stretch your middle back by pulling your back away from your knees as your hugging them.',
    nameDe: 'Oberer Rücken-Leg Grab',
    descriptionDe: 'While Sitzend, bend forward to hug your thighs from underneath with both arms. Keep your knees together and your legs extended out as you bring your Brust down to your knees. You can also Dehnung your middle Rücken by pulling your Rücken away from your knees as your hugging them.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Upper Back Stretch',
    description: 'Clasp fingers together with your thumbs pointing down, round your shoulders as you reach your hands forward.',
    nameDe: 'Oberer Rücken Dehnung',
    descriptionDe: 'Clasp fingers together with your thumbs pointing down, round your Schultern as you reach your hands forward.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.back],
  ),

  Exercise(
    name: 'Upward Stretch',
    description: 'Extend both hands straight above your head, palms touching. Slowly push your hands up and back, keeping your back straight.',
    nameDe: 'Upward Dehnung',
    descriptionDe: 'Extend both hands straight above your Kopf, palms touching. Slowly push your hands up and Rücken, keeping your Rücken straight.',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.shoulders],
  ),

  Exercise(
    name: 'Windmills',
    description: 'Lie on your back with your arms extended out to the sides and your legs straight. This will be your starting position. Lift one leg and quickly cross it over your body, attempting to touch the ground near the opposite hand. Return to the starting position, and repeat with the opposite leg. Continue to alternate for 10-20 repetitions.',
    nameDe: 'Windmills',
    descriptionDe: 'Lie on your Rücken with your arms extended out to the sides and your legs straight. This will be your starting position. Lift one leg and quickly Überkreuz it over your body, attempting to touch the ground near the opposite hand. Return to the starting position, and repeat with the opposite leg....',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'World\'s Greatest Stretch',
    description: 'This is a three-part stretch. Begin by lunging forward, with your front foot flat on the ground and on the toes of your back foot. With your knees bent, squat down until your knee is almost touching the ground. Keep your torso erect, and hold this position for 10-20 seconds. Now, place the arm on the same side as your front leg on the ground, with the elbow next to the foot. Your other hand...',
    nameDe: 'World\'s Greatest Dehnung',
    descriptionDe: 'This is a three-part Dehnung. Begin by lunging forward, with your front foot Flachbank on the ground and on the toes of your Rücken foot. With your knees bent, Kniebeuge down until your Knie is almost touching the ground. Keep your torso erect, and hold this position for 10-20 seconds. Now, place...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.legs],
  ),

  Exercise(
    name: 'Wrist Circles',
    description: 'Start by standing straight with your feet being shoulder width apart from each other. Elevate your arms to the side of you until they are fully extended and parallel to the floor at a height that is evenly aligned with your shoulders. Tip: Your torso and arms should form the letter "T: Your palms should be facing down. This is the starting position. Keeping your entire body stationary except for...',
    nameDe: 'Handgelenk Circles',
    descriptionDe: 'Start by Stehend straight with your feet being Schulter width apart from each other. Elevate your arms to the side of you until they are fully extended and parallel to the Boden at a height that is evenly aligned with your Schultern. Tip: Your torso and arms should form the letter "T: Your palms...',
    type: ExerciseType.flexibility,
    targetMuscleGroups: [MuscleGroup.biceps],
  ),

];
