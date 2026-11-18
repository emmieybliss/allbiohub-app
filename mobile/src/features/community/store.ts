import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { onPushTokenRefresh, pushToken } from '@/features/push/notifications';
import { imageUrlFor } from '@/lib/images';
import type { Article } from '@/models/types';
import { setBookmarkMirror, useBookmarks } from '@/stores/bookmarks';
import { community, type SavedSyncItem } from './api';
import { articleFromSyncJson, articleToSyncJson } from './articleJson';
import {
  type AccountSettings,
  type AuthUser,
  type Feature,
  type FollowedItem,
  type FollowTarget,
  flagsFromConfig,
  followKey,
  isOn,
  type SavedEntity,
  savedKey,
  toDate,
  type UserProfile,
} from './models';

// Feature switches ----------------------------------------------------------------

type FlagsState = { on: Feature[]; set: (on: Feature[]) => void };

/**
 * Remote feature switches (config/app in Firestore). The app opens with the
 * last switches seen, so it looks the same offline, then refreshes them.
 * Everything is off until switched on, and always off without Firebase.
 */
export const useFlags = create<FlagsState>()(
  persist((set) => ({ on: [], set: (on) => set({ on }) }), {
    name: 'abh.community.flags',
    version: 1,
    storage: createJSONStorage(() => AsyncStorage),
    partialize: (s) => ({ on: s.on }),
  }),
);

export async function refreshFlags(): Promise<void> {
  const { api } = community();
  if (!api.isAvailable) {
    useFlags.getState().set([]);
    return;
  }
  const config = await api.fetchConfig();
  if (config !== null) useFlags.getState().set(flagsFromConfig(config));
}

/** Whether a community feature is switched on. */
export function useFeature(feature: Feature): boolean {
  return useFlags((s) => community().api.isAvailable && isOn(s.on, feature));
}

export function featureOn(feature: Feature): boolean {
  return community().api.isAvailable && isOn(useFlags.getState().on, feature);
}

// Session -----------------------------------------------------------------------------

type SessionState = {
  /** False until Firebase has said whether someone is signed in. */
  ready: boolean;
  user: AuthUser | null;
  /** Undefined while loading; null until they choose a username. */
  profile: UserProfile | null | undefined;
  account: AccountSettings | null;
  blocked: string[];
  follows: FollowedItem[];
  followsLoaded: boolean;
  /** Follows changed on this phone but not yet in the server list, so buttons switch at once. */
  followOverrides: Record<string, boolean>;
  unread: number;
};

const initialSession: SessionState = {
  ready: false,
  user: null,
  profile: undefined,
  account: null,
  blocked: [],
  follows: [],
  followsLoaded: false,
  followOverrides: {},
  unread: 0,
};

export const useSession = create<SessionState>()(() => initialSession);

export const useUser = () => useSession((s) => s.user);

/** Resolves with the profile once it has loaded (or null after 5 seconds). */
export function profileLoaded(): Promise<UserProfile | null> {
  const now = useSession.getState().profile;
  if (now !== undefined) return Promise.resolve(now);
  return new Promise((resolve) => {
    const timer = setTimeout(() => (off(), resolve(null)), 5000);
    const off = useSession.subscribe((s) => {
      if (s.profile !== undefined) {
        clearTimeout(timer);
        off();
        resolve(s.profile);
      }
    });
  });
}

export function useIsFollowing(target: Pick<FollowTarget, 'kind' | 'id'>): boolean {
  const key = followKey(target);
  return useSession((s) => s.followOverrides[key] ?? s.follows.some((f) => followKey(f.target) === key));
}

/** Follows or unfollows. Throws (after rolling back) when it fails. */
export async function setFollow(target: FollowTarget, follow: boolean): Promise<void> {
  const key = followKey(target);
  useSession.setState((s) => ({ followOverrides: { ...s.followOverrides, [key]: follow } }));
  try {
    await community().api.setFollow(target, follow);
  } catch (e) {
    useSession.setState((s) => {
      const { [key]: _, ...rest } = s.followOverrides;
      return { followOverrides: rest };
    });
    throw e;
  }
}

function applyFollows(follows: FollowedItem[]) {
  useSession.setState((s) => {
    // Once the server list agrees with an override it is no longer needed.
    const keys = new Set(follows.map((f) => followKey(f.target)));
    const overrides: Record<string, boolean> = {};
    for (const [k, v] of Object.entries(s.followOverrides)) if (keys.has(k) !== v) overrides[k] = v;
    return { follows, followsLoaded: true, followOverrides: overrides };
  });
}

// Saved startups and founders ---------------------------------------------------------

type SavedEntitiesState = {
  items: SavedEntity[];
  /** Changes not yet confirmed by the account, retried after the next sign-in or launch. */
  pending: (SavedSyncItem & { saved: boolean })[];
  /** Accounts this phone's saved items were already uploaded to. */
  importedFor: string[];
  toggle: (entity: SavedEntity) => boolean;
  addFromAccount: (entity: SavedEntity) => void;
};

export const useSavedEntities = create<SavedEntitiesState>()(
  persist(
    (set, get) => ({
      items: [],
      pending: [],
      importedFor: [],
      toggle: (entity) => {
        const key = savedKey(entity);
        const saved = get().items.some((e) => savedKey(e) === key);
        if (saved) set({ items: get().items.filter((e) => savedKey(e) !== key) });
        else set({ items: [{ ...entity, savedAt: new Date().toISOString() }, ...get().items] });
        void mirror({ kind: entity.kind, id: entity.id, title: entity.title, image: entity.image, url: entity.url, saved: !saved });
        return !saved;
      },
      addFromAccount: (entity) => {
        if (get().items.some((e) => savedKey(e) === savedKey(entity))) return;
        set({ items: [...get().items, entity] });
      },
    }),
    {
      name: 'abh.savedEntities',
      version: 1,
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (s) => ({ items: s.items, pending: s.pending, importedFor: s.importedFor }),
    },
  ),
);

export function useIsEntitySaved(entity: Pick<SavedEntity, 'kind' | 'id'>): boolean {
  const key = savedKey(entity);
  return useSavedEntities((s) => s.items.some((e) => savedKey(e) === key));
}

// Saved items sync -------------------------------------------------------------------------

const syncEnabled = () => useSession.getState().user !== null && featureOn('savedSync');

/** Sends one change to the account; queues it when it can't reach the server. */
async function mirror(change: SavedSyncItem & { saved: boolean }): Promise<void> {
  if (!syncEnabled()) return;
  try {
    await community().api.setSaved(change);
  } catch {
    useSavedEntities.setState((s) => ({
      pending: [...s.pending.filter((p) => !(p.kind === change.kind && p.id === change.id)), change],
    }));
  }
}

function articleChange(article: Article, saved: boolean): SavedSyncItem & { saved: boolean } {
  return {
    kind: 'article',
    id: String(article.id),
    title: article.title,
    image: article.image ? imageUrlFor(article.image, 600) : null,
    url: article.link,
    data: saved ? articleToSyncJson(article) : undefined,
    saved,
  };
}

let syncing = false;

/**
 * After signing in (with savedSync on): uploads what this phone saved, once per
 * account, retries queued changes and brings in what the account has. Nothing
 * on the phone is deleted.
 */
export async function syncSaved(): Promise<void> {
  const user = useSession.getState().user;
  if (!user || !syncEnabled() || syncing) return;
  syncing = true;
  const { api } = community();
  try {
    const state = useSavedEntities.getState();
    if (!state.importedFor.includes(user.uid)) {
      await api.importSaved([
        ...useBookmarks.getState().items.map((a) => {
          const { saved: _, ...item } = articleChange(a, true);
          return item;
        }),
        ...state.items.map((e) => ({ kind: e.kind, id: e.id, title: e.title, image: e.image, url: e.url })),
      ]);
      useSavedEntities.setState((s) => ({ importedFor: [...s.importedFor, user.uid] }));
    }
    for (const change of useSavedEntities.getState().pending) await api.setSaved(change);
    useSavedEntities.setState({ pending: [] });
    const remote = await api.savedItems(user.uid);
    for (const item of remote) {
      if (item.kind === 'article') {
        const article = articleFromSyncJson(item.data);
        if (article) useBookmarks.getState().addFromAccount(article);
      } else if (item.kind === 'startup' || item.kind === 'founder') {
        useSavedEntities.getState().addFromAccount({
          kind: item.kind,
          id: String(item.id),
          title: String(item.title ?? ''),
          image: typeof item.image === 'string' ? item.image : undefined,
          url: typeof item.url === 'string' ? item.url : undefined,
          savedAt: toDate(item.savedAt)?.toISOString(),
        });
      }
    }
  } catch {
    // Tried again after the next sign-in or launch.
  } finally {
    syncing = false;
  }
}

// Push registration ---------------------------------------------------------------------------

let registeredFor: string | null = null;
let tokenRefreshOff: (() => void) | null = null;

/** Registers this phone for personal notifications while someone is signed in. */
async function registerDevice(uid: string) {
  const { api } = community();
  if (registeredFor === uid || !api.isAvailable) return;
  registeredFor = uid;
  try {
    const token = await pushToken();
    if (!token) return;
    await api.registerDevice(token);
    tokenRefreshOff?.();
    tokenRefreshOff = onPushTokenRefresh((t) => void api.registerDevice(t).catch(() => {}));
  } catch {
    registeredFor = null;
  }
}

/** Signs out after unregistering this phone from personal notifications. */
export async function signOut(): Promise<void> {
  await unregisterDevice();
  await community().auth.signOut();
}

export async function unregisterDevice(): Promise<void> {
  tokenRefreshOff?.();
  tokenRefreshOff = null;
  registeredFor = null;
  try {
    const token = await pushToken();
    if (token) await community().api.unregisterDevice(token);
  } catch {
    // The server drops tokens that stop working.
  }
}

// Start-up ------------------------------------------------------------------------------------

/**
 * Connects the community features: switches, the signed-in person and their
 * live data. Call once from the root layout; returns a function that stops it.
 */
export function startCommunity(): () => void {
  const { auth, api } = community();
  void refreshFlags();
  if (!api.isAvailable) {
    useSession.setState({ ...initialSession, ready: true });
    return () => {};
  }

  setBookmarkMirror((article, saved) => void mirror(articleChange(article, saved)));

  let userSubs: (() => void)[] = [];
  let unreadOff: (() => void) | null = null;
  let currentUid: string | null = null;

  const watchUnread = () => {
    unreadOff?.();
    unreadOff = null;
    if (currentUid && featureOn('notificationCenter')) {
      unreadOff = api.watchUnreadCount(currentUid, (unread) => useSession.setState({ unread }));
    } else {
      useSession.setState({ unread: 0 });
    }
  };

  const authOff = auth.onUser((user) => {
    const uid = user?.uid ?? null;
    if (uid === currentUid) {
      useSession.setState({ user, ready: true });
      return;
    }
    userSubs.forEach((off) => off());
    userSubs = [];
    currentUid = uid;
    useSession.setState({ ...initialSession, ready: true, user, profile: user ? undefined : null });
    watchUnread();
    if (!uid) return;
    userSubs = [
      api.watchProfile(uid, (profile) => useSession.setState({ profile })),
      api.watchAccount(uid, (account) => useSession.setState({ account })),
      api.watchBlocked(uid, (blocked) => useSession.setState({ blocked: [...blocked] })),
      api.watchFollows(uid, applyFollows),
    ];
    void registerDevice(uid);
    void syncSaved();
  });

  // Switches can change after start-up (the cached ones load first).
  const flagsOff = useFlags.subscribe((s, prev) => {
    if (s.on === prev.on) return;
    watchUnread();
    void syncSaved();
  });

  return () => {
    authOff();
    flagsOff();
    unreadOff?.();
    userSubs.forEach((off) => off());
    setBookmarkMirror(null);
  };
}
