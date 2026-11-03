import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 30 — Jour et nuit (moteur M4, décor 'ciel').
///
/// Le soleil se déplace pendant la journée : réveil, dîner, souper, dodo.
/// La routine du jour collée au ciel — pas une leçon d'horloge.
const clipsJourNuit = <ClipConsigne>[
  ClipConsigne('act.journuit.titre', 'Jour et nuit'),
  ClipConsigne('consigne.journuit.g1', 'Regarde le ciel.'),
  ClipConsigne(
    'consigne.journuit.e1',
    'Le soleil se lève doucement. Quel moment de la journée commence ?',
  ),
  ClipConsigne(
    'consigne.journuit.e2',
    'Le soleil est haut dans le ciel. C\'est l\'heure du dîner !',
  ),
  ClipConsigne(
    'consigne.journuit.e3',
    'Le soleil descend. Bientôt la nuit. Qu\'est-ce qui se lève dans le ciel ?',
  ),
  ClipConsigne(
    'consigne.journuit.e4',
    'Il fait tout noir, les étoiles brillent. Que fait-on ?',
  ),
];

const _jourNuitManches = <Manche>[
  Manche(
    id: 'journuit.1',
    clipsConsigne: ['consigne.journuit.g1', 'consigne.journuit.e1'],
    donnees: DonneesScene(
      decor: 'ciel',
      etapes: [
        EtapeScene(
          narrationCle: 'consigne.journuit.e1',
          options: ['matin', 'lit', 'assiette'],
          bonneOption: 'matin',
          montrerAvant: true,
          visuel: 'soleil_bas',
        ),
      ],
    ),
  ),
  Manche(
    id: 'journuit.2',
    clipsConsigne: ['consigne.journuit.g1', 'consigne.journuit.e2'],
    donnees: DonneesScene(
      decor: 'ciel',
      etapes: [
        EtapeScene(
          narrationCle: 'consigne.journuit.e2',
          options: ['assiette', 'dormir', 'ballon'],
          bonneOption: 'assiette',
          montrerAvant: true,
          visuel: 'soleil_haut',
        ),
      ],
    ),
  ),
  Manche(
    id: 'journuit.4',
    clipsConsigne: ['consigne.journuit.g1', 'consigne.journuit.e4'],
    donnees: DonneesScene(
      decor: 'ciel',
      etapes: [
        EtapeScene(
          narrationCle: 'consigne.journuit.e4',
          options: ['lit', 'assiette', 'ballon'],
          bonneOption: 'lit',
          montrerAvant: true,
          visuel: 'lune',
        ),
      ],
    ),
  ),
];

class JourNuitGenerateur extends GenerateurManches {
  const JourNuitGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final episodes = _jourNuitManches;
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
          id: 'journuit.${choisis.map((m) => m.id.split('.').last).join('.')}',
          clipsConsigne: choisis
              .expand((m) => m.clipsConsigne)
              .toSet()
              .toList(),
          donnees: DonneesScene(
            decor: 'ciel',
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

const activiteJourNuit = Activite(
  id: 'journuit',
  famille: Famille.monde,
  moteur: Moteur.scene,
  sensNaturel: Sens.paysage,
  titreCle: 'act.journuit.titre',
  illustration: 'act-journuit.svg',
  source: SourceGenerateur(JourNuitGenerateur()),
  clips: clipsJourNuit,
  nbItemsMaximum: 3,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 3),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 4,
      choixMax: 3,
      afficherMots: true,
    ),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 4,
      choixMax: 3,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
