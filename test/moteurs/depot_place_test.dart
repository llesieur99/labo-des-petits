import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m2_drop_place/depot_place.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/core/widgets/image_concept.dart';

/// Rappels factices : on enregistre tout, on ne fait rien.
class FakeRappels implements RappelsMoteur {
  final List<String> dires = <String>[];
  int reussis = 0;
  int rates = 0;
  Completer<void>? attenteFin;

  @override
  void itemReussi() => reussis++;

  @override
  void essaiRate() => rates++;

  @override
  Future<void> dire(String clipId) async {
    dires.add(clipId);
    if (clipId == 'phrase.test.dite') await attenteFin?.future;
  }

  @override
  Future<void> jouerSon(String asset) async {}
}

/// Aucune couleur rouge alarmante à l'écran (règle : jamais de rouge vif,
/// jamais de « buzzer » pour un enfant).
void aucunRougeAlarmant(WidgetTester tester) {
  for (final element in find.byType(AnimatedContainer).evaluate()) {
    final decoration = (element.widget as AnimatedContainer).decoration;
    if (decoration is! BoxDecoration) continue;
    final couleurs = <Color?>[decoration.color, decoration.border?.top.color];
    for (final couleur in couleurs) {
      if (couleur == null) continue;
      expect(
        couleur.r > 0.75 && couleur.g < 0.45 && couleur.b < 0.45,
        isFalse,
        reason: 'couleur rouge alarmante à l\'écran : $couleur',
      );
    }
  }
}

void main() {
  // Le lexique des manches de test. 'verre' n'existe pas encore dans
  // lexique_qc.dart : le test porte son propre lexique, comme tap_pick_test.
  const lexique = <String, EntreeLexique>{
    'ami': EntreeLexique(texte: 'ami'),
    'assiette': EntreeLexique(texte: 'assiette'),
    'verre': EntreeLexique(texte: 'verre'),
    'panier': EntreeLexique(texte: 'panier'),
    'boite': EntreeLexique(texte: 'boîte'),
  };

  // « Mettre la table » : deux amis, deux assiettes IDENTIQUES — chacune va
  // sur un ami, et n'importe laquelle va sur n'importe quel ami libre.
  final manche = Manche(
    id: 'table.mettre',
    clipsConsigne: const ['consigne.table.g1'],
    donnees: const DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'ami1', concept: 'ami'),
        EmplacementDepot(id: 'ami2', concept: 'ami'),
      ],
      objets: ['assiette', 'assiette'],
      places: {
        'ami1': ['assiette'],
        'ami2': ['assiette'],
      },
    ),
  );

  // Deux objets différents, chacun son ami : pour l'essai raté.
  final mancheVariee = Manche(
    id: 'table.variee',
    clipsConsigne: const ['consigne.table.g2'],
    donnees: const DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'ami1', concept: 'ami'),
        EmplacementDepot(id: 'ami2', concept: 'ami'),
      ],
      objets: ['assiette', 'verre'],
      places: {
        'ami1': ['assiette'],
        'ami2': ['verre'],
      },
    ),
  );

  // Le tri : deux grands bacs, le panier accepte les deux objets.
  final mancheBacs = Manche(
    id: 'tri.bacs',
    clipsConsigne: const ['consigne.tri.g1'],
    donnees: const DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'panier', concept: 'panier'),
        EmplacementDepot(id: 'boite', concept: 'boite'),
      ],
      objets: ['assiette', 'verre'],
      places: {
        'panier': ['assiette', 'verre'],
        'boite': ['assiette'],
      },
      modeBacs: true,
    ),
  );

  Finder objet(int id, String concept) =>
      find.byKey(MoteurDepotPlace.cleObjet(id, concept));

  Finder emplacement(String id) =>
      find.byKey(MoteurDepotPlace.cleEmplacement(id));

  /// Les images d'un emplacement : son dessin, puis les objets posés.
  Finder imagesDans(String id) =>
      find.descendant(of: emplacement(id), matching: find.byType(ImageConcept));

  Future<void> pomper(
    WidgetTester tester,
    FakeRappels rappels, {
    Manche? avec,
    bool afficherMots = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurDepotPlace(
            manche: avec ?? manche,
            lexique: lexique,
            rappels: rappels,
            afficherMots: afficherMots,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Touche l'objet, puis l'emplacement (touche-toucher).
  Future<void> poserAuDoigt(
    WidgetTester tester,
    int id,
    String concept,
    String emplacementId,
  ) async {
    await tester.tap(objet(id, concept));
    await tester.pump();
    await tester.tap(emplacement(emplacementId));
    await tester.pumpAndSettle();
  }

  testWidgets('chaque objet et chaque emplacement est une cible d\'au moins '
      '80 pt', (tester) async {
    await pomper(tester, FakeRappels());

    // Deux emplacements + deux objets dans la barre.
    expect(find.byType(CibleTactile), findsNWidgets(4));

    for (final element in find.byType(CibleTactile).evaluate()) {
      final taille = tester.getSize(find.byWidget(element.widget));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }

    // Les deux amis sont côte à côte sur la scène, la barre est en bas.
    final ami1 = tester.getRect(emplacement('ami1'));
    final ami2 = tester.getRect(emplacement('ami2'));
    final barre = tester.getRect(objet(0, 'assiette'));
    expect(ami1.center.dy, ami2.center.dy);
    expect(ami1.right, lessThanOrEqualTo(ami2.left));
    expect(barre.top, greaterThan(ami1.bottom));
  });

  testWidgets('toucher l\'objet puis le bon emplacement le pose '
      '(touche-toucher, sans glisser)', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    await tester.tap(objet(0, 'assiette'));
    await tester.pump();
    // L'objet est nommé à la prise.
    expect(rappels.dires, ['lex.assiette']);

    await tester.tap(emplacement('ami1'));
    await tester.pumpAndSettle();

    // La première assiette a quitté la barre et se voit sur le premier ami.
    expect(objet(0, 'assiette'), findsNothing);
    expect(objet(1, 'assiette'), findsOneWidget); // la deuxième attend
    expect(imagesDans('ami1'), findsNWidgets(2)); // l'ami, et l'assiette
    expect(imagesDans('ami2'), findsOneWidget); // l'ami seulement
    expect(rappels.rates, 0);
    expect(rappels.reussis, 0); // il reste une assiette à placer
  });

  testWidgets('deux objets identiques : une assiette par ami (l\'emplacement '
      'occupé refuse)', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    await poserAuDoigt(tester, 0, 'assiette', 'ami1');

    // La deuxième assiette sur l'ami déjà servi : refusée, sans punition.
    await poserAuDoigt(tester, 1, 'assiette', 'ami1');
    expect(rappels.rates, 0);
    expect(imagesDans('ami1'), findsNWidgets(2));
    expect(objet(1, 'assiette'), findsOneWidget); // toujours dans la barre

    // Sur l'autre ami, elle se pose — et la manche est réussie.
    await poserAuDoigt(tester, 1, 'assiette', 'ami2');
    expect(objet(1, 'assiette'), findsNothing);
    expect(imagesDans('ami2'), findsNWidgets(2));
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('glisser l\'objet sur son emplacement le pose aussi', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    final depart = tester.getCenter(objet(0, 'assiette'));
    final arrivee = tester.getCenter(emplacement('ami2'));
    await tester.drag(objet(0, 'assiette'), arrivee - depart);
    await tester.pumpAndSettle();

    // Nommé au début du glisser.
    expect(rappels.dires, ['lex.assiette']);
    expect(objet(0, 'assiette'), findsNothing);
    expect(imagesDans('ami2'), findsNWidgets(2));
    expect(rappels.rates, 0);
  });

  testWidgets('mauvais emplacement : l\'objet revient dans la barre et '
      'essaiRate est appelé', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels, avec: mancheVariee);

    // Le verre va sur le deuxième ami : viser le premier est une erreur.
    await poserAuDoigt(tester, 1, 'verre', 'ami1');

    expect(rappels.rates, 1);
    expect(rappels.reussis, 0);
    expect(objet(1, 'verre'), findsOneWidget); // toujours dans la barre
    expect(imagesDans('ami1'), findsOneWidget); // rien n'a été posé
    // L'erreur n'est jamais rouge : seulement un léger balancement.
    aucunRougeAlarmant(tester);
  });

  testWidgets('toucher l\'objet en main le repose dans la barre', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    await tester.tap(objet(0, 'assiette'));
    await tester.pump();
    await tester.tap(objet(0, 'assiette')); // on le repose
    await tester.pump();
    await tester.tap(emplacement('ami1')); // plus rien en main
    await tester.pumpAndSettle();

    expect(objet(0, 'assiette'), findsOneWidget);
    expect(imagesDans('ami1'), findsOneWidget);
    expect(rappels.rates, 0);
    expect(rappels.reussis, 0);
  });

  testWidgets('quand tous les objets sont placés, itemReussi est appelé '
      'une seule fois', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    await poserAuDoigt(tester, 0, 'assiette', 'ami1');
    expect(rappels.reussis, 0);

    await poserAuDoigt(tester, 1, 'assiette', 'ami2');
    expect(rappels.reussis, 1);
    expect(objet(0, 'assiette'), findsNothing);
    expect(objet(1, 'assiette'), findsNothing);

    // Toucher un emplacement ne refait pas réussir la manche.
    await tester.tap(emplacement('ami1'));
    await tester.pumpAndSettle();
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('dire n\'est pas spamé : une fois par prise', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels, avec: mancheVariee);

    await tester.tap(objet(0, 'assiette'));
    await tester.pump();
    expect(rappels.dires, ['lex.assiette']);

    // L'objet en main, un essai raté ne dit rien de plus.
    await tester.tap(emplacement('ami2'));
    await tester.pumpAndSettle();
    expect(rappels.dires, ['lex.assiette']);
    expect(rappels.rates, 1);

    // Des doigts sans objet en main ne disent jamais rien.
    await tester.tap(emplacement('ami1'));
    await tester.pumpAndSettle();
    expect(rappels.dires, ['lex.assiette']);

    // Une nouvelle prise le nomme de nouveau : c'est permis.
    await tester.tap(objet(0, 'assiette'));
    await tester.pump();
    expect(rappels.dires, ['lex.assiette', 'lex.assiette']);
  });

  testWidgets(
    'le tri laisse chercher puis indique une place après deux essais',
    (tester) async {
      final rappels = FakeRappels();
      await pomper(tester, rappels, avec: mancheVariee);

      await tester.tap(objet(1, 'verre'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.touch_app_rounded), findsNothing);
      Color bordure(String id) {
        final cartes = find.descendant(
          of: emplacement(id),
          matching: find.byType(AnimatedContainer),
        );
        final decoration =
            (tester.widget<AnimatedContainer>(cartes.first).decoration
                as BoxDecoration);
        return decoration.border!.top.color;
      }

      expect(
        bordure('ami1'),
        bordure('ami2'),
        reason: 'la prise ne doit pas révéler immédiatement la réponse',
      );
      await tester.tap(emplacement('ami1'));
      await tester.pumpAndSettle();
      await poserAuDoigt(tester, 1, 'verre', 'ami1');
      await tester.tap(objet(1, 'verre'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: emplacement('ami2'),
          matching: find.byIcon(Icons.touch_app_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: emplacement('ami1'),
          matching: find.byIcon(Icons.touch_app_rounded),
        ),
        findsNothing,
      );
      await tester.tap(emplacement('ami2'));
      await tester.pumpAndSettle();
      expect(imagesDans('ami2'), findsNWidgets(2));
    },
  );

  testWidgets('une nouvelle manche de même id remet les objets et les places', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);
    await poserAuDoigt(tester, 0, 'assiette', 'ami1');
    await pomper(
      tester,
      rappels,
      avec: Manche(
        id: manche.id,
        clipsConsigne: manche.clipsConsigne,
        donnees: manche.donnees,
      ),
    );
    expect(objet(0, 'assiette'), findsOneWidget);
    expect(imagesDans('ami1'), findsOneWidget);
  });

  testWidgets('modeBacs : deux grands bacs, les objets s\'y empilent en '
      'minuscules', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels, avec: mancheBacs);

    final panier = tester.getSize(emplacement('panier'));
    final boite = tester.getSize(emplacement('boite'));
    expect(panier.width, greaterThan(200)); // de GRANDS bacs
    expect(panier.height, greaterThan(150));
    expect(boite.width, panier.width); // côte à côte, de même taille

    // Un objet mal trié reste dans la barre.
    await poserAuDoigt(tester, 1, 'verre', 'boite');
    expect(rappels.rates, 1);
    expect(objet(1, 'verre'), findsOneWidget);
    expect(imagesDans('boite'), findsOneWidget);

    // Le panier, lui, accepte les deux objets : ils s'y empilent.
    await poserAuDoigt(tester, 0, 'assiette', 'panier');
    expect(rappels.reussis, 0);
    await poserAuDoigt(tester, 1, 'verre', 'panier');
    expect(rappels.reussis, 1);
    expect(objet(0, 'assiette'), findsNothing);
    expect(objet(1, 'verre'), findsNothing);

    final images = imagesDans('panier');
    expect(images, findsNWidgets(3)); // le panier + les deux objets posés
    final dessinBac = tester.getSize(images.at(0));
    final objetPose = tester.getSize(images.at(1));
    expect(objetPose.width, lessThan(dessinBac.width * 0.75)); // minuscule
  });

  testWidgets('tient sur un écran de téléphone, mots écrits (6-7 ans)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rappels = FakeRappels();
    await pomper(tester, rappels, avec: mancheVariee, afficherMots: true);

    expect(find.text('assiette'), findsOneWidget);
    expect(find.text('verre'), findsOneWidget);

    for (final element in find.byType(CibleTactile).evaluate()) {
      final taille = tester.getSize(find.byWidget(element.widget));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }

    // Et la manche reste jouable à cette taille.
    await poserAuDoigt(tester, 0, 'assiette', 'ami1');
    expect(rappels.rates, 0);
    expect(rappels.reussis, 0);
  });

  testWidgets('le clip de fin (finCle) est dit juste avant la réussite', (
    tester,
  ) async {
    // La phrase reconstruite doit s'entendre quand tout est en place.
    const manchePhrase = Manche(
      id: 'phrase.test',
      clipsConsigne: ['consigne.phrase.g1'],
      options: [
        OptionManche(id: 'chat', concept: 'chat'),
        OptionManche(id: 'pomme', concept: 'pomme'),
      ],
      donnees: DonneesDepot(
        emplacements: [
          EmplacementDepot(id: 'c1', concept: 'casier'),
          EmplacementDepot(id: 'c2', concept: 'casier'),
        ],
        objets: ['chat', 'pomme'],
        places: {
          'c1': ['chat'],
          'c2': ['pomme'],
        },
        finCle: 'phrase.test.dite',
      ),
    );

    final rappels = FakeRappels();
    await pomper(tester, rappels, avec: manchePhrase);

    await poserAuDoigt(tester, 0, 'chat', 'c1');
    expect(
      rappels.reussis,
      0,
      reason: 'la phrase se dit seulement quand tout est en place',
    );

    await poserAuDoigt(tester, 1, 'pomme', 'c2');
    await tester.pumpAndSettle();
    expect(rappels.dires, contains('phrase.test.dite'));
    expect(rappels.reussis, 1);
  });

  testWidgets('une fin audio retardée ne valide pas la manche suivante', (
    tester,
  ) async {
    final rappels = FakeRappels()..attenteFin = Completer<void>();
    const phrase = Manche(
      id: 'phrase.test',
      clipsConsigne: [],
      donnees: DonneesDepot(
        emplacements: [EmplacementDepot(id: 'ami1', concept: 'ami')],
        objets: ['assiette'],
        places: {
          'ami1': ['assiette'],
        },
        finCle: 'phrase.test.dite',
      ),
    );
    await pomper(tester, rappels, avec: phrase);
    await poserAuDoigt(tester, 0, 'assiette', 'ami1');
    expect(rappels.dires, contains('phrase.test.dite'));
    expect(rappels.reussis, 0);
    await pomper(tester, rappels, avec: mancheVariee);
    rappels.attenteFin!.complete();
    await tester.pumpAndSettle();
    expect(rappels.reussis, 0);
    expect(objet(0, 'assiette'), findsOneWidget);
  });
}
