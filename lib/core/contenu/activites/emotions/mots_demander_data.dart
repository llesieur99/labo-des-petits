import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 34 — Les mots pour demander (moteur M4, décor 'milo').
///
/// « Je voudrais », « à moi après », « stop » : de petites scènes, pas un
/// cours de morale. Milo vit la situation, l'enfant choisit quoi dire.
const clipsMotsDemander = <ClipConsigne>[
  ClipConsigne('act.mots.titre', 'Les mots pour demander'),
  ClipConsigne('consigne.mots.g1', 'Que peut dire Milo ?'),
  ClipConsigne(
    'mots.1.debut',
    'Milo veut jouer avec le ballon de son ami. Son ami le tient dans ses bras.',
  ),
  ClipConsigne(
    'mots.2.debut',
    'Un ami bouscule Milo sans faire exprès. Ça ne fait pas mal, mais Milo n\'aime pas ça.',
  ),
  ClipConsigne(
    'mots.3.debut',
    'Milo attend son tour à la glissoire. Un ami passe devant lui.',
  ),
  ClipConsigne(
    'mots.4.debut',
    'Milo n’arrive pas à fermer son manteau. Il voudrait que son papa l’aide.',
  ),
  ClipConsigne(
    'mots.5.debut',
    'Un ami veut faire un câlin à Milo. Milo ne veut pas de câlin maintenant.',
  ),
  ClipConsigne(
    'mots.6.debut',
    'Son ami joue encore sur la balançoire. Milo est d’accord pour jouer après lui.',
  ),
  ClipConsigne(
    'mots.7.debut',
    'Milo voudrait le crayon bleu. Il appartient à son amie, qui a fini de dessiner.',
  ),
  ClipConsigne(
    'mots.8.debut',
    'Un ami chatouille Milo. Milo ne trouve plus ça amusant et veut que ça s’arrête.',
  ),
  ClipConsigne(
    'mots.9.debut',
    'Milo ne comprend pas son casse-tête. Il voudrait qu’un adulte lui montre comment commencer.',
  ),
];

// Deux formulations peuvent convenir : demander de l'aide n'est jamais
// sanctionné lorsqu'on veut exprimer une limite ou résoudre un conflit.
const _situationsMots = [
  ('1', 'demander', 'attendre'),
  ('2', 'stop', 'aide'),
  ('3', 'demander', 'stop'),
  ('4', 'aide', 'demander'),
  ('5', 'stop', 'aide'),
  ('6', 'attendre', 'demander'),
  ('7', 'demander', 'attendre'),
  ('8', 'stop', 'aide'),
  ('9', 'aide', 'demander'),
];

class MotsDemanderGenerateur extends GenerateurManches {
  const MotsDemanderGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final limite = min(
      9,
      max(niveau.nbItems, 3 + niveau.palier.index + niveau.numero),
    );
    final situations = _situationsMots.take(limite).toList()..shuffle(alea);
    return [
      // Garder toute la banque éligible : preparerPartie choisit les scènes
      // non récentes avant de retenir le nombre de manches demandé.
      for (final (rang, reponse, alternative) in situations)
        Manche(
          id: 'mots.$rang',
          clipsConsigne: ['mots.$rang.debut'],
          donnees: DonneesScene(
            decor: 'milo',
            etapes: [
              EtapeScene(
                narrationCle: 'mots.$rang.debut',
                visuel: 'visage_content',
                montrerAvant: true,
              ),
              EtapeScene(
                narrationCle: 'consigne.mots.g1',
                options: [reponse, alternative, 'dormir', 'fourchette'],
                bonneOption: reponse,
                autresBonnesOptions: [alternative],
                visuel: 'visage_content',
              ),
              // Réinvestir deux situations successives, chacune avec sa
              // narration complète, aux étapes de synthèse.
              if (niveau.numero >= 7) ..._suiteMots(rang),
            ],
          ),
        ),
    ];
  }

  List<EtapeScene> _suiteMots(String rang) {
    final suivant =
        _situationsMots[(int.parse(rang) + 2) % _situationsMots.length];
    return [
      EtapeScene(
        narrationCle: 'mots.${suivant.$1}.debut',
        visuel: 'visage_content',
        montrerAvant: true,
      ),
      EtapeScene(
        narrationCle: 'consigne.mots.g1',
        options: [suivant.$2, suivant.$3, 'dormir', 'fourchette'],
        bonneOption: suivant.$2,
        autresBonnesOptions: [suivant.$3],
        visuel: 'visage_content',
      ),
    ];
  }
}

const activiteMotsDemander = Activite(
  id: 'mots',
  famille: Famille.emotions,
  moteur: Moteur.scene,
  sensNaturel: Sens.portrait,
  titreCle: 'act.mots.titre',
  illustration: 'act-mots.svg',
  source: SourceGenerateur(MotsDemanderGenerateur()),
  nbItemsMaximum: 9,
  clips: clipsMotsDemander,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 5, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 5, choixMax: 4),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 5,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
