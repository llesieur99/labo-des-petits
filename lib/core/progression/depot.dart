import 'modele.dart';

/// Ce que l'app attend d'un dépôt de progression.
/// Deux implémentations : SQLite (l'app) et mémoire (les tests).
abstract class DepotProgression {
  Future<void> initialiser();

  Future<List<Profil>> profils();

  Future<Profil> creerProfil({
    required String nom,
    required String avatar,
    int? ageDeclare,
  });

  Future<void> modifierProfil(Profil profil);

  Future<void> supprimerProfil(int profilId);

  Future<EtatActivite?> etat(int profilId, String activiteId);

  Future<List<EtatActivite>> etats(int profilId);

  Future<void> enregistrerEtat(EtatActivite etat);

  Future<void> enregistrerEvenement(Evenement evenement);

  Future<List<Evenement>> evenements(int profilId, {String? activiteId});

  /// Remet à zéro la progression : une activité, ou tout un profil.
  Future<void> remettreAZero(int profilId, {String? activiteId});

  /// Supprime les évènements plus vieux que [date] (purge à 180 jours).
  Future<int> purgerAvant(DateTime date);

  Future<void> fermer();
}
