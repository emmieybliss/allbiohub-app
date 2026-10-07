import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_exception.dart';
import '../../core/community/community_providers.dart';
import '../../core/providers.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/link_opener.dart';
import '../../shared/widgets/common.dart';
import '../community/community_widgets.dart';

/// Sign in or create an account. Pops with `true` once signed in; closing
/// it keeps the person browsing as a guest.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.reason});

  /// Why an account is needed, e.g. "Sign in to comment".
  final String? reason;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final done = await action();
      if (done && mounted) context.pop(true);
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) {
        setState(
          () =>
              _error = const CommunityException(CommunityErrorKind.unknown)
                  .message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = ref.read(authRepositoryProvider);
    final analytics = ref.read(analyticsProvider);
    await _run(() async {
      if (_register) {
        await auth.registerWithEmail(_email.text, _password.text);
        analytics.log(AnalyticsEvent.signUp, {'method': 'email'});
        if (mounted) {
          showMessage(
            context,
            'Account created. Check your email to verify it.',
          );
        }
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
        analytics.log(AnalyticsEvent.login, {'method': 'email'});
      }
      return true;
    });
  }

  Future<void> _google() => _run(() async {
    final user = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (user == null) return false;
    ref.read(analyticsProvider).log(AnalyticsEvent.login, {'method': 'google'});
    return true;
  });

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email address above first.');
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        showMessage(
          context,
          'If $email has an account, a reset link is on its way.',
        );
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final supportsGoogle = ref.watch(authRepositoryProvider).supportsGoogle;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Continue as guest',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(false),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            children: [
              const Center(child: LogoMark(size: 56)),
              const SizedBox(height: 16),
              Text(
                _register ? 'Join AllBioHub' : 'Welcome back',
                style: context.text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.reason ??
                    'Follow startups and topics, join conversations and sync '
                        'what you save.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.brand.muted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Sign in')),
                  ButtonSegment(value: true, label: Text('Create account')),
                ],
                selected: {_register},
                onSelectionChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _register = v.first;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v ?? '').trim().contains(RegExp(r'^\S+@\S+\.\S+$'))
                    ? null
                    : 'Enter a valid email address',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                autofillHints: [
                  _register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _register ? 'At least 8 characters' : null,
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Enter your password';
                  if (_register && v!.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Text(_register ? 'Create account' : 'Sign in'),
              ),
              if (!_register)
                TextButton(
                  onPressed: _busy ? null : _forgot,
                  child: const Text('Forgot password?'),
                ),
              if (supportsGoogle) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: context.text.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _google,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continue with Google'),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'You can keep reading without an account. Your email is never '
                'shown on your profile.',
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (config.termsUrl.isNotEmpty ||
                  config.privacyPolicyUrl.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (config.termsUrl.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            openLink(context, ref, Uri.parse(config.termsUrl)),
                        child: const Text('Terms'),
                      ),
                    if (config.privacyPolicyUrl.isNotEmpty)
                      TextButton(
                        onPressed: () => openLink(
                          context,
                          ref,
                          Uri.parse(config.privacyPolicyUrl),
                        ),
                        child: const Text('Privacy policy'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
