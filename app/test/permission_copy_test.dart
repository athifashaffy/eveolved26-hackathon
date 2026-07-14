import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native health access is least privilege and wellness framed', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final permission in <String>[
      'android.permission.health.READ_HEART_RATE_VARIABILITY',
      'android.permission.health.READ_SLEEP',
      'android.permission.health.READ_STEPS',
    ]) {
      expect(manifest, contains(permission));
    }
    expect(manifest, isNot(contains('android.permission.health.WRITE_')));

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSHealthShareUsageDescription'));
    expect(plist, contains('NSHealthUpdateUsageDescription'));
    expect(
      plist,
      contains(
        'Signa requests read-only Apple Health access to build your private '
        'wellness baseline. It does not add, edit, or delete Apple Health data.',
      ),
    );
    expect(plist.toLowerCase(), contains('usual range'));
    expect(plist.toLowerCase(), isNot(contains('stability score')));
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('com.apple.developer.healthkit'),
    );
  });

  test('authorization is absent from startup and explained on connect', () {
    final main = File('lib/main.dart').readAsStringSync();
    final connect = File('lib/screens/connect_screen.dart').readAsStringSync();

    expect(main, isNot(contains('requestAuthorization')));
    expect(connect, contains('Connect health data'));
    expect(connect, contains('HRV'));
    expect(connect, contains('sleep'));
    expect(connect, contains('steps'));
  });
}
