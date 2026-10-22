import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/intro_screens.dart';
import 'services/deep_link_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize backend session and stored credentials
  await appState.init();

  // Initialize deep linking (cold start and stream listeners)
  await DeepLinkService.instance.init();

  runApp(const RoutewiseApp());
}

class RoutewiseApp extends StatelessWidget {
  const RoutewiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Routewise',
          navigatorKey: DeepLinkService.instance.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: appState.themeMode,
          home: const RootGate(),
        );
      },
    );
  }
}

enum _Stage { splash, onboarding, app }

/// Opening screen, then first-run slides, then the auth flow or signed-in app.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  _Stage _stage = _Stage.splash;
  bool _seen = true;

  @override
  void initState() {
    super.initState();
    hasSeenOnboarding().then((v) => _seen = v);
  }

  void _afterSplash() {
    if (!mounted) return;
    setState(() => _stage = (_seen || appState.isAuthenticated) ? _Stage.app : _Stage.onboarding);
  }

  Future<void> _afterOnboarding() async {
    await markOnboardingSeen();
    if (mounted) setState(() => _stage = _Stage.app);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_stage) {
      _Stage.splash => SplashScreen(key: const ValueKey('splash'), onDone: _afterSplash),
      _Stage.onboarding =>
        OnboardingScreen(key: const ValueKey('onboarding'), onDone: _afterOnboarding),
      _Stage.app => ListenableBuilder(
          key: const ValueKey('app'),
          listenable: appState,
          builder: (context, _) =>
              appState.isAuthenticated ? const AppShell() : const AuthScreen(),
        ),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: child);
  }
}
