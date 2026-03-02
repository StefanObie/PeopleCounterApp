import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/collection_summary.dart';
import '../models/count_session.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _databaseName = 'people_counter.db';
  static const _databaseVersion = 1;

  static const collectionsTable = 'collections';
  static const sessionsTable = 'count_sessions';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDir.path, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $collectionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $sessionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        people_count INTEGER NOT NULL,
        correction INTEGER NOT NULL DEFAULT 0,
        image_path TEXT NOT NULL,
        confidence_threshold REAL NOT NULL,
        iou_threshold REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (collection_id) REFERENCES $collectionsTable(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_sessions_collection ON $sessionsTable(collection_id)',
    );
    await db.execute(
      'CREATE INDEX idx_collections_created_at ON $collectionsTable(created_at DESC)',
    );
  }

  Future<int> insertCollection({required String name}) async {
    final db = await database;
    return db.insert(collectionsTable, {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<CollectionSummary>> getCollections() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.created_at,
        COUNT(s.id) AS session_count,
        COALESCE(SUM(s.people_count + s.correction), 0) AS total_people
      FROM $collectionsTable c
      LEFT JOIN $sessionsTable s ON s.collection_id = c.id
      GROUP BY c.id
      ORDER BY c.created_at DESC
    ''');

    return rows.map(CollectionSummary.fromMap).toList();
  }

  Future<int> insertSession(CountSession session) async {
    final db = await database;
    return db.insert(sessionsTable, session.toMap()..remove('id'));
  }

  Future<List<CountSession>> getSessionsForCollection(int collectionId) async {
    final db = await database;
    final rows = await db.query(
      sessionsTable,
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(CountSession.fromMap).toList();
  }

  Future<void> updateCollectionName(int collectionId, String name) async {
    final db = await database;
    await db.update(
      collectionsTable,
      {'name': name},
      where: 'id = ?',
      whereArgs: [collectionId],
    );
  }

  Future<void> deleteCollection(int collectionId) async {
    final db = await database;
    await db.delete(
      collectionsTable,
      where: 'id = ?',
      whereArgs: [collectionId],
    );
  }

  Future<CountSession?> getSession(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      sessionsTable,
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }
    return CountSession.fromMap(maps.first);
  }

  Future<void> deleteSession(int sessionId) async {
    final db = await database;
    await db.delete(
      sessionsTable,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
