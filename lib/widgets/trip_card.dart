import 'package:flutter/material.dart';

import '../data/api_models.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

import '../utils/helpers.dart';
import 'action_sheet.dart';
import 'buttons.dart';
import 'misc.dart';
import 'trip_dialogs.dart';

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onOpen,
    this.indentMeta = 0,
  });

  final Trip trip;
  final VoidCallback onOpen;

  /// Left indent of the stats row (aligns it under the title on wide screens).
  final double indentMeta;

  Future<void> _guard(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) showInfo(context, e.message);
    }
  }

  void _showActions(BuildContext context) {
    showActionSheet(
      context,
      title: trip.title,
      actions: [
        SheetAction(
          icon: Icons.edit_outlined,
          label: 'Rename trip',
          onTap: () async {
            final name = await promptRenameTrip(context, trip.title);
            if (name != null && name != trip.title && context.mounted) {
              await _guard(context, () => appState.renameTrip(trip.id, name));
            }
          },
        ),
        SheetAction(
          icon: trip.starred ? Icons.star_border_rounded : Icons.star_rounded,
          label: trip.starred ? 'Remove star' : 'Star trip',
          onTap: () => appState.toggleStar(trip.id),
        ),
        SheetAction(
          icon: Icons.refresh_rounded,
          label: 'Recalculate route',
          onTap: () async {
            await _guard(context, () => appState.retryTrip(trip.id));
            if (context.mounted) showInfo(context, 'Recalculating "${trip.title}"…');
          },
        ),
        SheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete trip',
          danger: true,
          onTap: () async {
            if (await confirmDeleteTrip(context, trip.title) && context.mounted) {
              await _guard(context, () => appState.deleteTrip(trip.id));
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final compact = isCompact(context);
    final wide = isWide(context);
    return AppSurface(
      onTap: onOpen,
      padding: EdgeInsets.symmetric(horizontal: compact ? 15 : 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.alt_route_rounded, color: c.primary, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading(15, c.ink, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trip.stops} stops · ${trip.date}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(12, c.muted),
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: trip.starred ? Icons.star_rounded : Icons.star_border_rounded,
                label: trip.starred ? 'Unstar trip' : 'Star trip',
                active: trip.starred,
                onPressed: () => appState.toggleStar(trip.id),
              ),
              AppIconButton(
                icon: Icons.more_horiz_rounded,
                label: 'Trip actions',
                onPressed: () => _showActions(context),
              ),
            ],
          ),
          if (trip.editedFrom != null) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: c.soft,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_copy_rounded, size: 14, color: c.muted),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Edited copy of ${trip.editedFrom}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(11.2, c.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            margin: EdgeInsets.only(left: indentMeta),
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: compact ? 10 : 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(failed: trip.failed, calculating: trip.calculating),
                      _Meta(icon: Icons.map_outlined, text: trip.distance),
                      _Meta(icon: Icons.schedule_rounded, text: trip.time),
                    ],
                  ),
                ),
                if (trip.failed)
                  TextAction(
                    label: 'Try again',
                    onPressed: () async {
                      await _guard(context, () => appState.retryTrip(trip.id));
                      if (context.mounted) showInfo(context, 'Recalculating "${trip.title}"…');
                    },
                  )
                else if (wide && trip.savedPercent != null)
                  Text(
                    'Saved ${trip.savedPercent}',
                    style: AppText.body(12.5, c.primary, weight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: c.muted),
        const SizedBox(width: 5),
        Text(text, style: AppText.body(12.5, c.muted)),
      ],
    );
  }
}

/// Empty state used when no trips match the search / filter.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DashedBorder(
      color: c.line,
      radius: 18,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: c.soft, shape: BoxShape.circle),
              child: Icon(Icons.search_rounded, size: 28, color: c.muted),
            ),
            const SizedBox(height: 15),
            Text(title, style: AppText.heading(17, c.ink, weight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(message, textAlign: TextAlign.center, style: AppText.body(14, c.muted)),
          ],
        ),
      ),
    );
  }
}
