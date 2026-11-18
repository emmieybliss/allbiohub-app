import AsyncStorage from '@react-native-async-storage/async-storage';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen } from '@testing-library/react-native';
import type { ReactElement } from 'react';
import { clearCache } from '@/api/cache';
import StartupsScreen from '@/app/(tabs)/startups';
import SavedScreen from '@/app/(tabs)/saved';
import ProfileScreen from '@/app/(tabs)/profile';
import { setCommunity, unavailableApi, unavailableAuth } from '@/features/community/api';
import { useFlags, useSavedEntities, useSession } from '@/features/community/store';
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
  setCommunity(null);
  useFlags.setState({ on: [] });
  useSavedEntities.setState({ items: [], pending: [], importedFor: [] });
  useSession.setState({ ready: false, user: null, profile: undefined, unread: 0 });
});

/** A community backend that is "available" with the given switches on; every call fails, so nothing is faked. */
function communityWith(...on: string[]) {
  setCommunity({ auth: unavailableAuth, api: { ...unavailableApi, isAvailable: true } });
  useFlags.setState({ on: on as never });
}

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

it('keeps Profile free of account items while the community is off', async () => {
  await wrap(<ProfileScreen />);
  expect(screen.getByText('Your topics')).toBeTruthy();
  expect(screen.queryByText('Sign in or create an account')).toBeNull();
});

it('invites guests to join when accounts are switched on', async () => {
  communityWith('accounts');
  useSession.setState({ ready: true, user: null });
  await wrap(<ProfileScreen />);
  expect(screen.getByText('Join the AllBioHub community')).toBeTruthy();
  expect(screen.getByText('Sign in or create an account')).toBeTruthy();
});

it('shows a signed-in person their lists for the features that are on', async () => {
  communityWith('accounts', 'comments', 'polls');
  useSession.setState({ ready: true, user: { uid: 'u1', email: 'ada@example.com', emailVerified: true } as never, profile: null });
  await wrap(<ProfileScreen />);
  expect(screen.getByText('Choose a username')).toBeTruthy();
  expect(screen.getByText('My comments')).toBeTruthy();
  expect(screen.getByText('Polls')).toBeTruthy();
  expect(screen.queryByText('Startup watchlist')).toBeNull();
});

it('gives saved startups their own tab', async () => {
  useSavedEntities.setState({ items: [{ kind: 'startup', id: 'paystack', title: 'Paystack', subtitle: 'Fintech · Nigeria' }] });
  await wrap(<SavedScreen />);
  expect(screen.getByText('Stories 0')).toBeTruthy();
  await fireEvent.press(screen.getByText('Startups 1'));
  expect(screen.getByText('Paystack')).toBeTruthy();
  expect(screen.getByText('Fintech · Nigeria')).toBeTruthy();
});
