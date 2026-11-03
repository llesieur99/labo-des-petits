import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/image_concept.dart';
import '../rappels_moteur.dart';

// ──────────────────────────── le vocabulaire ────────────────────────────

/// Les trois blocs du programme — les seuls mots que l'enfant apprend ici,
/// et il ne les lit pas : il les touche (une flèche, un quart de tour, une
/// main qui ramasse).
enum BlocCode {
  /// Avancer d'une case, tout droit dans le sens où l'animal regarde.
  avancer,

  /// Un quart de tour vers la droite : droite → bas → gauche → haut.
  tourner,

  /// Ramasser l'objet — mais seulement si l'animal est dessus.
  ramasser,
}

/// Le sens de l'animal (il regarde et avance de ce côté).
///
/// L'ORDRE EST CELUI DU QUART DE TOUR : droite → bas → gauche → haut.
/// [SensAnimal.suivant] fait donc toujours tourner vers la droite (le sens
/// des aiguilles d'une horloge, l'axe y pointant vers le bas). L'animal
/// commence chaque manche — et chaque exécution — tourné vers la DROITE.
enum SensAnimal {
  droite(1, 0),
  bas(0, 1),
  gauche(-1, 0),
  haut(0, -1);

  const SensAnimal(this.dx, this.dy);

  /// Le pas d'une case dans ce sens (x = colonne, y = ligne).
  final int dx;
  final int dy;

  /// Le quart de tour vers la droite.
  SensAnimal get suivant =>
      SensAnimal.values[(index + 1) % SensAnimal.values.length];

  /// La rotation de l'indicateur d'orientation, en tours complets
  /// (0 = droite, 0,25 = bas…) pour AnimatedRotation.
  double get quarts => index / SensAnimal.values.length;
}

// ─────────────────────────────── le moteur ───────────────────────────────

/// Moteur M5 « mode exécuter » : le code de trois blocs.
///
/// L'enfant pose des blocs — avancer, tourner, ramasser — puis touche GO et
/// regarde l'animal suivre son programme case par case, à 500 ms par bloc.
/// C'est de la programmation sans mot : on pose, on regarde, on corrige.
/// Pour les 6-7 ans.
///
/// Rien n'est jamais perdu : un programme qui rate est CONSERVÉ, l'enfant le
/// corrige et rejoue ; l'animal revient à sa case de départ entre deux essais.
/// Un programme qui sort de la grille s'arrête net — l'animal butte — et le
/// reste ne s'exécute pas.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine, écoute les doigts,
/// exécute le programme et raconte ce qui vient de se passer à son hôte
/// ([RappelsMoteur]) — c'est l'hôte qui encourage et qui avance.
class MoteurCodeBlocs extends StatefulWidget {
  /// La manche à jouer ; `manche.donnees` est un [DonneesCode].
  final Manche manche;

  /// Le lexique du deck actif (illustrations de l'animal et de l'objet).
  final Lexique lexique;

  /// Ce que le moteur raconte à son hôte (réussite, essai raté, clips).
  final RappelsMoteur rappels;

  const MoteurCodeBlocs({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
  });

  @override
  MoteurCodeBlocsEtat createState() => MoteurCodeBlocsEtat();
}

/// L'état du moteur (public pour que les tests puissent lire le programme).
class MoteurCodeBlocsEtat extends State<MoteurCodeBlocs> {
  // ── les durées du jeu (les tests pompent exactement celles-ci) ──
  /// Le temps d'un bloc : 500 ms — assez lent pour que l'enfant suive.
  static const delaiBloc = Duration(milliseconds: 500);

  /// Le glissement de l'animal d'une case à l'autre.
  static const dureeGlissement = Duration(milliseconds: 400);

  /// La pause après le dernier bloc, avant le verdict : le temps de voir.
  static const pauseFinale = Duration(milliseconds: 350);

  /// Le clip dit quand l'animal a ramassé son objet.
  static const clipBravo = 'code.bravo';

  // ── les mesures (jamais moins de 80 pt pour ce qui se touche) ──
  static const _pasGrille = 8.0; // l'espace entre deux cases
  static const _margeEcran = 16.0; // l'air autour de la grille
  static const _coteCaseMin = 40.0;
  static const _coteCaseMax = 150.0;
  static const _tailleAnimal = 46.0;
  static const _coteEmplacement = 80.0; // une case du programme
  static const _cotePastille = 80.0; // un bloc, et le GO
  static const _hauteurBarre = 104.0; // 80 + l'air (12 en haut et en bas)
  static const _plafondEmplacements = 6; // au-delà, la rangée ne tient plus
  static const _plafondTaille = 8; // une grille plus grande ne tient plus

  // ── les données de la manche, assainies une fois pour toutes ──
  /// Les données de la manche, ou null : écran calme (données absentes,
  /// d'un autre type, ou incohérentes — jamais une exception).
  DonneesCode? _donnees;
  int _taille = 0;
  int _departX = 0;
  int _departY = 0;
  int _objectifX = 0;
  int _objectifY = 0;
  int _maxBlocs = 3;

  // ── le programme et l'animal ──
  /// Le programme posé, du premier au dernier bloc.
  final List<BlocCode> _programme = <BlocCode>[];

  /// Où est l'animal (0,0 = en haut à gauche).
  int _x = 0;
  int _y = 0;

  /// Où il regarde — il commence toujours tourné vers la droite.
  SensAnimal _sens = SensAnimal.droite;

  /// Vrai pendant l'exécution : tout est inerte, les blocs ne répondent plus.
  bool _enExecution = false;
  int? _blocActif;

  /// Vrai quand la manche est gagnée : on n'y touche plus.
  bool _reussi = false;

  /// Vrai quand l'objet a été ramassé (il s'envole dans un petit « pop »).
  bool _ramasse = false;

  /// Change à chaque butée : l'animal se balance doucement.
  int _balancementTick = 0;

  /// Le numéro de la course en cours : une manche neuve ou un nouveau départ
  /// l'incrémente, et tout ce qui était en vol s'arrête là.
  int _course = 0;

  // ── ce que les tests lisent ──
  /// Le programme posé, du premier au dernier bloc (lecture seule).
  List<BlocCode> get programme => List.unmodifiable(_programme);

  /// Vrai pendant l'exécution (tout est inerte).
  bool get enExecution => _enExecution;

  /// Vrai quand la manche est gagnée.
  bool get reussi => _reussi;

  @override
  void initState() {
    super.initState();
    _reinitialiser();
  }

  @override
  void didUpdateWidget(covariant MoteurCodeBlocs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte peut réutiliser le même moteur pour la manche suivante (l'élément
    // survit) : tout repart de zéro. Une exécution en vol s'arrête d'elle-même
    // (elle vérifie son numéro de course après chaque attente).
    if (oldWidget.manche != widget.manche) _reinitialiser();
  }

  /// Tout remettre à neuf : les données lues et assainies, le programme vidé,
  /// l'animal à sa case de départ, tourné vers la droite.
  void _reinitialiser() {
    _course++;
    _lireLesDonnees();
    _programme.clear();
    _blocActif = null;
    _sens = SensAnimal.droite;
    _enExecution = false;
    _reussi = false;
    _ramasse = false;
    _balancementTick = 0;
  }

  /// Lit les données de la manche en les assainissant : une donnée absente,
  /// mal typée ou folle ne doit JAMAIS lever — au pire, l'écran reste calme.
  void _lireLesDonnees() {
    final brut = widget.manche.donnees;
    final donnees = brut is DonneesCode ? brut : null;
    _x = 0;
    _y = 0;
    if (donnees == null || donnees.taille < 1) {
      _donnees = null;
      _taille = 0;
      _maxBlocs = 3;
      _departX = 0;
      _departY = 0;
      _objectifX = 0;
      _objectifY = 0;
      return;
    }
    _donnees = donnees;
    _taille = donnees.taille.clamp(1, _plafondTaille);
    _departX = donnees.departX.clamp(0, _taille - 1);
    _departY = donnees.departY.clamp(0, _taille - 1);
    _objectifX = donnees.objectifX.clamp(0, _taille - 1);
    _objectifY = donnees.objectifY.clamp(0, _taille - 1);
    _maxBlocs = donnees.maxBlocs.clamp(1, _plafondEmplacements);
    _x = _departX;
    _y = _departY;
  }

  // ─────────────────────────── les doigts ───────────────────────────

  /// Poser un bloc à la fin du programme — jamais pendant l'exécution, jamais
  /// après la victoire, et jamais un bloc de plus que [DonneesCode.maxBlocs].
  void _poser(BlocCode bloc) {
    if (_enExecution || _reussi) return;
    if (_programme.length >= _maxBlocs) return;
    setState(() => _programme.add(bloc));
  }

  /// Retirer un bloc conserve les suivants : une correction ne force pas
  /// à effacer tout le programme pour atteindre une erreur au début.
  void _retirer(int index) {
    if (_enExecution || _reussi || _programme.isEmpty) return;
    if (index < 0 || index >= _programme.length) return;
    setState(() => _programme.removeAt(index));
  }

  // ────────────────────────── l'exécution ──────────────────────────

  /// La case juste devant l'animal, dans son sens.
  (int, int) get _caseDevant => (_x + _sens.dx, _y + _sens.dy);

  /// GO : l'animal rejoue le programme depuis le début, bloc par bloc.
  ///
  /// Chaque bloc prend 500 ms (le glissement dure 400 ms et se termine dans
  /// la foulée). Une butée arrête tout : le reste du programme ne s'exécute
  /// pas. Puis on annonce le verdict à l'hôte — jamais un reproche.
  Future<void> _lancer() async {
    final donnees = _donnees;
    if (donnees == null || _enExecution || _reussi) return;
    if (_programme.isEmpty) return;

    final course = ++_course;
    final programme = List<BlocCode>.of(_programme);
    setState(() {
      _enExecution = true;
      // L'animal repart de sa case de départ, tourné vers la droite :
      // deux fois le même programme donnent deux fois la même chose.
      _x = _departX;
      _y = _departY;
      _sens = SensAnimal.droite;
      _ramasse = false;
    });

    var butte = false;
    for (var i = 0; i < programme.length; i++) {
      if (!mounted || _course != course) return;
      final bloc = programme[i];
      setState(() => _blocActif = i);
      switch (bloc) {
        case BlocCode.avancer:
          final (devantX, devantY) = _caseDevant;
          if (!_dansLaGrille(devantX, devantY)) {
            // Il n'y a pas de case : l'animal butte. Rien ne bouge, il se
            // balance un peu, et le reste du programme attendra.
            butte = true;
            setState(() => _balancementTick++);
          } else {
            setState(() {
              _x = devantX;
              _y = devantY;
            });
          }
        case BlocCode.tourner:
          setState(() => _sens = _sens.suivant);
        case BlocCode.ramasser:
          // On ne ramasse que ce qui est sous ses pattes.
          if (donnees.ramassable != null &&
              _x == _objectifX &&
              _y == _objectifY) {
            setState(() => _ramasse = true);
          }
      }
      await attendreMoteur(widget.rappels, delaiBloc);
      if (butte) break;
    }

    if (!mounted || _course != course) return;
    setState(() => _blocActif = null);
    await attendreMoteur(widget.rappels, pauseFinale);
    if (!mounted || _course != course) return;
    await _verdict(course);
  }

  /// Le programme est fini (ou s'est arrêté) : on regarde où en est l'animal.
  ///
  /// * à ramasser : réussi quand l'objet est ramassé ;
  /// * sans objet : réussi quand l'animal termine sur la case objectif.
  ///
  /// Gagné : l'animal est félicité ([clipBravo]), puis l'hôte annonce la
  /// réussite. Raté, doucement : l'hôte encourage, le programme est CONSERVÉ
  /// et l'animal rentre à sa case de départ — l'enfant corrige et rejoue.
  Future<void> _verdict(int course) async {
    final gagne = _donnees?.ramassable != null
        ? _ramasse
        : (_x == _objectifX && _y == _objectifY);

    if (gagne) {
      setState(() {
        _enExecution = false;
        _reussi = true;
      });
      await widget.rappels.dire(clipBravo);
      if (!mounted || _course != course) return;
      widget.rappels.itemReussi();
      return;
    }

    setState(() {
      _enExecution = false;
      _x = _departX;
      _y = _departY;
      _sens = SensAnimal.droite;
      _ramasse = false;
    });
    widget.rappels.essaiRate();
  }

  bool _dansLaGrille(int x, int y) =>
      x >= 0 && y >= 0 && x < _taille && y < _taille;

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
        if (largeur >= 600 && largeur > hauteur * 1.4) {
          final largeurGrille = math.min(hauteur, largeur * 0.42);
          return Row(
            children: [
              SizedBox(
                width: largeurGrille,
                child: Center(
                  child: _grille(
                    _coteDesCases(largeur: largeurGrille, hauteur: hauteur),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, commandes) {
                    final largeurCommandes = commandes.maxWidth;
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          _rangeeProgramme(largeurCommandes),
                          _barreDeBlocs(
                            largeurCommandes < 356 ? 196 : _hauteurBarre,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }
        final hauteurProgramme = _mesureProgramme(largeur);
        final hauteurBarre = largeur < 356 ? 196.0 : _hauteurBarre;
        final hauteurContenu = math.max(
          hauteur,
          _taille * (_coteCaseMin + _pasGrille) -
              _pasGrille +
              hauteurProgramme +
              hauteurBarre,
        );
        final cote = _coteDesCases(
          largeur: largeur - _margeEcran * 2,
          hauteur: hauteurContenu - hauteurProgramme - hauteurBarre,
        );

        return SingleChildScrollView(
          child: SizedBox(
            height: hauteurContenu,
            child: Column(
              children: [
                Expanded(child: Center(child: _grille(cote))),
                _rangeeProgramme(largeur),
                _barreDeBlocs(hauteurBarre),
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

  /// Le côté d'une case : il tient dans la largeur et la hauteur qu'on lui
  /// laisse, sans jamais devenir minuscule ni énorme.
  double _coteDesCases({required double largeur, required double hauteur}) {
    final espaces = _pasGrille * (_taille - 1);
    final parLargeur = (largeur - espaces) / _taille;
    final parHauteur = (hauteur - espaces) / _taille;
    final cote = parLargeur < parHauteur ? parLargeur : parHauteur;
    return cote.clamp(_coteCaseMin, _coteCaseMax);
  }

  /// La grille : les cases, ce qu'il y a sur la case objectif, et l'animal
  /// par-dessus — il glisse d'une case à l'autre en 400 ms.
  Widget _grille(double cote) {
    final pas = cote + _pasGrille;
    final coteGrille = pas * _taille - _pasGrille;

    return SizedBox(
      width: coteGrille,
      height: coteGrille,
      child: Stack(
        key: const ValueKey('code.grille'),
        clipBehavior: Clip.none,
        children: [
          for (var ligne = 0; ligne < _taille; ligne++)
            for (var colonne = 0; colonne < _taille; colonne++)
              Positioned(
                left: colonne * pas,
                top: ligne * pas,
                width: cote,
                height: cote,
                child: _Case(
                  cote: cote,
                  objectif: colonne == _objectifX && ligne == _objectifY,
                ),
              ),
          Positioned(
            left: _objectifX * pas,
            top: _objectifY * pas,
            width: cote,
            height: cote,
            child: Center(child: _contenuObjectif(cote)),
          ),
          AnimatedPositioned(
            duration: dureeGlissement,
            curve: Curves.easeOutCubic,
            left: _x * pas,
            top: _y * pas,
            width: cote,
            height: cote,
            child: _Balancement(tick: _balancementTick, child: _animal(cote)),
          ),
        ],
      ),
    );
  }

  /// L'animal, et le petit triangle qui dit où il regarde — toujours DEVANT
  /// lui, et il pivote d'un quart de tour quand le programme tourne.
  Widget _animal(double cote) {
    final animal = _donnees?.animal ?? '';
    final tailleAnimal = math.min(_tailleAnimal, cote * 0.62);

    return Stack(
      key: const ValueKey('code.animal'),
      alignment: Alignment.center,
      children: [
        // La clé suit le concept : une manche neuve change d'animal, et
        // l'illustration neuve se charge (le cache d'ImageConcept par nom).
        ImageConcept(
          key: ValueKey('code.animal.$animal'),
          concept: animal,
          fichier: widget.lexique[animal]?.illustrationPour(animal) ?? '',
          taille: tailleAnimal,
        ),
        AnimatedRotation(
          key: const ValueKey('code.fleche'),
          turns: _sens.quarts,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          // Le triangle est posé au bord droit d'un carré centré sur
          // l'animal : en tournant d'un quart de tour, il passe au bord du
          // bas, puis de la gauche, puis du haut — toujours devant.
          child: SizedBox(
            width: cote * 0.82,
            height: cote * 0.82,
            child: Align(
              alignment: Alignment.centerRight,
              child: _FlecheOrientation(
                taille: math.min(18.0, cote * 0.22),
                couleur: Palette.corail,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sur la case objectif : l'objet à ramasser (il pulse doucement), ou une
  /// étoile quand il suffit d'arriver.
  Widget _contenuObjectif(double cote) {
    final ramassable = _donnees?.ramassable;
    if (ramassable == null || ramassable.isEmpty) {
      return Icon(
        Icons.star,
        key: const ValueKey('code.etoile'),
        color: Palette.soleil,
        size: cote * 0.46,
      );
    }
    return _ObjetQuiPulse(
      ramasse: _ramasse,
      child: KeyedSubtree(
        // La clé de l'objet (les tests la cherchent ; elle disparaît avec lui).
        key: const ValueKey('code.objet'),
        // La clé interne suit le concept : l'illustration neuve se charge.
        child: ImageConcept(
          key: ValueKey('code.illustration.$ramassable'),
          concept: ramassable,
          fichier:
              widget.lexique[ramassable]?.illustrationPour(ramassable) ?? '',
          taille: math.min(_tailleAnimal, cote * 0.62),
        ),
      ),
    );
  }

  double _mesureProgramme(double largeur) {
    final colonnes = ((largeur + 8) / (_coteEmplacement + 8)).floor().clamp(
      1,
      _maxBlocs,
    );
    final lignes = (_maxBlocs / colonnes).ceil();
    return math.max(100, lignes * _coteEmplacement + (lignes - 1) * 8);
  }

  /// Tous les blocs restent visibles, sur plusieurs rangées au besoin.
  Widget _rangeeProgramme(double largeur) {
    return SizedBox(
      height: _mesureProgramme(largeur),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (var i = 0; i < _maxBlocs; i++) _emplacement(i)],
        ),
      ),
    );
  }

  /// Un emplacement du programme : pointillé tant qu'il est vide, puis le
  /// bloc posé. Toucher un bloc le retire et rapproche les suivants.
  Widget _emplacement(int i) {
    final bloc = i < _programme.length ? _programme[i] : null;
    final peutRetirer = bloc != null && !_enExecution && !_reussi;

    return CibleTactile(
      key: ValueKey('code.emplacement.$i'),
      onTap: peutRetirer ? () => _retirer(i) : null,
      semantique: bloc == null ? null : _nomDuBloc(bloc),
      child: SizedBox(
        width: _coteEmplacement,
        height: _coteEmplacement,
        child: bloc == null
            ? CustomPaint(
                painter: _Pointilles(
                  active: i == _programme.length && !_enExecution,
                ),
                child: Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Palette.cremeFonce,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              )
            : DecoratedBox(
                key: _enExecution && _blocActif == i
                    ? ValueKey('code.actif.$i')
                    : null,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    width: 4,
                    color: _enExecution && _blocActif == i
                        ? Palette.verdure
                        : Colors.transparent,
                  ),
                ),
                child: _BlocPose(key: ValueKey('code.pose.$i'), bloc: bloc),
              ),
      ),
    );
  }

  /// La barre des trois blocs, et le GO tout au bout.
  Widget _barreDeBlocs(double hauteur) {
    return SizedBox(
      height: hauteur,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final bloc in BlocCode.values)
              SizedBox(
                width: _cotePastille,
                height: _cotePastille,
                child: _pastilleDeBloc(bloc),
              ),
            // Le GO garde sa place même caché : rien ne saute à l'écran.
            SizedBox(
              width: _cotePastille,
              height: _cotePastille,
              child: _boutonGo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastilleDeBloc(BlocCode bloc) {
    final actif = !_enExecution && !_reussi;
    final teinte = _teinteDuBloc(bloc);
    return CibleTactile(
      key: ValueKey('code.bloc.${_nomDuBloc(bloc)}'),
      onTap: actif ? () => _poser(bloc) : null,
      semantique: _nomDuBloc(bloc),
      child: Container(
        width: _cotePastille,
        height: _cotePastille,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: teinte.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: teinte, width: 4),
        ),
        child: Icon(_iconeDuBloc(bloc), size: 44, color: teinte),
      ),
    );
  }

  /// Le gros bouton vert : il n'apparaît que quand il y a un programme à
  /// jouer (et il dort pendant l'exécution).
  Widget _boutonGo() {
    if (_programme.isEmpty || _reussi) return const SizedBox.shrink();
    return CibleTactile(
      key: const ValueKey('code.go'),
      onTap: _enExecution ? null : _lancer,
      semantique: 'jouer',
      child: Container(
        width: _cotePastille,
        height: _cotePastille,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Palette.verdure,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow, size: 48, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────── les petites pièces ───────────────────────────

Color _teinteDuBloc(BlocCode bloc) => switch (bloc) {
  BlocCode.avancer => Palette.ciel,
  BlocCode.tourner => Palette.soleil,
  BlocCode.ramasser => Palette.verdure,
};

IconData _iconeDuBloc(BlocCode bloc) => switch (bloc) {
  // L'animal avance TOUT DROIT, peu importe son orientation visuelle :
  // la flèche du bloc dit « une case de plus », pas « vers le haut ».
  BlocCode.avancer => Icons.arrow_forward,
  BlocCode.tourner => Icons.rotate_right,
  BlocCode.ramasser => Icons.pan_tool,
};

String _nomDuBloc(BlocCode bloc) => switch (bloc) {
  BlocCode.avancer => 'avancer',
  BlocCode.tourner => 'tourner',
  BlocCode.ramasser => 'ramasser',
};

/// Une case de la grille : douce, blanche, coins très ronds. La case objectif
/// est légèrement dorée pour que l'enfant la repère d'un coup d'œil.
class _Case extends StatelessWidget {
  final double cote;
  final bool objectif;

  const _Case({required this.cote, required this.objectif});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: objectif
            ? Color.lerp(Colors.white, Palette.soleil, 0.22) ?? Colors.white
            : Colors.white,
        borderRadius: BorderRadius.circular(cote * 0.2),
        border: Border.all(color: Palette.cremeFonce, width: 3),
      ),
    );
  }
}

/// Le bloc posé dans un emplacement du programme : la même pastille que dans
/// la barre, en plus petit, et il arrive en grandissant doucement.
class _BlocPose extends StatelessWidget {
  final BlocCode bloc;

  const _BlocPose({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final teinte = _teinteDuBloc(bloc);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.72, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, avancement, enfant) =>
          Transform.scale(scale: avancement, child: enfant),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: teinte.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: teinte, width: 4),
        ),
        child: Center(child: Icon(_iconeDuBloc(bloc), size: 40, color: teinte)),
      ),
    );
  }
}

/// Le cadre pointillé des emplacements vides (Flutter n'a pas de bord
/// pointillé). Recopié du style des cases vides du M5.
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

/// Le petit triangle qui montre où l'animal regarde : il pointe vers la
/// droite, puis c'est la rotation qui le tourne.
class _FlecheOrientation extends StatelessWidget {
  final double taille;
  final Color couleur;

  const _FlecheOrientation({required this.taille, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(taille, taille), painter: _Triangle(couleur));
  }
}

class _Triangle extends CustomPainter {
  final Color couleur;

  const _Triangle(this.couleur);

  @override
  void paint(Canvas canvas, Size taille) {
    final pinceau = Paint()
      ..color = couleur
      ..style = PaintingStyle.fill;
    final chemin = Path()
      ..moveTo(0, 0)
      ..lineTo(taille.width, taille.height / 2)
      ..lineTo(0, taille.height)
      ..close();
    canvas.drawPath(chemin, pinceau);
  }

  @override
  bool shouldRepaint(covariant _Triangle ancien) => ancien.couleur != couleur;
}

/// L'objet à ramasser : il pulse doucement pour dire « viens me chercher »,
/// et il s'envole dans un petit « pop » quand l'animal le prend.
class _ObjetQuiPulse extends StatefulWidget {
  /// Vrai quand l'animal vient de le ramasser.
  final bool ramasse;

  final Widget child;

  const _ObjetQuiPulse({required this.ramasse, required this.child});

  @override
  State<_ObjetQuiPulse> createState() => _ObjetQuiPulseState();
}

class _ObjetQuiPulseState extends State<_ObjetQuiPulse>
    with TickerProviderStateMixin {
  /// Le pouls, en boucle : un aller-retour par seconde, très doux.
  late final AnimationController _pouls = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  /// Le « pop » de la cueillette : 300 ms, une seule fois.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// Vrai quand le pop est fini : l'objet n'est plus dessiné du tout.
  bool _envole = false;

  @override
  void initState() {
    super.initState();
    _pop.addStatusListener(_finDuPop);
    if (widget.ramasse) {
      _envole = true; // déjà ramassé : il n'y a plus rien à montrer
    } else {
      _pouls.repeat(reverse: true);
    }
  }

  void _finDuPop(AnimationStatus statut) {
    if (statut == AnimationStatus.completed && mounted) {
      setState(() => _envole = true);
    }
  }

  @override
  void didUpdateWidget(covariant _ObjetQuiPulse ancien) {
    super.didUpdateWidget(ancien);
    if (widget.ramasse && !ancien.ramasse) {
      _pouls.stop();
      _pop.forward(from: 0);
    } else if (!widget.ramasse && ancien.ramasse) {
      // Manche neuve après une manche gagnée : l'objet revient, et il pulse.
      _pop.reset();
      _envole = false;
      _pouls.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pop.removeStatusListener(_finDuPop);
    _pouls.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_envole) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_pouls, _pop]),
      child: widget.child,
      builder: (context, enfant) {
        final pouls = widget.ramasse ? 1.0 : 1 + 0.08 * _pouls.value;
        final pop = widget.ramasse ? 1 + 0.5 * _pop.value : 1.0;
        final opacite = widget.ramasse ? 1 - _pop.value : 1.0;
        return Opacity(
          opacity: opacite.clamp(0.0, 1.0),
          child: Transform.scale(scale: pouls * pop, child: enfant),
        );
      },
    );
  }
}

/// Un petit balancement doux quand l'animal butte contre le bord de la
/// grille. Il reste où il est : on n'enlève rien, on ne punit rien.
class _Balancement extends StatefulWidget {
  /// Change à chaque butée (0 = jamais butté).
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
