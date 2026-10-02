import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/article.dart';
import '../../core/models/category.dart';
import '../../core/models/media_image.dart';
import '../../core/models/user_preferences.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../shared/link_opener.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/article_cards.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_views.dart';
import 'article_html.dart';
import 'article_providers.dart';

/// The reader. Opened by id (from a list, with [preview] for an instant
/// header) or by slug (from a deep link).
class ArticleScreen extends ConsumerStatefulWidget {
  const ArticleScreen({super.key, this.id, this.slug, this.preview})
    : assert(id != null || slug != null);

  final int? id;
  final String? slug;
  final Article? preview;

  @override
  ConsumerState<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends ConsumerState<ArticleScreen> {
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);
  int? _loggedId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final max = _scroll.position.maxScrollExtent;
      _progress.value = max <= 0 ? 0 : (_scroll.offset / max).clamp(0, 1);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  AsyncValue<Article> _watchArticle() => widget.id != null
      ? ref.watch(articleByIdProvider(widget.id!))
      : ref.watch(articleBySlugProvider(widget.slug!));

  void _retry() => widget.id != null
      ? ref.invalidate(articleByIdProvider(widget.id!))
      : ref.invalidate(articleBySlugProvider(widget.slug!));

  void _logView(Article article) {
    if (_loggedId == article.id) return;
    _loggedId = article.id;
    ref.read(analyticsProvider).log(AnalyticsEvent.articleView, {
      'article_id': article.id,
      if (article.primaryCategory != null)
        'category': article.primaryCategory!.slug,
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = _watchArticle();
    final article = async.value ?? widget.preview;
    if (async.value != null) _logView(async.value!);

    if (article == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.hasError
            ? ErrorView(error: async.error!, onRetry: _retry)
            : const ArticleListSkeleton(count: 4),
      );
    }

    final full = async.value;
    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          _ReaderAppBar(article: article, progress: _progress),
          SliverToBoxAdapter(child: _Header(article: full ?? article)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverToBoxAdapter(
              child: switch (async) {
                AsyncData(:final value) => _Body(article: value),
                AsyncError(:final error) when !async.isLoading => ErrorView(
                  error: error,
                  onRetry: _retry,
                  compact: true,
                ),
                _ => Skeleton(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 8; i++) ...const [
                        SkeletonBox(height: 15),
                        SizedBox(height: 10),
                      ],
                      const SkeletonBox(width: 200, height: 15),
                    ],
                  ),
                ),
              },
            ),
          ),
          if (full != null) ...[
            SliverToBoxAdapter(child: _Footer(article: full)),
            _Related(article: full),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _ReaderAppBar extends ConsumerWidget {
  const _ReaderAppBar({required this.article, required this.progress});

  final Article article;
  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = article.image != null;
    final width = MediaQuery.sizeOf(context).width;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: hasImage ? (width * 0.68).clamp(220.0, 420.0) : null,
      actions: [
        IconButton(
          tooltip: 'Text size',
          icon: const Icon(Icons.text_fields_rounded),
          onPressed: () => _showTextSize(context, ref),
        ),
        IconButton(
          tooltip: 'Share',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () async {
            final shared = await ref
                .read(shareServiceProvider)
                .shareArticle(article);
            if (shared) {
              ref.read(analyticsProvider).log(AnalyticsEvent.articleShare, {
                'article_id': article.id,
              });
            }
          },
        ),
        BookmarkButton(article: article),
        const SizedBox(width: 4),
      ],
      flexibleSpace: hasImage
          ? FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Hero(
                tag: 'article-image-${article.id}',
                child: AppImage(image: article.image),
              ),
            )
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: context.brand.accent,
            semanticsLabel: 'Reading progress',
          ),
        ),
      ),
    );
  }

  void _showTextSize(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final size = ref.watch(preferencesProvider.select((p) => p.textSize));
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Text size', style: context.text.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ReaderTextSize>(
                      showSelectedIcon: false,
                      segments: [
                        for (final s in ReaderTextSize.values)
                          ButtonSegment(
                            value: s,
                            tooltip: s.label,
                            label: Text(
                              'A',
                              style: TextStyle(fontSize: 13 * s.scale + 2),
                            ),
                          ),
                      ],
                      selected: {size},
                      onSelectionChanged: (v) => ref
                          .read(preferencesProvider.notifier)
                          .update((p) => p.copyWith(textSize: v.first)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final author = article.author;
    final meta = [
      fullDate(article.publishedAt),
      if (article.readingMinutes != null) '${article.readingMinutes} min read',
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.categories.isNotEmpty)
            Wrap(
              spacing: 12,
              children: [
                for (final c in article.categories.take(2))
                  InkWell(
                    onTap: () =>
                        context.push(Routes.category(c.slug), extra: c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: CategoryLabel(c.displayName),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Semantics(
            header: true,
            child: Text(article.title, style: context.text.headlineLarge),
          ),
          if (_showStandfirst(article)) ...[
            const SizedBox(height: 12),
            Text(
              article.excerpt,
              style: context.text.bodyLarge?.copyWith(
                color: brand.muted,
                fontSize: 17.5,
                height: 1.55,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _AuthorAvatar(name: author?.name, url: author?.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author?.name ?? 'AllBioHub',
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(meta, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
        ],
      ),
    );
  }

  /// WordPress auto-excerpts repeat the opening paragraph; only show a
  /// standfirst when it's a hand-written summary.
  static bool _showStandfirst(Article a) {
    if (a.excerpt.isEmpty || a.contentHtml == null) return false;
    final lead = a.excerpt.replaceAll('…', '').trim();
    if (lead.length < 20) return false;
    final body = htmlToPlainText(a.contentHtml);
    return !body.contains(lead.substring(0, lead.length.clamp(0, 60)));
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.name, this.url});

  final String? name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final initial = Center(
      child: Text(
        (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : 'A',
        style: TextStyle(color: brand.accentText, fontWeight: FontWeight.w700),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: brand.accentSoft,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: url == null
            ? initial
            : Stack(
                fit: StackFit.expand,
                children: [
                  initial,
                  AppImage(image: MediaImage.single(url!), allowCropped: true),
                ],
              ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(
      preferencesProvider.select((p) => p.textSize.scale),
    );
    final html = article.contentHtml;
    if (html == null || html.trim().isEmpty) {
      return const MessageView(
        icon: Icons.article_outlined,
        title: 'Nothing to show',
        message: "This story doesn't have any text.",
        compact: true,
      );
    }
    return ArticleHtml(
      html: html,
      baseUrl: Uri.parse(article.link),
      textScale: scale,
      onLinkTap: (uri) => openLink(context, ref, uri),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in article.tags.take(8))
                  ActionChip(
                    label: Text('#${t.name}'),
                    onPressed: () => context.push(Routes.tag(t.slug), extra: t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final shared = await ref
                        .read(shareServiceProvider)
                        .shareArticle(article);
                    if (shared) {
                      ref.read(analyticsProvider).log(
                        AnalyticsEvent.articleShare,
                        {'article_id': article.id},
                      );
                    }
                  },
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share this story'),
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.outline),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: BookmarkButton(article: article),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Related extends ConsumerWidget {
  const _Related({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related =
        ref.watch(relatedArticlesProvider(article)).value ?? const [];
    if (related.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final category = article.primaryCategory;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Related stories',
            onViewAll: category == null
                ? null
                : () => _openCategory(context, category),
          ),
        ),
        SliverList.list(
          children: [for (final a in related) ArticleListTile(article: a)],
        ),
      ],
    );
  }

  void _openCategory(BuildContext context, Category c) =>
      context.push(Routes.category(c.slug), extra: c);
}
