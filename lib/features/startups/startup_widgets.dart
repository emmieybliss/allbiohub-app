import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/startup.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_image.dart';

void openStartup(BuildContext context, Startup startup) =>
    context.push(Routes.startup(startup.slug));

/// Logo in a rounded square, or the startup's initials when there's none.
class StartupLogo extends StatelessWidget {
  const StartupLogo({super.key, required this.startup, this.size = 52});

  final Startup startup;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final initials = startup.name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: brand.goldSoft,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: brand.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: startup.logo != null
          ? Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: AppImage(
                image: startup.logo,
                fit: BoxFit.contain,
                allowCropped: true,
              ),
            )
          : Center(
              child: Text(
                initials,
                style: fontStyle(
                  AppFonts.display,
                  size * 0.36,
                  FontWeight.w700,
                  color: brand.goldText,
                ),
              ),
            ),
    );
  }
}

/// Status badges, only for flags the backend actually set.
class StartupBadges extends StatelessWidget {
  const StartupBadges({
    super.key,
    required this.startup,
    this.showClaimed = false,
  });

  final Startup startup;
  final bool showClaimed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final badges = [
      if (startup.verified)
        (Icons.verified_rounded, 'Verified', brand.verified),
      if (startup.featured) (Icons.star_rounded, 'Featured', brand.goldText),
      if (showClaimed && startup.claimed)
        (Icons.how_to_reg_rounded, 'Claimed', brand.muted),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (icon, label, color) in badges)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: context.text.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts(this.startup);

  final Startup startup;

  @override
  Widget build(BuildContext context) {
    final facts = [
      startup.industry,
      startup.location,
      startup.stage,
      startup.funding,
    ].whereType<String>().toSet().toList();
    if (facts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final f in facts.take(3))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: context.brand.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              f,
              style: context.text.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// Directory card: logo, name, badges, summary, key facts, View Startup.
class StartupCard extends StatelessWidget {
  const StartupCard({super.key, required this.startup, this.width});

  final Startup startup;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openStartup(context, startup),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    StartupLogo(startup: startup, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  startup.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleMedium,
                                ),
                              ),
                              if (startup.verified) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.verified_rounded,
                                  size: 17,
                                  color: brand.verified,
                                  semanticLabel: 'Verified',
                                ),
                              ],
                            ],
                          ),
                          if (startup.location != null)
                            Text(
                              startup.location!,
                              style: context.text.bodySmall,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    ),
                    if (startup.featured)
                      Icon(
                        Icons.star_rounded,
                        color: brand.goldText,
                        size: 20,
                        semanticLabel: 'Featured',
                      ),
                  ],
                ),
                if (startup.summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    startup.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      color: brand.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Facts(startup),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'View startup',
                      style: context.text.labelLarge?.copyWith(
                        color: brand.goldText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: brand.goldText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal rail of startup cards.
class StartupRailList extends StatelessWidget {
  const StartupRailList({super.key, required this.startups});

  final List<Startup> startups;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 236,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: startups.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, i) => StartupCard(startup: startups[i], width: 290),
    ),
  );
}

/// Shown when the startup API isn't available yet.
class StartupDirectoryPromo extends StatelessWidget {
  const StartupDirectoryPromo({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: const Color(0xFF111114),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STARTUP DIRECTORY',
                        style: context.text.labelSmall?.copyWith(
                          color: brand.gold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Explore African startups',
                        style: context.text.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Companies, founders and the ideas behind them.',
                        style: context.text.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.rocket_launch_rounded, color: brand.gold, size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
