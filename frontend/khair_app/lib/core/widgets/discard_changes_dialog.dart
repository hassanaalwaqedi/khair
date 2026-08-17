import 'package:flutter/material.dart';

Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text('Your unsaved edits will be lost.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard ?? false;
}
