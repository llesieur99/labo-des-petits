import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 45 — La recette de trois gestes (moteur M5).
///
/// Laver un fruit, laisser l'adulte le préparer, servir les morceaux :
/// une suite d'actions sécuritaire avant la vraie collation.
const clipsRecette = <ClipConsigne>[
  ClipConsigne(
    'consigne.recette.pomme',
    'Avec un adulte, prépare une pomme : lave-la, laisse l’adulte la couper, puis mets les morceaux dans une assiette. Remets les images dans l’ordre.',
  ),
  ClipConsigne(
    'consigne.recette.fraise',
    'Avec un adulte, prépare des fraises : lave-les, laisse l’adulte les couper, puis mets les morceaux dans une assiette. Remets les images dans l’ordre.',
  ),
  ClipConsigne(
    'consigne.recette.banane',
    'Avec un adulte, prépare une banane : lave la peau, laisse l’adulte la peler et la couper, puis mets les morceaux dans une assiette. Remets les images dans l’ordre.',
  ),
  ClipConsigne(
    'consigne.recette.aide',
    'Prépare la collation avec un adulte. Lave le fruit, demande de l’aide, laisse l’adulte le couper, puis mets les morceaux dans une assiette. Remets les images dans l’ordre.',
  ),
  ClipConsigne(
    'recette.fin_securite',
    'Le fruit est lavé, l’adulte l’a préparé et les morceaux sont dans l’assiette. Bon appétit !',
  ),

  ClipConsigne('act.recette.titre', 'La recette de trois gestes'),
  ClipConsigne(
    'consigne.recette.g1',
    'Avec un adulte : lave la pomme, laisse l’adulte la couper, puis place les morceaux dans une assiette. Remets les gestes dans le bon ordre.',
  ),
  ClipConsigne(
    'recette.fin',
    'La pomme est lavée et l’adulte l’a coupée. Les morceaux sont prêts dans l’assiette. Miam !',
  ),
];

/// Le rituel correct reste entier dès quatre ans. La progression porte sur
/// le rappel dans plusieurs situations et la discrimination des intrus.
class RecetteGenerateur extends GenerateurManches {
  const RecetteGenerateur();

  static const _gestes = ['eau', 'couteau', 'assiette'];
  static const _intrus = [
    'ballon',
    'lit',
    'fusee',
    'chaussette',
    'livre',
    'doudou',
    'tambour',
    'bottes',
  ];
  static const _contextes = [
    'consigne.recette.pomme',
    'consigne.recette.fraise',
    'consigne.recette.banane',
    'consigne.recette.aide',
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
    final avecAide = niveau.numero >= 7;
    final sequence = avecAide
        ? const ['eau', 'aide', 'couteau', 'assiette']
        : _gestes;
    final consigne = avecAide
        ? 'consigne.recette.aide'
        : contextes[i % contextes.length];

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
      id: 'recette.$consigne.${(List.of(distracteurs)..sort()).join('.')}.$i',
      clipsConsigne: [consigne],
      options: [
        for (final concept in options)
          OptionManche(id: concept, concept: concept),
      ],
      donnees: DonneesOrdre(
        cases: sequence,
        narrationCle: 'recette.fin_securite',
      ),
    );
  }
}

const activiteRecette = Activite(
  id: 'recette',
  famille: Famille.autonomie,
  moteur: Moteur.ordre,
  sensNaturel: Sens.paysage,
  titreCle: 'act.recette.titre',
  illustration: 'act-recette.svg',
  source: SourceGenerateur(RecetteGenerateur()),
  clips: clipsRecette,
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
