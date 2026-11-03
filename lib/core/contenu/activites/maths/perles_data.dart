import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 11 — Perles à motifs (moteur M4, décor 'perles').
///
/// Rouge-bleu, rouge-bleu, puis rouge-bleu-bleu : l'enfant continue la
/// suite. Le motif se voit avant de se dire.
class PerlesGenerateur extends GenerateurManches {
  const PerlesGenerateur();

  static const _couleurs = ['rouge', 'bleu', 'jaune', 'vert', 'violet'];
  // AB, AAB, ABB, ABC, AABB, ABAC, ABCB, ABCD : la règle change,
  // pas seulement la longueur du collier ou la couleur de sa première perle.
  static const _regles = <List<int>>[
    [0, 1],
    [0, 0, 1],
    [0, 1, 1],
    [0, 1, 2],
    [0, 0, 1, 1],
    [0, 1, 0, 2],
    [0, 1, 2, 1],
    [0, 1, 2, 3],
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final age = niveau.palier.index;
    final regleMax = switch (age) {
      0 => niveau.numero <= 5 ? 0 : 2,
      1 => min(4, 1 + (niveau.numero - 1) ~/ 2),
      _ => min(7, 2 + age + (niveau.numero - 1) ~/ 2),
    };
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems; i++) {
      final couleurs = List.of(_couleurs)..shuffle(alea);
      final regle = _regles[(regleMax - i % min(3, regleMax + 1))];
      final decalage = niveau.numero >= 4 ? alea.nextInt(regle.length) : 0;
      // Deux répétitions montrent la règle ; une amorce décalée empêche
      // d'apprendre simplement « la réponse est la première couleur ».
      final longueur =
          regle.length * 2 + (niveau.numero >= 3 ? i % regle.length : 0);
      final suite = [
        for (var p = 0; p < longueur; p++)
          couleurs[regle[(p + decalage) % regle.length]],
      ];
      final reponse = couleurs[regle[(longueur + decalage) % regle.length]];
      final leurres = couleurs.where((c) => c != reponse).toList()
        ..shuffle(alea);
      final options = [reponse, ...leurres.take(min(5, niveau.choixMax) - 1)]
        ..shuffle(alea);
      manches.add(
        Manche(
          id: 'perles.${suite.join('-')}.$reponse.$i',
          clipsConsigne: const ['consigne.perles.g1'],
          donnees: DonneesScene(
            decor: 'perles',
            etapes: [
              EtapeScene(
                narrationCle: 'consigne.perles.g1',
                visuel: 'perles:${suite.join('|')}',
              ),
              EtapeScene(
                narrationCle: 'consigne.perles.g2',
                options: options,
                bonneOption: reponse,
                visuel: 'perles:${[...suite, reponse].join('|')}',
              ),
            ],
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsPerles = <ClipConsigne>[
  ClipConsigne('act.perles.titre', 'Perles à motifs'),
  ClipConsigne('consigne.perles.g1', 'Regarde bien le collier…'),
  ClipConsigne(
    'consigne.perles.g2',
    'Quelle perle vient après ? Continue le collier !',
  ),
];

const activitePerles = Activite(
  id: 'perles',
  famille: Famille.maths,
  moteur: Moteur.scene,
  sensNaturel: Sens.paysage,
  titreCle: 'act.perles.titre',
  illustration: 'act-perles.svg',
  source: SourceGenerateur(PerlesGenerateur()),
  clips: clipsPerles,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 5,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
