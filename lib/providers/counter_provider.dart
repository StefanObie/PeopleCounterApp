import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../services/people_counter.dart';
import '../services/settings_service.dart';
import '../utils/coordinate_transformer.dart';
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
  Size? _imageDisplaySize; // Size of the widget displaying the image
  int? _imageWidth; // Original image dimensions
  int? _imageHeight;

  File? get selectedImage => _selectedImage;
  DetectionResult? get result => _result;
  bool get isRunning => _isRunning;
  String? get errorMessage => _errorMessage;
  bool get drawMode => _drawMode;
  List<DrawnPath> get drawnPaths => _drawnPaths;

  /// True when a history session was tapped and the app should navigate to the
  /// counter tab.  Consume with [consumeCounterNav] after switching.
  bool get pendingCounterNav => _pendingCounterNav;
  void consumeCounterNav() => _pendingCounterNav = false;
  double get confidenceThreshold => _counter.confidenceThreshold;
  double get iouThreshold => _counter.iouThreshold;

  /// Store the display size to transform drawing coordinates
  void setImageDisplaySize(Size size) {
    _imageDisplaySize = size;
  }

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
      }
    } catch (e) {
      print('Failed to load image dimensions: $e');
    }
  }

  void loadImageFromPath(String path) {
    _selectedImage = File(path);
    _result = null;
    _errorMessage = null;
    _pendingCounterNav = true;
    _drawnPaths = [];
    _drawMode = false;
    _loadImageDimensions();
    notifyListeners();
  }

  void clearImage() {
    _selectedImage = null;
    _result = null;
    _errorMessage = null;
    _drawnPaths = [];
    _drawMode = false;
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
      // Transform drawing paths from widget coordinates to image coordinates
      List<DrawnPath>? transformedPaths;
      if (_drawnPaths.isNotEmpty && 
          _imageDisplaySize != null && 
          _imageWidth != null && 
          _imageHeight != null) {
        final transformer = CoordinateTransformer(
          imageWidth: _imageWidth!.toDouble(),
          imageHeight: _imageHeight!.toDouble(),
          widgetWidth: _imageDisplaySize!.width,
          widgetHeight: _imageDisplaySize!.height,
        );

        transformedPaths = _drawnPaths.map((path) {
          return DrawnPath(
            points: path.points.map(transformer.widgetToImage).toList(),
            color: path.color,
            strokeWidth: path.strokeWidth / transformer.scale,
          );
        }).toList();
      }

      _result = await _counter.detectFromFile(image, maskPaths: transformedPaths);
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
    _loadImageDimensions();
    notifyListeners();
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
