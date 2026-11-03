import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 7 — La lettre en pâte à modeler (moteur M3, trace).
///
/// L'enfant suit le chemin de la lettre avec son doigt. Le tracé d'un
/// enfant de 4 ans tremble : le ruban est très large, on ne juge jamais la
/// beauté — on célèbre l'arrivée au bout.
class LettreGenerateur extends GenerateurManches {
  const LettreGenerateur();

  /// Les lettres par palier, des traits les plus simples aux plus tordus.
  static const lettresParPalier = {
    Palier.a4: ['o', 'c', 's', 'u', 'l'],
    Palier.a5: ['a', 'e', 'i', 'm', 'n', 'r'],
    Palier.a6: ['d', 'p', 'b', 'q', 't', 'f'],
    Palier.a7: ['v', 'w', 'y', 'k', 'x'],
  };

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    // Les nouveaux tracés arrivent par petites familles, avec révision des
    // acquis pour que les longues parties ne soient jamais tronquées.
    final lettres = <String>[
      ...lettresParPalier[niveau.palier]!,
      for (final palier in Palier.values.where(
        (p) => p.index < niveau.palier.index,
      ))
        ...lettresParPalier[palier]!,
    ];
    if (niveau.palier == Palier.a4 && niveau.numero >= 5) {
      lettres.addAll(lettresParPalier[Palier.a5]!.take(niveau.numero - 4));
    }
    final depart = (niveau.numero - 1) % lettres.length;
    final nouvelles = [...lettres.skip(depart), ...lettres.take(depart)];
    final quota = min(nouvelles.length, max(niveau.nbItems, 3));
    lettres
      ..clear()
      ..addAll(nouvelles.take(quota))
      ..shuffle(alea);
    final largeur = switch (niveau.palier) {
      Palier.a4 => 0.34,
      Palier.a5 => 0.30,
      Palier.a6 => 0.26,
      Palier.a7 => 0.22,
    };
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems && i < lettres.length; i++) {
      final lettre = lettres[i];
      manches.add(
        Manche(
          id: 'lettre.$lettre',
          clipsConsigne: ['consigne.lettre.g1', 'lettre.$lettre.dit'],
          donnees: DonneesTrace(
            cheminId: 'lettre.$lettre',
            largeurRuban:
                largeur -
                (niveau.numero - 1) * .008 +
                (niveau.aides.contains(Aide.indiceVisuel) ? .06 : 0),
            departOblige:
                niveau.palier.index >= Palier.a6.index || niveau.numero >= 6,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsLettre = <ClipConsigne>[
  ClipConsigne('act.lettre.titre', 'La lettre en pâte à modeler'),
  ClipConsigne(
    'consigne.lettre.g1',
    'Suis la lettre avec ton doigt, doucement.',
  ),
  ClipConsigne('lettre.o.dit', 'C\'est la lettre o.'),
  ClipConsigne('lettre.c.dit', 'C\'est la lettre c.'),
  ClipConsigne('lettre.s.dit', 'C\'est la lettre s.'),
  ClipConsigne('lettre.u.dit', 'C\'est la lettre u.'),
  ClipConsigne('lettre.l.dit', 'C\'est la lettre l.'),
  ClipConsigne('lettre.a.dit', 'C\'est la lettre a.'),
  ClipConsigne('lettre.e.dit', 'C\'est la lettre e.'),
  ClipConsigne('lettre.i.dit', 'C\'est la lettre i.'),
  ClipConsigne('lettre.m.dit', 'C\'est la lettre m.'),
  ClipConsigne('lettre.n.dit', 'C\'est la lettre n.'),
  ClipConsigne('lettre.r.dit', 'C\'est la lettre r.'),
  ClipConsigne('lettre.d.dit', 'C\'est la lettre d.'),
  ClipConsigne('lettre.p.dit', 'C\'est la lettre p.'),
  ClipConsigne('lettre.b.dit', 'C\'est la lettre b.'),
  ClipConsigne('lettre.q.dit', 'C\'est la lettre q.'),
  ClipConsigne('lettre.t.dit', 'C\'est la lettre t.'),
  ClipConsigne('lettre.f.dit', 'C\'est la lettre f.'),
  ClipConsigne('lettre.v.dit', 'C\'est la lettre v.'),
  ClipConsigne('lettre.w.dit', 'C\'est la lettre w.'),
  ClipConsigne('lettre.y.dit', 'C\'est la lettre y.'),
  ClipConsigne('lettre.k.dit', 'C\'est la lettre k.'),
  ClipConsigne('lettre.x.dit', 'C\'est la lettre x.'),
];

const activiteLettre = Activite(
  id: 'lettre',
  famille: Famille.langue,
  moteur: Moteur.trace,
  sensNaturel: Sens.portrait,
  titreCle: 'act.lettre.titre',
  illustration: 'act-lettre.svg',
  source: SourceGenerateur(LettreGenerateur()),
  clips: clipsLettre,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 5, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 5, choixMax: 2),
  ],
  payload: PayloadTrace(),
);
