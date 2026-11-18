/**
 * Community data: accounts, profiles, reactions, comments, follows, polls,
 * notifications and submissions. Mirrors the documents written by the Cloud
 * Functions in firebase/functions (COMMUNITY.md, "Data model"). Dates are
 * JavaScript Dates; Firestore Timestamps are converted in firebase.ts.
 */

// Feature switches -----------------------------------------------------------

/** Field names under `features` in the Firestore document config/app. */
export const FEATURES = [
  'accounts',
  'communityProfiles',
  'reactions',
  'comments',
  'startupFollows',
  'founderFollows',
  'topicFollows',
  'savedSync',
  'polls',
  'questionOfTheDay',
  'notificationCenter',
  'storySubmissions',
  'startupSubmissions',
  'startupClaims',
  'forYou',
  'aiAssistant',
] as const;

export type Feature = (typeof FEATURES)[number];

/** Features that only make sense with an account. */
export function needsAccount(feature: Feature): boolean {
  return feature !== 'accounts' && feature !== 'forYou' && feature !== 'aiAssistant';
}

/** The switches that are on, from the config/app document. Anything else is off. */
export function flagsFromConfig(json: unknown): Feature[] {
  const features = (json as { features?: unknown } | null)?.features;
  if (!features || typeof features !== 'object') return [];
  return FEATURES.filter((f) => (features as Record<string, unknown>)[f] === true);
}

/** A feature that needs an account is off while accounts are off. */
export function isOn(on: readonly Feature[], feature: Feature): boolean {
  if (!on.includes(feature)) return false;
  return !needsAccount(feature) || on.includes('accounts');
}

// Accounts and profiles ------------------------------------------------------

/** The signed-in person, from Firebase Authentication. */
export type AuthUser = {
  uid: string;
  /** Private. Shown only to the person themselves, never on a profile. */
  email?: string;
  displayName?: string;
  photoUrl?: string;
  emailVerified: boolean;
  isAdmin: boolean;
  /** Sign-in methods, e.g. `password`, `google.com`. */
  providers: string[];
};

export function usesPassword(user: AuthUser): boolean {
  return user.providers.includes('password');
}

export type ProfileVisibility = 'public' | 'private';

/** A person's public profile (profiles/{uid}). */
export type UserProfile = {
  uid: string;
  username: string;
  displayName: string;
  bio: string;
  photoUrl?: string;
  joinedAt?: Date;
  followingCount: number;
  commentCount: number;
  visibility: ProfileVisibility;
  showActivity: boolean;
  badges: string[];
};

type Json = Record<string, unknown>;

const str = (v: unknown, fallback = '') => (v === undefined || v === null ? fallback : String(v));
const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const optStr = (v: unknown) => (typeof v === 'string' && v ? v : undefined);

export function toDate(value: unknown): Date | undefined {
  if (value instanceof Date) return value;
  if (typeof value === 'string' || typeof value === 'number') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? undefined : d;
  }
  return undefined;
}

export function mapProfile(uid: string, json: Json): UserProfile {
  return {
    uid,
    username: str(json.username),
    displayName: str(json.displayName),
    bio: str(json.bio),
    photoUrl: optStr(json.photoUrl),
    joinedAt: toDate(json.joinedAt),
    followingCount: num(json.followingCount),
    commentCount: num(json.commentCount),
    visibility: json.visibility === 'private' ? 'private' : 'public',
    showActivity: json.showActivity !== false,
    badges: Array.isArray(json.badges) ? json.badges.map(String) : [],
  };
}

/**
 * Push and notification-centre preferences that live on the account. Story
 * topics (Breaking, Technology, ...) stay device topics in the preferences store.
 */
export const COMMUNITY_NOTIFICATION_PREFS = [
  { key: 'commentActivity', label: 'Comment activity', description: 'Replies to and likes on your comments' },
  { key: 'topicAlerts', label: 'Followed topics', description: 'New stories in topics you follow' },
  { key: 'startupAlerts', label: 'Startup alerts', description: 'News and updates about startups you follow' },
  { key: 'founderAlerts', label: 'Founder alerts', description: 'New stories about founders you follow' },
  { key: 'submissionUpdates', label: 'Your submissions', description: 'Status of stories and startups you send' },
  { key: 'community', label: 'Community', description: 'Community news from AllBioHub' },
  { key: 'marketing', label: 'Promotions', description: 'Occasional offers and announcements' },
] as const;

export type CommunityNotificationPref = (typeof COMMUNITY_NOTIFICATION_PREFS)[number]['key'];

export type AccountStatus = 'active' | 'suspended' | 'banned';

/** Private account settings (users/{uid}), visible only to the owner. */
export type AccountSettings = {
  status: AccountStatus;
  suspendedUntil?: Date;
  notificationPrefs: Partial<Record<CommunityNotificationPref, boolean>>;
  usernameChangedAt?: Date;
};

export function mapAccount(json: Json): AccountSettings {
  const prefs = (json.notificationPrefs ?? {}) as Json;
  const notificationPrefs: AccountSettings['notificationPrefs'] = {};
  for (const { key } of COMMUNITY_NOTIFICATION_PREFS) {
    if (typeof prefs[key] === 'boolean') notificationPrefs[key] = prefs[key] as boolean;
  }
  return {
    status: json.status === 'suspended' ? 'suspended' : json.status === 'banned' ? 'banned' : 'active',
    suspendedUntil: toDate(json.suspendedUntil),
    notificationPrefs,
    usernameChangedAt: toDate(json.usernameChangedAt),
  };
}

export function wants(account: AccountSettings | null | undefined, pref: CommunityNotificationPref): boolean {
  return account?.notificationPrefs[pref] ?? pref !== 'marketing';
}

/** When the username can next be changed (30 days after the last change). */
export function nextUsernameChange(account: AccountSettings | null | undefined): Date | undefined {
  const at = account?.usernameChangedAt;
  return at ? new Date(at.getTime() + 30 * 24 * 3600 * 1000) : undefined;
}

export function isRestricted(account: AccountSettings | null | undefined, now = new Date()): boolean {
  if (!account) return false;
  if (account.status === 'banned') return true;
  return account.status === 'suspended' && (!account.suspendedUntil || account.suspendedUntil > now);
}

/** The same rules the server applies (firebase/functions/src/validation.ts); the server decides. */
export function normalizeUsername(raw: string): string {
  return raw.trim().replace(/^@/, '').toLowerCase();
}

export function usernameRule(raw: string): string | null {
  const name = normalizeUsername(raw);
  if (name.length < 3) return 'Use at least 3 characters.';
  if (name.length > 20) return 'Use at most 20 characters.';
  if (!/^[a-z0-9_]+$/.test(name)) return 'Use only letters, numbers and underscores.';
  if (!/^[a-z]/.test(name)) return 'Start with a letter.';
  if (name.includes('__')) return 'Don’t use two underscores in a row.';
  return null;
}

// Reactions --------------------------------------------------------------------

export const REACTIONS = [
  { key: 'love', emoji: '❤️', label: 'Love' },
  { key: 'interesting', emoji: '🔥', label: 'Interesting' },
  { key: 'wow', emoji: '🤯', label: 'Wow' },
  { key: 'informative', emoji: '💡', label: 'Informative' },
] as const;

export type ReactionType = (typeof REACTIONS)[number]['key'];

export function reactionFromKey(key: unknown): ReactionType | null {
  return REACTIONS.find((r) => r.key === key)?.key ?? null;
}

/** Aggregate engagement for one article (articles/{id}). Counts are what the server recorded. */
export type ArticleEngagement = {
  reactions: Partial<Record<ReactionType, number>>;
  commentCount: number;
};

export const EMPTY_ENGAGEMENT: ArticleEngagement = { reactions: {}, commentCount: 0 };

export function mapEngagement(json: Json): ArticleEngagement {
  const r = (json.reactions ?? {}) as Json;
  const reactions: ArticleEngagement['reactions'] = {};
  for (const { key } of REACTIONS) {
    const n = num(r[key]);
    if (n > 0) reactions[key] = n;
  }
  return { reactions, commentCount: num(json.commentCount) };
}

/** Counts after the person's reaction changes from [from] to [to]. */
export function withReactionChange(e: ArticleEngagement, from: ReactionType | null, to: ReactionType | null): ArticleEngagement {
  const next = { ...e.reactions };
  if (from) next[from] = (next[from] ?? 1) - 1;
  if (to) next[to] = (next[to] ?? 0) + 1;
  for (const k of Object.keys(next) as ReactionType[]) if ((next[k] ?? 0) <= 0) delete next[k];
  return { reactions: next, commentCount: e.commentCount };
}

// Comments -----------------------------------------------------------------------

export type ModerationStatus = 'pending' | 'approved' | 'rejected' | 'removed';

export type CommentAuthor = { uid: string; username: string; displayName: string; photoUrl?: string };

export type Comment = {
  id: string;
  articleId: number;
  parentId?: string;
  rootId?: string;
  /** 0 for a comment, 1 for a reply, 2 for a reply to a reply (the limit). */
  depth: number;
  author: CommentAuthor;
  /** Who a deepest-level reply answers, shown as "@name". */
  replyToUsername?: string;
  body: string;
  status: ModerationStatus;
  /** Deleted by its author but kept as a placeholder because it has replies. */
  deleted: boolean;
  likeCount: number;
  replyCount: number;
  pinned: boolean;
  createdAt: Date;
  editedAt?: Date;
};

export function mapComment(id: string, json: Json): Comment {
  const author = (json.author ?? {}) as Json;
  const replyTo = json.replyTo as Json | null | undefined;
  const status = json.status;
  return {
    id,
    articleId: num(json.articleId),
    parentId: optStr(json.parentId),
    rootId: optStr(json.rootId),
    depth: num(json.depth),
    author: { uid: str(author.uid), username: str(author.username), displayName: str(author.displayName), photoUrl: optStr(author.photoUrl) },
    replyToUsername: replyTo ? str(replyTo.username) : undefined,
    body: str(json.body),
    status: status === 'pending' || status === 'rejected' || status === 'removed' ? status : 'approved',
    deleted: json.deleted === true,
    likeCount: num(json.likeCount),
    replyCount: num(json.replyCount),
    pinned: json.pinned === true,
    createdAt: toDate(json.createdAt) ?? new Date(),
    editedAt: toDate(json.editedAt),
  };
}

export const REPORT_REASONS = [
  { key: 'spam', label: 'Spam' },
  { key: 'harassment', label: 'Harassment' },
  { key: 'hate', label: 'Hate or abuse' },
  { key: 'misinformation', label: 'Misinformation' },
  { key: 'advertising', label: 'Advertising' },
  { key: 'other', label: 'Something else' },
] as const;

export type ReportReason = (typeof REPORT_REASONS)[number]['key'];

// Follows and saved items ----------------------------------------------------------

export type FollowKind = 'startup' | 'founder' | 'topic';

/** Something that can be followed: a startup (slug), a topic (category slug) or a founder (slug of their name). */
export type FollowTarget = {
  kind: FollowKind;
  id: string;
  /** Display name. The server replaces it with the name from allbiohub.com. */
  label: string;
};

export const followKey = (t: Pick<FollowTarget, 'kind' | 'id'>) => `${t.kind}_${t.id}`;

/** The switch that controls following each kind of thing. */
export function followFeature(kind: FollowKind): Feature {
  return kind === 'startup' ? 'startupFollows' : kind === 'founder' ? 'founderFollows' : 'topicFollows';
}

/** One of the person's follows (users/{uid}/follows). */
export type FollowedItem = { target: FollowTarget; image?: string; createdAt?: Date };

export function mapFollow(json: Json): FollowedItem {
  const kind: FollowKind = json.kind === 'startup' || json.kind === 'founder' ? json.kind : 'topic';
  const id = str(json.targetId);
  return { target: { kind, id, label: str(json.label, id) || id }, image: optStr(json.image), createdAt: toDate(json.createdAt) };
}

export type SavedKind = 'startup' | 'founder';

/** A saved startup or founder (stories keep their own store). */
export type SavedEntity = {
  kind: SavedKind;
  /** Startup slug or founder slug. */
  id: string;
  title: string;
  subtitle?: string;
  image?: string;
  url?: string;
  /** ISO date. */
  savedAt?: string;
};

export const savedKey = (e: Pick<SavedEntity, 'kind' | 'id'>) => `${e.kind}_${e.id}`;

const ACCENTS: Record<string, string> = {
  a: 'àáâãäåāăąạ', c: 'çćč', d: 'ďđ', e: 'èéêëēėęěẹ', i: 'ìíîïīįị', n: 'ñńňṅ',
  o: 'òóôõöøōọ', r: 'ŕř', s: 'śšşṣ', t: 'ťţ', u: 'ùúûüūůűụ', y: 'ýÿ', z: 'źżž',
};

/**
 * "Tosin Eniolorunda" -> "tosin-eniolorunda", the id of a founder page and
 * follow. Must stay identical to slugify in firebase/functions/src/validation.ts,
 * which checks it.
 */
export function slugify(input: string): string {
  let s = input.toLowerCase().replace(/[̀-ͯ]/g, '').replace(/ß/g, 'ss');
  for (const [plain, accented] of Object.entries(ACCENTS)) s = s.replace(new RegExp(`[${accented}]`, 'g'), plain);
  return s.replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80);
}

/** "ada-obi" -> "Ada Obi", when nothing better is known. */
export function titleFromSlug(slug: string): string {
  return slug
    .split('-')
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(' ');
}

// Polls ---------------------------------------------------------------------------------

export type PollKind = 'poll' | 'qotd';
export type PollStatus = 'draft' | 'scheduled' | 'active' | 'closed';
export type PollOption = { id: string; label: string };

/** An editorial poll or Question of the Day (polls/{id}). Only totals are public. */
export type Poll = {
  id: string;
  kind: PollKind;
  question: string;
  options: PollOption[];
  status: PollStatus;
  counts: Record<string, number>;
  totalVotes: number;
  allowChange: boolean;
  publishAt?: Date;
  expiresAt?: Date;
  articleId?: number;
};

export function mapPoll(id: string, json: Json): Poll {
  const counts: Record<string, number> = {};
  for (const [k, v] of Object.entries((json.counts ?? {}) as Json)) if (typeof v === 'number') counts[k] = Math.trunc(v);
  const status = json.status;
  return {
    id,
    kind: json.kind === 'qotd' ? 'qotd' : 'poll',
    question: str(json.question),
    options: Array.isArray(json.options) ? json.options.map((o) => ({ id: str((o as Json).id), label: str((o as Json).label) })) : [],
    status: status === 'active' || status === 'scheduled' || status === 'draft' ? status : 'closed',
    counts,
    totalVotes: num(json.totalVotes),
    allowChange: json.allowChange === true,
    publishAt: toDate(json.publishAt),
    expiresAt: toDate(json.expiresAt),
    articleId: typeof json.articleId === 'number' ? json.articleId : undefined,
  };
}

export function pollIsOpen(poll: Poll, now = new Date()): boolean {
  return poll.status === 'active' && (!poll.expiresAt || poll.expiresAt > now);
}

/** Whole-number percentages that add up to 100 (largest remainder). */
export function pollPercentages(poll: Poll): Record<string, number> {
  const result: Record<string, number> = {};
  if (poll.totalVotes <= 0) {
    for (const o of poll.options) result[o.id] = 0;
    return result;
  }
  const exact: Record<string, number> = {};
  for (const o of poll.options) {
    exact[o.id] = ((poll.counts[o.id] ?? 0) * 100) / poll.totalVotes;
    result[o.id] = Math.floor(exact[o.id]);
  }
  let left = 100 - Object.values(result).reduce((a, b) => a + b, 0);
  const byRemainder = Object.keys(exact).sort((a, b) => exact[b] - result[b] - (exact[a] - result[a]));
  for (const id of byRemainder) {
    if (left <= 0) break;
    if (!poll.counts[id]) continue;
    result[id] += 1;
    left -= 1;
  }
  return result;
}

export function pollWithVote(poll: Poll, from: string | null, to: string): Poll {
  const counts = { ...poll.counts };
  if (from) counts[from] = Math.max(0, (counts[from] ?? 1) - 1);
  counts[to] = (counts[to] ?? 0) + 1;
  return { ...poll, counts, totalVotes: from ? poll.totalVotes : poll.totalVotes + 1 };
}

// Notifications -------------------------------------------------------------------------

export type NotificationKind =
  | 'comment_reply'
  | 'comment_like'
  | 'startup_story'
  | 'founder_story'
  | 'topic_story'
  | 'submission_update'
  | 'claim_update'
  | 'other';

const NOTIFICATION_KINDS: NotificationKind[] = [
  'comment_reply',
  'comment_like',
  'startup_story',
  'founder_story',
  'topic_story',
  'submission_update',
  'claim_update',
];

/** An entry in the notification centre (users/{uid}/notifications). */
export type AppNotification = {
  id: string;
  kind: NotificationKind;
  title: string;
  body: string;
  /** allbiohub.com link or an app path such as /me/submissions. */
  url: string;
  read: boolean;
  createdAt: Date;
};

export function mapNotification(id: string, json: Json): AppNotification {
  const type = json.type as NotificationKind;
  return {
    id,
    kind: NOTIFICATION_KINDS.includes(type) ? type : 'other',
    title: str(json.title),
    body: str(json.body),
    url: str(json.url),
    read: json.read === true,
    createdAt: toDate(json.createdAt) ?? new Date(),
  };
}

// Submissions -----------------------------------------------------------------------------

export type SubmissionKind = 'story' | 'startup' | 'claim';

export const SUBMISSION_STATUS_LABELS = {
  submitted: 'Submitted',
  under_review: 'Under review',
  accepted: 'Accepted',
  rejected: 'Not accepted',
  published: 'Published',
  pending: 'Pending',
  approved: 'Approved',
} as const;

export type SubmissionStatus = keyof typeof SUBMISSION_STATUS_LABELS;

export function submissionStatus(key: unknown): SubmissionStatus {
  return typeof key === 'string' && key in SUBMISSION_STATUS_LABELS ? (key as SubmissionStatus) : 'submitted';
}

/** One of the person's own submissions or claims. */
export type Submission = {
  id: string;
  kind: SubmissionKind;
  title: string;
  status: SubmissionStatus;
  /** Message from the editors, shown to the sender. */
  editorNote?: string;
  createdAt?: Date;
};

export const STORY_TYPES = [
  { key: 'news_tip', label: 'News tip' },
  { key: 'startup_news', label: 'Startup news' },
  { key: 'funding', label: 'Funding announcement' },
  { key: 'product_launch', label: 'Product launch' },
  { key: 'founder_news', label: 'Founder announcement' },
  { key: 'event', label: 'Event' },
  { key: 'press_release', label: 'Press release' },
] as const;

export type StoryType = (typeof STORY_TYPES)[number]['key'];

export const SUBMISSION_RECEIVED = 'Your submission has been received and is awaiting editorial review.';

/** A page of results from a cursor-paginated collection. The cursor is opaque. */
export type CursorPage<T> = { items: T[]; cursor?: unknown; hasMore: boolean };
