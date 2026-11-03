import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 16 — Formes qui s'emboîtent (moteur M2, appariement).
///
/// Apparier deux formes, puis quatre formes et plusieurs exemplaires de
/// chacune : la place change, la silhouette qui convient reste la même.
class FormesGenerateur extends GenerateurManches {
  const FormesGenerateur();

  static const _formes = [
    'forme_rond',
    'forme_carre',
    'forme_triangle',
    'forme_losange',
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final age = niveau.palier.index;
    final nombreFormes = min(
      age == 0 ? 3 : 4,
      2 + age + (niveau.numero - 1) ~/ 3,
    );
    // Davantage de cases, puis plusieurs exemplaires à apparier : retrouver
    // la forme indépendamment de sa place et de ses voisines.
    final nombreCases = min(
      age == 0 ? 4 : 6,
      nombreFormes +
          (niveau.numero >= 5 ? 1 : 0) +
          (age >= 2 && niveau.numero >= 7 ? 1 : 0),
    );
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems; i++) {
      final formes = List.of(_formes)..shuffle(alea);
      final choisies = [
        for (var f = 0; f < nombreCases; f++) formes[f % nombreFormes],
      ]..shuffle(alea);
      final objets = List.of(choisies)..shuffle(alea);
      manches.add(
        Manche(
          id: 'formes.${choisies.join('-')}.${objets.join('-')}.$i',
          clipsConsigne: const ['consigne.formes.g1'],
          options: [
            for (var o = 0; o < objets.length; o++)
              OptionManche(id: '${objets[o]}$o', concept: objets[o]),
          ],
          donnees: DonneesDepot(
            emplacements: [
              for (var f = 0; f < choisies.length; f++)
                EmplacementDepot(id: 'case$f', concept: choisies[f]),
            ],
            objets: objets,
            places: {
              for (var f = 0; f < choisies.length; f++) 'case$f': [choisies[f]],
            },
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsFormes = <ClipConsigne>[
  ClipConsigne('act.formes.titre', 'Formes qui s\'emboîtent'),
  ClipConsigne(
    'consigne.formes.g1',
    'Chaque forme a sa case. Mets chaque forme dans la bonne case !',
  ),
];

const activiteFormes = Activite(
  id: 'formes',
  famille: Famille.maths,
  moteur: Moteur.dropPlace,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.formes.titre',
  illustration: 'act-formes.svg',
  source: SourceGenerateur(FormesGenerateur()),
  clips: clipsFormes,
  nbItemsMaximum: 6,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 5, choixMax: 3),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 5, choixMax: 3),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 6,
      choixMax: 4,
      afficherMots: true,
    ),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 6,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadDropPlace(),
);
