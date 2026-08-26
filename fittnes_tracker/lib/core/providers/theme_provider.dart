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
      colorScheme: ColorScheme.light(
        // The AA-safe variant, not the raw brand orange: colorScheme.primary
        // is what every FilledButton/FAB/selected-state fills with, and white
        // on #FF6B3E is 2.83:1. See ForgeColors.forgeOrangeOnLight.
        primary: ForgeColors.forgeOrangeOnLight,
        secondary: ForgeColors.forgeOrangeOnLight,
        tertiary: ForgeColors.charcoal,
        surface: ForgeColors.surfaceLight,
        background: ForgeColors.backgroundLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ForgeColors.charcoal,
        onBackground: ForgeColors.charcoal,
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
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: ForgeColors.surfaceLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
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
        elevation: 4,
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
      colorScheme: ColorScheme.dark(
        primary: ForgeColors.forgeOrange,
        secondary: ForgeColors.forgeOrange,
        tertiary: ForgeColors.charcoal,
        surface: ForgeColors.surfaceDark,
        background: ForgeColors.backgroundDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
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
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: ForgeColors.cardDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
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
        elevation: 4,
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
