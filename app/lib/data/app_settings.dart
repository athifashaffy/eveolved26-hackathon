import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences persisted in SharedPreferences.
///
/// Call [load] once from `main()` before reading any setting.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _kUseDemoData = 'use_demo_data';
  static const _kActiveSource = 'active_source';
  static const _kAppleHealthGranted = 'apple_health_granted';

  /// Constants for the [activeSource] preference.
  static const sourceFitbit = 'fitbit';
  static const sourceAppleHealth = 'apple_health';

  bool _useDemoData = true;
  String? _activeSource;
  bool _appleHealthGranted = false;

  bool get useDemoData => _useDemoData;

  /// The watch data source the user has chosen as authoritative when both
  /// Fitbit and Apple Health are paired. `null` means no live source has
  /// been picked yet (cold start / nothing connected).
  String? get activeSource => _activeSource;

  /// True once the user has tapped through the iOS HealthKit auth sheet at
  /// least once. iOS deliberately hides read-permission grant state from
  /// apps, so we rely on this persisted flag instead of the package's
  /// `hasPermissions()` result (which returns null on iOS for read types).
  bool get appleHealthGranted => _appleHealthGranted;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _useDemoData = prefs.getBool(_kUseDemoData) ?? true;
    _activeSource = prefs.getString(_kActiveSource);
    _appleHealthGranted = prefs.getBool(_kAppleHealthGranted) ?? false;
  }

  Future<void> setUseDemoData(bool value) async {
    _useDemoData = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseDemoData, value);
  }

  Future<void> setActiveSource(String? value) async {
    _activeSource = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_kActiveSource);
    } else {
      await prefs.setString(_kActiveSource, value);
    }
  }

  Future<void> setAppleHealthGranted(bool value) async {
    _appleHealthGranted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAppleHealthGranted, value);
  }
}
