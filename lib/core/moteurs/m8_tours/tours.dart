import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/lexique.dart';
import '../../widgets/image_concept.dart';
import '../rappels_moteur.dart';

/// L'état du tour, créé par l'écran de jeu (UNE fois par partie) et passé
/// au moteur. L'hôte appelle [changerDeTour] à chaque nouvelle manche.
class ToursController extends ChangeNotifier {
  /// Vrai quand c'est au tour du premier enfant : la moitié de GAUCHE,
  /// celle du profil actif. On commence toujours par lui.
  bool tourDuPremier = true;

  void changerDeTour() {
    tourDuPremier = !tourDuPremier;
    notifyListeners();
  }
}

/// Moteur M8 : « à tour de rôle » — deux enfants, une seule tablette.
///
/// L'app donne le tour : la moitié active contient le moteur interne
/// ([enfant]), l'autre moitié attend calmement. Un doigt sur la moitié
/// inactive n'a AUCUNE conséquence : pas de son, pas de sanction, juste
/// un petit « non » visuel doux.
///
/// Le moteur ne contient aucune pédagogie : il annonce le tour qui
/// commence (clips) et laisse l'hôte décider quand changer de tour.
class MoteurTours extends StatelessWidget {
  /// Le moteur interne à afficher du côté actif (ex. MoteurTapPick).
  final Widget enfant;

  /// L'état du tour, partagé avec l'hôte.
  final ToursController tours;

  /// Le lexique du deck actif (pour l'image d'attente).
  final Lexique lexique;

  final RappelsMoteur rappels;

  /// Clip « À ton tour ! ».
  final String clipsMonTour;

  /// Clip « À l'autre tour ! ».
  final String clipsAutreTour;

  const MoteurTours({
    super.key,
    required this.enfant,
    required this.tours,
    required this.lexique,
    required this.rappels,
    required this.clipsMonTour,
    required this.clipsAutreTour,
  });

  @override
  Widget build(BuildContext context) {
    return _EspaceTours(
      enfant: enfant,
      tours: tours,
      lexique: lexique,
      rappels: rappels,
      clipsMonTour: clipsMonTour,
      clipsAutreTour: clipsAutreTour,
    );
  }
}

/// La partie vivante : elle écoute le tour (pour l'annoncer) et dessine
/// les deux moitiés. Privé — le contrat public reste [MoteurTours].
class _EspaceTours extends StatefulWidget {
  final Widget enfant;
  final ToursController tours;
  final Lexique lexique;
  final RappelsMoteur rappels;
  final String clipsMonTour;
  final String clipsAutreTour;

  const _EspaceTours({
    required this.enfant,
    required this.tours,
    required this.lexique,
    required this.rappels,
    required this.clipsMonTour,
    required this.clipsAutreTour,
  });

  @override
  State<_EspaceTours> createState() => _EspaceToursState();
}

class _EspaceToursState extends State<_EspaceTours> {
  @override
  void initState() {
    super.initState();
    widget.tours.addListener(_tourChange);
    // Le tour du départ s'annonce une fois l'écran posé (jamais pendant
    // un build : le clip part par le SayKit, qui a le droit d'être lent).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _annoncer();
    });
  }

  @override
  void didUpdateWidget(covariant _EspaceTours ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.tours != widget.tours) {
      ancien.tours.removeListener(_tourChange);
      widget.tours.addListener(_tourChange);
    }
  }

  @override
  void dispose() {
    widget.tours.removeListener(_tourChange);
    super.dispose();
  }

  void _tourChange() {
    if (!mounted) return;
    setState(() {});
    _annoncer();
  }

  /// Dire le tour qui commence — c'est tout ce que l'app a besoin de dire.
  void _annoncer() {
    widget.rappels.dire(
      widget.tours.tourDuPremier ? widget.clipsMonTour : widget.clipsAutreTour,
    );
  }

  @override
  Widget build(BuildContext context) {
    final premierJoue = widget.tours.tourDuPremier;
    return LayoutBuilder(
      builder: (context, place) {
        // Deux demi-écrans conviennent à la tablette. Sur un téléphone,
        // le jeu garde toute sa largeur et l'attente devient un bandeau.
        final compact = place.maxWidth < 600;
        return Column(
          children: [
            _BandeauTour(premierJoue: premierJoue),
            if (compact) ...[
              SizedBox(
                height: 88,
                child: Row(
                  children: [
                    _moitie(false, gauche: !premierJoue, compact: true),
                  ],
                ),
              ),
              Expanded(
                child: Row(children: [_moitie(true, gauche: premierJoue)]),
              ),
            ] else
              Expanded(
                child: Row(
                  children: [
                    _moitie(premierJoue, gauche: true),
                    _moitie(!premierJoue, gauche: false),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Une moitié verticale de l'écran : le moteur si c'est le tour, sinon
  /// le panneau calme. La moitié active s'allume (AnimatedContainer).
  Widget _moitie(bool active, {required bool gauche, bool compact = false}) {
    return Expanded(
      child: AnimatedContainer(
        key: ValueKey(gauche ? 'tours.moitie.gauche' : 'tours.moitie.droite'),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: active
                ? Palette.soleil.withValues(alpha: 0.8)
                : Colors.transparent,
            width: 4,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: active
            ? _Apparition(child: widget.enfant)
            : _PanneauCalme(
                entreeEnfant: compact ? null : widget.lexique['enfant'],
              ),
      ),
    );
  }
}

/// Le bandeau du haut : « À ton tour ! » du côté actif, rien d'autre.
/// Il glisse d'une moitié à l'autre quand le tour change.
class _BandeauTour extends StatelessWidget {
  final bool premierJoue;

  const _BandeauTour({required this.premierJoue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(
        height: 84,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: premierJoue ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            key: const ValueKey('tours.bandeau'),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Palette.soleil, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.waving_hand_rounded,
                  size: 34,
                  color: Palette.corail,
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'À ton tour !',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Palette.encre,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  premierJoue
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  size: 30,
                  color: Palette.soleil,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La moitié qui attend : crème, calme, coins 28. Un doigt dessus ne fait
/// rien d'autre qu'un petit « non » visuel tout doux — jamais de son,
/// jamais de reproche, jamais de texte.
class _PanneauCalme extends StatefulWidget {
  /// L'entrée du concept 'enfant' si le deck la connaît (sinon : une main).
  final EntreeLexique? entreeEnfant;

  const _PanneauCalme({required this.entreeEnfant});

  @override
  State<_PanneauCalme> createState() => _PanneauCalmeState();
}

class _PanneauCalmeState extends State<_PanneauCalme>
    with SingleTickerProviderStateMixin {
  /// Au repos : 1 (aucune animation en cours, rien ne tourne pour rien).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pulse.forward(from: 0),
      child: AnimatedBuilder(
        animation: _pulse,
        child: _contenu(),
        builder: (context, enfant) => Transform.scale(
          // Deux petites poussées de 150 ms : « pas toi, attends ».
          scale: 1 + 0.06 * math.sin(_pulse.value * 2 * math.pi).abs(),
          child: enfant,
        ),
      ),
    );
  }

  Widget _contenu() {
    final entree = widget.entreeEnfant;
    return Container(
      decoration: BoxDecoration(
        color: Palette.creme,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Palette.cremeFonce, width: 4),
      ),
      child: Center(
        // Le message visuel, grisé : c'est la moitié qui attend.
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_gris),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: const BoxDecoration(
                    color: Palette.cremeFonce,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.back_hand_rounded,
                    size: 62,
                    color: Palette.encreDouce,
                  ),
                ),
                if (entree != null) ...[
                  const SizedBox(height: 16),
                  ImageConcept(
                    concept: 'enfant',
                    fichier: entree.illustrationPour('enfant'),
                    taille: 96,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le gris de la moitié qui attend (luminance, aucune couleur).
const List<double> _gris = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// L'arrivée du moteur du côté qui prend le tour : il apparaît en douceur.
class _Apparition extends StatelessWidget {
  final Widget child;

  const _Apparition({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: child,
      builder: (context, avancement, enfant) => Opacity(
        opacity: avancement,
        child: Transform.scale(scale: 0.96 + 0.04 * avancement, child: enfant),
      ),
    );
  }
}
