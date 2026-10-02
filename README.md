# AllBioHub

The AllBioHub Android app: stories from [allbiohub.com](https://allbiohub.com)
and the African startup directory, in a native Flutter app (no WebView).

*Discover the people, stories and ideas shaping Africa.*

- **Stories:** Home feed, Discover, search, a native article reader with text
  size and dark mode, sharing, and saved stories that work offline.
- **Startups:** discovery rails, directory search and filters, and profiles
  with AllBioHub coverage. These read the startup API from the WordPress
  add-on in [wordpress/allbiohub-app-api](wordpress/allbiohub-app-api/README.md),
  which has to be installed on the website once.

Docs: [ARCHITECTURE.md](ARCHITECTURE.md) · [API.md](API.md) ·
[RELEASE.md](RELEASE.md) · [TESTING.md](TESTING.md)

## Requirements

| Tool | Version |
|---|---|
| Flutter | 3.47 stable (Dart 3.13) |
| Java | 17 |
| Android SDK | via Android Studio; compile/target SDK from Flutter defaults |

Application ID: `com.allbiohub.app`. App name: `AllBioHub`.

## Setup

```bash
flutter pub get
cp .env.example .env.dev   # edit if needed; .env.* files are git-ignored
flutter run --dart-define-from-file=.env.dev
```

Running without `--dart-define-from-file` uses production defaults
(`https://allbiohub.com`).

## Dependencies

| Package | Why |
|---|---|
| flutter_riverpod | State management and dependency injection |
| dio | HTTP client with cancellation and timeouts |
| go_router | Navigation, tab stacks, deep links |
| hive_ce, hive_ce_flutter | Local cache, bookmarks, settings |
| cached_network_image | Image disk cache, decode at display size |
| html | Parse WordPress HTML for native rendering |
| share_plus | Android share sheet |
| url_launcher | External links, in-app browser tabs, email |
| intl | Date formatting |
| package_info_plus | App version in Profile |

Fonts (bundled, SIL OFL): Playfair Display, Inter, in `assets/fonts`.

## Environment configuration

Public, build-time values only (see `lib/core/config/app_config.dart`).
Never put credentials, admin passwords or private keys here: anything in the
app can be extracted from the APK.

| Key | Default | Purpose |
|---|---|---|
| `APP_ENV` | `production` | `development` / `staging` / `production` |
| `WORDPRESS_BASE_URL` | `https://allbiohub.com` | Content source and canonical share links |
| `STARTUP_API_PATH` | `/wp-json/allbiohub/v1` | Startup directory API base path |
| `PRIVACY_POLICY_URL` | empty | Website privacy policy (Profile → Privacy) |
| `TERMS_URL` | site terms page | Profile → Terms |
| `CONTACT_EMAIL` | empty | Profile → Contact (hidden when empty) |
| `FIREBASE_*` | empty | Firebase options (below) |

## API configuration

The app reads the public WordPress REST API; every endpoint is listed in
[API.md](API.md). To point at a staging site, set `WORDPRESS_BASE_URL`.

## Firebase (notifications and analytics)

The architecture is in place and V1 ships with Firebase off: notification
preferences are saved, analytics events are logged in debug builds only.
To connect production Firebase:

1. Create a Firebase project and add an Android app with package
   `com.allbiohub.app`.
2. Put the public app options in your env file: `FIREBASE_PROJECT_ID`,
   `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`
   (these identify the app; they are not secrets, but keep the env file out of git).
3. `flutter pub add firebase_core firebase_messaging firebase_analytics`.
4. In `main.dart`, when `AppConfig.hasFirebase`, call
   `Firebase.initializeApp(options: FirebaseOptions(...))` from the config.
5. Implement `NotificationService` with FCM (subscribe to
   `NotificationTopic.topic` names, forward taps with a `url` data field to
   `DeepLinkParser`) and `AnalyticsService` with Firebase Analytics; override
   `notificationServiceProvider` / `analyticsProvider` in `main.dart`.
6. Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
   to `AndroidManifest.xml` (Android 13+ runtime permission; the app asks
   when someone turns a topic on).
7. Send notifications to topics (`breaking`, `celebrity`, `technology`,
   `startups`, `money`, `biography`, `spotlight`) with `data.url` set to the
   allbiohub.com link to open.

No server key or service-account JSON ever goes in the app.

## Build

```bash
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=.env.prod      # debug APK
flutter build apk --release --dart-define-from-file=.env.prod    # release APK
```

Output: `build/app/outputs/flutter-apk/`. Signing and distribution:
[RELEASE.md](RELEASE.md). GitHub Actions (`.github/workflows/ci.yml`) runs
format, analyze and tests on every push and attaches an installable
(debug-signed) release APK to each run.

## Deep linking (Android App Links)

The app claims `https://allbiohub.com/*` and `https://www.allbiohub.com/*`.
`DeepLinkParser` maps:

| Website URL | App screen |
|---|---|
| `/{post-slug}/` | Article |
| `/category/{slug}/` | Category feed |
| `/tag/{slug}/` | Tag feed |
| `/startups/` | Startups tab |
| `/startups/{slug}/` | Startup profile |
| `/` | Home |

Anything else (forms, account pages, admin) opens in a browser tab. To make
links open the app without a chooser, publish
`https://allbiohub.com/.well-known/assetlinks.json` (a static file; nothing
else on the site changes):

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.allbiohub.app",
    "sha256_cert_fingerprints": ["<release key SHA-256>"]
  }
}]
```

Get the fingerprint with
`keytool -list -v -keystore allbiohub-release.jks -alias allbiohub`.
If the app is later distributed through Play with Play App Signing, add the
Play signing key's fingerprint too. Test with
`adb shell am start -a android.intent.action.VIEW -d "https://allbiohub.com/startups/vast/"`.

## Play Store preparation

Already in place: final application ID, release signing via
`key.properties`, versioning from `pubspec.yaml`, R8 shrinking, adaptive and
themed icon, Android 12 splash, INTERNET as the only permission, HTTPS-only
network config, no background work, backup rules that skip the API cache.
Still needed: a privacy policy URL on the website (none is published today),
store listing text and screenshots, the content rating questionnaire, the
Data safety form (the Privacy text in Profile summarizes what the app does),
and an AAB build (`flutter build appbundle`).

## Known limitations

- **Startup directory needs the add-on.** Until the AllBioHub App API plugin
  is installed and switched on (wordpress/allbiohub-app-api), the Startups
  tab, startup search and profiles show a "coming soon" state with links to
  the website.
- **No trending or editor's picks.** The site has no public endpoint for
  them; Featured uses sticky posts, else the newest stories.
- **Coverage is a name match.** Startup coverage searches stories for the
  startup's name; an explicit relationship in the API would be more precise.
- **Icon is a placeholder monogram** (gold "A") generated from the brand
  fonts and colours. Replace `android/app/src/main/res/mipmap-*` and
  `assets/branding/play_store_icon_512.png` with the official logo.
- **Firebase is not connected** (see above).
- **No accounts or cloud sync** in V1; bookmarks are on-device.
- **Website gaps:** no Technology/Spotlight categories and no privacy policy
  page exist on the site yet; the app adapts to whatever categories exist.

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter.sdk not set in local.properties` | Run `flutter pub get` once, or open the project in Android Studio |
| Release build signed with the debug key | `android/key.properties` is missing; see RELEASE.md |
| Links open a chooser instead of the app | `assetlinks.json` missing or fingerprint wrong; check `adb shell pm get-app-links com.allbiohub.app` |
| Everything shows "You're offline" | Check `WORDPRESS_BASE_URL`, and that the device can open the site in a browser |
| Startups tab says "on its way" | Install the AllBioHub App API plugin and switch it on under Tools (wordpress/allbiohub-app-api) |
| Old content after a site change | Profile → Clear cached content, or pull to refresh |
