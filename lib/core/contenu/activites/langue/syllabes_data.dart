import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 2 — Les syllabes qui sautent (moteur M6, mode syllabes).
///
/// L'app dit « cha-peau », une grenouille saute une fois par syllabe, puis
/// l'enfant rejoue le mot en tapant une fois par syllabe. L'oreille avant
/// la lettre.
class SyllabesGenerateur extends GenerateurManches {
  const SyllabesGenerateur();

  /// (mot, syllabes) — les mots de deux syllabes d'abord.
  static const _mots = <(String, List<String>)>[
    ('chapeau', ['cha', 'peau']),
    ('bateau', ['ba', 'teau']),
    ('gateau', ['ga', 'teau']),
    ('ballon', ['bal', 'lon']),
    ('bonbon', ['bon', 'bon']),
    ('mouton', ['mou', 'ton']),
    ('poisson', ['pois', 'son']),
    ('lapin', ['la', 'pin']),
    ('pizza', ['piz', 'za']),
    ('doudou', ['dou', 'dou']),
    ('chocolat', ['cho', 'co', 'lat']),
    // Banane est exclue : ba-na-ne compte un e muet à tort à l'oral.
    // Les clips historiques restent déclarés pour ne pas changer les assets.
    ('avion', ['a', 'vion']),
    ('pantalon', ['pan', 'ta', 'lon']),
  ];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final longs = _mots.where((m) => m.$2.length == 3).toList()..shuffle(alea);
    final courts = _mots.where((m) => m.$2.length == 2).toList()..shuffle(alea);
    // Un seul saut d'abord, puis deux, enfin les mots de trois syllabes.
    // Un monosyllabe réutilise son mot entier comme unique clip syllabique.
    final simples = <String>[
      'chat',
      'loup',
      'chou',
      'lit',
      'nid',
      'rat',
      'fleur',
      'coeur',
      'nez',
      'pied',
    ]..shuffle(alea);
    final nbLongs = niveau.palier.index >= 2 || niveau.numero >= 5
        ? min(longs.length, 1 + (niveau.numero - 1) ~/ 4)
        : 0;
    final nbSimples = niveau.numero <= 2 ? min(2, niveau.nbItems) : 1;
    final disponibles = [
      ...longs.take(nbLongs),
      ...courts.take(max(0, niveau.nbItems - nbLongs - nbSimples)),
    ]..shuffle(alea);
    final manches = <Manche>[];
    for (var i = 0; i < niveau.nbItems && i < disponibles.length; i++) {
      final (mot, syllabes) = disponibles[i];
      manches.add(
        Manche(
          id: 'syllabes.$mot',
          clipsConsigne: ['consigne.syllabes.g1', 'syllmot.$mot'],
          donnees: DonneesRythme(
            mode: ModeRythme.syllabes,
            motCle: 'syllmot.$mot',
            syllabesClips: [
              for (var s = 0; s < syllabes.length; s++) 'syll.$mot.${s + 1}',
            ],
          ),
        ),
      );
    }
    for (final mot in simples.take(
      min(nbSimples, niveau.nbItems - manches.length),
    )) {
      manches.add(
        Manche(
          id: 'syllabes.$mot',
          clipsConsigne: ['consigne.syllabes.g1', 'lex.$mot'],
          donnees: DonneesRythme(
            mode: ModeRythme.syllabes,
            motCle: 'lex.$mot',
            syllabesClips: ['lex.$mot'],
          ),
        ),
      );
    }
    manches.shuffle(alea);
    return manches;
  }
}

const clipsSyllabes = <ClipConsigne>[
  ClipConsigne('act.syllabes.titre', 'Les syllabes qui sautent'),
  ClipConsigne(
    'consigne.syllabes.g1',
    'Écoute le mot. La grenouille saute une fois pour chaque syllabe. À toi après !',
  ),
  // Les mots, puis chaque syllabe (dites séparément, comme le modèle).
  ClipConsigne('syllmot.chapeau', 'chapeau'),
  ClipConsigne('syll.chapeau.1', 'cha'),
  ClipConsigne('syll.chapeau.2', 'peau'),
  ClipConsigne('syllmot.bateau', 'bateau'),
  ClipConsigne('syll.bateau.1', 'ba'),
  ClipConsigne('syll.bateau.2', 'teau'),
  ClipConsigne('syllmot.gateau', 'gâteau'),
  ClipConsigne('syll.gateau.1', 'ga'),
  ClipConsigne('syll.gateau.2', 'teau'),
  ClipConsigne('syllmot.ballon', 'ballon'),
  ClipConsigne('syll.ballon.1', 'bal'),
  ClipConsigne('syll.ballon.2', 'lon'),
  ClipConsigne('syllmot.bonbon', 'bonbon'),
  ClipConsigne('syll.bonbon.1', 'bon'),
  ClipConsigne('syll.bonbon.2', 'bon'),
  ClipConsigne('syllmot.mouton', 'mouton'),
  ClipConsigne('syll.mouton.1', 'mou'),
  ClipConsigne('syll.mouton.2', 'ton'),
  ClipConsigne('syllmot.poisson', 'poisson'),
  ClipConsigne('syll.poisson.1', 'pois'),
  ClipConsigne('syll.poisson.2', 'son'),
  ClipConsigne('syllmot.lapin', 'lapin'),
  ClipConsigne('syll.lapin.1', 'la'),
  ClipConsigne('syll.lapin.2', 'pin'),
  ClipConsigne('syllmot.pizza', 'pizza'),
  ClipConsigne('syll.pizza.1', 'piz'),
  ClipConsigne('syll.pizza.2', 'za'),
  ClipConsigne('syllmot.doudou', 'doudou'),
  ClipConsigne('syll.doudou.1', 'dou'),
  ClipConsigne('syll.doudou.2', 'dou'),
  ClipConsigne('syllmot.chocolat', 'chocolat'),
  ClipConsigne('syll.chocolat.1', 'cho'),
  ClipConsigne('syll.chocolat.2', 'co'),
  ClipConsigne('syll.chocolat.3', 'lat'),
  ClipConsigne('syllmot.banane', 'banane'),
  ClipConsigne('syll.banane.1', 'ba'),
  ClipConsigne('syll.banane.2', 'na'),
  ClipConsigne('syll.banane.3', 'ne'),
  ClipConsigne('syllmot.avion', 'avion'),
  ClipConsigne('syll.avion.1', 'a'),
  ClipConsigne('syll.avion.2', 'vion'),
  ClipConsigne('syllmot.pantalon', 'pantalon'),
  ClipConsigne('syll.pantalon.1', 'pan'),
  ClipConsigne('syll.pantalon.2', 'ta'),
  ClipConsigne('syll.pantalon.3', 'lon'),
];

const activiteSyllabes = Activite(
  id: 'syllabes',
  famille: Famille.langue,
  moteur: Moteur.rythme,
  sensNaturel: Sens.paysage,
  titreCle: 'act.syllabes.titre',
  illustration: 'act-syllabes.svg',
  source: SourceGenerateur(SyllabesGenerateur()),
  clips: clipsSyllabes,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 2, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 4, choixMax: 3),
  ],
  payload: PayloadRythme(),
);
