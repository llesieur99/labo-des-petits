import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 4 — La phrase en images (moteur M2).
///
/// Il place « le chat / mange / la pomme » dans les trois cases, et l'app
/// prononce la phrase. Plus tard, les mots écrits remplaceront les images.
const clipsPhrase = <ClipConsigne>[
  ClipConsigne('act.phrase.titre', 'La phrase en images'),
  ClipConsigne('consigne.phrase.g1', 'Place les images pour faire la phrase :'),
  ClipConsigne('mot.mange', 'mange'),
  ClipConsigne('mot.dort', 'dort'),
  ClipConsigne('mot.joue', 'joue'),
  ClipConsigne('phrase.chat.dite', 'Le chat mange la pomme !'),
  ClipConsigne('phrase.lapin.dite', 'Le lapin dort dans son lit !'),
  ClipConsigne('phrase.vache.dite', 'La vache mange le chou !'),
  ClipConsigne('phrase.poussin.dite', 'Le poussin dort dans son nid !'),
  ClipConsigne('phrase.souris.dite', 'La souris joue avec le doudou !'),
];

const _phrases = <Manche>[
  Manche(
    id: 'phrase.chat',
    clipsConsigne: ['consigne.phrase.g1', 'phrase.chat.dite'],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['chat', 'assiette', 'pomme'],
      places: {
        'c1': ['chat'],
        'c2': ['assiette'],
        'c3': ['pomme'],
      },
      finCle: 'phrase.chat.dite',
    ),
  ),
  Manche(
    id: 'phrase.lapin',
    clipsConsigne: ['consigne.phrase.g1', 'phrase.lapin.dite'],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['lapin', 'dormir', 'lit'],
      places: {
        'c1': ['lapin'],
        'c2': ['dormir'],
        'c3': ['lit'],
      },
      finCle: 'phrase.lapin.dite',
    ),
  ),
  Manche(
    id: 'phrase.vache',
    clipsConsigne: ['consigne.phrase.g1', 'phrase.vache.dite'],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['vache', 'assiette', 'chou'],
      places: {
        'c1': ['vache'],
        'c2': ['assiette'],
        'c3': ['chou'],
      },
      finCle: 'phrase.vache.dite',
    ),
  ),
  Manche(
    id: 'phrase.poussin',
    clipsConsigne: ['consigne.phrase.g1', 'phrase.poussin.dite'],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['poussin', 'dormir', 'nid'],
      places: {
        'c1': ['poussin'],
        'c2': ['dormir'],
        'c3': ['nid'],
      },
      finCle: 'phrase.poussin.dite',
    ),
  ),
  Manche(
    id: 'phrase.souris',
    clipsConsigne: ['consigne.phrase.g1', 'phrase.souris.dite'],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['souris', 'ballon', 'doudou'],
      places: {
        'c1': ['souris'],
        'c2': ['ballon'],
        'c3': ['doudou'],
      },
      finCle: 'phrase.souris.dite',
    ),
  ),
  // Phrases grammaticales composées de clips existants (déterminants inclus).
  Manche(
    id: 'phrase.papa.mange.banane',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.papa',
      'mot.mange',
      'lex.banane',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['papa', 'assiette', 'banane'],
      places: {
        'c1': ['papa'],
        'c2': ['assiette'],
        'c3': ['banane'],
      },
    ),
  ),
  Manche(
    id: 'phrase.papa.mange.fraise',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.papa',
      'mot.mange',
      'lex.fraise',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['papa', 'assiette', 'fraise'],
      places: {
        'c1': ['papa'],
        'c2': ['assiette'],
        'c3': ['fraise'],
      },
    ),
  ),
  Manche(
    id: 'phrase.papa.mange.raisin',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.papa',
      'mot.mange',
      'lex.raisin',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['papa', 'assiette', 'raisin'],
      places: {
        'c1': ['papa'],
        'c2': ['assiette'],
        'c3': ['raisin'],
      },
    ),
  ),
  Manche(
    id: 'phrase.monstre.mange.banane',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.monstre',
      'mot.mange',
      'lex.banane',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['monstre', 'assiette', 'banane'],
      places: {
        'c1': ['monstre'],
        'c2': ['assiette'],
        'c3': ['banane'],
      },
    ),
  ),
  Manche(
    id: 'phrase.monstre.mange.fraise',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.monstre',
      'mot.mange',
      'lex.fraise',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['monstre', 'assiette', 'fraise'],
      places: {
        'c1': ['monstre'],
        'c2': ['assiette'],
        'c3': ['fraise'],
      },
    ),
  ),
  Manche(
    id: 'phrase.monstre.mange.raisin',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.monstre',
      'mot.mange',
      'lex.raisin',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['monstre', 'assiette', 'raisin'],
      places: {
        'c1': ['monstre'],
        'c2': ['assiette'],
        'c3': ['raisin'],
      },
    ),
  ),
  Manche(
    id: 'phrase.ours.mange.banane',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.ours',
      'mot.mange',
      'lex.banane',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['ours', 'assiette', 'banane'],
      places: {
        'c1': ['ours'],
        'c2': ['assiette'],
        'c3': ['banane'],
      },
    ),
  ),
  Manche(
    id: 'phrase.ours.mange.fraise',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.ours',
      'mot.mange',
      'lex.fraise',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['ours', 'assiette', 'fraise'],
      places: {
        'c1': ['ours'],
        'c2': ['assiette'],
        'c3': ['fraise'],
      },
    ),
  ),
  Manche(
    id: 'phrase.ours.mange.raisin',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.ours',
      'mot.mange',
      'lex.raisin',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
      ],
      objets: ['ours', 'assiette', 'raisin'],
      places: {
        'c1': ['ours'],
        'c2': ['assiette'],
        'c3': ['raisin'],
      },
    ),
  ),
  Manche(
    id: 'phrase.papa.dort.train',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.papa',
      'mot.dort',
      'lex.dans',
      'lex.train',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
        EmplacementDepot(id: 'c4', concept: 'casier'),
      ],
      objets: ['papa', 'dormir', 'dans', 'train'],
      places: {
        'c1': ['papa'],
        'c2': ['dormir'],
        'c3': ['dans'],
        'c4': ['train'],
      },
    ),
  ),
  Manche(
    id: 'phrase.monstre.dort.train',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.monstre',
      'mot.dort',
      'lex.dans',
      'lex.train',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
        EmplacementDepot(id: 'c4', concept: 'casier'),
      ],
      objets: ['monstre', 'dormir', 'dans', 'train'],
      places: {
        'c1': ['monstre'],
        'c2': ['dormir'],
        'c3': ['dans'],
        'c4': ['train'],
      },
    ),
  ),
  Manche(
    id: 'phrase.ours.dort.train',
    clipsConsigne: [
      'consigne.phrase.g1',
      'lex.ours',
      'mot.dort',
      'lex.dans',
      'lex.train',
    ],
    donnees: DonneesDepot(
      emplacements: [
        EmplacementDepot(id: 'c1', concept: 'casier'),
        EmplacementDepot(id: 'c2', concept: 'casier'),
        EmplacementDepot(id: 'c3', concept: 'casier'),
        EmplacementDepot(id: 'c4', concept: 'casier'),
      ],
      objets: ['ours', 'dormir', 'dans', 'train'],
      places: {
        'c1': ['ours'],
        'c2': ['dormir'],
        'c3': ['dans'],
        'c4': ['train'],
      },
    ),
  ),
];

class PhraseGenerateur extends GenerateurManches {
  const PhraseGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final quatreCases = niveau.palier.index >= 2 || niveau.numero >= 5;
    final disponibles = _phrases
        .where(
          (m) => quatreCases || (m.donnees as DonneesDepot).objets.length == 3,
        )
        .toList();
    final depart = (niveau.numero - 1) * 2 % disponibles.length;
    final fenetre = [...disponibles.skip(depart), ...disponibles.take(depart)];
    final choisies = fenetre.take(niveau.nbItems).toList();
    if (quatreCases &&
        !choisies.any((m) => (m.donnees as DonneesDepot).objets.length == 4)) {
      choisies[choisies.length - 1] = disponibles.last;
    }
    return choisies..shuffle(alea);
  }
}

const activitePhrase = Activite(
  id: 'phrase',
  famille: Famille.langue,
  moteur: Moteur.dropPlace,
  sensNaturel: Sens.paysage,
  titreCle: 'act.phrase.titre',
  illustration: 'act-phrase.svg',
  source: SourceGenerateur(PhraseGenerateur()),
  clips: clipsPhrase,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 3),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 5,
      choixMax: 3,
      afficherMots: true,
    ),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 5,
      choixMax: 3,
      afficherMots: true,
    ),
  ],
  payload: PayloadDropPlace(),
);
