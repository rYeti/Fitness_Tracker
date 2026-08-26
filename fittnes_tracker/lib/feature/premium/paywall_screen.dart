import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/premium/paywall_launcher.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

const _forgeOrange = ForgeColors.forgeOrange;
const _charcoal = ForgeColors.charcoal;

/// A custom-built paywall screen styled to match ForgeForm's own design
/// system, as an alternative to RevenueCat's hosted paywall template.
/// Fetches the current [Offering] and lets the user pick a package, purchase
/// it, or restore a previous purchase — all state changes flow back through
/// [AccessProvider] so gated UI unlocks immediately.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _LoadState { loading, error, empty, loaded }

class _PaywallScreenState extends State<PaywallScreen> {
  _LoadState _state = _LoadState.loading;
  Offering? _offering;
  Package? _selectedPackage;
  bool _isPurchasing = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadOffering();
  }

  Future<void> _loadOffering() async {
    setState(() => _state = _LoadState.loading);
    final offering = await context.read<AccessProvider>().getCurrentOffering();
    if (!mounted) return;
    if (offering == null) {
      setState(() => _state = _LoadState.error);
      return;
    }
    if (offering.availablePackages.isEmpty) {
      setState(() => _state = _LoadState.empty);
      return;
    }
    setState(() {
      _offering = offering;
      _selectedPackage = _defaultPackage(offering.availablePackages);
      _state = _LoadState.loaded;
    });
  }

  Package _defaultPackage(List<Package> packages) {
    return packages.firstWhere(
      (p) => p.packageType == PackageType.annual,
      orElse: () => packages.first,
    );
  }

  Future<void> _purchase() async {
    final selected = _selectedPackage;
    if (selected == null || _isPurchasing) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isPurchasing = true);
    try {
      await Purchases.purchase(PurchaseParams.package(selected));
      if (!mounted) return;
      final container = ProviderScope.containerOf(context);
      final auth = container.read(authProvider);
      final serverUrl = container.read(serverUrlProvider);
      await context.read<AccessProvider>().refresh(
        serverBaseUrl: serverUrl,
        bearerToken: auth.user?.token ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.paywallError)));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    await restorePurchases(context);
    if (!mounted) return;
    setState(() => _isRestoring = false);
    if (context.read<AccessProvider>().hasPremiumAccess) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(l10n),
            Expanded(child: _buildBody(l10n, theme, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          if (_state == _LoadState.loaded)
            TextButton(
              onPressed: _isRestoring ? null : _restore,
              child:
                  _isRestoring
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(l10n.paywallRestorePurchases),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme, bool isDark) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator(color: _forgeOrange));
      case _LoadState.error:
        return _buildMessageState(
          icon: Icons.wifi_off_rounded,
          message: l10n.paywallError,
          showRetry: true,
        );
      case _LoadState.empty:
        return _buildMessageState(
          icon: Icons.local_offer_outlined,
          message: l10n.paywallNoPlans,
          showRetry: false,
        );
      case _LoadState.loaded:
        return _buildOffering(l10n, theme, isDark);
    }
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
    required bool showRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (showRetry) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadOffering,
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOffering(AppLocalizations l10n, ThemeData theme, bool isDark) {
    final packages = _offering!.availablePackages;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: _forgeOrange,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.paywallUnlockPotential,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        ..._features(l10n).map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: _forgeOrange, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(feature, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...packages.map(
          (package) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PackageCard(
              package: package,
              selected: _selectedPackage == package,
              isDark: isDark,
              onTap: () => setState(() => _selectedPackage = package),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPurchasing ? null : _purchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: _forgeOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child:
                _isPurchasing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      _selectedPackage != null
                          ? '${l10n.goPremiumBannerButton} · ${_selectedPackage!.storeProduct.priceString}'
                          : l10n.goPremiumBannerButton,
                    ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.paywallFinePrint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  // Export and basic custom foods are free (data ownership is never gated),
  // so they are deliberately absent from this list.
  List<String> _features(AppLocalizations l10n) => [
    l10n.paywallFeatureProgress,
    l10n.paywallFeaturePlans,
    l10n.paywallFeatureTemplates,
    l10n.paywallFeatureCorrelation,
    l10n.paywallFeatureNutrition,
    l10n.paywallFeatureLongPlans,
    l10n.paywallFeatureFreeChoice,
  ];
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final Package package;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  String get _durationLabel {
    switch (package.packageType) {
      case PackageType.annual:
        return 'Annual';
      case PackageType.sixMonth:
        return '6 Months';
      case PackageType.threeMonth:
        return '3 Months';
      case PackageType.twoMonth:
        return '2 Months';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.weekly:
        return 'Weekly';
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.custom:
      case PackageType.unknown:
        return package.storeProduct.title;
    }
  }

  String _periodUnitLabel(AppLocalizations l10n, PeriodUnit unit, int count) {
    switch (unit) {
      case PeriodUnit.day:
        return count == 1 ? l10n.paywallPeriodDay : l10n.paywallPeriodDays;
      case PeriodUnit.week:
        return count == 1 ? l10n.paywallPeriodWeek : l10n.paywallPeriodWeeks;
      case PeriodUnit.month:
        return count == 1 ? l10n.paywallPeriodMonth : l10n.paywallPeriodMonths;
      case PeriodUnit.year:
        return count == 1 ? l10n.paywallPeriodYear : l10n.paywallPeriodYears;
      case PeriodUnit.unknown:
        return '';
    }
  }

  /// Returns the free-trial or discounted-intro-price label for this
  /// package, or null if it has no introductory offer.
  String? _introOfferLabel(AppLocalizations l10n) {
    final intro = package.storeProduct.introductoryPrice;
    if (intro == null) return null;
    final totalUnits = intro.periodNumberOfUnits * intro.cycles;
    final duration = '$totalUnits ${_periodUnitLabel(l10n, intro.periodUnit, totalUnits)}';
    if (intro.price == 0) {
      return l10n.paywallFreeTrial(duration);
    }
    return l10n.paywallIntroPrice(intro.priceString, duration);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final introOfferLabel = _introOfferLabel(l10n);
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: ForgeMotion.of(context),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _forgeOrange : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _forgeOrange : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _durationLabel,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (introOfferLabel != null)
                    Text(
                      introOfferLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _forgeOrange,
                      ),
                    )
                  else if (package.packageType == PackageType.annual)
                    Text(
                      package.storeProduct.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : _charcoal.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              package.storeProduct.priceString,
              style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
