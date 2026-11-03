import '../contenu/modele/activite.dart';

/// Un enfant (la fratrie a plusieurs profils).
class Profil {
  final int? id;
  final String nom;

  /// Identifiant d'avatar (voir les avatars proposés à la création).
  final String avatar;

  /// Âge déclaré (4 à 7) — sert de point de départ, jamais de limite.
  final int? ageDeclare;

  final DateTime creeLe;

  const Profil({
    this.id,
    required this.nom,
    required this.avatar,
    this.ageDeclare,
    required this.creeLe,
  });

  Profil avecId(int id) =>
      Profil(id: id, nom: nom, avatar: avatar, ageDeclare: ageDeclare, creeLe: creeLe);

  /// Le palier de départ selon l'âge déclaré (4 par défaut).
  Palier get palierDeDepart {
    final age = ageDeclare ?? 4;
    if (age <= 4) return Palier.a4;
    if (age == 5) return Palier.a5;
    if (age == 6) return Palier.a6;
    return Palier.a7;
  }
}

/// Le résultat d'un item (une manche), tel qu'enregistré.
class ResultatItem {
  final String itemId;
  final bool correctDuPremierCoup;
  final int dureeMs;

  const ResultatItem({
    required this.itemId,
    required this.correctDuPremierCoup,
    required this.dureeMs,
  });
}

/// Le résumé d'une partie (sert au calcul de l'adaptation et des étoiles).
class ResumePartie {
  final int items;
  final int reussisDuPremierCoup;

  const ResumePartie({required this.items, required this.reussisDuPremierCoup});

  /// Proportion de réussites du premier coup (0 à 1).
  double get taux => items == 0 ? 0 : reussisDuPremierCoup / items;

  /// Étoiles gagnées : 1 = partie terminée, 2 = bien joué, 3 = sans erreur.
  /// On ne perd jamais une étoile : rejouer peut seulement améliorer.
  int get etoiles {
    if (items == 0) return 0;
    if (reussisDuPremierCoup == items) return 3;
    if (taux >= 0.7) return 2;
    return 1;
  }
}

/// L'état d'un enfant sur une activité : son palier, son niveau, ses aides
/// et les derniers résumés de partie (pour l'adaptation).
class EtatActivite {
  final int profilId;
  final String activiteId;
  final Palier palier;
  final int niveau;
  final List<Aide> aides;

  /// Les derniers résumés de partie (du plus ancien au plus récent, max 6).
  final List<ResumePartie> historique;

  /// Nombre de parties terminées — ne redescend JAMAIS (sauf remise à zéro
  /// par le parent). Sert au mur de collants.
  final int partiesJouees;

  /// La meilleure note d'étoiles jamais atteinte (0 à 3) — ne redescend
  /// jamais non plus : « on ne perd jamais un acquis ».
  final int meilleureEtoile;

  /// Vrai si le palier/niveau a été posé par le parent (point de départ).
  final bool depuisParent;

  final DateTime majLe;

  const EtatActivite({
    required this.profilId,
    required this.activiteId,
    required this.palier,
    required this.niveau,
    this.aides = const [],
    this.historique = const [],
    this.partiesJouees = 0,
    this.meilleureEtoile = 0,
    this.depuisParent = false,
    required this.majLe,
  });

  EtatActivite copieAvec({
    Palier? palier,
    int? niveau,
    List<Aide>? aides,
    List<ResumePartie>? historique,
    int? partiesJouees,
    int? meilleureEtoile,
    bool? depuisParent,
    DateTime? majLe,
  }) =>
      EtatActivite(
        profilId: profilId,
        activiteId: activiteId,
        palier: palier ?? this.palier,
        niveau: niveau ?? this.niveau,
        aides: aides ?? this.aides,
        historique: historique ?? this.historique,
        partiesJouees: partiesJouees ?? this.partiesJouees,
        meilleureEtoile: meilleureEtoile ?? this.meilleureEtoile,
        depuisParent: depuisParent ?? this.depuisParent,
        majLe: majLe ?? this.majLe,
      );
}

/// Un évènement du journal (append-only, purgé à 180 jours).
class Evenement {
  final int? id;
  final int profilId;
  final String activiteId;
  final String itemId;
  final bool correctDuPremierCoup;
  final int dureeMs;
  final Palier palier;
  final int niveau;
  final DateTime horodatage;

  const Evenement({
    this.id,
    required this.profilId,
    required this.activiteId,
    required this.itemId,
    required this.correctDuPremierCoup,
    required this.dureeMs,
    required this.palier,
    required this.niveau,
    required this.horodatage,
  });
}
