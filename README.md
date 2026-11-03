# Labo des Petits

48 jeux gratuits en français pour les enfants de 4 à 7 ans, sur iOS et Android.
Les jeux fonctionnent hors ligne, sans publicité, achat intégré ni compte.
Chaque activité propose huit niveaux par âge, des consignes audio, de grandes
commandes et des collants pour accompagner la progression.

Les sept familles couvrent le langage, les mathématiques, la logique, les
découvertes, les émotions, la création et l’autonomie. Les profils et la
progression restent sur l’appareil. Le microphone est facultatif et contrôlé
par l’espace parent. Un adulte peut préparer un message au soutien dans son
application de courriel ; l’application n’envoie aucun message automatiquement.

- [Présentation et soutien](https://le-sieur.ca/jeux-enfants/)
- [Confidentialité](https://le-sieur.ca/jeux-enfants/confidentialite.html)
- Contact public : support@le-sieur.ca

## Démarrer

| Outil | Version |
|---|---|
| Flutter / Dart | 3.44.9 / 3.12 |
| iOS | 17.0 minimum, Xcode sur macOS |
| Android | minSdk 24, compileSdk et targetSdk 36, JDK 17 ou plus |
| Python | 3.10 ou plus pour les outils audio |

```sh
git clone https://github.com/llesieur99/labo-des-petits.git
cd labo-des-petits
flutter pub get
flutter run
```

La signature pour un appareil iOS nécessite votre propre équipe Apple et
vos profils locaux. Les clés de signature et les identifiants de publication
ne sont pas fournis. Voir [Compilation et distribution](docs/PUBLICATION.md).

## Vérifier

```sh
flutter analyze
flutter test
tools/verif.sh
python3 tools/verif_publication.py
```

La vérification complète contrôle l’analyse, les tests, l’export du contenu,
la cohérence audio et la taille des ressources. Les voix embarquées permettent
de compiler l’application sans compte de fournisseur de synthèse vocale.

## Organisation

- `lib/core/contenu/` : catalogue et contenu déclaratif des 48 jeux.
- `lib/core/moteurs/` : interactions réutilisables et aides gestuelles.
- `lib/core/audio/` : lecture des consignes et gestion des voix.
- `lib/core/progression/` : profils et progression locale.
- `lib/features/` : écrans de jeu et espace parent.
- `test/` : tests du contenu, des moteurs, des écrans et de la progression.
- `docs/CONTENU.md` et `docs/AUDIO.md` : guides techniques.
- `docs/publication/presentation/` : visuels de présentation avec données fictives.

## Contribution et crédits

Les modifications doivent améliorer les activités existantes, préserver le
fonctionnement hors ligne et passer les vérifications. Voir [AGENTS.md](AGENTS.md)
et [WORKFLOW-GITHUB.md](WORKFLOW-GITHUB.md).

Le code est consultable publiquement. Aucune licence générale de réutilisation
n’est accordée dans ce dépôt. Les illustrations et les polices conservent leurs
licences respectives, détaillées dans [CREDITS.md](CREDITS.md).
