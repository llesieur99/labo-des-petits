import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 17 — L'intrus qui parle (moteur M1).
///
/// « Tout ça se mange, sauf… » L'enfant touche l'intrus, et l'app dit
/// POURQUOI. On classe sans réciter de listes.
class IntrusGenerateur extends GenerateurManches {
  const IntrusGenerateur();

  /// Les familles d'objets (le clip de consigne, puis ses membres).
  /// Chaque famille a AU MOINS 4 membres (le palier 7 ans propose 4 + l'intrus),
  /// et aucun objet n'appartient à deux familles.
  static const familles = <String, List<String>>{
    'manger': ['pizza', 'pomme', 'gateau', 'bonbon', 'chocolat', 'banane'],
    'porter': [
      'chapeau',
      'bottes',
      'mitaines',
      'chaussette',
      'maillot',
      'echarpe',
    ],
    'animaux': [
      'chat',
      'loup',
      'souris',
      'lapin',
      'vache',
      'poule',
      'mouton',
      'hibou',
      'papillon',
    ],
    'jouer': ['ballon', 'doudou', 'tambour', 'fusee'],
    'maison': ['lit', 'assiette', 'verre', 'sac', 'bougie'],
  };

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    // D'abord un critère concret isolé, puis alternance entre critères.
    final criteres = ['manger', 'porter', 'animaux', 'jouer', 'maison'];
    final ouverture =
        (niveau.numero - 1 + niveau.palier.age - 4) % criteres.length;
    final nombre = (1 + (niveau.numero - 1) ~/ 2 + (niveau.palier.age - 4) ~/ 2)
        .clamp(1, 5);
    final familles = [
      for (var j = 0; j < nombre; j++)
        criteres[(ouverture + j) % criteres.length],
    ]..shuffle(alea);
    final manches = <Manche>[];
    final ids = <String>{};

    for (var i = 0; i < 160 && manches.length < niveau.nbItems; i++) {
      final famille = familles[i % familles.length];
      final membres = List.of(IntrusGenerateur.familles[famille]!)
        ..shuffle(alea);
      final intrusesPermises = famille == 'maison'
          ? ['animaux']
          : (famille == 'animaux'
                ? ['manger', 'porter', 'jouer', 'maison']
                : [
                    'manger',
                    'porter',
                    'jouer',
                  ].where((f) => f != famille).toList());
      final familleIntruse =
          intrusesPermises[alea.nextInt(intrusesPermises.length)];
      final intrus =
          IntrusGenerateur.familles[familleIntruse]![alea.nextInt(
            IntrusGenerateur.familles[familleIntruse]!.length,
          )];

      // Les membres de la famille, moins l'intrus d'une autre famille.
      final nombreMembres = (niveau.choixMax - 1).clamp(2, 4);
      final options = <OptionManche>[
        for (final membre in membres.take(nombreMembres))
          OptionManche(id: membre, concept: membre),
        OptionManche(id: intrus, concept: intrus),
      ]..shuffle(alea);

      final id =
          'intrus.$famille.${(options.map((o) => o.id).toList()..sort()).join('-')}';
      if (!ids.add(id)) continue;
      manches.add(
        Manche(
          id: id,
          clipsConsigne: ['consigne.intrus.$famille'],
          options: options,
          bonneOptionId: intrus,
          explicationCle: 'explication.intrus.$famille',
        ),
      );
    }
    return manches;
  }
}

const clipsIntrus = <ClipConsigne>[
  ClipConsigne('act.intrus.titre', 'L\'intrus qui parle'),
  ClipConsigne(
    'consigne.intrus.manger',
    'Tout ça, ça se mange… sauf un ! Touche ce qui ne se mange pas.',
  ),
  ClipConsigne(
    'consigne.intrus.porter',
    'Tout ça, ça se porte… sauf un ! Touche ce qui ne se porte pas.',
  ),
  ClipConsigne(
    'consigne.intrus.animaux',
    'Tout ça, ce sont des animaux… sauf un ! Touche celui qui n\'est pas un animal.',
  ),
  ClipConsigne(
    'consigne.intrus.jouer',
    'Tout ça, c\'est pour jouer… sauf un ! Touche ce qui n\'est pas un jeu.',
  ),
  ClipConsigne(
    'consigne.intrus.maison',
    'Voici des objets. Un animal s’est glissé parmi eux. Touche l’animal !',
  ),
  ClipConsigne('explication.intrus.manger', 'Celui-là, ça ne se mange pas !'),
  ClipConsigne('explication.intrus.porter', 'Celui-là, ça ne se porte pas !'),
  ClipConsigne(
    'explication.intrus.animaux',
    'Celui-là, ce n\'est pas un animal !',
  ),
  ClipConsigne('explication.intrus.jouer', 'Celui-là, ça ne se joue pas !'),
  ClipConsigne(
    'explication.intrus.maison',
    'Celui-là est un animal, les autres sont des objets !',
  ),
];

const activiteIntrus = Activite(
  id: 'intrus',
  choixMinimum: 3,
  famille: Famille.logique,
  moteur: Moteur.tapPick,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.intrus.titre',
  illustration: 'act-intrus.svg',
  source: SourceGenerateur(IntrusGenerateur()),
  clips: clipsIntrus,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 6, choixMax: 4),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 6,
      choixMax: 4,
      afficherMots: true,
    ),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 8,
      choixMax: 5,
      afficherMots: true,
    ),
  ],
  payload: PayloadTapPick(),
);
