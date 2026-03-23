import '../app_database.dart';
import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  late ThemeMode _themeMode = ThemeMode.light;
  final AppDatabase db;

  ThemeProvider(this.db) {
    loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await db.userSettingsDao.updateThemeMode(
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }

  Future<void> loadTheme() async {
    final settings = await db.userSettingsDao.getSettings();
    _themeMode =
        settings?.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // Light theme - ForgeForm branding
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'Exo 2',
      colorScheme: ColorScheme.light(
        primary: Color(0xFFFF6B3E), // ForgeForm orange
        secondary: Color(0xFFFF6B3E),
        tertiary: Color(0xFF333333), // Dark charcoal
        surface: Colors.white,
        background: Color(0xFFF5F5F5), // Light gray background
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF333333),
        onBackground: Color(0xFF333333),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
        displayMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
        displaySmall: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
        titleLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
        titleMedium: TextStyle(
          fontFamily: 'Exo 2',
          fontWeight: FontWeight.w500,
          color: Color(0xFF333333),
        ),
        titleSmall: TextStyle(
          fontFamily: 'Exo 2',
          fontWeight: FontWeight.w500,
          color: Color(0xFF333333),
        ),
        bodyLarge: TextStyle(fontFamily: 'Exo 2', color: Color(0xFF333333)),
        bodyMedium: TextStyle(fontFamily: 'Exo 2', color: Color(0xFF333333)),
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
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFF6B3E),
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
        backgroundColor: Color(0xFF333333),
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFF6B3E),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFFF6B3E), width: 2),
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
        primary: Color(0xFFFF6B3E), // ForgeForm orange
        secondary: Color(0xFFFF6B3E),
        tertiary: Color(0xFF333333),
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF121212),
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
        color: Color(0xFF2C2C2C),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFF6B3E),
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
        backgroundColor: Color(0xFF333333),
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFF6B3E),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF404040)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF404040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFFF6B3E), width: 2),
        ),
        labelStyle: TextStyle(fontFamily: 'Exo 2', color: Color(0xFFB0B0B0)),
      ),
    );
  }
}
