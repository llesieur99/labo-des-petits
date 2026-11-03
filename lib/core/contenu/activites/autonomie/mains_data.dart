import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 44 — Laver les mains (moteur M5).
///
/// Les étapes en chanson, dans l'ordre, un geste à toucher pour chacune.
/// Le vrai rituel du retour de l'école.
const clipsMains = <ClipConsigne>[
  ClipConsigne(
    'consigne.mains.avant_repas',
    'Avant de manger, on lave ses mains. Retrouve tous les gestes dans le bon ordre.',
  ),
  ClipConsigne(
    'consigne.mains.apres_parc',
    'Tu reviens du parc. Retrouve tous les gestes pour bien laver tes mains.',
  ),
  ClipConsigne(
    'consigne.mains.apres_animal',
    'Après avoir touché un animal, on lave ses mains. Remets les gestes dans le bon ordre.',
  ),
  ClipConsigne(
    'consigne.mains.apres_toilette',
    'Après les toilettes, on lave ses mains. Remets tous les gestes dans le bon ordre.',
  ),

  ClipConsigne('act.mains.titre', 'Laver les mains'),
  ClipConsigne(
    'consigne.mains.g1',
    'Remets les gestes dans l\'ordre pour laver tes mains !',
  ),
  ClipConsigne(
    'mains.comptine',
    'On mouille les mains, on savonne, on frotte partout pendant vingt secondes, puis on rince. Ensuite, on ferme le robinet et on sèche les mains avec une serviette propre. Bravo !',
  ),
];

/// Le rituel correct reste entier dès quatre ans. La progression porte sur
/// le rappel dans plusieurs situations et la discrimination des intrus.
class MainsGenerateur extends GenerateurManches {
  const MainsGenerateur();

  static const _gestes = ['robinet', 'savon', 'frotter', 'eau'];
  static const _intrus = [
    'ballon',
    'doudou',
    'livre',
    'pomme',
    'bottes',
    'fleur',
    'tambour',
    'assiette',
  ];
  static const _contextes = [
    'consigne.mains.avant_repas',
    'consigne.mains.apres_parc',
    'consigne.mains.apres_animal',
    'consigne.mains.apres_toilette',
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final progression = niveau.numero.clamp(1, 8) - 1;
    // Chaque paire de niveaux enseigne une situation puis ajoute un intrus.
    // Lorsqu'une nouvelle situation arrive, on allège les distractions.
    const intrusParEtape = [0, 1, 0, 1, 1, 2, 1, 2];
    final nbIntrus = intrusParEtape[progression];
    final contexte = _contextes[progression ~/ 2];
    final contextes = [contexte];
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        _manche(niveau, alea, i, nbIntrus, contextes),
    ];
  }

  Manche _manche(
    Niveau niveau,
    Random alea,
    int i,
    int nbIntrus,
    List<String> contextes,
  ) {
    final sequence = _gestes;
    final consigne = contextes[i % contextes.length];

    final candidats = niveau.palier.age >= 6
        ? [..._intrus.reversed]
        : List.of(_intrus);
    // Tirer dans une moitié différente à chaque âge diversifie les objets
    // sans augmenter la charge visuelle au-delà de six cartes.
    final palette = niveau.palier.age >= 6
        ? candidats.take(6).toList()
        : candidats.skip((niveau.palier.age - 4) * 2).take(6).toList();
    final distracteurs = (palette..shuffle(alea)).take(nbIntrus).toList();
    final options = [...sequence, ...distracteurs]..shuffle(alea);
    return Manche(
      id: 'mains.$consigne.${(List.of(distracteurs)..sort()).join('.')}.$i',
      clipsConsigne: [consigne],
      options: [
        for (final concept in options)
          OptionManche(id: concept, concept: concept),
      ],
      donnees: DonneesOrdre(cases: sequence, narrationCle: 'mains.comptine'),
    );
  }
}

const activiteMains = Activite(
  id: 'mains',
  famille: Famille.autonomie,
  moteur: Moteur.ordre,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.mains.titre',
  illustration: 'act-mains.svg',
  source: SourceGenerateur(MainsGenerateur()),
  clips: clipsMains,
  niveaux: [
    Niveau(
      palier: Palier.a4,
      numero: 1,
      nbItems: 1,
      choixMax: 3,
      aides: [Aide.narrationAvant],
    ),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 2, choixMax: 4),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 3, choixMax: 5),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 3,
      choixMax: 6,
      afficherMots: true,
    ),
  ],
  payload: PayloadOrdre(),
);
