import { env } from '@/config/env';
import type { Term, TermKind } from '@/models/types';
import { AppError } from './errors';
import { getJson, HOURS } from './http';
import { mapTerm } from './wordpress';

/** Internal or commercial categories that aren't editorial sections. */
export const HIDDEN_CATEGORY_SLUGS = new Set(['uncategorized', 'editorial-submission', 'sponsored']);

const TERM_FIELDS = 'id,name,slug,count,description,parent';

function terms(data: unknown, kind: TermKind): Term[] {
  if (!Array.isArray(data)) throw new AppError('badResponse');
  return data
    .filter((t): t is Record<string, unknown> => typeof t === 'object' && t !== null && typeof (t as { id?: unknown }).id === 'number')
    .map((t) => mapTerm(t, kind));
}

/** Every category (hidden ones too) by id, for labelling stories. */
export async function allCategoriesById(): Promise<Map<number, Term>> {
  const r = await getJson(`${env.wordpressApi}/categories`, {
    query: { per_page: 100, _fields: TERM_FIELDS },
    maxAgeMs: HOURS(12),
  });
  return new Map(terms(r.data, 'category').map((c) => [c.id, c]));
}

/** Editorial categories with at least one story, largest first. */
export async function fetchCategories(forceRefresh = false): Promise<Term[]> {
  const r = await getJson(`${env.wordpressApi}/categories`, {
    query: { per_page: 100, hide_empty: true, orderby: 'count', order: 'desc', _fields: TERM_FIELDS },
    maxAgeMs: HOURS(12),
    forceRefresh,
  });
  return terms(r.data, 'category').filter((c) => c.count > 0 && !HIDDEN_CATEGORY_SLUGS.has(c.slug));
}

export async function fetchPopularTags(count = 20): Promise<Term[]> {
  const r = await getJson(`${env.wordpressApi}/tags`, {
    query: { per_page: count, orderby: 'count', order: 'desc', hide_empty: true, _fields: 'id,name,slug,count' },
    maxAgeMs: HOURS(12),
  });
  return terms(r.data, 'tag').filter((t) => t.count > 1);
}

export async function categoryBySlug(slug: string): Promise<Term> {
  const all = await fetchCategories().catch(() => [] as Term[]);
  const found = all.find((c) => c.slug === slug);
  if (found) return found;
  const r = await getJson(`${env.wordpressApi}/categories`, { query: { slug, _fields: TERM_FIELDS }, maxAgeMs: HOURS(12) });
  const list = terms(r.data, 'category');
  if (!list.length) throw new AppError('notFound');
  return list[0];
}

export async function tagBySlug(slug: string): Promise<Term> {
  const r = await getJson(`${env.wordpressApi}/tags`, {
    query: { slug, _fields: 'id,name,slug,count,description' },
    maxAgeMs: HOURS(12),
  });
  const list = terms(r.data, 'tag');
  if (!list.length) throw new AppError('notFound');
  return list[0];
}

/** Categories and tags whose name matches the query. */
export async function searchTopics(query: string, signal?: AbortSignal): Promise<Term[]> {
  const results = await Promise.all(
    (['category', 'tag'] as const).map((kind) =>
      getJson(`${env.wordpressApi}/${kind === 'category' ? 'categories' : 'tags'}`, {
        query: { search: query, per_page: 10, hide_empty: true, _fields: 'id,name,slug,count' },
        maxAgeMs: HOURS(1),
        signal,
      }).then((r) => terms(r.data, kind)),
    ),
  );
  return results.flat().filter((t) => !HIDDEN_CATEGORY_SLUGS.has(t.slug));
}
