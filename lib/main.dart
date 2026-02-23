import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'detection_painter.dart';
import 'people_counter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final counter = PeopleCounter();
  try {
    await counter.loadModel();
  } catch (e, st) {
    debugPrint('[main] Failed to load model: $e\n$st');
  }

  runApp(MyApp(peopleCounter: counter));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.peopleCounter});

  final PeopleCounter peopleCounter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'People Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: PeopleCounterHome(peopleCounter: peopleCounter),
    );
  }
}

class PeopleCounterHome extends StatefulWidget {
  const PeopleCounterHome({super.key, required this.peopleCounter});

  final PeopleCounter peopleCounter;

  @override
  State<PeopleCounterHome> createState() => _PeopleCounterHomeState();
}

class _PeopleCounterHomeState extends State<PeopleCounterHome> {
  final _picker = ImagePicker();

  File? _selectedImage;
  DetectionResult? _result;
  bool _isRunning = false;
  String? _errorMessage;

  Future<void> _showSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _SettingsSheet(counter: widget.peopleCounter),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _runInference() async {
    final image = _selectedImage;
    if (image == null) return;

    setState(() {
      _isRunning = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.peopleCounter.detectFromFile(image);
      if (mounted) {
        setState(() {
          _result = result;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Inference failed: $e';
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = _selectedImage != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('People Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Detection settings',
            onPressed: _isRunning ? null : () => _showSettings(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image preview ─────────────────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_selectedImage!, fit: BoxFit.contain),
                          if (_result != null)
                            CustomPaint(
                              painter: DetectionPainter(_result!),
                            ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library_outlined, size: 64),
                              SizedBox(height: 12),
                              Text('Select an image to count people'),
                            ],
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Pick buttons ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isRunning ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isRunning ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Count button ──────────────────────────────────────────────
            FilledButton.icon(
              onPressed: (hasImage && !_isRunning) ? _runInference : null,
              icon: _isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.people),
              label: Text(_isRunning ? 'Counting…' : 'Count People'),
            ),

            const SizedBox(height: 16),

            // ── Result ────────────────────────────────────────────────────
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              )
            else if (_result != null)
              Column(
                children: [
                  Text(
                    '${_result!.count}',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _result!.count == 1 ? 'person detected' : 'people detected',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet for adjusting detection thresholds.
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.counter});

  final PeopleCounter counter;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late double _confidence;
  late double _iou;

  @override
  void initState() {
    super.initState();
    _confidence = widget.counter.confidenceThreshold;
    _iou = widget.counter.iouThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text('Detection Settings', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),

          // ── Confidence threshold ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Confidence threshold'),
              Text(
                _confidence.toStringAsFixed(2),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _confidence,
            min: 0.05,
            max: 0.95,
            divisions: 90,
            label: _confidence.toStringAsFixed(2),
            onChanged: (v) {
              setState(() => _confidence = v);
              widget.counter.confidenceThreshold = v;
            },
          ),
          Text(
            'Lower → more detections (more false positives). '
            'Higher → fewer but more certain detections.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          // ── IoU threshold ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('IoU threshold (NMS)'),
              Text(
                _iou.toStringAsFixed(2),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _iou,
            min: 0.1,
            max: 0.95,
            divisions: 85,
            label: _iou.toStringAsFixed(2),
            onChanged: (v) {
              setState(() => _iou = v);
              widget.counter.iouThreshold = v;
            },
          ),
          Text(
            'Lower → aggressively merges overlapping boxes. '
            'Higher → keeps more overlapping boxes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

