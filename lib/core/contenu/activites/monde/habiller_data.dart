import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 27 — S'habiller pour sortir (moteur M2, deux bacs de tri).
///
/// L'enfant trie les affaires : celles de l'hiver dans le bac à neige,
/// celles de l'été dans le bac au soleil. Utile chaque matin, surtout l'hiver.
class HabillerGenerateur extends GenerateurManches {
  const HabillerGenerateur();

  /// Les affaires, avec leur bac.
  static const _hiver = ['manteau', 'mitaines', 'bottes', 'echarpe'];
  static const _ete = ['maillot', 'gougounes', 'lunettes', 'chapeau'];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final manches = <Manche>[];
    final vus = <String>{};
    var essais = 0;
    while (manches.length < niveau.nbItems && essais++ < 200) {
      // Les deux saisons sont toujours représentées. Les derniers niveaux
      // utilisent aussi des groupes de tailles différentes.
      final parBac = niveau.numero < 4
          ? niveau.choixMax.clamp(1, 3)
          : (niveau.choixMax + (niveau.numero >= 5 ? 1 : 0)).clamp(
              1,
              4,
            ); // 2 à 4 par bac selon l'âge
      final hiver = List.of(_hiver)..shuffle(alea);
      final ete = List.of(_ete)..shuffle(alea);
      final objets = <String>[
        ...hiver.take(niveau.numero >= 4 ? 1 + alea.nextInt(parBac) : parBac),
        ...ete.take(niveau.numero >= 4 ? 1 + alea.nextInt(parBac) : parBac),
      ]..shuffle(alea);

      final signature = (List.of(objets)..sort()).join('.');
      if (!vus.add(signature)) continue;
      manches.add(
        Manche(
          id: 'habiller.${(List.of(objets)..sort()).join('.')}',
          clipsConsigne: ['consigne.habiller.g1'],
          options: [
            for (var o = 0; o < objets.length; o++)
              OptionManche(id: '${objets[o]}$o', concept: objets[o]),
          ],
          donnees: DonneesDepot(
            emplacements: const [
              EmplacementDepot(id: 'neige', concept: 'neige'),
              EmplacementDepot(id: 'soleil', concept: 'soleil'),
            ],
            objets: objets,
            places: {'neige': List.of(_hiver), 'soleil': List.of(_ete)},
            modeBacs: true,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsHabiller = <ClipConsigne>[
  ClipConsigne('act.habiller.titre', 'S\'habiller pour sortir'),
  ClipConsigne(
    'consigne.habiller.g1',
    'C\'est l\'hiver dehors ! Mets les affaires de neige dans le bac à neige, et les affaires d\'été dans le bac au soleil.',
  ),
];

const activiteHabiller = Activite(
  id: 'habiller',
  famille: Famille.monde,
  moteur: Moteur.dropPlace,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.habiller.titre',
  illustration: 'act-habiller.svg',
  source: SourceGenerateur(HabillerGenerateur()),
  clips: clipsHabiller,
  nbItemsMaximum: 6,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 4, choixMax: 2),
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
