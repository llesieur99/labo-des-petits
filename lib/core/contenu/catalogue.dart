import 'activites/autonomie/couper_data.dart';
import 'activites/autonomie/mains_data.dart';
import 'activites/autonomie/ranger_data.dart';
import 'activites/autonomie/recette_data.dart';
import 'activites/autonomie/sac_data.dart';
import 'activites/autonomie/table_data.dart';
import 'activites/autonomie/traverser_data.dart';
import 'activites/creation/animal_invente_data.dart';
import 'activites/creation/chanson_data.dart';
import 'activites/creation/papillon_data.dart';
import 'activites/creation/peinture_data.dart';
import 'activites/creation/rythme_data.dart';
import 'activites/creation/sons_hauteur_data.dart';
import 'activites/creation/theatre_data.dart';
import 'activites/emotions/milo_data.dart';
import 'activites/emotions/monstre_data.dart';
import 'activites/emotions/mots_demander_data.dart';
import 'activites/emotions/tours_data.dart';
import 'activites/langue/bouche_sons_data.dart';
import 'activites/langue/lettre_data.dart';
import 'activites/langue/mot_cache_data.dart';
import 'activites/langue/phrase_data.dart';
import 'activites/langue/rimes_data.dart';
import 'activites/langue/syllabes_data.dart';
import 'activites/logique/chemin_data.dart';
import 'activites/logique/code_data.dart';
import 'activites/logique/histoire_data.dart';
import 'activites/logique/intrus_data.dart';
import 'activites/logique/manque_data.dart';
import 'activites/logique/ordres_data.dart';
import 'activites/logique/si_alors_data.dart';
import 'activites/maths/balance_data.dart';
import 'activites/maths/bus_data.dart';
import 'activites/maths/formes_data.dart';
import 'activites/maths/gateau_data.dart';
import 'activites/maths/grenouille_data.dart';
import 'activites/maths/heure_data.dart';
import 'activites/maths/perles_data.dart';
import 'activites/maths/plus_moins_data.dart';
import 'activites/monde/cinq_sens_data.dart';
import 'activites/monde/fenetre_data.dart';
import 'activites/monde/flotte_data.dart';
import 'activites/monde/graine_data.dart';
import 'activites/monde/habiller_data.dart';
import 'activites/monde/jour_nuit_data.dart';
import 'activites/monde/ombres_data.dart';
import 'activites/monde/petit_maison_data.dart';
import 'activites/monde/spatial_data.dart';
import 'lexique/lexique_fr.dart';
import 'lexique/lexique_qc.dart';
import 'modele/activite.dart';
import 'modele/lexique.dart';

/// Toutes les activités de l'app : les 48 du catalogue, au complet. L'ordre du catalogue est l'ordre d'affichage dans une famille.
final catalogueActivites = <Activite>[
  // Langue française
  activiteRimes,
  activiteBoucheSons,
  activiteSyllabes,
  activiteMotCache,
  activitePhrase,
  activiteLettre,
  // Mathématiques
  activiteBus,
  activiteBalance,
  activiteGateau,
  activitePerles,
  activiteGrenouille,
  activitePlusMoins,
  activiteFormes,
  activiteHeure,
  // Logique et attention
  activiteIntrus,
  activiteHistoire,
  activiteManque,
  activiteSiAlors,
  activiteChemin,
  activiteCode,
  activiteOrdres,
  // Monde et sciences
  activiteCinqSens,
  activiteFlotte,
  activiteGraine,
  activiteHabiller,
  activiteJourNuit,
  activiteOmbres,
  activitePetitMaison,
  activiteSpatial,
  activiteFenetre,
  // Émotions et vie avec les autres
  activiteMilo,
  activiteTours,
  activiteMonstre,
  activiteMotsDemander,
  // Musique, geste, création
  activitePeinture,
  activitePapillon,
  activiteTheatre,
  activiteRythme,
  activiteAnimalInvente,
  activiteChanson,
  activiteHauteur,
  // Autonomie
  activiteTable,
  activiteSac,
  activiteCouper,
  activiteMains,
  activiteRecette,
  activiteRanger,
  activiteTraverser,
];

/// Les activités d'une famille.
List<Activite> activitesDe(Famille famille) =>
    catalogueActivites.where((a) => a.famille == famille).toList();

/// L'activité d'un identifiant, ou null.
Activite? activiteParId(String id) {
  for (final activite in catalogueActivites) {
    if (activite.id == id) return activite;
  }
  return null;
}

/// Le lexique d'un deck.
Lexique lexiquePour(Deck deck) => switch (deck) {
      Deck.qc => lexiqueQc,
      Deck.fr => lexiqueFr,
    };
