import 'dart:math';

import 'package:flutter/material.dart';

import 'people_counter.dart';

/// Draws YOLOv5 bounding boxes over the image preview.
///
/// Coordinate mapping
/// ──────────────────
/// The model preprocessed the image by stretching it to 640×640, so every
/// Detection stores coordinates in that 640×640 space.  The image widget
/// uses BoxFit.contain, which letterboxes the original aspect ratio inside
/// the available widget area.  The painter therefore applies two transforms:
///
///   1. Model space → original image space
///      nx = det.x / 640,  ny = det.y / 640
///      origX = nx * imgW, origY = ny * imgH
///
///   2. Original image space → widget display space  (BoxFit.contain)
///      scale   = min(widgetW / imgW,  widgetH / imgH)
///      offsetX = (widgetW - imgW * scale) / 2
///      offsetY = (widgetH - imgH * scale) / 2
///      widgetX = offsetX + origX * scale
class DetectionPainter extends CustomPainter {
  final DetectionResult result;

  DetectionPainter(this.result);

  static const double _strokeWidth = 1;
  static const double _fontSize = 12;
  static const Color _boxColour = Color.fromARGB(255, 128, 255, 0);

  @override
  void paint(Canvas canvas, Size size) {
    if (result.detections.isEmpty) return;

    final imgW = result.imageWidth.toDouble();
    final imgH = result.imageHeight.toDouble();

    // BoxFit.contain geometry
    final scale = min(size.width / imgW, size.height / imgH);
    final offsetX = (size.width - imgW * scale) / 2;
    final offsetY = (size.height - imgH * scale) / 2;

    final boxPaint = Paint()
      ..color = _boxColour
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final fillPaint = Paint()
      ..color = _boxColour.withAlpha(25)
      ..style = PaintingStyle.fill;

    for (final det in result.detections) {
      final left =
          offsetX + (det.x1 / PeopleCounter.inputSize) * imgW * scale;
      final top =
          offsetY + (det.y1 / PeopleCounter.inputSize) * imgH * scale;
      final right =
          offsetX + (det.x2 / PeopleCounter.inputSize) * imgW * scale;
      final bottom =
          offsetY + (det.y2 / PeopleCounter.inputSize) * imgH * scale;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, boxPaint);

      // _drawLabel(
      //   canvas,
      //   label: '${(det.confidence * 100).toStringAsFixed(0)}%',
      //   x: left,
      //   y: top,
      // );
    }
  }

  void _drawLabel(Canvas canvas, {required String label, required double x, required double y}) {
    final tp = TextPainter(
      text: TextSpan(
        text: ' $label ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Badge background
    const padding = 2.0;
    final bgRect = Rect.fromLTWH(
      x - padding,
      y - tp.height - padding * 2,
      tp.width + padding * 2,
      tp.height + padding * 2,
    );
    canvas.drawRect(bgRect, Paint()..color = _boxColour);

    // Text — draw just above the top-left corner of the box
    tp.paint(canvas, Offset(x, y - tp.height - padding));
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) =>
      oldDelegate.result != result;
}
