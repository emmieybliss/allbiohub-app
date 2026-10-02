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

## 2. Point the build at it

Create `android/key.properties` in the project (it's git-ignored):

```properties
storeFile=/full/path/to/allbiohub-keys/allbiohub-release.jks
storePassword=your keystore password
keyAlias=allbiohub
keyPassword=your key password (same as above unless you set another)
```

On Windows, write the path with forward slashes, for example
`storeFile=C:/Users/you/allbiohub-keys/allbiohub-release.jks`.

Without this file, release builds are signed with the debug key: fine for
testing, never for publishing. Step 6 below checks which key was used.

## 3. Set the version

In `pubspec.yaml`: `version: 1.0.0+1` is `versionName+versionCode`.
Increase the number after `+` for every release (Android refuses to install
an update with a lower or equal code).

## 4. Production config

Copy `.env.example` to `.env.prod` (git-ignored) and fill in:

- `PRIVACY_POLICY_URL`: already `https://allbiohub.com/privacy-policy/`;
  change it only if the page moves.
- `CONTACT_EMAIL`: shown in Profile → Contact.
- The four `FIREBASE_*` values, from README → Firebase → "Connect a new
  Firebase project". Leave them empty to ship without notifications and
  analytics.

## 5. Check and build

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=.env.prod
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

Smaller per-device downloads (optional):
`flutter build apk --release --split-per-abi --dart-define-from-file=.env.prod`
gives one APK per CPU type; offer `arm64-v8a` as the default download.

## 6. Verify before publishing

```bash
# Confirm the signature is the release key, not debug
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
# Install on a real device
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Then walk through: first launch and onboarding, Home scroll and pull to
refresh, open and share a story, save and unsave, search, Startups tab,
dark mode, airplane mode (cached stories + offline banner), and an
allbiohub.com link from another app.

## 7. Publish

Upload the APK to the download page with its version and SHA-256
(`sha256sum app-release.apk`) so people can check it. For App Links, make
sure `/.well-known/assetlinks.json` has the release key fingerprint
(README → Deep linking).

## Moving to Google Play

```bash
flutter build appbundle --release --dart-define-from-file=.env.prod
```

Upload `build/app/outputs/bundle/release/app-release.aab`. Use the same
release key as the upload key (or enroll it in Play App Signing) so APK
users can move to the Play version, and add Play's signing fingerprint to
`assetlinks.json`. See README → Play Store preparation for the listing items
still needed.
