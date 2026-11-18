import AsyncStorage from '@react-native-async-storage/async-storage';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react-native';
import type { ReactElement } from 'react';
import { clearCache } from '@/api/cache';
import StartupsScreen from '@/app/(tabs)/startups';
import SavedScreen from '@/app/(tabs)/saved';
import { ArticleBody } from '@/features/articles/ArticleBody';
import { fakeFetch } from '@/testing/fakeFetch';

jest.mock('react-native-safe-area-context', () => {
  const inset = { top: 0, right: 0, bottom: 0, left: 0 };
  return { useSafeAreaInsets: () => inset, SafeAreaProvider: ({ children }: { children: ReactElement }) => children };
});

function wrap(ui: ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: Infinity } } });
  return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>);
}

beforeEach(async () => {
  await clearCache();
  await AsyncStorage.clear();
});

it('explains the startup directory is coming when the add-on is off', async () => {
  fakeFetch([[/allbiohub\/v1/, { status: 404, body: { code: 'rest_no_route' } }]]);
  await wrap(<StartupsScreen />);
  expect(await screen.findByText('The startup directory is on its way')).toBeTruthy();
});

it('shows the website layout of the Startups tab', async () => {
  fakeFetch([
    ['/startups/filters', { body: { industries: [{ value: 'Fintech', label: 'Fintech', count: 40 }], countries: ['Nigeria', 'Kenya'] } }],
    [
      '/allbiohub/v1/startups',
      { body: [{ id: 1, slug: 'paystack', name: 'Paystack', link: 'https://allbiohub.com/startups/paystack/', verified: true }], headers: { 'X-WP-Total': '208' } },
    ],
  ]);
  await wrap(<StartupsScreen />);
  expect(await screen.findByText('Discover African Startups')).toBeTruthy();
  expect(screen.getByText('Browse by industry')).toBeTruthy();
  expect(screen.getByText('Browse by country')).toBeTruthy();
  expect(screen.getByText('Recently added')).toBeTruthy();
  expect(screen.getByText('Verified first')).toBeTruthy();
  expect(await screen.findAllByText('Paystack')).toBeTruthy();
  expect(await screen.findByLabelText('Startups: 208')).toBeTruthy();
});

it('shows an empty Saved tab', async () => {
  await wrap(<SavedScreen />);
  expect(screen.getByText('Nothing saved yet.')).toBeTruthy();
});

it('renders story HTML natively', async () => {
  await render(<ArticleBody html={'<h2>Career</h2><p>She founded <a href="https://allbiohub.com/startups/x/">X</a>.</p><iframe src="https://www.youtube.com/embed/abc"></iframe>'} scale={1} />);
  expect(screen.getByText('Career')).toBeTruthy();
  expect(screen.getByText('Watch on YouTube')).toBeTruthy();
  expect(screen.getByRole('link', { name: 'X' })).toBeTruthy();
});
