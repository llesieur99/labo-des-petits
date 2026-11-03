import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 46 — Ranger (moteur M2, bacs).
///
/// Jouets, vêtements, livres : chacun dans son bac. Trier par famille, le
/// vrai geste du rangement.
class RangerGenerateur extends GenerateurManches {
  const RangerGenerateur();

  /// Les familles, avec le concept du bac et ses membres.
  static const familles = <String, List<String>>{
    'ballon': ['ballon', 'doudou', 'tambour', 'fusee', 'poupee', 'grelot'],
    'chaussette': [
      'chaussette',
      'bottes',
      'mitaines',
      'maillot',
      'manteau',
      'echarpe',
      'chapeau',
      'casquette',
      'souliers',
      'gougounes',
    ],
    'livre': ['livre'],
  };

  /// Les paires de bacs, chacune avec sa consigne.
  static const _paires = [
    ('ballon', 'chaussette', 'consigne.ranger.jouets'),
    ('ballon', 'livre', 'consigne.ranger.livres'),
    ('chaussette', 'livre', 'consigne.ranger.vetements_livres'),
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final progression = niveau.numero.clamp(1, 8) - 1;
    // Une nouvelle famille arrive à la fois, avant de les mélanger.
    final paires = switch (progression) {
      0 || 1 => [_paires[0]],
      2 => [_paires[1]],
      3 => [_paires[2]],
      _ => List.of(_paires)..shuffle(alea),
    };
    final manches = <Manche>[];
    final troisBacs = niveau.palier.age >= 6 && progression >= 4;
    final parBac = (1 + progression ~/ 3 + (niveau.palier.age - 4) ~/ 2).clamp(
      1,
      3,
    );
    for (var i = 0; i < niveau.nbItems; i++) {
      final (bac1, bac2, consigne) = paires[i % paires.length];
      final bacs = troisBacs ? familles.keys.toList() : [bac1, bac2];
      final objets = <String>[
        for (final bac in bacs)
          ...(List.of(
            progression == 0 ? familles[bac]!.take(2) : familles[bac]!,
          )..shuffle(alea)).take(parBac),
      ]..shuffle(alea);
      manches.add(
        Manche(
          id: 'ranger.${bacs.join('.')}.${(List.of(objets)..sort()).join('.')}.$i',
          clipsConsigne: [troisBacs ? 'consigne.ranger.trois' : consigne],
          options: [
            for (var o = 0; o < objets.length; o++)
              OptionManche(id: '${objets[o]}$o', concept: objets[o]),
          ],
          donnees: DonneesDepot(
            emplacements: [
              for (var b = 0; b < bacs.length; b++)
                EmplacementDepot(id: 'bac$b', concept: bacs[b]),
            ],
            objets: objets,
            places: {
              for (var b = 0; b < bacs.length; b++) 'bac$b': familles[bacs[b]]!,
            },
            modeBacs: true,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsRanger = <ClipConsigne>[
  ClipConsigne(
    'consigne.ranger.trois',
    'On range ! Les jouets, les vêtements et les livres : chacun dans son bac !',
  ),
  ClipConsigne(
    'consigne.ranger.vetements_livres',
    'On range ! Les vêtements dans un bac, les livres dans l’autre !',
  ),
  ClipConsigne('act.ranger.titre', 'Ranger'),
  ClipConsigne(
    'consigne.ranger.jouets',
    'On range ! Mets les jouets dans un bac, et les vêtements dans l\'autre !',
  ),
  ClipConsigne(
    'consigne.ranger.livres',
    'On range ! Les jouets d\'un côté, les livres de l\'autre !',
  ),
];

const activiteRanger = Activite(
  id: 'ranger',
  famille: Famille.autonomie,
  moteur: Moteur.dropPlace,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.ranger.titre',
  illustration: 'act-ranger.svg',
  source: SourceGenerateur(RangerGenerateur()),
  clips: clipsRanger,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
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
