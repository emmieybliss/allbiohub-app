import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'community_api.dart';
import 'community_exception.dart';
import 'feature_flags.dart';
import 'models.dart';

/// Converts Firestore values (Timestamps) into plain Dart values.
Map<String, dynamic> plainMap(Map<String, dynamic> data) => {
  for (final e in data.entries) e.key: _plain(e.value),
};

Object? _plain(Object? value) => switch (value) {
  final Timestamp t => t.toDate(),
  final Map<String, dynamic> m => plainMap(m),
  final Map m => plainMap(Map<String, dynamic>.from(m)),
  final List l => l.map(_plain).toList(),
  _ => value,
};

/// Turns a function or Firestore error into a [CommunityException] with a
/// message people can read.
CommunityException communityError(Object error) {
  if (error is CommunityException) return error;
  if (error is FirebaseFunctionsException) {
    final details = error.details is Map ? error.details as Map : const {};
    final reason = details['reason'];
    final field = details['field'] as String?;
    final message = error.message;
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' => const CommunityException(
        CommunityErrorKind.offline,
      ),
      'unauthenticated' => const CommunityException(
        CommunityErrorKind.signInRequired,
      ),
      'resource-exhausted' => CommunityException(
        CommunityErrorKind.rateLimited,
        message: message,
      ),
      'failed-precondition' when reason == 'email_unverified' =>
        const CommunityException(CommunityErrorKind.emailUnverified),
      'failed-precondition' when reason == 'profile_missing' =>
        const CommunityException(CommunityErrorKind.profileRequired),
      'permission-denied' when reason == 'banned' || reason == 'suspended' =>
        CommunityException(CommunityErrorKind.restricted, message: message),
      'permission-denied' => CommunityException(
        CommunityErrorKind.forbidden,
        message: message,
      ),
      'invalid-argument' || 'failed-precondition' => CommunityException(
        CommunityErrorKind.invalid,
        message: message,
        field: field,
      ),
      'not-found' => CommunityException(
        CommunityErrorKind.notFound,
        message: message,
      ),
      'already-exists' => CommunityException(
        CommunityErrorKind.alreadyExists,
        message: message,
        field: field,
      ),
      _ when '$message'.toLowerCase().contains('network') =>
        const CommunityException(CommunityErrorKind.offline),
      _ => const CommunityException(CommunityErrorKind.unknown),
    };
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'network-request-failed' => const CommunityException(
        CommunityErrorKind.offline,
      ),
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-login-credentials' => const CommunityException(
        CommunityErrorKind.invalid,
        message: 'That email and password don\'t match an account.',
      ),
      'email-already-in-use' => const CommunityException(
        CommunityErrorKind.alreadyExists,
        message: 'An account already uses that email. Try signing in.',
        field: 'email',
      ),
      'invalid-email' => const CommunityException(
        CommunityErrorKind.invalid,
        message: 'Enter a valid email address.',
        field: 'email',
      ),
      'weak-password' => const CommunityException(
        CommunityErrorKind.invalid,
        message: 'Use a password with at least 8 characters.',
        field: 'password',
      ),
      'too-many-requests' => const CommunityException(
        CommunityErrorKind.rateLimited,
        message: 'Too many attempts. Wait a few minutes and try again.',
      ),
      'user-disabled' => const CommunityException(
        CommunityErrorKind.restricted,
        message: 'This account has been disabled.',
      ),
      'requires-recent-login' => const CommunityException(
        CommunityErrorKind.invalid,
        message: 'Sign in again to continue.',
      ),
      'account-exists-with-different-credential' => const CommunityException(
        CommunityErrorKind.alreadyExists,
        message:
            'This email already has an account with a password. Sign in with '
            'your email and password.',
      ),
      'operation-not-allowed' => const CommunityException(
        CommunityErrorKind.unavailable,
        message: 'This way of signing in isn\'t switched on yet.',
      ),
      _ => const CommunityException(CommunityErrorKind.unknown),
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' => const CommunityException(CommunityErrorKind.offline),
      'permission-denied' => const CommunityException(
        CommunityErrorKind.forbidden,
      ),
      'not-found' => const CommunityException(CommunityErrorKind.notFound),
      _ => const CommunityException(CommunityErrorKind.unknown),
    };
  }
  return const CommunityException(CommunityErrorKind.unknown);
}

/// Feature switches from the public `config/app` document.
class FirestoreFeatureFlagSource implements FeatureFlagSource {
  FirestoreFeatureFlagSource([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<Map<String, dynamic>?> fetch() async {
    try {
      final snap = await _db
          .doc('config/app')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      return snap.data();
    } on Object catch (e) {
      debugPrint('Feature switches not loaded: $e');
      return null;
    }
  }
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({required this.googleServerClientId, FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// OAuth "Web client" id from the Firebase project (GOOGLE_WEB_CLIENT_ID).
  /// Empty disables Google sign-in.
  final String googleServerClientId;
  bool _googleReady = false;

  @override
  bool get isAvailable => true;

  @override
  bool get supportsGoogle => googleServerClientId.isNotEmpty;

  AuthUser? _cached;

  @override
  AuthUser? get currentUser => _cached ?? _toUser(_auth.currentUser, false);

  AuthUser? _toUser(User? user, bool admin) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          emailVerified: user.emailVerified,
          isAdmin: admin,
          providers: [for (final p in user.providerData) p.providerId],
        );

  Future<AuthUser?> _withClaims(User? user) async {
    if (user == null) return _cached = null;
    var admin = false;
    try {
      final token = await user.getIdTokenResult();
      admin = token.claims?['admin'] == true;
    } on Object {
      // Offline: claims are refreshed on the next token change.
    }
    return _cached = _toUser(user, admin);
  }

  final _reloads = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield await _withClaims(_auth.currentUser);
    yield* StreamGroupLite.merge([
      _auth.userChanges().asyncMap(_withClaims),
      _reloads.stream,
    ]);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw communityError(e);
    }
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) =>
      _guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return (await _withClaims(cred.user))!;
      });

  @override
  Future<AuthUser> registerWithEmail(String email, String password) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user?.sendEmailVerification();
        return (await _withClaims(cred.user))!;
      });

  Future<void> _initGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(serverClientId: googleServerClientId);
    _googleReady = true;
  }

  @override
  Future<AuthUser?> signInWithGoogle() => _guard(() async {
    if (!supportsGoogle) {
      throw const CommunityException(
        CommunityErrorKind.unavailable,
        message: 'Google sign-in isn\'t set up in this version yet.',
      );
    }
    await _initGoogle();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    final cred = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return _withClaims(cred.user);
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    await _auth.currentUser?.sendEmailVerification();
  });

  @override
  Future<AuthUser?> reload() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    await user.getIdToken(true);
    final fresh = await _withClaims(_auth.currentUser);
    _reloads.add(fresh);
    return fresh;
  });

  @override
  Future<void> reauthenticate({String? password}) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CommunityException(CommunityErrorKind.signInRequired);
    }
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('password') && password != null) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } else if (providers.contains('google.com')) {
      await _initGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
    } else {
      throw const CommunityException(
        CommunityErrorKind.invalid,
        message: 'Enter your password to continue.',
        field: 'password',
      );
    }
  });

  @override
  Future<void> signOut() => _guard(() async {
    await _auth.signOut();
    if (_googleReady) await GoogleSignIn.instance.signOut();
  });
}

/// Merges streams without another package.
abstract final class StreamGroupLite {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late StreamController<T> controller;
    final subs = <StreamSubscription<T>>[];
    controller = StreamController<T>(
      onListen: () {
        for (final s in streams) {
          subs.add(s.listen(controller.add, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }
}

class FirebaseCommunityApi implements CommunityApi {
  FirebaseCommunityApi({
    required String functionsRegion,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _db = db ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion),
       _storageOverride = storage,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage? _storageOverride;
  final FirebaseAuth _auth;

  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  @override
  bool get isAvailable => true;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const CommunityException(CommunityErrorKind.signInRequired);
    }
    return uid;
  }

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    try {
      final result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<Object?>(data);
      final value = result.data;
      return value is Map ? plainMap(Map<String, dynamic>.from(value)) : {};
    } on Object catch (e) {
      throw communityError(e);
    }
  }

  Future<T> _read<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw communityError(e);
    }
  }

  // Profile ---------------------------------------------------------------

  @override
  Stream<UserProfile?> watchProfile(String uid) => _db
      .doc('profiles/$uid')
      .snapshots()
      .map(
        (s) => s.exists ? UserProfile.fromJson(uid, plainMap(s.data()!)) : null,
      )
      .handleError((Object _) {}, test: (e) => e is FirebaseException);

  @override
  Stream<AccountSettings?> watchAccount(String uid) => _db
      .doc('users/$uid')
      .snapshots()
      .map((s) => s.exists ? AccountSettings.fromJson(plainMap(s.data()!)) : null)
      .handleError((Object _) {}, test: (e) => e is FirebaseException);

  @override
  Future<UserProfile?> profile(String uid) async {
    try {
      final s = await _db.doc('profiles/$uid').get();
      return s.exists ? UserProfile.fromJson(uid, plainMap(s.data()!)) : null;
    } on FirebaseException catch (e) {
      // Private profiles can't be read by others.
      if (e.code == 'permission-denied') return null;
      throw communityError(e);
    }
  }

  @override
  Future<({bool available, String? message})> checkUsername(
    String username,
  ) async {
    final r = await _call('checkUsername', {'username': username});
    return (
      available: r['available'] == true,
      message: r['message'] as String?,
    );
  }

  @override
  Future<void> createProfile({
    required String username,
    required String displayName,
  }) => _call('createProfile', {
    'username': username,
    'displayName': displayName,
  });

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    ProfileVisibility? visibility,
    bool? showActivity,
  }) => _call('updateProfile', {
    'displayName': ?displayName,
    'bio': ?bio,
    'visibility': ?visibility?.name,
    'showActivity': ?showActivity,
  });

  static String _extension(String contentType) => switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };

  Future<String> _upload(String folder, Uint8List bytes, String type) =>
      _read(() async {
        final path =
            '$folder/$_uid/${DateTime.now().millisecondsSinceEpoch}.${_extension(type)}';
        await _storage
            .ref(path)
            .putData(bytes, SettableMetadata(contentType: type));
        return path;
      });

  @override
  Future<void> setProfilePhoto(Uint8List bytes, String contentType) async {
    final path = await _upload('avatars', bytes, contentType);
    await _call('updateProfile', {'photoPath': path});
  }

  @override
  Future<void> removeProfilePhoto() =>
      _call('updateProfile', {'photoPath': null});

  @override
  Future<void> changeUsername(String username) =>
      _call('changeUsername', {'username': username});

  @override
  Future<void> updateNotificationPrefs(
    Map<CommunityNotificationPref, bool> prefs,
  ) => _call('updateNotificationPrefs', {
    'prefs': {for (final e in prefs.entries) e.key.key: e.value},
  });

  @override
  Future<void> registerDevice(String token) =>
      _call('registerDevice', {'token': token, 'platform': 'android'});

  @override
  Future<void> unregisterDevice(String token) =>
      _call('unregisterDevice', {'token': token});

  @override
  Future<void> deleteAccount() => _call('deleteAccount', {'confirm': 'DELETE'});

  @override
  Future<void> claimAdmin() => _call('claimAdmin');

  // Reactions -------------------------------------------------------------

  @override
  Stream<ArticleEngagement> watchEngagement(int articleId) => _db
      .doc('articles/$articleId')
      .snapshots()
      .map(
        (s) => s.exists
            ? ArticleEngagement.fromJson(plainMap(s.data()!))
            : ArticleEngagement.empty,
      );

  @override
  Future<ReactionType?> myReaction(int articleId) => _read(() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final s = await _db.doc('articles/$articleId/reactions/$uid').get();
    return ReactionType.fromKey(s.data()?['reaction']);
  });

  @override
  Future<ArticleEngagement> setReaction(
    int articleId,
    ReactionType? reaction,
  ) async {
    final r = await _call('setReaction', {
      'articleId': articleId,
      'reaction': reaction?.key,
    });
    final current = await _db.doc('articles/$articleId').get();
    return ArticleEngagement.fromJson({
      ...plainMap(current.data() ?? const {}),
      'reactions': r['counts'],
    });
  }

  // Comments --------------------------------------------------------------

  Future<CursorPage<Comment>> _page(
    Query<Map<String, dynamic>> query,
    Object? cursor,
    int limit,
  ) => _read(() async {
    var q = query.limit(limit);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return CursorPage(
      [for (final d in snap.docs) Comment.fromJson(d.id, plainMap(d.data()))],
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  });

  @override
  Future<CursorPage<Comment>> comments(
    int articleId, {
    Object? cursor,
    int limit = 20,
  }) => _page(
    _db
        .collection('comments')
        .where('articleId', isEqualTo: articleId)
        .where('parentId', isNull: true)
        .where('status', isEqualTo: 'approved')
        .orderBy('pinned', descending: true)
        .orderBy('createdAt', descending: true),
    cursor,
    limit,
  );

  @override
  Future<CursorPage<Comment>> replies(
    String rootId, {
    Object? cursor,
    int limit = 30,
  }) => _page(
    _db
        .collection('comments')
        .where('rootId', isEqualTo: rootId)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt'),
    cursor,
    limit,
  );

  @override
  Future<CursorPage<Comment>> commentsBy(
    String uid, {
    Object? cursor,
    int limit = 20,
  }) => _page(
    _db
        .collection('comments')
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true),
    cursor,
    limit,
  );

  @override
  Future<Set<String>> likedComments(Iterable<String> commentIds) =>
      _read(() async {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return <String>{};
        final ids = commentIds.toList();
        final snaps = await Future.wait([
          for (final id in ids) _db.doc('comments/$id/likes/$uid').get(),
        ]);
        return {
          for (var i = 0; i < ids.length; i++)
            if (snaps[i].exists) ids[i],
        };
      });

  @override
  Future<Comment> addComment(
    int articleId,
    String body, {
    String? parentId,
  }) async {
    final r = await _call('addComment', {
      'articleId': articleId,
      'body': body,
      'parentId': ?parentId,
    });
    return Comment.fromJson('${r['id']}', r);
  }

  @override
  Future<Comment> editComment(String commentId, String body) async {
    final r = await _call('editComment', {
      'commentId': commentId,
      'body': body,
    });
    return Comment.fromJson('${r['id']}', r);
  }

  @override
  Future<void> deleteComment(String commentId) =>
      _call('deleteComment', {'commentId': commentId});

  @override
  Future<int> likeComment(String commentId, {required bool like}) async {
    final r = await _call('likeComment', {'commentId': commentId, 'like': like});
    return (r['likeCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String details = '',
  }) => _call('reportContent', {
    'targetType': targetType,
    'targetId': targetId,
    'reason': reason.key,
    'details': details,
  });

  // Safety ----------------------------------------------------------------

  @override
  Stream<Set<String>> watchBlocked(String uid) => _db
      .collection('users/$uid/blocks')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id})
      .handleError((Object _) {}, test: (e) => e is FirebaseException);

  @override
  Future<void> setBlocked(String otherUid, {required bool blocked}) =>
      _call('blockUser', {'uid': otherUid, 'block': blocked});

  @override
  Future<void> setMuted(String otherUid, {required bool muted}) =>
      _call('muteUser', {'uid': otherUid, 'mute': muted});

  // Follows and saved items -----------------------------------------------

  @override
  Stream<List<FollowedItem>> watchFollows(String uid) => _db
      .collection('users/$uid/follows')
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) FollowedItem.fromJson(plainMap(d.data()))],
      )
      .handleError((Object _) {}, test: (e) => e is FirebaseException);

  @override
  Future<void> setFollow(FollowTarget target, {required bool follow}) =>
      _call('setFollow', {
        'kind': target.kind.key,
        'id': target.id,
        'label': target.label,
        'follow': follow,
      });

  @override
  Future<int> followerCount(FollowTarget target) => _read(() async {
    final s = await _db.doc('followTargets/${target.key}').get();
    return (s.data()?['followerCount'] as num?)?.toInt() ?? 0;
  });

  @override
  Stream<List<SavedEntity>> watchSavedEntities(String uid) => _db
      .collection('users/$uid/saved')
      .where('kind', whereIn: ['startup', 'founder'])
      .limit(500)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            SavedEntity(
              kind: d.data()['kind'] == 'founder'
                  ? SavedKind.founder
                  : SavedKind.startup,
              id: '${d.data()['targetId']}',
              title: '${d.data()['title']}',
              image: d.data()['image'] as String?,
              url: d.data()['url'] as String?,
              savedAt: (d.data()['savedAt'] as Timestamp?)?.toDate(),
            ),
        ],
      )
      .handleError((Object _) {}, test: (e) => e is FirebaseException);

  @override
  Future<List<Map<String, Object?>>> savedItems(String uid) => _read(() async {
    final s = await _db
        .collection('users/$uid/saved')
        .orderBy('savedAt', descending: true)
        .limit(1000)
        .get();
    return [
      for (final d in s.docs)
        {...plainMap(d.data()), 'id': d.data()['targetId']},
    ];
  });

  @override
  Future<void> setSaved({
    required String kind,
    required String id,
    required String title,
    String? image,
    String? url,
    Object? data,
    required bool saved,
  }) => _call('setSaved', {
    'kind': kind,
    'id': id,
    'title': title,
    'image': image,
    'url': url,
    'data': ?data,
    'saved': saved,
  });

  @override
  Future<int> importSaved(List<Map<String, Object?>> items) async {
    var imported = 0;
    for (var i = 0; i < items.length; i += 200) {
      final r = await _call('importSaved', {
        'items': items.sublist(i, (i + 200).clamp(0, items.length)),
      });
      imported += (r['imported'] as num?)?.toInt() ?? 0;
    }
    return imported;
  }

  // Polls -----------------------------------------------------------------

  Future<List<Poll>> _polls(Query<Map<String, dynamic>> q) => _read(() async {
    final s = await q.get();
    return [for (final d in s.docs) Poll.fromJson(d.id, plainMap(d.data()))];
  });

  @override
  Future<List<Poll>> activePolls({int limit = 10}) => _polls(
    _db
        .collection('polls')
        .where('kind', isEqualTo: 'poll')
        .where('status', isEqualTo: 'active')
        .orderBy('publishAt', descending: true)
        .limit(limit),
  );

  @override
  Future<Poll?> questionOfTheDay() async {
    final list = await _polls(
      _db
          .collection('polls')
          .where('kind', isEqualTo: 'qotd')
          .where('status', isEqualTo: 'active')
          .orderBy('publishAt', descending: true)
          .limit(1),
    );
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<List<Poll>> pastPolls({int limit = 20}) => _polls(
    _db
        .collection('polls')
        .where('kind', isEqualTo: 'poll')
        .where('status', isEqualTo: 'closed')
        .orderBy('publishAt', descending: true)
        .limit(limit),
  );

  @override
  Stream<Poll?> watchPoll(String pollId) => _db
      .doc('polls/$pollId')
      .snapshots()
      .map((s) => s.exists ? Poll.fromJson(s.id, plainMap(s.data()!)) : null)
      .handleError((Object _) {}, test: (e) => e is FirebaseException);

  @override
  Future<String?> myVote(String pollId) => _read(() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final s = await _db.doc('polls/$pollId/votes/$uid').get();
    return s.data()?['optionId'] as String?;
  });

  @override
  Future<Poll> vote(Poll poll, String optionId) async {
    final r = await _call('votePoll', {'pollId': poll.id, 'optionId': optionId});
    return Poll.fromJson(poll.id, {
      'kind': poll.kind == PollKind.questionOfTheDay ? 'qotd' : 'poll',
      'question': poll.question,
      'options': [
        for (final o in poll.options) {'id': o.id, 'label': o.label},
      ],
      'status': poll.status.name,
      'counts': r['counts'],
      'totalVotes': r['totalVotes'],
      'allowChange': poll.allowChange,
      'publishAt': poll.publishAt,
      'expiresAt': poll.expiresAt,
      'articleId': poll.articleId,
    });
  }

  // Notifications ---------------------------------------------------------

  @override
  Future<CursorPage<AppNotification>> notifications(
    String uid, {
    Object? cursor,
    int limit = 20,
  }) => _read(() async {
    var q = _db
        .collection('users/$uid/notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return CursorPage(
      [
        for (final d in snap.docs)
          AppNotification.fromJson(d.id, plainMap(d.data())),
      ],
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  });

  @override
  Stream<int> watchUnreadCount(String uid) => _db
      .collection('users/$uid/notifications')
      .where('read', isEqualTo: false)
      .limit(100)
      .snapshots()
      .map((s) => s.size)
      .handleError((Object _) {}, test: (e) => e is FirebaseException);

  @override
  Future<void> markRead(String uid, String notificationId) => _read(
    () => _db
        .doc('users/$uid/notifications/$notificationId')
        .update({'read': true}),
  );

  @override
  Future<void> markAllRead() => _call('markAllNotificationsRead');

  // Submissions -----------------------------------------------------------

  @override
  Future<String> uploadSubmissionImage(Uint8List bytes, String contentType) =>
      _upload('submissions', bytes, contentType);

  @override
  Future<String> submitStory(Map<String, Object?> fields) async =>
      '${(await _call('submitStory', fields))['message']}';

  @override
  Future<String> submitStartup(Map<String, Object?> fields) async =>
      '${(await _call('submitStartup', fields))['message']}';

  @override
  Future<String> claimStartup(Map<String, Object?> fields) async =>
      '${(await _call('claimStartup', fields))['message']}';

  @override
  Future<List<Submission>> mySubmissions(String uid) => _read(() async {
    Future<List<Submission>> load(
      String collection,
      SubmissionKind kind,
      String Function(Map<String, dynamic>) title,
    ) async {
      final s = await _db
          .collection(collection)
          .where('submitterUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return [
        for (final d in s.docs)
          Submission(
            id: d.id,
            kind: kind,
            title: title(d.data()),
            status: SubmissionStatus.fromKey(d.data()['status']),
            editorNote: d.data()['editorNote'] as String?,
            createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
          ),
      ];
    }

    final all = await Future.wait([
      load('storySubmissions', SubmissionKind.story, (d) => '${d['title']}'),
      load('startupSubmissions', SubmissionKind.startup, (d) => '${d['name']}'),
      load('startupClaims', SubmissionKind.claim, (d) => '${d['startupName']}'),
    ]);
    return all.expand((l) => l).toList()..sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
  });
}
