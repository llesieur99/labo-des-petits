import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/say_kit.dart';
import '../../core/contenu/catalogue.dart';
import '../../core/contenu/modele/activite.dart';
import '../../core/contenu/modele/payloads_moteurs.dart';
import '../../core/moteurs/m1_tap_pick/tap_pick.dart';
import '../../core/moteurs/m2_drop_place/depot_place.dart';
import '../../core/moteurs/m3_trace/trace.dart';
import '../../core/moteurs/m4_scene/scene.dart';
import '../../core/moteurs/m5_ordre/code_blocs.dart';
import '../../core/moteurs/m5_ordre/composer.dart';
import '../../core/moteurs/m5_ordre/ordre.dart';
import '../../core/moteurs/m6_rythme/rythme.dart';
import '../../core/moteurs/m7_creation/atelier.dart';
import '../../core/moteurs/m7_creation/theatre.dart';
import '../../core/moteurs/m7_creation/toile.dart';
import '../../core/moteurs/m8_tours/tours.dart';
import '../../core/moteurs/m9_balance/balance.dart';
import '../../core/micro/mic_kit.dart';
import '../../core/parent/reglages.dart';
import '../../core/parent/fiches_activites.dart';
import '../../core/widgets/guide_gestuel.dart';
import '../../core/widgets/image_concept.dart';
import '../../core/progression/adaptation.dart';
import '../../core/progression/collants.dart';
import '../../core/progression/depot.dart';
import '../../core/progression/modele.dart';
import '../../core/widgets/barre_consigne.dart';
import '../../theme/palette.dart';
import 'fin_de_partie.dart';
import 'jeu_controller.dart';

/// L'hôte d'une partie : consigne dite → moteur → encouragement → item
/// suivant → fin (étoiles, jamais de score).
///
/// L'hôte choisit le moteur selon l'activité — les moteurs ne contiennent
/// aucune pédagogie, ils dessinent et racontent.
class JeuScreen extends StatefulWidget {
  final Activite activite;
  final Profil profil;
  final DateTime Function() maintenant;
  final Random? alea;

  const JeuScreen({
    super.key,
    required this.activite,
    required this.profil,
    this.maintenant = DateTime.now,
    this.alea,
  });

  @override
  State<JeuScreen> createState() => _JeuScreenState();
}

class _JeuScreenState extends State<JeuScreen> with WidgetsBindingObserver {
  /// Clips conventionnels du mode « à tour de rôle » (déclarés par
  /// l'activité 33 ; s'ils manquent, le SayKit journalise sans planter).
  static const _clipsMonTour = 'consigne.tours.mien';
  static const _clipsAutreTour = 'consigne.tours.autre';

  JeuController? _controleur;
  int _collantsAvant = 0;
  late DateTime _debutPartie;
  bool _tempsCompte = false;
  bool _guideAffiche = false;
  bool _partieDemarree = false;
  DateTime? _debutPause;
  Duration _tempsPause = Duration.zero;
  bool _preparationEnCours = false;
  bool _fermetureEnCours = false;
  ToursController? _tours;
  int _dernierItemPourTour = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preparer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controleur?.removeListener(_surAvancement);
    _controleur?.dispose();
    _tours?.dispose();
    super.dispose();
  }

  Future<void> _preparer() async {
    if (_preparationEnCours) return;
    _preparationEnCours = true;
    try {
      final depot = context.read<DepotProgression>();
      final say = context.read<SayKit>();
      final profilId = widget.profil.id!;

      final etatExistant = await depot.etat(profilId, widget.activite.id);
      if (!mounted) return;
      final etat =
          etatExistant ??
          AdaptationDouce.etatInitial(
            profilId: profilId,
            activiteId: widget.activite.id,
            palier: widget.profil.palierDeDepart,
          );

      final niveau =
          widget.activite.niveauPour(etat.palier, numero: etat.niveau) ??
          widget.activite.niveaux.first;
      _collantsAvant = _collantsGagnes(etat);

      final evenements = await depot.evenements(
        profilId,
        activiteId: widget.activite.id,
      );
      if (!mounted) return;
      final recents = evenements.reversed.take(12).map((e) => e.itemId).toSet();
      final controleur = JeuController(
        activite: widget.activite,
        niveau: niveau,
        etat: etat,
        say: say,
        depot: depot,
        alea: widget.alea,
        manchesRecentes: recents,
      );
      // En mode « à tour de rôle », le tour change à chaque nouvelle manche.
      if (_estEnTours(widget.activite)) {
        _tours = ToursController();
        _dernierItemPourTour = 0;
      }
      controleur.addListener(_surAvancement);
      setState(() {
        _controleur = controleur;
        _partieDemarree = false;
        _guideAffiche = !context.read<Reglages>().guideVu(
          widget.profil.id!,
          gestePour(widget.activite).name,
        );
      });
      _debutPartie = widget.maintenant();
      _tempsCompte = false;
      if (!_guideAffiche) await _demarrerPartie();
    } finally {
      _preparationEnCours = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_partieDemarree) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _marquerPause();
      _controleur?.suspendre();
    } else if (state == AppLifecycleState.resumed && !_guideAffiche) {
      _finPause();
      _controleur?.reprendre();
    }
  }

  Future<void> _demarrerPartie() async {
    _debutPartie = widget.maintenant();
    _tempsPause = Duration.zero;
    _debutPause = null;
    setState(() => _partieDemarree = true);
    await _controleur?.demarrer();
  }

  void _montrerGeste() {
    if (_guideAffiche) return;
    _marquerPause();
    _controleur?.suspendre();
    setState(() => _guideAffiche = true);
  }

  Future<void> _commencerGuide() async {
    await context.read<Reglages>().marquerGuideVu(
      widget.profil.id!,
      gestePour(widget.activite).name,
    );
    if (!mounted || !_guideAffiche) return;
    setState(() => _guideAffiche = false);
    if (_partieDemarree) {
      _finPause();
      await _controleur?.reprendre();
    } else {
      await _demarrerPartie();
    }
  }

  void _marquerPause() {
    if (_partieDemarree) _debutPause ??= widget.maintenant();
  }

  void _finPause() {
    final debut = _debutPause;
    if (debut != null) {
      final duree = widget.maintenant().difference(debut);
      if (!duree.isNegative) _tempsPause += duree;
      _debutPause = null;
    }
  }

  bool _estEnTours(Activite activite) =>
      activite.payload is PayloadTapPick &&
      (activite.payload as PayloadTapPick).tours;

  /// Le micro des jeux, ou null si le parent ne l'a pas autorisé.
  /// Aucun jeu ne l'exige : sans lui, « Écoute-toi » devient « J'ai essayé ! ».
  Micro? _microPourLesJeux(BuildContext context) =>
      context.read<Reglages>().microAutorise ? context.read<Micro>() : null;

  void _surAvancement() {
    final controleur = _controleur;
    if (controleur == null) return;
    if (controleur.fini && !_tempsCompte) {
      _tempsCompte = true;
      final minutes =
          (widget.maintenant().difference(_debutPartie) - _tempsPause)
              .inMinutes;
      if (minutes > 0) {
        context.read<Reglages>().ajouterMinutes(widget.profil.id!, minutes);
      }
    }
    if (_tours == null) return;
    if (controleur.itemsFaits != _dernierItemPourTour) {
      _dernierItemPourTour = controleur.itemsFaits;
      _tours!.changerDeTour();
    }
  }

  int _collantsGagnes(EtatActivite? etat) =>
      TypeCollant.values.where((t) => t.gagne(etat)).length;

  Future<void> _quitter() async {
    if (_fermetureEnCours) return;
    _fermetureEnCours = true;
    await context.read<SayKit>().stopper();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _rejouer() async {
    if (_preparationEnCours || _fermetureEnCours) return;
    _controleur?.removeListener(_surAvancement);
    _controleur?.dispose();
    _tours?.dispose();
    _tours = null;
    setState(() => _controleur = null);
    await _preparer();
  }

  @override
  Widget build(BuildContext context) {
    final controleur = _controleur;
    return Scaffold(
      body: SafeArea(
        child: controleur == null
            ? const Center(child: CircularProgressIndicator())
            : AnimatedBuilder(
                animation: controleur,
                builder: (context, _) {
                  if (controleur.fini) {
                    return _fin(controleur);
                  }
                  return Column(
                    children: [
                      BarreConsigne(
                        onRepeter: controleur.repeterConsigne,
                        onQuitter: _quitter,
                        onMontrerGeste: _montrerGeste,
                        itemsFaits: controleur.itemsFaits,
                        itemsTotal: controleur.itemsTotal,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            if (_partieDemarree && controleur.manchePrete)
                              Positioned.fill(
                                child: Offstage(
                                  offstage: _guideAffiche,
                                  child: AbsorbPointer(
                                    absorbing: !controleur.interactionPossible,
                                    child: _zoneDeJeu(controleur),
                                  ),
                                ),
                              ),
                            if (!_guideAffiche && !controleur.manchePrete)
                              Center(
                                child: ImageConcept(
                                  concept: widget.activite.id,
                                  fichier: widget.activite.illustration,
                                  taille: 144,
                                ),
                              ),
                            if (_guideAffiche)
                              Positioned.fill(
                                child: GuideGestuel(
                                  activite: widget.activite,
                                  onCommencer: _commencerGuide,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  /// Le moteur de l'activité, plein cadre.
  Widget _zoneDeJeu(JeuController controleur) {
    final lexique = lexiquePour(context.read<Reglages>().deck);
    final afficherMots = controleur.niveau.afficherMots;

    return switch (widget.activite.moteur) {
      Moteur.tapPick => _zoneTapPick(controleur, lexique, afficherMots),
      Moteur.dropPlace => Padding(
        padding: const EdgeInsets.all(20),
        child: MoteurDepotPlace(
          manche: controleur.manche,
          lexique: lexique,
          afficherMots: afficherMots,
          rappels: controleur,
        ),
      ),
      Moteur.scene => MoteurScene(
        manche: controleur.manche,
        lexique: lexique,
        afficherMots: afficherMots,
        rappels: controleur,
        // Le moteur dit et attend lui-même la narration de sa première
        // étape : l'hôte ne parle pas au départ pour la scène.
        direNarrationDepart: true,
      ),
      // M5 : la séquence (histoire, recette, ordres), le mode « exécuter »
      // (le code de trois blocs) ou le mode « composer » (la chanson de
      // quatre cases), selon le payload de l'activité.
      Moteur.ordre => switch (widget.activite.payload) {
        PayloadCode() => MoteurCodeBlocs(
          manche: controleur.manche,
          lexique: lexique,
          rappels: controleur,
        ),
        PayloadComposer() => MoteurComposer(
          manche: controleur.manche,
          lexique: lexique,
          rappels: controleur,
          afficherMots: afficherMots,
        ),
        _ => Padding(
          padding: const EdgeInsets.all(20),
          child: MoteurOrdre(
            manche: controleur.manche,
            lexique: lexique,
            afficherMots: afficherMots,
            rappels: controleur,
          ),
        ),
      },
      // M7 « création » : la toile (peinture et miroir), le théâtre rejoué
      // ou l'atelier d'animaux inventés, selon le payload.
      Moteur.creation => switch (widget.activite.payload) {
        PayloadTheatre() => MoteurTheatre(
          manche: controleur.manche,
          lexique: lexique,
          rappels: controleur,
        ),
        PayloadAtelier() => MoteurAtelier(
          manche: controleur.manche,
          lexique: lexique,
          rappels: controleur,
          micro: _microPourLesJeux(context),
        ),
        _ => MoteurToile(
          manche: controleur.manche,
          lexique: lexique,
          rappels: controleur,
        ),
      },
      Moteur.trace => MoteurTrace(
        manche: controleur.manche,
        lexique: lexique,
        rappels: controleur,
      ),
      Moteur.balance => MoteurBalance(
        manche: controleur.manche,
        lexique: lexique,
        rappels: controleur,
      ),
      Moteur.rythme => MoteurRythme(
        manche: controleur.manche,
        lexique: lexique,
        rappels: controleur,
        afficherMots: afficherMots,
        micro: _microPourLesJeux(context),
      ),
      // Les moteurs des vagues suivantes n'ont pas encore de jeux au
      // catalogue : on ne les croise pas ici.
      _ => const Center(
        child: Text(
          'Bientôt !',
          style: TextStyle(fontSize: 28, color: Palette.encreDouce),
        ),
      ),
    };
  }

  Widget _zoneTapPick(JeuController controleur, lexique, bool afficherMots) {
    final tapPick = MoteurTapPick(
      manche: controleur.manche,
      options: controleur.optionsAffichees,
      lexique: lexique,
      afficherMots: afficherMots,
      derniereErreurId: controleur.derniereErreurId,
      montrerIndice: controleur.montrerIndice,
      derniereReussiteId: controleur.derniereReussiteId,
      onRepeter: controleur.repeterConsigne,
      onChoix: controleur.choisir,
    );

    if (_tours == null) {
      return Padding(padding: const EdgeInsets.all(24), child: tapPick);
    }
    // Mode « à tour de rôle » : un seul côté de l'écran répond.
    return MoteurTours(
      enfant: tapPick,
      tours: _tours!,
      lexique: lexique,
      rappels: controleur,
      clipsMonTour: _clipsMonTour,
      clipsAutreTour: _clipsAutreTour,
    );
  }

  Widget _fin(JeuController controleur) {
    final resume = controleur.resume;
    if (resume == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final collantsApres = _collantsGagnes(controleur.etatApres);
    final nouveaux = collantsApres - _collantsAvant;

    return FinDePartie(
      resume: resume,
      nouveauxCollants: nouveaux,
      onRejouer: _rejouer,
      onRetour: _quitter,
    );
  }
}
