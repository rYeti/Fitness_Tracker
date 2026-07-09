import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';

/// Presents RevenueCat's hosted paywall for the premium entitlement.
/// On a successful purchase/restore, refreshes [AccessProvider] so gated
/// UI unlocks immediately without requiring an app restart.
Future<void> openPaywall(BuildContext context) async {
  final result = await RevenueCatUI.presentPaywallIfNeeded(premiumEntitlementId);
  if (!context.mounted) return;
  if (result == PaywallResult.purchased || result == PaywallResult.restored) {
    final container = ProviderScope.containerOf(context);
    final auth = container.read(authProvider);
    final serverUrl = container.read(serverUrlProvider);
    await context.read<AccessProvider>().refresh(
      serverBaseUrl: serverUrl,
      bearerToken: auth.user?.token ?? '',
    );
  }
}
