import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';

void main() {
  testWidgets(
    'deux cibles dans un Wrap gardent leurs tailles et leurs actions',
    (tester) async {
      var premier = 0;
      var second = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                CibleTactile(
                  key: const ValueKey('a'),
                  onTap: () => premier++,
                  child: const SizedBox(width: 88, height: 88),
                ),
                CibleTactile(
                  key: const ValueKey('b'),
                  onTap: () => second++,
                  child: const SizedBox(width: 88, height: 88),
                ),
              ],
            ),
          ),
        ),
      );
      final a = find.byKey(const ValueKey('a'));
      final b = find.byKey(const ValueKey('b'));
      expect(tester.getSize(a), const Size(88, 88));
      expect(tester.getRect(a).overlaps(tester.getRect(b)), isFalse);
      await tester.tap(a);
      await tester.tap(b);
      expect(premier, 1);
      expect(second, 1);
    },
  );
}
