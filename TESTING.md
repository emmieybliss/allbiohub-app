# Testing

```bash
flutter analyze
flutter test                 # everything
flutter test test/unit       # models, API client, repositories, routing
flutter test test/widget     # rendering and screens
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
| Accessibility | Light and dark text colours meet WCAG AA contrast (`theme_test`) |

## Manual checks before a release

See RELEASE.md step 6. The app was built in an environment that could not
reach allbiohub.com or install the Android SDK, so run these on a device
against the live site before the first release.
