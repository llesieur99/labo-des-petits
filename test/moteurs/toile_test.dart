import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m7_creation/toile.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';

/// Rappels enregistreurs : on garde la trace de tout ce que la toile dit à
/// son hôte (couleur de mélange nommée, item réussi, essai raté).
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

const lexique = <String, EntreeLexique>{
  'rouge': EntreeLexique(texte: 'rouge'),
  'jaune': EntreeLexique(texte: 'jaune'),
  'bleu': EntreeLexique(texte: 'bleu'),
  'orange': EntreeLexique(texte: 'orange'),
  'violet': EntreeLexique(texte: 'violet'),
};

/// L'atelier libre : deux couleurs, aucune cible (on peint pour peindre).
const _mancheAtelier = Manche(
  id: 'toile.atelier',
  clipsConsigne: ['consigne.toile'],
  donnees: DonneesToile(
    palette: ['rouge', 'bleu'],
    cellulesObjectif: 250, // inatteignable : rien ne vient interrompre
  ),
);

/// Le mélange : rouge puis jaune donnent l'orange. La cible de cellules est
/// inatteignable — ce test-là regarde la couleur, pas la réussite.
const _mancheMelange = Manche(
  id: 'toile.melange',
  clipsConsigne: ['consigne.toile'],
  donnees: DonneesToile(
    palette: ['rouge', 'jaune', 'bleu'],
    melanges: {'jaune+rouge': 'orange'},
    couleurObjectif: 'orange',
    cellulesObjectif: 400,
  ),
);

/// La peinture à objectif : assez de cellules bleues, et c'est réussi.
const _mancheObjectif = Manche(
  id: 'toile.bleu',
  clipsConsigne: ['consigne.toile'],
  donnees: DonneesToile(
    palette: ['bleu'],
    couleurObjectif: 'bleu',
    cellulesObjectif: 12,
  ),
);

/// Les ailes du papillon : en miroir, un doigt à gauche compte double (un
/// tap = 5 cellules à gauche + leurs 5 jumelles).
const _mancheMiroir = Manche(
  id: 'toile.miroir',
  clipsConsigne: ['consigne.toile'],
  donnees: DonneesToile(
    palette: ['violet'],
    couleurObjectif: 'violet',
    cellulesObjectif: 8,
    miroir: true,
  ),
);

/// Les taches du papillon : trois ronds sur l'aile GAUCHE (le miroir
/// remplira l'aile droite).
const _tachesPapillon = <PointToile>[
  PointToile(0.3, 0.5, 0.09),
  PointToile(0.22, 0.25, 0.07),
  PointToile(0.22, 0.75, 0.07),
];

/// Le papillon à taches : les taches sont à gauche, le miroir remplit
/// l'aile droite. La cible de couleur est minuscule exprès : si le moteur
/// comptait les cellules au lieu des taches, la première touche suffirait.
const _manchePapillon = Manche(
  id: 'toile.papillon',
  clipsConsigne: ['consigne.toile'],
  donnees: DonneesToile(
    palette: ['orange', 'violet'],
    couleurObjectif: 'orange',
    cellulesObjectif: 4,
    miroir: true,
    taches: _tachesPapillon,
  ),
);

Widget _toile(MoteurToile toile) => MaterialApp(home: Scaffold(body: toile));

/// La grille 16 × 16 telle que le peintre la voit : on lit l'état RÉEL du
/// moteur, pas une copie.
List<String?> _grille(WidgetTester tester) {
  final peintre = tester
      .widget<CustomPaint>(find.byKey(MoteurToile.cleToile))
      .painter;
  expect(peintre, isA<PeintureToile>());
  return (peintre! as PeintureToile).grille;
}

/// Un point de la toile, en coordonnées cellules continues (0..16).
Offset _point(WidgetTester tester, double x, double y) {
  final zone = tester.getRect(find.byKey(MoteurToile.cleToile));
  return zone.topLeft +
      Offset(
        x * zone.width / MoteurToile.cotes,
        y * zone.height / MoteurToile.cotes,
      );
}

/// Le centre d'une cellule (colonne, ligne), en points.
Offset _cellule(WidgetTester tester, int colonne, int ligne) =>
    _point(tester, colonne + 0.5, ligne + 0.5);

/// Le concept de couleur d'une cellule, ou null si elle est vierge.
String? _couleur(WidgetTester tester, int colonne, int ligne) =>
    _grille(tester)[ligne * MoteurToile.cotes + colonne];

int _cellulesPeintes(WidgetTester tester) =>
    _grille(tester).where((cellule) => cellule != null).length;

void main() {
  testWidgets('annuler retire le dernier trait en gardant les précédents', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _toile(
        MoteurToile(manche: _mancheAtelier, lexique: lexique, rappels: rappels),
      ),
    );
    await tester.pump();
    await tester.tapAt(_cellule(tester, 3, 4));
    await tester.pump();
    final premiere = List.of(_grille(tester));
    await tester.tapAt(_cellule(tester, 9, 10));
    await tester.pump();
    expect(_grille(tester), isNot(premiere));
    await tester.tap(find.byKey(const ValueKey('toile.annuler')));
    await tester.pump();
    expect(_grille(tester), premiere);
    expect(rappels.reussis, 0);
    await tester.tap(find.byKey(const ValueKey('toile.annuler')));
    await tester.pump();
    expect(_cellulesPeintes(tester), 0);
  });

  testWidgets('peindre au doigt : un tap puis un glissement rapide, sans '
      'trou et sans jamais rater', (tester) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _toile(
        MoteurToile(manche: _mancheAtelier, lexique: lexique, rappels: rappels),
      ),
    );
    await tester.pump();

    // La toile est vierge au départ.
    expect(_cellulesPeintes(tester), 0);

    // Un tap : la cellule touchée et son voisinage immédiat prennent la
    // couleur active (la première de la palette : le rouge).
    await tester.tapAt(_cellule(tester, 8, 8));
    await tester.pump();
    expect(_couleur(tester, 8, 8), 'rouge');
    expect(_couleur(tester, 7, 8), 'rouge');
    expect(_couleur(tester, 8, 7), 'rouge');
    // … et rien d'autre : la toile répond là où on la touche.
    expect(_couleur(tester, 0, 0), isNull);
    expect(tester.takeException(), isNull);

    // Un glissement rapide : les positions intermédiaires sont
    // interpolées, la ligne ne laisse aucun trou.
    final depart = _cellule(tester, 2, 12);
    final arrivee = _cellule(tester, 12, 12);
    await tester.dragFrom(depart, arrivee - depart);
    await tester.pump();
    for (var colonne = 2; colonne <= 12; colonne++) {
      expect(
        _couleur(tester, colonne, 12),
        'rouge',
        reason: 'la colonne $colonne du trait ne doit pas être sautée',
      );
    }
    expect(tester.takeException(), isNull);
    // Peindre n'est jamais un essai raté, et rien n'est annoncé à l'hôte :
    // la manche n'est pas finie.
    expect(rappels.rates, 0);
    expect(rappels.reussis, 0);
    expect(rappels.clips, isEmpty);
  });

  testWidgets('mélange : rouge puis jaune sur la même cellule donnent '
      'l\'orange, nommé une seule fois par manche', (tester) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _toile(
        MoteurToile(manche: _mancheMelange, lexique: lexique, rappels: rappels),
      ),
    );
    await tester.pump();

    // La pastille rouge est active au départ : on peint deux fois dans la
    // même zone, en haut à gauche de la toile.
    await tester.tapAt(_cellule(tester, 5, 5));
    await tester.pump();
    expect(_couleur(tester, 5, 5), 'rouge');
    expect(rappels.clips, isEmpty); // peindre du rouge ne se dit pas

    // On prend le jaune, et on repasse sur la MÊME cellule : mélange.
    await tester.tap(find.byKey(MoteurToile.clePastille('jaune')));
    await tester.pump();
    await tester.tapAt(_cellule(tester, 5, 5));
    await tester.pump();
    expect(_couleur(tester, 5, 5), 'orange');
    expect(rappels.clips.where((clip) => clip == 'lex.orange'), ['lex.orange']);

    // Repasser du jaune sur l'orange : pas de règle jaune+orange, on peint
    // par-dessus — et on ne re-nomme rien.
    await tester.tapAt(_cellule(tester, 5, 5));
    await tester.pump();
    expect(_couleur(tester, 5, 5), 'jaune');
    expect(rappels.clips.where((clip) => clip == 'lex.orange'), ['lex.orange']);

    // On remélange : l'orange revient, mais il ne se redit pas — une seule
    // fois par manche, c'est ce qui fait la surprise.
    await tester.tap(find.byKey(MoteurToile.clePastille('rouge')));
    await tester.pump();
    await tester.tapAt(_cellule(tester, 5, 5));
    await tester.pump();
    expect(_couleur(tester, 5, 5), 'orange');
    expect(rappels.clips.where((clip) => clip == 'lex.orange'), ['lex.orange']);
  });

  testWidgets('l\'objectif de couleur atteint : itemReussi une seule fois', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _toile(
        MoteurToile(
          manche: _mancheObjectif,
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();

    // Trois touches de bleu : la cible (12 cellules) n'est atteinte qu'à la
    // troisième — et la réussite n'est annoncée que quand elle l'est.
    for (final colonne in [8, 10, 12]) {
      await tester.tapAt(_cellule(tester, colonne, 8));
      await tester.pump();
      final peintes = _grille(
        tester,
      ).where((cellule) => cellule == 'bleu').length;
      expect(
        rappels.reussis,
        peintes >= 12 ? 1 : 0,
        reason: '$peintes cellules bleues peintes',
      );
    }
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0); // rien n'est jamais raté

    // On continue de peindre : la réussite n'est pas annoncée deux fois.
    final depart = _cellule(tester, 2, 14);
    final arrivee = _cellule(tester, 12, 14);
    await tester.dragFrom(depart, arrivee - depart);
    await tester.pump();
    expect(rappels.reussis, 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(rappels.reussis, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('miroir : peindre à gauche copie la cellule à droite, et la '
      'moitié droite ne se peint pas', (tester) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _toile(
        MoteurToile(manche: _mancheMiroir, lexique: lexique, rappels: rappels),
      ),
    );
    await tester.pump();

    await tester.tapAt(_cellule(tester, 2, 5));
    await tester.pump();

    // Chaque cellule peinte a sa jumelle de l'autre côté de l'axe (15 - x).
    expect(_couleur(tester, 2, 5), 'violet');
    expect(_couleur(tester, 13, 5), 'violet');
    expect(_couleur(tester, 3, 5), 'violet');
    expect(_couleur(tester, 12, 5), 'violet');
    expect(_couleur(tester, 2, 4), 'violet');
    expect(_couleur(tester, 13, 4), 'violet');
    // 5 cellules à gauche + 5 en miroir : la cible de 8 est déjà atteinte,
    // ce qui prouve que les jumelles comptent vraiment.
    expect(_cellulesPeintes(tester), 10);
    expect(rappels.reussis, 1);

    // Un doigt sur la moitié DROITE ne fait rien du tout — même le miroir
    // de cette cellule reste vierge.
    final avant = _cellulesPeintes(tester);
    await tester.tapAt(_cellule(tester, 12, 9));
    await tester.pump();
    expect(_couleur(tester, 12, 9), isNull);
    expect(_couleur(tester, 3, 9), isNull);
    expect(_cellulesPeintes(tester), avant);

    // Un glissement parti de la droite vers la gauche, lui, peint dès qu'il
    // entre dans la moitié gauche de la toile.
    await tester.dragFrom(
      _cellule(tester, 11, 3),
      _cellule(tester, 4, 3) - _cellule(tester, 11, 3),
    );
    await tester.pump();
    expect(_couleur(tester, 4, 3), 'violet');
    expect(_couleur(tester, 11, 3), 'violet'); // la jumelle de (4, 3)
    expect(tester.takeException(), isNull);
  });

  testWidgets('les taches du papillon remplies : la manche est réussie', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _toile(
        MoteurToile(
          manche: _manchePapillon,
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();

    // Une tache à la fois : on la balaie de gauche à droite, en large. Tant
    // qu'il reste une tache vide, la manche n'est pas réussie — même si la
    // cible de cellules, elle, est déjà dépassée (4 cellules orange).
    for (var i = 0; i < _tachesPapillon.length; i++) {
      final tache = _tachesPapillon[i];
      final demi = tache.rayon * 16 * 0.6; // du rayon, en cellules
      final debut = _point(tester, tache.x * 16 - demi, tache.y * 16);
      final fin = _point(tester, tache.x * 16 + demi, tache.y * 16);
      await tester.dragFrom(debut, fin - debut);
      await tester.pump();
      final derniere = i == _tachesPapillon.length - 1;
      expect(
        rappels.reussis,
        derniere ? 1 : 0,
        reason: 'après la tache ${i + 1}',
      );
    }

    // Toutes les taches sont remplies : c'est réussi, une seule fois.
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
    final depart = _cellule(tester, 1, 15);
    final arrivee = _cellule(tester, 6, 15);
    await tester.dragFrom(depart, arrivee - depart);
    await tester.pump();
    expect(rappels.reussis, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une manche suivante repart d\'une toile vierge', (tester) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _toile(
        MoteurToile(
          manche: _mancheObjectif,
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(_cellule(tester, 8, 8));
    await tester.pump();
    expect(_cellulesPeintes(tester), greaterThan(0));

    // L'hôte réutilise le moteur pour la manche suivante : la toile est
    // vierge, et la pastille active redevient la première de la palette.
    await tester.pumpWidget(
      _toile(
        MoteurToile(manche: _mancheMiroir, lexique: lexique, rappels: rappels),
      ),
    );
    await tester.pump();
    expect(_cellulesPeintes(tester), 0);
    expect(_couleur(tester, 0, 0), isNull);

    await tester.tapAt(_cellule(tester, 1, 1));
    await tester.pump();
    expect(_couleur(tester, 1, 1), 'violet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sur un écran de téléphone, six couleurs et le miroir tiennent', (
    tester,
  ) async {
    // iPhone 15 Pro : 390 × 844 points.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final rappels = FakeRappels();
    await tester.pumpWidget(
      _toile(
        MoteurToile(
          manche: const Manche(
            id: 'toile.telephone',
            clipsConsigne: ['consigne.toile'],
            donnees: DonneesToile(
              palette: ['rouge', 'jaune', 'bleu', 'orange', 'vert', 'violet'],
              melanges: {'jaune+rouge': 'orange'},
              miroir: true,
              taches: _tachesPapillon,
            ),
          ),
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();

    // La toile prend toute la largeur, et le bandeau ne déborde pas.
    final zone = tester.getRect(find.byKey(MoteurToile.cleToile));
    expect(zone.width, 390);
    expect(zone.height, lessThan(844));
    expect(tester.takeException(), isNull);

    // Les pastilles visibles restent des doigts d'enfant (au moins 80 pt) —
    // le bandeau glisse au lieu de les rétrécir.
    for (final concept in ['rouge', 'jaune']) {
      final taille = tester.getSize(
        find.byKey(MoteurToile.clePastille(concept)),
      );
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }

    // Le miroir fonctionne aussi sur ce format (cellules hautes et
    // étroites) : la jumelle de droite reçoit la couleur.
    await tester.tapAt(_cellule(tester, 3, 6));
    await tester.pump();
    expect(_couleur(tester, 3, 6), 'rouge');
    expect(_couleur(tester, 12, 6), 'rouge');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'un trait jaune conserve son mélange malgré les retours du doigt',
    (tester) async {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _toile(
          MoteurToile(
            manche: _mancheMelange,
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(_cellule(tester, 5, 5));
      await tester.tap(find.byKey(MoteurToile.clePastille('jaune')));
      await tester.pump();
      expect(rappels.clips, contains('lex.jaune'));
      final point = _cellule(tester, 5, 5);
      final geste = await tester.startGesture(point);
      await geste.moveTo(point + const Offset(2, 0));
      await geste.moveTo(point);
      await geste.up();
      await tester.pump();
      expect(_couleur(tester, 5, 5), 'orange');
      expect(rappels.clips.where((clip) => clip == 'lex.orange').length, 1);
    },
  );

  testWidgets('un second doigt ne trace pas une diagonale entre deux mains', (
    tester,
  ) async {
    await tester.pumpWidget(
      _toile(
        MoteurToile(
          manche: _mancheAtelier,
          lexique: lexique,
          rappels: FakeRappels(),
        ),
      ),
    );
    await tester.pump();
    final premier = await tester.startGesture(
      _cellule(tester, 2, 2),
      pointer: 1,
    );
    final second = await tester.startGesture(
      _cellule(tester, 12, 12),
      pointer: 2,
    );
    await second.moveTo(_cellule(tester, 11, 11));
    await second.up();
    await premier.moveTo(_cellule(tester, 3, 2));
    await premier.up();
    await tester.pump();
    expect(_couleur(tester, 3, 2), 'rouge');
    expect(_couleur(tester, 8, 8), isNull);
    expect(_couleur(tester, 12, 12), isNull);
  });
}
