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
- **Community (switched off until set up):** accounts, profiles, reactions,
  comments, follows, polls, notifications and submissions, on Firebase. Each
  feature is turned on remotely; see [COMMUNITY.md](COMMUNITY.md) for the
  setup checklist.

Docs: [ARCHITECTURE.md](ARCHITECTURE.md) · [API.md](API.md) ·
[COMMUNITY.md](COMMUNITY.md) · [RELEASE.md](RELEASE.md) · [TESTING.md](TESTING.md)

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
| `PRIVACY_POLICY_URL` | site privacy policy page | Profile → Privacy → full policy; also the Play Console privacy policy link |
| `TERMS_URL` | site terms page | Profile → Terms |
| `CONTACT_EMAIL` | empty | Profile → Contact (hidden when empty) |
| `FIREBASE_*` | empty | Firebase options (below) |

## API configuration

The app reads the public WordPress REST API; every endpoint is listed in
[API.md](API.md). To point at a staging site, set `WORDPRESS_BASE_URL`.

## Firebase (notifications and analytics)

The app already contains push notifications (Firebase Cloud Messaging) and
anonymous analytics (Firebase Analytics). Both stay off until a build is
given a Firebase project's settings. Without them the app works normally,
and Profile → Notifications says push isn't on yet.

### Connect a new Firebase project (about 10 minutes, no code)

1. Go to [console.firebase.google.com](https://console.firebase.google.com),
   sign in with the Google account that should own the app, and click
   **Create a project**. Name it `AllBioHub`. When asked about Google
   Analytics, leave it **on** and pick or create an Analytics account.
2. On the project's home page, click the **Android** icon ("Add app").
   - Android package name: `com.allbiohub.app` (exactly)
   - App nickname: `AllBioHub Android`
   - Debug signing certificate: leave empty
   - Click **Register app**.
3. Firebase offers `google-services.json`. Download it, but **don't add it
   to the project** (it's git-ignored and the app doesn't need it). Skip the
   remaining "Add Firebase SDK" steps; the app already has them.
4. Open the downloaded `google-services.json` in a text editor and copy four
   values into the repository's Actions secrets (RELEASE.md, step 2), and
   into your `.env.prod` if you build on your own computer. Keep them out of
   `.env.example`, which is in Git:

   | Name | Where it is in `google-services.json` |
   |---|---|
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |
   | `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` |
   | `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` (starts with `1:`) |
   | `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` (starts with `AIza`) |

   These identify the app and are safe inside it. They are not the
   server key or a service-account file, which never go in the app.
5. Build the release as in RELEASE.md. On first launch the app connects to
   Firebase; turning on a topic in Profile → Notifications asks for the
   notification permission and subscribes to that topic.
6. CI (`tool/ci/write_env.sh`) fills the four secrets into the build
   settings, so the test APK from every change and the signed Release build
   both have Firebase. Without the secrets, those builds have it off.

### Sending a notification

In the Firebase console: **Engage → Messaging → New campaign → Firebase
Notification messages**.

1. Write the title and text (for example the headline).
2. Target: **Topic**, one of `breaking`, `celebrity`, `technology`,
   `startups`, `money`, `biography`, `spotlight`.
3. Under **Additional options → Custom data**, add key `url` with the story's
   allbiohub.com link. Tapping the notification opens that story (or
   startup, category or tag) in the app.
4. Publish.

### What the app sends to Firebase

- Notifications: a device token and the topics the person turned on.
- Analytics: content events only (story or startup opened, shared or
  saved, searches, category views) with ids and slugs, never names or
  emails. The advertising id is removed from the app and ad
  personalisation is off (AndroidManifest.xml).

### How it's wired

`lib/core/services/firebase_services.dart`: `initializeFirebase` starts
Firebase from the env values (never from a bundled file),
`FirebaseNotificationService` handles topics and taps, and
`FirebaseAnalyticsService` forwards `AnalyticsEvent`s. `main.dart` swaps them
in only when Firebase started; `app.dart` opens tapped links through
`DeepLinkParser`.

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
(debug-signed) test APK to each run. The Release workflow
(`.github/workflows/release.yml`, run by hand) builds the signed APK and
Play Store bundle.

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
themed icon, Android 12 splash, only the INTERNET and (asked when a topic is
turned on) notification permissions, no advertising id, HTTPS-only
network config, no background work, backup rules that skip the API cache.
The privacy policy is live at https://allbiohub.com/privacy-policy/ and
linked from Profile → Privacy; use the same link in the Play Console.
Still needed: the release key (RELEASE.md), store listing text and
screenshots, the content rating questionnaire, and the Data safety form (the
Privacy text in Profile summarizes what the app does). The Release workflow
builds the AAB.

## Brand assets

The launcher icon (adaptive and themed), splash images, Play Store icon and
in-app logo all come from the official AllBioHub Media logo in
`tool/brand/allbiohub_media_logo.jpg`. If the logo changes, replace that
file and run `python3 tool/brand/make_icons.py` (needs Pillow and numpy).

## Known limitations

- **Startup directory needs the add-on.** Until the AllBioHub App API plugin
  is installed and switched on (wordpress/allbiohub-app-api), the Startups
  tab, startup search and profiles show a "coming soon" state with links to
  the website.
- **No trending or editor's picks.** The site has no public endpoint for
  them; Featured uses sticky posts, else the newest stories.
- **Coverage is a name match.** Startup coverage searches stories for the
  startup's name; an explicit relationship in the API would be more precise.
- **Community features need Firebase setup** (COMMUNITY.md). Until then the
  app has no accounts and bookmarks stay on the device.
- **Website gaps:** no Technology/Spotlight categories exist on the site
  yet; the app adapts to whatever categories exist.

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter.sdk not set in local.properties` | Run `flutter pub get` once, or open the project in Android Studio |
| Release build signed with the debug key | `android/key.properties` is missing (local builds) or the key secrets are missing (Release workflow); see RELEASE.md |
| Links open a chooser instead of the app | `assetlinks.json` missing or fingerprint wrong; check `adb shell pm get-app-links com.allbiohub.app` |
| Everything shows "You're offline" | Check `WORDPRESS_BASE_URL`, and that the device can open the site in a browser |
| Startups tab says "on its way" | Install the AllBioHub App API plugin and switch it on under Tools (wordpress/allbiohub-app-api) |
| Old content after a site change | Profile → Clear cached content, or pull to refresh |
