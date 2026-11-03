import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m1_tap_pick/tap_pick.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';

void main() {
  const lexique = <String, EntreeLexique>{
    'chat': EntreeLexique(texte: 'chat'),
    'rat': EntreeLexique(texte: 'rat'),
  };

  final manche = Manche(
    id: 'rimes.chapeau.chat',
    clipsConsigne: const ['consigne.rimes.g1', 'lex.chapeau'],
    options: const [
      OptionManche(id: 'chat', concept: 'chat'),
      OptionManche(id: 'rat', concept: 'rat'),
    ],
    bonneOptionId: 'chat',
  );

  testWidgets(
    'affiche chaque option dans une cible tactile et signale le choix',
    (tester) async {
      String? choix;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoteurTapPick(
              manche: manche,
              options: manche.options,
              lexique: lexique,
              onChoix: (option) => choix = option.id,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CibleTactile), findsNWidgets(2));

      await tester.tap(find.byType(CibleTactile).first);
      expect(choix, 'chat');
    },
  );

  testWidgets('affiche le mot écrit quand on le demande (6-7 ans)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurTapPick(
            manche: manche,
            options: manche.options,
            lexique: lexique,
            afficherMots: true,
            onChoix: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('chat'), findsOneWidget);
    expect(find.text('rat'), findsOneWidget);
  });

  testWidgets('toutes les cibles font au moins 80 points de côté', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurTapPick(
            manche: manche,
            options: manche.options,
            lexique: lexique,
            onChoix: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    for (final element in find.byType(CibleTactile).evaluate()) {
      final taille = tester.getSize(find.byWidget(element.widget));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }
  });

  testWidgets('l’aide est illustrée sans dévoiler la réponse au départ', (
    tester,
  ) async {
    Future<void> monter(bool aide) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurTapPick(
            manche: manche,
            options: manche.options,
            lexique: lexique,
            montrerIndice: aide,
            onChoix: (_) {},
          ),
        ),
      ),
    );
    await monter(false);
    expect(find.byIcon(Icons.touch_app_rounded), findsNothing);
    await monter(true);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tapPick.option.chat')),
        matching: find.byIcon(Icons.touch_app_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tapPick.option.rat')),
        matching: find.byIcon(Icons.touch_app_rounded),
      ),
      findsNothing,
    );
  });
}
