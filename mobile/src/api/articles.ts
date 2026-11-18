import { env } from '@/config/env';
import type { Article, Author, MediaImage, Page, Term } from '@/models/types';
import { AppError } from './errors';
import { getJson, HOURS, MINUTES } from './http';
import { allCategoriesById } from './taxonomy';
import { mapArticle, mapArticles, mapAuthor, mapMedia, mapTerm } from './wordpress';

const EMBED = 'author,wp:featuredmedia,wp:term';
/** Lists leave out `content`, by far the heaviest field. */
const LIST_FIELDS =
  'id,date,date_gmt,modified,modified_gmt,slug,link,title,excerpt,author,featured_media,categories,tags,sticky,_links,_embedded';
const FULL_FIELDS = `${LIST_FIELDS},content`;

export type LatestOptions = {
  page?: number;
  perPage?: number;
  categoryId?: number;
  /** Stories in any of these categories. */
  categoryIds?: number[];
  tagId?: number;
  authorId?: number;
  excludeIds?: number[];
  forceRefresh?: boolean;
  signal?: AbortSignal;
};

/** Past the last page: an empty page rather than an error. */
const endOfList = (page: number): Page<Article> => ({ items: [], page, totalPages: page - 1, stale: false });

export async function fetchLatest(o: LatestOptions = {}): Promise<Page<Article>> {
  const page = o.page ?? 1;
  try {
    const r = await getJson(`${env.wordpressApi}/posts`, {
      query: {
        page,
        per_page: o.perPage ?? 10,
        categories: o.categoryIds?.length ? o.categoryIds.join(',') : o.categoryId,
        tags: o.tagId,
        author: o.authorId,
        exclude: o.excludeIds?.length ? o.excludeIds.join(',') : undefined,
        _embed: EMBED,
        _fields: LIST_FIELDS,
      },
      maxAgeMs: MINUTES(5),
      forceRefresh: o.forceRefresh,
      signal: o.signal,
    });
    return { items: await complete(mapArticles(r.data)), page, totalPages: r.totalPages, total: r.total, stale: r.stale };
  } catch (e) {
    if (page > 1 && e instanceof AppError && e.kind === 'notFound') return endOfList(page);
    throw e;
  }
}

/** Sticky posts, which editors pin on the website's front page. */
export async function fetchFeatured(forceRefresh = false): Promise<Article[]> {
  const r = await getJson(`${env.wordpressApi}/posts`, {
    query: { sticky: true, per_page: 5, _embed: EMBED, _fields: LIST_FIELDS },
    maxAgeMs: MINUTES(10),
    forceRefresh,
  });
  return complete(mapArticles(r.data));
}

export async function fetchArticle(id: number, forceRefresh = false): Promise<Article> {
  const r = await getJson(`${env.wordpressApi}/posts/${id}`, {
    query: { _embed: EMBED, _fields: FULL_FIELDS },
    maxAgeMs: HOURS(1),
    forceRefresh,
  });
  if (typeof r.data !== 'object' || r.data === null) throw new AppError('badResponse');
  return (await complete([mapArticle(r.data as Record<string, unknown>)], true))[0];
}

/** Looks up a story by its URL slug (deep links, links inside stories). */
export async function fetchArticleBySlug(slug: string, forceRefresh = false): Promise<Article> {
  const r = await getJson(`${env.wordpressApi}/posts`, {
    query: { slug, _embed: EMBED, _fields: FULL_FIELDS },
    maxAgeMs: HOURS(1),
    forceRefresh,
  });
  const items = await complete(mapArticles(r.data), true);
  if (!items.length) throw new AppError('notFound');
  return items[0];
}

/** Other recent stories in the same primary category. */
export async function fetchRelated(article: Article, count = 4): Promise<Article[]> {
  const categoryId = article.categories[0]?.id ?? article.categoryIds[0];
  if (categoryId === undefined) return [];
  const page = await fetchLatest({ perPage: count, categoryId, excludeIds: [article.id] });
  return page.items;
}

export async function searchArticles(query: string, page = 1, signal?: AbortSignal): Promise<Page<Article>> {
  try {
    const r = await getJson(`${env.wordpressApi}/posts`, {
      query: { search: query, page, per_page: 10, _embed: EMBED, _fields: LIST_FIELDS },
      maxAgeMs: MINUTES(10),
      signal,
    });
    return { items: await complete(mapArticles(r.data)), page, totalPages: r.totalPages, total: r.total, stale: r.stale };
  } catch (e) {
    if (page > 1 && e instanceof AppError && e.kind === 'notFound') return endOfList(page);
    throw e;
  }
}

export async function fetchAuthor(id: number): Promise<Author> {
  const r = await getJson(`${env.wordpressApi}/users/${id}`, { maxAgeMs: HOURS(24) });
  const author = mapAuthor(r.data);
  if (!author) throw new AppError('notFound');
  return author;
}

async function byIds<T>(endpoint: string, ids: Set<number>, map: (j: Record<string, unknown>) => T | undefined): Promise<Map<number, T>> {
  const result = new Map<number, T>();
  if (!ids.size) return result;
  try {
    const sorted = [...ids].sort((a, b) => a - b);
    const r = await getJson(`${env.wordpressApi}/${endpoint}`, {
      query: { include: sorted.join(','), per_page: sorted.length },
      maxAgeMs: HOURS(24),
    });
    if (!Array.isArray(r.data)) return result;
    for (const item of r.data) {
      if (typeof item !== 'object' || item === null || typeof item.id !== 'number') continue;
      const value = map(item);
      if (value !== undefined) result.set(item.id, value);
    }
  } catch {
    // Failures leave gaps; cards fall back to placeholders.
  }
  return result;
}

/**
 * The live site drops _embed, returning ids only for the author, image and
 * terms. Fetch whatever is missing in one batched request per kind.
 */
export async function complete(articles: Article[], withTags = false): Promise<Article[]> {
  const mediaIds = new Set(articles.filter((a) => !a.image && a.featuredMediaId > 0).map((a) => a.featuredMediaId));
  const authorIds = new Set(articles.filter((a) => !a.author && a.authorId > 0).map((a) => a.authorId));
  const needsCategories = articles.some((a) => !a.categories.length && a.categoryIds.length);
  const tagIds = new Set(withTags ? articles.filter((a) => !a.tags.length).flatMap((a) => a.tagIds) : []);
  if (!mediaIds.size && !authorIds.size && !needsCategories && !tagIds.size) return articles;

  const [media, authors, categories, tags] = await Promise.all([
    byIds<MediaImage>('media', mediaIds, mapMedia),
    byIds<Author>('users', authorIds, mapAuthor),
    needsCategories ? allCategoriesById().catch(() => new Map<number, Term>()) : Promise.resolve(new Map<number, Term>()),
    byIds<Term>('tags', tagIds, (j) => mapTerm(j, 'tag')),
  ]);

  return articles.map((a) => ({
    ...a,
    image: a.image ?? media.get(a.featuredMediaId),
    author: a.author ?? authors.get(a.authorId),
    categories: a.categories.length ? a.categories : a.categoryIds.map((id) => categories.get(id)).filter((c): c is Term => !!c),
    tags: a.tags.length || !tags.size ? a.tags : a.tagIds.map((id) => tags.get(id)).filter((t): t is Term => !!t),
  }));
}
