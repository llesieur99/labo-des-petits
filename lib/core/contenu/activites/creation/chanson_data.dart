import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 38 — Chanson de quatre cases (moteur M5, mode composer).
///
/// L'enfant aligne quatre sons, l'app rejoue sa boucle — deux fois, comme
/// un refrain. Création pure : aucune réponse fausse, jamais.
class ChansonGenerateur extends GenerateurManches {
  const ChansonGenerateur();

  static const _sonsDir = 'assets/audio/neutre/sons/';

  // Huit petits orchestres : les quatre cases et la liberté de composer
  // restent les mêmes. Les sons sont tous déjà livrés hors ligne.
  static const _orchestres = [
    ['tambour', 'grelot', 'oiseau', 'ours'],
    ['grelot', 'oiseau', 'monstre', 'tambour'],
    ['oiseau', 'ours', 'grelot', 'monstre'],
    ['ours', 'tambour', 'monstre', 'oiseau'],
    ['tambour', 'oiseau', 'grelot', 'ours'],
    ['grelot', 'ours', 'tambour', 'monstre'],
    ['oiseau', 'monstre', 'ours', 'grelot'],
    ['monstre', 'tambour', 'oiseau', 'ours'],
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final etape = (niveau.numero - 1).clamp(0, 7);
    final nombre = min(4, 2 + niveau.palier.index + etape ~/ 4);
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        Manche(
          id: 'chanson.${niveau.palier.id}.${niveau.numero}.$i',
          clipsConsigne: const ['consigne.chanson.g1'],
          donnees: DonneesComposer(
            cases: 4,
            sons: {
              for (final concept in _orchestres[(etape + i) % 8].take(nombre))
                concept:
                    '$_sonsDir${switch (concept) {
                      'oiseau' => etape < 4 ? 'aigu_doux' : 'aigu_fort',
                      'ours' => etape < 4 ? 'grave_doux' : 'grave_fort',
                      'monstre' => 'grogne',
                      _ => concept,
                    }}.wav',
            },
            bravoCle: 'chanson.bravo',
          ),
        ),
    ];
  }
}

const clipsChanson = <ClipConsigne>[
  ClipConsigne('act.chanson.titre', 'Chanson de quatre cases'),
  ClipConsigne(
    'consigne.chanson.g1',
    'Place quatre sons dans les cases. Après, on écoute ta chanson !',
  ),
  ClipConsigne('chanson.bravo', 'Ta chanson est belle ! Écoutons-la encore !'),
];

const activiteChanson = Activite(
  id: 'chanson',
  famille: Famille.creation,
  moteur: Moteur.ordre,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.chanson.titre',
  illustration: 'act-chanson.svg',
  source: SourceGenerateur(ChansonGenerateur()),
  clips: clipsChanson,
  nbItemsMaximum: 2,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 1, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 1, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 2, choixMax: 2),
  ],
  payload: PayloadComposer(),
);
