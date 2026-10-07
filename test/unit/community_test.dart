import 'package:allbiohub/core/cache/local_store.dart';
import 'package:allbiohub/core/community/community_exception.dart';
import 'package:allbiohub/core/community/community_providers.dart';
import 'package:allbiohub/core/community/feature_flags.dart';
import 'package:allbiohub/core/community/models.dart';
import 'package:allbiohub/core/providers.dart';
import 'package:allbiohub/core/utils/text_utils.dart';
import 'package:allbiohub/features/account/username_screen.dart';
import 'package:allbiohub/features/community/comments_providers.dart';
import 'package:allbiohub/features/community/polls_providers.dart';
import 'package:allbiohub/features/community/reactions_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_community.dart';

const _author = CommentAuthor(uid: 'u2', username: 'ada', displayName: 'Ada');

ProviderContainer _container(
  FakeAuth auth,
  FakeCommunity api, {
  Set<Feature>? features,
}) {
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      settingsStoreProvider.overrideWithValue(MemoryLocalStore()),
      ...communityOverrides(auth: auth, api: api, features: features),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('Feature switches', () {
    test('everything is off without a community backend', () {
      final c = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemoryLocalStore()),
        ],
      );
      addTearDown(c.dispose);
      for (final f in Feature.values) {
        expect(c.read(featureProvider(f)), isFalse, reason: f.key);
      }
    });

    test('features that need an account are off while accounts are off', () {
      final flags = FeatureFlags.fromJson({
        'features': {'reactions': true, 'forYou': true},
      });
      expect(flags.isOn(Feature.reactions), isFalse);
      expect(flags.isOn(Feature.forYou), isTrue);
      expect(
        FeatureFlags.fromJson({
          'features': {'accounts': true, 'reactions': true},
        }).isOn(Feature.reactions),
        isTrue,
      );
    });

    test('switches load from the server and are remembered', () async {
      final store = MemoryLocalStore();
      final c = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          ...communityOverrides(
            auth: FakeAuth(),
            api: FakeCommunity(),
            features: {Feature.accounts, Feature.polls},
          ),
        ],
      );
      expect(c.read(featureProvider(Feature.polls)), isFalse);
      await _settle();
      expect(c.read(featureProvider(Feature.polls)), isTrue);
      expect(c.read(featureProvider(Feature.comments)), isFalse);
      c.dispose();
      expect(FeatureFlagCache(store).load().isOn(Feature.polls), isTrue);
    });
  });

  group('Reactions', () {
    test('show at once, then match the server', () async {
      final auth = FakeAuth(signedIn: verifiedUser());
      final api = FakeCommunity(auth: auth);
      final c = _container(auth, api);
      c.listen(reactionProvider(1), (_, _) {});
      await _settle();
      await c.read(reactionProvider(1).notifier).toggle(ReactionType.love);
      var s = c.read(reactionProvider(1));
      expect(s.mine, ReactionType.love);
      expect(s.engagement.countOf(ReactionType.love), 1);

      await c.read(reactionProvider(1).notifier).toggle(ReactionType.wow);
      s = c.read(reactionProvider(1));
      expect(s.engagement.countOf(ReactionType.love), 0);
      expect(s.engagement.countOf(ReactionType.wow), 1);

      await c.read(reactionProvider(1).notifier).toggle(ReactionType.wow);
      expect(c.read(reactionProvider(1)).mine, isNull);
    });

    test('roll back when offline', () async {
      final auth = FakeAuth(signedIn: verifiedUser());
      final api = FakeCommunity(auth: auth)..offline = true;
      final c = _container(auth, api);
      c.listen(reactionProvider(1), (_, _) {});
      await _settle();
      await expectLater(
        c.read(reactionProvider(1).notifier).toggle(ReactionType.interesting),
        throwsA(
          isA<CommunityException>().having(
            (e) => e.message,
            'message',
            'You are offline. Connect to the internet to perform this action.',
          ),
        ),
      );
      final s = c.read(reactionProvider(1));
      expect(s.mine, isNull);
      expect(s.engagement.countOf(ReactionType.interesting), 0);
    });
  });

  group('Comments', () {
    Future<(ProviderContainer, FakeCommunity)> setUp() async {
      final auth = FakeAuth(signedIn: verifiedUser());
      final api = FakeCommunity(auth: auth);
      await api.createProfile(username: 'me', displayName: 'Me');
      for (var i = 0; i < 25; i++) {
        api.storedComments.add(
          Comment(
            id: 'old$i',
            articleId: 7,
            author: _author,
            body: 'Comment $i',
            createdAt: DateTime(2026, 10, 1).add(Duration(minutes: i)),
          ),
        );
      }
      final c = _container(auth, api);
      c.listen(commentsProvider(7), (_, _) {});
      await _settle();
      return (c, api);
    }

    test('load a page at a time', () async {
      final (c, _) = await setUp();
      var s = c.read(commentsProvider(7));
      expect(s.threads, hasLength(20));
      expect(s.hasMore, isTrue);
      expect(s.threads.first.root.body, 'Comment 24');
      await c.read(commentsProvider(7).notifier).loadMore();
      s = c.read(commentsProvider(7));
      expect(s.threads, hasLength(25));
      expect(s.hasMore, isFalse);
    });

    test(
      'new comments and replies appear; replies stop at two levels',
      () async {
        final (c, api) = await setUp();
        final notifier = c.read(commentsProvider(7).notifier);
        final top = await notifier.add('Great story');
        expect(c.read(commentsProvider(7)).threads.first.root.id, top.id);

        final reply = await notifier.add('Agreed', parent: top);
        final deeper = await notifier.add('Me too', parent: reply);
        final deepest = await notifier.add('And me', parent: deeper);
        expect(reply.depth, 1);
        expect(deeper.depth, 2);
        expect(deepest.depth, 2, reason: 'a reply at depth 2 joins its parent');
        expect(deepest.parentId, reply.id);
        expect(deepest.replyToUsername, 'me');
        final thread = c.read(commentsProvider(7)).threads.first;
        expect(thread.replies.map((r) => r.body), [
          'Agreed',
          'Me too',
          'And me',
        ]);
        expect(
          api.storedComments.where((x) => x.rootId == top.id),
          hasLength(3),
        );
      },
    );

    test('comments held for review are not shown as published', () async {
      final (c, api) = await setUp();
      api.holdComments = true;
      final comment = await c
          .read(commentsProvider(7).notifier)
          .add('Link spam?');
      expect(comment.isPending, isTrue);
      expect(
        c.read(commentsProvider(7)).threads.any((t) => t.root.id == comment.id),
        isFalse,
      );
    });

    test('likes change at once and roll back on failure', () async {
      final (c, api) = await setUp();
      final notifier = c.read(commentsProvider(7).notifier);
      final first = c.read(commentsProvider(7)).threads.first.root;
      await notifier.toggleLike(first);
      expect(c.read(commentsProvider(7)).threads.first.root.likeCount, 1);
      expect(c.read(commentsProvider(7)).liked, contains(first.id));

      api.failNext = const CommunityException(CommunityErrorKind.rateLimited);
      final liked = c.read(commentsProvider(7)).threads.first.root;
      await expectLater(
        notifier.toggleLike(liked),
        throwsA(isA<CommunityException>()),
      );
      expect(c.read(commentsProvider(7)).threads.first.root.likeCount, 1);
      expect(c.read(commentsProvider(7)).liked, contains(first.id));
    });

    test('deleting a comment with replies leaves a placeholder', () async {
      final (c, _) = await setUp();
      final notifier = c.read(commentsProvider(7).notifier);
      final top = await notifier.add('Hello');
      await notifier.add('Reply', parent: top);
      final withCount = c.read(commentsProvider(7)).threads.first.root;
      expect(withCount.replyCount, 1);
      await notifier.delete(withCount);
      final root = c.read(commentsProvider(7)).threads.first.root;
      expect(root.deleted, isTrue);
      expect(root.body, isEmpty);
    });
  });

  group('Follows', () {
    test('follow at once and roll back when it fails', () async {
      final auth = FakeAuth(signedIn: verifiedUser());
      final api = FakeCommunity(auth: auth);
      final c = _container(auth, api);
      const target = FollowTarget(
        FollowKind.startup,
        'moniepoint',
        label: 'Moniepoint',
      );
      c.listen(isFollowingProvider(target), (_, _) {});
      await _settle();
      await c.read(followOverridesProvider.notifier).set(target, true);
      expect(c.read(isFollowingProvider(target)), isTrue);
      await _settle();
      expect(api.follows, [target]);

      api.offline = true;
      await expectLater(
        c.read(followOverridesProvider.notifier).set(target, false),
        throwsA(isA<CommunityException>()),
      );
      expect(c.read(isFollowingProvider(target)), isTrue);
    });
  });

  group('Polls', () {
    const poll = Poll(
      id: 'p1',
      kind: PollKind.poll,
      question: 'Which sector grows fastest?',
      options: [
        PollOption(id: 'o1', label: 'Fintech'),
        PollOption(id: 'o2', label: 'Health'),
      ],
      status: PollStatus.active,
      counts: {'o1': 2, 'o2': 1},
      totalVotes: 3,
    );

    test('one vote per person; results show after voting', () async {
      final auth = FakeAuth(signedIn: verifiedUser());
      final api = FakeCommunity(auth: auth)..polls.add(poll);
      final c = _container(auth, api);
      c.listen(pollProvider(poll), (_, _) {});
      await _settle();
      expect(c.read(pollProvider(poll)).showResults, isFalse);
      await c.read(pollProvider(poll).notifier).vote('o2');
      final s = c.read(pollProvider(poll));
      expect(s.showResults, isTrue);
      expect(s.canVote, isFalse);
      expect(s.poll.totalVotes, 4);
      expect(s.poll.percentages, {'o1': 50, 'o2': 50});
    });

    test('percentages always add up to 100', () {
      const p = Poll(
        id: 'p',
        kind: PollKind.poll,
        question: '?',
        options: [
          PollOption(id: 'a', label: 'A'),
          PollOption(id: 'b', label: 'B'),
          PollOption(id: 'c', label: 'C'),
        ],
        status: PollStatus.active,
        counts: {'a': 1, 'b': 1, 'c': 1},
        totalVotes: 3,
      );
      expect(p.percentages.values.reduce((a, b) => a + b), 100);
    });
  });

  group('Usernames and founder ids', () {
    test('username rules match the server', () {
      expect(usernameRule('ab'), isNotNull);
      expect(usernameRule('1abc'), isNotNull);
      expect(usernameRule('ada__lovelace'), isNotNull);
      expect(usernameRule('ada_lovelace'), isNull);
      expect(normalizeUsername(' Ada_Lovelace '), 'ada_lovelace');
    });

    test('founder slugs match the server (accents, ß, punctuation)', () {
      expect(slugify('Adébáyọ̀ Ọlọ́rùnṣọlá'), 'adebayo-olorunsola');
      expect(slugify('Jürgen Straße'), 'jurgen-strasse');
      expect(slugify("Tosin Eniolorunda (CEO)"), 'tosin-eniolorunda-ceo');
      expect(slugify('  --  '), '');
    });
  });
}
