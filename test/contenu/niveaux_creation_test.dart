import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';

final _activites = catalogueActivites.where(
  (a) => a.famille == Famille.creation,
);

Niveau _niveau(Activite activite, Palier palier, int numero) {
  final base = activite.niveaux.firstWhere((n) => n.palier == palier);
  return Niveau(
    palier: palier,
    numero: numero,
    nbItems: base.nbItems,
    choixMax: base.choixMax,
  );
}

List<Manche> _generer(Activite a, Palier p, int n) =>
    (a.source as SourceGenerateur).generateur.generer(
      _niveau(a, p, n),
      Random(7),
    );

String _signature(DonneesMoteur? donnees) => switch (donnees) {
  DonneesAtelier d =>
    '${d.groupes.map((g) => g.options.join(',')).join('/')}|${d.nourritures}',
  DonneesTheatre d => '${d.personnages}|${d.dureeMaxSecondes}',
  DonneesToile d =>
    '${d.palette}|${d.couleurObjectif}|${d.cellulesObjectif}|'
        '${d.taches.map((t) => '${t.x},${t.y},${t.rayon}').join('/')} ',
  DonneesComposer d => '${d.sons}|${d.cases}',
  DonneesRythme d =>
    '${d.battements}|${d.intervalleMs}|${d.sonsParOption}|${d.bonneOption}',
  _ => throw StateError('Données de création inattendues'),
};

void main() {
  test('les huit étapes proposées produisent toutes une partie complète', () {
    for (final activite in _activites) {
      for (final palier in Palier.values) {
        final etapes = activite.etapesPour(palier);
        expect(etapes.length, 8);
        for (final niveau in etapes) {
          final manches = preparerPartie(activite, niveau, Random(23));
          expect(
            manches.length,
            niveau.nbItems,
            reason: '${activite.id}/${palier.id}/${niveau.numero}',
          );
          expect(manches.map((m) => m.id).toSet().length, manches.length);
          expect(niveau.nbItems, lessThanOrEqualTo(activite.nbItemsMaximum));
        }
      }
    }
  });

  test('les sept jeux créatifs proposent de vraies variantes de données', () {
    expect(_activites.length, 7);
    for (final activite in _activites) {
      for (final palier in Palier.values) {
        final signatures = <String>{};
        for (var numero = 1; numero <= 8; numero++) {
          final manches = _generer(activite, palier, numero);
          expect(manches.length, _niveau(activite, palier, numero).nbItems);
          expect(manches.map((m) => m.id).toSet().length, manches.length);
          signatures.add(manches.map((m) => _signature(m.donnees)).join(';'));
        }
        // La peinture conserve volontairement ses trois mélanges primaires.
        expect(
          signatures.length,
          greaterThanOrEqualTo(activite.id == 'peinture' ? 3 : 8),
          reason: '${activite.id}/${palier.id}',
        );
      }
    }
  });

  test('les banques réutilisent des concepts et des sons déjà livrés', () {
    for (final activite in _activites) {
      final clips = activite.clips.map((c) => c.id).toSet();
      for (final palier in Palier.values) {
        for (var numero = 1; numero <= 8; numero++) {
          for (final manche in _generer(activite, palier, numero)) {
            expect(manche.clipsConsigne.every(clips.contains), isTrue);
            final (concepts, sons) = switch (manche.donnees) {
              DonneesAtelier d => (
                [...d.groupes.expand((g) => g.options), ...d.nourritures],
                <String>[],
              ),
              DonneesTheatre d => (d.personnages, <String>[]),
              DonneesToile d => (
                [...d.palette, ...d.melanges.values],
                <String>[],
              ),
              DonneesComposer d => (
                d.sons.keys.toList(),
                d.sons.values.toList(),
              ),
              DonneesRythme d => (
                d.sonsParOption.keys.toList(),
                d.sonsParOption.values.toList(),
              ),
              _ => throw StateError('Données inattendues'),
            };
            for (final deck in Deck.values) {
              expect(concepts.every(lexiquePour(deck).containsKey), isTrue);
            }
            for (final son in sons) {
              expect(File(son).existsSync(), isTrue, reason: son);
            }
          }
        }
      }
    }
  });

  test(
    'les papillons restent dans la moitié gauche avec des taches accessibles',
    () {
      final activite = _activites.firstWhere((a) => a.id == 'papillon');
      for (final palier in Palier.values) {
        for (var n = 1; n <= 8; n++) {
          for (final manche in _generer(activite, palier, n)) {
            final d = manche.donnees as DonneesToile;
            expect(d.miroir, isTrue);
            expect(d.taches.length, 3 + palier.index);
            for (final t in d.taches) {
              expect(t.x - t.rayon, greaterThan(0));
              expect(t.x + t.rayon, lessThan(0.5));
              expect(t.y - t.rayon, greaterThan(0));
              expect(t.y + t.rayon, lessThan(1));
              expect(t.rayon, greaterThanOrEqualTo(0.06));
            }
          }
        }
      }
    },
  );

  test(
    'peinture conserve chaque mélange réalisable sans fournir le résultat',
    () {
      final activite = _activites.firstWhere((a) => a.id == 'peinture');
      for (final palier in Palier.values) {
        for (var n = 1; n <= 8; n++) {
          for (final manche in _generer(activite, palier, n)) {
            final d = manche.donnees as DonneesToile;
            final recette = d.melanges.entries.firstWhere(
              (e) => e.value == d.couleurObjectif,
            );
            expect(recette.key.split('+').every(d.palette.contains), isTrue);
            expect(d.palette.contains(d.couleurObjectif), isFalse);
            expect(d.cellulesObjectif, inInclusiveRange(6, 14));
            if (palier == Palier.a4) expect(d.palette.length, 2);
          }
        }
      }
    },
  );

  test('écoute isole toujours hauteur et volume sur les deux options', () {
    final activite = _activites.firstWhere((a) => a.id == 'hauteur');
    for (final palier in Palier.values) {
      for (var n = 1; n <= 8; n++) {
        for (final manche in _generer(activite, palier, n)) {
          final d = manche.donnees as DonneesRythme;
          expect(manche.options.map((o) => o.id), contains(d.bonneOption));
          final fichiers = d.sonsParOption.values.map((s) => s.split('/').last);
          if (d.sonsParOption.containsKey('fort')) {
            expect(fichiers.map((s) => s.split('_').first).toSet().length, 1);
          } else {
            expect(fichiers.map((s) => s.split('_').last).toSet().length, 1);
          }
        }
      }
    }
  });

  test('la préparation garde des créations courtes et des choix libres', () {
    for (final activite in _activites) {
      for (final palier in Palier.values) {
        for (var numero = 1; numero <= 8; numero++) {
          for (final manche in preparerPartie(
            activite,
            _niveau(activite, palier, numero),
            Random(9),
          )) {
            switch (manche.donnees) {
              case DonneesAtelier d:
                expect(d.groupes.length, 3);
                for (final g in d.groupes) {
                  expect(
                    g.options.length,
                    inInclusiveRange(2, palier == Palier.a4 ? 2 : 4),
                  );
                  expect(g.options.toSet().length, g.options.length);
                }
              case DonneesTheatre d:
                expect(d.personnages.toSet().length, 2);
                expect(d.dureeMaxSecondes, inInclusiveRange(12, 20));
              case DonneesComposer d:
                expect(d.cases, 4);
                expect(d.sons.length, inInclusiveRange(2, 4));
              case DonneesRythme d when d.mode == ModeRythme.pulsation:
                expect(d.intervalleMs, inInclusiveRange(790, 1050));
                expect(d.battements, inInclusiveRange(6, 13));
              default:
                break;
            }
          }
        }
      }
    }
  });
}
