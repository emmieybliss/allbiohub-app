/**
 * Maps allbiohub.com URLs to app paths, so App Links, notification payloads
 * and links inside stories open natively. Returns null for URLs the app
 * doesn't handle (other sites, admin, forms such as List Your Startup);
 * callers open those in the browser.
 */
const RESERVED = new Set([
  'wp-admin',
  'wp-content',
  'wp-includes',
  'wp-json',
  'wp-login.php',
  'feed',
  'page',
  'search',
  'app',
  'list-your-startup',
  'claim-startup',
  'startup-account',
  'startup-dashboard',
  'startup-pricing',
  'submit-a-story',
  'terms-and-conditions',
  'privacy-policy',
  'contact',
  'about',
  'youtube-resources',
]);

export function isSiteUrl(url: URL, host: string): boolean {
  const h = url.hostname.toLowerCase();
  return (url.protocol === 'https:' || url.protocol === 'http:') && (h === host || h === `www.${host}`);
}

export const paths = {
  home: '/',
  discover: '/discover',
  startups: '/startups',
  article: (id: number) => `/article/${id}`,
  story: (slug: string) => `/story/${encodeURIComponent(slug)}`,
  category: (slug: string) => `/category/${encodeURIComponent(slug)}`,
  tag: (slug: string) => `/tag/${encodeURIComponent(slug)}`,
  author: (id: number) => `/author/${id}`,
  startup: (slug: string) => `/startup/${encodeURIComponent(slug)}`,
  directory: '/directory',
} as const;

export function appPathFor(raw: string, host: string): string | null {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  if (!isSiteUrl(url, host)) return null;
  const segments = url.pathname
    .split('/')
    .filter(Boolean)
    .map((s) => {
      try {
        return decodeURIComponent(s);
      } catch {
        return s;
      }
    });
  if (!segments.length) return paths.home;
  const first = segments[0].toLowerCase();
  switch (first) {
    case 'startups':
      if (segments.length === 1 || segments[1] === 'page') return paths.startups;
      return paths.startup(segments[1]);
    case 'category': {
      // Nested categories put the child last: /category/parent/child/.
      const rest = segments.slice(1).filter((s) => s !== 'page');
      if (!rest.length) return paths.discover;
      const named = rest.filter((s) => !/^\d+$/.test(s));
      return paths.category(named[named.length - 1] ?? rest[0]);
    }
    case 'tag':
      return segments.length < 2 ? paths.discover : paths.tag(segments[1]);
  }
  if (RESERVED.has(first) || first.includes('.') || first === 'author') return null;
  // Posts live at /{slug}/ ("post name" permalinks).
  if (segments.length === 1) return paths.story(segments[0]);
  return null;
}
