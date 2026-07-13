import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signa/data/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset clears consent, source, demo, and export preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings.instance;
    await settings.setUseDemoData(true);
    await settings.setActiveSource(AppSettings.sourceFitbit);
    await settings.setAppleHealthGranted(true);
    await settings.setLastExport(DateTime(2026, 6, 23), 'pdf');

    await settings.reset();

    expect(settings.useDemoData, isFalse);
    expect(settings.activeSource, isNull);
    expect(settings.appleHealthGranted, isFalse);
    expect(settings.lastExportAt, isNull);
    expect(settings.lastExportFormat, isNull);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
