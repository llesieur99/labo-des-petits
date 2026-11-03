import 'package:flutter/material.dart';

import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/image_concept.dart';
import '../../widgets/contenu_carte_concept.dart';

/// Moteur M1 : toucher la bonne image parmi N.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine les options qu'on
/// lui donne et signale le choix. La consigne, les aides, les retours et
/// la progression appartiennent à l'hôte (l'écran de jeu).
class MoteurTapPick extends StatelessWidget {
  final Manche manche;

  /// Les options à afficher (l'hôte peut en retirer pour aider).
  final List<OptionManche> options;

  /// Le lexique du deck actif (texte + illustration).
  final Lexique lexique;

  final bool afficherMots;

  final void Function(OptionManche option) onChoix;

  /// La dernière option touchée par erreur (pour un léger balancement).
  final String? derniereErreurId;
  final bool montrerIndice;
  final String? derniereReussiteId;
  final VoidCallback? onRepeter;

  const MoteurTapPick({
    super.key,
    required this.manche,
    required this.options,
    required this.lexique,
    required this.onChoix,
    this.afficherMots = false,
    this.derniereErreurId,
    this.montrerIndice = false,
    this.derniereReussiteId,
    this.onRepeter,
  });

  @override
  Widget build(BuildContext context) {
    if (manche.reperes.isEmpty) return _grille(context);
    final concept = manche.reperes.first;
    final repere = SizedBox(
      width: 104,
      height: 104,
      child: CibleTactile(
        key: const ValueKey('tapPick.repere'),
        onTap: onRepeter,
        semantique: 'Réécouter la consigne',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE9F3FF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ImageConcept(
                concept: concept,
                fichier: lexique[concept]?.illustrationPour(concept) ?? '',
                taille: 68,
              ),
              const Positioned(
                right: 6,
                bottom: 4,
                child: Icon(Icons.volume_up_rounded, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth > c.maxHeight && c.maxWidth >= 600) {
          return Row(
            children: [
              repere,
              const SizedBox(width: 16),
              Expanded(child: _grille(context)),
            ],
          );
        }
        return Column(
          children: [
            repere,
            const SizedBox(height: 12),
            Expanded(child: _grille(context)),
          ],
        );
      },
    );
  }

  Widget _grille(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        if (options.isEmpty) return const SizedBox.shrink();
        const espace = 12.0;
        final mot = afficherMots ? 44.0 : 0.0;
        var cote = 80.0;
        for (var colonnes = 1; colonnes <= options.length; colonnes++) {
          final lignes = (options.length / colonnes).ceil();
          final largeur =
              (contraintes.maxWidth - espace * (colonnes - 1)) / colonnes;
          final hauteur =
              (contraintes.maxHeight - espace * (lignes - 1)) / lignes - mot;
          final possible = (largeur < hauteur ? largeur : hauteur).clamp(
            0.0,
            220.0,
          );
          if (possible > cote) cote = possible;
        }

        return Center(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: espace,
              runSpacing: espace,
              alignment: WrapAlignment.center,
              children: [
                for (final option in options)
                  _CarteOption(
                    key: ValueKey('tapPick.option.${option.id}'),
                    concept: option.concept,
                    entree: lexique[option.concept],
                    cote: cote,
                    afficherMot: afficherMots,
                    enErreur: option.id == derniereErreurId,
                    enAide: montrerIndice && option.id == manche.bonneOptionId,
                    enReussite: option.id == derniereReussiteId,
                    onTap: () => onChoix(option),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CarteOption extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;
  final bool enErreur;
  final bool enAide;
  final bool enReussite;
  final VoidCallback onTap;

  const _CarteOption({
    super.key,
    required this.concept,
    required this.entree,
    required this.cote,
    required this.afficherMot,
    required this.enErreur,
    required this.enAide,
    required this.enReussite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Le SizedBox est INDISPENSABLE : dans un Wrap, la CibleTactile (son
    // Center interne) s'étirerait sur toute la largeur disponible et les
    // cartes s'empileraient une par ligne au lieu de se ranger côte à côte.
    return SizedBox(
      width: cote,
      height: afficherMot ? cote + 44 : cote,
      child: Semantics(
        selected: enReussite,
        child: CibleTactile(
          onTap: onTap,
          semantique: entree?.texte ?? concept,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: enErreur
                    ? const Color(0xFFE4BC73)
                    : (enAide || enReussite
                          ? const Color(0xFF4CAF87)
                          : const Color(0xFFF3E8CF)),
                width: 4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContenuCarteConcept(
                  concept: concept,
                  entree: entree,
                  cote: cote,
                  afficherMot: afficherMot,
                ),
                if (enReussite)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF278760),
                      size: 32,
                    ),
                  ),
                if (enAide && !enReussite)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(
                      Icons.touch_app_rounded,
                      color: Color(0xFF278760),
                      size: 32,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
