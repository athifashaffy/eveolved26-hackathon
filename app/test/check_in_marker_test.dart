import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/database_service.dart';
import 'package:signa/domain/timeline_marker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('timeline marker categories and local note round-trip', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DatabaseService.createSchema(db);
    final marker = TimelineMarker(
      id: 'marker-1',
      date: DateTime(2026, 7, 12),
      category: TimelineMarkerCategory.travel,
      note: 'Private note',
      createdAt: DateTime(2026, 7, 12, 20),
    );

    await DatabaseService.upsertTimelineMarkerIn(db, marker);
    final markers = await DatabaseService.getTimelineMarkersFrom(
      db,
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 31),
    );

    expect(markers.single.category, TimelineMarkerCategory.travel);
    expect(markers.single.note, 'Private note');
  });

  test('all supported marker categories serialize by stable name', () {
    for (final category in TimelineMarkerCategory.values) {
      final marker = TimelineMarker(
        id: category.name,
        date: DateTime(2026, 7, 12),
        category: category,
        createdAt: DateTime(2026, 7, 12, 20),
      );

      expect(TimelineMarker.fromMap(marker.toMap()).category, category);
    }
  });
}
