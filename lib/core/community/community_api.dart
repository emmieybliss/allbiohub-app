import 'dart:typed_data';

import 'community_exception.dart';
import 'models.dart';

/// Sign-in. Implemented with Firebase Authentication
/// ([FirebaseAuthRepository]); the app never handles passwords itself
/// beyond passing them to the provider.
abstract class AuthRepository {
  bool get isAvailable;

  /// Whether "Continue with Google" is set up in this build.
  bool get supportsGoogle;

  AuthUser? get currentUser;

  /// Emits on sign-in, sign-out and after [reload].
  Stream<AuthUser?> authStateChanges();

  Future<AuthUser> signInWithEmail(String email, String password);

  /// Creates the account and sends the verification email.
  Future<AuthUser> registerWithEmail(String email, String password);

  /// Returns null when the person closed the Google sign-in sheet.
  Future<AuthUser?> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  Future<void> sendEmailVerification();

  /// Refreshes the user (after verifying the email elsewhere) and their
  /// token (after being made an admin).
  Future<AuthUser?> reload();

  /// Confirms the person's identity just before a sensitive action such as
  /// deleting the account. [password] is used for email accounts.
  Future<void> reauthenticate({String? password});

  Future<void> signOut();
}

/// Everything the community features read and write. Reads come straight
/// from the database (allowed by its security rules); every write is a
/// server function that checks and validates it (COMMUNITY.md → API).
abstract class CommunityApi {
  bool get isAvailable;

  // Profile ---------------------------------------------------------------

  Stream<UserProfile?> watchProfile(String uid);

  Stream<AccountSettings?> watchAccount(String uid);

  /// Null when the profile is private or doesn't exist.
  Future<UserProfile?> profile(String uid);

  Future<({bool available, String? message})> checkUsername(String username);

  Future<void> createProfile({
    required String username,
    required String displayName,
  });

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    ProfileVisibility? visibility,
    bool? showActivity,
  });

  /// Uploads a profile picture (JPEG/PNG/WebP, ≤ 5 MB) and sets it.
  Future<void> setProfilePhoto(Uint8List bytes, String contentType);

  Future<void> removeProfilePhoto();

  Future<void> changeUsername(String username);

  Future<void> updateNotificationPrefs(
    Map<CommunityNotificationPref, bool> prefs,
  );

  Future<void> registerDevice(String token);

  Future<void> unregisterDevice(String token);

  Future<void> deleteAccount();

  Future<void> claimAdmin();

  // Reactions -------------------------------------------------------------

  Stream<ArticleEngagement> watchEngagement(int articleId);

  Future<ReactionType?> myReaction(int articleId);

  Future<ArticleEngagement> setReaction(int articleId, ReactionType? reaction);

  // Comments --------------------------------------------------------------

  /// Approved top-level comments, pinned first, then newest.
  Future<CursorPage<Comment>> comments(
    int articleId, {
    Object? cursor,
    int limit = 20,
  });

  /// Approved replies under a top-level comment, oldest first.
  Future<CursorPage<Comment>> replies(
    String rootId, {
    Object? cursor,
    int limit = 30,
  });

  /// The person's own comments, newest first, including pending ones.
  Future<CursorPage<Comment>> commentsBy(
    String uid, {
    Object? cursor,
    int limit = 20,
  });

  Future<Set<String>> likedComments(Iterable<String> commentIds);

  /// Returns the stored comment (status `pending` when held for review).
  Future<Comment> addComment(int articleId, String body, {String? parentId});

  Future<Comment> editComment(String commentId, String body);

  Future<void> deleteComment(String commentId);

  Future<int> likeComment(String commentId, {required bool like});

  Future<void> report({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String details = '',
  });

  // Safety ----------------------------------------------------------------

  Stream<Set<String>> watchBlocked(String uid);

  Future<void> setBlocked(String otherUid, {required bool blocked});

  Future<void> setMuted(String otherUid, {required bool muted});

  // Follows and saved items -----------------------------------------------

  Stream<List<FollowedItem>> watchFollows(String uid);

  Future<void> setFollow(FollowTarget target, {required bool follow});

  Future<int> followerCount(FollowTarget target);

  Stream<List<SavedEntity>> watchSavedEntities(String uid);

  /// Everything saved to the account: kind, id, title, image, url, data
  /// (a JSON copy for articles) and savedAt.
  Future<List<Map<String, Object?>>> savedItems(String uid);

  Future<void> setSaved({
    required String kind,
    required String id,
    required String title,
    String? image,
    String? url,
    Object? data,
    required bool saved,
  });

  Future<int> importSaved(List<Map<String, Object?>> items);

  // Polls -----------------------------------------------------------------

  Future<List<Poll>> activePolls({int limit = 10});

  Future<Poll?> questionOfTheDay();

  Future<List<Poll>> pastPolls({int limit = 20});

  Stream<Poll?> watchPoll(String pollId);

  Future<String?> myVote(String pollId);

  Future<Poll> vote(Poll poll, String optionId);

  // Notifications ---------------------------------------------------------

  Future<CursorPage<AppNotification>> notifications(
    String uid, {
    Object? cursor,
    int limit = 20,
  });

  Stream<int> watchUnreadCount(String uid);

  Future<void> markRead(String uid, String notificationId);

  Future<void> markAllRead();

  // Submissions -----------------------------------------------------------

  /// Uploads an image for a submission; returns its storage path.
  Future<String> uploadSubmissionImage(Uint8List bytes, String contentType);

  Future<String> submitStory(Map<String, Object?> fields);

  Future<String> submitStartup(Map<String, Object?> fields);

  Future<String> claimStartup(Map<String, Object?> fields);

  Future<List<Submission>> mySubmissions(String uid);
}

/// Used when the build has no Firebase settings: nothing is available and
/// every action explains that instead of pretending to work.
class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  static const _error = CommunityException(CommunityErrorKind.unavailable);

  @override
  bool get isAvailable => false;

  @override
  bool get supportsGoogle => false;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AuthUser> signInWithEmail(String email, String password) =>
      Future.error(_error);

  @override
  Future<AuthUser> registerWithEmail(String email, String password) =>
      Future.error(_error);

  @override
  Future<AuthUser?> signInWithGoogle() => Future.error(_error);

  @override
  Future<void> sendPasswordReset(String email) => Future.error(_error);

  @override
  Future<void> sendEmailVerification() => Future.error(_error);

  @override
  Future<AuthUser?> reload() async => null;

  @override
  Future<void> reauthenticate({String? password}) => Future.error(_error);

  @override
  Future<void> signOut() async {}
}
