# AllBioHub App API (WordPress plugin)

Shares the allbiohub.com startup directory with the AllBioHub app through
three read-only routes:

```
GET /wp-json/allbiohub/v1/startups           list, search, filters, sorting
GET /wp-json/allbiohub/v1/startups/filters   industries, countries, stages, …
GET /wp-json/allbiohub/v1/startups/{slug}    one startup
```

The contract is in [API.md](../../API.md).

## What it does and doesn't do

- **Read-only.** It only reads startups. It never changes startups, posts,
  pages, menus, URLs or settings, and adds no database tables.
- **Off until you turn it on.** After activation the routes answer
  "not found" (the app keeps showing "coming soon") until you check the
  preview and switch it on.
- **Only public fields.** It sends a fixed list of fields (name, tagline,
  description, logo, industry, country, city, founded, stages, employees,
  status, website, social links, founders, products, verified, claimed,
  featured, dates). Anything else stored with a startup, such as owner
  emails, payment details or internal notes, is never sent.
- **Only live startups.** Drafts, pending and private listings stay hidden.
- **Badges are never invented.** Verified, claimed and featured are `true`
  only when the directory stores them as yes.
- **Light on the server.** The directory is read once and cached for 10
  minutes (refreshed as soon as a startup is edited), and responses allow
  LiteSpeed to cache them for 5 minutes.

## Install

1. Download `allbiohub-app-api.zip`.
2. In WordPress: **Plugins → Add New → Upload Plugin**, choose the zip,
   **Install Now**, then **Activate**.
3. Open **Tools → AllBioHub App API**. It shows:
   - where it found the startups (the startup plugin's post type or table)
     and how many are live,
   - which stored field feeds each app field,
   - a preview of the first startup exactly as the app will see it.
4. If the preview looks right, tick **Share the startup directory with the
   app** and **Save**. The Startups tab in the app fills in on next open.

To stop sharing, untick and save, or deactivate the plugin. Deleting the
plugin removes its one setting and its cache; startup data is untouched.

If LiteSpeed Cache or a security plugin blocks `/wp-json/` for visitors,
allow `/wp-json/allbiohub/v1/` (the app already relies on `/wp-json/wp/v2/`
for stories, so this is usually already fine).

## How it finds the data

It looks for, in order:

1. A post type whose URL base is `/startups/` or whose name contains
   "startup". Details come from its post meta and taxonomies (for example
   the taxonomies behind `/startups/industry/…` and `/startups/country/…`).
2. A database table whose name contains "startup" and has `id`, a name
   column and a `slug` column.

Field names are matched loosely (`industry`, `startup_industry`,
`_ab_industry` all count as industry). The settings screen lists any field
it couldn't find; those are simply hidden in the app.

### For developers: overriding

```php
// Use a different field for a value.
add_filter( 'allbiohub_app_api_field_map', function ( $map ) {
	$map['stage'] = 'growth_stage';   // normalised source key
	return $map;
} );

// Adjust a startup before it's sent.
add_filter( 'allbiohub_app_api_startup', function ( $startup, $record ) {
	return $startup;
}, 10, 2 );

// Supply your own source (an AllBioHub_App_API_Source implementation).
add_filter( 'allbiohub_app_api_source', function () {
	return new My_Startup_Source();
} );
```

## Tests

```bash
php wordpress/allbiohub-app-api/tests/run.php
```

These cover field mapping, privacy (unknown fields never output), search,
filters, sorting and pagination without WordPress. The plugin was also run
against WordPress 7.1 with a startup post type and with a startup table:
routes, the off switch, hidden drafts, cache refresh on edits and the
settings screen. `test/unit/startup_contract_test.dart` checks the app
parses the plugin's real output.
