import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m5_ordre/ordre.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';

/// Le moteur ne parle qu'à travers ce contrat : on enregistre tout.
class _FakeRappels implements RappelsMoteur {
  int reussites = 0;
  int rates = 0;
  final List<String> dits = <String>[];

  @override
  void itemReussi() => reussites++;

  @override
  void essaiRate() => rates++;

  @override
  Future<void> dire(String clipId) async => dits.add(clipId);

  @override
  Future<void> jouerSon(String asset) async {}
}

class _RappelsNarration extends _FakeRappels {
  final attente = Completer<void>();
  @override
  Future<void> dire(String clipId) async {
    dits.add(clipId);
    await attente.future;
  }
}

void main() {
  const lexique = <String, EntreeLexique>{
    'graine': EntreeLexique(texte: 'graine'),
    'arrosoir': EntreeLexique(texte: 'arrosoir'),
    'fleur': EntreeLexique(texte: 'fleur'),
  };

  // L'histoire juste (graine → arrosoir → fleur) ; les images du bas sont
  // déjà mélangées par le générateur et le moteur les garde telles quelles.
  final manche = Manche(
    id: 'histoire.graine',
    clipsConsigne: const ['consigne.histoire'],
    options: const [
      OptionManche(id: 'fleur', concept: 'fleur'),
      OptionManche(id: 'graine', concept: 'graine'),
      OptionManche(id: 'arrosoir', concept: 'arrosoir'),
    ],
    donnees: const DonneesOrdre(
      cases: ['graine', 'arrosoir', 'fleur'],
      narrationCle: 'histoire.graine.racontee',
    ),
  );

  Future<void> monter(
    WidgetTester tester,
    _FakeRappels rappels, {
    Manche? aJouer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurOrdre(
            manche: aJouer ?? manche,
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('toucher une mauvaise image rate, et elle reste en bas', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    // La prochaine case attend « graine » : « fleur » n'est pas la bonne.
    await tester.tap(find.byKey(const ValueKey('ordre.image.fleur')));
    await tester.pumpAndSettle();

    expect(rappels.rates, 1);
    expect(rappels.reussites, 0);
    expect(rappels.dits, isEmpty);

    // Rien n'a bougé : les trois images sont encore en bas, aucune case
    // n'est remplie, et le jeu attend toujours la même image.
    expect(find.byType(CibleTactile), findsNWidgets(3));
    expect(find.byKey(const ValueKey('ordre.image.fleur')), findsOneWidget);
  });

  testWidgets('les bonnes images dans l\'ordre disent l\'histoire puis '
      'annoncent la réussite', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    await tester.tap(find.byKey(const ValueKey('ordre.image.graine')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is CibleTactile && w.key.toString().contains('ordre.image.'),
      ),
      findsNWidgets(2),
    );
    expect(rappels.dits, isEmpty);
    expect(rappels.reussites, 0);

    await tester.tap(find.byKey(const ValueKey('ordre.image.arrosoir')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is CibleTactile && w.key.toString().contains('ordre.image.'),
      ),
      findsOneWidget,
    );
    expect(rappels.dits, isEmpty);
    expect(rappels.reussites, 0);

    await tester.tap(find.byKey(const ValueKey('ordre.image.fleur')));
    await tester.pumpAndSettle();

    // L'histoire complète se raconte une fois, puis la manche est réussie.
    expect(rappels.dits, ['histoire.graine.racontee']);
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
    expect(find.byType(CibleTactile), findsNothing);
  });

  testWidgets('une nouvelle histoire dans le même moteur repart de zéro', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    // On commence la première histoire…
    await tester.tap(find.byKey(const ValueKey('ordre.image.graine')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is CibleTactile && w.key.toString().contains('ordre.image.'),
      ),
      findsNWidgets(2),
    );

    // … puis l'hôte réutilise le moteur pour l'histoire suivante.
    final suivante = Manche(
      id: 'histoire.fleur',
      clipsConsigne: const ['consigne.histoire'],
      options: const [
        OptionManche(id: 'graine', concept: 'graine'),
        OptionManche(id: 'fleur', concept: 'fleur'),
        OptionManche(id: 'arrosoir', concept: 'arrosoir'),
      ],
      donnees: const DonneesOrdre(cases: ['fleur', 'graine', 'arrosoir']),
    );
    await monter(tester, rappels, aJouer: suivante);

    // Les trois images sont revenues et l'ordre attendu est celui du neuf.
    expect(find.byType(CibleTactile), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('ordre.image.fleur')));
    await tester.pumpAndSettle();
    expect(rappels.rates, 0);
    expect(
      find.byWidgetPredicate(
        (w) => w is CibleTactile && w.key.toString().contains('ordre.image.'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets(
    'retirer la dernière image permet de la replacer sans perdre la séquence',
    (tester) async {
      final rappels = _FakeRappels();
      await monter(tester, rappels);
      await tester.tap(find.byKey(const ValueKey('ordre.image.graine')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ordre.case.0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ordre.image.graine')), findsOneWidget);
      expect(rappels.rates, 0);
      for (final concept in ['graine', 'arrosoir', 'fleur']) {
        await tester.tap(find.byKey(ValueKey('ordre.image.$concept')));
        await tester.pumpAndSettle();
      }
      expect(rappels.reussites, 1);
    },
  );

  testWidgets('toutes les cibles font au moins 80 points de côté', (
    tester,
  ) async {
    await monter(tester, _FakeRappels());

    expect(find.byType(CibleTactile), findsNWidgets(3));
    for (final element in find.byType(CibleTactile).evaluate()) {
      final taille = tester.getSize(find.byWidget(element.widget));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }

    // Les cases de l'histoire sont aussi assez grandes pour recevoir l'image.
    for (var i = 0; i < 3; i++) {
      final taille = tester.getSize(find.byKey(ValueKey('ordre.case.$i')));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }
  });
  testWidgets('poser une image garde les autres à la même taille et place', (
    tester,
  ) async {
    await monter(tester, _FakeRappels());
    final fleur = find.byKey(const ValueKey('ordre.image.fleur'));
    final avant = tester.getRect(fleur);
    await tester.tap(find.byKey(const ValueKey('ordre.image.graine')));
    await tester.pumpAndSettle();
    expect(tester.getRect(fleur), avant);
  });

  testWidgets('petit paysage : histoire et options restent accessibles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rappels = _FakeRappels();
    await monter(tester, rappels);
    for (final concept in ['graine', 'arrosoir', 'fleur']) {
      final carte = find.byKey(ValueKey('ordre.image.$concept'));
      await tester.ensureVisible(carte);
      await tester.tap(carte);
      await tester.pumpAndSettle();
    }
    expect(rappels.reussites, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('une ancienne histoire ne valide pas la nouvelle manche', (
    tester,
  ) async {
    final rappels = _RappelsNarration();
    await monter(tester, rappels);
    for (final concept in ['graine', 'arrosoir', 'fleur']) {
      await tester.tap(find.byKey(ValueKey('ordre.image.$concept')));
      await tester.pumpAndSettle();
    }
    await monter(
      tester,
      rappels,
      aJouer: const Manche(
        id: 'autre',
        clipsConsigne: [],
        options: [OptionManche(id: 'fleur', concept: 'fleur')],
        donnees: DonneesOrdre(cases: ['fleur']),
      ),
    );
    rappels.attente.complete();
    await tester.pump();
    expect(rappels.reussites, 0);
  });
}
