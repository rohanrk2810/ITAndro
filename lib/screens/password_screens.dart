import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../widgets/captcha.dart';

/// Shared by the three password forms: a busy flag, an error line and a submit guard.
mixin _FormState<T extends StatefulWidget> on State<T> {
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;

  Future<void> run(Future<void> Function() action, {String? fallback}) async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = apiErrorMessage(e, fallback ?? 'Something went wrong. Please try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget errorLine(BuildContext context) => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        );

  Widget submit(String label, VoidCallback onPressed) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
        ),
      );
}

String? _required(String? v) => (v == null || v.isEmpty) ? 'Required' : null;

/// Account → change password, and the screen a person is held on when an administrator forced a change.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> with _FormState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        automaticallyImplyLeading: !widget.forced,
        actions: [if (widget.forced) TextButton(onPressed: auth.logout, child: const Text('Sign out'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.forced)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('You must choose a new password before you continue.'),
              ),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password', border: OutlineInputBorder()),
              validator: (v) => v != _next.text ? 'Passwords do not match' : null,
            ),
            errorLine(context),
            submit('Change password', () {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              run(() async {
                await auth.changePassword(_current.text, _next.text);
                if (!widget.forced) {
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Password changed.')));
                }
              });
            }),
          ]),
        ),
      ),
    );
  }
}

/// Two steps: ask for the one-time code by email, then set the new password with it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with _FormState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _next = TextEditingController();
  final _captcha = CaptchaController();
  bool _codeSent = false;

  @override
  void dispose() {
    _captcha.dispose();
    _email.dispose();
    _otp.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              validator: _required,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              const Text('We sent a code to your email. Enter it with a new password.'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _otp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder()),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
                validator: _required,
              ),
            ],
            if (!_codeSent) ...[const SizedBox(height: 8), CaptchaField(controller: _captcha)],
            errorLine(context),
            if (!_codeSent)
              submit('Send code', () => run(() async {
                    if (_captcha.enabled && _captcha.token == null) {
                      throw StateError('Please confirm you are not a robot.');
                    }
                    try {
                      await auth.forgotPassword(_email.text.trim(), captchaToken: _captcha.token);
                    } catch (_) {
                      _captcha.reset();
                      rethrow;
                    }
                    if (mounted) setState(() => _codeSent = true);
                  }, fallback: 'Please confirm you are not a robot, then try again.'))
            else
              submit('Reset password', () {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                run(() async {
                  await auth.resetPassword(_email.text.trim(), _otp.text.trim(), _next.text);
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Password reset. Sign in with the new one.')));
                });
              }),
          ]),
        ),
      ),
    );
  }
}
