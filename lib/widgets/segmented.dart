import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SegmentItem {
  const SegmentItem({required this.label, this.sub, this.icon});

  final String label;
  final String? sub;
  final IconData? icon;
}

/// Selectable option tiles ("Fastest / Balanced / Shortest" etc.).
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.stackBelow = 0,
  });

  final List<SegmentItem> items;
  final int selected;
  final ValueChanged<int> onChanged;

  /// Stack the tiles vertically when the available width is below this value.
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < stackBelow;
        if (stack) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
                  child: _Tile(
                    item: items[i],
                    active: selected == i,
                    height: 58,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: _Tile(
                    item: items[i],
                    active: selected == i,
                    height: 66,
                    onTap: () => onChanged(i),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.item,
    required this.active,
    required this.height,
    required this.onTap,
  });

  final SegmentItem item;
  final bool active;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = active ? c.primary : c.ink;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: active ? c.primarySoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: active ? c.primary : c.line, width: active ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 20, color: fg),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(12.6, fg, weight: FontWeight.w700),
                      ),
                      if (item.sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.sub!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(11, c.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (active) Icon(Icons.check_rounded, size: 20, color: c.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
