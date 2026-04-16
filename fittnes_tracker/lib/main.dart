import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/network/services/sync_service.dart';
import 'package:ForgeForm/core/seed_exercises.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/view/login_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'core/di/service_locator.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/user_goals_provider.dart';
import 'feature/weight_tracking/presentation/providers/weight_provider.dart';
import 'feature/food_tracking/data/repositories/meal_template_repository.dart';
import 'feature/gym_tracking/presentation/providers/workout_provider.dart';
import 'feature/gym_tracking/presentation/view/gym_tracking_screen.dart';
import 'feature/food_tracking/presentation/view/food_tracking_screen.dart';
import 'feature/progress_dashboard_view.dart';
import 'feature/dashboard/view/dashboard_screen.dart';
import 'feature/food_tracking/presentation/view/food_add_screen.dart';
import 'feature/settings/settings_screen.dart';
import 'feature/weight_tracking/presentation/view/weight_tracking_screen.dart';
import 'feature/weight_tracking/presentation/view/weight_goal_screen.dart';
import 'feature/food_tracking/presentation/view/meal_templates_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feature/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await initializeDateFormatting();
  setupLocator();
  final db = AppDatabase();

  // Register the database instance with the service locator
  registerDatabase(db);

  // Seed exercises if database is empty
  await seedExercisesIfEmpty(db);

  final prefs = await SharedPreferences.getInstance();
  final hasToken = prefs.getString('token') != null;
  final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);

  // Always apply the compile-time default so a changed IP takes effect immediately.
  await prefs.setString(serverUrlPrefsKey, serverUrlDefault);
  final container = ProviderContainer(
    overrides: [serverUrlProvider.overrideWith((ref) => serverUrlDefault)],
  );
  await container.read(authProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: provider.MultiProvider(
        providers: [
          // Provide the AppDatabase instance directly
          provider.Provider<AppDatabase>.value(value: db),
          provider.ChangeNotifierProvider(create: (_) => ThemeProvider(db)),
          provider.ChangeNotifierProvider(create: (_) => UserGoalsProvider(db)),
          provider.ChangeNotifierProxyProvider<
            UserGoalsProvider,
            WeightProvider
          >(
            create:
                (context) => WeightProvider(
                  db,
                  userGoalsProvider: provider.Provider.of<UserGoalsProvider>(
                    context,
                    listen: false,
                  ),
                ),
            update:
                (context, userGoalsProvider, weightProvider) =>
                    weightProvider ??
                    WeightProvider(db, userGoalsProvider: userGoalsProvider),
          ),
          provider.Provider<MealTemplateRepository>(
            create: (_) => MealTemplateRepository(db),
          ),
          provider.ChangeNotifierProvider(
            create: (_) => WorkoutProvider()..loadTemplates(),
          ),
        ],
        child: MyApp(showOnboarding: showOnboarding, hasToken: hasToken),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  final bool hasToken;

  const MyApp({
    super.key,
    required this.showOnboarding,
    required this.hasToken,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = provider.Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      title: 'ForgeForm',
      home:
          showOnboarding
              ? const OnboardingScreen()
              : hasToken
              ? const HomeScreen()
              : const LoginScreen(),

      onGenerateRoute: (settings) {
        if (settings.name == '/add-food') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => FoodAddScreen(category: args['category']),
          );
        }

        if (settings.name == '/dashboard') {
          return MaterialPageRoute(builder: (_) => const DashboardScreen());
        }

        if (settings.name == '/settings') {
          return MaterialPageRoute(builder: (_) => const SettingsScreen());
        }

        if (settings.name == '/weight-tracking') {
          return MaterialPageRoute(
            builder: (_) => const WeightTrackingScreen(),
          );
        }

        if (settings.name == '/weight-goals') {
          return MaterialPageRoute(builder: (_) => const WeightGoalScreen());
        }

        if (settings.name == '/meal-templates') {
          return MaterialPageRoute(builder: (_) => const MealTemplatesScreen());
        }

        return MaterialPageRoute(builder: (_) => const HomeScreen());
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    FoodTrackingScreen(key: globalFoodTrackingKey),
    const GymTrackingScreen(),
    const ProgressScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // If the OS killed the app while the user was mid-workout, jump straight
    // to the gym tab so ScheduledWorkoutsView can auto-resume the session.
    _switchToGymTabIfWorkoutInProgress();
    _runInitialSync();
  }

  Future<void> _switchToGymTabIfWorkoutInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final hasActiveWorkout =
        prefs.getInt('active_workout_scheduled_id') != null;
    if (hasActiveWorkout && mounted) {
      setState(() => _selectedIndex = 2);
    }
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard),
              label: AppLocalizations.of(context)!.dashboard,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant),
              label: AppLocalizations.of(context)!.food,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: AppLocalizations.of(context)!.gym,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: AppLocalizations.of(context)!.progress,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              label: AppLocalizations.of(context)!.profile,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runInitialSync() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(serverUrlPrefsKey) ?? serverUrlDefault;

    final syncService = SyncService(
      db: sl<AppDatabase>(),
      apiClient: ApiClient(baseUrl: serverUrl),
    );

    await syncService.syncAll();
  }
}
