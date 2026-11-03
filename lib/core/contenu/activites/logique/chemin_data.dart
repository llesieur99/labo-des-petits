import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 20 — Le chemin du doigt (moteur M3, trace).
///
/// Suivre un sentier sans lever le doigt : la préparation au crayon et aux
/// labyrinthes, sans jamais juger la précision.
class CheminGenerateur extends GenerateurManches {
  const CheminGenerateur();

  static const _sentiers = ['sentier.ligne', 'sentier.s', 'sentier.boucle'];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    // Les premières étapes isolent un geste, puis mélangent les trois.
    final nombre = (1 + (niveau.numero - 1) ~/ 2 + (niveau.palier.age - 4) ~/ 2)
        .clamp(1, 3);
    final sentiers = List.of(_sentiers.take(nombre))..shuffle(alea);
    final largeurBase = switch (niveau.palier) {
      Palier.a4 => 0.32,
      Palier.a5 => 0.28,
      Palier.a6 => 0.24,
      Palier.a7 => 0.20,
    };
    final largeur = (largeurBase - (niveau.numero - 1) * 0.012).clamp(
      0.14,
      0.32,
    );
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems; i++) {
      final sentier = sentiers[i % sentiers.length];
      manches.add(
        Manche(
          id: 'chemin.$sentier.${niveau.palier.id}.${niveau.numero}.$i',
          clipsConsigne: const ['consigne.chemin.g1'],
          donnees: DonneesTrace(cheminId: sentier, largeurRuban: largeur),
        ),
      );
    }
    return manches;
  }
}

const clipsChemin = <ClipConsigne>[
  ClipConsigne('act.chemin.titre', 'Le chemin du doigt'),
  ClipConsigne(
    'consigne.chemin.g1',
    'Suis le chemin avec ton doigt, tout au long. Vas-y doucement !',
  ),
];

const activiteChemin = Activite(
  id: 'chemin',
  famille: Famille.logique,
  moteur: Moteur.trace,
  sensNaturel: Sens.portrait,
  titreCle: 'act.chemin.titre',
  illustration: 'act-chemin.svg',
  source: SourceGenerateur(CheminGenerateur()),
  clips: clipsChemin,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 4, choixMax: 2),
  ],
  payload: PayloadTrace(),
);
