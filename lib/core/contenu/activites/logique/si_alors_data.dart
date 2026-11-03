import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 22 — Si… alors (moteur M1).
///
/// « S'il pleut, le chat prend le parapluie. » L'enfant choisit l'objet qui
/// va avec la situation. Le raisonnement concret avant l'abstraction.
class SiAlorsGenerateur extends GenerateurManches {
  const SiAlorsGenerateur();

  /// (condition, bonne réponse, leurres).
  static const _situations = [
    ('pluie', 'parapluie', ['ballon', 'chocolat', 'tambour']),
    ('soleil', 'lunettes', ['echarpe', 'parapluie', 'bonbon']),
    ('neige', 'echarpe', ['lunettes', 'ballon', 'verre']),
    ('faim', 'poisson', ['chapeau', 'ballon', 'bottes']),
    ('soif', 'verre', ['chaussette', 'sac', 'fusee']),
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final ouverture =
        (niveau.numero - 1 + niveau.palier.age - 4) % _situations.length;
    final nombre = (2 + niveau.numero ~/ 2 + (niveau.palier.age - 4) ~/ 2)
        .clamp(2, _situations.length);
    final situations = [
      for (var j = 0; j < nombre; j++)
        _situations[(ouverture + j) % _situations.length],
    ]..shuffle(alea);
    final manches = <Manche>[];
    final ids = <String>{};
    final faciles = ['ballon', 'tambour', 'fusee', 'lit', 'train'];
    final proches = [
      'parapluie',
      'lunettes',
      'echarpe',
      'verre',
      'poisson',
      'chapeau',
      'bottes',
      'chaussette',
      'sac',
    ];
    for (var i = 0; i < 160 && manches.length < niveau.nbItems; i++) {
      final (condition, bonne, leurres) = situations[i % situations.length];
      // Vers la fin, les distracteurs répondent à une autre condition du jeu.
      final reserve = <String>{
        ...(niveau.numero <= 2 ? faciles : proches),
        ...leurres,
      }.where((c) => c != bonne).toList()..shuffle(alea);
      final options = <OptionManche>[
        OptionManche(id: bonne, concept: bonne),
        for (final leurre in reserve.take(niveau.choixMax - 1))
          OptionManche(id: leurre, concept: leurre),
      ]..shuffle(alea);
      final id =
          'sialors.$condition.${(options.map((o) => o.id).toList()..sort()).join('-')}';
      if (!ids.add(id)) continue;
      manches.add(
        Manche(
          id: id,
          clipsConsigne: ['consigne.sialors.$condition'],
          options: options,
          reperes: [
            switch (condition) {
              'pluie' => 'pluie',
              'soleil' => 'soleil',
              'neige' => 'neige',
              _ => 'chat',
            },
          ],
          bonneOptionId: bonne,
        ),
      );
    }
    return manches;
  }
}

const clipsSiAlors = <ClipConsigne>[
  ClipConsigne('act.sialors.titre', 'Si… alors'),
  ClipConsigne(
    'consigne.sialors.pluie',
    'S\'il pleut, que prend le chat pour sortir ?',
  ),
  ClipConsigne(
    'consigne.sialors.soleil',
    'S\'il fait très beau et très chaud, que met le chat sur ses yeux ?',
  ),
  ClipConsigne(
    'consigne.sialors.neige',
    'S\'il neige et qu\'il fait froid, que met le chat autour du cou ?',
  ),
  ClipConsigne(
    'consigne.sialors.faim',
    'Le chat a très faim. Que mange-t-il ?',
  ),
  ClipConsigne('consigne.sialors.soif', 'Le chat a très soif. Que boit-il ?'),
];

const activiteSiAlors = Activite(
  id: 'sialors',
  famille: Famille.logique,
  moteur: Moteur.tapPick,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.sialors.titre',
  illustration: 'act-sialors.svg',
  source: SourceGenerateur(SiAlorsGenerateur()),
  clips: clipsSiAlors,
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
  payload: PayloadTapPick(),
);
