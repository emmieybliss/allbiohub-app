import 'dart:async';
import 'dart:typed_data';

import 'package:allbiohub/core/community/community_api.dart';
import 'package:allbiohub/core/community/community_exception.dart';
import 'package:allbiohub/core/community/community_providers.dart';
import 'package:allbiohub/core/community/feature_flags.dart';
import 'package:allbiohub/core/community/models.dart';

/// In-memory sign-in for tests.
class FakeAuth implements AuthRepository {
  FakeAuth({AuthUser? signedIn}) : _user = signedIn;

  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast();
  final Map<String, String> passwords = {};
  final List<String> resetEmails = [];
  int verificationEmails = 0;
  int reauthentications = 0;

  void _emit() => _changes.add(_user);

  /// Signs someone in as if they had used the sign-in screen.
  void signIn(AuthUser user) {
    _user = user;
    _emit();
  }

  @override
  bool get isAvailable => true;

  @override
  bool supportsGoogle = false;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    if (passwords[email] != password) {
      throw const CommunityException(
        CommunityErrorKind.invalid,
        message: 'Email or password is incorrect.',
      );
    }
    _user = AuthUser(uid: 'uid-$email', email: email, emailVerified: true);
    _emit();
    return _user!;
  }

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async {
    passwords[email] = password;
    verificationEmails++;
    _user = AuthUser(uid: 'uid-$email', email: email);
    _emit();
    return _user!;
  }

  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);

  @override
  Future<void> sendEmailVerification() async => verificationEmails++;

  @override
  Future<AuthUser?> reload() async => _user;

  @override
  Future<void> reauthenticate({String? password}) async => reauthentications++;

  @override
  Future<void> signOut() async {
    _user = null;
    _emit();
  }
}

/// In-memory community backend. [offline] makes every call fail the way
/// the real one does without a connection.
class FakeCommunity implements CommunityApi {
  FakeCommunity({this.auth});

  final FakeAuth? auth;
  bool offline = false;

  /// Makes the next write fail (to test rollback).
  CommunityException? failNext;

  final profiles = <String, UserProfile>{};
  final accounts = <String, AccountSettings>{};
  final takenUsernames = <String>{'allbiohub'};
  final engagement = <int, ArticleEngagement>{};
  final myReactions = <int, ReactionType>{};
  final storedComments = <Comment>[];
  final likes = <String>{};
  final reports =
      <({String targetType, String targetId, ReportReason reason})>[];
  final blocked = <String>{};
  final follows = <FollowTarget>[];
  final polls = <Poll>[];
  final votes = <String, String>{};
  final notificationsList = <AppNotification>[];
  final submissions = <(String kind, Map<String, Object?> fields)>[];
  final saved = <String, Map<String, Object?>>{};
  bool deleted = false;
  int _ids = 0;

  final _profileChanges = StreamController<void>.broadcast();
  final _followChanges = StreamController<void>.broadcast();

  String get _uid {
    final user = auth?.currentUser;
    if (user == null)
      throw const CommunityException(CommunityErrorKind.signInRequired);
    return user.uid;
  }

  Future<void> _write() async {
    if (offline) throw const CommunityException(CommunityErrorKind.offline);
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  Future<void> _read() async {
    if (offline) throw const CommunityException(CommunityErrorKind.offline);
  }

  Stream<T> _watch<T>(
    StreamController<void> changes,
    T Function() value,
  ) async* {
    yield value();
    yield* changes.stream.map((_) => value());
  }

  @override
  bool get isAvailable => true;

  // Profile

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _watch(_profileChanges, () => profiles[uid]);

  @override
  Stream<AccountSettings?> watchAccount(String uid) =>
      _watch(_profileChanges, () => accounts[uid]);

  @override
  Future<UserProfile?> profile(String uid) async {
    await _read();
    final p = profiles[uid];
    if (p == null ||
        (p.visibility == ProfileVisibility.private &&
            uid != auth?.currentUser?.uid)) {
      return null;
    }
    return p;
  }

  @override
  Future<({bool available, String? message})> checkUsername(
    String username,
  ) async {
    await _read();
    final taken = takenUsernames.contains(username.toLowerCase());
    return (
      available: !taken,
      message: taken ? 'That username is taken.' : null,
    );
  }

  @override
  Future<void> createProfile({
    required String username,
    required String displayName,
  }) async {
    await _write();
    final uid = _uid;
    if (takenUsernames.contains(username)) {
      throw const CommunityException(
        CommunityErrorKind.alreadyExists,
        message: 'That username is taken.',
      );
    }
    takenUsernames.add(username);
    profiles[uid] = UserProfile(
      uid: uid,
      username: username,
      displayName: displayName,
      joinedAt: DateTime(2026, 10, 4),
    );
    accounts[uid] = const AccountSettings();
    _profileChanges.add(null);
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    ProfileVisibility? visibility,
    bool? showActivity,
  }) async {
    await _write();
    final p = profiles[_uid]!;
    profiles[_uid] = UserProfile(
      uid: p.uid,
      username: p.username,
      displayName: displayName ?? p.displayName,
      bio: bio ?? p.bio,
      joinedAt: p.joinedAt,
      visibility: visibility ?? p.visibility,
      showActivity: showActivity ?? p.showActivity,
    );
    _profileChanges.add(null);
  }

  @override
  Future<void> setProfilePhoto(Uint8List bytes, String contentType) => _write();

  @override
  Future<void> removeProfilePhoto() => _write();

  @override
  Future<void> changeUsername(String username) async {
    await _write();
    final p = profiles[_uid]!;
    takenUsernames
      ..remove(p.username)
      ..add(username);
    profiles[_uid] = UserProfile(
      uid: p.uid,
      username: username,
      displayName: p.displayName,
    );
    _profileChanges.add(null);
  }

  @override
  Future<void> updateNotificationPrefs(
    Map<CommunityNotificationPref, bool> prefs,
  ) async {
    await _write();
    final a = accounts[_uid] ?? const AccountSettings();
    accounts[_uid] = AccountSettings(
      notificationPrefs: {...a.notificationPrefs, ...prefs},
    );
    _profileChanges.add(null);
  }

  @override
  Future<void> registerDevice(String token) async {}

  @override
  Future<void> unregisterDevice(String token) async {}

  @override
  Future<void> deleteAccount() async {
    await _write();
    profiles.remove(_uid);
    accounts.remove(_uid);
    deleted = true;
  }

  @override
  Future<void> claimAdmin() => _write();

  // Reactions

  @override
  Stream<ArticleEngagement> watchEngagement(int articleId) =>
      Stream.value(engagement[articleId] ?? ArticleEngagement.empty);

  @override
  Future<ReactionType?> myReaction(int articleId) async =>
      myReactions[articleId];

  @override
  Future<ArticleEngagement> setReaction(
    int articleId,
    ReactionType? reaction,
  ) async {
    await _write();
    final before = myReactions[articleId];
    final next = (engagement[articleId] ?? ArticleEngagement.empty)
        .withReactionChange(before, reaction);
    engagement[articleId] = next;
    if (reaction == null) {
      myReactions.remove(articleId);
    } else {
      myReactions[articleId] = reaction;
    }
    return next;
  }

  // Comments

  CommentAuthor get _author {
    final p = profiles[_uid];
    if (p == null)
      throw const CommunityException(CommunityErrorKind.profileRequired);
    return CommentAuthor(
      uid: p.uid,
      username: p.username,
      displayName: p.displayName,
    );
  }

  CursorPage<Comment> _page(List<Comment> all, Object? cursor, int limit) {
    final start = cursor as int? ?? 0;
    final items = all.skip(start).take(limit).toList();
    final end = start + items.length;
    return CursorPage(items, cursor: end, hasMore: end < all.length);
  }

  @override
  Future<CursorPage<Comment>> comments(
    int articleId, {
    Object? cursor,
    int limit = 20,
  }) async {
    await _read();
    final top =
        storedComments
            .where(
              (c) =>
                  c.articleId == articleId &&
                  c.parentId == null &&
                  c.status == ModerationStatus.approved,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _page(top, cursor, limit);
  }

  @override
  Future<CursorPage<Comment>> replies(
    String rootId, {
    Object? cursor,
    int limit = 30,
  }) async {
    await _read();
    final list =
        storedComments
            .where(
              (c) =>
                  c.rootId == rootId && c.status == ModerationStatus.approved,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return _page(list, cursor, limit);
  }

  @override
  Future<CursorPage<Comment>> commentsBy(
    String uid, {
    Object? cursor,
    int limit = 20,
  }) async {
    await _read();
    return _page(
      storedComments.where((c) => c.author.uid == uid).toList(),
      cursor,
      limit,
    );
  }

  @override
  Future<Set<String>> likedComments(Iterable<String> commentIds) async => {
    for (final id in commentIds)
      if (likes.contains(id)) id,
  };

  /// Held for review instead of published (like premoderation).
  bool holdComments = false;

  @override
  Future<Comment> addComment(
    int articleId,
    String body, {
    String? parentId,
  }) async {
    await _write();
    final author = _author;
    final parent = parentId == null
        ? null
        : storedComments.firstWhere((c) => c.id == parentId);
    // Replies stop at depth 2: a reply to a depth-2 comment joins its parent.
    final attachTo = parent != null && parent.depth >= 2
        ? storedComments.firstWhere((c) => c.id == parent.parentId)
        : parent;
    final comment = Comment(
      id: 'c${++_ids}',
      articleId: articleId,
      author: author,
      body: body,
      createdAt: DateTime(2026, 10, 4, 12).add(Duration(minutes: _ids)),
      parentId: attachTo?.id,
      rootId: attachTo == null ? null : (attachTo.rootId ?? attachTo.id),
      depth: attachTo == null ? 0 : attachTo.depth + 1,
      replyToUsername: parent?.author.username,
      status: holdComments
          ? ModerationStatus.pending
          : ModerationStatus.approved,
    );
    storedComments.add(comment);
    return comment;
  }

  @override
  Future<Comment> editComment(String commentId, String body) async {
    await _write();
    final i = storedComments.indexWhere((c) => c.id == commentId);
    return storedComments[i] = storedComments[i].copyWith(body: body);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _write();
    storedComments.removeWhere((c) => c.id == commentId);
  }

  @override
  Future<int> likeComment(String commentId, {required bool like}) async {
    await _write();
    like ? likes.add(commentId) : likes.remove(commentId);
    final i = storedComments.indexWhere((c) => c.id == commentId);
    final next = storedComments[i].likeCount + (like ? 1 : -1);
    storedComments[i] = storedComments[i].copyWith(likeCount: next);
    return next;
  }

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String details = '',
  }) async {
    await _write();
    reports.add((targetType: targetType, targetId: targetId, reason: reason));
  }

  // Safety

  @override
  Stream<Set<String>> watchBlocked(String uid) =>
      _watch(_profileChanges, () => {...blocked});

  @override
  Future<void> setBlocked(String otherUid, {required bool blocked}) async {
    await _write();
    blocked ? this.blocked.add(otherUid) : this.blocked.remove(otherUid);
    _profileChanges.add(null);
  }

  @override
  Future<void> setMuted(String otherUid, {required bool muted}) => _write();

  // Follows and saved

  @override
  Stream<List<FollowedItem>> watchFollows(String uid) => _watch(
    _followChanges,
    () => [for (final t in follows) FollowedItem(target: t, label: t.label)],
  );

  @override
  Future<void> setFollow(FollowTarget target, {required bool follow}) async {
    await _write();
    follows.remove(target);
    if (follow) follows.add(target);
    _followChanges.add(null);
  }

  @override
  Future<int> followerCount(FollowTarget target) async =>
      follows.contains(target) ? 1 : 0;

  @override
  Stream<List<SavedEntity>> watchSavedEntities(String uid) =>
      Stream.value(const []);

  @override
  Future<List<Map<String, Object?>>> savedItems(String uid) async =>
      saved.values.toList();

  @override
  Future<void> setSaved({
    required String kind,
    required String id,
    required String title,
    String? image,
    String? url,
    Object? data,
    required bool saved,
  }) async {
    await _write();
    if (saved) {
      this.saved['${kind}_$id'] = {
        'kind': kind,
        'id': id,
        'title': title,
        'image': image,
        'url': url,
        'data': data,
      };
    } else {
      this.saved.remove('${kind}_$id');
    }
  }

  @override
  Future<int> importSaved(List<Map<String, Object?>> items) async {
    await _write();
    for (final i in items) {
      saved['${i['kind']}_${i['id']}'] = i;
    }
    return items.length;
  }

  // Polls

  @override
  Future<List<Poll>> activePolls({int limit = 10}) async =>
      polls.where((p) => p.kind == PollKind.poll && p.isOpen).toList();

  @override
  Future<Poll?> questionOfTheDay() async => polls
      .where((p) => p.kind == PollKind.questionOfTheDay && p.isOpen)
      .firstOrNull;

  @override
  Future<List<Poll>> pastPolls({int limit = 20}) async =>
      polls.where((p) => !p.isOpen).toList();

  @override
  Stream<Poll?> watchPoll(String pollId) =>
      Stream.value(polls.where((p) => p.id == pollId).firstOrNull);

  @override
  Future<String?> myVote(String pollId) async => votes[pollId];

  @override
  Future<Poll> vote(Poll poll, String optionId) async {
    await _write();
    final current = polls.firstWhere((p) => p.id == poll.id);
    final before = votes[poll.id];
    if (before != null && !current.allowChange) {
      throw const CommunityException(
        CommunityErrorKind.alreadyExists,
        message: 'You already voted.',
      );
    }
    votes[poll.id] = optionId;
    final next = current.withVote(from: before, to: optionId);
    polls[polls.indexOf(current)] = next;
    return next;
  }

  // Notifications

  @override
  Future<CursorPage<AppNotification>> notifications(
    String uid, {
    Object? cursor,
    int limit = 20,
  }) async {
    await _read();
    final start = cursor as int? ?? 0;
    final items = notificationsList.skip(start).take(limit).toList();
    return CursorPage(
      items,
      cursor: start + items.length,
      hasMore: start + items.length < notificationsList.length,
    );
  }

  @override
  Stream<int> watchUnreadCount(String uid) =>
      Stream.value(notificationsList.where((n) => !n.read).length);

  @override
  Future<void> markRead(String uid, String notificationId) async {}

  @override
  Future<void> markAllRead() => _write();

  // Submissions

  @override
  Future<String> uploadSubmissionImage(
    Uint8List bytes,
    String contentType,
  ) async {
    await _write();
    return 'submissions/$_uid/image.jpg';
  }

  static const received =
      'Your submission has been received and is awaiting editorial review.';

  Future<String> _submit(String kind, Map<String, Object?> fields) async {
    await _write();
    _uid;
    submissions.add((kind, fields));
    return received;
  }

  @override
  Future<String> submitStory(Map<String, Object?> fields) =>
      _submit('story', fields);

  @override
  Future<String> submitStartup(Map<String, Object?> fields) =>
      _submit('startup', fields);

  @override
  Future<String> claimStartup(Map<String, Object?> fields) =>
      _submit('claim', fields);

  @override
  Future<List<Submission>> mySubmissions(String uid) async => [
    for (final (i, (kind, f)) in submissions.indexed)
      Submission(
        id: 's$i',
        kind: switch (kind) {
          'story' => SubmissionKind.story,
          'startup' => SubmissionKind.startup,
          _ => SubmissionKind.claim,
        },
        title: '${f['title'] ?? f['name'] ?? f['startupName']}',
        status: SubmissionStatus.submitted,
      ),
  ];
}

/// A signed-in, verified person with a profile.
AuthUser verifiedUser([String uid = 'u1']) =>
    AuthUser(uid: uid, email: '$uid@example.com', emailVerified: true);

/// Provider overrides that switch community features on with fakes.
List communityOverrides({
  required FakeAuth auth,
  required FakeCommunity api,
  Set<Feature>? features,
}) => [
  authRepositoryProvider.overrideWithValue(auth),
  communityApiProvider.overrideWithValue(api),
  featureFlagSourceProvider.overrideWithValue(
    FixedFeatureFlagSource({
      'features': {
        for (final f in features ?? Feature.values.toSet()) f.key: true,
      },
    }),
  ),
];
