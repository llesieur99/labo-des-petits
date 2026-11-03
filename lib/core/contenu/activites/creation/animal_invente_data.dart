import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 42 — Animal inventé (moteur M7c, l'atelier).
///
/// Tête, corps, queue : l'enfant assemble un animal qui n'existe pas, lui
/// donne un nom (au micro, s'il est autorisé), et l'app demande seulement :
/// « Qu'est-ce qu'il mange ? » — c'est l'enfant qui invente la réponse.
const clipsAnimal = <ClipConsigne>[
  ClipConsigne('act.animal.titre', 'Animal inventé'),
  ClipConsigne('consigne.atelier.g1', 'On invente un animal !'),
  ClipConsigne('consigne.atelier.tete', 'Choisis une tête !'),
  ClipConsigne('consigne.atelier.corps', 'Choisis un corps !'),
  ClipConsigne('consigne.atelier.queue', 'Choisis une queue !'),
  ClipConsigne('consigne.atelier.nom', 'Donne-lui un nom !'),
  ClipConsigne('consigne.atelier.felicite', 'Quel beau nom !'),
  ClipConsigne('consigne.atelier.mange', 'Qu\'est-ce qu\'il mange ?'),
];

/// Les banques sont croisées : chaque étape ouvre d'autres associations,
/// sans exiger un animal réaliste ni une nourriture « correcte ».
class AnimalInventeGenerateur extends GenerateurManches {
  const AnimalInventeGenerateur();

  static const _animaux = [
    'chat',
    'lapin',
    'souris',
    'loup',
    'hibou',
    'tigre',
    'poule',
    'grenouille',
    'vache',
    'mouton',
    'cochon',
    'poisson',
    'serpent',
    'crevette',
    'doudou',
    'monstre',
  ];
  static const _fantaisie = ['fusee', 'fleur', 'gateau', 'couleur'];
  static const _aliments = [
    'pomme',
    'pizza',
    'poisson',
    'gateau',
    'bonbon',
    'chocolat',
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final etape = (niveau.numero - 1).clamp(0, 7);
    final nombre = min(4, 2 + niveau.palier.index + etape ~/ 4);
    final depart = etape * 2 + niveau.palier.index;
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        Manche(
          id: 'animal.${niveau.palier.id}.${niveau.numero}.$i',
          clipsConsigne: const ['consigne.atelier.g1'],
          donnees: DonneesAtelier(
            groupes: [
              for (var groupe = 0; groupe < 3; groupe++)
                GroupeAtelier(
                  libelleCle: const [
                    'consigne.atelier.tete',
                    'consigne.atelier.corps',
                    'consigne.atelier.queue',
                  ][groupe],
                  options: [
                    for (var option = 0; option < nombre; option++)
                      if (groupe == 2 && etape >= 4 && option == nombre - 1)
                        _fantaisie[(etape + i) % _fantaisie.length]
                      else
                        _animaux[(depart + i * 3 + groupe * 5 + option) %
                            _animaux.length],
                  ],
                ),
            ],
            inviterNomCle: 'consigne.atelier.nom',
            felicitationNomCle: 'consigne.atelier.felicite',
            questionCle: 'consigne.atelier.mange',
            nourritures: [
              for (var j = 0; j < nombre; j++)
                _aliments[(depart + i + j) % _aliments.length],
            ],
          ),
        ),
    ];
  }
}

const activiteAnimalInvente = Activite(
  id: 'animal',
  famille: Famille.creation,
  moteur: Moteur.creation,
  sensNaturel: Sens.portrait,
  titreCle: 'act.animal.titre',
  illustration: 'act-animal.svg',
  source: SourceGenerateur(AnimalInventeGenerateur()),
  clips: clipsAnimal,
  nbItemsMaximum: 3,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 1, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 2, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 2, choixMax: 4),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 3, choixMax: 4),
  ],
  payload: PayloadAtelier(),
);
