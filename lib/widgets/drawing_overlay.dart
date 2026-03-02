import 'package:flutter/material.dart';

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
}

/// Painter that renders all drawn strokes.
class DrawingPainter extends CustomPainter {
  final List<DrawnPath> paths;
  final DrawnPath? currentPath;

  const DrawingPainter({
    required this.paths,
    this.currentPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in [...paths, ?currentPath]) {
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

/// Overlay widget that captures drawing gestures.
class DrawingOverlay extends StatefulWidget {
  final List<DrawnPath> paths;
  final Color strokeColor;
  final double strokeWidth;
  final ValueChanged<DrawnPath> onPathComplete;

  const DrawingOverlay({
    super.key,
    required this.paths,
    required this.strokeColor,
    required this.strokeWidth,
    required this.onPathComplete,
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
          widget.onPathComplete(DrawnPath(
            points: List.from(_currentPoints),
            color: widget.strokeColor,
            strokeWidth: widget.strokeWidth,
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
        ),
        child: Container(),
      ),
    );
  }
}
