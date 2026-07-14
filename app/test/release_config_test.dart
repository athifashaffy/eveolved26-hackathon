import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile identifiers, display name, and version are store ready', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(pubspec, contains('version: 1.0.1+6'));
    expect(
      File('lib/app_info.dart').readAsStringSync(),
      contains("kAppVersion = '1.0.1+6'"),
    );
    expect(gradle, contains('applicationId = "com.autobiomarker.signa"'));
    expect(
      project,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.thealphanova.signa;'),
    );
    expect(
      project,
      contains('CURRENT_PROJECT_VERSION = "\$(FLUTTER_BUILD_NUMBER)";'),
    );
    expect(manifest, contains('android:label="Signa"'));
    expect(plist, contains('<string>Signa</string>'));
  });

  test('iOS declares that Signa uses no non-exempt encryption', () {
    final result = Process.runSync(
      'plutil',
      <String>[
        '-extract',
        'ITSAppUsesNonExemptEncryption',
        'raw',
        '-o',
        '-',
        'ios/Runner/Info.plist',
      ],
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), 'false');
  });

  test('release signing never uses debug keys and secrets are ignored', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final ignore = File('../.gitignore').readAsStringSync();

    expect(gradle, contains('key.properties'));
    expect(gradle, isNot(contains('signingConfig = signingConfigs.debug')));
    expect(ignore, contains('key.properties'));
    expect(ignore, contains('*.jks'));
    expect(File('android/key.properties.example').existsSync(), isTrue);
  });
}
