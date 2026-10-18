import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';

const List<String> _optimiseOptions = ['Fastest', 'Balanced', 'Shortest'];
const List<String> _typeOptions = ['One-way', 'Return to start'];
const List<String> _unitOptions = ['Kilometres', 'Miles'];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  Future<void> _pick(
    BuildContext context, {
    required String title,
    required List<String> options,
    required int current,
    required ValueChanged<int> onSelect,
  }) {
    final c = context.c;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: AppText.heading(18, c.ink)),
            ),
            for (var i = 0; i < options.length; i++)
              ListTile(
                title: Text(options[i], style: AppText.body(15, c.ink)),
                trailing: i == current
                    ? Icon(Icons.check_rounded, color: c.primary)
                    : null,
                onTap: () {
                  onSelect(i);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogoutAll(BuildContext context) async {
    final c = context.c;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Log out of all devices?', style: AppText.heading(18, c.ink)),
        content: Text(
          'Every active session, including this one, will be ended.',
          style: AppText.body(14.5, c.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: c.danger),
            child: const Text('Log out everywhere'),
          ),
        ],
      ),
    );
    if (confirmed == true) await appState.logoutAll();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = isWide(context);
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return SingleChildScrollView(
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
                        label: 'Back to trips',
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Eyebrow('Your account'),
                            const SizedBox(height: 7),
                            Text('Profile & settings',
                                style: AppText.heading(wide ? 34 : 28, c.ink, height: 1.14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _profileCard(context, wide),
                  _group(context, 'Route preferences', [
                    _SettingRow(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Default optimisation',
                      subtitle: 'Applied to new routes',
                      trailing: _SelectValue(
                        text: _optimiseOptions[appState.defaultOptimise],
                        onTap: () => _pick(
                          context,
                          title: 'Default optimisation',
                          options: _optimiseOptions,
                          current: appState.defaultOptimise,
                          onSelect: appState.setDefaultOptimise,
                        ),
                      ),
                    ),
                    _SettingRow(
                      icon: Icons.alt_route_rounded,
                      title: 'Default route type',
                      subtitle: 'How each journey ends',
                      trailing: _SelectValue(
                        text: _typeOptions[appState.defaultRouteType],
                        onTap: () => _pick(
                          context,
                          title: 'Default route type',
                          options: _typeOptions,
                          current: appState.defaultRouteType,
                          onSelect: appState.setDefaultRouteType,
                        ),
                      ),
                    ),
                    _SettingRow(
                      icon: Icons.map_outlined,
                      title: 'Distance units',
                      subtitle: 'Used across route results',
                      trailing: _SelectValue(
                        text: _unitOptions[appState.distanceUnit],
                        onTap: () => _pick(
                          context,
                          title: 'Distance units',
                          options: _unitOptions,
                          current: appState.distanceUnit,
                          onSelect: appState.setDistanceUnit,
                        ),
                      ),
                    ),
                  ]),
                  _group(context, 'Appearance', [
                    _SettingRow(
                      icon: Icons.layers_outlined,
                      title: 'Dark mode',
                      subtitle: 'Higher comfort in low light',
                      trailing: _Toggle(
                        value: appState.isDark,
                        onChanged: appState.setDarkMode,
                      ),
                    ),
                  ]),
                  _group(context, 'Account', [
                    _AccountRow(
                      icon: Icons.logout_rounded,
                      title: 'Log out',
                      subtitle: 'This device only',
                      onTap: appState.logout,
                    ),
                    _AccountRow(
                      icon: Icons.logout_rounded,
                      title: 'Log out of all devices',
                      subtitle: 'End every active session',
                      danger: true,
                      onTap: () => _confirmLogoutAll(context),
                    ),
                  ]),
                  const SizedBox(height: 42),
                  Center(
                    child: Text('Routewise v1.0 · Made for Lagos roads',
                        style: AppText.body(11.5, c.muted)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _profileCard(BuildContext context, bool wide) {
    final c = context.c;
    return AppSurface(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          AvatarCircle(initials: appState.initials, size: 58),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appState.userName, style: AppText.heading(18, c.ink)),
                const SizedBox(height: 3),
                Text(appState.userEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(13, c.muted)),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: appState.isEmailVerified ? c.primarySoft : c.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        appState.isEmailVerified ? Icons.check_rounded : Icons.info_outline_rounded,
                        size: 13,
                        color: appState.isEmailVerified ? c.primary : c.danger,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        appState.isEmailVerified ? 'Email confirmed' : 'Email not verified',
                        style: AppText.body(
                          10.8,
                          appState.isEmailVerified ? c.primary : c.danger,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (wide)
            AppButton(
              label: 'Edit profile',
              variant: ButtonVariant.secondary,
              onPressed: () => showInfo(context, 'Profile editing is coming soon'),
            ),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> rows) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 31),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.heading(18, c.ink)),
          const SizedBox(height: 11),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.line),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 74),
      child: Row(
        children: [
          Container(
            height: 39,
            width: 39,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(15, c.ink, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: AppText.body(12, c.muted)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SelectValue extends StatelessWidget {
  const _SelectValue({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: AppText.body(14, c.muted)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      toggled: value,
      label: value ? 'Turn off dark mode' : 'Turn on dark mode',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? c.primary : AppColors.toggleOff,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = danger ? c.danger : c.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Row(
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body(15, fg, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppText.body(12, c.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}
