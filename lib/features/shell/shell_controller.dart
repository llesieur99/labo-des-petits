import 'package:flutter/foundation.dart';

import '../../core/parent/reglages.dart';
import '../../core/progression/depot.dart';
import '../../core/progression/modele.dart';

/// L'aiguillage de l'app : qui joue, et si c'est encore l'heure.
class ShellController extends ChangeNotifier {
  final DepotProgression depot;
  final Reglages reglages;

  ShellController({required this.depot, required this.reglages});

  List<Profil> profils = const [];
  Profil? profilActif;
  bool pret = false;

  Future<void> initialiser() async {
    profils = await depot.profils();
    // Un seul enfant : on entre directement chez lui. Plusieurs enfants :
    // on demande TOUJOURS « qui joue ? » à l'ouverture (demande de LP,
    // 2026-10-16) — pas de reprise silencieuse du dernier profil, chacun
    // retrouve ses succès et sa progression en choisissant son avatar.
    if (profils.length == 1) {
      profilActif = profils.first;
      await reglages.setProfilActif(profils.first.id!);
    }
    pret = true;
    notifyListeners();
  }

  /// Revient à l'écran « Qui joue ? » (depuis l'accueil, en touchant
  /// l'avatar — la fratrie partage la tablette).
  void revenirAuChoix() {
    profilActif = null;
    notifyListeners();
  }

  Future<void> rafraichirProfils() async {
    profils = await depot.profils();
    notifyListeners();
  }

  Future<void> choisirProfil(Profil profil) async {
    profilActif = profil;
    await reglages.setProfilActif(profil.id!);
    notifyListeners();
  }

  Future<void> creerProfil(String nom, String avatar, int age) async {
    final profil = await depot.creerProfil(
      nom: nom,
      avatar: avatar,
      ageDeclare: age,
    );
    await rafraichirProfils();
    await choisirProfil(profil);
  }

  /// L'enfant peut-il encore jouer aujourd'hui ?
  bool peutJouer(Profil profil) => reglages.peutJouer(profil.id!);

  /// Minutes restantes avant la limite, ou null si illimité.
  int? minutesRestantes(Profil profil) {
    final limite = reglages.limiteMinutes(profil.id!);
    if (limite <= 0) return null;
    final restant = limite - reglages.minutesAujourdhui(profil.id!);
    return restant < 0 ? 0 : restant;
  }
}
