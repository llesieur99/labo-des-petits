import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';

const nombres = [
  'un',
  'deux',
  'trois',
  'quatre',
  'cinq',
  'six',
  'sept',
  'huit',
  'neuf',
  'dix',
];

Activite jeu(String id) => catalogueActivites.firstWhere((a) => a.id == id);
List<Manche> generer(String id, Palier age, int numero, {int graine = 4}) {
  final a = jeu(id);
  final niveau = a.niveauPour(age, numero: numero)!;
  return (a.source as SourceGenerateur).generateur.generer(
    niveau,
    Random(graine),
  );
}

void main() {
  test(
    'les huit jeux de maths fournissent 32 niveaux complets et jouables',
    () {
      final jeux = catalogueActivites.where((a) => a.famille == Famille.maths);
      expect(jeux.length, 8);
      for (final activite in jeux) {
        for (final age in Palier.values) {
          final niveaux = activite.etapesPour(age);
          expect(
            niveaux.map((n) => n.numero),
            orderedEquals(List.generate(8, (i) => i + 1)),
          );
          for (final niveau in niveaux) {
            for (var graine = 0; graine < 20; graine++) {
              final manches = preparerPartie(activite, niveau, Random(graine));
              expect(
                manches.length,
                niveau.nbItems,
                reason: '${activite.id}/$age/${niveau.numero}',
              );
              for (final manche in manches) {
                final d = manche.donnees;
                if (d is DonneesScene) {
                  for (final e in d.etapes.where((e) => e.options.isNotEmpty)) {
                    expect(
                      e.options.length,
                      inInclusiveRange(2, niveau.choixMax),
                    );
                    expect(e.options.toSet().length, e.options.length);
                    expect(e.options, contains(e.bonneOption));
                  }
                } else if (d is DonneesDepot) {
                  expect(d.objets.length, d.emplacements.length);
                  for (final concept in d.objets.toSet()) {
                    expect(
                      d.objets.where((o) => o == concept).length,
                      d.emplacements
                          .where((e) => d.places[e.id]!.contains(concept))
                          .length,
                    );
                  }
                } else if (d is DonneesBalance) {
                  expect(
                    d.reserve.length,
                    greaterThanOrEqualTo(d.minimumParPlateau * 2),
                  );
                  expect(d.minimumParPlateau, inInclusiveRange(1, 7));
                }
              }
            }
          }
        }
      }
    },
  );

  test('le bus raconte de vrais changements et propose leur total exact', () {
    final types = <String>{};
    for (final age in Palier.values) {
      for (var numero = 1; numero <= 8; numero++) {
        for (final m in generer('bus', age, numero)) {
          final d = m.donnees as DonneesScene;
          var total = 0;
          for (final e in d.etapes.where((e) => e.options.isEmpty)) {
            final quantite = int.parse(
              e.narrationCle.substring(e.narrationCle.length - 1),
            );
            final descend = e.narrationCle.contains('descend');
            types.add(e.narrationCle);
            total += descend ? -quantite : quantite;
            expect(total, inInclusiveRange(1, 5));
            expect(e.visuel, 'passagers_$total');
          }
          expect(d.etapes.last.bonneOption, nombres[total - 1]);
        }
      }
    }
    expect(types, contains('consigne.bus.descend2'));
    expect(
      (generer('bus', Palier.a7, 8).first.donnees as DonneesScene)
          .etapes
          .length,
      greaterThan(
        (generer('bus', Palier.a7, 1).first.donnees as DonneesScene)
            .etapes
            .length,
      ),
    );
  });

  test('la grenouille additionne chaque bond sans sortir de la droite', () {
    for (final age in Palier.values) {
      for (var numero = 1; numero <= 8; numero++) {
        for (final m in generer('grenouille', age, numero)) {
          final d = m.donnees as DonneesScene;
          var position = int.parse(d.etapes.first.visuel!.split('_').last);
          for (final e in d.etapes.where(
            (e) => e.narrationCle.startsWith('saut.'),
          )) {
            position += int.parse(e.narrationCle.split('.').last);
            expect(position, inInclusiveRange(1, 10));
            expect(e.visuel, 'grenouille_$position');
          }
          expect(d.etapes.last.bonneOption, nombres[position - 1]);
        }
      }
    }
    expect(
      (generer('grenouille', Palier.a7, 8).first.donnees as DonneesScene).etapes
          .where((e) => e.narrationCle.startsWith('saut.'))
          .length,
      2,
    );
  });

  test('les perles avancées contiennent des règles plus riches que AB', () {
    final simples = generer('perles', Palier.a4, 1);
    for (final m in simples) {
      final d = m.donnees as DonneesScene;
      final suite = d.etapes.first.visuel!.substring(7).split('|');
      expect(suite.toSet().length, 2);
      for (var i = 2; i < suite.length; i++) {
        expect(suite[i], suite[i - 2]);
      }
    }
    final avance = generer('perles', Palier.a7, 8);
    final maximum = avance
        .map(
          (m) => (m.donnees as DonneesScene).etapes.first.visuel!
              .substring(7)
              .split('|')
              .toSet()
              .length,
        )
        .reduce(max);
    expect(maximum, 4);
    for (final m in avance) {
      final d = m.donnees as DonneesScene;
      expect(d.etapes.last.visuel!.split('|').last, d.etapes.last.bonneOption);
    }
  });

  test('les formes et la balance progressent aussi dans leur contenu', () {
    final debut = generer('formes', Palier.a4, 1).first.donnees as DonneesDepot;
    final fin = generer('formes', Palier.a7, 8).first.donnees as DonneesDepot;
    expect(debut.emplacements.length, 2);
    expect(fin.emplacements.length, 6);
    expect(fin.objets.toSet().length, 4);
    final balanceDebut =
        generer('balance', Palier.a4, 1).first.donnees as DonneesBalance;
    final balanceFin =
        generer('balance', Palier.a7, 8).first.donnees as DonneesBalance;
    expect(
      balanceFin.minimumParPlateau,
      greaterThan(balanceDebut.minimumParPlateau),
    );
    expect(
      balanceFin.reserve.toSet().length,
      greaterThan(balanceDebut.reserve.toSet().length),
    );
  });

  test('les comparaisons utilisent des voisins et alternent plus et moins', () {
    final questions = <String>{};
    for (final m in generer('plusmoins', Palier.a7, 8)) {
      final d = m.donnees as DonneesScene;
      final tas = d.etapes.first.visuel!.substring(7).split('//');
      final gauche = tas[0].split('|').length;
      final droite = tas[1].split('|').length;
      expect((gauche - droite).abs(), 1);
      final e = d.etapes.last;
      questions.add(e.narrationCle);
      final plus = e.narrationCle.endsWith('.plus');
      expect(e.bonneOption, (plus == (gauche > droite)) ? 'gauche' : 'droite');
    }
    expect(questions.length, 2);
  });

  test(
    'gâteau et heure enchaînent deux problèmes uniquement aux niveaux avancés',
    () {
      for (final id in ['gateau', 'heure']) {
        for (final numero in [1, 8]) {
          final attendus = numero == 1 ? 1 : 2;
          for (final m in generer(id, Palier.a7, numero)) {
            final d = m.donnees as DonneesScene;
            expect(
              d.etapes.where((e) => e.options.isNotEmpty).length,
              attendus,
            );
            for (final e in d.etapes.where((e) => e.options.isNotEmpty)) {
              expect(
                e.montrerAvant,
                isFalse,
                reason: 'le résultat du gâteau reste caché avant le choix',
              );
              if (id == 'gateau') {
                expect(
                  e.bonneOption,
                  e.narrationCle.endsWith('.deux') ? 'deux' : 'quatre',
                );
              }
            }
          }
        }
      }
    },
  );
}
