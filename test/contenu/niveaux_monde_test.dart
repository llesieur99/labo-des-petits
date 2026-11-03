import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';

void main() {
  final jeux = catalogueActivites
      .where((a) => a.famille == Famille.monde)
      .toList();
  Activite jeu(String id) => jeux.firstWhere((a) => a.id == id);
  int questions(DonneesScene d) =>
      d.etapes.where((e) => e.options.isNotEmpty).length;

  test(
    'les neuf jeux monde livrent leurs 32 niveaux sans manches dupliquées',
    () {
      expect(jeux, hasLength(9));
      for (final a in jeux) {
        for (final p in Palier.values) {
          expect(
            a.etapesPour(p).map((n) => n.numero),
            orderedEquals([1, 2, 3, 4, 5, 6, 7, 8]),
          );
          for (final n in a.etapesPour(p)) {
            for (var seed = 0; seed < 20; seed++) {
              final manches = preparerPartie(a, n, Random(seed));
              final ou = '${a.id}/${p.id}/${n.numero}/$seed';
              expect(manches, hasLength(n.nbItems), reason: ou);
              expect(
                manches.map((m) => m.id).toSet(),
                hasLength(manches.length),
                reason: ou,
              );
              for (final m in manches) {
                switch (m.donnees) {
                  case DonneesScene d:
                    for (final e in d.etapes.where(
                      (e) => e.options.isNotEmpty,
                    )) {
                      expect(e.options, contains(e.bonneOption), reason: ou);
                      expect(
                        e.options.toSet(),
                        hasLength(e.options.length),
                        reason: ou,
                      );
                    }
                  case DonneesDepot d:
                    for (final objet in d.objets) {
                      expect(
                        d.places.values.where((v) => v.contains(objet)),
                        hasLength(1),
                        reason: ou,
                      );
                    }
                  default:
                    expect(
                      m.options.any((o) => o.id == m.bonneOptionId),
                      isTrue,
                      reason: ou,
                    );
                }
              }
            }
          }
        }
      }
    },
  );

  test('météo et positions passent de une à trois observations réelles', () {
    for (final id in ['fenetre', 'spatial']) {
      final a = jeu(id);
      for (final numero in [1, 5, 8]) {
        final n = a.niveauPour(Palier.a7, numero: numero)!;
        for (final m in preparerPartie(a, n, Random(47))) {
          final d = m.donnees as DonneesScene;
          expect(
            questions(d),
            numero == 1
                ? 1
                : numero == 5
                ? 2
                : 3,
          );
          expect(
            d.etapes
                .where((e) => e.options.isNotEmpty)
                .map((e) => e.bonneOption)
                .toSet(),
            hasLength(questions(d)),
          );
        }
      }
    }
  });

  test(
    'ombres conserve le côté opposé avec neuf silhouettes et une lampe mobile',
    () {
      final a = jeu('ombres');
      final n = a.niveauPour(Palier.a7, numero: 8)!;
      final banque = (a.source as SourceGenerateur).generateur.generer(
        n,
        Random(47),
      );
      final objets = <String>{};
      for (final m in banque) {
        final d = m.donnees as DonneesScene;
        expect(questions(d), 2);
        for (final e in d.etapes.where((e) => e.options.isNotEmpty)) {
          objets.add(e.visuel!.split(':').last);
          expect(
            e.bonneOption,
            e.visuel!.startsWith('lampe_gauche:') ? 'droite' : 'gauche',
          );
        }
      }
      expect(objets.length, greaterThanOrEqualTo(9));
    },
  );

  test(
    'flotte compare deux résultats opposés sans confondre couleur et fruit',
    () {
      final a = jeu('flotte');
      final n = a.niveauPour(Palier.a7, numero: 8)!;
      for (final m in preparerPartie(a, n, Random(47))) {
        final d = m.donnees as DonneesScene;
        final predictions = d.etapes
            .where((e) => e.options.isNotEmpty)
            .toList();
        expect(predictions, hasLength(2));
        expect(predictions.map((e) => e.bonneOption).toSet(), {'haut', 'bas'});
        expect(d.etapes.any((e) => e.visuel!.endsWith(':orange')), isFalse);
        expect(predictions.map((e) => e.visuel).toSet(), hasLength(2));
      }
    },
  );

  test('les histoires avancées gardent les épisodes dans leur chronologie', () {
    for (final id in ['graine', 'journuit']) {
      final a = jeu(id);
      final n = a.niveauPour(Palier.a7, numero: 8)!;
      for (final m in preparerPartie(a, n, Random(47))) {
        final d = m.donnees as DonneesScene;
        expect(questions(d), greaterThanOrEqualTo(2));
        final numeros = d.etapes
            .where((e) => e.options.isNotEmpty)
            .map((e) => int.parse(e.narrationCle.split('.').last.substring(1)))
            .toList();
        expect(numeros, orderedEquals(List.of(numeros)..sort()));
        if (id == 'journuit') expect(numeros, isNot(contains(3)));
      }
    }
  });

  test(
    'habitats avancés proposent trois groupes et aussi forêt contre maison',
    () {
      final a = jeu('petit');
      for (final m in preparerPartie(
        a,
        a.niveauPour(Palier.a7, numero: 8)!,
        Random(47),
      )) {
        expect((m.donnees as DonneesDepot).emplacements, hasLength(3));
      }
      final vus = <Set<String>>[];
      for (var seed = 0; seed < 20; seed++) {
        for (final m in preparerPartie(
          a,
          a.niveauPour(Palier.a5, numero: 5)!,
          Random(seed),
        )) {
          vus.add(
            (m.donnees as DonneesDepot).emplacements.map((e) => e.id).toSet(),
          );
        }
      }
      expect(
        vus.any(
          (s) =>
              s.contains('sapin') && s.contains('maison') && !s.contains('eau'),
        ),
        isTrue,
      );
    },
  );

  test('les vêtements avancés varient la taille des deux groupes', () {
    final a = jeu('habiller');
    final tailles = <int>{};
    var asymetrique = false;
    for (var seed = 0; seed < 20; seed++) {
      for (final m in preparerPartie(
        a,
        a.niveauPour(Palier.a7, numero: 8)!,
        Random(seed),
      )) {
        final d = m.donnees as DonneesDepot;
        final hiver = d.objets
            .where((o) => d.places['neige']!.contains(o))
            .length;
        final ete = d.objets
            .where((o) => d.places['soleil']!.contains(o))
            .length;
        expect(hiver, greaterThan(0));
        expect(ete, greaterThan(0));
        tailles.add(d.objets.length);
        asymetrique |= hiver != ete;
      }
    }
    expect(tailles.length, greaterThanOrEqualTo(4));
    expect(asymetrique, isTrue);
  });

  test('les sens varient les aliments et couvrent cinq sens dès cinq ans', () {
    final a = jeu('sens');
    final aliments = <String>{};
    for (var seed = 0; seed < 30; seed++) {
      final manches = preparerPartie(
        a,
        a.niveauPour(Palier.a7, numero: 8)!,
        Random(seed),
      );
      expect(
        manches.map((m) => m.id.split('.')[1]).toSet(),
        containsAll(['cri', 'texture', 'vue', 'odorat', 'gout']),
      );
      aliments.addAll(
        manches
            .where((m) => m.id.startsWith('sens.gout.'))
            .map((m) => m.bonneOptionId!),
      );
    }
    expect(aliments.length, greaterThanOrEqualTo(7));
  });
}
