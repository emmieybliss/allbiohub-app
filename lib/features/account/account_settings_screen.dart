import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_exception.dart';
import '../../core/community/community_providers.dart';
import '../../core/community/models.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../community/community_widgets.dart';

/// Account, privacy, sign-out and deletion.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _privacy(
    BuildContext context,
    WidgetRef ref, {
    ProfileVisibility? visibility,
    bool? showActivity,
  }) async {
    try {
      await ref
          .read(communityApiProvider)
          .updateProfile(visibility: visibility, showActivity: showActivity);
    } on Object catch (e) {
      if (context.mounted) showCommunityError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(child: Text('You are signed out.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Group('Sign-in'),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: Text(user.email ?? 'No email'),
            subtitle: Text(
              user.emailVerified ? 'Verified · only you can see this' : 'Not verified yet',
            ),
            trailing: user.emailVerified
                ? null
                : TextButton(
                    onPressed: () => verifyEmailDialog(context, ref),
                    child: const Text('Verify'),
                  ),
          ),
          if (profile != null)
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded),
              title: Text('@${profile.username}'),
              subtitle: const Text('Change username'),
              onTap: () => context.push(Routes.chooseUsername, extra: true),
            ),
          if (profile != null) ...[
            const _Group('Privacy'),
            SwitchListTile(
              secondary: const Icon(Icons.public_rounded),
              title: const Text('Public profile'),
              subtitle: const Text(
                'When off, only your name and username show next to your comments.',
              ),
              value: !profile.isPrivate,
              onChanged: (on) => _privacy(
                context,
                ref,
                visibility: on ? ProfileVisibility.public : ProfileVisibility.private,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.history_rounded),
              title: const Text('Show my activity'),
              subtitle: const Text('Comment count and followed topics on your profile'),
              value: profile.showActivity,
              onChanged: (on) => _privacy(context, ref, showActivity: on),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Notification preferences'),
            onTap: () => context.push(Routes.notificationSettings),
          ),
          const _Group('Account'),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () async {
              await signOut(ref);
              if (context.mounted) context.go(Routes.profile);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: context.colors.error),
            title: Text('Delete account', style: TextStyle(color: context.colors.error)),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _DeleteAccountSheet(),
            ),
          ),
          const _Group('AllBioHub team'),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(user.isAdmin ? 'Editor access is on' : 'Editor access'),
            subtitle: Text(
              user.isAdmin
                  ? 'You can moderate in the Firebase console (COMMUNITY.md).'
                  : 'For AllBioHub editors on the admin list',
            ),
            onTap: user.isAdmin
                ? null
                : () async {
                    try {
                      await ref.read(communityApiProvider).claimAdmin();
                      await ref.read(authRepositoryProvider).reload();
                      if (context.mounted) showMessage(context, 'Editor access is on.');
                    } on Object catch (e) {
                      if (context.mounted) showCommunityError(context, e);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
    child: Text(title.toUpperCase(), style: context.text.labelSmall),
  );
}

/// Explains exactly what deletion removes, confirms the person's identity
/// and only says the account is deleted once the server has done it.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    final usesPassword = ref.read(authUserProvider).value?.usesPassword ?? false;
    try {
      await auth.reauthenticate(password: usesPassword ? _password.text : null);
      await ref.read(deviceRegistrationProvider).beforeSignOut();
      await ref.read(communityApiProvider).deleteAccount();
      await auth.signOut().catchError((Object _) {});
      if (!mounted) return;
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      router.go(Routes.profile);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesPassword = ref.watch(authUserProvider).value?.usesPassword ?? false;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete your account?', style: context.text.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'This permanently deletes your profile, username, follows, saved '
                'items on your account, notifications and reactions. Your comments '
                'are emptied and shown as "Deleted". Stories and startups you '
                'submitted stay with our editors without your contact details. '
                'This can\'t be undone.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Stories saved on this phone stay on this phone.',
                style: context.text.bodySmall,
              ),
              if (usesPassword) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Your password'),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: const Text('I understand this is permanent'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: context.text.bodyMedium?.copyWith(color: context.colors.error),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Keep account'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.error,
                        foregroundColor: context.colors.onError,
                      ),
                      onPressed: !_confirmed || _busy ? null : _delete,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Text('Delete'),
                    ),
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
