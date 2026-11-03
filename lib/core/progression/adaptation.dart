import '../contenu/modele/activite.dart';
import 'modele.dart';

/// Les règles d'adaptation — douces, invisibles, testables.
///
/// Principes :
///  - la montée se décide en FIN de partie, jamais en cours ;
///  - la descente commence par des aides, pas par une baisse de niveau ;
///  - on ne descend jamais sous le niveau 1, et jamais de palier tout seul ;
///  - rien de tout ça n'est montré à l'enfant.
abstract final class AdaptationDouce {
  /// Nombre de résumés de partie conservés par activité.
  static const maxHistorique = 6;

  /// Seuil de « partie forte » (montée après 2 de suite).
  static const seuilFort = 0.8;

  /// Seuil de « partie faible » (aides puis descente).
  static const seuilFaible = 0.45;

  /// Nombre de parties faibles de suite avant de baisser le niveau
  /// (quand les aides ont déjà été ajoutées).
  static const partiesFaiblesAvantBaisse = 3;

  /// Ordre d'ajout des aides : d'abord redire la consigne, puis réduire
  /// le nombre de choix. On n'en ajoute pas plus de deux.
  static const ordreAides = [Aide.consigneRepetee, Aide.moinsDeChoix];

  /// L'état de départ pour un couple profil × activité.
  static EtatActivite etatInitial({
    required int profilId,
    required String activiteId,
    required Palier palier,
    bool depuisParent = false,
  }) => EtatActivite(
    profilId: profilId,
    activiteId: activiteId,
    palier: palier,
    niveau: 1,
    aides: const [],
    historique: const [],
    depuisParent: depuisParent,
    majLe: DateTime.now(),
  );

  /// L'état après une partie : ce que l'app enregistre.
  ///
  /// [nbNiveaux] : le nombre de niveaux (variantes) disponibles pour ce palier,
  /// pour ne pas monter au-delà.
  static EtatActivite apresPartie(
    EtatActivite etat,
    ResumePartie partie, {
    required int nbNiveaux,
  }) {
    var niveau = etat.niveau;
    var aides = List<Aide>.from(etat.aides);

    final historique = List<ResumePartie>.from(etat.historique)..add(partie);
    if (historique.length > maxHistorique) {
      historique.removeRange(0, historique.length - maxHistorique);
    }

    final dernieres = historique;
    final deuxFortesDeSuite =
        dernieres.length >= 2 &&
        dernieres[dernieres.length - 1].taux >= seuilFort &&
        dernieres[dernieres.length - 2].taux >= seuilFort;

    final faiblesDeSuite = _compterFaiblesDeSuite(dernieres);

    if (deuxFortesDeSuite && niveau < nbNiveaux) {
      // On monte d'un cran et on repart sans aides : nouveau défi.
      niveau += 1;
      aides = [];
      historique.clear();
    } else if (faiblesDeSuite >= partiesFaiblesAvantBaisse &&
        aides.length >= ordreAides.length) {
      // La partie reste difficile même avec toutes les aides : on redescend.
      if (niveau > 1) {
        niveau -= 1;
        historique.clear();
      }
      aides = [ordreAides.first];
    } else if (faiblesDeSuite >= 1 &&
        aides.length < ordreAides.length &&
        partie.taux <= seuilFaible) {
      // Première difficulté : on ajoute une aide, on ne baisse pas le niveau.
      aides.add(ordreAides[aides.length]);
    }

    return etat.copieAvec(
      niveau: niveau,
      aides: aides,
      historique: historique,
      partiesJouees: etat.partiesJouees + 1,
      meilleureEtoile: partie.etoiles > etat.meilleureEtoile
          ? partie.etoiles
          : etat.meilleureEtoile,
      depuisParent: false,
      majLe: DateTime.now(),
    );
  }

  static int _compterFaiblesDeSuite(List<ResumePartie> historique) {
    var compte = 0;
    for (var i = historique.length - 1; i >= 0; i--) {
      if (historique[i].taux <= seuilFaible) {
        compte++;
      } else {
        break;
      }
    }
    return compte;
  }
}
