# App download page

`allbiohub-app-download.html` is a ready-made "Get the app" section for
allbiohub.com: a download button, the step-by-step install guide (including
what to tap when the phone shows its warnings), and answers to common
questions. It only adds a page; nothing else on the site changes.

## Add it to the site (about 5 minutes)

1. Open the file on GitHub, click **Raw**, then select all and copy.
2. In WordPress: **Pages → Add New**. Title it `Get the AllBioHub app`.
3. Click **+** (add block), search for **Custom HTML**, and paste.
   Using Elementor? Add an **HTML** widget instead and paste there.
4. On the right, under **URL** (or **Permalink**), set the slug to `app`, so
   the page is `https://allbiohub.com/app/`.
5. Click **Preview** on your phone, then **Publish**.
6. Optional: add the page to the menu (**Appearance → Menus**) and link
   "Download the app" banners to `https://allbiohub.com/app/`.

Paste it as an administrator: WordPress removes the small script for other
roles. Without the script the page still works; it just doesn't show the
version and file size.

## What the buttons download

- **Download for Android:** `allbiohub.apk`, which works on almost every
  Android phone (32- and 64-bit).
- **Smaller download:** `allbiohub-arm64.apk`, for 64-bit phones (almost all
  phones sold since 2019). The page hides this link until a release
  includes it, which happens on the next run of the Release workflow
  (RELEASE.md, step 4).

Both links always serve the newest release, so the page never needs
editing for a new version.

## When the app is on Google Play

Replace the button's link with the Play Store link
(`https://play.google.com/store/apps/details?id=com.allbiohub.app`), change
its text to "Get it on Google Play", and remove the warning box and install
steps, which Google Play doesn't need. See PLAY_STORE.md.
