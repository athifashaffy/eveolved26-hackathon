import 'package:flutter_test/flutter_test.dart';
import 'package:signa/domain/daily_signal.dart';
import 'package:signa/screens/trends_screen.dart';

void main() {
  test('7, 30, and 90 day ranges filter actual signal dates', () {
    final now = DateTime(2026, 7, 13);
    final signals = List<DailySignal>.generate(
      100,
      (index) => DailySignal(
        date: now.subtract(Duration(days: 99 - index)),
        source: SignalSource.healthConnect,
        sleepMinutes: 420,
        hrvMs: 50,
      ),
    );

    expect(filterSignalsForRange(signals, now, 7), hasLength(7));
    expect(filterSignalsForRange(signals, now, 30), hasLength(30));
    expect(filterSignalsForRange(signals, now, 90), hasLength(90));
  });

  test('range filter preserves null gaps instead of filling zero', () {
    final now = DateTime(2026, 7, 13);
    final result = filterSignalsForRange(
      <DailySignal>[
        DailySignal(
          date: now,
          source: SignalSource.healthConnect,
          sleepMinutes: 420,
        ),
      ],
      now,
      7,
    );

    expect(result.single.hrvMs, isNull);
    expect(result.single.steps, isNull);
  });
}
