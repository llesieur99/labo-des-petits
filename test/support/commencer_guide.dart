import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> commencerGuide(WidgetTester tester) async {
  final jouer = find.byKey(const ValueKey('guide.commencer'));
  if (jouer.evaluate().isNotEmpty) {
    await tester.ensureVisible(jouer);
    await tester.tap(jouer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}
