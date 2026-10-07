// Pure input checks shared by the callable functions. Nothing here touches
// Firestore, so it is unit-tested directly (test/unit/validation.test.ts).
// Every rule the app shows on screen is repeated here: the server never
// trusts the client's validation.

export const USERNAME_MIN = 3;
export const USERNAME_MAX = 20;
export const DISPLAY_NAME_MAX = 50;
export const BIO_MAX = 160;
export const COMMENT_MAX = 2000;
export const MAX_LINKS_PER_COMMENT = 2;

/** Names nobody may take: brand, staff-sounding and app route words. */
export const RESERVED_USERNAMES = new Set([
  "abh", "about", "account", "admin", "administrator", "allbiohub",
  "allbiohubmedia", "allbiohub_media", "anonymous", "api", "app", "billing",
  "blog", "bot", "ceo", "contact", "deleted", "editor", "editorial",
  "editors", "everyone", "founder", "help", "here", "home", "info", "login",
  "logout", "me", "mod", "moderator", "moderators", "news", "newsroom",
  "notifications", "null", "official", "owner", "press", "privacy",
  "profile", "register", "root", "security", "settings", "signin", "signup",
  "staff", "startup", "startups", "support", "system", "team", "terms",
  "undefined", "user", "username", "verified", "webmaster", "www",
]);

/**
 * Words that may not appear anywhere in a username (after undoing common
 * letter swaps such as 0→o). Kept short on purpose to avoid blocking real
 * names; editors can add more in `config/moderation.blockedTerms`.
 */
export const BLOCKED_USERNAME_TERMS = [
  "fuck", "shit", "bitch", "cunt", "whore", "slut", "rapist", "nazi",
  "porn", "xxx", "nigg", "faggot", "asshole", "motherf", "pedo", "hitler",
];

/** Lowercases and trims; strips one leading @. */
export function normalizeUsername(input: unknown): string {
  return String(input ?? "").trim().replace(/^@/, "").toLowerCase();
}

function unLeet(s: string): string {
  return s
    .replace(/0/g, "o").replace(/1/g, "i").replace(/3/g, "e")
    .replace(/4/g, "a").replace(/5/g, "s").replace(/7/g, "t")
    .replace(/8/g, "b").replace(/_/g, "");
}

export type UsernameProblem =
  | "too_short" | "too_long" | "invalid_characters" | "must_start_with_letter"
  | "double_underscore" | "reserved" | "not_allowed";

export const USERNAME_MESSAGES: Record<UsernameProblem, string> = {
  too_short: `Use at least ${USERNAME_MIN} characters.`,
  too_long: `Use at most ${USERNAME_MAX} characters.`,
  invalid_characters: "Use only letters, numbers and underscores.",
  must_start_with_letter: "Start with a letter.",
  double_underscore: "Don't use two underscores in a row.",
  reserved: "That username is reserved.",
  not_allowed: "That username isn't allowed.",
};

/**
 * Returns the first problem with an already normalized username, or null
 * when it may be used (uniqueness is checked separately).
 */
export function usernameProblem(
  name: string,
  extraBlocked: readonly string[] = [],
): UsernameProblem | null {
  if (name.length < USERNAME_MIN) return "too_short";
  if (name.length > USERNAME_MAX) return "too_long";
  if (!/^[a-z0-9_]+$/.test(name)) return "invalid_characters";
  if (!/^[a-z]/.test(name)) return "must_start_with_letter";
  if (name.includes("__")) return "double_underscore";
  if (RESERVED_USERNAMES.has(name) || RESERVED_USERNAMES.has(name.replace(/_/g, ""))) {
    return "reserved";
  }
  const plain = unLeet(name);
  for (const term of [...BLOCKED_USERNAME_TERMS, ...extraBlocked]) {
    const t = term.toLowerCase().trim();
    if (t && (name.includes(t) || plain.includes(unLeet(t)))) return "not_allowed";
  }
  return null;
}

/**
 * Trims, removes control characters (keeping line breaks when [multiline])
 * and collapses runs of blank lines.
 */
export function cleanText(input: unknown, multiline = false): string {
  let s = String(input ?? "");
  s = s.replace(/\r\n?/g, "\n");
  // Control characters and invisible direction overrides.
  s = s.replace(/[\u0000-\u0009\u000B-\u001F\u007F​-‏‪-‮⁦-⁩]/g, "");
  if (multiline) {
    s = s.replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n");
  } else {
    s = s.replace(/\s+/g, " ");
  }
  return s.trim();
}

const URL_PATTERN = /\b(?:https?:\/\/|www\.)\S+/gi;

export function countLinks(text: string): number {
  return (text.match(URL_PATTERN) ?? []).length;
}

/** An http(s) URL, or null. */
export function cleanUrl(input: unknown, maxLength = 500): string | null {
  const s = String(input ?? "").trim();
  if (!s || s.length > maxLength) return null;
  try {
    const url = new URL(/^https?:\/\//i.test(s) ? s : `https://${s}`);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    if (!url.hostname.includes(".")) return null;
    return url.toString();
  } catch {
    return null;
  }
}

export function isEmail(input: unknown): boolean {
  const s = String(input ?? "").trim();
  return s.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(s);
}

/** True when the text contains any term (case-insensitive, whole words). */
export function containsBlockedTerm(text: string, terms: readonly string[]): boolean {
  const lower = text.toLowerCase();
  return terms.some((t) => {
    const term = t.toLowerCase().trim();
    if (!term) return false;
    const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return new RegExp(`(^|[^\\p{L}\\p{N}])${escaped}($|[^\\p{L}\\p{N}])`, "u").test(lower);
  });
}

const ACCENTS: Record<string, string> = {
  a: "àáâãäåāăąạ", c: "çćč", d: "ďđ", e: "èéêëēėęěẹ", i: "ìíîïīįị", n: "ñńňṅ",
  o: "òóôõöøōọ", r: "ŕř", s: "śšşṣ", t: "ťţ", u: "ùúûüūůűụ", y: "ýÿ", z: "źżž",
};

/**
 * Slug used for founder ids: "Tosin Eniolorunda" → "tosin-eniolorunda".
 * Kept identical to `slugify` in the app (lib/core/utils/text_utils.dart),
 * so both sides compute the same id: accents from a fixed table, combining
 * marks dropped, everything else that isn't a-z or 0-9 becomes a dash.
 */
export function slugify(input: unknown): string {
  let s = String(input ?? "").toLowerCase().replace(/[\u0300-\u036f]/g, "").replace(/ß/g, "ss");
  for (const [plain, accented] of Object.entries(ACCENTS)) {
    s = s.replace(new RegExp(`[${accented}]`, "g"), plain);
  }
  return s.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 80);
}

/**
 * Whole-word, case-insensitive match of [name] in [text], the same rule the
 * app uses for a startup's AllBioHub coverage. Names shorter than 3
 * characters never match, to avoid noise.
 */
export function mentions(text: string, name: string): boolean {
  const n = name.trim();
  if (n.length < 3) return false;
  const escaped = n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+");
  return new RegExp(`(^|[^\\p{L}\\p{N}])${escaped}($|[^\\p{L}\\p{N}])`, "iu").test(text);
}

export const REACTIONS = ["love", "interesting", "wow", "informative"] as const;
export type Reaction = (typeof REACTIONS)[number];

export const REPORT_REASONS = [
  "spam", "harassment", "hate", "misinformation", "advertising", "other",
] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

export const FOLLOW_KINDS = ["startup", "founder", "topic"] as const;
export type FollowKind = (typeof FOLLOW_KINDS)[number];

export const SAVED_KINDS = ["article", "startup", "founder"] as const;
export type SavedKind = (typeof SAVED_KINDS)[number];

export const STORY_TYPES = [
  "news_tip", "startup_news", "funding", "product_launch", "founder_news",
  "event", "press_release",
] as const;

export const COMMENT_STATUSES = ["pending", "approved", "rejected", "removed"] as const;
export type CommentStatus = (typeof COMMENT_STATUSES)[number];

export const SUBMISSION_STATUSES = [
  "submitted", "under_review", "accepted", "rejected", "published",
] as const;
export type SubmissionStatus = (typeof SUBMISSION_STATUSES)[number];

export const CLAIM_STATUSES = ["pending", "approved", "rejected"] as const;
export type ClaimStatus = (typeof CLAIM_STATUSES)[number];

/** Push and notification-centre preferences, all on except marketing. */
export const NOTIFICATION_PREFS = {
  community: true,
  commentActivity: true,
  startupAlerts: true,
  founderAlerts: true,
  topicAlerts: true,
  submissionUpdates: true,
  marketing: false,
} as const;
export type NotificationPref = keyof typeof NOTIFICATION_PREFS;

/** Comment, reply, reply: replies to the deepest level attach to its parent. */
export const MAX_COMMENT_DEPTH = 2;

/** Who is replied to, and where the new comment sits in the thread. */
export function placeReply(parent: { id: string; depth: number; parentId: string | null; rootId: string | null }): {
  parentId: string; rootId: string; depth: number;
} {
  const rootId = parent.rootId ?? parent.id;
  if (parent.depth >= MAX_COMMENT_DEPTH) {
    return { parentId: parent.parentId ?? parent.id, rootId, depth: MAX_COMMENT_DEPTH };
  }
  return { parentId: parent.id, rootId, depth: parent.depth + 1 };
}

