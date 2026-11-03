import '../contenu/modele/activite.dart';
import '../contenu/modele/payloads_moteurs.dart';

enum GesteGuide {
  toucher,
  poser,
  tracer,
  scene,
  ordonner,
  programmer,
  composer,
  rythme,
  peindre,
  theatre,
  assembler,
  equilibrer,
}

GesteGuide gestePour(Activite activite) => switch (activite.payload) {
  PayloadCode() => GesteGuide.programmer,
  PayloadComposer() => GesteGuide.composer,
  PayloadTheatre() => GesteGuide.theatre,
  PayloadAtelier() => GesteGuide.assembler,
  _ => switch (activite.moteur) {
    Moteur.tapPick => GesteGuide.toucher,
    Moteur.dropPlace => GesteGuide.poser,
    Moteur.trace => GesteGuide.tracer,
    Moteur.scene => GesteGuide.scene,
    Moteur.ordre => GesteGuide.ordonner,
    Moteur.rythme => GesteGuide.rythme,
    Moteur.balance => GesteGuide.equilibrer,
    _ => GesteGuide.peindre,
  },
};

class FicheActivite {
  final String objectif;
  final String commentJouer;
  final String accompagner;
  const FicheActivite(this.objectif, this.commentJouer, this.accompagner);
}

/// Informations pour l'adulte, uniquement locales et sans nouvelle activité.
const fichesActivites = <String, FicheActivite>{
  "rimes": FicheActivite(
    "Entendre les sons à la fin des mots.",
    "Écouter le mot puis toucher l’image qui rime.",
    "Redire les deux mots sans insister sur leur orthographe.",
  ),
  "bouche": FicheActivite(
    "Explorer les sons de la bouche sans être évalué.",
    "Écouter, imiter puis toucher la coche ou le micro autorisé.",
    "Imiter avec l’enfant ; le micro est facultatif et aucune voix n’est notée.",
  ),
  "syllabes": FicheActivite(
    "Entendre les morceaux d’un mot.",
    "Regarder les sauts puis taper une fois par syllabe.",
    "Dire le mot lentement et frapper ses syllabes dans les mains.",
  ),
  "motcache": FicheActivite(
    "Reconnaître le premier son d’un mot.",
    "Écouter le son puis choisir une image.",
    "Nommer les images en accentuant doucement leur premier son.",
  ),
  "phrase": FicheActivite(
    "Construire une phrase dans le bon ordre.",
    "Toucher une image puis la case où la poser.",
    "Décrire qui fait quoi, puis écouter ensemble la phrase obtenue.",
  ),
  "lettre": FicheActivite(
    "Se familiariser avec le geste des lettres.",
    "Suivre le ruban avec le doigt, en plusieurs gestes si nécessaire.",
    "Montrer le départ ; un doigt levé ne fait pas perdre le tracé acquis.",
  ),
  "bus": FicheActivite(
    "Dénombrer et suivre une quantité.",
    "Observer le bus puis toucher la réponse.",
    "Pointer les passagers un par un avant de choisir.",
  ),
  "balance": FicheActivite(
    "Comparer des quantités et construire une égalité.",
    "Toucher un fruit puis un plateau ; toucher un plateau main vide pour reprendre.",
    "Compter les fruits de chaque côté et essayer de nouveau librement.",
  ),
  "gateau": FicheActivite(
    "Découvrir le partage équitable.",
    "Écouter la situation puis choisir une proposition.",
    "Comparer les parts sans introduire de notation de fractions.",
  ),
  "perles": FicheActivite(
    "Repérer une répétition et la poursuivre.",
    "Observer le motif puis choisir la perle suivante.",
    "Nommer les couleurs du motif à voix haute, dans l’ordre.",
  ),
  "grenouille": FicheActivite(
    "Repérer des déplacements sur une ligne de nombres.",
    "Écouter le saut demandé puis toucher la destination.",
    "Compter les bonds plutôt que seulement le nombre d’arrivée.",
  ),
  "plusmoins": FicheActivite(
    "Comparer deux collections.",
    "Observer les deux groupes et choisir selon la consigne.",
    "Associer mentalement un objet de gauche à un objet de droite.",
  ),
  "formes": FicheActivite(
    "Reconnaître une forme indépendamment de sa place.",
    "Toucher une forme puis son emplacement.",
    "Suivre le contour avec le doigt avant de choisir.",
  ),
  "heure": FicheActivite(
    "Repérer les heures et les demi-heures.",
    "Observer les aiguilles et toucher la bonne réponse.",
    "Distinguer la petite aiguille de la grande, sans demander la vitesse.",
  ),
  "intrus": FicheActivite(
    "Trouver ce qui ne va pas avec un groupe.",
    "Nommer les images puis toucher l’intrus.",
    "Chercher ce que les autres images ont en commun.",
  ),
  "histoire": FicheActivite(
    "Ordonner une petite histoire.",
    "Toucher les images dans l’ordre des cases à remplir.",
    "Demander ce qui arrive au début, puis après, puis à la fin.",
  ),
  "manque": FicheActivite(
    "Observer et mémoriser un changement.",
    "Regarder la scène puis choisir l’élément disparu.",
    "Laisser le temps d’observer avant le changement.",
  ),
  "sialors": FicheActivite(
    "Relier une situation à une conséquence.",
    "Écouter la situation puis choisir ce qui suit.",
    "Laisser l’enfant expliquer son choix avec ses mots.",
  ),
  "chemin": FicheActivite(
    "Guider son geste sur un parcours.",
    "Suivre le ruban au doigt.",
    "Faire une pause puis reprendre au même endroit ; la précision esthétique n’est pas jugée.",
  ),
  "code": FicheActivite(
    "Préparer puis vérifier une suite de commandes.",
    "Poser les blocs, lancer le programme et corriger si nécessaire.",
    "Faire jouer le programme avec son doigt avant le bouton vert ; le ramassage compte comme un bloc.",
  ),
  "ordres": FicheActivite(
    "Retenir une courte suite d’actions.",
    "Écouter puis toucher les images dans l’ordre demandé.",
    "Redire les actions dans le même ordre sans en ajouter.",
  ),
  "sens": FicheActivite(
    "Relier une expérience au sens qui aide à la percevoir.",
    "Écouter puis choisir l’image.",
    "Donner un exemple vécu ; une situation peut mobiliser plusieurs sens.",
  ),
  "flotte": FicheActivite(
    "Formuler une prévision et observer un résultat.",
    "Choisir ce qu’on prévoit puis regarder ce qui arrive.",
    "Parler de la forme et de la matière sans présenter le poids comme seule explication.",
  ),
  "graine": FicheActivite(
    "Observer les besoins d’une plante.",
    "Choisir l’action qui aide la plante à l’étape actuelle.",
    "Rappeler que les transformations sont accélérées dans le jeu.",
  ),
  "habiller": FicheActivite(
    "Trier des vêtements selon une situation.",
    "Toucher un vêtement puis le bac correspondant.",
    "Relier les vêtements à la météo et au confort, sans jugement sur les habitudes.",
  ),
  "journuit": FicheActivite(
    "Repérer les changements entre jour et nuit.",
    "Observer la scène et suivre les choix proposés.",
    "Comparer avec un moment familier de la journée.",
  ),
  "ombres": FicheActivite(
    "Observer le lien entre lumière, objet et ombre.",
    "Suivre la scène et choisir selon la consigne.",
    "Reproduire ensuite avec une lampe si cela intéresse l’enfant.",
  ),
  "petit": FicheActivite(
    "Associer un animal à son milieu.",
    "Toucher l’animal puis son emplacement.",
    "Nommer les indices du milieu avant de donner la réponse.",
  ),
  "spatial": FicheActivite(
    "Comprendre les positions dans l’espace.",
    "Observer le chat et choisir la position demandée.",
    "Se placer soi-même devant, derrière ou à côté d’un objet.",
  ),
  "fenetre": FicheActivite(
    "Décrire une scène météo.",
    "Observer le décor puis choisir la réponse.",
    "La scène est imaginaire : l’application ne connaît pas la météo réelle.",
  ),
  "milo": FicheActivite(
    "Reconnaître une émotion dans une situation.",
    "Écouter la scène et choisir ce qui convient à Milo.",
    "Accueillir une autre interprétation et parler des indices du visage.",
  ),
  "tours": FicheActivite(
    "Attendre et reconnaître son tour.",
    "Répondre du côté actif puis laisser l’autre enfant jouer.",
    "Nommer calmement le tour ; le côté qui attend ne perd rien.",
  ),
  "monstre": FicheActivite(
    "Expérimenter un rythme lent.",
    "Toucher le monstre avec des pauses entre les gestes.",
    "Respirer ensemble ; les gestes rapides ne retirent pas les réussites acquises.",
  ),
  "mots": FicheActivite(
    "Découvrir des mots pour exprimer un besoin.",
    "Écouter la situation puis choisir une réponse.",
    "Reprendre la formulation dans une situation du quotidien.",
  ),
  "peinture": FicheActivite(
    "Expérimenter les mélanges de couleurs.",
    "Choisir une couleur puis peindre ; superposer pour mélanger.",
    "Nommer le mélange observé et laisser explorer librement.",
  ),
  "papillon": FicheActivite(
    "Explorer la symétrie.",
    "Choisir une couleur et peindre l’aile de gauche.",
    "Montrer comment le geste se retrouve de l’autre côté.",
  ),
  "theatre": FicheActivite(
    "Inventer et rejouer une petite scène.",
    "Toucher un personnage puis un endroit de la scène, ou le déplacer au doigt ; rejouer ensuite.",
    "Laisser l’enfant raconter ; seuls les gestes de la scène sont rejoués, sans captation vidéo.",
  ),
  "rythme": FicheActivite(
    "Écouter et accompagner une pulsation.",
    "Toucher le tambour au rythme entendu.",
    "Jouer avec l’enfant ; le tempo s’adapte, aucune erreur n’est reprochée.",
  ),
  "animal": FicheActivite(
    "Assembler et raconter une création personnelle.",
    "Choisir les morceaux, donner un nom puis une nourriture.",
    "Toutes les inventions sont acceptées ; l’enregistrement du nom est facultatif.",
  ),
  "chanson": FicheActivite(
    "Composer une courte suite de sons.",
    "Choisir des sons pour les cases puis lancer la boucle.",
    "Écouter la composition ; toucher une case permet de la changer.",
  ),
  "hauteur": FicheActivite(
    "Distinguer hauteur et intensité d’un son.",
    "Écouter puis choisir l’image associée.",
    "Comparer aigu et grave séparément de fort et doux.",
  ),
  "table": FicheActivite(
    "Associer les objets à leur place.",
    "Toucher un objet puis un emplacement libre.",
    "Nommer les objets et pointer les places disponibles.",
  ),
  "sac": FicheActivite(
    "Préparer des objets selon un besoin.",
    "Toucher un objet puis son bac.",
    "Relier la situation au sac de l’enfant, sans exiger les mêmes objets à la maison.",
  ),
  "couper": FicheActivite(
    "Contrôler un geste le long d’une bande.",
    "Suivre la bande au doigt.",
    "Le jeu entraîne le geste, pas la manipulation de vrais ciseaux.",
  ),
  "mains": FicheActivite(
    "Retenir les étapes du lavage des mains.",
    "Toucher les images dans l’ordre.",
    "Refaire les gestes au lavabo avec un adulte.",
  ),
  "recette": FicheActivite(
    "Suivre une suite de gestes de cuisine.",
    "Toucher les images dans le bon ordre.",
    "Nommer chaque geste ; la cuisine réelle se fait avec un adulte.",
  ),
  "ranger": FicheActivite(
    "Classer des objets selon leur usage.",
    "Toucher un objet puis le bac correspondant.",
    "Décrire la règle du classement et accepter de discuter d’autres règles.",
  ),
  "traverser": FicheActivite(
    "Reconnaître une suite d’actions de prudence.",
    "Remettre les images dans l’ordre.",
    "Le jeu ne rend pas autonome dans la rue : traverser reste accompagné d’un adulte.",
  ),
};
