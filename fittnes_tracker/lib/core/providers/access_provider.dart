import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

// ── Configuration ────────────────────────────────────────────────────────────
// Replace with your RevenueCat public SDK key from app.revenuecat.com
const _revenueCatApiKey = 'test_TCvOuZHakLANaavLrSNHqXdWMbB';

// The entitlement identifier set up in your RevenueCat dashboard.
const _premiumEntitlementId = 'ForgeForm Pro';

// SharedPreferences keys used to cache access state across cold starts.
const _prefIsPremium = 'access_is_premium';
const _prefIsTrainerClient = 'access_is_trainer_client';
// ─────────────────────────────────────────────────────────────────────────────

/// Aggregates premium status from RevenueCat purchases and the server-side
/// trainer–client relationship. Any widget can read [hasPremiumAccess] to gate
/// features — no knowledge of the source is needed.
class AccessProvider extends ChangeNotifier {
  bool _isPremium = false;
  bool _isTrainerClient = false;
  bool _initialized = false;

  bool get isPremium => _isPremium;
  bool get isTrainerClient => _isTrainerClient;

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
    notifyListeners();
  }

  /// Clears all access flags. Call on logout.
  Future<void> reset() async {
    _isPremium = false;
    _isTrainerClient = false;
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefIsPremium);
    await prefs.remove(_prefIsTrainerClient);
    try {
      await Purchases.logOut();
    } catch (_) {}
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _checkRevenueCat(String? userId) async {
    if (kIsWeb) return;
    try {
      if (!(await Purchases.isConfigured)) {
        final config = PurchasesConfiguration(_revenueCatApiKey);
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
    } catch (_) {
      // Keep cached value on failure.
    }
  }
}
