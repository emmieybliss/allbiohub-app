// Shared setup for tests that run against the Firebase emulators
// (npm run test:emulator starts them). Uses the client SDK the way the app
// does, so callables see real auth tokens.
import { createServer, type Server } from "node:http";
import { initializeApp as initClient, type FirebaseApp, deleteApp } from "firebase/app";
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword } from "firebase/auth";
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions";
import { initializeApp as initAdmin, getApps } from "firebase-admin/app";
import { getAuth as adminAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

export const PROJECT = "demo-allbiohub";

if (getApps().length === 0) initAdmin({ projectId: PROJECT });
export const adminDb = getFirestore();

let counter = 0;

export interface TestUser {
  uid: string;
  app: FirebaseApp;
  call: <T = unknown>(name: string, data?: unknown) => Promise<T>;
  close: () => Promise<void>;
}

/** A signed-in client. [verified] marks the email verified; [admin] sets the admin claim. */
export async function newUser(opts: { verified?: boolean; admin?: boolean; email?: string } = {}): Promise<TestUser> {
  counter += 1;
  const email = opts.email ?? `user${Date.now()}_${counter}@example.test`;
  const app = initClient({ projectId: PROJECT, apiKey: "fake-key" }, `u${Date.now()}_${counter}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  const cred = await createUserWithEmailAndPassword(auth, email, "password123");
  const uid = cred.user.uid;
  if (opts.verified || opts.admin) await adminAuth().updateUser(uid, { emailVerified: true });
  if (opts.admin) await adminAuth().setCustomUserClaims(uid, { admin: true });
  if (opts.verified || opts.admin) {
    await auth.signOut();
    await signInWithEmailAndPassword(auth, email, "password123");
  }
  const functions = getFunctions(app, "europe-west1");
  connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  return {
    uid,
    app,
    call: async <T>(name: string, data: unknown = {}) => (await httpsCallable(functions, name)(data)).data as T,
    close: () => deleteApp(app),
  };
}

export async function withProfile(user: TestUser, username: string): Promise<void> {
  await user.call("createProfile", { username, displayName: username });
}

/** Error code of a failed callable, e.g. "functions/permission-denied". */
export async function errorCode(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
  } catch (e) {
    return (e as { code: string }).code;
  }
  return "no-error";
}

/** A stand-in for allbiohub.com's REST API on port 5999. */
export function fakeSite(): Promise<Server> {
  const server = createServer((req, res) => {
    const url = new URL(req.url ?? "/", "http://x");
    res.setHeader("Content-Type", "application/json");
    if (url.pathname === "/wp-json/allbiohub/v1/startups/moniepoint") {
      res.end(JSON.stringify({ id: 1, slug: "moniepoint", name: "Moniepoint", link: "https://allbiohub.com/startups/moniepoint/" }));
    } else if (url.pathname === "/wp-json/wp/v2/categories" && url.searchParams.get("slug") === "money-career") {
      res.end(JSON.stringify([{ id: 216, slug: "money-career", name: "Money &amp; Career" }]));
    } else if (url.pathname === "/wp-json/wp/v2/categories") {
      res.end("[]");
    } else {
      res.statusCode = 404;
      res.end("{}");
    }
  });
  return new Promise((resolve) => server.listen(5999, "127.0.0.1", () => resolve(server)));
}

/** Waits until [check] passes (for triggers, which run asynchronously). */
export async function eventually(check: () => Promise<void>, timeoutMs = 10_000): Promise<void> {
  const start = Date.now();
  for (;;) {
    try {
      await check();
      return;
    } catch (e) {
      if (Date.now() - start > timeoutMs) throw e;
      await new Promise((r) => setTimeout(r, 250));
    }
  }
}
