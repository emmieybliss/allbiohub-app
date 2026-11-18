import { articleFromSyncJson, articleToSyncJson } from '@/features/community/articleJson';
import { CommunityError, OFFLINE_MESSAGE, toCommunityError } from '@/features/community/errors';
import {
  flagsFromConfig,
  isOn,
  mapPoll,
  normalizeUsername,
  pollIsOpen,
  pollPercentages,
  pollWithVote,
  slugify,
  titleFromSlug,
  usernameRule,
  wants,
  withReactionChange,
} from '@/features/community/models';
import type { Article } from '@/models/types';

describe('feature flags', () => {
  it('reads only switches that are exactly true', () => {
    expect(flagsFromConfig({ features: { accounts: true, comments: true, polls: 'yes', made_up: true } })).toEqual(['accounts', 'comments']);
    expect(flagsFromConfig(null)).toEqual([]);
    expect(flagsFromConfig({ features: 'all' })).toEqual([]);
  });

  it('keeps account features off without accounts', () => {
    expect(isOn(['comments'], 'comments')).toBe(false);
    expect(isOn(['accounts', 'comments'], 'comments')).toBe(true);
    // For you works without an account.
    expect(isOn(['forYou'], 'forYou')).toBe(true);
    expect(isOn([], 'accounts')).toBe(false);
  });
});

describe('usernames', () => {
  it('normalises and checks the rules', () => {
    expect(normalizeUsername('  @Ada_L ')).toBe('ada_l');
    expect(usernameRule('ab')).toBeTruthy();
    expect(usernameRule('a'.repeat(21))).toBeTruthy();
    expect(usernameRule('ada lovelace')).toBeTruthy();
    expect(usernameRule('ada_l')).toBeNull();
  });
});

describe('founder slugs match the server', () => {
  // Same cases as firebase/functions/test/unit/validation.test.ts.
  it.each([
    ['Tosin Eniolorunda', 'tosin-eniolorunda'],
    ['  Olúgbénga  Agboola! ', 'olugbenga-agboola'],
    ['Adébáyọ̀ Ọlọ́rùnṣọlá', 'adebayo-olorunsola'],
    ['Jürgen Straße', 'jurgen-strasse'],
  ])('%s', (name, slug) => {
    expect(slugify(name)).toBe(slug);
  });

  it('turns a slug back into a name', () => {
    expect(titleFromSlug('tosin-eniolorunda')).toBe('Tosin Eniolorunda');
  });
});

describe('polls', () => {
  const poll = mapPoll('p1', {
    kind: 'poll',
    question: 'Best hub?',
    options: [
      { id: 'a', label: 'Lagos' },
      { id: 'b', label: 'Nairobi' },
      { id: 'c', label: 'Cairo' },
    ],
    status: 'active',
    counts: { a: 1, b: 1, c: 1 },
    totalVotes: 3,
  });

  it('gives whole percentages that add up to 100', () => {
    const pct = pollPercentages(poll);
    expect(Object.values(pct).reduce((a, b) => a + b, 0)).toBe(100);
    expect(Object.values(pct).sort()).toEqual([33, 33, 34]);
  });

  it('shows zeros before anyone votes', () => {
    expect(pollPercentages({ ...poll, counts: {}, totalVotes: 0 })).toEqual({ a: 0, b: 0, c: 0 });
  });

  it('never rounds an option nobody chose above zero', () => {
    const pct = pollPercentages({ ...poll, counts: { a: 2, b: 1 }, totalVotes: 3 });
    expect(pct.c).toBe(0);
    expect(pct.a + pct.b).toBe(100);
  });

  it('applies a first vote and a changed vote', () => {
    const first = pollWithVote(poll, null, 'a');
    expect(first.counts.a).toBe(2);
    expect(first.totalVotes).toBe(4);
    const changed = pollWithVote(first, 'a', 'b');
    expect(changed.counts).toEqual({ a: 1, b: 2, c: 1 });
    expect(changed.totalVotes).toBe(4);
  });

  it('closes at its expiry time', () => {
    const now = new Date('2026-11-18T12:00:00Z');
    expect(pollIsOpen({ ...poll, expiresAt: new Date('2026-11-19T00:00:00Z') }, now)).toBe(true);
    expect(pollIsOpen({ ...poll, expiresAt: new Date('2026-11-18T00:00:00Z') }, now)).toBe(false);
    expect(pollIsOpen({ ...poll, status: 'closed' }, now)).toBe(false);
  });
});

it('moves a reaction from one kind to another', () => {
  const e = { reactions: { love: 2, wow: 1 } } as unknown as Parameters<typeof withReactionChange>[0];
  const next = withReactionChange(e, 'love', 'wow');
  expect(next.reactions).toMatchObject({ love: 1, wow: 2 });
});

it('turns account notification choices on by default, except promotions', () => {
  expect(wants(null, 'commentActivity')).toBe(true);
  expect(wants(null, 'marketing')).toBe(false);
  expect(wants({ status: 'active', notificationPrefs: { commentActivity: false } }, 'commentActivity')).toBe(false);
});

describe('errors', () => {
  it('maps Firebase codes to plain messages', () => {
    expect(toCommunityError({ code: 'auth/network-request-failed' }).message).toBe(OFFLINE_MESSAGE);
    expect(toCommunityError({ code: 'auth/email-already-in-use' })).toMatchObject({ kind: 'alreadyExists', field: 'email' });
    expect(toCommunityError({ code: 'functions/unauthenticated' }).kind).toBe('signInRequired');
    expect(toCommunityError({ code: 'functions/resource-exhausted' }).kind).toBe('rateLimited');
  });

  it('keeps a CommunityError as it is', () => {
    const e = new CommunityError('notFound');
    expect(toCommunityError(e)).toBe(e);
    expect(toCommunityError(undefined).kind).toBe('unknown');
  });
});

describe('saved stories shared with the Flutter app', () => {
  const article: Article = {
    id: 42,
    slug: 'meet-ada',
    link: 'https://allbiohub.com/meet-ada/',
    title: 'Meet Ada',
    excerpt: 'Founder story',
    publishedAt: '2026-10-01T09:00:00',
    modifiedAt: '2026-10-02T09:00:00',
    author: { id: 3, name: 'Editor', slug: 'editor', avatarUrl: undefined },
    image: { variants: [{ url: 'https://allbiohub.com/a.jpg', w: 800, h: 450 }], alt: 'Ada', caption: '' },
    categories: [{ id: 5, name: 'Founders', slug: 'founders', kind: 'category', count: 10, description: '', parentId: 0 }],
    tags: [],
    categoryIds: [5],
    readingMinutes: 4,
    sticky: false,
    authorId: 3,
    featuredMediaId: 9,
    tagIds: [],
  };

  it('uses the Flutter field names', () => {
    const json = articleToSyncJson(article);
    expect(json).toMatchObject({ id: 42, published: '2026-10-01T09:00:00', modified: '2026-10-02T09:00:00' });
    expect((json.image as { v: unknown[] }).v).toHaveLength(1);
    expect((json.categories as { parent: number }[])[0].parent).toBe(0);
  });

  it('reads back what it wrote, as an object or a string', () => {
    const json = articleToSyncJson(article);
    for (const raw of [json, JSON.stringify(json)]) {
      const back = articleFromSyncJson(raw);
      expect(back).toMatchObject({ id: 42, slug: 'meet-ada', title: 'Meet Ada', publishedAt: article.publishedAt, categoryIds: [5] });
      expect(back?.image?.variants[0].url).toBe('https://allbiohub.com/a.jpg');
    }
  });

  it('skips items it cannot read', () => {
    expect(articleFromSyncJson('not json')).toBeNull();
    expect(articleFromSyncJson({ id: 'x' })).toBeNull();
  });
});
