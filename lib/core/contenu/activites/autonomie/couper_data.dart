import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 43 — Découper avec le doigt (moteur M3, trace).
///
/// Suivre une bande épaisse comme des ciseaux : au bout, ça coupe. Prépare
/// le vrai découpage, sans ciseaux et sans risque.
class CouperGenerateur extends GenerateurManches {
  const CouperGenerateur();

  // Des bandes déjà présentes dans le registre, de la droite à la boucle.
  static const _lignes = [
    'coupe.droite',
    'sentier.ligne',
    'coupe.zigzag',
    'sentier.s',
    'sentier.boucle',
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final progression = niveau.numero.clamp(1, 8) - 1;
    final accessibles = (1 + progression ~/ 2 + (niveau.palier.age - 4) ~/ 2)
        .clamp(1, _lignes.length);
    final lignes = _lignes.take(accessibles).toList()..shuffle(alea);
    final largeur = switch (niveau.palier) {
      Palier.a4 => 0.26,
      Palier.a5 => 0.24,
      Palier.a6 => 0.22,
      Palier.a7 => 0.20,
    };
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems; i++) {
      manches.add(
        Manche(
          id: 'couper.${lignes[i % lignes.length]}.$i',
          clipsConsigne: const ['consigne.couper.g1'],
          donnees: DonneesTrace(
            cheminId: lignes[i % lignes.length],
            largeurRuban: largeur - progression * 0.008,
            departOblige: true,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsCouper = <ClipConsigne>[
  ClipConsigne('act.couper.titre', 'Découper avec le doigt'),
  ClipConsigne(
    'consigne.couper.g1',
    'Suis la ligne avec ton doigt, comme des ciseaux. Pars du point !',
  ),
];

const activiteCouper = Activite(
  id: 'couper',
  famille: Famille.autonomie,
  moteur: Moteur.trace,
  sensNaturel: Sens.paysage,
  titreCle: 'act.couper.titre',
  illustration: 'act-couper.svg',
  source: SourceGenerateur(CouperGenerateur()),
  clips: clipsCouper,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 4, choixMax: 2),
  ],
  payload: PayloadTrace(),
);
