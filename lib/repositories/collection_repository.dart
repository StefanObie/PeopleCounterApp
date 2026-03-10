import 'dart:io';

import '../database/database_helper.dart';
import '../models/collection_summary.dart';
import '../models/count_session.dart';
import '../services/image_storage_service.dart';
import '../widgets/drawing_overlay.dart';

class CollectionRepository {
  CollectionRepository({DatabaseHelper? db, ImageStorageService? imageStorage})
    : _db = db ?? DatabaseHelper.instance,
      _imageStorage = imageStorage ?? ImageStorageService();

  final DatabaseHelper _db;
  final ImageStorageService _imageStorage;

  Future<List<CollectionSummary>> getCollections() => _db.getCollections();

  Future<int> createCollection({required String name}) {
    return _db.insertCollection(name: name);
  }

  Future<void> updateCollectionName(int collectionId, String name) {
    return _db.updateCollectionName(collectionId, name);
  }

  Future<void> saveSessionToCollection({
    required int collectionId,
    required File sourceImage,
    required int peopleCount,
    int correction = 0,
    required double confidenceThreshold,
    required double iouThreshold,
    String? notes,
    List<DrawnPath>? maskPaths,
  }) async {
    final storedImagePath = await _imageStorage.saveImageCopy(sourceImage);

    final session = CountSession(
      collectionId: collectionId,
      timestamp: DateTime.now(),
      peopleCount: peopleCount,
      correction: correction,
      imagePath: storedImagePath,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
      notes: notes,
      maskPaths: maskPaths,
    );

    await _db.insertSession(session);
  }

  Future<List<CountSession>> getSessionsForCollection(int collectionId) {
    return _db.getSessionsForCollection(collectionId);
  }

  Future<void> updateSession({required CountSession session}) {
    return _db.updateSession(session);
  }

  Future<void> deleteCollection(int collectionId) async {
    final sessions = await _db.getSessionsForCollection(collectionId);
    await _db.deleteCollection(collectionId);

    for (final session in sessions) {
      await _imageStorage.deleteImageIfExists(session.imagePath);
    }
  }

  Future<void> deleteSession(int sessionId) async {
    final session = await _db.getSession(sessionId);
    if (session != null) {
      await _db.deleteSession(sessionId);
      await _imageStorage.deleteImageIfExists(session.imagePath);
    }
  }
}
