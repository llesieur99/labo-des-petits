import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 31 — Devant, derrière, à côté (moteur M4, décor 'maison').
///
/// Le chat se place autour de la maison ; l'enfant touche l'image qui dit
/// où il est. Le vocabulaire spatial se joue, il ne s'affiche pas en liste.
class SpatialGenerateur extends GenerateurManches {
  const SpatialGenerateur();

  static const positions = ['devant', 'derriere', 'acote', 'dans'];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final ordre = List.of(positions)..shuffle(alea);
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
          final concept = ordre[(depart + pas) % ordre.length];
          final visuel = 'chat_$concept';
          concepts.add(concept);
          final autres = ordre.where((c) => c != concept).toList()
            ..shuffle(alea);
          final options = [concept, ...autres.take(niveau.choixMax - 1)]
            ..shuffle(alea);
          etapes.addAll([
            EtapeScene(narrationCle: 'consigne.spatial.e1', visuel: visuel),
            EtapeScene(
              narrationCle: 'consigne.spatial.e2',
              options: options,
              bonneOption: concept,
              visuel: visuel,
              montrerAvant: true,
            ),
          ]);
        }
        manches.add(
          Manche(
            id: 'spatial.${concepts.join('.')}',
            clipsConsigne: const ['consigne.spatial.e1'],
            donnees: DonneesScene(decor: 'maison', etapes: etapes),
          ),
        );
      }
    }
    manches.shuffle(alea);
    return manches;
  }
}

const clipsSpatial = <ClipConsigne>[
  ClipConsigne('act.spatial.titre', 'Devant, derrière, à côté'),
  ClipConsigne('consigne.spatial.e1', 'Regarde bien où est le chat…'),
  ClipConsigne(
    'consigne.spatial.e2',
    'Où est le chat ? Touche la bonne image !',
  ),
];

const activiteSpatial = Activite(
  id: 'spatial',
  famille: Famille.monde,
  moteur: Moteur.scene,
  sensNaturel: Sens.paysage,
  titreCle: 'act.spatial.titre',
  illustration: 'act-spatial.svg',
  source: SourceGenerateur(SpatialGenerateur()),
  clips: clipsSpatial,
  nbItemsMaximum: 4,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 4,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
