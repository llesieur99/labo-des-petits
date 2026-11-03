import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 32 — La figure de Milo (moteur M4, décor 'milo').
///
/// Quelque chose arrive à Milo ; l'enfant choisit son visage, puis une action
/// possible : demander de l'aide, respirer, recommencer. On n'explique pas
/// les émotions, on les traverse.
const clipsMilo = <ClipConsigne>[
  ClipConsigne('act.milo.titre', 'La figure de Milo'),
  ClipConsigne('consigne.milo.g1', 'Regarde ce qui arrive à Milo.'),
  ClipConsigne('consigne.milo.visage', 'Comment se sent Milo ?'),
  ClipConsigne('consigne.milo.action', 'Qu\'est-ce qui peut aider Milo ?'),
  ClipConsigne(
    'milo.1.debut',
    'Milo joue avec son ballon. Le ballon s\'envole dans le ciel et disparaît !',
  ),
  ClipConsigne(
    'milo.2.debut',
    'Milo veut un biscuit, mais la boîte est vide. Il n\'y a plus rien !',
  ),
  ClipConsigne(
    'milo.3.debut',
    'Il fait tout noir. Milo entend un grand bruit : BOUUM !',
  ),
  ClipConsigne(
    'milo.4.debut',
    'Milo fait un casse-tête. Le morceau ne rentre pas, et il tombe par terre.',
  ),
  ClipConsigne(
    'milo.5.debut',
    'Milo retrouve son ami au parc. Il sourit et se sent content.',
  ),
  ClipConsigne(
    'milo.6.debut',
    'Milo a fini sa tour de blocs. Il est content de ce qu’il a construit.',
  ),
  ClipConsigne(
    'milo.7.debut',
    'La tour de Milo tombe. Il est déçu et se sent triste.',
  ),
  ClipConsigne(
    'milo.8.debut',
    'Milo entend le tonnerre. Il a peur et veut rester près de son papa.',
  ),
  ClipConsigne(
    'milo.9.debut',
    'Milo essaie de fermer son manteau. Ça bloque et il commence à se fâcher.',
  ),
  ClipConsigne(
    'milo.10.debut',
    'L’ami de Milo doit rentrer à la maison. Milo est triste de lui dire au revoir.',
  ),
];

Manche _mancheMilo(
  String rang,
  String debut,
  String borneVisage,
  String borneAction,
  Niveau niveau,
) => Manche(
  id: 'milo.$rang',
  clipsConsigne: ['consigne.milo.g1', debut],
  donnees: DonneesScene(
    decor: 'milo',
    etapes: [
      EtapeScene(
        narrationCle: debut,
        visuel: 'visage_content',
        montrerAvant: true,
      ),
      if (niveau.numero <= 3 ||
          niveau.numero >= 6 ||
          borneVisage == 'visage_content')
        EtapeScene(
          narrationCle: 'consigne.milo.visage',
          options: [
            'visage_content',
            'visage_triste',
            'visage_colere',
            'visage_peur',
          ],
          bonneOption: borneVisage,
          autresBonnesOptions: [
            // Les scènes initiales ne nomment pas l'émotion : plusieurs vécus
            // sont possibles. Les nouvelles scènes la disent explicitement.
            if (int.parse(rang) <= 4 && borneVisage == 'visage_triste')
              'visage_colere',
            if (int.parse(rang) <= 4 && borneVisage == 'visage_colere')
              'visage_triste',
          ],
          visuel: borneVisage,
        ),
      if (borneVisage != 'visage_content' && niveau.numero >= 4)
        EtapeScene(
          narrationCle: 'consigne.milo.action',
          options: [
            borneAction,
            if (borneAction != 'respirer') 'respirer',
            'fourchette',
            'camion',
          ],
          bonneOption: borneAction,
          autresBonnesOptions: [if (borneAction != 'respirer') 'respirer'],
          visuel: 'visage_content',
        ),
    ],
  ),
);

const _situationsMilo = [
  ('1', 'visage_triste', 'aide'),
  ('2', 'visage_colere', 'respirer'),
  ('3', 'visage_peur', 'calin'),
  ('4', 'visage_colere', 'recommencer'),
  ('5', 'visage_content', 'aide'),
  ('6', 'visage_content', 'recommencer'),
  ('7', 'visage_triste', 'recommencer'),
  ('8', 'visage_peur', 'aide'),
  ('9', 'visage_colere', 'aide'),
  ('10', 'visage_triste', 'calin'),
];

class MiloGenerateur extends GenerateurManches {
  const MiloGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    // Reconnaître, chercher un soutien, puis relier émotion et soutien.
    // La banque s'élargit avec l'âge et le niveau ; les joies ont leur place.
    final limite = min(
      10,
      max(niveau.nbItems, 4 + niveau.palier.index + niveau.numero),
    );
    final situations = _situationsMilo.take(limite).toList()..shuffle(alea);
    return [
      // La sélection commune doit voir tous les candidats pour repousser
      // les situations récentes avant de limiter la longueur de la partie.
      for (final (rang, visage, action) in situations)
        _mancheMilo(rang, 'milo.$rang.debut', visage, action, niveau),
    ];
  }
}

const activiteMilo = Activite(
  id: 'milo',
  famille: Famille.emotions,
  moteur: Moteur.scene,
  sensNaturel: Sens.portrait,
  titreCle: 'act.milo.titre',
  illustration: 'act-milo.svg',
  source: SourceGenerateur(MiloGenerateur()),
  nbItemsMaximum: 10,
  clips: clipsMilo,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 5, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 6, choixMax: 4),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 6, choixMax: 4),
  ],
  payload: PayloadScene(),
);
