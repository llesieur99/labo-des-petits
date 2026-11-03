/// Paramètres propres à un moteur, scellés par type.
///
/// Un payload ne contient jamais de contenu : seulement la façon de présenter.
/// Le contenu vit dans les manches (données).
sealed class Payload {
  const Payload();
}

/// Paramètres du moteur « toucher la bonne image parmi N » (M1).
class PayloadTapPick extends Payload {
  /// Vrai pour « À tour de rôle » : deux enfants, un seul doigt accepté,
  /// l'app annonce et alterne les tours.
  final bool tours;

  const PayloadTapPick({this.tours = false});
}

/// Paramètres du moteur « glisser-déposer » (M2).
class PayloadDropPlace extends Payload {
  /// Nombre maximum d'objets présentés à la fois dans la barre.
  final int objetsMax;

  const PayloadDropPlace({this.objetsMax = 6});
}

/// Paramètres du moteur « scène animée » (M4).
class PayloadScene extends Payload {
  const PayloadScene();
}

/// Paramètres du moteur « reconstruire une séquence » (M5).
class PayloadOrdre extends Payload {
  const PayloadOrdre();
}

/// Paramètres du moteur « toile » (M7a) : peinture et miroir.
class PayloadToile extends Payload {
  const PayloadToile();
}

/// Paramètres du moteur « théâtre » (M7b) : jouer, puis rejouer.
class PayloadTheatre extends Payload {
  const PayloadTheatre();
}

/// Paramètres du moteur « trace » (M3).
class PayloadTrace extends Payload {
  const PayloadTrace();
}

/// Paramètres du moteur « rythme » (M6).
class PayloadRythme extends Payload {
  const PayloadRythme();
}

/// Paramètres du moteur « atelier » (M7c) : inventer un animal.
class PayloadAtelier extends Payload {
  const PayloadAtelier();
}

/// Paramètres du moteur « ordre » en mode exécuter (code de blocs).
class PayloadCode extends Payload {
  const PayloadCode();
}

/// Paramètres du moteur « balance » (M9).
class PayloadBalance extends Payload {
  const PayloadBalance();
}

/// Paramètres du moteur « composer » (M5 mode chanson).
class PayloadComposer extends Payload {
  const PayloadComposer();
}
