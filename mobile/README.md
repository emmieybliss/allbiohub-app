# AllBioHub app (Expo)

The AllBioHub Android app rebuilt with **Expo SDK 58** (React Native 0.88,
TypeScript, Expo Router), set up like the Simvaya app. It replaces the Flutter
app in the repository root once it has been tested; until then both live side
by side and the Flutter release keeps serving the website download.

Nothing about the website changes: the app reads the same public WordPress
REST API and the read-only startup add-on (`../wordpress/allbiohub-app-api`),
uses the same app ID (`com.allbiohub.app`), the same release key, the same
Firebase project and the same push topics. No WebView, no demo data.

## What's in it

| Tab / screen | Data |
|---|---|
| Home: featured carousel, latest, category rails, startups rail, endless "Keep reading" | `/wp/v2/posts` (sticky first), `/wp/v2/categories` |
| Discover: every section, popular topics, startups by industry | categories, tags, `/allbiohub/v1/startups/filters` |
| Startups: hero + search, stats, featured, browse by industry/country, all startups with the website's 7 sort options, call to action | add-on `/startups`, `/startups/filters` |
| Startup directory: search, sort, filters (industry, country, city, stage, funding, model, team size, verified/claimed/featured) | add-on `/startups?…` |
| Startup profile: details, founders, products, social, claim/suggest, AllBioHub coverage | add-on `/startups/{slug}` + story search |
| Reader: native HTML rendering, text size, save, share, tags, related | `/wp/v2/posts/{id}` or `?slug=` |
| Category, tag and author feeds | `/wp/v2/posts?categories=` / `tags=` / `author=` |
| Search: stories and topics, recent searches | `?search=` |
| Saved (offline), Profile (topics, theme, text size, notifications, about, privacy, clear cache), onboarding | on the phone |

When the startup add-on is off, every startup surface says the directory is
on its way and links to allbiohub.com. Badges show only when the API says
`true`.

Behaviour carried over from the Flutter app: the response cache (fresh copy
without a request, stale copy with an offline banner when the network fails),
batched `include=` requests because the live site ignores `_embed`, the
smallest sharp image rendition, hidden categories, App Links for
allbiohub.com, and FCM topics `breaking`, `celebrity`, `technology`,
`startups`, `money`, `biography`, `spotlight` (a push with `data.url` opens
that page).

Community features (accounts, profiles, reactions, comments, follows, saved
startups and founders, polls, notifications inbox, submissions and claims)
use the same Firebase backend as the Flutter app and stay switched off until
turned on in Firestore `config/app` (../COMMUNITY.md). Code is in
`src/features/community` (models, API, Firebase adapter, store, hooks,
components) with screens under `src/app/account`, `src/app/me`,
`src/app/submit`, `src/app/u`, `src/app/founder`, `src/app/polls.tsx` and
`src/app/article/[id]/comments.tsx`. Builds without `google-services.json`
switch every community feature off.

## Run it

```bash
cd mobile
npm install
cp .env.example .env.local     # optional, defaults point at allbiohub.com
npx expo start                 # scan the QR code with Expo Go
```

Push notifications need a development build (`npx expo run:android`, or
`eas build --profile development`) and a `google-services.json`; without one
the app runs with notifications off.

## Checks

```bash
npm run typecheck
npm run lint
npm test
```

CI (`.github/workflows/mobile-ci.yml`) runs these on every change under
`mobile/` and builds a test APK (artifact `allbiohub-expo-test-apk`).

## Layout

```
src/app/            Routes (Expo Router). (tabs)/ holds the five tabs.
src/api/            HTTP + cache, WordPress mapper, articles, taxonomy, startups, React Query hooks
src/features/       Reader (HTML → native blocks), startups helpers, push, onboarding
src/components/     Cards, images, buttons, states
src/stores/         Saved stories and preferences (zustand, AsyncStorage)
src/lib/            Text, dates, images, deep links, link opening, sharing
plugins/            Config plugin that signs release builds with the AllBioHub key
tool/               google-services.json writer, release notes
```

Releasing: see [RELEASE.md](RELEASE.md).
