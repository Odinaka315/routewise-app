import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum ButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailing,
    this.variant = ButtonVariant.primary,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? trailing;
  final ButtonVariant variant;

  /// Fill the available width. Only use where the parent gives a bounded width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (Color bg, Color fg) = switch (variant) {
      ButtonVariant.primary => (c.primary, Colors.white),
      ButtonVariant.secondary => (c.surface, c.ink),
      ButtonVariant.ghost => (Colors.transparent, c.primary),
      ButtonVariant.danger => (c.dangerSoft, c.danger),
    };
    final side = variant == ButtonVariant.secondary
        ? BorderSide(color: c.line)
        : BorderSide.none;

    return Opacity(
      opacity: onPressed == null ? 0.42 : 1,
      child: Material(
        color: bg,
        elevation: variant == ButtonVariant.primary ? 2 : 0,
        shadowColor: c.primary.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 9),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(15, fg, weight: FontWeight.w700),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 9),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.active = false,
    this.elevated = false,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;

  /// Accessibility label / tooltip.
  final String label;
  final VoidCallback? onPressed;

  /// Gold colour, used for starred state.
  final bool active;

  /// White floating style used on top of maps.
  final bool elevated;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: label,
      child: Material(
        color: elevated ? c.surface : Colors.transparent,
        elevation: elevated ? 3 : 0,
        shadowColor: Colors.black38,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: size,
            width: size,
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: active ? AppColors.star : c.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TextAction extends StatelessWidget {
  const TextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: AppText.body(14, c.primary, weight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }
}
