import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

// ── Configuration ────────────────────────────────────────────────────────────
// Replace with your RevenueCat public SDK keys from app.revenuecat.com
// (one per store — Android keys start with "goog_", iOS keys with "appl_").
const revenueCatApiKey = 'goog_bngAaflqXhTyOmLFSRWpMQnOQnW';
const revenueCatApiKeyIOS = '';

// The entitlement identifier set up in your RevenueCat dashboard.
const premiumEntitlementId = 'ForgeForm Pro';
const _premiumEntitlementId = premiumEntitlementId;

// SharedPreferences keys used to cache access state across cold starts.
const _prefIsPremium = 'access_is_premium';
const _prefIsTrainerClient = 'access_is_trainer_client';
const _prefIsTrainer = 'access_is_trainer';
// ─────────────────────────────────────────────────────────────────────────────

/// Aggregates premium status from RevenueCat purchases and the server-side
/// trainer–client relationship. Any widget can read [hasPremiumAccess] to gate
/// features — no knowledge of the source is needed.
class AccessProvider extends ChangeNotifier {
  AccessProvider();

  /// Builds a provider in a known state, so role-gated UI can be tested
  /// without RevenueCat or a live `api/TrainerClient/status`.
  @visibleForTesting
  AccessProvider.withState({
    bool isPremium = false,
    bool isTrainerClient = false,
    bool isTrainer = false,
    bool initialized = true,
    bool roleResolved = true,
  }) : _isPremium = isPremium,
       _isTrainerClient = isTrainerClient,
       _isTrainer = isTrainer,
       _initialized = initialized,
       _roleResolved = roleResolved;

  bool _isPremium = false;
  bool _isTrainerClient = false;
  bool _isTrainer = false;
  bool _initialized = false;
  bool _roleResolved = false;

  bool get isPremium => _isPremium;
  bool get isTrainerClient => _isTrainerClient;
  bool get isTrainer => _isTrainer;

  /// Whether the server has been asked about this user's role since launch.
  ///
  /// Distinct from [initialized], which flips as soon as the *cached* flags are
  /// restored — on a first sign-in there is no cache, so [isTrainer] is false
  /// until the network check lands. Anything that would treat a trainer as a
  /// trainee must wait for this, or it will briefly do the wrong thing.
  ///
  /// Set even when the check fails: offline, the cached answer is the best
  /// available and callers shouldn't hang forever waiting for better.
  bool get roleResolved => _roleResolved;

  /// True if the user has access to premium features from ANY source.
  bool get hasPremiumAccess => _isPremium || _isTrainerClient;

  bool get initialized => _initialized;

  /// Called once after the user successfully logs in (or session is restored).
  /// [userId] is the server UUID used as RevenueCat's appUserID so purchase
  /// history follows the account rather than the device.
  Future<void> initialize({
    required String userId,
    required String serverBaseUrl,
    required String bearerToken,
  }) async {
    // Restore cached values immediately so UI is correct while we re-check.
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_prefIsPremium) ?? false;
    _isTrainerClient = prefs.getBool(_prefIsTrainerClient) ?? false;
    _isTrainer = prefs.getBool(_prefIsTrainer) ?? false;
    _initialized = true;
    notifyListeners();

    // Re-check both sources in parallel.
    await Future.wait([
      _checkRevenueCat(userId),
      _checkTrainerClient(serverBaseUrl, bearerToken),
    ]);

    // Persist so the next cold start has correct values before the network check.
    await prefs.setBool(_prefIsPremium, _isPremium);
    await prefs.setBool(_prefIsTrainerClient, _isTrainerClient);
    await prefs.setBool(_prefIsTrainer, _isTrainer);
    notifyListeners();
  }

  /// Re-checks access (e.g. after a purchase or trainer assignment).
  Future<void> refresh({
    required String serverBaseUrl,
    required String bearerToken,
  }) async {
    await Future.wait([
      _checkRevenueCat(null), // userId already set in RevenueCat SDK
      _checkTrainerClient(serverBaseUrl, bearerToken),
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsPremium, _isPremium);
    await prefs.setBool(_prefIsTrainerClient, _isTrainerClient);
    await prefs.setBool(_prefIsTrainer, _isTrainer);
    notifyListeners();
  }

  /// Clears all access flags. Call on logout.
  Future<void> reset() async {
    _isPremium = false;
    _isTrainerClient = false;
    _isTrainer = false;
    _initialized = false;
    _roleResolved = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefIsPremium);
    await prefs.remove(_prefIsTrainerClient);
    await prefs.remove(_prefIsTrainer);
    try {
      await Purchases.logOut();
    } catch (_) {}
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _checkRevenueCat(String? userId) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    final apiKey = Platform.isIOS ? revenueCatApiKeyIOS : revenueCatApiKey;
    if (apiKey.isEmpty) return;
    try {
      if (!(await Purchases.isConfigured)) {
        final config = PurchasesConfiguration(apiKey);
        if (userId != null) config.appUserID = userId;
        await Purchases.configure(config);
      } else if (userId != null) {
        await Purchases.logIn(userId);
      }
      final info = await Purchases.getCustomerInfo();
      _isPremium = info.entitlements.active.containsKey(_premiumEntitlementId);
    } catch (_) {
      // Keep cached value on failure — network may be unavailable.
    }
  }

  /// Fetches the current RevenueCat offering, or `null` if none is configured
  /// (e.g. no products set up yet in the dashboard) or the SDK isn't
  /// configured for this platform. Used to validate before presenting a
  /// paywall so callers can show a friendly message instead of a broken UI.
  Future<Offering?> getCurrentOffering() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (_) {
      return null;
    }
  }

  /// Restores previously purchased entitlements onto this account (e.g. the
  /// user reinstalled the app or is signing in on a new device). Returns the
  /// resulting premium status. Throws on failure so the caller can surface
  /// an error to the user.
  Future<bool> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    _isPremium = info.entitlements.active.containsKey(_premiumEntitlementId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsPremium, _isPremium);
    notifyListeners();
    return _isPremium;
  }

  Future<void> _checkTrainerClient(String baseUrl, String token) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final response = await dio.get('api/TrainerClient/status');
      _isTrainerClient =
          (response.data as Map<String, dynamic>)['isTrainerClient'] as bool? ??
          false;
      _isTrainer =
          (response.data as Map<String, dynamic>)['isTrainer'] as bool? ??
          false;
    } catch (_) {
      // Keep cached value on failure.
    } finally {
      // Resolved either way: offline, the cached answer is all there is, and
      // callers gated on this would otherwise wait forever.
      _roleResolved = true;
    }
  }
}
