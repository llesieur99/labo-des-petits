import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/avancement_geste.dart';
import '../../widgets/image_concept.dart';
import '../rappels_moteur.dart';

/// Les couleurs RÉELLES des concepts de la palette (les illustrations de
/// couleur sont des pastilles rondes) : c'est la couleur que prend la
/// cellule peinte, et le fond de la pastille dans le bandeau.
const Map<String, Color> _couleurs = <String, Color>{
  'rouge': Color(0xFFE53935),
  'jaune': Color(0xFFFDD835),
  'bleu': Color(0xFF1E88E5),
  'orange': Color(0xFFFB8C00),
  'vert': Color(0xFF43A047),
  'violet': Color(0xFF8E24AA),
};

/// La couleur d'un concept que cette version ne connaît pas : un gris doux,
/// jamais une erreur à l'écran.
Color _couleurToile(String concept) => _couleurs[concept] ?? Palette.grisDoux;

/// Moteur M7a : la toile — peindre au doigt, mélanger les couleurs, copier
/// en miroir (les ailes du papillon).
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine la mosaïque, écoute
/// les doigts et raconte ce qui vient de se passer (une couleur de mélange
/// nommée, la manche réussie) par [RappelsMoteur]. La consigne, les
/// encouragements et la progression appartiennent à l'hôte.
///
/// Rien n'est jamais raté : à quatre ans, un doigt qui tremble n'est pas une
/// faute, et une couleur posée sur une autre n'est pas une erreur — c'est un
/// MÉLANGE. Le seul jalon de la manche est la cible : assez de cellules de
/// la couleur demandée, ou toutes les taches du dessin remplies.
///
/// La toile est une grille de 16 × 16 cellules dessinée en petits carrés
/// arrondis ; le bandeau des couleurs occupe le bas de l'écran. En miroir,
/// seule la moitié GAUCHE se peint — chaque cellule posée est recopiée de
/// l'autre côté de l'axe, et les taches du dessin se remplissent toutes
/// seules sur l'aile droite.
class MoteurToile extends StatefulWidget {
  final Manche manche;

  /// Le lexique du deck actif (texte + illustration).
  final Lexique lexique;

  /// Ce que le moteur raconte à l'hôte.
  final RappelsMoteur rappels;

  const MoteurToile({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
  });

  /// Le côté de la grille : 16 × 16 = 256 cellules.
  static const int cotes = 16;

  /// La clé de la toile (les tests s'en servent pour viser une cellule).
  static const ValueKey<String> cleToile = ValueKey<String>('toile.zone');

  /// La clé d'une pastille de couleur (les tests s'en servent).
  static ValueKey<String> clePastille(String concept) =>
      ValueKey<String>('toile.pastille.$concept');

  @override
  State<MoteurToile> createState() => _MoteurToileState();
}

class _MoteurToileState extends State<MoteurToile> {
  /// Le pas d'échantillonnage d'un glissement, en cellules : bien plus fin
  /// que le doigt ne bouge entre deux événements, pour ne jamais laisser de
  /// trous dans le trait.
  static const double _pasGlissement = 0.4;

  /// Le nombre d'échantillons maximal d'un seul événement (un geste fou ne
  /// doit pas faire boucler sans fin).
  static const int _pasMaximum = 160;

  /// Le rayon du doigt, en cellules : la cellule touchée et ses voisines.
  static const double _rayonDoigt = 1;

  /// La hauteur du bandeau de palette, en bas de l'écran.
  static const double _hauteurBandeau = 110;

  /// La grille 16 × 16, ligne par ligne : concept de couleur, ou null quand
  /// la cellule est vierge.
  late List<String?> _grille;

  /// Le concept de la couleur active (la pastille choisie).
  String? _couleurActive;

  /// Les couleurs de mélange déjà nommées — une seule fois par manche.
  final Set<String> _melangesDits = <String>{};

  /// Le dernier point du doigt, en coordonnées cellules (0..16).
  Offset? _dernierPoint;

  // Une cellule reçoit la couleur une fois par trait : les échantillons
  // voisins ne doivent pas repeindre le mélange qu'ils viennent de créer.
  final Set<int> _cellulesDuTrait = {};
  int? _doigtActif;

  bool _reussi = false;
  final List<List<String?>> _traitsPrecedents = [];

  DonneesToile? get _donnees {
    final donnees = widget.manche.donnees;
    return donnees is DonneesToile ? donnees : null;
  }

  @override
  void initState() {
    super.initState();
    _recommencer();
  }

  @override
  void didUpdateWidget(covariant MoteurToile ancienne) {
    super.didUpdateWidget(ancienne);
    if (ancienne.manche.id != widget.manche.id) {
      // Manche suivante : la toile redevient vierge.
      _recommencer();
    }
  }

  /// Une manche neuve : la toile est vierge, la première pastille est active.
  void _recommencer() {
    _grille = List<String?>.filled(MoteurToile.cotes * MoteurToile.cotes, null);
    final palette = _donnees?.palette ?? const <String>[];
    _couleurActive = palette.isEmpty ? null : palette.first;
    _melangesDits.clear();
    _traitsPrecedents.clear();
    _dernierPoint = null;
    _cellulesDuTrait.clear();
    _doigtActif = null;
    _reussi = false;
  }

  // ── Les doigts ────────────────────────────────────────────────────────

  /// Le doigt touche ou glisse : on peint sous le doigt, en interpolant
  /// depuis le point précédent (un glissement rapide ne saute aucun pixel).
  void _doigt(Offset local, Size taille, DonneesToile donnees) {
    if (_couleurActive == null) return;
    final largeurCellule = taille.width / MoteurToile.cotes;
    final hauteurCellule = taille.height / MoteurToile.cotes;
    if (largeurCellule <= 0 || hauteurCellule <= 0) return;

    // Le doigt, en coordonnées cellules (0..16).
    final point = Offset(local.dx / largeurCellule, local.dy / hauteurCellule);
    final precedent = _dernierPoint;
    _dernierPoint = point;

    final points = <Offset>[point];
    if (precedent != null) {
      final dx = point.dx - precedent.dx;
      final dy = point.dy - precedent.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      final nombre = math.min((distance / _pasGlissement).ceil(), _pasMaximum);
      for (var k = 1; k < nombre; k++) {
        points.add(
          Offset(
            precedent.dx + dx * k / nombre,
            precedent.dy + dy * k / nombre,
          ),
        );
      }
    }

    var change = false;
    for (final p in points) {
      if (_peindre(donnees, p.dx, p.dy)) change = true;
    }
    if (change) setState(() {});
    _verifierReussite(donnees);
  }

  /// Peint les cellules à moins d'un rayon de doigt du point [x], [y] (en
  /// coordonnées cellules). Rend vrai si au moins une cellule a changé.
  bool _peindre(DonneesToile donnees, double x, double y) {
    final couleur = _couleurActive!;
    var change = false;
    for (
      var ligne = (y - _rayonDoigt - 0.5).ceil();
      ligne <= (y + _rayonDoigt - 0.5).floor();
      ligne++
    ) {
      if (ligne < 0 || ligne >= MoteurToile.cotes) continue;
      for (
        var colonne = (x - _rayonDoigt - 0.5).ceil();
        colonne <= (x + _rayonDoigt - 0.5).floor();
        colonne++
      ) {
        if (colonne < 0 || colonne >= MoteurToile.cotes) continue;
        // En miroir, seule la moitié GAUCHE est peignable : un doigt posé
        // à droite ne fait rien du tout.
        if (donnees.miroir && colonne >= MoteurToile.cotes ~/ 2) continue;
        final dx = colonne + 0.5 - x;
        final dy = ligne + 0.5 - y;
        if (dx * dx + dy * dy > _rayonDoigt * _rayonDoigt) continue;
        if (_peindreCellule(donnees, colonne, ligne, couleur)) change = true;
      }
    }
    return change;
  }

  /// Peint une cellule — et sa jumelle de l'autre côté de l'axe en miroir.
  bool _peindreCellule(
    DonneesToile donnees,
    int colonne,
    int ligne,
    String couleur,
  ) {
    var change = _colorier(donnees, colonne, ligne, couleur);
    if (donnees.miroir) {
      final jumelle = MoteurToile.cotes - 1 - colonne;
      if (jumelle != colonne) {
        change = _colorier(donnees, jumelle, ligne, couleur) || change;
      }
    }
    return change;
  }

  /// Pose [couleur] sur une cellule, en respectant les règles de mélange.
  bool _colorier(DonneesToile donnees, int colonne, int ligne, String couleur) {
    final position = ligne * MoteurToile.cotes + colonne;
    if (!_cellulesDuTrait.add(position)) return false;
    final actuelle = _grille[position];
    final nouvelle = _couleurMelangee(donnees, actuelle, couleur);
    if (nouvelle == actuelle) return false;
    _grille[position] = nouvelle;
    return true;
  }

  /// La couleur qui résulte d'un doigt de [couleur] sur une cellule qui
  /// portait [actuelle] : le mélange quand les données en connaissent un
  /// (clé des deux concepts TRIÉS, ex. 'jaune+rouge'), sinon la couleur du
  /// doigt — on peint par-dessus, comme un pinceau.
  ///
  /// La PREMIÈRE fois qu'une couleur de mélange apparaît dans la manche, on
  /// la nomme (« orange ! ») ; ensuite, on la laisse parler d'elle-même.
  String _couleurMelangee(
    DonneesToile donnees,
    String? actuelle,
    String couleur,
  ) {
    if (actuelle == null || actuelle == couleur) return couleur;
    final cle = <String>[actuelle, couleur]..sort();
    final melange = donnees.melanges[cle.join('+')];
    if (melange == null) return couleur;
    if (_melangesDits.add(melange)) {
      unawaited(
        widget.rappels.dire(
          widget.lexique[melange]?.clipPour(melange) ?? 'lex.$melange',
        ),
      );
    }
    return melange;
  }

  // ── La cible ──────────────────────────────────────────────────────────

  /// Le dessin est-il rempli, ou la couleur demandée est-elle assez là ?
  /// La manche est réussie UNE seule fois.
  void _verifierReussite(DonneesToile donnees) {
    if (_reussi) return;
    final bool gagne;
    if (donnees.taches.isNotEmpty) {
      gagne = donnees.taches.every(_tacheRemplie);
    } else if (donnees.couleurObjectif != null) {
      gagne = _cellulesDe(donnees.couleurObjectif!) >= donnees.cellulesObjectif;
    } else {
      gagne = _cellulesPeintes >= donnees.cellulesObjectif;
    }
    if (!gagne) return;
    _reussi = true;
    widget.rappels.itemReussi();
  }

  int _cellulesDe(String concept) {
    var nombre = 0;
    for (final cellule in _grille) {
      if (cellule == concept) nombre++;
    }
    return nombre;
  }

  int get _cellulesPeintes {
    var nombre = 0;
    for (final cellule in _grille) {
      if (cellule != null) nombre++;
    }
    return nombre;
  }

  /// Une tache est remplie quand au moins 60 % de ses cellules ont reçu une
  /// couleur (peu importe laquelle : c'est la fête de la couleur).
  bool _tacheRemplie(PointToile tache) {
    final centreX = tache.x * MoteurToile.cotes;
    final centreY = tache.y * MoteurToile.cotes;
    final rayon = tache.rayon * MoteurToile.cotes;
    var cellules = 0;
    var peintes = 0;
    for (
      var ligne = (centreY - rayon - 0.5).ceil();
      ligne <= (centreY + rayon - 0.5).floor();
      ligne++
    ) {
      if (ligne < 0 || ligne >= MoteurToile.cotes) continue;
      for (
        var colonne = (centreX - rayon - 0.5).ceil();
        colonne <= (centreX + rayon - 0.5).floor();
        colonne++
      ) {
        if (colonne < 0 || colonne >= MoteurToile.cotes) continue;
        final dx = colonne + 0.5 - centreX;
        final dy = ligne + 0.5 - centreY;
        if (dx * dx + dy * dy > rayon * rayon) continue;
        cellules++;
        if (_grille[ligne * MoteurToile.cotes + colonne] != null) peintes++;
      }
    }
    if (cellules == 0) return false;
    return peintes * 5 >= cellules * 3;
  }

  // ── Le dessin ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final donnees = widget.manche.donnees;
    assert(
      donnees is DonneesToile,
      'Le moteur M7a attend une manche qui porte des DonneesToile '
      '(palette, mélanges, objectif, miroir, taches).',
    );
    if (donnees is! DonneesToile) {
      // Une manche mal construite ne doit jamais montrer d'erreur à un
      // enfant : on ne dessine rien.
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        final hauteurBandeau = math.min(
          _hauteurBandeau,
          math.max(94.0, contraintes.maxHeight * 0.34),
        );
        // La pastille garde la taille d'un doigt d'enfant (88 pt au mieux),
        // sans jamais déborder du bandeau.
        final cotePastille = (hauteurBandeau - 14).clamp(80.0, 88.0);
        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _toile(donnees),
                  if (_traitsPrecedents.isNotEmpty && !_reussi)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: CibleTactile(
                          key: const ValueKey('toile.annuler'),
                          semantique: 'Annuler le dernier trait',
                          onTap: () => setState(() {
                            _grille = _traitsPrecedents.removeLast();
                            _dernierPoint = null;
                          }),
                          child: const Icon(
                            Icons.undo_rounded,
                            color: Palette.encreDouce,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 4,
                    child: AvancementGeste(
                      faits: donnees.taches.isNotEmpty
                          ? donnees.taches.where(_tacheRemplie).length
                          : donnees.couleurObjectif != null
                          ? _cellulesDe(donnees.couleurObjectif!)
                          : _cellulesPeintes,
                      total: donnees.taches.isNotEmpty
                          ? donnees.taches.length
                          : donnees.cellulesObjectif,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: hauteurBandeau,
              child: _bandeau(donnees, cotePastille),
            ),
          ],
        );
      },
    );
  }

  /// La toile : plein cadre, à doigts nus (aucun geste obligatoire, aucun
  /// double-tap) — un [Listener] suffit, et rien ne peut « rater ».
  Widget _toile(DonneesToile donnees) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final taille = Size(contraintes.maxWidth, contraintes.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (evenement) {
            if (_doigtActif != null || moteurEnPause(widget.rappels)) return;
            _doigtActif = evenement.pointer;
            _cellulesDuTrait.clear();
            _dernierPoint = null;
            if (!_reussi) {
              if (_traitsPrecedents.length >= 12) _traitsPrecedents.removeAt(0);
              _traitsPrecedents.add(List.of(_grille));
            }
            _doigt(evenement.localPosition, taille, donnees);
          },
          onPointerMove: (evenement) {
            if (evenement.pointer != _doigtActif ||
                moteurEnPause(widget.rappels)) {
              return;
            }
            _doigt(evenement.localPosition, taille, donnees);
          },
          // Le doigt se lève : le prochain trait repart d'où il se posera,
          // jamais d'un trait qui traverserait la toile.
          onPointerUp: (evenement) => _finTrait(evenement.pointer),
          onPointerCancel: (evenement) => _finTrait(evenement.pointer),
          child: CustomPaint(
            key: MoteurToile.cleToile,
            painter: PeintureToile(
              grille: _grille,
              taches: donnees.taches,
              miroir: donnees.miroir,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _finTrait(int doigt) {
    if (doigt != _doigtActif) return;
    _doigtActif = null;
    _dernierPoint = null;
    _cellulesDuTrait.clear();
  }

  /// Le bandeau des couleurs, en bas : les pastilles rondes de la palette.
  /// S'il y en a trop pour la largeur, le bandeau glisse doucement — les
  /// pastilles ne rétrécissent jamais sous la taille d'un doigt d'enfant.
  Widget _bandeau(DonneesToile donnees, double cote) {
    final palette = donnees.palette;
    return Container(
      decoration: const BoxDecoration(
        color: Palette.cremeFonce,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: palette.isEmpty
          ? null
          : Center(
              child: LayoutBuilder(
                builder: (context, contraintes) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: math.max(contraintes.maxWidth - 32, 0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < palette.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          _pastille(palette[i], cote),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// Une pastille de couleur : un cercle de SA couleur, l'illustration du
  /// concept par-dessus. L'active est plus grande, cerclée de blanc et
  /// entourée d'un halo — ça se voit de loin.
  Widget _pastille(String concept, double cote) {
    final active = concept == _couleurActive;
    final couleur = _couleurToile(concept);
    return SizedBox(
      width: cote,
      height: cote,
      child: CibleTactile(
        key: MoteurToile.clePastille(concept),
        tailleMin: cote,
        semantique: widget.lexique[concept]?.texte ?? concept,
        onTap: () {
          setState(() => _couleurActive = concept);
          unawaited(
            widget.rappels.dire(
              widget.lexique[concept]?.clipPour(concept) ?? 'lex.$concept',
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: active ? cote : cote * 0.82,
          height: active ? cote : cote * 0.82,
          decoration: BoxDecoration(
            color: couleur,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: active ? 6 : 4),
            boxShadow: [
              BoxShadow(
                color: active
                    ? couleur.withValues(alpha: 0.55)
                    : const Color(0x1A000000),
                blurRadius: active ? 20 : 8,
                spreadRadius: active ? 4 : 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: ImageConcept(
              concept: concept,
              fichier: widget.lexique[concept]?.illustrationPour(concept) ?? '',
              taille: cote * (active ? 0.62 : 0.52),
            ),
          ),
        ),
      ),
    );
  }
}

/// La peinture de la toile : la mosaïque de cellules, les taches du dessin
/// en pointillé et l'axe discret du miroir.
///
/// Publique pour que les tests puissent relire [grille] — l'API du moteur,
/// elle, ne change pas pour eux.
class PeintureToile extends CustomPainter {
  /// La grille 16 × 16, ligne par ligne : concept de couleur, ou null.
  final List<String?> grille;

  /// Les taches à remplir, en coordonnées normalisées 0..1.
  final List<PointToile> taches;

  /// Vrai : l'axe du miroir se dessine au centre de la toile.
  final bool miroir;

  const PeintureToile({
    required this.grille,
    this.taches = const <PointToile>[],
    this.miroir = false,
  });

  @override
  void paint(Canvas toile, Size taille) {
    if (taille.isEmpty) return;
    if (grille.length != MoteurToile.cotes * MoteurToile.cotes) return;

    final largeurCellule = taille.width / MoteurToile.cotes;
    final hauteurCellule = taille.height / MoteurToile.cotes;
    final rayon = math.min(largeurCellule, hauteurCellule);

    // Le fond : crème foncé, pour que les carrés crème des cellules vides
    // se détachent en mosaïque douce.
    toile.drawRect(Offset.zero & taille, Paint()..color = Palette.cremeFonce);

    // Chaque cellule : un petit carré arrondi, avec un mince interstice.
    final coins = Radius.circular(math.min(3, rayon * 0.18));
    for (var ligne = 0; ligne < MoteurToile.cotes; ligne++) {
      for (var colonne = 0; colonne < MoteurToile.cotes; colonne++) {
        final concept = grille[ligne * MoteurToile.cotes + colonne];
        final carre = Rect.fromLTWH(
          colonne * largeurCellule,
          ligne * hauteurCellule,
          largeurCellule,
          hauteurCellule,
        ).deflate(rayon * 0.06);
        toile.drawRRect(
          RRect.fromRectAndRadius(carre, coins),
          Paint()
            ..color = concept == null ? Palette.creme : _couleurToile(concept),
        );
      }
    }

    // Les taches du dessin, en pointillé : ce qu'il reste à remplir. En
    // miroir, la jumelle de droite se dessine aussi — l'aile se remplit
    // toute seule, mais le petit pointillé dit où la couleur s'en va.
    if (taches.isNotEmpty) {
      final pinceau = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, rayon * 0.09)
        ..strokeCap = StrokeCap.round
        ..color = Palette.encreDouce.withValues(alpha: 0.55);
      for (final tache in taches) {
        final rx = tache.rayon * taille.width;
        final ry = tache.rayon * taille.height;
        _pointille(
          toile,
          Offset(tache.x * taille.width, tache.y * taille.height),
          rx,
          ry,
          pinceau,
        );
        if (miroir) {
          _pointille(
            toile,
            Offset((1 - tache.x) * taille.width, tache.y * taille.height),
            rx,
            ry,
            pinceau,
          );
        }
      }
    }

    // L'axe du miroir : discret, au centre.
    if (miroir) {
      final pinceau = Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = Palette.encreDouce.withValues(alpha: 0.35);
      const morceau = 14.0;
      for (var y = 0.0; y < taille.height; y += morceau * 2) {
        toile.drawLine(
          Offset(taille.width / 2, y),
          Offset(taille.width / 2, math.min(y + morceau, taille.height)),
          pinceau,
        );
      }
    }
  }

  /// Un contour en pointillé (Flutter n'a pas de trait pointillé) : on
  /// découpe l'ellipse en petits arcs.
  void _pointille(
    Canvas toile,
    Offset centre,
    double rx,
    double ry,
    Paint pinceau,
  ) {
    const morceaux = 40;
    for (var k = 0; k < morceaux; k += 2) {
      final debut = k / morceaux * 2 * math.pi;
      final fin = (k + 1) / morceaux * 2 * math.pi;
      toile.drawLine(
        centre + Offset(rx * math.cos(debut), ry * math.sin(debut)),
        centre + Offset(rx * math.cos(fin), ry * math.sin(fin)),
        pinceau,
      );
    }
  }

  /// La grille est modifiée en place par le moteur : chaque passe redessine.
  @override
  bool shouldRepaint(covariant PeintureToile ancienne) => true;
}
