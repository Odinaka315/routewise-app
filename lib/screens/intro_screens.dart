import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';

const String _onboardingSeenKey = 'onboarding_seen_v1';

/// Whether the rider has already been through the intro slides.
Future<bool> hasSeenOnboarding() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  } catch (_) {
    return true; // never block the app on a storage problem
  }
}

Future<void> markOnboardingSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  } catch (_) {}
}

/// The big logo mark used on the opening screen.
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: Icon(Icons.alt_route_rounded, color: Colors.white, size: size * 0.56),
    );
  }
}

/// Opening screen: the logo pops in on a solid colour, holds briefly, then
/// [onDone] is called.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
  late final Animation<double> _fade = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _anim.forward();
    Future<void>.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(scale: _scale, child: const _LogoMark(size: 104)),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: _fade,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Route', style: AppText.heading(34, Colors.white)),
                    TextSpan(
                      text: 'wise',
                      style: AppText.heading(34, Colors.white.withValues(alpha: 0.75),
                          weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: _fade,
              child: Text('Fewer miles. More deliveries.',
                  style: AppText.body(14, Colors.white.withValues(alpha: 0.8))),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const List<_Slide> _slides = [
  _Slide(
    Icons.add_location_alt_rounded,
    'Add your stops',
    'Type or paste the addresses you need to visit, drop a pin on the map, or use where you are right now.',
  ),
  _Slide(
    Icons.alt_route_rounded,
    'Get the smartest order',
    'Routewise works out the quickest order to visit every stop, so you ride fewer kilometres and finish sooner.',
  ),
  _Slide(
    Icons.navigation_rounded,
    'Ride with turn-by-turn',
    'Open each stop in Google Maps or Waze, tick it off as you go, and keep the whole route on one map.',
  ),
];

/// First-run slides. Shown once; [onDone] is called on Skip or the last button.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  bool get _last => _page == _slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      widget.onDone();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                    child: TextButton(
                      onPressed: widget.onDone,
                      child: Text('Skip',
                          style: AppText.body(15, c.muted, weight: FontWeight.w700)),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final s = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                color: c.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(s.icon, size: 62, color: c.primary),
                            ),
                            const SizedBox(height: 36),
                            Text(s.title,
                                textAlign: TextAlign.center,
                                style: AppText.heading(26, c.ink)),
                            const SizedBox(height: 12),
                            Text(s.body,
                                textAlign: TextAlign.center,
                                style: AppText.body(16, c.muted, height: 1.5)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? c.primary : c.line,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: _last ? 'Get started' : 'Next',
                      expand: true,
                      onPressed: _next,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
