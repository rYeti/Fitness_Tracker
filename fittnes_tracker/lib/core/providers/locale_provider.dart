import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'app_locale';

class LocaleProvider with ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  LocaleProvider({Locale? initialLocale}) : _locale = initialLocale;

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
    notifyListeners();
  }
}
