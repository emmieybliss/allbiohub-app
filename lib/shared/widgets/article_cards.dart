import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/article.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import 'app_image.dart';

void openArticle(BuildContext context, Article article) =>
    context.push(Routes.article(article.id), extra: article);

/// Small uppercase category label in brand gold.
class CategoryLabel extends StatelessWidget {
  const CategoryLabel(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.text.labelSmall?.copyWith(
      color: color ?? context.brand.goldText,
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.article, {this.color});

  final Article article;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final parts = [
      relativeDate(article.publishedAt),
      if (article.readingMinutes != null) '${article.readingMinutes} min read',
    ];
    return Text(
      parts.join('  ·  '),
      maxLines: 1,
      style: context.text.bodySmall?.copyWith(color: color),
    );
  }
}

/// Large card with an overlaid headline, for the featured story.
class ArticleHeroCard extends StatelessWidget {
  const ArticleHeroCard({super.key, required this.article, this.height = 400});

  final Article article;
  final double height;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Semantics(
      button: true,
      label: 'Featured story: ${article.title}',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'article-image-${article.id}',
                child: AppImage(image: article.image),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, brand.heroScrim],
                    stops: const [0.3, 1],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.primaryCategory != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: brand.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: CategoryLabel(
                          article.primaryCategory!.displayName,
                          color: brand.onGold,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      article.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Meta(article, color: Colors.white70),
                  ],
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: () => openArticle(context, article)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row card: text on the left, square thumbnail on the right.
class ArticleListTile extends StatelessWidget {
  const ArticleListTile({super.key, required this.article, this.trailing});

  final Article article;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: article.title,
      child: InkWell(
        onTap: () => openArticle(context, article),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.primaryCategory != null) ...[
                      CategoryLabel(article.primaryCategory!.displayName),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _Meta(article)),
                        ?trailing,
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 96,
                height: 96,
                child: AppImage(
                  image: article.image,
                  allowCropped: true,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical card for horizontal rails.
class ArticleRailCard extends StatelessWidget {
  const ArticleRailCard({super.key, required this.article, this.width = 250});

  final Article article;
  final double width;

  /// Height a rail of these cards needs: the image plus a label, a
  /// three-line headline and the meta line at the reader's text size.
  static double railHeight(BuildContext context, {double width = 250}) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = context.text;
    double lines(TextStyle? style, int count) =>
        count * scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.4);
    return width * 10 / 16 +
        10 +
        lines(text.labelSmall, 1) +
        4 +
        lines(text.titleMedium, 3) +
        6 +
        lines(text.bodySmall, 1) +
        8;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: article.title,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openArticle(context, article),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                image: article.image,
                aspectRatio: 16 / 10,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(height: 10),
              if (article.primaryCategory != null) ...[
                CategoryLabel(article.primaryCategory!.displayName),
                const SizedBox(height: 4),
              ],
              Text(
                article.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium,
              ),
              const SizedBox(height: 6),
              _Meta(article),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide card with the image above the headline, for lead stories.
class ArticleFeatureCard extends StatelessWidget {
  const ArticleFeatureCard({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: article.title,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openArticle(context, article),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                image: article.image,
                aspectRatio: 16 / 9,
                borderRadius: BorderRadius.circular(18),
              ),
              const SizedBox(height: 14),
              if (article.primaryCategory != null) ...[
                CategoryLabel(article.primaryCategory!.displayName),
                const SizedBox(height: 6),
              ],
              Text(
                article.title,
                style: context.text.headlineSmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (article.excerpt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  article.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.brand.muted,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _Meta(article),
            ],
          ),
        ),
      ),
    );
  }
}
