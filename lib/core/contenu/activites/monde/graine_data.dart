import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 25 — La graine (moteur M4, scène animée).
///
/// L'enfant arrose, met au soleil, attend : de la graine à la fleur, en
/// accéléré. Prévoir, agir, voir le résultat pousser.
///
/// Sources fixes : chaque manche est une petite histoire de la plante.
const clipsGraine = <ClipConsigne>[
  ClipConsigne('act.graine.titre', 'La graine'),
  ClipConsigne('consigne.graine.g1', 'Regarde bien la plante !'),
  ClipConsigne(
    'consigne.graine.e1',
    'Une petite graine dort dans la terre. Que lui faut-il pour se réveiller ?',
  ),
  ClipConsigne(
    'consigne.graine.e2',
    'Ça pousse ! Mais la pousse a besoin de lumière. Que fait-on ?',
  ),
  ClipConsigne(
    'consigne.graine.e3',
    'La pousse est grande. Elle a soif ! Que lui donnes-tu ?',
  ),
  ClipConsigne(
    'consigne.graine.e4',
    'Regarde comme elle est belle ! Elle a encore besoin d\'eau.',
  ),
  ClipConsigne('consigne.graine.e5', 'Bravo ! La fleur est ouverte !'),
];

const _graineManches = <Manche>[
  Manche(
    id: 'graine.1',
    clipsConsigne: ['consigne.graine.g1', 'consigne.graine.e1'],
    donnees: DonneesScene(
      decor: 'graine',
      etapes: [
        EtapeScene(
          narrationCle: 'consigne.graine.e1',
          options: ['eau', 'soleil', 'dormir'],
          bonneOption: 'eau',
          montrerAvant: true,
          visuel: 'pousse_1',
        ),
      ],
    ),
  ),
  Manche(
    id: 'graine.2',
    clipsConsigne: ['consigne.graine.g1', 'consigne.graine.e2'],
    donnees: DonneesScene(
      decor: 'graine',
      etapes: [
        EtapeScene(
          narrationCle: 'consigne.graine.e2',
          options: ['soleil', 'eau', 'dormir'],
          bonneOption: 'soleil',
          montrerAvant: true,
          visuel: 'pousse_2',
        ),
      ],
    ),
  ),
  Manche(
    id: 'graine.3',
    clipsConsigne: ['consigne.graine.g1', 'consigne.graine.e3'],
    donnees: DonneesScene(
      decor: 'graine',
      etapes: [
        EtapeScene(
          narrationCle: 'consigne.graine.e3',
          options: ['eau', 'dormir', 'soleil'],
          bonneOption: 'eau',
          montrerAvant: true,
          visuel: 'pousse_3',
        ),
      ],
    ),
  ),
  Manche(
    id: 'graine.4',
    clipsConsigne: ['consigne.graine.g1', 'consigne.graine.e4'],
    donnees: DonneesScene(
      decor: 'graine',
      etapes: [
        EtapeScene(
          narrationCle: 'consigne.graine.e4',
          options: ['eau', 'soleil', 'dormir'],
          bonneOption: 'eau',
          montrerAvant: true,
          visuel: 'pousse_3',
        ),
        EtapeScene(narrationCle: 'consigne.graine.e5', visuel: 'fleur'),
      ],
    ),
  ),
];

class GraineGenerateur extends GenerateurManches {
  const GraineGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final episodes = _graineManches;
    // Combiner les épisodes en gardant leur chronologie : un besoin isolé,
    // puis plusieurs décisions dans la même histoire.
    final maximum = niveau.numero <= 2
        ? 1
        : niveau.numero <= 5
        ? 2
        : (niveau.palier == Palier.a4 ? 2 : 3);
    final banque = <Manche>[];
    for (var masque = 1; masque < (1 << episodes.length); masque++) {
      final choisis = [
        for (var j = 0; j < episodes.length; j++)
          if (masque & (1 << j) != 0) episodes[j],
      ];
      if (choisis.length > maximum ||
          (niveau.numero >= 4 && choisis.length < 2)) {
        continue;
      }
      banque.add(
        Manche(
          id: 'graine.${choisis.map((m) => m.id.split('.').last).join('.')}',
          clipsConsigne: choisis
              .expand((m) => m.clipsConsigne)
              .toSet()
              .toList(),
          donnees: DonneesScene(
            decor: 'graine',
            etapes: [
              for (final manche in choisis)
                ...(manche.donnees as DonneesScene).etapes,
            ],
          ),
        ),
      );
    }
    banque.shuffle(alea);
    return banque;
  }
}

const activiteGraine = Activite(
  id: 'graine',
  famille: Famille.monde,
  moteur: Moteur.scene,
  sensNaturel: Sens.portrait,
  titreCle: 'act.graine.titre',
  illustration: 'act-graine.svg',
  source: SourceGenerateur(GraineGenerateur()),
  clips: clipsGraine,
  nbItemsMaximum: 4,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 4, choixMax: 3),
  ],
  payload: PayloadScene(),
);
