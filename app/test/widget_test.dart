import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signa/main.dart';

void main() {
  testWidgets('Signa app boots', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const SignaApp());
    await tester.pump();
    expect(find.text('Signa'), findsWidgets);
  });
}
