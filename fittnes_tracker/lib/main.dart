import 'package:ForgeForm/core/app_database.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ForgeForm/core/app_router.dart';
import 'package:go_router/go_router.dart';
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
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart' as provider;
import 'package:workmanager/workmanager.dart';
import 'core/di/service_locator.dart';
import 'core/widgets/forge_nav_bar.dart';
import 'core/widgets/lazy_indexed_stack.dart';
import 'core/services/chat_push_decoder.dart';
import 'core/services/notification_service.dart';
import 'core/services/push_service.dart';
import 'feature/chat/data/chat_key_store.dart';
import 'feature/chat/presentation/view/coach_chat_entry.dart';
import 'feature/trainer_console/presentation/widgets/trainer_console_shell.dart';
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
import 'feature/settings/settings_screen.dart';
import 'feature/trainer_console/presentation/view/trainer_console_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'feature/auth/presentation/view/reset_password_screen.dart';
import 'feature/onboarding/profile_setup_prefs.dart';
import 'feature/onboarding/profile_setup_screen.dart';
import 'core/providers/access_provider.dart';
import 'feature/premium/paywall_launcher.dart';
import 'feature/trainer_console/presentation/widgets/licence_banner.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

const _backgroundSyncTask = 'com.forgeform.dailySync';

/// Top-level so both [MyApp]'s [MaterialApp] and the auth-expired listener
/// registered in [main] can reach the active [NavigatorState].
/// Kept as an alias so the auth-expiry and deep-link paths below read the
/// same as before; the key itself is owned by the router.
final navigatorKey = AppRouter.navigatorKey;

/// The root Riverpod container, assigned once in [main].
late final ProviderContainer rootContainer;

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
  // Real paths rather than #-fragment URLs. Without this the console's
  // sections would be bookmarkable only as `/#/console/nutrition`, which is
  // not a URL anyone would paste to a colleague. The static host already
  // rewrites unknown paths to /index.html (CLAUDE.md, "Web support"), which
  // is the server-side half of this working.
  usePathUrlStrategy();

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
  //
  // Push is started here but deliberately *not* awaited, for the same reason:
  // its init() asks for the notification permission. A cold-start notification
  // tap is still delivered — getInitialMessage() holds it until we ask, and
  // _openChatFor retries until the navigator exists.
  unawaited(_startPushNotifications());
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
  // Held globally so the router's redirect can read auth state: a redirect
  // runs before any of this app's widgets, so it has no BuildContext to look
  // the container up from.
  rootContainer = container;
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
    // The third path that establishes a session, alongside login and register.
    // Re-registering every launch is also what keeps a rotated FCM token current.
    unawaited(sl<PushService>().registerForCurrentUser());
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

/// Runs in a separate isolate when a push arrives with the app backgrounded.
///
/// Must be a top-level function and must carry `@pragma('vm:entry-point')`, or
/// tree-shaking removes it from the release build and background pushes silently
/// stop working — in release only, which is the worst possible place to find out.
///
/// This used to be empty, and the comment here used to explain why: the payload
/// was a `notification` message and the OS had already drawn it. Chat is
/// end-to-end encrypted now, so the server cannot write a notification for a
/// message it cannot read, and the payload is data-only. Drawing it is this
/// function's job.
///
/// **Nothing from the running app is available here.** A background isolate
/// starts empty: no service locator, no open database, no providers, no widget
/// tree. Everything below either reads the platform keystore or constructs what
/// it needs on the spot. See docs/chat-encryption.md.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'chat_message') return;

  // Required before any Firebase API is touched in this isolate — it has none
  // of the initialisation main() did.
  await Firebase.initializeApp();

  final content = await decodeChatPush(message.data, allowNetwork: false);

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
  );

  await presentChatNotification(
    plugin: plugin,
    title: content.title,
    body: content.body,
    threadId: content.threadId,
  );
}

/// Brings push up off the startup path.
///
/// Separated from `main()` so it can be started and not awaited: `init()` asks
/// for the notification permission, and blocking a first launch on that dialog
/// is exactly the splash-screen stall NotificationService was changed to avoid.
Future<void> _startPushNotifications() async {
  final push = sl<PushService>();
  await push.init();

  // Guarded, because "unavailable" is the *normal* state in three situations:
  // on web, on any machine without android/app/google-services.json, and in
  // every CI build. Wiring up regardless means calling
  // FirebaseMessaging.onBackgroundMessage against an uninitialised Firebase,
  // which throws -- inside an unawaited future, so it surfaces as an unhandled
  // async error rather than anything that points at the cause.
  if (!push.isAvailable) return;

  _wirePushNotifications();
}

/// Connects the two ways a chat notification can be tapped to the one place that
/// knows how to navigate.
void _wirePushNotifications() {
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  final push = sl<PushService>();
  final notifications = sl<NotificationService>();

  // Foreground: the OS does not display a notification for an app that is
  // already open, so if this device is not on the relevant screen we draw one
  // ourselves. A user staring at the thread gets nothing extra -- the bubble and
  // the tab badge already told them.
  FirebaseMessaging.onMessage.listen((message) {
    if (message.data['type'] != 'chat_message') return;

    // Read out of `data`, not `notification`. There is no notification block on
    // a chat push any more: the server sends ciphertext and this device is the
    // only thing that can turn it into words. The old `if (notification == null)
    // return` guard would now drop every chat notification there is.
    unawaited(() async {
      final content = await decodeChatPush(message.data, allowNetwork: true);
      await notifications.showChatMessage(
        title: content.title,
        body: content.body,
        threadId: content.threadId,
      );
    }());
  });

  // A tap on one we drew ourselves comes back through the plugin instead of
  // through FCM, so it is funnelled into the same stream.
  notifications.onChatNotificationTap = push.handleLocalTap;

  push.onNotificationTap.listen(_openChatFor);
}

/// Opens the right chat surface for a tapped notification.
///
/// Which surface depends on the role, and neither is addressable by route name:
/// a trainee has exactly one thread and reads it from AccessProvider, while a
/// trainer needs the console opened on its Messages tab. Deep-linking to one
/// specific conversation inside the console inbox is deliberately out of scope --
/// landing on the inbox with the badge showing is enough to act on.
void _openChatFor(ChatNotificationTarget target) {
  final nav = navigatorKey.currentState;
  if (nav == null) {
    // Same retry the password-reset link uses: a tap that launched the app from
    // cold arrives before the navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openChatFor(target));
    return;
  }

  final context = nav.context;
  final isTrainer = provider.Provider.of<AccessProvider>(
    context,
    listen: false,
  ).isTrainer;

  nav.push(
    MaterialPageRoute(
      builder: (_) => isTrainer
          ? const TrainerConsoleGate(
              initialRoute: TrainerConsoleRoute.messages,
            )
          : const CoachChatEntry(),
    ),
  );
}

class _MyAppState extends State<MyApp> {
  // The callback reads the auth provider on every redirect rather than
  // capturing widget.hasToken, which is only true of the moment the app
  // started.
  late final GoRouter _router = AppRouter.build(
    isSignedIn: () =>
        rootContainer.read(authProvider).user != null || widget.hasToken,
  );

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

    return MaterialApp.router(
      routerConfig: _router,
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
  /// Which console section a deep link asked for. Null means "wherever the
  /// console starts by default" — a cold start at `/`.
  final TrainerConsoleRoute? initialConsoleRoute;

  const PostAuthHome({super.key, this.initialConsoleRoute});

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
      initialRoute:
          widget.initialConsoleRoute ?? TrainerConsoleRoute.dashboard,
      onExitConsole: () => setState(() => _showTraineeApp = true),
      // This instance is the one PostAuthHome mounted for the current
      // location ('/' or '/console/:section'), so it's the only console
      // instance allowed to rewrite the URL when the trainer switches
      // sections. See TrainerConsoleHome.syncUrl.
      syncUrl: true,
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

    // Publishes this device's chat key, if it hasn't been already -- not
    // conditional on ever opening Coach Chat. `CoachChatEntry` only builds a
    // `ChatRepository` (and its socket) when the trainee actually pushes that
    // route, on purpose: chat should not cost a permanent connection for
    // someone who never uses it. But a key that is only published on that same
    // trigger means a trainer's *first* message to a client who hasn't opened
    // chat yet has no key to encrypt to -- `WebCryptoChatCrypto.encrypt` throws
    // rather than send something unreadable, the send is left `pending`, and
    // nothing will ever revisit it until the client happens to open chat on
    // their own. `ensureRegistered` only talks to `api/chat/keys`, never the
    // hub, so registering it here costs a REST round trip and no socket -- the
    // trainee app's own equivalent of what `trainer_console_home.dart` already
    // does for the trainer side.
    unawaited(ChatKeyStore().ensureRegistered().catchError((Object _) {}));
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
      bottomNavigationBar: ForgeNavBar(
        selectedIndex: _selectedIndex,
        onSelected: _onTabTapped,
        destinations: [
          ForgeNavDestination(
            label: AppLocalizations.of(context)!.dashboard,
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
          ),
          ForgeNavDestination(
            label: AppLocalizations.of(context)!.food,
            icon: Icons.restaurant_outlined,
            activeIcon: Icons.restaurant_rounded,
          ),
          ForgeNavDestination(
            label: AppLocalizations.of(context)!.gym,
            icon: Icons.fitness_center_outlined,
            activeIcon: Icons.fitness_center_rounded,
          ),
          ForgeNavDestination(
            label: AppLocalizations.of(context)!.progress,
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
          ),
          ForgeNavDestination(
            label: AppLocalizations.of(context)!.profile,
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
          ),
        ],
      ),
    );
  }

  Future<void> _runInitialSync() async {
    final prefs = await SharedPreferences.getInstance();
    // The pull is throttled on its own key, not on last_sync_timestamp. The
    // background task stamps that one after a push-only sync, so a background
    // run that never downloaded anything used to suppress the foreground pull
    // for the next six hours — which is why data could take most of a day to
    // come back after signing in again.
    final lastPullMs = prefs.getInt(lastPullPrefsKey);
    if (lastPullMs != null) {
      final lastPull = DateTime.fromMillisecondsSinceEpoch(lastPullMs);
      if (DateTime.now().difference(lastPull) < const Duration(hours: 6)) {
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
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('last_sync_timestamp', now);
      await prefs.setInt(lastPullPrefsKey, now);
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
