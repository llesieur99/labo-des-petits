import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 41 — Le théâtre de vingt secondes (moteur M7b).
///
/// L'enfant déplace deux personnages, l'app enregistre la scène et la
/// rejoue telle quelle. Il peut la refaire autrement, autant de fois
/// qu'il veut.
const clipsTheatre = <ClipConsigne>[
  ClipConsigne('act.theatre.titre', 'Le théâtre de vingt secondes'),
  ClipConsigne(
    'consigne.theatre.g1',
    'Fais bouger tes deux amis avec ton doigt. Après, on rejoue la scène !',
  ),
  ClipConsigne('theatre.bravo', 'Quelle belle scène ! On la rejoue ?'),
];

/// Rencontres ouvertes : aucun scénario ou dialogue à réussir.
class TheatreGenerateur extends GenerateurManches {
  const TheatreGenerateur();

  static const _duos = [
    ['chat', 'souris'],
    ['lapin', 'loup'],
    ['enfant', 'doudou'],
    ['hibou', 'grenouille'],
    ['poule', 'cochon'],
    ['tigre', 'mouton'],
    ['poisson', 'crevette'],
    ['vache', 'serpent'],
    ['chat', 'doudou'],
    ['monstre', 'enfant'],
    ['lapin', 'grenouille'],
    ['hibou', 'souris'],
    ['loup', 'mouton'],
    ['poule', 'poisson'],
    ['tigre', 'monstre'],
    ['vache', 'cochon'],
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final etape = (niveau.numero - 1).clamp(0, 7);
    final debut = etape * 2 + niveau.palier.index;
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        Manche(
          id: 'theatre.${(debut + i) % _duos.length}',
          clipsConsigne: const ['consigne.theatre.g1'],
          donnees: DonneesTheatre(
            personnages: _duos[(debut + i) % _duos.length],
            dureeMaxSecondes: min(
              20,
              12 + niveau.palier.index * 2 + etape ~/ 3,
            ),
          ),
        ),
    ];
  }
}

const activiteTheatre = Activite(
  id: 'theatre',
  famille: Famille.creation,
  moteur: Moteur.creation,
  sensNaturel: Sens.paysage,
  titreCle: 'act.theatre.titre',
  illustration: 'act-theatre.svg',
  source: SourceGenerateur(TheatreGenerateur()),
  clips: clipsTheatre,
  nbItemsMaximum: 3,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 1, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 3, choixMax: 2),
  ],
  payload: PayloadTheatre(),
);
