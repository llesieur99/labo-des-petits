import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 21 — Qu'est-ce qui manque ? (moteur M4, décor 'objets').
///
/// Une scène d'objets, puis un objet disparaît : « Qu'est-ce qui manque ? »
/// Observation avant mémoire pure — la scène reste toujours visible.
class ManqueGenerateur extends GenerateurManches {
  const ManqueGenerateur();

  /// Les scènes possibles (4 objets ; le palier 4 ans en enlèvera un).
  static const _scenes = [
    ['chat', 'ballon', 'fleur', 'pizza'],
    ['mouton', 'sapin', 'soleil', 'gateau'],
    ['loup', 'bateau', 'bougie', 'chocolat'],
    ['lapin', 'maison', 'cadeau', 'poisson'],
    ['souris', 'velo', 'fleur', 'bonbon'],
    ['chat', 'pomme', 'etoile', 'train'],
    ['chat', 'lapin', 'souris', 'loup', 'mouton', 'poisson'],
    ['pomme', 'pizza', 'gateau', 'bonbon', 'chocolat', 'poisson'],
    ['ballon', 'train', 'bateau', 'velo', 'fusee', 'tambour'],
    ['soleil', 'lune', 'etoile', 'sapin', 'fleur', 'caillou'],
    ['chapeau', 'bottes', 'mitaines', 'chaussette', 'maillot', 'sac'],
    ['lit', 'assiette', 'verre', 'bougie', 'cadeau', 'doudou'],
  ];

  /// Des réserve de leurres (des objets qui ne sont PAS dans les scènes).
  static const _leurres = ['hibou', 'caillou', 'papa', 'fusee', 'verre'];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final difficile = niveau.numero >= 5;
    final banque = difficile
        ? _scenes.skip(6).toList()
        : _scenes.take(6).toList();
    final scenes = List.of(banque)..shuffle(alea);
    final manches = <Manche>[];
    final ids = <String>{};
    final taille = (3 + (niveau.palier.age - 4) ~/ 2 + (niveau.numero - 1) ~/ 3)
        .clamp(3, 6);
    for (var i = 0; i < 160 && manches.length < niveau.nbItems; i++) {
      final disponibles = List.of(scenes[i % scenes.length])..shuffle(alea);
      final scene = disponibles.take(taille).toList();
      final manquant = scene[alea.nextInt(scene.length)];
      final restants = scene.where((c) => c != manquant).toList();
      // Les objets encore visibles deviennent des leurres : il faut comparer
      // les deux scènes, plutôt que reconnaître le seul objet familier.
      final leurresDispo = <String>{
        if (niveau.numero >= 3) ...restants,
        ..._leurres.where((c) => !scene.contains(c)),
      }.toList()..shuffle(alea);
      final options = <OptionManche>[
        OptionManche(id: manquant, concept: manquant),
        for (final leurre in leurresDispo.take(niveau.choixMax - 1))
          OptionManche(id: leurre, concept: leurre),
      ]..shuffle(alea);

      final id = 'manque.${scene.join('-')}.$manquant';
      if (!ids.add(id)) continue;
      manches.add(
        Manche(
          id: id,
          clipsConsigne: ['consigne.manque.e1'],
          donnees: DonneesScene(
            decor: 'objets',
            etapes: [
              EtapeScene(
                narrationCle: 'consigne.manque.e1',
                visuel: 'objets:${scene.join('|')}',
              ),
              EtapeScene(
                narrationCle: 'consigne.manque.e2',
                visuel: 'objets:${restants.join('|')}',
              ),
              EtapeScene(
                narrationCle: 'consigne.manque.e3',
                options: [for (final o in options) o.concept],
                bonneOption: manquant,
                visuel: 'objets:${restants.join('|')}',
              ),
            ],
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsManque = <ClipConsigne>[
  ClipConsigne('act.manque.titre', 'Qu\'est-ce qui manque ?'),
  ClipConsigne('consigne.manque.e1', 'Regarde bien tous les objets…'),
  ClipConsigne(
    'consigne.manque.e2',
    'Oh ! Un objet a disparu. Qu\'est-ce qui manque ?',
  ),
  ClipConsigne('consigne.manque.e3', 'Touche l\'objet qui a disparu !'),
];

final activiteManque = Activite(
  id: 'manque',
  famille: Famille.logique,
  moteur: Moteur.scene,
  sensNaturel: Sens.paysage,
  titreCle: 'act.manque.titre',
  illustration: 'act-manque.svg',
  source: SourceGenerateur(ManqueGenerateur()),
  clips: clipsManque,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 5, choixMax: 3),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 6,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
