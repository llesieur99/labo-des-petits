import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/micro/mic_kit.dart';
import 'package:jeux_enfants/core/moteurs/m7_creation/atelier.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/core/widgets/image_concept.dart';

import '../support/micro_controle.dart';

/// Rappels enregistreurs : on garde la trace de tout ce que l'atelier dit à
/// son hôte (les libellés des groupes, les invitations, la réussite).
class FakeRappels implements RappelsMoteur {
  final List<String> clips = [];
  int reussis = 0;
  int rates = 0;

  @override
  void itemReussi() => reussis++;

  @override
  void essaiRate() => rates++;

  @override
  Future<void> dire(String clipId) async => clips.add(clipId);

  @override
  Future<void> jouerSon(String asset) async {}
}

const _lexique = <String, EntreeLexique>{
  'lion': EntreeLexique(texte: 'lion'),
  'chat': EntreeLexique(texte: 'chat'),
  'canard': EntreeLexique(texte: 'canard'),
  'poisson': EntreeLexique(texte: 'poisson'),
  'souris': EntreeLexique(texte: 'souris'),
  'carotte': EntreeLexique(texte: 'carotte'),
  'banane': EntreeLexique(texte: 'banane'),
  'fromage': EntreeLexique(texte: 'fromage'),
};

/// L'atelier complet : trois groupes (une tête, un corps, une queue), puis le
/// nom, puis la question des bouchées.
const _mancheAtelier = Manche(
  id: 'atelier.bete',
  clipsConsigne: ['consigne.atelier'],
  donnees: DonneesAtelier(
    groupes: [
      GroupeAtelier(
        libelleCle: 'atelier.tete',
        options: ['lion', 'chat', 'canard'],
      ),
      GroupeAtelier(
        libelleCle: 'atelier.corps',
        options: ['poisson', 'souris'],
      ),
      GroupeAtelier(libelleCle: 'atelier.queue', options: ['poisson', 'chat']),
    ],
    inviterNomCle: 'atelier.nom',
    felicitationNomCle: 'atelier.beauNom',
    questionCle: 'atelier.mange',
    nourritures: ['carotte', 'banane', 'fromage'],
  ),
);

/// La manche suivante : un seul groupe, une seule bouchée — assez pour
/// vérifier que l'atelier repart vraiment de zéro.
const _mancheSuivante = Manche(
  id: 'atelier.bete-2',
  clipsConsigne: ['consigne.atelier'],
  donnees: DonneesAtelier(
    groupes: [
      GroupeAtelier(libelleCle: 'atelier.tete', options: ['lion', 'chat']),
    ],
    inviterNomCle: 'atelier.nom',
    felicitationNomCle: 'atelier.beauNom',
    questionCle: 'atelier.mange',
    nourritures: ['carotte'],
  ),
);

Widget _atelier(MoteurAtelier moteur) =>
    MaterialApp(home: Scaffold(body: moteur));

/// Monte l'atelier (et laisse la vérification du micro se terminer).
Future<void> _monter(
  WidgetTester tester,
  FakeRappels rappels,
  Manche manche, {
  Micro? micro,
}) async {
  await tester.pumpWidget(
    _atelier(
      MoteurAtelier(
        manche: manche,
        lexique: _lexique,
        rappels: rappels,
        micro: micro,
      ),
    ),
  );
  await tester.pump();
}

/// Touche un morceau du groupe ouvert.
Future<void> _prendre(WidgetTester tester, String concept) async {
  await tester.tap(find.byKey(MoteurAtelier.cleOption(concept)));
  await tester.pump();
}

/// Monte la bête en entier : la tête, le corps, la queue.
Future<void> _assembler(WidgetTester tester) async {
  await _prendre(tester, 'lion');
  await _prendre(tester, 'poisson');
  await _prendre(tester, 'chat');
}

/// Les morceaux posés dans l'assemblage (dans l'ordre de l'empilement).
List<ImageConcept> _morceaux(WidgetTester tester) => tester
    .widgetList<ImageConcept>(
      find.descendant(
        of: find.byKey(MoteurAtelier.cleAssemblage),
        matching: find.byType(ImageConcept),
      ),
    )
    .toList();

/// Toutes les cibles tactiles de l'écran font au moins 80 points.
void _ciblesTropPetites(WidgetTester tester) {
  final cibles = find.byType(CibleTactile);
  expect(cibles, findsWidgets);
  for (var i = 0; i < tester.widgetList(cibles).length; i++) {
    final taille = tester.getSize(cibles.at(i));
    expect(
      taille.width >= 80 && taille.height >= 80,
      isTrue,
      reason: 'la cible $i fait ${taille.width} × ${taille.height}',
    );
  }
}

void main() {
  testWidgets('la flèche reprend le dernier morceau et rouvre son groupe', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await _monter(tester, rappels, _mancheAtelier);
    await _prendre(tester, 'lion');
    await _prendre(tester, 'poisson');
    await tester.tap(find.byKey(const ValueKey('atelier.annuler')));
    await tester.pump();
    expect(_morceaux(tester).map((i) => i.concept), ['lion']);
    expect(find.byKey(MoteurAtelier.cleOption('souris')), findsOneWidget);
    expect(rappels.clips.last, 'atelier.corps');
    expect(rappels.reussis, 0);
    await _prendre(tester, 'souris');
    await _prendre(tester, 'chat');
    await tester.tap(find.byKey(MoteurAtelier.cleJaiUnNom));
    await tester.pump();
    await tester.tap(find.byKey(MoteurAtelier.cleNourriture('carotte')));
    await tester.pump();
    expect(rappels.reussis, 1);
  });

  for (final fermer in [true, false]) {
    testWidgets(
      'micro éphémère : ${fermer ? "fermeture en cours" : "échec de lecture"}',
      (tester) async {
        final micro = MicroControle(panneLecture: !fermer);
        final rappels = FakeRappels();
        await _monter(tester, rappels, _mancheAtelier, micro: micro);
        await _assembler(tester);
        await tester.tap(find.byKey(MoteurAtelier.cleEcouteToi));
        await tester.pump();
        expect(micro.fichiers, hasLength(1));
        if (fermer) await tester.pumpWidget(const SizedBox());
        micro.attente.complete();
        await tester.pump();
        await tester.pump();
        expect(micro.fichiers, isEmpty);
        if (fermer) expect(micro.rejoues, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('phase 1 : chaque groupe s\'ouvre en disant son libellé, dans '
      'l\'ordre et au fur et à mesure', (tester) async {
    final rappels = FakeRappels();
    await _monter(tester, rappels, _mancheAtelier);

    // Le premier groupe se présente tout de suite — le deuxième attend son
    // tour : l'enfant n'a rien choisi encore.
    expect(rappels.clips, ['atelier.tete']);
    expect(find.byKey(MoteurAtelier.cleOption('lion')), findsOneWidget);
    _ciblesTropPetites(tester);

    // Premier choix : le groupe du corps s'ouvre et se nomme.
    await _prendre(tester, 'lion');
    expect(rappels.clips, ['atelier.tete', 'atelier.corps']);
    expect(find.byKey(MoteurAtelier.cleOption('poisson')), findsOneWidget);

    // Deuxième choix : la queue.
    await _prendre(tester, 'poisson');
    expect(rappels.clips, ['atelier.tete', 'atelier.corps', 'atelier.queue']);

    // Troisième choix : il n'y a plus rien à assembler, on invite à nommer.
    await _prendre(tester, 'chat');
    expect(rappels.clips, [
      'atelier.tete',
      'atelier.corps',
      'atelier.queue',
      'atelier.nom',
    ]);
    expect(rappels.rates, 0);
    expect(rappels.reussis, 0); // la manche n'est pas finie
    expect(tester.takeException(), isNull);
  });

  testWidgets('trois choix : l\'assemblage montre les trois morceaux empilés '
      'de haut en bas', (tester) async {
    final rappels = FakeRappels();
    await _monter(tester, rappels, _mancheAtelier);

    // Avant tout choix : rien n'est posé, l'atelier attend.
    expect(_morceaux(tester), isEmpty);
    expect(find.byKey(MoteurAtelier.cleElement(0)), findsNothing);

    await _assembler(tester);

    // Trois morceaux, dans l'ordre : la tête, le corps, la queue.
    expect(_morceaux(tester).map((morceau) => morceau.concept).toList(), [
      'lion',
      'poisson',
      'chat',
    ]);
    for (var i = 0; i < 3; i++) {
      expect(
        find.byKey(MoteurAtelier.cleElement(i)),
        findsOneWidget,
        reason: 'le morceau $i est posé',
      );
    }

    // Les tailles de la bête bricolée : la tête, puis le gros corps, puis la
    // petite queue.
    expect(tester.getSize(find.byKey(MoteurAtelier.cleElement(0))).width, 70);
    expect(tester.getSize(find.byKey(MoteurAtelier.cleElement(1))).width, 110);
    expect(tester.getSize(find.byKey(MoteurAtelier.cleElement(2))).width, 60);

    // L'empilement va bien du haut vers le bas, avec le léger chevauchement.
    final tete = tester.getTopLeft(find.byKey(MoteurAtelier.cleElement(0)));
    final corps = tester.getTopLeft(find.byKey(MoteurAtelier.cleElement(1)));
    final queue = tester.getTopLeft(find.byKey(MoteurAtelier.cleElement(2)));
    expect(tete.dy, lessThan(corps.dy));
    expect(corps.dy, lessThan(queue.dy));
    expect(corps.dy, lessThan(tete.dy + 70)); // les morceaux se chevauchent
    expect(tester.takeException(), isNull);
  });

  testWidgets('phase 2 sans micro : « J\'ai un nom ! » dit la félicitation '
      'puis ouvre la question', (tester) async {
    final rappels = FakeRappels();
    await _monter(tester, rappels, _mancheAtelier);
    await _assembler(tester);

    // Sans micro, c'est le bouton de secours — jamais une impasse.
    expect(find.byKey(MoteurAtelier.cleJaiUnNom), findsOneWidget);
    expect(find.byKey(MoteurAtelier.cleEcouteToi), findsNothing);
    _ciblesTropPetites(tester);

    await tester.tap(find.byKey(MoteurAtelier.cleJaiUnNom));
    await tester.pump();
    await tester.pump();

    // La félicitation, puis la question — dans cet ordre.
    expect(rappels.clips, [
      'atelier.tete',
      'atelier.corps',
      'atelier.queue',
      'atelier.nom',
      'atelier.beauNom',
      'atelier.mange',
    ]);
    expect(find.byKey(MoteurAtelier.cleJaiUnNom), findsNothing);
    expect(find.byKey(MoteurAtelier.cleNourriture('carotte')), findsOneWidget);
    expect(find.byKey(MoteurAtelier.cleNourriture('fromage')), findsOneWidget);
    _ciblesTropPetites(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un micro refusé ne bloque jamais : « J\'ai un nom ! » prend la '
      'relève', (tester) async {
    final rappels = FakeRappels();
    final micro = MicroFactice(); // pas d'accord : le jeu n'insiste pas
    await _monter(tester, rappels, _mancheAtelier, micro: micro);
    await _assembler(tester);

    expect(find.byKey(MoteurAtelier.cleJaiUnNom), findsOneWidget);
    expect(find.byKey(MoteurAtelier.cleEcouteToi), findsNothing);
    // Le jeu ne demande JAMAIS la permission : c'est l'espace parent, ça.
    expect(micro.demandes, 0);

    await tester.tap(find.byKey(MoteurAtelier.cleJaiUnNom));
    await tester.pump();
    await tester.pump();
    expect(rappels.clips.last, 'atelier.mange');
  });

  testWidgets('phase 3 : n\'importe quelle nourriture est acceptée, une '
      'seule fois, et rien n\'est jamais raté', (tester) async {
    final rappels = FakeRappels();
    await _monter(tester, rappels, _mancheAtelier);
    await _assembler(tester);
    await tester.tap(find.byKey(MoteurAtelier.cleJaiUnNom));
    await tester.pump();
    await tester.pump();

    // La carte de la banane, telle que l'enfant la voit dans la barre.
    final avant = tester.getRect(
      find.descendant(
        of: find.byKey(MoteurAtelier.cleNourriture('banane')),
        matching: find.byType(ImageConcept),
      ),
    );
    final clipsAvant = [...rappels.clips];

    // La banane : ce n'est pas plus la bonne réponse qu'une autre — ici,
    // tout ce que la bête mange est la bonne réponse.
    await tester.tap(find.byKey(MoteurAtelier.cleNourriture('banane')));
    await tester.pump();

    expect(rappels.reussis, 1);
    expect(rappels.rates, 0); // l'atelier ne rate JAMAIS

    // La bouchée monte vers la bouche : elle rétrécit et s'élève. La mesure
    // est prise DANS l'envol (sous ses transformations), comme ce qui est
    // vraiment peint.
    final envol = find.byKey(MoteurAtelier.cleEnvol);
    expect(envol, findsOneWidget);
    await tester.pumpAndSettle();
    final pendant = tester.getRect(
      find.descendant(of: envol, matching: find.byType(ImageConcept)),
    );
    expect(pendant.width, lessThan(avant.width / 2));
    expect(pendant.top, lessThan(avant.top - 80));

    // Rien de plus n'est dit, et une deuxième bouchée ne rejoue rien.
    expect(rappels.clips, clipsAvant);
    await tester.tap(find.byKey(MoteurAtelier.cleNourriture('carotte')));
    await tester.pump();
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avec un micro accordé : « Écoute-toi » enregistre, rejoue, '
      'efface — et la suite s\'enchaîne', (tester) async {
    final rappels = FakeRappels();
    final micro = MicroFactice(accorde: true);
    await _monter(tester, rappels, _mancheAtelier, micro: micro);
    await _assembler(tester);

    // Le micro est accordé : c'est « Écoute-toi » qui s'affiche.
    expect(find.byKey(MoteurAtelier.cleEcouteToi), findsOneWidget);
    expect(find.byKey(MoteurAtelier.cleJaiUnNom), findsNothing);
    _ciblesTropPetites(tester);

    await tester.tap(find.byKey(MoteurAtelier.cleEcouteToi));
    await tester.pump();
    await tester.pump();

    // L'enfant a été enregistré (3 secondes au plus), réécouté, et le
    // fichier est parti aussitôt : rien ne reste derrière lui.
    expect(micro.rejoues, hasLength(1));
    expect(micro.rejoues.single, startsWith('/factice/'));
    expect(micro.fichiers, isEmpty);
    // Le jeu n'a pas sollicité l'OS : l'accord était déjà là.
    expect(micro.demandes, 0);

    // Et la suite s'enchaîne comme avec le bouton de secours.
    expect(rappels.clips.last, 'atelier.mange');
    expect(find.byKey(MoteurAtelier.cleNourriture('carotte')), findsOneWidget);
    await tester.tap(find.byKey(MoteurAtelier.cleNourriture('fromage')));
    await tester.pump();
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une nouvelle manche repart d\'une bête vierge', (tester) async {
    final rappels = FakeRappels();
    await _monter(tester, rappels, _mancheAtelier);
    await _assembler(tester);
    expect(_morceaux(tester), hasLength(3));

    // L'hôte réutilise le moteur pour la manche suivante : la bête repart
    // de zéro, et le premier groupe se présente de nouveau.
    await _monter(tester, rappels, _mancheSuivante);
    expect(_morceaux(tester), isEmpty);
    expect(find.byKey(MoteurAtelier.cleElement(0)), findsNothing);
    expect(rappels.clips, [
      'atelier.tete',
      'atelier.corps',
      'atelier.queue',
      'atelier.nom',
      'atelier.tete',
    ]);

    await _prendre(tester, 'chat');
    expect(rappels.clips.last, 'atelier.nom');
    expect(tester.takeException(), isNull);
  });

  testWidgets('des données manquantes ou mal typées : un écran calme, '
      'jamais une exception', (tester) async {
    final rappels = FakeRappels();

    // Une manche qui porte des données d'un autre moteur.
    await _monter(
      tester,
      rappels,
      const Manche(
        id: 'atelier.casse',
        clipsConsigne: ['consigne.atelier'],
        donnees: DonneesRythme(mode: ModeRythme.pulsation),
      ),
    );
    expect(find.byKey(MoteurAtelier.cleAssemblage), findsNothing);
    expect(rappels.clips, isEmpty);
    expect(tester.takeException(), isNull);

    // Une manche sans aucun groupe : rien à assembler, on va droit au nom.
    await _monter(
      tester,
      rappels,
      const Manche(
        id: 'atelier.vide',
        clipsConsigne: ['consigne.atelier'],
        donnees: DonneesAtelier(
          groupes: [],
          inviterNomCle: 'atelier.nom',
          felicitationNomCle: 'atelier.beauNom',
          questionCle: 'atelier.mange',
          nourritures: ['carotte'],
        ),
      ),
    );
    expect(rappels.clips, ['atelier.nom']);
    expect(find.byKey(MoteurAtelier.cleJaiUnNom), findsOneWidget);

    await tester.tap(find.byKey(MoteurAtelier.cleJaiUnNom));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(MoteurAtelier.cleNourriture('carotte')));
    await tester.pump();
    expect(rappels.reussis, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sur un écran de téléphone, la bête et les cartes tiennent', (
    tester,
  ) async {
    // iPhone 15 Pro : 390 × 844 points.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final rappels = FakeRappels();
    await _monter(tester, rappels, _mancheAtelier);

    // Trois options de front : chacune reste plus grande qu'un doigt.
    for (final concept in ['lion', 'chat', 'canard']) {
      final taille = tester.getSize(
        find.byKey(MoteurAtelier.cleOption(concept)),
      );
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }
    _ciblesTropPetites(tester);

    // La bête entière tient dans le haut de l'écran.
    await _assembler(tester);
    expect(_morceaux(tester), hasLength(3));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(MoteurAtelier.cleJaiUnNom));
    await tester.pump();
    await tester.pump();
    _ciblesTropPetites(tester);

    // Et la bouchée part de la barre jusqu'à la bouche, sans rien casser.
    await tester.tap(find.byKey(MoteurAtelier.cleNourriture('fromage')));
    await tester.pumpAndSettle();
    expect(rappels.reussis, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retirer le micro pendant une manche garde le nom jouable sans micro',
    (tester) async {
      final rappels = FakeRappels();
      await _monter(
        tester,
        rappels,
        _mancheAtelier,
        micro: MicroFactice(accorde: true),
      );
      await _assembler(tester);
      expect(find.byKey(MoteurAtelier.cleEcouteToi), findsOneWidget);
      await _monter(tester, rappels, _mancheAtelier);
      expect(find.byKey(MoteurAtelier.cleEcouteToi), findsNothing);
      expect(find.byKey(MoteurAtelier.cleJaiUnNom), findsOneWidget);
      await tester.tap(find.byKey(MoteurAtelier.cleJaiUnNom));
      await tester.pump();
      expect(
        find.byKey(MoteurAtelier.cleNourriture('carotte')),
        findsOneWidget,
      );
    },
  );
}
