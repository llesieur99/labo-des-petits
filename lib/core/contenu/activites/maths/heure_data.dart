import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 15 — L'heure du goûter (moteur M4, décor 'horloge').
///
/// Une horloge ronde, uniquement l'heure pile et la demie, collée à la
/// journée : réveil, dîner, parc, dodo. Pas une leçon d'horloge.
const clipsHeure = <ClipConsigne>[
  ClipConsigne('act.heure.titre', 'L\'heure du goûter'),
  ClipConsigne('consigne.heure.g1', 'Regarde l\'horloge…'),
  ClipConsigne(
    'consigne.heure.reveil',
    'Il est sept heures et demie du matin. Que fait-on ?',
  ),
  ClipConsigne(
    'consigne.heure.diner',
    'Il est midi ! Qu\'est-ce qu\'on fait à midi ?',
  ),
  ClipConsigne(
    'consigne.heure.parc',
    'Il est quatre heures. Le soleil brille. Que fait-on ?',
  ),
  ClipConsigne(
    'consigne.heure.dodo',
    'Il est huit heures du soir. Il fait noir dehors. Que fait-on ?',
  ),
];

/// Quatre repères déjà illustrés et enregistrés. Les dernières étapes
/// rapprochent les moments voisins de la journée et enchaînent deux horaires.
class HeureGenerateur extends GenerateurManches {
  const HeureGenerateur();

  static const _moments = [
    ('reveil', 'heure_7demi', 'matin'),
    ('diner', 'heure_12', 'assiette'),
    ('parc', 'heure_4', 'ballon'),
    ('dodo', 'heure_8', 'dormir'),
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final ordre = [0, 1, 2, 3]..shuffle(alea);
    final deuxHoraires = niveau.palier.index >= 1 && niveau.numero >= 6;
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        _manche(niveau, ordre[i % ordre.length], deuxHoraires, i, alea),
    ];
  }

  Manche _manche(
    Niveau niveau,
    int debut,
    bool deuxHoraires,
    int i,
    Random alea,
  ) {
    final indices = [debut, if (deuxHoraires) (debut + 1 + i % 3) % 4];
    final etapes = <EtapeScene>[];
    for (final index in indices) {
      final (moment, visuel, reponse) = _moments[index];
      final autres = [
        for (var m = 0; m < _moments.length; m++)
          if (m != index) _moments[m].$3,
      ];
      // Au début, jour/nuit forment un contraste clair. Ensuite les
      // distracteurs sont aussi des activités diurnes (repas ou parc).
      if (niveau.numero <= 2 && index != 3) {
        autres.remove('dormir');
        autres.insert(0, 'dormir');
      } else {
        autres.shuffle(alea);
      }
      final options = [reponse, ...autres.take(min(4, niveau.choixMax) - 1)]
        ..shuffle(alea);
      etapes.add(EtapeScene(narrationCle: 'consigne.heure.g1', visuel: visuel));
      etapes.add(
        EtapeScene(
          narrationCle: 'consigne.heure.$moment',
          options: options,
          bonneOption: reponse,
          visuel: visuel,
        ),
      );
    }
    return Manche(
      id: 'heure.${indices.join('-')}.${etapes.where((e) => e.options.isNotEmpty).map((e) => e.options.join('-')).join('_')}.$i',
      clipsConsigne: const ['consigne.heure.g1'],
      donnees: DonneesScene(decor: 'horloge', etapes: etapes),
    );
  }
}

const activiteHeure = Activite(
  id: 'heure',
  famille: Famille.maths,
  moteur: Moteur.scene,
  sensNaturel: Sens.portrait,
  titreCle: 'act.heure.titre',
  illustration: 'act-heure.svg',
  source: SourceGenerateur(HeureGenerateur()),
  clips: clipsHeure,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 4,
      choixMax: 3,
      afficherMots: true,
    ),
  ],
  payload: PayloadScene(),
);
