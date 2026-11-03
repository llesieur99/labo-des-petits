import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/contenu_carte_concept.dart';
import '../rappels_moteur.dart';

/// La hauteur qu'ajoute le mot écrit sous une illustration (paliers 6-7 ans).
const double _hauteurMot = 44;

// ──────────────────────────── le vocabulaire ────────────────────────────

/// Un son disponible dans la manche : son concept (illustration, mot du
/// lexique) et son asset non verbal (tambour, grelot…).
class _Son {
  final String concept;
  final String asset;

  const _Son(this.concept, this.asset);
}

/// Une case remplie : le son posé, et le numéro de sa pose — l'arrivée se
/// rejoue à chaque nouvelle pose dans la même case.
class _Pose {
  final int son;
  final int numero;

  const _Pose(this.son, this.numero);
}

// ─────────────────────────────── le moteur ───────────────────────────────

/// Moteur M5 « mode composer » : la chanson de quatre cases.
///
/// L'enfant touche des sons — un tambour, un grelot — et chaque son entendu
/// vient se poser dans la prochaine case libre. Quand les quatre cases sont
/// remplies, l'app rejoue SA boucle, deux fois de suite, puis la félicite.
///
/// Création libre : il n'y a AUCUNE bonne réponse, aucun essai raté, rien à
/// recommencer. C'est de la musique, pas un exercice — et c'est aussi une
/// première rencontre avec l'idée d'ordre : l'ordre des cases, de gauche à
/// droite, est celui que la boucle rejoue.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine, écoute les doigts,
/// joue les sons et raconte le reste à son hôte ([RappelsMoteur]) — c'est
/// l'hôte qui encourage et qui avance.
class MoteurComposer extends StatefulWidget {
  /// La manche à jouer ; `manche.donnees` est un [DonneesComposer]
  /// (contrat du générateur : une manche de chanson porte ses données).
  final Manche manche;

  /// Le lexique du deck actif (illustrations, mots écrits).
  final Lexique lexique;

  /// Ce que le moteur raconte à son hôte (bravo, réussite).
  final RappelsMoteur rappels;

  /// Afficher les mots sous les images (paliers 6-7 ans).
  final bool afficherMots;

  const MoteurComposer({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
    this.afficherMots = false,
  });

  @override
  MoteurComposerEtat createState() => MoteurComposerEtat();
}

/// L'état du moteur (public pour que les tests pompent ses durées).
class MoteurComposerEtat extends State<MoteurComposer> {
  // ── les durées du jeu (les tests pompent exactement celles-ci) ──
  /// Un son dure 500 ms — la case qui le porte pulse pendant ce temps.
  static const dureeCase = Duration(milliseconds: 500);

  /// Le souffle entre les deux passes : le temps d'attendre le refrain.
  static const pauseEntrePassees = Duration(milliseconds: 400);

  /// Une boucle se rejoue DEUX fois de suite (c'est le jeu).
  static const nombrePassees = 2;

  // ── les mesures (jamais moins de 80 pt pour ce qui se touche) ──
  static const _plafondCases = 6; // au-delà, la rangée ne tient plus
  static const _plafondCase = 168.0;
  static const _plafondCarte = 190.0;
  static const _pasCases = 12.0;
  static const _pasCartes = 20.0;
  static const _ecartRangees = 16.0;
  static const _hauteurBouton = 116.0; // la place réservée du gros bouton
  static const _coteBouton = 96.0;

  // ── les données de la manche, assainies ──
  /// Les données de la manche, ou null : écran calme (données absentes,
  /// d'un autre type, sans son ou sans case — jamais une exception).
  DonneesComposer? _donnees;

  /// Les sons disponibles, dans l'ordre de la manche : stable d'un dessin à
  /// l'autre, les cartes ne se mélangent pas pendant que l'enfant joue.
  List<_Son> _sons = const <_Son>[];

  /// Les cases, de gauche à droite : le son posé, ou rien.
  List<_Pose?> _cases = const <_Pose?>[];

  /// Vrai pendant le rejeu : tout est inerte, les doigts attendent.
  bool _enRejeu = false;

  /// Vrai une fois la boucle achevée : le bravo et la réussite ne sont dits
  /// qu'UNE fois — mais l'enfant peut refaire sa chanson autant qu'il veut.
  bool _aReussi = false;

  /// La case qui sonne (index), et son numéro de pulsation (0 = aucune).
  int _pulsation = -1;
  int _pulsationTick = 0;

  /// Le numéro de la dernière pose : chaque pose neuve rejoue l'arrivée.
  int _poseNumero = 0;

  /// Le numéro de la course : toute manche neuve l'incrémente, et tout ce
  /// qui était en vol s'arrête net.
  int _course = 0;

  @override
  void initState() {
    super.initState();
    _reinitialiser();
  }

  @override
  void didUpdateWidget(covariant MoteurComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte peut réutiliser le même moteur pour la chanson suivante
    // (l'élément survit) : tout repart d'un écran neuf.
    if (oldWidget.manche != widget.manche) _reinitialiser();
  }

  /// Tout remettre à neuf : les données relues et assainies, les cases vides.
  void _reinitialiser() {
    _course++;
    _enRejeu = false;
    _aReussi = false;
    _pulsation = -1;
    _pulsationTick = 0;
    _poseNumero = 0;

    // Des données absentes, d'un autre moteur, sans son ou sans case ne
    // doivent JAMAIS lever — au pire, l'écran reste calme.
    final brut = widget.manche.donnees;
    final donnees = brut is DonneesComposer ? brut : null;
    if (donnees == null || donnees.sons.isEmpty || donnees.cases < 1) {
      _donnees = null;
      _sons = const <_Son>[];
      _cases = const <_Pose?>[];
      return;
    }
    _donnees = donnees;
    _sons = [
      for (final entree in donnees.sons.entries) _Son(entree.key, entree.value),
    ];
    _cases = List<_Pose?>.filled(donnees.cases.clamp(1, _plafondCases), null);
  }

  // ─────────────────────────── les doigts ───────────────────────────

  /// La prochaine case libre, de gauche à droite (-1 : tout est rempli).
  int get _prochaineCaseLibre {
    for (var i = 0; i < _cases.length; i++) {
      if (_cases[i] == null) return i;
    }
    return -1;
  }

  /// Toutes les cases sont remplies : la chanson est prête à être rejouée.
  bool get _complet => _cases.isNotEmpty && _prochaineCaseLibre < 0;

  /// Toucher une carte de son : le son part TOUT DE SUITE, et une pastille
  /// du concept vient se poser dans la prochaine case libre. Les cartes
  /// restent disponibles — deux fois le même son, c'est une chanson.
  void _toucherCarte(int indexSon) {
    if (_enRejeu) return;
    if (indexSon < 0 || indexSon >= _sons.length) return;
    unawaited(widget.rappels.jouerSon(_sons[indexSon].asset));

    // Tout est rempli : on a entendu le son, et c'est tout. C'est l'enfant
    // qui décide quoi retirer — jamais l'app.
    final libre = _prochaineCaseLibre;
    if (libre < 0) return;

    setState(() => _cases[libre] = _Pose(indexSon, ++_poseNumero));
  }

  /// Toucher une case remplie la vide — n'importe laquelle : c'est plus
  /// simple pour un enfant que de n'accepter que la dernière. Les cases
  /// restent alignées de gauche à droite, et c'est cet ordre-là que la
  /// boucle rejoue.
  void _viderCase(int index) {
    if (_enRejeu) return;
    if (index < 0 || index >= _cases.length) return;
    if (_cases[index] == null) return; // une case vide ne répond pas
    setState(() => _cases[index] = null);
  }

  // ──────────────────────────── le rejeu ────────────────────────────

  /// Le gros bouton « jouer » : l'app rejoue la boucle DEUX fois de suite.
  ///
  /// Chaque case sonne 500 ms et pulse pendant son son ; la pause de 400 ms
  /// sépare les deux passes, comme un refrain qu'on se repasse. À la fin de
  /// la deuxième passe, la toute première fois, l'app dit son bravo puis
  /// annonce la réussite à l'hôte.
  Future<void> _rejouer() async {
    if (_enRejeu || !_complet) return;
    final course = _course;

    setState(() {
      _enRejeu = true;
      _pulsation = -1;
    });

    for (var passe = 0; passe < nombrePassees; passe++) {
      for (var i = 0; i < _cases.length; i++) {
        final pose = _cases[i];
        // On n'entre ici que si tout est rempli, et un rejeu en vol s'arrête
        // de lui-même quand la manche a changé.
        if (!mounted || _course != course) return;
        if (pose == null) return;

        setState(() {
          _pulsation = i;
          _pulsationTick++;
        });
        // Le son et son temps partent ensemble : la case pulse au moins
        // 500 ms, et plus longtemps si le son dure plus longtemps.
        await Future.wait(<Future<void>>[
          widget.rappels.jouerSon(_sons[pose.son].asset),
          attendreMoteur(widget.rappels, dureeCase),
        ]);
      }
      if (passe < nombrePassees - 1) {
        if (!mounted || _course != course) return;
        setState(() => _pulsation = -1); // silence entre les deux passes
        await attendreMoteur(widget.rappels, pauseEntrePassees);
      }
    }

    if (!mounted || _course != course) return;
    await _achever(course);
  }

  /// La boucle est finie : tout redevient libre, et — la toute première fois
  /// seulement — l'app dit son bravo puis annonce la réussite. Refaire la
  /// chanson ensuite n'a pas d'autre conséquence : c'est de la musique, on
  /// la rejoue tant qu'on veut.
  Future<void> _achever(int course) async {
    if (!mounted) return;
    final premier = !_aReussi;

    setState(() {
      _enRejeu = false;
      _pulsation = -1;
      _aReussi = true;
    });

    if (!premier) return;
    final bravo = _donnees?.bravoCle;
    if (bravo != null && bravo.isNotEmpty) {
      await widget.rappels.dire(bravo);
    }
    if (!mounted || _course != course) return;
    widget.rappels.itemReussi();
  }

  // ───────────────────────────── l'écran ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_donnees == null) return _ecranCalme();

    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeur = contraintes.maxWidth.isFinite
            ? contraintes.maxWidth
            : 800.0;
        final hauteur = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;

        final coteCase = _coteQuiRentre(
          dispo: largeur,
          hauteurMax: hauteur * 0.30 - (widget.afficherMots ? _hauteurMot : 0),
          nombre: _cases.length,
          espaces: _pasCases,
          plafond: _plafondCase,
        );
        // Ce qui reste une fois les cases et le bouton posés : les cartes
        // s'y taillent leur place, jamais au détriment du reste.
        final reste = hauteur - coteCase - _ecartRangees - _hauteurBouton;
        final coteCarte = _coteQuiRentre(
          dispo: largeur,
          hauteurMax: reste - (widget.afficherMots ? _hauteurMot : 0),
          nombre: _sons.length,
          espaces: _pasCartes,
          plafond: _plafondCarte,
        );

        final colonnesCases = math.max(
          1,
          ((largeur + _pasCases) / (coteCase + _pasCases)).floor(),
        );
        final lignesCases = (_cases.length / colonnesCases).ceil();
        final colonnesSons = math.max(
          1,
          ((largeur + _pasCartes) / (coteCarte + _pasCartes)).floor(),
        );
        final lignesSons = (_sons.length / colonnesSons).ceil();
        final mot = widget.afficherMots ? _hauteurMot : 0.0;
        final hauteurNecessaire =
            lignesCases * (coteCase + mot) +
            (lignesCases - 1) * _pasCases +
            _ecartRangees +
            lignesSons * (coteCarte + mot) +
            (lignesSons - 1) * _pasCartes +
            _hauteurBouton;
        return SingleChildScrollView(
          child: SizedBox(
            height: math.max(hauteur, hauteurNecessaire),
            child: Column(
              children: [
                // ── les cases de la chanson (vides, puis remplies au doigt) ──
                Wrap(
                  spacing: _pasCases,
                  runSpacing: _pasCases,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < _cases.length; i++) _case(i, coteCase),
                  ],
                ),
                const SizedBox(height: _ecartRangees),
                // ── les sons disponibles : on les touche autant qu'on veut ──
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: _pasCartes,
                      runSpacing: _pasCartes,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < _sons.length; i++)
                          _carte(i, coteCarte),
                      ],
                    ),
                  ),
                ),
                // ── le gros bouton : sa place est réservée, rien ne saute ──
                SizedBox(
                  height: _hauteurBouton,
                  child: Center(child: _boutonJouer()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Rien à jouer : un écran calme, jamais une erreur à l'écran.
  Widget _ecranCalme() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 112,
        color: Palette.cremeFonce,
      ),
    ),
  );

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

  /// Une case : vide (cadre pointillé crème), ou remplie d'une pastille du
  /// concept — que le doigt vide d'un coup.
  Widget _case(int index, double cote) {
    final pose = _cases[index];
    final remplie = pose != null;
    final concept = remplie ? _sons[pose.son].concept : '';
    final entree = remplie ? widget.lexique[concept] : null;

    return SizedBox(
      width: cote,
      // Avec les mots, la case est un peu plus haute (comme au M5 « ordre ») :
      // l'illustration et le mot tiennent ensemble.
      height: widget.afficherMots ? cote + _hauteurMot : cote,
      // Le SizedBox enveloppe la CibleTactile : dans un Wrap, son Center
      // interne s'étirerait sur toute la largeur et les cases
      // s'empileraient une par ligne.
      child: CibleTactile(
        key: ValueKey('composer.case.$index'),
        onTap: remplie && !_enRejeu ? () => _viderCase(index) : null,
        semantique: remplie ? (entree?.texte ?? concept) : null,
        child: remplie
            ? KeyedSubtree(
                // La clé stable que les doigts (et les tests) visent.
                key: ValueKey('composer.pastille.$index'),
                child: _Pastille(
                  // La clé change à chaque pose : l'arrivée se rejoue.
                  key: ValueKey('composer.arrivee.$index.${pose.numero}'),
                  concept: concept,
                  entree: entree,
                  cote: cote,
                  afficherMot: widget.afficherMots,
                  pulse: _pulsation == index ? _pulsationTick : 0,
                ),
              )
            : CustomPaint(
                painter: _Pointilles(active: index == _cases.indexOf(null)),
                child: Center(
                  child: SizedBox(
                    width: cote * 0.14,
                    height: cote * 0.14,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Palette.cremeFonce,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Une carte de son, dans le bas : on peut la toucher autant de fois
  /// qu'on veut — sauf pendant le rejeu, où tout dort.
  Widget _carte(int index, double cote) {
    final son = _sons[index];
    final entree = widget.lexique[son.concept];

    return SizedBox(
      width: cote,
      height: widget.afficherMots ? cote + _hauteurMot : cote,
      // Le SizedBox enveloppe la CibleTactile : dans un Wrap, son Center
      // interne s'étirerait sur toute la largeur et les cartes
      // s'empileraient une par ligne.
      child: CibleTactile(
        key: ValueKey('composer.carte.${son.concept}'),
        onTap: _enRejeu ? null : () => _toucherCarte(index),
        semantique: entree?.texte ?? son.concept,
        child: _Cadre(
          cote: cote,
          afficherMot: widget.afficherMots,
          child: _ContenuConcept(
            concept: son.concept,
            entree: entree,
            cote: cote,
            afficherMot: widget.afficherMots,
          ),
        ),
      ),
    );
  }

  /// Le gros bouton vert : il apparaît quand les cases sont toutes remplies,
  /// et il dort pendant le rejeu. Sa place est réservée même caché.
  Widget _boutonJouer() {
    if (!_complet) return const SizedBox.shrink();
    return CibleTactile(
      key: const ValueKey('composer.jouer'),
      onTap: _enRejeu ? null : _rejouer,
      semantique: 'jouer',
      child: Container(
        width: _coteBouton,
        height: _coteBouton,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Palette.verdure,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow, size: 56, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────── les petites pièces ───────────────────────────

/// Une pastille posée dans une case : elle arrive de bas en haut en
/// grandissant (~250 ms), puis pulse quand c'est son tour de sonner.
class _Pastille extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;

  /// 0 : ne pulse pas ; change à chaque pulsation de cette case.
  final int pulse;

  const _Pastille({
    super.key,
    required this.concept,
    required this.entree,
    required this.cote,
    required this.afficherMot,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, avancement, enfant) => Transform.translate(
        offset: Offset(0, 18 * (1 - avancement)),
        child: Transform.scale(scale: 0.78 + 0.22 * avancement, child: enfant),
      ),
      // Le pouls vit SOUS l'arrivée : sonner ne rejoue pas la pose.
      child: _Pulsation(
        tick: pulse,
        child: _Cadre(
          cote: cote,
          afficherMot: afficherMot,
          child: _ContenuConcept(
            concept: concept,
            entree: entree,
            cote: cote,
            afficherMot: afficherMot,
          ),
        ),
      ),
    );
  }
}

/// La case qui sonne pulse doucement : un petit grossissement et un halo
/// vert, le temps de son son (500 ms).
class _Pulsation extends StatefulWidget {
  /// 0 : au repos ; une valeur neuve à chaque pulsation.
  final int tick;

  final Widget child;

  const _Pulsation({required this.tick, required this.child});

  @override
  State<_Pulsation> createState() => _PulsationState();
}

class _PulsationState extends State<_Pulsation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _Pulsation ancien) {
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
        // Un aller-retour doux : 0 au début, 0 à la fin.
        final pouls = _controleur.value >= 1
            ? 0.0
            : math.sin(math.pi * _controleur.value);
        return Transform.scale(
          scale: 1 + 0.06 * pouls,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Palette.verdure.withValues(alpha: 0.55 * pouls),
                  blurRadius: 18 * pouls,
                  spreadRadius: 2 * pouls,
                ),
              ],
            ),
            child: enfant,
          ),
        );
      },
    );
  }
}

/// Le cadre d'une carte du jeu : un carré blanc, bord 4 px crème, coins 28,
/// une ombre douce — le même habit pour les sons du bas et pour les
/// pastilles posées dans les cases.
class _Cadre extends StatelessWidget {
  final double cote;
  final bool afficherMot;
  final Widget child;

  const _Cadre({
    required this.cote,
    required this.afficherMot,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cote,
      height: afficherMot ? cote + _hauteurMot : cote,
      child: Container(
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
        child: child,
      ),
    );
  }
}

/// Le contenu d'une carte : l'illustration, puis le mot si demandé.
class _ContenuConcept extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;

  const _ContenuConcept({
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

/// Le cadre pointillé des cases vides (Flutter n'a pas de bord pointillé).
/// C'est celui du M5 « ordre » : les deux jeux doivent se ressembler.
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
