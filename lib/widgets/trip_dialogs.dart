import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Asks for a new trip name. Returns null if cancelled or left empty.
Future<String?> promptRenameTrip(BuildContext context, String current) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(current: current),
  );
}

/// Asks "delete this trip?". Returns true only if the rider confirms.
Future<bool> confirmDeleteTrip(BuildContext context, String title) async {
  final c = context.c;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: c.surface,
      title: Text('Delete this trip?', style: AppText.heading(18, c.ink)),
      content: Text(
        '"$title" and its route history will be removed. This cannot be undone.',
        style: AppText.body(14.5, c.muted, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: c.danger),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current});

  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text('Rename trip', style: AppText.heading(18, c.ink)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: AppText.body(15, c.ink),
        decoration: InputDecoration(
          hintText: 'Trip name',
          hintStyle: AppText.body(15, AppColors.placeholder),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
