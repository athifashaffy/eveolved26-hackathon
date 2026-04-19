import 'dart:convert';
import 'package:flutter/services.dart';
import 'database_service.dart';
import 'fitbit_service.dart';
import 'healthkit_service.dart';
import 'models.dart';

/// Single source of truth for stability readings.
///
/// Priority on sync: Fitbit → HealthKit → bundled JSON demo data.
/// All readings are persisted to SQLite. On cold start, loads from SQLite
/// first for instant display, then refreshes in the background.
class RealData {
  RealData._();

  static StabilitySnapshot? _snapshot;
  static String _deviceName = 'Demo Data';
  static DateTime _lastFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);

  static StabilitySnapshot snapshot() => _snapshot ?? _fallback();

  /// Load data. On first call loads from SQLite immediately, then refreshes
  /// from remote if stale (>15 min). Safe to call on every foreground resume.
  static Future<void> load() async {
    // Always show cached SQLite data immediately
    if (_snapshot == null) {
      await _loadFromDb();
    }

    // Only re-fetch remote data if stale
    final stale = DateTime.now().difference(_lastFetchedAt).inMinutes >= 15;
    if (!stale) return;

    await _fetchRemote();
  }

  /// Force a fresh sync from the connected device.
  static Future<void> forceSync() async {
    _lastFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
    await _fetchRemote();
  }

  static Future<void> _fetchRemote() async {
    // 1. Try Fitbit
    if (await FitbitService.instance.isAuthenticated()) {
      final readings = await FitbitService.instance.fetchReadings();
      if (readings != null && readings.isNotEmpty) {
        await DatabaseService.instance.upsertReadings(readings, 'fitbit');
        _deviceName = 'Fitbit';
        await _loadFromDb();
        return;
      }
    }

    // 2. Try HealthKit / Health Connect
    if (await HealthKitService.instance.hasPermission()) {
      final readings = await HealthKitService.instance.fetchReadings();
      if (readings != null && readings.isNotEmpty) {
        await DatabaseService.instance.upsertReadings(readings, 'apple_health');
        _deviceName = 'Apple Health';
        await _loadFromDb();
        return;
      }
    }

    // 3. Only seed demo data if DB is completely empty AND no device is connected
    final fitbitConnected = await FitbitService.instance.isAuthenticated();
    final healthConnected = await HealthKitService.instance.hasPermission();
    if (!fitbitConnected && !healthConnected) {
      final existing = await DatabaseService.instance.getReadings();
      if (existing.isEmpty) await _seedFromJson();
    }
  }

  static Future<void> _loadFromDb() async {
    final readings = await DatabaseService.instance.getReadings(days: 90);
    if (readings.isNotEmpty) {
      // Detect source from last reading in DB
      _snapshot = StabilitySnapshot.fromReadings(
        readings,
        deviceName: _deviceName,
        lastSync: Duration(
          minutes: DateTime.now().difference(_lastFetchedAt).inMinutes,
        ),
      );
      _lastFetchedAt = DateTime.now();
    }
  }

  static Future<void> _seedFromJson() async {
    try {
      final raw = await rootBundle.loadString('assets/data/trends.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = json['readings'] as List;
      final readings = list
          .map((e) => StabilityReading.fromJson(e as Map<String, dynamic>))
          .toList();
      await DatabaseService.instance.upsertReadings(readings, 'demo');
      _deviceName = 'Demo Data';
      await _loadFromDb();
    } catch (_) {
      _snapshot = _fallback();
    }
  }

  static StabilitySnapshot _fallback() => StabilitySnapshot.fromReadings(
        const [],
        deviceName: 'No data',
      );
}
