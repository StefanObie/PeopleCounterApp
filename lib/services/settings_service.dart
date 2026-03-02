import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _confidenceKey = 'confidence_threshold';
  static const _iouKey = 'iou_threshold';

  Future<(double confidence, double iou)> loadThresholds({
    required double defaultConfidence,
    required double defaultIou,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final confidence = prefs.getDouble(_confidenceKey) ?? defaultConfidence;
    final iou = prefs.getDouble(_iouKey) ?? defaultIou;
    return (confidence, iou);
  }

  Future<void> saveThresholds({
    required double confidence,
    required double iou,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_confidenceKey, confidence);
    await prefs.setDouble(_iouKey, iou);
  }
}
