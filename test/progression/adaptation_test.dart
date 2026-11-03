import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/progression/adaptation.dart';
import 'package:jeux_enfants/core/progression/modele.dart';

void main() {
  EtatActivite initial() => AdaptationDouce.etatInitial(
        profilId: 1,
        activiteId: 'rimes',
        palier: Palier.a4,
      );

  const forte = ResumePartie(items: 6, reussisDuPremierCoup: 6);
  const faible = ResumePartie(items: 6, reussisDuPremierCoup: 1);

  test('les étoiles : 3 sans erreur, 2 bien joué, 1 pour avoir fini', () {
    expect(forte.etoiles, 3);
    expect(const ResumePartie(items: 6, reussisDuPremierCoup: 5).etoiles, 2);
    expect(faible.etoiles, 1);
  });

  test('monte d\'un niveau après deux parties fortes de suite', () {
    var etat = initial();
    etat = AdaptationDouce.apresPartie(etat, forte, nbNiveaux: 3);
    expect(etat.niveau, 1, reason: 'une seule partie forte ne suffit pas');
    etat = AdaptationDouce.apresPartie(etat, forte, nbNiveaux: 3);
    expect(etat.niveau, 2, reason: 'deux parties fortes : on monte');
  });

  test('ne monte jamais au-delà des niveaux disponibles', () {
    var etat = initial();
    etat = AdaptationDouce.apresPartie(etat, forte, nbNiveaux: 1);
    etat = AdaptationDouce.apresPartie(etat, forte, nbNiveaux: 1);
    expect(etat.niveau, 1);
  });

  test('ajoute les aides AVANT de toucher au niveau', () {
    var etat = initial();
    etat = AdaptationDouce.apresPartie(etat, faible, nbNiveaux: 3);
    expect(etat.niveau, 1, reason: 'on ne baisse pas le niveau tout de suite');
    expect(etat.aides, [Aide.consigneRepetee]);

    etat = AdaptationDouce.apresPartie(etat, faible, nbNiveaux: 3);
    expect(etat.niveau, 1);
    expect(etat.aides, [Aide.consigneRepetee, Aide.moinsDeChoix]);
  });

  test('baisse le niveau après trois parties faibles, aides déjà en place',
      () {
    var etat = initial().copieAvec(niveau: 2);
    for (var i = 0; i < 3; i++) {
      etat = AdaptationDouce.apresPartie(etat, faible, nbNiveaux: 3);
    }
    expect(etat.niveau, 1);
  });

  test('ne descend jamais sous le niveau 1', () {
    var etat = initial();
    for (var i = 0; i < 10; i++) {
      etat = AdaptationDouce.apresPartie(etat, faible, nbNiveaux: 3);
    }
    expect(etat.niveau, 1);
  });

  test('les acquis ne redescendent jamais : parties jouées et meilleure étoile',
      () {
    var etat = initial();
    etat = AdaptationDouce.apresPartie(etat, forte, nbNiveaux: 3);
    expect(etat.meilleureEtoile, 3);
    expect(etat.partiesJouees, 1);

    // Une partie faible ensuite : l'acquis reste.
    etat = AdaptationDouce.apresPartie(etat, faible, nbNiveaux: 3);
    expect(etat.meilleureEtoile, 3);
    expect(etat.partiesJouees, 2);
  });
}
