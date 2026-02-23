import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Represents a single detected bounding box.
class Detection {
  final double x1, y1, x2, y2;
  final double confidence;
  final int classId;

  const Detection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.confidence,
    required this.classId,
  });

  @override
  String toString() =>
      'Detection(class=$classId, conf=${confidence.toStringAsFixed(3)}, '
      'box=[${x1.toStringAsFixed(1)}, ${y1.toStringAsFixed(1)}, '
      '${x2.toStringAsFixed(1)}, ${y2.toStringAsFixed(1)}])';
}

/// Result returned by [PeopleCounter.detectFromFile], bundling the surviving
/// detections together with the original image size needed for rendering.
class DetectionResult {
  final List<Detection> detections;
  final int imageWidth;
  final int imageHeight;

  const DetectionResult({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  int get count => detections.length;
}

/// Runs YOLOv5 TFLite inference and returns a people count.
class PeopleCounter {
  late Interpreter _interpreter;
  late int _numClasses;
  late List<int> _outputShape;

  static const int inputSize = 640;
  static const String modelAsset = 'assets/models/crowdhuman_yolov5m.tflite';

  /// Minimum confidence score for a detection to be kept. Adjustable at runtime.
  double confidenceThreshold = 0.35;

  /// IoU threshold for non-maximum suppression. Adjustable at runtime.
  double iouThreshold = 0.6;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(modelAsset);

    final inputShape = _interpreter.getInputTensor(0).shape;
    _outputShape = _interpreter.getOutputTensor(0).shape;

    // YOLOv5 output: [1, num_boxes, 5 + num_classes]
    // e.g. [1, 25200, 85] for COCO or [1, 25200, 6] for 1-class CrowdHuman
    _numClasses = _outputShape.length == 3 ? _outputShape[2] - 5 : 1;

    print('[PeopleCounter] Model loaded.');
    print('[PeopleCounter]   Input shape : $inputShape');
    print('[PeopleCounter]   Output shape: $_outputShape');
    print('[PeopleCounter]   Num classes : $_numClasses');
  }

  /// Runs inference on a Flutter bundle asset (e.g. 'assets/test_image.jpg').
  Future<int> countFromAsset(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();
    return _runInference(bytes);
  }

  /// Runs inference on an image [File] selected from the gallery or camera.
  Future<int> countFromFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return _runInference(bytes);
  }

  /// Runs inference, returning detections and original image dimensions.
  Future<DetectionResult> detectFromFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return _runDetections(bytes);
  }

  Future<int> _runInference(Uint8List imageBytes) async {
    final result = await _runDetections(imageBytes);
    return result.count;
  }

  Future<DetectionResult> _runDetections(Uint8List imageBytes) async {
    // ── Preprocess ─────────────────────────────────────────────────────────
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Failed to decode image');

    final resized = img.copyResize(
      decoded,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Build [1, 640, 640, 3] float32 tensor, normalised to [0, 1].
    final inputTensor = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    // ── Inference ───────────────────────────────────────────────────────────
    final output = List.generate(
      _outputShape[0],
      (_) => List.generate(
        _outputShape[1],
        (_) => List.filled(_outputShape[2], 0.0),
      ),
    );

    _interpreter.run(inputTensor, output);

    // ── Post-process ────────────────────────────────────────────────────────
    final detections = _parseDetections(output[0]);
    final kept = _applyNMS(detections);

    print('[PeopleCounter] Raw candidates : ${detections.length}');
    print('[PeopleCounter] After NMS      : ${kept.length}');

    return DetectionResult(
      detections: kept,
      imageWidth: decoded.width,
      imageHeight: decoded.height,
    );
  }

  /// Converts raw YOLOv5 output rows into [Detection] objects, filtering by
  /// [confidenceThreshold].
  List<Detection> _parseDetections(List<List<double>> rows) {
    final detections = <Detection>[];

    for (final row in rows) {
      // row layout: [cx, cy, w, h, objectness, class_0, class_1, ...]
      final objectness = row[4];
      if (objectness < confidenceThreshold) continue;

      int bestClass = 0;
      double bestScore = 0.0;
      for (int c = 0; c < _numClasses; c++) {
        final s = row[5 + c];
        if (s > bestScore) {
          bestScore = s;
          bestClass = c;
        }
      }

      final confidence = objectness * bestScore;
      if (confidence < confidenceThreshold) continue;

      // Only keep head detections (class 1); ignore person boxes (class 0).
      if (bestClass != 1) continue;

      final cx = row[0], cy = row[1], w = row[2], h = row[3];

      detections.add(Detection(
        x1: cx - w / 2,
        y1: cy - h / 2,
        x2: cx + w / 2,
        y2: cy + h / 2,
        confidence: confidence,
        classId: bestClass,
      ));
    }

    return detections;
  }

  /// Greedy NMS — keeps the highest-confidence box and removes any box that
  /// overlaps it by more than [iouThreshold].
  List<Detection> _applyNMS(List<Detection> detections) {
    if (detections.isEmpty) return [];

    // Sort descending by confidence.
    final sorted = List<Detection>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <Detection>[];
    while (sorted.isNotEmpty) {
      final best = sorted.removeAt(0);
      kept.add(best);
      sorted.removeWhere((d) => _iou(best, d) > iouThreshold);
    }

    return kept;
  }

  double _iou(Detection a, Detection b) {
    final ix1 = a.x1 > b.x1 ? a.x1 : b.x1;
    final iy1 = a.y1 > b.y1 ? a.y1 : b.y1;
    final ix2 = a.x2 < b.x2 ? a.x2 : b.x2;
    final iy2 = a.y2 < b.y2 ? a.y2 : b.y2;

    final iw = ix2 - ix1;
    final ih = iy2 - iy1;
    if (iw <= 0 || ih <= 0) return 0.0;

    final interArea = iw * ih;
    final aArea = (a.x2 - a.x1) * (a.y2 - a.y1);
    final bArea = (b.x2 - b.x1) * (b.y2 - b.y1);

    return interArea / (aArea + bArea - interArea);
  }
}
