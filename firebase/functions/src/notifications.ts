import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { createHash } from "node:crypto";
import { callable, db, FieldValue, HttpsError, logger, requireString, str } from "./core.js";
import { NOTIFICATION_PREFS, type NotificationPref } from "./validation.js";

export type NotificationType =
  | "comment_reply" | "comment_like" | "startup_story" | "founder_story"
  | "topic_story" | "submission_update" | "claim_update" | "moderation";

export interface NotificationInput {
  type: NotificationType;
  /** Preference that controls it (Profile → Notifications). */
  pref: NotificationPref;
  title: string;
  body: string;
  /** allbiohub.com link opened when tapped, or an app path such as /me/submissions. */
  url: string;
  /** Collapses repeats, e.g. one notification per story per person. */
  dedupeKey?: string;
}

/** Whether [uid] wants this kind of notification. */
export function wants(prefs: Record<string, unknown> | undefined, pref: NotificationPref): boolean {
  const value = prefs?.[pref];
  return typeof value === "boolean" ? value : NOTIFICATION_PREFS[pref];
}

/**
 * Adds a notification to a person's notification centre and pushes it to
 * their devices, if their preferences allow. Returns false when skipped.
 */
export async function notify(uid: string, input: NotificationInput): Promise<boolean> {
  const user = await db.doc(`users/${uid}`).get();
  // No settings yet (never chose a username): send with default preferences,
  // unless the account no longer exists.
  if (!user.exists && !(await getAuth().getUser(uid).then(() => true, () => false))) return false;
  if (!wants(user.get("notificationPrefs"), input.pref)) return false;

  const col = db.collection(`users/${uid}/notifications`);
  const ref = input.dedupeKey
    ? col.doc(createHash("sha1").update(input.dedupeKey).digest("hex").slice(0, 24))
    : col.doc();
  try {
    await ref.create({
      type: input.type,
      title: input.title,
      body: input.body,
      url: input.url,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e: unknown) {
    // Already notified about this (dedupeKey).
    if ((e as { code?: number }).code === 6) return false;
    throw e;
  }
  await push(uid, input);
  return true;
}

async function push(uid: string, input: NotificationInput): Promise<void> {
  const devices = await db.collection(`users/${uid}/devices`).limit(10).get();
  const tokens = devices.docs.map((d) => str(d.get("token"))).filter(Boolean);
  if (tokens.length === 0) return;
  try {
    const result = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: input.title, body: input.body },
      data: { url: input.url, type: input.type },
      android: { priority: "normal" },
    });
    const stale = result.responses
      .map((r, i) => ({ r, doc: devices.docs[i] }))
      .filter(({ r }) =>
        !r.success &&
        ["messaging/registration-token-not-registered", "messaging/invalid-registration-token"]
          .includes(r.error?.code ?? ""));
    await Promise.all(stale.map(({ doc }) => doc.ref.delete()));
  } catch (e) {
    logger.warn("Push failed", { uid, error: String(e) });
  }
}

function tokenId(token: string): string {
  return createHash("sha256").update(token).digest("hex").slice(0, 40);
}

/** Stores this device's push token so personal notifications reach it. */
export const registerDevice = callable<{ token?: string; platform?: string }, { ok: true }>(
  { allowRestricted: true },
  async (data, caller) => {
    const token = requireString(data.token, "token", { max: 4096 });
    const platform = str(data.platform) === "ios" ? "ios" : "android";
    await db.doc(`users/${caller.uid}/devices/${tokenId(token)}`).set({
      token,
      platform,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { ok: true };
  },
);

/** Forgets this device's token (on sign-out). */
export const unregisterDevice = callable<{ token?: string }, { ok: true }>(
  { allowRestricted: true },
  async (data, caller) => {
    const token = requireString(data.token, "token", { max: 4096 });
    await db.doc(`users/${caller.uid}/devices/${tokenId(token)}`).delete();
    return { ok: true };
  },
);

/** Marks every unread notification as read. */
export const markAllNotificationsRead = callable<Record<string, never>, { updated: number }>(
  { allowRestricted: true },
  async (_data, caller) => {
    const unread = await db
      .collection(`users/${caller.uid}/notifications`)
      .where("read", "==", false)
      .limit(400)
      .get();
    const batch = db.batch();
    unread.docs.forEach((d) => batch.update(d.ref, { read: true }));
    await batch.commit();
    return { updated: unread.size };
  },
);

/** Saves notification preferences (validated against the known keys). */
export const updateNotificationPrefs = callable<{ prefs?: Record<string, unknown> }, { prefs: Record<string, boolean> }>(
  { allowRestricted: true },
  async (data, caller) => {
    const input = data.prefs;
    if (!input || typeof input !== "object") throw new HttpsError("invalid-argument", "Invalid preferences.");
    const prefs: Record<string, boolean> = {};
    for (const key of Object.keys(NOTIFICATION_PREFS) as NotificationPref[]) {
      if (typeof input[key] === "boolean") prefs[key] = input[key] as boolean;
    }
    const ref = db.doc(`users/${caller.uid}`);
    await ref.set({ notificationPrefs: prefs }, { merge: true });
    const saved = (await ref.get()).get("notificationPrefs") as Record<string, boolean>;
    return { prefs: saved };
  },
);
