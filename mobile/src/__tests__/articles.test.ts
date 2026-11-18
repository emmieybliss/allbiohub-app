import AsyncStorage from '@react-native-async-storage/async-storage';
import { clearCache } from '@/api/cache';
import { fetchLatest, searchArticles } from '@/api/articles';
import { fakeFetch } from '@/testing/fakeFetch';

beforeEach(async () => {
  await clearCache();
  await AsyncStorage.clear();
});

const bare = (id: number) => ({
  id,
  slug: `s${id}`,
  link: `https://allbiohub.com/s${id}/`,
  date_gmt: '2026-10-01T09:00:00',
  title: { rendered: `Story ${id}` },
  excerpt: { rendered: '' },
  author: 3,
  featured_media: 10 + id,
  categories: [137],
  tags: [],
});

it('fills in authors, images and categories in one batched request each', async () => {
  const calls = fakeFetch([
    ['/wp/v2/posts', { body: [bare(1), bare(2)], headers: { 'X-WP-TotalPages': '5' } }],
    ['/wp/v2/media', { body: [{ id: 11, source_url: 'https://x/11.jpg' }, { id: 12, source_url: 'https://x/12.jpg' }] }],
    ['/wp/v2/users', { body: [{ id: 3, name: 'Ada', slug: 'ada' }] }],
    ['/wp/v2/categories', { body: [{ id: 137, name: 'Celebrity News', slug: 'celebrity-news', count: 9 }] }],
  ]);
  const page = await fetchLatest({ perPage: 2 });
  expect(page.totalPages).toBe(5);
  expect(page.items.map((a) => [a.author?.name, a.image?.variants[0].url, a.categories[0]?.name])).toEqual([
    ['Ada', 'https://x/11.jpg', 'Celebrity News'],
    ['Ada', 'https://x/12.jpg', 'Celebrity News'],
  ]);
  expect(calls.filter((c) => c.includes('/media')).length).toBe(1);
  expect(calls.find((c) => c.includes('/media'))).toContain('include=11%2C12');
  expect(calls.find((c) => c.includes('/users'))).toContain('include=3');
});

it('still shows stories when the extra details fail', async () => {
  fakeFetch([['/wp/v2/posts', { body: [bare(1)] }]]);
  const page = await fetchLatest();
  expect(page.items[0].title).toBe('Story 1');
  expect(page.items[0].author).toBeUndefined();
});

it('ends a list cleanly past the last page', async () => {
  fakeFetch([['/wp/v2/posts', { status: 400, body: { code: 'rest_post_invalid_page_number' } }]]);
  expect((await fetchLatest({ page: 4 })).items).toEqual([]);
  expect((await searchArticles('x', 3)).items).toEqual([]);
});
