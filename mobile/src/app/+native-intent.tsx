import { env } from '@/config/env';
import { appPathFor } from '@/lib/deepLinks';

/** Paths the app has its own screens for (allbiohub:// links and notifications). */
const APP_PREFIXES = ['/article/', '/story/', '/category/', '/tag/', '/author/', '/startup/', '/directory'];
const APP_PAGES = new Set(['/', '/discover', '/startups', '/saved', '/profile', '/search', '/notifications', '/topics', '/about', '/privacy']);

/**
 * Translates incoming allbiohub.com links (App Links) into app routes, as
 * the Flutter DeepLinkParser did. Unknown website pages open Home.
 */
export function redirectSystemPath({ path }: { path: string; initial: boolean }): string {
  try {
    if (/^https?:\/\//i.test(path)) return appPathFor(path, env.siteHost) ?? '/';
    if (/^allbiohub:/i.test(path)) {
      // allbiohub://article/12 parses with "article" as the host.
      const url = new URL(path);
      const p = `${url.host ? `/${url.host}` : ''}${url.pathname}`.replace(/\/{2,}/g, '/');
      return p || '/';
    }
    if (APP_PAGES.has(path) || APP_PREFIXES.some((prefix) => path.startsWith(prefix))) return path;
    return appPathFor(`${env.siteUrl}${path.startsWith('/') ? path : `/${path}`}`, env.siteHost) ?? '/';
  } catch {
    return '/';
  }
}
