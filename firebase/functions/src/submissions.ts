import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import {
  callable, db, FieldValue, HttpsError, logModeration, once, rateLimit, REGION, requireKey, requireOneOf, str,
} from "./core.js";
import { notify } from "./notifications.js";
import {
  CLAIM_STATUSES, cleanText, cleanUrl, isEmail, STORY_TYPES, SUBMISSION_STATUSES, type ClaimStatus, type SubmissionStatus,
} from "./validation.js";

const DAILY = [{ max: 3, seconds: 3600 }, { max: 6, seconds: 86_400 }];

function text(value: unknown, field: string, { min = 0, max = 200, multiline = false } = {}): string {
  const s = cleanText(value, multiline);
  if (s.length < min) {
    throw new HttpsError("invalid-argument", min <= 1 ? `${field} is required.` : `${field} is too short.`, { field });
  }
  if (s.length > max) throw new HttpsError("invalid-argument", `${field} must be at most ${max} characters.`, { field });
  return s;
}

function optionalUrl(value: unknown, field: string): string | null {
  if (value == null || str(value).trim() === "") return null;
  const url = cleanUrl(value);
  if (!url) throw new HttpsError("invalid-argument", `${field} must be a web address.`, { field });
  return url;
}

async function optionalImage(uid: string, value: unknown): Promise<string | null> {
  if (value == null || str(value) === "") return null;
  const path = str(value);
  if (!new RegExp(`^submissions/${uid}/[A-Za-z0-9_.-]{1,80}$`).test(path)) {
    throw new HttpsError("invalid-argument", "Invalid image.", { field: "image" });
  }
  const [exists] = await getStorage().bucket().file(path).exists();
  if (!exists) throw new HttpsError("invalid-argument", "The image didn't finish uploading.", { field: "image" });
  return path;
}

async function contactEmail(uid: string, value: unknown): Promise<string> {
  const given = str(value).trim();
  if (given) {
    if (!isEmail(given)) throw new HttpsError("invalid-argument", "Enter a valid email address.", { field: "contactEmail" });
    return given;
  }
  return (await getAuth().getUser(uid)).email ?? "";
}

/** Who sent it. Private: only the sender and editors can read submissions. */
async function submitter(uid: string) {
  const profile = await db.doc(`profiles/${uid}`).get();
  return { submitterUid: uid, submitterUsername: profile.exists ? str(profile.get("username")) : null };
}

const RECEIVED = "Your submission has been received and is awaiting editorial review.";

/**
 * A story tip or announcement for the newsroom. It never becomes an
 * article by itself: an editor reviews it and writes any story in WordPress.
 */
export const submitStory = callable<Record<string, unknown>, { id: string; message: string }>(
  { verified: true },
  async (data, caller) => {
    await rateLimit(caller.uid, "story_submission", DAILY);
    const doc = {
      type: requireOneOf(data.type, STORY_TYPES, "type"),
      title: text(data.title, "Title", { min: 5, max: 200 }),
      description: text(data.description, "Description", { min: 20, max: 5000, multiline: true }),
      category: text(data.category, "Category", { max: 100 }),
      sourceUrl: optionalUrl(data.sourceUrl, "Source URL"),
      additionalInfo: text(data.additionalInfo, "Additional information", { max: 3000, multiline: true }),
      imagePath: await optionalImage(caller.uid, data.imagePath),
      contactEmail: await contactEmail(caller.uid, data.contactEmail),
      contactPhone: text(data.contactPhone, "Phone", { max: 30 }),
      ...(await submitter(caller.uid)),
      status: "submitted" as SubmissionStatus,
      editorNote: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    const ref = await db.collection("storySubmissions").add(doc);
    return { id: ref.id, message: RECEIVED };
  },
);

/** A startup for the directory. Editors add it to the website after review. */
export const submitStartup = callable<Record<string, unknown>, { id: string; message: string }>(
  { verified: true },
  async (data, caller) => {
    await rateLimit(caller.uid, "startup_submission", DAILY);
    const year = data.foundedYear == null || str(data.foundedYear) === "" ? null : Number(data.foundedYear);
    if (year !== null && (!Number.isInteger(year) || year < 1900 || year > new Date().getFullYear())) {
      throw new HttpsError("invalid-argument", "Enter a valid founding year.", { field: "foundedYear" });
    }
    const founders = (Array.isArray(data.founders) ? data.founders : []).slice(0, 10).map((f) => {
      const item = (f ?? {}) as Record<string, unknown>;
      return {
        name: text(item.name, "Founder name", { min: 2, max: 100 }),
        role: text(item.role, "Founder role", { max: 100 }),
        linkedin: optionalUrl(item.linkedin, "Founder LinkedIn"),
      };
    });
    const socialInput = (data.social ?? {}) as Record<string, unknown>;
    const social: Record<string, string> = {};
    for (const key of ["linkedin", "x", "facebook", "instagram", "youtube", "tiktok"]) {
      const url = optionalUrl(socialInput[key], key);
      if (url) social[key] = url;
    }
    const doc = {
      name: text(data.name, "Startup name", { min: 2, max: 100 }),
      description: text(data.description, "Description", { min: 30, max: 5000, multiline: true }),
      website: optionalUrl(data.website, "Website"),
      country: text(data.country, "Country", { min: 2, max: 60 }),
      city: text(data.city, "City", { max: 60 }),
      industry: text(data.industry, "Industry", { min: 2, max: 60 }),
      foundedYear: year,
      businessModel: text(data.businessModel, "Business model", { max: 60 }),
      stage: text(data.stage, "Stage", { max: 60 }),
      funding: text(data.funding, "Funding", { max: 100 }),
      employees: text(data.employees, "Employees", { max: 30 }),
      founders,
      social,
      logoPath: await optionalImage(caller.uid, data.logoPath),
      contactEmail: await contactEmail(caller.uid, data.contactEmail),
      ...(await submitter(caller.uid)),
      status: "submitted" as SubmissionStatus,
      editorNote: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    const ref = await db.collection("startupSubmissions").add(doc);
    return { id: ref.id, message: RECEIVED };
  },
);

/**
 * A founder's or representative's claim on a startup profile. It never
 * marks the startup verified: an editor checks it and updates the directory.
 */
export const claimStartup = callable<Record<string, unknown>, { id: string; message: string }>(
  { verified: true },
  async (data, caller) => {
    await rateLimit(caller.uid, "startup_claim", DAILY);
    const slug = requireKey(data.startupSlug, "startupSlug");
    const email = str(data.companyEmail).trim();
    if (!isEmail(email)) throw new HttpsError("invalid-argument", "Enter your company email address.", { field: "companyEmail" });
    const existing = await db.collection("startupClaims")
      .where("submitterUid", "==", caller.uid).where("startupSlug", "==", slug).where("status", "==", "pending").limit(1).get();
    if (!existing.empty) throw new HttpsError("already-exists", "You already have a claim waiting for this startup.");
    const doc = {
      startupSlug: slug,
      startupName: text(data.startupName, "Startup", { min: 1, max: 100 }),
      name: text(data.name, "Name", { min: 2, max: 100 }),
      role: text(data.role, "Role", { min: 2, max: 100 }),
      companyEmail: email,
      linkedin: optionalUrl(data.linkedin, "LinkedIn"),
      verificationInfo: text(data.verificationInfo, "Verification information", { max: 2000, multiline: true }),
      ...(await submitter(caller.uid)),
      status: "pending" as ClaimStatus,
      editorNote: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    const ref = await db.collection("startupClaims").add(doc);
    return { id: ref.id, message: RECEIVED };
  },
);

const COLLECTIONS = ["storySubmissions", "startupSubmissions", "startupClaims"] as const;
type SubmissionCollection = (typeof COLLECTIONS)[number];

/** Admin: moves a submission or claim to a new status, with a note the sender sees. */
export const reviewSubmission = callable<{ collection?: string; id?: string; status?: string; note?: string }, { ok: true }>(
  { admin: true },
  async (data, caller) => {
    const collection = requireOneOf(data.collection, COLLECTIONS, "collection");
    const id = requireKey(data.id, "id");
    const status = collection === "startupClaims"
      ? requireOneOf(data.status, CLAIM_STATUSES, "status")
      : requireOneOf(data.status, SUBMISSION_STATUSES, "status");
    const note = cleanText(data.note, true).slice(0, 1000) || null;
    await db.runTransaction(async (tx) => {
      const ref = db.doc(`${collection}/${id}`);
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Not found.");
      tx.update(ref, { status, editorNote: note, reviewedBy: caller.uid, updatedAt: FieldValue.serverTimestamp() });
      logModeration(tx, { actorUid: caller.uid, action: `${collection}.${status}`, targetType: collection, targetId: id, note: note ?? undefined });
    });
    return { ok: true };
  },
);

const STATUS_TEXT: Record<string, string> = {
  under_review: "is under review",
  accepted: "was accepted",
  rejected: "wasn't accepted",
  published: "has been published",
  approved: "was approved",
};

function kindLabel(collection: SubmissionCollection): string {
  return collection === "storySubmissions" ? "story submission"
    : collection === "startupSubmissions" ? "startup submission" : "startup claim";
}

/** Tells the sender when an editor changes the status (from the app or the console). */
function statusWatcher(collection: SubmissionCollection) {
  return onDocumentUpdated({ region: REGION, document: `${collection}/{id}` }, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;
    const phrase = STATUS_TEXT[str(after.status)];
    if (!phrase) return;
    await once(event.id, async () => {
      const name = str(after.title || after.name || after.startupName);
      await notify(str(after.submitterUid), {
        type: collection === "startupClaims" ? "claim_update" : "submission_update",
        pref: "submissionUpdates",
        title: `Your ${kindLabel(collection)} ${phrase}`,
        body: [name, str(after.editorNote)].filter(Boolean).join(" — ").slice(0, 200),
        url: "/me/submissions",
        dedupeKey: `${collection}:${event.params.id}:${after.status}`,
      });
    });
  });
}

export const onStorySubmissionUpdated = statusWatcher("storySubmissions");
export const onStartupSubmissionUpdated = statusWatcher("startupSubmissions");
export const onStartupClaimUpdated = statusWatcher("startupClaims");
