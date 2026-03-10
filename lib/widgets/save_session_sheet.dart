import 'package:flutter/material.dart';

import '../models/collection_summary.dart';

class SaveSessionRequest {
  final int? collectionId;
  final String? newCollectionName;
  final int correction;
  final String? notes;

  const SaveSessionRequest({
    this.collectionId,
    this.newCollectionName,
    this.correction = 0,
    this.notes,
  });
}

Future<SaveSessionRequest?> showSaveSessionSheet(
  BuildContext context,
  List<CollectionSummary> collections,
) {
  final formKey = GlobalKey<FormState>();
  final notesController = TextEditingController();
  final newNameController = TextEditingController();
  final correctionController = TextEditingController(text: '0');

  int? selectedCollectionId = collections.isNotEmpty
      ? collections.first.id
      : null;
  bool createNew = collections.isEmpty;

  return showModalBottomSheet<SaveSessionRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Save to Collection',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (collections.isNotEmpty) ...[
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Existing'),
                        ),
                        ButtonSegment<bool>(value: true, label: Text('New')),
                      ],
                      selected: {createNew},
                      onSelectionChanged: (selection) {
                        setModalState(() {
                          createNew = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (createNew) ...[
                    TextFormField(
                      controller: newNameController,
                      decoration: const InputDecoration(
                        labelText: 'Collection name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a collection name';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    DropdownButtonFormField<int>(
                      initialValue: selectedCollectionId,
                      decoration: const InputDecoration(
                        labelText: 'Collection',
                        border: OutlineInputBorder(),
                      ),
                      items: collections
                          .map(
                            (c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedCollectionId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Select a collection';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: correctionController,
                    decoration: const InputDecoration(
                      labelText: 'Correction (±)',
                      hintText: 'Adjust count (e.g., -2 or +3)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(signed: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null) {
                        return 'Enter a valid integer';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (createNew || collections.isNotEmpty) {
                        final valid = formKey.currentState?.validate() ?? false;
                        if (!valid) return;
                      }

                      Navigator.of(context).pop(
                        SaveSessionRequest(
                          collectionId: createNew ? null : selectedCollectionId,
                          newCollectionName: createNew
                              ? newNameController.text
                              : null,
                          correction: int.tryParse(correctionController.text.trim()) ?? 0,
                          notes: notesController.text,
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
