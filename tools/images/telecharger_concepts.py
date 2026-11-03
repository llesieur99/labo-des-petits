#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Télécharge les illustrations SVG des concepts du jeu (bibliothèque Twemoji).

Chaque concept du lexique donne un fichier `assets/images/concepts/<concept>.svg`
(le concept est la clé ASCII du lexique, sans accent). Les fichiers déjà présents
ne sont JAMAIS réécrits, sauf avec `--forcer`.

Source : https://github.com/jdecked/twemoji (Twemoji maintenu, licence CC-BY 4.0 —
voir CREDITS.md à la racine du projet).

Bibliothèque standard uniquement (aucune dépendance à installer).

Exemples :
  python3 tools/images/telecharger_concepts.py --liste   # montre le mapping, sans réseau
  python3 tools/images/telecharger_concepts.py           # télécharge les manquants
  python3 tools/images/telecharger_concepts.py --forcer  # retélécharge tout
"""

import argparse
import sys
import urllib.error
import urllib.request
from pathlib import Path

# --- Source -----------------------------------------------------------------
BASE_URL = (
    "https://raw.githubusercontent.com/jdecked/twemoji/main/assets/svg/"
    "{codepoint}.svg"
)
DELAI = 30  # secondes

# --- Emplacements -----------------------------------------------------------
# Chemins ancrés au projet : le script marche depuis n'importe quel répertoire.
RACINE_OUTILS = Path(__file__).resolve().parent           # tools/images
RACINE_PROJET = RACINE_OUTILS.parent.parent               # racine du projet
DOSSIER_DEFAUT = RACINE_PROJET / "assets" / "images" / "concepts"

# --- Mapping concept → codepoint Twemoji ------------------------------------
# L'ordre suit celui du lexique (lib/core/contenu/lexique/lexique_qc.dart).
# Pour changer une illustration : modifier le codepoint ici, relancer avec
# --forcer (ou supprimer le fichier ciblé avant de relancer).
CONCEPTS = {
    # ── Jeu 3 : la chasse aux rimes — rime en « o » ──
    "chapeau": "1f452",
    "bateau": "26f5",
    "gateau": "1f382",
    "cadeau": "1f381",
    "oiseau": "1f426",
    "chateau": "1f3f0",
    "velo": "1f6b2",
    "moto": "1f3cd",
    # ── rime en « on » ──
    "ballon": "1f388",
    "bonbon": "1f36c",
    "mouton": "1f411",
    "poisson": "1f41f",
    "maison": "1f3e0",
    "camion": "1f69a",
    "cochon": "1f437",
    # ── rime en « in » ──
    "lapin": "1f430",
    "sapin": "1f384",
    "poussin": "1f424",
    "chemin": "1f6e4",
    "matin": "1f305",
    # ── rime en « ou » ──
    "loup": "1f43a",
    "chou": "1f96c",
    "hibou": "1f989",
    "caillou": "1faa8",
    "genou": "1f9b5",
    "doudou": "1f9f8",
    # ── rime en « a » ──
    "chat": "1f431",
    "rat": "1f400",
    "chocolat": "1f36b",
    "pizza": "1f355",
    "papa": "1f468",
    # ── rime en « i » ──
    "souris": "1f42d",
    "lit": "1f6cf",
    "nid": "1faba",
    "bougie": "1f56f",
    "ami": "1f46b",
    # ── rime en « é » ──
    "bebe": "1f476",
    "fusee": "1f680",
    "nez": "1f443",
    "pied": "1f9b6",
    "cafe": "2615",
    "poupee": "1fa86",
    # ── rime en « ette » ──
    "fourchette": "1f374",
    "chaussette": "1f9e6",
    "assiette": "1f37d",
    "casquette": "1f9e2",
    "crevette": "1f990",
    # ── rime en « eur » ──
    "fleur": "1f337",
    "coeur": "2764",
    "beurre": "1f9c8",
    "couleur": "1f3a8",
    # ── Vague 1 : personnages et véhicules ──
    "enfant": "1f9d2",
    "bus": "1f68c",
    "poule": "1f414",
    "papillon": "1f98b",
    "chenille": "1f41b",
    "oeuf": "1f95a",
    # ── Vague 1 : les nombres 1 à 5 ──
    # Les keycaps Twemoji ne s'appellent PAS 0031-fe0f-20e3.svg : dans
    # jdecked/twemoji le fichier est le chiffre court + « -20e3 » (ni zéros
    # de tête, ni FE0F). Vérifié : 0031-fe0f-20e3.svg et 0031-20e3.svg
    # répondent 404, 31-20e3.svg répond 200.
    "un": "31-20e3",
    "deux": "32-20e3",
    "trois": "33-20e3",
    "quatre": "34-20e3",
    "cinq": "35-20e3",
    "six": "36-20e3",
    "sept": "37-20e3",
    "huit": "38-20e3",
    "neuf": "39-20e3",
    "dix": "1f51f",
    # ── Vague 1 : vêtements et temps ──
    "manteau": "1f9e5",
    "mitaines": "1f9e4",
    "bottes": "1f462",
    "echarpe": "1f9e3",
    "lunettes": "1f576",
    "maillot": "1f455",
    "gougounes": "1f461",
    "souliers": "1f45f",
    "parapluie": "2602",
    "neige": "2744",
    "soleil": "2600",
    "nuage": "2601",
    # ── Vague 1 : la maison et l'école ──
    "sac": "1f392",
    "lunch": "1f371",
    "verre": "1f95b",
    "pomme": "1f34e",
    # ── Vague 1 : la nature et la croissance ──
    "graine": "1f331",
    "eau": "1f4a7",
    "pot": "1fab4",
    "dormir": "1f4a4",
    "lune": "1f319",
    "etoile": "2b50",
    # ── Vague 1 : émotions et gestes ──
    "visage_content": "1f642",
    "visage_triste": "1f622",
    "visage_colere": "1f621",
    "visage_peur": "1f628",
    "aide": "1f64b",
    "respirer": "1f4a8",
    "recommencer": "1f504",
    "calin": "1f917",
    # ── Vague 2 : les couleurs (cercles colorés Twemoji) ──
    "rouge": "1f534",
    "jaune": "1f7e1",
    "bleu": "1f535",
    "orange": "1f7e0",
    "vert": "1f7e2",
    "violet": "1f7e3",
    # ── Vague 2 : le monstre du calme ──
    "monstre": "1f47e",
    "monstre_dodo": "1f634",
    # ── Vague 2 : les animaux des sons ──
    "serpent": "1f40d",
    "train": "1f682",
    "vache": "1f42e",
    "tigre": "1f42f",
    "abeille": "1f41d",
    "grenouille": "1f438",
    "tambour": "1f941",
    # ── Vague 3 : demander, stop, attendre, pluie ──
    "demander": "1f64f",
    "stop": "270b",
    "attendre": "23f3",
    "pluie": "1f327",
    # ── Vague 4 : formes et directions ──
    "forme_rond": "1f534",
    "forme_carre": "1f7e5",
    "forme_triangle": "1f53a",
    "forme_losange": "1f536",
    "haut": "2b06",
    "bas": "2b07",
    "gauche": "2b05",
    "droite": "27a1",
    # ── Vague 4 : les fruits du marché ──
    "orange": "1f34a",
    "banane": "1f34c",
    "fraise": "1f353",
    "raisin": "1f347",
    # ── Vague 4 : illustration de carte seulement (pas au lexique) ──
    "balance": "2696",
    # ── Vague 5 : temps, sons, hygiène, rue ──
    "vent": "1f32c",
    "ours": "1f43b",
    "grelot": "1f514",
    "fort": "1f50a",
    "doux": "1f508",
    "robinet": "1f6b0",
    "savon": "1f9fc",
    "frotter": "1f64c",
    "couteau": "1f52a",
    "livre": "1f4da",
    "panneau_stop": "1f6d1",
    "regarder": "1f440",
    "ecouter": "1f442",
    "marcher": "1f6b6",
}


def url_de(codepoint):
    """Adresse brute du SVG Twemoji d'un codepoint."""
    return BASE_URL.format(codepoint=codepoint)


def telecharger(codepoint):
    """Télécharge un SVG et renvoie ses octets (lève une erreur si échec)."""
    requete = urllib.request.Request(
        url_de(codepoint),
        headers={"User-Agent": "jeux-enfants/telecharger_concepts"},
    )
    with urllib.request.urlopen(requete, timeout=DELAI) as reponse:
        return reponse.read()


def valider(contenu):
    """Vérifie qu'un contenu est bien un SVG.

    Renvoie None si le contenu est valide, sinon le motif du refus. Le contrôle
    attrape les pages d'erreur HTML (404) servies à la place d'un SVG.
    """
    texte = contenu.decode("utf-8", errors="replace")
    debut = texte.lstrip("﻿ \t\r\n")
    if not (debut.startswith("<svg") or debut.startswith("<?xml")):
        return "ne commence pas par <svg ou <?xml (page d'erreur ?)"
    if "</svg>" not in texte:
        return "balise </svg> absente (fichier tronqué ?)"
    return None


def afficher_liste():
    """Affiche le mapping concept → codepoint, sans rien télécharger."""
    print("Mapping des {} concepts (illustrations Twemoji) :".format(len(CONCEPTS)))
    print("Source : {}".format(BASE_URL.format(codepoint="<codepoint>")))
    print()
    largeur = max(len(concept) for concept in CONCEPTS)
    for concept, codepoint in CONCEPTS.items():
        print("  {:<{largeur}}  {}.svg".format(concept, codepoint, largeur=largeur))
    return 0


def taille_lisible(octets):
    """Taille en Ko avec virgule décimale (usage francophone)."""
    return "{:.1f} Ko".format(octets / 1024).replace(".", ",")


def main():
    analyseur = argparse.ArgumentParser(
        description="Télécharge les SVG des concepts (Twemoji) dans assets/images/concepts/.",
    )
    analyseur.add_argument(
        "--liste",
        action="store_true",
        help="afficher le mapping concept → codepoint sans rien télécharger",
    )
    analyseur.add_argument(
        "--forcer",
        action="store_true",
        help="retélécharger et réécrire les fichiers déjà présents",
    )
    analyseur.add_argument(
        "--dossier",
        type=Path,
        default=DOSSIER_DEFAUT,
        help="dossier de destination (défaut : %(default)s)",
    )
    args = analyseur.parse_args()

    if args.liste:
        return afficher_liste()

    dossier = args.dossier
    dossier.mkdir(parents=True, exist_ok=True)

    total = len(CONCEPTS)
    prets = 0
    telecharges = 0
    deja_presents = 0
    echecs = []

    print("Dossier : {}".format(dossier))
    print("Concepts : {}".format(total))
    print()

    for concept, codepoint in CONCEPTS.items():
        cible = dossier / "{}.svg".format(concept)

        # Fichier déjà là : on n'y touche pas (sauf --forcer), mais on vérifie
        # qu'il est sain pour que le rapport soit honnête.
        if cible.exists() and not args.forcer:
            motif = valider(cible.read_bytes())
            if motif:
                echecs.append((concept, "fichier existant invalide ({}) — relancer avec --forcer".format(motif)))
                print("  échec    {:<12} {}".format(concept, echecs[-1][1]))
                continue
            deja_presents += 1
            prets += 1
            print("  déjà là  {:<12} {}".format(concept, codepoint))
            continue

        # Téléchargement en mémoire, validation, puis écriture seulement si le
        # contenu est un vrai SVG : aucun fichier tronqué ni page 404 ne reste.
        try:
            contenu = telecharger(codepoint)
        except urllib.error.HTTPError as err:
            motif = "HTTP {}".format(err.code)
        except urllib.error.URLError as err:
            motif = "réseau : {}".format(err.reason)
        except OSError as err:
            motif = "erreur : {}".format(err)
        else:
            motif = valider(contenu)

        if motif:
            echecs.append((concept, motif))
            print("  échec    {:<12} {:<6} {}".format(concept, codepoint, motif))
            continue

        # Écriture atomique : fichier temporaire puis renommage.
        temporaire = cible.parent / (cible.name + ".part")
        temporaire.write_bytes(contenu)
        temporaire.replace(cible)
        telecharges += 1
        prets += 1
        print("  ok       {:<12} {:<6} {}".format(concept, codepoint, taille_lisible(len(contenu))))

    print()
    if echecs:
        print("ÉCHECS ({}) :".format(len(echecs)))
        for concept, motif in echecs:
            print("  {} — {}".format(concept, motif))
        print()

    print("{} téléchargés, {} déjà présents".format(telecharges, deja_presents))
    print("[{}/{}] concepts OK".format(prets, total))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
