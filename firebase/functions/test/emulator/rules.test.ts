import { after, before, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs } from "firebase/firestore";

let env: RulesTestEnvironment;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-allbiohub",
    firestore: { rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "config/app"), { features: { comments: true } });
    await setDoc(doc(db, "profiles/alice"), { username: "alice", visibility: "public" });
    await setDoc(doc(db, "profiles/bob"), { username: "bob", visibility: "private" });
    await setDoc(doc(db, "users/alice"), { status: "active" });
    await setDoc(doc(db, "users/alice/notifications/n1"), { title: "Hi", read: false });
    await setDoc(doc(db, "users/alice/devices/d1"), { token: "secret" });
    await setDoc(doc(db, "users/alice/follows/startup_x"), { kind: "startup" });
    await setDoc(doc(db, "comments/c1"), { status: "approved", authorUid: "alice", articleId: 1, parentId: null });
    await setDoc(doc(db, "comments/c2"), { status: "pending", authorUid: "alice", articleId: 1, parentId: null });
    await setDoc(doc(db, "articles/1"), { reactions: { love: 1 } });
    await setDoc(doc(db, "articles/1/reactions/alice"), { reaction: "love" });
    await setDoc(doc(db, "polls/p1"), { status: "active" });
    await setDoc(doc(db, "polls/p2"), { status: "draft" });
    await setDoc(doc(db, "polls/p1/votes/alice"), { optionId: "o1" });
    await setDoc(doc(db, "storySubmissions/s1"), { submitterUid: "alice", status: "submitted" });
    await setDoc(doc(db, "reports/r1"), { status: "open" });
    await setDoc(doc(db, "usernames/alice"), { uid: "alice" });
  });
});

after(async () => { await env.cleanup(); });

const guest = () => env.unauthenticatedContext().firestore();
const alice = () => env.authenticatedContext("alice").firestore();
const bob = () => env.authenticatedContext("bob").firestore();
const admin = () => env.authenticatedContext("editor", { admin: true }).firestore();

test("public data is readable by guests", async () => {
  await assertSucceeds(getDoc(doc(guest(), "config/app")));
  await assertSucceeds(getDoc(doc(guest(), "articles/1")));
  await assertSucceeds(getDoc(doc(guest(), "comments/c1")));
  await assertSucceeds(getDoc(doc(guest(), "profiles/alice")));
  await assertSucceeds(getDoc(doc(guest(), "polls/p1")));
});

test("nobody writes community data directly", async () => {
  await assertFails(setDoc(doc(alice(), "comments/new"), { status: "approved", authorUid: "alice" }));
  await assertFails(setDoc(doc(alice(), "articles/1/reactions/alice"), { reaction: "wow" }));
  await assertFails(updateDoc(doc(alice(), "articles/1"), { "reactions.love": 999 }));
  await assertFails(setDoc(doc(alice(), "profiles/alice"), { username: "admin" }));
  await assertFails(setDoc(doc(alice(), "usernames/admin"), { uid: "alice" }));
  await assertFails(setDoc(doc(alice(), "polls/p1/votes/alice"), { optionId: "o2" }));
  await assertFails(setDoc(doc(alice(), "config/app"), { features: {} }));
  await assertFails(setDoc(doc(admin(), "config/app"), { features: {} }));
});

test("private profiles, settings and follows are owner-only", async () => {
  await assertFails(getDoc(doc(alice(), "profiles/bob")));
  await assertSucceeds(getDoc(doc(bob(), "profiles/bob")));
  await assertFails(getDoc(doc(bob(), "users/alice")));
  await assertSucceeds(getDoc(doc(alice(), "users/alice")));
  await assertFails(getDoc(doc(bob(), "users/alice/follows/startup_x")));
  await assertSucceeds(getDoc(doc(alice(), "users/alice/follows/startup_x")));
  await assertFails(getDoc(doc(alice(), "users/alice/devices/d1")));
});

test("pending comments are visible only to their author and admins", async () => {
  await assertFails(getDoc(doc(guest(), "comments/c2")));
  await assertFails(getDoc(doc(bob(), "comments/c2")));
  await assertSucceeds(getDoc(doc(alice(), "comments/c2")));
  await assertSucceeds(getDoc(doc(admin(), "comments/c2")));
  await assertSucceeds(getDocs(query(collection(guest(), "comments"),
    where("articleId", "==", 1), where("status", "==", "approved"))));
  await assertFails(getDocs(query(collection(guest(), "comments"), where("articleId", "==", 1))));
});

test("reactions and votes are private to the voter", async () => {
  await assertFails(getDoc(doc(bob(), "articles/1/reactions/alice")));
  await assertSucceeds(getDoc(doc(alice(), "articles/1/reactions/alice")));
  await assertFails(getDoc(doc(bob(), "polls/p1/votes/alice")));
  await assertSucceeds(getDoc(doc(alice(), "polls/p1/votes/alice")));
});

test("draft polls stay hidden", async () => {
  await assertFails(getDoc(doc(guest(), "polls/p2")));
  await assertSucceeds(getDoc(doc(admin(), "polls/p2")));
});

test("submissions are visible to the sender and editors only", async () => {
  await assertSucceeds(getDoc(doc(alice(), "storySubmissions/s1")));
  await assertFails(getDoc(doc(bob(), "storySubmissions/s1")));
  await assertSucceeds(getDoc(doc(admin(), "storySubmissions/s1")));
});

test("reports and the username index are not readable by users", async () => {
  await assertFails(getDoc(doc(alice(), "reports/r1")));
  await assertSucceeds(getDoc(doc(admin(), "reports/r1")));
  await assertFails(getDoc(doc(alice(), "usernames/alice")));
});

test("people can only mark their own notifications read", async () => {
  await assertFails(updateDoc(doc(bob(), "users/alice/notifications/n1"), { read: true }));
  await assertFails(updateDoc(doc(alice(), "users/alice/notifications/n1"), { title: "Changed" }));
  await assertSucceeds(updateDoc(doc(alice(), "users/alice/notifications/n1"), { read: true }));
});
