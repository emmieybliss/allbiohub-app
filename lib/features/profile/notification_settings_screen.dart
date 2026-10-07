import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/models/user_preferences.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../community/community_widgets.dart';

/// Choose which notification topics to receive. Choices are saved now and
/// synced to push topics whenever push is configured in the build.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(
      preferencesProvider.select((p) => p.notificationTopics),
    );
    final service = ref.watch(notificationServiceProvider);

    Future<void> toggle(NotificationTopic topic, bool on) async {
      if (on && service.isAvailable) await service.requestPermission();
      await ref
          .read(preferencesProvider.notifier)
          .update(
            (p) => p.copyWith(
              notificationTopics: on
                  ? {...p.notificationTopics, topic}
                  : ({...p.notificationTopics}..remove(topic)),
            ),
          );
      await service.syncTopics(
        ref.read(preferencesProvider).notificationTopics,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          if (!service.isAvailable)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.brand.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_paused_outlined,
                    color: context.brand.accentText,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Push notifications aren't switched on yet. Your choices are saved and "
                      'will apply as soon as they are.',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Notify me about', style: context.text.titleMedium),
          ),
          for (final topic in NotificationTopic.values)
            SwitchListTile(
              title: Text(topic.label),
              value: topics.contains(topic),
              onChanged: (on) => toggle(topic, on),
            ),
          const _AccountPrefs(),
        ],
      ),
    );
  }
}

/// Community notifications (replies, follows, submissions), stored on the
/// account so they apply on every device. Shown only when signed in.
class _AccountPrefs extends ConsumerStatefulWidget {
  const _AccountPrefs();

  @override
  ConsumerState<_AccountPrefs> createState() => _AccountPrefsState();
}

class _AccountPrefsState extends ConsumerState<_AccountPrefs> {
  /// Choices not yet confirmed by the server, shown at once.
  final Map<CommunityNotificationPref, bool> _pending = {};

  Future<void> _set(CommunityNotificationPref pref, bool on) async {
    setState(() => _pending[pref] = on);
    try {
      await ref.read(communityApiProvider).updateNotificationPrefs({pref: on});
      final service = ref.read(notificationServiceProvider);
      if (on && service.isAvailable) await service.requestPermission();
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e);
    } finally {
      if (mounted) setState(() => _pending.remove(pref));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider).value;
    if (user == null ||
        !ref.watch(featureProvider(Feature.notificationCenter))) {
      return const SizedBox.shrink();
    }
    final account = ref.watch(myAccountProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Text('Your account', style: context.text.titleMedium),
        ),
        for (final pref in CommunityNotificationPref.values)
          SwitchListTile(
            title: Text(pref.label),
            subtitle: Text(pref.description),
            value: _pending[pref] ?? account?.wants(pref) ?? pref.defaultValue,
            onChanged: account == null || _pending.containsKey(pref)
                ? null
                : (on) => _set(pref, on),
          ),
      ],
    );
  }
}
