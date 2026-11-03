import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../../contenu/modele/donnees_manche.dart';
import '../../contenu/modele/lexique.dart';
import '../../contenu/modele/manche.dart';
import '../../micro/mic_kit.dart';
import '../../widgets/cible_tactile.dart';
import '../../widgets/avancement_geste.dart';
import '../../widgets/image_concept.dart';
import '../../widgets/contenu_carte_concept.dart';
import '../rappels_moteur.dart';

// ─────────────────────── les sons non verbaux du moteur ───────────────────────
// Générés par tools/audio/generer_sons.py : des WAV courts et doux, jamais une
// voix. Ils vivent dans assets/audio/neutre/sons/ (à déclarer dans pubspec.yaml).
//
// Les huit sons disponibles : tambour.wav, grelot.wav, aigu_fort.wav,
// aigu_doux.wav, grave_fort.wav, grave_doux.wav, ronflement.wav, grogne.wav —
// le contenu les référence par leur chemin complet (`_sonsDir` + le nom).

const _sonsDir = 'assets/audio/neutre/sons/';
const _sonTambour = '${_sonsDir}tambour.wav';
const _sonGrogne = '${_sonsDir}grogne.wav';
const _sonRonflement = '${_sonsDir}ronflement.wav';

/// Les deux visages du monstre du bercement (assets/images/concepts/).
const _monstreEveille = 'monstre';
const _monstreEndormi = 'monstre_dodo';

/// L'eau de l'étang de la grenouille (l'entaille du nénuphar a la même teinte).
const _eauEtang = Color(0xFFCDE7F0);

/// Moteur M6 : le rythme, les sons et la voix — cinq modes, une seule règle :
/// l'enfant n'est JAMAIS jugé sur ce qu'il fait ou dit, seulement accompagné.
///
///  * [ModeRythme.pulsation] : le tambour bat, l'enfant tape avec lui ; le
///    tempo ralentit tout seul quand les tapes se perdent (aucun reproche).
///  * [ModeRythme.bercement] : taper lentement pour endormir le monstre ;
///    taper trop vite le réveille — on perd du temps, jamais un acquis.
///  * [ModeRythme.ecoute] : écouter un son (aigu/grave, fort/doux) et toucher
///    l'image qui va avec.
///  * [ModeRythme.echo] : l'app dit un son, l'enfant le reproduit (micro
///    optionnel — aucun jeu ne l'exige), l'animal réagit.
///  * [ModeRythme.syllabes] : la grenouille saute les syllabes du mot, puis
///    l'enfant rejoue le mot en tapant une fois par syllabe.
///
/// Le moteur ne contient AUCUNE pédagogie : il dessine, écoute les doigts,
/// dit ce qu'il a besoin de dire et raconte ce qui vient de se passer à son
/// hôte ([RappelsMoteur]) — c'est l'hôte qui encourage et qui avance.
class MoteurRythme extends StatefulWidget {
  final Manche manche;

  /// Le lexique du deck actif (texte + illustration des options).
  final Lexique lexique;

  /// Ce que le moteur raconte à son hôte (réussite, essai raté, clips).
  final RappelsMoteur rappels;

  /// Le micro (mode [ModeRythme.echo] seulement) : l'enfant s'enregistre et se
  /// réécoute. L'enregistrement est ÉPHÉMÈRE — réécouté puis effacé aussitôt,
  /// jamais jugé, jamais conservé, jamais transmis.
  ///
  /// null (défaut) : pas de micro — le moteur montre « J'ai essayé ! » à la
  /// place. Aucun jeu n'exige le micro : sans accord, [Micro.enregistrer] rend
  /// null et la manche se termine quand même.
  final Micro? micro;

  /// Vrai : le mot écrit apparaît sous chaque carte (6-7 ans).
  final bool afficherMots;

  const MoteurRythme({
    super.key,
    required this.manche,
    required this.lexique,
    required this.rappels,
    this.micro,
    this.afficherMots = false,
  });

  @override
  MoteurRythmeEtat createState() => MoteurRythmeEtat();
}

/// L'état du moteur (public pour que les tests puissent lire le tempo courant).
class MoteurRythmeEtat extends State<MoteurRythme> {
  // ── le pouls interne ──
  /// La période du pouls : 20 ms. C'est LUI qui donne l'heure au moteur —
  /// jamais l'heure murale — parce qu'il avance aussi dans les tests (les
  /// durées pompées y sont donc exactement celles de la vraie vie).
  static const _periodeTic = Duration(milliseconds: 20);

  // ── pulsation ──
  static const _plafondTempoMs = 1600; // le tempo ne ralentit pas sans fin
  static const _seuilEcart =
      0.40; // au-delà de 40 % de l'intervalle : on ralentit
  static const _pasRalentissement =
      1.15; // chaque ralentissement : +15 % d'intervalle
  static const _fenetreEcarts = 4; // la moyenne glissante des 4 derniers écarts
  static const _tailleTambour = 140.0; // le gros rond, style doudou

  // ── bercement ──
  static const _tapRapideMs = 450; // en bas de ça : le monstre se réveille

  int get _sommeilObjectif => math.max(1, _donnees?.battements ?? 8);
  int get _tapLentMs =>
      math.max(_tapRapideMs + 1, _donnees?.intervalleMs ?? 1100);

  // ── echo ──
  static const _dureeEnregistrement = Duration(seconds: 3);

  // ── syllabes ──
  static const _delaiSaut = Duration(milliseconds: 520); // le temps d'un saut
  static const _delaiAtterrissage = Duration(milliseconds: 300);
  static const _delaiErreur = Duration(milliseconds: 900);

  /// Millisecondes écoulées depuis le début de la manche (le pouls).
  int _ecouleMs = 0;
  int _recitation = 0;

  /// Vrai quand la manche est terminée (l'hôte enchaîne).
  bool _fini = false;

  // ── mode pulsation ──
  int _tapes = 0;
  int _battements = 12;
  int _intervalleMs = 900;
  int _pulsations = 0; // l'élan visuel du tambour
  int _dernierBattementMs = 0;
  int _prochainBattementMs = 900;
  final List<int> _ecarts = <int>[];

  // ── mode bercement ──
  int _sommeil = 0;
  bool _endormi = false;
  int _dernierTapMs = 0;
  int _sursauts = 0; // l'animation de réveil

  // ── modes ecoute / echo / syllabes ──
  String? _erreurConcept;
  bool _essaiFait = false;
  bool _enregistrementEnCours = false;
  int _reactions = 0;
  bool _phase2 = false;
  int _position = -1;
  int _taps = 0;

  Timer? _tic;
  Timer? _chronoErreur;
  Timer? _chronoAtterrissage;
  Timer? _chronoSaut;
  Completer<void>? _attenteSaut;

  DonneesRythme? get _donnees {
    final donnees = widget.manche.donnees;
    return donnees is DonneesRythme ? donnees : null;
  }

  ModeRythme get _mode => _donnees?.mode ?? ModeRythme.pulsation;

  /// Le nombre de syllabes du mot (au moins une : le moteur ne se bloque jamais).
  int get _nbSyllabes => math.max(1, _donnees?.syllabesClips.length ?? 0);

  /// L'intervalle courant du tambour (ms) — il ralentit quand les tapes se
  /// perdent. Exposé pour que les tests voient le tempo bouger.
  @visibleForTesting
  int get intervalleCourantMs => _intervalleMs;

  @override
  void initState() {
    super.initState();
    _recommencer();
    _lierConsigne();
  }

  @override
  void didUpdateWidget(covariant MoteurRythme oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Une autre manche : le moteur repart de zéro.
    if (oldWidget.manche.id != widget.manche.id) _recommencer();
    _lierConsigne();
  }

  @override
  void dispose() {
    final rappels = widget.rappels;
    if (rappels is ConsigneContextuelle) rappels.retirerConsigne(this);
    _recitation++;
    _chronoErreur?.cancel();
    _chronoAtterrissage?.cancel();
    _annulerSaut();
    _tic?.cancel();
    super.dispose();
  }

  /// Remet tout à zéro et lance ce que le mode fait au démarrage.
  ///
  /// Appelé pendant l'initialisation (aucun `setState` : la construction suit).
  void _recommencer() {
    _recitation++;
    _tic?.cancel();
    _chronoErreur?.cancel();
    _chronoAtterrissage?.cancel();
    _annulerSaut();
    _tic = null;
    _chronoErreur = null;
    _chronoAtterrissage = null;

    final donnees = _donnees;
    _fini = false;
    _ecouleMs = 0;

    // pulsation
    _tapes = 0;
    _ecarts.clear();
    _battements = math.max(1, donnees?.battements ?? 12);
    _intervalleMs = (donnees?.intervalleMs ?? 900).clamp(200, _plafondTempoMs);
    _pulsations = donnees?.mode == ModeRythme.pulsation ? 1 : 0;
    _dernierBattementMs = 0;
    _prochainBattementMs = _intervalleMs;

    // bercement
    _sommeil = 0;
    _endormi = false;
    _dernierTapMs = 0;
    _sursauts = 0;

    // ecoute / echo / syllabes
    _erreurConcept = null;
    _essaiFait = false;
    _enregistrementEnCours = false;
    _reactions = 0;
    _phase2 = false;
    _position = -1;
    _taps = 0;

    if (donnees == null) return;

    switch (donnees.mode) {
      case ModeRythme.pulsation:
        // Le premier coup part tout de suite : l'enfant entend le tempo.
        unawaited(widget.rappels.jouerSon(_sonTambour));
        _tic = Timer.periodic(_periodeTic, (_) => _pouls());
      case ModeRythme.bercement:
        // Le pouls ne sert qu'à mesurer la lenteur des caresses.
        _tic = Timer.periodic(_periodeTic, (_) => _pouls());
      case ModeRythme.ecoute:
        _jouerLeSonEcoute();
      case ModeRythme.echo:
        final sonCle = donnees.sonCle;
        if (sonCle != null && sonCle.isNotEmpty) {
          unawaited(widget.rappels.dire(sonCle));
        }
      case ModeRythme.syllabes:
        unawaited(_direLeMot());
    }
  }

  void _lierConsigne() {
    final rappels = widget.rappels;
    if (rappels is! ConsigneContextuelle) return;
    rappels.enregistrerConsigne(this, () async {
      final donnees = _donnees;
      if (donnees == null || _fini) return;
      switch (donnees.mode) {
        case ModeRythme.syllabes:
          setState(() {
            _phase2 = false;
            _taps = 0;
            _position = -1;
          });
          await _direLeMot();
        case ModeRythme.echo:
          if (donnees.sonCle != null) {
            await widget.rappels.dire(donnees.sonCle!);
          }
        case ModeRythme.ecoute:
          final asset = donnees.sonsParOption[donnees.bonneOption];
          if (asset != null) await widget.rappels.jouerSon(asset);
        default:
          for (final clip in widget.manche.clipsConsigne) {
            await widget.rappels.dire(clip);
          }
      }
    });
  }

  // ─────────────────────────────── le pouls ───────────────────────────────

  /// Le battement d'horloge du moteur (pulsation et bercement).
  void _pouls() {
    if (moteurEnPause(widget.rappels)) return;
    _ecouleMs += _periodeTic.inMilliseconds;
    if (_fini) return;
    if (_mode == ModeRythme.bercement) {
      // La couronne montre quand une nouvelle caresse sera assez lente.
      if (_ecouleMs % 100 == 0) setState(() {});
      return;
    }
    if (_mode != ModeRythme.pulsation) return;
    if (_ecouleMs < _prochainBattementMs) return;
    setState(() {
      _pulsations++;
      _dernierBattementMs = _ecouleMs;
      _prochainBattementMs = _ecouleMs + _intervalleMs;
    });
    unawaited(widget.rappels.jouerSon(_sonTambour));
  }

  /// Termine la manche : plus rien n'écoute, l'hôte célèbre et avance.
  void _terminer() {
    if (_fini) return;
    _tic?.cancel();
    _tic = null;
    _chronoErreur?.cancel();
    _chronoErreur = null;
    _chronoAtterrissage?.cancel();
    _chronoAtterrissage = null;
    _annulerSaut();
    setState(() => _fini = true);
    widget.rappels.itemReussi();
  }

  /// Une attente ANNULABLE : une manche qui se termine ne laisse jamais un
  /// minuteur en vie derrière elle (ni dans l'app, ni dans les tests).
  Future<void> _attendre(Duration duree) {
    _annulerSaut();
    final attente = Completer<void>();
    _attenteSaut = attente;
    var restant = duree.inMilliseconds;
    _chronoSaut = Timer.periodic(_periodeTic, (chrono) {
      if (!moteurEnPause(widget.rappels)) restant -= _periodeTic.inMilliseconds;
      if (restant > 0) return;
      chrono.cancel();
      if (!attente.isCompleted) attente.complete();
    });
    return attente.future;
  }

  void _annulerSaut() {
    _chronoSaut?.cancel();
    _chronoSaut = null;
    final attente = _attenteSaut;
    _attenteSaut = null;
    if (attente != null && !attente.isCompleted) attente.complete();
  }

  // ───────────────────────────── mode pulsation ─────────────────────────────

  /// L'enfant tape le tambour : on mesure l'écart avec la pulsation la plus
  /// proche. Des tapes qui se perdent ralentissent le tempo — on ne gronde
  /// jamais, on ralentit.
  void _taperTambour() {
    if (_fini || _mode != ModeRythme.pulsation) return;

    final depuisLeBattement = _ecouleMs - _dernierBattementMs;
    final versLeBattement = math.max(0, _prochainBattementMs - _ecouleMs);
    final ecart = math.min(depuisLeBattement, versLeBattement);

    _ecarts.add(ecart);
    if (_ecarts.length > _fenetreEcarts) _ecarts.removeAt(0);
    final moyenne = _ecarts.reduce((a, b) => a + b) / _ecarts.length.toDouble();

    if (moyenne > _intervalleMs * _seuilEcart &&
        _intervalleMs < _plafondTempoMs) {
      _intervalleMs = math.min(
        _plafondTempoMs,
        (_intervalleMs * _pasRalentissement).round(),
      );
      // Le prochain coup se replace sur le nouveau tempo.
      _prochainBattementMs = _dernierBattementMs + _intervalleMs;
    }

    setState(() {
      _tapes++;
      _pulsations++;
    });
    if (_tapes >= _battements) _terminer();
  }

  // ───────────────────────────── mode bercement ─────────────────────────────

  /// Une caresse sur le monstre : lente, elle l'endort ; trop vive, elle le
  /// réveille (il grogne) — sans jamais rien reprendre à l'enfant.
  void _caresser() {
    if (_fini || _mode != ModeRythme.bercement) return;

    final intervalle = _ecouleMs - _dernierTapMs;
    _dernierTapMs = _ecouleMs;

    if (intervalle < _tapRapideMs) {
      // Trop vite : le monstre se réveille. Le compteur de sommeil ne
      // descend PAS — l'enfant a seulement perdu un peu de temps.
      _endormi = false;
      _sursauts++;
      setState(() {});
      unawaited(widget.rappels.jouerSon(_sonGrogne));
      return;
    }

    if (intervalle < _tapLentMs) {
      // Entre les deux : ni caresse comptée, ni réveil. Rien de grave.
      return;
    }

    _sommeil++;
    _endormi = true;
    setState(() {});

    if (_sommeil >= _sommeilObjectif) {
      // Tout doux… le monstre dort pour de bon.
      unawaited(widget.rappels.jouerSon(_sonRonflement));
      _terminer();
    }
  }

  // ─────────────────────────────── mode ecoute ───────────────────────────────

  /// Joue le son de la bonne réponse (au démarrage et sur « Écouter encore »).
  void _jouerLeSonEcoute() {
    final donnees = _donnees;
    final bonne = donnees?.bonneOption;
    if (donnees == null || bonne == null) return;
    final asset = donnees.sonsParOption[bonne];
    if (asset != null && asset.isNotEmpty) {
      unawaited(widget.rappels.jouerSon(asset));
    }
  }

  void _choisirEcoute(OptionManche option) {
    if (_fini || _mode != ModeRythme.ecoute) return;
    final donnees = _donnees;
    if (donnees == null) return;

    if (option.concept == donnees.bonneOption) {
      _terminer();
      return;
    }

    // Raté : jamais grave — l'hôte encourage, l'enfant réessaie.
    widget.rappels.essaiRate();
    _chronoErreur?.cancel();
    setState(() => _erreurConcept = option.concept);
    _chronoErreur = Timer(_delaiErreur, () {
      if (!mounted) return;
      setState(() => _erreurConcept = null);
    });
  }

  // ──────────────────────────────── mode echo ────────────────────────────────

  /// L'app redit le son à reproduire.
  void _redireLeSon() {
    if (_fini) return;
    final sonCle = _donnees?.sonCle;
    if (sonCle != null && sonCle.isNotEmpty) {
      unawaited(widget.rappels.dire(sonCle));
    }
  }

  /// « Écoute-toi » : on enregistre l'enfant (3 s au plus), on lui rejoue, et
  /// on efface aussitôt. Rien n'est jugé, rien ne reste.
  Future<void> _ecouterSoi() async {
    final micro = widget.micro;
    if (micro == null || _fini || _enregistrementEnCours) return;

    final manche = widget.manche;
    bool courante() => mounted && identical(widget.manche, manche);
    setState(() => _enregistrementEnCours = true);
    try {
      // Sans accord, `enregistrer` rend null : l'enfant reste jouable et ne
      // s'aperçoit de rien.
      final chemin = await micro.enregistrer(max: _dureeEnregistrement);
      if (chemin != null && chemin.isNotEmpty) {
        try {
          if (!courante()) return;
          await micro.rejouer(chemin);
        } finally {
          // Même si l'écran est fermé ou si l'écoute échoue.
          await micro.effacer(chemin);
        }
      }
    } catch (_) {
      // Micro refusé, occupé ou en panne : l'enfant n'est JAMAIS bloqué.
    }
    if (!courante()) return;
    setState(() => _enregistrementEnCours = false);
    _reagir();
  }

  /// L'enfant a essayé : l'animal réagit, puis la manche est réussie.
  void _reagir() {
    if (_fini || _essaiFait || moteurEnPause(widget.rappels)) return;
    _reactions++;
    _essaiFait = true;
    setState(() {});
    unawaited(_direLaReaction());
  }

  Future<void> _direLaReaction() async {
    final manche = widget.manche;
    final reaction = _donnees?.reactionCle;
    if (reaction != null && reaction.isNotEmpty) {
      await widget.rappels.dire(reaction);
    }
    if (!mounted || _fini || !identical(widget.manche, manche)) return;
    _terminer();
  }

  // ────────────────────────────── mode syllabes ──────────────────────────────

  /// Phase 1 : le mot entier, puis chaque syllabe — la grenouille saute d'un
  /// nénuphar à chaque syllabe. Phase 2 : « À toi ! ».
  Future<void> _direLeMot() async {
    final recitation = ++_recitation;
    final donnees = _donnees;
    if (donnees == null) return;

    final mot = donnees.motCle;
    if (mot != null && mot.isNotEmpty) {
      await widget.rappels.dire(mot);
      if (!mounted || _fini || recitation != _recitation) return;
    }

    for (var i = 0; i < _nbSyllabes; i++) {
      if (i < donnees.syllabesClips.length) {
        await widget.rappels.dire(donnees.syllabesClips[i]);
        if (!mounted || _fini || recitation != _recitation) return;
      }
      setState(() => _position = i);
      await _attendre(_delaiSaut);
      if (!mounted || _fini || recitation != _recitation) return;
    }

    // « À toi ! » : la grenouille revient au départ, la grosse cible écoute.
    setState(() {
      _phase2 = true;
      _position = -1;
      _taps = 0;
    });
  }

  /// Une tape de l'enfant : une syllabe. Le mot est réussi quand il a tapé
  /// autant de fois qu'il y a de syllabes — une tape en trop, et on
  /// recommence le mot, doucement, sans rien perdre.
  void _taperSyllabe() {
    if (_fini || !_phase2) return;
    final nb = _nbSyllabes;

    if (_taps >= nb) {
      // Plus de tapes que de syllabes : on encourage doucement. On ne remet
      // PAS la manche à zéro — la grenouille revient au départ et l'enfant
      // refait le mot (phase 2), tout de suite.
      _recitation++;
      _annulerSaut();
      widget.rappels.essaiRate();
      setState(() {
        _taps = 0;
        _position = -1;
      });
      return;
    }

    setState(() {
      _taps++;
      _position = _taps - 1;
    });

    if (_taps >= nb) {
      // Le mot est complet : on laisse la grenouille atterrir, puis on gagne.
      final recitation = _recitation;
      unawaited(
        _attendre(_delaiAtterrissage).then((_) {
          if (mounted && !_fini && recitation == _recitation && _taps >= nb) {
            _terminer();
          }
        }),
      );
    }
  }

  // ───────────────────────────────── dessin ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final donnees = _donnees;
    if (donnees == null) {
      // Une manche sans données M6 : un doux silence, jamais une erreur.
      return const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 96,
          color: Palette.grisDoux,
        ),
      );
    }
    return RepaintBoundary(
      child: switch (donnees.mode) {
        ModeRythme.pulsation => _vuePulsation(donnees),
        ModeRythme.bercement => _vueBercement(donnees),
        ModeRythme.ecoute => _vueEcoute(donnees),
        ModeRythme.echo => _vueEcho(donnees),
        ModeRythme.syllabes => _vueSyllabes(donnees),
      },
    );
  }

  // ── pulsation : le tambour ──
  Widget _vuePulsation(DonneesRythme donnees) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: CibleTactile(
            key: const ValueKey('rythme.tambour'),
            onTap: _taperTambour,
            tailleMin: _tailleTambour,
            semantique: 'le tambour',
            child: _Tambour(taille: _tailleTambour, pulsation: _pulsations),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 12,
          child: AvancementGeste(faits: _tapes, total: _battements),
        ),
      ],
    );
  }

  // ── bercement : le monstre sur son lit ──
  Widget _vueBercement(DonneesRythme donnees) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: _BarreSommeil(sommeil: _sommeil, objectif: _sommeilObjectif),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, dispo) {
              final l = dispo.maxWidth.isFinite ? dispo.maxWidth : 360.0;
              final h = dispo.maxHeight.isFinite ? dispo.maxHeight : 320.0;
              return Center(
                child: _Lit(
                  largeur: l,
                  hauteur: h,
                  enfant: _leMonstre(math.min(l * 0.34, h * 0.52)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: CibleTactile(
            key: const ValueKey('rythme.caresse'),
            onTap: _caresser,
            tailleMin: 140,
            semantique: 'la caresse',
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    key: const ValueKey('rythme.attenteCaresse'),
                    width: 154,
                    height: 154,
                    child: CircularProgressIndicator(
                      value: ((_ecouleMs - _dernierTapMs) / _tapLentMs).clamp(
                        0.0,
                        1.0,
                      ),
                      strokeWidth: 6,
                      color: Palette.verdure,
                      backgroundColor: Palette.cremeFonce,
                    ),
                  ),
                  const _Nuage(taille: 148),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Le monstre : endormi quand il s'assoupit, avec un doux sursaut quand il
  /// se réveille.
  Widget _leMonstre(double taille) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('rythme.sursaut.$_sursauts'),
      tween: Tween(begin: _sursauts == 0 ? 0.0 : -26.0, end: 0.0),
      duration: const Duration(milliseconds: 460),
      curve: Curves.elasticOut,
      builder: (context, valeur, enfant) =>
          Transform.translate(offset: Offset(0, valeur), child: enfant),
      child: ImageConcept(
        concept: _endormi ? _monstreEndormi : _monstreEveille,
        taille: taille,
      ),
    );
  }

  // ── ecoute : un son, puis l'image qui va avec ──
  Widget _vueEcoute(DonneesRythme donnees) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: CibleTactile(
            key: const ValueKey('rythme.ecouter'),
            onTap: _jouerLeSonEcoute,
            tailleMin: 96,
            semantique: 'écouter encore',
            child: const _BoutonRond(
              icone: Icons.volume_up_rounded,
              couleur: Palette.ciel,
              cote: 96,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, contraintes) {
              final options = widget.manche.options;
              final colonnes = options.length <= 2
                  ? math.max(1, options.length)
                  : 2;
              final largeur =
                  (contraintes.maxWidth - 24 * (colonnes - 1)) / colonnes;
              final cote = math
                  .min(
                    largeur,
                    contraintes.maxHeight - (widget.afficherMots ? 44 : 0),
                  )
                  .clamp(80.0, 220.0);
              return Center(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final option in options)
                        // La taille est posée ici : dans un Wrap, la
                        // [CibleTactile] s'étirerait sinon sur toute la largeur.
                        SizedBox(
                          width: cote,
                          height: _CarteOption.hauteurPour(
                            cote,
                            widget.afficherMots,
                          ),
                          child: _CarteOption(
                            key: ValueKey('rythme.option.${option.concept}'),
                            concept: option.concept,
                            entree: widget.lexique[option.concept],
                            cote: cote,
                            afficherMot: widget.afficherMots,
                            enErreur: option.concept == _erreurConcept,
                            onTap: () => _choisirEcoute(option),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── echo : la bouche à sons ──
  Widget _vueEcho(DonneesRythme donnees) {
    final animal = donnees.animalConcept;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, dispo) {
              final l = dispo.maxWidth.isFinite ? dispo.maxWidth : 360.0;
              final h = dispo.maxHeight.isFinite ? dispo.maxHeight : 360.0;
              final taille = math.min(l * 0.42, h * 0.62);
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey('rythme.reaction.$_reactions'),
                        tween: Tween(
                          begin: _reactions == 0 ? 1.0 : 1.22,
                          end: 1.0,
                        ),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutBack,
                        builder: (context, valeur, enfant) =>
                            Transform.scale(scale: valeur, child: enfant),
                        child: animal == null
                            ? const Icon(
                                Icons.hearing_rounded,
                                size: 96,
                                color: Palette.grisDoux,
                              )
                            : ImageConcept(concept: animal, taille: taille),
                      ),
                      const SizedBox(height: 14),
                      _PastilleEcho(essaiFait: _essaiFait),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CibleTactile(
                key: const ValueKey('rythme.ecouter'),
                onTap: _redireLeSon,
                tailleMin: 96,
                semantique: 'écouter encore',
                child: const _BoutonRond(
                  icone: Icons.volume_up_rounded,
                  couleur: Palette.ciel,
                  cote: 96,
                ),
              ),
              const SizedBox(width: 30),
              if (widget.micro != null)
                // « Écoute-toi » : l'enfant s'enregistre et se réécoute.
                CibleTactile(
                  key: const ValueKey('rythme.ecouteToi'),
                  onTap: () => unawaited(_ecouterSoi()),
                  tailleMin: 96,
                  semantique: 'écoute-toi',
                  child: _BoutonRond(
                    icone: _enregistrementEnCours
                        ? Icons.graphic_eq_rounded
                        : Icons.mic_rounded,
                    couleur: Palette.corail,
                    cote: 96,
                  ),
                )
              else
                // Sans micro : l'enfant a essayé, c'est tout ce qui compte.
                CibleTactile(
                  key: const ValueKey('rythme.jaiEssaye'),
                  onTap: _reagir,
                  tailleMin: 96,
                  semantique: 'j\'ai essayé',
                  child: const _BoutonRond(
                    icone: Icons.check_rounded,
                    couleur: Palette.verdure,
                    cote: 96,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── syllabes : la grenouille et ses nénuphars ──
  Widget _vueSyllabes(DonneesRythme donnees) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeur = contraintes.maxWidth.isFinite
            ? contraintes.maxWidth
            : 360.0;
        final hauteur = contraintes.maxHeight.isFinite
            ? contraintes.maxHeight
            : 520.0;
        final nb = _nbSyllabes;
        final fentes = nb + 1; // le départ, puis un nénuphar par syllabe
        final pas = largeur / fentes;
        final tailleGrenouille = (pas * 0.86).clamp(56.0, 112.0);
        final largeurNenuphar = math.min(pas * 0.92, 148.0);
        final eau = hauteur * 0.34;
        final hautNenuphar = hauteur - eau * 0.78;

        double centreDe(int fente) => pas * (fente + 0.5);

        return CibleTactile(
          key: const ValueKey('rythme.syllabe'),
          onTap: _taperSyllabe,
          semantique: 'les syllabes du mot',
          child: SizedBox(
            width: largeur,
            height: hauteur,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // L'étang.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: eau,
                  child: const ColoredBox(color: _eauEtang),
                ),
                // Les nénuphars : un par syllabe.
                for (var i = 0; i < nb; i++)
                  Positioned(
                    left: centreDe(i + 1) - largeurNenuphar / 2,
                    top: hautNenuphar + (i.isEven ? 0 : 10),
                    child: _Nenuphar(largeur: largeurNenuphar),
                  ),
                // La grenouille : elle saute d'un nénuphar au suivant.
                AnimatedPositioned(
                  duration: _delaiSaut,
                  curve: Curves.easeOutBack,
                  left: centreDe(_position + 1) - tailleGrenouille / 2,
                  top: hautNenuphar - tailleGrenouille * 0.66,
                  child: _Grenouille(taille: tailleGrenouille),
                ),
                // « À toi ! » : une main qui attend les tapes.
                if (_phase2 && !_fini)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: hauteur * 0.05,
                    child: const Center(child: _InvitationTape()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────── les morceaux ───────────────────────────────

/// Le tambour : un gros rond doudou qui pulse à chaque coup.
class _Tambour extends StatelessWidget {
  final double taille;
  final int pulsation;

  const _Tambour({required this.taille, required this.pulsation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('rythme.pulsation.$pulsation'),
        tween: Tween(begin: 1.14, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, valeur, enfant) =>
            Transform.scale(scale: valeur, child: enfant),
        child: Container(
          decoration: BoxDecoration(
            color: Palette.corail,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC85A34), width: 6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.all(taille * 0.13),
          child: Container(
            decoration: BoxDecoration(
              color: Palette.creme,
              shape: BoxShape.circle,
              border: Border.all(color: Palette.cremeFonce, width: 5),
            ),
            child: Center(
              child: Icon(
                Icons.music_note_rounded,
                size: taille * 0.28,
                color: Palette.corail,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La barre des Z : un Z s'allume par caresse lente.
class _BarreSommeil extends StatelessWidget {
  final int sommeil;
  final int objectif;

  const _BarreSommeil({required this.sommeil, required this.objectif});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$sommeil Z sur $objectif',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < objectif; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: CustomPaint(
                size: const Size(20, 20),
                painter: _DessinZ(
                  i < sommeil
                      ? Palette.prune
                      : Palette.grisDoux.withValues(alpha: 0.45),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un Z dessiné (trois traits) — jamais une lettre à lire.
class _DessinZ extends CustomPainter {
  final Color couleur;

  const _DessinZ(this.couleur);

  @override
  void paint(Canvas canvas, Size taille) {
    final pinceau = Paint()
      ..color = couleur
      ..strokeWidth = taille.width * 0.17
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(taille.width * 0.22, taille.height * 0.24)
        ..lineTo(taille.width * 0.78, taille.height * 0.24)
        ..lineTo(taille.width * 0.22, taille.height * 0.76)
        ..lineTo(taille.width * 0.78, taille.height * 0.76),
      pinceau,
    );
  }

  @override
  bool shouldRepaint(covariant _DessinZ ancien) => ancien.couleur != couleur;
}

/// Le lit du monstre : un cadre, un matelas, un oreiller.
class _Lit extends StatelessWidget {
  final double largeur;
  final double hauteur;
  final Widget enfant;

  const _Lit({
    required this.largeur,
    required this.hauteur,
    required this.enfant,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largeur,
      height: hauteur,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Le mur de la chambre, derrière tout.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8E0F4), Palette.creme],
                ),
              ),
            ),
          ),
          // Le cadre du lit.
          Positioned(
            left: largeur * 0.06,
            right: largeur * 0.06,
            top: hauteur * 0.56,
            bottom: hauteur * 0.06,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF9C7248),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Le matelas.
          Positioned(
            left: largeur * 0.10,
            right: largeur * 0.10,
            top: hauteur * 0.48,
            bottom: hauteur * 0.18,
            child: Container(
              decoration: BoxDecoration(
                color: Palette.creme,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Palette.cremeFonce, width: 4),
              ),
            ),
          ),
          // L'oreiller.
          Positioned(
            left: largeur * 0.13,
            top: hauteur * 0.40,
            width: largeur * 0.22,
            height: hauteur * 0.13,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6E0F0), width: 3),
              ),
            ),
          ),
          // Le monstre, couché sur le matelas.
          Positioned(
            left: 0,
            right: 0,
            top: hauteur * 0.10,
            height: hauteur * 0.40,
            child: Center(child: enfant),
          ),
        ],
      ),
    );
  }
}

/// Le nuage des caresses : un gros rond doux, fait de trois bosses.
class _Nuage extends StatelessWidget {
  final double taille;

  const _Nuage({required this.taille});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: taille * 0.62,
            child: Container(
              decoration: BoxDecoration(
                color: Palette.creme,
                borderRadius: BorderRadius.circular(taille * 0.34),
                border: Border.all(color: const Color(0xFFBFD9EA), width: 5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: taille * 0.12,
            top: taille * 0.10,
            child: _Bosse(taille: taille * 0.40),
          ),
          Positioned(
            right: taille * 0.12,
            top: taille * 0.18,
            child: _Bosse(taille: taille * 0.32),
          ),
          Positioned(
            bottom: taille * 0.16,
            child: Icon(
              Icons.favorite_rounded,
              size: taille * 0.26,
              color: Palette.corail.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bosse extends StatelessWidget {
  final double taille;

  const _Bosse({required this.taille});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: Palette.creme,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFBFD9EA), width: 5),
      ),
    );
  }
}

/// Un gros bouton rond à icône (jamais de texte : l'enfant de 4 ans ne lit pas).
class _BoutonRond extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final double cote;

  const _BoutonRond({
    required this.icone,
    required this.couleur,
    required this.cote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cote,
      height: cote,
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
      child: Icon(icone, size: cote * 0.52, color: Colors.white),
    );
  }
}

/// La pastille de l'écho : une oreille qui écoute, un cœur quand l'enfant a essayé.
class _PastilleEcho extends StatelessWidget {
  final bool essaiFait;

  const _PastilleEcho({required this.essaiFait});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (essaiFait ? Palette.corail : Palette.ciel).withValues(
          alpha: 0.16,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        essaiFait ? Icons.favorite_rounded : Icons.hearing_rounded,
        size: 34,
        color: essaiFait ? Palette.corail : Palette.ciel,
      ),
    );
  }
}

/// La carte d'une option — les mêmes rondeurs que le moteur M1.
class _CarteOption extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;
  final bool enErreur;
  final VoidCallback onTap;

  const _CarteOption({
    super.key,
    required this.concept,
    required this.entree,
    required this.cote,
    required this.afficherMot,
    required this.enErreur,
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
            color: enErreur ? const Color(0xFFE8A0A0) : Palette.cremeFonce,
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

/// Un nénuphar : un ovale vert entaillé, avec une petite fleur.
class _Nenuphar extends StatelessWidget {
  final double largeur;

  const _Nenuphar({required this.largeur});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largeur,
      height: largeur * 0.40,
      child: CustomPaint(painter: const _DessinNenuphar(_eauEtang)),
    );
  }
}

class _DessinNenuphar extends CustomPainter {
  final Color eau;

  const _DessinNenuphar(this.eau);

  @override
  void paint(Canvas canvas, Size taille) {
    final centre = Offset(taille.width / 2, taille.height / 2);
    canvas.drawOval(
      Rect.fromCenter(
        center: centre,
        width: taille.width,
        height: taille.height,
      ),
      Paint()..color = Palette.verdure,
    );
    // L'entaille : le coin d'étang qu'on voit dans le nénuphar.
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(taille.width, centre.dy - taille.height * 0.62)
        ..lineTo(taille.width, centre.dy + taille.height * 0.62)
        ..close(),
      Paint()..color = eau,
    );
    // La fleur, sur le bord gauche.
    canvas.drawCircle(
      Offset(taille.width * 0.26, centre.dy - taille.height * 0.16),
      taille.height * 0.16,
      Paint()..color = Palette.corail,
    );
  }

  @override
  bool shouldRepaint(covariant _DessinNenuphar ancien) => ancien.eau != eau;
}

/// La grenouille : un corps ovale vert, deux gros yeux blancs, un sourire.
class _Grenouille extends StatelessWidget {
  final double taille;

  const _Grenouille({required this.taille});

  @override
  Widget build(BuildContext context) {
    final oeil = taille * 0.36;
    return SizedBox(
      width: taille,
      height: taille,
      child: Stack(
        children: [
          // Les deux grosses pattes, sous le corps.
          Positioned(
            left: taille * 0.10,
            bottom: 0,
            child: _Patte(taille: taille * 0.22),
          ),
          Positioned(
            right: taille * 0.10,
            bottom: 0,
            child: _Patte(taille: taille * 0.22),
          ),
          // Le corps.
          Positioned(
            left: 0,
            right: 0,
            bottom: taille * 0.10,
            height: taille * 0.60,
            child: Container(
              decoration: BoxDecoration(
                color: Palette.verdure,
                borderRadius: BorderRadius.all(
                  Radius.elliptical(taille * 0.5, taille * 0.30),
                ),
                border: Border.all(color: const Color(0xFF3C9068), width: 3),
              ),
              child: Center(
                child: Container(
                  width: taille * 0.34,
                  height: taille * 0.16,
                  decoration: BoxDecoration(
                    border: const Border(
                      bottom: BorderSide(color: Palette.creme, width: 3),
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.elliptical(taille * 0.17, taille * 0.16),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Les yeux, sur le dessus de la tête.
          Positioned(
            top: 0,
            left: taille * 0.04,
            child: _Oeil(taille: oeil),
          ),
          Positioned(
            top: 0,
            right: taille * 0.04,
            child: _Oeil(taille: oeil),
          ),
        ],
      ),
    );
  }
}

class _Oeil extends StatelessWidget {
  final double taille;

  const _Oeil({required this.taille});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF3C9068), width: 3),
      ),
      child: Center(
        child: Container(
          width: taille * 0.42,
          height: taille * 0.42,
          decoration: const BoxDecoration(
            color: Palette.encre,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _Patte extends StatelessWidget {
  final double taille;

  const _Patte({required this.taille});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: const BoxDecoration(
        color: Color(0xFF3C9068),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// « À toi ! » : une main qui attend la tape (aucun texte pour l'enfant).
class _InvitationTape extends StatelessWidget {
  const _InvitationTape();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 1.14),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      builder: (context, valeur, enfant) =>
          Transform.scale(scale: valeur, child: enfant),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.soleil.withValues(alpha: 0.30),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.touch_app_rounded,
          size: 44,
          color: Palette.encre,
        ),
      ),
    );
  }
}
