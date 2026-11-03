import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/lettres/chemins_lettres.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../rappels_moteur.dart';

/// Relit le path SVG du registre en [Path].
///
/// Le registre (`lib/core/contenu/lettres/chemins_lettres.dart`) n'utilise que
/// quatre ordres, tous ABSOLUS : `M` (départ), `L` (droite), `C` (cubique) et
/// `Z` (fermeture). Le moteur les relit lui-même : le fichier des chemins reste
/// une simple table de données, sans dépendance ni interpréteur SVG complet.
Path cheminDepuisSvg(String svg) {
  final jetons = RegExp(
    r'[A-Za-z]|-?\d*\.?\d+',
  ).allMatches(svg).map((entree) => entree.group(0)!).toList();
  final chemin = Path();
  var commande = '';
  var index = 0;
  var x = 0.0;
  var y = 0.0;
  while (index < jetons.length) {
    final jeton = jetons[index];
    if (jeton.length == 1 && RegExp(r'[A-Za-z]').hasMatch(jeton)) {
      commande = jeton;
      index++;
      if (commande == 'Z' || commande == 'z') chemin.close();
      continue;
    }
    switch (commande) {
      case 'M':
        x = double.parse(jetons[index]);
        y = double.parse(jetons[index + 1]);
        index += 2;
        chemin.moveTo(x, y);
        // En SVG, les nombres qui suivent un « M » sont des « L » implicites.
        commande = 'L';
      case 'L':
        x = double.parse(jetons[index]);
        y = double.parse(jetons[index + 1]);
        index += 2;
        chemin.lineTo(x, y);
      case 'C':
        final c1x = double.parse(jetons[index]);
        final c1y = double.parse(jetons[index + 1]);
        final c2x = double.parse(jetons[index + 2]);
        final c2y = double.parse(jetons[index + 3]);
        x = double.parse(jetons[index + 4]);
        y = double.parse(jetons[index + 5]);
        index += 6;
        chemin.cubicTo(c1x, c1y, c2x, c2y, x, y);
      default:
        // Ordre inconnu : on l'ignore (le registre n'en produit jamais).
        index++;
    }
  }
  return chemin;
}

/// La géométrie d'un chemin pour une boîte donnée : le carré du tracé, le
/// chemin mis à l'échelle, et les points que le doigt suit.
///
/// Le chemin vit en 0..1 (y vers le bas) ; ici il prend place dans un carré
/// inscrit dans la boîte. Le carré s'arrête à un demi-ruban des bords, pour que
/// le ruban ENTIER reste visible : à 4 ans il est très large (0,34 de l'écran)
/// et, sans cette marge, le bord de la lettre serait coupé.
///
/// Le premier point échantillonné est le point de départ : le générateur écrit
/// le chemin en commençant par lui, et la pastille du moteur se pose dessus.
class GeometrieTrace {
  /// Le nombre de points échantillonnés le long du chemin.
  static const nombrePoints = 240;

  /// Le chemin, mis à l'échelle dans la boîte (en pixels).
  final Path chemin;

  /// Les métriques du chemin (une par sous-chemin), pour découper le tracé.
  final List<PathMetric> metriques;

  /// Les points échantillonnés, presque à pas constant, dans la boîte.
  final List<Offset> points;

  /// La longueur totale du chemin, en pixels.
  final double longueur;

  /// La largeur du ruban, en pixels : `largeurRuban` × la plus petite
  /// dimension de l'écran (la règle du contenu).
  final double ruban;

  /// La distance maximale du doigt au chemin, en pixels : un demi-ruban, plus
  /// 15 % de générosité. Un doigt d'enfant de 4 ans tremble : on ne juge pas
  /// la beauté du tracé, on accueille l'à-peu-près.
  final double tolerance;

  /// Le côté du carré du tracé et son coin haut-gauche, dans la boîte.
  final double cote;
  final Offset decalage;

  /// Le point de départ (le premier point du chemin), dans la boîte.
  final Offset depart;

  /// L'index à atteindre pour que la manche soit réussie : 95 % des points.
  final int indexReussite;

  GeometrieTrace._({
    required this.chemin,
    required this.metriques,
    required this.points,
    required this.longueur,
    required this.ruban,
    required this.tolerance,
    required this.cote,
    required this.decalage,
    required this.depart,
    required this.indexReussite,
  });

  /// La géométrie d'un chemin dans une boîte donnée.
  factory GeometrieTrace.pour({
    required Size boite,
    required CheminTrace trace,
    required double largeurRuban,
  }) {
    final coteBoite = math.min(boite.width, boite.height);
    final ruban = largeurRuban * coteBoite;
    final cote = math.max(1.0, coteBoite - ruban);
    final decalage = Offset(
      (boite.width - cote) / 2,
      (boite.height - cote) / 2,
    );
    final transformation = Matrix4.identity()
      ..translateByDouble(decalage.dx, decalage.dy, 0, 1)
      ..scaleByDouble(cote, cote, 1, 1);
    final chemin = cheminDepuisSvg(
      trace.svgPath,
    ).transform(transformation.storage);

    final metriques = chemin.computeMetrics().toList();
    var longueur = 0.0;
    for (final metrique in metriques) {
      longueur += metrique.length;
    }

    final points = <Offset>[];
    for (var i = 0; i < nombrePoints; i++) {
      final distance = longueur * i / (nombrePoints - 1);
      final point = _pointA(metriques, distance);
      if (point != null) points.add(point);
    }

    return GeometrieTrace._(
      chemin: chemin,
      metriques: metriques,
      points: points,
      longueur: longueur,
      ruban: ruban,
      tolerance: ruban / 2 * 1.15,
      cote: cote,
      decalage: decalage,
      depart: points.isEmpty ? decalage : points.first,
      indexReussite: (nombrePoints * 0.95).ceil() - 1,
    );
  }

  /// Le point du chemin à [distance] (le long de tous les sous-chemins).
  static Offset? _pointA(List<PathMetric> metriques, double distance) {
    var reste = distance;
    for (final metrique in metriques) {
      if (reste <= metrique.length) {
        return metrique.getTangentForOffset(reste)?.position;
      }
      reste -= metrique.length;
    }
    if (metriques.isEmpty) return null;
    final derniere = metriques.last;
    return derniere.getTangentForOffset(derniere.length)?.position;
  }

  /// Le morceau du chemin parcouru jusqu'à [distance] : c'est lui qu'on peint
  /// en couleur gaie sous le doigt de l'enfant.
  Path portionJusqua(double distance) {
    final portion = Path();
    var reste = distance;
    for (final metrique in metriques) {
      if (reste <= 0) break;
      final fin = math.min(reste, metrique.length);
      portion.addPath(metrique.extractPath(0, fin), Offset.zero);
      reste -= fin;
    }
    return portion;
  }
}

/// Moteur M3 : suivre un chemin avec le doigt (lettre, sentier, bande de
/// coupe).
///
/// L'enfant pose son doigt sur la pastille de départ et suit le ruban. Le
/// tracé d'un enfant de 4 ans tremble : le ruban est très large, la tolérance
/// encore plus, et **rien n'est jamais raté** — on ne juge jamais la beauté
/// d'un tracé, on célèbre l'arrivée au bout. Un doigt qui sort du ruban ne
/// perd rien, un doigt levé non plus : le progrès reste acquis, et l'enfant
/// reprend au dernier point atteint, indiqué par une pastille.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine, écoute les doigts et
/// raconte à son hôte ([RappelsMoteur]) que la manche est réussie.
///
/// Note pour les tests : la pastille de départ pulse en boucle tant que le
/// tracé n'a pas commencé — avant le premier toucher, utiliser `pump()` et
/// non `pumpAndSettle()` (qui attendrait la fin d'une animation sans fin).
class MoteurTrace extends StatefulWidget {
  /// La manche à jouer ; `manche.donnees` est un [DonneesTrace]
  /// (contrat du générateur : une manche M3 porte toujours ses données).
  final Manche manche;

  /// Le lexique du deck actif. Ce moteur n'écrit aucun mot à l'écran : la
  /// lettre se suit au doigt, elle ne se lit pas encore. Le paramètre reste
  /// là comme chez les autres moteurs, pour que l'hôte n'ait rien à adapter.
  final Lexique lexique;

  /// Ce que le moteur raconte à son hôte.
  final RappelsMoteur rappels;

  const MoteurTrace({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
  });

  @override
  State<MoteurTrace> createState() => _MoteurTraceState();
}

class _MoteurTraceState extends State<MoteurTrace>
    with TickerProviderStateMixin {
  /// Le clip dit quand le chemin est suivi jusqu'au bout.
  static const _clipBravo = 'trace.bravo';

  /// La pastille de départ pulse tant que le tracé n'a pas commencé.
  late final AnimationController _pulsation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  /// Le ruban se remplit en couleur gaie quand c'est réussi (400 ms).
  late final AnimationController _fete = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  GeometrieTrace? _geometrie;
  Size? _tailleGeometrie;
  String? _idGeometrie;
  double? _largeurGeometrie;

  /// L'index le plus loin atteint : il ne redescend JAMAIS (un doigt qui
  /// tremble ne perd rien, un doigt levé ne perd rien).
  int _progresMax = 0;

  /// Le doigt a-t-il trouvé le point de départ (quand il est obligatoire) ?
  bool _departPris = false;

  bool _reussi = false;
  int? _doigtActif;

  DonneesTrace get _donnees => widget.manche.donnees as DonneesTrace;

  @override
  void didUpdateWidget(covariant MoteurTrace ancien) {
    super.didUpdateWidget(ancien);
    // L'hôte peut réutiliser le même moteur pour la manche suivante : la
    // nouvelle lettre repart d'un écran neuf.
    if (ancien.manche != widget.manche) {
      _progresMax = 0;
      _departPris = false;
      _reussi = false;
      _doigtActif = null;
      _fete.reset();
      if (!_pulsation.isAnimating) _pulsation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulsation.dispose();
    _fete.dispose();
    super.dispose();
  }

  /// La géométrie du chemin pour cette boîte (calculée une fois par taille :
  /// l'échantillonnage ne se refait pas à chaque image).
  GeometrieTrace? _geometriePour(Size taille, CheminTrace trace) {
    final memeTaille = _tailleGeometrie == taille;
    if (_geometrie != null &&
        memeTaille &&
        _idGeometrie == trace.id &&
        _largeurGeometrie == _donnees.largeurRuban) {
      return _geometrie;
    }
    final geometrie = GeometrieTrace.pour(
      boite: taille,
      trace: trace,
      largeurRuban: _donnees.largeurRuban,
    );
    _geometrie = geometrie;
    _tailleGeometrie = taille;
    _idGeometrie = trace.id;
    _largeurGeometrie = _donnees.largeurRuban;
    // Un écran qui change de taille change le nombre de points : le progrès
    // se recale sans jamais reculer plus loin que ce qui est acquis.
    _progresMax = math.min(_progresMax, geometrie.points.length - 1);
    return geometrie;
  }

  /// Le doigt touche ou glisse : on cherche le point du chemin le plus proche.
  void _suivre(Offset doigt) {
    if (_reussi) return;
    final geometrie = _geometrie;
    if (geometrie == null || geometrie.points.isEmpty) return;

    final points = geometrie.points;
    var plusProche = 0;
    var distance = double.infinity;
    // Une intersection ou un toucher à l’arrivée ne doit pas sauter la lettre.
    // La fenêtre garde une marge pour un doigt rapide et les événements espacés.
    final limite = math.min(points.length, _progresMax + 25);
    for (var i = 0; i < limite; i++) {
      final d = (points[i] - doigt).distanceSquared;
      if (d < distance) {
        distance = d;
        plusProche = i;
      }
    }

    // Loin du ruban : on ne dit RIEN — ni erreur, ni progrès. L'enfant a le
    // droit de se promener autour de la lettre.
    if (distance > geometrie.tolerance * geometrie.tolerance) return;

    // Départ obligatoire : tant que le doigt n'a pas trouvé la pastille, rien
    // n'avance (et la pastille continue de pulser pour montrer où commencer).
    if (_donnees.departOblige && !_departPris) {
      final auDepart =
          plusProche <= points.length ~/ 12 &&
          (geometrie.depart - doigt).distance <= geometrie.tolerance;
      if (!auDepart) return;
      _departPris = true;
    }

    if (plusProche <= _progresMax) return;
    final fini = plusProche >= geometrie.indexReussite;
    setState(() {
      _progresMax = plusProche;
      if (fini) _reussi = true;
    });

    // Le doigt a dépassé le départ : la pastille a montré ce qu'elle avait à
    // montrer (et l'animation sans fin s'arrête — utile aussi aux tests).
    if (_pulsation.isAnimating && _progresMax > points.length ~/ 20) {
      _pulsation.stop();
    }

    if (fini) {
      _fete.forward(from: 0);
      _annoncer();
    }
  }

  /// Le chemin est suivi jusqu'au bout : on dit le bravo, puis on annonce la
  /// réussite à l'hôte (qui enchaîne la manche suivante).
  Future<void> _annoncer() async {
    final manche = widget.manche;
    final rappels = widget.rappels;
    await rappels.dire(_clipBravo);
    if (!mounted || widget.manche != manche) return;
    rappels.itemReussi();
  }

  @override
  Widget build(BuildContext context) {
    final trace = cheminsTrace[_donnees.cheminId];
    if (trace == null) {
      // Un chemin absent du registre est une coquille de contenu : on la
      // signale fort en développement, et le jeu ne se brise jamais dans les
      // mains d'un enfant.
      assert(false, 'chemin « ${_donnees.cheminId} » absent de cheminsTrace');
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        if (!contraintes.hasBoundedWidth || !contraintes.hasBoundedHeight) {
          return const SizedBox.expand();
        }
        final geometrie = _geometriePour(contraintes.biggest, trace);
        if (geometrie == null || geometrie.points.isEmpty) {
          return const SizedBox.expand();
        }

        return Listener(
          key: const ValueKey('trace.zone'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (evenement) {
            if (_doigtActif != null) return;
            _doigtActif = evenement.pointer;
            _suivre(evenement.localPosition);
          },
          onPointerMove: (evenement) {
            if (_doigtActif == evenement.pointer) {
              _suivre(evenement.localPosition);
            }
          },
          onPointerUp: (evenement) {
            if (_doigtActif == evenement.pointer) _doigtActif = null;
          },
          onPointerCancel: (evenement) {
            if (_doigtActif == evenement.pointer) _doigtActif = null;
          },
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulsation, _fete]),
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _PeintureTrace(
                  geometrie: geometrie,
                  progresMax: _progresMax,
                  reussi: _reussi,
                  fete: _fete.value,
                  pulsation: _pulsation.value,
                  departOblige: _donnees.departOblige,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Le dessin : le ruban à suivre, le pointillé du milieu, la pastille de
/// départ, et le tracé de l'enfant en couleur gaie.
class _PeintureTrace extends CustomPainter {
  final GeometrieTrace geometrie;
  final int progresMax;
  final bool reussi;
  final double fete;
  final double pulsation;
  final bool departOblige;

  const _PeintureTrace({
    required this.geometrie,
    required this.progresMax,
    required this.reussi,
    required this.fete,
    required this.pulsation,
    required this.departOblige,
  });

  @override
  void paint(Canvas canvas, Size taille) {
    final ruban = geometrie.ruban;
    final bord = math.max(1.5, ruban * 0.06);
    final pinceau = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ── Le ruban : crème foncé, bord doux — la route à suivre ──
    canvas.drawPath(
      geometrie.chemin,
      pinceau
        ..strokeWidth = ruban + 2 * bord
        ..color = Palette.grisDoux,
    );
    canvas.drawPath(
      geometrie.chemin,
      pinceau
        ..strokeWidth = ruban
        ..color = Palette.cremeFonce,
    );

    // ── Le fin pointillé du milieu : le cœur du chemin ──
    final pointille = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, ruban * 0.035)
      ..color = Palette.encreDouce.withValues(alpha: 0.35);
    _pointiller(canvas, pointille, ruban);

    // ── Le tracé du doigt (soleil), puis la fête (verdure, 400 ms) ──
    final courbe = Curves.easeOutCubic.transform(fete);
    final part = reussi
        ? _melanger((progresMax + 1) / GeometrieTrace.nombrePoints, 1, courbe)
        : (progresMax + 1) / GeometrieTrace.nombrePoints;
    if (part > 0) {
      final couleur = reussi
          ? Color.lerp(Palette.soleil, Palette.verdure, courbe)!
          : Palette.soleil;
      canvas.drawPath(
        geometrie.portionJusqua(geometrie.longueur * part),
        pinceau
          ..strokeWidth = ruban * 0.92
          ..color = couleur,
      );
    }

    if (progresMax > 0 && !reussi) {
      // Une reprise visible sous un doigt d'enfant, même sur les rubans fins.
      // La flèche montre le sens à suivre sans texte ni consigne supplémentaire.
      final ici = geometrie.points[progresMax];
      final ensuite = geometrie
          .points[math.min(progresMax + 16, geometrie.points.length - 1)];
      canvas.drawCircle(
        ici,
        math.max(20, ruban * 0.24),
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
      final direction = ensuite - ici;
      if (direction.distance > 1) {
        final axe = direction / direction.distance;
        final travers = Offset(-axe.dy, axe.dx);
        final centre = ici + axe * math.max(24, ruban * 0.35);
        final fleche = Path()
          ..moveTo(
            (centre - axe * 7 + travers * 7).dx,
            (centre - axe * 7 + travers * 7).dy,
          )
          ..lineTo(centre.dx, centre.dy)
          ..lineTo(
            (centre - axe * 7 - travers * 7).dx,
            (centre - axe * 7 - travers * 7).dy,
          );
        canvas.drawPath(
          fleche,
          Paint()
            ..color = Palette.encreDouce
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      canvas.drawCircle(
        geometrie.points[progresMax],
        math.max(8, ruban * 0.16),
        Paint()..color = Palette.encreDouce,
      );
      canvas.drawCircle(
        geometrie.points[progresMax],
        math.max(4, ruban * 0.08),
        Paint()..color = Colors.white,
      );
    }

    // ── La pastille de départ : elle pulse tant que le tracé n'a pas commencé,
    //    puis s'efface doucement une fois le doigt lancé ──
    final opacite = (1 - progresMax / (GeometrieTrace.nombrePoints * 0.05))
        .clamp(0.0, 1.0);
    if (opacite <= 0) return;
    final rayon = ruban * (departOblige ? 0.5 : 0.4) * (0.9 + 0.2 * pulsation);
    canvas.drawCircle(
      geometrie.depart,
      rayon,
      Paint()..color = Palette.soleil.withValues(alpha: opacite),
    );
    canvas.drawCircle(
      geometrie.depart,
      rayon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, ruban * 0.05)
        ..color = Palette.encreDouce.withValues(alpha: opacite * 0.8),
    );
  }

  /// Le pointillé du milieu du ruban (Flutter n'a pas de tirets : on découpe
  /// le chemin en petits morceaux, comme les cases vides de M5).
  void _pointiller(Canvas canvas, Paint pinceau, double ruban) {
    final tiret = math.max(4, ruban * 0.16);
    final trou = math.max(4, ruban * 0.14);
    for (final metrique in geometrie.metriques) {
      var debut = 0.0;
      while (debut < metrique.length) {
        final fin = math.min(debut + tiret, metrique.length);
        canvas.drawPath(metrique.extractPath(debut, fin), pinceau);
        debut = fin + trou;
      }
    }
  }

  double _melanger(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _PeintureTrace ancien) =>
      ancien.geometrie != geometrie ||
      ancien.progresMax != progresMax ||
      ancien.reussi != reussi ||
      ancien.fete != fete ||
      ancien.pulsation != pulsation ||
      ancien.departOblige != departOblige;
}
