import 'package:flutter/material.dart';

import '../data/models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';

/// Every calculation made for a trip, newest first.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.title, this.tripId});

  final String title;
  final String? tripId;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = false;
  List<RouteRun> _runs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.tripId != null) {
      _loadRuns(widget.tripId!);
    }
  }

  Future<void> _loadRuns(String tripId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.getTripRuns(tripId);
      final runs = <RouteRun>[];
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final status = (item['status'] as String?) ?? 'failed';
          final ready = status == 'succeeded';
          final distM = (item['total_distance_m'] as num?)?.toDouble();
          final durS = (item['total_duration_s'] as num?)?.toDouble();
          final savedPct = (item['percent_saved'] as num?)?.toDouble();
          final createdAt = item['created_at']?.toString() ?? '';
          final solver = (item['solver'] as String?) ?? '';
          final matrixBackend = (item['matrix_backend'] as String?) ?? '';

          String distStr = '—';
          if (distM != null) distStr = '${(distM / 1000).toStringAsFixed(1)} km';

          String timeStr = '—';
          if (durS != null) {
            final mins = (durS / 60).round();
            if (mins >= 60) {
              final h = mins ~/ 60;
              final m = mins % 60;
              timeStr = '$h hr ${m > 0 ? '$m min' : ''}'.trim();
            } else {
              timeStr = '$mins min';
            }
          }

          String dateStr = 'Unknown';
          if (createdAt.isNotEmpty) {
            final dt = DateTime.tryParse(createdAt);
            if (dt != null) {
              final now = DateTime.now();
              final diff = now.difference(dt);
              if (diff.inMinutes < 60) {
                dateStr = 'Just now';
              } else if (diff.inHours < 24) {
                dateStr = '${diff.inHours}h ago';
              } else {
                dateStr = '${dt.day}/${dt.month}/${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              }
            }
          }

          String meta = 'Balanced · One-way';
          if (solver.isNotEmpty || matrixBackend.isNotEmpty) {
            meta = [if (solver.isNotEmpty) solver, if (matrixBackend.isNotEmpty) matrixBackend]
                .join(' · ');
          }

          String summary;
          if (!ready) {
            summary = status == 'queued'
                ? 'Queued'
                : status == 'running'
                    ? 'Calculating…'
                    : 'Calculation failed';
          } else {
            summary = savedPct != null ? '${savedPct.round()}% saved' : 'Route ready';
          }

          runs.add(RouteRun(
            date: dateStr,
            meta: meta,
            distance: distStr,
            time: timeStr,
            summary: summary,
            ready: ready,
          ));
        }
      }
      setState(() {
        _runs = runs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = isWide(context);
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 60 : 16, wide ? 48 : 23, wide ? 60 : 16, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIconButton(
                        icon: Icons.arrow_back_rounded,
                        label: 'Back to route',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(widget.title),
                            const SizedBox(height: 7),
                            Text('Run history',
                                style: AppText.heading(wide ? 34 : 28, c.ink, height: 1.14)),
                            const SizedBox(height: 7),
                            Text('Compare every calculation for this trip.',
                                style: AppText.body(15, c.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (_loading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: c.primary),
                            const SizedBox(height: 12),
                            Text('Loading run history…', style: AppText.body(14, c.muted)),
                          ],
                        ),
                      ),
                    )
                  else if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: c.danger),
                            const SizedBox(height: 12),
                            Text('Could not load run history.', style: AppText.body(15, c.ink)),
                            const SizedBox(height: 6),
                            Text(_error!, style: AppText.body(12, c.muted), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  else if (_runs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.history_rounded, size: 48, color: c.muted),
                            const SizedBox(height: 12),
                            Text('No run history yet.', style: AppText.body(15, c.ink)),
                            const SizedBox(height: 6),
                            Text('Run calculations will appear here.',
                                style: AppText.body(12, c.muted)),
                          ],
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < _runs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _RunCard(run: _runs[i], index: i),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run, required this.index});

  final RouteRun run;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final compact = isCompact(context);
    return AppSurface(
      padding: EdgeInsets.all(compact ? 14 : 18),
      onTap: () => showInfo(context, 'Run details are coming soon'),
      child: Row(
        crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (!compact) ...[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.soft, shape: BoxShape.circle),
              child: Text('${index + 1}',
                  style: AppText.body(14, c.ink, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 15),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(run.date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(15, c.ink, weight: FontWeight.w700)),
                    ),
                    if (index == 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Current',
                            style: AppText.body(10.2, c.primary, weight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(run.meta, style: AppText.body(12, c.muted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Stat(icon: Icons.map_outlined, text: run.distance),
                    _Stat(icon: Icons.schedule_rounded, text: run.time),
                    Text(
                      run.summary,
                      style: AppText.body(
                        12,
                        run.ready ? c.primary : c.danger,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            StatusChip(failed: !run.ready),
          ],
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c.muted),
        const SizedBox(width: 4),
        Text(text, style: AppText.body(12, c.muted)),
      ],
    );
  }
}
