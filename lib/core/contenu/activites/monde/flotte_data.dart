import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 23 — Flotte ou coule (moteur M4, décor 'eau').
///
/// L'enfant devine, puis l'objet tombe dans l'eau : prévoir, vérifier.
/// C'est le premier vrai raisonnement scientifique — et il est drôle.
class FlotteGenerateur extends GenerateurManches {
  const FlotteGenerateur();

  /// Ce qui flotte et ce qui coule (choix simples et vrais).
  static const _banque = <String, bool>{
    'ballon': true,
    'bateau': true,
    'pomme': true,
    'caillou': false,
    'fourchette': false,
    'couteau': false,
  };

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final flottants = _banque.keys.where((o) => _banque[o]!).toList()
      ..shuffle(alea);
    final coulants = _banque.keys.where((o) => !_banque[o]!).toList()
      ..shuffle(alea);
    // Alterner les résultats évite une série qui enseignerait seulement
    // « tout flotte ». Les niveaux avancés comparent deux objets différents.
    final objets = <String>[
      for (var i = 0; i < max(flottants.length, coulants.length); i++) ...[
        if (i < flottants.length) flottants[i],
        if (i < coulants.length) coulants[i],
      ],
    ];
    final manches = <Manche>[];

    for (var i = 0; i < niveau.nbItems && i < objets.length; i++) {
      final objet = objets[i];
      final flotte = _banque[objet]!;
      final bonConcept = flotte ? 'haut' : 'bas';

      manches.add(
        Manche(
          id: 'flotte.$objet${niveau.numero > 4 ? '.comparaison' : ''}',
          clipsConsigne: ['consigne.flotte.g1', 'lex.$objet'],
          donnees: DonneesScene(
            decor: 'eau',
            etapes: [
              EtapeScene(
                narrationCle: 'consigne.flotte.g1',
                options: const ['haut', 'bas'],
                bonneOption: bonConcept,
                visuel: 'objet:$objet',
              ),
              EtapeScene(
                narrationCle: 'consigne.flotte.plouf',
                visuel: '${flotte ? 'flotte' : 'coule'}:$objet',
              ),
              if (niveau.numero > 4) ...[
                EtapeScene(
                  narrationCle: 'consigne.flotte.g1',
                  options: const ['haut', 'bas'],
                  bonneOption: flotte ? 'bas' : 'haut',
                  visuel:
                      'objet:${flotte ? coulants[i % coulants.length] : flottants[i % flottants.length]}',
                  montrerAvant: true,
                ),
                EtapeScene(
                  narrationCle: 'consigne.flotte.plouf',
                  visuel:
                      '${flotte ? 'coule' : 'flotte'}:${flotte ? coulants[i % coulants.length] : flottants[i % flottants.length]}',
                ),
              ],
            ],
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsFlotte = <ClipConsigne>[
  ClipConsigne('act.flotte.titre', 'Flotte ou coule'),
  ClipConsigne(
    'consigne.flotte.g1',
    'Devine : est-ce que ça flotte sur l\'eau, ou est-ce que ça coule au fond ?',
  ),
  ClipConsigne('consigne.flotte.plouf', 'Plouf ! Regarde bien…'),
];

const activiteFlotte = Activite(
  id: 'flotte',
  famille: Famille.monde,
  moteur: Moteur.scene,
  sensNaturel: Sens.portrait,
  titreCle: 'act.flotte.titre',
  illustration: 'act-flotte.svg',
  source: SourceGenerateur(FlotteGenerateur()),
  clips: clipsFlotte,
  nbItemsMaximum: 6,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 5, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 6, choixMax: 2),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 7,
      choixMax: 2,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
