/// Community data: accounts, profiles, reactions, comments, follows, polls,
/// notifications and submissions. Mirrors the documents written by the
/// Cloud Functions in `firebase/functions` (COMMUNITY.md → Data model).
library;

/// The signed-in person, from the authentication provider.
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.isAdmin = false,
    this.providers = const [],
  });

  final String uid;

  /// Private. Shown only to the person themselves, never on a profile.
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final bool isAdmin;

  /// Sign-in methods, e.g. `password`, `google.com`.
  final List<String> providers;

  bool get usesPassword => providers.contains('password');
}

enum ProfileVisibility { public, private }

/// A person's public profile (`profiles/{uid}`).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.photoUrl,
    this.joinedAt,
    this.followingCount = 0,
    this.commentCount = 0,
    this.visibility = ProfileVisibility.public,
    this.showActivity = true,
    this.badges = const [],
  });

  factory UserProfile.fromJson(String uid, Map<String, dynamic> json) =>
      UserProfile(
        uid: uid,
        username: '${json['username'] ?? ''}',
        displayName: '${json['displayName'] ?? ''}',
        bio: '${json['bio'] ?? ''}',
        photoUrl: json['photoUrl'] as String?,
        joinedAt: json['joinedAt'] as DateTime?,
        followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        visibility: json['visibility'] == 'private'
            ? ProfileVisibility.private
            : ProfileVisibility.public,
        showActivity: json['showActivity'] != false,
        badges: [for (final b in json['badges'] as List? ?? const []) '$b'],
      );

  final String uid;
  final String username;
  final String displayName;
  final String bio;
  final String? photoUrl;
  final DateTime? joinedAt;
  final int followingCount;
  final int commentCount;
  final ProfileVisibility visibility;
  final bool showActivity;
  final List<String> badges;

  bool get isPrivate => visibility == ProfileVisibility.private;
}

/// Push and notification-centre preferences that live on the account.
/// Story topics (Breaking, Technology, …) stay device topics in
/// [NotificationTopic].
enum CommunityNotificationPref {
  commentActivity('commentActivity', 'Comment activity', 'Replies to and likes on your comments'),
  topicAlerts('topicAlerts', 'Followed topics', 'New stories in topics you follow'),
  startupAlerts('startupAlerts', 'Startup alerts', 'News and updates about startups you follow'),
  founderAlerts('founderAlerts', 'Founder alerts', 'New stories about founders you follow'),
  submissionUpdates('submissionUpdates', 'Your submissions', 'Status of stories and startups you send'),
  community('community', 'Community', 'Community news from AllBioHub'),
  marketing('marketing', 'Promotions', 'Occasional offers and announcements');

  const CommunityNotificationPref(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  bool get defaultValue => this != marketing;
}

enum AccountStatus { active, suspended, banned }

/// Private account settings (`users/{uid}`), visible only to the owner.
class AccountSettings {
  const AccountSettings({
    this.status = AccountStatus.active,
    this.suspendedUntil,
    this.notificationPrefs = const {},
    this.usernameChangedAt,
  });

  factory AccountSettings.fromJson(Map<String, dynamic> json) {
    final prefs = json['notificationPrefs'] as Map? ?? const {};
    return AccountSettings(
      status: switch (json['status']) {
        'suspended' => AccountStatus.suspended,
        'banned' => AccountStatus.banned,
        _ => AccountStatus.active,
      },
      suspendedUntil: json['suspendedUntil'] as DateTime?,
      notificationPrefs: {
        for (final p in CommunityNotificationPref.values)
          if (prefs[p.key] is bool) p: prefs[p.key] as bool,
      },
      usernameChangedAt: json['usernameChangedAt'] as DateTime?,
    );
  }

  final AccountStatus status;
  final DateTime? suspendedUntil;
  final Map<CommunityNotificationPref, bool> notificationPrefs;
  final DateTime? usernameChangedAt;

  bool wants(CommunityNotificationPref pref) =>
      notificationPrefs[pref] ?? pref.defaultValue;

  /// When the username can next be changed (30 days after the last change).
  DateTime? get nextUsernameChange =>
      usernameChangedAt?.add(const Duration(days: 30));

  bool get isRestricted =>
      status == AccountStatus.banned ||
      (status == AccountStatus.suspended &&
          (suspendedUntil == null || suspendedUntil!.isAfter(DateTime.now())));
}

enum ReactionType {
  love('love', '❤️', 'Love'),
  interesting('interesting', '🔥', 'Interesting'),
  wow('wow', '🤯', 'Wow'),
  informative('informative', '💡', 'Informative');

  const ReactionType(this.key, this.emoji, this.label);

  final String key;
  final String emoji;
  final String label;

  static ReactionType? fromKey(Object? key) {
    for (final r in values) {
      if (r.key == key) return r;
    }
    return null;
  }
}

/// Aggregate engagement for one article (`articles/{id}`). Counts are what
/// the server recorded; nothing is estimated.
class ArticleEngagement {
  const ArticleEngagement({this.reactions = const {}, this.commentCount = 0});

  factory ArticleEngagement.fromJson(Map<String, dynamic> json) {
    final r = json['reactions'] as Map? ?? const {};
    return ArticleEngagement(
      reactions: {
        for (final t in ReactionType.values)
          if (r[t.key] is num && (r[t.key] as num) > 0)
            t: (r[t.key] as num).toInt(),
      },
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = ArticleEngagement();

  final Map<ReactionType, int> reactions;
  final int commentCount;

  int countOf(ReactionType type) => reactions[type] ?? 0;

  int get reactionTotal => reactions.values.fold(0, (a, b) => a + b);

  /// Counts after the person's reaction changes from [from] to [to].
  ArticleEngagement withReactionChange(ReactionType? from, ReactionType? to) {
    final next = {...reactions};
    if (from != null) next[from] = (next[from] ?? 1) - 1;
    if (to != null) next[to] = (next[to] ?? 0) + 1;
    next.removeWhere((_, v) => v <= 0);
    return ArticleEngagement(reactions: next, commentCount: commentCount);
  }
}

enum ModerationStatus { pending, approved, rejected, removed }

/// The author fields copied onto each comment.
class CommentAuthor {
  const CommentAuthor({
    required this.uid,
    required this.username,
    required this.displayName,
    this.photoUrl,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) => CommentAuthor(
    uid: '${json['uid'] ?? ''}',
    username: '${json['username'] ?? ''}',
    displayName: '${json['displayName'] ?? ''}',
    photoUrl: json['photoUrl'] as String?,
  );

  final String uid;
  final String username;
  final String displayName;
  final String? photoUrl;
}

class Comment {
  const Comment({
    required this.id,
    required this.articleId,
    required this.author,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.rootId,
    this.depth = 0,
    this.replyToUsername,
    this.status = ModerationStatus.approved,
    this.deleted = false,
    this.likeCount = 0,
    this.replyCount = 0,
    this.pinned = false,
    this.editedAt,
  });

  factory Comment.fromJson(String id, Map<String, dynamic> json) {
    final replyTo = json['replyTo'] as Map?;
    return Comment(
      id: id,
      articleId: (json['articleId'] as num).toInt(),
      parentId: json['parentId'] as String?,
      rootId: json['rootId'] as String?,
      depth: (json['depth'] as num?)?.toInt() ?? 0,
      author: CommentAuthor.fromJson(
        Map<String, dynamic>.from(json['author'] as Map? ?? const {}),
      ),
      replyToUsername: replyTo == null ? null : '${replyTo['username']}',
      body: '${json['body'] ?? ''}',
      status: switch (json['status']) {
        'pending' => ModerationStatus.pending,
        'rejected' => ModerationStatus.rejected,
        'removed' => ModerationStatus.removed,
        _ => ModerationStatus.approved,
      },
      deleted: json['deleted'] == true,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      pinned: json['pinned'] == true,
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      editedAt: _date(json['editedAt']),
    );
  }

  final String id;
  final int articleId;
  final String? parentId;
  final String? rootId;

  /// 0 for a comment, 1 for a reply, 2 for a reply to a reply (the limit).
  final int depth;
  final CommentAuthor author;

  /// Who a deepest-level reply answers, shown as "@name".
  final String? replyToUsername;
  final String body;
  final ModerationStatus status;

  /// Deleted by its author but kept as a placeholder because it has replies.
  final bool deleted;
  final int likeCount;
  final int replyCount;
  final bool pinned;
  final DateTime createdAt;
  final DateTime? editedAt;

  bool get isPending => status == ModerationStatus.pending;

  Comment copyWith({String? body, int? likeCount, int? replyCount}) => Comment(
    id: id,
    articleId: articleId,
    parentId: parentId,
    rootId: rootId,
    depth: depth,
    author: author,
    replyToUsername: replyToUsername,
    body: body ?? this.body,
    status: status,
    deleted: deleted,
    likeCount: likeCount ?? this.likeCount,
    replyCount: replyCount ?? this.replyCount,
    pinned: pinned,
    createdAt: createdAt,
    editedAt: editedAt,
  );
}

DateTime? _date(Object? value) => switch (value) {
  final DateTime d => d,
  final String s => DateTime.tryParse(s),
  _ => null,
};

enum ReportReason {
  spam('spam', 'Spam'),
  harassment('harassment', 'Harassment'),
  hate('hate', 'Hate or abuse'),
  misinformation('misinformation', 'Misinformation'),
  advertising('advertising', 'Advertising'),
  other('other', 'Something else');

  const ReportReason(this.key, this.label);

  final String key;
  final String label;
}

enum FollowKind {
  startup('startup'),
  founder('founder'),
  topic('topic');

  const FollowKind(this.key);

  final String key;

  static FollowKind? fromKey(Object? key) {
    for (final k in values) {
      if (k.key == key) return k;
    }
    return null;
  }
}

/// Something that can be followed: a startup (by slug), a topic (category
/// slug) or a founder (slug of their name).
class FollowTarget {
  const FollowTarget(this.kind, this.id, {this.label = ''});

  final FollowKind kind;
  final String id;

  /// Display name. The server replaces it with the name from allbiohub.com.
  final String label;

  String get key => '${kind.key}_$id';

  @override
  bool operator ==(Object other) =>
      other is FollowTarget && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// One of the person's follows (`users/{uid}/follows`).
class FollowedItem {
  const FollowedItem({
    required this.target,
    required this.label,
    this.image,
    this.createdAt,
  });

  factory FollowedItem.fromJson(Map<String, dynamic> json) {
    final kind = FollowKind.fromKey(json['kind']) ?? FollowKind.topic;
    final id = '${json['targetId']}';
    final label = '${json['label'] ?? id}';
    return FollowedItem(
      target: FollowTarget(kind, id, label: label),
      label: label,
      image: json['image'] as String?,
      createdAt: _date(json['createdAt']),
    );
  }

  final FollowTarget target;
  final String label;
  final String? image;
  final DateTime? createdAt;
}

enum PollKind { poll, questionOfTheDay }

enum PollStatus { draft, scheduled, active, closed }

class PollOption {
  const PollOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// An editorial poll or Question of the Day (`polls/{id}`). Only totals are
/// public; who voted for what never leaves the server.
class Poll {
  const Poll({
    required this.id,
    required this.kind,
    required this.question,
    required this.options,
    required this.status,
    this.counts = const {},
    this.totalVotes = 0,
    this.allowChange = false,
    this.publishAt,
    this.expiresAt,
    this.articleId,
  });

  factory Poll.fromJson(String id, Map<String, dynamic> json) {
    final counts = json['counts'] as Map? ?? const {};
    return Poll(
      id: id,
      kind: json['kind'] == 'qotd' ? PollKind.questionOfTheDay : PollKind.poll,
      question: '${json['question'] ?? ''}',
      options: [
        for (final o in json['options'] as List? ?? const [])
          PollOption(id: '${(o as Map)['id']}', label: '${o['label']}'),
      ],
      status: switch (json['status']) {
        'active' => PollStatus.active,
        'scheduled' => PollStatus.scheduled,
        'draft' => PollStatus.draft,
        _ => PollStatus.closed,
      },
      counts: {
        for (final e in counts.entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      },
      totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
      allowChange: json['allowChange'] == true,
      publishAt: _date(json['publishAt']),
      expiresAt: _date(json['expiresAt']),
      articleId: (json['articleId'] as num?)?.toInt(),
    );
  }

  final String id;
  final PollKind kind;
  final String question;
  final List<PollOption> options;
  final PollStatus status;
  final Map<String, int> counts;
  final int totalVotes;
  final bool allowChange;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final int? articleId;

  bool get isOpen =>
      status == PollStatus.active &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  int votesFor(String optionId) => counts[optionId] ?? 0;

  /// Whole-number percentages that add up to 100 (largest remainder).
  Map<String, int> get percentages {
    if (totalVotes <= 0) return {for (final o in options) o.id: 0};
    final exact = {
      for (final o in options) o.id: votesFor(o.id) * 100 / totalVotes,
    };
    final result = {for (final e in exact.entries) e.key: e.value.floor()};
    var left = 100 - result.values.fold(0, (a, b) => a + b);
    final byRemainder = exact.keys.toList()
      ..sort(
        (a, b) => (exact[b]! - result[b]!).compareTo(exact[a]! - result[a]!),
      );
    for (final id in byRemainder) {
      if (left <= 0) break;
      if (votesFor(id) == 0) continue;
      result[id] = result[id]! + 1;
      left--;
    }
    return result;
  }

  Poll withVote({String? from, required String to}) {
    final next = {...counts};
    if (from != null) next[from] = ((next[from] ?? 1) - 1).clamp(0, 1 << 30);
    next[to] = (next[to] ?? 0) + 1;
    return Poll(
      id: id,
      kind: kind,
      question: question,
      options: options,
      status: status,
      counts: next,
      totalVotes: from == null ? totalVotes + 1 : totalVotes,
      allowChange: allowChange,
      publishAt: publishAt,
      expiresAt: expiresAt,
      articleId: articleId,
    );
  }
}

enum NotificationKind {
  commentReply,
  commentLike,
  startupStory,
  founderStory,
  topicStory,
  submissionUpdate,
  claimUpdate,
  other,
}

/// An entry in the notification centre (`users/{uid}/notifications`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.url,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(String id, Map<String, dynamic> json) =>
      AppNotification(
        id: id,
        kind: switch (json['type']) {
          'comment_reply' => NotificationKind.commentReply,
          'comment_like' => NotificationKind.commentLike,
          'startup_story' => NotificationKind.startupStory,
          'founder_story' => NotificationKind.founderStory,
          'topic_story' => NotificationKind.topicStory,
          'submission_update' => NotificationKind.submissionUpdate,
          'claim_update' => NotificationKind.claimUpdate,
          _ => NotificationKind.other,
        },
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        url: '${json['url'] ?? ''}',
        read: json['read'] == true,
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
      );

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// allbiohub.com link or an app path such as `/me/submissions`.
  final String url;
  final bool read;
  final DateTime createdAt;
}

enum SubmissionKind { story, startup, claim }

enum SubmissionStatus {
  submitted('Submitted'),
  underReview('Under review'),
  accepted('Accepted'),
  rejected('Not accepted'),
  published('Published'),
  pending('Pending'),
  approved('Approved');

  const SubmissionStatus(this.label);

  final String label;

  static SubmissionStatus fromKey(Object? key) => switch (key) {
    'under_review' => underReview,
    'accepted' => accepted,
    'rejected' => rejected,
    'published' => published,
    'pending' => pending,
    'approved' => approved,
    _ => submitted,
  };
}

/// One of the person's own submissions or claims.
class Submission {
  const Submission({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    this.editorNote,
    this.createdAt,
  });

  final String id;
  final SubmissionKind kind;
  final String title;
  final SubmissionStatus status;

  /// Message from the editors, shown to the sender.
  final String? editorNote;
  final DateTime? createdAt;
}

/// Types of story submission.
enum StoryType {
  newsTip('news_tip', 'News tip'),
  startupNews('startup_news', 'Startup news'),
  funding('funding', 'Funding announcement'),
  productLaunch('product_launch', 'Product launch'),
  founderNews('founder_news', 'Founder announcement'),
  event('event', 'Event'),
  pressRelease('press_release', 'Press release');

  const StoryType(this.key, this.label);

  final String key;
  final String label;
}

/// A page of results from a cursor-paginated collection.
class CursorPage<T> {
  const CursorPage(this.items, {this.cursor, required this.hasMore});

  final List<T> items;

  /// Opaque position to continue from.
  final Object? cursor;
  final bool hasMore;
}

/// A saved startup or founder (articles keep their own store).
class SavedEntity {
  const SavedEntity({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.image,
    this.url,
    this.savedAt,
  });

  factory SavedEntity.fromJson(Map<String, dynamic> json) => SavedEntity(
    kind: json['kind'] == 'founder' ? SavedKind.founder : SavedKind.startup,
    id: '${json['id']}',
    title: '${json['title']}',
    subtitle: json['subtitle'] as String?,
    image: json['image'] as String?,
    url: json['url'] as String?,
    savedAt: _date(json['savedAt']),
  );

  final SavedKind kind;

  /// Startup slug or founder slug.
  final String id;
  final String title;
  final String? subtitle;
  final String? image;
  final String? url;
  final DateTime? savedAt;

  String get key => '${kind.name}_$id';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'image': image,
    'url': url,
    'savedAt': (savedAt ?? DateTime.now()).toIso8601String(),
  };
}

enum SavedKind { startup, founder }
