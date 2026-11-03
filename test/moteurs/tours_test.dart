import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/moteurs/m8_tours/tours.dart';
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

/// Compte les doigts reçus par le moteur interne.
class _Compteur {
  int taps = 0;
}

/// Un moteur interne factice : une cible tactile qui compte les taps.
Widget _enfantFactice(_Compteur compteur) {
  return Container(
    color: const Color(0xFFEDE7DA),
    child: CibleTactile(
      key: const ValueKey('enfant.cible'),
      onTap: () => compteur.taps++,
      child: const SizedBox(width: 140, height: 140),
    ),
  );
}

void main() {
  late ToursController tours;
  late _FakeRappels rappels;
  late _Compteur compteur;

  setUp(() {
    tours = ToursController();
    rappels = _FakeRappels();
    compteur = _Compteur();
  });

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurTours(
            enfant: _enfantFactice(compteur),
            tours: tours,
            lexique: const <String, EntreeLexique>{},
            rappels: rappels,
            clipsMonTour: 'consigne.monTour',
            clipsAutreTour: 'consigne.autreTour',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Un doigt au milieu d'une moitié de l'écran.
  Future<void> toucher(WidgetTester tester, String moitie) async {
    final cible = find.byKey(ValueKey('tours.moitie.$moitie'));
    await tester.tapAt(tester.getCenter(cible));
    await tester.pumpAndSettle();
  }

  testWidgets('au démarrage, l\'app annonce le tour du premier enfant', (
    tester,
  ) async {
    await monter(tester);

    expect(rappels.dits, ['consigne.monTour']);
    // Le bandeau est du côté actif : à gauche au premier tour.
    final bandeau = tester.getCenter(
      find.byKey(const ValueKey('tours.bandeau')),
    );
    expect(bandeau.dx, lessThan(400));
  });

  testWidgets('un doigt sur la moitié active joue ; sur l\'inactive, rien', (
    tester,
  ) async {
    await monter(tester);

    await toucher(tester, 'gauche');
    expect(compteur.taps, 1);

    // La moitié inactive absorbe le doigt : aucun tap ne va au moteur,
    // aucun son, aucune sanction — juste le petit « non » visuel.
    await toucher(tester, 'droite');
    expect(compteur.taps, 1);
    expect(rappels.dits, ['consigne.monTour']);
    expect(rappels.rates, 0);

    // Le moteur interne n'existe qu'une fois : il n'est pas dupliqué
    // de l'autre côté.
    expect(find.byKey(const ValueKey('enfant.cible')), findsOneWidget);
  });

  testWidgets('changer de tour annonce l\'autre clip et déplace la moitié '
      'qui répond', (tester) async {
    await monter(tester);
    expect(compteur.taps, 0);

    tours.changerDeTour();
    await tester.pumpAndSettle();

    expect(rappels.dits, ['consigne.monTour', 'consigne.autreTour']);
    final bandeau = tester.getCenter(
      find.byKey(const ValueKey('tours.bandeau')),
    );
    expect(bandeau.dx, greaterThan(400));

    // La moitié gauche ne répond plus…
    await toucher(tester, 'gauche');
    expect(compteur.taps, 0);

    // … et c'est maintenant la droite qui joue.
    await toucher(tester, 'droite');
    expect(compteur.taps, 1);
    expect(
      tester.getCenter(find.byKey(const ValueKey('enfant.cible'))).dx,
      greaterThan(400),
    );
  });

  testWidgets('deux tours de suite : chacun est annoncé une seule fois', (
    tester,
  ) async {
    await monter(tester);

    tours.changerDeTour();
    await tester.pumpAndSettle();
    tours.changerDeTour();
    await tester.pumpAndSettle();

    expect(rappels.dits, [
      'consigne.monTour',
      'consigne.autreTour',
      'consigne.monTour',
    ]);
    await toucher(tester, 'gauche');
    expect(compteur.taps, 1);
  });

  testWidgets(
    'sur téléphone le jeu garde toute la largeur et chaque tour reste jouable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await monter(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('enfant.cible'))).width,
        greaterThanOrEqualTo(350),
      );
      await toucher(tester, 'droite');
      expect(compteur.taps, 0);
      await toucher(tester, 'gauche');
      expect(compteur.taps, 1);
      tours.changerDeTour();
      await tester.pumpAndSettle();
      await toucher(tester, 'gauche');
      expect(compteur.taps, 1);
      await toucher(tester, 'droite');
      expect(compteur.taps, 2);
      expect(find.byKey(const ValueKey('enfant.cible')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
