import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/collection_summary.dart';
import '../models/count_session.dart';
import '../repositories/collection_repository.dart';
import '../widgets/drawing_overlay.dart';

class CollectionProvider extends ChangeNotifier {
  CollectionProvider(this._repository) {
    loadCollections();
  }

  final CollectionRepository _repository;

  final Map<int, List<CountSession>> _sessionsByCollection = {};
  List<CollectionSummary> _collections = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CollectionSummary> get collections => _collections;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<CountSession> sessionsForCollection(int collectionId) =>
      _sessionsByCollection[collectionId] ?? const [];

  Future<void> loadCollections() async {
    _setLoading(true);
    try {
      _collections = await _repository.getCollections();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load collections: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<int?> createCollection({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    try {
      final id = await _repository.createCollection(name: trimmed);
      await loadCollections();
      return id;
    } catch (e) {
      _errorMessage = 'Failed to create collection: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCollectionName(int collectionId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    try {
      await _repository.updateCollectionName(collectionId, trimmed);
      await loadCollections();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update collection: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveSessionToCollection({
    required int collectionId,
    required File sourceImage,
    required int peopleCount,
    int correction = 0,
    required double confidenceThreshold,
    required double iouThreshold,
    String? notes,
    List<DrawnPath>? maskPaths,
  }) async {
    try {
      await _repository.saveSessionToCollection(
        collectionId: collectionId,
        sourceImage: sourceImage,
        peopleCount: peopleCount,
        correction: correction,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        maskPaths: maskPaths,
      );
      await loadCollections();
      await loadSessions(collectionId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save session: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadSessions(int collectionId) async {
    try {
      final sessions = await _repository.getSessionsForCollection(collectionId);
      _sessionsByCollection[collectionId] = sessions;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load sessions: $e';
      notifyListeners();
    }
  }

  Future<bool> updateSession(CountSession session) async {
    try {
      await _repository.updateSession(session: session);
      await loadCollections();
      await loadSessions(session.collectionId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update session: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteCollection(int collectionId) async {
    try {
      await _repository.deleteCollection(collectionId);
      _sessionsByCollection.remove(collectionId);
      await loadCollections();
    } catch (e) {
      _errorMessage = 'Failed to delete collection: $e';
      notifyListeners();
    }
  }

  Future<void> deleteSession(int collectionId, int sessionId) async {
    try {
      await _repository.deleteSession(sessionId);
      await loadCollections();
      await loadSessions(collectionId);
    } catch (e) {
      _errorMessage = 'Failed to delete session: $e';
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
