import 'dart:math';
import 'models.dart';

class MockData {
  static StabilitySnapshot snapshot() {
    final rand = Random(42);
    final now = DateTime.now();
    final last14 = List.generate(14, (i) {
      final t = 13 - i;
      final trend = 0.55 + (i / 13) * 0.35;
      final noise = (rand.nextDouble() - 0.5) * 0.18;
      return StabilityReading(
        now.subtract(Duration(days: t)),
        (trend + noise).clamp(0.0, 1.0),
      );
    });
    final last30 = List.generate(30, (i) {
      final t = 29 - i;
      // Dip around day 14 (the "Mar 15 event" from trends screen).
      final base = 0.72 + sin(i / 4.5) * 0.05;
      final dip = (i >= 12 && i <= 17) ? -0.28 + (i - 14).abs() * 0.05 : 0.0;
      final noise = (rand.nextDouble() - 0.5) * 0.10;
      return StabilityReading(
        now.subtract(Duration(days: t)),
        (base + dip + noise).clamp(0.0, 1.0),
      );
    });

    return StabilitySnapshot(
      score: 0.78,
      status: StabilityStatus.stable,
      deltaPct: 4.2,
      hrvMs: 64,
      hrvDeltaPct: 12,
      sleepScore: 82,
      sleepTrendLabel: 'Stable',
      last14Days: last14,
      last30Days: last30,
      deviceName: 'Apple Watch',
      lastSync: const Duration(minutes: 4),
    );
  }
}
