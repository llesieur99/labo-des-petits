import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/lettres/chemins_lettres.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/moteurs/m1_tap_pick/tap_pick.dart';
import 'package:jeux_enfants/core/moteurs/m2_drop_place/depot_place.dart';
import 'package:jeux_enfants/core/moteurs/m3_trace/trace.dart';
import 'package:jeux_enfants/core/moteurs/m4_scene/scene.dart';
import 'package:jeux_enfants/core/moteurs/m7_creation/atelier.dart';
import 'package:jeux_enfants/core/moteurs/m7_creation/theatre.dart';
import 'package:jeux_enfants/core/moteurs/m7_creation/toile.dart';
import 'package:jeux_enfants/core/moteurs/m9_balance/balance.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/features/jeu/jeu_controller.dart';

Future<void> toucher(WidgetTester tester, Finder cible) async {
  expect(cible, findsOneWidget);
  await tester.ensureVisible(cible);
  await tester.tap(cible);
  await tester.pump();
}

Future<void> toucheCle(WidgetTester tester, Key cle) =>
    toucher(tester, find.byKey(cle));

Future<void> toucheConcept(WidgetTester tester, Type moteur, String concept) =>
    toucher(
      tester,
      find.descendant(
        of: find.byType(moteur),
        matching: find.byWidgetPredicate(
          (w) =>
              w is CibleTactile &&
              w.semantique == lexiquePour(Deck.qc)[concept]!.texte,
        ),
      ),
    );

Future<void> souffler(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Résolution par les mêmes touches et tracés que l'enfant, sans appeler
/// itemReussi ni changer l'état interne d'un moteur.
Future<void> jouerManche(
  WidgetTester tester,
  JeuController partie, {
  bool avecErreur = false,
}) async {
  final manche = partie.manche;
  final donnees = manche.donnees;
  if (partie.activite.moteur == Moteur.tapPick) {
    if (avecErreur) {
      final mauvaise = manche.options.firstWhere(
        (o) => o.id != manche.bonneOptionId,
      );
      await toucheConcept(tester, MoteurTapPick, mauvaise.concept);
      await souffler(tester);
    }
    await toucheConcept(tester, MoteurTapPick, manche.bonneOption.concept);
  } else if (donnees is DonneesDepot) {
    final occupes = <String>{};
    for (var i = 0; i < donnees.objets.length; i++) {
      final concept = donnees.objets[i];
      final emplacement = donnees.emplacements.firstWhere(
        (e) =>
            (donnees.modeBacs || !occupes.contains(e.id)) &&
            donnees.places[e.id]!.contains(concept),
      );
      await toucheCle(tester, MoteurDepotPlace.cleObjet(i, concept));
      await toucheCle(tester, MoteurDepotPlace.cleEmplacement(emplacement.id));
      occupes.add(emplacement.id);
    }
  } else if (donnees is DonneesScene) {
    for (final etape in donnees.etapes) {
      if (etape.options.isEmpty) {
        await tester.pump(Duration(milliseconds: etape.observationMs + 400));
        await tester.pump();
      } else {
        await toucheConcept(tester, MoteurScene, etape.bonneOption!);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
      }
    }
  } else if (donnees is DonneesOrdre) {
    final poses = <String>{};
    for (final concept in donnees.cases) {
      final option = manche.options.firstWhere(
        (o) => o.concept == concept && !poses.contains(o.id),
      );
      await toucheCle(tester, ValueKey('ordre.image.${option.id}'));
      poses.add(option.id);
    }
  } else if (donnees is DonneesCode) {
    final programme = solutionCode(donnees);
    for (final bloc in programme) {
      await toucheCle(tester, ValueKey('code.bloc.$bloc'));
    }
    await toucheCle(tester, const ValueKey('code.go'));
    for (var i = 0; i < (programme.length + 2) * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else if (donnees is DonneesComposer) {
    for (var i = 0; i < donnees.cases; i++) {
      await toucheCle(
        tester,
        ValueKey('composer.carte.${donnees.sons.keys.first}'),
      );
    }
    await toucheCle(tester, const ValueKey('composer.jouer'));
    for (var i = 0; i < (donnees.cases * 2 + 4) * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else if (donnees is DonneesTrace) {
    final zone = tester.getRect(find.byKey(const ValueKey('trace.zone')));
    final geo = GeometrieTrace.pour(
      boite: zone.size,
      trace: cheminsTrace[donnees.cheminId]!,
      largeurRuban: donnees.largeurRuban,
    );
    final doigt = await tester.startGesture(zone.topLeft + geo.points.first);
    for (var i = 1; i < geo.points.length; i += 4) {
      await doigt.moveTo(zone.topLeft + geo.points[i]);
      await tester.pump();
    }
    await doigt.moveTo(zone.topLeft + geo.points.last);
    await doigt.up();
    await tester.pump();
  } else if (donnees is DonneesAtelier) {
    for (final groupe in donnees.groupes) {
      await toucheCle(tester, MoteurAtelier.cleOption(groupe.options.first));
    }
    await toucheCle(tester, MoteurAtelier.cleJaiUnNom);
    await tester.pump();
    await toucheCle(
      tester,
      MoteurAtelier.cleNourriture(donnees.nourritures.first),
    );
  } else if (donnees is DonneesTheatre) {
    await toucheConcept(tester, MoteurTheatre, donnees.personnages.first);
    final zone = tester.getRect(find.byType(MoteurTheatre));
    await tester.tapAt(zone.center);
    for (var i = 0; i < 22; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await toucheCle(tester, MoteurTheatre.cleRejouer);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else if (donnees is DonneesToile) {
    final zone = tester.getRect(find.byKey(MoteurToile.cleToile));
    final palette = donnees.palette;
    final peintures = donnees.couleurObjectif == null
        ? [palette.first]
        : donnees.melanges.entries
              .firstWhere((e) => e.value == donnees.couleurObjectif)
              .key
              .split('+');
    for (final couleur in peintures) {
      await toucheCle(tester, MoteurToile.clePastille(couleur));
      final points = donnees.taches.isNotEmpty
          ? donnees.taches.map((t) => Offset(t.x, t.y)).toList()
          : [
              for (var y = 2; y < 8; y++)
                for (var x = 2; x < 7; x++)
                  Offset((x + .5) / 16, (y + .5) / 16),
            ];
      for (final point in points) {
        // Une tache couvre plusieurs cellules : quelques touches voisines
        // reproduisent le geste d'un enfant qui la colorie complètement.
        final appuis = donnees.taches.isEmpty
            ? [point]
            : [
                point,
                point + const Offset(0.025, 0),
                point + const Offset(-0.025, 0),
                point + const Offset(0, 0.025),
                point + const Offset(0, -0.025),
              ];
        for (final appui in appuis) {
          await tester.tapAt(
            zone.topLeft +
                Offset(appui.dx * zone.width, appui.dy * zone.height),
          );
          await tester.pump();
          if (partie.manche.id != manche.id || partie.fini) return;
        }
      }
    }
  } else if (donnees is DonneesBalance) {
    for (var i = 0; i < donnees.minimumParPlateau * 2; i++) {
      await toucheCle(tester, MoteurBalance.cleFruit(i, donnees.reserve[i]));
      await toucheCle(
        tester,
        MoteurBalance.clePlateau(i.isEven ? 'gauche' : 'droite'),
      );
    }
  } else if (donnees is DonneesRythme) {
    switch (donnees.mode) {
      case ModeRythme.echo:
        await toucheCle(tester, const ValueKey('rythme.jaiEssaye'));
      case ModeRythme.ecoute:
        await toucheCle(
          tester,
          ValueKey('rythme.option.${donnees.bonneOption}'),
        );
      case ModeRythme.syllabes:
        for (var i = 0; i < donnees.syllabesClips.length + 2; i++) {
          await tester.pump(const Duration(milliseconds: 600));
        }
        for (var i = 0; i < donnees.syllabesClips.length; i++) {
          await toucheCle(tester, const ValueKey('rythme.syllabe'));
        }
        await tester.pump(const Duration(milliseconds: 350));
      case ModeRythme.pulsation:
        for (var i = 0; i < donnees.battements; i++) {
          await tester.pump(Duration(milliseconds: donnees.intervalleMs));
          await toucheCle(tester, const ValueKey('rythme.tambour'));
        }
      case ModeRythme.bercement:
        for (var i = 0; i < donnees.battements; i++) {
          await tester.pump(Duration(milliseconds: donnees.intervalleMs + 100));
          await toucheCle(tester, const ValueKey('rythme.caresse'));
        }
    }
  } else {
    fail('Moteur non couvert : ${partie.activite.id}');
  }
  await souffler(tester);
  await souffler(tester);
}

List<String> solutionCode(DonneesCode d) {
  final file = Queue<(int, int, int, List<String>)>()
    ..add((d.departX, d.departY, 0, []));
  final vus = <(int, int, int)>{};
  const directions = [(1, 0), (0, 1), (-1, 0), (0, -1)];
  while (file.isNotEmpty) {
    final (x, y, sens, programme) = file.removeFirst();
    if (!vus.add((x, y, sens))) continue;
    if (x == d.objectifX && y == d.objectifY) {
      return [...programme, if (d.ramassable != null) 'ramasser'];
    }
    if (programme.length >= d.maxBlocs) continue;
    file.add((x, y, (sens + 1) % 4, [...programme, 'tourner']));
    final (dx, dy) = directions[sens];
    if (x + dx >= 0 && y + dy >= 0 && x + dx < d.taille && y + dy < d.taille) {
      file.add((x + dx, y + dy, sens, [...programme, 'avancer']));
    }
  }
  throw StateError('Aucune solution');
}
