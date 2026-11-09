import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const String prefKey = 'app_pref_dark';
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  bool _isDarkMode;
  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider({bool initialDark = false}) : _isDarkMode = initialDark {
    AppColors.isDarkMode = initialDark;
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value && AppColors.isDarkMode == value) return;
    _isDarkMode = value;
    AppColors.isDarkMode = value;
    await _prefs.setBool(prefKey, value);
    _updateSystemOverlay();
    notifyListeners();
  }

  void _updateSystemOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            _isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor:
            _isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        systemNavigationBarIconBrightness:
            _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }
}
