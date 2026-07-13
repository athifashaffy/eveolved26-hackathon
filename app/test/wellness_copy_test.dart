import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release copy contains no clinical or automatic-monitoring claims',
      () async {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final buffer = StringBuffer();
    for (final file in files) {
      buffer.writeln(await file.readAsString());
    }
    buffer.writeln(await File('pubspec.yaml').readAsString());
    final text = buffer.toString().toLowerCase();

    for (final phrase in <String>[
      'continuous depression monitoring',
      'depression risk',
      'clinical threshold',
      'clinician notified',
      'notified automatically',
      'health canada samd',
    ]) {
      expect(text, isNot(contains(phrase)), reason: phrase);
    }
  });
}
