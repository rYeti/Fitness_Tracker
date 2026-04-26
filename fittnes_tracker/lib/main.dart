import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
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
import 'package:workmanager/workmanager.dart';
import 'core/di/service_locator.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
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
import 'dart:async' show unawaited;
import 'feature/onboarding/onboarding_screen.dart';
import 'core/providers/access_provider.dart';

const _backgroundSyncTask = 'com.forgeform.dailySync';

/// Top-level callback required by workmanager — runs in a separate isolate.
@pragma('vm:entry-point')
void _backgroundSyncDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _backgroundSyncTask) return true;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return true; // not logged in, nothing to sync

    final serverUrl = prefs.getString(serverUrlPrefsKey) ?? serverUrlDefault;

    // Background isolate has its own memory — re-initialise the locator and db.
    setupLocator();
    final db = AppDatabase();
    registerDatabase(db);

    final syncService = SyncService(
      db: db,
      apiClient: ApiClient(baseUrl: serverUrl),
      mealTemplateDao: MealTemplateDao(db),
    );

    await syncService.syncAll();
    await prefs.setInt(
      'last_sync_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );

    return true;
  });
}

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

  final prefs = await SharedPreferences.getInstance();
  final hasToken = prefs.getString('token') != null;
  final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);

  // Load settings and latest weight before runApp so providers start with correct values.
  final userSettings = await db.userSettingsDao.getSettings();
  final initialTheme =
      userSettings?.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  final localeCode = prefs.getString('app_locale');
  final initialLocale = localeCode != null ? Locale(localeCode) : null;
  final latestWeight = await db.weightRecordDao.getLatestWeightRecord();

  // Run seeding in the background — no need to block the UI.
  seedExercisesIfEmpty(db);

  // Always apply the compile-time default so changing the IP in code takes effect immediately.
  await prefs.setString(serverUrlPrefsKey, serverUrlDefault);
  final container = ProviderContainer(
    overrides: [serverUrlProvider.overrideWith((ref) => serverUrlDefault)],
  );
  await container.read(authProvider.notifier).restoreSession();

  // Initialize premium / trainer-client access for already-logged-in users.
  final accessProvider = AccessProvider();
  final restoredAuth = container.read(authProvider);
  if (restoredAuth.user != null) {
    // Ensure last_logged_in_user is always set so the login-time user-switch
    // detection never incorrectly wipes data for an existing session.
    await prefs.setString('last_logged_in_user', restoredAuth.user!.username);
    unawaited(accessProvider.initialize(
      userId: restoredAuth.user!.username,
      serverBaseUrl: serverUrlDefault,
      bearerToken: restoredAuth.user!.token,
    ));
  }

  // Register the once-a-day background sync task.
  await Workmanager().initialize(_backgroundSyncDispatcher);
  await Workmanager().registerPeriodicTask(
    _backgroundSyncTask,
    _backgroundSyncTask,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep, // don't reset the 24-h clock on every launch
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: provider.MultiProvider(
        providers: [
          // Provide the AppDatabase instance directly
          provider.Provider<AppDatabase>.value(value: db),
          provider.ChangeNotifierProvider(create: (_) => ThemeProvider(db, initialTheme: initialTheme)),
          provider.ChangeNotifierProvider(create: (_) => LocaleProvider(initialLocale: initialLocale)),
          provider.ChangeNotifierProvider(create: (_) => UserGoalsProvider(db, initialSettings: userSettings, initialCurrentWeight: latestWeight?.weight)),
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
          provider.ChangeNotifierProvider<AccessProvider>.value(
            value: accessProvider,
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
    final localeProvider = provider.Provider.of<LocaleProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    FoodTrackingScreen(key: globalFoodTrackingKey),
    const GymTrackingScreen(),
    ProgressScreen(key: globalProgressKey),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // If the OS killed the app while the user was mid-workout, jump straight
    // to the gym tab so ScheduledWorkoutsView can auto-resume the session.
    _switchToGymTabIfWorkoutInProgress();
    _runInitialSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runInitialSync();
    }
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
    final lastSyncMs = prefs.getInt('last_sync_timestamp');
    if (lastSyncMs != null) {
      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      if (DateTime.now().difference(lastSync) < const Duration(minutes: 15)) {
        return;
      }
    }

    final token = prefs.getString('token');
    if (token == null) return; // not logged in

    final serverUrl = prefs.getString(serverUrlPrefsKey) ?? serverUrlDefault;
    final db = sl<AppDatabase>();
    final syncService = SyncService(
      db: db,
      apiClient: ApiClient(baseUrl: serverUrl),
      mealTemplateDao: MealTemplateDao(db),
    );

    try {
      await syncService.syncAll();
      await syncService.pullAll();
      await prefs.setInt(
        'last_sync_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
      if (mounted) {
        globalFoodTrackingKey.currentState?.loadNutritionData();
        globalProgressKey.currentState?.reloadGymData();
        provider.Provider.of<WeightProvider>(context, listen: false).reload();
      }
    } catch (_) {
      // silent — no network or server down, try again next time
    }
  }
}
