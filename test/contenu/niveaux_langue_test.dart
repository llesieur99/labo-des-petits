import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/bouche_sons_data.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/lettre_data.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/mot_cache_data.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/phrase_data.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/rimes_data.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/syllabes_data.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';
import 'package:jeux_enfants/core/contenu/validateur.dart';

const activites = [
  activiteBoucheSons,
  activiteSyllabes,
  activiteRimes,
  activitePhrase,
  activiteMotCache,
  activiteLettre,
];

Niveau variante(Activite activite, Palier palier, int numero) {
  final base = activite.niveauPour(palier)!;
  return Niveau(
    palier: palier,
    numero: numero,
    nbItems: base.nbItems,
    choixMax: base.choixMax,
    afficherMots: base.afficherMots,
  );
}

void main() {
  test('les six jeux passent tous les invariants du validateur', () {
    final problemes = validerContenu(grainesParNiveau: 20)
        .where((p) => activites.any((a) => p.startsWith('Activité ${a.id} ')))
        .toList();
    expect(problemes, isEmpty, reason: problemes.join('\n'));
  });

  test('les six jeux livrent leurs manches sans doublon aux huit niveaux', () {
    for (final activite in activites) {
      for (final palier in Palier.values) {
        for (var numero = 1; numero <= 8; numero++) {
          final niveau = activite.niveauPour(palier, numero: numero)!;
          for (var graine = 0; graine < 30; graine++) {
            final manches = preparerPartie(activite, niveau, Random(graine));
            expect(
              manches,
              hasLength(niveau.nbItems),
              reason: '${activite.id} $palier $numero',
            );
            expect(manches.map((m) => m.id).toSet(), hasLength(manches.length));
          }
        }
      }
    }
  });

  test('chaque contraste de rimes garde exactement une bonne réponse', () {
    final rimes = {for (final mot in banqueRimes) mot.concept: mot.rime};
    for (var numero = 1; numero <= 8; numero++) {
      for (var graine = 0; graine < 40; graine++) {
        for (final manche in const RimesGenerateur().generer(
          variante(activiteRimes, Palier.a7, numero),
          Random(graine),
        )) {
          final cible = manche.reperes.single;
          expect(
            manche.options.where((o) => rimes[o.concept] == rimes[cible]),
            hasLength(1),
          );
          expect(manche.options.map((o) => o.concept), isNot(contains(cible)));
        }
      }
    }
  });

  test(
    'les sons voisins restent des leurres et les cibles ne se répètent pas',
    () {
      for (var numero = 1; numero <= 8; numero++) {
        for (var graine = 0; graine < 40; graine++) {
          final manches = const MotCacheGenerateur().generer(
            variante(activiteMotCache, Palier.a7, numero),
            Random(graine),
          );
          expect(
            manches.map((m) => m.bonneOptionId).toSet(),
            hasLength(manches.length),
          );
          for (final manche in manches) {
            final son = manche.clipsConsigne.last.split('.').last;
            expect(manche.options, hasLength(4));
            expect(
              manche.options.where((o) => o.concept.startsWith(son)),
              hasLength(1),
            );
          }
        }
      }
    },
  );

  test('les syllabes orales vont de un à trois sauts sans e muet inventé', () {
    final debut = const SyllabesGenerateur().generer(
      variante(activiteSyllabes, Palier.a4, 1),
      Random(7),
    );
    final fin = const SyllabesGenerateur().generer(
      variante(activiteSyllabes, Palier.a7, 8),
      Random(7),
    );
    expect(
      debut.every(
        (m) => (m.donnees as DonneesRythme).syllabesClips.length <= 2,
      ),
      isTrue,
    );
    expect(
      fin.any((m) => (m.donnees as DonneesRythme).syllabesClips.length == 3),
      isTrue,
    );
    for (final manches in [debut, fin]) {
      expect(manches.any((m) => m.id == 'syllabes.banane'), isFalse);
    }
  });

  test('les tracés gardent un ruban accueillant et deviennent plus précis', () {
    for (final palier in Palier.values) {
      final debut = const LettreGenerateur().generer(
        variante(activiteLettre, palier, 1),
        Random(3),
      );
      final fin = const LettreGenerateur().generer(
        variante(activiteLettre, palier, 8),
        Random(3),
      );
      final premier = debut.first.donnees as DonneesTrace;
      final dernier = fin.first.donnees as DonneesTrace;
      expect(dernier.largeurRuban, lessThan(premier.largeurRuban));
      expect(dernier.largeurRuban, greaterThanOrEqualTo(.16));
      expect(dernier.departOblige, isTrue);
      expect(
        debut.map((m) => m.id).toSet(),
        isNot(fin.map((m) => m.id).toSet()),
      );
    }
  });

  test(
    'les phrases progressent vers quatre cases et utilisent des clips existants',
    () {
      final clips = {
        for (final c in clipsPhrase) c.id,
        for (final concept in lexiquePour(Deck.qc).keys) 'lex.$concept',
      };
      final ids = <String>{};
      for (var numero = 1; numero <= 8; numero++) {
        for (final palier in Palier.values) {
          final manches = const PhraseGenerateur().generer(
            variante(activitePhrase, palier, numero),
            Random(0),
          );
          for (final manche in manches) {
            ids.add(manche.id);
            expect(clips.containsAll(manche.clipsConsigne), isTrue);
            final depot = manche.donnees as DonneesDepot;
            expect(
              depot.places.values.expand((o) => o).toSet(),
              depot.objets.toSet(),
            );
            expect(depot.emplacements, hasLength(depot.objets.length));
            if (palier == Palier.a4 && numero < 5) {
              expect(depot.objets, hasLength(3));
            }
          }
          if (palier.index >= 2 || numero >= 5) {
            expect(
              manches.any(
                (m) => (m.donnees as DonneesDepot).objets.length == 4,
              ),
              isTrue,
            );
          }
        }
      }
      expect(ids, hasLength(17));
      expect(
        ids,
        containsAll([
          'phrase.chat',
          'phrase.lapin',
          'phrase.vache',
          'phrase.poussin',
          'phrase.souris',
        ]),
      );
    },
  );

  test('la bouche découvre progressivement les six sons enregistrés', () {
    final debut = const BoucheSonsGenerateur().generer(
      variante(activiteBoucheSons, Palier.a4, 1),
      Random(0),
    );
    final sons = <String>{};
    for (var graine = 0; graine < 20; graine++) {
      sons.addAll(
        const BoucheSonsGenerateur()
            .generer(variante(activiteBoucheSons, Palier.a4, 8), Random(graine))
            .map((m) => (m.donnees as DonneesRythme).sonCle!),
      );
    }
    expect(debut.map((m) => (m.donnees as DonneesRythme).sonCle).toSet(), {
      'son.sss',
      'son.ou',
    });
    expect(sons, hasLength(5));
  });
}
