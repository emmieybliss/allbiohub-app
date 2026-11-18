import { CommunityError } from './errors';
import type {
  AccountSettings,
  AppNotification,
  ArticleEngagement,
  AuthUser,
  Comment,
  CommunityNotificationPref,
  CursorPage,
  FollowedItem,
  FollowTarget,
  Poll,
  ProfileVisibility,
  ReactionType,
  ReportReason,
  SavedEntity,
  Submission,
  UserProfile,
} from './models';

export type Unsubscribe = () => void;

/** Sign-in, through Firebase Authentication. The app never stores passwords. */
export interface AuthRepository {
  readonly isAvailable: boolean;
  /** Whether "Continue with Google" is set up in this build. */
  readonly supportsGoogle: boolean;
  /** Calls [listener] now and on sign-in, sign-out and after reload(). */
  onUser(listener: (user: AuthUser | null) => void): Unsubscribe;
  signInWithEmail(email: string, password: string): Promise<AuthUser>;
  /** Creates the account and sends the verification email. */
  registerWithEmail(email: string, password: string): Promise<AuthUser>;
  /** Null when the person closed the Google sheet. */
  signInWithGoogle(): Promise<AuthUser | null>;
  sendPasswordReset(email: string): Promise<void>;
  sendEmailVerification(): Promise<void>;
  /** Refreshes the user (after verifying the email) and their token (after being made an editor). */
  reload(): Promise<AuthUser | null>;
  /** Confirms the person's identity before deleting the account. */
  reauthenticate(password?: string): Promise<void>;
  signOut(): Promise<void>;
}

/**
 * Everything the community features read and write. Reads come straight from
 * Firestore (allowed by its security rules); every write is a Cloud Function
 * that checks and validates it (COMMUNITY.md, "Server API").
 */
export interface CommunityApi {
  readonly isAvailable: boolean;

  /** The config/app document, or null when it can't be read. */
  fetchConfig(): Promise<unknown>;

  // Profile
  watchProfile(uid: string, cb: (p: UserProfile | null) => void): Unsubscribe;
  watchAccount(uid: string, cb: (a: AccountSettings | null) => void): Unsubscribe;
  /** Null when the profile is private or doesn't exist. */
  profile(uid: string): Promise<UserProfile | null>;
  checkUsername(username: string): Promise<{ available: boolean; message?: string }>;
  createProfile(username: string, displayName: string): Promise<void>;
  updateProfile(changes: { displayName?: string; bio?: string; visibility?: ProfileVisibility; showActivity?: boolean }): Promise<void>;
  /** Uploads a local image file (JPEG/PNG/WebP, at most 5 MB) and sets it as the profile picture. */
  setProfilePhoto(fileUri: string, contentType: string): Promise<void>;
  removeProfilePhoto(): Promise<void>;
  changeUsername(username: string): Promise<void>;
  updateNotificationPrefs(prefs: Partial<Record<CommunityNotificationPref, boolean>>): Promise<void>;
  registerDevice(token: string): Promise<void>;
  unregisterDevice(token: string): Promise<void>;
  deleteAccount(): Promise<void>;
  claimAdmin(): Promise<void>;

  // Reactions
  watchEngagement(articleId: number, cb: (e: ArticleEngagement) => void): Unsubscribe;
  myReaction(articleId: number): Promise<ReactionType | null>;
  /** Returns the server's new counts. */
  setReaction(articleId: number, reaction: ReactionType | null): Promise<ArticleEngagement>;

  // Comments
  /** Approved top-level comments, pinned first, then newest. */
  comments(articleId: number, cursor?: unknown, limit?: number): Promise<CursorPage<Comment>>;
  /** Approved replies under a top-level comment, oldest first. */
  replies(rootId: string, cursor?: unknown, limit?: number): Promise<CursorPage<Comment>>;
  /** The person's own comments, newest first, including pending ones. */
  commentsBy(uid: string, cursor?: unknown, limit?: number): Promise<CursorPage<Comment>>;
  likedComments(ids: string[]): Promise<Set<string>>;
  /** Returns the stored comment (status `pending` when held for review). */
  addComment(articleId: number, body: string, parentId?: string): Promise<Comment>;
  editComment(commentId: string, body: string): Promise<Comment>;
  deleteComment(commentId: string): Promise<void>;
  /** Returns the new like count. */
  likeComment(commentId: string, like: boolean): Promise<number>;
  report(targetType: 'comment' | 'user', targetId: string, reason: ReportReason, details?: string): Promise<void>;

  // Safety
  watchBlocked(uid: string, cb: (ids: Set<string>) => void): Unsubscribe;
  setBlocked(otherUid: string, blocked: boolean): Promise<void>;
  setMuted(otherUid: string, muted: boolean): Promise<void>;

  // Follows and saved items
  watchFollows(uid: string, cb: (items: FollowedItem[]) => void): Unsubscribe;
  setFollow(target: FollowTarget, follow: boolean): Promise<void>;
  followerCount(target: FollowTarget): Promise<number>;
  /** Everything saved to the account: kind, id, title, image, url, data (JSON text for stories) and savedAt. */
  savedItems(uid: string): Promise<Record<string, unknown>[]>;
  setSaved(item: SavedSyncItem & { saved: boolean }): Promise<void>;
  importSaved(items: SavedSyncItem[]): Promise<number>;

  // Polls
  activePolls(limit?: number): Promise<Poll[]>;
  questionOfTheDay(): Promise<Poll | null>;
  pastPolls(limit?: number): Promise<Poll[]>;
  myVote(pollId: string): Promise<string | null>;
  vote(poll: Poll, optionId: string): Promise<Poll>;

  // Notifications
  notifications(uid: string, cursor?: unknown, limit?: number): Promise<CursorPage<AppNotification>>;
  watchUnreadCount(uid: string, cb: (n: number) => void): Unsubscribe;
  markRead(uid: string, notificationId: string): Promise<void>;
  markAllRead(): Promise<void>;

  // Submissions
  /** Uploads a local image file for a submission; returns its storage path. */
  uploadSubmissionImage(fileUri: string, contentType: string): Promise<string>;
  submitStory(fields: Record<string, unknown>): Promise<string>;
  submitStartup(fields: Record<string, unknown>): Promise<string>;
  claimStartup(fields: Record<string, unknown>): Promise<string>;
  mySubmissions(uid: string): Promise<Submission[]>;
}

/** A saved item as the server's setSaved and importSaved take it. */
export type SavedSyncItem = {
  kind: 'article' | SavedEntity['kind'];
  id: string;
  title: string;
  image?: string | null;
  url?: string | null;
  data?: unknown;
};

const unavailable = () => Promise.reject(new CommunityError('unavailable'));
const noop: Unsubscribe = () => {};

/** Used when the build has no Firebase settings: nothing is available and nothing pretends to work. */
export const unavailableAuth: AuthRepository = {
  isAvailable: false,
  supportsGoogle: false,
  onUser: (listener) => (listener(null), noop),
  signInWithEmail: unavailable,
  registerWithEmail: unavailable,
  signInWithGoogle: unavailable,
  sendPasswordReset: unavailable,
  sendEmailVerification: unavailable,
  reload: async () => null,
  reauthenticate: unavailable,
  signOut: async () => {},
};

export const unavailableApi: CommunityApi = {
  isAvailable: false,
  fetchConfig: async () => null,
  watchProfile: (_, cb) => (cb(null), noop),
  watchAccount: (_, cb) => (cb(null), noop),
  profile: async () => null,
  checkUsername: unavailable,
  createProfile: unavailable,
  updateProfile: unavailable,
  setProfilePhoto: unavailable,
  removeProfilePhoto: unavailable,
  changeUsername: unavailable,
  updateNotificationPrefs: unavailable,
  registerDevice: unavailable,
  unregisterDevice: unavailable,
  deleteAccount: unavailable,
  claimAdmin: unavailable,
  watchEngagement: () => noop,
  myReaction: async () => null,
  setReaction: unavailable,
  comments: unavailable,
  replies: unavailable,
  commentsBy: unavailable,
  likedComments: async () => new Set(),
  addComment: unavailable,
  editComment: unavailable,
  deleteComment: unavailable,
  likeComment: unavailable,
  report: unavailable,
  watchBlocked: (_, cb) => (cb(new Set()), noop),
  setBlocked: unavailable,
  setMuted: unavailable,
  watchFollows: (_, cb) => (cb([]), noop),
  setFollow: unavailable,
  followerCount: async () => 0,
  savedItems: async () => [],
  setSaved: unavailable,
  importSaved: unavailable,
  activePolls: async () => [],
  questionOfTheDay: async () => null,
  pastPolls: async () => [],
  myVote: async () => null,
  vote: unavailable,
  notifications: async () => ({ items: [], hasMore: false }),
  watchUnreadCount: (_, cb) => (cb(0), noop),
  markRead: unavailable,
  markAllRead: unavailable,
  uploadSubmissionImage: unavailable,
  submitStory: unavailable,
  submitStartup: unavailable,
  claimStartup: unavailable,
  mySubmissions: async () => [],
};

let current: { auth: AuthRepository; api: CommunityApi } | null = null;

/**
 * The community backend: Firebase when the build has it (google-services.json),
 * otherwise the unavailable stand-ins. Tests replace it with setCommunity().
 */
export function community(): { auth: AuthRepository; api: CommunityApi } {
  if (!current) {
    // Loaded lazily so tests and builds without Firebase never touch the native modules.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { createFirebaseCommunity } = require('./firebase') as typeof import('./firebase');
    current = createFirebaseCommunity() ?? { auth: unavailableAuth, api: unavailableApi };
  }
  return current;
}

export function setCommunity(value: { auth: AuthRepository; api: CommunityApi } | null) {
  current = value;
}
