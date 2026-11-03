import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 39 — La peinture qui se mélange (moteur M7a, toile).
///
/// Rouge et jaune sous le doigt : l'enfant peint, les couleurs se
/// rencontrent, et la nouvelle couleur est nommée. On découvre avant de
/// réciter.
class PeintureGenerateur extends GenerateurManches {
  const PeintureGenerateur();

  /// (résultat, clé du mélange — concepts triés —, les deux couleurs).
  static const _melanges = [
    ('orange', 'jaune+rouge', 'rouge', 'jaune'),
    ('violet', 'bleu+rouge', 'rouge', 'bleu'),
    ('vert', 'bleu+jaune', 'jaune', 'bleu'),
  ];

  static const _regles = <String, String>{
    'jaune+rouge': 'orange',
    'bleu+rouge': 'violet',
    'bleu+jaune': 'vert',
  };

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final etape = (niveau.numero - 1).clamp(0, 7);
    // Trois vrais mélanges seulement : chaque partie les aborde dans un
    // autre ordre, avec deux couleurs guidées puis la palette primaire libre.
    final depart = (etape + niveau.palier.index) % _melanges.length;
    final ordre = [
      for (var j = 0; j < _melanges.length; j++)
        _melanges[(depart + (etape.isEven ? j : -j)) % _melanges.length],
    ];
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems && i < ordre.length; i++) {
      final (resultat, _, couleur1, couleur2) = ordre[i];
      final guide = niveau.palier == Palier.a4 || etape < 2;
      manches.add(
        Manche(
          id: 'peinture.$resultat.${guide ? 'duo' : 'trio'}.${etape % 2}',
          clipsConsigne: ['consigne.peinture.$resultat'],
          donnees: DonneesToile(
            palette: guide
                ? [couleur1, couleur2]
                : [
                    couleur1,
                    couleur2,
                    ...const [
                      'rouge',
                      'jaune',
                      'bleu',
                    ].where((c) => c != couleur1 && c != couleur2),
                  ],
            melanges: _regles,
            couleurObjectif: resultat,
            // La surface ne grossit pas sans fin : une petite zone suffit
            // pour entendre et observer le résultat du mélange.
            cellulesObjectif: 6 + niveau.palier.index * 2 + etape % 2 * 2,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsPeinture = <ClipConsigne>[
  ClipConsigne('act.peinture.titre', 'La peinture qui se mélange'),
  ClipConsigne(
    'consigne.peinture.orange',
    'Peins du rouge, puis ajoute du jaune. Que se passe-t-il ?',
  ),
  ClipConsigne(
    'consigne.peinture.violet',
    'Peins du rouge, puis ajoute du bleu. Que se passe-t-il ?',
  ),
  ClipConsigne(
    'consigne.peinture.vert',
    'Peins du jaune, puis ajoute du bleu. Que se passe-t-il ?',
  ),
];

const activitePeinture = Activite(
  id: 'peinture',
  famille: Famille.creation,
  moteur: Moteur.creation,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.peinture.titre',
  illustration: 'act-peinture.svg',
  source: SourceGenerateur(PeintureGenerateur()),
  clips: clipsPeinture,
  nbItemsMaximum: 3,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 3, choixMax: 3),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 3, choixMax: 3),
  ],
  payload: PayloadToile(),
);
