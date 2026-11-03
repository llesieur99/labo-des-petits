import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 18 — Trois ordres, pas plus (moteur M5).
///
/// « Prends le ballon, mets-le dans le sac, ferme le couvercle. » La mémoire
/// d'ordres grandit d'une consigne à trois — jamais plus.
const clipsOrdres = <ClipConsigne>[
  ClipConsigne('act.ordres.titre', 'Trois ordres, pas plus'),
  ClipConsigne(
    'consigne.ordres.g1',
    'Écoute bien les ordres, puis fais-les dans l\'ordre.',
  ),
  ClipConsigne(
    'ordres.1.dit',
    'Prends le ballon, et va le porter jusqu\'à la maison !',
  ),
  ClipConsigne('ordres.1.fin', 'Le ballon est arrivé à la maison !'),
  ClipConsigne(
    'ordres.2.dit',
    'Le chat a faim. Prends le chat, puis donne-lui son assiette !',
  ),
  ClipConsigne('ordres.2.fin', 'Le chat mange dans son assiette. Miam !'),
  ClipConsigne(
    'ordres.3.dit',
    'Prends le ballon, mets-le dans le sac, puis prends ton toutou !',
  ),
  ClipConsigne(
    'ordres.3.fin',
    'Tu as tout pris : le ballon dans le sac, et le toutou !',
  ),
  ClipConsigne(
    'ordres.4.dit',
    'Prends la fleur, donne-lui de l\'eau, puis mets-la au soleil !',
  ),
  ClipConsigne(
    'ordres.4.fin',
    'La fleur a de l\'eau et du soleil. Elle est contente !',
  ),
];

const _ordresManches = <Manche>[
  Manche(
    id: 'ordres.1',
    clipsConsigne: ['consigne.ordres.g1', 'ordres.1.dit'],
    options: [
      OptionManche(id: 'ballon', concept: 'ballon'),
      OptionManche(id: 'maison', concept: 'maison'),
      OptionManche(id: 'doudou', concept: 'doudou'),
      OptionManche(id: 'pizza', concept: 'pizza'),
    ],
    donnees: DonneesOrdre(
      cases: ['ballon', 'maison'],
      narrationCle: 'ordres.1.fin',
    ),
  ),
  Manche(
    id: 'ordres.2',
    clipsConsigne: ['consigne.ordres.g1', 'ordres.2.dit'],
    options: [
      OptionManche(id: 'chat', concept: 'chat'),
      OptionManche(id: 'assiette', concept: 'assiette'),
      OptionManche(id: 'lit', concept: 'lit'),
      OptionManche(id: 'bateau', concept: 'bateau'),
    ],
    donnees: DonneesOrdre(
      cases: ['chat', 'assiette'],
      narrationCle: 'ordres.2.fin',
    ),
  ),
  Manche(
    id: 'ordres.3',
    clipsConsigne: ['consigne.ordres.g1', 'ordres.3.dit'],
    options: [
      OptionManche(id: 'ballon', concept: 'ballon'),
      OptionManche(id: 'sac', concept: 'sac'),
      OptionManche(id: 'doudou', concept: 'doudou'),
      OptionManche(id: 'chocolat', concept: 'chocolat'),
      OptionManche(id: 'fusee', concept: 'fusee'),
    ],
    donnees: DonneesOrdre(
      cases: ['ballon', 'sac', 'doudou'],
      narrationCle: 'ordres.3.fin',
    ),
  ),
  Manche(
    id: 'ordres.4',
    clipsConsigne: ['consigne.ordres.g1', 'ordres.4.dit'],
    options: [
      OptionManche(id: 'fleur', concept: 'fleur'),
      OptionManche(id: 'eau', concept: 'eau'),
      OptionManche(id: 'soleil', concept: 'soleil'),
      OptionManche(id: 'lune', concept: 'lune'),
      OptionManche(id: 'caillou', concept: 'caillou'),
    ],
    donnees: DonneesOrdre(
      cases: ['fleur', 'eau', 'soleil'],
      narrationCle: 'ordres.4.fin',
    ),
  ),
];

/// Les voix existantes décrivent quatre séquences : on augmente la mémoire
/// et l'inhibition avec des distracteurs, sans inventer d'ordre non prononcé.
class OrdresGenerateur extends GenerateurManches {
  const OrdresGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final trois = niveau.palier.age >= 5 && niveau.numero >= 3;
    final modeles = _ordresManches
        .where(
          (m) => (m.donnees as DonneesOrdre).cases.length == (trois ? 3 : 2),
        )
        .toList();
    final reserve = [
      'ballon',
      'maison',
      'doudou',
      'pizza',
      'chat',
      'assiette',
      'lit',
      'bateau',
      'sac',
      'chocolat',
      'fusee',
      'fleur',
      'eau',
      'soleil',
      'lune',
      'caillou',
    ];
    final manches = <Manche>[];
    final ids = <String>{};
    for (
      var essai = 0;
      essai < 120 && manches.length < niveau.nbItems;
      essai++
    ) {
      final modele = modeles[essai % modeles.length];
      final d = modele.donnees as DonneesOrdre;
      final nombreLeurres =
          niveau.numero ~/ 2 + (niveau.palier.age >= 6 ? 1 : 0);
      final leurres = reserve.where((c) => !d.cases.contains(c)).toList()
        ..shuffle(alea);
      final concepts = [...d.cases, ...leurres.take(nombreLeurres.clamp(0, 3))];
      final signature = List.of(concepts)..sort();
      final id = '${modele.id}.${signature.join("-")}';
      if (!ids.add(id)) continue;
      manches.add(
        Manche(
          id: id,
          clipsConsigne: modele.clipsConsigne,
          options: [for (final c in concepts) OptionManche(id: c, concept: c)],
          donnees: d,
        ),
      );
    }
    return manches;
  }
}

const activiteOrdres = Activite(
  id: 'ordres',
  famille: Famille.logique,
  moteur: Moteur.ordre,
  sensNaturel: Sens.paysage,
  titreCle: 'act.ordres.titre',
  illustration: 'act-ordres.svg',
  source: SourceGenerateur(OrdresGenerateur()),
  clips: clipsOrdres,
  niveaux: [
    Niveau(
      palier: Palier.a4,
      numero: 1,
      nbItems: 2,
      choixMax: 3,
      aides: [Aide.narrationAvant],
    ),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 4),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 4,
      choixMax: 5,
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
