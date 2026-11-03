import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 19 — Le code de trois blocs (M5 en mode exécuter, 6-7 ans).
///
/// Avancer, tourner, ramasser : l'enfant pose trois blocs et la souris suit
/// le programme, case par case. Assez pour 6-7 ans, trop ambitieux avant.
const clipsCode = <ClipConsigne>[
  ClipConsigne('act.code.titre', 'Le code de trois blocs'),
  ClipConsigne(
    'consigne.code.g1',
    'Pose tes blocs pour amener la souris jusqu\'à la pomme. Après, appuie sur le bouton vert !',
  ),
  ClipConsigne('code.bravo', 'Bravo ! La souris a suivi ton programme !'),
];

/// Générateur : des petits parcours, du plus court au plus long.
class CodeGenerateur extends GenerateurManches {
  const CodeGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final age = niveau.palier.age;
    // Avant six ans : translation seulement. Ensuite viennent le virage,
    // puis le retour vers la gauche (deux rotations vers la droite).
    final distanceBase = age < 6
        ? 1 + (niveau.numero >= 4 ? 1 : 0)
        : 1 + ((niveau.numero - 1) ~/ 3).clamp(0, 2);
    final virage = age >= 6 && niveau.numero >= 3;
    final retour = age == 7 && niveau.numero >= 6;
    // Deux rotations et le ramassage laissent au plus trois déplacements.
    final distance = retour ? min(2, distanceBase) : distanceBase;
    final parcours = <DonneesCode>[];
    for (var pas = max(1, distance - 1); pas <= distance; pas++) {
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final dx = retour ? -pas : pas;
          final dy = virage ? 1 : 0;
          if (x + dx < 0 || x + dx >= 4 || y + dy >= 4) continue;
          parcours.add(
            DonneesCode(
              taille: 4,
              departX: x,
              departY: y,
              objectifX: x + dx,
              objectifY: y + dy,
              animal: 'souris',
              ramassable: 'pomme',
              maxBlocs: pas + dy + (retour ? 2 : (virage ? 1 : 0)) + 1,
            ),
          );
        }
      }
    }
    parcours.shuffle(alea);
    return [
      for (final d in parcours.take(niveau.nbItems))
        Manche(
          id: 'code.${d.departX}.${d.departY}.${d.objectifX}.${d.objectifY}',
          clipsConsigne: const ['consigne.code.g1'],
          donnees: d,
        ),
    ];
  }
}

final activiteCode = Activite(
  id: 'code',
  famille: Famille.logique,
  moteur: Moteur.ordre,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.code.titre',
  illustration: 'act-code.svg',
  source: SourceGenerateur(CodeGenerateur()),
  clips: clipsCode,
  niveaux: [
    // Visible dès 4 ans, mais les parcours courts seulement : le vrai jeu
    // est pour 6-7 ans (voir le catalogue).
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 4, choixMax: 2),
  ],
  payload: PayloadCode(),
);
