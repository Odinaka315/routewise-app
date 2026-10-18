import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/fields.dart';
import '../widgets/misc.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.token});

  final String? token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _submitting = false;
  bool _success = false;
  String? _errorMessage;
  bool _serverWakingUp = false;
  Timer? _wakeUpTimer;

  @override
  void dispose() {
    _wakeUpTimer?.cancel();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _submit() async {
    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'This reset link is invalid or missing a security token.');
      return;
    }

    final p1 = _newPassword.text;
    final p2 = _confirmPassword.text;

    if (p1.length < 8 || p1.length > 128) {
      showInfo(context, 'Password must be between 8 and 128 characters.');
      return;
    }
    if (p1 != p2) {
      showInfo(context, 'Passwords do not match.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _serverWakingUp = false;
    });

    _wakeUpTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _submitting) {
        setState(() => _serverWakingUp = true);
      }
    });

    try {
      await ApiService.instance.resetPassword(
        token: token,
        newPassword: p1,
      );
      if (!mounted) return;
      _wakeUpTimer?.cancel();
      setState(() {
        _submitting = false;
        _success = true;
        _serverWakingUp = false;
      });
    } catch (e) {
      if (!mounted) return;
      _wakeUpTimer?.cancel();
      setState(() {
        _submitting = false;
        _errorMessage = e.toString();
        _serverWakingUp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = isWide(context);
    final hasValidToken = widget.token != null && widget.token!.trim().isNotEmpty;

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
            child: _success
                ? _buildSuccess(c)
                : !hasValidToken
                    ? _buildMissingToken(c)
                    : _buildForm(c),
          ),
        ),
      ),
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
        const Eyebrow('Security update'),
        const SizedBox(height: 8),
        Text('Password updated', style: AppText.heading(28, c.ink), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Your password has been changed successfully. For your security, you have been signed out on all devices. You can now log in with your new password.',
          style: AppText.body(15, c.muted, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        AppButton(
          label: 'Log in with new password',
          expand: true,
          onPressed: _goToLogin,
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
        Text('This reset link is incomplete', style: AppText.heading(28, c.ink)),
        const SizedBox(height: 12),
        Text(
          'The reset link is missing a security token or has already been used. Please request a new reset link.',
          style: AppText.body(15, c.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        AppButton(
          label: 'Request a new reset link',
          expand: true,
          onPressed: _goToLogin,
        ),
      ],
    );
  }

  Widget _buildForm(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Account security'),
        const SizedBox(height: 8),
        Text('Choose new password', style: AppText.heading(28, c.ink)),
        const SizedBox(height: 10),
        Text(
          'Please choose a strong password between 8 and 128 characters.',
          style: AppText.body(15, c.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.dangerSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_errorMessage!, style: AppText.body(13.5, c.danger, weight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _goToLogin,
                        child: Text(
                          'Request a new reset link →',
                          style: AppText.body(13, c.primary, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        AppTextField(
          label: 'New password',
          placeholder: 'At least 8 characters',
          icon: Icons.lock_outline_rounded,
          controller: _newPassword,
          obscure: true,
          hint: '8 to 128 characters',
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'Confirm new password',
          placeholder: 'Re-enter your new password',
          icon: Icons.lock_reset_rounded,
          controller: _confirmPassword,
          obscure: true,
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
          label: _submitting ? 'Updating password...' : 'Update password',
          expand: true,
          onPressed: _submitting ? null : _submit,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextAction(
            label: 'Cancel and return to Log in',
            onPressed: _goToLogin,
          ),
        ),
      ],
    );
  }
}
