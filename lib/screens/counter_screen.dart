import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../widgets/detection_painter.dart';
import '../widgets/drawing_overlay.dart';
import '../providers/collection_provider.dart';
import '../providers/counter_provider.dart';
import '../widgets/save_session_sheet.dart';

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counter = context.watch<CounterProvider>();
    final hasImage = counter.selectedImage != null;
    final hasResult = counter.result != null;

    return Stack(
      children: [
        Column(
          children: [
            // Image preview area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Store the display size for coordinate transformation
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      counter.setImageDisplaySize(
                        Size(constraints.maxWidth, constraints.maxHeight),
                      );
                    });

                    return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hasImage
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  InteractiveViewer(
                                    minScale: 1.0,
                                    maxScale: 5.0,
                                    panEnabled: !counter.drawMode,
                                    scaleEnabled: !counter.drawMode,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          counter.selectedImage!,
                                          fit: BoxFit.contain,
                                        ),
                                        if (hasResult)
                                          CustomPaint(
                                            painter: DetectionPainter(counter.result!),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (counter.drawMode)
                                    DrawingOverlay(
                                      paths: counter.drawnPaths,
                                      strokeColor: Colors.black.withValues(alpha: 150),
                                      strokeWidth: 20,
                                      onPathComplete: counter.addDrawnPath,
                                    ),
                                  if (!counter.drawMode && counter.drawnPaths.isNotEmpty)
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: DrawingPainter(
                                          paths: counter.drawnPaths,
                                        ),
                                      ),
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
                    if (!hasImage)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton.small(
                              onPressed: counter.isRunning
                                  ? null
                                  : () => counter.pickImage(ImageSource.camera),
                              heroTag: 'camera',
                              child: const Icon(Icons.camera_alt),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              onPressed: counter.isRunning
                                  ? null
                                  : () => counter.pickImage(ImageSource.gallery),
                              heroTag: 'gallery',
                              child: const Icon(Icons.photo_library),
                            ),
                          ],
                        ),
                      ),
                    if (hasImage)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton.small(
                              onPressed: counter.isRunning ? null : counter.clearImage,
                              heroTag: 'clear',
                              backgroundColor: theme.colorScheme.errorContainer,
                              foregroundColor: theme.colorScheme.onErrorContainer,
                              child: const Icon(Icons.close),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              onPressed: counter.isRunning ? null : counter.toggleDrawMode,
                              heroTag: 'draw',
                              backgroundColor: counter.drawMode
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: counter.drawMode
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              child: Icon(
                                counter.drawMode ? Icons.pan_tool : Icons.edit,
                              ),
                            ),
                            if (counter.drawMode) ...[
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                onPressed: counter.isRunning ? null : counter.undoLastPath,
                                heroTag: 'undo',
                                tooltip: 'Undo last stroke',
                                child: const Icon(Icons.undo),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                onPressed: counter.isRunning ? null : counter.clearDrawings,
                                heroTag: 'clearDrawings',
                                tooltip: 'Clear drawings',
                                child: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

            // Result card at bottom
            if (hasResult || counter.errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: counter.errorMessage != null
                    ? Text(
                        counter.errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${counter.result!.count}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            counter.result!.count == 1
                                ? 'person detected'
                                : 'people detected',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (hasImage && !counter.isRunning)
                          ? counter.runInference
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: counter.isRunning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.people),
                      label: Text(
                        counter.isRunning ? 'Counting…' : 'Count People',
                      ),
                    ),
                  ),
                  if (hasResult) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: () => _saveToCollection(context),
                      icon: const Icon(Icons.save),
                      tooltip: 'Save to collection',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),


      ],
    );
  }

  Future<void> _saveToCollection(BuildContext context) async {
    final counter = context.read<CounterProvider>();
    final collectionsProvider = context.read<CollectionProvider>();
    final image = counter.selectedImage;
    final result = counter.result;

    if (image == null || result == null) return;

    // Ensure collections are loaded before showing the sheet
    await collectionsProvider.loadCollections();

    if (!context.mounted) return;

    final request = await showSaveSessionSheet(
      context,
      collectionsProvider.collections,
    );
    if (request == null) return;

    int? targetCollectionId = request.collectionId;
    if (targetCollectionId == null) {
      targetCollectionId = await collectionsProvider.createCollection(
        name: request.newCollectionName ?? '',
      );
      if (targetCollectionId == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create collection.')),
        );
        return;
      }
    }

    final success = await collectionsProvider.saveSessionToCollection(
      collectionId: targetCollectionId!,
      sourceImage: image,
      peopleCount: result.count,
      correction: request.correction,
      confidenceThreshold: counter.confidenceThreshold,
      iouThreshold: counter.iouThreshold,
      notes: request.notes,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved to collection.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
      counter.clearResult();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(collectionsProvider.errorMessage ?? 'Save failed.'),
        ),
      );
    }
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late double _confidence;
  late double _iou;

  @override
  void initState() {
    super.initState();
    final counter = context.read<CounterProvider>();
    _confidence = counter.confidenceThreshold;
    _iou = counter.iouThreshold;
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
              context.read<CounterProvider>().updateThresholds(
                confidence: _confidence,
                iou: _iou,
              );
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
              context.read<CounterProvider>().updateThresholds(
                confidence: _confidence,
                iou: _iou,
              );
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
