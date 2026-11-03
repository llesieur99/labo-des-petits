import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 33 — À tour de rôle (moteur M1 en mode « tours »).
///
/// Deux enfants, une tablette. L'app donne le tour, annonce à qui c'est,
/// et l'autre moitié de l'écran ne répond pas. Rare, et très demandé dans
/// une fratrie.
class ToursGenerateur extends GenerateurManches {
  const ToursGenerateur();

  /// Des désignations simples, comprises de deux joueurs de 4 ans.
  static const _familles = [
    [
      'chat',
      'souris',
      'poisson',
      'lapin',
      'poule',
      'mouton',
      'cochon',
      'oiseau',
    ],
    [
      'pomme',
      'gateau',
      'chou',
      'pizza',
      'chocolat',
      'bonbon',
      'beurre',
      'oeuf',
    ],
    [
      'chapeau',
      'casquette',
      'manteau',
      'mitaines',
      'bottes',
      'echarpe',
      'souliers',
      'chaussette',
    ],
    ['bateau', 'velo', 'moto', 'camion', 'bus', 'train', 'fusee'],
    ['soleil', 'lune', 'etoile', 'nuage', 'pluie', 'neige', 'fleur', 'sapin'],
    [
      'maison',
      'lit',
      'verre',
      'assiette',
      'fourchette',
      'pot',
      'sac',
      'doudou',
    ],
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final manches = <Manche>[];
    // Chaque étape découvre une famille ; les dernières les mélangent.
    // Les leurres voisins arrivent après les premiers échanges très distincts.
    final etape = niveau.numero.clamp(1, 8) - 1;
    final depart = (etape + niveau.palier.index) % _familles.length;
    final banque = [
      ..._familles[depart],
      ..._familles[(depart + 1) % _familles.length],
      if (etape >= 6) ..._familles[(depart + 2) % _familles.length],
    ];
    final cibles = List<String>.of(banque)..shuffle(alea);

    for (final cible in cibles.take(niveau.nbItems)) {
      final famille = _familles.firstWhere((f) => f.contains(cible));
      final voisins = famille.where((c) => c != cible).toList()..shuffle(alea);
      final eloignes = banque.where((c) => !famille.contains(c)).toList()
        ..shuffle(alea);

      final leurres =
          (etape < 3 ? [...eloignes, ...voisins] : [...voisins, ...eloignes])
              .take(niveau.choixMax - 1)
              .toList();

      final options = <OptionManche>[
        OptionManche(id: cible, concept: cible),
        for (final l in leurres) OptionManche(id: l, concept: l),
      ]..shuffle(alea);

      manches.add(
        Manche(
          id: 'tours.$cible',
          clipsConsigne: ['consigne.tours.g1', 'lex.$cible'],
          options: options,
          bonneOptionId: cible,
        ),
      );
    }
    return manches;
  }
}

const clipsTours = <ClipConsigne>[
  ClipConsigne('act.tours.titre', 'À tour de rôle'),
  ClipConsigne('consigne.tours.g1', 'Trouve :'),
  ClipConsigne('consigne.tours.mien', 'À toi !'),
  ClipConsigne('consigne.tours.autre', 'À l\'autre !'),
];

const activiteTours = Activite(
  id: 'tours',
  famille: Famille.emotions,
  moteur: Moteur.tapPick,
  sensNaturel: Sens.paysage,
  titreCle: 'act.tours.titre',
  illustration: 'act-tours.svg',
  source: SourceGenerateur(ToursGenerateur()),
  clips: clipsTours,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 6, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 8, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 8, choixMax: 3),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 10, choixMax: 4),
  ],
  payload: PayloadTapPick(tours: true),
);
