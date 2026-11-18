import AsyncStorage from '@react-native-async-storage/async-storage';
import { clearCache } from '@/api/cache';
import { StartupDirectoryUnavailable } from '@/api/errors';
import { activeFilterCount, fetchStartup, fetchStartupFilters, fetchStartups, mapFilters, mapStartup, startupQueryParams } from '@/api/startups';
import { paramsToQuery, queryToParams } from '@/features/startups/params';
import { STARTUP_SORTS } from '@/models/types';
import { fakeFetch } from '@/testing/fakeFetch';

beforeEach(async () => {
  await clearCache();
  await AsyncStorage.clear();
});

const vast = {
  id: 7,
  slug: 'vast',
  name: 'Vast',
  link: 'https://allbiohub.com/startups/vast/',
  tagline: 'Haven-1, a commercial space station',
  logo: 'https://allbiohub.com/logo.png',
  industry: 'Habitats',
  country: 'United States',
  city: 'Long Beach',
  founded: '2021',
  business_model: 'B2B',
  social: { linkedin: 'https://l', x: '' },
  founders: [{ name: 'Jed', role: 'Founder', url: null }],
  products: ['Haven-1'],
  verified: 'yes',
  claimed: true,
  featured: false,
};

it('maps the add-on startup object', () => {
  const s = mapStartup(vast);
  expect(s).toMatchObject({ id: 7, founded: 2021, businessModel: 'B2B', social: { linkedin: 'https://l' }, founders: [{ name: 'Jed', role: 'Founder', url: undefined }] });
  // Badges only when the database says exactly true.
  expect([s.verified, s.claimed, s.featured]).toEqual([false, true, false]);
  expect(s.logo?.variants[0].url).toBe('https://allbiohub.com/logo.png');
});

it('offers the website’s seven sort options in order', () => {
  expect(STARTUP_SORTS.map((s) => s.key)).toEqual(['newest', 'updated', 'founded', 'oldest', 'name', 'featured', 'verified']);
});

it('sends only the filters that are set', () => {
  expect(startupQueryParams({ industry: 'saas', verified: true, featured: false, sort: 'name', search: '  ' })).toMatchObject({
    industry: 'saas',
    verified: 1,
    featured: 0,
    orderby: 'name',
    search: undefined,
  });
  expect(startupQueryParams({}).orderby).toBe('newest');
  expect(activeFilterCount({ industry: 'a', country: 'b', search: 'x', sort: 'name' })).toBe(2);
});

it('round-trips a query through route params', () => {
  const q = { industry: 'Fintech', foundedFrom: 2019, verified: true, sort: 'oldest' as const };
  expect(paramsToQuery(queryToParams(q))).toMatchObject(q);
  expect(paramsToQuery({ sort: 'bogus' }).sort).toBeUndefined();
});

it('accepts filter options as objects or strings', () => {
  expect(mapFilters({ industries: [{ value: 'saas', label: 'SaaS', count: 12 }, 'Fintech'], countries: [{ slug: 'ng', name: 'Nigeria' }] })).toMatchObject({
    industries: [{ value: 'saas', label: 'SaaS', count: 12 }, { value: 'Fintech', label: 'Fintech' }],
    countries: [{ value: 'ng', label: 'Nigeria' }],
    stages: [],
  });
});

it('reports the add-on as switched off on a 404', async () => {
  fakeFetch([[/allbiohub\/v1/, { status: 404, body: { code: 'rest_no_route' } }]]);
  await expect(fetchStartups({})).rejects.toBeInstanceOf(StartupDirectoryUnavailable);
  await expect(fetchStartupFilters()).rejects.toBeInstanceOf(StartupDirectoryUnavailable);
  // A missing profile is just not found.
  await expect(fetchStartup('nope')).rejects.toMatchObject({ kind: 'notFound' });
});

it('lists startups with totals and skips malformed records', async () => {
  const calls = fakeFetch([['/allbiohub/v1/startups', { body: [vast, { id: 'x' }], headers: { 'X-WP-Total': '208', 'X-WP-TotalPages': '11' } }]]);
  const page = await fetchStartups({ country: 'Nigeria', sort: 'verified' }, 2);
  expect(page).toMatchObject({ total: 208, totalPages: 11, page: 2 });
  expect(page.items.map((s) => s.slug)).toEqual(['vast']);
  expect(calls[0]).toContain('country=Nigeria');
  expect(calls[0]).toContain('orderby=verified');
  expect(calls[0]).toContain('page=2');
});
