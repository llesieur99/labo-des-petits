import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 36 — Le rythme des pas (moteur M6, mode pulsation).
///
/// Taper en même temps qu'un tambour. Le tempo ralentit si les tapes se
/// perdent : c'est l'app qui s'adapte à l'enfant, jamais l'inverse.
class RythmeGenerateur extends GenerateurManches {
  const RythmeGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    // On explore plusieurs allures, pas une course de plus en plus rapide.
    // Les séquences restent courtes et le moteur ralentit si nécessaire.
    const allures = [1050, 1010, 970, 1030, 930, 990, 910, 950];
    const longueurs = [6, 6, 8, 6, 8, 8, 10, 8];
    final etape = (niveau.numero - 1).clamp(0, 7);
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        Manche(
          id: 'rythme.${niveau.palier.id}.${niveau.numero}.$i',
          clipsConsigne: const ['consigne.rythme.g1'],
          donnees: DonneesRythme(
            mode: ModeRythme.pulsation,
            battements: longueurs[(etape + i) % 8] + niveau.palier.index,
            intervalleMs: allures[(etape + i) % 8] - niveau.palier.index * 40,
          ),
        ),
    ];
  }
}

const clipsRythme = <ClipConsigne>[
  ClipConsigne('act.rythme.titre', 'Le rythme des pas'),
  ClipConsigne(
    'consigne.rythme.g1',
    'Tape sur le tambour en même temps que moi. Écoute bien…',
  ),
];

const activiteRythme = Activite(
  id: 'rythme',
  famille: Famille.creation,
  moteur: Moteur.rythme,
  sensNaturel: Sens.portrait,
  titreCle: 'act.rythme.titre',
  illustration: 'act-rythme.svg',
  source: SourceGenerateur(RythmeGenerateur()),
  clips: clipsRythme,
  nbItemsMaximum: 3,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 3, choixMax: 2),
  ],
  payload: PayloadRythme(),
);
