import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/activites/autonomie/couper_data.dart';
import 'package:jeux_enfants/core/contenu/activites/autonomie/mains_data.dart';
import 'package:jeux_enfants/core/contenu/activites/autonomie/ranger_data.dart';
import 'package:jeux_enfants/core/contenu/activites/autonomie/recette_data.dart';
import 'package:jeux_enfants/core/contenu/activites/autonomie/sac_data.dart';
import 'package:jeux_enfants/core/contenu/activites/autonomie/table_data.dart';
import 'package:jeux_enfants/core/contenu/activites/autonomie/traverser_data.dart';
import 'package:jeux_enfants/core/contenu/lettres/chemins_lettres.dart';
import 'package:jeux_enfants/core/contenu/lexique/lexique_qc.dart';
import 'package:jeux_enfants/core/contenu/lexique/lexique_fr.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';

const jeux = [
  activiteCouper,
  activiteMains,
  activiteRanger,
  activiteRecette,
  activiteSac,
  activiteTable,
  activiteTraverser,
];

List<Manche> generer(
  Activite jeu,
  Palier palier,
  int numero, [
  int seed = 47,
]) =>
    preparerPartie(jeu, jeu.niveauPour(palier, numero: numero)!, Random(seed));

void main() {
  test(
    'les sept jeux servent les 32 niveaux sans concept ni consigne absent',
    () {
      for (final jeu in jeux) {
        final clips = {
          for (final c in jeu.clips) c.id,
          for (final c in lexiqueQc.keys) 'lex.$c',
        };
        for (final age in Palier.values) {
          expect(jeu.etapesPour(age), hasLength(8));
          for (final niveau in jeu.etapesPour(age)) {
            for (var seed = 0; seed < 12; seed++) {
              final manches = preparerPartie(jeu, niveau, Random(seed));
              expect(manches, hasLength(niveau.nbItems));
              expect(
                manches.map((m) => m.id).toSet(),
                hasLength(manches.length),
              );
              for (final m in manches) {
                expect(m.clipsConsigne.every(clips.contains), isTrue);
                for (final o in m.options) {
                  expect(lexiqueQc.containsKey(o.concept), isTrue);
                  expect(lexiqueFr.containsKey(o.concept), isTrue);
                }
                final d = m.donnees;
                if (d is DonneesOrdre) {
                  expect(m.options.map((o) => o.concept), containsAll(d.cases));
                  expect(m.options.length, lessThanOrEqualTo(6));
                  expect(clips, contains(d.narrationCle));
                }
                if (d is DonneesDepot) {
                  for (final objet in d.objets) {
                    expect(
                      d.places.values.where((p) => p.contains(objet)),
                      hasLength(d.modeBacs ? 1 : d.emplacements.length),
                    );
                  }
                }
              }
            }
          }
        }
      }
    },
  );

  test('les huit étapes des rituels changent situation ou discrimination', () {
    for (final jeu in [activiteMains, activiteRecette, activiteTraverser]) {
      for (final age in Palier.values) {
        final signatures = <String>{};
        for (var numero = 1; numero <= 8; numero++) {
          final m = generer(jeu, age, numero).first;
          signatures.add('${m.clipsConsigne.first}:${m.options.length}');
        }
        expect(signatures, hasLength(8), reason: '${jeu.id} ${age.id}');
      }
    }
  });

  test('le lavage ne supprime jamais savon, friction ou rinçage', () {
    for (final age in Palier.values) {
      for (var numero = 1; numero <= 8; numero++) {
        for (final m in generer(activiteMains, age, numero)) {
          expect((m.donnees as DonneesOrdre).cases, [
            'robinet',
            'savon',
            'frotter',
            'eau',
          ]);
        }
      }
    }
    final narration = clipsMains
        .firstWhere((c) => c.id == 'mains.comptine')
        .texte;
    expect(narration, contains('vingt secondes'));
    expect(narration, contains('sèche'));
  });

  test('la traversée reste complète et toujours accompagnée', () {
    for (final age in Palier.values) {
      for (var numero = 1; numero <= 8; numero++) {
        for (final m in generer(activiteTraverser, age, numero)) {
          expect((m.donnees as DonneesOrdre).cases, [
            'panneau_stop',
            'regarder',
            'ecouter',
            'marcher',
          ]);
          final consigne = clipsTraverser.firstWhere(
            (c) => c.id == m.clipsConsigne.first,
          );
          expect(consigne.texte, contains('adulte'));
        }
      }
    }
  });

  test(
    'la recette réserve le couteau à l’adulte et enseigne la demande d’aide',
    () {
      final vus = <String>{};
      for (var numero = 1; numero <= 8; numero++) {
        for (final m in generer(activiteRecette, Palier.a4, numero)) {
          final consigne = clipsRecette.firstWhere(
            (c) => c.id == m.clipsConsigne.first,
          );
          expect(consigne.texte, contains('adulte'));
          final sequence = (m.donnees as DonneesOrdre).cases;
          expect(sequence.first, 'eau');
          expect(sequence.last, 'assiette');
          if (numero >= 7) {
            expect(
              sequence.indexOf('aide'),
              lessThan(sequence.indexOf('couteau')),
            );
          }
          vus.add(consigne.id);
        }
      }
      expect(
        vus,
        containsAll([
          'consigne.recette.pomme',
          'consigne.recette.fraise',
          'consigne.recette.banane',
          'consigne.recette.aide',
        ]),
      );
    },
  );

  test('découper élargit les formes et affine progressivement le geste', () {
    for (final age in Palier.values) {
      final debut =
          generer(activiteCouper, age, 1).first.donnees as DonneesTrace;
      final fin = generer(activiteCouper, age, 8).first.donnees as DonneesTrace;
      expect(fin.largeurRuban, lessThan(debut.largeurRuban));
      expect(fin.largeurRuban, greaterThanOrEqualTo(0.14));
      final chemins = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        for (final m in generer(activiteCouper, age, 8, seed)) {
          final trace = m.donnees as DonneesTrace;
          expect(cheminsTrace, contains(trace.cheminId));
          expect(trace.departOblige, isTrue);
          chemins.add(trace.cheminId);
        }
      }
      expect(chemins.length, greaterThanOrEqualTo(4));
    }
  });

  test(
    'ranger augmente les objets puis introduit les trois familles à six ans',
    () {
      final debut =
          generer(activiteRanger, Palier.a6, 1).first.donnees as DonneesDepot;
      final fin =
          generer(activiteRanger, Palier.a6, 8).first.donnees as DonneesDepot;
      expect(debut.emplacements, hasLength(2));
      expect(fin.emplacements, hasLength(3));
      expect(fin.objets.length, greaterThan(debut.objets.length));
      for (final m in generer(activiteRanger, Palier.a4, 8)) {
        expect((m.donnees as DonneesDepot).emplacements, hasLength(2));
      }
      expect(
        RangerGenerateur.familles['chaussette']!.length,
        greaterThanOrEqualTo(10),
      );
    },
  );

  test('la liste parlée du sac est exactement la liste à emporter', () {
    final vus = <String>{};
    var objetScolaireNonDemande = false;
    for (var seed = 0; seed < 30; seed++) {
      for (final m in generer(activiteSac, Palier.a7, 8, seed)) {
        final depot = m.donnees as DonneesDepot;
        expect(
          m.clipsConsigne
              .where((c) => c.startsWith('lex.'))
              .map((c) => c.substring(4))
              .toSet(),
          depot.places['sac']!.toSet(),
        );
        expect(
          depot.places['sac']!.toSet().intersection(
            depot.places['maison']!.toSet(),
          ),
          isEmpty,
        );
        vus.addAll(depot.places['sac']!);
        objetScolaireNonDemande |= depot.places['maison']!.any(
          [
            'lunch',
            'souliers',
            'doudou',
            'pomme',
            'livre',
            'eau',
            'casquette',
            'mitaines',
            'chaussette',
            'manteau',
          ].contains,
        );
      }
    }
    expect(vus, hasLength(10));
    expect(objetScolaireNonDemande, isTrue);
    final debut =
        generer(activiteSac, Palier.a4, 1).first.donnees as DonneesDepot;
    expect(debut.objets, hasLength(2));
  });

  test(
    'la table varie les objets et invités tout en gardant un objet par ami',
    () {
      final objets = <String>{};
      final invites = <int>{};
      for (var seed = 0; seed < 12; seed++) {
        for (final m in generer(activiteTable, Palier.a7, 8, seed)) {
          final d = m.donnees as DonneesDepot;
          expect(d.objets, hasLength(d.emplacements.length));
          expect(d.places.values.every((v) => v.length == 1), isTrue);
          expect(d.objets.toSet(), hasLength(1));
          objets.addAll(d.objets);
          invites.add(d.emplacements.length);
        }
      }
      expect(objets, {'assiette', 'verre', 'fourchette'});
      expect(invites.length, greaterThanOrEqualTo(3));
    },
  );
}
