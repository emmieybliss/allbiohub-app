import { callable, db, FieldValue, HttpsError, rateLimit, requirePositiveInt, str } from "./core.js";
import { REACTIONS, type Reaction } from "./validation.js";

/**
 * Sets, changes or removes (reaction: null) the caller's single reaction to
 * an article. One reaction per account per article: the reaction document
 * id is the user id, and counts change in the same transaction.
 */
export const setReaction = callable<{ articleId?: number; reaction?: string | null }, {
  reaction: Reaction | null; counts: Record<Reaction, number>;
}>(
  {},
  async (data, caller) => {
    const articleId = requirePositiveInt(data.articleId, "articleId");
    const wanted = data.reaction == null ? null : str(data.reaction);
    if (wanted !== null && !REACTIONS.includes(wanted as Reaction)) {
      throw new HttpsError("invalid-argument", "Invalid reaction.");
    }
    await rateLimit(caller.uid, "reaction", [{ max: 30, seconds: 60 }, { max: 500, seconds: 86_400 }]);

    const articleRef = db.doc(`articles/${articleId}`);
    const mineRef = articleRef.collection("reactions").doc(caller.uid);
    return db.runTransaction(async (tx) => {
      const [article, mine] = await Promise.all([tx.get(articleRef), tx.get(mineRef)]);
      const previous = mine.exists ? (str(mine.get("reaction")) as Reaction) : null;
      const counts = Object.fromEntries(
        REACTIONS.map((r) => [r, Number(article.get(`reactions.${r}`) ?? 0)]),
      ) as Record<Reaction, number>;
      if (previous === wanted) return { reaction: wanted as Reaction | null, counts };

      if (previous) counts[previous] = Math.max(0, counts[previous] - 1);
      if (wanted) counts[wanted as Reaction] += 1;
      if (wanted) {
        tx.set(mineRef, { uid: caller.uid, reaction: wanted, updatedAt: FieldValue.serverTimestamp() });
      } else {
        tx.delete(mineRef);
      }
      tx.set(articleRef, {
        reactions: counts,
        reactionTotal: REACTIONS.reduce((sum, r) => sum + counts[r], 0),
        lastActivityAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return { reaction: wanted as Reaction | null, counts };
    });
  },
);
