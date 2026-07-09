import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'paywall_launcher.dart';

/// Wraps [child] and shows nothing / a lock indicator while access is unknown.
/// When the user does NOT have premium access, tapping the area opens the paywall.
///
/// Usage:
/// ```dart
/// PremiumGate(child: MyPremiumWidget())
/// ```
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.child,
    this.placeholder,
    this.showLockBadge = true,
  });

  final Widget child;

  /// Widget shown in place of [child] for free users.
  /// Defaults to a blurred/locked version of [child] with a lock icon overlay.
  final Widget? placeholder;

  /// Whether to show a small lock icon badge on the gated content.
  final bool showLockBadge;

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();

    if (!access.initialized) return const SizedBox.shrink();
    if (access.hasPremiumAccess) return child;

    return GestureDetector(
      onTap: () => _openPaywall(context),
      child: RepaintBoundary(
        child: Stack(
          children: [
            // Show a visually dimmed placeholder so the user sees what they're missing.
            IgnorePointer(
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.black38,
                  BlendMode.darken,
                ),
                child: placeholder ?? child,
              ),
            ),
            if (showLockBadge)
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openPaywall(BuildContext context) => openPaywall(context);
}

/// Thin wrapper that makes a single tab / menu item appear locked.
/// Instead of hiding the content, it shows a lock icon in the corner.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    if (access.hasPremiumAccess) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => openPaywall(context),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B3E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
