import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/network/secure_token_storage.dart';
import 'package:ForgeForm/core/network/services/sync_service.dart';
import 'package:ForgeForm/core/network/token_refresh_service.dart';
import 'package:ForgeForm/core/seed_exercises.dart';
import 'package:ForgeForm/core/seed_verified_foods.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/view/login_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:workmanager/workmanager.dart';
import 'core/di/service_locator.dart';
import 'core/services/notification_service.dart';
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
import 'feature/trainer_console/presentation/view/trainer_dashboard_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'feature/auth/presentation/view/reset_password_screen.dart';
import 'feature/onboarding/onboarding_screen.dart';
import 'core/providers/access_provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

const _backgroundSyncTask = 'com.forgeform.dailySync';

/// Top-level so both [MyApp]'s [MaterialApp] and the auth-expired listener
/// registered in [main] can reach the active [NavigatorState].
final navigatorKey = GlobalKey<NavigatorState>();

/// Top-level callback required by workmanager — runs in a separate isolate.
@pragma('vm:entry-point')
void _backgroundSyncDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _backgroundSyncTask) return true;

    final token = await SecureTokenStorage.getToken();
    if (token == null) return true; // not logged in, nothing to sync

    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(serverUrlPrefsKey) ?? serverUrlDefault;

    // Background isolate has its own memory — re-initialise the locator and db.
    setupLocator();
    final db = AppDatabase();
    registerDatabase(db);

    final syncService = SyncService(
      db: db,
      // allowTokenRefresh: false — this isolate has its own TokenRefreshService
      // instance, isolated from the foreground app's. Letting it refresh
      // independently can race the foreground refresh and trip the server's
      // token-reuse detection, which revokes the whole session. If the access
      // token is stale, just let this sync fail silently; the foreground app
      // refreshes normally on its own next launch/request.
      apiClient: ApiClient(baseUrl: serverUrl, allowTokenRefresh: false),
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
  FlutterNativeSplash.preserve(
    widgetsBinding: WidgetsFlutterBinding.ensureInitialized(),
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await initializeDateFormatting();
  setupLocator();
  await sl<NotificationService>().init();
  final db = AppDatabase();

  // Register the database instance with the service locator
  registerDatabase(db);

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);

  // Load settings and latest weight before runApp so providers start with correct values.
  final userSettings = await db.userSettingsDao.getSettings();
  final initialTheme =
      userSettings?.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  final localeCode = prefs.getString('app_locale');
  final initialLocale = localeCode != null ? Locale(localeCode) : null;
  final latestWeight = await db.weightRecordDao.getLatestWeightRecord();

  // Awaited so the verified-food table is fully seeded before the UI (and
  // any search) can run against it. The version gate makes this a no-op
  // after the first launch on a given seed version.
  await seedExercisesIfEmpty(db);
  await seedVerifiedFoodsIfNeeded(db);

  // Always apply the compile-time default so changing the IP in code takes effect immediately.
  await prefs.setString(serverUrlPrefsKey, serverUrlDefault);
  final container = ProviderContainer(
    overrides: [serverUrlProvider.overrideWith((ref) => serverUrlDefault)],
  );
  await container.read(authProvider.notifier).restoreSession();

  // If a silent token refresh later fails mid-session (refresh token expired
  // or revoked), reset auth state and drop back to the login screen from
  // wherever the user currently is.
  TokenRefreshService.instance.onAuthExpired.listen((_) {
    container.read(authProvider.notifier).logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  });

  // Initialize premium / trainer-client access for already-logged-in users.
  final accessProvider = AccessProvider();
  final restoredAuth = container.read(authProvider);
  if (restoredAuth.user != null) {
    // Ensure last_logged_in_user is always set so the login-time user-switch
    // detection never incorrectly wipes data for an existing session.
    await prefs.setString('last_logged_in_user', restoredAuth.user!.username);
    unawaited(
      accessProvider.initialize(
        userId: restoredAuth.user!.username,
        serverBaseUrl: serverUrlDefault,
        bearerToken: restoredAuth.user!.token,
      ),
    );
  }

  // Register the once-a-day background sync task (mobile only).
  if (!kIsWeb) {
    await Workmanager().initialize(_backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      _backgroundSyncTask,
      _backgroundSyncTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy:
          ExistingPeriodicWorkPolicy
              .keep, // don't reset the 24-h clock on every launch
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
  FlutterNativeSplash.remove();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: provider.MultiProvider(
        providers: [
          // Provide the AppDatabase instance directly
          provider.Provider<AppDatabase>.value(value: db),
          provider.ChangeNotifierProvider(
            create: (_) => ThemeProvider(db, initialTheme: initialTheme),
          ),
          provider.ChangeNotifierProvider(
            create: (_) => LocaleProvider(initialLocale: initialLocale),
          ),
          provider.ChangeNotifierProvider(
            create:
                (_) => UserGoalsProvider(
                  db,
                  initialSettings: userSettings,
                  initialCurrentWeight: latestWeight?.weight,
                ),
          ),
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
        child: MyApp(
          showOnboarding: showOnboarding,
          // Use the post-restoreSession() state, not the raw pre-check
          // snapshot — restoreSession() may have cleared an expired token
          // (or refreshed it), so this must reflect the outcome, not the
          // token's mere presence before that ran.
          hasToken: restoredAuth.user != null,
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool showOnboarding;
  final bool hasToken;

  const MyApp({
    super.key,
    required this.showOnboarding,
    required this.hasToken,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<Uri>? _linkSub;
  String? _pendingResetToken;

  @override
  void initState() {
    super.initState();
    _handleInitialLink();
    _linkSub = AppLinks().uriLinkStream.listen(_handleDeepLink);
  }

  Future<void> _handleInitialLink() async {
    final uri = await AppLinks().getInitialLink();
    if (uri == null) return;
    _handleDeepLink(uri);
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'forgeform' || uri.host != 'reset-password') return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;

    _pendingResetToken = token;
    _tryNavigateToReset();
  }

  void _tryNavigateToReset() {
    final token = _pendingResetToken;
    if (token == null) return;
    final nav = navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryNavigateToReset());
      return;
    }
    _pendingResetToken = null;
    nav.push(MaterialPageRoute(builder: (_) => ResetPasswordScreen(token: token)));
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = provider.Provider.of<ThemeProvider>(context);
    final localeProvider = provider.Provider.of<LocaleProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
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
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: child!,
        );
      },
      home:
          widget.showOnboarding
              ? const OnboardingScreen()
              : widget.hasToken
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

        // TODO: gate behind AccessProvider.isTrainer once there's a real
        // nav entry point (e.g. a "Trainer Console" item in Settings for
        // users where isTrainer is true) instead of a bare route.
        if (settings.name == '/trainer-console') {
          return MaterialPageRoute(
            builder: (_) => const TrainerDashboardScreen(),
          );
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
    );
  }

  Future<void> _runInitialSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncMs = prefs.getInt('last_sync_timestamp');
    if (lastSyncMs != null) {
      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      if (DateTime.now().difference(lastSync) < const Duration(hours: 6)) {
        return;
      }
    }

    final token = await SecureTokenStorage.getToken();
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
