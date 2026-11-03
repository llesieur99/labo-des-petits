import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/activites/emotions/milo_data.dart';
import 'package:jeux_enfants/core/contenu/activites/emotions/monstre_data.dart';
import 'package:jeux_enfants/core/contenu/activites/emotions/mots_demander_data.dart';
import 'package:jeux_enfants/core/contenu/activites/emotions/tours_data.dart';
import 'package:jeux_enfants/core/contenu/lexique/lexique_qc.dart';
import 'package:jeux_enfants/core/contenu/lexique/lexique_fr.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';

Niveau _niveau(Activite activite, Palier palier, int numero) {
  return activite.niveauPour(palier, numero: numero)!;
}

void main() {
  const activites = [
    activiteMilo,
    activiteMotsDemander,
    activiteTours,
    activiteMonstre,
  ];

  test('les huit étapes par âge restent complètes, uniques et jouables', () {
    for (final activite in activites) {
      final clips = {for (final c in activite.clips) c.id};
      for (final palier in Palier.values) {
        expect(activite.etapesPour(palier), hasLength(8));
        for (var numero = 1; numero <= 8; numero++) {
          final niveau = _niveau(activite, palier, numero);
          for (var graine = 0; graine < 20; graine++) {
            final manches = preparerPartie(activite, niveau, Random(graine));
            expect(
              manches,
              hasLength(niveau.nbItems),
              reason: '${activite.id}/${palier.id}/$numero',
            );
            expect(manches.map((m) => m.id).toSet(), hasLength(manches.length));
            for (final manche in manches) {
              final concepts = [...manche.options.map((o) => o.concept)];
              if (manche.donnees case DonneesScene(:final etapes)) {
                for (final etape in etapes) {
                  expect(clips, contains(etape.narrationCle));
                  concepts.addAll(etape.options);
                  expect(
                    etape.options.toSet(),
                    hasLength(etape.options.length),
                  );
                  if (etape.options.isEmpty) continue;
                  expect(etape.options, contains(etape.bonneOption));
                  expect(etape.options, containsAll(etape.autresBonnesOptions));
                  expect(
                    etape.options.length,
                    lessThanOrEqualTo(niveau.choixMax),
                  );
                }
              }
              for (final concept in concepts) {
                expect(lexiqueQc, contains(concept));
                expect(lexiqueFr, contains(concept));
              }
            }
          }
        }
      }
    }
  });

  test('les scènes récentes sont évitées dès que la banque le permet', () {
    for (final activite in [activiteMilo, activiteMotsDemander]) {
      final generateur = (activite.source as SourceGenerateur).generateur;
      for (final palier in Palier.values) {
        for (final niveau in activite.etapesPour(palier)) {
          final banque = generateur.generer(niveau, Random(0));
          final ids = banque.map((m) => m.id).toSet();
          expect(banque.length, greaterThanOrEqualTo(niveau.nbItems));
          expect(ids, hasLength(banque.length));
          final precedentes = preparerPartie(
            activite,
            niveau,
            Random(3),
          ).map((m) => m.id).toSet();
          final nouvellesDisponibles = ids.difference(precedentes).length;
          for (var graine = 0; graine < 20; graine++) {
            final partie = preparerPartie(
              activite,
              niveau,
              Random(graine),
              manchesRecentes: precedentes,
            );
            final recentesReprises = partie
                .where((m) => precedentes.contains(m.id))
                .length;
            expect(
              recentesReprises,
              max(0, niveau.nbItems - nouvellesDisponibles),
              reason: '${activite.id}/${palier.id}/${niveau.numero}/$graine',
            );
          }
          // Même avec un historique entièrement rempli, la partie reste
          // complète : les scènes récentes sont repoussées, pas interdites.
          final repli = preparerPartie(
            activite,
            niveau,
            Random(4),
            manchesRecentes: ids,
          );
          expect(repli, hasLength(niveau.nbItems));
        }
      }
    }
  });

  test(
    'Milo relie progressivement visage et soutien sans nier les émotions',
    () {
      final debut = preparerPartie(
        activiteMilo,
        _niveau(activiteMilo, Palier.a7, 1),
        Random(7),
      );
      expect(
        debut.every(
          (m) =>
              (m.donnees as DonneesScene).etapes
                  .where((e) => e.options.isNotEmpty)
                  .length ==
              1,
        ),
        isTrue,
      );
      final fins = [
        for (var graine = 0; graine < 15; graine++)
          ...preparerPartie(
            activiteMilo,
            _niveau(activiteMilo, Palier.a7, 8),
            Random(graine),
          ),
      ];
      expect(fins.map((m) => m.id).toSet(), hasLength(10));
      final joie =
          fins.firstWhere((m) => m.id == 'milo.5').donnees as DonneesScene;
      expect(joie.etapes.last.bonneOption, 'visage_content');
      final perte =
          fins.firstWhere((m) => m.id == 'milo.1').donnees as DonneesScene;
      expect(perte.etapes[1].accepte('visage_triste'), isTrue);
      expect(perte.etapes[1].accepte('visage_colere'), isTrue);
      expect(perte.etapes.last.accepte('aide'), isTrue);
      expect(perte.etapes.last.accepte('respirer'), isTrue);
    },
  );

  test('dire stop et demander de l’aide sont valables pour une limite', () {
    final manches = [
      for (var graine = 0; graine < 20; graine++)
        ...preparerPartie(
          activiteMotsDemander,
          _niveau(activiteMotsDemander, Palier.a7, 8),
          Random(graine),
        ),
    ];
    expect(manches.map((m) => m.id).toSet(), hasLength(9));
    for (final id in ['mots.2', 'mots.5', 'mots.8']) {
      final scene =
          manches.firstWhere((m) => m.id == id).donnees as DonneesScene;
      expect(scene.etapes[1].accepte('stop'), isTrue);
      expect(scene.etapes[1].accepte('aide'), isTrue);
      expect(scene.etapes[1].accepte('attendre'), isFalse);
    }
    expect(
      manches.every((m) => (m.donnees as DonneesScene).etapes.length == 4),
      isTrue,
    );
  });

  test('le bercement allonge le calme avec des délais confortables', () {
    const generateur = MonstreGenerateur();
    for (final palier in Palier.values) {
      final debut = generateur.generer(
        _niveau(activiteMonstre, palier, 1),
        Random(4),
      );
      final fin = generateur.generer(
        _niveau(activiteMonstre, palier, 8),
        Random(4),
      );
      expect(
        (fin.first.donnees as DonneesRythme).battements,
        greaterThan((debut.first.donnees as DonneesRythme).battements),
      );
      for (final manche in [...debut, ...fin]) {
        final donnees = manche.donnees as DonneesRythme;
        expect(donnees.mode, ModeRythme.bercement);
        expect(donnees.battements, inInclusiveRange(4, 11));
        expect(donnees.intervalleMs, inInclusiveRange(1100, 1400));
      }
    }
  });

  test('les tours renouvellent les thèmes et gardent une cible unique', () {
    const generateur = ToursGenerateur();
    final cibles = <String>{};
    for (var numero = 1; numero <= 8; numero++) {
      final niveau = _niveau(activiteTours, Palier.a7, numero);
      final manches = generateur.generer(niveau, Random(12));
      cibles.addAll(manches.map((m) => m.bonneOption.concept));
      for (final manche in manches) {
        expect(manche.options, hasLength(niveau.choixMax));
        expect(
          manche.options.map((o) => o.concept).toSet(),
          hasLength(niveau.choixMax),
        );
        expect(manche.clipsConsigne.last, 'lex.${manche.bonneOption.concept}');
      }
    }
    expect(cibles.length, greaterThan(30));
  });
}
