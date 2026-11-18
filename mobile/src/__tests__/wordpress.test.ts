import { mapArticle, mapArticles, mapAuthor, mapMedia } from '@/api/wordpress';
import { imageUrlFor } from '@/lib/images';

const post = {
  id: 42,
  slug: 'wizkid-net-worth',
  link: 'https://allbiohub.com/wizkid-net-worth/',
  date_gmt: '2026-10-01T09:30:00',
  modified_gmt: '2026-10-02T10:00:00',
  title: { rendered: 'Wizkid&#8217;s net worth &amp; more' },
  excerpt: { rendered: '<p>The singer&#8217;s story [&hellip;]</p>' },
  content: { rendered: '<p>' + 'word '.repeat(440) + '</p>' },
  author: 3,
  featured_media: 9,
  categories: [137, 1],
  tags: [5],
  sticky: true,
  _embedded: {
    author: [{ id: 3, name: 'Ada &amp; Co', slug: 'ada', avatar_urls: { '24': 'a24', '96': 'a96' } }],
    'wp:featuredmedia': [
      {
        id: 9,
        source_url: 'https://x/full.jpg',
        alt_text: 'Wizkid',
        media_details: {
          width: 2000,
          height: 1000,
          sizes: {
            thumbnail: { source_url: 'https://x/150.jpg', width: 150, height: 150 },
            medium: { source_url: 'https://x/600.jpg', width: 600, height: 300 },
            large: { source_url: 'https://x/1200.jpg', width: 1200, height: 600 },
          },
        },
      },
    ],
    'wp:term': [
      [
        { id: 1, name: 'Biography', slug: 'biography', taxonomy: 'category' },
        { id: 137, name: 'Celebrity News', slug: 'celebrity-news', taxonomy: 'category' },
      ],
      [{ id: 5, name: 'Afrobeats', slug: 'afrobeats', taxonomy: 'post_tag' }],
    ],
  },
};

describe('mapArticle', () => {
  it('maps a full post with embeds', () => {
    const a = mapArticle(post);
    expect(a.title).toBe('Wizkid’s net worth & more');
    expect(a.excerpt).toBe('The singer’s story…');
    expect(a.publishedAt).toBe('2026-10-01T09:30:00.000Z');
    expect(a.author).toEqual({ id: 3, name: 'Ada & Co', slug: 'ada', avatarUrl: 'a96', description: undefined });
    // Primary category first, in the post's own order, not alphabetical.
    expect(a.categories.map((c) => c.slug)).toEqual(['celebrity-news', 'biography']);
    expect(a.tags.map((t) => t.slug)).toEqual(['afrobeats']);
    expect(a.readingMinutes).toBe(2);
    expect(a.sticky).toBe(true);
  });

  it('keeps ids when the server ignores _embed', () => {
    const { _embedded, ...bare } = post;
    const a = mapArticle(bare);
    expect(a.author).toBeUndefined();
    expect(a.image).toBeUndefined();
    expect(a.categories).toEqual([]);
    expect(a.authorId).toBe(3);
    expect(a.featuredMediaId).toBe(9);
    expect(a.categoryIds).toEqual([137, 1]);
    expect(a.tagIds).toEqual([5]);
  });

  it('ignores error objects in embeds', () => {
    const a = mapArticle({ ...post, _embedded: { author: [{ code: 'rest_user_invalid_id' }], 'wp:featuredmedia': [{ code: 'rest_forbidden' }] } });
    expect(a.author).toBeUndefined();
    expect(a.image).toBeUndefined();
  });

  it('skips a malformed post in a list', () => {
    expect(mapArticles([post, { nope: true }, 'x']).map((a) => a.id)).toEqual([42]);
  });
});

describe('media', () => {
  const image = mapMedia(post._embedded['wp:featuredmedia'][0])!;

  it('sorts renditions smallest first', () => {
    expect(image.variants.map((v) => v.w)).toEqual([150, 600, 1200, 2000]);
    expect(image.alt).toBe('Wizkid');
  });

  it('picks the smallest sharp, uncropped rendition', () => {
    expect(imageUrlFor(image, 500)).toBe('https://x/600.jpg');
    expect(imageUrlFor(image, 100)).toBe('https://x/600.jpg');
    expect(imageUrlFor(image, 100, true)).toBe('https://x/150.jpg');
    expect(imageUrlFor(image, 5000)).toBe('https://x/full.jpg');
  });
});

it('rejects an author error object', () => {
  expect(mapAuthor({ code: 'rest_user_invalid_id' })).toBeUndefined();
});
