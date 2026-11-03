import 'package:shared_preferences/shared_preferences.dart';

import '../audio/manifeste_audio.dart';
import '../contenu/modele/activite.dart';

/// Les réglages de l'app, en `shared_preferences` : tout ce qui n'est pas
/// la progression elle-même (qui vit en SQLite).
class Reglages {
  static const _cleDeck = 'deck';
  static const _cleVoix = 'voix';
  static const _cleMicro = 'microAutorise';
  static const _cleProfilActif = 'profilActif';
  static const _cleRespecterSilencieux = 'respecterSilencieux';

  final SharedPreferences _prefs;

  Reglages(this._prefs);

  static Future<Reglages> charger() async =>
      Reglages(await SharedPreferences.getInstance());

  bool guideVu(int profilId, String geste) =>
      _prefs.getBool('guide.v1.$profilId.$geste') ?? false;

  Future<void> marquerGuideVu(int profilId, String geste) =>
      _prefs.setBool('guide.v1.$profilId.$geste', true);

  // ── Deck (Québec / France) ──
  Deck get deck {
    final id = _prefs.getString(_cleDeck) ?? Deck.qc.id;
    return Deck.values.firstWhere((d) => d.id == id, orElse: () => Deck.qc);
  }

  Future<void> setDeck(Deck deck) => _prefs.setString(_cleDeck, deck.id);

  // ── Voix (Antoine par défaut, Sylvie au choix — décision LP 2026-10-16) ──
  String get voix => _prefs.getString(_cleVoix) ?? VoixDisponibles.defaut;

  Future<void> setVoix(String voix) => _prefs.setString(_cleVoix, voix);

  // ── Micro (toujours accordé par le parent depuis son espace) ──
  /// Vrai si le parent a autorisé les jeux à enregistrer la voix.
  /// La permission iOS est demandée en plus, au moment de l'activation.
  bool get microAutorise => _prefs.getBool(_cleMicro) ?? false;

  Future<void> setMicroAutorise(bool valeur) =>
      _prefs.setBool(_cleMicro, valeur);

  // ── Dernier profil utilisé ──
  int? get profilActifId => _prefs.getInt(_cleProfilActif);

  Future<void> setProfilActif(int profilId) =>
      _prefs.setInt(_cleProfilActif, profilId);

  // ── Mode silencieux ──
  /// Faux par défaut : l'app parle même si le téléphone est en silencieux.
  bool get respecterSilencieux =>
      _prefs.getBool(_cleRespecterSilencieux) ?? false;

  Future<void> setRespecterSilencieux(bool valeur) =>
      _prefs.setBool(_cleRespecterSilencieux, valeur);

  // ── Limite de temps quotidienne, par enfant (0 = illimité) ──
  int limiteMinutes(int profilId) => _prefs.getInt('limite.$profilId') ?? 0;

  Future<void> setLimiteMinutes(int profilId, int minutes) =>
      _prefs.setInt('limite.$profilId', minutes);

  /// Minutes déjà jouées aujourd'hui par cet enfant (remises à zéro à minuit).
  int minutesAujourdhui(int profilId) {
    final jour = _prefs.getString('jour.$profilId');
    if (jour != _aujourdHui) return 0;
    return _prefs.getInt('minutes.$profilId') ?? 0;
  }

  Future<void> ajouterMinutes(int profilId, int minutes) async {
    final deja = minutesAujourdhui(profilId);
    await _prefs.setString('jour.$profilId', _aujourdHui);
    await _prefs.setInt('minutes.$profilId', deja + minutes);
  }

  Future<void> remettreTempsAZero(int profilId) async {
    await _prefs.remove('minutes.$profilId');
    await _prefs.remove('jour.$profilId');
  }

  /// Vrai si l'enfant a encore le droit de jouer.
  bool peutJouer(int profilId) {
    final limite = limiteMinutes(profilId);
    if (limite <= 0) return true;
    return minutesAujourdhui(profilId) < limite;
  }

  String get _aujourdHui {
    final maintenant = DateTime.now();
    return '${maintenant.year}-${maintenant.month}-${maintenant.day}';
  }
}
