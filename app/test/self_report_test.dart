import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/models.dart';

void main() {
  test('SelfReport round-trips through toMap/fromMap', () {
    final r = SelfReport(
      date: DateTime(2026, 6, 23),
      sleepRating: 4,
      moodRating: 3,
      notes: 'slept ok',
      createdAt: DateTime(2026, 6, 23, 8, 30),
    );
    final back = SelfReport.fromMap(r.toMap());
    expect(back.sleepRating, 4);
    expect(back.moodRating, 3);
    expect(back.notes, 'slept ok');
    expect(SelfReport.dateKey(back.date), '2026-06-23');
  });

  test('SelfReport.toJson omits created_at and never returns null notes', () {
    final r = SelfReport(
      date: DateTime(2026, 1, 5),
      sleepRating: 1,
      moodRating: 2,
      notes: null,
      createdAt: DateTime(2026, 1, 5),
    );
    final j = r.toJson();
    expect(j['date'], '2026-01-05');
    expect(j['notes'], '');
    expect(j.containsKey('created_at'), false);
  });
}
