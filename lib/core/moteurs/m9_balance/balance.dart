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

/// Moteur M9 : la balance du marché — des fruits sur deux plateaux, jusqu'à
/// l'égalité.
///
/// En haut, une balance dessinée en primitives Flutter : un pivot (un
/// triangle crème foncé), un fléau arrondi qui penche de dix degrés du côté
/// le plus lourd, deux plateaux à hauteur FIXE — la main de l'enfant les
/// trouve toujours au même endroit, même quand la balance penche. En bas,
/// les fruits de la réserve, en cartes.
///
/// Tout se fait au doigt, jamais au glisser : à quatre ans on n'exige
/// jamais un geste savant.
///  - toucher un fruit le met « en main » (il s'illumine) et le nomme ;
///  - toucher un plateau y dépose le fruit en main (il arrive en douceur) ;
///  - toucher un plateau qui porte des fruits, la main vide, en reprend un
///    (le dernier posé) — il retourne à sa place dans la réserve.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine, écoute les doigts
/// et raconte ce qui vient de se passer par [RappelsMoteur] (nom du fruit
/// pris, « ça penche », « c'est égal », manche réussie). L'hôte encourage,
/// avance et enregistre la progression. Rien n'est jamais raté ici :
/// [RappelsMoteur.essaiRate] n'est JAMAIS appelé.
///
/// La règle, après CHAQUE dépôt ou retrait :
///  - les deux plateaux portent le même nombre de fruits, au moins
///    [DonneesBalance.minimumParPlateau] : [DonneesBalance.egalCle] est dit
///    quand l'égalité est nouvelle, puis la manche est réussie — une seule
///    fois : l'enfant peut continuer de manipuler après ;
///  - un dépôt rend les plateaux inégaux : [DonneesBalance.pencheCle] est
///    dit, mais seulement si le déséquilibre est NOUVEAU (le signe vient de
///    changer) : jamais deux fois de suite le même « ça penche ».
class MoteurBalance extends StatefulWidget {
  /// La manche jouée (elle porte des [DonneesBalance]).
  final Manche manche;

  /// Le lexique du deck actif (texte + illustration).
  final Lexique lexique;

  /// Ce que le moteur raconte à l'hôte.
  final RappelsMoteur rappels;

  const MoteurBalance({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
  });

  /// Le plateau de gauche.
  static const coteGauche = 'gauche';

  /// Le plateau de droite.
  static const coteDroite = 'droite';

  /// Clé de la carte d'un fruit de la réserve (les tests s'en servent).
  ///
  /// L'id est la position du fruit dans [DonneesBalance.reserve] : trois
  /// pommes sont trois fruits, et chacune a sa carte.
  static ValueKey<String> cleFruit(int id, String concept) =>
      ValueKey('fruit-$id-$concept');

  /// Clé d'un plateau ([coteGauche] ou [coteDroite]).
  static ValueKey<String> clePlateau(String cote) => ValueKey('plateau-$cote');

  /// Clé d'un fruit posé sur un plateau.
  static ValueKey<String> cleFruitPose(String cote, int id) =>
      ValueKey('pose-$cote-$id');

  /// Clé de la pastille du compteur d'un plateau (une par fruit posé).
  static ValueKey<String> clePoint(String cote, int index) =>
      ValueKey('point-$cote-$index');

  /// Clé du compteur d'un plateau (le rang de pastilles).
  static ValueKey<String> clePoints(String cote) => ValueKey('points-$cote');

  /// Clé du fléau (le dessin qui penche).
  static const cleFleau = ValueKey<String>('balance.fleau');

  /// Clé de l'écran crème montré quand la manche n'a pas ses données.
  static const cleEcranCalme = ValueKey<String>('balance.calme');

  @override
  State<MoteurBalance> createState() => _MoteurBalanceState();
}

/// Un fruit de la réserve : son concept et sa position dans la manche.
///
/// Trois pommes sont trois fruits : chacune peut aller sur un plateau
/// différent, et chacune revient à sa place dans la réserve.
class _Fruit {
  final int id;
  final String concept;

  const _Fruit(this.id, this.concept);
}

/// L'état de la balance après un dépôt ou un retrait.
enum _Equilibre {
  /// Égal, et chaque plateau porte au moins le minimum : c'est réussi.
  egal,

  /// Égal, mais pas encore assez de fruits pour que ça compte.
  juste,

  /// Un plateau porte plus de fruits que l'autre : ça penche.
  penche,
}

class _MoteurBalanceState extends State<MoteurBalance> {
  /// Les fruits encore dans la réserve, dans l'ordre de la manche.
  late List<_Fruit> _reserve;

  /// Les fruits posés, du premier au dernier.
  final List<_Fruit> _gauche = [];
  final List<_Fruit> _droite = [];

  /// Le fruit « en main » (touche-toucher), ou null.
  _Fruit? _enMain;

  bool _reussi = false;

  /// L'état de la balance au dernier dépôt ou retrait, et le signe du
  /// déséquilibre (+1 : la gauche est plus lourde) — c'est ce qui permet de
  /// ne dire « ça penche » que quand le déséquilibre est nouveau.
  _Equilibre _equilibre = _Equilibre.juste;
  int _signe = 0;

  DonneesBalance? get _donnees {
    final donnees = widget.manche.donnees;
    return donnees is DonneesBalance ? donnees : null;
  }

  @override
  void initState() {
    super.initState();
    _reserve = _fruitsDeLaManche();
    _equilibre = _equilibreDe(_gauche.length, _droite.length);
  }

  @override
  void didUpdateWidget(covariant MoteurBalance ancienne) {
    super.didUpdateWidget(ancienne);
    if (ancienne.manche.id != widget.manche.id) {
      // Manche suivante : tous les fruits reviennent dans la réserve, la
      // balance est droite, et la manche peut être réussie de nouveau.
      _reserve = _fruitsDeLaManche();
      _gauche.clear();
      _droite.clear();
      _enMain = null;
      _reussi = false;
      _equilibre = _equilibreDe(_gauche.length, _droite.length);
      _signe = 0;
    }
  }

  List<_Fruit> _fruitsDeLaManche() {
    final reserve = _donnees?.reserve ?? const <String>[];
    return [for (var i = 0; i < reserve.length; i++) _Fruit(i, reserve[i])];
  }

  _Equilibre _equilibreDe(int gauche, int droite) {
    if (gauche != droite) return _Equilibre.penche;
    final minimum = _donnees?.minimumParPlateau ?? 0;
    return gauche >= minimum ? _Equilibre.egal : _Equilibre.juste;
  }

  /// L'inclinaison du fléau, en degrés : dix degrés du côté le plus lourd.
  ///
  /// Une rotation positive tourne vers la droite : c'est donc un plateau de
  /// GAUCHE plus lourd qui donne un angle négatif (le bout gauche descend).
  double get _angleDegres {
    final difference = _gauche.length - _droite.length;
    if (difference == 0) return 0;
    return difference > 0 ? -_inclinaison : _inclinaison;
  }

  // ── Les doigts ────────────────────────────────────────────────────────

  /// Un fruit de la réserve est touché : il vient « en main » (halo) et il
  /// est nommé — une seule fois par prise. Touché de nouveau, il se repose.
  void _toucherFruit(_Fruit fruit) {
    if (_enMain?.id == fruit.id) {
      setState(() => _enMain = null);
      return;
    }
    if (!_reserve.contains(fruit)) return;
    setState(() => _enMain = fruit);
    final entree = widget.lexique[fruit.concept];
    unawaited(
      widget.rappels.dire(
        entree?.clipPour(fruit.concept) ?? 'lex.${fruit.concept}',
      ),
    );
  }

  /// Un plateau est touché : le fruit en main s'y dépose ; la main vide, le
  /// dernier fruit posé revient dans la réserve (l'enfant se reprend).
  void _toucherPlateau(bool gauche) {
    final fruit = _enMain;
    if (fruit != null) {
      _deposer(fruit, gauche);
      return;
    }
    _reprendre(gauche);
  }

  /// Dépose [fruit] sur un plateau.
  void _deposer(_Fruit fruit, bool gauche) {
    if (!_reserve.contains(fruit)) return;
    setState(() {
      _reserve.remove(fruit);
      (gauche ? _gauche : _droite).add(fruit);
      _enMain = null;
    });
    _apresChangement(depot: true);
  }

  /// Reprend le dernier fruit posé sur un plateau : il rentre dans la
  /// réserve, à la place qu'il y occupait.
  void _reprendre(bool gauche) {
    final poses = gauche ? _gauche : _droite;
    if (poses.isEmpty) return;
    setState(() {
      final fruit = poses.removeLast();
      _reserve.add(fruit);
      _reserve.sort((a, b) => a.id.compareTo(b.id));
    });
    _apresChangement(depot: false);
  }

  /// Après CHAQUE dépôt ou retrait, la balance parle.
  ///
  /// Égale et assez garnie : c'est réussi (une seule fois — la manche peut
  /// encore être manipulée après). Sinon, un dépôt qui rend les plateaux
  /// inégaux le dit, mais seulement si le déséquilibre est NOUVEAU : ni
  /// deux fois de suite du même côté, ni à chaque retrait.
  void _apresChangement({required bool depot}) {
    final donnees = _donnees;
    if (donnees == null) return;

    final avant = _equilibre;
    final signe = (_gauche.length - _droite.length).sign;
    final maintenant = _equilibreDe(_gauche.length, _droite.length);
    final desequilibreNouveau = signe != _signe;
    _equilibre = maintenant;
    _signe = signe;

    if (maintenant == _Equilibre.egal) {
      if (avant != _Equilibre.egal) {
        unawaited(widget.rappels.dire(donnees.egalCle));
      }
      _mancheReussie();
      return;
    }
    if (maintenant == _Equilibre.penche && depot && desequilibreNouveau) {
      unawaited(widget.rappels.dire(donnees.pencheCle));
    }
  }

  void _mancheReussie() {
    if (_reussi) return;
    _reussi = true;
    widget.rappels.itemReussi();
  }

  // ── La géométrie ──────────────────────────────────────────────────────

  /// Où se dessine la balance.
  ///
  /// Le fléau va d'un plateau à l'autre ; les plateaux pendent à hauteur
  /// FIXE sous lui, reliés par deux petits traits.
  ({
    double hauteurPlateau,
    double hautPlateaux,
    double centreX,
    double centreY,
    double demi,
    double largeurPlateau,
    double plateauGaucheX,
    double plateauDroiteX,
  })
  _geometrie(double largeur, double hauteur) {
    final l = largeur.isFinite ? largeur : 390.0;
    final h = hauteur.isFinite ? hauteur : 460.0;
    const marge = 12.0;
    // Le creux entre les deux plateaux : le pivot s'y dresse.
    const ecart = 16.0;
    final largeurPlateau = ((l - 2 * marge - ecart) / 2)
        .clamp(90.0, 460.0)
        .toDouble();
    final hauteurPlateau = math
        .min((h * 0.55).clamp(116.0, 210.0), h)
        .toDouble();
    final hautPlateaux = math.max(h - hauteurPlateau, 0.0);
    final centreX = l / 2;
    // Le fléau s'arrête au-dessus du centre de chaque plateau : c'est de là
    // que pendent les traits.
    final demi = ecart / 2 + largeurPlateau / 2;
    // Les bouts du fléau descendent de demi × sin(10°) : la suspension est
    // toujours plus longue, les plateaux ne sont jamais touchés.
    final centreY = math.max(hautPlateaux - math.max(56.0, demi * 0.3), 26.0);
    return (
      hauteurPlateau: hauteurPlateau,
      hautPlateaux: hautPlateaux,
      centreX: centreX,
      centreY: centreY,
      demi: demi,
      largeurPlateau: largeurPlateau,
      plateauGaucheX: centreX - ecart / 2 - largeurPlateau,
      plateauDroiteX: centreX + ecart / 2,
    );
  }

  // ── Le dessin ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final donnees = _donnees;
    if (donnees == null) {
      // Une manche mal construite ne doit jamais montrer d'erreur à un
      // enfant : un écran crème, calme, sans rien d'autre.
      return const _EcranCalme();
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        final barre = _mesureBarre(
          contraintes.maxWidth,
          contraintes.maxHeight,
          donnees,
        );
        // La réserve ne prend jamais toute la hauteur : la balance reste
        // visible même avec beaucoup de fruits.
        final hauteurBarre = math.min(
          barre.hauteur,
          math.max(contraintes.maxHeight - _hauteurBalanceMini - 10, 0.0),
        );
        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, place) =>
                    _scene(place.maxWidth, place.maxHeight),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: hauteurBarre,
              child: SingleChildScrollView(
                child: _reserveFruits(
                  barre.cote,
                  contraintes.maxHeight < 400
                      ? 2
                      : contraintes.maxWidth <= 500
                      ? 4
                      : donnees.reserve.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// La balance : le pivot et les traits (peints), les deux plateaux, puis
  /// le fléau par-dessus.
  Widget _scene(double largeur, double hauteur) {
    final place = _geometrie(largeur, hauteur);
    final angle = _angleDegres * math.pi / 180;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: place.hautPlateaux,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: angle),
            duration: _dureePenchement,
            curve: Curves.easeInOut,
            builder: (context, valeur, _) => CustomPaint(
              painter: _PeintreBalance(
                angle: valeur,
                centre: Offset(place.centreX, place.centreY),
                demi: place.demi,
                bas: place.hautPlateaux,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Les deux plateaux, à hauteur fixe : ils ne bougent jamais, même
        // quand la balance penche.
        Positioned(
          left: place.plateauGaucheX,
          top: place.hautPlateaux,
          width: place.largeurPlateau,
          height: place.hauteurPlateau,
          child: _plateau(cote: MoteurBalance.coteGauche, fruits: _gauche),
        ),
        Positioned(
          left: place.plateauDroiteX,
          top: place.hautPlateaux,
          width: place.largeurPlateau,
          height: place.hauteurPlateau,
          child: _plateau(cote: MoteurBalance.coteDroite, fruits: _droite),
        ),
        // Le fléau, par-dessus le pivot : il penche du côté le plus lourd.
        Positioned(
          left: place.centreX - place.demi,
          top: place.centreY - _hauteurFleau / 2,
          width: place.demi * 2,
          height: _hauteurFleau,
          child: AnimatedRotation(
            key: MoteurBalance.cleFleau,
            turns: angle / (2 * math.pi),
            duration: _dureePenchement,
            curve: Curves.easeInOut,
            child: const _Fleau(),
          ),
        ),
      ],
    );
  }

  Widget _plateau({required String cote, required List<_Fruit> fruits}) {
    return CibleTactile(
      key: MoteurBalance.clePlateau(cote),
      onTap: () => _toucherPlateau(cote == MoteurBalance.coteGauche),
      // Étiquette d'accessibilité : invisible pour l'enfant, qui n'écoute
      // que les clips.
      semantique: cote == MoteurBalance.coteGauche
          ? 'plateau de gauche'
          : 'plateau de droite',
      child: _Plateau(
        cote: cote,
        fruits: fruits,
        lexique: widget.lexique,
        invite: _enMain != null,
        minimum: _donnees?.minimumParPlateau ?? 0,
      ),
    );
  }

  /// La réserve de fruits, en bas : les cartes qui attendent d'être posées.
  Widget _reserveFruits(double cote, int capacite) {
    if (_reserve.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: [
          for (final fruit in _reserve.take(capacite))
            _carteReserve(fruit, cote),
        ],
      ),
    );
  }

  Widget _carteReserve(_Fruit fruit, double cote) {
    final entree = widget.lexique[fruit.concept];
    return SizedBox(
      width: cote,
      height: cote,
      child: CibleTactile(
        key: MoteurBalance.cleFruit(fruit.id, fruit.concept),
        onTap: () => _toucherFruit(fruit),
        semantique: entree?.texte ?? fruit.concept,
        child: _CarteFruit(
          concept: fruit.concept,
          fichier: entree?.illustrationPour(fruit.concept) ?? '',
          cote: cote,
          enMain: _enMain?.id == fruit.id,
        ),
      ),
    );
  }

  /// La place qu'il faut à la réserve, et la taille des cartes.
  ///
  /// Le calcul se fait sur la fenêtre visible de la réserve : la réserve ne bouge pas quand
  /// un fruit est posé. Les cartes ne descendent jamais sous 84 pt (des
  /// doigts d'enfant) et l'image garde la taille d'une carte de jeu.
  ({double cote, double hauteur}) _mesureBarre(
    double largeurMax,
    double hauteurMax,
    DonneesBalance donnees,
  ) {
    final n = math.min(
      donnees.reserve.length,
      hauteurMax < 400
          ? 2
          : largeurMax <= 500
          ? 4
          : donnees.reserve.length,
    );
    if (n == 0) return (cote: 0, hauteur: 0);
    final largeur = largeurMax.isFinite ? largeurMax : 390.0;

    var cote = 0.0;
    var lignes = 1;
    for (var parLigne = n; parLigne >= 1; parLigne--) {
      final l = (n / parLigne).ceil();
      final c = math.min(
        (largeur - _ecartFruits * (parLigne - 1)) / parLigne,
        _coteFruitMax,
      );
      if (c > cote) {
        cote = c;
        lignes = l;
      }
      if (c >= _coteFruitMin) break;
    }

    var hauteur = lignes * cote + _ecartLignes * (lignes - 1);
    final plafond = (hauteurMax.isFinite ? hauteurMax : 460.0) * 0.42;
    if (hauteur > plafond) {
      cote = math.max(
        _coteFruitMin,
        (plafond - _ecartLignes * (lignes - 1)) / lignes,
      );
      hauteur = lignes * cote + _ecartLignes * (lignes - 1);
    }
    return (
      cote: cote.clamp(_coteFruitMin, _coteFruitMax).floorToDouble(),
      hauteur: hauteur.ceilToDouble(),
    );
  }
}

/// La hauteur qu'on garde toujours pour la balance.
const _hauteurBalanceMini = 150.0;

/// L'inclinaison du fléau, en degrés.
const _inclinaison = 10.0;

/// La hauteur du fléau (la longue barre arrondie).
const _hauteurFleau = 16.0;

/// Le pivot : sa hauteur et la largeur de sa base.
const _hauteurPivot = 46.0;
const _largeurPivot = 68.0;

/// Le temps que met la balance à pencher (le fléau et ses traits).
const _dureePenchement = Duration(milliseconds: 350);

/// Le temps qu'un fruit met à se poser sur un plateau.
const _dureeArrivee = Duration(milliseconds: 200);

/// La taille d'un fruit posé sur un plateau.
const _coteFruit = 36.0;

/// Ce que deux fruits posés se chevauchent.
const _chevauchement = 8.0;

/// Les cartes de la réserve.
const _coteFruitMin = 84.0;
const _coteFruitMax = 108.0;
const _ecartFruits = 20.0;
const _ecartLignes = 16.0;

/// Un fruit de la réserve : la carte blanche d'un concept.
class _CarteFruit extends StatelessWidget {
  final String concept;
  final String fichier;
  final double cote;

  /// Le fruit est « en main » : la carte s'illumine pour dire où il est.
  final bool enMain;

  const _CarteFruit({
    required this.concept,
    required this.fichier,
    required this.cote,
    this.enMain = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: enMain ? Palette.soleil : Palette.cremeFonce,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: enMain
                ? Palette.soleil.withValues(alpha: 0.35)
                : const Color(0x14000000),
            blurRadius: enMain ? 18 : 10,
            spreadRadius: enMain ? 2 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ImageConcept(
          concept: concept,
          fichier: fichier,
          taille: cote * 0.6,
        ),
      ),
    );
  }
}

/// Un plateau : le grand plateau blanc de la balance.
///
/// Au fond les fruits posés, en minuscules et légèrement chevauchés, puis
/// la planche, puis le compteur discret — une pastille par fruit.
class _Plateau extends StatelessWidget {
  final String cote;
  final List<_Fruit> fruits;
  final Lexique lexique;

  /// Un fruit est en main : le plateau s'allume pour inviter à le poser.
  final bool invite;
  final int minimum;

  const _Plateau({
    required this.cote,
    required this.fruits,
    required this.lexique,
    required this.invite,
    required this.minimum,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: invite
              ? Palette.soleil.withValues(alpha: 0.7)
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
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _empilement(),
            ),
          ),
          const SizedBox(height: 4),
          _planche(),
          const SizedBox(height: 6),
          _compteur(),
        ],
      ),
    );
  }

  /// Les fruits posés, empilés du plus ancien au plus récent.
  Widget _empilement() {
    if (fruits.isEmpty) return const SizedBox(height: _coteFruit);
    return SizedBox(
      height: _coteFruit,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < fruits.length; i++)
              Transform.translate(
                offset: Offset(i == 0 ? 0 : -_chevauchement, 0),
                child: _FruitPose(
                  key: MoteurBalance.cleFruitPose(cote, fruits[i].id),
                  concept: fruits[i].concept,
                  fichier:
                      lexique[fruits[i].concept]?.illustrationPour(
                        fruits[i].concept,
                      ) ??
                      '',
                  taille: _coteFruit,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// La planche du plateau : c'est là que les fruits se posent.
  Widget _planche() {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: Palette.cremeFonce,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.grisDoux, width: 3),
      ),
    );
  }

  /// Le compteur discret : une pastille de soleil par fruit posé.
  Widget _compteur() {
    return SizedBox(
      height: 20,
      child: fruits.isEmpty && minimum <= 0
          ? null
          : Center(
              child: Container(
                key: MoteurBalance.clePoints(cote),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Palette.creme,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < math.max(fruits.length, minimum); i++)
                        Container(
                          key: i < fruits.length
                              ? MoteurBalance.clePoint(cote, i)
                              : ValueKey('balance.place.$cote.$i'),
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i < fruits.length
                                ? Palette.soleil
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.soleil, width: 2),
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

/// Un fruit fraîchement posé : il arrive en douceur (200 ms).
class _FruitPose extends StatefulWidget {
  final String concept;
  final String fichier;
  final double taille;

  const _FruitPose({
    super.key,
    required this.concept,
    required this.fichier,
    required this.taille,
  });

  @override
  State<_FruitPose> createState() => _FruitPoseState();
}

class _FruitPoseState extends State<_FruitPose> {
  bool _arrive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _arrive = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _arrive ? 1 : 0.55,
      duration: _dureeArrivee,
      curve: Curves.easeOut,
      child: ImageConcept(
        concept: widget.concept,
        fichier: widget.fichier,
        taille: widget.taille,
      ),
    );
  }
}

/// Le fléau : une longue barre arrondie, en bois clair.
class _Fleau extends StatelessWidget {
  const _Fleau();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.cremeFonce,
        borderRadius: BorderRadius.circular(_hauteurFleau / 2),
        border: Border.all(color: Palette.grisDoux, width: 3),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Le pivot (un triangle crème foncé) et les deux traits qui pendent des
/// bouts du fléau jusqu'aux plateaux.
///
/// Les traits sont TOUJOURS verticaux : un plateau pend, il ne tourne pas
/// avec la barre — c'est ce qui fait lire la balance d'un coup d'œil.
class _PeintreBalance extends CustomPainter {
  /// L'inclinaison du fléau, en radians (0 : la balance est droite).
  final double angle;

  /// Le centre du fléau — l'axe, sur la pointe du pivot.
  final Offset centre;

  /// La demi-longueur du fléau, du centre à chacune des deux extrémités.
  final double demi;

  /// Le y du haut des plateaux : les traits s'arrêtent là.
  final double bas;

  const _PeintreBalance({
    required this.angle,
    required this.centre,
    required this.demi,
    required this.bas,
  });

  @override
  void paint(Canvas canvas, Size taille) {
    final pointe = centre;
    final base = centre.dy + _hauteurPivot;
    final triangle = Path()
      ..moveTo(pointe.dx, pointe.dy)
      ..lineTo(pointe.dx - _largeurPivot / 2, base)
      ..lineTo(pointe.dx + _largeurPivot / 2, base)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..color = Palette.cremeFonce
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      triangle,
      Paint()
        ..color = Palette.grisDoux
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final trait = Paint()
      ..color = Palette.encreDouce
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    for (final sens in const [-1.0, 1.0]) {
      final bout = Offset(
        centre.dx + sens * demi * cos,
        centre.dy + sens * demi * sin,
      );
      canvas.drawLine(bout, Offset(bout.dx, bas), trait);
    }
  }

  @override
  bool shouldRepaint(covariant _PeintreBalance ancien) =>
      ancien.angle != angle ||
      ancien.centre != centre ||
      ancien.demi != demi ||
      ancien.bas != bas;

  /// La peinture ne prend jamais les doigts : sous elle, rien n'est
  /// touchable — les plateaux, eux, sont des vrais widgets au-dessus.
  @override
  bool hitTest(Offset position) => false;
}

/// Une manche mal construite (données absentes ou d'un autre moteur) :
/// un écran crème, calme, jamais une erreur pour un enfant.
class _EcranCalme extends StatelessWidget {
  const _EcranCalme();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: MoteurBalance.cleEcranCalme,
      color: Palette.creme,
      child: SizedBox.shrink(),
    );
  }
}
