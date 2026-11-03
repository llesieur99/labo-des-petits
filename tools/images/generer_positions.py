#!/usr/bin/env python3
"""Génère les illustrations de position (maison + chat) pour le jeu 31.

Compose deux SVG Twemoji dans une scène 128x128 : une grande maison, et un
chat placé DEVANT, DERRIÈRE, À CÔTÉ ou DANS. Les concepts correspondants du
lexique pointent vers ces fichiers via leur `illustration`.

Usage : python3 tools/images/generer_positions.py [--forcer]
"""
import argparse
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
DOSSIER = RACINE / "assets" / "images" / "concepts"

# nom de fichier → éléments dans l'ordre de dessin :
#   (concept, taille, x, y) — le premier dessiné est dessous.
POSITIONS = {
    # Le chat est dessiné AVANT la maison : la maison le cache en partie,
    # il dépasse au-dessus du toit — c'est ce qui rend « derrière » visible.
    "position_derriere.svg": [
        ("chat", 52, 62, 12),
        ("maison", 96, 16, 26),
    ],
    # Le chat est dessiné APRÈS la maison : il est devant.
    "position_devant.svg": [
        ("maison", 96, 16, 26),
        ("chat", 46, 41, 76),
    ],
    "position_acote.svg": [
        ("maison", 88, 12, 30),
        ("chat", 46, 82, 74),
    ],
    "position_dans.svg": [
        ("maison", 96, 16, 26),
        ("chat", 40, 44, 50),
    ],
}


def contenu_svg(chemin):
    """Le contenu interne d'un SVG Twemoji (sans la balise <svg> externe)."""
    texte = chemin.read_text(encoding="utf-8")
    interieur = re.sub(r"^.*?<svg[^>]*>", "", texte, count=1, flags=re.S)
    interieur = re.sub(r"</svg>\s*$", "", interieur, count=1, flags=re.S)
    return interieur.strip()


def element(concept, taille, x, y):
    """Un concept Twemoji posé à (x, y), à la taille voulue (viewBox 36)."""
    source = DOSSIER / f"{concept}.svg"
    if not source.is_file():
        raise FileNotFoundError(source)
    facteur = taille / 36.0
    return (
        f'  <g transform="translate({x},{y}) scale({facteur:.4f})">\n'
        f"    {contenu_svg(source)}\n"
        f"  </g>"
    )


def scene(elements):
    corps = "\n".join(elements)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">\n'
        '  <rect x="2" y="100" width="124" height="26" rx="12" fill="#E8F0D8"/>\n'
        f"{corps}\n"
        "</svg>\n"
    )


def main():
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument("--forcer", action="store_true",
                           help="réécrit les fichiers déjà présents")
    args = analyseur.parse_args()

    echecs = []
    for nom, elements in POSITIONS.items():
        cible = DOSSIER / nom
        if cible.is_file() and not args.forcer:
            print(f"[déjà là] {nom}")
            continue
        try:
            cible.write_text(
                scene([element(*e) for e in elements]), encoding="utf-8")
            print(f"[créé]     {nom}")
        except FileNotFoundError as erreur:
            echecs.append(f"{nom} : illustration absente ({erreur})")

    if echecs:
        print("\nÉCHECS :")
        for echec in echecs:
            print(f"  - {echec}")
        return 1
    print(f"\n{len(POSITIONS)} position(s) OK dans {DOSSIER.relative_to(RACINE)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
