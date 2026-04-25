import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _packages = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      setState(() {
        _packages = current?.availablePackages ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _purchase(Package package) async {
    setState(() => _purchasing = true);
    try {
      await Purchases.purchasePackage(package);
      if (!mounted) return;
      final auth = ref.read(authProvider);
      final serverUrl = ref.read(serverUrlProvider);
      await context.read<AccessProvider>().refresh(
        serverBaseUrl: serverUrl,
        bearerToken: auth.user?.token ?? '',
      );
      if (mounted) Navigator.of(context).pop();
    } on PurchasesErrorCode catch (e) {
      if (e != PurchasesErrorCode.purchaseCancelledError && mounted) {
        setState(() => _error = 'Purchase failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    try {
      await Purchases.restorePurchases();
      if (!mounted) return;
      final auth = ref.read(authProvider);
      final serverUrl = ref.read(serverUrlProvider);
      await context.read<AccessProvider>().refresh(
        serverBaseUrl: serverUrl,
        bearerToken: auth.user?.token ?? '',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'Nothing to restore.');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Header
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Forge',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        color: Color(0xFFFF6B3E),
                      ),
                    ),
                    TextSpan(
                      text: 'Form ',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: 'Premium',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock your full potential',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Feature list
              ..._features.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFFFF6B3E), size: 20),
                      const SizedBox(width: 12),
                      Text(f, style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              if (_loading)
                const CircularProgressIndicator(color: Color(0xFFFF6B3E))
              else if (_packages.isEmpty)
                const Text('No plans available.', style: TextStyle(color: Colors.white60))
              else
                ..._packages.map(
                  (pkg) => _PackageButton(
                    package: pkg,
                    purchasing: _purchasing,
                    onTap: () => _purchase(pkg),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _purchasing ? null : _restore,
                child: const Text(
                  'Restore purchases',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageButton extends StatelessWidget {
  const _PackageButton({
    required this.package,
    required this.purchasing,
    required this.onTap,
  });

  final Package package;
  final bool purchasing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priceStr = package.storeProduct.priceString;
    final title = package.storeProduct.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: purchasing ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B3E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: purchasing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  '$title — $priceStr',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ),
    );
  }
}

const _features = [
  'Full progress dashboard — 30 days & custom range',
  'Unlimited workout plans',
  'Unlimited meal templates',
  'Weight & calorie correlation chart',
  'Exercise progress graphs',
  'Export workout data (CSV)',
];
