import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('canonical and adaptive brand assets meet the icon contract', () {
    final canonicalFile = File('assets/brand/signa-s-1024.png');
    final foregroundFile = File('assets/brand/signa-s-foreground.png');
    expect(canonicalFile.existsSync(), isTrue);
    expect(foregroundFile.existsSync(), isTrue);

    final canonical = image.decodePng(canonicalFile.readAsBytesSync())!;
    final foreground = image.decodePng(foregroundFile.readAsBytesSync())!;
    expect((canonical.width, canonical.height), (1024, 1024));
    expect((foreground.width, foreground.height), (1024, 1024));
    expect(canonical.numChannels, lessThan(4));
    expect(foreground.numChannels, 4);

    for (final point in <(int, int)>[
      (0, 0),
      (1023, 0),
      (0, 1023),
      (1023, 1023),
    ]) {
      final pixel = canonical.getPixel(point.$1, point.$2);
      expect(
          (pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()), (251, 247, 236));
      expect(foreground.getPixel(point.$1, point.$2).a.toInt(), 0);
    }

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/brand/signa-s-1024.png'));
    expect(pubspec, contains('assets/brand/signa-s-foreground.png'));
  });
}
