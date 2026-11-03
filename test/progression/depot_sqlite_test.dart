import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/progression/depot_sqlite.dart';
import 'package:jeux_enfants/core/progression/modele.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('crée un profil, enregistre un état et le relit fidèlement', () async {
    final depot = DepotSqlite(cheminBase: inMemoryDatabasePath);
    await depot.initialiser();

    final profil = await depot.creerProfil(
        nom: 'Anna', avatar: 'chat', ageDeclare: 5);
    expect(profil.id, isNotNull);
    expect((await depot.profils()).single.nom, 'Anna');

    final maintenant = DateTime.now();
    await depot.enregistrerEtat(EtatActivite(
      profilId: profil.id!,
      activiteId: 'rimes',
      palier: Palier.a5,
      niveau: 2,
      aides: const [Aide.moinsDeChoix],
      historique: const [ResumePartie(items: 6, reussisDuPremierCoup: 5)],
      partiesJouees: 3,
      meilleureEtoile: 2,
      majLe: maintenant,
    ));

    final relu = await depot.etat(profil.id!, 'rimes');
    expect(relu, isNotNull);
    expect(relu!.palier, Palier.a5);
    expect(relu.niveau, 2);
    expect(relu.aides, const [Aide.moinsDeChoix]);
    expect(relu.partiesJouees, 3);
    expect(relu.meilleureEtoile, 2);
    expect(relu.historique.single.reussisDuPremierCoup, 5);

    await depot.fermer();
  });

  test('remise à zéro ciblée : une activité seulement', () async {
    final depot = DepotSqlite(cheminBase: inMemoryDatabasePath);
    await depot.initialiser();
    final profil = await depot.creerProfil(nom: 'Léo', avatar: 'loup');

    await depot.enregistrerEtat(EtatActivite(
      profilId: profil.id!,
      activiteId: 'rimes',
      palier: Palier.a4,
      niveau: 1,
      majLe: DateTime.now(),
    ));
    await depot.enregistrerEtat(EtatActivite(
      profilId: profil.id!,
      activiteId: 'autre',
      palier: Palier.a4,
      niveau: 1,
      majLe: DateTime.now(),
    ));
    await depot.enregistrerEvenement(Evenement(
      profilId: profil.id!,
      activiteId: 'rimes',
      itemId: 'rimes.chapeau.chat',
      correctDuPremierCoup: true,
      dureeMs: 2100,
      palier: Palier.a4,
      niveau: 1,
      horodatage: DateTime.now(),
    ));

    await depot.remettreAZero(profil.id!, activiteId: 'rimes');

    expect(await depot.etat(profil.id!, 'rimes'), isNull);
    expect(await depot.etat(profil.id!, 'autre'), isNotNull);
    expect(await depot.evenements(profil.id!), isEmpty);

    await depot.fermer();
  });

  test('la purge enlève les évènements trop vieux, pas les récents', () async {
    final depot = DepotSqlite(cheminBase: inMemoryDatabasePath);
    await depot.initialiser();
    final profil = await depot.creerProfil(nom: 'Zoé', avatar: 'souris');

    await depot.enregistrerEvenement(Evenement(
      profilId: profil.id!,
      activiteId: 'rimes',
      itemId: 'vieux',
      correctDuPremierCoup: true,
      dureeMs: 1000,
      palier: Palier.a4,
      niveau: 1,
      horodatage: DateTime.now().subtract(const Duration(days: 200)),
    ));
    await depot.enregistrerEvenement(Evenement(
      profilId: profil.id!,
      activiteId: 'rimes',
      itemId: 'recent',
      correctDuPremierCoup: true,
      dureeMs: 1000,
      palier: Palier.a4,
      niveau: 1,
      horodatage: DateTime.now(),
    ));

    final supprimes =
        await depot.purgerAvant(DateTime.now().subtract(const Duration(days: 180)));

    expect(supprimes, 1);
    final restants = await depot.evenements(profil.id!);
    expect(restants.single.itemId, 'recent');

    await depot.fermer();
  });
}
