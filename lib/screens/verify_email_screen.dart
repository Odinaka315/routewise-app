import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/fields.dart';
import '../widgets/misc.dart';

enum VerifyStatus { verifying, success, failure, missingToken }

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.token});

  final String? token;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  VerifyStatus _status = VerifyStatus.verifying;
  String _message = 'Verifying your email address...';
  bool _serverWakingUp = false;
  Timer? _wakeUpTimer;
  bool _hasCalledApi = false;

  final _resendEmailController = TextEditingController();
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      _status = VerifyStatus.missingToken;
      _message = 'This link is incomplete or missing a token.';
      return;
    }

    _wakeUpTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _status == VerifyStatus.verifying) {
        setState(() => _serverWakingUp = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCalledApi) {
        _hasCalledApi = true;
        _verify(token);
      }
    });
  }

  @override
  void dispose() {
    _wakeUpTimer?.cancel();
    _resendEmailController.dispose();
    super.dispose();
  }

  Future<void> _verify(String token) async {
    try {
      final message = await ApiService.instance.verifyEmail(token: token);
      if (!mounted) return;
      _wakeUpTimer?.cancel();
      setState(() {
        _status = VerifyStatus.success;
        _message = message;
        _serverWakingUp = false;
      });
    } catch (e) {
      if (!mounted) return;
      _wakeUpTimer?.cancel();
      setState(() {
        _status = VerifyStatus.failure;
        _message = e.toString();
        _serverWakingUp = false;
      });
    }
  }

  Future<void> _resendEmail() async {
    final email = _resendEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showInfo(context, 'Please enter a valid email address.');
      return;
    }

    setState(() => _resending = true);
    try {
      final msg = await ApiService.instance.resendVerification(email: email);
      if (!mounted) return;
      showInfo(context, msg);
      _resendEmailController.clear();
    } catch (e) {
      if (!mounted) return;
      showInfo(context, e.toString());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _goToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = isWide(context);

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: c.ink),
          onPressed: _goToLogin,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 40 : 22,
            vertical: wide ? 40 : 28,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: switch (_status) {
              VerifyStatus.verifying => _buildVerifying(c),
              VerifyStatus.success => _buildSuccess(c),
              VerifyStatus.failure => _buildFailure(c),
              VerifyStatus.missingToken => _buildMissingToken(c),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVerifying(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 32),
        const Eyebrow('Account verification'),
        const SizedBox(height: 8),
        Text('Verifying email', style: AppText.heading(28, c.ink), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(_message, style: AppText.body(15, c.muted), textAlign: TextAlign.center),
        if (_serverWakingUp) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: c.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Waking up the server, one moment…',
                    style: AppText.body(13.5, c.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccess(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.check_circle_rounded, size: 36, color: c.primary),
        ),
        const SizedBox(height: 28),
        const Eyebrow('Success'),
        const SizedBox(height: 8),
        Text('Email confirmed', style: AppText.heading(28, c.ink), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Your account has been verified. You can now log in and plan your delivery routes.',
          style: AppText.body(15, c.muted, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        AppButton(
          label: 'Log in',
          expand: true,
          onPressed: _goToLogin,
        ),
      ],
    );
  }

  Widget _buildFailure(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: c.dangerSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.error_outline_rounded, size: 32, color: c.danger),
        ),
        const SizedBox(height: 24),
        const Eyebrow('Link error'),
        const SizedBox(height: 8),
        Text('Verification failed', style: AppText.heading(28, c.ink)),
        const SizedBox(height: 12),
        Text(
          _message.isNotEmpty ? _message : 'This verification link is invalid or has expired.',
          style: AppText.body(15, c.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        Text('Resend confirmation email', style: AppText.heading(18, c.ink)),
        const SizedBox(height: 8),
        Text(
          'Enter your email address and we will send you a fresh link.',
          style: AppText.body(13.5, c.muted),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Email address',
          placeholder: 'you@example.com',
          icon: Icons.mail_outline_rounded,
          controller: _resendEmailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: _resending ? 'Sending...' : 'Resend confirmation email',
          expand: true,
          onPressed: _resending ? null : _resendEmail,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextAction(
            label: 'Back to Log in',
            onPressed: _goToLogin,
          ),
        ),
      ],
    );
  }

  Widget _buildMissingToken(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: c.dangerSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.link_off_rounded, size: 32, color: c.danger),
        ),
        const SizedBox(height: 24),
        const Eyebrow('Invalid link'),
        const SizedBox(height: 8),
        Text('This link is incomplete', style: AppText.heading(28, c.ink)),
        const SizedBox(height: 12),
        Text(
          'The verification link appears to be missing its security token. Please request a new confirmation email below.',
          style: AppText.body(15, c.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        AppTextField(
          label: 'Email address',
          placeholder: 'you@example.com',
          icon: Icons.mail_outline_rounded,
          controller: _resendEmailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: _resending ? 'Sending...' : 'Resend confirmation email',
          expand: true,
          onPressed: _resending ? null : _resendEmail,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextAction(
            label: 'Back to Log in',
            onPressed: _goToLogin,
          ),
        ),
      ],
    );
  }
}
