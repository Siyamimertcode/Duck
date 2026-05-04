import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central application state — theme, locale, vibration, notifications.
/// Singleton [ChangeNotifier] so any widget tree can listen for changes.
class AppState extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────
  static final AppState instance = AppState._internal();
  factory AppState() => instance;
  AppState._internal();

  // ── Preference keys ────────────────────────────────────────────────
  static const _keyThemeMode = 'app_theme_mode'; // 'light' | 'dark'
  static const _keyLocale = 'app_locale'; // 'tr' | 'en'
  static const _keyVibration = 'app_vibration'; // bool
  static const _keyNotifications = 'notifications_enabled'; // bool

  // ── State ──────────────────────────────────────────────────────────
  ThemeMode _themeMode = ThemeMode.light;
  String _locale = 'tr';
  bool _vibrationEnabled = true;
  bool _notificationsEnabled = true;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  String get locale => _locale;
  bool get isEnglish => _locale == 'en';
  bool get isTurkish => _locale == 'tr';
  bool get vibrationEnabled => _vibrationEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get initialized => _initialized;

  // ── Initialization ─────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final themeStr = prefs.getString(_keyThemeMode) ?? 'light';
      _themeMode = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;

      _locale = prefs.getString(_keyLocale) ?? 'tr';
      _vibrationEnabled = prefs.getBool(_keyVibration) ?? true;
      _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
    } catch (e) {
      // Use defaults if SharedPreferences fails
    }
    _initialized = true;
    notifyListeners();
  }

  // ── Setters (with persistence) ─────────────────────────────────────
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyThemeMode,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> toggleTheme() async {
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setLocale(String locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale);
  }

  Future<void> setVibration(bool enabled) async {
    if (_vibrationEnabled == enabled) return;
    _vibrationEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibration, enabled);
  }

  Future<void> setNotifications(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, enabled);
  }
}
