import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/daily_signal.dart';
import '../domain/wellness_score.dart';
import '../scoring/baseline_engine.dart';
import '../scoring/insight_engine.dart';
import 'app_settings.dart';
import 'daily_signal_repository.dart';
import 'database_service.dart';
import 'fitbit_service.dart';
import 'health_data_source.dart';
import 'healthkit_service.dart';
import 'models.dart';

class WellnessViewSnapshot {
  final WellnessScore wellness;
  final List<DailySignal> signals;
  final WellnessInsight insight;
  final DateTime? lastSyncAt;
  final String? syncIssue;

  const WellnessViewSnapshot({
    required this.wellness,
    required this.signals,
    required this.insight,
    required this.lastSyncAt,
    this.syncIssue,
  });

  WellnessViewSnapshot copyWith({String? syncIssue}) => WellnessViewSnapshot(
        wellness: wellness,
        signals: signals,
        insight: insight,
        lastSyncAt: lastSyncAt,
        syncIssue: syncIssue,
      );
}

class WellnessDataController {
  final DailySignalRepository repository;
  final HealthDataSource source;
  final BaselineEngine baselineEngine;
  final InsightEngine insightEngine;
  final DateTime Function() clock;

  WellnessViewSnapshot? _snapshot;
  DateTime? _lastFetchAttempt;

  WellnessDataController({
    required this.repository,
    required this.source,
    required this.baselineEngine,
    required this.insightEngine,
    required this.clock,
  });

  WellnessViewSnapshot? get current => _snapshot;

  Future<WellnessViewSnapshot> load({bool refreshIfStale = true}) async {
    _snapshot ??= await _recompute();
    final stale = _lastFetchAttempt == null ||
        clock().difference(_lastFetchAttempt!).inMinutes >= 15;
    if (refreshIfStale && stale) return forceSync();
    return _snapshot!;
  }

  Future<WellnessViewSnapshot> forceSync() async {
    final now = clock();
    _lastFetchAttempt = now;
    final result = await source.fetch(
      now.subtract(const Duration(days: 90)),
      now,
    );
    if (!result.isSuccess) {
      _snapshot ??= await _recompute();
      _snapshot = _snapshot!.copyWith(syncIssue: result.failure!.name);
      return _snapshot!;
    }
    await repository.upsertSignals(result.signals);
    _snapshot = await _recompute(lastSyncAt: result.fetchedAt ?? now);
    return _snapshot!;
  }

  Future<WellnessViewSnapshot> _recompute({DateTime? lastSyncAt}) async {
    final signals = await repository.getSignals();
    final reports = await repository.getSelfReports();
    final wellness = baselineEngine.evaluate(signals, reports, clock());
    await repository.saveScore(wellness);
    return WellnessViewSnapshot(
      wellness: wellness,
      signals: signals,
      insight: insightEngine.build(wellness),
      lastSyncAt: lastSyncAt,
    );
  }
}

/// Single source of truth for stability readings.
///
/// Behaviour depends on [AppSettings.useDemoData]:
///  - Demo mode ON  → seeds and reads only the bundled JSON dataset.
///  - Demo mode OFF → only Fitbit / HealthKit, gated by [AppSettings.activeSource].
/// All readings are persisted to SQLite tagged with their source. On cold
/// start, loads from SQLite first for instant display, then refreshes in
/// the background.
class RealData {
  RealData._();

  static const _demoSources = ['demo'];

  static StabilitySnapshot? _snapshot;
  static WellnessViewSnapshot? _wellnessView;
  static String _deviceName = 'Demo Data';
  static DateTime _lastFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);

  static StabilitySnapshot snapshot() => _snapshot ?? _fallback();

  static WellnessViewSnapshot? wellnessSnapshot() => _wellnessView;

  /// Load data. On first call loads from SQLite immediately, then refreshes
  /// from remote if stale (>15 min). Safe to call on every foreground resume.
  static Future<void> load() async {
    if (_snapshot == null) {
      await _loadFromDb(await _currentSources());
    }

    final stale = DateTime.now().difference(_lastFetchedAt).inMinutes >= 15;
    if (!stale) return;

    await _fetchRemote();
  }

  /// Force a fresh sync from the connected device (or re-seed demo data).
  static Future<void> forceSync() async {
    _lastFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
    _snapshot = null;
    await _fetchRemote();
  }

  /// Call after a device finishes pairing successfully. If no active source
  /// is set yet, the just-paired device becomes active automatically (the
  /// "first device wins" default). Then triggers a fresh sync.
  static Future<void> onDeviceConnected(String source) async {
    if (AppSettings.instance.activeSource == null) {
      await AppSettings.instance.setActiveSource(source);
    }
    await forceSync();
  }

  /// Call after a device is unpaired. If it was the active source, promote
  /// the other device if it's still authorised; otherwise clear the active
  /// source. Then triggers a fresh sync.
  static Future<void> onDeviceDisconnected(String source) async {
    if (AppSettings.instance.activeSource != source) {
      await forceSync();
      return;
    }
    final other = source == AppSettings.sourceFitbit
        ? AppSettings.sourceAppleHealth
        : AppSettings.sourceFitbit;
    final otherStillConnected = await _isSourceAuthorised(other);
    await AppSettings.instance
        .setActiveSource(otherStillConnected ? other : null);
    await forceSync();
  }

  /// User-initiated active-source switch from the Connect screen.
  static Future<void> setActiveSource(String source) async {
    await AppSettings.instance.setActiveSource(source);
    await forceSync();
  }

  static Future<void> _fetchRemote() async {
    if (AppSettings.instance.useDemoData) {
      await _ensureDemoSeeded();
      _deviceName = 'Demo Data';
      await _loadFromDb(_demoSources);
      return;
    }

    // Live mode: prefer the user-chosen active source. If it's no longer
    // authorised, fall back to the other; if neither, show empty state.
    final source = await _resolveLiveSource();
    if (source == null) {
      _deviceName = 'No device connected';
      _snapshot = StabilitySnapshot.fromReadings(
        const [],
        deviceName: _deviceName,
      );
      _lastFetchedAt = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final adapter = source == AppSettings.sourceFitbit
        ? FitbitService.instance
        : HealthKitService.instance;
    final result = await adapter.fetch(
      now.subtract(const Duration(days: 90)),
      now,
    );
    _deviceName =
        source == AppSettings.sourceFitbit ? 'Fitbit' : 'Apple Health';
    final repository = DailySignalRepository(await DatabaseService.instance.db);
    if (result.isSuccess) {
      await repository.upsertSignals(result.signals);
      await _loadWellnessFromDb(
        repository,
        lastSyncAt: result.fetchedAt ?? now,
      );
    } else {
      await _loadWellnessFromDb(
        repository,
        syncIssue: result.failure?.name,
      );
    }
  }

  /// Resolve which live source to use this fetch. Promotes/repairs the
  /// stored [activeSource] if it has gone stale (e.g. user revoked Fitbit).
  static Future<String?> _resolveLiveSource() async {
    final stored = AppSettings.instance.activeSource;
    if (stored != null && await _isSourceAuthorised(stored)) {
      return stored;
    }
    // Stored choice no longer valid — try to promote the other.
    for (final candidate in const [
      AppSettings.sourceFitbit,
      AppSettings.sourceAppleHealth,
    ]) {
      if (await _isSourceAuthorised(candidate)) {
        await AppSettings.instance.setActiveSource(candidate);
        return candidate;
      }
    }
    if (stored != null) {
      await AppSettings.instance.setActiveSource(null);
    }
    return null;
  }

  static Future<bool> _isSourceAuthorised(String source) {
    switch (source) {
      case AppSettings.sourceFitbit:
        return FitbitService.instance.isAuthenticated();
      case AppSettings.sourceAppleHealth:
        return HealthKitService.instance.hasPermission();
      default:
        return Future.value(false);
    }
  }

  static Future<void> _ensureDemoSeeded() async {
    final existing =
        await DatabaseService.instance.getReadings(sources: _demoSources);
    if (existing.isEmpty) await _seedFromJson();
  }

  static Future<void> _loadFromDb(List<String> sources) async {
    if (!AppSettings.instance.useDemoData) {
      await _loadWellnessFromDb(
        DailySignalRepository(await DatabaseService.instance.db),
      );
      return;
    }
    final readings =
        await DatabaseService.instance.getReadings(days: 90, sources: sources);
    if (readings.isEmpty) {
      _snapshot = StabilitySnapshot.fromReadings(
        const [],
        deviceName: _deviceName,
      );
      _lastFetchedAt = DateTime.now();
      return;
    }
    _snapshot = StabilitySnapshot.fromReadings(
      readings,
      deviceName: _deviceName,
      lastSync: Duration(
        minutes: DateTime.now().difference(_lastFetchedAt).inMinutes,
      ),
    );
    _lastFetchedAt = DateTime.now();
  }

  static Future<void> _loadWellnessFromDb(
    DailySignalRepository repository, {
    DateTime? lastSyncAt,
    String? syncIssue,
  }) async {
    final signals = await repository.getSignals();
    final reports = await repository.getSelfReports();
    final wellness =
        BaselineEngine().evaluate(signals, reports, DateTime.now());
    await repository.saveScore(wellness);
    _wellnessView = WellnessViewSnapshot(
      wellness: wellness,
      signals: signals,
      insight: const InsightEngine().build(wellness),
      lastSyncAt: lastSyncAt,
      syncIssue: syncIssue,
    );
    final normalizedScore = (wellness.score ?? 0) / 100;
    final readings = signals.map((signal) {
      final sleepMinutes = signal.sleepMinutes ?? 0;
      return StabilityReading(
        date: signal.date,
        score: normalizedScore,
        hrvMs: signal.hrvMs?.round() ?? 0,
        sleepMinutes: sleepMinutes,
        sleepScore: (sleepMinutes / 480 * 100).clamp(0, 100).round(),
        steps: signal.steps ?? 0,
      );
    }).toList();
    _snapshot = StabilitySnapshot.fromReadings(
      readings,
      deviceName: _deviceName,
      lastSync: lastSyncAt == null
          ? Duration.zero
          : DateTime.now().difference(lastSyncAt),
    );
    _lastFetchedAt = DateTime.now();
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
    } catch (_) {
      // Bundled asset missing — leave DB empty; _loadFromDb produces fallback.
    }
  }

  /// Sources to read from DB on cold start, before [_fetchRemote] runs.
  static Future<List<String>> _currentSources() async {
    if (AppSettings.instance.useDemoData) return _demoSources;
    final resolved = await _resolveLiveSource();
    return resolved == null ? const <String>[] : [resolved];
  }

  static StabilitySnapshot _fallback() => StabilitySnapshot.fromReadings(
        const [],
        deviceName: AppSettings.instance.useDemoData
            ? 'Demo Data'
            : 'No device connected',
      );
}
