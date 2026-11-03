import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/palette.dart';

/// L'illustration d'un concept (objet, animal…).
///
/// Le fichier vient du lexique ; s'il manque, on affiche une tuile douce
/// plutôt qu'une erreur — y compris dans les tests, où les assets ne sont
/// pas chargés.
class ImageConcept extends StatefulWidget {
  final String concept;
  final String fichier;
  final double taille;

  const ImageConcept({
    super.key,
    required this.concept,
    this.fichier = '',
    this.taille = 96,
  });

  @override
  State<ImageConcept> createState() => _ImageConceptState();
}

class _ImageConceptState extends State<ImageConcept> {
  /// Cache des SVG lus par nom de fichier : '' = introuvable.
  static final Map<String, String> _cache = {};

  bool _charge = false;
  String? _svg;

  String get _nomFichier =>
      widget.fichier.isEmpty ? '${widget.concept}.svg' : widget.fichier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_charge) _charger();
  }

  @override
  void didUpdateWidget(covariant ImageConcept ancien) {
    super.didUpdateWidget(ancien);
    final ancienNom = ancien.fichier.isEmpty
        ? '${ancien.concept}.svg'
        : ancien.fichier;
    if (ancienNom != _nomFichier) {
      _charge = false;
      _svg = null;
      _charger();
    }
  }

  Future<void> _charger() async {
    final nom = _nomFichier;
    final enCache = _cache[nom];
    if (enCache != null) {
      setState(() {
        _svg = enCache.isEmpty ? null : enCache;
        _charge = true;
      });
      return;
    }
    String? svg;
    try {
      svg = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/images/concepts/$nom');
    } catch (_) {
      svg = null;
    }
    _cache[nom] = svg ?? '';
    if (!mounted || _nomFichier != nom) return;
    setState(() {
      _svg = svg;
      _charge = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final svg = _svg;
    if (svg == null) {
      // Tuile de secours : douce, colorée, jamais une erreur visible.
      return Container(
        width: widget.taille,
        height: widget.taille,
        decoration: BoxDecoration(
          color: Palette.tuilePour(widget.concept).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(widget.taille * 0.25),
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          size: widget.taille * 0.4,
          color: Palette.tuilePour(widget.concept),
        ),
      );
    }
    return SvgPicture.string(
      svg,
      width: widget.taille,
      height: widget.taille,
      semanticsLabel: widget.concept,
    );
  }
}
