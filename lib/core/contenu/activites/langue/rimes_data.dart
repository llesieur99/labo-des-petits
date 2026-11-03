import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Un mot de la banque de rimes.
class MotRime {
  /// Clé de concept du lexique.
  final String concept;

  /// Clé phonétique de la rime (le SON final, pas l'orthographe) :
  /// 'o', 'on', 'in', 'ou', 'a', 'i', 'e', 'ette', 'eur'.
  final String rime;

  const MotRime(this.concept, this.rime);
}

/// La banque : c'est elle qui fait la rejouabilité. Chaque rime a au moins
/// 4 mots pour que le générateur puisse toujours trouver un « ami » et
/// assez de leurres. Tous les concepts existent dans les deux lexiques.
const banqueRimes = <MotRime>[
  // rime en « o »
  MotRime('chapeau', 'o'),
  MotRime('bateau', 'o'),
  MotRime('gateau', 'o'),
  MotRime('cadeau', 'o'),
  MotRime('oiseau', 'o'),
  MotRime('chateau', 'o'),
  MotRime('velo', 'o'),
  MotRime('moto', 'o'),
  MotRime('manteau', 'o'),
  MotRime('couteau', 'o'),
  // rime en « on »
  MotRime('ballon', 'on'),
  MotRime('bonbon', 'on'),
  MotRime('mouton', 'on'),
  MotRime('poisson', 'on'),
  MotRime('maison', 'on'),
  MotRime('camion', 'on'),
  MotRime('cochon', 'on'),
  MotRime('papillon', 'on'),
  MotRime('savon', 'on'),
  // rime en « in »
  MotRime('lapin', 'in'),
  MotRime('sapin', 'in'),
  MotRime('poussin', 'in'),
  MotRime('chemin', 'in'),
  MotRime('matin', 'in'),
  MotRime('train', 'in'),
  // rime en « ou »
  MotRime('loup', 'ou'),
  MotRime('chou', 'ou'),
  MotRime('hibou', 'ou'),
  MotRime('caillou', 'ou'),
  MotRime('genou', 'ou'),
  MotRime('doudou', 'ou'),
  // rime en « a »
  MotRime('chat', 'a'),
  MotRime('rat', 'a'),
  MotRime('chocolat', 'a'),
  MotRime('pizza', 'a'),
  MotRime('papa', 'a'),
  // rime en « i »
  MotRime('souris', 'i'),
  MotRime('lit', 'i'),
  MotRime('nid', 'i'),
  MotRime('bougie', 'i'),
  MotRime('ami', 'i'),
  // rime en « é »
  MotRime('bebe', 'e'),
  MotRime('fusee', 'e'),
  MotRime('nez', 'e'),
  MotRime('pied', 'e'),
  MotRime('cafe', 'e'),
  MotRime('poupee', 'e'),
  // rime en « ette »
  MotRime('fourchette', 'ette'),
  MotRime('chaussette', 'ette'),
  MotRime('assiette', 'ette'),
  MotRime('casquette', 'ette'),
  MotRime('crevette', 'ette'),
  // rime en « eur »
  MotRime('fleur', 'eur'),
  MotRime('coeur', 'eur'),
  MotRime('beurre', 'eur'),
  MotRime('couleur', 'eur'),
];

/// Les gabarits de consigne, dits AVANT le mot entendu.
/// Trois formulations tournent pour que le jeu ne devienne pas une rengaine.
const clipsRimes = <ClipConsigne>[
  ClipConsigne('act.rimes.titre', 'La chasse aux rimes'),
  ClipConsigne('consigne.rimes.g1', 'Trouve l\'image qui rime avec'),
  ClipConsigne('consigne.rimes.g2', 'Écoute bien. Quel mot rime avec…'),
  ClipConsigne('consigne.rimes.g3', 'Lequel rime avec…'),
];

/// Les gabarits utilisés au hasard pour la consigne (ids seulement).
const gabaritsRimes = [
  'consigne.rimes.g1',
  'consigne.rimes.g2',
  'consigne.rimes.g3',
];

/// Générateur de manches de la chasse aux rimes.
///
/// Le mot entendu est illustré à part, au-dessus des réponses. L’enfant
/// cherche l’image dont le nom rime avec lui, sans lire le mot.
class RimesGenerateur extends GenerateurManches {
  final List<MotRime> banque;

  const RimesGenerateur([this.banque = banqueRimes]);

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    if (banque.isEmpty) return const [];
    final manches = <Manche>[];
    final ciblesVues = <String>{};
    // Trois familles sonores au départ, puis élargissement du contraste.
    // La fenêtre tourne : deux niveaux ne sont pas seulement une autre durée.
    final rimes = banque.map((m) => m.rime).toSet().toList();
    final depart = (niveau.numero - 1 + niveau.palier.index) % rimes.length;
    final nbFamilles = min(
      rimes.length,
      3 + niveau.palier.index + (niveau.numero - 1) ~/ 2,
    );
    final familles = {
      for (var i = 0; i < nbFamilles; i++) rimes[(depart + i) % rimes.length],
    };
    final candidates = banque.where((m) => familles.contains(m.rime)).toList();

    // choixMax compte les images AFFICHÉES : 1 bonne + des leurres.
    final nbOptions = niveau.choixMax < 2 ? 2 : niveau.choixMax;
    final nbLeurres = nbOptions - 1;

    var essais = 0;
    final essaisMax = niveau.nbItems * 30;
    while (manches.length < niveau.nbItems && essais < essaisMax) {
      essais++;

      final cible = _tirerCible(alea, ciblesVues, candidates);
      if (cible == null) break;
      ciblesVues.add(cible.concept);

      final amis = _amisDeRime(cible);
      final bonne = amis[alea.nextInt(amis.length)];
      final leurres = _tirerLeurres(
        alea,
        cible,
        bonne,
        nbLeurres,
        niveau.numero >= 5,
      );
      if (leurres == null) {
        continue; // pas assez de leurres distincts, on repioche
      }

      final options = <OptionManche>[
        OptionManche(id: bonne.concept, concept: bonne.concept),
        for (final leurre in leurres)
          OptionManche(id: leurre.concept, concept: leurre.concept),
      ]..shuffle(alea);

      final gabarit = gabaritsRimes[alea.nextInt(gabaritsRimes.length)];

      manches.add(
        Manche(
          id: 'rimes.${cible.concept}.${bonne.concept}',
          clipsConsigne: [gabarit, 'lex.${cible.concept}'],
          options: options,
          reperes: [cible.concept],
          bonneOptionId: bonne.concept,
        ),
      );
    }

    return manches;
  }

  /// Tire une cible qui a au moins un ami de rime et pas encore vue.
  MotRime? _tirerCible(
    Random alea,
    Set<String> dejaVues,
    List<MotRime> disponibles,
  ) {
    final candidates = disponibles
        .where(
          (m) => !dejaVues.contains(m.concept) && _amisDeRime(m).isNotEmpty,
        )
        .toList();
    if (candidates.isEmpty) return null;
    return candidates[alea.nextInt(candidates.length)];
  }

  /// Les autres mots qui riment avec [mot].
  List<MotRime> _amisDeRime(MotRime mot) => banque
      .where((m) => m.rime == mot.rime && m.concept != mot.concept)
      .toList();

  /// Des leurres qui ne riment NI avec la cible, NI ne sont la cible ou la bonne.
  List<MotRime>? _tirerLeurres(
    Random alea,
    MotRime cible,
    MotRime bonne,
    int combien,
    bool rapprocher,
  ) {
    final possibles = banque
        .where(
          (m) =>
              m.concept != cible.concept &&
              m.concept != bonne.concept &&
              m.rime != cible.rime,
        )
        .toList();
    if (possibles.length < combien) return null;
    possibles.shuffle(alea);
    if (rapprocher) {
      const voisines = {
        'o': 'ou',
        'ou': 'o',
        'on': 'in',
        'in': 'on',
        'i': 'e',
        'e': 'i',
      };
      final proche = voisines[cible.rime];
      possibles.sort(
        (a, b) =>
            (a.rime == proche ? 0 : 1).compareTo(b.rime == proche ? 0 : 1),
      );
    }
    return possibles.take(combien).toList();
  }
}

/// Activité 3 — La chasse aux rimes.
const activiteRimes = Activite(
  id: 'rimes',
  famille: Famille.langue,
  moteur: Moteur.tapPick,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.rimes.titre',
  illustration: 'act-rimes.svg',
  source: SourceGenerateur(RimesGenerateur()),
  clips: clipsRimes,
  niveaux: [
    Niveau(
      palier: Palier.a4,
      numero: 1,
      nbItems: 6,
      choixMax: 2,
      aides: [Aide.consigneRepetee],
    ),
    Niveau(
      palier: Palier.a5,
      numero: 1,
      nbItems: 8,
      choixMax: 3,
      aides: [Aide.consigneRepetee],
    ),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 8,
      choixMax: 3,
      afficherMots: true,
    ),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 10,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadTapPick(),
);
