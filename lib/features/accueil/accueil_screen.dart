import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/say_kit.dart';
import '../../core/identite.dart';
import '../../core/contenu/catalogue.dart';
import '../../core/contenu/modele/activite.dart';
import '../../core/parent/portail_parent.dart';
import '../../core/progression/modele.dart';
import '../../core/widgets/cible_tactile.dart';
import '../../core/widgets/image_concept.dart';
import '../../core/widgets/grille_cartes.dart';
import '../../theme/libelles.dart';
import '../../theme/palette.dart';
import '../../theme/theme_enfant.dart';
import '../famille/famille_screen.dart';
import '../jardin/jardin_screen.dart';
import '../parent/parent_screen.dart';
import '../shell/shell_controller.dart';

/// L'écran d'accueil de l'enfant : les familles de jeux en grandes tuiles,
/// son avatar, et le mur de collants.
class AccueilScreen extends StatelessWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final profil = shell.profilActif;
    final familles = Famille.values
        .where((f) => activitesDe(f).isNotEmpty)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  // Toucher son avatar : « Qui joue ? » — la fratrie
                  // partage la tablette, chacun a sa progression.
                  CibleTactile(
                    semantique: 'Changer de joueur',
                    onTap: () =>
                        context.read<ShellController>().revenirAuChoix(),
                    child: Stack(
                      children: [
                        _Avatar(profil: profil),
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(
                            Icons.switch_account_rounded,
                            size: 24,
                            color: Palette.ciel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          Identite.nom,
                          style: TextStyle(
                            fontSize: 17,
                            color: Palette.encreDouce,
                          ),
                        ),
                        Text(
                          profil?.nom ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Palette.encre,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // L'espace parent, discret et verrouillé.
                  CibleTactile(
                    onTap: () => _ouvrirParent(context),
                    semantique: 'Espace des parents',
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 34,
                        color: Palette.grisDoux,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GrilleCartes(
                largeurMin: 144,
                enfants: [
                  for (var i = 0; i < familles.length; i++)
                    _TuileFamille(
                      famille: familles[i],
                      couleur: Palette.familles[i % Palette.familles.length],
                    ),
                  CibleTactile(
                    semantique: 'Mes collants',
                    onTap: () => Navigator.of(
                      context,
                    ).push(routeDouce(const JardinScreen())),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Palette.prune.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Palette.prune.withValues(alpha: 0.45),
                          width: 3,
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 64,
                            color: Palette.prune,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Mes collants',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _ouvrirParent(BuildContext context) async {
    await context.read<SayKit>().stopper();
    if (!context.mounted) return;
    Navigator.of(context).push(
      routeDouce(
        PortailParent(
          onReussi: () => Navigator.of(
            context,
          ).pushReplacement(routeDouce(const ParentScreen())),
          onAnnuler: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Profil? profil;

  const _Avatar({this.profil});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: Palette.cremeFonce, width: 3),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: ImageConcept(concept: profil?.avatar ?? 'chat', taille: 48),
    );
  }
}

/// Une « île » : la famille de jeux.
class _TuileFamille extends StatelessWidget {
  final Famille famille;
  final Color couleur;

  const _TuileFamille({required this.famille, required this.couleur});

  @override
  Widget build(BuildContext context) {
    final jeux = activitesDe(famille).take(2).toList();
    return CibleTactile(
      semantique: famille.id,
      onTap: () {
        Navigator.of(context).push(routeDouce(FamilleScreen(famille: famille)));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: couleur.withValues(alpha: 0.55), width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Les dessins des vrais jeux parlent davantage à un enfant qui
            // ne lit pas que des pictogrammes abstraits de catégories.
            SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < jeux.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    ImageConcept(
                      concept: jeux[i].id,
                      fichier: jeux[i].illustration,
                      taille: 44,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              libelleFamille(famille),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
