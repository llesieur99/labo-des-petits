# CONTENU.md — ajouter du contenu sans toucher au code

Le contenu de l'app est **déclaratif** : 48 activités existantes, mais un seul moteur
d'interaction réutilisé plusieurs fois. « Beaucoup de possibilités » veut dire
**beaucoup de données, pas beaucoup de code**.

Règle de base : **le contenu ne contient jamais un mot**, seulement des **concepts**.
Un concept (`'chapeau'`) devient un texte, une illustration et un clip grâce au lexique
du deck. C'est ce qui permet de servir le Québec et la France sans dupliquer les jeux.

## Où vit quoi

| Fichier | Rôle |
|---|---|
| `lib/core/contenu/lexique/lexique_qc.dart` | concept → mot québécois (+ illustration, + id de clip) |
| `lib/core/contenu/lexique/lexique_fr.dart` | les écarts France (part du lexique QC) |
| `lib/core/contenu/activites/<famille>/<jeu>_data.dart` | une activité : banque, gabarits, niveaux, titre |
| `lib/core/contenu/catalogue.dart` | la liste des activités de l'app |
| `lib/core/contenu/preparer_partie.dart` | préparation commune : mélange, historique, adaptation des moteurs, copies des données |
| `lib/core/contenu/modele/` | les « formulaires » : `Activite`, `Niveau`, `Manche`, `ClipConsigne`… |
| `assets/images/concepts/<concept>.svg` | l'illustration (Twemoji) |
| `tools/images/telecharger_concepts.py` | télécharge ces illustrations |

## Ajouter un concept au lexique

Prenons **`tuque`** — le mot québécois que la France appelle un bonnet. Quatre
endroits, dans cet ordre :

**1. Le québécois** — `lib/core/contenu/lexique/lexique_qc.dart` :

```dart
  // ── Vêtements ──
  'tuque': EntreeLexique(texte: 'tuque'),
```

La clé `'tuque'` est le **concept** : minuscules, sans accent, ASCII. Elle sert aussi de
nom de fichier (`tuque.svg`) et d'id de clip (`lex.tuque`) tant que tu ne précises rien.

**2. La France** — `lib/core/contenu/lexique/lexique_fr.dart` :

```dart
const lexiqueFr = <String, EntreeLexique>{
  ...lexiqueQc,
  // Écarts France — à remplir au fil du catalogue (vagues suivantes) :
  'tuque': EntreeLexique(texte: 'bonnet', illustration: 'tuque.svg'),
};
```

Les deux lexiques vont **toujours ensemble** : le validateur refuse un concept présent
au Québec mais absent de France (« Concept « X » présent au Québec mais absent du
lexique France »). Ici le mot change mais l'illustration reste la même : deux enfants
voient la même image, chacun entend son mot.

**3. L'illustration** — le mapping `CONCEPTS` de `tools/images/telecharger_concepts.py` :

```python
    "tuque": "1f9e2",   # le codepoint Twemoji de l'image choisie
```

puis :

```zsh
python3 tools/images/telecharger_concepts.py --liste    # vérifier le mapping, sans réseau
python3 tools/images/telecharger_concepts.py            # télécharge ce qui manque
```

Le script **ne réécrit jamais** un fichier déjà là (`--forcer` pour ça). Un test
(`test/contenu/contenu_test.dart`) vérifie que chaque concept du lexique QC a bien son
SVG sur disque : sans l'étape 3, les tests échouent.

**4. Le clip** — rien à faire à la main : l'export fabrique `lex.tuque` tout seul à
partir du lexique (`registre_clips.dart`). Mais il faut le lancer :

```zsh
dart run tool/exporter_scripts.dart --csv          # réécrit scripts.json + clips.csv
tools/audio/.venv/bin/python tools/audio/generer_audio.py --fournisseur edge
```

Sans le premier, `tools/verif.sh` (étape 3) échoue ; sans le second, le mot entre au
manifeste mais le fichier n'existe pas — et c'est `--verifier` (étape 4) qui te le dira.
(Un clip **absent du manifeste** est seulement ignoré avec une ligne de journal par
`SayKit` ; un clip **présent au manifeste mais sans fichier** empêche le lecteur de
charger le son — d'où l'importance de la vérification.) Le détail de la chaîne audio :
[AUDIO.md](AUDIO.md).

## Ajouter un mot à la banque de rimes

`lib/core/contenu/activites/langue/rimes_data.dart` :

```dart
const banqueRimes = <MotRime>[
  // rime en « o »
  MotRime('chapeau', 'o'),
  MotRime('marteau', 'o'),   // ← même son final : même clé de rime
  …
];
```

(Ton mot doit d'abord exister dans les deux lexiques — section précédente.)

Trois règles, **toutes vérifiées par les tests** :

- **La rime est un SON, pas une orthographe.** `'o'` pour *chapeau / bateau / gâteau*,
  `'ette'` pour *fourchette / chaussette*. Deux mots qui s'écrivent pareil mais ne
  riment pas ne doivent pas partager la clé. Les clés utilisées aujourd'hui : `o`, `on`,
  `in`, `ou`, `a`, `i`, `e` (son « é »), `ette`, `eur`.
- **Au moins 3 mots par rime** (test « chaque rime de la banque a au moins trois mots »).
  En dessous, le générateur ne peut plus garantir un « ami » et assez de leurres.
  La banque actuelle en a 4 à 8 par rime — garde cette marge.
- **Le concept doit exister dans les deux lexiques** (test dédié). Ajoute-le d'abord
  (section précédente), sinon le test te le dira.

Une fois le mot dans la banque, le générateur `RimesGenerateur` l'utilise tout seul :
il tire une cible, un « ami » qui rime, et des leurres — en vérifiant qu'aucun leurre ne
rime avec la cible (règle anti-rime, testée sur 30 graines × 4 paliers).

## Ajouter une variante / un palier

Un `Niveau` = une variante d'une activité **à un palier d'âge donné** (4, 5, 6 ou 7 ans).
Chaque activité déclare une configuration de base par âge ; `Activite.etapesPour`
en dérive **8 niveaux**. Le niveau 3 conserve la longueur et le nombre de choix
historiques quand la banque le permet ; `nbItemsMaximum` peut raccourcir la
partie pour éviter de répéter les mêmes cas. Les générateurs peuvent lire `niveau.numero` (1 à 8) pour faire
évoluer les situations, l'ordre des gestes et les distracteurs. Une banque fixe
est ordonnée de la découverte vers les cas plus élaborés : `preparerPartie`
choisit une fenêtre glissante selon le niveau avant de mélanger les manches.
Dans `rimes_data.dart` :

```dart
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 6,  choixMax: 2, aides: [Aide.consigneRepetee]),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 8,  choixMax: 3, aides: [Aide.consigneRepetee]),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 8,  choixMax: 3, afficherMots: true),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 10, choixMax: 4, afficherMots: true),
  ],
```

| Champ | Ce qu'il faut respecter (sinon le validateur refuse) |
|---|---|
| `palier` | `a4`, `a5`, `a6`, `a7` — une configuration de base par âge. Le validateur refuse un palier dupliqué dans la liste déclarée. |
| `numero` | `1` pour la configuration de base ; les niveaux `1` à `8` en sont dérivés et transmis aux générateurs. |
| `nbItems` | **1 à 12** manches par partie selon le type de jeu ; `nbItemsMaximum` sur l'activité borne les banques courtes. Viser 3 à 8 minutes au total. |
| `choixMax` | **2 à 6** options par manche, et **≤ 3 à 4 ans** |
| `aides` | aides actives par défaut : `consigneRepetee`, `moinsDeChoix`, `indiceVisuel`, `narrationAvant` |
| `afficherMots` | écrit le mot sous l'image — à partir de 6 ans (transition vers la lecture) |

Le validateur **joue vraiment** chaque niveau : il génère des parties avec 20 graines par
niveau et vérifie que chaque manche a exactement `choixMax` options, que la bonne réponse
est dedans, qu'aucune manche ne se répète, et que tous les concepts et tous les clips
existent. Si ta variante ne peut pas tenir ces promesses, il le dit tout de suite.

## Ajouter un titre d'activité

Le titre ne s'écrit **jamais en dur** : c'est un clip, déclaré dans la liste `clips` de
l'activité, et désigné par `titreCle`.

```dart
const clipsRimes = <ClipConsigne>[
  ClipConsigne('act.rimes.titre', 'La chasse aux rimes'),
  ClipConsigne('consigne.rimes.g1', 'Trouve l\'image qui rime avec'),
  …
];

const activiteRimes = Activite(
  id: 'rimes',                            // minuscules ASCII, unique dans le catalogue
  famille: Famille.langue,                // l'« île » de l'accueil
  moteur: Moteur.tapPick,                 // le moteur qui dessine le jeu
  sensNaturel: Sens.lesDeux,              // préférence seulement : jouable dans les deux sens
  titreCle: 'act.rimes.titre',            // DOIT être dans clips (vérifié)
  illustration: 'act-rimes.svg',          // l'image de la carte (illustration maison)
  clips: clipsRimes,
  niveaux: [ … ],
  payload: PayloadTapPick(),
);
```

Le validateur refuse une activité dont le `titreCle` n'est pas déclaré dans `clips`. Un
clip de consigne suit la convention `act.<activité>.<nom>` / `consigne.<activité>.<nom>`
— c'est ce qui range le MP3 dans `assets/audio/qc/consignes/<activité>/` (voir la
convention de nommage dans [AUDIO.md](AUDIO.md)).

Une activité de plus = un fichier de données + une ligne dans
`catalogueActivites` (`catalogue.dart`). Aucun écran à écrire tant que le moteur existe.

## Le principe QC / FR en une image

```
contenu :      "trouve l'image qui rime avec"  +  concept « tuque »
                            │
              ┌─────────────┴─────────────┐
        deck qc │                     deck fr │
   lexique_qc : « tuque »        lexique_fr : « bonnet »
   clip lex.tuque → « tuque »    clip lex.tuque → « bonnet »
   illustration tuque.svg (la même des deux côtés)
```

Le contenu ne change pas d'un deck à l'autre : seuls le lexique et les clips changent.
Un même id (`lex.tuque`) peut dire deux mots différents selon le deck, parce que chaque
deck a **son propre manifeste**. Le deck France n'est servi que quand ses clips existent ;
d'ici là l'app se rabat clip par clip sur le québécois.

Si tu as besoin d'un clip qui ne suit pas la clé du concept, `EntreeLexique` accepte
`clipId:` — par exemple pour réutiliser le clip d'un autre concept.

## Comment le contenu est vérifié

```zsh
flutter test test/contenu/     # juste le contenu (rapide)
tools/verif.sh                 # tout : analyze + tests + export + audio + taille
```

`validerContenu()` (`lib/core/contenu/validateur.dart`) vérifie :

- les **identifiants** : minuscules ASCII (`^[a-z][a-z0-9]*$`), jamais deux fois ;
- le **titre** : `titreCle` déclaré dans les clips de l'activité ;
- les **bornes des niveaux** (voir le tableau plus haut) et l'absence de palier dupliqué ;
- en **générant de vraies parties** (20 graines par niveau) : nombre de manches et
  d'options, bonne réponse présente, pas de manche en double dans une partie, tous les
  concepts présents au lexique, **tous les clips consignes déclarés** quelque part
  (chrome, activité ou lexique) ;
- les **lexiques** : tout concept québécois existe aussi en France.

Et les tests de `test/contenu/` ajoutent :

- la banque de rimes : ≥ 3 mots par rime, concepts présents dans les deux lexiques ;
- la **règle anti-rime** : aucun leurre ne rime avec la cible (30 graines × 4 paliers) ;
- chaque concept du lexique a **son illustration sur disque** ;
- le contenu **n'importe jamais Flutter** (`lib/core/contenu/` est du Dart pur — c'est ce
  qui permet de le tester sans appareil, et de l'exporter vers `scripts.json`).

Si un de ces contrôles échoue, le message dit exactement quoi corriger (« Activité rimes
a4 graine 7 : manche rimes.chapeau.bateau, 2 options au lieu de 3 »). Ne contourne pas un
test : c'est lui qui empêche un enfant de tomber sur une manche impossible.

## Préparation des parties et contrôle du contenu

L’écran et le validateur passent par `preparerPartie` : tester seulement le
résultat brut d’un générateur ne suffit pas pour valider ce que l’enfant voit.
Les scénarios fixes sont mélangés avant sélection et les identifiants récents
sont repoussés après les autres scénarios. Le contenu d’origine reste intact.
`Manche.reperes` porte une référence illustrée distincte des réponses.
`EtapeScene` accepte un visuel avant narration, un temps d’observation et des
réponses alternatives ; chacune doit exister parmi les choix. Les délais de
scène s’arrêtent en arrière-plan. Voir `BASE-48-JEUX-2026-10-16.md`.
