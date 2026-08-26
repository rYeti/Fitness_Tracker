import 'package:flutter/material.dart';

import 'package:ForgeForm/l10n/app_localizations.dart';

/// Chrome and state widgets shared by every Trainer Console screen.
///
/// These exist so the console reads as one surface: the same card treatment,
/// the same empty/error/loading shapes everywhere. Per CLAUDE.md, one shared
/// widget per repeated pattern — don't re-implement a card inline in a screen.

/// Card chrome from the handoff: 12px radius (16 for hero cards), hairline
/// border, soft shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return decorated;
    // Ink effects need to clip to the same radius or they bleed past the card.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: decorated,
      ),
    );
  }
}

/// Section heading used above card groups.
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: colors.onSurface,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Skeleton placeholder shaped like the content it replaces — per CLAUDE.md,
/// never a bare spinner for anything above ~300ms.
class LoadingSkeleton extends StatelessWidget {
  final int rows;
  final double rowHeight;

  /// Overrides the generic "Loading" announcement with something screen
  /// specific ("Loading roster"). Null keeps the generic one — resolved in
  /// [build] because a localized default can't be a const constructor value.
  final String? semanticsLabel;

  const LoadingSkeleton({
    super.key,
    this.rows = 5,
    this.rowHeight = 64,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: semanticsLabel ?? l10n.consoleLoading,
      child: ListView.builder(
        itemCount: rows,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: AppCard(
            child: SizedBox(
              height: rowHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bar(colors, 140, 14),
                  const SizedBox(height: 8),
                  _bar(colors, 90, 11),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _bar(ColorScheme colors, double width, double height) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

/// Inline, recoverable error — never a silent failure or a raw exception.
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon + message (+ optional action) rather than a blank screen.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Wraps the state in a card, for empty regions inside a populated screen.
  final bool inCard;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.inCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 38, color: colors.onSurface.withValues(alpha: 0.55)),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 12.5,
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    );

    if (!inCard) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: content),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
      child: Center(child: content),
    );
  }
}
