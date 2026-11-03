import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 6 — Le mot caché dans la maison (moteur M1).
///
/// « Trouve quelque chose qui commence par m. » Aucune lettre écrite :
/// c'est l'oreille qui entend le premier son. Les objets sont dessinés —
/// les photos de la vraie maison restent un réglage parent, hors écran.

/// Les objets par son initial (le son est un clip, le mot jamais écrit).
class _BanqueSons {
  static const parSon = <String, List<String>>{
    'm': ['moto', 'mouton', 'maison', 'monstre', 'manteau'],
    's': ['souris', 'soleil', 'serpent', 'savon'],
    'p': ['pizza', 'pomme', 'poisson', 'papa', 'poupee', 'poussin'],
    'ch': ['chat', 'chapeau', 'chaussette', 'chocolat', 'chou', 'chateau'],
    'b': ['ballon', 'bonbon', 'bateau', 'bottes', 'bebe', 'beurre'],
    'l': ['lapin', 'loup', 'lune', 'lit', 'livre'],
  };
}

class MotCacheGenerateur extends GenerateurManches {
  const MotCacheGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    // Les sons continus sont plus faciles à isoler que p/b.
    final ordre = ['m', 's', 'l', 'ch', 'p', 'b'];
    final nbSons = (3 + niveau.palier.index + (niveau.numero - 1) ~/ 2).clamp(
      3,
      6,
    );
    final sons = ordre.take(nbSons).toList()..shuffle(alea);
    final vus = <String>{};
    final manches = <Manche>[];

    for (var i = 0; i < niveau.nbItems; i++) {
      final son = sons[i % sons.length];
      final objetsDuSon = _BanqueSons.parSon[son]!;
      final candidats = objetsDuSon.where((o) => !vus.contains(o)).toList()
        ..shuffle(alea);
      final bonne = candidats.first;
      vus.add(bonne);

      // Des leurres qui commencent par un AUTRE son.
      final leurres = <String>[];
      final autresSons = _BanqueSons.parSon.keys.where((s) => s != son).toList()
        ..shuffle(alea);
      // À la fin, comparer les sons voisins s/ch et p/b, sans jamais
      // introduire un second mot qui commence par le son demandé.
      if (niveau.numero >= 5) {
        final voisin = {'s': 'ch', 'ch': 's', 'p': 'b', 'b': 'p'}[son];
        if (voisin != null) {
          autresSons.remove(voisin);
          autresSons.insert(0, voisin);
        }
      }
      for (final autre in autresSons) {
        if (leurres.length >= niveau.choixMax - 1) break;
        final objets = _BanqueSons.parSon[autre]!;
        leurres.add(objets[alea.nextInt(objets.length)]);
      }

      final options = <OptionManche>[
        OptionManche(id: bonne, concept: bonne),
        for (final leurre in leurres) OptionManche(id: leurre, concept: leurre),
      ]..shuffle(alea);

      manches.add(
        Manche(
          id: 'motcache.$son.$bonne',
          clipsConsigne: ['consigne.motcache.g1', 'son.lettre.$son'],
          options: options,
          bonneOptionId: bonne,
        ),
      );
    }
    return manches;
  }
}

const clipsMotCache = <ClipConsigne>[
  ClipConsigne('act.motcache.titre', 'Le mot caché dans la maison'),
  ClipConsigne(
    'consigne.motcache.g1',
    'Trouve quelque chose qui commence par…',
  ),
  ClipConsigne('son.lettre.m', 'Mmmm…'),
  ClipConsigne('son.lettre.s', 'Ssss…'),
  ClipConsigne('son.lettre.p', 'Pppp…'),
  ClipConsigne('son.lettre.ch', 'Chhhh…'),
  ClipConsigne('son.lettre.b', 'Bbbb…'),
  ClipConsigne('son.lettre.l', 'Llll…'),
];

const activiteMotCache = Activite(
  id: 'motcache',
  famille: Famille.langue,
  moteur: Moteur.tapPick,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.motcache.titre',
  illustration: 'act-motcache.svg',
  source: SourceGenerateur(MotCacheGenerateur()),
  clips: clipsMotCache,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 6, choixMax: 3),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 8, choixMax: 3),
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
