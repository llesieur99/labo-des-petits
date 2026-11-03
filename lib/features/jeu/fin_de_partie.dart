import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/progression/modele.dart';
import '../../core/widgets/bouton_action_enfant.dart';
import '../../theme/palette.dart';

/// Les récompenses et les deux actions restent accessibles, même en paysage.
class FinDePartie extends StatefulWidget {
  final ResumePartie resume;
  final int nouveauxCollants;
  final VoidCallback onRejouer;
  final VoidCallback onRetour;

  const FinDePartie({
    super.key,
    required this.resume,
    required this.onRejouer,
    required this.onRetour,
    this.nouveauxCollants = 0,
  });

  @override
  State<FinDePartie> createState() => _FinDePartieState();
}

class _FinDePartieState extends State<FinDePartie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entree = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _entree.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: LayoutBuilder(
          builder: (context, place) {
            final taille = math.min(96.0, (place.maxWidth - 32) / 3);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _entree,
                          curve: Interval(
                            i * 0.22,
                            i * 0.22 + 0.5,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: Icon(
                          i < widget.resume.etoiles
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: taille,
                          color: i < widget.resume.etoiles
                              ? Palette.soleil
                              : Palette.grisDoux,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                if (widget.nouveauxCollants > 0) ...[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 40,
                    color: Palette.prune,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.nouveauxCollants > 1
                        ? '${widget.nouveauxCollants} nouveaux collants !'
                        : 'Un nouveau collant !',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Palette.prune,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    BoutonActionEnfant(
                      icone: Icons.replay_rounded,
                      libelle: 'Encore !',
                      couleur: Palette.verdure,
                      onTap: widget.onRejouer,
                    ),
                    BoutonActionEnfant(
                      icone: Icons.home_rounded,
                      libelle: 'Retour',
                      couleur: Palette.ciel,
                      onTap: widget.onRetour,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
