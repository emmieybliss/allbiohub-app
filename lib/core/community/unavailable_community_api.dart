import 'dart:typed_data';

import 'community_api.dart';
import 'community_exception.dart';
import 'models.dart';

/// Used when the build has no Firebase settings. Feature switches are all
/// off in that case, so nothing should call this; if something does, it
/// gets an honest "not available" instead of a fake success.
class UnavailableCommunityApi implements CommunityApi {
  const UnavailableCommunityApi();

  static Future<T> _no<T>() =>
      Future.error(const CommunityException(CommunityErrorKind.unavailable));

  @override
  bool get isAvailable => false;

  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.value(null);

  @override
  Stream<AccountSettings?> watchAccount(String uid) => Stream.value(null);

  @override
  Future<UserProfile?> profile(String uid) async => null;

  @override
  Future<({bool available, String? message})> checkUsername(String u) => _no();

  @override
  Future<void> createProfile({
    required String username,
    required String displayName,
  }) => _no();

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    ProfileVisibility? visibility,
    bool? showActivity,
  }) => _no();

  @override
  Future<void> setProfilePhoto(Uint8List bytes, String contentType) => _no();

  @override
  Future<void> removeProfilePhoto() => _no();

  @override
  Future<void> changeUsername(String username) => _no();

  @override
  Future<void> updateNotificationPrefs(
    Map<CommunityNotificationPref, bool> prefs,
  ) => _no();

  @override
  Future<void> registerDevice(String token) async {}

  @override
  Future<void> unregisterDevice(String token) async {}

  @override
  Future<void> deleteAccount() => _no();

  @override
  Future<void> claimAdmin() => _no();

  @override
  Stream<ArticleEngagement> watchEngagement(int articleId) =>
      Stream.value(ArticleEngagement.empty);

  @override
  Future<ReactionType?> myReaction(int articleId) async => null;

  @override
  Future<ArticleEngagement> setReaction(int articleId, ReactionType? r) =>
      _no();

  @override
  Future<CursorPage<Comment>> comments(
    int articleId, {
    Object? cursor,
    int limit = 20,
  }) => _no();

  @override
  Future<CursorPage<Comment>> replies(
    String rootId, {
    Object? cursor,
    int limit = 30,
  }) => _no();

  @override
  Future<CursorPage<Comment>> commentsBy(
    String uid, {
    Object? cursor,
    int limit = 20,
  }) => _no();

  @override
  Future<Set<String>> likedComments(Iterable<String> commentIds) async => {};

  @override
  Future<Comment> addComment(int articleId, String body, {String? parentId}) =>
      _no();

  @override
  Future<Comment> editComment(String commentId, String body) => _no();

  @override
  Future<void> deleteComment(String commentId) => _no();

  @override
  Future<int> likeComment(String commentId, {required bool like}) => _no();

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String details = '',
  }) => _no();

  @override
  Stream<Set<String>> watchBlocked(String uid) => Stream.value(const {});

  @override
  Future<void> setBlocked(String otherUid, {required bool blocked}) => _no();

  @override
  Future<void> setMuted(String otherUid, {required bool muted}) => _no();

  @override
  Stream<List<FollowedItem>> watchFollows(String uid) => Stream.value(const []);

  @override
  Future<void> setFollow(FollowTarget target, {required bool follow}) => _no();

  @override
  Future<int> followerCount(FollowTarget target) async => 0;

  @override
  Stream<List<SavedEntity>> watchSavedEntities(String uid) =>
      Stream.value(const []);

  @override
  Future<List<Map<String, Object?>>> savedItems(String uid) async => const [];

  @override
  Future<void> setSaved({
    required String kind,
    required String id,
    required String title,
    String? image,
    String? url,
    Object? data,
    required bool saved,
  }) => _no();

  @override
  Future<int> importSaved(List<Map<String, Object?>> items) => _no();

  @override
  Future<List<Poll>> activePolls({int limit = 10}) async => const [];

  @override
  Future<Poll?> questionOfTheDay() async => null;

  @override
  Future<List<Poll>> pastPolls({int limit = 20}) async => const [];

  @override
  Stream<Poll?> watchPoll(String pollId) => Stream.value(null);

  @override
  Future<String?> myVote(String pollId) async => null;

  @override
  Future<Poll> vote(Poll poll, String optionId) => _no();

  @override
  Future<CursorPage<AppNotification>> notifications(
    String uid, {
    Object? cursor,
    int limit = 20,
  }) async => const CursorPage([], hasMore: false);

  @override
  Stream<int> watchUnreadCount(String uid) => Stream.value(0);

  @override
  Future<void> markRead(String uid, String notificationId) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<String> uploadSubmissionImage(Uint8List bytes, String contentType) =>
      _no();

  @override
  Future<String> submitStory(Map<String, Object?> fields) => _no();

  @override
  Future<String> submitStartup(Map<String, Object?> fields) => _no();

  @override
  Future<String> claimStartup(Map<String, Object?> fields) => _no();

  @override
  Future<List<Submission>> mySubmissions(String uid) async => const [];
}
