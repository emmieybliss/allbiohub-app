import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/category.dart';
import '../../core/providers.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/article_cards.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_views.dart';
import 'article_providers.dart';

/// All stories in a category or tag ("View all").
class TopicFeedScreen extends ConsumerWidget {
  const TopicFeedScreen({
    super.key,
    required this.slug,
    required this.kind,
    this.preview,
  });

  final String slug;
  final TermKind kind;
  final Category? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (kind: kind, slug: slug);
    final topic = preview ?? ref.watch(topicProvider(key)).value;
    final lookup = preview == null ? ref.watch(topicProvider(key)) : null;

    if (topic == null) {
      return Scaffold(
        appBar: AppBar(),
        body: lookup?.hasError ?? false
            ? ErrorView(
                error: lookup!.error!,
                onRetry: () => ref.invalidate(topicProvider(key)),
              )
            : const ArticleListSkeleton(),
      );
    }
    return _TopicFeed(topic: topic);
  }
}

class _TopicFeed extends ConsumerStatefulWidget {
  const _TopicFeed({required this.topic});

  final Category topic;

  @override
  ConsumerState<_TopicFeed> createState() => _TopicFeedState();
}

class _TopicFeedState extends ConsumerState<_TopicFeed> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).log(AnalyticsEvent.categoryView, {
      'slug': widget.topic.slug,
      'kind': widget.topic.kind.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final state = ref.watch(topicFeedProvider(topic));
    final notifier = ref.read(topicFeedProvider(topic).notifier);
    final title = topic.kind == TermKind.tag
        ? '#${topic.name}'
        : topic.displayName;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 800) notifier.loadMore();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          edgeOffset: 120,
          child: CustomScrollView(
            slivers: [
              SliverAppBar.medium(
                title: Text(title, style: context.text.headlineSmall),
              ),
              if (topic.description.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      topic.description,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.brand.muted,
                      ),
                    ),
                  ),
                ),
              if (state.stale)
                SliverToBoxAdapter(
                  child: OfflineBanner(onRetry: notifier.refresh),
                ),
              if (state.isInitialLoading)
                const SliverToBoxAdapter(child: ArticleListSkeleton())
              else if (state.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    error: state.error!,
                    onRetry: notifier.retry,
                  ),
                )
              else if (state.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: MessageView(
                    icon: Icons.article_outlined,
                    title: 'No stories yet',
                    message: 'Nothing has been published here yet.',
                  ),
                )
              else ...[
                SliverList.builder(
                  itemCount: state.items.length,
                  itemBuilder: (_, i) => i == 0
                      ? ArticleFeatureCard(article: state.items[i])
                      : ArticleListTile(article: state.items[i]),
                ),
                SliverToBoxAdapter(
                  child: LoadMoreFooter(
                    isLoading: state.isLoadingMore,
                    error: state.loadMoreError,
                    onRetry: notifier.retry,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
