import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/parent/fiches_activites.dart';
import 'package:jeux_enfants/core/progression/adaptation.dart';
import 'package:jeux_enfants/core/progression/modele.dart';

void main() {
  test('les 48 activités ont une fiche parent et huit étapes par âge', () {
    expect(
      fichesActivites.keys.toSet(),
      catalogueActivites.map((a) => a.id).toSet(),
    );
    for (final activite in catalogueActivites) {
      final fiche = fichesActivites[activite.id]!;
      expect(fiche.objectif, isNotEmpty);
      expect(fiche.commentJouer, isNotEmpty);
      expect(fiche.accompagner, isNotEmpty);
      for (final palier in Palier.values) {
        final etapes = activite.etapesPour(palier);
        expect(etapes.map((e) => e.numero), [1, 2, 3, 4, 5, 6, 7, 8]);
        expect(etapes.first.nbItems, lessThanOrEqualTo(etapes.last.nbItems));
        expect(etapes.first.choixMax, lessThanOrEqualTo(etapes.last.choixMax));
        expect(activite.niveauPour(palier, numero: 2)!.numero, 2);
        expect(activite.niveauPour(palier, numero: 8)!.numero, 8);
        expect(
          etapes[2].nbItems,
          activite
              .niveauPour(palier)!
              .nbItems
              .clamp(1, activite.nbItemsMaximum),
        );
        expect(etapes.last.aides, isEmpty);
      }
    }
  });

  test(
    'chaque montée demande deux nouvelles parties fortes, sans perdre les acquis',
    () {
      var etat = AdaptationDouce.etatInitial(
        profilId: 1,
        activiteId: 'rimes',
        palier: Palier.a4,
      );
      const parfait = ResumePartie(items: 4, reussisDuPremierCoup: 4);
      for (var partie = 1; partie <= 5; partie++) {
        etat = AdaptationDouce.apresPartie(etat, parfait, nbNiveaux: 3);
        expect(etat.niveau, partie < 2 ? 1 : (partie < 4 ? 2 : 3));
        expect(etat.partiesJouees, partie);
        expect(etat.meilleureEtoile, 3);
      }
    },
  );
}
