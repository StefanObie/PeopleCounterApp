import 'dart:math';
import 'dart:ui';

/// Helper class to transform coordinates between widget display space and
/// original image space, accounting for BoxFit.contain letterboxing.
class CoordinateTransformer {
  final double imageWidth;
  final double imageHeight;
  final double widgetWidth;
  final double widgetHeight;

  late final double scale;
  late final double offsetX;
  late final double offsetY;

  CoordinateTransformer({
    required this.imageWidth,
    required this.imageHeight,
    required this.widgetWidth,
    required this.widgetHeight,
  }) {
    // BoxFit.contain geometry
    scale = min(widgetWidth / imageWidth, widgetHeight / imageHeight);
    offsetX = (widgetWidth - imageWidth * scale) / 2;
    offsetY = (widgetHeight - imageHeight * scale) / 2;
  }

  /// Transforms a point from widget display space to original image space.
  Offset widgetToImage(Offset widgetPoint) {
    final imgX = (widgetPoint.dx - offsetX) / scale;
    final imgY = (widgetPoint.dy - offsetY) / scale;
    return Offset(imgX, imgY);
  }

  /// Transforms a point from original image space to widget display space.
  Offset imageToWidget(Offset imagePoint) {
    final widgetX = offsetX + imagePoint.dx * scale;
    final widgetY = offsetY + imagePoint.dy * scale;
    return Offset(widgetX, widgetY);
  }
}
