import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collection_summary.dart';
import '../models/count_session.dart';
import '../providers/collection_provider.dart';
import '../providers/counter_provider.dart';

class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({super.key, required this.collection});

  final CollectionSummary collection;

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollectionProvider>().loadSessions(widget.collection.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CollectionProvider>();
    final sessions = provider.sessionsForCollection(widget.collection.id);
    final totalPeople = sessions.fold<int>(
      0,
      (sum, session) => sum + session.correctedCount,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.collection.name)),
      body: Column(
        children: [
          // Collection summary header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFD8E7F8),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFB4CCE7),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  icon: Icons.photo_library,
                  label: 'Saved Images',
                  value: '${sessions.length}',
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: const Color(0xFF7EA6D0).withValues(alpha: 0.45),
                ),
                _SummaryItem(
                  icon: Icons.people,
                  label: 'Total People',
                  value: '$totalPeople',
                  emphasized: true,
                ),
              ],
            ),
          ),

          // Images list
          Expanded(
            child: sessions.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No saved images in this collection yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final date = _formatDate(session.timestamp);
                      final time = _formatTime(session.timestamp);

                      return Card(
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          children: [
                            InkWell(
                              onTap: () => _openImageInHome(context, session),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: Image.file(
                                          File(session.imagePath),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const ColoredBox(
                                                color: Colors.black12,
                                                child: Icon(Icons.broken_image),
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            date,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          Text(
                                            time,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'Detected: ',
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                        color: theme.colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                ),
                                                TextSpan(
                                                  text:
                                                      '${session.peopleCount}',
                                                  style: theme
                                                      .textTheme.labelMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                if (session.correction != 0)
                                                  TextSpan(
                                                    text:
                                                        ' (${session.correction > 0 ? '+' : ''}${session.correction})',
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .secondary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (session.notes != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              session.notes!,
                                              style: theme.textTheme.bodySmall,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${session.correctedCount}',
                                          style: theme.textTheme.displaySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                        ),
                                        Text(
                                          session.correctedCount == 1
                                              ? 'person'
                                              : 'people',
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 28),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline_outlined),
                                iconSize: 20,
                                color: theme.colorScheme.error,
                                onPressed: () =>
                                    _deleteSession(context, session),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openImageInHome(BuildContext context, CountSession session) {
    context.read<CounterProvider>().loadImageFromPath(
      session.imagePath,
      sessionId: session.id,
      collectionId: session.collectionId,
      correction: session.correction,
      notes: session.notes,
      maskPaths: session.maskPaths,
      confidenceThreshold: session.confidenceThreshold,
      iouThreshold: session.iouThreshold,
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteSession(
    BuildContext context,
    CountSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text(
          'Delete this saved image from the collection?\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final provider = context.read<CollectionProvider>();
    await provider.deleteSession(widget.collection.id, session.id!);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image deleted')),
      );
    }
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: emphasized ? 24 : 20,
              color: emphasized
                  ? theme.colorScheme.primary
                  : const Color(0xFF234A72),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: emphasized
                    ? const Color(0xFF17385C)
                    : const Color(0xFF234A72).withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: emphasized
                ? theme.colorScheme.primary
                : const Color(0xFF17385C),
          ),
        ),
      ],
    );
  }
}

