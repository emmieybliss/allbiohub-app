# Releasing the APK

V1 is distributed as an APK from an AllBioHub download page (for example
`https://allbiohub.com/app/`). The same setup produces a Play Store App
Bundle later.

## 1. Create the release key (once)

The release key proves every future update comes from AllBioHub. Android
refuses an update signed with a different key, so **if it's lost, people
must uninstall and reinstall to get updates**. Make it once, on your own
computer, and back it up.

1. Install [Android Studio](https://developer.android.com/studio) (it
   includes the `keytool` program) or any Java 17 JDK.
2. Open a terminal:
   - **Windows:** Start → type `cmd` → Command Prompt.
   - **Mac:** Applications → Utilities → Terminal.
3. Create a private folder for the key and go into it:
   - Windows: `mkdir %USERPROFILE%\allbiohub-keys && cd %USERPROFILE%\allbiohub-keys`
   - Mac: `mkdir -p ~/allbiohub-keys && cd ~/allbiohub-keys`
4. Run this (on Windows, if `keytool` isn't found, use the full path
   `"C:\Program Files\Android\Android Studio\jbr\bin\keytool"`; on Mac,
   `"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"`):

   ```bash
   keytool -genkey -v -keystore allbiohub-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias allbiohub
   ```

5. Answer the prompts:
   - **Keystore password:** a strong password (at least 12 characters).
     Write it in your password manager now.
   - **Name, organisation, city, country:** for example `AllBioHub Media`,
     `AllBioHub`, your city, and the two-letter country code (`NG`).
   - Type `yes` to confirm. If asked for a separate key password, press
     Enter to reuse the keystore password.
6. Back it up in two places: your password manager (attach the
   `allbiohub-release.jks` file and both passwords) and an offline copy
   (an encrypted USB stick). **Never** email it, commit it to Git or upload
   it to a shared drive.
7. Note the key's fingerprint, needed for App Links (README → Deep linking):

   ```bash
   keytool -list -v -keystore allbiohub-release.jks -alias allbiohub
   ```

   Copy the line starting `SHA256:`.

## 2. Give GitHub the key and the Firebase settings (once)

GitHub builds the signed app for you, so you don't need Flutter installed.
The key and passwords are stored as encrypted repository secrets: GitHub
never shows them again, and they are not part of the code.

1. Turn the key file into text and copy it:
   - **Windows** (PowerShell, in the `allbiohub-keys` folder):
     `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\allbiohub-release.jks")) | Set-Clipboard`
   - **Mac** (Terminal, in the `allbiohub-keys` folder):
     `base64 -i allbiohub-release.jks | pbcopy`
2. On GitHub, open the repository → **Settings → Secrets and variables →
   Actions → New repository secret**, and add each of these:

   | Name | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | paste what you just copied |
   | `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
   | `ANDROID_KEY_PASSWORD` | only if you set a separate key password |
   | `FIREBASE_PROJECT_ID` | from README → Firebase, step 4 |
   | `FIREBASE_API_KEY` | 〃 |
   | `FIREBASE_APP_ID` | 〃 |
   | `FIREBASE_MESSAGING_SENDER_ID` | 〃 |

   The Firebase secrets also turn on notifications and analytics in the
   test APK that every change builds.

## 3. Set the version

In `pubspec.yaml`: `version: 1.0.0+1` is `versionName+versionCode`.
Increase the number after `+` for every release (Android refuses to install
an update with a lower or equal code).

## 4. Build

On GitHub: **Actions → Release → Run workflow → Run workflow**. When it
finishes (about 15 minutes), open the run and download:

- `allbiohub-release-apk`: the APK for the download page,
- `allbiohub-release-aab`: the bundle for Google Play.

The run stops with a clear message if the key secrets are missing, and
refuses to finish if the app came out signed with the debug key. Its summary
shows the release key's SHA-1 and SHA-256 fingerprints.

## 5. Verify before publishing

Install the APK on a real phone (copy it over and open it, or
`adb install -r app-release.apk`). Then walk through: first launch and
onboarding, Home scroll and pull to refresh, open and share a story, save
and unsave, search, Startups tab, dark mode, airplane mode (cached stories +
offline banner), an allbiohub.com link from another app, and a test
notification (README → Sending a notification).

## 6. Publish

Upload the APK to the download page with its version and SHA-256
(`sha256sum app-release.apk`, or `certutil -hashfile app-release.apk SHA256`
on Windows) so people can check it. For App Links, make sure
`/.well-known/assetlinks.json` has the release key fingerprint
(README → Deep linking).

## Building on your own computer instead

Needs Flutter installed (README → Setup).

1. Create `android/key.properties` (it's git-ignored):

   ```properties
   storeFile=/full/path/to/allbiohub-keys/allbiohub-release.jks
   storePassword=your keystore password
   keyAlias=allbiohub
   keyPassword=your key password (same as above unless you set another)
   ```

   On Windows, write the path with forward slashes, for example
   `storeFile=C:/Users/you/allbiohub-keys/allbiohub-release.jks`. Without
   this file, release builds are signed with the debug key: fine for
   testing, never for publishing.
2. Copy `.env.example` to `.env.prod` (git-ignored) and fill in the four
   `FIREBASE_*` values. Don't put them in `.env.example`, which is in Git.
3. Build and check the signature:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter build apk --release --dart-define-from-file=.env.prod
   keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
   ```

   Output: `build/app/outputs/flutter-apk/app-release.apk`. For smaller
   per-device downloads, add `--split-per-abi` and offer `arm64-v8a` as the
   default download.

## Moving to Google Play

Upload the `allbiohub-release-aab` from the Release run (or, building
locally, `flutter build appbundle --release --dart-define-from-file=.env.prod`
and `build/app/outputs/bundle/release/app-release.aab`). Use the same
release key as the upload key (or enroll it in Play App Signing) so APK
users can move to the Play version, and add Play's signing fingerprint to
`assetlinks.json`. See README → Play Store preparation for the listing items
still needed.
