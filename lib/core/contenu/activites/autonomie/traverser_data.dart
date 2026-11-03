import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 47 — Traverser (moteur M5).
///
/// Stop, regarder, écouter, marcher : un exercice à REFAIRE DEHORS avec un
/// adulte. L'app le dit elle-même — elle ne remplace pas la rue.
const clipsTraverser = <ClipConsigne>[
  ClipConsigne(
    'consigne.traverser.parc',
    'Pour aller au parc, on traverse avec un adulte, main dans la main. On s’arrête, on regarde et on écoute. L’adulte décide quand on peut traverser en marchant. Remets les images dans l’ordre.',
  ),
  ClipConsigne(
    'consigne.traverser.ecole',
    'Sur le chemin de l’école, on traverse avec un adulte, main dans la main. On s’arrête, on regarde et on écoute. L’adulte décide quand on peut traverser en marchant. Remets les images dans l’ordre.',
  ),

  ClipConsigne('act.traverser.titre', 'Traverser'),
  ClipConsigne(
    'consigne.traverser.g1',
    'Avec un adulte, on s’arrête, on regarde et on écoute avant de traverser. Remets les images dans l’ordre.',
  ),
  ClipConsigne(
    'consigne.traverser.g2',
    'Avec un adulte : stop, regarde, écoute, puis traverse quand c’est possible. Remets les images dans l’ordre.',
  ),
  ClipConsigne(
    'traverser.rappel',
    'Bravo ! Et rappelle-toi : dans la vraie rue, on traverse toujours avec un adulte, la main dans la main.',
  ),
];

/// Le rituel correct reste entier dès quatre ans. La progression porte sur
/// le rappel dans plusieurs situations et la discrimination des intrus.
class TraverserGenerateur extends GenerateurManches {
  const TraverserGenerateur();

  static const _gestes = ['panneau_stop', 'regarder', 'ecouter', 'marcher'];
  static const _intrus = [
    'ballon',
    'pizza',
    'fusee',
    'chocolat',
    'chat',
    'livre',
    'doudou',
    'tambour',
  ];
  static const _contextes = [
    'consigne.traverser.g1',
    'consigne.traverser.g2',
    'consigne.traverser.parc',
    'consigne.traverser.ecole',
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
      id: 'traverser.$consigne.${(List.of(distracteurs)..sort()).join('.')}.$i',
      clipsConsigne: [consigne],
      options: [
        for (final concept in options)
          OptionManche(id: concept, concept: concept),
      ],
      donnees: DonneesOrdre(cases: sequence, narrationCle: 'traverser.rappel'),
    );
  }
}

const activiteTraverser = Activite(
  id: 'traverser',
  famille: Famille.autonomie,
  moteur: Moteur.ordre,
  sensNaturel: Sens.paysage,
  titreCle: 'act.traverser.titre',
  illustration: 'act-traverser.svg',
  source: SourceGenerateur(TraverserGenerateur()),
  clips: clipsTraverser,
  niveaux: [
    Niveau(
      palier: Palier.a4,
      numero: 1,
      nbItems: 1,
      choixMax: 3,
      aides: [Aide.narrationAvant],
    ),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 2, choixMax: 5),
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
