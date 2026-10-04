import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/providers.dart';
import '../../core/services/analytics_service.dart';

/// Open editorial polls. Empty when polls are switched off.
final activePollsProvider = FutureProvider<List<Poll>>((ref) async {
  if (!ref.watch(featureProvider(Feature.polls))) return const [];
  return ref.watch(communityApiProvider).activePolls();
});

final pastPollsProvider = FutureProvider<List<Poll>>((ref) async {
  if (!ref.watch(featureProvider(Feature.polls))) return const [];
  return ref.watch(communityApiProvider).pastPolls();
});

/// Today's Question of the Day, or null when there isn't one.
final questionOfTheDayProvider = FutureProvider<Poll?>((ref) async {
  if (!ref.watch(featureProvider(Feature.questionOfTheDay))) return null;
  return ref.watch(communityApiProvider).questionOfTheDay();
});

class PollState {
  const PollState({required this.poll, this.myVote, this.busy = false});

  final Poll poll;
  final String? myVote;
  final bool busy;

  bool get hasVoted => myVote != null;

  /// Results show after voting, or once the poll has closed.
  bool get showResults => hasVoted || !poll.isOpen;

  bool get canVote => poll.isOpen && (!hasVoted || poll.allowChange);
}

/// One poll with the person's vote. Voting updates the results at once
/// and rolls back if the vote doesn't go through.
class PollNotifier extends Notifier<PollState> {
  PollNotifier(this.initial);

  final Poll initial;

  @override
  PollState build() {
    final api = ref.watch(communityApiProvider);
    if (ref.watch(currentUidProvider) != null) {
      unawaited(
        api.myVote(initial.id).then((vote) {
          if (ref.mounted && !state.busy) {
            state = PollState(poll: state.poll, myVote: vote);
          }
        }, onError: (Object _) {}),
      );
    }
    return PollState(poll: initial);
  }

  Future<void> vote(String optionId) async {
    final before = state;
    if (before.busy || !before.canVote || before.myVote == optionId) return;
    state = PollState(
      poll: before.poll.withVote(from: before.myVote, to: optionId),
      myVote: optionId,
      busy: true,
    );
    try {
      final poll = await ref
          .read(communityApiProvider)
          .vote(before.poll, optionId);
      if (ref.mounted) state = PollState(poll: poll, myVote: optionId);
      unawaited(
        ref.read(analyticsProvider).log(AnalyticsEvent.pollVote, {
          'poll_id': before.poll.id,
        }),
      );
    } on Object {
      if (ref.mounted) state = before;
      rethrow;
    }
  }
}

final pollProvider = NotifierProvider.autoDispose
    .family<PollNotifier, PollState, Poll>(PollNotifier.new);
