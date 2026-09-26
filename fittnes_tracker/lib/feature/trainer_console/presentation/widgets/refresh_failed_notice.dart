import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// What a console pane says when reading its data again failed: "Couldn't
/// refresh", with a way to try again, beside the data it kept on screen.
///
/// A refresh is a read nobody asked for — the console heard a client's data
/// changed, or the window came back into focus — so its failure must not
/// take the data away: no error state, no empty state
/// (`docs/sync-architecture.md` §52). But keeping the data and saying
/// nothing left a console whose API was unreachable showing figures that
/// got older by the minute, with nothing to tell the trainer they were.
/// This is the one place a pane says so (§58); a pane passes its provider's
/// `refreshFailed` and its own refresh as [onRetry].
///
/// It is a small warn-toned pill rather than a banner: what is shown is
/// still the last thing the server said, and the trainer can keep working.
/// The warning is carried by the icon and the words, never the tint alone.
class RefreshFailedNotice extends StatelessWidget {
  const RefreshFailedNotice({
    super.key,
    required this.failed,
    required this.onRetry,
    this.padding = const EdgeInsets.only(top: 8),
  });

  /// Whether the pane's last refresh failed. Nothing is drawn otherwise.
  final bool failed;

  /// Reads the pane again, as a refresh: what is shown stays up meanwhile.
  final VoidCallback onRetry;

  /// Space around the notice while it shows, so a pane without it has no
  /// gap where it would be.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ForgeMotion.of(context),
      switchInCurve: ForgeMotion.curve,
      switchOutCurve: ForgeMotion.curve,
      // Start-aligned, so a parent that stretches its children (Client
      // Detail's column) doesn't centre the pill.
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, if (current != null) current],
      ),
      child: failed
          ? Padding(
              key: const ValueKey('refresh-failed'),
              padding: padding,
              child: _Pill(onRetry: onRetry),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brightness = theme.brightness;
    // CLAUDE.md: 44×44 on a phone; 32×32 is enough for a desktop pointer.
    final target = Breakpoints.isDesktop(context) ? 32.0 : 44.0;

    // The tint is StatusBadge's warn wash. Text and the Retry label are
    // onSurface rather than amber: amber text on its own tint over the
    // light page measures 4.35:1, short of AA for 12px. The icon keeps the
    // tone (4.35 light, 6.01 dark, against 3:1). contrast_test.dart names
    // each pair.
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.consoleRefreshFailedDetail,
      child: Container(
        constraints: BoxConstraints(minHeight: target),
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        decoration: BoxDecoration(
          color: refreshFailedTint(brightness),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.sync_problem_rounded,
                size: 16,
                color: ForgeColors.statusWarnFor(brightness),
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Text(
                l10n.consoleRefreshFailed,
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurface,
                minimumSize: Size(target, target),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// The notice's fill: the warn tone washed over whatever is behind it, a
/// little stronger in the dark theme, as `StatusBadge` does. Named so
/// `contrast_test.dart` measures the colour the widget paints.
@visibleForTesting
Color refreshFailedTint(Brightness brightness) => ForgeColors.statusWarn
    .withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.14);
