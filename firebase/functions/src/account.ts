import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { defineString } from "firebase-functions/params";
import { callable, db, FieldValue, HttpsError, logger, logModeration, str } from "./core.js";
import { deletionUpdate } from "./comments.js";
import { REACTIONS } from "./validation.js";

/** Comma-separated emails that may become admins (COMMUNITY.md → Admin access). */
const adminEmails = defineString("ADMIN_EMAILS", { default: "" });

async function deleteCollection(path: string): Promise<void> {
  for (;;) {
    const page = await db.collection(path).limit(400).get();
    if (page.empty) return;
    const batch = db.batch();
    page.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

/**
 * Permanently deletes the caller's account: profile, username, settings,
 * follows, saved items, notifications, devices, reactions, likes, votes
 * and pictures. Their comments are emptied and shown as "Deleted"; a
 * comment that others replied to stays as a placeholder so the replies
 * still make sense. Submissions are kept for the newsroom without the
 * person's contact details. Finally the sign-in account itself is deleted.
 *
 * The app asks the person to sign in again just before calling this.
 */
export const deleteAccount = callable<{ confirm?: string }, { deleted: true }>(
  { allowRestricted: true },
  async (data, caller, request) => {
    if (data.confirm !== "DELETE") throw new HttpsError("invalid-argument", "Confirm the deletion first.");
    const authTime = Number(request.auth?.token.auth_time ?? 0) * 1000;
    if (Date.now() - authTime > 10 * 60 * 1000) {
      throw new HttpsError("failed-precondition", "Sign in again to delete your account.", { reason: "recent_login_required" });
    }
    const uid = caller.uid;
    logger.info("Deleting account", { uid });

    // Reactions: undo the counts first.
    const myReactions = await db.collectionGroup("reactions").where("uid", "==", uid).get();
    for (const doc of myReactions.docs) {
      const reaction = str(doc.get("reaction"));
      const articleRef = doc.ref.parent.parent!;
      await db.runTransaction(async (tx) => {
        const article = await tx.get(articleRef);
        const fresh = await tx.get(doc.ref);
        if (!fresh.exists) return;
        if (REACTIONS.includes(reaction as (typeof REACTIONS)[number])) {
          const count = Math.max(0, Number(article.get(`reactions.${reaction}`) ?? 0) - 1);
          tx.set(articleRef, { reactions: { [reaction]: count }, reactionTotal: FieldValue.increment(-1) }, { merge: true });
        }
        tx.delete(doc.ref);
      });
    }

    // Likes and votes.
    for (const group of ["likes", "votes"] as const) {
      const mine = await db.collectionGroup(group).where("uid", "==", uid).get();
      for (const doc of mine.docs) {
        const parentRef = doc.ref.parent.parent!;
        await db.runTransaction(async (tx) => {
          const parent = await tx.get(parentRef);
          const fresh = await tx.get(doc.ref);
          if (!fresh.exists) return;
          if (group === "likes" && parent.exists) {
            tx.update(parentRef, { likeCount: Math.max(0, Number(parent.get("likeCount") ?? 0) - 1) });
          }
          if (group === "votes" && parent.exists) {
            const option = str(fresh.get("optionId"));
            tx.update(parentRef, {
              [`counts.${option}`]: Math.max(0, Number(parent.get(`counts.${option}`) ?? 0) - 1),
              totalVotes: Math.max(0, Number(parent.get("totalVotes") ?? 0) - 1),
            });
          }
          tx.delete(doc.ref);
        });
      }
    }

    // Follows: undo follower counts.
    const follows = await db.collection(`users/${uid}/follows`).get();
    for (const doc of follows.docs) {
      const targetRef = db.doc(`followTargets/${doc.id}`);
      await db.runTransaction(async (tx) => {
        const target = await tx.get(targetRef);
        tx.delete(targetRef.collection("followers").doc(uid));
        if (target.exists) {
          tx.update(targetRef, { followerCount: Math.max(0, Number(target.get("followerCount") ?? 0) - 1) });
        }
      });
    }

    // Comments: empty them (counts follow through onCommentWritten).
    for (;;) {
      const page = await db.collection("comments").where("authorUid", "==", uid).where("deleted", "==", false).limit(200).get();
      if (page.empty) break;
      const batch = db.batch();
      page.docs.forEach((d) => batch.update(d.ref, deletionUpdate(d.data())));
      await batch.commit();
    }

    // Submissions stay with the newsroom, without contact details.
    for (const col of ["storySubmissions", "startupSubmissions", "startupClaims"]) {
      const mine = await db.collection(col).where("submitterUid", "==", uid).get();
      const batch = db.batch();
      mine.docs.forEach((d) => batch.update(d.ref, {
        contactEmail: "", contactPhone: "", companyEmail: "", submitterUsername: null, submitterDeleted: true,
      }));
      await batch.commit();
    }

    for (const sub of ["follows", "saved", "notifications", "devices", "blocks", "mutes"]) {
      await deleteCollection(`users/${uid}/${sub}`);
    }
    const profile = await db.doc(`profiles/${uid}`).get();
    const username = str(profile.get("username"));
    const batch = db.batch();
    if (username) batch.delete(db.doc(`usernames/${username}`));
    batch.delete(db.doc(`profiles/${uid}`));
    batch.delete(db.doc(`users/${uid}`));
    await batch.commit();
    await getStorage().bucket().deleteFiles({ prefix: `avatars/${uid}/` }).catch(() => undefined);
    await getAuth().deleteUser(uid);
    await logModeration(null, { actorUid: uid, action: "account.delete", targetType: "user", targetId: uid });
    return { deleted: true };
  },
);

/**
 * Gives the admin role to a signed-in person whose verified email is in
 * ADMIN_EMAILS. The app signs in again afterwards to pick up the role.
 */
export const claimAdmin = callable<Record<string, never>, { admin: boolean }>(
  { allowRestricted: true },
  async (_data, caller) => {
    const user = await getAuth().getUser(caller.uid);
    const allowed = adminEmails.value().split(",").map((e) => e.trim().toLowerCase()).filter(Boolean);
    const email = (user.email ?? "").toLowerCase();
    if (!user.emailVerified || !email || !allowed.includes(email)) {
      throw new HttpsError("permission-denied", "This account isn't on the admin list.");
    }
    await getAuth().setCustomUserClaims(caller.uid, { ...(user.customClaims ?? {}), admin: true });
    await logModeration(null, { actorUid: caller.uid, action: "admin.claim", targetType: "user", targetId: caller.uid });
    return { admin: true };
  },
);
