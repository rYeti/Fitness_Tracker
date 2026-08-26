import '../app_database.dart';
import '../design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode;
  final AppDatabase db;

  ThemeProvider(this.db, {ThemeMode initialTheme = ThemeMode.light})
    : _themeMode = initialTheme;

  ThemeMode get themeMode => _themeMode;

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await db.userSettingsDao.updateThemeMode(
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }

  static const Color kSuccessColor = Color(0xFF4CAF50);

  // Light theme - ForgeForm branding
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'Exo 2',
      // Scaffold reads this, NOT colorScheme.background — which Material 3
      // deprecated, so setting `background` alone silently did nothing and
      // every page stayed #FFFFFF behind #FFFFFF cards. Caught by sampling
      // the rendered pixels, not by a test: contrast_test.dart asserts the
      // token *pair* is valid and cannot see whether the app uses it.
      scaffoldBackgroundColor: ForgeColors.backgroundLight,
      colorScheme: ColorScheme.light(
        // The AA-safe variant, not the raw brand orange: colorScheme.primary
        // is what every FilledButton/FAB/selected-state fills with, and white
        // on #FF6B3E is 2.83:1. See ForgeColors.forgeOrangeOnLight.
        primary: ForgeColors.forgeOrangeOnLight,
        secondary: ForgeColors.forgeOrangeOnLight,
        tertiary: ForgeColors.charcoal,
        surface: ForgeColors.surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ForgeColors.charcoal,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: ForgeColors.charcoal,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: ForgeColors.charcoal,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: ForgeColors.charcoal,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: ForgeColors.charcoal,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: ForgeColors.charcoal,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: ForgeColors.charcoal,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: ForgeColors.charcoal,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Exo 2',
          fontWeight: FontWeight.w500,
          color: ForgeColors.charcoal,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Exo 2',
          fontWeight: FontWeight.w500,
          color: ForgeColors.charcoal,
        ),
        bodyLarge: TextStyle(fontFamily: 'Exo 2', color: ForgeColors.charcoal),
        bodyMedium: TextStyle(fontFamily: 'Exo 2', color: ForgeColors.charcoal),
        bodySmall: TextStyle(fontFamily: 'Exo 2', color: Color(0xFF666666)),
        labelLarge: TextStyle(
          fontFamily: 'Exo 2',
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      // Flat, separated by tone rather than a drop shadow — the Material 3
      // treatment. This only works because scaffoldBackgroundColor is
      // #F5F5F5: while the page was white, that 2dp shadow was the only thing
      // making a white card visible, so removing it first would have erased
      // the card entirely.
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ForgeColors.charcoal.withValues(alpha: 0.08)),
        ),
        color: ForgeColors.surfaceLight,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ForgeColors.forgeOrangeOnLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(
            fontFamily: 'Exo 2',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // The M3 default indicator derives from `secondaryContainer`, which
        // with Forge Orange as `secondary` comes out solid orange — leaving
        // the orange selected glyph invisible on top of it. A 16% tint of the
        // same hue keeps the glyph readable against it.
        indicatorColor: ForgeColors.forgeOrange.withValues(alpha: 0.16),
        backgroundColor: ForgeColors.surfaceLight,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? ForgeColors.forgeOrangeOnLight
                : const Color(0xFF5F5F5F),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: ForgeColors.charcoal,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ForgeColors.forgeOrangeOnLight,
        foregroundColor: Colors.white,
        // A FAB floats over content by definition, so tone alone cannot
        // separate it — it keeps a lift, just an M3-sized one.
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ForgeColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ForgeColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ForgeColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: ForgeColors.forgeOrangeOnLight,
            width: 2,
          ),
        ),
        labelStyle: TextStyle(fontFamily: 'Exo 2', color: Color(0xFF666666)),
      ),
    );
  }

  // Dark theme - ForgeForm branding
  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Exo 2',
      scaffoldBackgroundColor: ForgeColors.backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: ForgeColors.forgeOrange,
        secondary: ForgeColors.forgeOrange,
        tertiary: ForgeColors.charcoal,
        surface: ForgeColors.surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Exo 2',
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Exo 2',
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(fontFamily: 'Exo 2', color: Colors.white),
        bodyMedium: TextStyle(fontFamily: 'Exo 2', color: Colors.white),
        bodySmall: TextStyle(fontFamily: 'Exo 2', color: Color(0xFFB0B0B0)),
        labelLarge: TextStyle(
          fontFamily: 'Exo 2',
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        color: ForgeColors.cardDark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ForgeColors.forgeOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(
            fontFamily: 'Exo 2',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // The M3 default indicator derives from `secondaryContainer`, which
        // with Forge Orange as `secondary` comes out solid orange — leaving
        // the orange selected glyph invisible on top of it. A 16% tint of the
        // same hue keeps the glyph readable against it.
        indicatorColor: ForgeColors.forgeOrange.withValues(alpha: 0.16),
        backgroundColor: ForgeColors.surfaceDark,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? ForgeColors.forgeOrange
                : Colors.white70,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: ForgeColors.charcoal,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ForgeColors.forgeOrange,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ForgeColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ForgeColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ForgeColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ForgeColors.forgeOrange, width: 2),
        ),
        labelStyle: TextStyle(fontFamily: 'Exo 2', color: Color(0xFFB0B0B0)),
      ),
    );
  }
}
