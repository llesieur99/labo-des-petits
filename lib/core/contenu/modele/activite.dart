import 'dart:math';

import 'manche.dart';
import 'payloads_moteurs.dart';

/// Famille d'activités — une « île » de l'écran d'accueil.
enum Famille {
  langue('langue'),
  maths('maths'),
  logique('logique'),
  monde('monde'),
  emotions('emotions'),
  creation('creation'),
  autonomie('autonomie');

  /// Identifiant stable utilisé dans les données et l'export JSON.
  final String id;

  const Famille(this.id);
}

/// Moteur d'interaction réutilisable : plusieurs activités partagent le même.
enum Moteur {
  tapPick('tapPick'),
  dropPlace('dropPlace'),
  trace('trace'),
  scene('scene'),
  ordre('ordre'),
  rythme('rythme'),
  creation('creation'),
  tours('tours'),
  balance('balance');

  final String id;

  const Moteur(this.id);
}

/// Sens de l'écran où le jeu est le plus naturel.
/// C'est une PRÉFÉRENCE : le jeu doit rester jouable dans les deux sens.
enum Sens { portrait, paysage, lesDeux }

/// Deck linguistique : le québécois d'abord, la France ensuite.
enum Deck {
  qc('qc'),
  fr('fr');

  final String id;

  const Deck(this.id);
}

/// Palier d'âge : 4, 5, 6 ou 7 ans.
enum Palier {
  a4('a4', 4),
  a5('a5', 5),
  a6('a6', 6),
  a7('a7', 7);

  final String id;
  final int age;

  const Palier(this.id, this.age);

  /// Le palier suivant, ou null si c'est le dernier.
  Palier? get suivant => switch (this) {
    Palier.a4 => Palier.a5,
    Palier.a5 => Palier.a6,
    Palier.a6 => Palier.a7,
    Palier.a7 => null,
  };
}

/// Aides douces qu'un niveau peut activer ou que l'adaptation ajoute.
enum Aide {
  consigneRepetee('consigneRepetee'),
  moinsDeChoix('moinsDeChoix'),
  indiceVisuel('indiceVisuel'),
  narrationAvant('narrationAvant');

  final String id;

  const Aide(this.id);
}

/// Un niveau = une variante d'une activité à un palier d'âge donné.
class Niveau {
  final Palier palier;

  /// Numéro de la variante à l'intérieur du palier (1, 2, 3…).
  final int numero;

  /// Nombre d'items (manches) d'une partie — vise 3 à 8 minutes.
  final int nbItems;

  /// Nombre maximum d'options présentées dans une manche.
  final int choixMax;

  /// Aides actives par défaut à ce niveau.
  final List<Aide> aides;

  /// Afficher le mot écrit sous l'image (transition vers la lecture, 6-7 ans).
  final bool afficherMots;

  const Niveau({
    required this.palier,
    required this.numero,
    required this.nbItems,
    required this.choixMax,
    this.aides = const [],
    this.afficherMots = false,
  });
}

/// Un clip déclaré par une activité, avec son texte source.
/// C'est ce texte que le script de génération audio transforme en voix.
class ClipConsigne {
  final String id;
  final String texte;
  final String categorie;
  final String? rate;
  final String? pitch;

  const ClipConsigne(
    this.id,
    this.texte, {
    this.categorie = 'consigne',
    this.rate,
    this.pitch,
  });
}

/// Fabrique les manches d'une partie. Peut piocher dans une banque
/// (rejouabilité) ou rendre une liste fixe.
abstract class GenerateurManches {
  const GenerateurManches();

  List<Manche> generer(Niveau niveau, Random alea);
}

/// D'où viennent les manches d'une activité.
sealed class SourceManches {
  const SourceManches();
}

/// Liste de manches écrite d'avance (histoires, recettes…).
class SourceFixe extends SourceManches {
  final List<Manche> manches;

  const SourceFixe(this.manches);
}

/// Manches tirées à la volée par un générateur (rimes, bus…).
class SourceGenerateur extends SourceManches {
  final GenerateurManches generateur;

  const SourceGenerateur(this.generateur);
}

/// Une activité du catalogue — l'unité que l'enfant choisit.
class Activite {
  static const etapesParPalier = 8;

  /// Identifiant stable : ASCII, minuscules ('rimes', 'bus'…).
  final String id;

  final Famille famille;
  final Moteur moteur;
  final Sens sensNaturel;

  /// Identifiant du clip du titre (jamais de texte en dur).
  final String titreCle;

  /// Identifiant de l'illustration de la carte.
  final String illustration;

  final SourceManches source;

  /// Tous les clips, déclarés par l'activité, avec leur texte source.
  /// Doit contenir [titreCle].
  final List<ClipConsigne> clips;

  /// Une entrée par palier d'âge disponible (4 paliers en général).
  final List<Niveau> niveaux;

  final Payload payload;
  final int choixMinimum;

  /// Une petite banque de clips peut limiter la longueur d'une partie sans
  /// empêcher d'avoir huit niveaux de difficulté et de contenu par âge.
  final int nbItemsMaximum;

  const Activite({
    required this.id,
    required this.famille,
    required this.moteur,
    required this.sensNaturel,
    required this.titreCle,
    required this.illustration,
    required this.source,
    required this.clips,
    required this.niveaux,
    required this.payload,
    this.choixMinimum = 2,
    this.nbItemsMaximum = 12,
  });

  /// Le niveau correspondant à un palier, ou null si absent.
  List<Niveau> etapesPour(Palier palier) {
    final bases = niveaux.where((n) => n.palier == palier).toList();
    if (bases.isEmpty) return const [];
    if (bases.length > 1) {
      return bases..sort((a, b) => a.numero.compareTo(b.numero));
    }
    final base = bases.single;
    return [
      for (var numero = 1; numero <= etapesParPalier; numero++)
        Niveau(
          palier: palier,
          numero: numero,
          // Les trois premières étapes gardent leur progression historique,
          // sous le plafond d'une banque courte qui évite les répétitions.
          nbItems:
              (base.nbItems +
                      switch (numero) {
                        1 => -2,
                        2 => -1,
                        3 || 4 => 0,
                        5 || 6 => 1,
                        _ => 2,
                      })
                  .clamp(1, min(12, nbItemsMaximum)),
          choixMax: numero == 1 && moteur == Moteur.tapPick
              ? max(choixMinimum, base.choixMax - 1)
              : base.choixMax,
          aides: numero == 1
              ? const [Aide.consigneRepetee, Aide.indiceVisuel]
              : numero <= 4
              ? base.aides
              : const [],
          afficherMots: base.afficherMots,
        ),
    ];
  }

  Niveau? niveauPour(Palier palier, {int? numero}) {
    if (numero != null) {
      final etapes = etapesPour(palier);
      if (etapes.isEmpty) return null;
      return etapes[(numero - 1).clamp(0, etapes.length - 1)];
    }
    for (final niveau in niveaux) {
      if (niveau.palier == palier) return niveau;
    }
    return null;
  }
}
