import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/article.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// The AllBioHub wordmark as in the logo: bold sans, "Hub" in brand orange.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = fontStyle(
      AppFonts.body,
      size,
      FontWeight.w800,
      letterSpacing: size * -0.03,
      color: color ?? context.colors.onSurface,
    );
    return Semantics(
      label: 'AllBioHub',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'AllBio', style: base),
            TextSpan(
              text: 'Hub',
              style: base.copyWith(color: context.brand.highlight),
            ),
          ],
        ),
      ),
    );
  }
}

/// The circle-and-silhouette mark from the logo.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/logo_mark.png',
    width: size,
    height: size,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
  );
}

/// Section title with an optional "View all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onViewAll,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: context.text.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: Semantics(
                label: 'View all $title',
                excludeSemantics: true,
                child: const Text('View all'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Save/unsave toggle with a small pop animation.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({
    super.key,
    required this.article,
    this.color,
    this.showSnackBar = true,
  });

  final Article article;
  final Color? color;
  final bool showSnackBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isBookmarkedProvider(article.id));
    return IconButton(
      tooltip: saved ? 'Remove from saved' : 'Save story',
      onPressed: () async {
        HapticFeedback.lightImpact();
        final nowSaved = await ref
            .read(bookmarksProvider.notifier)
            .toggle(article);
        if (!context.mounted || !showSnackBar) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                nowSaved ? 'Saved for later' : 'Removed from saved',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
        child: Icon(
          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          key: ValueKey(saved),
          color: saved ? context.brand.accentText : color,
        ),
      ),
    );
  }
}

/// Pill-shaped tappable topic.
class TopicChip extends StatelessWidget {
  const TopicChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    avatar: icon == null ? null : Icon(icon, size: 18),
    selected: selected,
    onSelected: (_) => onTap(),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
