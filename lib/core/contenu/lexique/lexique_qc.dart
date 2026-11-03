import '../modele/lexique.dart';

/// Lexique québécois : comment chaque concept se dit ici.
///
/// L'illustration par défaut est `assets/images/concepts/<concept>.svg`
/// et le clip par défaut est `lex.<concept>`.
///
/// Les mots ajoutés ici doivent AUSSI exister dans [lexiqueFr].
const lexiqueQc = <String, EntreeLexique>{
  // ── Jeu 3 : la chasse aux rimes — rime en « o » ──
  'chapeau': EntreeLexique(texte: 'chapeau'),
  'bateau': EntreeLexique(texte: 'bateau'),
  'gateau': EntreeLexique(texte: 'gâteau'),
  'cadeau': EntreeLexique(texte: 'cadeau'),
  'oiseau': EntreeLexique(texte: 'oiseau'),
  'chateau': EntreeLexique(texte: 'château'),
  'velo': EntreeLexique(texte: 'vélo'),
  'moto': EntreeLexique(texte: 'moto'),

  // ── rime en « on » ──
  'ballon': EntreeLexique(texte: 'ballon'),
  'bonbon': EntreeLexique(texte: 'bonbon'),
  'mouton': EntreeLexique(texte: 'mouton'),
  'poisson': EntreeLexique(texte: 'poisson'),
  'maison': EntreeLexique(texte: 'maison'),
  'camion': EntreeLexique(texte: 'camion'),
  'cochon': EntreeLexique(texte: 'cochon'),

  // ── rime en « in » ──
  'lapin': EntreeLexique(texte: 'lapin'),
  'sapin': EntreeLexique(texte: 'sapin'),
  'poussin': EntreeLexique(texte: 'poussin'),
  'chemin': EntreeLexique(texte: 'chemin'),
  'matin': EntreeLexique(texte: 'matin'),

  // ── rime en « ou » ──
  'loup': EntreeLexique(texte: 'loup'),
  'chou': EntreeLexique(texte: 'chou'),
  'hibou': EntreeLexique(texte: 'hibou'),
  'caillou': EntreeLexique(texte: 'caillou'),
  'genou': EntreeLexique(texte: 'genou'),
  'doudou': EntreeLexique(texte: 'doudou'),

  // ── rime en « a » ──
  'chat': EntreeLexique(texte: 'chat'),
  'rat': EntreeLexique(texte: 'rat'),
  'chocolat': EntreeLexique(texte: 'chocolat'),
  'pizza': EntreeLexique(texte: 'pizza'),
  'papa': EntreeLexique(texte: 'papa'),

  // ── rime en « i » ──
  'souris': EntreeLexique(texte: 'souris'),
  'lit': EntreeLexique(texte: 'lit'),
  'nid': EntreeLexique(texte: 'nid'),
  'bougie': EntreeLexique(texte: 'bougie'),
  'ami': EntreeLexique(texte: 'ami'),

  // ── rime en « é » ──
  'bebe': EntreeLexique(texte: 'bébé'),
  'fusee': EntreeLexique(texte: 'fusée'),
  'nez': EntreeLexique(texte: 'nez'),
  'pied': EntreeLexique(texte: 'pied'),
  'cafe': EntreeLexique(texte: 'café'),
  'poupee': EntreeLexique(texte: 'poupée'),

  // ── rime en « ette » ──
  'fourchette': EntreeLexique(texte: 'fourchette'),
  'chaussette': EntreeLexique(texte: 'chaussette'),
  'assiette': EntreeLexique(texte: 'assiette'),
  'casquette': EntreeLexique(texte: 'casquette'),
  'crevette': EntreeLexique(texte: 'crevette'),

  // ── rime en « eur » ──
  'fleur': EntreeLexique(texte: 'fleur'),
  'coeur': EntreeLexique(texte: 'cœur'),
  'beurre': EntreeLexique(texte: 'beurre'),
  'couleur': EntreeLexique(texte: 'couleur'),

  // ── Vague 1 : personnages et véhicules ──
  'enfant': EntreeLexique(texte: 'enfant'),
  'bus': EntreeLexique(texte: 'bus'),
  'poule': EntreeLexique(texte: 'poule'),
  'papillon': EntreeLexique(texte: 'papillon'),
  'chenille': EntreeLexique(texte: 'chenille'),
  'oeuf': EntreeLexique(texte: 'œuf'),

  // ── Vague 1 : les nombres 1 à 5 (pour compter ; le texte est le chiffre) ──
  'un': EntreeLexique(texte: '1'),
  'deux': EntreeLexique(texte: '2'),
  'trois': EntreeLexique(texte: '3'),
  'quatre': EntreeLexique(texte: '4'),
  'cinq': EntreeLexique(texte: '5'),

  // ── Vague 4 : les nombres 6 à 10 (la droite numérique) ──
  'six': EntreeLexique(texte: '6'),
  'sept': EntreeLexique(texte: '7'),
  'huit': EntreeLexique(texte: '8'),
  'neuf': EntreeLexique(texte: '9'),
  'dix': EntreeLexique(texte: '10'),

  // ── Vague 1 : vêtements et temps (jeu « S'habiller pour sortir ») ──
  'manteau': EntreeLexique(texte: 'manteau'),
  'mitaines': EntreeLexique(texte: 'mitaines'),
  'bottes': EntreeLexique(texte: 'bottes'),
  'echarpe': EntreeLexique(texte: 'écharpe'),
  'lunettes': EntreeLexique(texte: 'lunettes de soleil'),
  'maillot': EntreeLexique(texte: 'maillot de bain'),
  'gougounes': EntreeLexique(texte: 'gougounes'),
  'souliers': EntreeLexique(texte: 'souliers'),
  'parapluie': EntreeLexique(texte: 'parapluie'),
  'neige': EntreeLexique(texte: 'neige'),
  'soleil': EntreeLexique(texte: 'soleil'),
  'nuage': EntreeLexique(texte: 'nuage'),

  // ── Vague 1 : la maison et l'école (jeux « Mon sac du matin », « Mettre la table ») ──
  'sac': EntreeLexique(texte: 'sac à dos'),
  'lunch': EntreeLexique(texte: 'lunch'),
  'verre': EntreeLexique(texte: 'verre'),
  'pomme': EntreeLexique(texte: 'pomme'),

  // ── Vague 1 : la nature et la croissance (jeu « La graine ») ──
  'graine': EntreeLexique(texte: 'graine'),
  'eau': EntreeLexique(texte: 'eau'),
  'pot': EntreeLexique(texte: 'pot'),
  'dormir': EntreeLexique(texte: 'dormir'),
  'lune': EntreeLexique(texte: 'lune'),
  'etoile': EntreeLexique(texte: 'étoile'),

  // ── Vague 1 : émotions et gestes (jeu « La figure de Milo ») ──
  // Textes courts : chaque clip est dit seul, sans phrase autour.
  // Au Québec on dit « fâché », pas « en colère ».
  'visage_content': EntreeLexique(texte: 'content'),
  'visage_triste': EntreeLexique(texte: 'triste'),
  'visage_colere': EntreeLexique(texte: 'fâché'),
  'visage_peur': EntreeLexique(texte: 'peur'),
  'aide': EntreeLexique(texte: 'demander de l\'aide'),
  'respirer': EntreeLexique(texte: 'respirer'),
  'recommencer': EntreeLexique(texte: 'recommencer'),
  'calin': EntreeLexique(texte: 'un câlin'),

  // ── Vague 2 : les couleurs (peinture qui se mélange, ailes du papillon) ──
  'rouge': EntreeLexique(texte: 'rouge'),
  'jaune': EntreeLexique(texte: 'jaune'),
  'bleu': EntreeLexique(texte: 'bleu'),
  'orange': EntreeLexique(texte: 'orange'),
  'vert': EntreeLexique(texte: 'vert'),
  'violet': EntreeLexique(texte: 'violet'),

  // ── Vague 2 : le monstre du calme (le jeu « Le calme du monstre ») ──
  'monstre': EntreeLexique(texte: 'le monstre'),
  'monstre_dodo': EntreeLexique(texte: 'le monstre dort'),

  // ── Vague 2 : les animaux des sons (jeu « La bouche à sons ») ──
  'serpent': EntreeLexique(texte: 'le serpent'),
  'train': EntreeLexique(texte: 'le train'),
  'vache': EntreeLexique(texte: 'la vache'),
  'tigre': EntreeLexique(texte: 'le tigre'),
  'abeille': EntreeLexique(texte: 'l\'abeille'),
  'grenouille': EntreeLexique(texte: 'la grenouille'),
  'tambour': EntreeLexique(texte: 'le tambour'),

  // ── Vague 3 : les mots pour demander (jeu « Les mots pour demander ») ──
  'demander': EntreeLexique(texte: 'demander gentiment'),
  'stop': EntreeLexique(texte: 'dire stop'),
  'attendre': EntreeLexique(texte: 'attendre son tour'),

  // ── Vague 3 : le temps qu'il fait (jeu « Si… alors ») ──
  'pluie': EntreeLexique(texte: 'la pluie'),

  // ── Vague 3 : les positions (jeu « Devant, derrière, à côté ») ──
  // Illustrations composées (maison + chat) par
  // tools/images/generer_positions.py.
  'devant': EntreeLexique(texte: 'devant', illustration: 'position_devant.svg'),
  'derriere':
      EntreeLexique(texte: 'derrière', illustration: 'position_derriere.svg'),
  'acote': EntreeLexique(texte: 'à côté', illustration: 'position_acote.svg'),
  'dans': EntreeLexique(texte: 'dans', illustration: 'position_dans.svg'),

  // ── Vague 4 : les formes (jeu « Formes qui s'emboîtent ») ──
  'forme_rond': EntreeLexique(texte: 'le rond'),
  'forme_carre': EntreeLexique(texte: 'le carré'),
  'forme_triangle': EntreeLexique(texte: 'le triangle'),
  'forme_losange': EntreeLexique(texte: 'le losange'),

  // ── Vague 4 : les directions (flotte ou coule, plus ou moins) ──
  'haut': EntreeLexique(texte: 'en haut'),
  'bas': EntreeLexique(texte: 'en bas'),
  'gauche': EntreeLexique(texte: 'à gauche'),
  'droite': EntreeLexique(texte: 'à droite'),

  // ── Vague 4 : le casier de la phrase (illustration maison, voir
  // tools/images/generer_illustrations_activites.py) ──
  'casier': EntreeLexique(texte: 'la case', illustration: 'casier.svg'),

  // ── Vague 4 : les fruits du marché (jeu « La balance du marché ») ──
  // (« orange » existe déjà comme couleur : son cercle orange sert aussi de
  // fruit dans la balance.)
  'banane': EntreeLexique(texte: 'une banane'),
  'fraise': EntreeLexique(texte: 'une fraise'),
  'raisin': EntreeLexique(texte: 'du raisin'),

  // ── Vague 5 : le temps qu'il fait, les sons, l'hygiène, la rue ──
  'vent': EntreeLexique(texte: 'le vent'),
  'ours': EntreeLexique(texte: 'l\'ours'),
  'grelot': EntreeLexique(texte: 'le grelot'),
  'fort': EntreeLexique(texte: 'fort'),
  'doux': EntreeLexique(texte: 'doux'),
  'robinet': EntreeLexique(texte: 'le robinet'),
  'savon': EntreeLexique(texte: 'le savon'),
  'frotter': EntreeLexique(texte: 'frotter les mains'),
  'couteau': EntreeLexique(texte: 'le couteau'),
  'livre': EntreeLexique(texte: 'le livre'),
  'panneau_stop': EntreeLexique(texte: 'le panneau stop'),
  'regarder': EntreeLexique(texte: 'regarder'),
  'ecouter': EntreeLexique(texte: 'écouter'),
  'marcher': EntreeLexique(texte: 'marcher'),
};
