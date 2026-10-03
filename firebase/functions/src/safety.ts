import { callable, db, FieldValue, HttpsError, logModeration, rateLimit, requireKey, requireOneOf, str, Timestamp } from "./core.js";
import { getAuth } from "firebase-admin/auth";
import { cleanText, REPORT_REASONS } from "./validation.js";

/**
 * Reports a comment or a person to the moderators. Reported content is
 * never removed automatically; it waits in `reports` for an editor. One
 * report per person per target.
 */
export const reportContent = callable<{ targetType?: string; targetId?: string; reason?: string; details?: string }, { ok: true }>(
  {},
  async (data, caller) => {
    const targetType = requireOneOf(data.targetType, ["comment", "user"] as const, "targetType");
    const targetId = requireKey(data.targetId, "targetId");
    const reason = requireOneOf(data.reason, REPORT_REASONS, "reason");
    const details = cleanText(data.details, true).slice(0, 1000);
    if (targetType === "user" && targetId === caller.uid) {
      throw new HttpsError("invalid-argument", "You can't report yourself.");
    }
    await rateLimit(caller.uid, "report", [{ max: 10, seconds: 3600 }, { max: 30, seconds: 86_400 }]);

    let snapshot: Record<string, unknown> = {};
    if (targetType === "comment") {
      const comment = await db.doc(`comments/${targetId}`).get();
      if (!comment.exists) throw new HttpsError("not-found", "That comment is no longer available.");
      snapshot = {
        body: comment.get("body"),
        authorUid: comment.get("authorUid"),
        articleId: comment.get("articleId"),
      };
    } else {
      const profile = await db.doc(`profiles/${targetId}`).get();
      if (!profile.exists) throw new HttpsError("not-found", "That account is no longer available.");
      snapshot = { username: profile.get("username"), displayName: profile.get("displayName") };
    }

    const ref = db.doc(`reports/${targetType}_${targetId}_${caller.uid}`);
    await ref.set({
      targetType,
      targetId,
      reason,
      details,
      reporterUid: caller.uid,
      snapshot,
      status: "open",
      createdAt: FieldValue.serverTimestamp(),
    });
    return { ok: true };
  },
);

async function setRelation(kind: "blocks" | "mutes", owner: string, other: string, on: boolean) {
  const ref = db.doc(`users/${owner}/${kind}/${other}`);
  if (on) {
    const profile = await db.doc(`profiles/${other}`).get();
    await ref.set({
      username: str(profile.get("username")),
      displayName: str(profile.get("displayName")),
      createdAt: FieldValue.serverTimestamp(),
    });
  } else {
    await ref.delete();
  }
}

/**
 * Blocks or unblocks a person. Their comments are hidden from the caller,
 * their replies and likes no longer notify the caller, and they are not
 * told.
 */
export const blockUser = callable<{ uid?: string; block?: boolean }, { blocked: boolean }>(
  { allowRestricted: true },
  async (data, caller) => {
    const other = requireKey(data.uid, "uid");
    if (other === caller.uid) throw new HttpsError("invalid-argument", "You can't block yourself.");
    await rateLimit(caller.uid, "block", [{ max: 30, seconds: 3600 }]);
    const block = data.block !== false;
    await setRelation("blocks", caller.uid, other, block);
    return { blocked: block };
  },
);

/** Mutes or unmutes a person: their activity stops notifying the caller. */
export const muteUser = callable<{ uid?: string; mute?: boolean }, { muted: boolean }>(
  { allowRestricted: true },
  async (data, caller) => {
    const other = requireKey(data.uid, "uid");
    if (other === caller.uid) throw new HttpsError("invalid-argument", "You can't mute yourself.");
    await rateLimit(caller.uid, "mute", [{ max: 30, seconds: 3600 }]);
    const mute = data.mute !== false;
    await setRelation("mutes", caller.uid, other, mute);
    return { muted: mute };
  },
);

/** Admin: closes a report as actioned or dismissed. */
export const resolveReport = callable<{ reportId?: string; resolution?: string; note?: string }, { ok: true }>(
  { admin: true },
  async (data, caller) => {
    const id = requireKey(data.reportId, "reportId");
    const resolution = requireOneOf(data.resolution, ["actioned", "dismissed"] as const, "resolution");
    await db.runTransaction(async (tx) => {
      const ref = db.doc(`reports/${id}`);
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Report not found.");
      tx.update(ref, { status: resolution, resolvedBy: caller.uid, resolvedAt: FieldValue.serverTimestamp() });
      logModeration(tx, { actorUid: caller.uid, action: `report.${resolution}`, targetType: "report", targetId: id, note: str(data.note) });
    });
    return { ok: true };
  },
);

/**
 * Admin: suspends (for a number of days), bans or reactivates an account.
 * Banned accounts are also disabled in Firebase Auth so they can't sign in.
 */
export const setUserStatus = callable<{ uid?: string; status?: string; days?: number; note?: string }, { ok: true }>(
  { admin: true },
  async (data, caller) => {
    const uid = requireKey(data.uid, "uid");
    const status = requireOneOf(data.status, ["active", "suspended", "banned"] as const, "status");
    const days = Math.min(365, Math.max(1, Math.floor(Number(data.days ?? 7))));
    const until = status === "suspended" ? Timestamp.fromMillis(Date.now() + days * 86_400_000) : null;
    const batch = db.batch();
    batch.set(db.doc(`users/${uid}`), { status, suspendedUntil: until }, { merge: true });
    batch.set(db.doc(`profiles/${uid}`), { status }, { merge: true });
    await batch.commit();
    await getAuth().updateUser(uid, { disabled: status === "banned" });
    if (status !== "active") await getAuth().revokeRefreshTokens(uid);
    await logModeration(null, {
      actorUid: caller.uid, action: `user.${status}`, targetType: "user", targetId: uid,
      note: [str(data.note), until ? `until ${until.toDate().toISOString()}` : ""].filter(Boolean).join(" "),
    });
    return { ok: true };
  },
);
