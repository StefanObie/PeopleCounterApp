import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/coordinate_transformer.dart';

/// Represents a single drawn stroke (a series of points).
class DrawnPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const DrawnPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, Object> toJson() => {
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
      };

  factory DrawnPath.fromJson(Map<String, Object?> json) => DrawnPath(
        points: (json['points'] as List)
            .map(
              (p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ),
            )
            .toList(),
        color: Color(json['color'] as int),
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
      );

  static String encodeList(List<DrawnPath> paths) =>
      jsonEncode(paths.map((p) => p.toJson()).toList());

  static List<DrawnPath> decodeList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    final list = jsonDecode(encoded) as List;
    return list
        .map((e) => DrawnPath.fromJson(e as Map<String, Object?>))
        .toList();
  }
}

/// Painter that renders all drawn strokes.
///
/// Completed [paths] are stored in **original image pixel coordinates**.
/// They are reprojected to widget space using BoxFit.contain geometry on
/// every paint call so they stay aligned with the image regardless of
/// how the container size changes (e.g. when the result card appears).
///
/// The live [currentPath] (in-progress stroke) is in widget coordinates
/// and is rendered directly for immediate visual feedback.
class DrawingPainter extends CustomPainter {
  final List<DrawnPath> paths;
  final DrawnPath? currentPath;
  final double? imageWidth;
  final double? imageHeight;

  const DrawingPainter({
    required this.paths,
    this.currentPath,
    this.imageWidth,
    this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Completed paths — stored in image coords, reproject to widget space.
    if (paths.isNotEmpty && imageWidth != null && imageHeight != null) {
      final scale = min(size.width / imageWidth!, size.height / imageHeight!);
      final offsetX = (size.width - imageWidth! * scale) / 2;
      final offsetY = (size.height - imageHeight! * scale) / 2;

      for (final path in paths) {
        final paint = Paint()
          ..color = path.color
          ..strokeWidth = path.strokeWidth * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final pts = path.points
            .map((p) => Offset(offsetX + p.dx * scale, offsetY + p.dy * scale))
            .toList();
        for (int i = 0; i < pts.length - 1; i++) {
          canvas.drawLine(pts[i], pts[i + 1], paint);
        }
      }
    }

    // Live currentPath — in widget coords, render directly.
    if (currentPath != null) {
      final paint = Paint()
        ..color = currentPath!.color
        ..strokeWidth = currentPath!.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < currentPath!.points.length - 1; i++) {
        canvas.drawLine(
            currentPath!.points[i], currentPath!.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

/// Overlay widget that captures drawing gestures.
///
/// Completed strokes are transformed to original image pixel coordinates
/// before being passed to [onPathComplete], so the stored paths remain
/// correct regardless of any subsequent layout changes.
class DrawingOverlay extends StatefulWidget {
  final List<DrawnPath> paths;
  final Color strokeColor;
  final double strokeWidth;
  final ValueChanged<DrawnPath> onPathComplete;
  final double imageWidth;
  final double imageHeight;

  const DrawingOverlay({
    super.key,
    required this.paths,
    required this.strokeColor,
    required this.strokeWidth,
    required this.onPathComplete,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  State<DrawingOverlay> createState() => _DrawingOverlayState();
}

class _DrawingOverlayState extends State<DrawingOverlay> {
  List<Offset> _currentPoints = [];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _currentPoints = [details.localPosition];
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _currentPoints.add(details.localPosition);
        });
      },
      onPanEnd: (details) {
        if (_currentPoints.isNotEmpty) {
          // Transform widget-space points to image-space before storing,
          // so the path stays aligned when the layout changes later.
          final size = context.size!;
          final transformer = CoordinateTransformer(
            imageWidth: widget.imageWidth,
            imageHeight: widget.imageHeight,
            widgetWidth: size.width,
            widgetHeight: size.height,
          );
          widget.onPathComplete(DrawnPath(
            points: _currentPoints.map(transformer.widgetToImage).toList(),
            color: widget.strokeColor,
            strokeWidth: widget.strokeWidth / transformer.scale,
          ));
          setState(() {
            _currentPoints = [];
          });
        }
      },
      child: CustomPaint(
        painter: DrawingPainter(
          paths: widget.paths,
          currentPath: _currentPoints.isNotEmpty
              ? DrawnPath(
                  points: _currentPoints,
                  color: widget.strokeColor,
                  strokeWidth: widget.strokeWidth,
                )
              : null,
          imageWidth: widget.imageWidth,
          imageHeight: widget.imageHeight,
        ),
        child: Container(),
      ),
    );
  }
}
