import Constants from 'expo-constants';

/**
 * Public build settings (EXPO_PUBLIC_*). Everything here ships inside the app,
 * so never put secrets in these variables.
 */
function trimSlash(url: string) {
  return url.replace(/\/+$/, '');
}

const siteUrl = trimSlash(process.env.EXPO_PUBLIC_SITE_URL || 'https://allbiohub.com');
const startupApiPath = process.env.EXPO_PUBLIC_STARTUP_API_PATH || '/wp-json/allbiohub/v1';

export const env = {
  appEnv: (process.env.EXPO_PUBLIC_APP_ENV || 'production') as 'development' | 'staging' | 'production',
  siteUrl,
  siteHost: new URL(siteUrl).host,
  wordpressApi: `${siteUrl}/wp-json/wp/v2`,
  startupApi: `${siteUrl}${startupApiPath}`,
  privacyPolicyUrl: process.env.EXPO_PUBLIC_PRIVACY_POLICY_URL ?? 'https://allbiohub.com/privacy-policy/',
  termsUrl: process.env.EXPO_PUBLIC_TERMS_URL ?? 'https://allbiohub.com/terms-and-conditions/',
  contactEmail: process.env.EXPO_PUBLIC_CONTACT_EMAIL ?? 'hello@allbiohub.com',
  /** True when the build included google-services.json (push notifications). */
  hasFirebase: Boolean(Constants.expoConfig?.extra?.hasFirebase),
  version: Constants.expoConfig?.version ?? '',
};

export function sitePage(path: string) {
  return `${env.siteUrl}/${path.replace(/^\/+/, '')}`;
}
