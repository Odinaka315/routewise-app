import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/fields.dart';
import '../widgets/misc.dart';
import '../widgets/trip_card.dart';
import 'route_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, required this.onPlan, required this.onProfile});

  final VoidCallback onPlan;
  final VoidCallback onProfile;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _search = TextEditingController();
  bool _starredOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appState.isAuthenticated) {
        appState.refreshTrips();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Trip trip) {
    if (trip.failed) {
      showInfo(context, 'This route could not be calculated. Tap "Try again".');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteScreen(
          tripId: trip.id,
          title: trip.title,
          initialDistance: trip.distance,
          initialTime: trip.time,
          initialSavedPercent: trip.savedPercent,
          initialStarred: trip.starred,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final trips = appState.trips;
        final starred = appState.starredTrips;
        final query = _search.text.trim().toLowerCase();
        final filtered = trips
            .where((t) =>
                (!_starredOnly || t.starred) &&
                t.title.toLowerCase().contains(query))
            .toList();

        return RefreshIndicator(
          onRefresh: appState.refreshTrips,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(wide ? 56 : 16, wide ? 46 : 18, wide ? 56 : 16, 40),
            child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, wide),
                  SizedBox(height: wide ? 32 : 25),
                  _stats(context, wide),
                  const SizedBox(height: 32),
                  _starredSection(context, wide, starred),
                  const SizedBox(height: 39),
                  _allTrips(context, wide, trips.length, filtered),
                ],
              ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, bool wide) {
    final c = context.c;
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) ...[
                const Brand(),
                const SizedBox(height: 14),
              ],
              Eyebrow(dateLabel(now)),
              const SizedBox(height: 7),
              Text(
                '${greeting(now)}, ${appState.firstName}',
                style: AppText.heading(wide ? 34 : 26, c.ink, height: 1.14),
              ),
              const SizedBox(height: 7),
              Text('Where are we delivering today?', style: AppText.body(15, c.muted)),
            ],
          ),
        ),
        if (wide)
          AppButton(label: 'Plan new route', icon: Icons.add_rounded, onPressed: widget.onPlan)
        else
          Padding(
            padding: const EdgeInsets.only(top: 56),
            child: GestureDetector(
              onTap: widget.onProfile,
              child: AvatarCircle(initials: appState.initials, size: 42),
            ),
          ),
      ],
    );
  }

  Widget _stats(BuildContext context, bool wide) {
    final c = context.c;
    final items = [
      (Icons.alt_route_rounded, c.accent, c.accentSoft, 'Routes this month', appState.routesThisMonthText),
      (Icons.map_outlined, c.primary, c.primarySoft, 'Distance planned', appState.totalDistancePlannedText),
      (Icons.schedule_rounded, c.blue, c.blueSoft, 'Time planned', appState.totalTimePlannedText),
    ];
    return AppSurface(
      padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 10, vertical: wide ? 18 : 13),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : (wide ? 24 : 12)),
                  decoration: i == 0
                      ? null
                      : BoxDecoration(border: Border(left: BorderSide(color: c.line))),
                  child: Row(
                    children: [
                      if (wide) ...[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: items[i].$3,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(items[i].$1, size: 22, color: items[i].$2),
                        ),
                        const SizedBox(width: 13),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              items[i].$4,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(wide ? 11.7 : 10, c.muted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items[i].$5,
                              style: AppText.heading(wide ? 17.6 : 14.4, c.ink),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _starredSection(BuildContext context, bool wide, List<Trip> starred) {
    final c = context.c;
    Widget content;
    if (starred.isEmpty) {
      content = Text('No starred trips yet. Tap the star on a trip to pin it here.',
          style: AppText.body(14, c.muted));
    } else if (wide) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 14) / 2;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final trip in starred)
                SizedBox(
                  width: cardWidth,
                  child: TripCard(trip: trip, onOpen: () => _open(trip)),
                ),
            ],
          );
        },
      );
    } else {
      final cardWidth = (MediaQuery.sizeOf(context).width - 32) * 0.87;
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final trip in starred)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: cardWidth,
                    child: TripCard(trip: trip, onOpen: () => _open(trip)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 20, color: AppColors.star),
            const SizedBox(width: 9),
            Text('Starred trips', style: AppText.heading(18, c.ink)),
            const Spacer(),
            TextAction(
              label: _starredOnly ? 'Show all' : 'View all',
              onPressed: () => setState(() => _starredOnly = !_starredOnly),
            ),
          ],
        ),
        const SizedBox(height: 15),
        content,
      ],
    );
  }

  Widget _allTrips(BuildContext context, bool wide, int total, List<Trip> filtered) {
    final c = context.c;
    final title = Row(
      children: [
        Text('All trips', style: AppText.heading(18, c.ink)),
        const SizedBox(width: 9),
        CountBadge('$total'),
      ],
    );
    final search = AppTextField(
      icon: Icons.search_rounded,
      placeholder: 'Search trips',
      controller: _search,
      dense: true,
      onChanged: (_) => setState(() {}),
    );
    final filter = _FilterButton(
      active: _starredOnly,
      onTap: () => setState(() => _starredOnly = !_starredOnly),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide)
          Row(
            children: [
              title,
              const Spacer(),
              SizedBox(width: 220, child: search),
              const SizedBox(width: 10),
              filter,
            ],
          )
        else ...[
          title,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              filter,
            ],
          ),
        ],
        const SizedBox(height: 15),
        if (filtered.isEmpty)
          const EmptyState(
            title: 'No trips found',
            message: 'Try another search or plan a new route.',
          )
        else
          for (final trip in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: TripCard(
                trip: trip,
                indentMeta: wide ? 53 : 0,
                onOpen: () => _open(trip),
              ),
            ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = active ? c.primary : c.ink;
    return SizedBox(
      height: 43,
      child: Material(
        color: active ? c.primarySoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: active ? Colors.transparent : c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: fg,
                ),
                const SizedBox(width: 7),
                Text('Starred', style: AppText.body(14, fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
