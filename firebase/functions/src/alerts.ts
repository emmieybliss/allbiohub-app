import { onSchedule } from "firebase-functions/v2/scheduler";
import { db, FieldValue, logger, REGION, str } from "./core.js";
import { fetchJson, siteUrl, startupApiPath } from "./follows.js";
import { notify, type NotificationInput } from "./notifications.js";
import { mentions } from "./validation.js";

interface WpPost {
  id: number;
  date_gmt: string;
  link: string;
  title?: { rendered?: string };
  excerpt?: { rendered?: string };
  categories?: number[];
}

export function plain(html: string): string {
  return html
    .replace(/<[^>]*>/g, " ")
    .replace(/&#8217;|&#039;|&#39;/g, "'")
    .replace(/&#8220;|&#8221;|&quot;/g, '"')
    .replace(/&#8211;|&#8212;/g, "-")
    .replace(/&amp;/g, "&")
    .replace(/&nbsp;/g, " ")
    .replace(/&#\d+;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function followersOf(key: string): Promise<string[]> {
  const uids: string[] = [];
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db.collection(`followTargets/${key}/followers`).orderBy("__name__").limit(500);
    if (last) q = q.startAfter(last);
    const page = await q.get();
    uids.push(...page.docs.map((d) => d.id));
    if (page.size < 500) return uids;
    last = page.docs[page.docs.length - 1];
  }
}

async function fanOut(key: string, input: NotificationInput): Promise<number> {
  let sent = 0;
  for (const uid of await followersOf(key)) {
    if (await notify(uid, input).catch(() => false)) sent += 1;
  }
  return sent;
}

/**
 * Checks allbiohub.com for newly published stories and tells the people
 * who follow the story's topic, or a startup or founder it names. Only real
 * stories trigger alerts, and each person hears about a story once.
 */
export const checkNewStories = onSchedule({ region: REGION, schedule: "every 30 minutes", timeoutSeconds: 300 }, async () => {
  const base = siteUrl.value().replace(/\/$/, "");
  const stateRef = db.doc("system/alerts");
  const state = await stateRef.get();
  const lastDate = str(state.get("lastPostDate"));

  const posts = (await fetchJson(`${base}/wp-json/wp/v2/posts?per_page=20&orderby=date&order=desc`)) as WpPost[] | null;
  if (!posts || posts.length === 0) return;
  const newest = posts[0].date_gmt;
  if (!lastDate) {
    // First run: start from now instead of announcing old stories.
    await stateRef.set({ lastPostDate: newest, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return;
  }
  const fresh = posts.filter((p) => p.date_gmt > lastDate).reverse();
  if (fresh.length === 0) return;

  const categories = (await fetchJson(`${base}/wp-json/wp/v2/categories?per_page=100`)) as
    Array<{ id: number; slug: string; name: string }> | null ?? [];
  const named = await db.collection("followTargets")
    .where("kind", "in", ["startup", "founder"]).where("followerCount", ">", 0).get();

  for (const post of fresh) {
    const title = plain(post.title?.rendered ?? "");
    const text = `${title} ${plain(post.excerpt?.rendered ?? "")}`;
    const dedupeKey = `post:${post.id}`;
    const url = post.link;

    for (const target of named.docs) {
      const label = str(target.get("label"));
      if (!mentions(text, label)) continue;
      const startup = target.get("kind") === "startup";
      await fanOut(target.id, {
        type: startup ? "startup_story" : "founder_story",
        pref: startup ? "startupAlerts" : "founderAlerts",
        title: `New AllBioHub story about ${label}`,
        body: title,
        url,
        dedupeKey,
      });
    }
    for (const id of post.categories ?? []) {
      const category = categories.find((c) => c.id === id);
      if (!category) continue;
      const target = await db.doc(`followTargets/topic_${category.slug}`).get();
      if (Number(target.get("followerCount") ?? 0) === 0) continue;
      await fanOut(target.id, {
        type: "topic_story",
        pref: "topicAlerts",
        title: `New ${plain(category.name)} story`,
        body: title,
        url,
        dedupeKey,
      });
    }
  }
  await stateRef.set({ lastPostDate: newest, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  logger.info("Story alerts checked", { stories: fresh.length });
});

/**
 * Once a day, compares each followed startup with what it looked like the
 * day before and tells followers when it became verified or featured, or
 * when its profile changed (at most once a week per startup).
 */
export const checkStartupChanges = onSchedule({ region: REGION, schedule: "every day 07:00", timeoutSeconds: 540 }, async () => {
  const base = `${siteUrl.value().replace(/\/$/, "")}${startupApiPath.value()}`;
  const followed = await db.collection("followTargets")
    .where("kind", "==", "startup").where("followerCount", ">", 0).limit(300).get();
  for (const target of followed.docs) {
    const slug = str(target.get("targetId"));
    let startup: { name?: string; link?: string; verified?: boolean; featured?: boolean; updated_at?: string } | null;
    try {
      startup = (await fetchJson(`${base}/startups/${encodeURIComponent(slug)}`)) as typeof startup;
    } catch (e) {
      logger.warn("Startup check failed", { slug, error: String(e) });
      continue;
    }
    if (!startup?.name) continue;
    const before = target.get("snapshot") as { verified?: boolean; featured?: boolean; updated_at?: string } | undefined;
    const snapshot = {
      verified: startup.verified === true,
      featured: startup.featured === true,
      updated_at: str(startup.updated_at),
    };
    const update: Record<string, unknown> = { snapshot, label: startup.name };
    if (before) {
      const name = startup.name;
      const url = startup.link ?? `${siteUrl.value()}/startups/${slug}/`;
      if (snapshot.verified && !before.verified) {
        await fanOut(target.id, {
          type: "startup_story", pref: "startupAlerts", title: `${name} is now AllBioHub Verified`,
          body: "Its profile has been checked by the AllBioHub team.", url, dedupeKey: `verified:${slug}`,
        });
      } else if (snapshot.featured && !before.featured) {
        await fanOut(target.id, {
          type: "startup_story", pref: "startupAlerts", title: `${name} has been featured on AllBioHub`,
          body: "See the startup's profile.", url, dedupeKey: `featured:${slug}:${new Date().toISOString().slice(0, 10)}`,
        });
      } else if (snapshot.updated_at && before.updated_at && snapshot.updated_at !== before.updated_at) {
        const lastNotice = Number(target.get("lastUpdateNoticeAt") ?? 0);
        if (Date.now() - lastNotice > 7 * 86_400_000) {
          await fanOut(target.id, {
            type: "startup_story", pref: "startupAlerts", title: `${name}'s profile was updated`,
            body: "See what's new on AllBioHub.", url, dedupeKey: `updated:${slug}:${snapshot.updated_at}`,
          });
          update.lastUpdateNoticeAt = Date.now();
        }
      }
    }
    await target.ref.set(update, { merge: true });
  }
});
