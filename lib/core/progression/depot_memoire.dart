import 'depot.dart';
import 'modele.dart';

/// Dépôt en mémoire — pour les tests et la démo.
class DepotMemoire implements DepotProgression {
  final List<Profil> _profils = [];
  final Map<String, EtatActivite> _etats = {}; // clé : '<profilId>/<activiteId>'
  final List<Evenement> _evenements = [];
  int _prochainProfil = 1;
  int _prochainEvenement = 1;

  @override
  Future<void> initialiser() async {}

  @override
  Future<List<Profil>> profils() async => List.unmodifiable(_profils);

  @override
  Future<Profil> creerProfil({
    required String nom,
    required String avatar,
    int? ageDeclare,
  }) async {
    final profil = Profil(
      id: _prochainProfil++,
      nom: nom,
      avatar: avatar,
      ageDeclare: ageDeclare,
      creeLe: DateTime.now(),
    );
    _profils.add(profil);
    return profil;
  }

  @override
  Future<void> modifierProfil(Profil profil) async {
    final index = _profils.indexWhere((p) => p.id == profil.id);
    if (index >= 0) _profils[index] = profil;
  }

  @override
  Future<void> supprimerProfil(int profilId) async {
    _profils.removeWhere((p) => p.id == profilId);
    _etats.removeWhere((cle, _) => cle.startsWith('$profilId/'));
    _evenements.removeWhere((e) => e.profilId == profilId);
  }

  @override
  Future<EtatActivite?> etat(int profilId, String activiteId) async =>
      _etats['$profilId/$activiteId'];

  @override
  Future<List<EtatActivite>> etats(int profilId) async => _etats.values
      .where((e) => e.profilId == profilId)
      .toList(growable: false);

  @override
  Future<void> enregistrerEtat(EtatActivite etat) async {
    _etats['${etat.profilId}/${etat.activiteId}'] = etat;
  }

  @override
  Future<void> enregistrerEvenement(Evenement evenement) async {
    _evenements.add(Evenement(
      id: _prochainEvenement++,
      profilId: evenement.profilId,
      activiteId: evenement.activiteId,
      itemId: evenement.itemId,
      correctDuPremierCoup: evenement.correctDuPremierCoup,
      dureeMs: evenement.dureeMs,
      palier: evenement.palier,
      niveau: evenement.niveau,
      horodatage: evenement.horodatage,
    ));
  }

  @override
  Future<List<Evenement>> evenements(int profilId, {String? activiteId}) async =>
      _evenements
          .where((e) =>
              e.profilId == profilId &&
              (activiteId == null || e.activiteId == activiteId))
          .toList(growable: false);

  @override
  Future<void> remettreAZero(int profilId, {String? activiteId}) async {
    if (activiteId == null) {
      _etats.removeWhere((cle, _) => cle.startsWith('$profilId/'));
      _evenements.removeWhere((e) => e.profilId == profilId);
    } else {
      _etats.remove('$profilId/$activiteId');
      _evenements
          .removeWhere((e) => e.profilId == profilId && e.activiteId == activiteId);
    }
  }

  @override
  Future<int> purgerAvant(DateTime date) async {
    final avant = _evenements.length;
    _evenements.removeWhere((e) => e.horodatage.isBefore(date));
    return avant - _evenements.length;
  }

  @override
  Future<void> fermer() async {}
}
