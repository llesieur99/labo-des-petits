#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère les sons NON VERBAUX de l'application « jeux-enfants ».

Ce sont les sons du moteur M6 (le rythme) : le tambour, le grelot, les notes
hautes et basses (fortes et douces), le ronflement et le grognement du monstre.
Ils vivent à côté des voix, dans assets/audio/neutre/sons/ — des WAV courts,
doux, sans aucune parole (l'enfant les reconnaît à l'oreille, pas au texte).

Bibliothèque standard uniquement (aucune dépendance à installer).

  python3 tools/audio/generer_sons.py
  python3 tools/audio/generer_sons.py --forcer
"""

import argparse
import math
import random
import re
import struct
import subprocess
import sys
import wave
from pathlib import Path

# --- Emplacements (ancrés au projet : le script marche depuis n'importe quel cwd) ---
RACINE_OUTILS = Path(__file__).resolve().parent      # tools/audio
RACINE_PROJET = RACINE_OUTILS.parent.parent          # racine du projet
DOSSIER_SONS = RACINE_PROJET / "assets" / "audio" / "neutre" / "sons"

FREQUENCE = 22050        # Hz — des sons courts : un petit fichier suffit
LIMITE = 0.85            # crête maximale : jamais 1,0, qui « claque » sur le téléphone

# Graine fixe : un même son donne toujours exactement le même fichier
# (pas de bruit Git à chaque relance).
GRAINE = 20261016


# --- Petits utilitaires -----------------------------------------------------
def echantillons(duree):
    """Nombre d'échantillons d'une durée en secondes."""
    return int(round(duree * FREQUENCE))


def montee(i, millisecondes):
    """Rampe d'attaque linéaire : le premier échantillon part de zéro
    (sinon le haut-parleur fait « clic » à chaque lecture)."""
    pente = max(1, int(round(millisecondes * FREQUENCE / 1000.0)))
    return min(1.0, i / float(pente))


def chute(i, total, millisecondes):
    """Rampe de sortie linéaire : le son s'éteint à zéro, sans clic."""
    pente = max(1, int(round(millisecondes * FREQUENCE / 1000.0)))
    return min(1.0, (total - 1 - i) / float(pente))


def moyenne_glissante(valeurs, fenetre):
    """Un filtre passe-bas simple : la moyenne des [fenetre] derniers points."""
    sortie = []
    somme = 0.0
    for i, valeur in enumerate(valeurs):
        somme += valeur
        if i >= fenetre:
            somme -= valeurs[i - fenetre]
        sortie.append(somme / min(i + 1, fenetre))
    return sortie


def formater_octets(nombre):
    """2 180 o — séparateur de milliers à la française."""
    return "{:,}".format(nombre).replace(",", " ")


# --- Les sons ---------------------------------------------------------------
def son_tambour():
    """Le coup de tambour : la peau se détend (95 Hz qui descendent), très court."""
    total = echantillons(0.25)
    phase, sortie = 0.0, []
    for i in range(total):
        t = i / FREQUENCE
        frequence = 45.0 + 50.0 * math.exp(-t * 18.0)     # 95 Hz → 45 Hz
        phase += 2 * math.pi * frequence / FREQUENCE
        enveloppe = math.exp(-t * 14.0) * montee(i, 3) * chute(i, total, 12)
        sortie.append(0.9 * math.sin(phase) * enveloppe)
    return sortie


def son_grelot():
    """Un clic de grelot tout doux : une seule note haute, très brève."""
    total = echantillons(0.15)
    sortie = []
    for i in range(total):
        t = i / FREQUENCE
        enveloppe = math.exp(-t * 26.0) * montee(i, 2) * chute(i, total, 10)
        sortie.append(0.5 * math.sin(2 * math.pi * 1200.0 * t) * enveloppe)
    return sortie


def son_notes(frequences, duree, amplitude):
    """Une suite de notes douces : chaque note a sa petite attaque (10 ms) et
    sa sortie — la note suivante n'est jamais coupée en plein son."""
    total = echantillons(duree)
    longueur = total // len(frequences)
    phase, sortie = 0.0, []
    for i in range(total):
        index = min(len(frequences) - 1, i // longueur)
        i_note = i - index * longueur
        phase += 2 * math.pi * frequences[index] / FREQUENCE
        enveloppe = (math.exp(-i_note / float(FREQUENCE) * 3.0)
                     * montee(i_note, 10) * chute(i_note, longueur, 35))
        sortie.append(amplitude * math.sin(phase) * enveloppe)
    return sortie


def son_aigu_fort():
    """Trois notes hautes, décidées (880 → 1174 Hz) — forte, mais douce."""
    return son_notes([880.0, 1046.5, 1174.7], 0.60, 0.9)


def son_aigu_doux():
    """Les mêmes notes hautes, en tout petit (une caresse)."""
    return son_notes([880.0, 1046.5, 1174.7], 0.60, 0.25)


def son_grave_fort():
    """Trois notes basses (196 → 147 Hz) — forte, mais douce."""
    return son_notes([196.0, 174.6, 147.0], 0.70, 0.9)


def son_grave_doux():
    """Les mêmes notes basses, en tout petit."""
    return son_notes([196.0, 174.6, 147.0], 0.70, 0.25)


def son_ronflement():
    """Le souffle du monstre endormi : du bruit blanc très filtré (trois
    moyennes glissantes), qui monte et qui descend comme une respiration."""
    total = echantillons(1.2)
    aleatoire = random.Random(GRAINE)
    bruit = [aleatoire.uniform(-1.0, 1.0) for _ in range(total)]
    filtre = moyenne_glissante(moyenne_glissante(moyenne_glissante(bruit, 90), 90), 90)
    souffle = []
    for i, valeur in enumerate(filtre):
        t = i / FREQUENCE
        # La respiration : nulle au début, pleine au milieu, nulle à la fin.
        respiration = math.sin(math.pi * (t / 1.2)) ** 1.2
        souffle.append(valeur * respiration)
    crete = max(abs(valeur) for valeur in souffle) or 1.0
    return [0.5 * (valeur / crete) * montee(i, 20) for i, valeur in enumerate(souffle)]


def son_grogne():
    """Le grognement du monstre réveillé : un grave qui descend, un peu de
    souffle et un tremblement — plus dur que les notes douces, jamais méchant."""
    total = echantillons(0.4)
    aleatoire = random.Random(GRAINE)
    bruit = moyenne_glissante([aleatoire.uniform(-1.0, 1.0) for _ in range(total)], 8)
    crete_bruit = max(abs(valeur) for valeur in bruit) or 1.0
    phase, sortie = 0.0, []
    for i in range(total):
        t = i / FREQUENCE
        frequence = 70.0 + 40.0 * math.exp(-t * 5.0)      # 110 Hz → 70 Hz
        phase += 2 * math.pi * frequence / FREQUENCE
        tremblement = 1.0 + 0.25 * math.sin(2 * math.pi * 22.0 * t)
        enveloppe = montee(i, 8) * chute(i, total, 60) * math.exp(-t * 0.6)
        grave = math.sin(phase)
        souffle = bruit[i] / crete_bruit
        sortie.append(0.9 * enveloppe * tremblement * (0.75 * grave + 0.35 * souffle))
    return sortie


# nom du fichier, description, fabrique, durée visée (s)
SONS = [
    ("tambour.wav", "le coup de tambour (le rythme des pas)", son_tambour, 0.25),
    ("grelot.wav", "le petit clic de grelot", son_grelot, 0.15),
    ("aigu_fort.wav", "les notes hautes, fortes (aigu fort)", son_aigu_fort, 0.60),
    ("aigu_doux.wav", "les notes hautes, tout douces", son_aigu_doux, 0.60),
    ("grave_fort.wav", "les notes basses, fortes (grave fort)", son_grave_fort, 0.70),
    ("grave_doux.wav", "les notes basses, tout douces", son_grave_doux, 0.70),
    ("ronflement.wav", "le souffle du monstre endormi", son_ronflement, 1.20),
    ("grogne.wav", "le grognement du monstre réveillé", son_grogne, 0.40),
]


# --- Écriture et vérification ----------------------------------------------
def ecrire_wav(chemin, valeurs):
    """Écrit un WAV 16 bits mono et rend la crête brute.

    Si la crête dépasse LIMITE, TOUT le son est réduit d'un même facteur
    (jamais d'écrêtage : le son reste propre, simplement un peu plus doux).
    """
    chemin.parent.mkdir(parents=True, exist_ok=True)
    crete = max((abs(valeur) for valeur in valeurs), default=0.0)
    facteur = (LIMITE / crete) if crete > LIMITE else 1.0
    octets = bytearray()
    for valeur in valeurs:
        octets += struct.pack("<h", int(round(valeur * facteur * 32767)))
    with wave.open(str(chemin), "wb") as flux:
        flux.setnchannels(1)
        flux.setsampwidth(2)
        flux.setframerate(FREQUENCE)
        flux.writeframes(bytes(octets))
    return crete


def duree_afinfo(chemin):
    """Durée mesurée par afinfo (macOS) ; None si afinfo n'est pas disponible."""
    try:
        resultat = subprocess.run(["afinfo", str(chemin)],
                                  capture_output=True, text=True, timeout=30)
    except (FileNotFoundError, subprocess.SubprocessError):
        return None
    if resultat.returncode != 0:
        return None
    correspondance = re.search(r"duration:\s*([0-9]+(?:\.[0-9]+)?)", resultat.stdout)
    return float(correspondance.group(1)) if correspondance else None


def construire_analyseur():
    analyseur = argparse.ArgumentParser(
        description="Génère les sons non verbaux (le rythme) : des WAV courts et doux.")
    analyseur.add_argument("--forcer", action="store_true",
                           help="réécrit même un son déjà présent (défaut : jamais écrasé)")
    return analyseur


def main(argv=None):
    args = construire_analyseur().parse_args(argv)
    DOSSIER_SONS.mkdir(parents=True, exist_ok=True)
    print("Sons non verbaux — %d son(s) attendu(s) dans %s" % (len(SONS), DOSSIER_SONS))

    ecrits, gardes = [], []
    for nom, description, fabrique, duree in SONS:
        chemin = DOSSIER_SONS / nom
        if chemin.is_file() and not args.forcer:
            gardes.append(chemin)
            print("  = %-15s déjà là — conservé (%s o)"
                  % (nom, formater_octets(chemin.stat().st_size)))
            continue

        crete = ecrire_wav(chemin, fabrique())
        ecrits.append(chemin)
        reduction = (" → ramenée à %.2f" % LIMITE) if crete > LIMITE else ""
        print("  + %-15s écrit (%s o, crête %.2f%s) — %s"
              % (nom, formater_octets(chemin.stat().st_size), crete, reduction, description))

        mesuree = duree_afinfo(chemin)
        if mesuree is None:
            print("      afinfo : pas disponible ici (macOS seulement) — durée non vérifiée")
        elif abs(mesuree - duree) > 0.02:
            print("      afinfo : %.3f s — ÉCART INATTENDU (visé %.2f s)" % (mesuree, duree))
        else:
            print("      afinfo : %.3f s — conforme (visé %.2f s)" % (mesuree, duree))

    connus = {nom for nom, _, _, _ in SONS}
    inattendus = sorted(f for f in DOSSIER_SONS.glob("*.wav") if f.name not in connus)

    print("\nVérification (afinfo) :")
    conforme = True
    for nom, _, _, duree in SONS:
        chemin = DOSSIER_SONS / nom
        if not chemin.is_file():
            print("  ? %-15s ABSENT — relance le script" % nom)
            conforme = False
            continue
        mesuree = duree_afinfo(chemin)
        if mesuree is None:
            print("  · %-15s %s o (afinfo indisponible ici)"
                  % (nom, formater_octets(chemin.stat().st_size)))
        else:
            ecart = abs(mesuree - duree)
            conforme = conforme and ecart <= 0.02
            print("  %s %-15s %s o — %.3f s (visé %.2f s)"
                  % ("ok" if ecart <= 0.02 else "⚠ ", nom,
                     formater_octets(chemin.stat().st_size), mesuree, duree))

    total = sum(f.stat().st_size for f in DOSSIER_SONS.glob("*.wav"))
    print("\nRapport — %d écrit(s), %d conservé(s), %s o au total dans %s"
          % (len(ecrits), len(gardes), formater_octets(total), DOSSIER_SONS))
    print("  Crête bornée à %.2f : un son ne colle jamais à 1,0 (pas de « clic »)."
          % LIMITE)
    if not conforme:
        print("  ⚠ un ou plusieurs sons ne sont pas conformes : voir ci-dessus.")
    if inattendus:
        print("  Note : %d fichier(s) du dossier ne viennent pas de ce script :"
              % len(inattendus))
        for fichier in inattendus:
            print("      - %s" % fichier.name)
    if not ecrits:
        print("  Rien à faire : tous les sons sont déjà là (--forcer pour réécrire).")
    print("  Écouter : afplay %s" % (DOSSIER_SONS / "tambour.wav"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
