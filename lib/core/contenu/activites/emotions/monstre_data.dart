import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 35 — Le calme du monstre (moteur M6, mode bercement).
///
/// Le monstre s'endort si on tape tout doucement, lentement. Taper vite le
/// réveille — sans reproche : on recommence, c'est tout. Fort et doux,
/// vite et lent se vivent avec les mains.
class MonstreGenerateur extends GenerateurManches {
  const MonstreGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final etape = niveau.numero.clamp(1, 8) - 1;
    final age = niveau.palier.index;
    // D'abord quelques caresses, puis garder le calme plus longtemps.
    // Le délai reste large : aucun objectif de précision à la milliseconde.
    final caresses = 4 + age + etape ~/ 2;
    final depart = alea.nextInt(2);
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        Manche(
          id: 'monstre.${niveau.palier.id}.${niveau.numero}.$i',
          clipsConsigne: const ['consigne.monstre.g1'],
          donnees: DonneesRythme(
            mode: ModeRythme.bercement,
            battements: caresses + (etape >= 4 ? i % 2 : 0),
            intervalleMs:
                1100 +
                (etape % 2) * 100 +
                (etape >= 4 ? ((depart + i) % 2) * 200 : 0),
          ),
        ),
    ];
  }
}

const clipsMonstre = <ClipConsigne>[
  ClipConsigne('act.monstre.titre', 'Le calme du monstre'),
  ClipConsigne(
    'consigne.monstre.g1',
    'Tape tout doucement, sans te presser, pour endormir le monstre.',
  ),
];

const activiteMonstre = Activite(
  id: 'monstre',
  famille: Famille.emotions,
  moteur: Moteur.rythme,
  sensNaturel: Sens.portrait,
  titreCle: 'act.monstre.titre',
  illustration: 'act-monstre.svg',
  source: SourceGenerateur(MonstreGenerateur()),
  clips: clipsMonstre,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 1, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 3, choixMax: 2),
  ],
  payload: PayloadRythme(),
);
