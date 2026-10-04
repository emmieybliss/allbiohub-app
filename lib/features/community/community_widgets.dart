import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_exception.dart';
import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/community/saved.dart';
import '../../core/models/media_image.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_image.dart';

/// Shows why a community action failed. Offline gets the standard message;
/// nothing is reported as done when it wasn't.
void showCommunityError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final message = error is CommunityException
      ? error.message
      : const CommunityException(CommunityErrorKind.unknown).message;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Makes sure the person can take part before a community action: signed
/// in, with a username when [profile], and a verified email when
/// [verified]. Guides them through whatever is missing and returns whether
/// they may go ahead. Reading never needs any of this.
Future<bool> requireAccount(
  BuildContext context,
  WidgetRef ref, {
  bool profile = true,
  bool verified = false,
  String reason = 'Sign in to take part in the AllBioHub community.',
}) async {
  if (!ref.read(featureProvider(Feature.accounts))) return false;
  var user = ref.read(authUserProvider).value;
  if (user == null) {
    final signedIn = await context.push<bool>(Routes.signIn, extra: reason);
    if (signedIn != true || !context.mounted) return false;
    user = ref.read(authUserProvider).value;
    if (user == null) return false;
  }
  if (profile) {
    // The profile stream may not have delivered yet after signing in.
    final me =
        ref.read(myProfileProvider).value ??
        await ref
            .read(myProfileProvider.future)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (me == null) {
      if (!context.mounted) return false;
      final created = await context.push<bool>(Routes.chooseUsername);
      if (created != true || !context.mounted) return false;
    }
  }
  if (verified && !user.emailVerified) {
    if (!context.mounted) return false;
    return verifyEmailDialog(context, ref);
  }
  final account = ref.read(myAccountProvider).value;
  if (account?.isRestricted ?? false) {
    if (context.mounted) {
      showCommunityError(
        context,
        const CommunityException(CommunityErrorKind.restricted),
      );
    }
    return false;
  }
  return true;
}

/// Asks the person to verify their email, with a resend button. Returns
/// true once the email shows as verified.
Future<bool> verifyEmailDialog(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authRepositoryProvider);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Verify your email'),
      content: Text(
        'We sent a link to ${ref.read(authUserProvider).value?.email ?? 'your email'}. '
        'Open it, then come back and tap "I\'ve verified".',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            try {
              await auth.sendEmailVerification();
              if (context.mounted) showMessage(context, 'Verification email sent.');
            } on Object catch (e) {
              if (context.mounted) showCommunityError(context, e);
            }
          },
          child: const Text('Send again'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              final user = await auth.reload();
              if (!context.mounted) return;
              if (user?.emailVerified ?? false) {
                Navigator.pop(context, true);
              } else {
                showMessage(context, 'Not verified yet. Check your inbox.');
              }
            } on Object catch (e) {
              if (context.mounted) showCommunityError(context, e);
            }
          },
          child: const Text("I've verified"),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Round profile picture with the person's initial behind it.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.name, this.photoUrl, this.size = 36});

  final String? name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final initial = Center(
      child: Text(
        (name?.trim().isNotEmpty ?? false) ? name!.trim()[0].toUpperCase() : '?',
        style: TextStyle(
          color: brand.accentText,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: brand.accentSoft, shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: photoUrl == null || photoUrl!.isEmpty
            ? initial
            : Stack(
                fit: StackFit.expand,
                children: [
                  initial,
                  AppImage(image: MediaImage.single(photoUrl!), allowCropped: true),
                ],
              ),
      ),
    );
  }
}

/// Which switch controls following each kind of thing.
Feature followFeature(FollowKind kind) => switch (kind) {
  FollowKind.startup => Feature.startupFollows,
  FollowKind.founder => Feature.founderFollows,
  FollowKind.topic => Feature.topicFollows,
};

/// "+ Follow" / "✓ Following". Hidden when following this kind of thing
/// is switched off. Changes at once and rolls back if it fails.
class FollowButton extends ConsumerWidget {
  const FollowButton({super.key, required this.target, this.dense = false});

  final FollowTarget target;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureProvider(followFeature(target.kind)))) {
      return const SizedBox.shrink();
    }
    final following = ref.watch(isFollowingProvider(target));
    final label = following ? 'Following' : 'Follow';
    final icon = Icon(
      following ? Icons.check_rounded : Icons.add_rounded,
      size: dense ? 16 : 18,
    );
    final style = dense
        ? const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          )
        : null;
    Future<void> onPressed() async {
      HapticFeedback.selectionClick();
      if (!await requireAccount(
        context,
        ref,
        profile: false,
        reason: 'Sign in to follow ${target.label.isEmpty ? 'this' : target.label} '
            'and hear about new stories.',
      )) {
        return;
      }
      try {
        await ref.read(followOverridesProvider.notifier).set(target, !following);
        if (!following) {
          ref.read(analyticsProvider).log(
            switch (target.kind) {
              FollowKind.startup => AnalyticsEvent.startupFollow,
              FollowKind.founder => AnalyticsEvent.founderFollow,
              FollowKind.topic => AnalyticsEvent.topicFollow,
            },
            {'id': target.id},
          );
        }
      } on Object catch (e) {
        if (context.mounted) showCommunityError(context, e);
      }
    }

    return Semantics(
      button: true,
      toggled: following,
      label: following ? 'Following ${target.label}' : 'Follow ${target.label}',
      excludeSemantics: true,
      child: following
          ? OutlinedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            )
          : FilledButton.tonalIcon(
              style: style,
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            ),
    );
  }
}

/// Save toggle for a startup or founder (works without an account).
class SaveEntityButton extends ConsumerWidget {
  const SaveEntityButton({super.key, required this.entity, this.color});

  final SavedEntity entity;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isEntitySavedProvider((entity.kind, entity.id)));
    return IconButton(
      tooltip: saved ? 'Remove from saved' : 'Save',
      onPressed: () async {
        HapticFeedback.lightImpact();
        final nowSaved = await ref.read(savedEntitiesProvider.notifier).toggle(entity);
        if (context.mounted) {
          showMessage(context, nowSaved ? 'Saved' : 'Removed from saved');
        }
      },
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: saved ? context.brand.accentText : color,
      ),
    );
  }
}

/// A compact card inviting guests to sign in, used where a community
/// section would otherwise be empty.
class JoinPrompt extends ConsumerWidget {
  const JoinPrompt({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.brand.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text(message, style: context.text.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => requireAccount(context, ref, profile: false),
            child: const Text('Sign in or create an account'),
          ),
        ],
      ),
    );
  }
}
