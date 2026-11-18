# Releasing the Expo app

## Version numbers

Edit `VERSION` and `ANDROID_VERSION_CODE` at the top of `app.config.ts`.
`ANDROID_VERSION_CODE` must go up by at least 1 for every APK or bundle you
publish. The Flutter app shipped versionCode 1; the Expo app starts at 2.

## Signed APK from GitHub (recommended)

Uses the secrets the Flutter release already uses: `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` and
the `FIREBASE_*` values. Nothing new to set up.

1. GitHub → **Actions** → **Release (Expo app)** → **Run workflow**. Leave
   "Publish the APK" unticked the first time.
2. When it finishes, open the run, download **allbiohub-expo-release-apk**
   and install `allbiohub.apk` on a phone that has the current AllBioHub app.
   It must install as an update. If Android says the app conflicts, the key
   is wrong: stop and check the secrets.
3. Happy with it? Run the workflow again with **Publish the APK** ticked. That
   creates the `v<version>` GitHub Release, and the website link
   https://github.com/emmieybliss/allbiohub-app/releases/latest/download/allbiohub.apk
   starts serving it.

The run summary shows the key's SHA-256. It must equal the Flutter release's,
which is also what `https://allbiohub.com/.well-known/assetlinks.json` lists.

People updating from 1.x keep the app but start with an empty Saved list and
default settings: the Flutter app's on-phone storage isn't read by the new app.

## Google Play

The workflow also produces `allbiohub-expo-release-aab` (artifact). Upload it
to Play Console as described in `../PLAY_STORE.md`.

## Building with EAS (optional)

EAS works too, as in the Simvaya app, but it must sign with the same key:

1. `npx eas-cli@latest login`, then `npx eas-cli@latest init` in `mobile/`
   and put the project ID into `EAS_PROJECT_ID` (or as the default in
   `app.config.ts`).
2. `npx eas-cli@latest credentials` → Android → production → **upload your
   existing keystore** (the one in `C:\Users\emmie\OneDrive\Documents\keystore`).
   Never let EAS generate a new key for this app: installed phones would
   refuse the update.
3. `npx eas-cli@latest build --profile preview --platform android` for a test
   APK, `--profile production` for a Play Store bundle.

Push notifications in EAS builds need `google-services.json`: add it as a
file secret (`eas env:create --type file --name GOOGLE_SERVICES_FILE`).
