import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp, type Firestore, type Transaction } from "firebase-admin/firestore";
import { HttpsError, onCall, type CallableRequest, type CallableOptions } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

if (getApps().length === 0) initializeApp();

export const db: Firestore = getFirestore();
export { FieldValue, Timestamp, HttpsError, logger };

/** Region for every function. The app calls the same region (FUNCTIONS_REGION). */
export const REGION = "europe-west1";

export type AccountStatus = "active" | "suspended" | "banned";

export interface Caller {
  uid: string;
  emailVerified: boolean;
  admin: boolean;
}

export interface CallOptions {
  /** Signed-in user required (default true). */
  auth?: boolean;
  /** Email address must be verified (Google accounts always are). */
  verified?: boolean;
  /** Suspended or banned users may still do this (reading own data, deleting the account). */
  allowRestricted?: boolean;
  /** Admin claim required. */
  admin?: boolean;
}

/**
 * Declares a callable function with the checks every community action
 * needs: a signed-in user, a verified email where it matters, an account
 * that isn't suspended or banned, and admin rights for moderation.
 */
export function callable<T, R>(
  options: CallOptions,
  handler: (data: T, caller: Caller, request: CallableRequest<T>) => Promise<R>,
  runtime: CallableOptions = {},
) {
  return onCall<T>({ region: REGION, ...runtime }, async (request) => {
    const required = options.auth ?? true;
    const auth = request.auth;
    if (!auth) {
      if (required || options.admin) {
        throw new HttpsError("unauthenticated", "Sign in to do this.");
      }
      return handler((request.data ?? {}) as T, { uid: "", emailVerified: false, admin: false }, request);
    }
    const caller: Caller = {
      uid: auth.uid,
      emailVerified: auth.token.email_verified === true,
      admin: auth.token.admin === true,
    };
    if (options.admin && !caller.admin) {
      throw new HttpsError("permission-denied", "Only AllBioHub editors can do this.");
    }
    if (options.verified && !caller.emailVerified && !caller.admin) {
      throw new HttpsError("failed-precondition", "Verify your email address first.", { reason: "email_unverified" });
    }
    if (!options.allowRestricted && !caller.admin) {
      await assertActive(caller.uid);
    }
    return handler((request.data ?? {}) as T, caller, request);
  });
}

/** Throws when the account is suspended (until a date) or banned. */
export async function assertActive(uid: string): Promise<void> {
  const snap = await db.doc(`users/${uid}`).get();
  const status = (snap.get("status") as AccountStatus | undefined) ?? "active";
  if (status === "banned") {
    throw new HttpsError("permission-denied", "This account can't take part in the community.", { reason: "banned" });
  }
  if (status === "suspended") {
    const until = snap.get("suspendedUntil") as Timestamp | undefined;
    if (!until || until.toMillis() > Date.now()) {
      throw new HttpsError("permission-denied", "This account is temporarily suspended.", {
        reason: "suspended",
        until: until?.toDate().toISOString() ?? null,
      });
    }
  }
}

/** Profile must exist (username chosen) before taking part. */
export async function requireProfile(uid: string): Promise<FirebaseFirestore.DocumentData> {
  const snap = await db.doc(`profiles/${uid}`).get();
  if (!snap.exists) {
    throw new HttpsError("failed-precondition", "Choose a username first.", { reason: "profile_missing" });
  }
  return snap.data()!;
}

export function str(value: unknown): string {
  return typeof value === "string" ? value : value == null ? "" : String(value);
}

export function requireString(value: unknown, field: string, { min = 1, max = 500 } = {}): string {
  const s = str(value).trim();
  if (s.length < min) throw new HttpsError("invalid-argument", `${field} is required.`, { field });
  if (s.length > max) {
    throw new HttpsError("invalid-argument", `${field} must be at most ${max} characters.`, { field });
  }
  return s;
}

export function requireOneOf<T extends string>(value: unknown, allowed: readonly T[], field: string): T {
  const s = str(value) as T;
  if (!allowed.includes(s)) throw new HttpsError("invalid-argument", `Invalid ${field}.`, { field });
  return s;
}

export function requirePositiveInt(value: unknown, field: string): number {
  const n = typeof value === "number" ? value : Number.parseInt(str(value), 10);
  if (!Number.isSafeInteger(n) || n <= 0) throw new HttpsError("invalid-argument", `Invalid ${field}.`, { field });
  return n;
}

/** A Firestore-safe document id piece (slugs, numeric ids). */
export function requireKey(value: unknown, field: string): string {
  const s = str(value).trim();
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,119}$/.test(s)) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`, { field });
  }
  return s;
}

export interface RateLimit {
  /** Requests allowed per window. */
  max: number;
  /** Window length in seconds. */
  seconds: number;
}

/**
 * Fixed-window rate limits per user and action, stored in `rateLimits`.
 * Throws `resource-exhausted` when any window is full.
 */
export async function rateLimit(uid: string, action: string, limits: RateLimit[]): Promise<void> {
  const ref = db.doc(`rateLimits/${uid}_${action}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const windows = (snap.get("windows") as Record<string, { start: number; count: number }> | undefined) ?? {};
    const next: Record<string, { start: number; count: number }> = {};
    for (const limit of limits) {
      const key = String(limit.seconds);
      const w = windows[key];
      const fresh = !w || now - w.start >= limit.seconds * 1000;
      const count = fresh ? 0 : w.count;
      if (count >= limit.max) {
        throw new HttpsError("resource-exhausted", "You're doing that too often. Try again later.", {
          reason: "rate_limited",
          retryAfterSeconds: Math.ceil((w.start + limit.seconds * 1000 - now) / 1000),
        });
      }
      next[key] = { start: fresh ? now : w.start, count: count + 1 };
    }
    tx.set(ref, { windows: next, updatedAt: FieldValue.serverTimestamp() });
  });
}

/** Community settings editors can change without a deploy (`config/moderation`). */
export interface ModerationConfig {
  /** Hold every new comment for review instead of publishing it at once. */
  premoderateComments: boolean;
  /** Extra words that hold a comment for review. */
  heldTerms: string[];
  /** Extra words that may not appear in usernames. */
  blockedUsernameTerms: string[];
  /** Accounts younger than this many hours have comments with links held. */
  newAccountHours: number;
}

let moderationCache: { at: number; value: ModerationConfig } | null = null;

export async function moderationConfig(): Promise<ModerationConfig> {
  if (moderationCache && Date.now() - moderationCache.at < 60_000) return moderationCache.value;
  const snap = await db.doc("config/moderation").get();
  const list = (v: unknown) => (Array.isArray(v) ? v.map(str).filter(Boolean) : []);
  const value: ModerationConfig = {
    premoderateComments: snap.get("premoderateComments") === true,
    heldTerms: list(snap.get("heldTerms")),
    blockedUsernameTerms: list(snap.get("blockedUsernameTerms")),
    newAccountHours: typeof snap.get("newAccountHours") === "number" ? snap.get("newAccountHours") : 24,
  };
  moderationCache = { at: Date.now(), value };
  return value;
}

/** Public author fields copied onto comments, so lists need no extra reads. */
export function authorSnapshot(uid: string, profile: FirebaseFirestore.DocumentData) {
  return {
    uid,
    username: str(profile.username),
    displayName: str(profile.displayName),
    photoUrl: profile.photoUrl ? str(profile.photoUrl) : null,
  };
}

/** Records an editor action for the audit trail. */
export function logModeration(
  tx: Transaction | null,
  entry: { actorUid: string; action: string; targetType: string; targetId: string; note?: string },
) {
  const ref = db.collection("moderationLog").doc();
  const data = { ...entry, note: entry.note ?? null, createdAt: FieldValue.serverTimestamp() };
  if (tx) tx.set(ref, data);
  else return ref.set(data);
  return undefined;
}

/**
 * Runs [work] once per event id. Firestore triggers can be delivered more
 * than once; counters must not drift when they are.
 */
export async function once(eventId: string, work: () => Promise<void>): Promise<void> {
  const ref = db.doc(`system/events/processed/${eventId}`);
  try {
    await ref.create({ at: FieldValue.serverTimestamp() });
  } catch (e: unknown) {
    if ((e as { code?: number }).code === 6) return; // ALREADY_EXISTS
    throw e;
  }
  try {
    await work();
  } catch (e) {
    await ref.delete().catch(() => undefined);
    throw e;
  }
}
