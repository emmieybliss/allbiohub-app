import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/saved.dart';
import '../../core/models/category.dart';
import '../../core/models/user_preferences.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/link_opener.dart';
import '../../shared/widgets/common.dart';
import '../community/community_widgets.dart';
import '../community/following_screen.dart' show ProfileHeader;
import '../discover/discover_screen.dart' show categoryIcon;
import '../home/home_providers.dart';

/// The person's account (when community features are on), settings and
/// information. Reading never needs an account.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final config = ref.watch(appConfigProvider);
    final version = ref.watch(appVersionProvider);
    final savedCount =
        ref.watch(bookmarksProvider.select((b) => b.length)) +
        ref.watch(savedEntitiesProvider.select((s) => s.length));
    final site = Uri.parse(config.siteUrl);
    final inAppStories = ref.watch(featureProvider(Feature.storySubmissions));
    final inAppStartups = ref.watch(
      featureProvider(Feature.startupSubmissions),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text('Profile', style: context.text.headlineSmall),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _AccountSection(),
          const _Group('Reading'),
          ListTile(
            leading: const Icon(Icons.bookmark_border_rounded),
            title: const Text('Saved'),
            trailing: Text('$savedCount', style: context.text.bodySmall),
            onTap: () => context.go(Routes.saved),
          ),
          ListTile(
            leading: const Icon(Icons.interests_outlined),
            title: const Text('Your topics'),
            subtitle: Text(
              prefs.interestSlugs.isEmpty
                  ? 'Not set'
                  : '${prefs.interestSlugs.length} selected',
            ),
            onTap: () => _editInterests(context),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields_rounded),
            title: const Text('Text size'),
            subtitle: Text(prefs.textSize.label),
            onTap: () => _pick<ReaderTextSize>(
              context,
              ref,
              title: 'Text size',
              values: ReaderTextSize.values,
              label: (s) => s.label,
              selected: prefs.textSize,
              onSelect: (s) => ref
                  .read(preferencesProvider.notifier)
                  .update((p) => p.copyWith(textSize: s)),
            ),
          ),
          const _Group('Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
              ],
              selected: {prefs.themeMode},
              onSelectionChanged: (v) => ref
                  .read(preferencesProvider.notifier)
                  .update((p) => p.copyWith(themeMode: v.first)),
            ),
          ),
          const _Group('Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Notification preferences'),
            subtitle: Text('${prefs.notificationTopics.length} topics'),
            onTap: () => context.push(Routes.notificationSettings),
          ),
          const _Group('AllBioHub'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About AllBioHub'),
            onTap: () => _about(context, ref, version),
          ),
          if (inAppStories)
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Submit a story'),
              onTap: () => context.push(Routes.submitStory),
            )
          else
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Submit a story'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => openLink(
                context,
                ref,
                site.replace(path: '/submit-a-story/'),
              ),
            ),
          if (inAppStartups)
            ListTile(
              leading: const Icon(Icons.rocket_launch_outlined),
              title: const Text('Submit a startup'),
              onTap: () => context.push(Routes.submitStartup),
            ),
          if (config.contactEmail.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('Contact'),
              subtitle: Text(config.contactEmail),
              onTap: () => openLink(
                context,
                ref,
                Uri(scheme: 'mailto', path: config.contactEmail),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            onTap: () => _privacy(context, ref),
          ),
          if (config.termsUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms and conditions'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => openLink(context, ref, Uri.parse(config.termsUrl)),
            ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear cached content'),
            subtitle: const Text('Saved stories are kept'),
            onTap: () async {
              await ref.read(cacheStoreProvider).clear();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
              }
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('AllBioHub $version', style: context.text.bodySmall),
          ),
        ],
      ),
    );
  }

  void _editInterests(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _InterestsSheet(),
  );

  void _pick<T>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<T> values,
    required String Function(T) label,
    required T selected,
    required ValueChanged<T> onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<T>(
          groupValue: selected,
          onChanged: (v) {
            if (v != null) onSelect(v);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: context.text.titleLarge),
              ),
              for (final v in values)
                RadioListTile<T>(value: v, title: Text(label(v))),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _about(BuildContext context, WidgetRef ref, String version) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark(size: 26),
              const SizedBox(height: 16),
              Text(
                'AllBioHub Media is a digital media and discovery platform covering African people, '
                'celebrity news, biography, technology, startups, founders, money and careers.',
                style: context.text.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Read. Discover. Connect in one hub.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.brand.muted,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => openLink(
                  context,
                  ref,
                  Uri.parse(ref.read(appConfigProvider).siteUrl),
                  inApp: false,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Visit allbiohub.com'),
              ),
              const SizedBox(height: 12),
              Text('Version $version', style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  void _privacy(BuildContext context, WidgetRef ref) {
    final url = ref.read(appConfigProvider).privacyPolicyUrl;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy', style: context.text.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'You can use AllBioHub without an account. Saved stories, settings and recent searches '
                'are stored on this device. The app loads stories and startup profiles from '
                'allbiohub.com. Usage events (such as which story was opened) are recorded without your '
                'name, email or contacts, and only when analytics is enabled in this build.',
                style: context.text.bodyLarge,
              ),
              if (ref.read(featureProvider(Feature.accounts))) ...[
                const SizedBox(height: 12),
                Text(
                  'If you create an account, your email, username, profile, comments, reactions, '
                  'follows, saved items and submissions are stored with AllBioHub so they work on '
                  'every device. Your email is never shown to other people. You can delete your '
                  'account at any time in Account settings.',
                  style: context.text.bodyLarge,
                ),
              ],
              if (url.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => openLink(context, ref, Uri.parse(url)),
                  child: const Text('Read the full privacy policy'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign-in prompt for guests, or the person's profile and community
/// pages. Hidden entirely while accounts are switched off.
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureProvider(Feature.accounts))) {
      return const SizedBox.shrink();
    }
    final user = ref.watch(authUserProvider).value;
    if (user == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: JoinPrompt(
          title: 'Join the AllBioHub community',
          message:
              'React to stories, comment, follow startups and topics, and keep '
              'your saved items on every device. Reading stays free without an account.',
        ),
      );
    }
    bool on(Feature f) => ref.watch(featureProvider(f));
    final profile = ref.watch(myProfileProvider).value;
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final following =
        on(Feature.startupFollows) ||
        on(Feature.topicFollows) ||
        on(Feature.founderFollows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: profile == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email ?? '', style: context.text.titleMedium),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => context.push(Routes.chooseUsername),
                      child: const Text('Choose a username'),
                    ),
                  ],
                )
              : ProfileHeader(profile: profile, isMe: true),
        ),
        if (profile != null)
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Edit profile'),
            onTap: () => context.push(Routes.editProfile),
          ),
        const _Group('Community'),
        if (on(Feature.notificationCenter))
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Notifications'),
            trailing: unread > 0
                ? Badge(label: Text(unread > 99 ? '99+' : '$unread'))
                : null,
            onTap: () => context.push(Routes.notificationCenter),
          ),
        if (following)
          ListTile(
            leading: const Icon(Icons.favorite_border_rounded),
            title: const Text('Following'),
            onTap: () => context.push(Routes.following),
          ),
        if (on(Feature.startupFollows))
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Startup watchlist'),
            onTap: () => context.push(Routes.watchlist),
          ),
        if (on(Feature.comments))
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: const Text('My comments'),
            onTap: () => context.push(Routes.myComments),
          ),
        if (on(Feature.storySubmissions) ||
            on(Feature.startupSubmissions) ||
            on(Feature.startupClaims))
          ListTile(
            leading: const Icon(Icons.outbox_outlined),
            title: const Text('My submissions'),
            onTap: () => context.push(Routes.mySubmissions),
          ),
        if (on(Feature.polls))
          ListTile(
            leading: const Icon(Icons.poll_outlined),
            title: const Text('Polls'),
            onTap: () => context.push(Routes.polls),
          ),
        ListTile(
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('Account settings'),
          onTap: () => context.push(Routes.accountSettings),
        ),
      ],
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

class _InterestsSheet extends ConsumerWidget {
  const _InterestsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      preferencesProvider.select((p) => p.interestSlugs),
    );
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your topics', style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text('These come first on Home.', style: context.text.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  FilterChip(
                    avatar: Icon(categoryIcon(c.slug), size: 18),
                    label: Text(c.displayName),
                    selected: selected.contains(c.slug),
                    onSelected: (on) => ref
                        .read(preferencesProvider.notifier)
                        .update(
                          (p) => p.copyWith(
                            interestSlugs: on
                                ? {...p.interestSlugs, c.slug}
                                : ({...p.interestSlugs}..remove(c.slug)),
                          ),
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
