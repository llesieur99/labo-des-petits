import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/audio/say_kit.dart';
import '../../core/contenu/modele/activite.dart';
import '../../core/contenu/modele/manche.dart';
import '../../core/contenu/preparer_partie.dart';
import '../../core/moteurs/rappels_moteur.dart';
import '../../core/progression/adaptation.dart';
import '../../core/progression/depot.dart';
import '../../core/progression/modele.dart';

/// Pilote une partie : dit les consignes, écoute les choix, encourage,
/// enregistre les résultats et applique l'adaptation douce.
///
/// Tout est pensé pour un enfant qui ne lit pas : la voix fait le travail,
/// les erreurs ne sont jamais punies (on retire un choix, on redit), et
/// la consigne se redit toute seule si l'enfant hésite.
///
/// Deux façons pour un moteur de travailler :
///  - M1 touche une option → il appelle [choisir], l'hôte compare ;
///  - les autres moteurs gèrent leur logique et racontent via [RappelsMoteur].
class JeuController extends ChangeNotifier
    implements RappelsMoteur, ConsigneContextuelle, HorlogeMoteur {
  final Activite activite;
  final Niveau niveau;
  final EtatActivite etat;
  final SayKit say;
  final DepotProgression depot;
  final Random alea;

  /// Pause entre deux items (réduite à zéro dans les tests).
  final Duration delaiEntreItems;

  JeuController({
    required this.activite,
    required this.niveau,
    required this.etat,
    required this.say,
    required this.depot,
    Random? alea,
    Set<String> manchesRecentes = const {},
    this.delaiEntreItems = const Duration(milliseconds: 850),
  }) : alea = alea ?? Random() {
    _manches = preparerPartie(
      activite,
      niveau,
      this.alea,
      manchesRecentes: manchesRecentes,
    );
  }

  late final List<Manche> _manches;
  int _index = 0;
  int _erreursItem = 0;
  int _reussisPremierCoup = 0;
  final Set<String> _leurresRetires = {};
  final Map<String, DateTime> _debutItem = {};
  String? _derniereErreurId;
  String? _derniereReussiteId;
  bool _enTransition = false;
  bool _enRetourErreur = false;
  bool _dispose = false;
  bool _fini = false;
  bool _enConsigne = false;
  bool _enPause = false;
  Completer<void>? _reprise;
  final Set<String> _annoncees = {};
  Object? _proprietaireConsigne;
  Future<void> Function()? _consigneMoteur;
  int _rappelsAuto = 0;
  int _interruption = 0;
  int _voixEnCours = 0;

  @override
  bool get enPause => _enPause;
  bool get manchePrete => _annoncees.contains(manche.id);
  bool get interactionPossible =>
      !_occupe && !_enConsigne && !_enPause && manchePrete;
  bool get montrerIndice =>
      _erreursItem >= 2 ||
      (_erreursItem > 0 &&
          (etat.aides.contains(Aide.indiceVisuel) ||
              niveau.aides.contains(Aide.indiceVisuel)));

  @override
  void enregistrerConsigne(
    Object proprietaire,
    Future<void> Function() repeter,
  ) {
    _proprietaireConsigne = proprietaire;
    _consigneMoteur = repeter;
  }

  @override
  void retirerConsigne(Object proprietaire) {
    if (_proprietaireConsigne == proprietaire) {
      _proprietaireConsigne = null;
      _consigneMoteur = null;
    }
  }

  void suspendre() {
    if (_dispose || _enPause) return;
    _enPause = true;
    _interruption++;
    _reprise = Completer<void>();
    _chronoInactivite?.cancel();
    unawaited(say.stopper());
    notifyListeners();
  }

  Future<void> reprendre() async {
    if (_dispose || !_enPause) return;
    _enPause = false;
    _reprise?.complete();
    _reprise = null;
    notifyListeners();
    if (!_occupe && !_enConsigne && !_fini && _voixEnCours == 0) {
      await _direConsigne();
    }
  }

  Future<void> _attendreReprise() async {
    if (_enPause) await _reprise?.future;
  }

  bool get _occupe => _dispose || _fini || _enTransition || _enRetourErreur;
  Timer? _chronoInactivite;
  ResumePartie? _resume;
  EtatActivite? _etatApres;

  /// Durée d'inactivité avant que la consigne se redise toute seule.
  static const delaiInactivite = Duration(seconds: 10);

  Manche get manche => _manches[_index];
  int get itemsFaits => _index;
  int get itemsTotal => _manches.length;
  bool get fini => _fini;
  String? get derniereReussiteId => _derniereReussiteId;
  String? get derniereErreurId => _derniereErreurId;
  ResumePartie? get resume => _resume;
  EtatActivite? get etatApres => _etatApres;

  /// Les options affichées : la manche, moins les leurres retirés en aide
  /// (moteur M1 seulement).
  List<OptionManche> get optionsAffichees {
    final visibles = manche.options
        .where((o) => !_leurresRetires.contains(o.id))
        .toList();
    if (etat.aides.contains(Aide.moinsDeChoix)) {
      while (visibles.length > activite.choixMinimum) {
        final leurre = visibles.lastWhere((o) => o.id != manche.bonneOptionId);
        visibles.remove(leurre);
      }
    }
    return visibles;
  }

  /// Lance la partie : dit la première consigne.
  ///
  /// Pour le moteur « scène animée » (M4), l'hôte ne parle PAS au départ :
  /// le moteur dit lui-même la narration de sa première étape, et l'attend.
  /// Deux voix en parallèle se couperaient.
  Future<void> demarrer() async {
    if (_occupe) return;
    _debutItem[manche.id] = DateTime.now();
    notifyListeners();
    if (activite.moteur == Moteur.scene) {
      _annoncees.add(manche.id);
      notifyListeners();
      return;
    }
    await _direConsigne();
  }

  /// Redit la consigne (bouton « Répète » ou inactivité).
  Future<void> repeterConsigne() async {
    if (_occupe || _enPause || _enConsigne) return;
    _chronoInactivite?.cancel();
    await dire('consigne.repete');
    if (_occupe) return;
    await _direConsigne();
  }

  /// L'enfant a touché une option (moteur M1).
  Future<void> choisir(OptionManche option) async {
    if (!interactionPossible) return;
    if (!optionsAffichees.any((o) => o.id == option.id)) return;
    _chronoInactivite?.cancel();

    if (option.id == manche.bonneOptionId) {
      await _reussirItem();
      return;
    }

    _derniereErreurId = option.id;
    await _raterEssai();
    if (_dispose) return;
    // Aide en séance (M1 seulement) : après deux erreurs, on retire un choix.
    if (_erreursItem >= 2) _retirerUnLeurre();
    _derniereErreurId = null;
    notifyListeners();
  }

  // ── RappelsMoteur : ce que les moteurs M2, M4, M5 racontent ──

  @override
  void itemReussi() {
    // Les moteurs gèrent leurs touches : une réussite reste valable même
    // si l’encouragement du dernier essai est encore en cours.
    if (_dispose || _fini || _enTransition) return;
    _chronoInactivite?.cancel();
    _reussirItem();
  }

  @override
  void essaiRate() {
    if (_occupe) return;
    _chronoInactivite?.cancel();
    _raterEssai();
  }

  @override
  Future<void> dire(String clipId) => _jouerVoix(() => say.dire(clipId));

  Future<void> _jouerVoix(Future<void> Function() lire) async {
    _voixEnCours++;
    try {
      while (!_dispose) {
        await _attendreReprise();
        if (_dispose) return;
        final interruption = _interruption;
        await lire();
        await _attendreReprise();
        if (interruption == _interruption) return;
      }
    } finally {
      _voixEnCours--;
    }
  }

  @override
  Future<void> attendre(Duration duree) async {
    var restant = duree.inMilliseconds;
    while (restant > 0 && !_dispose) {
      await _attendreReprise();
      if (_dispose) return;
      final pas = min(restant, 100);
      await Future<void>.delayed(Duration(milliseconds: pas));
      if (!_enPause) restant -= pas;
    }
  }

  @override
  Future<void> jouerSon(String asset) async {
    if (_dispose || _enPause) return;
    await say.jouerAsset(asset);
  }

  /// À appeler quand l'écran se ferme : coupe la voix et le chrono.
  @override
  void dispose() {
    _dispose = true;
    _reprise?.complete();
    _reprise = null;
    _chronoInactivite?.cancel();
    unawaited(say.stopper());
    super.dispose();
  }

  Future<void> _reussirItem() async {
    // Verrouiller avant la sauvegarde : plusieurs touches peuvent arriver
    // pendant que SQLite travaille.
    _enTransition = true;
    _derniereReussiteId = manche.bonneOptionId;
    notifyListeners();
    try {
      await _attendreReprise();
      if (_dispose) return;
      final premierCoup = _erreursItem == 0;
      final debut = _debutItem[manche.id] ?? DateTime.now();
      await depot.enregistrerEvenement(
        Evenement(
          profilId: etat.profilId,
          activiteId: activite.id,
          itemId: manche.id,
          correctDuPremierCoup: premierCoup,
          dureeMs: DateTime.now().difference(debut).inMilliseconds,
          palier: etat.palier,
          niveau: etat.niveau,
          horodatage: DateTime.now(),
        ),
      );

      if (_dispose) return;
      if (premierCoup) _reussisPremierCoup++;
      notifyListeners();
      if (activite.moteur == Moteur.tapPick) {
        await dire('lex.${manche.bonneOption.concept}');
        if (_dispose) return;
        if (manche.explicationCle != null) await dire(manche.explicationCle!);
      }
      if (_dispose) return;
      await dire(_auHasard(_bravos));
      if (_dispose) return;
      await Future<void>.delayed(delaiEntreItems);
      await _attendreReprise();
      if (_dispose) return;
      await _itemSuivant();
    } finally {
      _enTransition = false;
      if (!_dispose) notifyListeners();
    }
  }

  Future<void> _raterEssai() async {
    _enRetourErreur = true;
    final index = _index;
    bool annule() => _dispose || _fini || _enTransition || _index != index;
    try {
      // Erreur : jamais de reproche, jamais de rouge alarmant.
      _erreursItem++;
      notifyListeners();
      await dire(_auHasard(_encore));
      await _attendreReprise();
      if (annule()) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (annule()) return;
      notifyListeners();
      await _direConsigne();
    } finally {
      _enRetourErreur = false;
      if (!_dispose) notifyListeners();
    }
  }

  Future<void> _direConsigne() async {
    await _attendreReprise();
    if (_dispose || _fini) return;
    _enConsigne = true;
    notifyListeners();
    try {
      final contextuelle = _consigneMoteur;
      if (contextuelle != null) {
        await contextuelle();
      } else {
        await _jouerVoix(() => say.direSequence(manche.clipsConsigne));
      }
      await _attendreReprise();
      if (!_dispose) _annoncees.add(manche.id);
    } finally {
      _enConsigne = false;
      if (!_dispose) {
        notifyListeners();
        _armerChronoInactivite();
      }
    }
  }

  void _armerChronoInactivite() {
    // Un seul rappel, réservé au choix d'images : pas de narration qui
    // coupe une peinture, une histoire ou un rythme en cours.
    _chronoInactivite?.cancel();
    if (_enPause ||
        _fini ||
        _rappelsAuto > 0 ||
        activite.moteur != Moteur.tapPick) {
      return;
    }
    _chronoInactivite = Timer(delaiInactivite, () {
      if (interactionPossible) {
        _rappelsAuto++;
        _direConsigne();
      }
    });
  }

  void _retirerUnLeurre() {
    final retirables = optionsAffichees
        .where((o) => o.id != manche.bonneOptionId)
        .toList();
    // Certains jeux, comme les intrus, ont besoin de deux exemples
    // de la famille en plus de la réponse.
    if (optionsAffichees.length > activite.choixMinimum) {
      _leurresRetires.add(retirables.first.id);
      notifyListeners();
    }
  }

  Future<void> _itemSuivant() async {
    if (_index >= _manches.length - 1) {
      await _terminer();
      return;
    }
    _index++;
    _consigneMoteur = null;
    _proprietaireConsigne = null;
    _rappelsAuto = 0;
    if (activite.moteur == Moteur.scene) _annoncees.add(manche.id);
    _erreursItem = 0;
    _derniereErreurId = null;
    _derniereReussiteId = null;
    _leurresRetires.clear();
    _debutItem[manche.id] = DateTime.now();
    notifyListeners();
    if (activite.moteur != Moteur.scene) await _direConsigne();
  }

  Future<void> _terminer() async {
    _chronoInactivite?.cancel();

    final resume = ResumePartie(
      items: _manches.length,
      reussisDuPremierCoup: _reussisPremierCoup,
    );
    _resume = resume;

    final nbNiveaux = activite.etapesPour(etat.palier).length;
    _etatApres = AdaptationDouce.apresPartie(
      etat,
      resume,
      nbNiveaux: nbNiveaux < 1 ? 1 : nbNiveaux,
    );
    await depot.enregistrerEtat(_etatApres!);
    if (_dispose) return;
    _fini = true;
    notifyListeners();
    await dire(_auHasard(_fins));
  }

  String _auHasard(List<String> ids) => ids[alea.nextInt(ids.length)];

  static const _bravos = [
    'retour.bravo.1',
    'retour.bravo.2',
    'retour.bravo.3',
    'retour.bravo.4',
    'retour.bravo.5',
  ];

  static const _encore = [
    'retour.encore.1',
    'retour.encore.2',
    'retour.encore.3',
  ];

  static const _fins = ['retour.fin.1', 'retour.fin.2'];
}
