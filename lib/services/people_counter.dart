import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../widgets/drawing_overlay.dart';

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

/// Metadata produced during letterbox preprocessing.
class _LetterboxResult {
  final img.Image image;
  final double scale;
  final double padX;
  final double padY;

  const _LetterboxResult({
    required this.image,
    required this.scale,
    required this.padX,
    required this.padY,
  });
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
  /// Optionally accepts [maskPaths] to exclude drawn areas from detection.
  Future<DetectionResult> detectFromFile(
    File imageFile, {
    List<DrawnPath>? maskPaths,
  }) async {
    final bytes = await imageFile.readAsBytes();
    return _runDetections(bytes, maskPaths: maskPaths);
  }

  Future<int> _runInference(Uint8List imageBytes) async {
    final result = await _runDetections(imageBytes);
    return result.count;
  }

  Future<DetectionResult> _runDetections(
    Uint8List imageBytes, {
    List<DrawnPath>? maskPaths,
  }) async {
    // ── Preprocess ─────────────────────────────────────────────────────────
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Failed to decode image');

    // Letterbox first — much faster to apply mask on 640×640 than on full-res.
    final letterboxed = _letterbox(decoded);
    var letterboxedImage = letterboxed.image;

    // Apply mask on the 640×640 letterboxed image for performance.
    // Paths are in original image coords; transform to letterboxed space.
    if (maskPaths != null && maskPaths.isNotEmpty) {
      final transformedPaths = maskPaths.map((path) {
        return DrawnPath(
          points: path.points
              .map(
                (p) => Offset(
                  p.dx * letterboxed.scale + letterboxed.padX,
                  p.dy * letterboxed.scale + letterboxed.padY,
                ),
              )
              .toList(),
          color: path.color,
          strokeWidth: path.strokeWidth * letterboxed.scale,
        );
      }).toList();
      letterboxedImage = await _applyMask(letterboxedImage, transformedPaths);
    }

    // Build [1, 640, 640, 3] float32 tensor, normalised to [0, 1].
    final inputTensor = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = letterboxedImage.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
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
    final mapped = kept
        .map(
          (d) => _mapDetectionToOriginal(
            d,
            imageWidth: decoded.width.toDouble(),
            imageHeight: decoded.height.toDouble(),
            scale: letterboxed.scale,
            padX: letterboxed.padX,
            padY: letterboxed.padY,
          ),
        )
        .whereType<Detection>()
        .toList();

    print('[PeopleCounter] Raw candidates : ${detections.length}');
    print('[PeopleCounter] After NMS      : ${kept.length}');
    print('[PeopleCounter] After unpad    : ${mapped.length}');

    return DetectionResult(
      detections: mapped,
      imageWidth: decoded.width,
      imageHeight: decoded.height,
    );
  }

  _LetterboxResult _letterbox(img.Image source) {
    final scale = min(inputSize / source.width, inputSize / source.height);

    final resizedWidth = (source.width * scale).round();
    final resizedHeight = (source.height * scale).round();

    final resized = img.copyResize(
      source,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );

    final padX = ((inputSize - resizedWidth) ~/ 2).toDouble();
    final padY = ((inputSize - resizedHeight) ~/ 2).toDouble();

    final canvas = img.Image(width: inputSize, height: inputSize);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(canvas, resized, dstX: padX.toInt(), dstY: padY.toInt());

    return _LetterboxResult(
      image: canvas,
      scale: scale,
      padX: padX,
      padY: padY,
    );
  }

  Detection? _mapDetectionToOriginal(
    Detection det, {
    required double imageWidth,
    required double imageHeight,
    required double scale,
    required double padX,
    required double padY,
  }) {
    final x1 = ((det.x1 - padX) / scale).clamp(0.0, imageWidth);
    final y1 = ((det.y1 - padY) / scale).clamp(0.0, imageHeight);
    final x2 = ((det.x2 - padX) / scale).clamp(0.0, imageWidth);
    final y2 = ((det.y2 - padY) / scale).clamp(0.0, imageHeight);

    if (x2 <= x1 || y2 <= y1) return null;

    return Detection(
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      confidence: det.confidence,
      classId: det.classId,
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

      detections.add(
        Detection(
          x1: cx - w / 2,
          y1: cy - h / 2,
          x2: cx + w / 2,
          y2: cy + h / 2,
          confidence: confidence,
          classId: bestClass,
        ),
      );
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

  /// Applies mask by painting over drawn paths with black pixels.
  Future<img.Image> _applyMask(
    img.Image source,
    List<DrawnPath> paths,
  ) async {
    // Create a copy to avoid mutating the original
    final masked = img.Image.from(source);

    // Draw each path as a thick line on the image
    for (final path in paths) {
      for (int i = 0; i < path.points.length - 1; i++) {
        final p1 = path.points[i];
        final p2 = path.points[i + 1];

        // Scale points from widget coordinates to image coordinates
        // (This assumes paths were drawn relative to the actual image display)
        _drawThickLine(
          masked,
          p1.dx.toInt(),
          p1.dy.toInt(),
          p2.dx.toInt(),
          p2.dy.toInt(),
          path.strokeWidth.toInt(),
        );
      }
    }

    return masked;
  }

  /// Draws a thick line on the image by painting black pixels.
  void _drawThickLine(
    img.Image image,
    int x1,
    int y1,
    int x2,
    int y2,
    int thickness,
  ) {
    final black = img.ColorRgb8(0, 0, 0);
    
    // Bresenham's line algorithm with thickness
    final dx = (x2 - x1).abs();
    final dy = (y2 - y1).abs();
    final sx = x1 < x2 ? 1 : -1;
    final sy = y1 < y2 ? 1 : -1;
    var err = dx - dy;

    var x = x1;
    var y = y1;

    while (true) {
      // Draw a circle of pixels at this point for thickness
      for (int dy = -thickness ~/ 2; dy <= thickness ~/ 2; dy++) {
        for (int dx = -thickness ~/ 2; dx <= thickness ~/ 2; dx++) {
          if (dx * dx + dy * dy <= (thickness ~/ 2) * (thickness ~/ 2)) {
            final px = x + dx;
            final py = y + dy;
            if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
              image.setPixel(px, py, black);
            }
          }
        }
      }

      if (x == x2 && y == y2) break;

      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }
}
