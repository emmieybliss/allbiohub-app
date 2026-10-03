import { defineString } from "firebase-functions/params";
import { callable, db, FieldValue, HttpsError, rateLimit, requireKey, requireOneOf, str } from "./core.js";
import { cleanText, cleanUrl, FOLLOW_KINDS, SAVED_KINDS, slugify, type FollowKind } from "./validation.js";

/** The WordPress site the app reads from. */
export const siteUrl = defineString("WORDPRESS_BASE_URL", { default: "https://allbiohub.com" });
/** Base path of the startup directory add-on on that site. */
export const startupApiPath = defineString("STARTUP_API_PATH", { default: "/wp-json/allbiohub/v1" });

const MAX_FOLLOWS = 500;
const MAX_SAVED = 1000;

export async function fetchJson(url: string): Promise<unknown | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { "User-Agent": "AllBioHubCommunity/1.0", Accept: "application/json" },
    });
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

/**
 * The real name of what is being followed, looked up on allbiohub.com so a
 * follow can't attach a made-up name (names drive startup and topic alerts).
 */
async function resolveTarget(kind: FollowKind, id: string, label: string): Promise<{ label: string; image: string | null }> {
  const base = siteUrl.value().replace(/\/$/, "");
  try {
    if (kind === "startup") {
      const json = await fetchJson(`${base}${startupApiPath.value()}/startups/${encodeURIComponent(id)}`) as
        { name?: string; logo?: unknown } | null;
      if (!json?.name) throw new HttpsError("not-found", "That startup isn't in the directory.");
      const logo = typeof json.logo === "string" ? json.logo : (json.logo as { url?: string } | undefined)?.url;
      return { label: str(json.name), image: logo ? cleanUrl(logo) : null };
    }
    if (kind === "topic") {
      const json = await fetchJson(`${base}/wp-json/wp/v2/categories?slug=${encodeURIComponent(id)}`) as
        Array<{ name?: string }> | null;
      const name = json?.[0]?.name;
      if (!name) throw new HttpsError("not-found", "That topic doesn't exist.");
      return { label: decodeEntities(name), image: null };
    }
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("unavailable", "allbiohub.com didn't answer. Try again in a moment.");
  }
  // Founders have no id in the directory: the id is the slug of their name.
  const name = cleanText(label).slice(0, 100);
  if (!name || slugify(name) !== id) throw new HttpsError("invalid-argument", "Invalid founder.");
  return { label: name, image: null };
}

function decodeEntities(s: string): string {
  return s.replace(/&amp;/g, "&").replace(/&#0?39;|&#8217;/g, "'").replace(/&quot;/g, '"');
}

/** Follows or unfollows a startup, founder or topic. */
export const setFollow = callable<{ kind?: string; id?: string; label?: string; follow?: boolean }, {
  following: boolean; followerCount: number;
}>(
  {},
  async (data, caller) => {
    const kind = requireOneOf(data.kind, FOLLOW_KINDS, "kind");
    const id = requireKey(data.id, "id");
    const follow = data.follow !== false;
    await rateLimit(caller.uid, "follow", [{ max: 30, seconds: 60 }, { max: 300, seconds: 86_400 }]);

    const key = `${kind}_${id}`;
    const mineRef = db.doc(`users/${caller.uid}/follows/${key}`);
    const targetRef = db.doc(`followTargets/${key}`);
    const followerRef = targetRef.collection("followers").doc(caller.uid);
    const profileRef = db.doc(`profiles/${caller.uid}`);

    const existing = await mineRef.get();
    if (follow === existing.exists) {
      const target = await targetRef.get();
      return { following: follow, followerCount: Number(target.get("followerCount") ?? 0) };
    }
    const resolved = follow ? await resolveTarget(kind, id, str(data.label)) : null;
    if (follow) {
      const count = await db.collection(`users/${caller.uid}/follows`).count().get();
      if (count.data().count >= MAX_FOLLOWS) {
        throw new HttpsError("resource-exhausted", `You can follow up to ${MAX_FOLLOWS} things.`);
      }
    }

    return db.runTransaction(async (tx) => {
      const [mine, target, profile] = await Promise.all([tx.get(mineRef), tx.get(targetRef), tx.get(profileRef)]);
      let followers = Number(target.get("followerCount") ?? 0);
      if (follow && !mine.exists) {
        followers += 1;
        tx.set(mineRef, {
          kind, targetId: id, label: resolved!.label, image: resolved!.image, createdAt: FieldValue.serverTimestamp(),
        });
        tx.set(followerRef, { createdAt: FieldValue.serverTimestamp() });
        tx.set(targetRef, {
          kind, targetId: id, label: resolved!.label, followerCount: followers, updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        if (profile.exists) tx.update(profileRef, { followingCount: FieldValue.increment(1) });
      } else if (!follow && mine.exists) {
        followers = Math.max(0, followers - 1);
        tx.delete(mineRef);
        tx.delete(followerRef);
        tx.set(targetRef, { followerCount: followers }, { merge: true });
        if (profile.exists) tx.update(profileRef, { followingCount: FieldValue.increment(-1) });
      }
      return { following: follow, followerCount: followers };
    });
  },
);

interface SavedInput {
  kind?: string; id?: string; title?: string; image?: string | null; url?: string; data?: unknown; saved?: boolean;
}

function savedDoc(item: SavedInput) {
  const kind = requireOneOf(item.kind, SAVED_KINDS, "kind");
  const id = requireKey(item.id, "id");
  const title = cleanText(item.title).slice(0, 300);
  if (!title) throw new HttpsError("invalid-argument", "Missing title.");
  const json = item.data === undefined ? null : JSON.stringify(item.data);
  if (json && json.length > 30_000) throw new HttpsError("invalid-argument", "Saved item too large.");
  return {
    key: `${kind}_${id}`,
    doc: {
      kind,
      targetId: id,
      title,
      image: item.image ? cleanUrl(item.image) : null,
      url: item.url ? cleanUrl(item.url) : null,
      // A copy of the story or profile so Saved works offline on a new phone.
      data: json,
      savedAt: FieldValue.serverTimestamp(),
    },
  };
}

/** Saves or unsaves an article, startup or founder to the account. */
export const setSaved = callable<SavedInput, { saved: boolean }>(
  { allowRestricted: true },
  async (data, caller) => {
    await rateLimit(caller.uid, "save", [{ max: 60, seconds: 60 }]);
    const saved = data.saved !== false;
    const kind = requireOneOf(data.kind, SAVED_KINDS, "kind");
    const id = requireKey(data.id, "id");
    const ref = db.doc(`users/${caller.uid}/saved/${kind}_${id}`);
    if (!saved) {
      await ref.delete();
      return { saved: false };
    }
    const count = await db.collection(`users/${caller.uid}/saved`).count().get();
    if (count.data().count >= MAX_SAVED) throw new HttpsError("resource-exhausted", `You can save up to ${MAX_SAVED} items.`);
    const { doc } = savedDoc(data);
    await ref.set(doc);
    return { saved: true };
  },
);

/**
 * Uploads items saved on this phone before signing in, so they join the
 * account. Items already in the account are left as they are.
 */
export const importSaved = callable<{ items?: SavedInput[] }, { imported: number }>(
  { allowRestricted: true },
  async (data, caller) => {
    await rateLimit(caller.uid, "import_saved", [{ max: 10, seconds: 3600 }]);
    const items = Array.isArray(data.items) ? data.items.slice(0, 200) : [];
    const col = db.collection(`users/${caller.uid}/saved`);
    const docs = items.map(savedDoc);
    const existing = docs.length
      ? await db.getAll(...docs.map((d) => col.doc(d.key)))
      : [];
    const batch = db.batch();
    let imported = 0;
    docs.forEach((d, i) => {
      if (!existing[i].exists) {
        batch.set(col.doc(d.key), d.doc);
        imported += 1;
      }
    });
    await batch.commit();
    return { imported };
  },
);
