import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/models.dart';
import '../../core/providers.dart';
import '../../core/services/analytics_service.dart';

class ReactionState {
  const ReactionState({
    this.engagement = ArticleEngagement.empty,
    this.mine,
    this.busy = false,
  });

  final ArticleEngagement engagement;

  /// The signed-in person's reaction.
  final ReactionType? mine;

  /// A change is being sent; the counts shown already include it.
  final bool busy;
}

/// Reaction counts for one article, live from the server, plus the
/// person's own reaction. Changing it updates the screen at once and rolls
/// back if the server refuses or the phone is offline.
class ReactionNotifier extends Notifier<ReactionState> {
  ReactionNotifier(this.articleId);

  final int articleId;

  @override
  ReactionState build() {
    final api = ref.watch(communityApiProvider);
    final uid = ref.watch(currentUidProvider);
    final sub = api.watchEngagement(articleId).listen((engagement) {
      // While a change is in flight the optimistic counts stay on screen.
      if (!state.busy) {
        state = ReactionState(engagement: engagement, mine: state.mine);
      }
    }, onError: (Object _) {});
    ref.onDispose(sub.cancel);
    if (uid != null) {
      unawaited(
        api.myReaction(articleId).then((mine) {
          if (ref.mounted && !state.busy) {
            state = ReactionState(engagement: state.engagement, mine: mine);
          }
        }, onError: (Object _) {}),
      );
    }
    return const ReactionState();
  }

  /// Selects [reaction], or clears it when it's already selected.
  Future<void> toggle(ReactionType reaction) =>
      set(state.mine == reaction ? null : reaction);

  Future<void> set(ReactionType? reaction) async {
    if (state.busy) return;
    final before = state;
    state = ReactionState(
      engagement: before.engagement.withReactionChange(before.mine, reaction),
      mine: reaction,
      busy: true,
    );
    try {
      final engagement = await ref
          .read(communityApiProvider)
          .setReaction(articleId, reaction);
      if (!ref.mounted) return;
      state = ReactionState(engagement: engagement, mine: reaction);
      if (reaction != null) {
        unawaited(
          ref.read(analyticsProvider).log(AnalyticsEvent.articleReaction, {
            'article_id': articleId,
            'reaction': reaction.key,
          }),
        );
      }
    } on Object {
      if (ref.mounted) state = before;
      rethrow;
    }
  }
}

final reactionProvider =
    NotifierProvider.family<ReactionNotifier, ReactionState, int>(
      ReactionNotifier.new,
    );
