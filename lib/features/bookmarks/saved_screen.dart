import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/article_cards.dart';
import '../../shared/widgets/state_views.dart';

/// Saved stories, stored on the device. Swipe to remove.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(bookmarksProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text('Saved', style: context.text.headlineSmall),
      ),
      body: saved.isEmpty
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
            ),
    );
  }
}
