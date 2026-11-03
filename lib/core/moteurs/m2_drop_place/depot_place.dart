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
import '../../widgets/contenu_carte_concept.dart';
import '../rappels_moteur.dart';

/// Moteur M2 : déposer chaque objet à sa place — ou le trier dans son bac.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine la scène et la barre
/// d'objets qu'on lui donne, écoute les doigts et raconte ce qui se passe
/// (objet nommé à la prise, essai raté, manche réussie) par [RappelsMoteur].
/// La consigne, les encouragements et la progression appartiennent à l'hôte.
///
/// Deux façons de faire, toujours les deux — à quatre ans on n'exige JAMAIS
/// un glisser :
///  - **glisser** une carte de la barre vers un emplacement (`Draggable`) ;
///  - **toucher** l'objet (il vient « en main »), puis toucher l'emplacement ;
///    toucher l'objet en main le repose dans la barre.
///
/// Ce qui est juste, ce qui ne l'est pas :
///  - un dépôt est bon quand l'emplacement accepte le concept
///    ([DonneesDepot.places]) — avec des objets identiques, n'importe quelle
///    assiette va sur n'importe quel ami libre ;
///  - hors des bacs, un emplacement ne reçoit QU'UN objet : une fois occupé,
///    il refuse le suivant sans punir (l'objet revient dans la barre) ;
///  - dans un bac, les objets s'empilent ;
///  - un essai raté n'est jamais puni ni coloré : l'objet retourne dans la
///    barre et l'emplacement se balance doucement (moins de 300 ms, sans
///    rouge et sans son dur).
///
/// La manche est réussie quand tous les objets sont placés.
class MoteurDepotPlace extends StatefulWidget {
  final Manche manche;

  /// Le lexique du deck actif (texte + illustration).
  final Lexique lexique;

  /// Afficher le mot écrit sous les images (6-7 ans).
  final bool afficherMots;

  /// Ce que le moteur raconte à l'hôte.
  final RappelsMoteur rappels;

  const MoteurDepotPlace({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
    this.afficherMots = false,
  });

  /// Clé de la carte d'un objet de la barre (les tests s'en servent).
  ///
  /// L'id est la position de l'objet dans [DonneesDepot.objets] : deux
  /// assiettes identiques sont deux objets, et chacune a sa carte.
  static ValueKey<String> cleObjet(int id, String concept) =>
      ValueKey('objet-$id-$concept');

  /// Clé de la carte d'un emplacement (les tests s'en servent).
  static ValueKey<String> cleEmplacement(String id) =>
      ValueKey('emplacement-$id');

  @override
  State<MoteurDepotPlace> createState() => _MoteurDepotPlaceState();
}

/// Un objet de la barre : son concept et sa position dans la manche.
///
/// Deux objets identiques sont deux objets : c'est ce qui permet à deux
/// amis d'avoir chacun leur assiette.
class _ObjetBarre {
  final int id;
  final String concept;

  const _ObjetBarre(this.id, this.concept);
}

class _MoteurDepotPlaceState extends State<MoteurDepotPlace>
    with SingleTickerProviderStateMixin {
  /// Les objets encore dans la barre, dans l'ordre de la manche.
  late List<_ObjetBarre> _barre;

  /// Ce qui est posé : id d'emplacement → concepts posés dessus.
  final Map<String, List<String>> _poses = {};

  /// L'objet « en main » (touche-toucher), ou null.
  _ObjetBarre? _enMain;

  /// L'emplacement qui se balance après un essai raté.
  String? _emplacementErreur;

  bool _reussi = false;
  final Map<String, int> _erreursParConcept = {};

  late final AnimationController _balancement;
  late final Animation<double> _angle;

  DonneesDepot? get _donnees {
    final donnees = widget.manche.donnees;
    return donnees is DonneesDepot ? donnees : null;
  }

  @override
  void initState() {
    super.initState();
    _barre = _objetsDeLaManche();
    _balancement = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addStatusListener(_apresBalancement);
    // Deux allers-retours, très légers : « pas tout à fait ici ».
    _angle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.03), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: -0.03), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.03), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _balancement, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant MoteurDepotPlace ancienne) {
    super.didUpdateWidget(ancienne);
    if (ancienne.manche != widget.manche) {
      // Manche suivante : on repart avec la barre pleine.
      _balancement.stop();
      _barre = _objetsDeLaManche();
      _poses.clear();
      _erreursParConcept.clear();
      _enMain = null;
      _emplacementErreur = null;
      _reussi = false;
    }
  }

  @override
  void dispose() {
    _balancement.dispose();
    super.dispose();
  }

  List<_ObjetBarre> _objetsDeLaManche() {
    final objets = _donnees?.objets ?? const <String>[];
    return [for (var i = 0; i < objets.length; i++) _ObjetBarre(i, objets[i])];
  }

  void _apresBalancement(AnimationStatus statut) {
    if (statut == AnimationStatus.completed && mounted) {
      setState(() => _emplacementErreur = null);
    }
  }

  /// Vrai si l'emplacement n'accepte plus d'objet.
  ///
  /// Hors des bacs, chaque zone ne reçoit qu'UN objet (« une assiette par
  /// ami ») ; un bac, lui, se remplit.
  bool _plein(DonneesDepot donnees, String emplacementId) {
    if (donnees.modeBacs) return false;
    return _poses[emplacementId]?.isNotEmpty ?? false;
  }

  // ── Les doigts ────────────────────────────────────────────────────────

  /// Un objet est pris : touché (il vient en main) ou soulevé pour un
  /// glisser. On le nomme — une seule fois par prise.
  void _prendre(_ObjetBarre objet) {
    if (_enMain?.id == objet.id || !_barre.contains(objet)) return;
    setState(() => _enMain = objet);
    final entree = widget.lexique[objet.concept];
    unawaited(
      widget.rappels.dire(
        entree?.clipPour(objet.concept) ?? 'lex.${objet.concept}',
      ),
    );
  }

  /// Toucher l'objet déjà en main le repose dans la barre.
  void _toucherObjet(_ObjetBarre objet) {
    if (_enMain?.id == objet.id) {
      setState(() => _enMain = null);
      return;
    }
    _prendre(objet);
  }

  /// Après un glisser : si l'objet n'a pas trouvé sa place, on le lâche.
  void _apresGlisser(_ObjetBarre objet) {
    if (!mounted) return;
    if (_enMain?.id == objet.id && _barre.contains(objet)) {
      setState(() => _enMain = null);
    }
  }

  /// Dépose [objet] sur [emplacement] — par glisser ou par toucher, c'est le
  /// même chemin.
  void _deposer(_ObjetBarre objet, EmplacementDepot emplacement) {
    final donnees = _donnees;
    if (donnees == null || !_barre.contains(objet)) return;

    // Une place déjà prise refuse l'objet sans punir : ce n'est pas une
    // erreur de l'enfant, la place est occupée. L'objet rentre dans la
    // barre, comme après un glisser refusé.
    if (_plein(donnees, emplacement.id)) {
      setState(() => _enMain = null);
      return;
    }

    final accepte = donnees.places[emplacement.id]?.contains(objet.concept);
    if (accepte != true) {
      // Jamais de rouge ni de son dur : l'objet revient dans la barre et
      // l'emplacement se balance doucement.
      setState(() {
        _erreursParConcept.update(
          objet.concept,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
        _enMain = null;
        _emplacementErreur = emplacement.id;
      });
      _balancement.forward(from: 0);
      widget.rappels.essaiRate();
      return;
    }

    setState(() {
      _barre.remove(objet);
      (_poses[emplacement.id] ??= <String>[]).add(objet.concept);
      _enMain = null;
    });
    if (_barre.isEmpty) _mancheReussie();
  }

  void _mancheReussie() {
    if (_reussi) return;
    _reussi = true;
    // Le clip de fin (ex. la phrase reconstruite) se dit AVANT la réussite —
    // c'est le moment où tout est en place et où l'enfant regarde l'écran.
    final finCle = _donnees?.finCle;
    if (finCle != null) {
      final manche = widget.manche;
      final rappels = widget.rappels;
      rappels.dire(finCle).then((_) {
        if (mounted && widget.manche == manche) rappels.itemReussi();
      });
    } else {
      widget.rappels.itemReussi();
    }
  }

  // ── Le dessin ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final donnees = widget.manche.donnees;
    assert(
      donnees is DonneesDepot,
      'Le moteur M2 attend une manche qui porte des DonneesDepot '
      '(emplacements, objets, places).',
    );
    if (donnees is! DonneesDepot) {
      // Une manche mal construite ne doit jamais montrer d'erreur à un
      // enfant : on ne dessine rien.
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        final barre = _mesureBarre(contraintes.maxWidth, contraintes.maxHeight);
        final hauteurScene = math.max(
          contraintes.maxHeight - barre.hauteur - 18,
          0.0,
        );
        return Column(
          children: [
            Expanded(
              child: donnees.modeBacs
                  ? _bacs(donnees)
                  : _emplacements(donnees, contraintes.maxWidth, hauteurScene),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
              child: AvancementGeste(
                faits: donnees.objets.length - _barre.length,
                total: donnees.objets.length,
              ),
            ),
            SizedBox(
              height: barre.hauteur,
              child: SingleChildScrollView(
                child: _barreObjets(
                  contraintes.maxWidth,
                  barre.cote,
                  barre.capacite,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// La scène : chaque emplacement est une carte blanche (une assiette
  /// devant un ami, une case du sac…).
  Widget _emplacements(
    DonneesDepot donnees,
    double largeurDispo,
    double hauteurScene,
  ) {
    final n = donnees.emplacements.length;
    if (n == 0) return const SizedBox.shrink();
    if (hauteurScene < 160 && largeurDispo >= n * 80 + (n - 1) * 12) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _emplacement(
                donnees,
                donnees.emplacements[i],
                double.infinity,
                double.infinity,
                false,
              ),
            ),
          ],
        ],
      );
    }
    final colonnes = n <= 2 ? n : (n <= 4 ? 2 : 3);
    final lignes = (n / colonnes).ceil();
    final mot = widget.afficherMots ? _hauteurMot : 0.0;
    final largeur = (largeurDispo - 24 * (colonnes - 1)) / colonnes;
    final hauteur = (hauteurScene - 24 * (lignes - 1)) / lignes - mot;
    final cote = math.min(largeur, hauteur).clamp(110.0, 300.0);

    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: [
            for (final emplacement in donnees.emplacements)
              _emplacement(
                donnees,
                emplacement,
                cote.floorToDouble(),
                (cote + mot).floorToDouble(),
                false,
              ),
          ],
        ),
      ),
    );
  }

  /// Le tri : deux GRANDS bacs côte à côte, les objets s'y empilent en
  /// minuscules.
  Widget _bacs(DonneesDepot donnees) {
    final emplacements = donnees.emplacements;
    if (emplacements.isEmpty) return const SizedBox.shrink();
    final parLigne = math.min(emplacements.length, 3);
    final lignes = <List<EmplacementDepot>>[
      for (var i = 0; i < emplacements.length; i += parLigne)
        emplacements.sublist(i, math.min(i + parLigne, emplacements.length)),
    ];
    return Column(
      children: [
        for (var l = 0; l < lignes.length; l++) ...[
          if (l > 0) const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < lignes[l].length; i++) ...[
                  if (i > 0) const SizedBox(width: 24),
                  Expanded(
                    child: _emplacement(
                      donnees,
                      lignes[l][i],
                      double.infinity,
                      double.infinity,
                      true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Un emplacement : zone de dépôt au doigt et au glisser (`DragTarget`),
  /// qui se balance doucement après un essai raté.
  Widget _emplacement(
    DonneesDepot donnees,
    EmplacementDepot emplacement,
    double largeur,
    double hauteur,
    bool bac,
  ) {
    final enfant = AnimatedBuilder(
      animation: _angle,
      builder: (context, enfant) => Transform.rotate(
        angle: _emplacementErreur == emplacement.id ? _angle.value : 0,
        child: enfant,
      ),
      child: DragTarget<_ObjetBarre>(
        key: MoteurDepotPlace.cleEmplacement(emplacement.id),
        // Une place prise ne s'allume même pas.
        onWillAcceptWithDetails: (_) => !_plein(donnees, emplacement.id),
        onAcceptWithDetails: (details) => _deposer(details.data, emplacement),
        builder: (context, candidats, rejetes) {
          final enMain = _enMain;
          return CibleTactile(
            onTap: enMain == null ? null : () => _deposer(enMain, emplacement),
            semantique:
                widget.lexique[emplacement.concept]?.texte ??
                emplacement.concept,
            child: _CarteEmplacement(
              emplacement: emplacement,
              entree: widget.lexique[emplacement.concept],
              lexique: widget.lexique,
              poses: _poses[emplacement.id] ?? const <String>[],
              largeur: largeur,
              hauteur: hauteur,
              bac: bac,
              afficherMot: widget.afficherMots,
              survole: candidats.isNotEmpty,
              invite:
                  enMain != null &&
                  candidats.isEmpty &&
                  !_plein(donnees, emplacement.id),
              aide:
                  enMain != null &&
                  (_erreursParConcept[enMain.concept] ?? 0) >= 2 &&
                  !_plein(donnees, emplacement.id) &&
                  (donnees.places[emplacement.id]?.contains(enMain.concept) ??
                      false),
            ),
          );
        },
      ),
    );
    // Dans un Wrap, la cible tactile s'étirerait à toute la ligne : on lui
    // donne sa taille nette (un bac, lui, prend toute la place offerte).
    if (!largeur.isFinite || !hauteur.isFinite) return enfant;
    return SizedBox(width: largeur, height: hauteur, child: enfant);
  }

  /// La barre d'objets, en bas : les cartes qui restent à placer.
  Widget _barreObjets(double largeurDispo, double cote, int capacite) {
    if (_barre.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Wrap(
        spacing: 24,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: [
          for (final objet in _barre.take(capacite)) _objetBarre(objet, cote),
        ],
      ),
    );
  }

  Widget _objetBarre(_ObjetBarre objet, double cote) {
    final entree = widget.lexique[objet.concept];
    final hauteur = (widget.afficherMots ? cote + _hauteurMot : cote)
        .floorToDouble();
    return SizedBox(
      width: cote,
      height: hauteur,
      child: Draggable<_ObjetBarre>(
        key: MoteurDepotPlace.cleObjet(objet.id, objet.concept),
        data: objet,
        onDragStarted: () => _prendre(objet),
        onDragEnd: (_) => _apresGlisser(objet),
        // La carte suit le doigt, soulevée et lumineuse.
        feedback: Material(
          type: MaterialType.transparency,
          child: Transform.scale(
            scale: 1.08,
            child: _CarteConcept(
              concept: objet.concept,
              entree: entree,
              cote: cote,
              afficherMot: widget.afficherMots,
              enMain: true,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.28,
          child: _CarteConcept(
            concept: objet.concept,
            entree: entree,
            cote: cote,
            afficherMot: widget.afficherMots,
          ),
        ),
        child: CibleTactile(
          onTap: () => _toucherObjet(objet),
          semantique: entree?.texte ?? objet.concept,
          child: _CarteConcept(
            concept: objet.concept,
            entree: entree,
            cote: cote,
            afficherMot: widget.afficherMots,
            enMain: _enMain?.id == objet.id,
          ),
        ),
      ),
    );
  }

  /// La hauteur qu'il faut à la barre, et la taille des cartes : la plus
  /// grande disposition confortable (cartes ≥ 96 pt), jamais sous 80 pt,
  /// jamais plus du tiers bas de l'écran.
  ///
  /// Le calcul se fait sur TOUTE la manche : la barre ne bouge pas quand un
  /// objet est posé.
  ({double cote, double hauteur, int capacite}) _mesureBarre(
    double largeurMax,
    double hauteurMax,
  ) {
    final capacite = hauteurMax < 420 ? 2 : (largeurMax < 600 ? 4 : 8);
    final n = math.min(_donnees?.objets.length ?? 0, capacite);
    if (n == 0) return (cote: 0, hauteur: 0, capacite: capacite);
    final mot = widget.afficherMots ? _hauteurMot : 0.0;

    var cote = 0.0;
    var lignes = 1;
    for (var parLigne = n; parLigne >= 1; parLigne--) {
      final l = (n / parLigne).ceil();
      final c = math.min((largeurMax - 24 * (parLigne - 1)) / parLigne, 150.0);
      if (c > cote) {
        cote = c;
        lignes = l;
      }
      if (c >= 96) break;
    }

    var hauteur = lignes * (cote + mot) + 20 * (lignes - 1);
    final plafond = hauteurMax * 0.55;
    if (hauteur > plafond) {
      cote = math.max(80.0, (plafond - 20 * (lignes - 1)) / lignes - mot);
      hauteur = lignes * (cote + mot) + 20 * (lignes - 1);
    }
    return (
      cote: cote.clamp(80.0, 150.0).floorToDouble(),
      hauteur: math.min(hauteur, plafond).ceilToDouble(),
      capacite: capacite,
    );
  }
}

/// Ce qu'un mot écrit ajoute sous une image (texte 24 pt + espace).
const _hauteurMot = 44.0;

/// La carte blanche d'un concept : coins 28, bord crème de 4 pt.
BoxDecoration _decorCarte({required Color bordure, Color? lueur}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: bordure, width: 4),
    boxShadow: [
      BoxShadow(
        color: lueur == null
            ? const Color(0x14000000)
            : lueur.withValues(alpha: 0.35),
        blurRadius: lueur == null ? 10 : 18,
        spreadRadius: lueur == null ? 0 : 2,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// Un texte d'enfant : il ne se coupe jamais en deux, il rétrécit un peu.
class _Mot extends StatelessWidget {
  final String texte;
  final double taille;

  const _Mot({required this.texte, required this.taille});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        texte,
        maxLines: 1,
        style: TextStyle(
          fontSize: taille,
          fontWeight: FontWeight.w700,
          color: Palette.encre,
        ),
      ),
    );
  }
}

/// Un objet de la barre (ou la carte qui suit le doigt pendant un glisser).
class _CarteConcept extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;
  final bool enMain;

  const _CarteConcept({
    required this.concept,
    required this.entree,
    required this.cote,
    required this.afficherMot,
    this.enMain = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: cote,
      height: afficherMot ? cote + _hauteurMot : cote,
      padding: const EdgeInsets.all(12),
      decoration: _decorCarte(
        bordure: enMain ? Palette.soleil : const Color(0xFFF3E8CF),
        lueur: enMain ? Palette.soleil : null,
      ),
      child: ContenuCarteConcept(
        concept: concept,
        entree: entree,
        cote: cote,
        afficherMot: afficherMot,
      ),
    );
  }
}

/// Un emplacement de la scène : le concept en grand, les objets posés
/// en petit (dessous, ou empilés au fond du bac).
class _CarteEmplacement extends StatelessWidget {
  final EmplacementDepot emplacement;
  final EntreeLexique? entree;
  final Lexique lexique;
  final List<String> poses;
  final double largeur;
  final double hauteur;
  final bool bac;
  final bool afficherMot;

  /// Un objet glissé est au-dessus : la zone s'illumine pour inviter.
  final bool survole;

  /// Un objet est « en main » (touche-toucher) : invitation plus douce.
  final bool invite;
  final bool aide;

  const _CarteEmplacement({
    required this.emplacement,
    required this.entree,
    required this.lexique,
    required this.poses,
    required this.largeur,
    required this.hauteur,
    required this.bac,
    required this.afficherMot,
    this.survole = false,
    this.invite = false,
    this.aide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: largeur,
          height: hauteur,
          padding: EdgeInsets.all(bac ? 16 : 10),
          decoration: _decorCarte(
            bordure: survole || aide
                ? Palette.verdure
                : (invite
                      ? Palette.soleil.withValues(alpha: 0.7)
                      : const Color(0xFFF3E8CF)),
            lueur: survole ? Palette.verdure : null,
          ),
          child: LayoutBuilder(
            builder: (context, contraintes) {
              if ((bac && contraintes.maxWidth > contraintes.maxHeight * 2) ||
                  (!bac &&
                      contraintes.maxHeight < 100 &&
                      contraintes.maxWidth > contraintes.maxHeight)) {
                final cote = math.min(80.0, contraintes.maxHeight);
                return Row(
                  children: [
                    ImageConcept(
                      concept: emplacement.concept,
                      fichier:
                          entree?.illustrationPour(emplacement.concept) ?? '',
                      taille: cote,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (afficherMot)
                            _Mot(
                              texte: entree?.texte ?? emplacement.concept,
                              taille: 22,
                            ),
                          if (poses.isNotEmpty)
                            _rangeePoses(math.min(24, cote * 0.4)),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: contraintes.maxWidth,
                  child: _contenu(
                    math.min(contraintes.maxWidth, contraintes.maxHeight),
                  ),
                ),
              );
            },
          ),
        ),
        if (aide)
          const Positioned(
            top: 8,
            right: 8,
            child: Icon(
              Icons.touch_app_rounded,
              color: Palette.verdure,
              size: 32,
            ),
          ),
      ],
    );
  }

  Widget _contenu(double cote) {
    final concept = emplacement.concept;
    final fichier = entree?.illustrationPour(concept) ?? '';
    final texte = entree?.texte ?? concept;

    if (bac) {
      final mini = cote * 0.2;
      return Column(
        children: [
          ImageConcept(concept: concept, fichier: fichier, taille: cote * 0.55),
          if (afficherMot) ...[
            const SizedBox(height: 4),
            _Mot(texte: texte, taille: 22),
          ],
          const SizedBox(height: 8),
          if (poses.isNotEmpty) _rangeePoses(mini),
        ],
      );
    }

    final dessin =
        cote *
        (poses.isEmpty
            ? (afficherMot ? 0.52 : 0.62)
            : (afficherMot ? 0.34 : 0.44));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ImageConcept(concept: concept, fichier: fichier, taille: dessin),
        if (poses.isNotEmpty) ...[
          const SizedBox(height: 4),
          _rangeePoses(cote * 0.22),
        ],
        if (afficherMot) ...[
          const SizedBox(height: 4),
          _Mot(texte: texte, taille: 22),
        ],
      ],
    );
  }

  /// Les objets posés ici, en minuscules — réduits ensemble si la place
  /// manque, jamais coupés.
  Widget _rangeePoses(double taille) {
    return SizedBox(
      height: taille,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final concept in poses)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _ObjetPose(
                  concept: concept,
                  fichier: lexique[concept]?.illustrationPour(concept) ?? '',
                  taille: taille,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un objet fraîchement posé : il se dépose en douceur (200 ms).
class _ObjetPose extends StatefulWidget {
  final String concept;
  final String fichier;
  final double taille;

  const _ObjetPose({
    required this.concept,
    required this.fichier,
    required this.taille,
  });

  @override
  State<_ObjetPose> createState() => _ObjetPoseState();
}

class _ObjetPoseState extends State<_ObjetPose> {
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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: ImageConcept(
        concept: widget.concept,
        fichier: widget.fichier,
        taille: widget.taille,
      ),
    );
  }
}
