import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 1 — La bouche à sons (moteur M6, mode echo).
///
/// L'enfant reproduit un son du français (« sss », « ch », « ou »), un
/// animal réagit. Les lettres n'apparaissent jamais : c'est la bouche qui
/// apprend, pas l'œil. Peu d'apps font les sons du français — c'est ici.
class BoucheSonsGenerateur extends GenerateurManches {
  const BoucheSonsGenerateur();

  /// (palier d'arrivée, clip du son, animal, clip de réaction).
  static const _sons = [
    (Palier.a4, 'son.sss', 'serpent', 'reaction.serpent'),
    (Palier.a4, 'son.ou', 'loup', 'reaction.loup'),
    (Palier.a5, 'son.ch', 'train', 'reaction.train'),
    (Palier.a6, 'son.mmm', 'vache', 'reaction.vache'),
    (Palier.a6, 'son.rrr', 'tigre', 'reaction.tigre'),
    (Palier.a7, 'son.zzz', 'abeille', 'reaction.abeille'),
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final disponibles =
        _sons
            .take(
              (2 + niveau.palier.index + (niveau.numero - 1) ~/ 2).clamp(
                2,
                _sons.length,
              ),
            )
            .toList()
          ..shuffle(alea);
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems && i < disponibles.length; i++) {
      final (_, sonCle, animal, reaction) = disponibles[i];
      manches.add(
        Manche(
          id: 'bouche.$animal',
          // Amorce + le son : le bouton « Répète » redit le son à reproduire.
          clipsConsigne: ['consigne.bouche.g1', sonCle],
          donnees: DonneesRythme(
            mode: ModeRythme.echo,
            sonCle: sonCle,
            animalConcept: animal,
            reactionCle: reaction,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsBoucheSons = <ClipConsigne>[
  ClipConsigne('act.bouche.titre', 'La bouche à sons'),
  ClipConsigne(
    'consigne.bouche.g1',
    'Écoute bien ce son… et fais-le toi aussi !',
  ),
  ClipConsigne('son.sss', 'Sssssss…'),
  ClipConsigne('son.ou', 'Ouuuu…'),
  ClipConsigne('son.ch', 'Chhhhh…'),
  ClipConsigne('son.mmm', 'Mmmmm…'),
  ClipConsigne('son.rrr', 'Rrrrrr…'),
  ClipConsigne('son.zzz', 'Zzzzzz…'),
  ClipConsigne('reaction.serpent', 'Le serpent aime ça ! Regarde-le danser.'),
  ClipConsigne('reaction.loup', 'Le loup répond : ouuuu !'),
  ClipConsigne('reaction.train', 'Le train roule : chhhhh !'),
  ClipConsigne('reaction.vache', 'La vache meugle : mmmmm !'),
  ClipConsigne('reaction.tigre', 'Le tigre grogne : rrrrr !'),
  ClipConsigne('reaction.abeille', 'L\'abeille butine : zzzzz !'),
];

const activiteBoucheSons = Activite(
  id: 'bouche',
  famille: Famille.langue,
  moteur: Moteur.rythme,
  sensNaturel: Sens.portrait,
  titreCle: 'act.bouche.titre',
  illustration: 'act-bouche.svg',
  source: SourceGenerateur(BoucheSonsGenerateur()),
  clips: clipsBoucheSons,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 5, choixMax: 2),
  ],
  nbItemsMaximum: 6,
  payload: PayloadRythme(),
);
