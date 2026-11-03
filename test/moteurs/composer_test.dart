import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m5_ordre/composer.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';

/// Le moteur ne parle qu'à travers ce contrat : on enregistre tout.
class _FakeRappels implements RappelsMoteur {
  int reussites = 0;
  int rates = 0;
  final List<String> dits = <String>[];
  final List<String> sons = <String>[];

  @override
  void itemReussi() => reussites++;

  @override
  void essaiRate() => rates++;

  @override
  Future<void> dire(String clipId) async => dits.add(clipId);

  @override
  Future<void> jouerSon(String asset) async => sons.add(asset);
}

const _tambour = 'assets/audio/neutre/sons/tambour.wav';
const _grelot = 'assets/audio/neutre/sons/grelot.wav';

const _lexique = <String, EntreeLexique>{
  'tambour': EntreeLexique(texte: 'tambour'),
  'grelot': EntreeLexique(texte: 'grelot'),
};

/// La chanson de quatre cases : deux sons, quatre places.
const _chanson = DonneesComposer(
  cases: 4,
  sons: {'tambour': _tambour, 'grelot': _grelot},
  bravoCle: 'chanson.bravo',
);

Manche _manche({
  String id = 'chanson.quatre',
  DonneesMoteur? donnees = _chanson,
}) =>
    Manche(id: id, clipsConsigne: const ['consigne.chanson'], donnees: donnees);

void main() {
  Future<void> monter(
    WidgetTester tester,
    _FakeRappels rappels, {
    Manche? aJouer,
    bool afficherMots = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurComposer(
            manche: aJouer ?? _manche(),
            lexique: _lexique,
            rappels: rappels,
            afficherMots: afficherMots,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Toucher une carte de son : le son part, et la pastille se pose dans la
  /// prochaine case libre (le temps de l'arrivée, 250 ms).
  Future<void> poser(WidgetTester tester, String concept) async {
    await tester.tap(find.byKey(ValueKey('composer.carte.$concept')));
    await tester.pumpAndSettle();
  }

  /// Remplir les quatre cases : tambour, grelot, tambour, grelot.
  Future<void> remplirLesQuatre(WidgetTester tester) async {
    await poser(tester, 'tambour');
    await poser(tester, 'grelot');
    await poser(tester, 'tambour');
    await poser(tester, 'grelot');
  }

  /// Laisser la boucle se dérouler : deux passes de quatre cases à 500 ms,
  /// plus la pause de 400 ms entre les deux.
  Future<void> attendreLaBoucle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(MoteurComposerEtat.dureeCase);
    }
    await tester.pump(MoteurComposerEtat.pauseEntrePassees);
    await tester.pump(MoteurComposerEtat.dureeCase);
  }

  /// Taper « jouer » et laisser la boucle se dérouler en entier.
  Future<void> laisserRejouer(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('composer.jouer')));
    await tester.pump(); // le rejeu démarre : le premier son est déjà parti
    await attendreLaBoucle(tester);
  }

  // ──────────────────────── les doigts sur les cartes ───────────────────────

  testWidgets('toucher une carte joue son son et remplit la première case', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    // Rien ne sonne tant que l'enfant n'a rien touché.
    expect(rappels.sons, isEmpty);
    expect(find.byKey(const ValueKey('composer.pastille.0')), findsNothing);

    await poser(tester, 'tambour');

    // Le son est parti TOUT DE SUITE, et la pastille du concept s'est posée
    // dans la première case (celle de gauche).
    expect(rappels.sons, [_tambour]);
    expect(find.byKey(const ValueKey('composer.pastille.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer.pastille.1')), findsNothing);

    // Les cartes restent disponibles : le même son peut entrer deux fois…
    await poser(tester, 'tambour');
    expect(rappels.sons, [_tambour, _tambour]);
    expect(find.byKey(const ValueKey('composer.pastille.1')), findsOneWidget);

    // … et une chanson de quatre cases n'est pas finie à deux sons.
    expect(find.byKey(const ValueKey('composer.jouer')), findsNothing);
    expect(rappels.rates, 0);
  });

  testWidgets('les quatre cases remplies font apparaître le bouton jouer', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    expect(find.byKey(const ValueKey('composer.jouer')), findsNothing);

    await remplirLesQuatre(tester);

    expect(find.byKey(const ValueKey('composer.pastille.3')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer.jouer')), findsOneWidget);

    // Une cinquième touche ne déborde pas : le son part, mais aucune case
    // neuve ne se crée (c'est à l'enfant de faire de la place).
    await poser(tester, 'tambour');
    expect(rappels.sons.length, 5);
    expect(find.byKey(const ValueKey('composer.pastille.4')), findsNothing);
    expect(find.byKey(const ValueKey('composer.jouer')), findsOneWidget);
  });

  // ─────────────────────────── le rejeu (la boucle) ─────────────────────────

  testWidgets('jouer rejoue la chanson dans l\'ordre deux fois, puis '
      'félicite une seule fois', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);
    await remplirLesQuatre(tester);

    // On oublie les quatre sons des cartes : ce qui compte ici, c'est la
    // boucle que l'app rejoue.
    rappels.sons.clear();

    await laisserRejouer(tester);

    // La boucle entière, DANS L'ORDRE des cases, deux fois de suite.
    expect(rappels.sons, [
      _tambour, _grelot, _tambour, _grelot, //
      _tambour, _grelot, _tambour, _grelot,
    ]);
    expect(rappels.dits, ['chanson.bravo']);
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);

    // L'enfant peut refaire sa chanson : deux passes de plus, mais aucune
    // autre conséquence — le bravo et la réussite ne comptent qu'une fois.
    rappels.sons.clear();
    await laisserRejouer(tester);

    expect(rappels.sons, [
      _tambour, _grelot, _tambour, _grelot, //
      _tambour, _grelot, _tambour, _grelot,
    ]);
    expect(rappels.dits, ['chanson.bravo']);
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('pendant le rejeu, les cartes ne répondent pas', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);
    await remplirLesQuatre(tester);
    rappels.sons.clear();

    await tester.tap(find.byKey(const ValueKey('composer.jouer')));
    await tester.pump();
    expect(rappels.sons, [_tambour]); // la première case sonne déjà

    // En pleine boucle, une carte touchée ne joue rien…
    await tester.tap(find.byKey(const ValueKey('composer.carte.tambour')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(rappels.sons, [_tambour]);

    // … et une case touchée ne se vide pas.
    await tester.tap(find.byKey(const ValueKey('composer.case.0')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('composer.pastille.0')), findsOneWidget);

    // La boucle finit d'elle-même, sans qu'aucun son de plus soit parti.
    await attendreLaBoucle(tester);
    expect(rappels.sons, [
      _tambour, _grelot, _tambour, _grelot, //
      _tambour, _grelot, _tambour, _grelot,
    ]);

    // À la fin, tout redevient libre : la case se vide, et une carte peut
    // la remplir de nouveau.
    await tester.tap(find.byKey(const ValueKey('composer.case.0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('composer.pastille.0')), findsNothing);

    await poser(tester, 'grelot');
    expect(find.byKey(const ValueKey('composer.pastille.0')), findsOneWidget);
    expect(rappels.sons.length, 9); // les 8 de la boucle + cette carte
  });

  // ─────────────────────────── vider une case ───────────────────────────

  testWidgets('toucher une case remplie la vide, et le bouton jouer s\'en va', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);
    await remplirLesQuatre(tester);
    expect(find.byKey(const ValueKey('composer.jouer')), findsOneWidget);

    // N'importe quelle case se vide d'un doigt — pas seulement la dernière.
    await tester.tap(find.byKey(const ValueKey('composer.case.1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('composer.pastille.1')), findsNothing);
    expect(find.byKey(const ValueKey('composer.pastille.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer.pastille.3')), findsOneWidget);
    // Trois cases sur quatre : le bouton jouer s'en va.
    expect(find.byKey(const ValueKey('composer.jouer')), findsNothing);

    // La prochaine pastille reprend la première place libre : la chanson
    // reste alignée de gauche à droite.
    await poser(tester, 'grelot');
    expect(find.byKey(const ValueKey('composer.pastille.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer.jouer')), findsOneWidget);
  });

  testWidgets('une case vidée se remplit à la prochaine place libre, et '
      'l\'ordre rejoué reste celui des cases', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    // Quatre tambours, puis un grelot à la place de la case du milieu.
    await poser(tester, 'tambour');
    await poser(tester, 'tambour');
    await poser(tester, 'tambour');
    await poser(tester, 'tambour');
    await tester.tap(find.byKey(const ValueKey('composer.case.1')));
    await tester.pump();
    await poser(tester, 'grelot');

    rappels.sons.clear();
    await laisserRejouer(tester);

    // Le grelot est bien dans la DEUXIÈME case : la boucle le rejoue à sa
    // place, de gauche à droite.
    expect(rappels.sons, [
      _tambour, _grelot, _tambour, _tambour, //
      _tambour, _grelot, _tambour, _tambour,
    ]);
  });

  // ───────────────────────── la création libre ─────────────────────────

  testWidgets('essaiRate() n\'est JAMAIS appelé : il n\'y a pas de mauvaise '
      'réponse', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    // On touche les cartes, on vide une case, on rejoue deux fois : rien de
    // tout ça n'est un essai raté — c'est de la musique.
    await remplirLesQuatre(tester);
    await tester.tap(find.byKey(const ValueKey('composer.case.0')));
    await tester.pump();
    await poser(tester, 'tambour');
    await laisserRejouer(tester);
    await laisserRejouer(tester);

    expect(rappels.rates, 0);
    expect(rappels.reussites, 1); // la première boucle finie compte, une fois
  });

  // ───────────────────────────── l'ergonomie ─────────────────────────────

  testWidgets('toutes les cibles font au moins 80 points', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    // Quatre cases et deux cartes de sons : tout est assez gros.
    expect(find.byType(CibleTactile), findsNWidgets(6));
    for (final element in find.byType(CibleTactile).evaluate()) {
      final taille = tester.getSize(find.byWidget(element.widget));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }

    // Les cases aussi, nommément.
    for (var i = 0; i < 4; i++) {
      final taille = tester.getSize(find.byKey(ValueKey('composer.case.$i')));
      expect(taille.width, greaterThanOrEqualTo(80));
      expect(taille.height, greaterThanOrEqualTo(80));
    }

    // Et le gros bouton jouer, quand il apparaît.
    await remplirLesQuatre(tester);
    final bouton = tester.getSize(find.byKey(const ValueKey('composer.jouer')));
    expect(bouton.width, greaterThanOrEqualTo(80));
    expect(bouton.height, greaterThanOrEqualTo(80));
  });

  testWidgets('tient sur un écran de téléphone, mots affichés', (tester) async {
    // Un iPhone en portrait : c'est là que le jeu vit vraiment.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rappels = _FakeRappels();
    await monter(tester, rappels, afficherMots: true);

    for (final cle in const [
      'composer.case.0',
      'composer.case.3',
      'composer.carte.tambour',
      'composer.carte.grelot',
    ]) {
      final taille = tester.getSize(find.byKey(ValueKey(cle)));
      expect(
        taille.width,
        greaterThanOrEqualTo(80),
        reason: '$cle est trop petit en largeur (${taille.width})',
      );
      expect(
        taille.height,
        greaterThanOrEqualTo(80),
        reason: '$cle est trop petit en hauteur (${taille.height})',
      );
    }

    await remplirLesQuatre(tester);
    await laisserRejouer(tester);
    expect(rappels.reussites, 1);
    expect(tester.takeException(), isNull); // rien ne déborde de l'écran
  });

  // ─────────────────── les données folles et la manche neuve ────────────────

  testWidgets('des données absentes ou d\'un autre type : écran calme', (
    tester,
  ) async {
    final rappels = _FakeRappels();

    // Une manche sans donnees…
    await monter(
      tester,
      rappels,
      aJouer: const Manche(
        id: 'chanson.vide',
        clipsConsigne: ['consigne.chanson'],
      ),
    );
    expect(find.byType(CibleTactile), findsNothing);

    // … des données d'un autre moteur…
    await monter(
      tester,
      rappels,
      aJouer: _manche(
        id: 'chanson.faux',
        donnees: const DonneesOrdre(cases: ['graine', 'fleur']),
      ),
    );
    expect(find.byType(CibleTactile), findsNothing);

    // … une chanson sans case…
    await monter(
      tester,
      rappels,
      aJouer: _manche(
        id: 'chanson.zero',
        donnees: const DonneesComposer(
          cases: 0,
          sons: {'tambour': _tambour},
          bravoCle: 'chanson.bravo',
        ),
      ),
    );
    expect(find.byType(CibleTactile), findsNothing);

    // … et une chanson sans aucun son.
    await monter(
      tester,
      rappels,
      aJouer: _manche(
        id: 'chanson.muet',
        donnees: const DonneesComposer(sons: {}, bravoCle: 'chanson.bravo'),
      ),
    );
    expect(find.byType(CibleTactile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une nouvelle chanson dans le même moteur repart de zéro', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels);

    await poser(tester, 'tambour');
    await poser(tester, 'grelot');
    expect(find.byKey(const ValueKey('composer.pastille.0')), findsOneWidget);

    // L'hôte réutilise le même moteur pour la chanson suivante.
    await monter(tester, rappels, aJouer: _manche(id: 'chanson.deux'));

    expect(find.byKey(const ValueKey('composer.pastille.0')), findsNothing);
    expect(find.byKey(const ValueKey('composer.pastille.1')), findsNothing);
    expect(find.byKey(const ValueKey('composer.jouer')), findsNothing);
    expect(tester.takeException(), isNull);

    // Et la chanson neuve se remplit comme si on venait d'arriver.
    await remplirLesQuatre(tester);
    expect(find.byKey(const ValueKey('composer.jouer')), findsOneWidget);
    expect(rappels.rates, 0);
  });
  testWidgets('six cases avec mots restent jouables sur un petit paysage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await monter(
      tester,
      _FakeRappels(),
      afficherMots: true,
      aJouer: _manche(
        donnees: const DonneesComposer(
          cases: 6,
          bravoCle: 'chanson.bravo',
          sons: {'tambour': _tambour, 'grelot': _grelot},
        ),
      ),
    );
    final tambour = find.byKey(const ValueKey('composer.carte.tambour'));
    await tester.ensureVisible(tambour);
    for (var i = 0; i < 6; i++) {
      await tester.tap(tambour);
      await tester.pumpAndSettle();
    }
    final jouer = find.byKey(const ValueKey('composer.jouer'));
    await tester.ensureVisible(jouer);
    expect(tester.getSize(jouer).shortestSide, greaterThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
  });
}
