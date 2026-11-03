import 'dart:math';
import 'package:jeux_enfants/core/contenu/activites/logique/code_data.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m5_ordre/code_blocs.dart';
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

const _lexique = <String, EntreeLexique>{
  'souris': EntreeLexique(texte: 'souris'),
  'fromage': EntreeLexique(texte: 'fromage'),
};

/// Une manche de code : la souris part en haut à gauche (0,0), tournée vers
/// la droite, sur une grille 3 × 3 — l'objectif est deux cases plus loin.
Manche _manche({
  String id = 'code.souris',
  int departX = 0,
  int departY = 0,
  int objectifX = 2,
  int objectifY = 0,
  String? ramassable,
  int maxBlocs = 3,
}) => Manche(
  id: id,
  clipsConsigne: const ['consigne.code'],
  donnees: DonneesCode(
    taille: 3,
    departX: departX,
    departY: departY,
    objectifX: objectifX,
    objectifY: objectifY,
    animal: 'souris',
    ramassable: ramassable,
    maxBlocs: maxBlocs,
  ),
);

void main() {
  Future<void> monter(
    WidgetTester tester,
    _FakeRappels rappels,
    Manche manche,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurCodeBlocs(
            manche: manche,
            lexique: _lexique,
            rappels: rappels,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// L'état du moteur : sert à lire le programme posé.
  MoteurCodeBlocsEtat etat(WidgetTester tester) =>
      tester.state<MoteurCodeBlocsEtat>(find.byType(MoteurCodeBlocs));

  /// Toucher un bloc de la barre : il vient se poser à la fin du programme.
  Future<void> poser(WidgetTester tester, String bloc) async {
    await tester.tap(find.byKey(ValueKey('code.bloc.$bloc')));
    await tester.pump();
  }

  /// Toucher GO, puis laisser le programme se dérouler : 500 ms par bloc,
  /// l'animation de glissement (400 ms) et la pause finale comprises.
  Future<void> lancerEtAttendre(WidgetTester tester, int nbBlocs) async {
    await tester.tap(find.byKey(const ValueKey('code.go')));
    await tester.pump();
    for (var i = 0; i < nbBlocs; i++) {
      await tester.pump(MoteurCodeBlocsEtat.delaiBloc);
      await tester.pump(MoteurCodeBlocsEtat.dureeGlissement);
    }
    await tester.pump(MoteurCodeBlocsEtat.delaiBloc); // la pause finale
    await tester.pump();
  }

  /// L'orientation affichée par l'indicateur, en tours complets
  /// (0 = droite, 0,25 = bas, 0,5 = gauche, 0,75 = haut).
  double quartsDeFleche(WidgetTester tester) => tester
      .widget<AnimatedRotation>(find.byKey(const ValueKey('code.fleche')))
      .turns;

  Future<void> attendre(WidgetTester tester, int ms) =>
      tester.pump(Duration(milliseconds: ms));

  testWidgets('le programme montre le bloc en cours pendant l’exécution', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _manche());
    await poser(tester, 'avancer');
    await poser(tester, 'avancer');
    await tester.tap(find.byKey(const ValueKey('code.go')));
    await tester.pump();
    expect(find.byKey(const ValueKey('code.actif.0')), findsOneWidget);
    await tester.pump(MoteurCodeBlocsEtat.delaiBloc);
    expect(find.byKey(const ValueKey('code.actif.1')), findsOneWidget);
    await tester.pump(MoteurCodeBlocsEtat.delaiBloc);
    await tester.pump(MoteurCodeBlocsEtat.pauseFinale);
    await tester.pump();
    expect(rappels.reussites, 1);
    expect(find.byKey(const ValueKey('code.actif.1')), findsNothing);
  });

  for (final taille in [const Size(358, 560), const Size(756, 273)]) {
    testWidgets('six commandes visibles avec le plateau $taille', (
      tester,
    ) async {
      tester.view.physicalSize = taille;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await monter(tester, _FakeRappels(), _manche(maxBlocs: 6));
      await poser(tester, 'avancer');
      final ecran = Offset.zero & taille;
      for (final cle in [
        'code.grille',
        for (var i = 0; i < 6; i++) 'code.emplacement.$i',
        'code.bloc.avancer',
        'code.bloc.tourner',
        'code.bloc.ramasser',
        'code.go',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(cle)));
        expect(ecran.contains(rect.topLeft), isTrue, reason: cle);
        expect(
          rect.right <= ecran.right && rect.bottom <= ecran.bottom,
          isTrue,
          reason: cle,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  // ─────────────────────────── avancer jusqu'à l'objectif ───────────────────

  testWidgets('le retour avancé du catalogue se gagne avec six blocs', (
    tester,
  ) async {
    final manches = const CodeGenerateur().generer(
      activiteCode.niveauPour(Palier.a7, numero: 8)!,
      Random(1),
    );
    final manche = manches.firstWhere((m) {
      final d = m.donnees as DonneesCode;
      return d.departX - d.objectifX == 2 && d.objectifY - d.departY == 1;
    });
    final rappels = _FakeRappels();
    await monter(tester, rappels, manche);
    for (final bloc in [
      'tourner',
      'avancer',
      'tourner',
      'avancer',
      'avancer',
      'ramasser',
    ]) {
      await poser(tester, bloc);
    }
    expect(etat(tester).programme, hasLength(6));
    await lancerEtAttendre(tester, 6);
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('deux blocs « avancer » mènent l\'animal à l\'étoile', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _manche());

    // Sans programme, il n'y a pas de GO ; l'objectif porte son étoile.
    expect(find.byKey(const ValueKey('code.go')), findsNothing);
    expect(find.byKey(const ValueKey('code.etoile')), findsOneWidget);
    expect(find.byKey(const ValueKey('code.animal')), findsOneWidget);

    await poser(tester, 'avancer');
    await poser(tester, 'avancer');
    expect(etat(tester).programme, [BlocCode.avancer, BlocCode.avancer]);

    await lancerEtAttendre(tester, 2);

    // L'animal a marché deux cases et s'est arrêté sur l'objectif : gagné.
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
    expect(rappels.dits, [MoteurCodeBlocsEtat.clipBravo]);
    expect(etat(tester).reussi, isTrue);
    expect(etat(tester).enExecution, isFalse);
  });

  // ──────────────────────────── la butée contre le mur ──────────────────────

  testWidgets('un programme qui butte rate doucement, et le programme reste', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    // L'animal est collé au bord droit et regarde à droite : « avancer »
    // le mène tout droit dans le mur.
    await monter(
      tester,
      rappels,
      _manche(
        departX: 2,
        departY: 0,
        objectifX: 0,
        objectifY: 0,
        ramassable: 'fromage',
      ),
    );

    await poser(tester, 'avancer');
    await poser(tester, 'avancer');
    await tester.tap(find.byKey(const ValueKey('code.go')));
    await tester.pump();
    expect(etat(tester).enExecution, isTrue);

    // Pendant l'exécution, tout est inerte : taper un bloc ne fait rien.
    await attendre(tester, 200);
    await poser(tester, 'avancer');
    expect(etat(tester).programme.length, 2);

    // On laisse finir : la butée a arrêté le programme tout de suite.
    await tester.pump(MoteurCodeBlocsEtat.delaiBloc);
    await tester.pump(const Duration(milliseconds: 1400));

    expect(rappels.rates, 1);
    expect(rappels.reussites, 0);
    // Rien n'a été perdu : les deux blocs sont toujours là, prêts à corriger.
    expect(etat(tester).programme, [BlocCode.avancer, BlocCode.avancer]);
    expect(find.byKey(const ValueKey('code.pose.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('code.pose.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('code.pose.2')), findsNothing);
    // Et l'animal a repris sa place, tourné vers la droite.
    expect(quartsDeFleche(tester), 0);

    // Le programme peut être modifié : le dernier bloc posé s'en va.
    await tester.tap(find.byKey(const ValueKey('code.emplacement.1')));
    await tester.pump();
    expect(etat(tester).programme, [BlocCode.avancer]);
  });

  testWidgets('une butée arrête le programme : le reste ne s\'exécute pas', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    // Piège : l'animal part SUR l'objectif (avec son fromage) mais regarde
    // le mur. « avancer » butte, donc « ramasser » ne doit JAMAIS s'exécuter :
    // si le moteur continuait, l'objet serait ramassé et la manche gagnée.
    await monter(
      tester,
      rappels,
      _manche(
        departX: 2,
        departY: 0,
        objectifX: 2,
        objectifY: 0,
        ramassable: 'fromage',
      ),
    );

    await poser(tester, 'avancer');
    await poser(tester, 'ramasser');
    await lancerEtAttendre(tester, 2);

    expect(rappels.rates, 1);
    expect(rappels.reussites, 0);
    expect(find.byKey(const ValueKey('code.objet')), findsOneWidget);
    expect(find.byKey(const ValueKey('code.pose.1')), findsOneWidget);
  });

  // ───────────────────────────── le quart de tour ───────────────────────────

  testWidgets('« tourner » fait pivoter l\'animal, qui avance ensuite en bas', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    // L'objectif est SOUS la case de départ : sans le quart de tour,
    // « avancer » emmènerait l'animal à droite, pas en bas.
    await monter(
      tester,
      rappels,
      _manche(departX: 1, departY: 0, objectifX: 1, objectifY: 1),
    );

    // L'animal commence tourné vers la droite (0 tour).
    expect(quartsDeFleche(tester), 0);

    await poser(tester, 'tourner');
    await poser(tester, 'avancer');
    await tester.tap(find.byKey(const ValueKey('code.go')));
    await tester.pump();

    // Le quart de tour est joué : l'indicateur a pivoté (droite → bas).
    await tester.pump(MoteurCodeBlocsEtat.delaiBloc);
    expect(quartsDeFleche(tester), 0.25);

    await tester.pump(MoteurCodeBlocsEtat.delaiBloc);
    await tester.pump(MoteurCodeBlocsEtat.delaiBloc);
    await tester.pump();

    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  // ──────────────────────────────── ramasser ───────────────────────────────

  testWidgets('« ramasser » fait disparaître l\'objet et gagne la manche', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(
      tester,
      rappels,
      _manche(
        departX: 0,
        departY: 0,
        objectifX: 1,
        objectifY: 0,
        ramassable: 'fromage',
      ),
    );

    expect(find.byKey(const ValueKey('code.objet')), findsOneWidget);
    expect(find.byKey(const ValueKey('code.etoile')), findsNothing);

    await poser(tester, 'avancer');
    await poser(tester, 'ramasser');
    await lancerEtAttendre(tester, 2);

    // L'objet s'est envolé dans son petit « pop », et la manche est gagnée.
    expect(find.byKey(const ValueKey('code.objet')), findsNothing);
    expect(rappels.dits, [MoteurCodeBlocsEtat.clipBravo]);
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('passer sur l\'objet sans le ramasser rate — puis on corrige', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(
      tester,
      rappels,
      _manche(
        departX: 0,
        departY: 0,
        objectifX: 1,
        objectifY: 0,
        ramassable: 'fromage',
      ),
    );

    // Le programme amène l'animal SUR l'objet, mais ne le ramasse pas.
    await poser(tester, 'avancer');
    await lancerEtAttendre(tester, 1);

    expect(rappels.rates, 1);
    expect(rappels.reussites, 0);
    // L'objet est toujours là, et le programme aussi : l'enfant n'a qu'à
    // ajouter le bloc manquant, sans tout refaire.
    expect(find.byKey(const ValueKey('code.objet')), findsOneWidget);
    expect(etat(tester).programme, [BlocCode.avancer]);
    expect(find.byKey(const ValueKey('code.pose.0')), findsOneWidget);

    // Il ajoute « ramasser » et rejoue : cette fois, c'est gagné.
    await poser(tester, 'ramasser');
    await lancerEtAttendre(tester, 2);

    expect(rappels.reussites, 1);
    expect(rappels.rates, 1); // l'essai raté reste un essai raté, sans reproche
    expect(find.byKey(const ValueKey('code.objet')), findsNothing);
  });

  testWidgets('un « ramasser » dans le vide ne fait rien du tout', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(
      tester,
      rappels,
      _manche(
        departX: 0,
        departY: 0,
        objectifX: 2,
        objectifY: 0,
        ramassable: 'fromage',
      ),
    );

    // L'animal ramasse à sa case de départ : il n'y a rien à ramasser là.
    await poser(tester, 'ramasser');
    await lancerEtAttendre(tester, 1);

    expect(find.byKey(const ValueKey('code.objet')), findsOneWidget);
    expect(rappels.rates, 1);
    expect(rappels.reussites, 0);
  });

  // ───────────────────────────── le programme ──────────────────────────────

  testWidgets('le programme refuse un bloc de plus que maxBlocs', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _manche(maxBlocs: 3));

    for (var i = 0; i < 4; i++) {
      await poser(tester, 'avancer');
    }

    // Trois emplacements, pas quatre : le bloc de trop n'entre pas.
    expect(etat(tester).programme.length, 3);
    expect(find.byKey(const ValueKey('code.pose.2')), findsOneWidget);
    expect(find.byKey(const ValueKey('code.pose.3')), findsNothing);

    // On corrige : le DERNIER bloc posé s'en va quand on le touche…
    await tester.tap(find.byKey(const ValueKey('code.emplacement.2')));
    await tester.pump();
    expect(etat(tester).programme.length, 2);

    // Une erreur au début se corrige aussi sans effacer les blocs suivants.
    await tester.tap(find.byKey(const ValueKey('code.emplacement.0')));
    await tester.pump();
    expect(etat(tester).programme.length, 1);
  });

  testWidgets('corriger un bloc au début conserve la suite du programme', (
    tester,
  ) async {
    await monter(tester, _FakeRappels(), _manche(maxBlocs: 3));
    await poser(tester, 'avancer');
    await poser(tester, 'tourner');
    await poser(tester, 'ramasser');
    await tester.tap(find.byKey(const ValueKey('code.emplacement.0')));
    await tester.pump();
    expect(etat(tester).programme, [BlocCode.tourner, BlocCode.ramasser]);
  });

  // ───────────────────────────── l'ergonomie ───────────────────────────────

  testWidgets('toutes les cibles font au moins 80 points', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _manche());

    const cibles = [
      'code.bloc.avancer',
      'code.bloc.tourner',
      'code.bloc.ramasser',
      'code.emplacement.0',
      'code.emplacement.1',
      'code.emplacement.2',
    ];
    for (final cle in cibles) {
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

    // Le GO n'apparaît qu'avec un programme — et lui aussi est assez gros.
    expect(find.byKey(const ValueKey('code.go')), findsNothing);
    await poser(tester, 'avancer');
    final go = tester.getSize(find.byKey(const ValueKey('code.go')));
    expect(go.width, greaterThanOrEqualTo(80));
    expect(go.height, greaterThanOrEqualTo(80));

    // La grille tient sur l'écran, avec ses trois cases bien visibles.
    final grille = tester.getSize(find.byKey(const ValueKey('code.grille')));
    expect(grille.width, lessThanOrEqualTo(800));
    expect(grille.height, lessThanOrEqualTo(600));
  });

  // ─────────────────────── les données folles et la manche neuve ────────────

  testWidgets('des données absentes ou d\'un autre type : écran calme', (
    tester,
  ) async {
    final rappels = _FakeRappels();

    // Une manche sans donnees…
    await monter(
      tester,
      rappels,
      const Manche(id: 'code.vide', clipsConsigne: ['consigne.code']),
    );
    expect(find.byType(CibleTactile), findsNothing);
    expect(find.byKey(const ValueKey('code.grille')), findsNothing);

    // … puis une manche de code avec une grille de taille nulle…
    await monter(
      tester,
      rappels,
      Manche(
        id: 'code.zero',
        clipsConsigne: const ['consigne.code'],
        donnees: const DonneesCode(
          taille: 0,
          departX: 0,
          departY: 0,
          objectifX: 0,
          objectifY: 0,
          animal: 'souris',
        ),
      ),
    );
    expect(find.byType(CibleTactile), findsNothing);

    // … puis des données d'un autre moteur : jamais une exception.
    await monter(
      tester,
      rappels,
      const Manche(
        id: 'code.faux',
        clipsConsigne: ['consigne.code'],
        donnees: DonneesOrdre(cases: ['graine', 'fleur']),
      ),
    );
    expect(find.byType(CibleTactile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une nouvelle manche repart de zéro', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _manche());

    await poser(tester, 'avancer');
    await poser(tester, 'avancer');
    expect(etat(tester).programme.length, 2);

    // L'hôte réutilise le même moteur pour la manche suivante : l'ancien
    // programme s'efface, l'objet neuf est là, l'animal est à son départ.
    await monter(
      tester,
      rappels,
      _manche(
        id: 'code.souris.2',
        departX: 0,
        departY: 1,
        objectifX: 2,
        objectifY: 1,
        ramassable: 'fromage',
      ),
    );

    expect(etat(tester).programme, isEmpty);
    expect(etat(tester).reussi, isFalse);
    expect(find.byKey(const ValueKey('code.pose.0')), findsNothing);
    expect(find.byKey(const ValueKey('code.objet')), findsOneWidget);
    expect(quartsDeFleche(tester), 0);

    // Et la manche neuve se gagne normalement.
    await poser(tester, 'avancer');
    await poser(tester, 'avancer');
    await poser(tester, 'ramasser');
    await lancerEtAttendre(tester, 3);
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });
}
