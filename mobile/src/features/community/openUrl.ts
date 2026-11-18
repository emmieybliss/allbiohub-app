import { router } from 'expo-router';
import { env } from '@/config/env';
import { appPathFor } from '@/lib/deepLinks';
import { openLink } from '@/lib/links';

/** Opens a notification's link: an app path, an allbiohub.com page in the app, or anything else in the browser. */
export function openNotificationUrl(url: string) {
  if (!url) return;
  if (url.startsWith('/')) {
    router.push(url as never);
    return;
  }
  const path = appPathFor(url, env.siteHost);
  if (path) router.push(path as never);
  else void openLink(url);
}
