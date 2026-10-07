import { after, before, describe, test } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";
import { adminDb, errorCode, eventually, fakeSite, newUser, withProfile } from "./helpers.js";

let site: Server;
before(async () => { site = await fakeSite(); });
after(() => { site.close(); });

describe("accounts and usernames", () => {
  test("a username is claimed once, normalized, and validated on the server", async () => {
    const a = await newUser();
    const b = await newUser();
    await a.call("createProfile", { username: "@TechLover", displayName: "Tech Lover" });
    const profile = await adminDb.doc(`profiles/${a.uid}`).get();
    assert.equal(profile.get("username"), "techlover");
    assert.equal(profile.get("visibility"), "public");
    assert.equal(await errorCode(b.call("createProfile", { username: "techlover" })), "functions/already-exists");
    assert.equal(await errorCode(b.call("createProfile", { username: "admin" })), "functions/invalid-argument");
    assert.equal(await errorCode(b.call("createProfile", { username: "x" })), "functions/invalid-argument");
    const check = await b.call<{ available: boolean; message: string }>("checkUsername", { username: "TECHLOVER" });
    assert.equal(check.available, false);
    await Promise.all([a.close(), b.close()]);
  });

  test("username changes are limited to once every 30 days", async () => {
    const a = await newUser();
    await withProfile(a, `first${Date.now() % 100000}`);
    assert.equal(await errorCode(a.call("changeUsername", { username: `second${Date.now() % 100000}` })), "functions/failed-precondition");
    await a.close();
  });

  test("profile edits are validated", async () => {
    const a = await newUser();
    await withProfile(a, `bio${Date.now() % 100000}`);
    await a.call("updateProfile", { bio: "Technology enthusiast", visibility: "private" });
    const profile = await adminDb.doc(`profiles/${a.uid}`).get();
    assert.equal(profile.get("bio"), "Technology enthusiast");
    assert.equal(profile.get("visibility"), "private");
    assert.equal(await errorCode(a.call("updateProfile", { bio: "x".repeat(200) })), "functions/invalid-argument");
    assert.equal(await errorCode(a.call("updateProfile", { photoPath: "avatars/someone-else/a.jpg" })), "functions/invalid-argument");
    await a.close();
  });

  test("guests can't take community actions", async () => {
    const { initializeApp } = await import("firebase/app");
    const { getFunctions, connectFunctionsEmulator, httpsCallable } = await import("firebase/functions");
    const app = initializeApp({ projectId: "demo-allbiohub", apiKey: "k" }, "guest");
    const fns = getFunctions(app, "europe-west1");
    connectFunctionsEmulator(fns, "127.0.0.1", 5001);
    assert.equal(await errorCode(httpsCallable(fns, "setReaction")({ articleId: 1, reaction: "love" })), "functions/unauthenticated");
    assert.equal(await errorCode(httpsCallable(fns, "addComment")({ articleId: 1, body: "hi" })), "functions/unauthenticated");
  });
});

describe("reactions", () => {
  test("one reaction per account, changeable and removable, with real counts", async () => {
    const a = await newUser();
    const b = await newUser();
    const article = 900_000 + (Date.now() % 1000);
    await a.call("setReaction", { articleId: article, reaction: "love" });
    await a.call("setReaction", { articleId: article, reaction: "love" });
    await b.call("setReaction", { articleId: article, reaction: "love" });
    let doc = await adminDb.doc(`articles/${article}`).get();
    assert.equal(doc.get("reactions.love"), 2);
    await a.call("setReaction", { articleId: article, reaction: "wow" });
    doc = await adminDb.doc(`articles/${article}`).get();
    assert.equal(doc.get("reactions.love"), 1);
    assert.equal(doc.get("reactions.wow"), 1);
    await a.call("setReaction", { articleId: article, reaction: null });
    doc = await adminDb.doc(`articles/${article}`).get();
    assert.equal(doc.get("reactions.wow"), 0);
    assert.equal(doc.get("reactionTotal"), 1);
    assert.equal(await errorCode(a.call("setReaction", { articleId: article, reaction: "angry" })), "functions/invalid-argument");
    await Promise.all([a.close(), b.close()]);
  });
});

describe("comments", () => {
  test("commenting needs a verified email and a username", async () => {
    const unverified = await newUser();
    await withProfile(unverified, `unv${Date.now() % 100000}`);
    assert.equal(await errorCode(unverified.call("addComment", { articleId: 1, body: "Hello" })), "functions/failed-precondition");
    const noProfile = await newUser({ verified: true });
    assert.equal(await errorCode(noProfile.call("addComment", { articleId: 1, body: "Hello" })), "functions/failed-precondition");
    await Promise.all([unverified.close(), noProfile.close()]);
  });

  test("comments, replies, likes, counts and notifications", async () => {
    const a = await newUser({ verified: true });
    const b = await newUser({ verified: true });
    await withProfile(a, `usera${Date.now() % 100000}`);
    await withProfile(b, `userb${Date.now() % 100000}`);
    const article = 800_000 + (Date.now() % 1000);

    const top = await a.call<{ id: string; status: string; depth: number }>("addComment", {
      articleId: article, body: "What do you think about this startup?",
    });
    assert.equal(top.status, "approved");
    assert.equal(top.depth, 0);
    const reply = await b.call<{ id: string; depth: number; parentId: string }>("addComment", {
      articleId: article, parentId: top.id, body: "I think their product is interesting.",
    });
    assert.equal(reply.depth, 1);
    const reply2 = await a.call<{ id: string; depth: number; parentId: string }>("addComment", {
      articleId: article, parentId: reply.id, body: "Agreed.",
    });
    assert.equal(reply2.depth, 2);
    const reply3 = await b.call<{ depth: number; parentId: string; rootId: string }>("addComment", {
      articleId: article, parentId: reply2.id, body: "Same here.",
    });
    assert.equal(reply3.depth, 2, "no deeper than two levels");
    assert.equal(reply3.parentId, reply.id);
    assert.equal(reply3.rootId, top.id);

    await eventually(async () => {
      const doc = await adminDb.doc(`articles/${article}`).get();
      assert.equal(doc.get("commentCount"), 4);
      const topDoc = await adminDb.doc(`comments/${top.id}`).get();
      assert.equal(topDoc.get("replyCount"), 1);
      const notes = await adminDb.collection(`users/${a.uid}/notifications`).where("type", "==", "comment_reply").get();
      assert.ok(notes.size >= 1);
    });

    const like = await b.call<{ liked: boolean; likeCount: number }>("likeComment", { commentId: top.id, like: true });
    assert.deepEqual(like, { liked: true, likeCount: 1 });
    const again = await b.call<{ likeCount: number }>("likeComment", { commentId: top.id, like: true });
    assert.equal(again.likeCount, 1, "one like per account");

    assert.equal(await errorCode(b.call("editComment", { commentId: top.id, body: "hijack" })), "functions/not-found");
    await a.call("editComment", { commentId: top.id, body: "What do you think about this startup now?" });
    assert.ok((await adminDb.doc(`comments/${top.id}`).get()).get("editedAt"));

    // A comment with replies stays as a placeholder when deleted.
    await a.call("deleteComment", { commentId: top.id });
    const deleted = await adminDb.doc(`comments/${top.id}`).get();
    assert.equal(deleted.get("deleted"), true);
    assert.equal(deleted.get("body"), "");
    assert.equal(deleted.get("status"), "approved");
    await eventually(async () => {
      assert.equal((await adminDb.doc(`articles/${article}`).get()).get("commentCount"), 3);
    });

    await b.call("reportContent", { targetType: "comment", targetId: reply2.id, reason: "spam" });
    const report = await adminDb.doc(`reports/comment_${reply2.id}_${b.uid}`).get();
    assert.equal(report.get("status"), "open");
    assert.equal((await adminDb.doc(`comments/${reply2.id}`).get()).get("status"), "approved", "reports never remove content");
    await Promise.all([a.close(), b.close()]);
  });

  test("blocked people don't notify the person who blocked them", async () => {
    const a = await newUser({ verified: true });
    const b = await newUser({ verified: true });
    await withProfile(a, `blka${Date.now() % 100000}`);
    await withProfile(b, `blkb${Date.now() % 100000}`);
    await a.call("blockUser", { uid: b.uid, block: true });
    const top = await a.call<{ id: string }>("addComment", { articleId: 7, body: "Thoughts?" });
    const reply = await b.call<{ id: string }>("addComment", { articleId: 7, parentId: top.id, body: "Mine." });
    await new Promise((r) => setTimeout(r, 2000));
    const notes = await adminDb.collection(`users/${a.uid}/notifications`).get();
    assert.ok(!notes.docs.some((d) => String(d.get("url")).includes(reply.id)));
    await Promise.all([a.close(), b.close()]);
  });

  test("moderators can remove and restore; normal users can't", async () => {
    const a = await newUser({ verified: true });
    const editor = await newUser({ admin: true });
    await withProfile(a, `moda${Date.now() % 100000}`);
    const article = 700_000 + (Date.now() % 1000);
    const c = await a.call<{ id: string }>("addComment", { articleId: article, body: "Buy my stuff" });
    assert.equal(await errorCode(a.call("moderateComment", { commentId: c.id, action: "remove" })), "functions/permission-denied");
    await editor.call("moderateComment", { commentId: c.id, action: "remove" });
    assert.equal((await adminDb.doc(`comments/${c.id}`).get()).get("status"), "removed");
    await eventually(async () => {
      assert.equal((await adminDb.doc(`articles/${article}`).get()).get("commentCount"), 0);
    });
    await editor.call("moderateComment", { commentId: c.id, action: "restore" });
    await eventually(async () => {
      assert.equal((await adminDb.doc(`articles/${article}`).get()).get("commentCount"), 1);
    });
    await Promise.all([a.close(), editor.close()]);
  });

  test("suspended accounts can't comment", async () => {
    const a = await newUser({ verified: true });
    const editor = await newUser({ admin: true });
    await withProfile(a, `susp${Date.now() % 100000}`);
    await editor.call("setUserStatus", { uid: a.uid, status: "suspended", days: 3 });
    const code = await errorCode(a.call("addComment", { articleId: 1, body: "hello" }));
    assert.equal(code, "functions/permission-denied");
    await Promise.all([a.close(), editor.close()]);
  });

  test("comments are rate limited", async () => {
    const a = await newUser({ verified: true });
    await withProfile(a, `rate${Date.now() % 100000}`);
    const codes: string[] = [];
    for (let i = 0; i < 5; i++) codes.push(await errorCode(a.call("addComment", { articleId: 5, body: `comment ${i}` })));
    assert.equal(codes.filter((c) => c === "functions/resource-exhausted").length, 1);
    await a.close();
  });
});

describe("follows", () => {
  test("startups and topics are followed with their real names", async () => {
    const a = await newUser();
    await withProfile(a, `fol${Date.now() % 100000}`);
    const r = await a.call<{ following: boolean; followerCount: number }>("setFollow", {
      kind: "startup", id: "moniepoint", label: "Fake name", follow: true,
    });
    assert.equal(r.following, true);
    const mine = await adminDb.doc(`users/${a.uid}/follows/startup_moniepoint`).get();
    assert.equal(mine.get("label"), "Moniepoint", "name comes from the site, not the app");
    await a.call("setFollow", { kind: "topic", id: "money-career", follow: true });
    assert.equal((await adminDb.doc(`users/${a.uid}/follows/topic_money-career`).get()).get("label"), "Money & Career");
    assert.equal((await adminDb.doc(`profiles/${a.uid}`).get()).get("followingCount"), 2);
    assert.equal(await errorCode(a.call("setFollow", { kind: "startup", id: "not-real", follow: true })), "functions/not-found");
    assert.equal(await errorCode(a.call("setFollow", { kind: "founder", id: "x-y", label: "Someone Else", follow: true })), "functions/invalid-argument");
    await a.call("setFollow", { kind: "startup", id: "moniepoint", follow: false });
    assert.equal((await adminDb.doc(`users/${a.uid}/follows/startup_moniepoint`).get()).exists, false);
    assert.equal((await adminDb.doc(`profiles/${a.uid}`).get()).get("followingCount"), 1);
    await a.close();
  });

  test("saved items sync to the account", async () => {
    const a = await newUser();
    await a.call("importSaved", { items: [
      { kind: "article", id: "123", title: "A story", url: "https://allbiohub.com/a-story/" },
      { kind: "startup", id: "moniepoint", title: "Moniepoint" },
    ] });
    await a.call("setSaved", { kind: "founder", id: "tosin-eniolorunda", title: "Tosin Eniolorunda", saved: true });
    const saved = await adminDb.collection(`users/${a.uid}/saved`).get();
    assert.equal(saved.size, 3);
    await a.close();
  });
});

describe("polls", () => {
  test("editors publish polls; people vote once; voters stay private", async () => {
    const editor = await newUser({ admin: true });
    const a = await newUser();
    const b = await newUser();
    assert.equal(await errorCode(a.call("savePoll", { question: "Hack?", options: ["a", "b"] })), "functions/permission-denied");
    const { pollId } = await editor.call<{ pollId: string }>("savePoll", {
      question: "What technology will have the biggest impact on African fintech?",
      options: ["AI", "Blockchain", "Open Banking", "Embedded Finance"],
    });
    const r1 = await a.call<{ counts: Record<string, number>; totalVotes: number }>("votePoll", { pollId, optionId: "o1" });
    assert.equal(r1.totalVotes, 1);
    await b.call("votePoll", { pollId, optionId: "o3" });
    assert.equal(await errorCode(a.call("votePoll", { pollId, optionId: "o2" })), "functions/failed-precondition");
    assert.equal(await errorCode(a.call("votePoll", { pollId, optionId: "o9" })), "functions/invalid-argument");
    const poll = await adminDb.doc(`polls/${pollId}`).get();
    assert.equal(poll.get("totalVotes"), 2);
    assert.deepEqual(poll.get("counts"), { o1: 1, o3: 1 });
    assert.equal(await errorCode(editor.call("savePoll", { pollId, question: "Changed question here", options: ["x", "y"] })), "functions/failed-precondition");
    await Promise.all([editor.close(), a.close(), b.close()]);
  });

  test("only the newest Question of the Day stays open", async () => {
    const editor = await newUser({ admin: true });
    const first = await editor.call<{ pollId: string }>("savePoll", { kind: "qotd", question: "Which city first?", options: ["Lagos", "Nairobi"] });
    const second = await editor.call<{ pollId: string }>("savePoll", { kind: "qotd", question: "Which city next?", options: ["Cairo", "Kigali"] });
    assert.equal((await adminDb.doc(`polls/${first.pollId}`).get()).get("status"), "closed");
    assert.equal((await adminDb.doc(`polls/${second.pollId}`).get()).get("status"), "active");
    await editor.close();
  });

  test("polls that allow it let people change their vote", async () => {
    const editor = await newUser({ admin: true });
    const a = await newUser();
    const { pollId } = await editor.call<{ pollId: string }>("savePoll", { question: "Change allowed?", options: ["Yes", "No"], allowChange: true });
    await a.call("votePoll", { pollId, optionId: "o1" });
    const r = await a.call<{ counts: Record<string, number>; totalVotes: number }>("votePoll", { pollId, optionId: "o2" });
    assert.deepEqual(r.counts, { o1: 0, o2: 1 });
    assert.equal(r.totalVotes, 1);
    await Promise.all([editor.close(), a.close()]);
  });
});

describe("submissions", () => {
  test("a story submission waits for review and the sender hears about status changes", async () => {
    const a = await newUser({ verified: true });
    const editor = await newUser({ admin: true });
    const result = await a.call<{ id: string; message: string }>("submitStory", {
      type: "funding", title: "Startup X raises $2m", description: "A seed round led by a Lagos fund, announced today.",
      category: "Startups", sourceUrl: "example.com/news",
    });
    assert.equal(result.message, "Your submission has been received and is awaiting editorial review.");
    const doc = await adminDb.doc(`storySubmissions/${result.id}`).get();
    assert.equal(doc.get("status"), "submitted");
    assert.equal(doc.get("sourceUrl"), "https://example.com/news");
    assert.equal(await errorCode(a.call("reviewSubmission", { collection: "storySubmissions", id: result.id, status: "published" })), "functions/permission-denied");
    await editor.call("reviewSubmission", { collection: "storySubmissions", id: result.id, status: "accepted", note: "Thanks!" });
    await eventually(async () => {
      const notes = await adminDb.collection(`users/${a.uid}/notifications`).where("type", "==", "submission_update").get();
      assert.equal(notes.size, 1);
      assert.match(String(notes.docs[0].get("title")), /was accepted/);
    });
    await Promise.all([a.close(), editor.close()]);
  });

  test("startup submissions and claims are validated and never publish anything", async () => {
    const a = await newUser({ verified: true });
    assert.equal(await errorCode(a.call("submitStartup", { name: "X" })), "functions/invalid-argument");
    const s = await a.call<{ id: string }>("submitStartup", {
      name: "Acme Pay", description: "Payments infrastructure for small merchants across West Africa.",
      country: "Nigeria", industry: "Fintech", foundedYear: 2023, founders: [{ name: "Ada Obi", role: "CEO" }],
      social: { linkedin: "linkedin.com/company/acme" },
    });
    assert.equal((await adminDb.doc(`startupSubmissions/${s.id}`).get()).get("status"), "submitted");
    const c = await a.call<{ id: string }>("claimStartup", {
      startupSlug: "moniepoint", startupName: "Moniepoint", name: "Ada Obi", role: "Head of Comms", companyEmail: "ada@moniepoint.com",
    });
    assert.equal((await adminDb.doc(`startupClaims/${c.id}`).get()).get("status"), "pending");
    assert.equal(await errorCode(a.call("claimStartup", {
      startupSlug: "moniepoint", startupName: "Moniepoint", name: "Ada Obi", role: "Head of Comms", companyEmail: "ada@moniepoint.com",
    })), "functions/already-exists");
    await a.close();
  });
});

describe("account deletion", () => {
  test("removes the person's data, frees the username and keeps conversations readable", async () => {
    const a = await newUser({ verified: true });
    const b = await newUser({ verified: true });
    const name = `gone${Date.now() % 100000}`;
    await withProfile(a, name);
    await withProfile(b, `stay${Date.now() % 100000}`);
    const article = 600_000 + (Date.now() % 1000);
    await a.call("setReaction", { articleId: article, reaction: "love" });
    const top = await a.call<{ id: string }>("addComment", { articleId: article, body: "My comment" });
    await b.call("addComment", { articleId: article, parentId: top.id, body: "A reply" });
    await a.call("setFollow", { kind: "startup", id: "moniepoint", follow: true });
    await eventually(async () => {
      assert.equal((await adminDb.doc(`comments/${top.id}`).get()).get("replyCount"), 1);
    });
    assert.equal(await errorCode(a.call("deleteAccount", {})), "functions/invalid-argument");
    await a.call("deleteAccount", { confirm: "DELETE" });
    assert.equal((await adminDb.doc(`profiles/${a.uid}`).get()).exists, false);
    assert.equal((await adminDb.doc(`usernames/${name}`).get()).exists, false);
    assert.equal((await adminDb.doc(`articles/${article}`).get()).get("reactions.love"), 0);
    const comment = await adminDb.doc(`comments/${top.id}`).get();
    assert.equal(comment.get("body"), "");
    assert.equal(comment.get("author.displayName"), "Deleted");
    assert.equal((await adminDb.doc("followTargets/startup_moniepoint/followers/" + a.uid).get()).exists, false);
    await Promise.all([a.close(), b.close()]);
  });
});

describe("admin access", () => {
  test("only listed, verified emails can become admins", async () => {
    const stranger = await newUser({ verified: true });
    assert.equal(await errorCode(stranger.call("claimAdmin")), "functions/permission-denied");
    const editor = await newUser({ verified: true, email: "editor@allbiohub.test" });
    assert.deepEqual(await editor.call("claimAdmin"), { admin: true });
    await Promise.all([stranger.close(), editor.close()]);
  });
});
