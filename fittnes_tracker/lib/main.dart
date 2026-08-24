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
import 'core/widgets/lazy_indexed_stack.dart';
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
import 'feature/trainer_console/presentation/view/trainer_console_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'feature/auth/presentation/view/reset_password_screen.dart';
import 'feature/onboarding/profile_setup_prefs.dart';
import 'feature/onboarding/profile_setup_screen.dart';
import 'feature/onboarding/welcome_screen.dart';
import 'core/providers/access_provider.dart';
import 'feature/premium/paywall_launcher.dart';
import 'feature/trainer_console/presentation/widgets/licence_banner.dart';
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
  // Only the locales we actually support — the no-argument form initialises
  // every locale's date symbols, which is a large chunk of the startup budget.
  await Future.wait([
    initializeDateFormatting('en'),
    initializeDateFormatting('de'),
  ]);
  setupLocator();
  // NotificationService is *not* initialised here. It loads the timezone
  // database and used to raise the Android 13+ permission dialog, which blocks
  // on the user's tap — a first launch sat on the splash until they answered.
  // It now initialises itself on first use.
  final db = AppDatabase();

  // Register the database instance with the service locator
  registerDatabase(db);

  // Independent of each other, so opened together rather than in series. Both
  // queries go through the same drift connection, which serialises internally.
  final (prefs, userSettings, latestWeight) = await (
    SharedPreferences.getInstance(),
    db.userSettingsDao.getSettings(),
    db.weightRecordDao.getLatestWeightRecord(),
  ).wait;

  // Loaded before runApp so providers start with correct values.
  final initialTheme =
      userSettings?.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  final localeCode = prefs.getString('app_locale');
  final initialLocale = localeCode != null ? Locale(localeCode) : null;

  // Awaited: the version gate makes this a single prefs read after the first
  // launch on a given seed version, and keeping it ahead of the UI guarantees
  // SyncService can never match server exercises against a half-filled table.
  await seedExercisesIfEmpty(db);
  // Not awaited: seeding decodes a 1.2 MB asset, and nothing on the dashboard
  // reads verified foods. Food search falls back to OpenFoodFacts results if
  // it runs before this lands, which can only happen on a first launch.
  unawaited(seedVerifiedFoodsIfNeeded(db));

  // Always apply the compile-time default so changing the IP in code takes
  // effect immediately. Not awaited — the returned future is the disk write,
  // and the in-memory value is updated before it completes.
  unawaited(prefs.setString(serverUrlPrefsKey, serverUrlDefault));
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
    unawaited(
      prefs.setString('last_logged_in_user', restoredAuth.user!.username),
    );
    unawaited(
      accessProvider.initialize(
        userId: restoredAuth.user!.username,
        serverBaseUrl: serverUrlDefault,
        bearerToken: restoredAuth.user!.token,
      ),
    );
  }

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
          // Use the post-restoreSession() state, not the raw pre-check
          // snapshot — restoreSession() may have cleared an expired token
          // (or refreshed it), so this must reflect the outcome, not the
          // token's mere presence before that ran.
          hasToken: restoredAuth.user != null,
        ),
      ),
    ),
  );

  // Everything below is deferred until the first frame is up: none of it is
  // needed to paint the dashboard, and the WorkManager calls in particular are
  // platform-channel round trips into a scheduler that does its own disk work.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Removed here rather than before runApp — doing it earlier tore the splash
    // down before Flutter had drawn anything, leaving a blank window for the
    // whole first-frame build.
    FlutterNativeSplash.remove();
    unawaited(_registerBackgroundSync());
  });
}

/// Registers the once-a-day background sync task (mobile only).
Future<void> _registerBackgroundSync() async {
  if (kIsWeb) return;
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

class MyApp extends StatefulWidget {
  final bool hasToken;

  const MyApp({
    super.key,
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
      // Signed out, the welcome screen *is* the home — it carries both Sign in
      // and Create account, so there's no flag deciding whether to show it.
      // Web goes straight to login instead: that surface is the Trainer
      // Console, and a consumer pitch for calorie tracking has no place in
      // front of it.
      home:
          widget.hasToken
              ? const PostAuthHome()
              : kIsWeb
              ? const LoginScreen()
              : const WelcomeScreen(),

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

        // Pushed from Settings (trainers only) — the gate re-checks the role
        // itself so a deep link can't bypass the entry point. No
        // onExitConsole: this is a pushed route, so back already returns to
        // the trainee app.
        if (settings.name == '/trainer-console') {
          return MaterialPageRoute(builder: (_) => const TrainerConsoleGate());
        }

        return MaterialPageRoute(builder: (_) => const HomeScreen());
      },
    );
  }
}

/// Where an authenticated user lands: a trainer gets the console, everyone
/// else the trainee app.
///
/// This is deliberately the *only* place that decision is made. Cold start,
/// login and register each used to push [HomeScreen] directly, which meant a
/// trainer signing in on the web was dropped into the trainee app instead of
/// the console — the landing logic only ever ran on a cold start with an
/// existing token.
///
/// The decision is the *role*, not the platform. It used to short-circuit on
/// `!kIsWeb`, on the reasoning that off the web the console is reached from
/// Settings — which quietly meant a trainer registering on a phone or desktop
/// landed on the trainee dashboard and had to go find the console. Settings
/// still offers it; it is no longer the only way in.
///
/// Stateful only to hold the "I chose to look at my own training" flag — a
/// trainer is also a ForgeForm user, so leaving the console has to be possible
/// without signing out.
class PostAuthHome extends StatefulWidget {
  const PostAuthHome({super.key});

  @override
  State<PostAuthHome> createState() => _PostAuthHomeState();
}

class _PostAuthHomeState extends State<PostAuthHome> {
  bool _showTraineeApp = false;

  Widget _home() {
    if (_showTraineeApp) return const HomeScreen();
    return TrainerConsoleGate(
      // Everyone who isn't a trainer gets the normal app rather than a
      // "trainer access only" wall — the gate is the router here, not a bouncer.
      fallback: const HomeScreen(),
      onExitConsole: () => setState(() => _showTraineeApp = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSetupGate(
      userId: _currentUserId(context),
      onDone: (_) => _home(),
    );
  }
}

/// Sends a trainee who hasn't set up their profile through it once, then hands
/// over to [onDone].
///
/// Two conditions have to be met before showing it, and both matter:
///
/// * The role must actually be resolved. `AccessProvider.initialized` flips as
///   soon as *cached* flags load, and on a first sign-in there is no cache — so
///   gating on that alone would flash the trainee questionnaire at a trainer.
/// * The user must not be a trainer. If the role can't be resolved at all
///   (offline, no cache) the setup is skipped rather than risked: asking a
///   trainer for their goal weight is worse than a trainee setting goals later
///   in Settings, and they'll be prompted on the next launch that has network.
class ProfileSetupGate extends StatefulWidget {
  /// Account to check, or null when there's no signed-in user to key the
  /// completion flag on. Passed in rather than read here so the gate has no
  /// dependency on how auth is stored.
  final String? userId;
  final WidgetBuilder onDone;

  const ProfileSetupGate({super.key, required this.userId, required this.onDone});

  @override
  State<ProfileSetupGate> createState() => _ProfileSetupGateState();
}

class _ProfileSetupGateState extends State<ProfileSetupGate> {
  String? _checkedUserId;
  bool? _needsSetup;

  Future<void> _check(String userId, bool isTrainer) async {
    final complete = await ProfileSetupPrefs.isComplete(userId);
    if (!mounted) return;
    setState(() => _needsSetup = !complete && !isTrainer);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final userId = widget.userId;

    // No signed-in user id to key completion on, or the role is still in
    // flight: fall through rather than guess.
    if (userId == null || !access.roleResolved) return widget.onDone(context);

    if (_checkedUserId != userId) {
      _checkedUserId = userId;
      _needsSetup = null;
      // Deferred: this runs during build.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _check(userId, access.isTrainer),
      );
    }

    if (_needsSetup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_needsSetup!) return widget.onDone(context);

    return ProfileSetupScreen(userId: userId, onDone: widget.onDone);
  }
}

/// The signed-in user's id, or null if there isn't one. Read rather than
/// watched: the gate already rebuilds on AccessProvider changes, and auth
/// state cannot change underneath a signed-in user without a full remount.
String? _currentUserId(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false)
        .read(authProvider)
        .user
        ?.username;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Builders rather than widgets: LazyIndexedStack mounts a tab the first time
  // it is selected. Building all five up front meant every tab ran its
  // initState database loads on the first frame — the Progress tab's
  // history-wide aggregate query included — while the dashboard waited behind
  // them for the drift connection.
  static final List<WidgetBuilder> _screenBuilders = [
    (_) => DashboardScreen(key: globalDashboardKey),
    (_) => FoodTrackingScreen(key: globalFoodTrackingKey),
    (_) => const GymTrackingScreen(),
    (_) => ProgressScreen(key: globalProgressKey),
    (_) => const SettingsScreen(),
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
    // DashboardScreen lives inside an IndexedStack and isn't rebuilt just by
    // switching tabs, so nutrition/workout edits made on other tabs would
    // otherwise never be reflected here — force a reload on every visit.
    if (index == 0) {
      globalDashboardKey.currentState?.refresh();
    } else if (index == 3) {
      globalProgressKey.currentState?.reloadNutritionData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // A trainee's Pro can stop because their *trainer* stopped paying.
          // They did nothing wrong, so they get told before a feature locks
          // rather than discovering it when one refuses to open.
          const _TraineeProNotice(),
          Expanded(
            child: LazyIndexedStack(
              index: _selectedIndex,
              builders: _screenBuilders,
            ),
          ),
        ],
      ),
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


/// Warns a trainee that the Pro they get through their trainer is ending, and
/// offers them a way to keep it. Dismissible, and silent whenever nothing is
/// actually expiring.
class _TraineeProNotice extends StatefulWidget {
  const _TraineeProNotice();

  @override
  State<_TraineeProNotice> createState() => _TraineeProNoticeState();
}

class _TraineeProNoticeState extends State<_TraineeProNotice> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    if (_dismissed || !access.proIsLapsing) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: TraineeProLapsingBanner(
                endsAt: access.proEndsAt!,
                onSeePlans: () => openPaywall(context),
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.dismiss,
              onPressed: () => setState(() => _dismissed = true),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
