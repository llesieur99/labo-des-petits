import 'dart:math';

import 'modele/activite.dart';
import 'modele/donnees_manche.dart';
import 'modele/manche.dart';

/// Prépare les 48 jeux avec les mêmes garanties : variété, choix adaptés,
/// observation réelle et données immuables. Aucun état personnel ici.
List<Manche> preparerPartie(
  Activite activite,
  Niveau niveau,
  Random alea, {
  Set<String> manchesRecentes = const {},
}) {
  final banque = switch (activite.source) {
    SourceGenerateur(:final generateur) => generateur.generer(niveau, alea),
    SourceFixe(:final manches) => List<Manche>.of(manches),
  };
  // Les ordres de trois gestes ne doivent pas arriver dès la découverte à 4 ans.
  if (activite.id == 'ordres' && niveau.palier == Palier.a4) {
    banque.removeWhere((m) => (m.donnees as DonneesOrdre).cases.length > 2);
  }
  // Les banques fixes sont classées de la découverte vers les cas plus
  // élaborés. Une fenêtre glissante évite de rejouer tout le temps la même
  // poignée de situations quand l'enfant progresse dans le même jeu.
  if (activite.source is SourceFixe && banque.length > niveau.nbItems) {
    final taille = max(niveau.nbItems, (banque.length / 2).ceil());
    final marge = banque.length - taille;
    final debut =
        (marge * (niveau.numero - 1) / max(1, Activite.etapesParPalier - 1))
            .round()
            .clamp(0, marge);
    final fenetre = banque.sublist(debut, debut + taille);
    banque
      ..clear()
      ..addAll(fenetre);
  }
  banque.shuffle(alea);
  final nouvelles = banque.where((m) => !manchesRecentes.contains(m.id));
  final connues = banque.where((m) => manchesRecentes.contains(m.id));
  return [...nouvelles, ...connues]
      .take(niveau.nbItems)
      .map((m) => _adapter(activite, m, niveau, alea))
      .toList(growable: false);
}

List<String> _choix(
  List<String> options,
  String? bonne,
  int maximum,
  Random alea, {
  List<String> autresBonnes = const [],
}) {
  final melange = List<String>.of(options)..shuffle(alea);
  if (bonne == null || options.length <= maximum) return melange;
  // Ne jamais transformer une réponse acceptable en leurre ou retirer la réponse.
  final gardees = [bonne, ...autresBonnes.where((c) => c != bonne)];
  final place = max(0, maximum - gardees.length);
  return [...gardees, ...melange.where((c) => !gardees.contains(c)).take(place)]
    ..shuffle(alea);
}

Manche _adapter(Activite activite, Manche manche, Niveau niveau, Random alea) {
  final decouverte = niveau.aides.contains(Aide.indiceVisuel);
  final maximum = max(activite.choixMinimum, niveau.choixMax);
  var options = List<OptionManche>.of(manche.options)..shuffle(alea);
  final consigne = List<String>.of(manche.clipsConsigne);
  final donnees = switch (manche.donnees) {
    DonneesScene d => DonneesScene(
      decor: d.decor,
      visuelInitial:
          d.visuelInitial ??
          (activite.id == 'flotte' ? d.etapes.first.visuel : null),
      etapes: [
        for (final e in d.etapes)
          EtapeScene(
            narrationCle: e.narrationCle,
            // Les boutons de direction restent dans leur sens spatial.
            options: e.options.toSet().difference({'gauche', 'droite'}).isEmpty
                ? List.of(e.options)
                : _choix(
                    e.options,
                    e.bonneOption,
                    maximum,
                    alea,
                    autresBonnes: e.autresBonnesOptions,
                  ),
            bonneOption: e.bonneOption,
            autresBonnesOptions: e.autresBonnesOptions,
            visuel: e.visuel,
            montrerAvant: e.options.isEmpty || e.montrerAvant,
            observationMs: activite.id == 'manque' && e == d.etapes.first
                ? (decouverte ? 4500 : 3000)
                : (decouverte ? 1800 : 1200),
          ),
      ],
    ),
    DonneesDepot d => DonneesDepot(
      emplacements: d.modeBacs
          ? (List<EmplacementDepot>.of(d.emplacements)..shuffle(alea))
          : List.of(d.emplacements),
      objets: List<String>.of(d.objets)..shuffle(alea),
      places: d.places,
      modeBacs: d.modeBacs,
      finCle: d.finCle,
    ),
    DonneesAtelier d => DonneesAtelier(
      groupes: [
        for (final g in d.groupes)
          GroupeAtelier(
            libelleCle: g.libelleCle,
            options: (List<String>.of(
              g.options,
            )..shuffle(alea)).take(maximum).toList(),
          ),
      ],
      inviterNomCle: d.inviterNomCle,
      felicitationNomCle: d.felicitationNomCle,
      questionCle: d.questionCle,
      nourritures: (List<String>.of(
        d.nourritures,
      )..shuffle(alea)).take(maximum).toList(),
    ),
    DonneesTheatre d => DonneesTheatre(
      personnages: List<String>.of(d.personnages)..shuffle(alea),
      dureeMaxSecondes: decouverte
          ? min(12, d.dureeMaxSecondes)
          : d.dureeMaxSecondes,
    ),
    DonneesToile d => DonneesToile(
      palette: List<String>.of(d.palette),
      melanges: d.melanges,
      couleurObjectif: d.couleurObjectif,
      cellulesObjectif: decouverte
          ? max(6, d.cellulesObjectif ~/ 2)
          : d.cellulesObjectif,
      miroir: d.miroir,
      taches: d.taches,
    ),
    DonneesBalance d => DonneesBalance(
      reserve: List<String>.of(d.reserve)..shuffle(alea),
      minimumParPlateau: decouverte
          ? max(1, d.minimumParPlateau - 1)
          : d.minimumParPlateau,
      pencheCle: d.pencheCle,
      egalCle: d.egalCle,
    ),
    DonneesComposer d => DonneesComposer(
      cases: d.cases,
      sons: Map.fromEntries(d.sons.entries.toList()..shuffle(alea)),
      bravoCle: d.bravoCle,
    ),
    DonneesRythme d => DonneesRythme(
      mode: d.mode,
      battements: decouverte ? max(4, d.battements - 2) : d.battements,
      intervalleMs: decouverte ? d.intervalleMs + 150 : d.intervalleMs,
      sonsParOption: d.sonsParOption,
      bonneOption: d.bonneOption,
      sonCle: d.sonCle,
      animalConcept: d.animalConcept,
      reactionCle: d.reactionCle,
      syllabesClips: d.syllabesClips,
      motCle: d.motCle,
    ),
    final autres => autres,
  };
  if (activite.moteur == Moteur.tapPick && options.length > maximum) {
    final ids = _choix(
      options.map((o) => o.id).toList(),
      manche.bonneOptionId,
      maximum,
      alea,
    );
    options = ids.map((id) => options.firstWhere((o) => o.id == id)).toList();
  }
  if (donnees is DonneesOrdre &&
      decouverte &&
      activite.id != 'ordres' &&
      donnees.narrationCle != null &&
      !consigne.contains(donnees.narrationCle)) {
    consigne.add(donnees.narrationCle!);
  }
  return Manche(
    id: manche.id,
    clipsConsigne: consigne,
    options: options,
    reperes: manche.reperes,
    bonneOptionId: manche.bonneOptionId,
    explicationCle: manche.explicationCle,
    donnees: donnees,
  );
}
