import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';

/// Every calculation made for a trip, newest first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.title});

  final String title;

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
                            Eyebrow(title),
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
                  for (var i = 0; i < sampleRuns.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: _RunCard(run: sampleRuns[i], index: i),
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
