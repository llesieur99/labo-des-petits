import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../contenu/modele/activite.dart';
import 'depot.dart';
import 'modele.dart';

/// Dépôt réel de l'app : SQLite local, sur l'appareil uniquement.
/// Rien ne sort jamais de l'appareil — c'est une exigence de la catégorie
/// enfant des deux stores.
class DepotSqlite implements DepotProgression {
  /// Chemin forcé (les tests passent `inMemoryDatabasePath`).
  final String? cheminBase;

  DepotSqlite({this.cheminBase});

  Database? _db;

  Database get _base {
    final db = _db;
    if (db == null) {
      throw StateError('DepotSqlite non initialisé : appeler initialiser() d\'abord.');
    }
    return db;
  }

  @override
  Future<void> initialiser() async {
    if (_db != null) return;
    final chemin = cheminBase ?? '${await getDatabasesPath()}/jeux_enfants.db';
    _db = await openDatabase(
      chemin,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profils (
            id INTEGER PRIMARY KEY,
            nom TEXT NOT NULL,
            avatar TEXT NOT NULL,
            age_declare INTEGER,
            cree_le INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE etats_activite (
            profil_id INTEGER NOT NULL,
            activite_id TEXT NOT NULL,
            palier TEXT NOT NULL,
            niveau INTEGER NOT NULL,
            aides TEXT NOT NULL DEFAULT '[]',
            fenetre TEXT NOT NULL DEFAULT '[]',
            parties_jouees INTEGER NOT NULL DEFAULT 0,
            meilleure_etoile INTEGER NOT NULL DEFAULT 0,
            depuis_parent INTEGER NOT NULL DEFAULT 0,
            maj_le INTEGER NOT NULL,
            PRIMARY KEY (profil_id, activite_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE evenements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profil_id INTEGER NOT NULL,
            activite_id TEXT NOT NULL,
            item_id TEXT NOT NULL,
            correct_du_premier_coup INTEGER NOT NULL,
            duree_ms INTEGER NOT NULL,
            palier TEXT NOT NULL,
            niveau INTEGER NOT NULL,
            horodatage INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_ev_profil_date ON evenements(profil_id, horodatage)');
      },
    );
  }

  @override
  Future<List<Profil>> profils() async {
    final lignes = await _base.query('profils', orderBy: 'cree_le');
    return lignes.map(_profilDepuisLigne).toList(growable: false);
  }

  @override
  Future<Profil> creerProfil({
    required String nom,
    required String avatar,
    int? ageDeclare,
  }) async {
    final id = await _base.insert('profils', {
      'nom': nom,
      'avatar': avatar,
      'age_declare': ageDeclare,
      'cree_le': DateTime.now().millisecondsSinceEpoch,
    });
    return Profil(
      id: id,
      nom: nom,
      avatar: avatar,
      ageDeclare: ageDeclare,
      creeLe: DateTime.now(),
    );
  }

  @override
  Future<void> modifierProfil(Profil profil) async {
    await _base.update(
      'profils',
      {
        'nom': profil.nom,
        'avatar': profil.avatar,
        'age_declare': profil.ageDeclare,
      },
      where: 'id = ?',
      whereArgs: [profil.id],
    );
  }

  @override
  Future<void> supprimerProfil(int profilId) async {
    await _base.delete('profils', where: 'id = ?', whereArgs: [profilId]);
    await _base.delete('etats_activite', where: 'profil_id = ?', whereArgs: [profilId]);
    await _base.delete('evenements', where: 'profil_id = ?', whereArgs: [profilId]);
  }

  @override
  Future<EtatActivite?> etat(int profilId, String activiteId) async {
    final lignes = await _base.query(
      'etats_activite',
      where: 'profil_id = ? AND activite_id = ?',
      whereArgs: [profilId, activiteId],
      limit: 1,
    );
    if (lignes.isEmpty) return null;
    return _etatDepuisLigne(lignes.first);
  }

  @override
  Future<List<EtatActivite>> etats(int profilId) async {
    final lignes = await _base
        .query('etats_activite', where: 'profil_id = ?', whereArgs: [profilId]);
    return lignes.map(_etatDepuisLigne).toList(growable: false);
  }

  @override
  Future<void> enregistrerEtat(EtatActivite etat) async {
    await _base.insert(
      'etats_activite',
      _etatVersLigne(etat),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> enregistrerEvenement(Evenement evenement) async {
    await _base.insert('evenements', {
      'profil_id': evenement.profilId,
      'activite_id': evenement.activiteId,
      'item_id': evenement.itemId,
      'correct_du_premier_coup': evenement.correctDuPremierCoup ? 1 : 0,
      'duree_ms': evenement.dureeMs,
      'palier': evenement.palier.id,
      'niveau': evenement.niveau,
      'horodatage': evenement.horodatage.millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<Evenement>> evenements(int profilId, {String? activiteId}) async {
    final lignes = await _base.query(
      'evenements',
      where: activiteId == null
          ? 'profil_id = ?'
          : 'profil_id = ? AND activite_id = ?',
      whereArgs: activiteId == null ? [profilId] : [profilId, activiteId],
      orderBy: 'horodatage',
    );
    return lignes
        .map((ligne) => Evenement(
              id: ligne['id'] as int,
              profilId: ligne['profil_id'] as int,
              activiteId: ligne['activite_id'] as String,
              itemId: ligne['item_id'] as String,
              correctDuPremierCoup:
                  (ligne['correct_du_premier_coup'] as int) == 1,
              dureeMs: ligne['duree_ms'] as int,
              palier: _palierDepuisId(ligne['palier'] as String),
              niveau: ligne['niveau'] as int,
              horodatage:
                  DateTime.fromMillisecondsSinceEpoch(ligne['horodatage'] as int),
            ))
        .toList(growable: false);
  }

  @override
  Future<void> remettreAZero(int profilId, {String? activiteId}) async {
    if (activiteId == null) {
      await _base.delete('etats_activite', where: 'profil_id = ?', whereArgs: [profilId]);
      await _base.delete('evenements', where: 'profil_id = ?', whereArgs: [profilId]);
    } else {
      await _base.delete('etats_activite',
          where: 'profil_id = ? AND activite_id = ?',
          whereArgs: [profilId, activiteId]);
      await _base.delete('evenements',
          where: 'profil_id = ? AND activite_id = ?',
          whereArgs: [profilId, activiteId]);
    }
  }

  @override
  Future<int> purgerAvant(DateTime date) async {
    return _base.delete(
      'evenements',
      where: 'horodatage < ?',
      whereArgs: [date.millisecondsSinceEpoch],
    );
  }

  @override
  Future<void> fermer() async {
    await _db?.close();
    _db = null;
  }

  Profil _profilDepuisLigne(Map<String, Object?> ligne) => Profil(
        id: ligne['id'] as int,
        nom: ligne['nom'] as String,
        avatar: ligne['avatar'] as String,
        ageDeclare: ligne['age_declare'] as int?,
        creeLe:
            DateTime.fromMillisecondsSinceEpoch(ligne['cree_le'] as int),
      );

  EtatActivite _etatDepuisLigne(Map<String, Object?> ligne) {
    final aides = (jsonDecode(ligne['aides'] as String) as List)
        .map((id) => Aide.values.firstWhere((a) => a.id == id))
        .toList(growable: false);
    final fenetre = (jsonDecode(ligne['fenetre'] as String) as List)
        .map((brut) => brut as Map<String, dynamic>)
        .map((json) => ResumePartie(
              items: json['items'] as int,
              reussisDuPremierCoup: json['reussis'] as int,
            ))
        .toList(growable: false);
    return EtatActivite(
      profilId: ligne['profil_id'] as int,
      activiteId: ligne['activite_id'] as String,
      palier: _palierDepuisId(ligne['palier'] as String),
      niveau: ligne['niveau'] as int,
      aides: aides,
      historique: fenetre,
      partiesJouees: ligne['parties_jouees'] as int,
      meilleureEtoile: ligne['meilleure_etoile'] as int,
      depuisParent: (ligne['depuis_parent'] as int) == 1,
      majLe: DateTime.fromMillisecondsSinceEpoch(ligne['maj_le'] as int),
    );
  }

  Map<String, Object?> _etatVersLigne(EtatActivite etat) => {
        'profil_id': etat.profilId,
        'activite_id': etat.activiteId,
        'palier': etat.palier.id,
        'niveau': etat.niveau,
        'aides': jsonEncode(etat.aides.map((a) => a.id).toList()),
        'fenetre': jsonEncode([
          for (final resume in etat.historique)
            {'items': resume.items, 'reussis': resume.reussisDuPremierCoup},
        ]),
        'parties_jouees': etat.partiesJouees,
        'meilleure_etoile': etat.meilleureEtoile,
        'depuis_parent': etat.depuisParent ? 1 : 0,
        'maj_le': etat.majLe.millisecondsSinceEpoch,
      };

  Palier _palierDepuisId(String id) =>
      Palier.values.firstWhere((p) => p.id == id, orElse: () => Palier.a4);
}
