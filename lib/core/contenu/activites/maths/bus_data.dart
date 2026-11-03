import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 8 — Le bus des amis (moteur M4, scène animée).
///
/// Des amis montent, d'autres descendent : « Combien restent ? » L'addition
/// et la soustraction deviennent une histoire qu'on voit, avant tout chiffre.
class BusGenerateur extends GenerateurManches {
  const BusGenerateur();

  static const _nombres = ['un', 'deux', 'trois', 'quatre', 'cinq'];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final age = niveau.palier.index;
    final numero = niveau.numero;
    // Les petits découvrent une montée, puis deux. Les plus grands gardent
    // le total en mémoire à travers jusqu'à quatre arrêts (toujours 1..5).
    final changements = min(4, 1 + (age + 1) ~/ 2 + (numero - 1) ~/ 3);
    final maxTotal = min(5, 2 + age + (numero - 1) ~/ 3);
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems; i++) {
      var total = 0;
      final etapes = <EtapeScene>[];
      final histoire = <String>[];
      for (var arret = 0; arret < changements; arret++) {
        final peutDescendre = total > 1 && (age > 0 || numero >= 4);
        final descend =
            peutDescendre && (total == maxTotal || (arret + i + numero).isEven);
        // On garde un passager : zéro n'est pas encore une réponse du lexique.
        final quantite = descend
            ? 1 + alea.nextInt(min(total - 1, age >= 2 || numero >= 5 ? 2 : 1))
            : 1 + alea.nextInt(min(3, maxTotal - total));
        total += descend ? -quantite : quantite;
        final cle = 'consigne.bus.${descend ? 'descend' : 'monte'}$quantite';
        histoire.add('${descend ? 'd' : 'm'}$quantite');
        etapes.add(EtapeScene(narrationCle: cle, visuel: 'passagers_$total'));
      }
      final leurres = [
        for (var n = 1; n <= 5; n++)
          if (n != total) n,
      ];
      if (numero < 5) {
        leurres.shuffle(alea);
      } else {
        leurres.sort((a, b) => (a - total).abs().compareTo((b - total).abs()));
      }
      final options = [total, ...leurres.take(min(5, niveau.choixMax) - 1)]
        ..shuffle(alea);
      etapes.add(
        EtapeScene(
          narrationCle: 'consigne.bus.combien',
          options: [for (final n in options) _nombres[n - 1]],
          bonneOption: _nombres[total - 1],
        ),
      );
      manches.add(
        Manche(
          id: 'bus.${histoire.join('-')}.$i',
          clipsConsigne: ['consigne.bus.g1', etapes.first.narrationCle],
          donnees: DonneesScene(decor: 'bus', etapes: etapes),
        ),
      );
    }
    return manches;
  }
}

const clipsBus = <ClipConsigne>[
  ClipConsigne('act.bus.titre', 'Le bus des amis'),
  ClipConsigne('consigne.bus.g1', 'Écoute bien l\'histoire du bus.'),
  ClipConsigne('consigne.bus.monte1', 'Un ami monte dans le bus.'),
  ClipConsigne('consigne.bus.monte2', 'Deux amis montent dans le bus.'),
  ClipConsigne('consigne.bus.monte3', 'Trois amis montent dans le bus.'),
  ClipConsigne('consigne.bus.descend1', 'Un ami descend du bus.'),
  ClipConsigne('consigne.bus.descend2', 'Deux amis descendent du bus.'),
  ClipConsigne('consigne.bus.combien', 'Combien d\'amis restent dans le bus ?'),
];

const activiteBus = Activite(
  id: 'bus',
  famille: Famille.maths,
  moteur: Moteur.scene,
  sensNaturel: Sens.paysage,
  titreCle: 'act.bus.titre',
  illustration: 'act-bus.svg',
  source: SourceGenerateur(BusGenerateur()),
  clips: clipsBus,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 5, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 6, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 6, choixMax: 3),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 7, choixMax: 4),
  ],
  payload: PayloadScene(),
);
