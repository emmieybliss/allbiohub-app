import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_preferences.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

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
                color: context.brand.goldSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_paused_outlined,
                    color: context.brand.goldText,
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
        ],
      ),
    );
  }
}
