import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/parent/courriel_retour.dart';
import 'package:jeux_enfants/features/parent/retour_parent_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'le pont natif prépare seulement l’adresse et le texte du parent',
    () async {
      const canal = MethodChannel('ca.lesieur.jeuxEnfants/retours_parent');
      final messager =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? appel;
      messager.setMockMethodCallHandler(canal, (valeur) async {
        appel = valeur;
        return true;
      });
      addTearDown(() => messager.setMockMethodCallHandler(canal, null));

      final ouvert = await CourrielRetour.ouvrir(
        'Une idée',
        'Des couleurs douces',
      );
      expect(ouvert, isTrue);
      expect(appel?.method, 'ouvrirCourriel');
      expect(appel?.arguments, {
        'adresse': 'support@le-sieur.ca',
        'sujet': 'Une idée',
        'message': 'Des couleurs douces',
      });
    },
  );

  testWidgets('le parent relit son message avant de choisir son courriel', (
    tester,
  ) async {
    final brouillons = <(String, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RetourParentScreen(
          ouvrirCourriel: (sujet, message) async {
            brouillons.add((sujet, message));
            return true;
          },
        ),
      ),
    );

    final envoyer = find.byKey(const ValueKey('retour.ouvrirCourriel'));
    await tester.scrollUntilVisible(
      envoyer,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(envoyer).onPressed, isNull);
    expect(brouillons, isEmpty);
    final commentaire = find.byKey(const ValueKey('retour.type.commentaire'));
    await tester.scrollUntilVisible(
      commentaire,
      -240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(commentaire);
    await tester.enterText(
      find.byKey(const ValueKey('retour.message')),
      'La chasse aux rimes pourrait proposer un autre animal.',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      envoyer,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(envoyer);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(envoyer).onPressed, isNotNull);
    await tester.tap(envoyer);
    await tester.pump();

    expect(brouillons, [
      (
        'Labo des Petits — Commentaire',
        'La chasse aux rimes pourrait proposer un autre animal.',
      ),
    ]);
  });

  testWidgets('sans application de courriel, le texte reste disponible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RetourParentScreen(ouvrirCourriel: (_, _) async => false),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('retour.message')),
      'Une idée à conserver',
    );
    final ouvrir = find.byKey(const ValueKey('retour.ouvrirCourriel'));
    await tester.scrollUntilVisible(
      ouvrir,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(ouvrir);
    await tester.pump();

    expect(
      find.textContaining('Aucune application de courriel'),
      findsOneWidget,
    );
    expect(find.text('Une idée à conserver'), findsOneWidget);
    expect(find.byKey(const ValueKey('retour.copier')), findsOneWidget);
  });
}
