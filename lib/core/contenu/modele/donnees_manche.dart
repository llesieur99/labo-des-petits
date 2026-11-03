/// Données spécifiques à un moteur, portées par une manche.
///
/// Une manche reste générique (consigne en clips, options) ; ce que le
/// moteur a besoin de savoir en plus vit ici, scellé par type.
sealed class DonneesMoteur {
  const DonneesMoteur();
}

/// Une zone de dépôt (assiette devant un ami, case du sac, bac de tri).
class EmplacementDepot {
  final String id;

  /// Concept du lexique (illustration de la zone).
  final String concept;

  const EmplacementDepot({required this.id, required this.concept});
}

/// M2 — déposer des objets à leur place (un pour un) ou dans des bacs (trier).
class DonneesDepot extends DonneesMoteur {
  final List<EmplacementDepot> emplacements;

  /// Concepts des objets à placer, dans l'ordre de la barre. Les doublons
  /// sont normaux : deux assiettes pour deux amis sont deux objets.
  final List<String> objets;

  /// emplacementId → concepts que cet emplacement accepte.
  /// Ex. deux amis acceptent chacun 'assiette' ; le bac du sac accepte
  /// ['lunch', 'souliers', 'doudou'] ; le bac maison accepte le reste.
  final Map<String, List<String>> places;

  /// Vrai : les emplacements sont de grands bacs (trier), faux : des zones
  /// posées sur une scène (une assiette devant chaque ami).
  final bool modeBacs;

  /// Clip dit quand TOUT est placé, juste avant la réussite
  /// (ex. la phrase reconstruite : « Le chat mange la pomme ! »).
  final String? finCle;

  const DonneesDepot({
    required this.emplacements,
    required this.objets,
    required this.places,
    this.modeBacs = false,
    this.finCle,
  });
}

/// Une étape d'une scène animée (M4) : l'app raconte, puis demande ou avance.
class EtapeScene {
  /// Clip de narration, dit au début de l'étape.
  final String narrationCle;

  /// Concepts touchables (vide = étape automatique : on raconte et on avance).
  final List<String> options;

  /// La bonne option si [options] est non vide.
  final String? bonneOption;

  /// Plusieurs émotions ou stratégies peuvent être raisonnables.
  final List<String> autresBonnesOptions;
  bool accepte(String concept) =>
      concept == bonneOption || autresBonnesOptions.contains(concept);

  /// Afficher ce qui est raconté pendant la narration, plutôt qu’après.
  final bool montrerAvant;
  final int observationMs;

  /// Nom de l'état visuel à afficher APRÈS la réussite
  /// (le moteur Scene connaît les dessins de chaque décor).
  final String? visuel;

  const EtapeScene({
    required this.narrationCle,
    this.options = const [],
    this.bonneOption,
    this.autresBonnesOptions = const [],
    this.montrerAvant = false,
    this.observationMs = 700,
    this.visuel,
  });
}

/// M4 — scène animée : des étapes changent l'état visuel, puis une question.
class DonneesScene extends DonneesMoteur {
  /// Concept du décor ('bus', 'graine', 'ciel', 'milo'…) : le moteur Scene
  /// sait dessiner chaque décor et ses états visuels.
  final String decor;

  final List<EtapeScene> etapes;

  final String? visuelInitial;

  const DonneesScene({
    required this.decor,
    required this.etapes,
    this.visuelInitial,
  });
}

/// M5 — reconstruire une séquence (histoire en quatre cases, recette…).
///
/// L'enfant place les images une à une, dans l'ordre : chaque case touchée
/// doit être la prochaine de l'histoire. C'est jouable à 4 ans (pas de
/// réarrangement à faire, on construit de gauche à droite).
class DonneesOrdre extends DonneesMoteur {
  /// Concepts des cases, DANS L'ORDRE CORRECT.
  final List<String> cases;

  /// Clip de narration (raconté après la réussite ; redit avant si l'aide
  /// « narrationAvant » est active).
  final String? narrationCle;

  const DonneesOrdre({required this.cases, this.narrationCle});
}

/// Un point de la toile (tache à remplir), en coordonnées normalisées 0..1.
class PointToile {
  final double x;
  final double y;
  final double rayon;

  const PointToile(this.x, this.y, this.rayon);
}

/// M7a — la toile : peindre au doigt, mélanger les couleurs, copier en miroir.
///
/// L'enfant peint librement ; rien n'est jamais raté. La manche est réussie
/// quand la CIBLE apparaît : assez de cellules de la couleur demandée
/// (peinture) ou toutes les taches remplies (ailes du papillon, en miroir).
class DonneesToile extends DonneesMoteur {
  /// Concepts des couleurs de la palette (ex. 'rouge', 'jaune', 'bleu').
  final List<String> palette;

  /// Règles de mélange : clé `a+b` (noms de concepts TRIÉS, ex. 'jaune+rouge')
  /// → concept de la couleur obtenue ('orange').
  final Map<String, String> melanges;

  /// La couleur demandée, pour la peinture (null = atelier libre sans cible,
  /// la manche se termine quand l'enfant a assez peint).
  final String? couleurObjectif;

  /// Nombre de cellules de la couleur objectif pour réussir.
  final int cellulesObjectif;

  /// Vrai : ce qui est peint à gauche se copie à droite (ailes du papillon).
  final bool miroir;

  /// Les taches à remplir (papillon) ; vide pour la peinture libre.
  final List<PointToile> taches;

  const DonneesToile({
    required this.palette,
    this.melanges = const {},
    this.couleurObjectif,
    this.cellulesObjectif = 10,
    this.miroir = false,
    this.taches = const [],
  });
}

/// M7b — la scène qu'on joue, puis qu'on rejoue.
///
/// Deux personnages déplaçables au doigt ; l'app enregistre les gestes et
/// rejoue la scène telle quelle (20 secondes au maximum).
class DonneesTheatre extends DonneesMoteur {
  /// Concepts des personnages (2).
  final List<String> personnages;

  /// Durée maximale d'une scène, en secondes.
  final int dureeMaxSecondes;

  const DonneesTheatre({required this.personnages, this.dureeMaxSecondes = 20});
}

/// M3 — suivre un chemin avec le doigt (lettre, sentier, bande de coupe).
///
/// Le tracé d'un enfant de 4 ans tremble : le ruban est très large, on ne
/// juge jamais la beauté — on célèbre l'arrivée au bout.
class DonneesTrace extends DonneesMoteur {
  /// Clé du chemin dans le registre (lib/core/contenu/lettres/chemins_lettres.dart).
  final String cheminId;

  /// Largeur du ruban, en fraction de la plus petite dimension de l'écran.
  final double largeurRuban;

  /// Faut-il poser le doigt sur le point de départ marqué ?
  final bool departOblige;

  const DonneesTrace({
    required this.cheminId,
    this.largeurRuban = 0.28,
    this.departOblige = false,
  });
}

/// M6 — rythme, sons et voix : taper, bercer, écouter, reproduire, syllaber.
enum ModeRythme {
  /// Taper avec le tambour ; le tempo ralentit si les tapes se perdent.
  pulsation,

  /// Taper lentement pour endormir le monstre (vite = il se réveille).
  bercement,

  /// Écouter un son (aigu/grave, fort/doux) et toucher l'image qui va avec.
  ecoute,

  /// La bouche à sons : l'app dit un son (« sss », « ch », « ou »), l'enfant
  /// le reproduit (micro optionnel), un animal réagit.
  echo,

  /// Syllabes qui sautent : la grenouille saute une fois par syllabe,
  /// puis l'enfant rejoue le mot en tapant une fois par syllabe.
  syllabes,
}

class DonneesRythme extends DonneesMoteur {
  final ModeRythme mode;

  // ── modes pulsation / bercement ──
  /// Nombre de battements à accompagner, ou de caresses lentes nécessaires
  /// pour endormir le monstre.
  final int battements;

  /// Intervalle initial entre deux battements, ou attente minimale entre
  /// deux caresses (ms).
  final int intervalleMs;

  // ── mode ecoute ──
  /// Concept → asset de son non verbal
  /// (ex. {'oiseau': 'assets/audio/neutre/sons/aigu_fort.wav'}).
  final Map<String, String> sonsParOption;

  /// La bonne réponse parmi les options (mode ecoute).
  final String? bonneOption;

  // ── mode echo (la bouche à sons) ──
  /// Clip du son à reproduire (dit par l'app).
  final String? sonCle;

  /// Concept de l'animal qui réagit.
  final String? animalConcept;

  /// Clip de réaction de l'animal (dit après l'essai de l'enfant).
  final String? reactionCle;

  // ── mode syllabes ──
  /// Un clip par syllabe (« cha », « peau »…).
  final List<String> syllabesClips;

  /// Clip du mot entier (« chapeau »).
  final String? motCle;

  const DonneesRythme({
    required this.mode,
    int? battements,
    int? intervalleMs,
    this.sonsParOption = const {},
    this.bonneOption,
    this.sonCle,
    this.animalConcept,
    this.reactionCle,
    this.syllabesClips = const [],
    this.motCle,
  }) : battements = battements ?? (mode == ModeRythme.bercement ? 8 : 12),
       intervalleMs =
           intervalleMs ?? (mode == ModeRythme.bercement ? 1100 : 900);
}

/// Un groupe de choix de l'atelier (« une tête », « un corps », « une queue »).
class GroupeAtelier {
  /// Clip qui invite à choisir (« Choisis une tête ! »).
  final String libelleCle;

  /// Concepts des éléments proposés (des animaux, empilés pour inventer).
  final List<String> options;

  const GroupeAtelier({required this.libelleCle, required this.options});
}

/// M5 mode composer — la chanson de quatre cases : l'enfant aligne quatre
/// sons, puis l'app rejoue sa boucle. Création libre : aucune réponse fausse.
class DonneesComposer extends DonneesMoteur {
  /// Le nombre de cases à remplir (quatre).
  final int cases;

  /// Les sons disponibles : concept → asset non verbal
  /// (ex. {'tambour': 'assets/audio/neutre/sons/tambour.wav'}).
  final Map<String, String> sons;

  /// Clip dit après le rejeu (« Ta chanson est belle ! »).
  final String bravoCle;

  const DonneesComposer({
    this.cases = 4,
    required this.sons,
    required this.bravoCle,
  });
}

/// M9 — la balance du marché : poser des fruits jusqu'à l'égalité.
///
/// L'enfant pose et reprend des fruits sur les deux plateaux ; la balance
/// penche tant que ce n'est pas égal. L'égalité arrive avant le signe =.
class DonneesBalance extends DonneesMoteur {
  /// Les fruits de la réserve (concepts, doublons permis).
  final List<String> reserve;

  /// Nombre minimum de fruits par plateau pour que l'égalité compte.
  final int minimumParPlateau;

  /// Clip dit quand ça penche après un dépôt (« Ça penche ! »).
  final String pencheCle;

  /// Clip dit quand c'est égal (« C'est égal ! »), puis l'hôte félicite.
  final String egalCle;

  const DonneesBalance({
    required this.reserve,
    this.minimumParPlateau = 2,
    required this.pencheCle,
    required this.egalCle,
  });
}

/// M7c — l'atelier : inventer un animal en empilant tête, corps et queue,
/// lui donner un nom (micro optionnel), puis répondre à l'app qui demande
/// seulement : « Qu'est-ce qu'il mange ? »
class DonneesAtelier extends DonneesMoteur {
  final List<GroupeAtelier> groupes;

  /// Clip qui invite à nommer (« Donne-lui un nom ! »).
  final String inviterNomCle;

  /// Clip de félicitation après le nom (« Quel beau nom ! »).
  final String felicitationNomCle;

  /// La question finale (« Qu'est-ce qu'il mange ? »).
  final String questionCle;

  /// Les nourritures proposées (n'importe laquelle est acceptée).
  final List<String> nourritures;

  const DonneesAtelier({
    required this.groupes,
    required this.inviterNomCle,
    required this.felicitationNomCle,
    required this.questionCle,
    required this.nourritures,
  });
}

/// M5 mode exécuter — le code de trois blocs : un animal suit le programme.
///
/// L'enfant pose des blocs (avancer, tourner, ramasser), puis regarde
/// l'animal exécuter son programme case par case. Pour les 6-7 ans.
class DonneesCode extends DonneesMoteur {
  /// La grille fait [taille] × [taille] cases.
  final int taille;

  /// Case de départ de l'animal (0 = en haut à gauche). Il regarde à droite.
  final int departX;
  final int departY;

  /// La case à atteindre.
  final int objectifX;
  final int objectifY;

  /// Concept de l'animal (souris, chat…).
  final String animal;

  /// Concept à ramasser sur la case objectif (null = il suffit d'y arriver).
  final String? ramassable;

  /// Nombre maximum de blocs dans le programme.
  final int maxBlocs;

  const DonneesCode({
    required this.taille,
    required this.departX,
    required this.departY,
    required this.objectifX,
    required this.objectifY,
    required this.animal,
    this.ramassable,
    this.maxBlocs = 3,
  });
}
