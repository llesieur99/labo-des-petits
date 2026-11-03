import 'package:flutter/material.dart';

import '../../core/contenu/catalogue.dart';
import '../../core/parent/fiches_activites.dart';
import '../../core/widgets/cible_tactile.dart';
import '../../theme/libelles.dart';

class GuideParentScreen extends StatelessWidget {
  const GuideParentScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88,
      leadingWidth: 88,
      leading: CibleTactile(
        semantique: 'Retour',
        onTap: () => Navigator.of(context).pop(),
        child: const Icon(Icons.arrow_back_rounded, size: 40),
      ),
      title: const Text('Accompagner les jeux'),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Trois étapes dans chaque âge : découvrir avec des aides, pratiquer, puis jouer une partie complète. Les étoiles et collants gagnés restent acquis. Les gestes peuvent être remontrés avec le bouton main.',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          for (final activite in catalogueActivites)
            Card(
              child: ExpansionTile(
                key: ValueKey('fiche.${activite.id}'),
                title: Text(
                  activite.clips
                      .firstWhere((c) => c.id == activite.titreCle)
                      .texte,
                ),
                subtitle: Text(libelleFamille(activite.famille)),
                childrenPadding: const EdgeInsets.all(16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fichesActivites[activite.id]!.objectif,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Comment jouer\n${fichesActivites[activite.id]!.commentJouer}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Comment aider\n${fichesActivites[activite.id]!.accompagner}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
