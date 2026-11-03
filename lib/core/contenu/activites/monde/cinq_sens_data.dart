import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 28 — Les cinq sens (moteur M1).
///
/// Reconnaître d’abord des cris et des textures, puis associer aussi
/// une lumière, une odeur et des aliments à la vue, l’odorat et le goût.
class CinqSensGenerateur extends GenerateurManches {
  const CinqSensGenerateur();

  /// (animal, clip du cri) — le cri est joué par la voix, jamais écrit.
  static const cris = [
    ('chat', 'cri.chat'),
    ('vache', 'cri.vache'),
    ('loup', 'cri.loup'),
    ('serpent', 'cri.serpent'),
    ('poule', 'cri.poule'),
    ('abeille', 'cri.abeille'),
    ('hibou', 'cri.hibou'),
    ('tigre', 'cri.tigre'),
  ];

  /// (clip de consigne, membres) — les textures au toucher.
  /// Assez de membres des deux côtés pour fournir les leurres des grands.
  static const textures = [
    ('consigne.sens.doux', ['doudou', 'chaussette', 'mouton']),
    ('consigne.sens.dur', ['caillou', 'tambour', 'verre', 'pot']),
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final manches = <Manche>[];
    final modes = niveau.palier.age >= 5
        ? ['cri', 'texture', 'vue', 'odorat', 'gout']
        : niveau.numero <= 2
        ? ['cri', 'texture']
        : niveau.numero <= 4
        ? ['cri', 'texture', 'gout']
        : ['cri', 'texture', 'vue', 'odorat', 'gout'];
    for (final (animal, clip) in cris) {
      final autres = cris.where((c) => c.$1 != animal).map((c) => c.$1).toList()
        ..shuffle(alea);
      manches.add(
        Manche(
          id: 'sens.cri.$animal',
          clipsConsigne: [clip],
          options: [
            OptionManche(id: animal, concept: animal),
            for (final autre in autres.take(niveau.choixMax - 1))
              OptionManche(id: autre, concept: autre),
          ]..shuffle(alea),
          bonneOptionId: animal,
        ),
      );
    }
    for (final (consigne, membres) in textures) {
      for (final bonne in membres) {
        final leurres =
            textures.where((t) => t.$1 != consigne).expand((t) => t.$2).toList()
              ..shuffle(alea);
        manches.add(
          Manche(
            id: 'sens.texture.$bonne',
            clipsConsigne: [consigne],
            options: [
              OptionManche(id: bonne, concept: bonne),
              for (final autre in leurres.take(niveau.choixMax - 1))
                OptionManche(id: autre, concept: autre),
            ]..shuffle(alea),
            bonneOptionId: bonne,
          ),
        );
      }
    }
    for (final mode in modes.where((m) => !['cri', 'texture'].contains(m))) {
      // Une seule réponse raisonnable par question : jamais un autre aliment
      // comme leurre du goût, ni une autre lumière pour la vue.
      final bonnes = switch (mode) {
        'vue' => ['soleil', 'lune', 'etoile'],
        'odorat' => ['fleur'],
        _ => [
          'pomme',
          'banane',
          'fraise',
          'raisin',
          'pizza',
          'chocolat',
          'chou',
        ],
      };
      for (final bonne in bonnes) {
        final leurres = ['tambour', 'chaussette', 'caillou', 'lit', 'velo']
          ..shuffle(alea);
        manches.add(
          Manche(
            id: 'sens.$mode.$bonne',
            clipsConsigne: ['consigne.sens.$mode'],
            options: [
              OptionManche(id: bonne, concept: bonne),
              for (final autre in leurres.take(niveau.choixMax - 1))
                OptionManche(id: autre, concept: autre),
            ]..shuffle(alea),
            bonneOptionId: bonne,
          ),
        );
      }
    }
    // Répartir les sens avant le mélange commun garantit que chaque partie
    // complète dès cinq ans contient les cinq sens, sans répéter une cible.
    final parMode = {
      for (final mode in modes)
        mode: manches.where((m) => m.id.split('.')[1] == mode).toList()
          ..shuffle(alea),
    };
    final ordre = List.of(modes)..shuffle(alea);
    final selection = <Manche>[];
    while (selection.length < niveau.nbItems &&
        parMode.values.any((m) => m.isNotEmpty)) {
      for (final mode in ordre) {
        if (selection.length == niveau.nbItems) break;
        if (parMode[mode]!.isNotEmpty) {
          selection.add(parMode[mode]!.removeLast());
        }
      }
    }
    return selection;
  }
}

const clipsCinqSens = <ClipConsigne>[
  ClipConsigne(
    'consigne.sens.vue',
    'Avec tes yeux, tu vois une lumière dans le ciel. Quelle image montre cette lumière ?',
  ),
  ClipConsigne(
    'consigne.sens.odorat',
    'Avec ton nez, tu sens une bonne odeur dans le jardin. Quelle image peut avoir cette odeur ?',
  ),
  ClipConsigne(
    'consigne.sens.gout',
    'Avec ta bouche, tu goûtes un aliment. Quelle image montre quelque chose à manger ?',
  ),

  ClipConsigne('act.sens.titre', 'Les cinq sens'),
  ClipConsigne(
    'consigne.sens.doux',
    'C\'est tout doux ! Qu\'est-ce qui est tout doux au toucher ?',
  ),
  ClipConsigne(
    'consigne.sens.dur',
    'C\'est dur comme un caillou ! Qu\'est-ce qui est dur ?',
  ),
  ClipConsigne('cri.chat', 'Miaou ! Qui fait ce bruit ?'),
  ClipConsigne('cri.vache', 'Meuh ! Qui fait ce bruit ?'),
  ClipConsigne('cri.loup', 'Ouuuuu ! Qui fait ce bruit ?'),
  ClipConsigne('cri.serpent', 'Ssssss ! Qui fait ce bruit ?'),
  ClipConsigne('cri.poule', 'Cot cot codet ! Qui fait ce bruit ?'),
  ClipConsigne('cri.abeille', 'Zzzzzz ! Qui fait ce bruit ?'),
  ClipConsigne('cri.hibou', 'Hou hou ! Qui fait ce bruit ?'),
  ClipConsigne('cri.tigre', 'Rrrrrr ! Qui fait ce bruit ?'),
];

const activiteCinqSens = Activite(
  id: 'sens',
  famille: Famille.monde,
  moteur: Moteur.tapPick,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.sens.titre',
  illustration: 'act-sens.svg',
  source: SourceGenerateur(CinqSensGenerateur()),
  clips: clipsCinqSens,
  nbItemsMaximum: 10,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 6, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 6, choixMax: 3),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 8,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadTapPick(),
);
