import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/parent/portail_parent.dart';
import '../../core/widgets/cible_tactile.dart';
import '../../theme/palette.dart';
import '../../theme/theme_enfant.dart';
import '../accueil/accueil_screen.dart';
import '../parent/parent_screen.dart';
import '../profil/choix_profil_screen.dart';
import '../profil/creation_profil_screen.dart';
import 'shell_controller.dart';

/// L'aiguillage de départ : premier lancement, choix du joueur, ou l'heure
/// de ranger les jouets.
class PortailApp extends StatelessWidget {
  const PortailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();

    if (!shell.pret) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (shell.profils.isEmpty) {
      return const CreationProfilScreen(premier: true);
    }
    final profil = shell.profilActif;
    if (profil == null) {
      return const ChoixProfilScreen();
    }
    if (!shell.peutJouer(profil)) {
      return const EcranBonneJournee();
    }
    return const AccueilScreen();
  }
}

/// L'écran calme quand le temps de jeu du jour est fini.
/// Aucune punition, aucune explication d'adulte : on range, à demain.
class EcranBonneJournee extends StatelessWidget {
  const EcranBonneJournee({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.nightlight_round,
                  size: 120, color: Palette.prune),
              const SizedBox(height: 24),
              const Text(
                'On range les jouets.\nÀ demain !',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Palette.encre),
              ),
              const SizedBox(height: 48),
              // Le parent peut déverrouiller derrière son portail.
              CibleTactile(
                semantique: 'Espace des parents',
                onTap: () => Navigator.of(context).push(routeDouce(
                  PortailParent(
                    onReussi: () => Navigator.of(context).pushReplacement(
                        routeDouce(const ParentScreen())),
                    onAnnuler: () => Navigator.of(context).pop(),
                  ),
                )),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Parent',
                      style:
                          TextStyle(fontSize: 18, color: Palette.grisDoux)),
                ),
              ),
              if (shell.profilActif?.nom != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'Bravo ${shell.profilActif!.nom} !',
                    style: const TextStyle(
                        fontSize: 24, color: Palette.verdure),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
