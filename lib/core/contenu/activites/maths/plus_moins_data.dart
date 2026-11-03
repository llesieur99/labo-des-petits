import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 13 — Plus, moins, pareil (moteur M4, décor 'objets').
///
/// Deux tas. L'enfant touche le plus gros (ou le plus petit). Les nombres
/// arrivent seulement quand la comparaison est devenue facile.
class PlusMoinsGenerateur extends GenerateurManches {
  const PlusMoinsGenerateur();

  static const _fruits = ['pomme', 'fraise', 'orange', 'raisin', 'banane'];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final age = niveau.palier.index;
    final maximum = min(9, 4 + age + (niveau.numero - 1) ~/ 3);
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems; i++) {
      final fruit =
          _fruits[(i + alea.nextInt(_fruits.length)) % _fruits.length];
      // D'abord des écarts visibles, puis les voisins (4/5, 7/8…).
      final ecart = niveau.numero <= 2
          ? 2
          : niveau.numero <= 5
          ? 1 + i % 2
          : 1;
      final petit = 1 + alea.nextInt(maximum - ecart);
      final grand = petit + ecart;
      final demanderLePlus =
          age == 0 && niveau.numero <= 4 || (i + niveau.numero).isEven;
      final grandAGauche = alea.nextBool();
      final gauche = grandAGauche ? grand : petit;
      final droite = grandAGauche ? petit : grand;
      // Aux derniers niveaux, la quantité doit rester indépendante du fruit.
      final autreFruit = age >= 1 && niveau.numero >= 5
          ? _fruits[(_fruits.indexOf(fruit) + 1) % _fruits.length]
          : fruit;
      final visuel =
          'objets:${List.filled(gauche, fruit).join('|')}//${List.filled(droite, autreFruit).join('|')}';
      manches.add(
        Manche(
          id: 'plusmoins.$fruit.$autreFruit.$gauche.$droite.$demanderLePlus.$i',
          clipsConsigne: const ['consigne.plusmoins.g1'],
          donnees: DonneesScene(
            decor: 'objets',
            etapes: [
              EtapeScene(narrationCle: 'consigne.plusmoins.g1', visuel: visuel),
              EtapeScene(
                narrationCle: demanderLePlus
                    ? 'consigne.plusmoins.plus'
                    : 'consigne.plusmoins.moins',
                options: const ['gauche', 'droite'],
                bonneOption: (demanderLePlus == grandAGauche)
                    ? 'gauche'
                    : 'droite',
                visuel: visuel,
              ),
            ],
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsPlusMoins = <ClipConsigne>[
  ClipConsigne('act.plusmoins.titre', 'Plus, moins, pareil'),
  ClipConsigne('consigne.plusmoins.g1', 'Regarde les deux tas !'),
  ClipConsigne(
    'consigne.plusmoins.plus',
    'Où y a-t-il le PLUS de fruits ? Touche ce côté-là !',
  ),
  ClipConsigne(
    'consigne.plusmoins.moins',
    'Où y a-t-il le MOINS de fruits ? Touche ce côté-là !',
  ),
];

const activitePlusMoins = Activite(
  id: 'plusmoins',
  famille: Famille.maths,
  moteur: Moteur.scene,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.plusmoins.titre',
  illustration: 'act-plusmoins.svg',
  source: SourceGenerateur(PlusMoinsGenerateur()),
  clips: clipsPlusMoins,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 5, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 6, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 6, choixMax: 2),
  ],
  payload: PayloadScene(),
);
