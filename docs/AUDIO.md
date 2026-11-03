# Audio embarqué

Les consignes sont pré-générées et embarquées. L’application ne contacte aucun
service de synthèse vocale pendant les jeux. Antoine et Sylvie désignent les
voix synthétiques du catalogue ; aucune voix d’enfant réelle n’est incluse.

## Contenu et validation

```sh
dart run tool/exporter_scripts.dart --check
python3 tools/audio/generer_audio.py --verifier
python3 tools/audio/generer_audio.py --voix fr-CA-SylvieNeural --verifier
```

Les textes sont exportés depuis le contenu Dart dans tools/audio/scripts.json.
Les MP3 et les manifestes sont dans assets/audio/qc/antoine/ et
assets/audio/qc/sylvie/. Chaque manifeste décrit les clips et leurs empreintes.
Chaque sous-dossier embarqué doit être déclaré dans pubspec.yaml.

## Préparer des voix

Voir [le guide des outils](../tools/audio/README.md). La génération est une
opération de développement distincte du fonctionnement de l’application.
Les fournisseurs éventuels utilisent des variables d’environnement locales.
Ne jamais enregistrer de clé ni de fichier .env dans Git. Ne pas remplacer les
clips validés sans écoute et contrôle de leur prononciation, niveau sonore et
correspondance avec le contenu. Les enregistrements marqués comme humains dans
un manifeste sont protégés par l’outil ; cette capacité ne signifie pas que le
catalogue contient des enregistrements de personnes réelles.
