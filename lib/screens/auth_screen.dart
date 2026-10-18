import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/fields.dart';
import '../widgets/map_views.dart';
import '../widgets/misc.dart';

enum AuthView { login, signup, check, forgot }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthView _view = AuthView.login;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _serverWakingUp = false;
  Timer? _wakeUpTimer;

  @override
  void dispose() {
    _wakeUpTimer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _go(AuthView view) {
    setState(() {
      _view = view;
      _loading = false;
      _serverWakingUp = false;
    });
  }

  void _startWakeUpTimer() {
    _wakeUpTimer?.cancel();
    _wakeUpTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _loading) {
        setState(() => _serverWakingUp = true);
      }
    });
  }

  void _stopWakeUpTimer() {
    _wakeUpTimer?.cancel();
    if (_serverWakingUp) {
      setState(() => _serverWakingUp = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || !email.contains('@')) {
      showInfo(context, 'Please enter a valid email address.');
      return;
    }

    if ((_view == AuthView.login || _view == AuthView.signup) && password.isEmpty) {
      showInfo(context, 'Please enter your password.');
      return;
    }

    if (_view == AuthView.signup && password.length < 8) {
      showInfo(context, 'Password must be at least 8 characters.');
      return;
    }

    setState(() => _loading = true);
    _startWakeUpTimer();

    try {
      switch (_view) {
        case AuthView.login:
          await appState.login(email: email, password: password);
          if (!mounted) return;
          _stopWakeUpTimer();
          // Logged in successfully: AppState listener switches root to AppShell
          break;

        case AuthView.signup:
          await appState.signup(
            email: email,
            password: password,
            displayName: _name.text.trim().isNotEmpty ? _name.text.trim() : null,
          );
          if (!mounted) return;
          _stopWakeUpTimer();
          setState(() {
            _loading = false;
            _view = AuthView.check;
          });
          break;

        case AuthView.forgot:
          final msg = await appState.forgotPassword(email: email);
          if (!mounted) return;
          _stopWakeUpTimer();
          showInfo(context, msg);
          _go(AuthView.login);
          break;

        case AuthView.check:
          final msg = await appState.resendVerification(email: email);
          if (!mounted) return;
          _stopWakeUpTimer();
          showInfo(context, msg);
          setState(() => _loading = false);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _stopWakeUpTimer();
      setState(() => _loading = false);
      showInfo(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = isWide(context);
    return Scaffold(
      backgroundColor: c.surface,
      body: wide
          ? Row(
              children: [
                Expanded(flex: 85, child: _brandPanel(context)),
                Expanded(flex: 115, child: _formPanel(context, wide)),
              ],
            )
          : SafeArea(child: _formPanel(context, wide)),
    );
  }

  Widget _brandPanel(BuildContext context) {
    return Container(
      color: AppColors.sidebar,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(56),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Brand(color: Colors.white),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: ClipRect(
                            child: Transform.translate(
                              offset: const Offset(60, 0),
                              child: Transform.rotate(
                                angle: -0.07,
                                child: const MiniMap(radius: 30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Eyebrow('Built for Lagos riders', color: AppColors.mint),
                        const SizedBox(height: 10),
                        Text(
                          'Better routes.\nMore deliveries.',
                          style: AppText.heading(48, Colors.white, height: 1.1),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Text(
                            'Plan every stop in the right order and spend less time on the road.',
                            style: AppText.body(16, Colors.white.withValues(alpha: 0.65),
                                height: 1.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Container(
                          height: 39,
                          width: 39,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded,
                              size: 20, color: AppColors.mint),
                        ),
                        const SizedBox(width: 11),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Up to 30% shorter routes\n',
                                  style: AppText.body(12.2, Colors.white,
                                      weight: FontWeight.w700, height: 1.5),
                                ),
                                TextSpan(
                                  text: 'Based on road distance and travel time',
                                  style: AppText.body(
                                      12.2, Colors.white.withValues(alpha: 0.58),
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _formPanel(BuildContext context, bool wide) {
    final c = context.c;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 22, vertical: wide ? 40 : 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) ...[
                const Brand(),
                const SizedBox(height: 56),
              ],
              if (_view == AuthView.check) ..._checkEmail(c) else ..._form(c),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _checkEmail(AppColors c) {
    final email = _email.text.trim().isEmpty ? appState.userEmail : _email.text.trim();
    return [
      Container(
        height: 68,
        width: 68,
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.mail_outline_rounded, size: 30, color: c.primary),
      ),
      const SizedBox(height: 25),
      const Eyebrow('Almost there'),
      const SizedBox(height: 7),
      Text('Check your email', style: AppText.heading(30, c.ink, height: 1.14)),
      const SizedBox(height: 10),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'We sent a confirmation link to '),
            TextSpan(text: email, style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: '. Open it on this phone or in your browser to activate your account.'),
          ],
        ),
        style: AppText.body(15, c.muted, height: 1.5),
      ),
      if (_serverWakingUp) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Waking up the server, one moment…',
                  style: AppText.body(13, c.ink),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 26),
      AppButton(
        label: _loading ? 'Sending...' : 'Resend confirmation email',
        expand: true,
        onPressed: _loading ? null : _submit,
      ),
      const SizedBox(height: 12),
      Center(
        child: TextAction(
          label: 'Use a different email',
          onPressed: () => _go(AuthView.signup),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: TextAction(
          label: 'Back to Log in',
          onPressed: () => _go(AuthView.login),
        ),
      ),
    ];
  }

  List<Widget> _form(AppColors c) {
    final isLogin = _view == AuthView.login;
    final isSignup = _view == AuthView.signup;
    final isForgot = _view == AuthView.forgot;
    final eyebrow = isSignup
        ? 'Create your account'
        : isForgot
            ? 'Account recovery'
            : 'Welcome back';
    final title = isSignup
        ? 'Start planning smarter'
        : isForgot
            ? 'Reset your password'
            : 'Log in to Routewise';
    final intro = isForgot
        ? "Enter your email and we'll send you a secure reset link."
        : 'Quick, reliable routes are a few taps away.';
    final button = _loading
        ? (isSignup ? 'Creating account...' : isForgot ? 'Sending link...' : 'Logging in...')
        : (isSignup ? 'Create account' : isForgot ? 'Send reset link' : 'Log in');

    return [
      Eyebrow(eyebrow),
      const SizedBox(height: 7),
      Text(title, style: AppText.heading(30, c.ink, height: 1.14)),
      const SizedBox(height: 10),
      Text(intro, style: AppText.body(15, c.muted, height: 1.5)),
      const SizedBox(height: 30),
      if (isSignup) ...[
        AppTextField(
          label: 'Display name (optional)',
          placeholder: 'What should we call you?',
          icon: Icons.person_outline_rounded,
          controller: _name,
        ),
        const SizedBox(height: 17),
      ],
      AppTextField(
        label: 'Email address',
        placeholder: 'you@example.com',
        icon: Icons.mail_outline_rounded,
        controller: _email,
        keyboardType: TextInputType.emailAddress,
      ),
      if (!isForgot) ...[
        const SizedBox(height: 17),
        AppTextField(
          label: 'Password',
          placeholder: isSignup ? 'At least 8 characters' : 'Enter your password',
          icon: Icons.lock_outline_rounded,
          controller: _password,
          obscure: true,
          hint: isSignup ? 'Use 8+ characters' : null,
        ),
      ],
      if (isLogin)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: TextAction(
              label: 'Forgot password?',
              onPressed: () => _go(AuthView.forgot),
            ),
          ),
        )
      else
        const SizedBox(height: 20),
      if (_serverWakingUp) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Waking up the server, one moment…',
                  style: AppText.body(13, c.ink),
                ),
              ),
            ],
          ),
        ),
      ],
      AppButton(
        label: button,
        expand: true,
        onPressed: _loading ? null : _submit,
        trailing: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
      ),
      const SizedBox(height: 20),
      Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              isLogin
                  ? 'New to Routewise? '
                  : isForgot
                      ? 'Remembered your password? '
                      : 'Already have an account? ',
              style: AppText.body(13.5, c.muted),
            ),
            GestureDetector(
              onTap: () => _go(isLogin ? AuthView.signup : AuthView.login),
              child: Text(
                isLogin
                    ? 'Create account'
                    : isForgot
                        ? 'Back to Log in'
                        : 'Log in',
                style: AppText.body(13.5, c.primary, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
