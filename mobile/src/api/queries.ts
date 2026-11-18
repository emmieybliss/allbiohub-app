import { QueryClient, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { usePreferences } from '@/stores/preferences';
import type { Article, Page, StartupQuery } from '@/models/types';
import { hasMore } from '@/models/types';
import { escapeRegExp } from '@/lib/text';
import {
  fetchArticle,
  fetchArticleBySlug,
  fetchAuthor,
  fetchFeatured,
  fetchLatest,
  fetchRelated,
  searchArticles,
} from './articles';
import { categoryBySlug, fetchCategories, fetchPopularTags, searchTopics, tagBySlug } from './taxonomy';
import { fetchStartup, fetchStartupFilters, fetchStartups } from './startups';
import { StartupDirectoryUnavailable } from './errors';

/** Every error state has its own Retry button, so no automatic retries. */
export const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false, staleTime: 60_000, refetchOnWindowFocus: false } },
});

export const HOME_LATEST_COUNT = 12;

/**
 * Pull-to-refresh bypasses the HTTP cache: while [refreshAll] runs, every
 * query function asks the network first (and still falls back to the cache
 * when offline).
 */
let forcing = 0;
const force = () => forcing > 0;

export async function refreshAll(...refetches: (() => Promise<unknown>)[]): Promise<void> {
  forcing++;
  try {
    await Promise.all(refetches.map((r) => r().catch(() => undefined)));
  } finally {
    forcing--;
  }
}

export function useHomeFeed() {
  return useQuery({
    queryKey: ['home'],
    queryFn: async () => {
      const f = force();
      const [sticky, latest] = await Promise.all([fetchFeatured(f).catch(() => [] as Article[]), fetchLatest({ perPage: HOME_LATEST_COUNT, forceRefresh: f })]);
      // Lead stories: sticky posts if editors pinned any, else the newest.
      const featured = (sticky.length ? sticky : latest.items).slice(0, 3);
      const ids = new Set(featured.map((a) => a.id));
      return { featured, latest: latest.items.filter((a) => !ids.has(a.id)), stale: latest.stale };
    },
  });
}

/** Categories ordered by the person's interests first, then by size. */
export function useCategories() {
  const interests = usePreferences((s) => s.interestSlugs);
  return useQuery({
    queryKey: ['categories'],
    queryFn: () => fetchCategories(force()),
    select: (cats) => (interests.length ? [...cats.filter((c) => interests.includes(c.slug)), ...cats.filter((c) => !interests.includes(c.slug))] : cats),
  });
}

export function usePopularTags() {
  return useQuery({ queryKey: ['tags', 'popular'], queryFn: () => fetchPopularTags() });
}

export function useCategoryPreview(categoryId: number) {
  return useQuery({ queryKey: ['category-preview', categoryId], queryFn: async () => (await fetchLatest({ perPage: 6, categoryId, forceRefresh: force() })).items });
}

type FeedKind = { categoryId?: number; tagId?: number; authorId?: number; skip?: number };

/** Infinite list of stories. [skip] continues after stories the screen already shows. */
export function useStoryFeed(key: string, kind: FeedKind, enabled = true) {
  return useInfiniteQuery({
    queryKey: ['feed', key, kind],
    enabled,
    initialPageParam: 1,
    queryFn: ({ pageParam }) =>
      fetchLatest({
        page: pageParam + (kind.skip ?? 0),
        perPage: kind.skip ? HOME_LATEST_COUNT : 10,
        categoryId: kind.categoryId,
        tagId: kind.tagId,
        authorId: kind.authorId,
        forceRefresh: force(),
      }),
    getNextPageParam: (last: Page<Article>, _all, lastParam) => (hasMore(last) && last.items.length ? lastParam + 1 : undefined),
  });
}

/** Flattens pages, de-duplicating items that shifted between pages. */
export function flatten<T extends { id: number }>(pages?: Page<T>[]): T[] {
  const seen = new Set<number>();
  const out: T[] = [];
  for (const p of pages ?? []) {
    for (const item of p.items) {
      if (seen.has(item.id)) continue;
      seen.add(item.id);
      out.push(item);
    }
  }
  return out;
}

export function useArticle(id: number) {
  return useQuery({ queryKey: ['article', id], queryFn: () => fetchArticle(id, force()), enabled: Number.isFinite(id) });
}

export function useArticleBySlug(slug: string) {
  return useQuery({ queryKey: ['article-slug', slug], queryFn: () => fetchArticleBySlug(slug, force()) });
}

export function useRelated(article?: Article) {
  return useQuery({ queryKey: ['related', article?.id], queryFn: () => fetchRelated(article!), enabled: !!article });
}

export function useAuthor(id: number) {
  return useQuery({ queryKey: ['author', id], queryFn: () => fetchAuthor(id) });
}

export function useCategory(slug: string) {
  return useQuery({ queryKey: ['category', slug], queryFn: () => categoryBySlug(slug) });
}

export function useTag(slug: string) {
  return useQuery({ queryKey: ['tag', slug], queryFn: () => tagBySlug(slug) });
}

export function useSearch(query: string) {
  const q = query.trim();
  const stories = useInfiniteQuery({
    queryKey: ['search', q],
    enabled: q.length >= 2,
    initialPageParam: 1,
    queryFn: ({ pageParam, signal }) => searchArticles(q, pageParam, signal),
    getNextPageParam: (last, _all, lastParam) => (hasMore(last) && last.items.length ? lastParam + 1 : undefined),
  });
  const topics = useQuery({ queryKey: ['topics', q], enabled: q.length >= 2, queryFn: ({ signal }) => searchTopics(q, signal) });
  return { stories, topics };
}

// --- Startups -------------------------------------------------------------

export const isDirectoryUnavailable = (e: unknown): boolean => e instanceof StartupDirectoryUnavailable;

export function useStartupFilters() {
  return useQuery({ queryKey: ['startup-filters'], queryFn: () => fetchStartupFilters(force()) });
}

export function useStartupRail(query: StartupQuery) {
  return useQuery({ queryKey: ['startup-rail', query], queryFn: async () => (await fetchStartups(query, 1, 10, force())).items });
}

/** The first page of a directory query, with the total the API reports. */
export function useStartupPage(query: StartupQuery, perPage = 10) {
  return useQuery({ queryKey: ['startup-page', query, perPage], queryFn: () => fetchStartups(query, 1, perPage, force()) });
}

export function useStartupDirectory(query: StartupQuery) {
  return useInfiniteQuery({
    queryKey: ['startups', query],
    initialPageParam: 1,
    queryFn: ({ pageParam }) => fetchStartups(query, pageParam, 20, force()),
    getNextPageParam: (last, _all, lastParam) => (hasMore(last) && last.items.length ? lastParam + 1 : undefined),
  });
}

export function useStartup(slug: string) {
  return useQuery({ queryKey: ['startup', slug], queryFn: () => fetchStartup(slug, force()) });
}

/**
 * Stories that mention a startup by name. WordPress has no startup to story
 * link, so this searches for the name and keeps whole-word matches in the
 * title or excerpt only.
 */
export function useStartupCoverage(name?: string) {
  return useQuery({
    queryKey: ['coverage', name],
    enabled: !!name,
    queryFn: async () => {
      const results = await searchArticles(`"${name}"`);
      const pattern = new RegExp(`(^|\\W)${escapeRegExp(name!)}(\\W|$)`, 'i');
      return results.items.filter((a) => pattern.test(a.title) || pattern.test(a.excerpt));
    },
  });
}
