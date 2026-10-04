import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_exception.dart';
import '../../core/community/community_providers.dart';
import '../../core/theme/app_theme.dart';

/// The same rules the server applies (firebase/functions/src/validation.ts);
/// the server is what decides.
String? usernameRule(String raw) {
  final name = normalizeUsername(raw);
  if (name.length < 3) return 'Use at least 3 characters.';
  if (name.length > 20) return 'Use at most 20 characters.';
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(name)) {
    return 'Use only letters, numbers and underscores.';
  }
  if (!RegExp('^[a-z]').hasMatch(name)) return 'Start with a letter.';
  if (name.contains('__')) return "Don't use two underscores in a row.";
  return null;
}

String normalizeUsername(String raw) =>
    raw.trim().replaceFirst(RegExp('^@'), '').toLowerCase();

/// Picks a unique username, as first-time setup ([changing] false) or to
/// change it later. Pops with `true` when saved.
class UsernameScreen extends ConsumerStatefulWidget {
  const UsernameScreen({super.key, this.changing = false});

  final bool changing;

  @override
  ConsumerState<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends ConsumerState<UsernameScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _name;
  Timer? _debounce;
  String? _availability;
  bool _available = false;
  bool _checking = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authUserProvider).value;
    final profile = ref.read(myProfileProvider).value;
    _username = TextEditingController(text: profile?.username ?? '');
    _name = TextEditingController(
      text: profile?.displayName ?? user?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Checks availability half a second after typing stops.
  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _availability = null;
      _available = false;
    });
    if (usernameRule(value) != null) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _checking = true);
      try {
        final r = await ref.read(communityApiProvider).checkUsername(value);
        if (!mounted ||
            normalizeUsername(_username.text) != normalizeUsername(value)) {
          return;
        }
        setState(() {
          _available = r.available;
          _availability = r.available ? 'Available' : r.message;
        });
      } on CommunityException catch (e) {
        if (mounted) setState(() => _availability = e.message);
      } finally {
        if (mounted) setState(() => _checking = false);
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(communityApiProvider);
    try {
      if (widget.changing) {
        await api.changeUsername(_username.text);
      } else {
        await api.createProfile(
          username: _username.text,
          displayName: _name.text.trim(),
        );
      }
      if (mounted) context.pop(true);
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = ref.watch(myAccountProvider).value?.nextUsernameChange;
    final locked =
        widget.changing && next != null && next.isAfter(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.changing ? 'Change username' : 'Choose a username'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(
                widget.changing
                    ? 'Your old username becomes available to others.'
                    : 'This is how you appear when you comment. You can change it later.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.brand.muted,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _username,
                enabled: !locked,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  helperText: '3–20 letters, numbers or underscores',
                  suffixIcon: _checking
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _availability == null
                      ? null
                      : Icon(
                          _available
                              ? Icons.check_circle_rounded
                              : Icons.error_outline,
                          color: _available
                              ? context.brand.verified
                              : context.colors.error,
                        ),
                ),
                validator: (v) => usernameRule(v ?? ''),
              ),
              if (_availability != null) ...[
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _availability!,
                    style: context.text.bodySmall?.copyWith(
                      color: _available
                          ? context.brand.verified
                          : context.colors.error,
                    ),
                  ),
                ),
              ],
              if (locked) ...[
                const SizedBox(height: 8),
                Text(
                  'You can change your username again on '
                  '${MaterialLocalizations.of(context).formatMediumDate(next)}.',
                  style: context.text.bodySmall,
                ),
              ],
              if (!widget.changing) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy || locked ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Text(widget.changing ? 'Save username' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
