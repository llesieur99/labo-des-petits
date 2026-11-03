# Consignes — Labo des Petits

Dépôt public : https://github.com/llesieur99/labo-des-petits ; branche main.
Examiner les sources et l’état Git avant toute modification. Préserver les
travaux locaux et les historiques ; aucun force-push ni nettoyage destructif.

## Périmètre

Améliorer les 48 activités existantes sans en ajouter. Huit niveaux par âge,
contenu déclaratif, composants et moteurs réutilisables. Respecter les conventions
Flutter/Dart du projet et éviter les dépendances inutiles.

## Protection des enfants

- Aucun suivi, publicité, compte, boutique ou SDK de collecte.
- Jeux entièrement hors ligne ; aucune permission INTERNET ou AD_ID en release.
- Microphone facultatif, activé par un adulte, enregistrements temporaires locaux.
- Espace parent protégé ; brouillon de courriel externe seulement sur action
  explicite de l’adulte, sans donnée de profil ou de progression jointe.
- Grandes commandes, consignes audio disponibles, aucune lecture requise.
- Ne jamais ajouter de donnée réelle d’enfant aux tests ou aux captures.

## Validation

Flutter 3.44.9 / Dart 3.12 ; iOS 17 minimum ; Android minSdk 24, SDK 36.
Avant chaque commit, exécuter tools/verif.sh : analyse sans problème et tous
les tests réussis. Vérifier les secrets et la cohérence des documents modifiés.
Les contrôles de publication sont séparés de l’envoi vers les boutiques.
Ne pas revendiquer un test physique d’appareil sans l’avoir effectué.

## Git et publication

Les secrets, données, profils de signature et journaux de machine restent hors
Git dans _local/ ou un stockage privé. Utiliser une adresse de commit GitHub
noreply et un nom de contributeur public. Inspecter le diff avant commit.
Les changements validés rejoignent main. Toute publication vers une boutique
requiert une autorisation explicite ; rendre le code public ne publie pas l’app.
