# Audio — voix pré-enregistrées

`generer_audio.py` lit `scripts.json` (export du contenu Dart) et écrit les MP3 ainsi que le
`manifest.json` que lit l'app, dans `assets/audio/<deck>/…`. Rien n'est généré au runtime.

- `python3 tools/audio/generer_audio.py` : génère les clips manquants ou modifiés (fournisseur `dummy`, muet, sans réseau ni clé).
- `--rapport` : clips, caractères et coût Azure estimé (16 $/M) ; `--verifier` : compare manifest ↔ fichiers ↔ `scripts.json`, sortie non nulle si écart (pour `tools/verif.sh`).
- `--probe <id> [--texte …]` : extrait d'écoute dans `tools/audio/ecoutes/`, sans toucher aux assets.
- Vraies voix : `--fournisseur azure` (env `AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION`) ou `--fournisseur edge` (CLI gratuite : `python3 -m venv tools/audio/.venv && tools/audio/.venv/bin/pip install edge-tts`).

Un clip `statut: enregistre` (voix humaine) n'est **jamais** écrasé, même par `--tout` ;
seul `--forcer <id>` le régénère, et le repasse à `genere`.

Le cache `tools/audio/.cache/<empreinte>.mp3` évite de payer deux fois le même contenu ; il ne
sert qu'aux vrais fournisseurs. Après un essai en `dummy`, relance avec `--tout` pour obtenir
les vraies voix (sinon le manifest les croit à jour). `scripts.exemple.json` : jeu d'essai.
