import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../micro/mic_kit.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/image_concept.dart';
import '../rappels_moteur.dart';

/// La couleur de la bouche de la bête : un corail soutenu, jamais un noir,
/// jamais un rouge qui fait peur.
const _corailBouche = Color(0xFFC2603F);
const _corailBoucheTrait = Color(0xFFA64C2E);

/// Moteur M7c : l'atelier — inventer un animal, lui donner un nom, le nourrir.
///
/// Trois temps, aucune faute possible :
///
///  1. **On assemble.** Les groupes s'ouvrent l'un après l'autre (« Choisis
///     une tête ! ») et chaque choix rejoint l'assemblage, du haut vers le
///     bas : la tête (petite), le corps (gros), la queue (petite). Les
///     morceaux se chevauchent un peu — une bête bricolée, forcément rigolote.
///     Une flèche permet de reprendre le dernier choix.
///  2. **On nomme.** L'app invite à nommer la bête. Si le micro est accordé
///     ([MoteurAtelier.micro] non nul ET permission déjà donnée), l'enfant
///     s'enregistre trois secondes, se réécoute, et l'enregistrement est
///     effacé aussitôt : rien ne reste, rien n'est jugé, rien ne part sur le
///     réseau. Sans micro — ou micro refusé, en panne — le gros bouton
///     « J'ai un nom ! » fait exactement la même chose, un cran plus loin.
///  3. **On nourrit.** « Qu'est-ce qu'il mange ? » — N'IMPORTE QUELLE
///     nourriture est la bonne : elle monte jusqu'à la bouche de la bête et
///     la manche est réussie.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine, écoute les doigts,
/// dit les clips qu'on lui donne et raconte ce qui vient de se passer à son
/// hôte ([RappelsMoteur]) — c'est l'hôte qui encourage et qui avance.
/// [RappelsMoteur.essaiRate] n'est JAMAIS appelé ici : dans l'atelier, rien
/// n'est une faute.
class MoteurAtelier extends StatefulWidget {
  /// La manche jouée : elle doit porter des [DonneesAtelier].
  final Manche manche;

  /// Le lexique du deck actif (texte et illustration des concepts).
  final Lexique lexique;

  /// Ce que l'atelier raconte à son hôte (clips, réussite).
  final RappelsMoteur rappels;

  /// Le micro (phase 2 seulement), optionnel : l'enfant se nomme à voix haute
  /// et se réécoute. L'enregistrement est ÉPHÉMÈRE — réécouté puis effacé
  /// aussitôt, jamais jugé, jamais conservé, jamais transmis.
  ///
  /// null (défaut) : l'atelier propose « J'ai un nom ! ». Aucun jeu n'exige le
  /// micro : refusé ou en panne, la manche se joue pareil.
  final Micro? micro;

  const MoteurAtelier({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
    this.micro,
  });

  // ── ce que les tests (et l'hôte) peuvent retrouver ──

  /// La zone de l'assemblage : la bête s'y construit, du haut vers le bas.
  static const ValueKey<String> cleAssemblage = ValueKey('atelier.assemblage');

  /// Un morceau posé dans l'assemblage (0 = la tête, 1 = le corps…).
  static ValueKey<String> cleElement(int index) =>
      ValueKey('atelier.element-$index');

  /// Une carte d'option de la phase 1.
  static ValueKey<String> cleOption(String concept) =>
      ValueKey('atelier.option.$concept');

  /// Une carte de nourriture de la phase 3.
  static ValueKey<String> cleNourriture(String concept) =>
      ValueKey('atelier.nourriture.$concept');

  /// La bouchée en vol, qui monte vers la bouche.
  static const ValueKey<String> cleEnvol = ValueKey('atelier.envol');

  /// Le bouton « Écoute-toi » (micro accordé).
  static const ValueKey<String> cleEcouteToi = ValueKey('atelier.ecouteToi');

  /// Le bouton « J'ai un nom ! » (sans micro).
  static const ValueKey<String> cleJaiUnNom = ValueKey('atelier.jaiUnNom');

  /// L'enregistrement du nom : trois secondes au plus, puis on efface.
  static const Duration dureeEnregistrement = Duration(seconds: 3);

  /// L'arrivée d'un morceau dans l'assemblage.
  static const Duration dureeArrivee = Duration(milliseconds: 250);

  /// L'envol d'une bouchée vers la bouche.
  static const Duration dureeBouchee = Duration(milliseconds: 400);

  /// De combien la bouchée monte (en hauteurs de carte).
  static const Offset envolBouchee = Offset(0, -2.4);

  /// Les tailles des morceaux empilés : la tête, le corps, la queue.
  static const List<double> tailles = [70, 110, 60];

  /// Le léger chevauchement entre deux morceaux posés.
  static const double chevauchement = -12;

  /// Le côté du gros bouton de la phase 2 (bien au-delà des 80 points).
  static const double tailleBoutonNom = 132;

  /// La taille de la bouche quand elle s'ouvre pour une bouchée.
  static const double largeurBouche = 58;

  @override
  State<MoteurAtelier> createState() => _MoteurAtelierEtat();
}

/// Ce que l'atelier fait en ce moment.
enum _Phase {
  /// Phase 1 : on assemble les morceaux, groupe après groupe.
  assemblage,

  /// Phase 2 : on donne un nom à la bête.
  nom,

  /// Phase 3 : « Qu'est-ce qu'il mange ? » — tout est accepté.
  question,
}

class _MoteurAtelierEtat extends State<MoteurAtelier> {
  _Phase _phase = _Phase.assemblage;

  /// Le groupe ouvert (index dans [_groupes]).
  int _groupe = 0;

  /// Les concepts choisis, DANS L'ORDRE : la tête, le corps, la queue.
  final List<String> _choisis = <String>[];

  /// Vrai quand le micro est là ET déjà accordé (vérifié à l'ouverture :
  /// on REGARDE la permission, on ne la demande jamais ici).
  bool _microPret = false;

  /// Vrai pendant l'enregistrement du nom (le bouton change d'icône).
  bool _enregistrementEnCours = false;

  /// La nourriture en vol vers la bouche (null : aucune).
  String? _bouchee;

  /// Vrai quand la manche est réussie : on ne l'annonce qu'une fois.
  bool _reussi = false;

  DonneesAtelier? get _donnees {
    final donnees = widget.manche.donnees;
    return donnees is DonneesAtelier ? donnees : null;
  }

  /// Les groupes à jouer — un groupe sans option ne se joue pas (il ne
  /// bloquerait l'enfant devant rien).
  List<GroupeAtelier> get _groupes {
    final donnees = _donnees;
    if (donnees == null) return const [];
    return [
      for (final groupe in donnees.groupes)
        if (groupe.options.isNotEmpty) groupe,
    ];
  }

  /// Le groupe ouvert, ou null quand il n'y a plus rien à assembler.
  GroupeAtelier? get _groupeCourant =>
      _groupe >= 0 && _groupe < _groupes.length ? _groupes[_groupe] : null;

  /// La taille d'un morceau posé : la tête, le corps, la queue.
  static double _tailleMorceau(int index) =>
      index < MoteurAtelier.tailles.length
      ? MoteurAtelier.tailles[index]
      : MoteurAtelier.tailles.last;

  @override
  void initState() {
    super.initState();
    // Aucun setState avant la première construction : l'atelier se pose
    // directement dans son état de départ.
    _recommencer();
    _enregistrerConsigne();
  }

  @override
  void didUpdateWidget(covariant MoteurAtelier ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.rappels != widget.rappels) {
      final rappels = ancien.rappels;
      if (rappels is ConsigneContextuelle) rappels.retirerConsigne(this);
      _enregistrerConsigne();
    }
    if (ancien.manche.id != widget.manche.id) {
      // Une autre manche : une autre bête, on repart de zéro.
      _recommencer();
    } else if (ancien.micro != widget.micro) {
      _microPret = false;
      _verifierMicro();
    }
  }

  void _enregistrerConsigne() {
    final rappels = widget.rappels;
    if (rappels is ConsigneContextuelle) {
      rappels.enregistrerConsigne(
        this,
        () => _dire(switch (_phase) {
          _Phase.assemblage => _groupeCourant?.libelleCle,
          _Phase.nom => _donnees?.inviterNomCle,
          _Phase.question => _donnees?.questionCle,
        }),
      );
    }
  }

  @override
  void dispose() {
    final rappels = widget.rappels;
    if (rappels is ConsigneContextuelle) rappels.retirerConsigne(this);
    super.dispose();
  }

  void _reprendreChoix() {
    if (_choisis.isEmpty || _enregistrementEnCours || _reussi) return;
    setState(() {
      _choisis.removeLast();
      _groupe = _choisis.length;
      _phase = _Phase.assemblage;
    });
    unawaited(_dire(_groupeCourant?.libelleCle));
  }

  /// Remet l'atelier à son état de départ (sans `setState`).
  void _recommencer() {
    _phase = _Phase.assemblage;
    _groupe = 0;
    _choisis.clear();
    _microPret = false;
    _enregistrementEnCours = false;
    _bouchee = null;
    _reussi = false;

    // Le premier groupe s'ouvre tout de suite — ou la phase du nom, s'il n'y
    // a rien à assembler : une manche sans groupe reste jouable.
    final premier = _groupeCourant;
    if (premier == null) {
      _phase = _Phase.nom;
      unawaited(_dire(_donnees?.inviterNomCle));
    } else {
      unawaited(_dire(premier.libelleCle));
    }

    if (widget.micro != null) unawaited(_verifierMicro());
  }

  /// Regarde si le micro est accordé — sans jamais ouvrir la boîte de l'OS
  /// (c'est l'affaire de l'espace parent, pas d'un jeu).
  Future<void> _verifierMicro() async {
    final micro = widget.micro;
    final manche = widget.manche;
    if (micro == null) return;
    var accorde = false;
    try {
      accorde = await micro.estAccorde();
    } catch (e) {
      debugPrint('Atelier : micro illisible ($e) — on joue sans.');
      accorde = false;
    }
    if (!mounted ||
        !identical(widget.micro, micro) ||
        !identical(widget.manche, manche)) {
      return;
    }
    setState(() => _microPret = accorde);
  }

  /// Dit un clip, sans jamais faire attendre l'enfant ni lever d'erreur.
  Future<void> _dire(String? cle) async {
    if (cle == null || cle.isEmpty) return;
    try {
      await widget.rappels.dire(cle);
    } catch (e) {
      debugPrint('Atelier : le clip « $cle » ne peut pas être dit ($e).');
    }
  }

  // ──────────────────────── phase 1 : on assemble ────────────────────────

  /// L'enfant touche une option : elle rejoint l'assemblage et le groupe
  /// suivant s'ouvre ; la flèche permet de reprendre ce choix.
  void _choisir(String concept) {
    if (_phase != _Phase.assemblage) return;
    final groupe = _groupeCourant;
    if (groupe == null || !groupe.options.contains(concept)) return;

    setState(() {
      _choisis.add(concept);
      _groupe++;
      if (_groupeCourant == null) _phase = _Phase.nom;
    });

    final suivant = _groupeCourant;
    if (suivant == null) {
      // Plus rien à assembler : on invite à nommer la bête.
      unawaited(_dire(_donnees?.inviterNomCle));
    } else {
      // Le groupe qui s'ouvre se présente tout de suite.
      unawaited(_dire(suivant.libelleCle));
    }
  }

  // ────────────────────────── phase 2 : le nom ──────────────────────────

  /// « Écoute-toi » : on enregistre l'enfant (3 s au plus), on lui rejoue, et
  /// on efface aussitôt. Rien n'est jugé, rien ne reste.
  Future<void> _ecouterSoi() async {
    final micro = widget.micro;
    if (micro == null || _phase != _Phase.nom || _enregistrementEnCours) return;

    final manche = widget.manche;
    bool courante() => mounted && identical(widget.manche, manche);
    setState(() => _enregistrementEnCours = true);
    try {
      final chemin = await micro.enregistrer(
        max: MoteurAtelier.dureeEnregistrement,
      );
      if (chemin != null && chemin.isNotEmpty) {
        try {
          if (!courante()) return;
          await micro.rejouer(chemin);
        } finally {
          // Même si l'écran est fermé ou si l'écoute échoue.
          await micro.effacer(chemin);
        }
      }
    } catch (e) {
      // Micro refusé, occupé ou en panne : l'enfant n'est JAMAIS bloqué.
      debugPrint('Atelier : enregistrement impossible ($e) — on continue.');
    }
    if (!courante()) return;
    setState(() => _enregistrementEnCours = false);
    await _nommer();
  }

  /// Le nom est donné (« J'ai un nom ! », ou la voix vient d'être écoutée) :
  /// on félicite, puis on demande ce que la bête mange.
  Future<void> _nommer() async {
    if (_phase != _Phase.nom) return;
    final manche = widget.manche;
    setState(() => _phase = _Phase.question);

    await _dire(_donnees?.felicitationNomCle);
    if (!mounted ||
        !identical(widget.manche, manche) ||
        _phase != _Phase.question) {
      return;
    }
    unawaited(_dire(_donnees?.questionCle));
  }

  // ──────────────────────── phase 3 : la bouchée ────────────────────────

  /// L'enfant touche une nourriture : elle monte vers la bouche, et la manche
  /// est réussie. N'importe laquelle fait l'affaire — c'est la bête de
  /// l'enfant, c'est son histoire. Aucun essai raté n'existe ici.
  void _gouter(String concept) {
    if (_phase != _Phase.question || _reussi) return;
    setState(() {
      _reussi = true;
      _bouchee = concept;
    });
    // Rien de plus à dire : la bouchée se raconte toute seule à l'écran.
    widget.rappels.itemReussi();
  }

  // ────────────────────────────── dessin ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    final donnees = _donnees;
    if (donnees == null) {
      // Une manche sans données M7c (ou mal typées) ne montre jamais
      // d'erreur à un enfant : on ne dessine rien.
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: Palette.creme,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _assemblage()),
                if (_choisis.isNotEmpty && !_enregistrementEnCours && !_reussi)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CibleTactile(
                        key: const ValueKey('atelier.annuler'),
                        onTap: _reprendreChoix,
                        semantique: 'Reprendre le dernier choix',
                        child: const Icon(
                          Icons.undo_rounded,
                          color: Palette.encreDouce,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          switch (_phase) {
            _Phase.assemblage => _barreOptions(),
            _Phase.nom => _barreNom(),
            _Phase.question => _barreNourritures(donnees),
          },
        ],
      ),
    );
  }

  /// La bête qui se construit : la bouche, puis les morceaux empilés du haut
  /// vers le bas, chacun un peu par-dessus le précédent.
  ///
  /// Le [FittedBox] est le garde-fou : sur un petit écran, la bête se réduit
  /// un peu plutôt que de déborder.
  Widget _assemblage() {
    final vierge = _choisis.isEmpty && _phase != _Phase.question;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            key: MoteurAtelier.cleAssemblage,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vierge)
                const _Invitation()
              else ...[
                _Bouche(ouverte: _bouchee != null),
                for (var i = 0; i < _choisis.length; i++)
                  // Le chevauchement est un DESSIN : la place de chaque
                  // morceau ne change pas, c'est la bête qui se serre.
                  Transform.translate(
                    offset: Offset(0, i == 0 ? 0 : MoteurAtelier.chevauchement),
                    child: _Arrivee(
                      key: MoteurAtelier.cleElement(i),
                      child: _morceau(_choisis[i], _tailleMorceau(i)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Un morceau de la bête : l'illustration du concept, posée sur une
  /// pastille blanche.
  Widget _morceau(String concept, double taille) {
    final entree = widget.lexique[concept];
    return Container(
      width: taille,
      height: taille,
      padding: EdgeInsets.all(taille * 0.07),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Palette.cremeFonce, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ImageConcept(
        concept: concept,
        fichier: entree?.illustrationPour(concept) ?? '',
        taille: taille * 0.80,
      ),
    );
  }

  /// Les options du groupe ouvert, en cartes, au bas de l'écran.
  Widget _barreOptions() {
    final groupe = _groupeCourant;
    if (groupe == null) return const SizedBox.shrink();
    return _BarreCartes(
      concepts: groupe.options,
      lexique: widget.lexique,
      cleDe: MoteurAtelier.cleOption,
      onChoix: _choisir,
    );
  }

  /// La phase du nom : un seul gros bouton — celui du micro s'il est accordé,
  /// « J'ai un nom ! » sinon.
  Widget _barreNom() {
    final avecMicro = widget.micro != null && _microPret;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
      child: Center(
        child: SizedBox(
          width: MoteurAtelier.tailleBoutonNom,
          height: MoteurAtelier.tailleBoutonNom,
          child: CibleTactile(
            key: avecMicro
                ? MoteurAtelier.cleEcouteToi
                : MoteurAtelier.cleJaiUnNom,
            onTap: avecMicro
                ? () => unawaited(_ecouterSoi())
                : () => unawaited(_nommer()),
            semantique: avecMicro ? 'écoute-toi' : 'j\'ai un nom',
            child: _BoutonRond(
              icone: avecMicro
                  ? (_enregistrementEnCours
                        ? Icons.graphic_eq_rounded
                        : Icons.mic_rounded)
                  : Icons.waving_hand_rounded,
              couleur: avecMicro ? Palette.corail : Palette.soleil,
            ),
          ),
        ),
      ),
    );
  }

  /// La phase de la bouchée : les nourritures, en cartes.
  Widget _barreNourritures(DonneesAtelier donnees) {
    if (donnees.nourritures.isEmpty) return const SizedBox.shrink();
    return _BarreCartes(
      concepts: donnees.nourritures,
      lexique: widget.lexique,
      cleDe: MoteurAtelier.cleNourriture,
      onChoix: _gouter,
      envol: _bouchee,
    );
  }
}

// ─────────────────────────────── les morceaux ───────────────────────────────

/// Une carte de concept (une option, une nourriture) : l'illustration grande
/// sur une pastille blanche — les mêmes rondeurs que le moteur M1.
class _CarteConcept extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;

  /// null : la carte ne répond plus (une bouchée est déjà en vol).
  final VoidCallback? onTap;

  /// Vrai : la carte s'efface doucement (elle attend son tour).
  final bool effacee;

  const _CarteConcept({
    required this.concept,
    required this.entree,
    required this.cote,
    this.onTap,
    this.effacee = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: effacee ? 0.45 : 1,
      child: CibleTactile(
        onTap: onTap,
        semantique: entree?.texte ?? concept,
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
          child: Center(
            child: ImageConcept(
              concept: concept,
              fichier: entree?.illustrationPour(concept) ?? '',
              taille: cote * 0.62,
            ),
          ),
        ),
      ),
    );
  }
}

/// La barre de cartes du bas : les options d'un groupe, ou les nourritures.
///
/// La taille des cartes vient de la place RÉELLE : jamais moins de 84 points
/// (des doigts d'enfant), jamais plus de 132, et jamais plus de la moitié de
/// l'écran en hauteur — les cartes se rangent sur plusieurs lignes au besoin.
class _BarreCartes extends StatelessWidget {
  final List<String> concepts;
  final Lexique lexique;

  /// La clé d'une carte (chaque phase a la sienne).
  final Key Function(String concept) cleDe;

  final void Function(String concept) onChoix;

  /// La nourriture en vol (phase 3) — null les autres fois.
  final String? envol;

  const _BarreCartes({
    required this.concepts,
    required this.lexique,
    required this.cleDe,
    required this.onChoix,
    this.envol,
  });

  static const double _ecart = 16;
  static const double _coteMini = 84;
  static const double _coteMax = 132;
  static const double _bordGauche = 12;
  static const double _margeBasse = 22;

  @override
  Widget build(BuildContext context) {
    if (concepts.isEmpty) return const SizedBox.shrink();

    final hauteurEcran = MediaQuery.maybeSizeOf(context)?.height ?? 600;
    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeur = contraintes.maxWidth.isFinite
            ? contraintes.maxWidth
            : 360.0;
        final dispo = largeur - 2 * _bordGauche;
        // Combien de cartes tiennent côte à côte, à au moins 84 points ?
        final colonnes = math.min(
          concepts.length,
          math.max(1, ((dispo + _ecart) / (_coteMini + _ecart)).floor()),
        );
        final lignes = (concepts.length / colonnes).ceil();
        // La barre ne mange jamais plus de la moitié de l'écran.
        final budget =
            hauteurEcran * 0.42 - _margeBasse - _ecart * (lignes - 1);
        final placeLargeur = (dispo - _ecart * (colonnes - 1)) / colonnes;
        final placeHauteur = budget / lignes;
        final cote = math.max(
          _coteMini,
          math.min(math.min(placeLargeur, placeHauteur), _coteMax),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            _bordGauche,
            8,
            _bordGauche,
            _margeBasse,
          ),
          child: Center(
            child: Wrap(
              spacing: _ecart,
              runSpacing: _ecart,
              alignment: WrapAlignment.center,
              children: [
                for (final concept in concepts)
                  SizedBox(
                    // La taille est posée ICI : dans un Wrap, la CibleTactile
                    // s'étirerait sinon sur toute la largeur disponible.
                    key: cleDe(concept),
                    width: cote,
                    height: cote,
                    child: concept == envol
                        ? _CarteEnVol(
                            key: MoteurAtelier.cleEnvol,
                            cote: cote,
                            child: _carte(concept, cote, inertes: true),
                          )
                        : _carte(concept, cote, inertes: envol != null),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _carte(String concept, double cote, {required bool inertes}) {
    return _CarteConcept(
      concept: concept,
      entree: lexique[concept],
      cote: cote,
      onTap: inertes ? null : () => onChoix(concept),
      effacee: inertes,
    );
  }
}

/// La bouchée en vol : la carte se réduit et monte vers la bouche de la bête.
///
/// Un [TweenAnimationBuilder] (et non un `AnimatedSlide`) parce que la carte
/// VIENT d'apparaître en vol : un widget implicitement animé ne joue rien à sa
/// première image, celui-ci part de zéro et file.
class _CarteEnVol extends StatelessWidget {
  final double cote;
  final Widget child;

  const _CarteEnVol({super.key, required this.cote, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: MoteurAtelier.dureeBouchee,
      curve: Curves.easeIn,
      child: child,
      builder: (context, valeur, enfant) => Transform.translate(
        offset: Offset(0, MoteurAtelier.envolBouchee.dy * cote * valeur),
        child: Transform.scale(
          scale: 1 - 0.78 * valeur,
          child: Opacity(opacity: (1 - valeur).clamp(0.0, 1.0), child: enfant),
        ),
      ),
    );
  }
}

/// L'arrivée d'un morceau dans l'assemblage : il tombe en place, un peu
/// rebondissant. Même raison qu'une bouchée en vol : le morceau vient
/// d'apparaître, donc un tween explicite — 250 ms, et c'est posé.
class _Arrivee extends StatelessWidget {
  final Widget child;

  const _Arrivee({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: MoteurAtelier.dureeArrivee,
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, valeur, enfant) => Transform.translate(
        offset: Offset(0, (1 - valeur) * -26),
        child: Transform.scale(scale: 0.55 + 0.45 * valeur, child: enfant),
      ),
    );
  }
}

/// La bouche de la bête : elle s'ouvre quand une bouchée arrive.
class _Bouche extends StatelessWidget {
  final bool ouverte;

  const _Bouche({required this.ouverte});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'la bouche',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: MoteurAtelier.largeurBouche,
        height: ouverte ? 46 : 22,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _corailBouche,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(10),
            bottom: Radius.circular(30),
          ),
          border: Border.all(color: _corailBoucheTrait, width: 2),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
          ),
        ),
      ),
    );
  }
}

/// La place de la bête, avant le premier morceau : une tuile douce qui
/// attend les choix. Aucun mot — l'enfant de quatre ans ne lit pas.
class _Invitation extends StatelessWidget {
  const _Invitation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Palette.cremeFonce, width: 4),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 56,
        color: Palette.grisDoux,
      ),
    );
  }
}

/// Un gros bouton rond à icône (jamais de texte : l'enfant ne lit pas).
class _BoutonRond extends StatelessWidget {
  final IconData icone;
  final Color couleur;

  const _BoutonRond({required this.icone, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      // La pastille prend toute la cible : sans ça, le rond se réduirait à
      // la taille de l'icône (le Center interne de la CibleTactile).
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: couleur,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: Icon(icone, size: 64, color: Colors.white)),
      ),
    );
  }
}
