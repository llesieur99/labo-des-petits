import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m7_creation/theatre.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/core/widgets/image_concept.dart';

/// Rappels enregistreurs : on garde la trace de tout ce que la scène raconte
/// à son hôte (clip du bravo, item réussi, essai raté).
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

class _RappelsPausables extends FakeRappels implements HorlogeMoteur {
  @override
  bool enPause = false;

  @override
  Future<void> attendre(Duration duree) => Future<void>.delayed(duree);
}

const lexique = <String, EntreeLexique>{
  'loup': EntreeLexique(texte: 'loup'),
  'lapin': EntreeLexique(texte: 'lapin'),
};

/// Manche « théâtre » : le loup et le lapin jouent une petite scène.
const _mancheTheatre = Manche(
  id: 'theatre.loup-lapin',
  clipsConsigne: ['consigne.theatre.joue'],
  donnees: DonneesTheatre(personnages: ['loup', 'lapin']),
);

Widget _scene(MoteurTheatre theatre) =>
    MaterialApp(home: Scaffold(body: theatre));

/// Le personnage [index] sur la scène (sa position se lit au centre).
Finder _perso(int index) => find.byKey(MoteurTheatre.clePersonnage(index));

/// Avance la scène de [pas] pas d'enregistrement (100 ms chacun) : c'est le
/// rythme de l'échantillonnage, on pompe donc pas par pas.
Future<void> _pomper(WidgetTester tester, int pas) async {
  for (var i = 0; i < pas; i++) {
    await tester.pump(MoteurTheatre.pas);
  }
}

void main() {
  testWidgets(
    'recommencer efface le scénario et permet d’en enregistrer un autre',
    (tester) async {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurTheatre(
            manche: _mancheTheatre,
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      );
      await tester.pump();
      final depart = tester.getCenter(_perso(0));
      await tester.timedDragFrom(
        depart,
        const Offset(80, -60),
        const Duration(milliseconds: 300),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('theatre.recommencer')));
      await tester.pump();
      expect(tester.getCenter(_perso(0)), depart);
      expect(find.byKey(MoteurTheatre.cleRejouer), findsNothing);
      expect(rappels.reussis, 0);
      await tester.timedDragFrom(
        depart,
        const Offset(40, -30),
        const Duration(milliseconds: 300),
      );
      await _pomper(tester, 25);
      await tester.tap(find.byKey(MoteurTheatre.cleRejouer));
      await _pomper(tester, 40);
      expect(rappels.reussis, 1);
    },
  );

  testWidgets('au départ : deux personnages sur la scène, pas de bouton '
      'Rejouer', (tester) async {
    await tester.pumpWidget(
      _scene(
        MoteurTheatre(
          manche: _mancheTheatre,
          lexique: lexique,
          rappels: FakeRappels(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(MoteurTheatre.clePersonnage(0)), findsOneWidget);
    expect(find.byKey(MoteurTheatre.clePersonnage(1)), findsOneWidget);
    expect(find.byType(ImageConcept), findsNWidgets(2));
    // Rien à rejouer tant que rien n'a été joué.
    expect(find.byKey(MoteurTheatre.cleRejouer), findsNothing);

    // Les deux personnages attendent en bas (l'écran de test fait
    // 800 × 600) : l'un à gauche, l'autre à droite.
    final gauche = tester.getCenter(_perso(0));
    final droite = tester.getCenter(_perso(1));
    expect(gauche.dx, lessThan(droite.dx));
    expect(gauche.dx, lessThan(250));
    expect(droite.dx, greaterThan(550));
    expect(gauche.dy, greaterThan(300));
    expect(droite.dy, greaterThan(300));
  });

  testWidgets('un doigt déplace un personnage — et lui seul', (tester) async {
    await tester.pumpWidget(
      _scene(
        MoteurTheatre(
          manche: _mancheTheatre,
          lexique: lexique,
          rappels: FakeRappels(),
        ),
      ),
    );
    await tester.pump();

    final avant0 = tester.getCenter(_perso(0));
    final avant1 = tester.getCenter(_perso(1));

    // Le personnage suit le doigt : il se déplace exactement d'autant.
    await tester.timedDragFrom(
      avant0,
      const Offset(120, -70),
      const Duration(milliseconds: 300),
    );
    await tester.pump();

    final apres0 = tester.getCenter(_perso(0));
    expect(apres0.dx, closeTo(avant0.dx + 120, 1));
    expect(apres0.dy, closeTo(avant0.dy - 70, 1));
    // L'autre personnage n'a pas bougé d'un point.
    expect(tester.getCenter(_perso(1)), avant1);
  });

  testWidgets('le bouton Rejouer apparaît après deux secondes de scène', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scene(
        MoteurTheatre(
          manche: _mancheTheatre,
          lexique: lexique,
          rappels: FakeRappels(),
        ),
      ),
    );
    await tester.pump();

    // Le premier déplacement lance l'enregistrement ; ensuite la scène
    // s'échantillonne toute seule, dix positions par seconde.
    await tester.timedDragFrom(
      tester.getCenter(_perso(0)),
      const Offset(60, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pump();

    await _pomper(tester, 15); // 1,5 s de scène : pas encore
    expect(find.byKey(MoteurTheatre.cleRejouer), findsNothing);

    await _pomper(tester, 10); // 2,5 s de scène : le bouton est là
    expect(find.byKey(MoteurTheatre.cleRejouer), findsOneWidget);
  });

  testWidgets('Rejouer rejoue la scène, dit bravo, et l\'item est réussi '
      'une seule fois', (tester) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _scene(
        MoteurTheatre(
          manche: _mancheTheatre,
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();

    // On joue une petite scène : le loup part vers la droite, en haut.
    final depart = tester.getCenter(_perso(0));
    await tester.timedDragFrom(
      depart,
      const Offset(110, -60),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    await _pomper(tester, 25); // 2,5 s de scène enregistrée

    expect(find.byKey(MoteurTheatre.cleRejouer), findsOneWidget);
    expect(rappels.reussis, 0);

    // On rejoue : la scène repart de son tout début.
    await tester.tap(find.byKey(MoteurTheatre.cleRejouer));
    await tester.pump();
    await tester.pump(MoteurTheatre.pas);
    expect(tester.getCenter(_perso(0)).dx, closeTo(depart.dx, 10));

    // Pendant le rejeu, les prises ne répondent plus.
    final pendant = tester.getCenter(_perso(1));
    await tester.timedDragFrom(
      pendant,
      const Offset(120, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    expect(tester.getCenter(_perso(1)), pendant);

    // À la fin du rejeu complet : bravo, puis l'item réussi. Une fois.
    await _pomper(tester, 40);
    expect(rappels.reussis, 1);
    expect(rappels.rates, 0);
    expect(rappels.clips, contains('theatre.bravo'));

    // Le bouton redevient disponible : on peut rejouer encore, mais l'item
    // est déjà réussi et rien n'est redit.
    expect(find.byKey(MoteurTheatre.cleRejouer), findsOneWidget);
    await tester.tap(find.byKey(MoteurTheatre.cleRejouer));
    await tester.pump();
    await _pomper(tester, 40);
    expect(rappels.reussis, 1);
    expect(rappels.clips.where((clip) => clip == 'theatre.bravo').length, 1);
  });

  testWidgets('sur un écran de téléphone, tout ce qui se touche fait au '
      'moins 80 points', (tester) async {
    // iPhone 15 Pro : 390 × 844 points.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _scene(
        MoteurTheatre(
          manche: _mancheTheatre,
          lexique: lexique,
          rappels: FakeRappels(),
        ),
      ),
    );
    await tester.pump();

    await tester.timedDragFrom(
      tester.getCenter(_perso(1)),
      const Offset(0, -120),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    await _pomper(tester, 25); // le bouton Rejouer est là aussi

    // Les deux personnages, Rejouer et Recommencer.
    expect(find.byType(CibleTactile), findsNWidgets(4));
    for (final element in find.byType(CibleTactile).evaluate()) {
      final taille = tester.getSize(find.byWidget(element.widget));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }
    // Le bouton est exactement le bouton : sa cible ne s'étire pas sur
    // toute la bande du bas (le Center interne d'une CibleTactile prend
    // toute la place qu'on lui laisse).
    final bouton = tester.getSize(find.byKey(MoteurTheatre.cleRejouer));
    expect(bouton.width, lessThan(200));
    expect(bouton.height, lessThan(200));
    // Et le rond vert est bien GROS : la pastille dessinée prend la cible.
    final pastille = tester.getSize(
      find.descendant(
        of: find.byKey(MoteurTheatre.cleRejouer),
        matching: find.byType(Icon),
      ),
    );
    expect(pastille.width, greaterThanOrEqualTo(80));
    expect(pastille.height, greaterThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('le temps de scène s\'arrête tout seul : la scène dure ce que '
      'le chrono a permis', (tester) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _scene(
        MoteurTheatre(
          manche: const Manche(
            id: 'theatre.court',
            clipsConsigne: ['consigne.theatre.joue'],
            donnees: DonneesTheatre(
              personnages: ['loup', 'lapin'],
              dureeMaxSecondes: 3,
            ),
          ),
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();

    await tester.timedDragFrom(
      tester.getCenter(_perso(0)),
      const Offset(40, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pump();

    // Quatre secondes passent : le chrono de trois secondes a coupé
    // l'enregistrement tout seul.
    await _pomper(tester, 40);
    expect(find.byKey(MoteurTheatre.cleRejouer), findsOneWidget);

    // La scène rejouée tient donc dans les trois secondes enregistrées :
    // le rejeu se termine et la scène est réussie.
    await tester.tap(find.byKey(MoteurTheatre.cleRejouer));
    await tester.pump();
    await _pomper(tester, 32);
    expect(rappels.reussis, 1);
  });

  testWidgets('une manche sans données de théâtre ne casse rien', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scene(
        MoteurTheatre(
          manche: const Manche(
            id: 'theatre.sans-donnees',
            clipsConsigne: ['consigne.theatre.joue'],
          ),
          lexique: lexique,
          rappels: FakeRappels(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ImageConcept), findsNothing);
    expect(find.byKey(MoteurTheatre.cleRejouer), findsNothing);
  });

  testWidgets('la pause ne consomme pas le temps disponible pour la scène', (
    tester,
  ) async {
    final rappels = _RappelsPausables();
    await tester.pumpWidget(
      _scene(
        MoteurTheatre(
          manche: const Manche(
            id: 'theatre.pause',
            clipsConsigne: [],
            donnees: DonneesTheatre(
              personnages: ['loup', 'lapin'],
              dureeMaxSecondes: 3,
            ),
          ),
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(_perso(0));
    await _pomper(tester, 5);
    rappels.enPause = true;
    await _pomper(tester, 40);
    expect(find.byKey(MoteurTheatre.cleRejouer), findsNothing);
    rappels.enPause = false;
    await _pomper(tester, 25);
    expect(find.byKey(MoteurTheatre.cleRejouer), findsOneWidget);
    await tester.tap(find.byKey(MoteurTheatre.cleRejouer));
    await _pomper(tester, 35);
    expect(rappels.reussis, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
