import fs from 'node:fs';
import path from 'node:path';
import type { ConfigContext, ExpoConfig } from 'expo/config';

/**
 * AllBioHub app identity. The application ID must stay com.allbiohub.app and
 * every release must be signed with the same key as the Flutter releases, or
 * phones that already have the app refuse the update (RELEASE.md).
 */
const APP_ENV = process.env.EXPO_PUBLIC_APP_ENV ?? 'development';

/**
 * Shown to people as the version. Raise it with every release.
 * versionCode must go up by at least 1 for every APK or AAB you publish.
 * The Flutter app shipped versionCode 1 (pubspec `1.0.0+1`).
 */
const VERSION = '2.0.0';
const ANDROID_VERSION_CODE = 2;

const ANDROID_PACKAGE = 'com.allbiohub.app';
const IOS_BUNDLE_ID = 'com.allbiohub.app';

/** Brand colours, kept in sync with src/theme/tokens.ts. */
const LIGHT_BACKGROUND = '#F8F6F7';
const DARK_BACKGROUND = '#0B0B0D';

/**
 * Push notifications need the Firebase Android client file at build time.
 * Without it the app builds and runs with notifications switched off.
 */
const GOOGLE_SERVICES_FILE = process.env.GOOGLE_SERVICES_FILE ?? './google-services.json';
const HAS_FIREBASE = fs.existsSync(path.resolve(__dirname, GOOGLE_SERVICES_FILE));

/** EAS project id, set by `eas init` (RELEASE.md, "Building with EAS"). */
const EAS_PROJECT_ID = process.env.EAS_PROJECT_ID || undefined;

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'AllBioHub',
  slug: 'allbiohub',
  scheme: 'allbiohub',
  version: VERSION,
  orientation: 'portrait',
  icon: './assets/images/icon.png',
  userInterfaceStyle: 'automatic',
  backgroundColor: LIGHT_BACKGROUND,
  ios: {
    bundleIdentifier: IOS_BUNDLE_ID,
    supportsTablet: true,
    associatedDomains: ['applinks:allbiohub.com', 'applinks:www.allbiohub.com'],
    infoPlist: { ITSAppUsesNonExemptEncryption: false },
  },
  android: {
    package: ANDROID_PACKAGE,
    versionCode: ANDROID_VERSION_CODE,
    adaptiveIcon: {
      backgroundColor: '#FFFFFF',
      foregroundImage: './assets/images/android-icon-foreground.png',
      monochromeImage: './assets/images/android-icon-monochrome.png',
    },
    ...(HAS_FIREBASE ? { googleServicesFile: GOOGLE_SERVICES_FILE } : {}),
    predictiveBackGestureEnabled: false,
    // allbiohub.com links open in the app (App Links). Verification needs
    // https://allbiohub.com/.well-known/assetlinks.json with the release key's
    // SHA-256, the same file the Flutter app used.
    intentFilters: [
      {
        action: 'VIEW',
        autoVerify: true,
        data: [
          { scheme: 'https', host: 'allbiohub.com' },
          { scheme: 'https', host: 'www.allbiohub.com' },
        ],
        category: ['BROWSABLE', 'DEFAULT'],
      },
    ],
    permissions: [
      'android.permission.INTERNET',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.POST_NOTIFICATIONS',
    ],
    blockedPermissions: [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.RECORD_AUDIO',
      'android.permission.CAMERA',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.SYSTEM_ALERT_WINDOW',
      'android.permission.READ_PHONE_STATE',
    ],
  },
  web: {
    output: 'single',
    favicon: './assets/images/favicon.png',
  },
  plugins: [
    'expo-router',
    'expo-status-bar',
    [
      'expo-splash-screen',
      {
        image: './assets/images/splash-icon.png',
        imageWidth: 120,
        resizeMode: 'contain',
        backgroundColor: LIGHT_BACKGROUND,
        dark: { backgroundColor: DARK_BACKGROUND, image: './assets/images/splash-icon.png' },
      },
    ],
    'expo-font',
    'expo-image',
    'expo-web-browser',
    [
      'expo-build-properties',
      {
        ios: { useFrameworks: 'static' },
        android: { enableMinifyInReleaseBuilds: true, enableShrinkResourcesInReleaseBuilds: true },
      },
    ],
    ...(HAS_FIREBASE ? ['@react-native-firebase/app', '@react-native-firebase/messaging'] : []),
    // Signs release builds with the existing AllBioHub key when the
    // ALLBIOHUB_UPLOAD_* variables are set (GitHub Release workflow).
    './plugins/with-release-signing',
  ],
  experiments: {
    typedRoutes: true,
  },
  extra: {
    appEnv: APP_ENV,
    hasFirebase: HAS_FIREBASE,
    ...(EAS_PROJECT_ID ? { eas: { projectId: EAS_PROJECT_ID } } : {}),
  },
});
