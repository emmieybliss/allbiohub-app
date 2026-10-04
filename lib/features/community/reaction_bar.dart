import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/theme/app_theme.dart';
import 'community_widgets.dart';
import 'reactions_providers.dart';

/// ❤️ Love · 🔥 Interesting · 🤯 Wow · 💡 Informative. One reaction per
/// person; counts are the server's real totals (hidden while zero).
class ReactionBar extends ConsumerWidget {
  const ReactionBar({super.key, required this.articleId});

  final int articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureProvider(Feature.reactions))) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(reactionProvider(articleId));
    final brand = context.brand;

    Future<void> react(ReactionType type) async {
      HapticFeedback.selectionClick();
      if (!await requireAccount(
        context,
        ref,
        profile: false,
        reason: 'Sign in to react to stories.',
      )) {
        return;
      }
      try {
        await ref.read(reactionProvider(articleId).notifier).toggle(type);
      } on Object catch (e) {
        if (context.mounted) showCommunityError(context, e);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What did you think?', style: context.text.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in ReactionType.values)
              Builder(
                builder: (context) {
                  final selected = state.mine == type;
                  final count = state.engagement.countOf(type);
                  return Semantics(
                    button: true,
                    selected: selected,
                    label:
                        '${type.label}${count > 0 ? ', $count' : ''}'
                        '${selected ? ', your reaction' : ''}',
                    excludeSemantics: true,
                    child: Material(
                      color: selected ? brand.accentSoft : Colors.transparent,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: selected ? brand.accent : brand.border,
                        ),
                      ),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => react(type),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(type.emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                count > 0 ? '$count' : type.label,
                                style: context.text.labelLarge?.copyWith(
                                  color: selected ? brand.accentText : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
