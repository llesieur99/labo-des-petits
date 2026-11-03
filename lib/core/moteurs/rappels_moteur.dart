/// Ce qu'un moteur dit à son hôte (le contrôleur de partie).
///
/// Le moteur ne décide de RIEN : il dessine, écoute les doigts, et raconte
/// ce qui vient de se passer. C'est l'hôte qui encourage, redit, avance,
/// enregistre la progression — et c'est pour ça qu'aucun moteur n'a besoin
/// de connaître la pédagogie.
abstract class RappelsMoteur {
  /// L'item (la manche) est terminé et réussi.
  void itemReussi();

  /// Un essai raté — jamais grave, jamais puni : l'hôte encourage et redit.
  void essaiRate();

  /// Dire un clip (nommer un objet, saluer un tour…).
  Future<void> dire(String clipId);

  /// Joue un son NON VERBAL (tambour, note, grelot) : un asset de
  /// `assets/audio/neutre/sons/`, pas un clip de voix.
  Future<void> jouerSon(String asset);
}

/// Facultatif : un moteur peut fournir la consigne de son étape courante.
abstract interface class ConsigneContextuelle implements RappelsMoteur {
  void enregistrerConsigne(
    Object proprietaire,
    Future<void> Function() repeter,
  );
  void retirerConsigne(Object proprietaire);
}

abstract interface class HorlogeMoteur implements RappelsMoteur {
  bool get enPause;
  Future<void> attendre(Duration duree);
}

bool moteurEnPause(RappelsMoteur rappels) =>
    rappels is HorlogeMoteur && rappels.enPause;

Future<void> attendreMoteur(RappelsMoteur rappels, Duration duree) =>
    rappels is HorlogeMoteur
    ? rappels.attendre(duree)
    : Future<void>.delayed(duree);
