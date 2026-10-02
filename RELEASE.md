# Releasing the APK

V1 is distributed as an APK from an AllBioHub download page (for example
`https://allbiohub.com/app/`). The same setup produces a Play Store App
Bundle later.

## 1. Create the release key (once)

```bash
keytool -genkey -v -keystore ~/keys/allbiohub-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias allbiohub
```

Keep the `.jks` file and its passwords somewhere safe and backed up (a
password manager plus an offline copy). **If it's lost, existing installs
can't be updated** with a new APK. Never commit it.

## 2. Point Gradle at it

Create `android/key.properties` (git-ignored):

```properties
storeFile=/absolute/path/to/allbiohub-release.jks
storePassword=…
keyAlias=allbiohub
keyPassword=…
```

Without this file, release builds are signed with the debug key: fine for
testing, not for distribution.

## 3. Set the version

In `pubspec.yaml`: `version: 1.0.0+1` is `versionName+versionCode`.
Increase the number after `+` for every release (Android refuses to install
an update with a lower or equal code).

## 4. Production config

Create `env/prod.json` from `env/example.json` (git-ignored) and fill in
`PRIVACY_POLICY_URL`, `CONTACT_EMAIL` and, if used, the `FIREBASE_*` values.

## 5. Check and build

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=env/prod.json
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

Smaller per-device downloads (optional):
`flutter build apk --release --split-per-abi --dart-define-from-file=env/prod.json`
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
flutter build appbundle --release --dart-define-from-file=env/prod.json
```

Upload `build/app/outputs/bundle/release/app-release.aab`. Use the same
release key as the upload key (or enroll it in Play App Signing) so APK
users can move to the Play version, and add Play's signing fingerprint to
`assetlinks.json`. See README → Play Store preparation for the listing items
still needed.
