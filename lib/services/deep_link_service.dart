import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../screens/reset_password_screen.dart';
import '../screens/verify_email_screen.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;
  String? _lastHandledUri;
  DateTime? _lastHandledAt;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Check cold-start initial deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        handleUri(initialUri);
      }
    } catch (_) {}

    // Listen for warm-start incoming links while app is open/resumed
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        handleUri(uri);
      },
      onError: (_) {},
    );
  }

  void dispose() {
    _sub?.cancel();
  }

  void handleUri(Uri uri) {
    final uriStr = uri.toString();
    final now = DateTime.now();
    if (_lastHandledUri == uriStr &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastHandledUri = uriStr;
    _lastHandledAt = now;

    // Determine target route and extract token
    // Supported formats:
    // https://routewise-backend-6bmk.onrender.com/verify-email?token=...
    // https://routewise-backend-6bmk.onrender.com/reset-password?token=...
    // routewise://verify-email?token=...
    // routewise://reset-password?token=...
    // routewise:///verify-email?token=...
    final path = uri.path.toLowerCase();
    final host = uri.host.toLowerCase();
    final token = uri.queryParameters['token'];

    final isVerify = path.contains('verify-email') || host == 'verify-email';
    final isReset = path.contains('reset-password') || host == 'reset-password';

    if (!isVerify && !isReset) return;

    // Defer until navigator context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = navigatorKey.currentState;
      if (state == null) return;

      if (isVerify) {
        state.push<void>(
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(token: token),
          ),
        );
      } else if (isReset) {
        state.push<void>(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(token: token),
          ),
        );
      }
    });
  }
}
