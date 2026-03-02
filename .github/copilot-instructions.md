# People Counter App — AI Agent Instructions

## Project Overview

Flutter mobile app for counting people in images using a YOLOv5 TFLite model. **Privacy-first and offline-only**: all ML inference runs on-device, no network permissions.

**Model**: CrowdHuman-trained YOLOv5m detects **heads (class 1)** instead of full person boxes for better accuracy in crowded scenes.

### Critical Data Flow

1. User picks image → `main.dart` gets File
2. `PeopleCounter.detectFromFile()` runs inference pipeline:
   - Decode image → resize to 640×640 → normalize to [0,1] RGB
   - Run TFLite interpreter
   - Parse raw output → filter by confidence → **filter class 1 only** → NMS
3. Returns `DetectionResult` with bounding boxes + original image dimensions
4. `DetectionPainter` transforms coordinates: model space (640×640) → original image → widget display (BoxFit.contain letterboxing)

## Model-Specific Knowledge

### Hard-Coded Filtering ([people_counter.dart#L168](../lib/people_counter.dart))
```dart
// Only keep head detections (class 1); ignore person boxes (class 0).
if (bestClass != 1) continue;
```
**Why**: The CrowdHuman model outputs 2 classes — full person (0) and head (1). We count heads for better accuracy in dense crowds.

### Preprocessing Requirements
- **Input shape**: `[1, 640, 640, 3]` float32
- **Color space**: RGB (not BGR)
- **Normalization**: `pixel / 255.0` to range [0, 1]
- **Resize**: Linear interpolation using `image` package

### Output Shape
`[1, 25200, 6]` where each row is `[cx, cy, w, h, objectness, class_0_score, class_1_score]`

### NMS Implementation
Greedy NMS in Dart ([people_counter.dart#L196-L209](..\lib\people_counter.dart)). Not baked into the TFLite graph — must be done manually in post-processing.

## Coordinate Transformation Logic

**Critical for bounding box display** ([detection_painter.dart#L48-L57](../lib/detection_painter.dart)):

```dart
// Step 1: Model space (640×640) → Original image space
final origX = (det.x1 / 640) * imageWidth;

// Step 2: Original image → Widget display (BoxFit.contain)
final scale = min(widgetWidth / imageWidth, widgetHeight / imageHeight);
final offsetX = (widgetWidth - imageWidth * scale) / 2;
final widgetX = offsetX + origX * scale;
```

Image uses `BoxFit.contain`, so letterboxing offsets must be calculated. Any change to the fit mode breaks coordinate mapping.

## Flutter Development Workflow

### Run App
```bash
flutter run                    # Hot reload enabled
flutter run --release          # Test performance
```

### Build
```bash
flutter build apk              # Android APK
flutter build appbundle        # Play Store AAB
```

### Model Asset Path
`assets/models/crowdhuman_yolov5m.tflite` — registered in `pubspec.yaml`. Changes require `flutter clean` + full rebuild.

### Key Dependencies
- `tflite_flutter: ^0.12.1` — TFLite interpreter
- `image: ^4.0.0` — Pure Dart image processing (decoding, resizing)
- `image_picker: ^1.0.0` — Gallery/camera access

### Settings Modal
Bottom sheet with real-time threshold adjustment. Changes apply immediately to the `PeopleCounter` instance passed via constructor.

## Privacy Design Constraints

1. **NO network permissions** — Do not add `INTERNET` to Android manifest
4. **Offline-first** — All features must work airplane mode

## Common Modifications

### Adjust Detection Thresholds
- **Confidence**: Lower = more detections (more false positives). Default 0.35
- **IoU (NMS)**: Lower = aggressively merges boxes. Default 0.6
- Both exposed in settings UI, stored as mutable fields in `PeopleCounter`

### Change Input Size
Changing from 640×640 requires:
1. Re-export model with new `--imgsz` in YOLOv5
2. Update `PeopleCounter.inputSize` constant
3. Verify coordinate transformations still work

## Testing Strategy

### Quick Validation
Run on `assets/test_image.jpg` (bundled test asset). Expected: consistent count across runs.

### Device Testing
- Test on low-end Android (inference time)
- Test landscape/portrait orientation (coordinate mapping)
- Test varied image aspect ratios (letterboxing edge cases)

## Troubleshooting

### "Failed to load model"
- Check `assets/models/crowdhuman_yolov5m.tflite` exists
- Run `flutter clean && flutter pub get`
- Verify `pubspec.yaml` assets section

### Wrong Bounding Box Positions
- Verify image fit mode is `BoxFit.contain` in `main.dart`
- Check `DetectionPainter` scale/offset calculations
- Confirm preprocessing uses same 640×640 as model training

### Low Detection Count
- Lower confidence threshold in settings
- Verify image quality (blurry images fail)
- Check if people's heads are visible (model detects heads, not bodies)

## Reference Files

- **Full spec**: [SPEC.md](../SPEC.md) — Original project specification with model conversion steps
- **Model asset**: `assets/models/crowdhuman_yolov5m.tflite` (not in VCS, must be generated)
- **Test image**: `assets/test_image.jpg` — For regression testing
