import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 24 — Les ombres (moteur M4, décor 'ombre').
///
/// La lampe se déplace, l'ombre change de côté. Où est l'ombre quand la
/// lampe est à gauche ? La lumière se comprend avec les yeux.
const clipsOmbres = <ClipConsigne>[
  ClipConsigne('act.ombres.titre', 'Les ombres'),
  ClipConsigne('consigne.ombres.g1', 'Regarde bien la lampe et l\'ombre…'),
  ClipConsigne(
    'consigne.ombres.g2',
    'La lampe brille d\'un côté. De quel côté est l\'ombre ?',
  ),
];

Manche _mancheOmbre(String id, String positionLampe, String objet) => Manche(
  id: 'ombres.$id',
  clipsConsigne: const ['consigne.ombres.g1'],
  donnees: DonneesScene(
    decor: 'ombre',
    etapes: [
      EtapeScene(
        narrationCle: 'consigne.ombres.g1',
        visuel: 'lampe_$positionLampe:$objet',
      ),
      EtapeScene(
        narrationCle: 'consigne.ombres.g2',
        options: ['gauche', 'droite'],
        bonneOption: positionLampe == 'gauche' ? 'droite' : 'gauche',
        visuel: 'lampe_$positionLampe:$objet',
      ),
    ],
  ),
);

class OmbresGenerateur extends GenerateurManches {
  const OmbresGenerateur();
  static const objets = [
    'ballon',
    'doudou',
    'chat',
    'sapin',
    'bateau',
    'pomme',
    'maison',
    'fleur',
    'velo',
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    // Les objets du lexique ont des silhouettes différentes. Le dernier
    // palier vérifie aussi le déplacement de la lampe autour du même objet.
    final banque = List.of(objets)..shuffle(alea);
    final manches = <Manche>[];
    for (final objet in banque) {
      for (final cote in ['gauche', 'droite']) {
        final premiere = _mancheOmbre('$objet.$cote', cote, objet);
        final etapes = (premiere.donnees as DonneesScene).etapes;
        manches.add(
          Manche(
            id: 'ombres.$objet.$cote.${niveau.numero > 4 ? 'retour' : 'simple'}',
            clipsConsigne: premiere.clipsConsigne,
            donnees: DonneesScene(
              decor: 'ombre',
              etapes: [
                ...etapes,
                if (niveau.numero > 4)
                  ...(_mancheOmbre(
                            'retour',
                            cote == 'gauche' ? 'droite' : 'gauche',
                            objet,
                          ).donnees
                          as DonneesScene)
                      .etapes,
              ],
            ),
          ),
        );
      }
    }
    return manches..shuffle(alea);
  }
}

final activiteOmbres = Activite(
  id: 'ombres',
  famille: Famille.monde,
  moteur: Moteur.scene,
  sensNaturel: Sens.paysage,
  titreCle: 'act.ombres.titre',
  illustration: 'act-ombres.svg',
  source: SourceGenerateur(OmbresGenerateur()),
  clips: clipsOmbres,
  nbItemsMaximum: 6,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 4,
      choixMax: 2,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
