import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 26 — Regarde par la fenêtre (moteur M4, décor 'fenetre').
///
/// L'enfant dit le temps qu'il VOIT dans la fenêtre dessinée : soleil,
/// pluie, neige, vent, nuage. L'app ne prétend jamais connaître la météo
/// dehors — c'est la fenêtre du jeu, et l'enfant qui nomme.
class FenetreGenerateur extends GenerateurManches {
  const FenetreGenerateur();

  /// (visuel de la fenêtre, concept du temps à toucher).
  static const _temps = [
    ('temps_soleil', 'soleil'),
    ('temps_pluie', 'pluie'),
    ('temps_neige', 'neige'),
    ('temps_vent', 'vent'),
    ('temps_nuage', 'nuage'),
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final ordre = List.of(_temps)..shuffle(alea);
    // Une seule observation au début ; les derniers niveaux suivent deux
    // ou trois changements réels, sans inventer de nouveaux états visuels.
    final longueur = niveau.numero <= 3
        ? 1
        : (niveau.numero <= 6 || niveau.palier == Palier.a4 ? 2 : 3);
    final manches = <Manche>[];
    for (var depart = 0; depart < ordre.length; depart++) {
      for (final sens in longueur == 1 ? [1] : [1, -1]) {
        final etapes = <EtapeScene>[];
        final concepts = <String>[];
        for (var j = 0; j < longueur; j++) {
          final pas = (sens * j) % ordre.length;
          final (visuel, concept) = ordre[(depart + pas) % ordre.length];
          concepts.add(concept);
          final autres =
              ordre.map((t) => t.$2).where((c) => c != concept).toList()
                ..shuffle(alea);
          final options = [concept, ...autres.take(niveau.choixMax - 1)]
            ..shuffle(alea);
          etapes.addAll([
            EtapeScene(narrationCle: 'consigne.fenetre.e1', visuel: visuel),
            EtapeScene(
              narrationCle: 'consigne.fenetre.e2',
              options: options,
              bonneOption: concept,
              visuel: visuel,
              montrerAvant: true,
            ),
          ]);
        }
        manches.add(
          Manche(
            id: 'fenetre.${concepts.join('.')}',
            clipsConsigne: const ['consigne.fenetre.e1'],
            donnees: DonneesScene(decor: 'fenetre', etapes: etapes),
          ),
        );
      }
    }
    manches.shuffle(alea);
    return manches;
  }
}

const clipsFenetre = <ClipConsigne>[
  ClipConsigne('act.fenetre.titre', 'Regarde par la fenêtre'),
  ClipConsigne('consigne.fenetre.e1', 'Regarde bien par la fenêtre…'),
  ClipConsigne(
    'consigne.fenetre.e2',
    'Quel temps fait-il dans la fenêtre ? Touche la bonne image !',
  ),
];

const activiteFenetre = Activite(
  id: 'fenetre',
  famille: Famille.monde,
  moteur: Moteur.scene,
  sensNaturel: Sens.paysage,
  titreCle: 'act.fenetre.titre',
  illustration: 'act-fenetre.svg',
  source: SourceGenerateur(FenetreGenerateur()),
  clips: clipsFenetre,
  nbItemsMaximum: 5,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 5, choixMax: 3),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 5,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
