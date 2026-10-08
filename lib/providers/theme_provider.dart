import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedTheme = 'pink';

  // Theme colors
  final Map<String, Map<String, Color>> _themeColors = {
    'pink': {
      'light': const Color(0xFFFFC7C7),
      'dark': const Color(0xFF493737),
      'hoverLight': const Color(0xFFFFADAD),
      'hoverDark': const Color(0xFF5C4848),
    },
    'green': {
      'light': const Color(0xFFC7F7BC),
      'dark': const Color(0xFF2C382C),
      'hoverLight': const Color(0xFFB2ECA8),
      'hoverDark': const Color(0xFF3A4B3A),
    },
    'blue': {
      'light': const Color(0xFFE5FEFF),
      'dark': const Color(0xFF314041),
      'hoverLight': const Color(0xFFCFF9FA),
      'hoverDark': const Color(0xFF435354),
    },
    'yellow': {
      'light': const Color(0xFFFAFAE1),
      'dark': const Color(0xFF3B3B2B),
      'hoverLight': const Color(0xFFF0F0C4),
      'hoverDark': const Color(0xFF565643),
    },
    'white': {
      'light': const Color(0xFFEBEBEB),
      'dark': const Color(0xFF303030),
      'hoverLight': const Color(0xFFD6D6D6),
      'hoverDark': const Color(0xFF4A4A4A),
    },
  };

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  String get selectedTheme => _selectedTheme;

  Color get primaryLight => _themeColors[_selectedTheme]!['light']!;
  Color get primaryDark => _themeColors[_selectedTheme]!['dark']!;
  Color get hoverLight => _themeColors[_selectedTheme]!['hoverLight']!;
  Color get hoverDark => _themeColors[_selectedTheme]!['hoverDark']!;

  ThemeData get currentTheme => _buildLightTheme();
  ThemeData get currentDarkTheme => _buildDarkTheme();

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedTheme = prefs.getString('theme') ?? 'pink';
    final mode = prefs.getString('themeMode') ?? 'system';
    _themeMode = mode == 'light'
        ? ThemeMode.light
        : mode == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;
    notifyListeners();
  }

  Future<void> setThemeColor(String theme) async {
    _selectedTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeMode',
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system',
    );
    notifyListeners();
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: primaryLight,
      colorScheme: ColorScheme.light(
        primary: primaryDark,
        secondary: hoverLight,
        surface: primaryLight,
        background: primaryLight,
        onPrimary: primaryLight,
        onSecondary: primaryDark,
        onSurface: primaryDark,
        onBackground: primaryDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryLight,
        foregroundColor: primaryDark,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: hoverLight,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: primaryLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primaryDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primaryDark, width: 2),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: ColorScheme.dark(
        primary: primaryLight,
        secondary: hoverDark,
        surface: primaryDark,
        background: primaryDark,
        onPrimary: primaryDark,
        onSecondary: primaryLight,
        onSurface: primaryLight,
        onBackground: primaryLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: primaryLight,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: hoverDark,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: primaryDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primaryLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primaryLight, width: 2),
        ),
      ),
    );
  }
}