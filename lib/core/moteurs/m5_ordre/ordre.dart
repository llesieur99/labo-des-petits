import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/contenu_carte_concept.dart';
import '../rappels_moteur.dart';

/// Moteur M5 : reconstruire une séquence (« L'histoire en quatre cases »).
///
/// En haut, les cases vides de l'histoire ; en bas, les images mélangées.
/// L'enfant touche les images une à une : chacune vient se poser dans la
/// prochaine case vide, de gauche à droite. Aucun réarrangement, aucun
/// glisser obligatoire — c'est ce qui rend le jeu possible à 4 ans.
///
/// Le moteur ne contient AUCUNE pédagogie et ne dit PAS les images isolément :
/// il dessine, écoute les doigts, raconte l'histoire quand elle est complète
/// et signale le reste à son hôte (RappelsMoteur).
class MoteurOrdre extends StatefulWidget {
  /// La manche à jouer ; `manche.donnees` est un [DonneesOrdre]
  /// (contrat du générateur : une manche M5 porte toujours ses données).
  final Manche manche;

  /// Le lexique du deck actif (illustrations, mots écrits).
  final Lexique lexique;

  /// Afficher les mots sous les images (paliers 6-7 ans).
  final bool afficherMots;

  /// Ce que le moteur raconte à son hôte.
  final RappelsMoteur rappels;

  const MoteurOrdre({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
    this.afficherMots = false,
  });

  @override
  State<MoteurOrdre> createState() => _MoteurOrdreState();
}

class _MoteurOrdreState extends State<MoteurOrdre> {
  /// Les données de la manche (le générateur garantit le type).
  DonneesOrdre get _donnees => widget.manche.donnees as DonneesOrdre;

  /// Les options déjà posées, par leur id : elles quittent la rangée du bas.
  final Set<String> _posees = <String>{};
  final ScrollController _defilement = ScrollController();

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  /// Nombre de cases remplies = index de la prochaine case vide.
  int get _remplies => _posees.length;

  /// La dernière image touchée par erreur (petit balancement, jamais punie).
  String? _erreurId;
  int _erreurTick = 0;

  bool get _fini => _remplies >= _donnees.cases.length;

  @override
  void didUpdateWidget(covariant MoteurOrdre ancien) {
    super.didUpdateWidget(ancien);
    // L'hôte peut réutiliser le même moteur pour la manche suivante
    // (l'élément survit) : l'histoire neuve repart d'un écran neuf.
    if (ancien.manche != widget.manche) {
      _posees.clear();
      _erreurId = null;
      _erreurTick = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _defilement.hasClients) _defilement.jumpTo(0);
      });
    }
  }

  void _toucher(OptionManche option) {
    if (_fini || moteurEnPause(widget.rappels)) return;
    // On construit strictement de gauche à droite : la seule bonne image
    // est celle de la prochaine case vide.
    if (option.concept != _donnees.cases[_remplies]) {
      setState(() {
        _erreurId = option.id;
        _erreurTick++;
      });
      widget.rappels.essaiRate();
      return;
    }

    setState(() {
      _posees.add(option.id);
      _erreurId = null;
      _erreurTick = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_defilement.hasClients) return;
      _defilement.animateTo(
        _defilement.position.maxScrollExtent *
            (_remplies / _donnees.cases.length),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
    if (_fini) _raconterLHistoire();
  }

  /// Toutes les cases sont remplies : on raconte l'histoire en entier,
  /// puis on annonce la réussite à l'hôte.
  Future<void> _raconterLHistoire() async {
    final manche = widget.manche;
    final narration = _donnees.narrationCle;
    if (narration != null) await widget.rappels.dire(narration);
    if (!mounted || !identical(widget.manche, manche)) return;
    widget.rappels.itemReussi();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final nombreCases = _donnees.cases.length;

        final coteCase = _coteQuiRentre(
          dispo: contraintes.maxWidth,
          hauteurMax: contraintes.maxHeight * 0.34,
          nombre: nombreCases,
          espaces: 12,
          plafond: 168,
        );
        final coteImage = _coteQuiRentre(
          dispo: contraintes.maxWidth,
          hauteurMax: contraintes.maxHeight * 0.52,
          nombre: widget.manche.options.length,
          espaces: 20,
          plafond: 190,
        );

        return Column(
          children: [
            // ── Les cases de l'histoire (vides, puis remplies en ordre) ──
            SizedBox(
              height: coteCase + (widget.afficherMots ? 44 : 0),
              child: SingleChildScrollView(
                controller: _defilement,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: contraintes.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < nombreCases; i++)
                        if (i < _remplies)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _casePosee(i, coteCase),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _CaseVide(
                              key: ValueKey('ordre.case.$i'),
                              cote: coteCase,
                              active: i == _remplies,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // ── Les images de l'histoire, mélangées (ordre du générateur) ──
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final option in widget.manche.options)
                        SizedBox(
                          width: coteImage,
                          height: coteImage + (widget.afficherMots ? 44 : 0),
                          child: _posees.contains(option.id)
                              ? const SizedBox.shrink()
                              : _Balancement(
                                  tick: option.id == _erreurId
                                      ? _erreurTick
                                      : 0,
                                  child: _CarteHistoire(
                                    option: option,
                                    entree: widget.lexique[option.concept],
                                    cote: coteImage,
                                    afficherMot: widget.afficherMots,
                                    enErreur: option.id == _erreurId,
                                    enAide:
                                        _erreurTick >= 2 &&
                                        !_fini &&
                                        option.concept ==
                                            _donnees.cases[_remplies],
                                    onTap: () => _toucher(option),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _casePosee(int index, double cote) {
    final carte = _CartePosee(
      concept: _donnees.cases[index],
      entree: widget.lexique[_donnees.cases[index]],
      cote: cote,
      afficherMot: widget.afficherMots,
    );
    return SizedBox(
      key: ValueKey('ordre.case.$index'),
      width: cote,
      height: widget.afficherMots ? cote + 44 : cote,
      child: !_fini && index == _remplies - 1
          ? CibleTactile(
              semantique: 'Retirer la dernière image',
              onTap: () => setState(() {
                _posees.remove(_posees.last);
                _erreurId = null;
                _erreurTick = 0;
              }),
              child: carte,
            )
          : carte,
    );
  }

  /// Le côté d'une carte : il tient dans la largeur, reste sous [plafond],
  /// ne mange jamais plus de [hauteurMax], et ne descend pas sous 80 pt.
  double _coteQuiRentre({
    required double dispo,
    required double hauteurMax,
    required int nombre,
    required double espaces,
    required double plafond,
  }) {
    if (nombre <= 0) return 80;
    final parLargeur = (dispo - espaces * (nombre - 1)) / nombre;
    final parPlafond = parLargeur < plafond ? parLargeur : plafond;
    final parHauteur = hauteurMax < parPlafond ? hauteurMax : parPlafond;
    return parHauteur < 80 ? 80 : parHauteur;
  }
}

/// Une case encore vide : cadre pointillé crème, coins 28, un petit point
/// discret au centre pour dire « il y a une place ici » (aucun texte).
class _CaseVide extends StatelessWidget {
  final double cote;

  final bool active;
  const _CaseVide({super.key, required this.cote, this.active = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cote,
      height: cote,
      child: CustomPaint(
        painter: _Pointilles(active: active),
        child: Center(
          child: Container(
            width: cote * 0.14,
            height: cote * 0.14,
            decoration: BoxDecoration(
              color: active ? Palette.ciel : Palette.cremeFonce,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Le cadre pointillé des cases vides (Flutter n'a pas de bord pointillé).
class _Pointilles extends CustomPainter {
  final bool active;
  const _Pointilles({this.active = false});

  @override
  void paint(Canvas canvas, Size taille) {
    final cadre = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, taille.width - 4, taille.height - 4),
      const Radius.circular(28),
    );
    final pinceau = Paint()
      ..color = active ? Palette.ciel : Palette.cremeFonce
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (final metrique in (Path()..addRRect(cadre)).computeMetrics()) {
      var debut = 0.0;
      while (debut < metrique.length) {
        final suite = debut + 12;
        final fin = suite < metrique.length ? suite : metrique.length;
        canvas.drawPath(metrique.extractPath(debut, fin), pinceau);
        debut = fin + 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Pointilles ancien) => ancien.active != active;
}

/// L'image d'une histoire : carte blanche, bord 4 px crème, coins 28.
class _CarteHistoire extends StatelessWidget {
  final OptionManche option;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;
  final bool enErreur;
  final bool enAide;
  final VoidCallback onTap;

  const _CarteHistoire({
    required this.option,
    required this.entree,
    required this.cote,
    required this.afficherMot,
    required this.enErreur,
    required this.enAide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CibleTactile(
      key: ValueKey('ordre.image.${option.id}'),
      onTap: onTap,
      semantique: entree?.texte ?? option.concept,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: cote,
        height: afficherMot ? cote + 44 : cote,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: enErreur
                ? const Color(0xFFE8A0A0)
                : enAide
                ? Palette.verdure
                : Palette.cremeFonce,
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
        child: _ContenuCarte(
          concept: option.concept,
          entree: entree,
          cote: cote,
          afficherMot: afficherMot,
        ),
      ),
    );
  }
}

/// La même carte, posée dans une case : elle arrive en glissant de bas en
/// haut et en grandissant (~250 ms), comme si elle venait de voler là.
class _CartePosee extends StatefulWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;

  const _CartePosee({
    required this.concept,
    required this.entree,
    required this.cote,
    required this.afficherMot,
  });

  @override
  State<_CartePosee> createState() => _CartePoseeState();
}

class _CartePoseeState extends State<_CartePosee> {
  /// Faux à la première image (la carte est encore « en l'air »), vrai
  /// ensuite : les animations implicites font le reste.
  bool _posee = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _posee = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _posee ? Offset.zero : const Offset(0, 0.35),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: _posee ? 1 : 0.7,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.cote,
          height: widget.afficherMot ? widget.cote + 44 : widget.cote,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Palette.cremeFonce, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _ContenuCarte(
            concept: widget.concept,
            entree: widget.entree,
            cote: widget.cote,
            afficherMot: widget.afficherMot,
          ),
        ),
      ),
    );
  }
}

/// Le contenu d'une carte : l'illustration, puis le mot si demandé.
class _ContenuCarte extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;

  const _ContenuCarte({
    required this.concept,
    required this.entree,
    required this.cote,
    required this.afficherMot,
  });

  @override
  Widget build(BuildContext context) {
    return ContenuCarteConcept(
      concept: concept,
      entree: entree,
      cote: cote,
      afficherMot: afficherMot,
    );
  }
}

/// Un petit balancement doux quand la carte touchée n'était pas la bonne.
/// Elle reste à sa place : on n'enlève rien, on ne punit rien.
class _Balancement extends StatefulWidget {
  /// Change à chaque erreur sur cette carte (0 = jamais touchée par erreur).
  final int tick;
  final Widget child;

  const _Balancement({required this.tick, required this.child});

  @override
  State<_Balancement> createState() => _BalancementState();
}

class _BalancementState extends State<_Balancement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _Balancement ancien) {
    super.didUpdateWidget(ancien);
    if (widget.tick > ancien.tick && widget.tick > 0) {
      _controleur.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controleur,
      child: widget.child,
      builder: (context, enfant) {
        final avancement = _controleur.value;
        // Trois allers-retours qui s'éteignent doucement (0 à la fin).
        final angle = avancement >= 1
            ? 0.0
            : 0.07 * (1 - avancement) * math.sin(avancement * 3 * math.pi);
        return Transform.rotate(angle: angle, child: enfant);
      },
    );
  }
}
