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
  static const _kLastExportAt = 'last_export_at';
  static const _kLastExportFormat = 'last_export_format';

  /// Constants for the [activeSource] preference.
  static const sourceFitbit = 'fitbit';
  static const sourceAppleHealth = 'apple_health';

  bool _useDemoData = true;
  String? _activeSource;
  bool _appleHealthGranted = false;
  DateTime? _lastExportAt;
  String? _lastExportFormat;

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

  /// When the user last shared an export, and which format ('csv' / 'json').
  DateTime? get lastExportAt => _lastExportAt;
  String? get lastExportFormat => _lastExportFormat;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _useDemoData = prefs.getBool(_kUseDemoData) ?? true;
    _activeSource = prefs.getString(_kActiveSource);
    _appleHealthGranted = prefs.getBool(_kAppleHealthGranted) ?? false;
    final ts = prefs.getString(_kLastExportAt);
    _lastExportAt = ts != null ? DateTime.tryParse(ts) : null;
    _lastExportFormat = prefs.getString(_kLastExportFormat);
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

  Future<void> setLastExport(DateTime when, String format) async {
    _lastExportAt = when;
    _lastExportFormat = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastExportAt, when.toIso8601String());
    await prefs.setString(_kLastExportFormat, format);
  }

  /// Clears every persisted Signa preference after the user confirms data
  /// deletion. Live fields are reset too so the current process cannot keep
  /// using stale consent or source state.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _useDemoData = false;
    _activeSource = null;
    _appleHealthGranted = false;
    _lastExportAt = null;
    _lastExportFormat = null;
  }
}
