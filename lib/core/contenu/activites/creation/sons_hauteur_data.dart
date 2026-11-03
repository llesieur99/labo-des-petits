import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 37 — Aigu, grave, fort, doux (moteur M6, mode écoute).
///
/// Un oiseau tout en haut, un ours tout en bas ; un son fort, un son doux.
/// L'oreille choisit — c'est le jeu d'écoute pure de l'app.
class HauteurGenerateur extends GenerateurManches {
  const HauteurGenerateur();

  static const _sonsDir = 'assets/audio/neutre/sons/';

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final etape = (niveau.numero - 1).clamp(0, 7);
    // Les premières étapes isolent hauteur puis intensité. Les grands
    // alternent ensuite les deux questions ; on ne confond jamais les axes.
    final reponses = [true, false]..shuffle(alea);
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        _manche(niveau, etape, i, reponses[(i + etape) % 2]),
    ];
  }

  Manche _manche(Niveau niveau, int etape, int i, bool premiere) {
    final alternance = niveau.palier.index >= 1 && etape >= 4;
    final intensite = alternance
        ? (etape + (etape >= 6 ? i ~/ 2 : i)).isOdd
        : etape % 4 >= 2;
    // Varier le timbre sans ajouter de son ni modifier la bonne réponse.
    final doux = (etape ~/ 4 + i).isOdd;
    final aigu = (etape ~/ 4 + i).isOdd;
    final concepts = intensite ? ['fort', 'doux'] : ['oiseau', 'ours'];
    final sons = intensite
        ? {
            'fort': '$_sonsDir${aigu ? 'aigu' : 'grave'}_fort.wav',
            'doux': '$_sonsDir${aigu ? 'aigu' : 'grave'}_doux.wav',
          }
        : {
            'oiseau': '${_sonsDir}aigu_${doux ? 'doux' : 'fort'}.wav',
            'ours': '${_sonsDir}grave_${doux ? 'doux' : 'fort'}.wav',
          };
    final bonne = concepts[premiere ? 0 : 1];
    return Manche(
      id: 'hauteur.${intensite ? 'intensite' : 'hauteur'}.${sons.values.first}.$bonne.$i',
      options: [for (final c in concepts) OptionManche(id: c, concept: c)],
      clipsConsigne: [
        intensite ? 'consigne.hauteur.g2' : 'consigne.hauteur.g1',
      ],
      donnees: DonneesRythme(
        mode: ModeRythme.ecoute,
        sonsParOption: sons,
        bonneOption: bonne,
      ),
    );
  }
}

const clipsHauteur = <ClipConsigne>[
  ClipConsigne('act.hauteur.titre', 'Aigu, grave, fort, doux'),
  ClipConsigne(
    'consigne.hauteur.g1',
    'Écoute bien ce son ! Qui chante tout en haut, ou qui grogne tout en bas ?',
  ),
  ClipConsigne(
    'consigne.hauteur.g2',
    'Écoute bien ce son ! Est-ce qu\'il est fort, ou est-ce qu\'il est tout doux ?',
  ),
];

const activiteHauteur = Activite(
  id: 'hauteur',
  famille: Famille.creation,
  moteur: Moteur.rythme,
  sensNaturel: Sens.portrait,
  titreCle: 'act.hauteur.titre',
  illustration: 'act-hauteur.svg',
  source: SourceGenerateur(HauteurGenerateur()),
  clips: clipsHauteur,
  nbItemsMaximum: 8,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 5, choixMax: 2),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 6,
      choixMax: 2,
      afficherMots: true,
    ),
  ],
  payload: PayloadRythme(),
);
