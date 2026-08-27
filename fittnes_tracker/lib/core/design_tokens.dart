import 'package:flutter/material.dart';

/// Fixed brand and macro colors from the design handoff (CLAUDE.md
/// "Design tokens" section) — do not deviate. Single source of truth so a
/// color literal can't silently drift (e.g. Forge Orange typo'd as
/// `#FF6B35` instead of `#FF6B3E`).
abstract final class ForgeColors {
  static const forgeOrange = Color(0xFFFF6B3E);
  static const charcoal = Color(0xFF333333);

  /// Forge Orange for **light** surfaces. The brand orange is a 2.83:1 pair
  /// with white, so it cannot carry white-on-orange fill, text or an icon on
  /// anything light — it fails even the 3:1 large-text bar.
  ///
  /// This is the same hue darkened 30% toward black, which clears AA against
  /// *both* light surfaces: 5.32:1 on `#FFFFFF` and 4.88:1 on
  /// [backgroundLight]. The page background is the binding constraint — a
  /// shallower 25% darkening reaches 4.75 on white but only 4.36 on
  /// `#F5F5F5`, which is how the first attempt at this token shipped a value
  /// that failed on half the surfaces it was for. `contrast_test.dart` now
  /// asserts both.
  ///
  /// Dark surfaces keep [forgeOrange]: it measures 4.94:1 on [cardDark] and
  /// 5.89:1 on [surfaceDark], so darkening there would cost brand fidelity
  /// for no accessibility gain.
  ///
  /// Rejected alternative: charcoal on orange is 4.47:1 — still short of AA,
  /// and it loses the white-on-orange look entirely.
  static const forgeOrangeOnLight = Color(0xFFB24B2B);

  /// Page background behind [surfaceLight] cards. White cards on a white page
  /// are a 1.00:1 pair, which left the 2dp drop shadow as the only thing
  /// making a card visible; this is the value the design handoff specifies.
  static const backgroundLight = Color(0xFFF5F5F5);
  static const surfaceLight = Color(0xFFFFFFFF);

  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const cardDark = Color(0xFF2C2C2C);

  /// Input borders. A border is the only thing marking where a field is, so
  /// it is a non-text UI component under WCAG 1.4.11 and needs 3:1. The old
  /// values (`#E0E0E0` on white, `#404040` on the dark card) measured 1.32
  /// and 1.35 — roughly a quarter of the requirement.
  ///
  /// [borderLight] is sized against the *darkest* fill it sits on, not the
  /// lightest. Fields are filled two different ways: the theme fills with
  /// [surfaceLight], while `onboardingFieldDecoration` fills with `onSurface`
  /// at 7% alpha — about `#E8E8E8`. A value picked against white alone
  /// measured 3.03 there but only 2.48 on the tinted fill, which is how the
  /// first attempt still failed on the login screen after the token changed.
  /// `#808080` clears 3:1 on both (3.95 on white, 3.22 on `#E8E8E8`).
  static const borderLight = Color(0xFF808080);
  static const borderDark = Color(0xFF7A7A7A);

  /// The tinted fill `onboardingFieldDecoration` uses, named so
  /// `contrast_test.dart` can assert against it rather than assuming every
  /// field is filled with [surfaceLight].
  static const inputFillLight = Color(0xFFE8E8E8);

  static const proteinColor = Color(0xFFE53935);
  static const carbsColor = Color(0xFF1E88E5);
  static const fatColor = Color(0xFF43A047);

  /// Status tones (CLAUDE.md "Status tones: ok = green, warn = amber,
  /// bad = red"). Always pair with a label/icon — never color alone.
  ///
  /// These are *fill* colours — a badge wash, a progress bar, a chart bar.
  /// On a light surface none of them can carry text: measured on white they
  /// are 3.30, 2.04 and 4.23, and amber fails even the 3:1 icon bar. Use the
  /// `OnLight` variants below for anything a reader has to read.
  static const statusOk = Color(0xFF43A047);
  static const statusWarn = Color(0xFFFFA000);
  static const statusBad = Color(0xFFE53935);

  /// Status tones darkened for use as **foreground on light surfaces** —
  /// text, icons, small labels. Same relationship [forgeOrangeOnLight] has to
  /// [forgeOrange], and for the same reason: a brand or status hue tuned to
  /// look right as a fill is almost never legible as 12px text on white.
  ///
  /// Each clears 4.5:1 against both light surfaces:
  ///
  /// | tone | on `#FFFFFF` | on [backgroundLight] |
  /// |------|-------------:|---------------------:|
  /// | ok   | 5.42         | 4.97                 |
  /// | warn | 5.21         | 4.78                 |
  /// | bad  | 6.11         | 5.60                 |
  ///
  /// Amber needs the deepest darkening because it starts far brighter than
  /// the other two — the same asymmetry `StatusBadge` accounts for.
  ///
  /// Dark surfaces keep the raw tones: they measure 4.23–6.84 on [cardDark].
  static const statusOkOnLight = Color(0xFF327835);
  static const statusWarnOnLight = Color(0xFF996000);
  static const statusBadOnLight = Color(0xFFB72E2A);

  /// Informational — a scheduled or pending state, distinct from ok/warn/bad.
  /// Reuses the carbs blue's hue but is a separate token: a macro colour and
  /// a status colour drifting together would be a coincidence, not a rule.
  static const statusInfo = Color(0xFF1E88E5);
  static const statusInfoOnLight = Color(0xFF15669F);

  /// The tone to use as a foreground for the current brightness.
  static Color statusOkFor(Brightness b) =>
      b == Brightness.dark ? statusOk : statusOkOnLight;
  static Color statusWarnFor(Brightness b) =>
      b == Brightness.dark ? statusWarn : statusWarnOnLight;
  static Color statusBadFor(Brightness b) =>
      b == Brightness.dark ? statusBad : statusBadOnLight;
  static Color statusInfoFor(Brightness b) =>
      b == Brightness.dark ? statusInfo : statusInfoOnLight;
}

/// Responsive breakpoints (CLAUDE.md "Layout & spacing": mobile `<600`,
/// tablet `600–1024`, desktop `>1024`).
///
/// Named because `> 1024` was copy-pasted across eight Trainer Console files
/// and was the only breakpoint literal in the codebase — which is why the
/// 600–1024 band renders the phone layout on a tablet-width browser, with the
/// bottom tab bar and ~250px of dead space above it. Having the tablet bound
/// exist as a name is the precondition for ever handling that band.
abstract final class Breakpoints {
  /// Below this is a phone.
  static const double mobile = 600;

  /// Above this is a desktop: the Trainer Console shows its sidebar here.
  static const double desktop = 1024;

  /// Widest a single column of form fields should get. Login, Register and
  /// profile setup had no constraint at all and rendered 1,384px-wide inputs
  /// on a 1440px viewport — a phone layout stretched across a monitor, on the
  /// surface CLAUDE.md calls the trainer's workstation.
  static const double formMaxWidth = 480;

  /// Widest a page of content should get before it is centred instead.
  ///
  /// The Trainer Console never needed this: its screens are card grids that
  /// reflow, so its widest control is about 15% of a 1440px viewport. The
  /// trainee app is single-column lists and full-width cards with no
  /// constraint anywhere, and measures **97.8%** of the same viewport — a
  /// phone layout stretched across a monitor. That reads worst on Food, where
  /// a row's name sits at x=33 and its own edit and delete controls sit at
  /// x=1334, about 1,300px away from the thing they act on.
  ///
  /// Wider than [formMaxWidth] on purpose: a column of inputs wants to be
  /// narrow, but a list of meals with macros, or a chart, has real content to
  /// spend the width on.
  static const double contentMaxWidth = 840;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width > desktop;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;
}
