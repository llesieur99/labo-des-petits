import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import 'cible_tactile.dart';

/// Une seule barre garde Quitter, progression et Répète à portée de main.
class BarreConsigne extends StatelessWidget {
  final VoidCallback onRepeter;
  final VoidCallback? onQuitter;
  final String? prenom;
  final VoidCallback? onMontrerGeste;
  final int itemsFaits;
  final int itemsTotal;

  const BarreConsigne({
    super.key,
    required this.onRepeter,
    required this.itemsFaits,
    required this.itemsTotal,
    this.onQuitter,
    this.prenom,
    this.onMontrerGeste,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Palette.cremeFonce, width: 2),
    ),
    child: Row(
      children: [
        if (onQuitter != null)
          CibleTactile(
            onTap: onQuitter,
            semantique: 'Quitter le jeu',
            child: const Icon(
              Icons.close_rounded,
              size: 40,
              color: Palette.encreDouce,
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prenom != null) ...[
                Text(
                  prenom!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Semantics(
                label:
                    'Étape ${itemsFaits < itemsTotal ? itemsFaits + 1 : itemsTotal} sur $itemsTotal',
                child: ExcludeSemantics(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 5,
                    children: [
                      for (var i = 0; i < itemsTotal; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: i == itemsFaits ? 22 : 16,
                          height: 12,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: i < itemsFaits
                                ? Palette.verdure
                                : i == itemsFaits
                                ? Palette.soleil
                                : Palette.grisDoux.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onMontrerGeste != null)
          CibleTactile(
            key: const ValueKey('jeu.guide'),
            onTap: onMontrerGeste,
            semantique: 'Montrer le geste',
            child: const Icon(
              Icons.touch_app_rounded,
              size: 36,
              color: Palette.ciel,
            ),
          ),
        const SizedBox(width: 8),
        CibleTactile(
          onTap: onRepeter,
          semantique: 'Répéter la consigne',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Palette.cremeFonce, width: 3),
              ),
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              size: 40,
              color: Palette.encre,
            ),
          ),
        ),
      ],
    ),
  );
}
