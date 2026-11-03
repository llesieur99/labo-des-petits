import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/image_concept.dart';
import '../rappels_moteur.dart';

/// Un pas de la scène enregistrée : les deux personnages, en coordonnées
/// normalisées 0..1 par rapport à la scène (le point est le CENTRE du
/// personnage, ce qui rend le rejeu indépendant de la taille de l'écran).
typedef PasTheatre = ({double x1, double y1, double x2, double y2});

/// Moteur M7b : le petit théâtre — on joue une scène, puis on la rejoue.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine une scène, laisse les
/// doigts déplacer deux personnages, enregistre la scène et la rejoue. La
/// consigne, les encouragements et la progression appartiennent à l'hôte
/// (l'écran de jeu) ; tout ce que le moteur raconte passe par
/// [RappelsMoteur].
///
/// La manche se joue en deux temps :
///
///  1. **On joue.** Chaque personnage se prend au doigt ([Draggable]) et se
///     pose où l'enfant le laisse : l'ancrage du glisser est le CENTRE du
///     personnage et il compte depuis le point où le doigt s'est posé, donc
///     le personnage vient sous le doigt et le suit exactement — à quatre
///     ans, on ne vise pas. Le PREMIER doigt posé lance l'enregistrement :
///     les positions des deux personnages sont échantillonnées toutes les
///     [pas] (dix par seconde) pendant au plus
///     [DonneesTheatre.dureeMaxSecondes] secondes. Un petit rond corail qui
///     pulse, en haut, dit « on joue » — sans un mot, parce que l'enfant ne
///     lit pas. Dès qu'il y a [dureeMinScene] de scène enregistrée, le gros
///     bouton « Rejouer » apparaît.
///  2. **On rejoue.** Un doigt sur « Rejouer » fige l'enregistrement et la
///     scène se rejoue toute seule : les personnages suivent l'enregistrement,
///     un pas de [pas], en douceur ([AnimatedPositioned]). Pendant le rejeu,
///     les personnages ne se prennent plus (`IgnorePointer`) et le bouton ne
///     répond pas. À la fin du rejeu complet, le moteur dit `theatre.bravo`
///     puis annonce [RappelsMoteur.itemReussi] — une seule fois par manche.
///
/// Une manche n'enregistre qu'UNE scène : elle commence au premier doigt et
/// s'arrête au chrono ou au premier « Rejouer ». Ensuite les personnages
/// restent jouables au doigt (librement, sans être enregistrés) et le bouton
/// rejoue la même scène autant de fois que l'enfant veut — la scène est
/// déjà réussie, mais rejouer reste un jeu.
class MoteurTheatre extends StatefulWidget {
  /// La manche jouée : elle doit porter des [DonneesTheatre].
  final Manche manche;

  /// Le lexique du deck actif (texte lu aux parents, illustration).
  final Lexique lexique;

  /// Ce que la scène raconte à son hôte (fin de rejeu réussie).
  final RappelsMoteur rappels;

  const MoteurTheatre({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
  });

  /// Le pas de l'enregistrement et du rejeu : dix positions par seconde.
  static const Duration pas = Duration(milliseconds: 100);

  /// Ce qu'il faut de scène avant que « Rejouer » apparaisse.
  static const Duration dureeMinScene = Duration(seconds: 2);

  /// La taille d'un personnage sur la scène.
  static const double taillePersonnage = 96;

  /// La clé d'un personnage (les tests s'en servent).
  static ValueKey<String> clePersonnage(int index) =>
      ValueKey('theatre.personnage-$index');

  /// La clé du bouton « Rejouer » (les tests s'en servent).
  static const ValueKey<String> cleRejouer = ValueKey('theatre.rejouer');

  @override
  State<MoteurTheatre> createState() => _MoteurTheatreEtat();
}

/// Ce que fait la scène en ce moment.
enum _Phase {
  /// L'enfant joue : les doigts prennent les personnages, ça s'enregistre.
  jeu,

  /// La scène se rejoue toute seule : les doigts ne prennent plus rien.
  rejeu,
}

/// La position de départ des personnages : en bas, à gauche et à droite.
const _departGauche = Offset(0.22, 0.76);
const _departDroite = Offset(0.78, 0.76);

/// La demi-taille d'un personnage : le doigt le tient par son centre.
const double _demiPersonnage = MoteurTheatre.taillePersonnage / 2;

class _MoteurTheatreEtat extends State<MoteurTheatre>
    with SingleTickerProviderStateMixin {
  /// La clé de la scène : elle donne la taille et le repère des doigts.
  final GlobalKey _cleScene = GlobalKey();

  /// Les personnages, en coordonnées normalisées (le centre, 0..1).
  /// Toujours deux — même si la manche n'en déclare qu'un.
  late List<Offset> _positions;

  /// La scène enregistrée, un pas toutes les [MoteurTheatre.pas].
  final List<PasTheatre> _enregistrement = [];

  /// Vrai pendant l'enregistrement (le rond corail pulse).
  bool _enregistre = false;

  /// Vrai quand la scène a été rejouée en entier : on ne le dit qu'une fois.
  bool _reussi = false;
  int? _selection;

  _Phase _phase = _Phase.jeu;

  /// Le pas de l'enregistrement qu'on est en train de rejouer.
  int _indexRejeu = 0;

  late final AnimationController _pulse;

  /// Le chrono qui échantillonne les positions pendant qu'on joue.
  Timer? _chronoPas;

  /// Le chrono du rejeu, un pas à la fois.
  Timer? _chronoRejeu;

  DonneesTheatre? get _donnees {
    final donnees = widget.manche.donnees;
    return donnees is DonneesTheatre ? donnees : null;
  }

  /// Les concepts des personnages à dessiner (deux au plus).
  List<String> get _concepts =>
      _donnees?.personnages.take(2).toList(growable: false) ?? const [];

  /// Ce qui a été enregistré : le premier pas est le point de départ, donc
  /// la scène dure un pas de moins que le nombre de positions.
  Duration get _dureeEnregistree => _enregistrement.isEmpty
      ? Duration.zero
      : MoteurTheatre.pas * (_enregistrement.length - 1);

  /// Vrai dès qu'il y a assez de scène pour valoir la peine d'être rejouée.
  bool get _rejouable => _dureeEnregistree >= MoteurTheatre.dureeMinScene;

  /// Le temps de scène maximal (le chrono qu'on donne à l'enfant).
  Duration get _dureeMax {
    final secondes = _donnees?.dureeMaxSecondes ?? 20;
    return Duration(
      seconds: math.max(secondes, MoteurTheatre.dureeMinScene.inSeconds),
    );
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _positions = [_departGauche, _departDroite];
  }

  @override
  void didUpdateWidget(covariant MoteurTheatre ancien) {
    super.didUpdateWidget(ancien);
    // Une autre manche : une autre scène, on repart de zéro.
    if (ancien.manche.id != widget.manche.id) _recommencer();
  }

  @override
  void dispose() {
    _chronoPas?.cancel();
    _chronoRejeu?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Remet la scène à son état de départ (sans `setState`).
  void _recommencer() {
    _chronoPas?.cancel();
    _chronoRejeu?.cancel();
    _chronoPas = null;
    _chronoRejeu = null;
    _pulse.stop();
    _pulse.value = 0;
    _enregistre = false;
    _enregistrement.clear();
    _positions = [_departGauche, _departDroite];
    _phase = _Phase.jeu;
    _indexRejeu = 0;
    _reussi = false;
    _selection = null;
  }

  // ── On joue : les doigts et l'enregistrement ──────────────────────────

  /// Le doigt prend un personnage. Le premier doigt de la manche lance
  /// l'enregistrement — la scène commence au premier déplacement.
  void _prise(int index) {
    if (_phase != _Phase.jeu || index >= _positions.length) return;
    if (!_enregistre && _enregistrement.isEmpty) _demarrerEnregistrement();
  }

  /// Le personnage suit le doigt : il vient sous le doigt et y reste
  /// (`dragAnchorStrategy` ancre le glisser à son centre, depuis le point
  /// où le doigt s'est posé).
  void _suivre(int index, Offset global) {
    if (_phase != _Phase.jeu) return;
    final boite = _cleScene.currentContext?.findRenderObject();
    if (boite is! RenderBox || !boite.hasSize || index >= _positions.length) {
      return;
    }
    final local = boite.globalToLocal(global);
    setState(() => _positions[index] = _borner(local, boite.size));
  }

  /// Une position de doigt ramenée dans la scène : le personnage y entre
  /// en entier, jamais à moitié dehors.
  Offset _borner(Offset pixel, Size scene) {
    if (scene.isEmpty) return _positions.first;
    final demiX = math.min(
      MoteurTheatre.taillePersonnage / 2 / scene.width,
      0.5,
    );
    final demiY = math.min(
      MoteurTheatre.taillePersonnage / 2 / scene.height,
      0.5,
    );
    return Offset(
      (pixel.dx / scene.width).clamp(demiX, 1 - demiX).toDouble(),
      (pixel.dy / scene.height).clamp(demiY, 1 - demiY).toDouble(),
    );
  }

  /// Le premier pas de la scène : les deux personnages, tels qu'ils sont.
  PasTheatre _unPas() => (
    x1: _positions[0].dx,
    y1: _positions[0].dy,
    x2: _positions[1].dx,
    y2: _positions[1].dy,
  );

  void _demarrerEnregistrement() {
    if (_enregistre) return;
    _enregistre = true;
    _enregistrement
      ..clear()
      ..add(_unPas());
    _pulse.repeat(reverse: true);
    _chronoPas = Timer.periodic(MoteurTheatre.pas, (_) => _echantillonner());
    setState(() {});
  }

  /// Un pas de plus dans l'enregistrement (dix fois par seconde).
  void _echantillonner() {
    if (moteurEnPause(widget.rappels)) return;
    if (!_enregistre) return;
    final rejouableAvant = _rejouable;
    _enregistrement.add(_unPas());
    if (_dureeEnregistree >= _dureeMax) _arreterEnregistrement();
    // Le bouton « Rejouer » s'allume au moment où la scène devient jouable :
    // une seule reconstruction, dix fois par seconde c'est assez.
    if (_rejouable != rejouableAvant && mounted) setState(() {});
  }

  /// L'enregistrement s'arrête : le temps est écoulé, ou l'enfant a demandé
  /// à rejouer. Le rond corail s'éteint.
  void _arreterEnregistrement() {
    if (!_enregistre) return;
    _enregistre = false;
    _chronoPas?.cancel();
    _chronoPas = null;
    _pulse.stop();
    if (mounted) setState(() {});
  }

  // ── On rejoue ─────────────────────────────────────────────────────────

  /// L'enfant touche « Rejouer » : la scène enregistrée se rejoue toute
  /// seule, un pas à la fois.
  void _rejouer() {
    if (_phase != _Phase.jeu || !_rejouable) return;
    _arreterEnregistrement();
    _chronoRejeu?.cancel();
    setState(() {
      _phase = _Phase.rejeu;
      _indexRejeu = 0;
      _appliquer(_enregistrement.first);
    });
    _chronoRejeu = Timer.periodic(MoteurTheatre.pas, (_) => _pasDeRejeu());
  }

  void _pasDeRejeu() {
    if (moteurEnPause(widget.rappels)) return;
    if (!mounted) return;
    if (_indexRejeu + 1 >= _enregistrement.length) {
      _finDuRejeu();
      return;
    }
    setState(() {
      _indexRejeu++;
      _appliquer(_enregistrement[_indexRejeu]);
    });
  }

  /// La scène a été rejouée en entier : on le dit, UNE fois.
  void _finDuRejeu() {
    _chronoRejeu?.cancel();
    _chronoRejeu = null;
    final premiere = !_reussi;
    _reussi = true;
    setState(() => _phase = _Phase.jeu);
    if (premiere) {
      unawaited(widget.rappels.dire('theatre.bravo'));
      widget.rappels.itemReussi();
    }
  }

  void _appliquer(PasTheatre pas) {
    _positions = [Offset(pas.x1, pas.y1), Offset(pas.x2, pas.y2)];
  }

  // ── Le dessin ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_donnees == null) {
      // Une manche mal construite ne doit jamais montrer d'erreur à un
      // enfant : on ne dessine rien.
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: Palette.creme,
      child: Column(
        children: [
          _bandeauEnregistrement(),
          Expanded(child: _scene()),
          _bandeauRejouer(),
        ],
      ),
    );
  }

  /// En haut : le rond corail qui pulse pendant qu'on joue. Aucun mot —
  /// l'enfant de quatre ans ne lit pas. La bande garde sa place pour que
  /// la scène ne saute pas quand le rond s'allume.
  Widget _bandeauEnregistrement() {
    return SizedBox(
      height: 56,
      child: Center(
        child: !_enregistre
            ? const SizedBox.shrink()
            : AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final battement =
                      0.82 + 0.30 * Curves.easeInOut.transform(_pulse.value);
                  return Transform.scale(
                    scale: battement,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Palette.corail,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Palette.corail.withValues(alpha: 0.30),
                            blurRadius: 14,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// La scène : un grand rectangle arrondi, comme un petit théâtre, avec
  /// les deux personnages dedans.
  Widget _scene() {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Palette.cremeFonce, width: 6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: LayoutBuilder(
            builder: (context, contraintes) {
              final scene = contraintes.biggest;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final selection = _selection;
                  if (selection != null) {
                    _suivre(selection, details.globalPosition);
                  }
                },
                child: Stack(
                  key: _cleScene,
                  children: [
                    for (var i = 0; i < _concepts.length; i++)
                      _personnagePositionne(i, scene),
                    if (_enregistrement.isNotEmpty &&
                        !_reussi &&
                        _phase == _Phase.jeu)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: CibleTactile(
                            key: const ValueKey('theatre.recommencer'),
                            semantique: 'Recommencer la scène',
                            onTap: () => setState(_recommencer),
                            child: const Icon(
                              Icons.restart_alt_rounded,
                              color: Palette.encreDouce,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Un personnage posé sur la scène : pendant qu'on joue il suit le doigt
  /// tout de suite ; pendant le rejeu il glisse d'un pas à l'autre.
  Widget _personnagePositionne(int index, Size scene) {
    const cote = MoteurTheatre.taillePersonnage;
    final centre = Offset(
      _positions[index].dx * scene.width,
      _positions[index].dy * scene.height,
    );
    return AnimatedPositioned(
      key: MoteurTheatre.clePersonnage(index),
      duration: _phase == _Phase.rejeu ? MoteurTheatre.pas : Duration.zero,
      left: centre.dx - _demiPersonnage,
      top: centre.dy - _demiPersonnage,
      width: cote,
      height: cote,
      child: RepaintBoundary(child: _personnageTactile(index)),
    );
  }

  /// Le personnage qu'on attrape : le doigt le tient par son centre (c'est
  /// l'ancrage du glisser) et il vient sous le doigt.
  Widget _personnageTactile(int index) {
    final concept = _concepts[index];
    final entree = widget.lexique[concept];
    return IgnorePointer(
      // Pendant le rejeu, les prises ne répondent plus : la scène se donne
      // en spectacle, on regarde.
      ignoring: _phase == _Phase.rejeu,
      child: Draggable<int>(
        data: index,
        dragAnchorStrategy: (_, _, _) =>
            const Offset(_demiPersonnage, _demiPersonnage),
        onDragStarted: () => _prise(index),
        onDragUpdate: (details) => _suivre(index, details.globalPosition),
        // Le personnage suit le doigt lui-même : un clone ne double pas.
        childWhenDragging: const SizedBox.shrink(),
        feedback: Material(
          type: MaterialType.transparency,
          child: Transform.scale(
            scale: 1.06,
            child: _personnage(concept, entree),
          ),
        ),
        child: CibleTactile(
          tailleMin: MoteurTheatre.taillePersonnage,
          semantique: entree?.texte ?? concept,
          onTap: () {
            _prise(index);
            setState(() => _selection = index);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: _selection == index
                  ? Border.all(color: Palette.soleil, width: 4)
                  : null,
            ),
            child: _personnage(concept, entree),
          ),
        ),
      ),
    );
  }

  Widget _personnage(String concept, EntreeLexique? entree) {
    return ImageConcept(
      concept: concept,
      fichier: entree?.illustrationPour(concept) ?? '',
      taille: MoteurTheatre.taillePersonnage,
    );
  }

  /// En bas : le gros bouton « Rejouer », une pastille verte avec la flèche
  /// du recommencement. Il n'apparaît qu'une fois la scène enregistrée, et
  /// il attend la fin du rejeu pour redevenir actif.
  Widget _bandeauRejouer() {
    if (!_rejouable) {
      // La bande garde sa place : la scène ne saute pas quand il s'allume.
      return const SizedBox(height: 112);
    }
    final actif = _phase == _Phase.jeu;
    return SizedBox(
      height: 112,
      child: Center(
        // La taille nette du bouton : la cible tactile ne s'étire pas sur
        // toute la bande (le Center interne d'une CibleTactile prend toute
        // la place qu'on lui laisse).
        child: SizedBox(
          width: MoteurTheatre.taillePersonnage,
          height: MoteurTheatre.taillePersonnage,
          child: CibleTactile(
            key: MoteurTheatre.cleRejouer,
            tailleMin: MoteurTheatre.taillePersonnage,
            onTap: actif ? _rejouer : null,
            semantique: 'Rejouer',
            child: AnimatedOpacity(
              opacity: actif ? 1 : 0.45,
              duration: const Duration(milliseconds: 200),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.7, end: 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, echelle, enfant) =>
                    Transform.scale(scale: echelle, child: enfant),
                child: const SizedBox.expand(
                  // La pastille prend toute la cible : sans ça, le rond vert
                  // se réduirait à la taille de l'icône.
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.verdure,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.replay_rounded,
                      size: 54,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
