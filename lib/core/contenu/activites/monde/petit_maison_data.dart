import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 29 — Le petit et sa maison (moteur M2, bacs).
///
/// Où habite chaque animal ? Dans l'eau, dans la forêt ou près de la
/// maison. Classer, pas réciter.
class PetitMaisonGenerateur extends GenerateurManches {
  const PetitMaisonGenerateur();

  /// Les habitats (concept de bac) et leurs habitants.
  static const habitats = <String, List<String>>{
    'eau': ['poisson', 'crevette'],
    'sapin': ['loup', 'hibou', 'ours'],
    'maison': ['chat', 'cochon', 'poule', 'vache', 'mouton', 'poussin'],
  };

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final paires = niveau.numero <= 2
        ? [
            ['eau', 'sapin'],
            ['eau', 'maison'],
          ]
        : [
            ['eau', 'sapin'],
            ['eau', 'maison'],
            ['sapin', 'maison'],
          ];
    final manches = <Manche>[];
    final vus = <String>{};
    var essais = 0;
    while (manches.length < niveau.nbItems && essais++ < 200) {
      final groupes = niveau.palier.age >= 6 && niveau.numero >= 6
          ? ['eau', 'sapin', 'maison']
          : paires[alea.nextInt(paires.length)];
      final parBac = (niveau.choixMax - 1 + (niveau.numero >= 5 ? 1 : 0)).clamp(
        1,
        3,
      );
      final places = <String, List<String>>{
        for (final groupe in groupes)
          groupe: (List.of(
            habitats[groupe]!,
          )..shuffle(alea)).take(parBac).toList(),
      };
      final objets = places.values.expand((o) => o).toList()..shuffle(alea);
      final signature =
          '${groupes.join('.')}.${(List.of(objets)..sort()).join('.')}';
      if (!vus.add(signature)) continue;
      manches.add(
        Manche(
          id: 'petit.$signature',
          clipsConsigne: const ['consigne.petit.g1'],
          options: [
            for (final objet in objets) OptionManche(id: objet, concept: objet),
          ],
          donnees: DonneesDepot(
            emplacements: [
              for (final g in groupes) EmplacementDepot(id: g, concept: g),
            ],
            objets: objets,
            places: places,
            modeBacs: true,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsPetitMaison = <ClipConsigne>[
  ClipConsigne('act.petit.titre', 'Le petit et sa maison'),
  ClipConsigne(
    'consigne.petit.g1',
    'Chaque animal a sa maison. Mets les animaux dans le bon bac !',
  ),
];

const activitePetitMaison = Activite(
  id: 'petit',
  famille: Famille.monde,
  moteur: Moteur.dropPlace,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.petit.titre',
  illustration: 'act-petit.svg',
  source: SourceGenerateur(PetitMaisonGenerateur()),
  clips: clipsPetitMaison,
  nbItemsMaximum: 6,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 5, choixMax: 3),
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
      nbItems: 6,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadDropPlace(),
);
