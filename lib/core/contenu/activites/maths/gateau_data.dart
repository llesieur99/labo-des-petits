import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 10 — Partager le gâteau (moteur M4, décor 'gateau').
///
/// Un gâteau, deux amis, puis quatre : moitiés et quarts avec les yeux et
/// les doigts, jamais avec des fractions écrites.
const clipsGateau = <ClipConsigne>[
  ClipConsigne('act.gateau.titre', 'Partager le gâteau'),
  ClipConsigne('consigne.gateau.g1', 'Regarde le gâteau…'),
  ClipConsigne(
    'consigne.gateau.deux',
    'Deux amis veulent chacun la même part. En combien de parts coupe-t-on le gâteau ?',
  ),
  ClipConsigne(
    'consigne.gateau.quatre',
    'Maintenant, quatre amis veulent chacun la même part. En combien de parts coupe-t-on le gâteau ?',
  ),
];

/// Les deux découpes que le décor et les voix savent vraiment représenter.
/// On passe du partage guidé à l'alternance, puis à deux demandes successives.
class GateauGenerateur extends GenerateurManches {
  const GateauGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final age = niveau.palier.index;
    final doublePartage = niveau.numero >= 6 && age >= 1;
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        _manche(niveau, i, age, doublePartage, alea),
    ];
  }

  Manche _manche(
    Niveau niveau,
    int i,
    int age,
    bool doublePartage,
    Random alea,
  ) {
    final premier = age == 0 && niveau.numero <= 2
        ? 2
        : ((i + niveau.numero).isEven ? 2 : 4);
    final partages = [premier, if (doublePartage) 6 - premier];
    final etapes = <EtapeScene>[];
    for (final parts in partages) {
      final autres = [
        for (var n = 1; n <= (age >= 2 ? 6 : 4); n++)
          if (n != parts) n,
      ];
      if (niveau.numero >= 4) {
        autres.sort((a, b) => (a - parts).abs().compareTo((b - parts).abs()));
      } else {
        autres.shuffle(alea);
      }
      final nombres = [parts, ...autres.take(niveau.choixMax - 1)]
        ..shuffle(alea);
      etapes.add(
        const EtapeScene(
          narrationCle: 'consigne.gateau.g1',
          visuel: 'gateau_entier',
        ),
      );
      etapes.add(
        EtapeScene(
          narrationCle: parts == 2
              ? 'consigne.gateau.deux'
              : 'consigne.gateau.quatre',
          options: [for (final n in nombres) _nombres[n - 1]],
          bonneOption: _nombres[parts - 1],
          visuel: 'gateau_$parts',
        ),
      );
    }
    return Manche(
      id: 'gateau.${partages.join('-')}.${etapes.where((e) => e.options.isNotEmpty).map((e) => e.options.join('-')).join('_')}.$i',
      clipsConsigne: const ['consigne.gateau.g1'],
      donnees: DonneesScene(decor: 'gateau', etapes: etapes),
    );
  }

  static const _nombres = ['un', 'deux', 'trois', 'quatre', 'cinq', 'six'];
}

const activiteGateau = Activite(
  id: 'gateau',
  famille: Famille.maths,
  moteur: Moteur.scene,
  sensNaturel: Sens.portrait,
  titreCle: 'act.gateau.titre',
  illustration: 'act-gateau.svg',
  source: SourceGenerateur(GateauGenerateur()),
  clips: clipsGateau,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 4,
      choixMax: 3,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
