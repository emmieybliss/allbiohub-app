import { onDocumentWritten } from "firebase-functions/v2/firestore";
import {
  authorSnapshot, callable, db, FieldValue, HttpsError, logModeration, moderationConfig, once, rateLimit, REGION,
  requireKey, requirePositiveInt, requireProfile, str, Timestamp,
} from "./core.js";
import { notify } from "./notifications.js";
import {
  cleanText, COMMENT_MAX, containsBlockedTerm, countLinks, MAX_LINKS_PER_COMMENT, placeReply,
} from "./validation.js";

/** A comment counts towards totals when it's public and not a deleted placeholder. */
export function isVisible(data: FirebaseFirestore.DocumentData | undefined): boolean {
  return !!data && data.status === "approved" && data.deleted !== true;
}

/** Public JSON for a comment returned by the callables. */
function toJson(id: string, data: FirebaseFirestore.DocumentData) {
  const ts = (v: unknown) => (v instanceof Timestamp ? v.toDate().toISOString() : new Date().toISOString());
  return {
    id,
    articleId: data.articleId,
    parentId: data.parentId ?? null,
    rootId: data.rootId ?? null,
    depth: data.depth ?? 0,
    author: data.author,
    replyTo: data.replyTo ?? null,
    body: data.body,
    status: data.status,
    deleted: data.deleted === true,
    likeCount: data.likeCount ?? 0,
    replyCount: data.replyCount ?? 0,
    pinned: data.pinned === true,
    createdAt: ts(data.createdAt),
    editedAt: data.editedAt ? ts(data.editedAt) : null,
  };
}

/** Checks a comment body; returns it cleaned and whether to hold it for review. */
async function checkBody(uid: string, input: unknown): Promise<{ body: string; hold: boolean }> {
  const body = cleanText(input, true);
  if (!body) throw new HttpsError("invalid-argument", "Write a comment first.", { field: "body" });
  if (body.length > COMMENT_MAX) {
    throw new HttpsError("invalid-argument", `Keep comments under ${COMMENT_MAX} characters.`, { field: "body" });
  }
  const links = countLinks(body);
  if (links > MAX_LINKS_PER_COMMENT) {
    throw new HttpsError("invalid-argument", `Use at most ${MAX_LINKS_PER_COMMENT} links in a comment.`, { field: "body" });
  }
  const config = await moderationConfig();
  let hold = config.premoderateComments || containsBlockedTerm(body, config.heldTerms);
  if (!hold && links > 0) {
    const user = await db.doc(`users/${uid}`).get();
    const created = user.get("createdAt") as Timestamp | undefined;
    const ageHours = created ? (Date.now() - created.toMillis()) / 3_600_000 : 0;
    hold = ageHours < config.newAccountHours;
  }
  return { body, hold };
}

/** Posts a comment on an article, or a reply to a comment. */
export const addComment = callable<{ articleId?: number; parentId?: string; body?: string }, ReturnType<typeof toJson>>(
  { verified: true },
  async (data, caller) => {
    const articleId = requirePositiveInt(data.articleId, "articleId");
    const profile = await requireProfile(caller.uid);
    await rateLimit(caller.uid, "comment", [
      { max: 4, seconds: 60 }, { max: 30, seconds: 3600 }, { max: 100, seconds: 86_400 },
    ]);
    const { body, hold } = await checkBody(caller.uid, data.body);

    let placement = { parentId: null as string | null, rootId: null as string | null, depth: 0 };
    let replyTo: { uid: string; username: string } | null = null;
    if (data.parentId) {
      const parentId = requireKey(data.parentId, "parentId");
      const parent = await db.doc(`comments/${parentId}`).get();
      if (!parent.exists || parent.get("status") !== "approved" || parent.get("articleId") !== articleId) {
        throw new HttpsError("not-found", "That comment is no longer available.");
      }
      placement = placeReply({
        id: parent.id,
        depth: Number(parent.get("depth") ?? 0),
        parentId: parent.get("parentId") ?? null,
        rootId: parent.get("rootId") ?? null,
      });
      replyTo = { uid: str(parent.get("authorUid")), username: str(parent.get("author.username")) };
    }

    const ref = db.collection("comments").doc();
    const comment = {
      articleId,
      ...placement,
      authorUid: caller.uid,
      author: authorSnapshot(caller.uid, profile),
      replyTo,
      body,
      status: hold ? "pending" : "approved",
      deleted: false,
      likeCount: 0,
      replyCount: 0,
      pinned: false,
      createdAt: FieldValue.serverTimestamp(),
      editedAt: null,
    };
    await ref.set(comment);
    const saved = await ref.get();
    return toJson(ref.id, saved.data()!);
  },
);

/** Edits the caller's own comment. Edited comments show "edited". */
export const editComment = callable<{ commentId?: string; body?: string }, ReturnType<typeof toJson>>(
  { verified: true },
  async (data, caller) => {
    const id = requireKey(data.commentId, "commentId");
    await rateLimit(caller.uid, "comment_edit", [{ max: 10, seconds: 60 }, { max: 60, seconds: 86_400 }]);
    const { body, hold } = await checkBody(caller.uid, data.body);
    const ref = db.doc(`comments/${id}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.get("authorUid") !== caller.uid || snap.get("deleted") === true) {
        throw new HttpsError("not-found", "That comment is no longer available.");
      }
      const status = str(snap.get("status"));
      if (status === "removed" || status === "rejected") {
        throw new HttpsError("failed-precondition", "This comment was removed by a moderator.");
      }
      tx.update(ref, {
        body,
        editedAt: FieldValue.serverTimestamp(),
        ...(hold && status === "approved" ? { status: "pending" } : {}),
      });
    });
    return toJson(id, (await ref.get()).data()!);
  },
);

/**
 * Deletes the caller's own comment. A comment with replies stays as a
 * "deleted" placeholder so the conversation under it still makes sense.
 */
export const deleteComment = callable<{ commentId?: string }, { ok: true }>(
  { allowRestricted: true },
  async (data, caller) => {
    const id = requireKey(data.commentId, "commentId");
    const ref = db.doc(`comments/${id}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.get("authorUid") !== caller.uid) {
        throw new HttpsError("not-found", "That comment is no longer available.");
      }
      tx.update(ref, deletionUpdate(snap.data()!));
    });
    return { ok: true };
  },
);

/** What a comment becomes when its author deletes it (or their account). */
export function deletionUpdate(data: FirebaseFirestore.DocumentData): Record<string, unknown> {
  const placeholder = data.status === "approved" && Number(data.replyCount ?? 0) > 0;
  return {
    body: "",
    deleted: true,
    deletedAt: FieldValue.serverTimestamp(),
    "author.displayName": "Deleted",
    "author.username": "",
    "author.photoUrl": null,
    ...(placeholder ? {} : { status: "removed", removedBy: "author" }),
  };
}

const LIKE_MILESTONES = new Set([1, 10, 50, 100, 500]);

/** Likes or unlikes a comment (one like per account). */
export const likeComment = callable<{ commentId?: string; like?: boolean }, { liked: boolean; likeCount: number }>(
  {},
  async (data, caller) => {
    const id = requireKey(data.commentId, "commentId");
    const like = data.like !== false;
    await rateLimit(caller.uid, "comment_like", [{ max: 60, seconds: 60 }, { max: 1000, seconds: 86_400 }]);
    const ref = db.doc(`comments/${id}`);
    const mine = ref.collection("likes").doc(caller.uid);
    const result = await db.runTransaction(async (tx) => {
      const [comment, existing] = await Promise.all([tx.get(ref), tx.get(mine)]);
      if (!comment.exists || comment.get("status") !== "approved" || comment.get("deleted") === true) {
        throw new HttpsError("not-found", "That comment is no longer available.");
      }
      let count = Number(comment.get("likeCount") ?? 0);
      if (like && !existing.exists) {
        count += 1;
        tx.set(mine, { uid: caller.uid, createdAt: FieldValue.serverTimestamp() });
        tx.update(ref, { likeCount: count });
      } else if (!like && existing.exists) {
        count = Math.max(0, count - 1);
        tx.delete(mine);
        tx.update(ref, { likeCount: count });
      }
      return {
        liked: like,
        likeCount: count,
        newLike: like && !existing.exists,
        authorUid: str(comment.get("authorUid")),
        articleId: Number(comment.get("articleId")),
      };
    });
    if (result.newLike && result.authorUid !== caller.uid && LIKE_MILESTONES.has(result.likeCount)
      && !(await isBlockedBy(result.authorUid, caller.uid))) {
      await notify(result.authorUid, {
        type: "comment_like",
        pref: "commentActivity",
        title: result.likeCount === 1 ? "Someone liked your comment" : `Your comment has ${result.likeCount} likes`,
        body: "See the conversation on AllBioHub.",
        url: `/article/${result.articleId}/comments?focus=${id}`,
        dedupeKey: `like:${id}:${result.likeCount}`,
      });
    }
    return { liked: result.liked, likeCount: result.likeCount };
  },
);

/** Whether [ownerUid] has blocked [otherUid]. */
export async function isBlockedBy(ownerUid: string, otherUid: string): Promise<boolean> {
  if (!ownerUid || !otherUid) return false;
  return (await db.doc(`users/${ownerUid}/blocks/${otherUid}`).get()).exists;
}

/**
 * Keeps comment counts (article, parent reply count, author total) in step
 * with every status change, whether it came from the app, an admin
 * function or an edit in the Firebase console, and tells people about
 * replies once a reply is public.
 */
export const onCommentWritten = onDocumentWritten({ region: REGION, document: "comments/{commentId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  const delta = (isVisible(after) ? 1 : 0) - (isVisible(before) ? 1 : 0);
  const becamePublic = after?.status === "approved" && before?.status !== "approved" && after?.deleted !== true;
  if (delta === 0 && !becamePublic) return;

  await once(event.id, async () => {
    const data = (after ?? before)!;
    if (delta !== 0) {
      const batch = db.batch();
      batch.set(db.doc(`articles/${data.articleId}`), {
        commentCount: FieldValue.increment(delta),
        lastActivityAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      if (data.parentId) {
        batch.set(db.doc(`comments/${data.parentId}`), { replyCount: FieldValue.increment(delta) }, { merge: true });
      }
      batch.set(db.doc(`profiles/${data.authorUid}`), { commentCount: FieldValue.increment(delta) }, { merge: true });
      await batch.commit();
    }
    if (becamePublic && after?.replyTo?.uid && after.replyTo.uid !== after.authorUid
      && !(await isBlockedBy(after.replyTo.uid, after.authorUid))
      && !(await isMutedBy(after.replyTo.uid, after.authorUid))) {
      const name = str(after.author?.displayName) || "Someone";
      await notify(after.replyTo.uid, {
        type: "comment_reply",
        pref: "commentActivity",
        title: `${name} replied to your comment`,
        body: str(after.body).slice(0, 120),
        url: `/article/${after.articleId}/comments?focus=${event.params.commentId}`,
        dedupeKey: `reply:${event.params.commentId}`,
      });
    }
  });
});

async function isMutedBy(ownerUid: string, otherUid: string): Promise<boolean> {
  return (await db.doc(`users/${ownerUid}/mutes/${otherUid}`).get()).exists;
}

/** Admin actions on a comment. */
export const moderateComment = callable<{ commentId?: string; action?: string; note?: string }, { ok: true }>(
  { admin: true },
  async (data, caller) => {
    const id = requireKey(data.commentId, "commentId");
    const action = str(data.action);
    const updates: Record<string, Record<string, unknown>> = {
      approve: { status: "approved" },
      reject: { status: "rejected" },
      remove: { status: "removed", removedBy: "moderator" },
      hide: { status: "pending" },
      restore: { status: "approved", removedBy: FieldValue.delete() },
      pin: { pinned: true },
      unpin: { pinned: false },
    };
    const update = updates[action];
    if (!update) throw new HttpsError("invalid-argument", "Unknown action.");
    const ref = db.doc(`comments/${id}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Comment not found.");
      tx.update(ref, { ...update, moderatedAt: FieldValue.serverTimestamp(), moderatedBy: caller.uid });
      logModeration(tx, { actorUid: caller.uid, action: `comment.${action}`, targetType: "comment", targetId: id, note: str(data.note) });
    });
    return { ok: true };
  },
);
