import 'package:flutter/material.dart';

/// Tout ce qui se touche dans l'app passe par ici.
///
/// Règles d'ergonomie enfant : au moins 80 points de côté, un léger
/// enfoncement à l'appui, jamais de double-tap, jamais de geste obligatoire.
class CibleTactile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double tailleMin;
  final String? semantique;

  const CibleTactile({
    super.key,
    required this.child,
    this.onTap,
    this.tailleMin = 80,
    this.semantique,
  });

  @override
  State<CibleTactile> createState() => _CibleTactileState();
}

class _CibleTactileState extends State<CibleTactile> {
  bool _presse = false;

  void _changer(bool presse) {
    if (_presse != presse) setState(() => _presse = presse);
  }

  @override
  Widget build(BuildContext context) {
    final actif = widget.onTap != null;
    return Semantics(
      label: widget.semantique,
      button: actif,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: actif ? (_) => _changer(true) : null,
        onTapUp: actif ? (_) => _changer(false) : null,
        onTapCancel: actif ? () => _changer(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _presse ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.tailleMin,
              minHeight: widget.tailleMin,
            ),
            // La cible ne doit pas s'étirer sur un Wrap ou recouvrir une carte
            // voisine ; des contraintes serrées peuvent toujours la remplir.
            child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
          ),
        ),
      ),
    );
  }
}
