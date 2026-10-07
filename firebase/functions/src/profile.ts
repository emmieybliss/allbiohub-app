import { getAuth } from "firebase-admin/auth";
import { getStorage, getDownloadURL } from "firebase-admin/storage";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import {
  callable, db, FieldValue, HttpsError, moderationConfig, rateLimit, REGION, requireProfile, str, Timestamp,
} from "./core.js";
import {
  BIO_MAX, cleanText, countLinks, DISPLAY_NAME_MAX, normalizeUsername, USERNAME_MESSAGES, usernameProblem,
} from "./validation.js";

const USERNAME_CHANGE_DAYS = 30;

async function assertUsernameAllowed(name: string): Promise<void> {
  const config = await moderationConfig();
  const problem = usernameProblem(name, config.blockedUsernameTerms);
  if (problem) {
    throw new HttpsError("invalid-argument", USERNAME_MESSAGES[problem], { field: "username", reason: problem });
  }
}

function cleanDisplayName(input: unknown): string {
  const name = cleanText(input).slice(0, DISPLAY_NAME_MAX).trim();
  if (!name) throw new HttpsError("invalid-argument", "Enter your name.", { field: "displayName" });
  if (countLinks(name) > 0) {
    throw new HttpsError("invalid-argument", "Names can't contain links.", { field: "displayName" });
  }
  return name;
}

/** Whether a username can be taken, with the reason when not. */
export const checkUsername = callable<{ username?: string }, {
  username: string; available: boolean; message: string | null;
}>(
  {},
  async (data, caller) => {
    await rateLimit(caller.uid, "check_username", [{ max: 40, seconds: 60 }]);
    const name = normalizeUsername(data.username);
    const config = await moderationConfig();
    const problem = usernameProblem(name, config.blockedUsernameTerms);
    if (problem) return { username: name, available: false, message: USERNAME_MESSAGES[problem] };
    const taken = await db.doc(`usernames/${name}`).get();
    const mine = taken.exists && taken.get("uid") === caller.uid;
    return {
      username: name,
      available: !taken.exists || mine,
      message: taken.exists && !mine ? "That username is taken." : null,
    };
  },
);

/** First-time setup after signing in: claims a username and creates the profile. */
export const createProfile = callable<{ username?: string; displayName?: string }, { username: string }>(
  {},
  async (data, caller) => {
    await rateLimit(caller.uid, "create_profile", [{ max: 10, seconds: 3600 }]);
    const name = normalizeUsername(data.username);
    await assertUsernameAllowed(name);
    const authUser = await getAuth().getUser(caller.uid);
    const displayName = cleanDisplayName(data.displayName || authUser.displayName || name);

    await db.runTransaction(async (tx) => {
      const profileRef = db.doc(`profiles/${caller.uid}`);
      const nameRef = db.doc(`usernames/${name}`);
      const [profile, taken] = await Promise.all([tx.get(profileRef), tx.get(nameRef)]);
      if (profile.exists) throw new HttpsError("already-exists", "Your profile already exists.");
      if (taken.exists) {
        throw new HttpsError("already-exists", "That username is taken.", { field: "username", reason: "taken" });
      }
      const now = FieldValue.serverTimestamp();
      tx.set(nameRef, { uid: caller.uid, createdAt: now });
      tx.set(profileRef, {
        username: name,
        displayName,
        bio: "",
        photoUrl: authUser.photoURL ?? null,
        visibility: "public",
        showActivity: true,
        joinedAt: now,
        followingCount: 0,
        commentCount: 0,
        badges: [],
        status: "active",
      });
      tx.set(db.doc(`users/${caller.uid}`), {
        status: "active",
        createdAt: now,
        usernameChangedAt: now,
      }, { merge: true });
    });
    return { username: name };
  },
);

/** Edits name, bio, picture and privacy settings. */
export const updateProfile = callable<{
  displayName?: string; bio?: string; photoPath?: string | null;
  visibility?: string; showActivity?: boolean;
}, { ok: true }>(
  {},
  async (data, caller) => {
    await rateLimit(caller.uid, "update_profile", [{ max: 20, seconds: 3600 }]);
    await requireProfile(caller.uid);
    const update: Record<string, unknown> = {};
    if (data.displayName !== undefined) update.displayName = cleanDisplayName(data.displayName);
    if (data.bio !== undefined) {
      const bio = cleanText(data.bio);
      if (bio.length > BIO_MAX) {
        throw new HttpsError("invalid-argument", `Keep your bio under ${BIO_MAX} characters.`, { field: "bio" });
      }
      if (countLinks(bio) > 1) throw new HttpsError("invalid-argument", "Use at most one link in your bio.", { field: "bio" });
      update.bio = bio;
    }
    if (data.visibility !== undefined) {
      if (data.visibility !== "public" && data.visibility !== "private") {
        throw new HttpsError("invalid-argument", "Invalid visibility.");
      }
      update.visibility = data.visibility;
    }
    if (data.showActivity !== undefined) update.showActivity = data.showActivity === true;
    if (data.photoPath === null) {
      update.photoUrl = null;
    } else if (data.photoPath !== undefined) {
      const path = str(data.photoPath);
      if (!new RegExp(`^avatars/${caller.uid}/[A-Za-z0-9_.-]{1,80}$`).test(path)) {
        throw new HttpsError("invalid-argument", "Invalid picture.");
      }
      const file = getStorage().bucket().file(path);
      const [meta] = await file.getMetadata();
      if (!/^image\/(jpeg|png|webp)$/.test(str(meta.contentType)) || Number(meta.size) > 5 * 1024 * 1024) {
        throw new HttpsError("invalid-argument", "Use a JPEG, PNG or WebP image under 5 MB.");
      }
      update.photoUrl = await getDownloadURL(file);
    }
    if (Object.keys(update).length > 0) await db.doc(`profiles/${caller.uid}`).update(update);
    return { ok: true };
  },
);

/** Changes the username, at most once every 30 days. The old name is freed. */
export const changeUsername = callable<{ username?: string }, { username: string }>(
  {},
  async (data, caller) => {
    await rateLimit(caller.uid, "change_username", [{ max: 5, seconds: 3600 }]);
    const name = normalizeUsername(data.username);
    await assertUsernameAllowed(name);
    await db.runTransaction(async (tx) => {
      const profileRef = db.doc(`profiles/${caller.uid}`);
      const userRef = db.doc(`users/${caller.uid}`);
      const nameRef = db.doc(`usernames/${name}`);
      const [profile, user, taken] = await Promise.all([tx.get(profileRef), tx.get(userRef), tx.get(nameRef)]);
      if (!profile.exists) throw new HttpsError("failed-precondition", "Choose a username first.");
      const current = str(profile.get("username"));
      if (current === name) return;
      if (taken.exists) throw new HttpsError("already-exists", "That username is taken.", { field: "username" });
      const changed = user.get("usernameChangedAt") as Timestamp | undefined;
      if (changed && Date.now() - changed.toMillis() < USERNAME_CHANGE_DAYS * 86_400_000) {
        const next = new Date(changed.toMillis() + USERNAME_CHANGE_DAYS * 86_400_000);
        throw new HttpsError("failed-precondition",
          `You can change your username again on ${next.toDateString()}.`, { reason: "too_soon", next: next.toISOString() });
      }
      tx.delete(db.doc(`usernames/${current}`));
      tx.set(nameRef, { uid: caller.uid, createdAt: FieldValue.serverTimestamp() });
      tx.update(profileRef, { username: name });
      tx.set(userRef, { usernameChangedAt: FieldValue.serverTimestamp() }, { merge: true });
    });
    return { username: name };
  },
);

/**
 * Keeps the author name and picture on a person's recent comments in step
 * with their profile, so comment lists need no extra reads.
 */
export const onProfileUpdated = onDocumentUpdated({ region: REGION, document: "profiles/{uid}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const changed = ["username", "displayName", "photoUrl"].some((k) => before[k] !== after[k]);
  if (!changed) return;
  const uid = event.params.uid;
  const comments = await db.collection("comments")
    .where("authorUid", "==", uid)
    .orderBy("createdAt", "desc")
    .limit(500)
    .get();
  const batch = db.batch();
  comments.docs.forEach((doc) => batch.update(doc.ref, {
    "author.username": after.username,
    "author.displayName": after.displayName,
    "author.photoUrl": after.photoUrl ?? null,
  }));
  await batch.commit();
});
