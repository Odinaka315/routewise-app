import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// One row in an [showActionSheet] menu.
class SheetAction {
  const SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
}

/// A bottom sheet menu. Tapping a row closes the sheet, then runs its action.
Future<void> showActionSheet(
  BuildContext context, {
  String? title,
  required List<SheetAction> actions,
}) {
  final c = context.c;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading(18, c.ink),
                ),
              ),
            for (final action in actions)
              ListTile(
                leading: Icon(action.icon, color: action.danger ? c.danger : c.ink),
                title: Text(
                  action.label,
                  style: AppText.body(15, action.danger ? c.danger : c.ink,
                      weight: FontWeight.w600),
                ),
                subtitle: action.subtitle == null
                    ? null
                    : Text(action.subtitle!, style: AppText.body(12.5, c.muted)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  action.onTap();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
