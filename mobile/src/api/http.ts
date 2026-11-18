import { readCache, writeCache } from './cache';
import { AppError } from './errors';

export type ApiResponse<T = unknown> = {
  data: T;
  total?: number;
  totalPages?: number;
  /** Served from the local cache because the network failed; may be out of date. */
  stale: boolean;
};

export type Query = Record<string, string | number | boolean | null | undefined>;

export type GetOptions = {
  query?: Query;
  /** How long a cached response is used without asking the network. */
  maxAgeMs?: number;
  forceRefresh?: boolean;
  signal?: AbortSignal;
};

const TIMEOUT_MS = 20_000;
const MINUTE = 60_000;

export function buildUrl(url: string, query: Query = {}): string {
  const params = Object.entries(query)
    .filter(([, v]) => v !== null && v !== undefined && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`);
  if (!params.length) return url;
  return `${url}${url.includes('?') ? '&' : '?'}${params.join('&')}`;
}

function intHeader(headers: Headers, name: string): number | undefined {
  const n = parseInt(headers.get(name) ?? '', 10);
  return Number.isFinite(n) ? n : undefined;
}

/** Injected so tests can replace the network. */
export let fetcher: typeof fetch = (...args) => fetch(...args);
export function setFetcher(f: typeof fetch) {
  fetcher = f;
}

/**
 * The only place the app talks HTTP. Cache policy, as in the Flutter app:
 * 1. a cached response younger than maxAge is returned without a request;
 * 2. otherwise the network is used and the response cached;
 * 3. if the network fails and any cached copy exists, it's returned with
 *    stale: true so screens can show an offline notice.
 */
export async function getJson<T = unknown>(url: string, options: GetOptions = {}): Promise<ApiResponse<T>> {
  const { query = {}, maxAgeMs = 5 * MINUTE, forceRefresh = false, signal } = options;
  const key = buildUrl(url, query);
  const cached = await readCache(key);
  if (!forceRefresh && cached && Date.now() - cached.savedAt < maxAgeMs) {
    return { data: cached.data as T, total: cached.total, totalPages: cached.totalPages, stale: false };
  }

  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    const onAbort = () => controller.abort();
    signal?.addEventListener('abort', onAbort);
    let response: Response;
    try {
      response = await fetcher(key, { headers: { Accept: 'application/json' }, signal: controller.signal });
    } catch (e) {
      if (signal?.aborted) throw new AppError('cancelled');
      if (controller.signal.aborted) throw new AppError('timeout');
      throw AppError.from(e);
    } finally {
      clearTimeout(timer);
      signal?.removeEventListener('abort', onAbort);
    }
    if (response.status === 404) throw new AppError('notFound', 404);
    if (response.status === 400) {
      // WordPress answers 400 rest_post_invalid_page_number past the last page.
      const body = (await response.json().catch(() => null)) as { code?: string } | null;
      if (body?.code === 'rest_post_invalid_page_number') throw new AppError('notFound', 400, body.code);
      throw new AppError('badResponse', 400);
    }
    if (!response.ok) throw new AppError('server', response.status);
    let data: T;
    try {
      data = (await response.json()) as T;
    } catch {
      throw new AppError('badResponse', response.status);
    }
    const result = {
      data,
      total: intHeader(response.headers, 'x-wp-total'),
      totalPages: intHeader(response.headers, 'x-wp-totalpages'),
      stale: false,
    };
    // A full or broken cache must never turn a good response into an error.
    await writeCache(key, { savedAt: Date.now(), data, total: result.total, totalPages: result.totalPages }).catch(() => {});
    return result;
  } catch (e) {
    const failure = AppError.from(e);
    if (cached && failure.kind !== 'cancelled' && failure.kind !== 'notFound') {
      return { data: cached.data as T, total: cached.total, totalPages: cached.totalPages, stale: true };
    }
    throw failure;
  }
}

export const MINUTES = (n: number) => n * MINUTE;
export const HOURS = (n: number) => n * 60 * MINUTE;
