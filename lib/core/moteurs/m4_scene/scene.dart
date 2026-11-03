import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/image_concept.dart';
import '../../widgets/contenu_carte_concept.dart';
import '../rappels_moteur.dart';

/// Moteur M4 : une scène animée qui se raconte en étapes.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine un décor, écoute le
/// doigt de l'enfant et raconte ce qui vient de se passer à son hôte
/// ([RappelsMoteur]). Les encouragements, les aides et la progression
/// appartiennent à l'hôte (l'écran de jeu).
///
/// Déroulement d'une manche :
///  1. le décor s'affiche dans son état initial ;
///  2. une étape SANS option montre son visuel pendant la narration si demandé,
///     puis laisse le temps d’observer avant d’avancer ;
///  3. une étape AVEC options attend un doigt : la bonne option applique son
///     visuel puis la scène avance (ou [RappelsMoteur.itemReussi] si c'était
///     la dernière étape), une mauvaise option appelle
///     [RappelsMoteur.essaiRate] et l'étape reste ouverte.
///
/// La narration du DÉBUT appartient à l'hôte, qui dit `clipsConsigne` ; le
/// moteur dit lui-même la narration des étapes qu'il ouvre en interne (voir
/// [direNarrationDepart] pour le cas où l'hôte préfère laisser la première
/// narration au moteur).
///
/// Une manche dont l'identifiant change (item suivant) remet la scène au
/// début ; l'hôte peut aussi forcer le redémarrage avec une `ValueKey`.
class MoteurScene extends StatefulWidget {
  final Manche manche;

  /// Le lexique du deck actif (texte des options, illustrations).
  final Lexique lexique;

  /// Vrai : le mot écrit apparaît sous chaque option (6-7 ans).
  final bool afficherMots;

  /// Ce que la scène raconte à son hôte (narration, réussite, essai raté).
  final RappelsMoteur rappels;

  /// Vrai pour que le moteur dise lui-même la narration de la première étape.
  ///
  /// Faux par défaut : la narration du début est portée par l'hôte, qui dit
  /// `clipsConsigne` (elle contient alors `etapes[0].narrationCle`).
  final bool direNarrationDepart;

  const MoteurScene({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
    this.afficherMots = false,
    this.direNarrationDepart = false,
  });

  @override
  State<MoteurScene> createState() => _MoteurSceneEtat();
}

class _MoteurSceneEtat extends State<MoteurScene> {
  /// Nom du visuel commun que le moteur dessine lui-même par-dessus le décor
  /// (les décors ignorent les noms qu'ils ne connaissent pas).
  static const visuelReussi = 'reponse_ok';

  /// Durée d'une animation douce (passage d'un état visuel au suivant).
  static const delaiAnimation = Duration(milliseconds: 350);

  /// Durée du clin d'œil doux sur une carte touchée par erreur.
  static const delaiErreur = Duration(milliseconds: 900);

  /// La bande du bas (réservée aux cartes) : elle garde TOUJOURS sa place
  /// pour que la scène ne saute pas quand les cartes apparaissent.
  static const _partBande = 0.36;
  static const _bandeMin = 150.0;
  static const _bandeMax = 260.0;

  /// L'étape en cours.
  int _indexEtape = 0;
  int _erreursEtape = 0;
  int _narration = 0;

  /// Le nom de l'état visuel affiché par le décor.
  String _visuelCourant = '';

  /// Vrai pendant l'animation de réussite : plus aucun doigt n'est écouté.
  bool _enTransition = false;

  /// Vrai quand la manche est terminée (l'hôte enchaîne).
  bool _fini = false;

  /// La dernière option touchée par erreur (léger bord rosé).
  String? _derniereErreur;

  Timer? _chrono;
  Timer? _chronoErreur;

  DonneesScene? get _donnees {
    final donnees = widget.manche.donnees;
    return donnees is DonneesScene ? donnees : null;
  }

  List<EtapeScene> get _etapes => _donnees?.etapes ?? const <EtapeScene>[];

  EtapeScene? get _etapeCourante {
    final etapes = _etapes;
    return _indexEtape < etapes.length ? etapes[_indexEtape] : null;
  }

  @override
  void initState() {
    super.initState();
    _recommencer();
    _lierConsigne();
  }

  @override
  void didUpdateWidget(covariant MoteurScene ancien) {
    super.didUpdateWidget(ancien);
    // Une autre manche : la scène repart de son premier état.
    if (ancien.manche.id != widget.manche.id) _recommencer();
    _lierConsigne();
  }

  @override
  void dispose() {
    final rappels = widget.rappels;
    if (rappels is ConsigneContextuelle) rappels.retirerConsigne(this);
    _chrono?.cancel();
    _chronoErreur?.cancel();
    super.dispose();
  }

  /// Remet la scène au premier état (sans `setState` : appelé pendant
  /// l'initialisation ou juste avant une reconstruction).
  void _recommencer() {
    _chrono?.cancel();
    _chronoErreur?.cancel();
    _chrono = null;
    _chronoErreur = null;
    _indexEtape = 0;
    _erreursEtape = 0;
    _narration++;
    _enTransition = false;
    _fini = false;
    _derniereErreur = null;

    final donnees = _donnees;
    if (donnees == null || donnees.etapes.isEmpty) {
      _visuelCourant = '';
      return;
    }
    _visuelCourant = donnees.visuelInitial ?? _visuelInitial(donnees.decor);
    final premiere = donnees.etapes.first;
    if (premiere.montrerAvant && premiere.visuel != null) {
      _visuelCourant = premiere.visuel!;
    }
    // La narration de la première étape : dite ici si elle attend un doigt
    // (les étapes automatiques passent par _armerEtape, qui la dit et
    // l'ATTEND avant d'enchaîner — jamais deux voix en parallèle).
    if (widget.direNarrationDepart && donnees.etapes.first.options.isNotEmpty) {
      unawaited(_narrerOption(donnees.etapes.first));
    }
    _armerEtape(donnees.etapes.first);
  }

  void _lierConsigne() {
    final rappels = widget.rappels;
    if (rappels is ConsigneContextuelle) {
      rappels.enregistrerConsigne(this, () async {
        final etape = _etapeCourante;
        if (etape == null || _fini) return;
        if (etape.options.isEmpty) {
          _chrono?.cancel();
          await _avancerApresNarration(etape);
        } else {
          await _narrerOption(etape);
        }
      });
    }
  }

  Future<void> _narrerOption(EtapeScene etape) async {
    final narration = ++_narration;
    _enTransition = true;
    await widget.rappels.dire(etape.narrationCle);
    if (!mounted ||
        narration != _narration ||
        _etapeCourante != etape ||
        _fini) {
      return;
    }
    setState(() => _enTransition = false);
  }

  /// L'état visuel de départ d'un décor (avant toute étape).
  String _visuelInitial(String decor) => switch (decor) {
    'bus' => 'passagers_0',
    'graine' => 'graine',
    'ciel' => 'soleil_bas',
    'milo' => 'visage_content',
    'horloge' => 'heure_12', // midi
    'droite' => 'grenouille_0', // la grenouille part du point 0
    'gateau' => 'gateau_entier', // aucune part encore coupée
    'perles' => 'perles:', // le fil est vide : la place 1 attend
    'eau' => '', // le bac d'eau seul
    'ombre' => '', // le mur et sa lampe, sans objet
    'fenetre' => 'temps_soleil', // il fait beau, au départ
    // Le chat commence dans la maison (le jeu « Devant, derrière, à côté »
    // demande ensuite où il se trouve).
    'maison' => 'chat_dans',
    _ => '',
  };

  /// Une étape sans option avance toute seule APRÈS sa narration.
  ///
  /// On attend la fin de la voix (`rappels.dire` est await-able) avant de
  /// compter le petit délai : sinon l'étape suivante couperait sa propre
  /// narration. Une étape auto = narration, un souffle, puis on avance.
  void _armerEtape(EtapeScene etape) {
    if (etape.options.isNotEmpty) return;
    _chrono?.cancel();
    unawaited(_avancerApresNarration(etape));
  }

  Future<void> _avancerApresNarration(EtapeScene etape) async {
    final narration = ++_narration;
    await widget.rappels.dire(etape.narrationCle);
    if (!mounted ||
        narration != _narration ||
        _etapeCourante != etape ||
        _fini) {
      return;
    }
    _apresDelai(
      Duration(milliseconds: etape.observationMs),
      () => _reussir(etape),
    );
  }

  /// L'enfant a touché une carte.
  void _choisir(String concept) {
    if (_fini || _enTransition || moteurEnPause(widget.rappels)) return;
    final etape = _etapeCourante;
    if (etape == null) return;

    if (etape.accepte(concept)) {
      _reussir(etape, choix: concept);
      return;
    }

    // Raté : jamais grave, jamais puni — l'hôte encourage et redit.
    widget.rappels.essaiRate();
    _chronoErreur?.cancel();
    setState(() {
      _derniereErreur = concept;
      _erreursEtape++;
    });
    _chronoErreur = Timer(delaiErreur, () {
      if (!mounted) return;
      setState(() => _derniereErreur = null);
    });
  }

  /// Applique le visuel de l'étape, puis avance (ou termine la manche).
  void _reussir(EtapeScene etape, {String? choix}) {
    final visuel =
        choix != null &&
            etape.autresBonnesOptions.contains(choix) &&
            etape.visuel == etape.bonneOption
        ? choix
        : etape.visuel;
    setState(() {
      _enTransition = true;
      _derniereErreur = null;
      if (visuel != null && visuel.isNotEmpty) _visuelCourant = visuel;
    });
    _apresDelai(delaiAnimation, _avancer);
  }

  /// Les délais d’observation et d’animation ne consomment pas la pause.
  void _apresDelai(Duration duree, VoidCallback action) {
    _chrono?.cancel();
    var restant = duree.inMilliseconds;
    void programmer() {
      final pas = math.min(100, restant);
      _chrono = Timer(Duration(milliseconds: pas), () {
        if (!mounted) return;
        if (!moteurEnPause(widget.rappels)) restant -= pas;
        if (restant <= 0) {
          action();
        } else {
          programmer();
        }
      });
    }

    programmer();
  }

  void _avancer() {
    if (_fini) return;
    final etapes = _etapes;
    final suivant = _indexEtape + 1;
    if (suivant >= etapes.length) {
      _terminer();
      return;
    }

    final etape = etapes[suivant];
    setState(() {
      _indexEtape = suivant;
      _erreursEtape = 0;
      if (etape.montrerAvant && etape.visuel != null) {
        _visuelCourant = etape.visuel!;
      }
      _enTransition = false;
      _derniereErreur = null;
    });
    // Le moteur raconte lui-même l'étape qu'il vient d'ouvrir.
    if (etape.options.isNotEmpty) unawaited(_narrerOption(etape));
    _armerEtape(etape);
  }

  void _terminer() {
    if (_fini) return;
    setState(() {
      _fini = true;
      _enTransition = true;
    });
    widget.rappels.itemReussi();
  }

  @override
  Widget build(BuildContext context) {
    final donnees = _donnees;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, contraintes) {
          final bande = _hauteurBande(
            contraintes.maxHeight,
            contraintes.maxWidth,
          );
          final etape = _etapeCourante;
          final options = (etape == null || _fini)
              ? const <String>[]
              : etape.options;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: donnees == null
                    ? const _DecorInconnu(decor: '', visuel: '')
                    : _decor(donnees.decor, bande),
              ),
              if (_visuelCourant == visuelReussi)
                Positioned(
                  left: 0,
                  right: 0,
                  top: contraintes.maxHeight * 0.05,
                  child: const Center(child: _PastilleReussite()),
                ),
              if (options.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: bande,
                  child: _barreOptions(options, contraintes, bande),
                ),
            ],
          );
        },
      ),
    );
  }

  double _hauteurBande(double hauteur, double largeur) {
    final n = _etapeCourante?.options.length ?? 0;
    final colonnes = math.max(1, ((largeur - 32 + 12) / (88 + 12)).floor());
    final lignes = n == 0 ? 1 : (n / colonnes).ceil();
    final necessaire =
        lignes * (88.0 + (widget.afficherMots ? 44 : 0)) +
        12 * (lignes - 1) +
        24;
    return math.min(
      hauteur,
      math.max(necessaire, (hauteur * _partBande).clamp(_bandeMin, _bandeMax)),
    );
  }

  Widget _decor(String decor, double bande) {
    final visuel = _visuelCourant;
    return switch (decor) {
      'bus' => _DecorBus(visuel: visuel, basReserve: bande),
      'graine' => _DecorGraine(visuel: visuel, basReserve: bande),
      'ciel' => _DecorCiel(visuel: visuel, basReserve: bande),
      'milo' => _DecorMilo(visuel: visuel, basReserve: bande),
      'objets' => _DecorObjets(visuel: visuel, basReserve: bande),
      'horloge' => _DecorHorloge(visuel: visuel, basReserve: bande),
      'droite' => _DecorDroite(visuel: visuel, basReserve: bande),
      'gateau' => _DecorGateau(visuel: visuel, basReserve: bande),
      'perles' => _DecorPerles(visuel: visuel, basReserve: bande),
      'eau' => _DecorEau(visuel: visuel, basReserve: bande),
      'ombre' => _DecorOmbre(visuel: visuel, basReserve: bande),
      'fenetre' => _DecorFenetre(visuel: visuel, basReserve: bande),
      'maison' => _DecorMaison(visuel: visuel, basReserve: bande),
      _ => _DecorInconnu(decor: decor, visuel: visuel),
    };
  }

  Widget _barreOptions(
    List<String> concepts,
    BoxConstraints contraintes,
    double bande,
  ) {
    final n = concepts.length;
    final parLigne = math.min(
      n,
      math.max(1, ((contraintes.maxWidth - 32 + 12) / 100).floor()),
    );
    final lignes = (n / parLigne).ceil();
    final mot = widget.afficherMots ? 44.0 : 0.0;
    final largeurDispo = contraintes.maxWidth - 32;
    final hauteurDispo = bande - 24;
    final coteL = (largeurDispo - 12 * (parLigne - 1)) / parLigne;
    final coteH = (hauteurDispo - 12 * (lignes - 1)) / lignes - mot;
    final cote = math.min(coteL, coteH).clamp(88.0, 132.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Palette.creme.withValues(alpha: 0),
            Palette.creme.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final concept in concepts)
              // La taille est posée ici : dans un Wrap, la [CibleTactile]
              // s'étirerait sinon sur toute la largeur (son Center intérieur
              // prend toute la place offerte).
              SizedBox(
                width: cote,
                height: _CarteOption.hauteurPour(cote, widget.afficherMots),
                child: _CarteOption(
                  concept: concept,
                  entree: widget.lexique[concept],
                  cote: cote,
                  afficherMot: widget.afficherMots,
                  enErreur: concept == _derniereErreur,
                  enAide:
                      _erreursEtape >= 2 &&
                      (_etapeCourante?.accepte(concept) ?? false),
                  onTap: () => _choisir(concept),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La carte blanche d'une option — les mêmes rondeurs que le moteur M1.
class _CarteOption extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;
  final bool enErreur;
  final bool enAide;
  final VoidCallback onTap;

  const _CarteOption({
    required this.concept,
    required this.entree,
    required this.cote,
    required this.afficherMot,
    required this.enErreur,
    required this.enAide,
    required this.onTap,
  });

  /// La hauteur de la carte : le mot écrit demande de la place en plus.
  static double hauteurPour(double cote, bool afficherMot) =>
      afficherMot ? cote + 44 : cote;

  @override
  Widget build(BuildContext context) {
    return CibleTactile(
      onTap: onTap,
      semantique: entree?.texte ?? concept,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: cote,
        height: hauteurPour(cote, afficherMot),
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
        child: ContenuCarteConcept(
          concept: concept,
          entree: entree,
          cote: cote,
          afficherMot: afficherMot,
        ),
      ),
    );
  }
}

/// La pastille de réussite : un crochet vert, jamais un score.
class _PastilleReussite extends StatelessWidget {
  const _PastilleReussite();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (contexte, valeur, enfant) =>
          Transform.scale(scale: valeur, child: enfant),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.creme,
          shape: BoxShape.circle,
          border: Border.all(color: Palette.verdure, width: 5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 54,
          color: Palette.verdure,
        ),
      ),
    );
  }
}

/// Repli pour un décor que cette version ne sait pas encore dessiner :
/// un fond crème doux et le visuel en simple [ImageConcept]. Jamais
/// d'exception, même si le dessin n'existe pas encore.
class _DecorInconnu extends StatelessWidget {
  final String decor;
  final String visuel;

  const _DecorInconnu({required this.decor, required this.visuel});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.creme,
      child: Center(
        child: ImageConcept(
          concept: visuel.isEmpty ? decor : visuel,
          taille: 150,
        ),
      ),
    );
  }
}

// ─────────────────────────── Décor « bus » ───────────────────────────

/// Le bus jaune, sa route et ses passagers.
///
/// Visuels : 'passagers_0' à 'passagers_5' — le nombre de petits personnages
/// debout devant le bus.
class _DecorBus extends StatefulWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : le sol se dessine au-dessus.
  final double basReserve;

  const _DecorBus({required this.visuel, required this.basReserve});

  @override
  State<_DecorBus> createState() => _DecorBusEtat();
}

class _DecorBusEtat extends State<_DecorBus> {
  static const _couleursPassagers = [
    Palette.corail,
    Palette.ciel,
    Palette.verdure,
    Palette.prune,
    Palette.soleil,
  ];

  int _passagers = 0;

  /// Traduit un nom d'état visuel en nombre de passagers.
  /// null : nom que ce décor ne connaît pas → on garde l'état courant.
  int? visuelPour(String nom) {
    if (!nom.startsWith('passagers_')) return null;
    return int.tryParse(nom.substring('passagers_'.length))?.clamp(0, 5);
  }

  @override
  void initState() {
    super.initState();
    _passagers = visuelPour(widget.visuel) ?? 0;
  }

  @override
  void didUpdateWidget(covariant _DecorBus ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) {
      _passagers = visuelPour(widget.visuel) ?? _passagers;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        final busH = sol * 0.52;
        final busL = math.min(l * 0.78, busH * 1.9);
        // Cinq passagers tiennent toujours côte à côte, même sur un téléphone.
        final taillePassager = math.min(sol * 0.20, l * 0.16);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le ciel du matin.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFBFE3F6), Color(0xFFEAF6FC)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: sol * 0.10,
              right: l * 0.10,
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Palette.soleil,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // La route passe sous les cartes.
            Positioned(
              left: 0,
              right: 0,
              top: sol,
              bottom: 0,
              child: const ColoredBox(color: Color(0xFFCFC5B0)),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: sol - 6,
              height: 6,
              child: const ColoredBox(color: Color(0xFFE6DCC6)),
            ),
            Positioned(
              left: (l - busL) / 2,
              top: math.max(0, sol - busH - sol * 0.02),
              width: busL,
              height: busH,
              child: const _BusJaune(),
            ),
            // Les passagers, devant le bus.
            Positioned(
              left: l * 0.06,
              right: l * 0.06,
              top: sol - sol * 0.24,
              height: sol * 0.24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 5; i++)
                    _Passager(
                      visible: i < _passagers,
                      couleur: _couleursPassagers[i],
                      taille: taillePassager,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// La caisse jaune du bus : vitres, bande corail, phares et roues.
class _BusJaune extends StatelessWidget {
  const _BusJaune();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth;
        final h = contraintes.maxHeight;
        final roue = h * 0.26;
        final rayon = h * 0.16;

        return Stack(
          children: [
            Positioned(
              left: l * 0.12 - roue / 2,
              bottom: 0,
              child: _Roue(diametre: roue),
            ),
            Positioned(
              right: l * 0.12 - roue / 2,
              bottom: 0,
              child: _Roue(diametre: roue),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: roue * 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.soleil,
                  borderRadius: BorderRadius.circular(rayon),
                  border: Border.all(color: const Color(0xFFDFA92B), width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(rayon - 4),
                  child: Stack(
                    children: [
                      // Les vitres.
                      Positioned(
                        left: l * 0.06,
                        right: l * 0.06,
                        top: h * 0.10,
                        height: h * 0.30,
                        child: Row(
                          children: [
                            for (var i = 0; i < 4; i++)
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCBE9F9),
                                    borderRadius: BorderRadius.circular(
                                      h * 0.06,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF9FC7DE),
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // La bande corail.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.52,
                        height: h * 0.12,
                        child: const ColoredBox(color: Palette.corail),
                      ),
                      // Le phare avant.
                      Positioned(
                        right: l * 0.04,
                        bottom: h * 0.08,
                        child: Container(
                          width: l * 0.07,
                          height: h * 0.10,
                          decoration: BoxDecoration(
                            color: Palette.creme,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFDFA92B),
                              width: 3,
                            ),
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
}

class _Roue extends StatelessWidget {
  final double diametre;

  const _Roue({required this.diametre});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametre,
      height: diametre,
      decoration: BoxDecoration(
        color: const Color(0xFF3E3327),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF5C4A38), width: 3),
      ),
      child: Center(
        child: Container(
          width: diametre * 0.36,
          height: diametre * 0.36,
          decoration: const BoxDecoration(
            color: Color(0xFFCDBF9F),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Un petit passager : un rond coloré avec un visage simple.
class _Passager extends StatelessWidget {
  final bool visible;
  final Color couleur;
  final double taille;

  const _Passager({
    required this.visible,
    required this.couleur,
    required this.taille,
  });

  @override
  Widget build(BuildContext context) {
    final tete = taille * 0.58;
    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        offset: visible ? Offset.zero : const Offset(0, 0.45),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          opacity: visible ? 1 : 0,
          child: SizedBox(
            width: taille * 0.75,
            height: taille,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _Tete(taille: tete),
                Container(
                  width: taille * 0.72,
                  height: taille - tete,
                  decoration: BoxDecoration(
                    color: couleur,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                      bottom: Radius.circular(4),
                    ),
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

class _Tete extends StatelessWidget {
  final double taille;

  const _Tete({required this.taille});

  @override
  Widget build(BuildContext context) {
    final oeil = taille * 0.13;
    const encre = Palette.encre;
    return Container(
      width: taille,
      height: taille,
      decoration: const BoxDecoration(
        color: Color(0xFFF6CFA8),
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: oeil,
                height: oeil,
                decoration: const BoxDecoration(
                  color: encre,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: taille * 0.22),
              Container(
                width: oeil,
                height: oeil,
                decoration: const BoxDecoration(
                  color: encre,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          SizedBox(height: taille * 0.06),
          // Le sourire : un simple trait arrondi.
          Container(
            width: taille * 0.34,
            height: taille * 0.2,
            decoration: BoxDecoration(
              border: const Border(
                bottom: BorderSide(color: encre, width: 2.5),
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.elliptical(taille * 0.17, taille * 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Décor « graine » ─────────────────────────

/// La terre, l'arrosoir, et une pousse qui grandit.
///
/// Visuels : 'graine', 'pousse_1', 'pousse_2', 'pousse_3' (la tige monte),
/// 'fleur' (la fleur s'ouvre).
class _DecorGraine extends StatefulWidget {
  final String visuel;
  final double basReserve;

  const _DecorGraine({required this.visuel, required this.basReserve});

  @override
  State<_DecorGraine> createState() => _DecorGraineEtat();
}

class _DecorGraineEtat extends State<_DecorGraine> {
  /// 0 graine, 1-3 pousses de plus en plus hautes, 4 fleur éclose.
  int _pousse = 0;

  /// Traduit un nom d'état visuel en étape de pousse.
  /// null : nom inconnu de ce décor → on garde l'état courant.
  int? visuelPour(String nom) => switch (nom) {
    'graine' => 0,
    'pousse_1' => 1,
    'pousse_2' => 2,
    'pousse_3' => 3,
    'fleur' => 4,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _pousse = visuelPour(widget.visuel) ?? 0;
  }

  @override
  void didUpdateWidget(covariant _DecorGraine ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) {
      _pousse = visuelPour(widget.visuel) ?? _pousse;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        final base = sol - sol * 0.04;
        // La bande où la plante grandit : assez haute pour la fleur éclose.
        final bandePlante = sol * 0.72;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE4F2FB), Palette.creme],
                  ),
                ),
              ),
            ),
            // Le soleil.
            Positioned(
              top: sol * 0.08,
              right: l * 0.12,
              child: Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: Palette.soleil,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x33F6C445), blurRadius: 24),
                  ],
                ),
              ),
            ),
            // La terre (elle descend sous les cartes).
            Positioned(
              left: l * 0.02,
              right: l * 0.02,
              top: sol - sol * 0.10,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF9C7248),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.elliptical(l * 0.55, sol * 0.12),
                  ),
                ),
              ),
            ),
            // L'arrosoir, posé sur la terre.
            Positioned(
              right: l * 0.14,
              top: sol - sol * 0.20,
              child: _Arrosoir(taille: sol * 0.17),
            ),
            // La plante : elle pousse vers le haut depuis la terre.
            Positioned(
              left: 0,
              right: 0,
              top: base - bandePlante,
              height: bandePlante,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // La fleur éclose.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    opacity: _pousse >= 4 ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      scale: _pousse >= 4 ? 1 : 0.4,
                      child: ImageConcept(concept: 'fleur', taille: sol * 0.22),
                    ),
                  ),
                  // Les deux feuilles.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 350),
                    opacity: _pousse >= 2 ? 1 : 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Feuille(taille: sol * 0.11, gauche: true),
                        SizedBox(width: sol * 0.03),
                        _Feuille(taille: sol * 0.11, gauche: false),
                      ],
                    ),
                  ),
                  // La tige : sa hauteur est l'animation du moteur.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    width: 10,
                    height: switch (_pousse) {
                      0 => 0.0,
                      1 => sol * 0.10,
                      2 => sol * 0.19,
                      3 => sol * 0.27,
                      _ => sol * 0.27,
                    },
                    decoration: BoxDecoration(
                      color: Palette.verdure,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // La graine, au pied de la tige.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _pousse == 0 ? 1 : 0,
                    child: Container(
                      width: 22,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6B4A2E),
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(11, 8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Feuille extends StatelessWidget {
  final double taille;
  final bool gauche;

  const _Feuille({required this.taille, required this.gauche});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: gauche ? 0.5 : -0.5,
      child: Container(
        width: taille,
        height: taille * 0.55,
        decoration: const BoxDecoration(
          color: Palette.verdure,
          borderRadius: BorderRadius.all(Radius.elliptical(30, 14)),
        ),
      ),
    );
  }
}

class _Arrosoir extends StatelessWidget {
  final double taille;

  const _Arrosoir({required this.taille});

  @override
  Widget build(BuildContext context) {
    const corps = Color(0xFF8FB6C9);
    const trait = Color(0xFF6E97AB);
    return SizedBox(
      width: taille * 1.2,
      height: taille,
      child: Stack(
        children: [
          // La poignée.
          Positioned(
            left: taille * 0.20,
            top: 0,
            child: Container(
              width: taille * 0.46,
              height: taille * 0.26,
              decoration: BoxDecoration(
                border: Border.all(color: trait, width: 4),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(taille * 0.23),
                ),
              ),
            ),
          ),
          // Le corps.
          Positioned(
            left: 0,
            right: taille * 0.30,
            top: taille * 0.22,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: corps,
                borderRadius: BorderRadius.circular(taille * 0.14),
                border: Border.all(color: trait, width: 3),
              ),
            ),
          ),
          // Le bec.
          Positioned(
            right: 0,
            top: taille * 0.16,
            child: Transform.rotate(
              angle: 0.6,
              child: Container(
                width: taille * 0.46,
                height: taille * 0.12,
                decoration: BoxDecoration(
                  color: corps,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: trait, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Décor « ciel » ──────────────────────────

/// Le grand ciel qui change d'heure : matin clair, midi bleu, nuit étoilée.
///
/// Visuels : 'soleil_bas' (le soleil monte, bas dans le ciel),
/// 'soleil_haut' (midi), 'lune' (la nuit tombe).
class _DecorCiel extends StatefulWidget {
  final String visuel;
  final double basReserve;

  const _DecorCiel({required this.visuel, required this.basReserve});

  @override
  State<_DecorCiel> createState() => _DecorCielEtat();
}

enum _Moment { matin, midi, nuit }

class _DecorCielEtat extends State<_DecorCiel> {
  /// Des étoiles : x, y (fractions de la zone) et diamètre.
  static const _etoiles = <List<double>>[
    [0.15, 0.10, 7],
    [0.30, 0.26, 5],
    [0.52, 0.08, 6],
    [0.80, 0.28, 5],
    [0.66, 0.04, 4],
    [0.24, 0.40, 4],
  ];

  _Moment _moment = _Moment.matin;

  /// Traduit un nom d'état visuel en moment du ciel.
  /// null : nom inconnu de ce décor → on garde l'état courant.
  _Moment? visuelPour(String nom) => switch (nom) {
    'soleil_bas' => _Moment.matin,
    'soleil_haut' => _Moment.midi,
    'lune' => _Moment.nuit,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _moment = visuelPour(widget.visuel) ?? _Moment.matin;
  }

  @override
  void didUpdateWidget(covariant _DecorCiel ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) {
      _moment = visuelPour(widget.visuel) ?? _moment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        final nuit = _moment == _Moment.nuit;

        final couleurs = switch (_moment) {
          _Moment.matin => const [Color(0xFFA9D9F4), Color(0xFFFBE6C4)],
          _Moment.midi => const [Color(0xFF79C2EC), Color(0xFFC7E7F8)],
          _Moment.nuit => const [Color(0xFF252E58), Color(0xFF4C578C)],
        };
        // L'astre glisse le long de son arc : une ligne de trois positions.
        final astre = switch (_moment) {
          _Moment.matin => (l * 0.10, sol * 0.52),
          _Moment.midi => (l * 0.44, sol * 0.06),
          _Moment.nuit => (l * 0.68, sol * 0.10),
        };

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: couleurs,
                  ),
                ),
              ),
            ),
            // Les étoiles, seulement la nuit.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: nuit ? 1 : 0,
                  child: Stack(
                    children: [
                      for (final etoile in _etoiles)
                        Positioned(
                          left: l * etoile[0],
                          top: sol * etoile[1],
                          child: Container(
                            width: etoile[2],
                            height: etoile[2],
                            decoration: const BoxDecoration(
                              color: Color(0xFFFDF6E3),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Le soleil (ou la lune) qui se déplace.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              left: astre.$1,
              top: astre.$2,
              width: 76,
              height: 76,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  color: nuit
                      ? const Color(0xFFF3EEDC)
                      : (_moment == _Moment.midi
                            ? Palette.soleil
                            : const Color(0xFFFFC85C)),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: nuit
                          ? const Color(0x33F3EEDC)
                          : const Color(0x44F6C445),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            // La colline (elle descend sous les cartes).
            Positioned(
              left: -l * 0.10,
              right: -l * 0.10,
              top: sol - sol * 0.06,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: nuit
                      ? const Color(0xFF3D5B52)
                      : const Color(0xFF8FC9A0),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.elliptical(l * 0.5, sol * 0.14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────── Décor « milo » ──────────────────────────

/// Milo, la marionnette ronde : sa tête change de visage.
///
/// Visuels : 'visage_content', 'visage_triste', 'visage_colere',
/// 'visage_peur' (les illustrations du lexique des visages).
class _DecorMilo extends StatefulWidget {
  final String visuel;
  final double basReserve;

  const _DecorMilo({required this.visuel, required this.basReserve});

  @override
  State<_DecorMilo> createState() => _DecorMiloEtat();
}

class _DecorMiloEtat extends State<_DecorMilo> {
  String _visage = 'visage_content';

  /// Traduit un nom d'état visuel en visage.
  /// null : nom inconnu de ce décor → on garde le visage courant.
  String? visuelPour(String nom) => nom.startsWith('visage_') ? nom : null;

  @override
  void initState() {
    super.initState();
    _visage = visuelPour(widget.visuel) ?? 'visage_content';
  }

  @override
  void didUpdateWidget(covariant _DecorMilo ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) {
      _visage = visuelPour(widget.visuel) ?? _visage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        final taille = math.min(sol * 0.92, l * 0.62);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7EEDC), Palette.creme],
                  ),
                ),
              ),
            ),
            // Le plancher, sous les cartes.
            Positioned(
              left: 0,
              right: 0,
              top: sol,
              bottom: 0,
              child: const ColoredBox(color: Color(0xFFEADFC4)),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: sol,
              child: Center(
                child: _Marionnette(taille: taille, visage: _visage),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Un bras de Milo : une petite forme crème, légèrement inclinée.
class _Bras extends StatelessWidget {
  final double taille;
  final double angle;

  const _Bras({required this.taille, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: taille * 0.15,
        height: taille * 0.34,
        decoration: BoxDecoration(
          color: Palette.cremeFonce,
          borderRadius: BorderRadius.circular(taille * 0.08),
          border: Border.all(color: const Color(0xFFE3D5B8), width: 3),
        ),
      ),
    );
  }
}

/// Milo : une grande forme crème bordée, un corps, deux bras, et la tête
/// qui porte le visage du moment.
class _Marionnette extends StatelessWidget {
  final double taille;
  final String visage;

  const _Marionnette({required this.taille, required this.visage});

  @override
  Widget build(BuildContext context) {
    const bord = Color(0xFFE3D5B8);
    return SizedBox(
      width: taille,
      height: taille,
      child: Stack(
        children: [
          // Les bras.
          Positioned(
            left: taille * 0.02,
            top: taille * 0.54,
            child: _Bras(taille: taille, angle: 0.35),
          ),
          Positioned(
            right: taille * 0.02,
            top: taille * 0.54,
            child: _Bras(taille: taille, angle: -0.35),
          ),
          // Le corps.
          Positioned(
            bottom: 0,
            left: taille * 0.20,
            right: taille * 0.20,
            height: taille * 0.44,
            child: Container(
              decoration: BoxDecoration(
                color: Palette.cremeFonce,
                borderRadius: BorderRadius.circular(taille * 0.16),
                border: Border.all(color: bord, width: 4),
              ),
            ),
          ),
          // La tête ronde.
          Positioned(
            top: 0,
            left: taille * 0.22,
            width: taille * 0.56,
            height: taille * 0.56,
            child: Container(
              decoration: BoxDecoration(
                color: Palette.creme,
                shape: BoxShape.circle,
                border: Border.all(color: bord, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (enfant, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: enfant),
                  ),
                  child: ImageConcept(
                    key: ValueKey(visage),
                    concept: visage,
                    taille: taille * 0.38,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Décor « objets » ─────────────────────────

/// Le plateau d'objets du jeu « Qu'est-ce qui manque ? ».
///
/// Visuels : 'objets:a|b|c' — les concepts posés sur le plateau, séparés par
/// `|` (ex. 'objets:chat|ballon|fleur|pizza'). Un `//` sépare deux GROUPES
/// côte à côte (ex. 'objets:pomme|pomme|pomme//poisson|poisson') : c'est ce
/// qui permet de comparer deux tas. Un nom sans ce préfixe, ou une liste
/// vide ('objets:'), laisse le plateau vide : jamais d'exception.
class _DecorObjets extends StatelessWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : le plateau se pose au-dessus.
  final double basReserve;

  const _DecorObjets({required this.visuel, required this.basReserve});

  /// Le préfixe d'un visuel qui porte lui-même la liste des objets.
  static const _prefixe = 'objets:';

  /// La taille d'un objet quand la place le permet, et l'espace entre deux.
  static const _cote = 96.0;
  static const _espace = 24.0;

  /// Le grand espace du séparateur `//`, entre deux groupes.
  static const _espaceGroupes = 48.0;

  /// Sous cette taille, un objet ne rétrécit plus : la liste s'étage sur
  /// deux rangées (rare — les jeux posent trois ou quatre objets).
  static const _coteMini = 56.0;
  static const _espaceRangees = 16.0;

  /// Le plateau : son épaisseur, et de combien les objets le chevauchent
  /// (ils sont dessinés APRÈS lui, donc posés dessus).
  static const _hauteurPlateau = 28.0;
  static const _piedsSurLePlateau = 8.0;

  /// Traduit un nom d'état visuel en GROUPES de concepts.
  /// Tout nom qui ne commence pas par 'objets:' → aucun groupe (plateau vide).
  List<List<String>> groupesPour(String nom) {
    if (!nom.startsWith(_prefixe)) return const <List<String>>[];
    final groupes = <List<String>>[];
    for (final morceau in nom.substring(_prefixe.length).split('//')) {
      final groupe = morceau
          .split('|')
          .where((concept) => concept.isNotEmpty)
          .toList();
      if (groupe.isNotEmpty) groupes.add(groupe);
    }
    return groupes;
  }

  /// Tous les concepts du plateau, groupes confondus.
  List<String> visuelPour(String nom) => [
    for (final groupe in groupesPour(nom)) ...groupe,
  ];

  @override
  Widget build(BuildContext context) {
    final groupes = groupesPour(visuel);
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - basReserve).clamp(80.0, h);

        // Le plateau se pose au milieu de la scène, au-dessus des cartes.
        final hautPlateau = sol * 0.60;
        final largeurPlateau = math.min(l * 0.90, 520.0);
        final largeurUtile = largeurPlateau - 30;

        // Un seul tas la plupart du temps ; deux tas à comparer se partagent
        // la largeur, avec le grand espace du séparateur `//` entre eux.
        final nbGroupes = math.max(1, groupes.length);
        final largeurGroupe =
            (largeurUtile - _espaceGroupes * (nbGroupes - 1)) / nbGroupes;

        // Une rangée d'objets plutôt que deux étages sur la même tablette :
        // les objets rétrécissent un peu quand l'écran est étroit.
        double cotePour(int n) => n <= 1
            ? _cote
            : ((largeurGroupe - _espace * (n - 1)) / n).clamp(_coteMini, _cote);
        // Tous les tas ont des objets de la MÊME taille : c'est ce qui rend
        // les deux tas comparables d'un coup d'œil.
        final cote = groupes.isEmpty
            ? _cote
            : groupes.map((groupe) => cotePour(groupe.length)).reduce(math.min);
        final parLigne = math.max(
          1,
          ((largeurGroupe + _espace) / (cote + _espace)).floor(),
        );
        // Le tas le plus haut décide de la hauteur réservée.
        double hauteurPour(int n) {
          final rangees = n == 0 ? 1 : (n / parLigne).ceil();
          return rangees * cote + (rangees - 1) * _espaceRangees;
        }

        final hauteurObjets = groupes.isEmpty
            ? cote
            : groupes.map((g) => hauteurPour(g.length)).reduce(math.max);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le mur doux de la pièce.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7EEDC), Palette.creme],
                  ),
                ),
              ),
            ),
            // Le plateau : une tablette crème foncé, arrondie.
            Positioned(
              left: (l - largeurPlateau) / 2,
              top: hautPlateau,
              width: largeurPlateau,
              height: _hauteurPlateau,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.cremeFonce,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFFE3D5B8), width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            // Les objets, PAR-DESSUS le plateau (dessinés après lui).
            Positioned(
              left: (l - largeurUtile) / 2,
              top: math.max(
                0.0,
                hautPlateau - hauteurObjets + _piedsSurLePlateau,
              ),
              width: largeurUtile,
              height: hauteurObjets,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                  // Un objet qui part s'efface doucement ; celui qui arrive
                  // grandit. C'est l'animation du « qu'est-ce qui manque ? ».
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (enfant, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: enfant),
                    ),
                    child: Row(
                      key: ValueKey(visuel),
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < groupes.length; i++) ...[
                          if (i > 0) const SizedBox(width: _espaceGroupes),
                          // Chaque groupe se centre sur lui-même : les deux
                          // tas se lisent séparément.
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              runAlignment: WrapAlignment.end,
                              spacing: _espace,
                              runSpacing: _espaceRangees,
                              children: [
                                for (final concept in groupes[i])
                                  ImageConcept(concept: concept, taille: cote),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ────────────────────────── Décor « maison » ─────────────────────────

/// Où le chat se trouve, par rapport à la maison.
enum _PlaceChat {
  /// Devant la maison, sur le seuil.
  devant,

  /// Derrière la maison : dessiné AVANT elle, donc caché en partie.
  derriere,

  /// À côté de la maison, à hauteur du sol.
  acote,

  /// Dans la maison, à la fenêtre.
  dans,
}

/// La maison et son chat — le décor du jeu « Devant, derrière, à côté ».
///
/// Visuels : 'chat_devant', 'chat_derriere', 'chat_acote', 'chat_dans'.
/// Tout autre nom → la maison seule (jamais d'exception).
class _DecorMaison extends StatefulWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : la ligne de sol se dessine au-dessus.
  final double basReserve;

  const _DecorMaison({required this.visuel, required this.basReserve});

  @override
  State<_DecorMaison> createState() => _DecorMaisonEtat();
}

class _DecorMaisonEtat extends State<_DecorMaison> {
  /// La grande maison, le chat du sol, et celui de la fenêtre (plus petit).
  static const _coteMaison = 160.0;
  static const _coteChat = 72.0;
  static const _coteChatFenetre = 56.0;

  /// Le chat garde son identité d'une place à l'autre : il glisse doucement,
  /// même quand le Stack change l'ordre de ses enfants (« derriere » passe
  /// avant la maison, les autres places après).
  final _cleChat = GlobalKey();

  /// La place du chat ; null : la maison seule.
  _PlaceChat? _place;

  /// Traduit un nom d'état visuel en place du chat.
  /// null : nom inconnu de ce décor → la maison seule.
  _PlaceChat? visuelPour(String nom) => switch (nom) {
    'chat_devant' => _PlaceChat.devant,
    'chat_derriere' => _PlaceChat.derriere,
    'chat_acote' => _PlaceChat.acote,
    'chat_dans' => _PlaceChat.dans,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _place = visuelPour(widget.visuel);
  }

  @override
  void didUpdateWidget(covariant _DecorMaison ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) _place = visuelPour(widget.visuel);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        // La ligne de sol : la maison et le chat s'y posent.
        final base = sol - sol * 0.04;
        final coteMaison = math.min(_coteMaison, math.min(sol * 0.62, l * 0.5));
        final gaucheMaison = (l - coteMaison) / 2;
        final place = _place;
        // Le chat derrière est le seul à passer AVANT la maison.
        final derriere = place == _PlaceChat.derriere;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le ciel doux.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE4F2FB), Palette.creme],
                  ),
                ),
              ),
            ),
            // La ligne de sol : un pré plat, verdure et crème.
            Positioned(
              left: 0,
              right: 0,
              top: base,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Palette.verdure.withValues(alpha: 0.45),
                      Palette.creme,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: base - 5,
              height: 5,
              child: ColoredBox(color: Palette.verdure.withValues(alpha: 0.5)),
            ),
            // Le chat derrière : dessiné AVANT la maison, qui le cache.
            if (derriere) _chat(_PlaceChat.derriere, l, base, coteMaison),
            // La maison, posée sur la ligne de sol.
            Positioned(
              left: gaucheMaison,
              top: base - coteMaison,
              width: coteMaison,
              height: coteMaison,
              child: ImageConcept(concept: 'maison', taille: coteMaison),
            ),
            // Devant, à côté ou à la fenêtre : le chat passe après la maison.
            if (place != null && !derriere) _chat(place, l, base, coteMaison),
          ],
        );
      },
    );
  }

  /// Le chat à sa place, avec la taille de cette place.
  Widget _chat(_PlaceChat place, double l, double base, double coteMaison) {
    final (gauche, haut, cote) = switch (place) {
      // Sur le seuil : centré, les pieds dans la ligne de sol.
      _PlaceChat.devant => (
        (l - _coteChat) / 2,
        base - _coteChat + 6,
        _coteChat,
      ),
      // Plus haut et décalé à droite : la maison le cache en partie.
      _PlaceChat.derriere => (
        (l - coteMaison) / 2 + coteMaison * 0.70,
        base - coteMaison * 0.78,
        _coteChat,
      ),
      // À droite de la maison, à hauteur du sol.
      _PlaceChat.acote => (
        math.min(
          (l - coteMaison) / 2 + coteMaison + l * 0.02,
          l - _coteChat - 6,
        ),
        base - _coteChat + 6,
        _coteChat,
      ),
      // À la fenêtre : plus petit, au centre de la maison.
      _PlaceChat.dans => (
        (l - _coteChatFenetre) / 2,
        base - coteMaison * 0.28 - _coteChatFenetre,
        _coteChatFenetre,
      ),
    };

    return AnimatedPositioned(
      key: _cleChat,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      left: gauche,
      top: haut,
      width: cote,
      height: cote,
      child: ImageConcept(concept: 'chat', taille: cote),
    );
  }
}

// ───────────────────────── Décor « horloge » ─────────────────────────

/// Le cadran de l'horloge (les tests s'y accrochent ; le moteur, non).
const cleHorloge = ValueKey('horloge.cadran');

/// La petite aiguille (épaisse) et la grande (fine) : leur [Transform] porte
/// l'heure dessinée.
const cleAiguilleHeure = ValueKey('horloge.aiguille_heure');
const cleAiguilleMinute = ValueKey('horloge.aiguille_minute');

/// Le cadran de « L'heure du goûter » : un cercle crème bordé, douze marques
/// et deux aiguilles — aucun chiffre écrit, c'est l'heure qu'on regarde.
///
/// Visuels : 'heure_7' (sept heures), 'heure_7demi' (sept heures et demie)…
/// soit `heure_<h>` ou `heure_<h>demi`, h de 1 à 12. Un nom inconnu ne change
/// rien ; l'état de départ est midi ('heure_12').
class _DecorHorloge extends StatefulWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : le cadran se dessine au-dessus.
  final double basReserve;

  const _DecorHorloge({required this.visuel, required this.basReserve});

  @override
  State<_DecorHorloge> createState() => _DecorHorlogeEtat();
}

class _DecorHorlogeEtat extends State<_DecorHorloge> {
  static const _prefixe = 'heure_';
  static const _demie = 'demi';

  /// L'heure dessinée (1 à 12), et le vrai quand la grande aiguille est sur 6.
  int _heure = 12;
  bool _etDemie = false;

  /// Traduit un nom d'état visuel en (heure, demie).
  /// null : nom inconnu de ce décor → le cadran garde son heure.
  (int, bool)? visuelPour(String nom) {
    if (!nom.startsWith(_prefixe)) return null;
    var reste = nom.substring(_prefixe.length);
    var etDemie = false;
    if (reste.endsWith(_demie)) {
      etDemie = true;
      reste = reste.substring(0, reste.length - _demie.length);
    }
    final heure = int.tryParse(reste);
    if (heure == null || heure < 1 || heure > 12) return null;
    return (heure, etDemie);
  }

  /// L'heure reconnue prend la place de l'ancienne ; null : on garde.
  void _appliquer((int, bool)? heure) {
    if (heure == null) return;
    _heure = heure.$1;
    _etDemie = heure.$2;
  }

  @override
  void initState() {
    super.initState();
    _appliquer(visuelPour(widget.visuel));
  }

  @override
  void didUpdateWidget(covariant _DecorHorloge ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) _appliquer(visuelPour(widget.visuel));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        // Le cadran : rond, il tient dans la scène au-dessus des cartes.
        final taille = math.min(l * 0.70, sol * 0.70);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le mur doux de la cuisine.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7EEDC), Palette.creme],
                  ),
                ),
              ),
            ),
            Positioned(
              left: (l - taille) / 2,
              top: (sol - taille) / 2,
              width: taille,
              height: taille,
              child: _Cadran(
                key: cleHorloge,
                taille: taille,
                heure: _heure,
                demie: _etDemie,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Le cadran dessiné : le cercle, les douze marques et les aiguilles.
class _Cadran extends StatelessWidget {
  final double taille;
  final int heure;
  final bool demie;

  const _Cadran({
    super.key,
    required this.taille,
    required this.heure,
    required this.demie,
  });

  @override
  Widget build(BuildContext context) {
    final centre = taille / 2;
    return Stack(
      children: [
        // Le fond crème, bordé d'encre douce.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.creme,
              shape: BoxShape.circle,
              border: Border.all(color: Palette.encreDouce, width: 6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
          ),
        ),
        // Les douze marques — aucun chiffre écrit.
        for (var i = 0; i < 12; i++)
          Transform.rotate(
            angle: i * math.pi / 6,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: EdgeInsets.only(top: taille * 0.055),
                width: i % 3 == 0 ? taille * 0.034 : taille * 0.022,
                height: i % 3 == 0 ? taille * 0.075 : taille * 0.05,
                decoration: BoxDecoration(
                  color: Palette.encreDouce,
                  borderRadius: BorderRadius.circular(taille * 0.02),
                ),
              ),
            ),
          ),
        // La petite aiguille, sur l'heure ; la grande, sur le 12 ou le 6.
        _Aiguille(
          key: cleAiguilleHeure,
          ancre: centre,
          angle: (heure % 12) * 30,
          longueur: taille * 0.26,
          largeur: taille * 0.045,
          couleur: Palette.encre,
        ),
        _Aiguille(
          key: cleAiguilleMinute,
          ancre: centre,
          angle: demie ? 180 : 0,
          longueur: taille * 0.39,
          largeur: taille * 0.024,
          couleur: Palette.corail,
        ),
        // L'axe, au centre du cadran.
        Center(
          child: Container(
            width: taille * 0.055,
            height: taille * 0.055,
            decoration: const BoxDecoration(
              color: Palette.encre,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

/// Une aiguille : une barre arrondie accrochée au centre du cadran.
///
/// [angle] se lit en degrés d'horloge : 0 = midi, 90 = trois heures.
class _Aiguille extends StatelessWidget {
  final double ancre;
  final double angle;
  final double longueur;
  final double largeur;
  final Color couleur;

  const _Aiguille({
    super.key,
    required this.ancre,
    required this.angle,
    required this.longueur,
    required this.largeur,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    // La barre pend sous son point d'attache : on la fait tourner autour de
    // lui (le centre du cadran) du demi-tour qui la remet vers le haut.
    return Positioned(
      left: ancre - largeur / 2,
      top: ancre,
      child: Transform.rotate(
        angle: (angle - 180) * math.pi / 180,
        alignment: Alignment.topCenter,
        child: Container(
          width: largeur,
          height: longueur,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(largeur / 2),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Décor « droite » ─────────────────────────

/// La grenouille de la droite numérique (les tests s'y accrochent).
const cleGrenouille = ValueKey('droite.grenouille');

/// Le petit bond pointillé que la grenouille laisse derrière elle.
const cleBond = ValueKey('droite.bond');

/// La droite numérique de « La grenouille sur la ligne » : des points alignés
/// sur une ligne, sans chiffres, et la grenouille posée sur l'un d'eux.
///
/// Visuels : 'grenouille_3' (sur le point 3). Le préfixe 'droite20:' étend la
/// droite de 0 à 20 ('droite20:grenouille_15') ; sinon elle va de 0 à 10.
/// Un nom inconnu ne change rien ; au départ, la grenouille est au point 0.
class _DecorDroite extends StatefulWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : la ligne se dessine au-dessus.
  final double basReserve;

  const _DecorDroite({required this.visuel, required this.basReserve});

  @override
  State<_DecorDroite> createState() => _DecorDroiteEtat();
}

class _DecorDroiteEtat extends State<_DecorDroite> {
  static const _prefixe = 'grenouille';
  static const _prefixe20 = 'droite20:';

  /// Le nombre de points de la droite : 11 pour 0 à 10, 21 pour 0 à 20.
  int _points = 11;

  /// Le point où la grenouille est posée, et celui d'où elle vient — le bond
  /// se dessine entre les deux.
  int _point = 0;
  int? _precedent;

  /// Traduit un nom d'état visuel en (nombre de points, point de la grenouille).
  /// null : nom inconnu de ce décor → la grenouille ne bouge pas.
  (int, int)? visuelPour(String nom) {
    final vingt = nom.startsWith(_prefixe20);
    final reste = vingt ? nom.substring(_prefixe20.length) : nom;
    if (!reste.startsWith(_prefixe)) return null;
    var queue = reste.substring(_prefixe.length);
    if (queue.startsWith('_')) queue = queue.substring(1);
    final maximum = vingt ? 20 : 10;
    final chiffres = RegExp(r'\d+').firstMatch(queue);
    final point = chiffres == null ? 0 : int.parse(chiffres.group(0)!);
    return (maximum + 1, point.clamp(0, maximum));
  }

  /// La place reconnue prend la place de l'ancienne ; null : on garde.
  void _appliquer((int, int)? place) {
    if (place == null) return;
    final (points, point) = place;
    if (points != _points) {
      // La droite a changé de longueur : la grenouille repart sans bond.
      _points = points;
      _precedent = null;
    } else if (point != _point) {
      _precedent = _point;
    }
    _point = point;
  }

  @override
  void initState() {
    super.initState();
    _appliquer(visuelPour(widget.visuel));
  }

  @override
  void didUpdateWidget(covariant _DecorDroite ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) _appliquer(visuelPour(widget.visuel));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        final n = _points;
        // La grenouille doit tenir entre deux points, même sur la droite à 20.
        final part = 1.45 / (n - 1);
        final cote = (part * (l - 16) / (1 + part)).clamp(24.0, 56.0);
        final espacement = (l - 16 - cote) / (n - 1);
        final ligne = sol * 0.62;
        double x(int point) => 8 + cote / 2 + point * espacement;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le fond doux de la cour.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEAF6FC), Palette.creme],
                  ),
                ),
              ),
            ),
            // La ligne, d'un bout à l'autre de la droite.
            Positioned(
              left: x(0),
              top: ligne - 3,
              width: x(n - 1) - x(0),
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.encreDouce.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Les points de la droite : aucun chiffre écrit.
            for (var i = 0; i < n; i++)
              Positioned(
                left: x(i) - 5,
                top: ligne - 5,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Palette.encreDouce,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Le bond du dernier saut, traîné derrière elle.
            if (_precedent != null && _precedent != _point)
              _Bond(
                key: cleBond,
                depart: x(_precedent!),
                arrivee: x(_point),
                ligne: ligne,
                hauteur: cote * 0.85,
              ),
            // La grenouille, posée sur son point.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              left: x(_point) - cote / 2,
              top: ligne - cote,
              width: cote,
              height: cote,
              child: _Grenouille(key: cleGrenouille, taille: cote),
            ),
          ],
        );
      },
    );
  }
}

/// Le bond : un arc pointillé léger, de l'ancien point au nouveau.
class _Bond extends StatelessWidget {
  final double depart;
  final double arrivee;

  /// La hauteur de la ligne où la grenouille se pose.
  final double ligne;

  /// La hauteur de l'arc, au-dessus de la ligne.
  final double hauteur;

  const _Bond({
    super.key,
    required this.depart,
    required this.arrivee,
    required this.ligne,
    required this.hauteur,
  });

  /// Le nombre de points de l'arc.
  static const _grains = 9;

  /// La marge autour de l'arc : les points du bout ne sont pas coupés.
  static const _marge = 5.0;

  @override
  Widget build(BuildContext context) {
    final gauche = math.min(depart, arrivee);
    final largeur = (arrivee - depart).abs();
    return Positioned(
      left: gauche - _marge,
      top: ligne - hauteur - _marge,
      width: largeur + _marge * 2,
      height: hauteur + _marge * 2,
      child: IgnorePointer(
        child: Stack(
          children: [
            for (var i = 1; i < _grains; i++)
              Positioned(
                left: _marge + largeur * i / _grains - 4,
                top:
                    _marge +
                    hauteur * (1 - math.sin(math.pi * i / _grains)) -
                    4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Palette.verdure.withValues(
                      alpha: 0.12 + 0.42 * i / _grains,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La grenouille : un corps ovale vert, deux gros yeux blancs, un sourire.
class _Grenouille extends StatelessWidget {
  final double taille;

  const _Grenouille({super.key, required this.taille});

  /// Le vert de la grenouille, et le trait plus foncé de son contour.
  static const _vert = Color(0xFF63B96B);
  static const _vertFonce = Color(0xFF42914C);

  @override
  Widget build(BuildContext context) {
    final corps = taille * 0.70;
    final oeil = taille * 0.34;
    return SizedBox(
      width: taille,
      height: taille,
      child: Stack(
        children: [
          // Le corps, au bas de la boîte : ses pieds sur le point.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: corps,
            child: Container(
              decoration: BoxDecoration(
                color: _vert,
                borderRadius: BorderRadius.all(
                  Radius.elliptical(taille * 0.5, corps * 0.5),
                ),
                border: Border.all(
                  color: _vertFonce,
                  width: math.max(2, taille * 0.05),
                ),
              ),
            ),
          ),
          // Le sourire, sur le corps.
          Positioned(
            left: taille * 0.32,
            right: taille * 0.32,
            bottom: corps * 0.22,
            child: Container(
              height: corps * 0.16,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _vertFonce,
                    width: math.max(2, taille * 0.045),
                  ),
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(taille * 0.18, corps * 0.16),
                ),
              ),
            ),
          ),
          // Les deux gros yeux, à cheval sur le haut du corps.
          Positioned(
            left: taille * 0.10,
            top: taille * 0.02,
            child: _Oeil(diametre: oeil, trait: _vertFonce),
          ),
          Positioned(
            right: taille * 0.10,
            top: taille * 0.02,
            child: _Oeil(diametre: oeil, trait: _vertFonce),
          ),
        ],
      ),
    );
  }
}

/// Un gros œil blanc à pupille d'encre.
class _Oeil extends StatelessWidget {
  final double diametre;
  final Color trait;

  const _Oeil({required this.diametre, required this.trait});

  @override
  Widget build(BuildContext context) {
    final pupille = diametre * 0.42;
    return Container(
      width: diametre,
      height: diametre,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: trait, width: math.max(1.5, diametre * 0.09)),
      ),
      child: Align(
        alignment: const Alignment(0, 0.18),
        child: Container(
          width: pupille,
          height: pupille,
          decoration: const BoxDecoration(
            color: Palette.encre,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Décor « gateau » ─────────────────────────

/// Le gâteau vu de dessus (les tests s'y accrochent).
const cleGateau = ValueKey('gateau.centre');

/// Les lignes de coupe : une verticale pour deux parts, plus une horizontale
/// pour quatre.
const cleCoupeVerticale = ValueKey('gateau.coupe_verticale');
const cleCoupeHorizontale = ValueKey('gateau.coupe_horizontale');

/// La clé d'une cerise du gâteau (i : son rang).
ValueKey<String> cleCerise(int i) => ValueKey('gateau.cerise.$i');

/// Le gâteau de « Partager le gâteau », vu de dessus : un grand cercle corail,
/// ses cerises, et les lignes de coupe du partage.
///
/// Visuels : 'gateau_entier' (aucune coupe), 'gateau_2' (deux parts),
/// 'gateau_4' (quatre parts). Tout autre nom → le gâteau entier.
class _DecorGateau extends StatelessWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : le gâteau se pose au-dessus.
  final double basReserve;

  const _DecorGateau({required this.visuel, required this.basReserve});

  /// Les lignes de coupe que le visuel demande.
  static const _coupes = <String, int>{'gateau_2': 1, 'gateau_4': 2};

  /// Les cerises : x puis y, en fractions du gâteau.
  static const _cerises = <List<double>>[
    [0.50, 0.17],
    [0.19, 0.38],
    [0.81, 0.38],
    [0.29, 0.73],
    [0.71, 0.73],
    [0.50, 0.88],
  ];

  /// Traduit un nom d'état visuel en nombre de lignes de coupe.
  /// Nom inconnu ou vide → le gâteau entier (aucune coupe).
  int visuelPour(String nom) => _coupes[nom] ?? 0;

  @override
  Widget build(BuildContext context) {
    final coupes = visuelPour(visuel);
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - basReserve).clamp(80.0, h);
        final diam = math.min(l * 0.68, sol * 0.72);
        final gauche = (l - diam) / 2;
        final haut = (sol - diam) / 2;
        final trait = math.max(4.0, diam * 0.025);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le fond doux de la table.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE4F2FB), Palette.creme],
                  ),
                ),
              ),
            ),
            // L'assiette, sous le gâteau.
            Positioned(
              left: gauche - diam * 0.03,
              top: haut - diam * 0.03,
              width: diam * 1.06,
              height: diam * 1.06,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.cremeFonce,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFFE3D5B8), width: 4),
                  ),
                ),
              ),
            ),
            // Le gâteau : un grand cercle corail bordé.
            Positioned(
              left: gauche,
              top: haut,
              width: diam,
              height: diam,
              child: Container(
                key: cleGateau,
                decoration: BoxDecoration(
                  color: Palette.corail,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC9552F), width: 6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 14,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
              ),
            ),
            // Le glaçage : un anneau crème, posé sur le gâteau.
            Positioned(
              left: gauche + diam * 0.10,
              top: haut + diam * 0.10,
              width: diam * 0.80,
              height: diam * 0.80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Palette.creme.withValues(alpha: 0.85),
                    width: trait,
                  ),
                ),
              ),
            ),
            // Les lignes de coupe, sous les cerises.
            if (coupes >= 1)
              Positioned(
                left: gauche + diam / 2 - trait / 2,
                top: haut + diam * 0.02,
                width: trait,
                height: diam * 0.96,
                child: DecoratedBox(
                  key: cleCoupeVerticale,
                  decoration: BoxDecoration(
                    color: Palette.creme,
                    borderRadius: BorderRadius.circular(trait / 2),
                  ),
                ),
              ),
            if (coupes >= 2)
              Positioned(
                left: gauche + diam * 0.02,
                top: haut + diam / 2 - trait / 2,
                width: diam * 0.96,
                height: trait,
                child: DecoratedBox(
                  key: cleCoupeHorizontale,
                  decoration: BoxDecoration(
                    color: Palette.creme,
                    borderRadius: BorderRadius.circular(trait / 2),
                  ),
                ),
              ),
            // Les cerises, réparties sur le gâteau.
            for (var i = 0; i < _cerises.length; i++)
              Positioned(
                left: gauche + _cerises[i][0] * diam - diam * 0.055,
                top: haut + _cerises[i][1] * diam - diam * 0.055,
                child: _Cerise(key: cleCerise(i), diametre: diam * 0.11),
              ),
          ],
        );
      },
    );
  }
}

/// Une cerise : un rond rouge et son petit reflet.
class _Cerise extends StatelessWidget {
  final double diametre;

  const _Cerise({super.key, required this.diametre});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametre,
      height: diametre,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFB23834),
          width: math.max(1.5, diametre * 0.08),
        ),
      ),
      child: Align(
        alignment: const Alignment(-0.35, -0.35),
        child: Container(
          width: diametre * 0.26,
          height: diametre * 0.26,
          decoration: BoxDecoration(
            color: Palette.creme.withValues(alpha: 0.75),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Décor « perles » ─────────────────────────

/// La clé d'une perle du fil (i : son rang, 0 = la première).
ValueKey<String> clePerle(int i) => ValueKey('perles.perle.$i');

/// La place suivante du fil : la première libre, dessinée en pointillé.
const clePlaceSuivante = ValueKey('perles.place_suivante');

/// Le fil à perles de « Perles à motifs » : un fil souple, des perles
/// colorées enfilées dessus, et la place suivante qui attend sa perle.
///
/// Visuels : 'perles:rouge|jaune|rouge|jaune' — les couleurs des perles,
/// séparées par `|`. Un nom vide ('' ou 'perles:') laisse le fil vide avec sa
/// place 1 en pointillé ; un nom inconnu laisse le fil tel quel.
class _DecorPerles extends StatefulWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : le fil se dessine au-dessus.
  final double basReserve;

  const _DecorPerles({required this.visuel, required this.basReserve});

  @override
  State<_DecorPerles> createState() => _DecorPerlesEtat();
}

class _DecorPerlesEtat extends State<_DecorPerles> {
  static const _prefixe = 'perles:';

  /// Les couleurs concrètes des perles, par concept de couleur.
  static const _couleurs = <String, Color>{
    'rouge': Color(0xFFE53935),
    'jaune': Color(0xFFFDD835),
    'bleu': Color(0xFF1E88E5),
    'vert': Color(0xFF4CAF47),
    'violet': Color(0xFF8E24AA),
    'orange': Color(0xFFFB8C00),
  };

  /// Un concept de couleur inconnu : une perle grise, sans surprise.
  static const _grise = Color(0xFFBDBDBD);

  /// Les teintes des perles enfilées, de la première à la dernière.
  List<String> _perles = const <String>[];

  /// Traduit un nom d'état visuel en liste de concepts de couleurs.
  /// null : nom inconnu de ce décor → le fil garde ses perles.
  List<String>? visuelPour(String nom) {
    if (nom.isEmpty) return const <String>[]; // le fil est vide
    if (!nom.startsWith(_prefixe)) return null;
    return nom
        .substring(_prefixe.length)
        .split('|')
        .where((couleur) => couleur.isNotEmpty)
        .toList();
  }

  /// La couleur d'une perle : un concept inconnu devient gris.
  Color couleurDe(String concept) => _couleurs[concept] ?? _grise;

  @override
  void initState() {
    super.initState();
    _perles = visuelPour(widget.visuel) ?? const <String>[];
  }

  @override
  void didUpdateWidget(covariant _DecorPerles ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) {
      _perles = visuelPour(widget.visuel) ?? _perles;
    }
  }

  @override
  Widget build(BuildContext context) {
    final perles = _perles;
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);

        // Les places du fil : les perles enfilées, puis la place suivante.
        final places = perles.length + 1;
        final largeur = l - 40;
        final cote = (largeur / (1.35 * places - 0.35)).clamp(16.0, 34.0);
        final pas = places == 1
            ? 0.0
            : (largeur - places * cote) / (places - 1);
        final base = sol * 0.46;
        double x(int place) => 20 + cote / 2 + place * (cote + pas);
        // Le fil ondule doucement : ses creux tombent entre les perles.
        double y(double xx) {
          if (pas <= 0) return base;
          final periode = cote + pas;
          final creux = math.min(periode * 0.22, 12.0);
          return base +
              creux *
                  (0.5 - 0.5 * math.cos(2 * math.pi * (xx - x(0)) / periode));
        }

        // Le fil : de petits segments qui suivent sa courbe.
        final debut = math.max(0.0, x(0) - cote / 2 - 8);
        final fin = math.min(l, x(places - 1) + cote / 2 + 8);
        final pasFil = places == 1 ? 20.0 : (cote + pas) / 2;
        final grains = math.max(1, ((fin - debut) / pasFil).ceil());
        final points = [
          for (var i = 0; i <= grains; i++)
            Offset(
              debut + (fin - debut) * i / grains,
              y(debut + (fin - debut) * i / grains),
            ),
        ];

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le fond doux de la table.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7EEDC), Palette.creme],
                  ),
                ),
              ),
            ),
            // Le fil, sous les perles.
            for (var i = 0; i < points.length - 1; i++)
              _SegmentFil(debut: points[i], fin: points[i + 1], epaisseur: 4),
            // Les perles enfilées.
            for (var i = 0; i < perles.length; i++)
              Positioned(
                left: x(i) - cote / 2,
                top: y(x(i)) - cote / 2,
                child: _Perle(
                  key: clePerle(i),
                  couleur: couleurDe(perles[i]),
                  cote: cote,
                ),
              ),
            // La place suivante : en pointillé, avec sa question discrète.
            Positioned(
              left: x(perles.length) - cote / 2,
              top: y(x(perles.length)) - cote / 2,
              child: _PlaceLibre(key: clePlaceSuivante, cote: cote),
            ),
          ],
        );
      },
    );
  }
}

/// Un morceau du fil : une petite barre qui relie deux points de sa courbe.
class _SegmentFil extends StatelessWidget {
  final Offset debut;
  final Offset fin;
  final double epaisseur;

  const _SegmentFil({
    required this.debut,
    required this.fin,
    required this.epaisseur,
  });

  @override
  Widget build(BuildContext context) {
    final delta = fin - debut;
    final longueur = delta.distance;
    final milieu = (debut + fin) / 2;
    return Positioned(
      left: milieu.dx - longueur / 2,
      top: milieu.dy - epaisseur / 2,
      width: longueur,
      height: epaisseur,
      child: Transform.rotate(
        angle: math.atan2(delta.dy, delta.dx),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.encreDouce.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(epaisseur / 2),
          ),
        ),
      ),
    );
  }
}

/// Une perle enfilée : un rond coloré, son bord plus foncé et un reflet.
class _Perle extends StatelessWidget {
  final Color couleur;
  final double cote;

  const _Perle({super.key, required this.couleur, required this.cote});

  @override
  Widget build(BuildContext context) {
    final bord = Color.lerp(couleur, Palette.encre, 0.30)!;
    return Container(
      width: cote,
      height: cote,
      decoration: BoxDecoration(
        color: couleur,
        shape: BoxShape.circle,
        border: Border.all(color: bord, width: math.max(2, cote * 0.07)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.35, -0.35),
        child: Container(
          width: cote * 0.24,
          height: cote * 0.24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// La place suivante du fil : un cercle de points avec un « ? » discret —
/// c'est là que la réponse ira.
class _PlaceLibre extends StatelessWidget {
  final double cote;

  const _PlaceLibre({super.key, required this.cote});

  /// Le nombre de points du cercle.
  static const _grains = 10;

  @override
  Widget build(BuildContext context) {
    final rayon = cote / 2 - 3;
    final grain = math.min(5.0, cote * 0.18);
    return SizedBox(
      width: cote,
      height: cote,
      child: Stack(
        children: [
          for (var i = 0; i < _grains; i++)
            Positioned(
              left:
                  cote / 2 +
                  rayon * math.cos(2 * math.pi * i / _grains) -
                  grain / 2,
              top:
                  cote / 2 +
                  rayon * math.sin(2 * math.pi * i / _grains) -
                  grain / 2,
              child: Container(
                width: grain,
                height: grain,
                decoration: BoxDecoration(
                  color: Palette.encreDouce.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Center(
            child: Text(
              '?',
              style: TextStyle(
                fontSize: cote * 0.44,
                fontWeight: FontWeight.w700,
                color: Palette.encreDouce.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Décor « eau » ───────────────────────────

/// Le bac d'eau (les tests s'y accrochent).
const cleBacEau = ValueKey('eau.bac');

/// Où l'objet se trouve dans le bac.
enum _PlaceEau {
  /// Suspendu au-dessus de la surface : « devine avant de vérifier ».
  auDessus,

  /// À la surface, à moitié dans l'eau.
  surface,

  /// Au fond du bac, sous l'eau.
  fond,
}

/// Le bac d'eau de « Flotte ou coule » : l'objet tombe, flotte ou coule.
///
/// Visuels : 'objet:pomme' (suspendu au-dessus du bac, comme s'il allait
/// tomber), 'flotte:pomme' (à la surface, à moitié immergé), 'coule:pomme'
/// (au fond, sous l'eau). Un nom inconnu laisse le bac tel quel ; au départ,
/// le bac est vide.
class _DecorEau extends StatefulWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : le bac se pose au-dessus.
  final double basReserve;

  const _DecorEau({required this.visuel, required this.basReserve});

  @override
  State<_DecorEau> createState() => _DecorEauEtat();
}

class _DecorEauEtat extends State<_DecorEau> {
  /// Les formes de visuel du décor, et la place qu'elles demandent.
  static const _formes = <String, _PlaceEau>{
    'objet:': _PlaceEau.auDessus,
    'flotte:': _PlaceEau.surface,
    'coule:': _PlaceEau.fond,
  };

  static const _couleurEau = Color(0xFF9CC9EC);
  static const _bordEau = Color(0xFF7FB4DE);

  /// L'objet dans le bac ('' : le bac seul) et sa place.
  String _concept = '';
  _PlaceEau _place = _PlaceEau.surface;

  /// Traduit un nom d'état visuel en (concept, place).
  /// null : nom inconnu de ce décor → le bac garde ce qu'il montre.
  (String, _PlaceEau)? visuelPour(String nom) {
    for (final forme in _formes.entries) {
      if (nom.startsWith(forme.key)) {
        return (nom.substring(forme.key.length), forme.value);
      }
    }
    return null;
  }

  /// L'objet reconnu prend la place de l'ancien ; null : on garde.
  void _appliquer((String, _PlaceEau)? objet) {
    if (objet == null) return;
    _concept = objet.$1;
    _place = objet.$2;
  }

  @override
  void initState() {
    super.initState();
    _appliquer(visuelPour(widget.visuel));
  }

  @override
  void didUpdateWidget(covariant _DecorEau ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) _appliquer(visuelPour(widget.visuel));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        final largeurBac = math.min(l * 0.88, 520.0);
        final hauteurBac = sol * 0.42;
        final gaucheBac = (l - largeurBac) / 2;
        final basBac = sol * 0.98;
        final hautBac = basBac - hauteurBac; // la surface de l'eau
        final objet = math.min(l * 0.28, hauteurBac * 0.55);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le fond doux de la pièce.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE7F5EC), Palette.creme],
                  ),
                ),
              ),
            ),
            // L'objet : suspendu au-dessus, à la surface, ou au fond.
            if (_concept.isNotEmpty)
              AnimatedPositioned(
                key: const ValueKey('eau.objet'),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                left: (l - objet) / 2,
                top: switch (_place) {
                  _PlaceEau.auDessus => hautBac - 20 - objet,
                  _PlaceEau.surface => hautBac - objet / 2,
                  _PlaceEau.fond => basBac - 12 - objet,
                },
                width: objet,
                height: objet,
                child: ImageConcept(concept: _concept, taille: objet),
              ),
            // L'eau, dessinée APRÈS l'objet : il est immergé dessous.
            Positioned(
              left: gaucheBac,
              top: hautBac,
              width: largeurBac,
              height: hauteurBac,
              child: Container(
                key: cleBacEau,
                decoration: BoxDecoration(
                  color: _couleurEau.withValues(alpha: 0.60),
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
                  border: Border.all(color: _bordEau, width: 5),
                ),
              ),
            ),
            // Les vagues, sur l'eau.
            for (var i = 0; i < 3; i++)
              Positioned(
                left: gaucheBac + largeurBac * (0.08 + i * 0.04),
                top: hautBac + hauteurBac * (0.10 + i * 0.13),
                child: _Vague(largeur: largeurBac * 0.46, hauteur: 10),
              ),
          ],
        );
      },
    );
  }
}

/// Une vague : un trait blanc courbe, en petits tirets.
class _Vague extends StatelessWidget {
  final double largeur;

  /// La hauteur de la vague (crête à creux).
  final double hauteur;

  const _Vague({required this.largeur, required this.hauteur});

  /// Une vague fait deux creux et deux crêtes.
  static const _periodes = 2;

  /// Le nombre de tirets par période.
  static const _tiretsParPeriode = 6;

  @override
  Widget build(BuildContext context) {
    const epaisseur = 4.0;
    final grains = _periodes * _tiretsParPeriode;
    final tiret = largeur / (_periodes * _tiretsParPeriode * 2);
    return SizedBox(
      width: largeur,
      height: hauteur + epaisseur,
      child: Stack(
        children: [
          for (var i = 0; i < grains; i++)
            Positioned(
              left: i * largeur / grains,
              top:
                  hauteur /
                  2 *
                  (1 - math.cos(2 * math.pi * _periodes * (i + 0.5) / grains)),
              child: Container(
                width: tiret,
                height: epaisseur,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(epaisseur / 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────── Décor « ombre » ──────────────────────────

/// La lampe (les tests s'y accrochent).
const cleLampe = ValueKey('ombre.lampe');

/// L'ombre portée sur le mur.
const cleOmbre = ValueKey('ombre.silhouette');

/// Où la lampe éclaire depuis.
enum _PlaceLampe { gauche, haut, droite }

/// Le mur, la lampe et l'ombre de « Les ombres ».
///
/// Visuels : 'lampe_gauche:ballon', 'lampe_haut:ballon',
/// 'lampe_droite:ballon' — la place de la lampe décide de celle de l'ombre :
/// grande et décalée à l'opposé, ou courte et juste sous l'objet.
/// Un nom inconnu laisse la scène telle quelle ; au départ, la lampe seule.
class _DecorOmbre extends StatefulWidget {
  final String visuel;

  /// La hauteur de la bande des cartes : le mur s'arrête au-dessus.
  final double basReserve;

  const _DecorOmbre({required this.visuel, required this.basReserve});

  @override
  State<_DecorOmbre> createState() => _DecorOmbreEtat();
}

class _DecorOmbreEtat extends State<_DecorOmbre> {
  static const _prefixe = 'lampe_';

  /// La taille de la lampe, et le gris de l'ombre portée.
  static const _coteLampe = 54.0;
  static const _grisOmbre = Color(0xFF9A8F7D);

  _PlaceLampe _lampe = _PlaceLampe.haut;
  String _concept = '';

  /// Traduit un nom d'état visuel en (place de la lampe, objet éclairé).
  /// null : nom inconnu de ce décor → la scène garde sa lampe et son objet.
  (_PlaceLampe, String)? visuelPour(String nom) {
    if (!nom.startsWith(_prefixe)) return null;
    final reste = nom.substring(_prefixe.length);
    final coupure = reste.indexOf(':');
    if (coupure < 0) return null;
    final place = switch (reste.substring(0, coupure)) {
      'gauche' => _PlaceLampe.gauche,
      'droite' => _PlaceLampe.droite,
      'haut' => _PlaceLampe.haut,
      _ => null,
    };
    if (place == null) return null;
    return (place, reste.substring(coupure + 1));
  }

  /// La scène reconnue prend la place de l'ancienne ; null : on garde.
  void _appliquer((_PlaceLampe, String)? scene) {
    if (scene == null) return;
    _lampe = scene.$1;
    _concept = scene.$2;
  }

  @override
  void initState() {
    super.initState();
    _appliquer(visuelPour(widget.visuel));
  }

  @override
  void didUpdateWidget(covariant _DecorOmbre ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) _appliquer(visuelPour(widget.visuel));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final l = contraintes.maxWidth.isFinite ? contraintes.maxWidth : 400.0;
        final h = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 600.0;
        final sol = (h - widget.basReserve).clamp(80.0, h);
        final objet = math.min(l * 0.26, sol * 0.30);
        final hautObjet = sol * 0.34;
        final centre = l / 2;
        // L'objet se décale un peu à l'opposé de la lampe : les deux tiennent
        // dans l'écran, même quand l'ombre s'allonge.
        final decalage = switch (_lampe) {
          _PlaceLampe.gauche => -objet * 0.20,
          _PlaceLampe.droite => objet * 0.20,
          _PlaceLampe.haut => 0.0,
        };
        final gaucheObjet = centre - objet / 2 + decalage;
        final (gaucheLampe, hautLampe) = switch (_lampe) {
          _PlaceLampe.gauche => (l * 0.07, sol * 0.10),
          _PlaceLampe.haut => (centre - _coteLampe / 2, sol * 0.04),
          _PlaceLampe.droite => (l * 0.93 - _coteLampe, sol * 0.10),
        };
        // L'ombre : grande et décalée à l'opposé de la lampe, ou courte et
        // juste sous l'objet quand la lampe est au-dessus.
        final (largeurOmbre, hauteurOmbre) = switch (_lampe) {
          _PlaceLampe.haut => (objet * 1.02, objet * 0.44),
          _ => (objet * 1.20, objet * 1.02),
        };
        final (dxOmbre, dyOmbre) = switch (_lampe) {
          _PlaceLampe.gauche => (objet * 0.95, objet * 0.16),
          _PlaceLampe.droite => (-objet * 0.95, objet * 0.16),
          _PlaceLampe.haut => (0.0, objet * 0.60),
        };
        final angleOmbre = switch (_lampe) {
          _PlaceLampe.gauche => 0.14,
          _PlaceLampe.droite => -0.14,
          _PlaceLampe.haut => 0.0,
        };
        final centreObjet = Offset(
          gaucheObjet + objet / 2,
          hautObjet + objet / 2,
        );

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Le mur clair.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFBF5E7), Palette.creme],
                  ),
                ),
              ),
            ),
            // L'ombre portée, derrière l'objet.
            if (_concept.isNotEmpty)
              AnimatedPositioned(
                key: const ValueKey('ombre.place_ombre'),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                left: centreObjet.dx + dxOmbre - largeurOmbre / 2,
                top: centreObjet.dy + dyOmbre - hauteurOmbre / 2,
                width: largeurOmbre,
                height: hauteurOmbre,
                child: Transform.rotate(
                  angle: angleOmbre,
                  child: Container(
                    key: cleOmbre,
                    decoration: BoxDecoration(
                      color: _grisOmbre.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(largeurOmbre / 2, hauteurOmbre / 2),
                      ),
                    ),
                  ),
                ),
              ),
            // L'objet, sur le mur.
            if (_concept.isNotEmpty)
              AnimatedPositioned(
                key: const ValueKey('ombre.place_objet'),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                left: gaucheObjet,
                top: hautObjet,
                width: objet,
                height: objet,
                child: ImageConcept(concept: _concept, taille: objet),
              ),
            // La lampe, qui glisse d'une place à l'autre.
            AnimatedPositioned(
              key: const ValueKey('ombre.place_lampe'),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              left: gaucheLampe,
              top: hautLampe,
              width: _coteLampe,
              height: _coteLampe,
              child: const _Lampe(key: cleLampe, taille: _coteLampe),
            ),
          ],
        );
      },
    );
  }
}

/// La lampe : un rond jaune et quatre courts rayons.
class _Lampe extends StatelessWidget {
  final double taille;

  const _Lampe({super.key, required this.taille});

  /// Le nombre de rayons autour du rond.
  static const _rayons = 4;

  @override
  Widget build(BuildContext context) {
    final boule = taille * 0.56;
    return SizedBox(
      width: taille,
      height: taille,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Les rayons, courts, tout autour.
          for (var i = 0; i < _rayons; i++)
            Transform.rotate(
              angle: i * math.pi / 2 + math.pi / 4,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: taille * 0.07,
                  height: taille * 0.20,
                  decoration: BoxDecoration(
                    color: Palette.soleil,
                    borderRadius: BorderRadius.circular(taille * 0.04),
                  ),
                ),
              ),
            ),
          // Le rond jaune, au centre.
          Container(
            width: boule,
            height: boule,
            decoration: const BoxDecoration(
              color: Palette.soleil,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x55F6C445), blurRadius: 18)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Le décor « fenêtre » (Regarde par la fenêtre) : une fenêtre à carreaux
/// ouverte sur le temps qu'il fait. Le visuel porte le temps —
/// `temps_soleil`, `temps_pluie`, `temps_neige`, `temps_vent`, `temps_nuage`.
///
/// L'app ne prétend JAMAIS connaître la météo dehors : la fenêtre dessine
/// le temps que la manche a choisi, et c'est l'enfant qui le nomme.
class _DecorFenetre extends StatefulWidget {
  final String visuel;
  final double basReserve;

  const _DecorFenetre({required this.visuel, required this.basReserve});

  @override
  State<_DecorFenetre> createState() => _DecorFenetreEtat();
}

class _DecorFenetreEtat extends State<_DecorFenetre> {
  static const tempsConnus = {
    'temps_soleil',
    'temps_pluie',
    'temps_neige',
    'temps_vent',
    'temps_nuage',
  };

  String _temps = 'temps_soleil';

  @override
  void initState() {
    super.initState();
    _appliquer();
  }

  @override
  void didUpdateWidget(covariant _DecorFenetre ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.visuel != widget.visuel) _appliquer();
  }

  /// Un nom inconnu (comme `reponse_ok`) garde le temps affiché.
  void _appliquer() {
    if (tempsConnus.contains(widget.visuel)) _temps = widget.visuel;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final dispo = contraintes.maxHeight - widget.basReserve;
        final cote =
            (contraintes.maxWidth * 0.78 < dispo * 0.82
                    ? contraintes.maxWidth * 0.78
                    : dispo * 0.82)
                .clamp(180.0, 420.0);
        return Center(
          child: SizedBox(
            width: cote,
            height: cote,
            child: Stack(
              children: [
                // Le ciel, derrière les carreaux.
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(cote * 0.08),
                    child: Container(
                      color: _temps == 'temps_neige'
                          ? const Color(0xFFD8E6F0)
                          : const Color(0xFFBEE0F7),
                      child: _ciel(cote),
                    ),
                  ),
                ),
                // La croisée des carreaux, par-dessus.
                Positioned.fill(child: CustomPaint(painter: _CroiseeFenetre())),
                // Le cadre.
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF9A7150),
                        width: cote * 0.045,
                      ),
                      borderRadius: BorderRadius.circular(cote * 0.08),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ciel(double cote) {
    return Stack(
      children: [
        if (_temps == 'temps_soleil')
          Align(
            alignment: const Alignment(-0.35, -0.4),
            child: Container(
              width: cote * 0.22,
              height: cote * 0.22,
              decoration: const BoxDecoration(
                color: Palette.soleil,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x66F6C445), blurRadius: 18),
                ],
              ),
            ),
          ),
        if (_temps == 'temps_pluie' || _temps == 'temps_neige')
          const Align(alignment: Alignment(-0.1, -0.45), child: _Nuage()),
        if (_temps == 'temps_vent')
          const Align(alignment: Alignment(-0.1, -0.45), child: _Nuage()),
        if (_temps == 'temps_nuage')
          const Align(alignment: Alignment(0, -0.1), child: _Nuage()),
        if (_temps == 'temps_pluie')
          Positioned.fill(child: CustomPaint(painter: _Gouttes())),
        if (_temps == 'temps_neige')
          Positioned.fill(child: CustomPaint(painter: _Flocons())),
        if (_temps == 'temps_vent')
          Positioned.fill(child: CustomPaint(painter: _Souffle())),
      ],
    );
  }
}

/// Un nuage doux (trois ronds blancs assemblés).
class _Nuage extends StatelessWidget {
  const _Nuage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 44,
      child: Stack(
        children: [
          for (final (dx, dy, d) in [
            (0.0, 16.0, 34.0),
            (22.0, 0.0, 44.0),
            (52.0, 12.0, 36.0),
          ])
            Positioned(
              left: dx,
              top: dy,
              child: Container(
                width: d,
                height: d,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F7FA),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Les gouttes de pluie, obliques.
class _Gouttes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()
      ..color = const Color(0xFF6FA8DC)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.12 + 0.12 * i);
      final y = size.height * 0.42;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 4, y + size.height * 0.14),
        peinture,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter ancien) => false;
}

/// Les flocons, ronds et calmes.
class _Flocons extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()..color = Colors.white;
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.12 + 0.12 * i);
      final y = size.height * (0.5 + 0.06 * (i % 3));
      canvas.drawCircle(Offset(x, y), 5, peinture);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter ancien) => false;
}

/// Les traits de vent, trois souffles courbes.
class _Souffle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()
      ..color = const Color(0xFF8FB6D9)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.5 + 0.12 * i);
      final chemin = Path()
        ..moveTo(size.width * 0.12, y)
        ..quadraticBezierTo(size.width * 0.4, y - 10, size.width * 0.62, y)
        ..quadraticBezierTo(size.width * 0.78, y + 8, size.width * 0.88, y - 4);
      canvas.drawPath(chemin, peinture);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter ancien) => false;
}

/// La croisée des carreaux (une barre verticale et une horizontale).
class _CroiseeFenetre extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()
      ..color = const Color(0xFF9A7150)
      ..strokeWidth = size.width * 0.035;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      peinture,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      peinture,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter ancien) => false;
}
