# Getting rid of the "harmful" warnings

## Why phones warn

When someone downloads `allbiohub.apk` from a website, Android shows up to
three warnings. None of them is about AllBioHub itself:

| Warning | Who shows it | Can we remove it? |
|---|---|---|
| "This type of file can harm your device" | Chrome, for **every** APK downloaded from a website | Only by being on Google Play |
| "Your phone is not allowed to install unknown apps from this source" | Android, the first time a browser or Files app installs an app | Only by being on Google Play |
| "App scan recommended" / "Send app for security check?" | Google Play Protect, for apps it hasn't seen many times | Reduced by registering the app with Google (below); gone on Google Play |

So the real fix is **Google Play**: apps installed from it show none of
these. Until then, the download page (`wordpress/download-page/`) tells
people exactly what to tap, and the release ships a smaller APK.

## Step 1: register the app with Google (free)

Google is rolling out **Android developer verification**: apps installed
outside Google Play must come from a developer who has registered with
Google, starting in some countries in late 2026 and everywhere in 2027.
Registered apps are known to Play Protect, which cuts down the scan prompts.

1. Go to the Android Developer Console
   (https://developer.android.com/developer-verification) and sign in with
   the Google account AllBioHub will own the app with.
2. Verify your identity (personal) or organisation, as it asks.
3. Register the package name `com.allbiohub.app` and the release key. It
   asks for the key's SHA-256 fingerprint: copy it from the summary of the
   latest **Actions → Release** run ("Release key fingerprints").

If you go on to create a Google Play developer account (step 2), use the
same Google account: a Play account counts as verified, and the app is
registered when you upload it.

## Step 2: publish on Google Play

### What it needs from you

- A **Google Play developer account**: https://play.google.com/console/signup,
  a one-time USD 25 fee, and an ID check.
  - **Personal account:** Google requires a **closed test with at least 12
    testers who stay opted in for 14 days** before you can publish to
    everyone. Ask 12+ people (staff, friends, readers) for the Gmail
    address they use on their Android phone.
  - **Organisation account:** skips the 12-tester rule, but needs a free
    D-U-N-S number for AllBioHub Media (https://www.dnb.com/duns.html),
    which can take a few days to a few weeks.
- An Android phone to confirm the account in the Play Console app.
- About an hour for the forms below. Everything else is ready in this
  repository.

### What's already done

- The app bundle (`allbiohub-release-aab` from every Release run).
- The 512 px icon: `assets/branding/play_store_icon_512.png`.
- The feature graphic (1024 x 500): `assets/branding/play_feature_graphic.png`
  (`python3 tool/brand/make_feature_graphic.py` rebuilds it).
- The privacy policy: https://allbiohub.com/privacy-policy/
- Only internet and (asked when turned on) notification permissions, no
  advertising id, no ads.

### Steps in the Play Console

1. **Create app:** name `AllBioHub`, default language English, App, Free.
2. **App signing:** the first time you upload, Play asks how to sign the
   app. Choose **Use a different key → Export and upload a key from Java
   keystore**, and follow its steps with your existing
   `allbiohub-release.jks` (RELEASE.md, step 1). This keeps the same key
   as the website APK, so people who installed from the website get the
   Play version as a normal update. (If Play signs with its own new key
   instead, website users would have to uninstall first.)
3. **Testing → Closed testing → Create track:** upload the AAB, add your
   testers' emails, and share the opt-in link with them. They install
   from that link and keep the app for 14 days. (Organisation accounts can
   go straight to step 5 after the forms.)
4. **App content** (left menu, "Policy and programs"), answer:
   - Privacy policy: https://allbiohub.com/privacy-policy/
   - Ads: **No**.
   - App access: **All functionality is available without special access**.
   - Content rating: fill in the questionnaire (category: News /
     Reference; no violence or gambling).
   - Target audience: **18 and over** (or 13+). Don't pick under-13 ages,
     which adds the Families rules.
   - News apps: **Yes**, it's a news/magazine app; give AllBioHub Media's
     contact details and the website as it asks.
   - Data safety: **No data shared**. Collected: **App activity → App
     interactions** and **Device or other IDs** (anonymous analytics and
     the notification token, both via Firebase), encrypted in transit, not
     required for the app to work (users can't opt out in-app, so answer
     that question honestly as "No" if asked). No location, contacts,
     photos, financial or personal info.
5. **Store listing:** short description (80 characters), for example
   *Stories shaping Africa, and the African startups behind them.*; a full
   description; the icon and feature graphic above; and at least 2 phone
   screenshots (take them on your phone: Home, a story, Startups, a
   startup profile).
6. **Production → Create release** (after the 14 days, choose **Apply for
   production** first on a personal account): upload the latest AAB and
   roll out. Google's review usually takes a few days.

### After it's live

- Change the website's download button to the Play Store link
  (`wordpress/download-page/README.md`, last section).
- Add Play's **App signing key** SHA-256 (Play Console → Setup → App
  signing) to `assetlinks.json` (README → Deep linking). If you uploaded
  your own key in step 2, it's the same fingerprint you already have.
- For each new version: raise `version:` in `pubspec.yaml`, run the Release
  workflow, and upload the new AAB in Production → Create release.
