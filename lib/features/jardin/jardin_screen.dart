import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/contenu/catalogue.dart';
import '../../core/contenu/modele/activite.dart';
import '../../core/progression/collants.dart';
import '../../core/progression/depot.dart';
import '../../core/progression/modele.dart';
import '../../theme/palette.dart';
import '../../core/widgets/cible_tactile.dart';
import '../../core/widgets/collant.dart';
import '../shell/shell_controller.dart';

/// Le grand mur de collants : ce que l'enfant a débloqué, activité par
/// activité. Un collant gagné ne se perd JAMAIS.
class JardinScreen extends StatelessWidget {
  const JardinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profil = context.watch<ShellController>().profilActif;
    if (profil == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 88,
        leadingWidth: 88,
        title: const Text(
          'Mes collants',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Palette.encre,
          ),
        ),
        leading: CibleTactile(
          onTap: () => Navigator.of(context).pop(),
          semantique: 'Retour',
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 44,
            color: Palette.encreDouce,
          ),
        ),
      ),
      body: FutureBuilder<List<EtatActivite>>(
        future: context.read<DepotProgression>().etats(profil.id!),
        builder: (context, instantane) {
          final etats = <String, EtatActivite>{
            for (final etat in instantane.data ?? const <EtatActivite>[])
              etat.activiteId: etat,
          };
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final activite in catalogueActivites)
                _MurActivite(activite: activite, etat: etats[activite.id]),
            ],
          );
        },
      ),
    );
  }
}

class _MurActivite extends StatelessWidget {
  final Activite activite;
  final EtatActivite? etat;

  const _MurActivite({required this.activite, required this.etat});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activite.clips.firstWhere((c) => c.id == activite.titreCle).texte,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                for (final type in TypeCollant.values)
                  Collant(type: type, gagne: type.gagne(etat)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
