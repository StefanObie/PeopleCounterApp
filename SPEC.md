# Church People Counter — Flutter Mobile App Spec

## Project Overview

Migrate an existing Python/Flask people-counting web app to a fully offline, privacy-first Flutter Android app. All ML inference runs on-device using TensorFlow Lite. No data ever leaves the user's device.

**Primary driver:** Renew Google Play Developer license by publishing a functional app.  
**Secondary goals:** On-device privacy, count history, native performance, offline-first operation.

---

## Current Stack (Source of Truth)

| Component | Technology |
|---|---|
| ML Model | Fine-tuned YOLOv5 (`.pt` PyTorch checkpoint) |
| Backend | Python + Flask |
| Frontend | Basic HTML/JS webpage |
| Deployment | Server-side (online) |

---

## Target Stack

| Component | Technology |
|---|---|
| App framework | Flutter (Dart) |
| ML runtime | TensorFlow Lite (`tflite_flutter`) |
| Model format | `.tflite` (float32, no quantization initially) |
| Local database | SQLite via `sqflite` |
| Camera | `camera` or `image_picker` Flutter plugin |
| Platform | Android (primary), iOS (optional later) |

---

## Phase 0 — Model Conversion and Validation (Do This First)

This phase is entirely in Python and must be completed before any Flutter work begins. It de-risks the entire project.

### Step 1: Export YOLOv5 → ONNX

```bash
# Run from within your YOLOv5 repo
python export.py --weights your_model.pt --include onnx --imgsz 640
```

### Step 2: Convert ONNX → TFLite

```bash
pip install onnx2tf
onnx2tf -i your_model.onnx -o tflite_output
```

The output `.tflite` file will be in `tflite_output/`. Use the **float32 variant** — do not apply quantization yet.

### Step 3: Validate Accuracy

Run both the original `.pt` model and the converted `.tflite` model on the same set of test images and compare detection counts and bounding box coordinates.

```python
import tensorflow as tf
import numpy as np
from PIL import Image

def run_tflite_inference(model_path, image_path, input_size=640):
    # Load interpreter
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    # Preprocess image — must match YOLOv5 preprocessing exactly
    img = Image.open(image_path).convert("RGB")
    img = img.resize((input_size, input_size))
    img_array = np.array(img, dtype=np.float32) / 255.0  # normalize to [0, 1]
    img_array = np.expand_dims(img_array, axis=0)        # add batch dim [1, 640, 640, 3]

    interpreter.set_tensor(input_details[0]['index'], img_array)
    interpreter.invoke()

    output = interpreter.get_tensor(output_details[0]['index'])
    return output

# Compare against your existing Python YOLOv5 inference on the same images
```

**Go/No-Go Criteria:**
- Detection counts match within ±1 on your test images → proceed
- Significant divergence → investigate preprocessing differences before continuing

### Key Conversion Risks

- **Color channel order:** YOLOv5 expects RGB. Verify your existing Python pipeline isn't using BGR (OpenCV default).
- **Input normalization:** Must be `/ 255.0` to match training. Any difference here causes silent accuracy loss.
- **NMS:** YOLOv5 ONNX export may or may not include NMS in the graph. Confirm whether post-processing needs to be done manually.

---

## Phase 1 — Minimal Flutter App (MVP for Play Store)

Goal: A working app that loads the TFLite model, accepts an image, and returns a count. This is the minimum viable upload for the Play Store.

### Flutter Project Setup

```bash
flutter create church_counter
cd church_counter
```

### Required Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  tflite_flutter: ^0.10.4
  image_picker: ^1.0.0
  image: ^4.0.0        # Pure Dart image processing
  sqflite: ^2.3.0      # Local database (Phase 2)
  path_provider: ^2.1.0
```

### Model Asset Setup

Place the `.tflite` file in `assets/models/` and register it:

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/models/church_counter.tflite
```

### Inference Pipeline (Dart)

The inference logic mirrors your Python validation script. Key steps:

1. **Load model** — done once at app startup, keep interpreter in memory
2. **Preprocess image** — resize to 640×640, normalize pixels to `[0.0, 1.0]`, reshape to `[1, 640, 640, 3]`
3. **Run inference** — feed tensor to TFLite interpreter
4. **Post-process** — apply Non-Maximum Suppression (NMS) to filter overlapping boxes
5. **Count** — number of surviving boxes = people count

```dart
// Conceptual structure — flesh out with tflite_flutter API
class PeopleCounter {
  late Interpreter _interpreter;
  static const int inputSize = 640;
  static const double confidenceThreshold = 0.5;
  static const double iouThreshold = 0.45;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/models/church_counter.tflite');
  }

  Future<int> countPeople(File imageFile) async {
    final input = await _preprocessImage(imageFile);
    final output = /* run interpreter */;
    final boxes = _applyNMS(output, confidenceThreshold, iouThreshold);
    return boxes.length;
  }

  // Preprocessing: resize → normalize → reshape
  // NMS: filter boxes by confidence, then by IoU overlap
}
```

> **Note:** NMS must be implemented in Dart if it is not baked into your TFLite graph. Reference implementations exist — do not write from scratch. Search for `YOLOv5 Flutter NMS Dart` for community implementations to adapt.

### MVP Screen

A single screen with:
- Button to capture image (camera) or pick from gallery
- Display selected image
- "Count People" button
- Result displayed as a large number

---

## Phase 2 — History and Full Feature Set

Once the MVP is on the Play Store, add these features iteratively.

### Local Database Schema (SQLite)

```sql
CREATE TABLE count_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,           -- ISO 8601
  count INTEGER NOT NULL,
  image_path TEXT,                   -- local file path, nullable
  location_label TEXT,               -- e.g. "Main Hall", user-defined
  notes TEXT
);
```

### Feature List

| Feature | Priority | Notes |
|---|---|---|
| Capture from camera | High | Use `camera` plugin for live preview |
| Pick from gallery | High | Use `image_picker` |
| Display bounding boxes | Medium | Draw overlays on image canvas |
| Save count to history | High | SQLite via `sqflite` |
| History list view | High | Grouped by date |
| Location labels | Medium | User-defined tags e.g. "Sunday Service" |
| Export history as CSV | Low | Share via Android share sheet |
| Confidence threshold setting | Medium | Let user tune sensitivity |
| Quantized model option | Low | Smaller/faster, validate accuracy first |

### App Navigation Structure

```
HomeScreen
├── CameraScreen (capture image)
├── ResultScreen (show count + bounding boxes)
│   └── SaveScreen (add label/notes before saving)
└── HistoryScreen
    └── SessionDetailScreen
```

---

## Phase 3 — Optimisation (Optional)

Only pursue these after the app is stable and published.

### Quantization

Apply post-training quantization to reduce model size and improve inference speed on lower-end devices. Validate accuracy is acceptable before shipping.

```python
# INT8 quantization example
converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
# Provide representative dataset for full integer quantization
tflite_quant_model = converter.convert()
```

### Hardware Acceleration

Enable GPU or NNAPI delegate in Flutter for faster inference on supported devices:

```dart
// GPU delegate
final options = InterpreterOptions()..addDelegate(GpuDelegateV2());
final interpreter = await Interpreter.fromAsset('model.tflite', options: options);
```

Test on target devices — not all devices support all delegates reliably.

---

## Privacy Design Principles

These should be maintained throughout development and documented in the Play Store listing.

- No network permissions required (do not add `INTERNET` to `AndroidManifest.xml`)
- No analytics, no crash reporting SDKs that phone home
- Images are processed in memory and never written to disk unless the user explicitly saves them
- Saved images stay in app-private storage, not the public gallery
- No account creation or login required

---

## Play Store Submission Checklist

- [ ] App icon (512×512 PNG)
- [ ] Feature graphic (1024×500 PNG)
- [ ] At least 2 screenshots
- [ ] Short description (80 chars max)
- [ ] Full description highlighting offline/privacy angle
- [ ] Privacy policy URL (required even for offline apps — host a simple one)
- [ ] Content rating questionnaire completed
- [ ] Target SDK ≥ 34 (current Play Store requirement)
- [ ] Release signed APK or AAB with upload keystore

> **Keep your upload keystore safe.** If you lose it, you cannot update the app. Store it outside the project directory and back it up.

---

## Recommended Build Order

```
Phase 0: Convert model → validate accuracy in Python
    ↓
Phase 1a: Flutter project setup + model loads without crashing
    ↓
Phase 1b: Inference runs on a hardcoded test image, correct count returned
    ↓
Phase 1c: Camera/gallery input working
    ↓
Phase 1d: Polish MVP UI → submit to Play Store (solves license expiry)
    ↓
Phase 2a: SQLite history
    ↓
Phase 2b: Bounding box overlay display
    ↓
Phase 2c: Settings screen (confidence threshold, location labels)
    ↓
Phase 3: Optimisation if needed
```

---

## Reference Resources

| Resource | URL |
|---|---|
| tflite_flutter plugin | https://pub.dev/packages/tflite_flutter |
| YOLOv5 export docs | https://docs.ultralytics.com/yolov5/tutorials/model_export/ |
| onnx2tf converter | https://github.com/PINTO0309/onnx2tf |
| sqflite plugin | https://pub.dev/packages/sqflite |
| Flutter camera plugin | https://pub.dev/packages/camera |
| Play Store target API requirements | https://developer.android.com/google/play/requirements/target-sdk |

---

*Spec version 1.0 — generated from design discussion. Revisit after Phase 0 validation results are known.*
