import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 12 — La grenouille sur la ligne (moteur M4, décor 'droite').
///
/// Une droite de 0 à 10. « Saute de 2 ! » — les bonds se
/// voient, la réponse se touche.
class GrenouilleGenerateur extends GenerateurManches {
  const GrenouilleGenerateur();

  /// Les nombres disponibles comme réponses (les concepts chiffres 1 à 10).
  static const _nombres = [
    'un',
    'deux',
    'trois',
    'quatre',
    'cinq',
    'six',
    'sept',
    'huit',
    'neuf',
    'dix',
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final age = niveau.palier.index;
    // Petits bonds au début ; puis additions jusqu'à dix et bonds successifs.
    final sautMax = min(3, 1 + age ~/ 2 + (niveau.numero - 1) ~/ 4);
    final maxDroite = min(10, 5 + age + (niveau.numero - 1) ~/ 2);
    final deuxBonds = niveau.numero >= 6 && age >= 1;

    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems; i++) {
      final saut = 1 + alea.nextInt(sautMax);
      final secondSaut = deuxBonds ? 1 + alea.nextInt(sautMax) : 0;
      final depart = alea.nextInt(maxDroite - saut - secondSaut + 1);
      final arrivee = depart + saut + secondSaut;

      // Les options : l'arrivée et ses voisines, sans jamais dépendre du
      // hasard pour remplir (borné et toujours complet).
      final reponses = <int>{arrivee};
      var delta = 1;
      while (reponses.length < niveau.choixMax) {
        if (arrivee - delta >= 1) reponses.add(arrivee - delta);
        if (reponses.length < niveau.choixMax && arrivee + delta <= maxDroite) {
          reponses.add(arrivee + delta);
        }
        delta++;
      }
      final options = <String>[for (final n in reponses) _nombres[n - 1]]
        ..shuffle(alea);

      manches.add(
        Manche(
          id: 'grenouille.$depart.$saut.$secondSaut.$i',
          clipsConsigne: const ['consigne.grenouille.e1'],
          donnees: DonneesScene(
            decor: 'droite',
            etapes: [
              EtapeScene(
                narrationCle: 'consigne.grenouille.e1',
                visuel: 'grenouille_$depart',
              ),
              EtapeScene(
                narrationCle: 'saut.$saut',
                visuel: 'grenouille_${depart + saut}',
              ),
              if (deuxBonds)
                EtapeScene(
                  narrationCle: 'saut.$secondSaut',
                  visuel: 'grenouille_$arrivee',
                ),
              EtapeScene(
                narrationCle: 'consigne.grenouille.e2',
                options: options,
                bonneOption: _nombres[arrivee - 1],
                visuel: 'grenouille_$arrivee',
              ),
            ],
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsGrenouille = <ClipConsigne>[
  ClipConsigne('act.grenouille.titre', 'La grenouille sur la ligne'),
  ClipConsigne(
    'consigne.grenouille.e1',
    'La grenouille est sur la ligne. Regarde bien !',
  ),
  ClipConsigne(
    'consigne.grenouille.e2',
    'Où est-elle arrivée ? Touche le bon nombre !',
  ),
  ClipConsigne('saut.1', 'Elle saute de un !'),
  ClipConsigne('saut.2', 'Elle saute de deux !'),
  ClipConsigne('saut.3', 'Elle saute de trois !'),
];

const activiteGrenouille = Activite(
  id: 'grenouille',
  famille: Famille.maths,
  moteur: Moteur.scene,
  sensNaturel: Sens.paysage,
  titreCle: 'act.grenouille.titre',
  illustration: 'act-grenouille.svg',
  source: SourceGenerateur(GrenouilleGenerateur()),
  clips: clipsGrenouille,
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
  payload: PayloadScene(),
);
