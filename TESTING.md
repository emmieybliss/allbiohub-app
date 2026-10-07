# Testing

```bash
flutter analyze
flutter test                 # everything
flutter test test/unit       # models, API client, repositories, routing
flutter test test/widget     # rendering, screens and user journeys
```

Tests never touch the real website. `test/helpers/fake_http.dart` plugs a
fake adapter into Dio that serves canned WordPress-shaped JSON from
`test/fixtures/` (test-only data, never bundled in the app) and can simulate
being offline. `test/helpers/test_app.dart` pumps a screen with in-memory
storage.

## What's covered

| Area | Tests |
|---|---|
| Model parsing | Post with embeds, entity decoding, category order, image sizes, author/image error embeds, malformed posts (`wordpress_mapper_test`) |
| API client | Pagination headers, fresh cache without a request, expiry and forced refresh, stale cache when offline, friendly errors for offline/404/500, no raw exception text (`api_client_test`) |
| Repositories | Images/authors/categories fetched when `_embed` is ignored, failures leave placeholders, slim list requests, last page, malformed and empty responses, page past the end, slug not found, hidden categories, startup API missing, startup parsing and filters (`repositories_test`) |
| Pagination | Load more, de-duplication, first-page error and retry, load-more error keeps items, lazy lists (`paged_list_test`) |
| Bookmarks and settings | Save/unsave/order, survives restart, corrupt data, preferences, recent searches (`local_storage_test`) |
| Deep links | Site URLs to app routes, website-only pages left alone (`deep_links_test`) |
| Utilities | Plain text, reading time, relative dates, share text uses canonical URLs, startup filter state (`text_utils_test`) |
| Article rendering | Paragraphs, headings, lists, quotes; scripts/forms dropped; relative and unsafe links; embeds; captions; lazy-load images (`article_html_test`) |
| Screens | Saved empty and filled, Home success, offline error and retry, offline cache fallback, reader content and saving, Startups without API, dark mode (`screens_test`) |
| Startup API contract | The app parses real output from the WordPress add-on (`startup_contract_test`) |
| Accessibility | Light and dark text colours meet WCAG AA contrast (`theme_test`) |
| User journeys | Whole app with its router: first launch and onboarding, open a story, save it and find it in Saved, allbiohub.com links, every tab, dark mode, search; phone and small-phone screens at the largest text size without overflow (`journeys_test`) |

## Community backend

```bash
cd firebase/functions
npm ci && npm run lint && npm test       # validation rules (usernames, slugs, replies)
npm run build && npm run test:emulator   # security rules and functions on the Firebase emulators
```

The emulator run needs Java 21 and `npm install -g firebase-tools`. App-side
community tests use the in-memory backend in `test/helpers/fake_community.dart`
(`test/unit/community_test.dart`, `test/widget/community_test.dart`).

## WordPress add-on

```bash
php wordpress/allbiohub-app-api/tests/run.php
```

Field mapping, privacy (only contract fields are ever sent), search,
filters, sorting and pagination. CI runs these on PHP 7.4 and 8.3 and
uploads the installable plugin zip. See the plugin's README for what was
checked against a real WordPress install.

## Manual checks before a release

See RELEASE.md step 5. The app was built in an environment that could not
reach allbiohub.com or install the Android SDK, so run these on a device
against the live site before the first release.
