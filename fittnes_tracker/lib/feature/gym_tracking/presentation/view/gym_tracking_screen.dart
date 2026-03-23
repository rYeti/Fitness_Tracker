import 'package:ForgeForm/feature/gym_tracking/presentation/providers/scheduled_workout_provider.dart';
import 'package:flutter/material.dart';
import 'scheduled_workouts_view.dart';
import 'package:provider/provider.dart';

class GymTrackingScreen extends StatefulWidget {
  const GymTrackingScreen({super.key});

  @override
  _GymTrackingScreen createState() => _GymTrackingScreen();
}

class _GymTrackingScreen extends State<GymTrackingScreen> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScheduleWorkoutProvider()),
      ],
      child: const ScheduledWorkoutsView(),
    );
  }
}
