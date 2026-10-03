import { onSchedule } from "firebase-functions/v2/scheduler";
import { callable, db, FieldValue, HttpsError, logModeration, rateLimit, REGION, requireKey, str, Timestamp } from "./core.js";
import { cleanText } from "./validation.js";

export type PollStatus = "draft" | "scheduled" | "active" | "closed";

/** Votes once (or changes the vote, when the poll allows it). */
export const votePoll = callable<{ pollId?: string; optionId?: string }, {
  optionId: string; counts: Record<string, number>; totalVotes: number;
}>(
  {},
  async (data, caller) => {
    const pollId = requireKey(data.pollId, "pollId");
    const optionId = requireKey(data.optionId, "optionId");
    await rateLimit(caller.uid, "poll_vote", [{ max: 20, seconds: 60 }]);
    const pollRef = db.doc(`polls/${pollId}`);
    const voteRef = pollRef.collection("votes").doc(caller.uid);
    return db.runTransaction(async (tx) => {
      const [poll, vote] = await Promise.all([tx.get(pollRef), tx.get(voteRef)]);
      if (!poll.exists || poll.get("status") !== "active") {
        throw new HttpsError("failed-precondition", "This poll is closed.");
      }
      const now = Date.now();
      const expires = poll.get("expiresAt") as Timestamp | null;
      if (expires && expires.toMillis() <= now) throw new HttpsError("failed-precondition", "This poll is closed.");
      const options = (poll.get("options") as Array<{ id: string }> | undefined) ?? [];
      if (!options.some((o) => o.id === optionId)) throw new HttpsError("invalid-argument", "Invalid option.");

      const counts = { ...((poll.get("counts") as Record<string, number> | undefined) ?? {}) };
      let total = Number(poll.get("totalVotes") ?? 0);
      const previous = vote.exists ? str(vote.get("optionId")) : null;
      if (previous === optionId) return { optionId, counts, totalVotes: total };
      if (previous) {
        if (poll.get("allowChange") !== true) {
          throw new HttpsError("failed-precondition", "You've already voted in this poll.", { reason: "already_voted" });
        }
        counts[previous] = Math.max(0, (counts[previous] ?? 0) - 1);
      } else {
        total += 1;
      }
      counts[optionId] = (counts[optionId] ?? 0) + 1;
      tx.set(voteRef, { uid: caller.uid, optionId, updatedAt: FieldValue.serverTimestamp() });
      tx.update(pollRef, { counts, totalVotes: total });
      return { optionId, counts, totalVotes: total };
    });
  },
);

interface PollInput {
  pollId?: string;
  kind?: string;
  question?: string;
  options?: string[];
  allowChange?: boolean;
  publishAt?: string;
  expiresAt?: string | null;
  articleId?: number | null;
  status?: string;
}

/**
 * Admin: creates or edits a poll or Question of the Day. Options can't be
 * changed once anyone has voted.
 */
export const savePoll = callable<PollInput, { pollId: string }>(
  { admin: true },
  async (data, caller) => {
    const kind = data.kind === "qotd" ? "qotd" : "poll";
    const question = cleanText(data.question).slice(0, 200);
    if (question.length < 5) throw new HttpsError("invalid-argument", "Write the question.");
    const labels = (Array.isArray(data.options) ? data.options : []).map((o) => cleanText(o).slice(0, 80)).filter(Boolean);
    if (labels.length < 2 || labels.length > 6) throw new HttpsError("invalid-argument", "Give 2 to 6 options.");
    const publishAt = data.publishAt ? new Date(data.publishAt) : new Date();
    const expiresAt = data.expiresAt ? new Date(data.expiresAt) : null;
    if (Number.isNaN(publishAt.getTime()) || (expiresAt && Number.isNaN(expiresAt.getTime()))) {
      throw new HttpsError("invalid-argument", "Invalid date.");
    }
    if (expiresAt && expiresAt <= publishAt) throw new HttpsError("invalid-argument", "The end must be after the start.");
    const wantedStatus = data.status === "draft" ? "draft" : publishAt.getTime() <= Date.now() ? "active" : "scheduled";

    const ref = data.pollId ? db.doc(`polls/${requireKey(data.pollId, "pollId")}`) : db.collection("polls").doc();
    await db.runTransaction(async (tx) => {
      const existing = await tx.get(ref);
      const voted = Number(existing.get("totalVotes") ?? 0) > 0;
      const options = labels.map((label, i) => ({ id: `o${i + 1}`, label }));
      if (voted) {
        const before = JSON.stringify(existing.get("options"));
        if (before !== JSON.stringify(options)) {
          throw new HttpsError("failed-precondition", "Options can't change after people have voted.");
        }
      }
      tx.set(ref, {
        kind,
        question,
        options,
        allowChange: data.allowChange === true,
        publishAt: Timestamp.fromDate(publishAt),
        expiresAt: expiresAt ? Timestamp.fromDate(expiresAt) : null,
        articleId: typeof data.articleId === "number" && data.articleId > 0 ? data.articleId : null,
        status: wantedStatus,
        ...(existing.exists ? {} : { counts: {}, totalVotes: 0, createdAt: FieldValue.serverTimestamp(), createdBy: caller.uid }),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      logModeration(tx, { actorUid: caller.uid, action: existing.exists ? "poll.update" : "poll.create", targetType: "poll", targetId: ref.id });
    });
    if (wantedStatus === "active" && kind === "qotd") await closeOtherQuestions(ref.id);
    return { pollId: ref.id };
  },
);

/** Admin: closes a poll now. */
export const closePoll = callable<{ pollId?: string }, { ok: true }>(
  { admin: true },
  async (data, caller) => {
    const id = requireKey(data.pollId, "pollId");
    await db.doc(`polls/${id}`).update({ status: "closed", closedAt: FieldValue.serverTimestamp() });
    await logModeration(null, { actorUid: caller.uid, action: "poll.close", targetType: "poll", targetId: id });
    return { ok: true };
  },
);

/** Only one Question of the Day is open at a time: the newest one. */
async function closeOtherQuestions(keepId: string): Promise<void> {
  const open = await db.collection("polls").where("kind", "==", "qotd").where("status", "==", "active").get();
  const batch = db.batch();
  open.docs.filter((d) => d.id !== keepId)
    .forEach((d) => batch.update(d.ref, { status: "closed", closedAt: FieldValue.serverTimestamp() }));
  await batch.commit();
}

/** Opens scheduled polls and closes expired ones, every 15 minutes. */
export const updatePollStatuses = onSchedule({ region: REGION, schedule: "every 15 minutes" }, async () => {
  const now = Timestamp.now();
  const due = await db.collection("polls").where("status", "==", "scheduled").where("publishAt", "<=", now).get();
  for (const doc of due.docs) {
    await doc.ref.update({ status: "active" });
    if (doc.get("kind") === "qotd") await closeOtherQuestions(doc.id);
  }
  const expired = await db.collection("polls").where("status", "==", "active").where("expiresAt", "<=", now).get();
  const batch = db.batch();
  expired.docs.forEach((d) => batch.update(d.ref, { status: "closed", closedAt: FieldValue.serverTimestamp() }));
  await batch.commit();
});
