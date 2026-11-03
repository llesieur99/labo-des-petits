import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Une petite histoire : les cases dans l'ordre, et sa narration.
class Histoire {
  final String id;
  final List<String> cases;
  final String narrationCle;

  const Histoire(this.id, this.cases, this.narrationCle);
}

/// La banque d'histoires — toutes avec des concepts déjà illustrés.
const banqueHistoires = <Histoire>[
  Histoire('plante', [
    'graine',
    'eau',
    'soleil',
    'fleur',
  ], 'histoire.plante.raconte'),
  Histoire('poussin', ['oeuf', 'poussin', 'poule'], 'histoire.poussin.raconte'),
  Histoire('papillon', [
    'oeuf',
    'chenille',
    'papillon',
  ], 'histoire.papillon.raconte'),
  Histoire('chat', [
    'lit',
    'chat',
    'assiette',
    'ballon',
  ], 'histoire.chat.raconte'),
  Histoire('soiree', [
    'soleil',
    'lune',
    'etoile',
    'dormir',
  ], 'histoire.soiree.raconte'),
  Histoire('matin', ['soleil', 'cafe', 'sac'], 'histoire.matin.raconte'),
];

/// Activité 5 — Histoire en quatre cases (moteur M5).
///
/// Remettre des images dans l'ordre : ça travaille le récit (avant, après),
/// pas le décodage. L'app raconte l'histoire à la fin.
class HistoireGenerateur extends GenerateurManches {
  const HistoireGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final longueur =
        (2 + (niveau.palier.age - 4) ~/ 2 + (niveau.numero >= 5 ? 1 : 0)).clamp(
          2,
          4,
        );
    // Des épisodes consécutifs gardent la chronologie et la narration d'origine.
    // Les histoires complètes arrivent après les relations avant/après.
    final episodes = <(Histoire, List<String>)>[];
    for (final histoire in banqueHistoires) {
      final taille = min(longueur, histoire.cases.length);
      for (var debut = 0; debut <= histoire.cases.length - taille; debut++) {
        episodes.add((histoire, histoire.cases.sublist(debut, debut + taille)));
      }
    }
    episodes.shuffle(alea);
    final manches = <Manche>[];
    for (final (histoire, cases) in episodes.take(niveau.nbItems)) {
      final melangees = List.of(cases)..shuffle(alea);
      manches.add(
        Manche(
          id: 'histoire.${histoire.id}.${cases.join("-")}',
          clipsConsigne: ['consigne.histoire.g1'],
          options: [for (final c in melangees) OptionManche(id: c, concept: c)],
          donnees: DonneesOrdre(
            cases: cases,
            narrationCle: histoire.narrationCle,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsHistoire = <ClipConsigne>[
  ClipConsigne('act.histoire.titre', 'L\'histoire en quatre cases'),
  ClipConsigne(
    'consigne.histoire.g1',
    'Remets l\'histoire dans l\'ordre. Commence par le début !',
  ),
  ClipConsigne(
    'histoire.plante.raconte',
    'On met la graine dans la terre, on l\'arrose, le soleil la réchauffe, et une belle fleur pousse !',
  ),
  ClipConsigne(
    'histoire.poussin.raconte',
    'Dans l\'œuf, il y avait un petit poussin. Il casse la coquille, et il devient une belle poule !',
  ),
  ClipConsigne(
    'histoire.papillon.raconte',
    'Un petit œuf devient une chenille, et la chenille devient un beau papillon !',
  ),
  ClipConsigne(
    'histoire.chat.raconte',
    'Le chat dormait dans son lit. Il se réveille, il mange, et il va jouer avec son ballon !',
  ),
  ClipConsigne(
    'histoire.soiree.raconte',
    'Le soleil se couche, la lune se lève, les étoiles apparaissent… et on va dormir !',
  ),
  ClipConsigne(
    'histoire.matin.raconte',
    'Le matin, le soleil se lève, on prend un bon café, et on prépare le sac pour l\'école !',
  ),
];

const activiteHistoire = Activite(
  id: 'histoire',
  famille: Famille.logique,
  moteur: Moteur.ordre,
  sensNaturel: Sens.paysage,
  titreCle: 'act.histoire.titre',
  illustration: 'act-histoire.svg',
  source: SourceGenerateur(HistoireGenerateur()),
  clips: clipsHistoire,
  niveaux: [
    Niveau(
      palier: Palier.a4,
      numero: 1,
      nbItems: 2,
      choixMax: 3,
      aides: [Aide.narrationAvant],
    ),
    Niveau(
      palier: Palier.a5,
      numero: 1,
      nbItems: 3,
      choixMax: 4,
      aides: [Aide.narrationAvant],
    ),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 3,
      choixMax: 4,
      afficherMots: true,
    ),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 4,
      choixMax: 5,
      afficherMots: true,
    ),
  ],
  payload: PayloadOrdre(),
);
