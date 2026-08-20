import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';

Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.discardChanges),
      content: Text(context.l10n.yourUnsavedEditsWillBeLost),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.keepEditing),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.l10n.discard),
        ),
      ],
    ),
  );
  return discard ?? false;
}
