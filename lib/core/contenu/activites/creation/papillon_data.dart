import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 40 — Les ailes du papillon (moteur M7a en miroir).
///
/// L'enfant remplit les points sur une aile : l'autre se copie toute seule.
/// La symétrie se voit avant de se dire.
const clipsPapillon = <ClipConsigne>[
  ClipConsigne('act.papillon.titre', 'Les ailes du papillon'),
  ClipConsigne(
    'consigne.papillon.g1',
    'Peins les points sur l\'aile. L\'autre aile se copie toute seule !',
  ),
];

/// Huit dispositions par âge, sur de grandes taches espacées.
/// Le nombre reste lié à l'âge : avancer n'impose pas un dessin interminable.
class PapillonGenerateur extends GenerateurManches {
  const PapillonGenerateur();

  static const _couleurs = [
    'rouge',
    'jaune',
    'bleu',
    'vert',
    'violet',
    'orange',
  ];
  static const _positions = [
    (0.17, 0.22),
    (0.35, 0.34),
    (0.16, 0.48),
    (0.34, 0.60),
    (0.17, 0.75),
    (0.35, 0.81),
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final etape = (niveau.numero - 1).clamp(0, 7);
    final nombre = 3 + niveau.palier.index;
    final couleurs = min(6, 3 + niveau.palier.index + etape ~/ 4);
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        Manche(
          id: 'papillon.${niveau.palier.id}.${niveau.numero}.$i',
          clipsConsigne: const ['consigne.papillon.g1'],
          donnees: DonneesToile(
            palette: [
              for (var c = 0; c < couleurs; c++)
                _couleurs[(etape + i + c) % _couleurs.length],
            ],
            miroir: true,
            taches: [
              for (var t = 0; t < nombre; t++)
                PointToile(
                  _positions[t].$1 + ((etape + i) % 4 - 1.5) * 0.012,
                  etape.isEven ? _positions[t].$2 : 1 - _positions[t].$2,
                  niveau.palier == Palier.a4 ? 0.075 : 0.060,
                ),
            ],
          ),
        ),
    ];
  }
}

const activitePapillon = Activite(
  id: 'papillon',
  famille: Famille.creation,
  moteur: Moteur.creation,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.papillon.titre',
  illustration: 'act-papillon.svg',
  source: SourceGenerateur(PapillonGenerateur()),
  clips: clipsPapillon,
  nbItemsMaximum: 4,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 1, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 4, choixMax: 2),
  ],
  payload: PayloadToile(),
);
