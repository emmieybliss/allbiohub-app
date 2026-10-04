import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/models.dart';
import '../../core/community/saved.dart';
import '../../core/models/media_image.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/article_cards.dart';
import '../../shared/widgets/state_views.dart';

/// Saved stories, plus saved startups and founders once there are any.
/// Stored on the device (and synced to the account when signed in).
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(savedEntitiesProvider);
    final title = Text('Saved', style: context.text.headlineSmall);
    if (entities.isEmpty) {
      return Scaffold(
        appBar: AppBar(titleSpacing: 20, title: title),
        body: const _SavedStories(),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: title,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Stories'),
              Tab(text: 'Startups'),
              Tab(text: 'Founders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _SavedStories(),
            _SavedEntities(
              items: [
                for (final e in entities)
                  if (e.kind == SavedKind.startup) e,
              ],
              empty: 'Tap the bookmark on a startup profile to save it here.',
            ),
            _SavedEntities(
              items: [
                for (final e in entities)
                  if (e.kind == SavedKind.founder) e,
              ],
              empty: 'Tap the bookmark on a founder to save them here.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedEntities extends ConsumerWidget {
  const _SavedEntities({required this.items, required this.empty});

  final List<SavedEntity> items;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return MessageView(
        icon: Icons.bookmark_border_rounded,
        title: 'Nothing saved yet.',
        message: empty,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        return ListTile(
          leading: SizedBox.square(
            dimension: 44,
            child: e.image == null
                ? CircleAvatar(
                    child: Icon(
                      e.kind == SavedKind.startup
                          ? Icons.rocket_launch_outlined
                          : Icons.person_outline_rounded,
                    ),
                  )
                : AppImage(
                    image: MediaImage.single(e.image!),
                    borderRadius: BorderRadius.circular(10),
                  ),
          ),
          title: Text(e.title),
          subtitle: e.subtitle == null
              ? null
              : Text(e.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: 'Remove from saved',
            icon: const Icon(Icons.bookmark_remove_outlined),
            onPressed: () => ref.read(savedEntitiesProvider.notifier).toggle(e),
          ),
          onTap: () => context.push(
            e.kind == SavedKind.startup
                ? Routes.startup(e.id)
                : Routes.founder(e.id),
          ),
        );
      },
    );
  }
}

class _SavedStories extends ConsumerWidget {
  const _SavedStories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(bookmarksProvider);
    return saved.isEmpty
        ? MessageView(
            icon: Icons.bookmark_border_rounded,
            title: 'Nothing saved yet.',
            message: 'Save stories you want to read later.',
            actionLabel: 'Browse stories',
            onAction: () => context.go(Routes.home),
          )
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: saved.length,
            itemBuilder: (context, i) {
              final article = saved[i];
              return Dismissible(
                key: ValueKey(article.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: context.colors.error,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: context.colors.onError,
                  ),
                ),
                onDismissed: (_) {
                  ref.read(bookmarksProvider.notifier).remove(article.id);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: const Text('Removed from saved'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => ref
                              .read(bookmarksProvider.notifier)
                              .toggle(article),
                        ),
                      ),
                    );
                },
                child: ArticleListTile(article: article),
              );
            },
          );
  }
}
