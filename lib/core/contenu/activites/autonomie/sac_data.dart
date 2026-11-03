import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 48 — Mon sac du matin (moteur M2, tri sac / maison).
///
/// La liste parlée nomme les objets à emporter ; tout le reste reste à la
/// maison. C'est un vrai rituel du matin, jouable à quatre ans.
class SacGenerateur extends GenerateurManches {
  const SacGenerateur();

  /// Ce qui va dans le sac pour l'école.
  static const _pourLEcole = [
    'lunch',
    'souliers',
    'doudou',
    'pomme',
    'livre',
    'eau',
    'casquette',
    'mitaines',
    'chaussette',
    'manteau',
  ];

  /// Ce qui reste à la maison.
  static const _pourLaMaison = [
    'pizza',
    'chat',
    'ballon',
    'poisson',
    'bougie',
    'cafe',
    'couteau',
    'pot',
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems; i++) {
      // La liste dite est la règle : même un objet scolaire peut rester à
      // la maison s'il n'a pas été demandé aujourd'hui.
      final progression = niveau.numero.clamp(1, 8) - 1;
      const bonsParEtape = [1, 1, 2, 2, 2, 3, 3, 4];
      const intrusParEtape = [1, 2, 1, 2, 3, 2, 3, 4];
      final bonusAge = (niveau.palier.age - 4) ~/ 2;
      final nbBons = (bonsParEtape[progression] + bonusAge).clamp(1, 4);
      final nbIntrus = (intrusParEtape[progression] + bonusAge).clamp(1, 4);

      final bons = (List.of(_pourLEcole)..shuffle(alea)).take(nbBons).toList();
      final candidatsIntrus = [
        ..._pourLaMaison,
        if (progression >= 4) ..._pourLEcole.where((c) => !bons.contains(c)),
      ]..shuffle(alea);
      final intrus = candidatsIntrus.take(nbIntrus).toList();
      final objets = <String>[...bons, ...intrus]..shuffle(alea);

      manches.add(
        Manche(
          id: 'sac.${(List.of(bons)..sort()).join('.')}.${(List.of(intrus)..sort()).join('.')}.$i',
          clipsConsigne: [
            'consigne.sac.g1',
            for (final concept in bons) 'lex.$concept',
            'consigne.sac.fin',
          ],
          options: [
            for (var o = 0; o < objets.length; o++)
              OptionManche(id: '${objets[o]}$o', concept: objets[o]),
          ],
          donnees: DonneesDepot(
            emplacements: const [
              EmplacementDepot(id: 'sac', concept: 'sac'),
              EmplacementDepot(id: 'maison', concept: 'maison'),
            ],
            objets: objets,
            places: {'sac': bons, 'maison': intrus},
            modeBacs: true,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsSac = <ClipConsigne>[
  ClipConsigne('act.sac.titre', 'Mon sac du matin'),
  ClipConsigne(
    'consigne.sac.g1',
    'On prépare le sac pour l\'école. Mets dans le sac :',
  ),
  ClipConsigne('consigne.sac.fin', 'Et laisse le reste à la maison.'),
];

const activiteSac = Activite(
  id: 'sac',
  famille: Famille.autonomie,
  moteur: Moteur.dropPlace,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.sac.titre',
  illustration: 'act-sac.svg',
  source: SourceGenerateur(SacGenerateur()),
  clips: clipsSac,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 5, choixMax: 3),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 5,
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
