import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/misc.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'trips_screen.dart';

/// Signed-in shell: sidebar on wide screens, bottom navigation on phones.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0; // 0 = Trips, 1 = Settings

  void _openPlan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlanScreen()),
    );
  }

  Widget get _body {
    if (_tab == 0) {
      return TripsScreen(
        onPlan: _openPlan,
        onProfile: () => setState(() => _tab = 1),
      );
    }
    return ProfileScreen(onBack: () => setState(() => _tab = 0));
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              tab: _tab,
              onTrips: () => setState(() => _tab = 0),
              onPlan: _openPlan,
              onSettings: () => setState(() => _tab = 1),
            ),
            Expanded(child: _body),
          ],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(bottom: false, child: _body),
      bottomNavigationBar: _MobileNav(
        tab: _tab,
        onTrips: () => setState(() => _tab = 0),
        onPlan: _openPlan,
        onSettings: () => setState(() => _tab = 1),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.tab,
    required this.onTrips,
    required this.onPlan,
    required this.onSettings,
  });

  final int tab;
  final VoidCallback onTrips;
  final VoidCallback onPlan;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 244,
      color: AppColors.sidebar,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Brand(color: Colors.white),
            const SizedBox(height: 46),
            _SideItem(icon: Icons.home_outlined, label: 'Trips', active: tab == 0, onTap: onTrips),
            const SizedBox(height: 7),
            _SideItem(icon: Icons.add_rounded, label: 'Plan a route', active: false, onTap: onPlan),
            const SizedBox(height: 7),
            _SideItem(icon: Icons.settings_outlined, label: 'Settings', active: tab == 1, onTap: onSettings),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 31,
                    width: 31,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 17, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text('Quick tip', style: AppText.body(13, Colors.white, weight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(
                    'Star routes you ride often for faster access.',
                    style: AppText.body(13, Colors.white.withValues(alpha: 0.64), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSettings,
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: ListenableBuilder(
                    listenable: appState,
                    builder: (context, _) => Row(
                      children: [
                        AvatarCircle(initials: appState.initials),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appState.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(13, Colors.white, weight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                appState.userEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(12, Colors.white.withValues(alpha: 0.55)),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = active ? Colors.white : Colors.white.withValues(alpha: 0.68);
    return Material(
      color: active ? Colors.white.withValues(alpha: 0.11) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: active ? c.accent : Colors.transparent, width: 3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 13),
              Text(label, style: AppText.body(15, fg, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({
    required this.tab,
    required this.onTrips,
    required this.onPlan,
    required this.onSettings,
  });

  final int tab;
  final VoidCallback onTrips;
  final VoidCallback onPlan;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  label: 'Trips',
                  active: tab == 0,
                  onTap: onTrips,
                ),
              ),
              SizedBox(
                width: 70,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -11),
                    child: Material(
                      color: c.primary,
                      elevation: 6,
                      shadowColor: c.primary.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onPlan,
                        child: const SizedBox(
                          width: 54,
                          height: 54,
                          child: Icon(Icons.add_rounded, size: 26, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  active: tab == 1,
                  onTap: onSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = active ? c.primary : c.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: fg),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.body(11, fg, weight: active ? FontWeight.w700 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
