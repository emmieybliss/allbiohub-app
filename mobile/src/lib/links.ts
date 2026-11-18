import { router } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { Linking } from 'react-native';
import { env } from '@/config/env';
import { appPathFor, isSiteUrl } from './deepLinks';
import { brand } from '@/theme/tokens';

/**
 * allbiohub.com stories, categories and startups open in the app; other
 * allbiohub.com pages (forms, account) open in an in-app browser tab;
 * external sites open in the browser or their own app. Only http(s), mailto
 * and tel are followed.
 */
export async function openLink(raw: string): Promise<void> {
  let url: URL;
  try {
    url = new URL(raw, env.siteUrl);
  } catch {
    return;
  }
  const href = url.toString();
  if (url.protocol === 'mailto:' || url.protocol === 'tel:') {
    await Linking.openURL(href).catch(() => {});
    return;
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return;
  const inApp = appPathFor(href, env.siteHost);
  if (inApp) {
    router.push(inApp as never);
    return;
  }
  if (isSiteUrl(url, env.siteHost)) {
    await openInAppBrowser(href);
    return;
  }
  await Linking.openURL(href).catch(() => openInAppBrowser(href));
}

export async function openInAppBrowser(href: string): Promise<void> {
  await WebBrowser.openBrowserAsync(href, {
    toolbarColor: brand.purple,
    controlsColor: brand.purple,
    showTitle: true,
  }).catch(() => Linking.openURL(href).catch(() => {}));
}
