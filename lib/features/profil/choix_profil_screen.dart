import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/parent/portail_parent.dart';
import '../../core/widgets/cible_tactile.dart';
import '../../core/widgets/image_concept.dart';
import '../../core/widgets/grille_cartes.dart';
import '../../core/widgets/bouton_action_enfant.dart';
import '../../theme/palette.dart';
import '../../theme/theme_enfant.dart';
import '../shell/shell_controller.dart';
import 'creation_profil_screen.dart';

/// Le choix du joueur quand la fratrie partage l'appareil.
class ChoixProfilScreen extends StatelessWidget {
  const ChoixProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Qui joue ?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Palette.encre,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GrilleCartes(
                  largeurMin: 150,
                  padding: EdgeInsets.zero,
                  enfants: [
                    for (final profil in shell.profils)
                      CibleTactile(
                        semantique: profil.nom,
                        onTap: () => context
                            .read<ShellController>()
                            .choisirProfil(profil),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Palette.cremeFonce,
                              width: 4,
                            ),
                          ),
                          child: Column(
                            children: [
                              ImageConcept(concept: profil.avatar, taille: 84),
                              const SizedBox(height: 10),
                              Text(
                                profil.nom,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Palette.encre,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Ajouter un enfant : une action de parent, derrière le portail.
              Center(
                child: BoutonActionEnfant(
                  icone: Icons.person_add_alt_1_rounded,
                  libelle: 'Ajouter un enfant',
                  couleur: Palette.ciel,
                  onTap: () => Navigator.of(context).push(
                    routeDouce(
                      PortailParent(
                        onReussi: () => Navigator.of(context).pushReplacement(
                          routeDouce(
                            const CreationProfilScreen(premier: false),
                          ),
                        ),
                        onAnnuler: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
