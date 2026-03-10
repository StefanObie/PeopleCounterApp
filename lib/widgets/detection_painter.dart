import 'dart:math';

import 'package:flutter/material.dart';

import '../services/people_counter.dart';

/// Draws YOLOv5 bounding boxes over the image preview.
///
/// Coordinate mapping
/// ──────────────────
/// Detections are returned in original image coordinates. The image widget
/// uses BoxFit.contain, so this painter only applies the display transform:
///      scale   = min(widgetW / imgW,  widgetH / imgH)
///      offsetX = (widgetW - imgW * scale) / 2
///      offsetY = (widgetH - imgH * scale) / 2
///      widgetX = offsetX + origX * scale
class DetectionPainter extends CustomPainter {
  final DetectionResult result;

  DetectionPainter(this.result);

  static const double _strokeWidth = 1;
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
      final left = offsetX + det.x1 * scale;
      final top = offsetY + det.y1 * scale;
      final right = offsetX + det.x2 * scale;
      final bottom = offsetY + det.y2 * scale;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, boxPaint);
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) =>
      oldDelegate.result != result;
}
