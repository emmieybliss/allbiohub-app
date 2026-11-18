import AsyncStorage from '@react-native-async-storage/async-storage';
import { clearCache } from '@/api/cache';
import { AppError } from '@/api/errors';
import { buildUrl, getJson } from '@/api/http';
import { fakeFetch } from '@/testing/fakeFetch';

beforeEach(async () => {
  await clearCache();
  await AsyncStorage.clear();
});

it('builds query strings without empty values', () => {
  expect(buildUrl('https://a/b', { page: 1, q: 'x y', none: undefined, empty: '', no: null })).toBe('https://a/b?page=1&q=x%20y');
});

it('reads pagination headers and serves a fresh copy from the cache', async () => {
  const calls = fakeFetch([['/posts', { body: [1, 2], headers: { 'X-WP-Total': '30', 'X-WP-TotalPages': '3' } }]]);
  const first = await getJson('https://s/posts', { query: { page: 1 } });
  expect(first).toEqual({ data: [1, 2], total: 30, totalPages: 3, stale: false });
  const second = await getJson('https://s/posts', { query: { page: 1 } });
  expect(second.stale).toBe(false);
  expect(calls).toHaveLength(1);
  await getJson('https://s/posts', { query: { page: 1 }, forceRefresh: true });
  expect(calls).toHaveLength(2);
});

it('falls back to the last copy, marked stale, when offline', async () => {
  fakeFetch([['/posts', { body: ['cached'] }]]);
  await getJson('https://s/posts');
  fakeFetch([]); // every request fails
  const r = await getJson('https://s/posts', { forceRefresh: true });
  expect(r).toMatchObject({ data: ['cached'], stale: true });
});

it('raises offline when nothing is cached', async () => {
  fakeFetch([]);
  await expect(getJson('https://s/none')).rejects.toMatchObject({ kind: 'offline' });
});

it('never serves a cached copy for a 404', async () => {
  fakeFetch([['/thing', { body: { ok: 1 } }]]);
  await getJson('https://s/thing');
  fakeFetch([['/thing', { status: 404, body: { code: 'rest_no_route' } }]]);
  await expect(getJson('https://s/thing', { forceRefresh: true })).rejects.toMatchObject({ kind: 'notFound' });
});

it('treats the past-the-end page error as not found', async () => {
  fakeFetch([['/posts', { status: 400, body: { code: 'rest_post_invalid_page_number' } }]]);
  const e = await getJson('https://s/posts').catch((x) => x);
  expect(e).toBeInstanceOf(AppError);
  expect(e.kind).toBe('notFound');
});

it('reports server errors', async () => {
  fakeFetch([['/posts', { status: 503, body: {} }]]);
  await expect(getJson('https://s/posts')).rejects.toMatchObject({ kind: 'server', status: 503 });
});
