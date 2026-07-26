import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/premium/paywall_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Opens ForgeForm's custom-branded paywall for the premium entitlement.
/// Validates that a RevenueCat offering is actually configured first, so a
/// dashboard misconfiguration surfaces as a friendly message instead of a
/// blank/broken screen.
Future<void> openPaywall(BuildContext context) async {
  final access = context.read<AccessProvider>();
  final offering = await access.getCurrentOffering();
  if (!context.mounted) return;
  if (offering == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.paywallNoPlans)),
    );
    return;
  }

  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
}

/// Manually restores previously purchased entitlements onto this account
/// (e.g. reinstalled app, new device, or the store purchase didn't sync).
/// Shows a snackbar with the outcome.
Future<void> restorePurchases(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final access = context.read<AccessProvider>();
  try {
    final isPremium = await access.restorePurchases();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPremium ? l10n.restoreComplete : l10n.noActivePurchasesFound),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.restoreFailed('$e'))));
  }
}
