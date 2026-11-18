/**
 * Firebase implementation of the community backend (COMMUNITY.md): Firebase
 * Authentication, Cloud Firestore reads, Cloud Functions for every write and
 * Cloud Storage for pictures. The native modules are loaded only when the
 * build has Firebase (google-services.json), so builds without it and tests
 * never touch them.
 */
import { env } from '@/config/env';
import type { AuthRepository, CommunityApi, SavedSyncItem, Unsubscribe } from './api';
import { CommunityError, toCommunityError } from './errors';
import {
  type AuthUser,
  type Comment,
  type CursorPage,
  EMPTY_ENGAGEMENT,
  mapAccount,
  mapComment,
  mapEngagement,
  mapFollow,
  mapNotification,
  mapPoll,
  mapProfile,
  reactionFromKey,
  type Submission,
  type SubmissionKind,
  submissionStatus,
  toDate,
} from './models';

type AuthModule = typeof import('@react-native-firebase/auth');
type FirestoreModule = typeof import('@react-native-firebase/firestore');
type FunctionsModule = typeof import('@react-native-firebase/functions');
type StorageModule = typeof import('@react-native-firebase/storage');
type GoogleModule = typeof import('@react-native-google-signin/google-signin');
type User = import('@react-native-firebase/auth').User;
type Query = import('@react-native-firebase/firestore').Query;
type DocSnap = import('@react-native-firebase/firestore').QueryDocumentSnapshot;

/** Converts Firestore values (Timestamps) into plain values. */
export function plain(value: unknown): unknown {
  if (value && typeof value === 'object') {
    if (typeof (value as { toDate?: unknown }).toDate === 'function') return (value as { toDate: () => Date }).toDate();
    if (Array.isArray(value)) return value.map(plain);
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value)) out[k] = plain(v);
    return out;
  }
  return value;
}

const plainMap = (value: unknown) => (plain(value ?? {}) as Record<string, unknown>) ?? {};

async function guard<T>(action: () => Promise<T>): Promise<T> {
  try {
    return await action();
  } catch (e) {
    throw toCommunityError(e);
  }
}

export function createFirebaseCommunity(): { auth: AuthRepository; api: CommunityApi } | null {
  if (!env.hasFirebase) return null;
  let A: AuthModule, F: FirestoreModule, Fn: FunctionsModule, S: StorageModule;
  try {
    /* eslint-disable @typescript-eslint/no-require-imports */
    A = require('@react-native-firebase/auth');
    F = require('@react-native-firebase/firestore');
    Fn = require('@react-native-firebase/functions');
    S = require('@react-native-firebase/storage');
    /* eslint-enable @typescript-eslint/no-require-imports */
  } catch {
    return null;
  }
  const auth = A.getAuth();
  const db = F.getFirestore();
  const functions = Fn.getFunctions(undefined, env.functionsRegion);

  // Auth ------------------------------------------------------------------------

  let google: GoogleModule | null = null;
  function loadGoogle(): GoogleModule {
    if (!google) {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      google = require('@react-native-google-signin/google-signin') as GoogleModule;
      google.GoogleSignin.configure({ webClientId: env.googleWebClientId });
    }
    return google;
  }

  /** Returns the Google ID token, or null when the person closed the sheet. */
  async function googleIdToken(): Promise<string | null> {
    const g = loadGoogle();
    await g.GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });
    try {
      const result = await g.GoogleSignin.signIn();
      if (result.type !== 'success') return null;
      if (!result.data.idToken) throw new CommunityError('unknown');
      return result.data.idToken;
    } catch (e) {
      if (g.isErrorWithCode(e) && e.code === g.statusCodes.SIGN_IN_CANCELLED) return null;
      throw e;
    }
  }

  async function toUser(user: User | null): Promise<AuthUser | null> {
    if (!user) return null;
    let isAdmin = false;
    try {
      const token = await A.getIdTokenResult(user);
      isAdmin = token.claims?.admin === true;
    } catch {
      // Offline: the claim is read again on the next change.
    }
    return {
      uid: user.uid,
      email: user.email ?? undefined,
      displayName: user.displayName ?? undefined,
      photoUrl: user.photoURL ?? undefined,
      emailVerified: user.emailVerified,
      isAdmin,
      providers: user.providerData.map((p) => p.providerId),
    };
  }

  const listeners = new Set<(u: AuthUser | null) => void>();
  const emit = (u: AuthUser | null) => listeners.forEach((l) => l(u));

  const authRepo: AuthRepository = {
    isAvailable: true,
    supportsGoogle: env.googleWebClientId.length > 0,
    onUser(listener) {
      listeners.add(listener);
      const off = A.onAuthStateChanged(auth, (u) => {
        toUser(u).then(listener, () => listener(null));
      });
      return () => {
        listeners.delete(listener);
        off();
      };
    },
    signInWithEmail: (email, password) =>
      guard(async () => {
        const cred = await A.signInWithEmailAndPassword(auth, email.trim(), password);
        return (await toUser(cred.user))!;
      }),
    registerWithEmail: (email, password) =>
      guard(async () => {
        const cred = await A.createUserWithEmailAndPassword(auth, email.trim(), password);
        await A.sendEmailVerification(cred.user);
        return (await toUser(cred.user))!;
      }),
    signInWithGoogle: () =>
      guard(async () => {
        if (!authRepo.supportsGoogle) throw new CommunityError('unavailable', 'Google sign-in isn’t set up in this version yet.');
        const idToken = await googleIdToken();
        if (!idToken) return null;
        const cred = await A.signInWithCredential(auth, A.GoogleAuthProvider.credential(idToken));
        return toUser(cred.user);
      }),
    sendPasswordReset: (email) => guard(() => A.sendPasswordResetEmail(auth, email.trim())),
    sendEmailVerification: () =>
      guard(async () => {
        if (auth.currentUser) await A.sendEmailVerification(auth.currentUser);
      }),
    reload: () =>
      guard(async () => {
        const user = auth.currentUser;
        if (!user) return null;
        await A.reload(user);
        await A.getIdTokenResult(user, true);
        const fresh = await toUser(auth.currentUser);
        emit(fresh);
        return fresh;
      }),
    reauthenticate: (password) =>
      guard(async () => {
        const user = auth.currentUser;
        if (!user) throw new CommunityError('signInRequired');
        const providers = new Set(user.providerData.map((p) => p.providerId));
        if (providers.has('password') && password) {
          await A.reauthenticateWithCredential(user, A.EmailAuthProvider.credential(user.email ?? '', password));
        } else if (providers.has('google.com')) {
          const idToken = await googleIdToken();
          if (!idToken) throw new CommunityError('invalid', 'Confirm with Google to continue.');
          await A.reauthenticateWithCredential(user, A.GoogleAuthProvider.credential(idToken));
        } else {
          throw new CommunityError('invalid', 'Enter your password to continue.', 'password');
        }
      }),
    signOut: () =>
      guard(async () => {
        await A.signOut(auth);
        if (google) await google.GoogleSignin.signOut().catch(() => null);
      }),
  };

  // Community API ------------------------------------------------------------------

  async function call(name: string, data: Record<string, unknown> = {}): Promise<Record<string, unknown>> {
    return guard(async () => {
      const result = await Fn.httpsCallable(functions, name, { timeout: 30_000 })(data);
      const value = result.data;
      return value && typeof value === 'object' ? plainMap(value) : {};
    });
  }

  function uid(): string {
    const id = auth.currentUser?.uid;
    if (!id) throw new CommunityError('signInRequired');
    return id;
  }

  /** Live document or query, with errors (signed out, permission) treated as "nothing". */
  function watchDoc<T>(path: string, map: (data: Record<string, unknown> | null) => T, cb: (v: T) => void): Unsubscribe {
    return F.onSnapshot(
      F.doc(db, path),
      (s) => cb(map(s.exists() ? plainMap(s.data()) : null)),
      () => {},
    );
  }

  async function page<T>(q: Query, cursor: unknown, limit: number, map: (d: DocSnap) => T): Promise<CursorPage<T>> {
    return guard(async () => {
      let paged = F.query(q, F.limit(limit));
      if (cursor) paged = F.query(paged, F.startAfter(cursor as DocSnap));
      const snap = await F.getDocs(paged);
      return {
        items: snap.docs.map(map),
        cursor: snap.docs.length ? snap.docs[snap.docs.length - 1] : cursor,
        hasMore: snap.docs.length === limit,
      };
    });
  }

  const toComment = (d: DocSnap): Comment => mapComment(d.id, plainMap(d.data()));
  const comments = () => F.collection(db, 'comments');

  async function upload(folder: string, fileUri: string, contentType: string): Promise<string> {
    return guard(async () => {
      const ext = contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
      const path = `${folder}/${uid()}/${Date.now()}.${ext}`;
      await S.putFile(S.ref(S.getStorage(), path), fileUri, { contentType });
      return path;
    });
  }

  async function polls(q: Query) {
    return guard(async () => (await F.getDocs(q)).docs.map((d) => mapPoll(d.id, plainMap(d.data()))));
  }

  const pollsWhere = (kind: string, status: string, n: number) =>
    F.query(F.collection(db, 'polls'), F.where('kind', '==', kind), F.where('status', '==', status), F.orderBy('publishAt', 'desc'), F.limit(n));

  const api: CommunityApi = {
    isAvailable: true,

    async fetchConfig() {
      try {
        const snap = await Promise.race([
          F.getDocFromServer(F.doc(db, 'config/app')),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 8000)),
        ]);
        return snap.exists() ? plainMap(snap.data()) : {};
      } catch {
        return null;
      }
    },

    // Profile
    watchProfile: (id, cb) => watchDoc(`profiles/${id}`, (d) => (d ? mapProfile(id, d) : null), cb),
    watchAccount: (id, cb) => watchDoc(`users/${id}`, (d) => (d ? mapAccount(d) : null), cb),
    async profile(id) {
      try {
        const s = await F.getDoc(F.doc(db, `profiles/${id}`));
        return s.exists() ? mapProfile(id, plainMap(s.data())) : null;
      } catch (e) {
        // Private profiles can't be read by others.
        if (String((e as { code?: unknown }).code).endsWith('permission-denied')) return null;
        throw toCommunityError(e);
      }
    },
    async checkUsername(username) {
      const r = await call('checkUsername', { username });
      return { available: r.available === true, message: typeof r.message === 'string' ? r.message : undefined };
    },
    createProfile: async (username, displayName) => void (await call('createProfile', { username, displayName })),
    async updateProfile(changes) {
      const data: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(changes)) if (v !== undefined) data[k] = v;
      await call('updateProfile', data);
    },
    async setProfilePhoto(fileUri, contentType) {
      const path = await upload('avatars', fileUri, contentType);
      await call('updateProfile', { photoPath: path });
    },
    removeProfilePhoto: async () => void (await call('updateProfile', { photoPath: null })),
    changeUsername: async (username) => void (await call('changeUsername', { username })),
    updateNotificationPrefs: async (prefs) => void (await call('updateNotificationPrefs', { prefs })),
    registerDevice: async (token) => void (await call('registerDevice', { token, platform: 'android' })),
    unregisterDevice: async (token) => void (await call('unregisterDevice', { token })),
    deleteAccount: async () => void (await call('deleteAccount', { confirm: 'DELETE' })),
    claimAdmin: async () => void (await call('claimAdmin')),

    // Reactions
    watchEngagement: (articleId, cb) => watchDoc(`articles/${articleId}`, (d) => (d ? mapEngagement(d) : EMPTY_ENGAGEMENT), cb),
    myReaction: (articleId) =>
      guard(async () => {
        const me = auth.currentUser?.uid;
        if (!me) return null;
        const s = await F.getDoc(F.doc(db, `articles/${articleId}/reactions/${me}`));
        return reactionFromKey(s.exists() ? s.data()?.reaction : null);
      }),
    async setReaction(articleId, reaction) {
      const r = await call('setReaction', { articleId, reaction });
      const current = await F.getDoc(F.doc(db, `articles/${articleId}`)).catch(() => null);
      return mapEngagement({ ...plainMap(current?.exists() ? current.data() : {}), reactions: r.counts });
    },

    // Comments
    comments: (articleId, cursor, limit = 20) =>
      page(
        F.query(
          comments(),
          F.where('articleId', '==', articleId),
          F.where('parentId', '==', null),
          F.where('status', '==', 'approved'),
          F.orderBy('pinned', 'desc'),
          F.orderBy('createdAt', 'desc'),
        ),
        cursor,
        limit,
        toComment,
      ),
    replies: (rootId, cursor, limit = 30) =>
      page(F.query(comments(), F.where('rootId', '==', rootId), F.where('status', '==', 'approved'), F.orderBy('createdAt')), cursor, limit, toComment),
    commentsBy: (authorUid, cursor, limit = 20) =>
      page(F.query(comments(), F.where('authorUid', '==', authorUid), F.orderBy('createdAt', 'desc')), cursor, limit, toComment),
    likedComments: (ids) =>
      guard(async () => {
        const me = auth.currentUser?.uid;
        if (!me || !ids.length) return new Set<string>();
        const snaps = await Promise.all(ids.map((id) => F.getDoc(F.doc(db, `comments/${id}/likes/${me}`))));
        return new Set(ids.filter((_, i) => snaps[i].exists()));
      }),
    async addComment(articleId, body, parentId) {
      const r = await call('addComment', { articleId, body, ...(parentId ? { parentId } : {}) });
      return mapComment(String(r.id), r);
    },
    async editComment(commentId, body) {
      const r = await call('editComment', { commentId, body });
      return mapComment(String(r.id), r);
    },
    deleteComment: async (commentId) => void (await call('deleteComment', { commentId })),
    async likeComment(commentId, like) {
      const r = await call('likeComment', { commentId, like });
      return typeof r.likeCount === 'number' ? r.likeCount : 0;
    },
    report: async (targetType, targetId, reason, details = '') => void (await call('reportContent', { targetType, targetId, reason, details })),

    // Safety
    watchBlocked: (id, cb) =>
      F.onSnapshot(
        F.collection(db, `users/${id}/blocks`),
        (s) => cb(new Set(s.docs.map((d) => d.id))),
        () => {},
      ),
    setBlocked: async (other, block) => void (await call('blockUser', { uid: other, block })),
    setMuted: async (other, mute) => void (await call('muteUser', { uid: other, mute })),

    // Follows and saved items
    watchFollows: (id, cb) =>
      F.onSnapshot(
        F.query(F.collection(db, `users/${id}/follows`), F.orderBy('createdAt', 'desc'), F.limit(500)),
        (s) => cb(s.docs.map((d) => mapFollow(plainMap(d.data())))),
        () => {},
      ),
    setFollow: async (t, follow) => void (await call('setFollow', { kind: t.kind, id: t.id, label: t.label, follow })),
    followerCount: (t) =>
      guard(async () => {
        const s = await F.getDoc(F.doc(db, `followTargets/${t.kind}_${t.id}`));
        const n = s.exists() ? s.data()?.followerCount : 0;
        return typeof n === 'number' ? n : 0;
      }),
    savedItems: (id) =>
      guard(async () => {
        const s = await F.getDocs(F.query(F.collection(db, `users/${id}/saved`), F.orderBy('savedAt', 'desc'), F.limit(1000)));
        return s.docs.map((d) => {
          const data = plainMap(d.data());
          return { ...data, id: data.targetId };
        });
      }),
    setSaved: async (item) => void (await call('setSaved', { ...item })),
    async importSaved(items: SavedSyncItem[]) {
      let imported = 0;
      for (let i = 0; i < items.length; i += 200) {
        const r = await call('importSaved', { items: items.slice(i, i + 200) });
        imported += typeof r.imported === 'number' ? r.imported : 0;
      }
      return imported;
    },

    // Polls
    activePolls: (n = 10) => polls(pollsWhere('poll', 'active', n)),
    async questionOfTheDay() {
      const list = await polls(pollsWhere('qotd', 'active', 1));
      return list[0] ?? null;
    },
    pastPolls: (n = 20) => polls(pollsWhere('poll', 'closed', n)),
    myVote: (pollId) =>
      guard(async () => {
        const me = auth.currentUser?.uid;
        if (!me) return null;
        const s = await F.getDoc(F.doc(db, `polls/${pollId}/votes/${me}`));
        const v = s.exists() ? s.data()?.optionId : null;
        return typeof v === 'string' ? v : null;
      }),
    async vote(poll, optionId) {
      const r = await call('votePoll', { pollId: poll.id, optionId });
      return mapPoll(poll.id, {
        ...poll,
        status: poll.status,
        counts: r.counts,
        totalVotes: r.totalVotes,
      });
    },

    // Notifications
    notifications: (id, cursor, limit = 20) =>
      page(F.query(F.collection(db, `users/${id}/notifications`), F.orderBy('createdAt', 'desc')), cursor, limit, (d) =>
        mapNotification(d.id, plainMap(d.data())),
      ),
    watchUnreadCount: (id, cb) =>
      F.onSnapshot(
        F.query(F.collection(db, `users/${id}/notifications`), F.where('read', '==', false), F.limit(100)),
        (s) => cb(s.size),
        () => {},
      ),
    markRead: (id, notificationId) => guard(() => F.updateDoc(F.doc(db, `users/${id}/notifications/${notificationId}`), { read: true })),
    markAllRead: async () => void (await call('markAllNotificationsRead')),

    // Submissions
    uploadSubmissionImage: (fileUri, contentType) => upload('submissions', fileUri, contentType),
    submitStory: async (fields) => String((await call('submitStory', fields)).message ?? ''),
    submitStartup: async (fields) => String((await call('submitStartup', fields)).message ?? ''),
    claimStartup: async (fields) => String((await call('claimStartup', fields)).message ?? ''),
    mySubmissions: (id) =>
      guard(async () => {
        const load = async (name: string, kind: SubmissionKind, titleField: string): Promise<Submission[]> => {
          const s = await F.getDocs(
            F.query(F.collection(db, name), F.where('submitterUid', '==', id), F.orderBy('createdAt', 'desc'), F.limit(50)),
          );
          return s.docs.map((d) => {
            const data = plainMap(d.data());
            return {
              id: d.id,
              kind,
              title: String(data[titleField] ?? ''),
              status: submissionStatus(data.status),
              editorNote: typeof data.editorNote === 'string' ? data.editorNote : undefined,
              createdAt: toDate(data.createdAt),
            };
          });
        };
        const all = await Promise.all([
          load('storySubmissions', 'story', 'title'),
          load('startupSubmissions', 'startup', 'name'),
          load('startupClaims', 'claim', 'startupName'),
        ]);
        return all.flat().sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0));
      }),
  };

  return { auth: authRepo, api };
}
