import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/community/models.dart';
import '../../core/providers.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/state_views.dart';
import 'community_widgets.dart';
import 'polls_providers.dart';

/// A poll or Question of the Day. Vote once (or change it when the poll
/// allows); results show after voting or when the poll closes.
class PollCard extends ConsumerWidget {
  const PollCard({super.key, required this.poll, this.label});

  final Poll poll;

  /// Small heading above the question, e.g. "Question of the Day".
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pollProvider(poll));
    final brand = context.brand;
    final p = state.poll;
    final percentages = p.percentages;

    Future<void> vote(String optionId) async {
      HapticFeedback.selectionClick();
      if (!await requireAccount(
        context,
        ref,
        profile: false,
        reason: 'Sign in to vote. Your vote is never shown to anyone.',
      )) {
        return;
      }
      try {
        await ref.read(pollProvider(poll).notifier).vote(optionId);
      } on Object catch (e) {
        if (context.mounted) showCommunityError(context, e);
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: brand.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brand.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (label ??
                          (p.kind == PollKind.questionOfTheDay
                              ? 'Question of the Day'
                              : 'Poll'))
                      .toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: brand.accentText,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Share poll',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                onPressed: () => _share(ref, p),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(p.question, style: context.text.titleLarge),
          const SizedBox(height: 14),
          for (final option in p.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionRow(
                label: option.label,
                selected: state.myVote == option.id,
                showResults: state.showResults,
                percent: percentages[option.id] ?? 0,
                onTap: state.canVote && !state.busy
                    ? () => vote(option.id)
                    : null,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            [
              if (state.showResults || p.totalVotes > 0)
                '${p.totalVotes} ${p.totalVotes == 1 ? 'vote' : 'votes'}',
              if (!p.isOpen) 'Closed',
              if (p.isOpen && state.hasVoted && p.allowChange)
                'You can change your vote',
              if (p.isOpen && p.expiresAt != null)
                'Closes ${MaterialLocalizations.of(context).formatMediumDate(p.expiresAt!)}',
            ].join(' · '),
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }

  void _share(WidgetRef ref, Poll p) {
    final site = ref.read(appConfigProvider).siteUrl;
    ref.read(analyticsProvider).log(AnalyticsEvent.pollShare, {
      'poll_id': p.id,
    });
    SharePlus.instance.share(
      ShareParams(
        text: '${p.question}\n\nVote in the AllBioHub app:\n$site',
        subject: p.question,
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.showResults,
    required this.percent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showResults;
  final int percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: showResults ? '$label, $percent percent' : label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: selected ? brand.accent : brand.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (showResults)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percent / 100,
                    child: ColoredBox(
                      color: selected
                          ? brand.accentSoft
                          : brand.border.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (selected) ...[
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: brand.accentText,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: Text(label, style: context.text.bodyLarge)),
                    if (showResults)
                      Text('$percent%', style: context.text.titleSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Open polls, then closed ones.
class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activePollsProvider);
    final past = ref.watch(pastPollsProvider).value ?? const <Poll>[];
    final qotd = ref.watch(questionOfTheDayProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Polls')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activePollsProvider);
          ref.invalidate(pastPollsProvider);
          ref.invalidate(questionOfTheDayProvider);
          await ref.read(activePollsProvider.future);
        },
        child: switch (active) {
          AsyncError(:final error) when !active.isLoading => ListView(
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.invalidate(activePollsProvider),
              ),
            ],
          ),
          AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (qotd != null) ...[
                PollCard(poll: qotd),
                const SizedBox(height: 16),
              ],
              for (final p in value) ...[
                PollCard(poll: p),
                const SizedBox(height: 16),
              ],
              if (value.isEmpty && qotd == null)
                const MessageView(
                  icon: Icons.poll_outlined,
                  title: 'No open polls',
                  message: 'AllBioHub editors post new polls regularly.',
                ),
              if (past.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text('Past polls', style: context.text.titleLarge),
                ),
                for (final p in past) ...[
                  PollCard(poll: p),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
