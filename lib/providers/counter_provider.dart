import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../services/people_counter.dart';
import '../services/settings_service.dart';
import '../widgets/drawing_overlay.dart';

class CounterProvider extends ChangeNotifier {
  CounterProvider(this._counter, this._settingsService);

  final PeopleCounter _counter;
  final SettingsService _settingsService;
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  DetectionResult? _result;
  bool _isRunning = false;
  String? _errorMessage;
  bool _pendingCounterNav = false;
  bool _drawMode = false;
  List<DrawnPath> _drawnPaths = [];
  int? _activeSessionId;
  int? _activeCollectionId;
  int _activeCorrection = 0;
  String? _activeNotes;
  int? _imageWidth; // Original image dimensions
  int? _imageHeight;

  File? get selectedImage => _selectedImage;
  DetectionResult? get result => _result;
  bool get isRunning => _isRunning;
  String? get errorMessage => _errorMessage;
  bool get drawMode => _drawMode;
  List<DrawnPath> get drawnPaths => _drawnPaths;
  int? get activeSessionId => _activeSessionId;
  int? get activeCollectionId => _activeCollectionId;
  int get activeCorrection => _activeCorrection;
  String? get activeNotes => _activeNotes;
  bool get isEditingSavedSession => _activeSessionId != null;
  int? get imageWidth => _imageWidth;
  int? get imageHeight => _imageHeight;

  /// True when a history session was tapped and the app should navigate to the
  /// counter tab.  Consume with [consumeCounterNav] after switching.
  bool get pendingCounterNav => _pendingCounterNav;
  void consumeCounterNav() => _pendingCounterNav = false;
  double get confidenceThreshold => _counter.confidenceThreshold;
  double get iouThreshold => _counter.iouThreshold;

  Future<void> initialize() async {
    final thresholds = await _settingsService.loadThresholds(
      defaultConfidence: _counter.confidenceThreshold,
      defaultIou: _counter.iouThreshold,
    );
    _counter.confidenceThreshold = thresholds.$1;
    _counter.iouThreshold = thresholds.$2;
    notifyListeners();
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    _selectedImage = File(picked.path);
    _result = null;
    _errorMessage = null;
    _drawnPaths = [];
    _drawMode = false;
    clearActiveSessionContext();
    
    // Load image dimensions
    await _loadImageDimensions();
    
    notifyListeners();
  }

  Future<void> _loadImageDimensions() async {
    if (_selectedImage == null) return;
    
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        notifyListeners();
      }
    } catch (e) {
      print('Failed to load image dimensions: $e');
    }
  }

  void loadImageFromPath(
    String path, {
    int? sessionId,
    int? collectionId,
    int? correction,
    String? notes,
    List<DrawnPath>? maskPaths,
    double? confidenceThreshold,
    double? iouThreshold,
  }) {
    _selectedImage = File(path);
    _result = null;
    _errorMessage = null;
    _pendingCounterNav = true;
    _drawnPaths = maskPaths != null ? List.from(maskPaths) : [];
    _drawMode = false;
    _activeSessionId = sessionId;
    _activeCollectionId = collectionId;
    _activeCorrection = correction ?? 0;
    _activeNotes = notes;
    if (confidenceThreshold != null) {
      _counter.confidenceThreshold = confidenceThreshold;
    }
    if (iouThreshold != null) {
      _counter.iouThreshold = iouThreshold;
    }
    _loadImageDimensions();
    notifyListeners();
  }

  void clearImage() {
    _selectedImage = null;
    _result = null;
    _errorMessage = null;
    _drawnPaths = [];
    _drawMode = false;
    clearActiveSessionContext();
    _imageWidth = null;
    _imageHeight = null;
    notifyListeners();
  }

  Future<void> runInference() async {
    final image = _selectedImage;
    if (image == null) return;

    _isRunning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _result = await _counter.detectFromFile(
        image,
        maskPaths: _drawnPaths.isNotEmpty ? _drawnPaths : null,
      );
    } catch (e) {
      _errorMessage = 'Inference failed: $e';
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> updateThresholds({
    required double confidence,
    required double iou,
  }) async {
    _counter.confidenceThreshold = confidence;
    _counter.iouThreshold = iou;
    notifyListeners();

    await _settingsService.saveThresholds(confidence: confidence, iou: iou);
  }

  void clearResult() {
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }

  void loadImageFromFile(File file) {
    _selectedImage = file;
    _result = null;
    _errorMessage = null;
    _drawnPaths = [];
    _drawMode = false;
    clearActiveSessionContext();
    _loadImageDimensions();
    notifyListeners();
  }

  void clearActiveSessionContext() {
    _activeSessionId = null;
    _activeCollectionId = null;
    _activeCorrection = 0;
    _activeNotes = null;
  }

  void toggleDrawMode() {
    _drawMode = !_drawMode;
    notifyListeners();
  }

  void addDrawnPath(DrawnPath path) {
    _drawnPaths.add(path);
    notifyListeners();
  }

  void undoLastPath() {
    if (_drawnPaths.isNotEmpty) {
      _drawnPaths.removeLast();
      notifyListeners();
    }
  }

  void clearDrawings() {
    _drawnPaths.clear();
    notifyListeners();
  }
}
