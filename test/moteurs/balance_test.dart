import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m9_balance/balance.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/theme/palette.dart';

/// Rappels enregistreurs : on garde la trace de tout ce que la balance dit
/// à son hôte. Le journal garde l'ORDRE des événements (un clip, puis la
/// réussite) — c'est ce qui permet de vérifier que l'app dit « c'est égal »
/// avant de féliciter.
class FakeRappels implements RappelsMoteur {
  final List<String> journal = <String>[];
  final List<String> dires = <String>[];
  int reussis = 0;
  int rates = 0;

  @override
  void itemReussi() {
    reussis++;
    journal.add('reussi');
  }

  @override
  void essaiRate() {
    rates++;
    journal.add('rate');
  }

  @override
  Future<void> dire(String clipId) async {
    dires.add(clipId);
    journal.add(clipId);
  }

  @override
  Future<void> jouerSon(String asset) async {}
}

const lexique = <String, EntreeLexique>{
  'pomme': EntreeLexique(texte: 'pomme'),
  'poisson': EntreeLexique(texte: 'poisson'),
  'fraise': EntreeLexique(texte: 'fraise'),
};

/// La manche du marché : trois pommes et trois poissons, deux fruits par
/// plateau au minimum pour que l'égalité compte.
const _manche = Manche(
  id: 'balance.marche',
  clipsConsigne: ['consigne.balance'],
  donnees: DonneesBalance(
    reserve: ['pomme', 'pomme', 'pomme', 'poisson', 'poisson', 'poisson'],
    minimumParPlateau: 2,
    pencheCle: 'balance.penche',
    egalCle: 'balance.egal',
  ),
);

/// La même manche, l'id suivant : l'hôte réutilise le moteur.
const _mancheSuivante = Manche(
  id: 'balance.marche.suivante',
  clipsConsigne: ['consigne.balance'],
  donnees: DonneesBalance(
    reserve: ['pomme', 'pomme', 'pomme', 'poisson', 'poisson', 'poisson'],
    minimumParPlateau: 2,
    pencheCle: 'balance.penche',
    egalCle: 'balance.egal',
  ),
);

/// Trois fruits par plateau avant que l'égalité compte.
const _mancheTrois = Manche(
  id: 'balance.trois',
  clipsConsigne: ['consigne.balance'],
  donnees: DonneesBalance(
    reserve: ['fraise', 'fraise', 'fraise', 'poisson', 'poisson', 'poisson'],
    minimumParPlateau: 3,
    pencheCle: 'balance.penche',
    egalCle: 'balance.egal',
  ),
);

Finder fruit(int id, String concept) =>
    find.byKey(MoteurBalance.cleFruit(id, concept));

Finder plateau(String cote) => find.byKey(MoteurBalance.clePlateau(cote));

Finder pose(String cote, int id) =>
    find.byKey(MoteurBalance.cleFruitPose(cote, id));

Finder point(String cote, int index) =>
    find.byKey(MoteurBalance.clePoint(cote, index));

/// L'inclinaison demandée au fléau (l'objet qui penche), en tours.
double toursFleau(WidgetTester tester) =>
    tester.widget<AnimatedRotation>(find.byKey(MoteurBalance.cleFleau)).turns;

Future<void> pomper(
  WidgetTester tester,
  FakeRappels rappels, {
  Manche? avec,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MoteurBalance(
          manche: avec ?? _manche,
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Touche le fruit, puis le plateau (touche-toucher).
Future<void> poser(
  WidgetTester tester,
  int id,
  String concept,
  String cote,
) async {
  await tester.tap(fruit(id, concept));
  await tester.pump();
  await tester.tap(plateau(cote));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('poser deux fruits à gauche puis deux à droite : c\'est égal, '
      'et la manche est réussie une seule fois', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    // Un fruit à gauche : c'est la gauche qui est plus lourde.
    await poser(tester, 0, 'pomme', 'gauche');
    expect(rappels.dires, ['lex.pomme', 'balance.penche']);

    // Deux à gauche, puis un à droite : toujours inégal.
    await poser(tester, 1, 'pomme', 'gauche');
    await poser(tester, 3, 'poisson', 'droite');
    expect(rappels.dires, isNot(contains('balance.egal')));
    expect(rappels.reussis, 0);

    // Deux contre deux : c'est égal, la manche est réussie.
    await poser(tester, 4, 'poisson', 'droite');
    expect(rappels.dires, contains('balance.egal'));
    expect(rappels.reussis, 1);
    // L'app dit « c'est égal » AVANT que l'hôte félicite.
    final egal = rappels.journal.indexOf('balance.egal');
    expect(egal, isNot(-1));
    expect(rappels.journal.indexOf('reussi'), greaterThan(egal));
    expect(rappels.rates, 0);

    // On continue de jouer après la réussite : cinq puis six fruits, la
    // manche n'est jamais réussie deux fois.
    await poser(tester, 2, 'pomme', 'gauche');
    await poser(tester, 5, 'poisson', 'droite');
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trois fruits à gauche, un à droite : ça penche, et la manche '
      'n\'est jamais réussie', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    for (final id in [0, 1, 2]) {
      await poser(tester, id, 'pomme', 'gauche');
    }
    await poser(tester, 3, 'poisson', 'droite');

    expect(rappels.dires, contains('balance.penche'));
    expect(rappels.reussis, 0);
    expect(rappels.dires, isNot(contains('balance.egal')));
    // Le déséquilibre est le même du début à la fin : l'app ne le répète
    // pas à chaque dépôt (jamais deux fois de suite le même « ça penche »).
    expect(rappels.dires.where((clip) => clip == 'balance.penche').length, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('reprendre un fruit posé : un doigt dessus le ramène dans la '
      'réserve, et le compteur du plateau baisse', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    await poser(tester, 0, 'pomme', 'gauche');
    await poser(tester, 1, 'pomme', 'gauche');
    expect(point('gauche', 0), findsOneWidget);
    expect(point('gauche', 1), findsOneWidget);
    expect(fruit(1, 'pomme'), findsNothing); // il est sur le plateau

    // Un doigt sur le fruit posé : il retourne dans la réserve. (Le fruit
    // est minuscule DANS le plateau : c'est le plateau qui reçoit le doigt
    // et qui reprend le dernier fruit posé.)
    await tester.tap(pose('gauche', 1), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(point('gauche', 1), findsNothing);
    expect(point('gauche', 0), findsOneWidget);
    expect(pose('gauche', 1), findsNothing);
    expect(fruit(1, 'pomme'), findsOneWidget); // de retour dans la réserve
    expect(rappels.rates, 0);

    // Le compteur du voisin n'a pas bougé.
    expect(point('droite', 0), findsNothing);

    // Et la manche reste jouable : on le repose, on remet l'égalité.
    await poser(tester, 1, 'pomme', 'gauche');
    await poser(tester, 3, 'poisson', 'droite');
    await poser(tester, 4, 'poisson', 'droite');
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('prendre un fruit dit son nom, une seule fois par prise', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    await tester.tap(fruit(0, 'pomme'));
    await tester.pump();
    expect(rappels.dires, ['lex.pomme']);

    // Touché de nouveau, il se repose dans la réserve : rien ne se redit.
    await tester.tap(fruit(0, 'pomme'));
    await tester.pump();
    expect(rappels.dires, ['lex.pomme']);

    // Des doigts sur un plateau, la main vide et le plateau vide : rien.
    await tester.tap(plateau('gauche'));
    await tester.pumpAndSettle();
    expect(rappels.dires, ['lex.pomme']);

    // Une nouvelle prise le nomme de nouveau — c'est permis.
    await tester.tap(fruit(0, 'pomme'));
    await tester.pump();
    expect(rappels.dires, ['lex.pomme', 'lex.pomme']);

    // Un doigt sur un AUTRE fruit change ce qui est en main : le premier
    // reste dans la réserve (rien ne se perd), et le nom est dit.
    await tester.tap(fruit(1, 'pomme'));
    await tester.pump();
    expect(rappels.dires, ['lex.pomme', 'lex.pomme', 'lex.pomme']);

    // On pose celui qui est en main : le premier fruit est toujours là.
    await tester.tap(plateau('gauche'));
    await tester.pumpAndSettle();
    expect(pose('gauche', 1), findsOneWidget);
    expect(fruit(0, 'pomme'), findsOneWidget);
    expect(point('gauche', 0), findsOneWidget);
    expect(rappels.rates, 0);
  });

  testWidgets('rien n\'est jamais raté : essaiRate n\'est appelé dans aucun '
      'scénario', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    // On touche dans tous les sens : des plateaux vides, un fruit pris puis
    // reposé, des dépôts qui penchent, un retrait.
    await tester.tap(plateau('gauche'));
    await tester.pump();
    await tester.tap(plateau('droite'));
    await tester.pump();
    await tester.tap(fruit(0, 'pomme'));
    await tester.pump();
    await tester.tap(fruit(0, 'pomme'));
    await tester.pump();
    await poser(tester, 0, 'pomme', 'gauche');
    await poser(tester, 1, 'pomme', 'gauche');
    await poser(tester, 2, 'pomme', 'droite');
    await tester.tap(plateau('droite'));
    await tester.pumpAndSettle();

    expect(rappels.rates, 0);
    expect(rappels.journal, isNot(contains('rate')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('les fruits de la réserve et les deux plateaux sont des cibles '
      'd\'au moins 80 pt', (tester) async {
    await pomper(tester, FakeRappels());

    // Six fruits dans la réserve, deux plateaux.
    expect(find.byType(CibleTactile), findsNWidgets(8));
    for (final element in find.byType(CibleTactile).evaluate()) {
      final taille = tester.getSize(find.byWidget(element.widget));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }

    // Les plateaux sont sous les extrémités du fléau, côte à côte, et la
    // réserve est en dessous.
    final gauche = tester.getRect(plateau(MoteurBalance.coteGauche));
    final droite = tester.getRect(plateau(MoteurBalance.coteDroite));
    final reserve = tester.getRect(fruit(0, 'pomme'));
    expect(gauche.center.dy, droite.center.dy);
    expect(gauche.right, lessThanOrEqualTo(droite.left));
    expect(reserve.top, greaterThan(gauche.bottom));
  });

  testWidgets('l\'égalité ne compte qu\'avec le minimum de fruits par '
      'plateau', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels, avec: _mancheTrois);

    // Un contre un : la balance est droite, mais ce n'est pas encore assez.
    await poser(tester, 0, 'fraise', 'gauche');
    await poser(tester, 3, 'poisson', 'droite');
    expect(rappels.dires, isNot(contains('balance.egal')));
    expect(rappels.reussis, 0);
    final penches = rappels.dires.where((clip) => clip == 'balance.penche');
    expect(penches.length, 1); // le premier dépôt, à gauche

    // On reprend le poisson du plateau de droite : la gauche redevient plus
    // lourde, mais c'est un RETRAIT — « ça penche » ne se dit que sur un
    // dépôt, jamais quand l'enfant se reprend.
    await tester.tap(plateau(MoteurBalance.coteDroite), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(point('droite', 0), findsNothing);
    expect(
      rappels.dires.where((clip) => clip == 'balance.penche').length,
      1,
      reason: 'un retrait ne dit pas « ça penche »',
    );

    // Deux contre deux : toujours pas assez.
    await poser(tester, 3, 'poisson', 'droite');
    await poser(tester, 1, 'fraise', 'gauche');
    await poser(tester, 4, 'poisson', 'droite');
    expect(rappels.dires, isNot(contains('balance.egal')));
    expect(rappels.reussis, 0);

    // Trois contre trois : c'est égal, et c'est réussi.
    await poser(tester, 2, 'fraise', 'gauche');
    await poser(tester, 5, 'poisson', 'droite');
    expect(rappels.dires, contains('balance.egal'));
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('le fléau penche du côté le plus lourd, et se remet droit à '
      'l\'égalité', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    // Deux plateaux vides : le fléau est horizontal.
    expect(toursFleau(tester), 0);

    // Un fruit à gauche : le bout gauche descend (une rotation positive
    // tourne vers la droite, donc c'est un angle négatif).
    await poser(tester, 0, 'pomme', 'gauche');
    expect(toursFleau(tester), closeTo(-10 / 360, 0.0001));

    // Un de chaque côté : la balance est droite.
    await poser(tester, 3, 'poisson', 'droite');
    expect(toursFleau(tester), 0);

    // Plus lourd à droite : le fléau bascule de l'autre côté.
    await poser(tester, 4, 'poisson', 'droite');
    expect(toursFleau(tester), closeTo(10 / 360, 0.0001));

    // Deux contre deux : droit, et c'est réussi.
    await poser(tester, 1, 'pomme', 'gauche');
    expect(toursFleau(tester), 0);
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une manche suivante : tous les fruits reviennent dans la '
      'réserve', (tester) async {
    final rappels = FakeRappels();
    await pomper(tester, rappels);

    await poser(tester, 0, 'pomme', 'gauche');
    await poser(tester, 3, 'poisson', 'droite');
    expect(fruit(0, 'pomme'), findsNothing);
    expect(pose('gauche', 0), findsOneWidget);

    // L'hôte réutilise le moteur pour la manche suivante : la réserve est
    // pleine, les plateaux sont vides, et la manche peut être gagnée.
    await pomper(tester, rappels, avec: _mancheSuivante);
    expect(fruit(0, 'pomme'), findsOneWidget);
    expect(fruit(3, 'poisson'), findsOneWidget);
    expect(pose('gauche', 0), findsNothing);
    expect(point('droite', 0), findsNothing);
    expect(toursFleau(tester), 0);

    await poser(tester, 0, 'pomme', 'gauche');
    await poser(tester, 1, 'pomme', 'gauche');
    await poser(tester, 3, 'poisson', 'droite');
    await poser(tester, 4, 'poisson', 'droite');
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('des données manquantes ou d\'un autre moteur : un écran crème, '
      'jamais d\'exception', (tester) async {
    final rappels = FakeRappels();

    // Une manche sans données du tout.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurBalance(
            manche: const Manche(
              id: 'balance.vide',
              clipsConsigne: ['consigne.balance'],
            ),
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      ),
    );
    await tester.pump();

    final calme = find.byKey(MoteurBalance.cleEcranCalme);
    expect(calme, findsOneWidget);
    expect(tester.widget<ColoredBox>(calme).color, Palette.creme);
    expect(find.byType(CibleTactile), findsNothing);
    expect(tester.takeException(), isNull);

    // Une manche d'un AUTRE moteur (les données ne sont pas celles de la
    // balance) : même écran calme.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurBalance(
            manche: const Manche(
              id: 'balance.depot',
              clipsConsigne: ['consigne.balance'],
              donnees: DonneesDepot(emplacements: [], objets: [], places: {}),
            ),
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(MoteurBalance.cleEcranCalme), findsOneWidget);
    expect(rappels.journal, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sur un écran de téléphone, six fruits et la balance tiennent', (
    tester,
  ) async {
    // iPhone 15 Pro : 390 × 844 points.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final rappels = FakeRappels();
    await pomper(tester, rappels);

    // Toutes les cibles restent des doigts d'enfant, même serrées.
    for (final element in find.byType(CibleTactile).evaluate()) {
      final taille = tester.getSize(find.byWidget(element.widget));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }

    // Et la manche reste jouable : deux contre deux, c'est réussi.
    await poser(tester, 0, 'pomme', 'gauche');
    await poser(tester, 1, 'pomme', 'gauche');
    await poser(tester, 3, 'poisson', 'droite');
    await poser(tester, 4, 'poisson', 'droite');
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'les places vides rendent le minimum visible et se remplissent une à une',
    (tester) async {
      final rappels = FakeRappels();
      await pomper(tester, rappels);
      expect(
        find.byKey(const ValueKey('balance.place.gauche.0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('balance.place.gauche.1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('balance.place.droite.0')),
        findsOneWidget,
      );
      await poser(tester, 0, 'pomme', 'gauche');
      expect(
        find.byKey(const ValueKey('balance.place.gauche.0')),
        findsNothing,
      );
      expect(point('gauche', 0), findsOneWidget);
      expect(
        find.byKey(const ValueKey('balance.place.gauche.1')),
        findsOneWidget,
      );
      expect(rappels.reussis, 0);
      await tester.tap(plateau('gauche'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('balance.place.gauche.0')),
        findsOneWidget,
      );
    },
  );
}
