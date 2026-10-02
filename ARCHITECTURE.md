# Architecture

## Layers

```
Presentation   lib/features/*/…_screen.dart, lib/shared/widgets
   ↓ watches
State          Riverpod providers and notifiers (…_providers.dart, PagedListNotifier)
   ↓ calls
Domain         lib/core/models (Article, Category, Author, Startup, Paginated, …)
   ↓ returned by
Repository     lib/core/repositories (ArticleRepository, TaxonomyRepository,
               StartupRepository, BookmarkRepository, PreferencesRepository)
   ↓ uses
Data/API       lib/core/networking (ApiClient on Dio, WordPressMapper, AppException)
   ↓ backed by
Local cache    lib/core/cache (CacheStore, LocalStore on Hive)
```

Widgets never make HTTP requests or parse JSON. Screens read providers;
providers call repositories; repositories call `ApiClient` and map JSON into
models. `lib/core/providers.dart` wires the graph and is the single place to
swap implementations (tests override it with fakes).

## Folder layout

```
lib/
  main.dart                 Opens Hive, overrides storage providers, runs the app
  app.dart                  MaterialApp.router, themes, text-scale clamp
  core/
    config/                 AppConfig from --dart-define (no secrets)
    networking/             ApiClient (cache policy), WordPressMapper, AppException
    cache/                  CacheStore (API responses), LocalStore (bookmarks, settings)
    models/                 Domain models
    repositories/           Data access per domain
    services/               Analytics, notifications, sharing
    routing/                Routes, GoRouter config, deep-link parser
    theme/                  Light/dark themes, BrandColors, typography
    utils/                  HTML-to-text, reading time, dates
    providers.dart          Dependency graph
  features/
    splash/ onboarding/ shell/ home/ discover/ search/
    articles/               Reader, native HTML renderer, category/tag feeds
    startups/               Startups home, directory + filters, profile
    bookmarks/ profile/
  shared/
    widgets/                Cards, images, skeletons, empty/error/offline states
    paged_list.dart         Generic infinite-list notifier
    link_opener.dart        In-app vs browser link handling
```

## Key decisions

**State: Riverpod 3.** `FutureProvider` for read-only data,
`AsyncNotifier`/`Notifier` where screens trigger actions (refresh, bookmark,
search). Automatic retry is turned off in `main.dart`: every error state has
its own Retry button.

**HTTP: Dio**, created once. Debug builds log request lines only (no bodies).

**Cache: Hive CE** (pure Dart, no code generation). `ApiClient.getJson`:
fresh cache → no request; otherwise network, then cache; network failure →
last cached copy flagged `stale`, and screens show an offline banner.
Cache size is capped (oldest entries dropped). Images are cached on disk by
`cached_network_image`, decoded at display size.

**Lists: `PagedListNotifier`.** One request at a time, de-duplicates items
that shift between pages, separate first-page and load-more errors, lazy
first load for lists at the bottom of a screen.

**Article rendering: native.** `ArticleHtml` parses WordPress HTML with
`package:html` and builds Flutter widgets for a whitelist of elements
(paragraphs, headings, lists, quotes, figures, tables, code). Scripts,
styles and forms are dropped; iframes/video become link cards (YouTube
embeds open the YouTube app); only http(s)/mailto/tel links are tappable;
lazy-load placeholders (`data:` src) are replaced with `data-src`.
No WebView anywhere.

**Navigation: go_router** with a `StatefulShellRoute` (five tabs that keep
their own stacks). Detail screens sit on the root navigator above the tabs.
An unrecognized path is treated as an incoming allbiohub.com link and
translated by `DeepLinkParser`, so App Links need no extra plumbing.

**Links.** `openLink`: allbiohub.com stories/categories/startups open
in-app; other allbiohub.com pages (forms, account) open in an in-app
browser tab (Custom Tabs), which can't bounce back into the app via App
Links; external sites open in the browser or their app.

**Startups.** `StartupRepository` targets the proposed read-only endpoint
(API.md). A 404 on the route raises `StartupDirectoryUnavailable`, which
every startup surface turns into an honest "coming soon" state with links
to the website. Rails, filters and badges render only from real data.

**Analytics.** `AnalyticsService` with typed `AnalyticsEvent`s. Debug builds
print, release builds are no-op until a sink is added. A Firebase sink and an
`ab-analytics` sink (the website's own system) can run side by side through
`CompositeAnalyticsService`; screens don't change. Only content identifiers
are logged (ids, slugs, search terms), never personal data.

**Notifications.** `NotificationService` with `NotificationTopic`s matching
FCM topic names. `DisabledNotificationService` is used until Firebase is
configured; preferences are stored either way.

**Theming.** Material 3 with hand-tuned light and dark palettes (not
generated or inverted) plus a `BrandColors` extension. Brand gold for fills,
a darker/lighter "gold text" variant per theme for AA contrast. Playfair
Display for headlines, Inter for UI and body, bundled (no runtime font
download). System text size is respected and clamped to 0.85–1.6×; the
reader has its own size setting on top.

**iOS later.** Nothing in `lib/` is Android-specific. iOS needs signing,
App Store metadata, an Associated Domains entitlement for universal links,
and `GoogleService-Info.plist` when Firebase is added.
