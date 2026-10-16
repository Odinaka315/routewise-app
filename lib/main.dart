import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
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

/// Switches between the auth flow and the signed-in app.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) =>
          appState.isAuthenticated ? const AppShell() : const AuthScreen(),
    );
  }
}
