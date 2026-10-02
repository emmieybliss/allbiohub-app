# API

Every network call the app makes, and the one endpoint it still needs.
All requests are HTTPS `GET`s to `WORDPRESS_BASE_URL` (default
`https://allbiohub.com`), are unauthenticated, and go through
`lib/core/networking/api_client.dart`. No request writes to the website.

Findings come from inspecting the live site on 2 October 2026 (read-only).

## Website architecture (as found)

| Area | Finding |
|---|---|
| Platform | Self-hosted WordPress, REST API public at `/wp-json/` |
| Theme | Foxiz (image sizes `foxiz_crop_*`) |
| Plugins seen via REST | Rank Math (SEO, sitemaps, schema), Elementor, LiteSpeed Cache, Akismet, IndexNow, Brevo (`mailin`), WPMU DEV, Image Optimizer, Google Site Kit, WordPress Abilities/MCP, custom `ab-analytics/v1` |
| Post types in REST | `post`, `page`, `attachment` plus builder/system types. **No startup type.** |
| Taxonomies | `category`, `post_tag` |
| Categories | biography (1), celebrity-news (137), around-the-web (124), startup-founders-innovator (231), reviews (206), money-career (216), women-in-tech (611), editorial-submission (777), sponsored (639) |
| Article URLs | `https://allbiohub.com/{post-slug}/` |
| Category URLs | `https://allbiohub.com/category/{slug}/` |
| Startup URLs | `https://allbiohub.com/startups/` (paged `/startups/page/{n}/`), profiles `/startups/{slug}/` |
| Startup pages | `list-your-startup`, `claim-startup`, `startup-account`, `startup-dashboard`, `startup-pricing` |
| Sitemap | `/sitemap_index.xml` (Rank Math): posts, pages, categories. No startups. |
| Search | WordPress core search (`?search=`) |
| Auth | None needed for public content. `ab-analytics` and abilities routes return 401. |

## Endpoints used today

Common post parameters:
`_embed=author,wp:featuredmedia,wp:term` (author, featured image with all
sizes, and terms in one request) and `_fields=…` to drop unused fields.
List requests omit `content`, the heaviest field.

| Purpose | Request | Cache |
|---|---|---|
| Latest stories / category / tag feeds | `GET /wp-json/wp/v2/posts?page&per_page&categories&tags&exclude&_embed&_fields` | 5 min |
| Featured (sticky) stories | `GET /wp-json/wp/v2/posts?sticky=true&per_page=5&_embed&_fields` | 10 min |
| Article by id | `GET /wp-json/wp/v2/posts/{id}?_embed&_fields` (incl. `content`) | 1 h |
| Article by slug (deep links) | `GET /wp-json/wp/v2/posts?slug={slug}&_embed&_fields` | 1 h |
| Related stories | `GET /wp-json/wp/v2/posts?categories={primary}&exclude={id}&per_page=4` | 5 min |
| Story search | `GET /wp-json/wp/v2/posts?search={q}&per_page=10` | 10 min |
| Startup coverage | `GET /wp-json/wp/v2/posts?search="{startup name}"` then whole-word match on title/excerpt | 10 min |
| Categories | `GET /wp-json/wp/v2/categories?per_page=100&hide_empty=true&orderby=count&order=desc` | 12 h |
| Category / tag by slug | `GET /wp-json/wp/v2/categories?slug=` / `GET /wp-json/wp/v2/tags?slug=` | 12 h |
| Popular tags | `GET /wp-json/wp/v2/tags?orderby=count&order=desc&per_page=20` | 12 h |
| Topic search | `GET /wp-json/wp/v2/categories?search=` and `/tags?search=` | 1 h |

| Missing images (see below) | `GET /wp-json/wp/v2/media?include={ids}&per_page={n}` | 1 day |
| Missing authors | `GET /wp-json/wp/v2/users?include={ids}` | 1 day |
| Missing tags (reader) | `GET /wp-json/wp/v2/tags?include={ids}` | 1 day |
| Category labels | `GET /wp-json/wp/v2/categories?per_page=100` | 12 h |

**`_embed` and `_fields` are currently ignored by the live site.** Responses
come back as full post objects with ids only for the author, image and
terms (likely a caching or security layer dropping `_`-prefixed query
parameters). The app still sends them, since they make responses smaller
and faster wherever they work, and when the embedded data is missing it
fetches images, authors and terms in one batched `include=` request per
kind (`ArticleRepository._complete`). Fixing this on the server (for
example excluding `/wp-json/` from query-string stripping) would cut
requests and payload size, but isn't required.

Pagination uses the `X-WP-Total` and `X-WP-TotalPages` headers. A page past
the end (`400 rest_post_invalid_page_number`) is treated as the end of the list.

Images: the app picks the smallest `media_details.sizes` rendition that is
sharp at the rendered width (`MediaImage.urlFor`), so cards download
`medium`/`large`, not the original upload.

Hidden categories (not shown as sections): `uncategorized`,
`editorial-submission`, `sponsored` (`TaxonomyRepository.hiddenCategorySlugs`).

Not used: `ab-analytics/v1/*` (admin-only), any authenticated route.
Trending and Editor's Picks are not shown because no public endpoint
provides them; Featured uses sticky posts, falling back to the newest stories.

## Startup directory API (required, not yet on the website)

The startup database is not exposed by any REST route. The app is built
against the read-only contract below under `STARTUP_API_PATH`
(default `/wp-json/allbiohub/v1`). Until it exists, the Startups tab explains
that the directory is coming and links to the website; nothing is faked.

Recommended implementation: a small, separate WordPress plugin that
registers these `GET` routes (`register_rest_route`, `permission_callback`
returning `true`), reads from wherever the existing startup plugin stores
its data, and returns only public fields. It adds routes and changes no
existing data, pages or URLs. Responses should send
`Cache-Control: public, max-age=300` so LiteSpeed can cache them.

### `GET /startups`

Query parameters (all optional; unknown filters ignored):

| Param | Type | Meaning |
|---|---|---|
| `page`, `per_page` | int | Pagination (`per_page` ≤ 50) |
| `search` | string | Name, tagline, description |
| `industry`, `country`, `city`, `stage`, `funding`, `business_model`, `employees` | string | Exact filter values from `/startups/filters` |
| `founded_from`, `founded_to` | int | Founded year range |
| `verified`, `claimed`, `featured` | 0/1 | Status flags |
| `orderby` | `newest` \| `updated` \| `verified` \| `name` | Sort |

Response: JSON array of startup objects, with `X-WP-Total` and
`X-WP-TotalPages` headers.

### `GET /startups/{slug}`

One startup object, `404` if not found.

### `GET /startups/filters`

Values that exist in the directory, so the app never hardcodes them:

```json
{
  "industries": [{"value": "saas", "label": "SaaS", "count": 12}],
  "countries": [{"value": "Nigeria", "label": "Nigeria", "count": 140}],
  "stages": [], "funding": [], "business_models": [], "employees": []
}
```

Each option may also be a plain string.

### Startup object

```json
{
  "id": 7,
  "slug": "vast",
  "name": "Vast",
  "link": "https://allbiohub.com/startups/vast/",
  "tagline": "Haven-1, a commercial space station",
  "description": "…",
  "logo": "https://allbiohub.com/wp-content/uploads/…/logo.png",
  "industry": "Habitats",
  "country": "United States",
  "city": "Long Beach",
  "founded": 2021,
  "stage": "Series A",
  "funding": "Founder funding",
  "business_model": "B2B",
  "employees": "51–200",
  "status": "Active",
  "website": "https://vastspace.com",
  "social": {"linkedin": "https://…", "x": "https://…"},
  "founders": [{"name": "…", "role": "Founder", "url": null}],
  "products": ["Haven-1"],
  "verified": false,
  "claimed": false,
  "featured": false,
  "created_at": "2026-09-25T10:00:00Z",
  "updated_at": "2026-09-25T10:00:00Z",
  "verified_at": null
}
```

Only `id`, `slug`, `name` and `link` are required; the app hides anything
missing. `logo` may also be a WordPress media object. `verified`, `claimed`
and `featured` must reflect the database exactly: the app shows badges only
when they are `true`.

Startup actions (List, Claim, Suggest an update) open the existing website
forms in an in-app browser tab; the app doesn't submit them itself.
