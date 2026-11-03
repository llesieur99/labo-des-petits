import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';

void main() {
  Activite jeu(String id) => catalogueActivites.firstWhere((a) => a.id == id);

  test(
    'les 48 jeux ont une partie non vide pour chaque âge et chaque étape',
    () {
      expect(catalogueActivites, hasLength(48));
      for (final a in catalogueActivites) {
        for (final p in Palier.values) {
          for (final n in a.etapesPour(p)) {
            final manches = preparerPartie(a, n, Random(47));
            expect(manches, isNotEmpty, reason: '${a.id} ${p.id} ${n.numero}');
            expect(manches.length, lessThanOrEqualTo(n.nbItems));
            expect(manches.map((m) => m.id).toSet(), hasLength(manches.length));
            for (final m in manches) {
              if (a.moteur == Moteur.tapPick) {
                expect(m.options.any((o) => o.id == m.bonneOptionId), isTrue);
                expect(
                  m.options.length,
                  lessThanOrEqualTo(max(n.choixMax, a.choixMinimum)),
                );
              }
            }
          }
        }
      }
    },
  );

  test(
    'les scènes de Milo vues récemment passent après les scénarios nouveaux',
    () {
      final a = jeu('milo');
      final n = a.niveauPour(Palier.a4, numero: 1)!;
      final premiere = preparerPartie(a, n, Random(47));
      final suivante = preparerPartie(
        a,
        n,
        Random(47),
        manchesRecentes: premiere.map((m) => m.id).toSet(),
      );
      expect(
        suivante
            .map((m) => m.id)
            .toSet()
            .intersection(premiere.map((m) => m.id).toSet()),
        isEmpty,
      );
      final banque = (a.source as SourceGenerateur).generateur.generer(n, Random(47));
      expect(banque.length, greaterThan(n.nbItems));
      expect(banque.map((m) => m.id).toSet(), hasLength(banque.length));
      expect(
        (banque.first.donnees as DonneesScene).etapes[1].options,
        hasLength(4),
      );
    },
  );

  test('le mélange renouvelle les situations de Milo', () {
    final a = jeu('milo');
    final vus = <String>{};
    for (var seed = 0; seed < 30; seed++) {
      vus.addAll(
        preparerPartie(
          a,
          a.niveauPour(Palier.a4, numero: 1)!,
          Random(seed),
        ).map((m) => m.id),
      );
    }
    expect(vus.length, greaterThanOrEqualTo(5));
  });

  test('Flotte montre son objet avant la première réponse', () {
    final a = jeu('flotte');
    for (final m in preparerPartie(a, a.niveauPour(Palier.a4)!, Random(47))) {
      final d = m.donnees as DonneesScene;
      expect(d.visuelInitial, isNotEmpty);
      expect(d.visuelInitial, d.etapes.first.visuel);
    }
  });

  test(
    'la mémoire donne un temps d’observation réel, plus long en découverte',
    () {
      final a = jeu('manque');
      for (final numero in [1, 3]) {
        final d =
            preparerPartie(
                  a,
                  a.niveauPour(Palier.a4, numero: numero)!,
                  Random(47),
                ).first.donnees
                as DonneesScene;
        expect(d.etapes.first.montrerAvant, isTrue);
        expect(d.etapes.first.observationMs, numero == 1 ? 4500 : 3000);
      }
    },
  );

  test('Milo garde toutes les émotions acceptables dans ses choix', () {
    final a = jeu('milo');
    for (final m in preparerPartie(a, a.niveauPour(Palier.a7)!, Random(47))) {
      final e = (m.donnees as DonneesScene).etapes[1];
      for (final autre in e.autresBonnesOptions) {
        expect(e.accepte(autre), isTrue);
        expect(e.options, contains(autre));
      }
    }
  });

  test(
    'à partir de cinq ans les cinq sens apparaissent dans une partie complète',
    () {
      final a = jeu('sens');
      for (var seed = 0; seed < 30; seed++) {
        final manches = preparerPartie(
          a,
          a.niveauPour(Palier.a5, numero: 3)!,
          Random(seed),
        );
        expect(
          manches.map((m) => m.id.split('.')[1]).toSet(),
          containsAll(['cri', 'texture', 'vue', 'odorat', 'gout']),
        );
      }
    },
  );

  test(
    'chaque traversée commence par arrêter, regarder, écouter, traverser',
    () {
      final a = jeu('traverser');
      for (final m in preparerPartie(a, a.niveauPour(Palier.a7)!, Random(47))) {
        final d = m.donnees as DonneesOrdre;
        expect(d.cases, ['panneau_stop', 'regarder', 'ecouter', 'marcher']);
      }
    },
  );
}
