import 'package:flutter/material.dart';

import 'cible_tactile.dart';

/// Action avec icône et libellé : le texte peut grandir ou revenir à la ligne.
class BoutonActionEnfant extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final Color couleur;
  final VoidCallback? onTap;

  const BoutonActionEnfant({
    super.key,
    required this.icone,
    required this.libelle,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => CibleTactile(
    onTap: onTap,
    semantique: libelle,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 36, color: Colors.white),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              libelle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
