import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/activites/logique/histoire_data.dart';
import 'package:jeux_enfants/core/contenu/activites/logique/intrus_data.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';
import 'package:jeux_enfants/core/contenu/validateur.dart';

void main() {
  final jeux = catalogueActivites
      .where((a) => a.famille == Famille.logique)
      .toList();
  test('les sept jeux de logique couvrent 224 niveaux jouables et uniques', () {
    expect(jeux, hasLength(7));
    for (final jeu in jeux) {
      for (final age in Palier.values) {
        final niveaux = jeu.etapesPour(age);
        expect(
          niveaux.map((n) => n.numero),
          orderedEquals([1, 2, 3, 4, 5, 6, 7, 8]),
        );
        for (final niveau in niveaux) {
          for (var graine = 0; graine < 30; graine++) {
            final manches = preparerPartie(jeu, niveau, Random(graine));
            final contexte =
                '${jeu.id} ${age.id} ${niveau.numero} graine $graine';
            expect(manches, hasLength(niveau.nbItems), reason: contexte);
            expect(
              manches.map((m) => m.id).toSet(),
              hasLength(manches.length),
              reason: contexte,
            );
            for (final m in manches) {
              final d = m.donnees;
              if (d is DonneesCode) {
                expect(codeEstRealisable(d), isTrue, reason: contexte);
                if (age.age < 6) expect(d.maxBlocs, lessThanOrEqualTo(3));
              }
              if (d is DonneesOrdre) {
                expect(d.cases.toSet().length, d.cases.length);
                expect(m.options.map((o) => o.concept), containsAll(d.cases));
                if (jeu.id == 'ordres') {
                  expect(
                    d.cases.length,
                    lessThanOrEqualTo(age == Palier.a4 ? 2 : 3),
                  );
                } else {
                  final modele = banqueHistoires.firstWhere(
                    (h) => h.narrationCle == d.narrationCle,
                  );
                  final debut = modele.cases.indexOf(d.cases.first);
                  expect(
                    d.cases,
                    modele.cases.sublist(debut, debut + d.cases.length),
                  );
                }
              }
              if (d is DonneesScene) {
                final avant = d.etapes.first.visuel!.split(':').last.split('|');
                final apres = d.etapes[1].visuel!.split(':').last.split('|');
                final disparu = d.etapes.last.bonneOption!;
                expect(avant.toSet().difference(apres.toSet()), {disparu});
                expect(d.etapes.last.options, contains(disparu));
                expect(apres.length, avant.length - 1);
              }
              if (jeu.id == 'intrus') {
                final famille = m.clipsConsigne.single.split('.').last;
                final membres = IntrusGenerateur.familles[famille]!;
                expect(membres, isNot(contains(m.bonneOption.concept)));
                expect(
                  m.options
                      .where((o) => o.id != m.bonneOptionId)
                      .map((o) => o.concept),
                  everyElement(isIn(membres)),
                );
              }
            }
          }
        }
      }
    }
  });

  test('le validateur ne rapporte aucun problème dans la famille logique', () {
    final ids = jeux.map((a) => a.id).toSet();
    final problemes = validerContenu(
      grainesParNiveau: 20,
    ).where((p) => ids.any((id) => p.startsWith('Activité $id '))).toList();
    expect(problemes, isEmpty, reason: problemes.join('\n'));
  });

  test('la progression change la mémoire, les gestes et les distracteurs', () {
    for (final age in Palier.values) {
      for (final id in ['chemin', 'histoire', 'manque', 'ordres']) {
        final jeu = jeux.firstWhere((j) => j.id == id);
        final debut = preparerPartie(
          jeu,
          jeu.niveauPour(age, numero: 1)!,
          Random(47),
        );
        final fin = preparerPartie(
          jeu,
          jeu.niveauPour(age, numero: 8)!,
          Random(47),
        );
        if (id == 'chemin') {
          expect(
            (fin.first.donnees as DonneesTrace).largeurRuban,
            lessThan((debut.first.donnees as DonneesTrace).largeurRuban),
          );
        } else if (id == 'histoire') {
          expect(
            (fin.first.donnees as DonneesOrdre).cases.length,
            greaterThanOrEqualTo(
              (debut.first.donnees as DonneesOrdre).cases.length,
            ),
          );
        } else if (id == 'manque') {
          expect(
            (fin.first.donnees as DonneesScene).etapes.first.visuel!
                .split('|')
                .length,
            greaterThan(
              (debut.first.donnees as DonneesScene).etapes.first.visuel!
                  .split('|')
                  .length,
            ),
          );
        } else {
          expect(
            fin.first.options.length,
            greaterThan(debut.first.options.length),
          );
        }
      }
    }
  });
}
